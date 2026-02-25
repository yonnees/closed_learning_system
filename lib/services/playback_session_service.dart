import 'dart:async';
import '../data/language_loader.dart';
import 'tts_service.dart';
import 'settings_controller.dart';

// ADDED: need SrsGrade type for grading mapping
import 'srs_service.dart';

class PlaybackSessionService {
  final TtsService tts;
  final SettingsController settings;

  PlaybackSessionService({required this.tts, required this.settings});

  int _token = 0;
  Timer? _timer;
  bool _running = false;

  bool get isRunning => _running;

  // ===== NEW: rating plumbing for review mode =====
  Completer<int>? _ratingCompleter;

  /// Submit rating from UI (0..5). Completes the pending rating wait.
  /// If no rating is awaited, this call is ignored.
  void submitRatingInt(int score) {
    if (_ratingCompleter == null) return;
    if (_ratingCompleter!.isCompleted) return;
    // clamp between 0..5
    final s = score.clamp(0, 5);
    _ratingCompleter!.complete(s);
  }

  bool get isAwaitingRating => _ratingCompleter != null && !_ratingCompleter!.isCompleted;

  Future<int> _waitForRating() async {
    // create if missing
    _ratingCompleter ??= Completer<int>();
    try {
      final res = await _ratingCompleter!.future;
      return res;
    } finally {
      // reset for next use
      _ratingCompleter = null;
    }
  }

  SrsGrade _mapIntToSrsGrade(int q) {
    if (q <= 1) return SrsGrade.again;
    if (q == 2) return SrsGrade.hard;
    if (q == 3) return SrsGrade.good;
    // 4 or 5
    return SrsGrade.easy;
  }
  // ===== end rating plumbing =====

  Future<void> stop() async {
    _token++;
    _timer?.cancel();
    _timer = null;
    _running = false;
    // If waiting for rating, complete it as "again" (0) to avoid dangling futures.
    if (_ratingCompleter != null && !_ratingCompleter!.isCompleted) {
      try {
        _ratingCompleter!.complete(0);
      } catch (_) {}
    }
    await tts.stop();
  }

  /// تشغيل عام لكل الكلمات في لغة الهدف (يستخدم سابقاً)
  Future<void> startSession({
    required String targetLang,
    required String nativeLang,
    required int minutes,
    required bool loop,
    bool includeSynonyms = false,
    bool includeAntonyms = false,
  }) async {
    await stop();
    final myToken = ++_token;
    _running = true;

    if (minutes > 0) {
      _timer = Timer(Duration(minutes: minutes), () {
        stop();
      });
    }

    await tts.configure(
      speechRate: settings.speechRateValue,
      pitch: settings.pitch,
      volume: settings.volume,
    );

    final l2Words = await LanguageLoader.loadWords(targetLang);
    if (myToken != _token) return;

    int startIndex = 0;
    final lastId = await settings.getLastPlayedWordId(
      nativeLang: nativeLang,
      targetLang: targetLang,
    );
    if (lastId != null) {
      final idx = l2Words.indexWhere((w) => w['id'] == lastId);
      if (idx >= 0) startIndex = idx;
    }

    int i = startIndex;

    while (myToken == _token) {
      if (i >= l2Words.length) {
        if (!loop) break;
        i = 0;
      }

      final id = l2Words[i]['id'];
      if (id is! int) {
        i++;
        continue;
      }

      final l2 = await LanguageLoader.loadWordById(targetLang, id);
      final l1 = await LanguageLoader.loadWordById(nativeLang, id);
      if (myToken != _token) return;

      if (l2 == null || l1 == null) {
        i++;
        continue;
      }

      final items = buildWordSequence(
        wordL2: l2,
        wordL1: l1,
        langCodeL2: LanguageLoader.langCode(targetLang),
        langCodeL1: LanguageLoader.langCode(nativeLang),
        settings: settings,
        includeSynonyms: includeSynonyms,
        includeAntonyms: includeAntonyms,
      );

      await tts.speakSequence(items);
      if (myToken != _token) return;

      await settings.saveLastPlayedWordId(
        nativeLang: nativeLang,
        targetLang: targetLang,
        wordId: id,
      );
      i++;
    }

    if (myToken == _token) {
      await stop();
    }
  }

