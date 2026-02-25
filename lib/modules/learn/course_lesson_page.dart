// lib/modules/learn/course_lesson_page.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import '../../data/language_loader.dart';
import '../../services/settings_controller.dart';
import '../../services/tts_service.dart';
import '../../services/playback_session_service.dart';
import '../../services/favorites_service.dart';
import '../../services/srs_service.dart';

import 'widgets/bilingual_pairs_wrap.dart';
import 'widgets/sentence_item.dart';

import 'package:shared_preferences/shared_preferences.dart';

class CourseLessonPage extends StatefulWidget {
  final SettingsController settings;
  final String targetLang;
  final String nativeLang;
  final String levelKey;
  final String levelTitle;
  final int courseIndex;
  final List<int> courseIds;
  final int startIndex;

  const CourseLessonPage({
    super.key,
    required this.settings,
    required this.targetLang,
    required this.nativeLang,
    required this.levelKey,
    required this.levelTitle,
    required this.courseIndex,
    required this.courseIds,
    required this.startIndex,
  });

  @override
  State<CourseLessonPage> createState() => _CourseLessonPageState();
}

class _CourseLessonPageState extends State<CourseLessonPage> {
  final TtsService _tts = TtsService();
  late final PlaybackSessionService _session;

  bool _autoRunning = false;
  late int _index;

  Map<String, dynamic>? _l2;
  Map<String, dynamic>? _l1;

  bool get _sameLang => widget.nativeLang == widget.targetLang;

  // Cache for sidebar word titles (L2)
  final Map<int, Future<Map<String, dynamic>?>> _l2TitleCache = {};

  // Favorites
  Set<int> _favorites = {};
  bool _favoritesLoaded = false;

  // Scroll controllers for Sheet and Sidebar (fix Scrollbar exception)
  final ScrollController _sheetScrollController = ScrollController();
  final ScrollController _sidebarScrollController = ScrollController();

  // ===== Test / Course mastery state =====
  bool _testRunning = false;
  bool _courseMastered = false;

  // Local session results
  final List<_TestResult> _testSessionResults = [];

  // Abort flag (allows user to quit test anytime)
  bool _testAbort = false;

  // ===== Persist last test summary so it doesn't "disappear" =====
  int _lastTestTotal = 0;
  int _lastTestCorrect = 0;
  int _lastTestPercent = 0;
  List<_TestResult> _lastWrongResults = [];

  @override
  void initState() {
    super.initState();
    _session = PlaybackSessionService(tts: _tts, settings: widget.settings);
    _index = widget.startIndex.clamp(0, widget.courseIds.length - 1);
    _loadCurrentWord();
    _loadFavorites();
    _loadCourseMastered();

    // Warm-up (help web tts latency)
    Future.microtask(() async {
      try {
        await _applySpeed();
        await _tts.speak(' ', LanguageLoader.langCode(widget.targetLang));
        await _tts.stop();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _session.stop();
    _sheetScrollController.dispose();
    _sidebarScrollController.dispose();
    super.dispose();
  }

  // =========================
  // Course mastered persistence
  // =========================
  String _courseMasteredKey() =>
      'course_mastered_${widget.nativeLang}_${widget.targetLang}_${widget.levelKey}_c${widget.courseIndex}';

  Future<void> _loadCourseMastered() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getBool(_courseMasteredKey()) ?? false;
    if (!mounted) return;
    setState(() => _courseMastered = v);
  }

  Future<void> _markCourseMastered() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_courseMasteredKey(), true);
    if (!mounted) return;
    setState(() => _courseMastered = true);
  }