  /// ✅ تشغيل قائمة IDs محددة (Learn Courses / Review / Favorites)
  Future<void> startSessionForIds({
    required List<int> ids,
    required String targetLang,
    required String nativeLang,
    int minutes = 0,
    bool loop = false,
    int startFromIndex = 0,
    Future<void> Function(int currentIndex, int wordId)? onProgress,
    Future<void> Function(int currentIndex, int wordId)? onWordStart,
    bool includeSynonyms = false,
    bool includeAntonyms = false,
  }) async {
    await stop();
    final myToken = ++_token;
    _running = true;

    if (minutes > 0) {
      _timer = Timer(Duration(minutes: minutes), () {
        stop();
      });
    }

    await tts.configure(
      speechRate: settings.speechRateValue,
      pitch: settings.pitch,
      volume: settings.volume,
    );

    if (ids.isEmpty) {
      await stop();
      return;
    }

    int i = startFromIndex;
    if (i < 0) i = 0;
    if (i >= ids.length) i = ids.length - 1;

    while (myToken == _token) {
      if (i >= ids.length) {
        if (!loop) break;
        i = 0;
      }

      final id = ids[i];

      if (onWordStart != null) {
        await onWordStart(i, id);
      }

      final l2 = await LanguageLoader.loadWordById(targetLang, id);
      final l1 = await LanguageLoader.loadWordById(nativeLang, id);
      if (myToken != _token) return;

      if (l2 == null || l1 == null) {
        i++;
        continue;
      }

      final items = buildWordSequence(
        wordL2: l2,
        wordL1: l1,
        langCodeL2: LanguageLoader.langCode(targetLang),
        langCodeL1: LanguageLoader.langCode(nativeLang),
        settings: settings,
        includeSynonyms: includeSynonyms,
        includeAntonyms: includeAntonyms,
      );

      await tts.speakSequence(items);
      if (myToken != _token) return;

      if (onProgress != null) {
        await onProgress(i, id);
      }

      await settings.saveLastPlayedWordId(
        nativeLang: nativeLang,
        targetLang: targetLang,
        wordId: id,
      );
      i++;
    }

    if (myToken == _token) {
      await stop();
    }
  }

  /// ====== NEW: Review Mode (uses SRS queue + waits for user rating) ======
  ///
  /// How it works:
  ///  - fetch due ids via settings.srsGetDueQueue(nativeLang, targetLang, limit)
  ///  - for each id: play sequence, then wait for UI rating (submitRatingInt)
  ///  - map rating -> SrsGrade and call settings.srsGrade(...)
  ///
  /// UI Integration: after each word is spoken, show rating UI and call:
  ///    playbackSession.submitRatingInt(userScore); // userScore in 0..5
  Future<void> startReviewSession({
    required String nativeLang,
    required String targetLang,
    int limit = 200,
    bool loop = false,
    bool includeSynonyms = false,
    bool includeAntonyms = false,
    int minutes = 0,
  }) async {
    await stop();
    final myToken = ++_token;
    _running = true;

    if (minutes > 0) {
      _timer = Timer(Duration(minutes: minutes), () {
        stop();
      });
    }

    await tts.configure(
      speechRate: settings.speechRateValue,
      pitch: settings.pitch,
      volume: settings.volume,
    );

    // fetch due items (ids)
    final ids = await settings.srsGetDueQueue(
      nativeLang: nativeLang,
      targetLang: targetLang,
      limit: limit,
    );

    if (myToken != _token) return;
    if (ids.isEmpty) {
      // nothing to review
      await stop();
      return;
    }

    int i = 0;
    while (myToken == _token) {
      if (i >= ids.length) {
        if (!loop) break;
        i = 0;
      }

      final id = ids[i];

      // load words
      final l2 = await LanguageLoader.loadWordById(targetLang, id);
      final l1 = await LanguageLoader.loadWordById(nativeLang, id);
      if (myToken != _token) return;

      if (l2 == null || l1 == null) {
        i++;
        continue;
      }

      // play the sequence
      final items = buildWordSequence(
        wordL2: l2,
        wordL1: l1,
        langCodeL2: LanguageLoader.langCode(targetLang),
        langCodeL1: LanguageLoader.langCode(nativeLang),
        settings: settings,
        includeSynonyms: includeSynonyms,
        includeAntonyms: includeAntonyms,
      );

      await tts.speakSequence(items);
      if (myToken != _token) return;

      // WAIT for user rating via submitRatingInt(...)
      final userScore = await _waitForRating();
      if (myToken != _token) return;

      final grade = _mapIntToSrsGrade(userScore);
      // apply grade (this updates daily stats inside SrsService)
      await settings.srsGrade(
        nativeLang: nativeLang,
        targetLang: targetLang,
        wordId: id,
        grade: grade,
      );

      await settings.saveLastPlayedWordId(
        nativeLang: nativeLang,
        targetLang: targetLang,
        wordId: id,
      );

      i++;
    }

    if (myToken == _token) {
      await stop();
    }
  }
  // ====== end Review Mode ======
}

/// ====== Spelling helper (English/Numbers) ======
List<String> _spellLetters(String word) {
  final chars = word.trim().split('');
  final out = <String>[];

  for (final c in chars) {
    if (RegExp(r'[A-Za-z0-9]').hasMatch(c)) out.add(c);
  }
  return out;
}

/// ✅ NEW: Build spelling as ONE text (fast in Auto, natural everywhere)
String _spellAsOneText(String word, {String joiner = ' . '}) {
  final letters = _spellLetters(word);
  return letters.join(joiner);
}