  Future<void> _unmarkCourseMastered() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_courseMasteredKey());
    if (!mounted) return;
    setState(() => _courseMastered = false);
  }

  // =========================
  // Favorites
  // =========================
  Future<void> _loadFavorites() async {
    final set = await FavoritesService.instance.getFavorites(
      nativeLang: widget.nativeLang,
      targetLang: widget.targetLang,
    );
    if (!mounted) return;
    setState(() {
      _favorites = set;
      _favoritesLoaded = true;
    });
  }

  Future<void> _toggleFavorite(int id) async {
    final l2Text = (_l2?['word'] ?? '').toString();
    final l1Text = (_l1?['word'] ?? '').toString();

    await FavoritesService.instance.toggleFavorite(
      nativeLang: widget.nativeLang,
      targetLang: widget.targetLang,
      id: id,
      l1: l1Text,
      l2: l2Text,
    );

    // reload local favorites for this language pair
    await _loadFavorites();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_favorites.contains(id) ? 'Added to Favorites' : 'Removed from Favorites'),
        duration: const Duration(milliseconds: 700),
      ),
    );
  }

  int get _currentId => widget.courseIds[_index];

  Future<void> _loadCurrentWord() async {
    final id = _currentId;
    final l2 = await LanguageLoader.loadWordById(widget.targetLang, id);
    final l1 = _sameLang ? l2 : await LanguageLoader.loadWordById(widget.nativeLang, id);

    if (!mounted) return;
    setState(() {
      _l2 = l2;
      _l1 = l1;
    });
  }

  Future<Map<String, dynamic>?> _loadL2Title(int id) {
    return _l2TitleCache[id] ??= LanguageLoader.loadWordById(widget.targetLang, id);
  }

  // --------- helpers ----------
  String _word(Map<String, dynamic>? m) => (m?['word'] ?? '').toString();

  String _firstDef(Map<String, dynamic>? m) {
    final defs = (m?['definitions'] is List) ? (m!['definitions'] as List) : const [];
    if (defs.isEmpty) return '';
    final first = defs.first;
    if (first is String) return first;
    if (first is Map && first.containsKey('text')) return (first['text'] ?? '').toString();
    return first.toString();
  }

  List<String> _sentences(Map<String, dynamic>? m, int maxCount) {
    final s = (m?['sentences'] is List) ? (m!['sentences'] as List) : const [];
    final n = min(maxCount, s.length);
    return List.generate(n, (i) => (s[i]['text'] ?? '').toString());
  }

  List<Map<String, dynamic>> _list(Map<String, dynamic>? m, String key) {
    final v = m?[key];
    if (v is List) return v.cast<Map<String, dynamic>>();
    return const [];
  }

  Map<int, String> _idTextMap(Map<String, dynamic>? m, String key) {
    final items = _list(m, key);
    final map = <int, String>{};
    for (final x in items) {
      final id = x['id'];
      if (id is int) map[id] = (x['text'] ?? '').toString();
    }
    return map;
  }

  // ---------- Speed ----------
  String _speedLabel(SpeechSpeed s) {
    switch (s) {
      case SpeechSpeed.slow3x:
        return 'Speed -3';
      case SpeechSpeed.slow2x:
        return 'Speed -2';
      case SpeechSpeed.slow1x:
        return 'Speed -1';
      case SpeechSpeed.normal:
        return 'Speed 0';
      case SpeechSpeed.fast1x:
        return 'Speed +1';
      case SpeechSpeed.fast2x:
        return 'Speed +2';
      case SpeechSpeed.fast3x:
        return 'Speed +3';
    }
  }

  Future<void> _applySpeed() async {
    await _tts.configure(
      speechRate: widget.settings.speechRateValue,
      pitch: widget.settings.pitch,
      volume: widget.settings.volume,
    );
  }

  Future<void> _speedDown() async {
    final i = widget.settings.speechSpeed.index;
    final next = max(0, i - 1);
    await widget.settings.update(() => widget.settings.speechSpeed = SpeechSpeed.values[next]);
    await _applySpeed();
    if (mounted) setState(() {});
  }

  Future<void> _speedUp() async {
    final i = widget.settings.speechSpeed.index;
    final next = min(SpeechSpeed.values.length - 1, i + 1);
    await widget.settings.update(() => widget.settings.speechSpeed = SpeechSpeed.values[next]);
    await _applySpeed();
    if (mounted) setState(() {});
  }

  // ---------- speak helpers ----------
  Future<void> _speakSingle(String text, String langCode) async {
    final t = text.trim();
    if (t.isEmpty) return;

    if (_autoRunning) await _stopAuto();

    await _tts.stop();
    await _applySpeed();

    await _tts.speakSequence([
      TtsItem(text: t, langCode: langCode, pauseMsAfter: widget.settings.pauseShortMs),
    ]);
  }

  List<String> _spellLetters(String word) {
    final chars = word.trim().split('');
    final out = <String>[];
    for (final c in chars) {
      if (RegExp(r'[A-Za-z0-9]').hasMatch(c)) out.add(c);
    }
    return out;
  }

  Future<void> _speakSpellingOnly(String word, String langCode) async {
    final w = word.trim();
    if (w.isEmpty) return;

    if (_autoRunning) await _stopAuto();

    final letters = _spellLetters(w);
    if (letters.isEmpty) return;

    final spellingText = letters.join(' ');

    await _tts.configure(
      speechRate: widget.settings.speechRateValue,
      pitch: widget.settings.pitch,
      volume: widget.settings.volume,
    );

    await _tts.speak(spellingText, langCode);
  }

  // --------- navigation ----------
  Future<void> _goPrev() async {
    if (_index <= 0) return;

    await _tts.stop();
    if (_autoRunning) await _stopAuto();

    setState(() => _index = _index - 1);
    await _loadCurrentWord();
  }

  Future<void> _goNext() async {
    if (_index >= widget.courseIds.length - 1) return;

    await _tts.stop();
    if (_autoRunning) await _stopAuto();

    setState(() => _index = _index + 1);
    await _loadCurrentWord();
  }

  Future<void> _jumpTo(int idx) async {
    if (_autoRunning) return;
    if (idx < 0 || idx >= widget.courseIds.length) return;

    await _tts.stop();
    setState(() => _index = idx);
    await _loadCurrentWord();
  }

  // --------- AUTO ----------
  Future<void> _startAutoFromHere() async {
    if (_autoRunning) return;

    await _tts.stop();
    setState(() => _autoRunning = true);

    await _session.startSessionForIds(
      ids: widget.courseIds,
      targetLang: widget.targetLang,
      nativeLang: widget.nativeLang,
      startFromIndex: _index,
      loop: false,
      minutes: 0,
      includeSynonyms: widget.settings.autoSpeakSynonyms,
      includeAntonyms: widget.settings.autoSpeakAntonyms,
      onWordStart: (idx, wordId) async {
        if (!mounted) return;
        setState(() => _index = idx);
        await _loadCurrentWord();
      },
      onProgress: (idx, wordId) async {
        await widget.settings.saveLearnPosition(
          nativeLang: widget.nativeLang,
          targetLang: widget.targetLang,
          levelKey: widget.levelKey,
          courseIndex: widget.courseIndex,
          wordIndexInCourse: idx,
        );
      },
    );

    if (mounted) setState(() => _autoRunning = false);
  }

  Future<void> _stopAuto() async {
    await _session.stop();
    if (mounted) setState(() => _autoRunning = false);
  }

  // ---------- UI helpers ----------
  void _openWordsSheet() {
    if (_autoRunning) return;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        final pad = widget.settings.tilePadding();
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.all(pad),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.list),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Words • ${_index + 1}/${widget.courseIds.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Scrollbar(
                    controller: _sheetScrollController,
                    thumbVisibility: true,
                    child: ListView.builder(
                      controller: _sheetScrollController,
                      itemCount: widget.courseIds.length,
                      itemBuilder: (context, idx) {
                        final id = widget.courseIds[idx];
                        final selected = idx == _index;

                        return FutureBuilder<Map<String, dynamic>?>(
                          future: _loadL2Title(id),
                          builder: (context, snap) {
                            final w = (snap.data?['word'] ?? '...').toString();
                            final isFav = _favorites.contains(id);
                            return ListTile(
                              dense: true,
                              selected: selected,
                              leading: CircleAvatar(
                                radius: 14,
                                child: Text('${idx + 1}', style: const TextStyle(fontSize: 11)),
                              ),
                              title: Text(
                                w,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Favorite star
                                  IconButton(
                                    icon: Icon(
                                      isFav ? Icons.star : Icons.star_outline,
                                      size: 20,
                                      color: isFav ? Colors.amber[700] : null,
                                    ),
                                    onPressed: _favoritesLoaded ? () => _toggleFavorite(id) : null,
                                  ),
                                  if (selected) const Icon(Icons.check),
                                ],
                              ),
                              onTap: () async {
                                Navigator.pop(context);
                                await _jumpTo(idx);
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _speedWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Slower',
            icon: const Icon(Icons.remove),
            onPressed: () => _speedDown(),
          ),
          Text(
            _speedLabel(widget.settings.speechSpeed),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          IconButton(
            tooltip: 'Faster',
            icon: const Icon(Icons.add),
            onPressed: () => _speedUp(),
          ),
        ],
      ),
    );
  }

  Widget _leftSidebar(double width) {
    final pad = widget.settings.tilePadding();
    final border = BorderSide(color: Colors.grey.shade300);

    return Container(
      width: width,
      decoration: BoxDecoration(border: Border(right: border)),
      child: Scrollbar(
        controller: _sidebarScrollController,
        thumbVisibility: true,
        child: ListView.builder(
          controller: _sidebarScrollController,
          itemCount: widget.courseIds.length,
          itemBuilder: (context, idx) {
            final id = widget.courseIds[idx];
            final selected = idx == _index;

            return FutureBuilder<Map<String, dynamic>?>(
              future: _loadL2Title(id),
              builder: (context, snap) {
                final w = (snap.data?['word'] ?? '...').toString();
                final isFav = _favorites.contains(id);
                return ListTile(
                  dense: true,
                  selected: selected,
                  contentPadding: EdgeInsets.symmetric(horizontal: pad * 0.6, vertical: pad * 0.15),
                  title: Text(
                    '${idx + 1}. $w',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          isFav ? Icons.star : Icons.star_outline,
                          size: 18,
                          color: isFav ? Colors.amber[700] : null,
                        ),
                        onPressed: _favoritesLoaded ? () => _toggleFavorite(id) : null,
                      ),
                    ],
                  ),
                  onTap: () => _jumpTo(idx),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // =========================
  // ====== Quick Course Test (Definition -> Choose word) ======
  // =========================

  // Prepare question IDs from current course (shuffled). If course length < requested count, use course length.
  Future<List<int>> _prepareCourseQuestionIds({required int count}) async {
    final ids = List<int>.from(widget.courseIds);
    ids.shuffle();
    if (ids.length > count) ids.removeRange(count, ids.length);
    return ids;
  }

  // Build options: correct id + 3 distractors from outside current course (preferred)
  Future<List<int>> _buildDefinitionOptionsFromOtherCourses(int correctId, {int needed = 3}) async {
    final allWords = await LanguageLoader.loadWords(widget.targetLang); // full list
    final pool = <int>[];
    for (final w in allWords) {
      final id = w['id'];
      if (id is int && id != correctId && !widget.courseIds.contains(id)) {
        pool.add(id);
      }
    }
    pool.shuffle();
    final picked = <int>[];
    for (final id in pool) {
      if (picked.length >= needed) break;
      picked.add(id);
    }

    // Fallback: if not enough outside-course words, pick from other ids in course (last resort)
    if (picked.length < needed) {
      final alt = widget.courseIds.where((i) => i != correctId).toList()..shuffle();
      for (final id in alt) {
        if (picked.length >= needed) break;
        if (!picked.contains(id)) picked.add(id);
      }
    }

    return picked;
  }

  // Map response time to SrsGrade (thresholds: <=1200 easy, <=4000 good, >4000 hard)
  SrsGrade _mapResponseToGrade(bool correct, int responseMs) {
    if (!correct) return SrsGrade.again;
    if (responseMs <= 1200) return SrsGrade.easy;
    if (responseMs <= 4000) return SrsGrade.good;
    return SrsGrade.hard;
  }

  // Localization helper for Quit label
  String _localizedQuitLabel() {
    final ui = (widget.settings.uiLanguage ?? 'english').toLowerCase();
    switch (ui) {
      case 'arabic':
      case 'ar':
      case 'arabic_language':
        return 'إنهاء الاختبار';
      case 'spanish':
      case 'es':
      case 'español':
        return 'Salir de la prueba';
      case 'english':
      case 'en':
      default:
        return 'Quit Test';
    }
  }

  // Ask one question: show definition, speak it (if autoplay), then show options and measure response time.
  Future<_QuestionOutcome> _askDefinitionQuestion(int wordId) async {
    // Reset abort for this question check (but global _testAbort controls overall)
    if (_testAbort) return _QuestionOutcome(wordId: wordId, answered: false, chosenId: -1, correct: false, responseMs: 0, graded: SrsGrade.again);

    // Load words
    final l2 = await LanguageLoader.loadWordById(widget.targetLang, wordId);
    final l1 = _sameLang ? l2 : await LanguageLoader.loadWordById(widget.nativeLang, wordId);
    if (l2 == null) return _QuestionOutcome(wordId: wordId, answered: false, chosenId: -1, correct: false, responseMs: 0, graded: SrsGrade.again);

    // Determine definition text (prefer L2 definition; fallback to L1)
    String defText = '';
    final defs2 = (l2['definitions'] is List) ? (l2['definitions'] as List) : const [];
    if (defs2.isNotEmpty) {
      final f = defs2.first;
      if (f is String) defText = f;
      else if (f is Map && f.containsKey('text')) defText = (f['text'] ?? '').toString();
      else defText = f.toString();
    } else {
      // fallback to L1 def if available
      final defs1 = (l1?['definitions'] is List) ? (l1!['definitions'] as List) : const [];
      if (defs1.isNotEmpty) {
        final f = defs1.first;
        if (f is String) defText = f;
        else if (f is Map && f.containsKey('text')) defText = (f['text'] ?? '').toString();
        else defText = f.toString();
      }
    }

    // Build options
    final distractors = await _buildDefinitionOptionsFromOtherCourses(wordId, needed: 3);
    final optionIds = <int>[wordId] + distractors;
    optionIds.shuffle();

    int chosenId = -1;
    int responseMs = 0;
    bool buttonsEnabled = false;
    final sw = Stopwatch();

    // Show dialog with definition first, then play TTS if enabled, then reveal options and start stopwatch
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          // start speaking automatically when dialog builds first time
          Future.microtask(() async {
            // ensure we only start speaking once
            if (!buttonsEnabled && !_testAbort) {
              try {
                await _applySpeed();
                if (defText.trim().isNotEmpty) {
                  await _tts.speak(defText, LanguageLoader.langCode(widget.targetLang));
                }
              } catch (_) {}
              // After TTS finished (or immediately if empty), reveal options and start stopwatch
              if (!mounted) return;
              setStateDialog(() {
                buttonsEnabled = true;
                sw.reset();
                sw.start();
              });
            }
          });

          // Build options widgets
          final optionButtons = optionIds.map((id) {
            return FutureBuilder<Map<String, dynamic>?>(
              future: _loadL2Title(id),
              builder: (c, snap) {
                final text = (snap.data?['word'] ?? (id == wordId ? (l2['word'] ?? '') : '...')).toString();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ElevatedButton(
                    onPressed: buttonsEnabled
                        ? () {
                            if (sw.isRunning) sw.stop();
                            chosenId = id;
                            responseMs = sw.elapsedMilliseconds;
                            Navigator.of(ctx).pop();
                          }
                        : null,
                    child: Align(alignment: Alignment.centerLeft, child: Text(text)),
                  ),
                );
              },
            );
          }).toList();

          return AlertDialog(
            title: Row(
              children: [
                const Expanded(child: Text('Question')),
                TextButton(
                  onPressed: () {
                    // user wants to quit the whole test
                    _testAbort = true;
                    Navigator.of(ctx).pop();
                  },
                  child: Text(
                    _localizedQuitLabel(),
                    style: const TextStyle(color: Colors.blue, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Text(defText.isEmpty ? '...' : defText, textAlign: TextAlign.left),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.volume_up),
                                onPressed: defText.trim().isEmpty
                                    ? null
                                    : () async {
                                        await _applySpeed();
                                        await _tts.speak(defText, LanguageLoader.langCode(widget.targetLang));
                                      },
                              ),
                              if (!buttonsEnabled) const Text('Listening...'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...optionButtons,
                ],
              ),
            ),
          );
        });
      },
    );

    final answered = chosenId != -1;
    final correct = chosenId == wordId;

    // Map to grade and record via SrsService (immediate)
    final grade = _mapResponseToGrade(correct, responseMs);
    try {
      await SrsService().grade(
        nativeLang: widget.nativeLang,
        targetLang: widget.targetLang,
        wordId: wordId,
        grade: grade,
      );
    } catch (_) {
      // ignore grading errors
    }

    return _QuestionOutcome(
      wordId: wordId,
      answered: answered,
      chosenId: chosenId,
      correct: correct,
      responseMs: responseMs,
      graded: grade,
    );
  }

  // Start a test for the current course. Count = number of questions (default = course length or 10)
  Future<void> _startCourseDefinitionTest({int? count}) async {
    if (_testRunning) return;
    // stop other sessions
    await _stopAuto();
    await _session.stop();

    setState(() {
      _testRunning = true;
      _testSessionResults.clear();
      _testAbort = false;
    });

    // decide number of questions
    final desired = count ?? min(10, max(1, widget.courseIds.length));
    final ids = await _prepareCourseQuestionIds(count: desired);

    int correctCount = 0;
    for (final id in ids) {
      if (!mounted) break;
      if (_testAbort) break;
      final outcome = await _askDefinitionQuestion(id);
      _testSessionResults.add(_TestResult(
        wordId: id,
        chosenId: outcome.chosenId,
        correct: outcome.correct,
        responseMs: outcome.responseMs,
        grade: outcome.graded,
      ));
      if (outcome.correct) correctCount++;
      // small delay for UX
      await Future.delayed(const Duration(milliseconds: 400));
      if (_testAbort) break;
    }

    if (!mounted) return;
    setState(() => _testRunning = false);

    final total = _testSessionResults.length;
    final percent = total == 0 ? 0 : ((correctCount / total) * 100).round();

    // Save mastery if >= 80%
    if (percent >= 80) {
      await _markCourseMastered();
    }

    // Persist last test summary so it doesn't disappear
    _lastTestTotal = total;
    _lastTestCorrect = correctCount;
    _lastTestPercent = percent;
    _lastWrongResults = _testSessionResults.where((r) => !r.correct).toList();

    // Show summary dialog with colored result & wrong items list
    _showTestSummary(correctCount: correctCount, total: total, percent: percent);
  }

  Color _resultColorForPercent(int percent) {
    if (percent >= 80) return Colors.green;
    if (percent >= 60) return Colors.orange;
    return Colors.red;
  }

  Future<void> _showTestSummary({required int correctCount, required int total, required int percent}) async {
    // Build wrong items list (those with correct == false)
    final wrongResults = _testSessionResults.where((r) => !r.correct).toList();

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final color = _resultColorForPercent(percent);
        return AlertDialog(
          title: Row(
            children: [
              Expanded(child: Text('Test Summary')),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                child: Text('$percent%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              children: [
                Text('Score: $correctCount / $total'),
                const SizedBox(height: 8),
                if (wrongResults.isEmpty)
                  const Text('Great! No mistakes.')
                else ...[
                  const SizedBox(height: 8),
                  Text('Wrong items (tap to review):', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: wrongResults.map((r) {
                      return FutureBuilder<Map<String, dynamic>?>(
                        future: _loadL2Title(r.wordId),
                        builder: (c, snap) {
                          final txt = (snap.data?['word'] ?? r.wordId.toString()).toString();
                          return ActionChip(
                            backgroundColor: Colors.red[50],
                            label: Text(txt, style: const TextStyle(color: Colors.red)),
                            onPressed: () {
                              // open mistake detail directly (dialog)
                              Navigator.of(ctx).pop();
                              _showMistakeDetail(r);
                            },
                          );
                        },
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (wrongResults.isNotEmpty)
              TextButton(
                onPressed: () {
                  // do NOT clear stored last results — open review page while keeping the summary saved
                  Navigator.of(ctx).pop();
                  // open review page for persistent review
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReviewMistakesPage(
                    wrongResults: _lastWrongResults,
                    targetLang: widget.targetLang,
                    nativeLang: widget.nativeLang,
                    session: _session,
                    settings: widget.settings,
                    onReturn: () {
                      // no changes to last results; user can re-open summary
                    },
                  )));
                },
                child: const Text('Review wrong items'),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // When user taps a wrong item in the summary, show a learning dialog:
  // show the wrong chosen word (red) and the correct word + definition to learn from error
  Future<void> _showMistakeDetail(_TestResult r) async {
    final correctId = r.wordId;
    final chosenId = r.chosenId;
    final correctL2 = await LanguageLoader.loadWordById(widget.targetLang, correctId);
    final correctL1 = _sameLang ? correctL2 : await LanguageLoader.loadWordById(widget.nativeLang, correctId);

    final chosenL2 = await LanguageLoader.loadWordById(widget.targetLang, chosenId);
    final chosenL1 = _sameLang ? chosenL2 : await LanguageLoader.loadWordById(widget.nativeLang, chosenId);

    String correctDef = '';
    final defs2 = (correctL2?['definitions'] is List) ? (correctL2!['definitions'] as List) : const [];
    if (defs2.isNotEmpty) {
      final f = defs2.first;
      if (f is String) correctDef = f;
      else if (f is Map && f.containsKey('text')) correctDef = (f['text'] ?? '').toString();
      else correctDef = f.toString();
    } else {
      final defs1 = (correctL1?['definitions'] is List) ? (correctL1!['definitions'] as List) : const [];
      if (defs1.isNotEmpty) {
        final f = defs1.first;
        if (f is String) correctDef = f;
        else if (f is Map && f.containsKey('text')) correctDef = (f['text'] ?? '').toString();
        else correctDef = f.toString();
      }
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Review Mistake'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (chosenL2 != null)
                  Row(
                    children: [
                      const Text('You chose: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(6)),
                        child: Text((chosenL2['word'] ?? '').toString(), style: const TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Correct: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(6)),
                      child: Text((correctL2?['word'] ?? '').toString(), style: const TextStyle(color: Colors.green)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (correctDef.isNotEmpty) ...[
                  const Text('Definition:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(correctDef),
                ],
                if (!_sameLang && correctL1 != null) ...[
                  const SizedBox(height: 8),
                  const Text('Translation:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text((correctL1['word'] ?? '').toString()),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                // Optionally, start TTS for correct definition to reinforce learning
                if (correctDef.trim().isNotEmpty) {
                  await _applySpeed();
                  await _tts.speak(correctDef, LanguageLoader.langCode(widget.targetLang));
                }
              },
              child: const Text('Hear definition'),
            ),
          ],
        );
      },
    );
  }

  // ---------- Speed / Demo end ----------

  @override
  Widget build(BuildContext context) {
    final title = 'Course ${widget.courseIndex + 1} • ${widget.levelTitle}';
    final progressText = '${_index + 1}/${widget.courseIds.length}';

    final w2 = _word(_l2);
    final w1 = _word(_l1);

    final def2 = _firstDef(_l2);
    final def1 = _firstDef(_l1);

    int count = widget.settings.maxSentencesToPlay;
    if (count < 1) count = 1;
    if (count > 5) count = 5;

    final s2 = _sentences(_l2, count);
    final s1 = _sameLang ? const <String>[] : _sentences(_l1, count);

    final syn2 = _list(_l2, 'synonyms');
    final ant2 = _list(_l2, 'antonyms');

    final synMap1 = _sameLang ? <int, String>{} : _idTextMap(_l1, 'synonyms');
    final antMap1 = _sameLang ? <int, String>{} : _idTextMap(_l1, 'antonyms');

    final lc2 = LanguageLoader.langCode(widget.targetLang);
    final lc1 = LanguageLoader.langCode(widget.nativeLang);

    final pad = widget.settings.tilePadding().toDouble();
    final gap = widget.settings.gridSpacing().toDouble();

    final progressValue = widget.courseIds.isEmpty ? 0.0 : (_index + 1) / widget.courseIds.length;

    return LayoutBuilder(
      builder: (context, c) {
        final isWide = c.maxWidth >= 900; // split view for wide screens
        final sidebarW = min(280.0, max(200.0, c.maxWidth * 0.26));

        final topControls = Row(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.chevron_left),
              label: const Text('Prev'),
              onPressed: _index <= 0 ? null : _goPrev,
            ),
            SizedBox(width: gap),
            if (!isWide)
              OutlinedButton.icon(
                icon: const Icon(Icons.list),
                label: const Text('Words'),
                onPressed: isWide ? null : _openWordsSheet,
              ),
            SizedBox(width: gap),
            _speedWidget(),
            SizedBox(width: gap),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: Text(_autoRunning ? 'Auto Running...' : 'Auto From Here • $progressText'),
                onPressed: _autoRunning ? null : _startAutoFromHere,
              ),
            ),
            SizedBox(width: gap),
            OutlinedButton.icon(
              icon: const Icon(Icons.chevron_right),
              label: const Text('Next'),
              onPressed: _index >= widget.courseIds.length - 1 ? null : _goNext,
            ),
          ],
        );

        final content = ListView(
          children: [
            // Progress
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progressValue,
                      minHeight: 8,
                      backgroundColor: Colors.grey.withOpacity(0.2),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(progressText, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: gap),

            topControls,
            SizedBox(height: gap),

            // Options card
            Card(
              child: Padding(
                padding: EdgeInsets.all(pad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Options', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Spell after word (Auto)'),
                      value: widget.settings.speakSpelling,
                      onChanged: (v) => widget.settings.update(() => widget.settings.speakSpelling = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Auto include Synonyms'),
                      value: widget.settings.autoSpeakSynonyms,
                      onChanged: (v) => widget.settings.update(() => widget.settings.autoSpeakSynonyms = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Auto include Antonyms'),
                      value: widget.settings.autoSpeakAntonyms,
                      onChanged: (v) => widget.settings.update(() => widget.settings.autoSpeakAntonyms = v),
                    ),
                    Text(
                      'Manual chips work even if Auto options are off.',
                      style: TextStyle(color: Colors.grey[700], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: gap),

            // Word card
            Card(
              child: Padding(
                padding: EdgeInsets.all(pad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            w2.isEmpty ? '...' : w2,
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Speak word (L2)',
                          icon: const Icon(Icons.volume_up),
                          onPressed: _autoRunning ? null : () async => _speakSingle(w2, lc2),
                        ),
                        IconButton(
                          tooltip: 'Spell (L2)',
                          icon: const Icon(Icons.spellcheck),
                          onPressed: _autoRunning ? null : () async => _speakSpellingOnly(w2, lc2),
                        ),
                        // Favorite button for current word
                        IconButton(
                          tooltip: _favorites.contains(_currentId) ? 'Remove from Favorites' : 'Add to Favorites',
                          icon: Icon(
                            _favorites.contains(_currentId) ? Icons.star : Icons.star_outline,
                            color: _favorites.contains(_currentId) ? Colors.amber[700] : null,
                          ),
                          onPressed: _favoritesLoaded ? () => _toggleFavorite(_currentId) : null,
                        ),
                      ],
                    ),
                    if (!_sameLang && w1.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              w1,
                              style: TextStyle(fontSize: 18, color: Colors.grey[800]),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Speak translation (L1)',
                            icon: const Icon(Icons.volume_up),
                            onPressed: _autoRunning ? null : () async => _speakSingle(w1, lc1),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    // Course Test button (placed inside word card for visibility)
                    Row(
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.playlist_add_check),
                          label: Text(_courseMastered ? 'Course Mastered ✓' : 'اختبار الكورس'),
                          style: _courseMastered
                              ? ElevatedButton.styleFrom(backgroundColor: Colors.green[600])
                              : null,
                          onPressed: _courseMastered || _testRunning
                              ? null
                              : () {
                                  // default: number of questions = course length but max 10
                                  final desired = min(10, max(1, widget.courseIds.length));
                                  _openCourseTestConfirm(count: desired);
                                },
                        ),
                        const SizedBox(width: 12),
                        if (_courseMastered)
                          Text('متقن', style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold)),
                        const Spacer(),
                        // Show last results button (if a last test exists)
                        if (_lastTestTotal > 0)
                          TextButton.icon(
                            onPressed: () {
                              // reopen the last results dialog
                              _showTestSummary(correctCount: _lastTestCorrect, total: _lastTestTotal, percent: _lastTestPercent);
                            },
                            icon: const Icon(Icons.history),
                            label: const Text('Show Last Results'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: gap),

            // Definition
            if (def2.trim().isNotEmpty || (!_sameLang && def1.trim().isNotEmpty))
              Card(
                child: Padding(
                  padding: EdgeInsets.all(pad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Definition', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (def2.trim().isNotEmpty)
                        Row(
                          children: [
                            Expanded(child: Text(def2)),
                            IconButton(
                              tooltip: 'Speak definition (L2)',
                              icon: const Icon(Icons.volume_up),
                              onPressed: _autoRunning ? null : () async => _speakSingle(def2, lc2),
                            ),
                          ],
                        ),
                      if (!_sameLang && def1.trim().isNotEmpty) ...[
                        const Divider(),
                        Row(
                          children: [
                            Expanded(child: Text(def1)),
                            IconButton(
                              tooltip: 'Speak definition (L1)',
                              icon: const Icon(Icons.volume_up),
                              onPressed: _autoRunning ? null : () async => _speakSingle(def1, lc1),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            SizedBox(height: gap),

            // Sentences
            if (s2.isNotEmpty)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(pad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sentences', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      for (int i = 0; i < s2.length; i++)
                        SentenceItem(
                          s2: s2[i],
                          s1: (!_sameLang && i < s1.length) ? s1[i] : '',
                          sameLang: _sameLang,
                          onSpeakL2: _autoRunning ? null : () async => _speakSingle(s2[i], lc2),
                          onSpeakL1: (_autoRunning || _sameLang || i >= s1.length)
                              ? null
                              : () async => _speakSingle(s1[i], lc1),
                        ),
                    ],
                  ),
                ),
              ),

            SizedBox(height: gap),

            // Synonyms / Antonyms
            BilingualPairsWrap(
              title: 'Synonyms (Manual)',
              l2Items: syn2,
              l1MapById: synMap1,
              sameLang: _sameLang,
              onSpeakSingle: (text, isL2) async {
                if (_autoRunning) return;
                await _speakSingle(text, isL2 ? lc2 : lc1);
              },
            ),

            SizedBox(height: gap),

            BilingualPairsWrap(
              title: 'Antonyms (Manual)',
              l2Items: ant2,
              l1MapById: antMap1,
              sameLang: _sameLang,
              onSpeakSingle: (text, isL2) async {
                if (_autoRunning) return;
                await _speakSingle(text, isL2 ? lc2 : lc1);
              },
            ),

            const SizedBox(height: 30),
          ],
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: [
              if (!_autoRunning)
                IconButton(
                  tooltip: 'Words',
                  icon: const Icon(Icons.list),
                  onPressed: isWide ? null : _openWordsSheet,
                ),
              if (_autoRunning)
                IconButton(
                  tooltip: 'Stop Auto',
                  icon: const Icon(Icons.stop_circle),
                  onPressed: _stopAuto,
                ),
            ],
          ),
          body: Row(
            children: [
              if (isWide) _leftSidebar(sidebarW),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(pad),
                  child: content,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ========= Test UI helpers =========

  void _openCourseTestConfirm({required int count}) {
    if (_autoRunning || _testRunning) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('بدء اختبار الكورس', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('عدد الأسئلة: $count'),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _startCourseDefinitionTest(count: count);
                  },
                  child: const Text('ابدأ الاختبار'),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// =====================
// Helper classes
// =====================

class _TestResult {
  final int wordId; // correct target id
  final int chosenId; // chosen option id (may be -1 if skipped/quit)
  final bool correct;
  final int responseMs;
  final SrsGrade grade;
  _TestResult({
    required this.wordId,
    required this.chosenId,
    required this.correct,
    required this.responseMs,
    required this.grade,
  });
}

class _QuestionOutcome {
  final int wordId;
  final bool answered;
  final int chosenId;
  final bool correct;
  final int responseMs;
  final SrsGrade graded;
  _QuestionOutcome({
    required this.wordId,
    required this.answered,
    required this.chosenId,
    required this.correct,
    required this.responseMs,
    required this.graded,
  });
}

// Review page: persistent list of wrong items and review actions
class ReviewMistakesPage extends StatelessWidget {
  final List<_TestResult> wrongResults;
  final String targetLang;
  final String nativeLang;
  final PlaybackSessionService session;
  final SettingsController settings;
  final VoidCallback? onReturn;

  const ReviewMistakesPage({
    super.key,
    required this.wrongResults,
    required this.targetLang,
    required this.nativeLang,
    required this.session,
    required this.settings,
    this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    final wrongIds = wrongResults.map((r) => r.wordId).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Mistakes'),
        actions: [
          IconButton(
            tooltip: 'Play all',
            icon: const Icon(Icons.play_circle_fill),
            onPressed: wrongIds.isEmpty
                ? null
                : () {
                    // start session for wrong ids (fire-and-forget)
                    unawaited(session.startSessionForIds(
                      ids: wrongIds,
                      targetLang: targetLang,
                      nativeLang: nativeLang,
                      loop: false,
                      minutes: 0,
                      includeSynonyms: settings.autoSpeakSynonyms,
                      includeAntonyms: settings.autoSpeakAntonyms,
                    ));
                  },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: wrongResults.length,
        itemBuilder: (context, idx) {
          final r = wrongResults[idx];
          return FutureBuilder<Map<String, dynamic>?>(
            future: LanguageLoader.loadWordById(targetLang, r.wordId),
            builder: (c, snap) {
              final title = (snap.data?['word'] ?? r.wordId.toString()).toString();
              return ListTile(
                leading: CircleAvatar(child: Text('${idx + 1}')),
                title: Text(title),
                subtitle: Text(r.correct ? 'Correct' : 'Wrong'),
                trailing: IconButton(
                  icon: const Icon(Icons.visibility),
                  onPressed: () {
                    // open small detail dialog
                    showDialog<void>(
                      context: context,
                      builder: (ctx) {
                        return AlertDialog(
                          title: Text(title),
                          content: FutureBuilder<Map<String, dynamic>?>(
                            future: LanguageLoader.loadWordById(nativeLang, r.wordId),
                            builder: (c2, snap2) {
                              final def = (snap.data?['definitions'] is List && (snap.data!['definitions'] as List).isNotEmpty)
                                  ? (((snap.data!['definitions'] as List).first is Map) ? ((snap.data!['definitions'] as List).first['text'] ?? '') : ((snap.data!['definitions'] as List).first.toString()))
                                  : '';
                              final trans = (snap2.data?['word'] ?? '').toString();
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (def.isNotEmpty) Text('Definition: $def'),
                                  if (trans.isNotEmpty) Text('Translation: $trans'),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.volume_up),
                                        label: const Text('Hear'),
                                        onPressed: def.trim().isEmpty
                                            ? null
                                            : () async {
                                                await session.tts.configure(
                                                  speechRate: settings.speechRateValue,
                                                  pitch: settings.pitch,
                                                  volume: settings.volume,
                                                );
                                                await session.tts.speak(def, LanguageLoader.langCode(targetLang));
                                              },
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton(
                                        onPressed: () => Navigator.of(ctx).pop(),
                                        child: const Text('Close'),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Small utility to allow using unawaited where used
void unawaited(Future<void> f) {}