/// ====== Sequence builder ======
/// Word(L2) -> (Spelling optional) -> Translation(L1) -> Confirm(L2) -> Definitions -> Sentences -> (Syn/Ant optional)
List<TtsItem> buildWordSequence({
  required Map<String, dynamic> wordL2,
  required Map<String, dynamic> wordL1,
  required String langCodeL2,
  required String langCodeL1,
  required SettingsController settings,
  required bool includeSynonyms,
  required bool includeAntonyms,
}) {
  final items = <TtsItem>[];

  final w2 = (wordL2['word'] ?? '').toString();
  final w1 = (wordL1['word'] ?? '').toString();

  // ✅ Word first (L2)
  items.add(TtsItem(text: w2, langCode: langCodeL2, pauseMsAfter: settings.pauseShortMs));

  // ✅ Spelling optional AFTER word (FIXED: ONE item instead of letter-by-letter)
  if (settings.speakSpelling) {
    final spellText = _spellAsOneText(w2, joiner: ' . ');
    if (spellText.trim().isNotEmpty) {
      items.add(TtsItem(
        text: spellText,
        langCode: langCodeL2,
        pauseMsAfter: settings.pauseMediumMs,
      ));
    }
  }

  // Translation (L1)
  items.add(TtsItem(text: w1, langCode: langCodeL1, pauseMsAfter: settings.pauseMediumMs));

  // Confirm L2 repeats
  for (int i = 0; i < settings.confirmL2Repeats; i++) {
    items.add(TtsItem(text: w2, langCode: langCodeL2, pauseMsAfter: settings.pauseMediumMs));
  }

  // Definition (first)
  final defs2 = (wordL2['definitions'] is List) ? (wordL2['definitions'] as List) : const [];
  final defs1 = (wordL1['definitions'] is List) ? (wordL1['definitions'] as List) : const [];
  final def2 = defs2.isNotEmpty ? (defs2.first['text'] ?? '').toString() : '';
  final def1 = defs1.isNotEmpty ? (defs1.first['text'] ?? '').toString() : '';

  if (def2.trim().isNotEmpty) {
    items.add(TtsItem(text: def2, langCode: langCodeL2, pauseMsAfter: settings.pauseShortMs));
  }
  if (def1.trim().isNotEmpty) {
    items.add(TtsItem(text: def1, langCode: langCodeL1, pauseMsAfter: settings.pauseLongMs));
  }

  // Sentences (N)
  final s2 = (wordL2['sentences'] is List) ? (wordL2['sentences'] as List) : const [];
  final s1 = (wordL1['sentences'] is List) ? (wordL1['sentences'] as List) : const [];

  int count = settings.maxSentencesToPlay;
  if (count < 1) count = 1;
  if (count > 5) count = 5;

  final maxPair = s2.length < s1.length ? s2.length : s1.length;
  if (count > maxPair) count = maxPair;

  for (int i = 0; i < count; i++) {
    final t2 = (s2[i]['text'] ?? '').toString();
    final t1 = (s1[i]['text'] ?? '').toString();

    for (int r = 0; r < settings.sentenceRepeat; r++) {
      if (t2.trim().isNotEmpty) {
        items.add(TtsItem(text: t2, langCode: langCodeL2, pauseMsAfter: settings.pauseShortMs));
      }
      if (t1.trim().isNotEmpty) {
        items.add(TtsItem(text: t1, langCode: langCodeL1, pauseMsAfter: settings.pauseLongMs));
      }
    }
  }

  // Synonyms/Antonyms (AUTO only if include flags)
  if (includeSynonyms) {
    final syn2 = (wordL2['synonyms'] is List) ? (wordL2['synonyms'] as List) : const [];
    final syn1 = (wordL1['synonyms'] is List) ? (wordL1['synonyms'] as List) : const [];
    final map1 = <int, String>{};
    for (final x in syn1) {
      final id = x['id'];
      if (id is int) map1[id] = (x['text'] ?? '').toString();
    }
    for (final x in syn2) {
      final id = x['id'];
      final t2 = (x['text'] ?? '').toString();
      final t1 = (id is int) ? (map1[id] ?? '') : '';
      if (t2.trim().isNotEmpty) items.add(TtsItem(text: t2, langCode: langCodeL2, pauseMsAfter: settings.pauseShortMs));
      if (t1.trim().isNotEmpty) items.add(TtsItem(text: t1, langCode: langCodeL1, pauseMsAfter: settings.pauseShortMs));
    }
  }

  if (includeAntonyms) {
    final ant2 = (wordL2['antonyms'] is List) ? (wordL2['antonyms'] as List) : const [];
    final ant1 = (wordL1['antonyms'] is List) ? (wordL1['antonyms'] as List) : const [];
    final map1 = <int, String>{};
    for (final x in ant1) {
      final id = x['id'];
      if (id is int) map1[id] = (x['text'] ?? '').toString();
    }
    for (final x in ant2) {
      final id = x['id'];
      final t2 = (x['text'] ?? '').toString();
      final t1 = (id is int) ? (map1[id] ?? '') : '';
      if (t2.trim().isNotEmpty) items.add(TtsItem(text: t2, langCode: langCodeL2, pauseMsAfter: settings.pauseShortMs));
      if (t1.trim().isNotEmpty) items.add(TtsItem(text: t1, langCode: langCodeL1, pauseMsAfter: settings.pauseShortMs));
    }
  }

  return items;
}