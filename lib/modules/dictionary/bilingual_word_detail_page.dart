import 'package:flutter/material.dart';
import '../../services/tts_service.dart';
import '../../services/settings_controller.dart';

class BilingualWordDetailPage extends StatefulWidget {
  final Map<String, dynamic>? wordL2;
  final Map<String, dynamic>? wordL1;
  final String langL2; // en/ar/es
  final String langL1;
  final SettingsController settings;

  const BilingualWordDetailPage({
    super.key,
    required this.wordL2,
    required this.wordL1,
    required this.langL2,
    required this.langL1,
    required this.settings,
  });

  @override
  State<BilingualWordDetailPage> createState() => _BilingualWordDetailPageState();
}

class _BilingualWordDetailPageState extends State<BilingualWordDetailPage> {
  final TtsService tts = TtsService();
  bool playing = false;

  // ---------- Extractors ----------
  String _word(Map<String, dynamic>? w) => (w?['word'] ?? '').toString();

  List<Map<String, dynamic>> _defs(Map<String, dynamic>? w) {
    final d = w?['definitions'];
    if (d is List) return d.cast<Map<String, dynamic>>();
    return const [];
  }

  List<Map<String, dynamic>> _sents(Map<String, dynamic>? w) {
    final s = w?['sentences'];
    if (s is List) return s.cast<Map<String, dynamic>>();
    return const [];
  }

  List<Map<String, dynamic>> _syns(Map<String, dynamic>? w) {
    final s = w?['synonyms'];
    if (s is List) return s.cast<Map<String, dynamic>>();
    return const [];
  }

  List<Map<String, dynamic>> _ants(Map<String, dynamic>? w) {
    final s = w?['antonyms'];
    if (s is List) return s.cast<Map<String, dynamic>>();
    return const [];
  }

  // ---------- ID matching helpers ----------
  Map<int, Map<String, dynamic>> _indexById(List<Map<String, dynamic>> list, String idKey) {
    final m = <int, Map<String, dynamic>>{};
    for (final x in list) {
      final id = x[idKey];
      if (id is int) m[id] = x;
    }
    return m;
  }

  // definitions: definition_id
  List<_PairItem> _pairedDefinitions() {
    final l2 = _defs(widget.wordL2);
    final l1 = _defs(widget.wordL1);

    final l1Index = _indexById(l1, 'definition_id');
    final out = <_PairItem>[];

    for (final d2 in l2) {
      final id = d2['definition_id'];
      if (id is! int) continue;
      final t2 = (d2['text'] ?? '').toString();
      final t1 = (l1Index[id]?['text'] ?? '').toString();
      out.add(_PairItem(id: id, textL2: t2, textL1: t1));
    }
    return out;
  }

  // sentences: sentence_id
  List<_PairItem> _pairedSentences() {
    final l2 = _sents(widget.wordL2);
    final l1 = _sents(widget.wordL1);

    final l1Index = _indexById(l1, 'sentence_id');
    final out = <_PairItem>[];

    for (final s2 in l2) {
      final id = s2['sentence_id'];
      if (id is! int) continue;
      final t2 = (s2['text'] ?? '').toString();
      final t1 = (l1Index[id]?['text'] ?? '').toString();
      out.add(_PairItem(id: id, textL2: t2, textL1: t1));
    }
    return out;
  }

  // synonyms/antonyms: id
  List<_PairItem> _pairedListById(List<Map<String, dynamic>> l2, List<Map<String, dynamic>> l1) {
    final l1Index = _indexById(l1, 'id');
    final out = <_PairItem>[];

    for (final x2 in l2) {
      final id = x2['id'];
      if (id is! int) continue;
      final t2 = (x2['text'] ?? '').toString();
      final t1 = (l1Index[id]?['text'] ?? '').toString();
      out.add(_PairItem(id: id, textL2: t2, textL1: t1));
    }
    return out;
  }

  // ---------- Speed quick toggle ----------
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

  SpeechSpeed _nextSpeed(SpeechSpeed s) {
    final list = SpeechSpeed.values;
    final nextIndex = (s.index + 1) % list.length;
    return list[nextIndex];
  }

  Future<void> _toggleSpeedQuick() async {
    final current = widget.settings.speechSpeed;
    final next = _nextSpeed(current);

    await widget.settings.update(() => widget.settings.speechSpeed = next);
    await tts.stop();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_speedLabel(next)),
        duration: const Duration(milliseconds: 700),
      ),
    );
  }

  // ---------- Speech helpers ----------
  Future<void> _prepTtsFromSettings() async {
    final s = widget.settings;
    await tts.configure(
      speechRate: s.speechRateValue,
      pitch: s.pitch,
      volume: s.volume,
    );
  }

  Future<void> _speakL2(String text) async {
    await _prepTtsFromSettings();
    await tts.speak(text, widget.langL2);
  }

  Future<void> _speakL1(String text) async {
    await _prepTtsFromSettings();
    await tts.speak(text, widget.langL1);
  }

  // ---------- Spelling only (ONE utterance, ✅ NORMAL/global speed) ----------
  List<String> _spellLetters(String word) {
    final chars = word.trim().split('');
    final out = <String>[];
    for (final c in chars) {
      if (RegExp(r'[A-Za-z0-9]').hasMatch(c)) out.add(c);
    }
    return out;
  }

  Future<void> _spellOnlyL2(String word) async {
    final w = word.trim();
    if (w.isEmpty) return;

    final letters = _spellLetters(w);
    if (letters.isEmpty) return;

    final spellingText = letters.join(' '); // ✅ utterance واحد

    // (اختياري) يمنع تداخل أصوات
    await tts.stop();

    // ✅ نفس سرعة النظام (لا Fast +2)
    await tts.configure(
      speechRate: widget.settings.speechRateValue,
      pitch: widget.settings.pitch,
      volume: widget.settings.volume,
    );

    await tts.speak(spellingText, widget.langL2);
  }

  Future<void> _autoPlay() async {
    final s = widget.settings;
    await _prepTtsFromSettings();

    final items = <TtsItem>[];

    final w2 = _word(widget.wordL2);
    final w1 = _word(widget.wordL1);

    // 1) Word: L2 -> L1 -> L2 (confirm repeats)
    items.add(TtsItem(text: w2, langCode: widget.langL2, pauseMsAfter: s.pauseShortMs));
    items.add(TtsItem(text: w1, langCode: widget.langL1, pauseMsAfter: s.pauseMediumMs));
    for (int i = 0; i < s.confirmL2Repeats; i++) {
      items.add(TtsItem(text: w2, langCode: widget.langL2, pauseMsAfter: s.pauseMediumMs));
    }

    // 2) Definition: first
    final defs = _pairedDefinitions();
    if (defs.isNotEmpty) {
      items.add(TtsItem(text: defs.first.textL2, langCode: widget.langL2, pauseMsAfter: s.pauseShortMs));
      items.add(TtsItem(text: defs.first.textL1, langCode: widget.langL1, pauseMsAfter: s.pauseLongMs));
    }

    // 3) Sentences: up to N
    final sents = _pairedSentences();
    final count = s.maxSentencesToPlay.clamp(1, 5);
    final take = (sents.length < count) ? sents.length : count;

    for (int i = 0; i < take; i++) {
      for (int r = 0; r < s.sentenceRepeat; r++) {
        items.add(TtsItem(text: sents[i].textL2, langCode: widget.langL2, pauseMsAfter: s.pauseShortMs));
        items.add(TtsItem(text: sents[i].textL1, langCode: widget.langL1, pauseMsAfter: s.pauseLongMs));
      }
    }

    // 4) Optional: synonyms/antonyms in autoplay only
    if (s.speakSynonyms) {
      final syn = _pairedListById(_syns(widget.wordL2), _syns(widget.wordL1));
      if (syn.isNotEmpty) {
        items.add(TtsItem(text: 'Synonyms', langCode: widget.langL2, pauseMsAfter: s.pauseShortMs));
        for (final x in syn) {
          items.add(TtsItem(text: x.textL2, langCode: widget.langL2, pauseMsAfter: s.pauseShortMs));
          if (x.textL1.trim().isNotEmpty) {
            items.add(TtsItem(text: x.textL1, langCode: widget.langL1, pauseMsAfter: s.pauseShortMs));
          }
        }
      }
    }

    if (s.speakAntonyms) {
      final ant = _pairedListById(_ants(widget.wordL2), _ants(widget.wordL1));
      if (ant.isNotEmpty) {
        items.add(TtsItem(text: 'Antonyms', langCode: widget.langL2, pauseMsAfter: s.pauseShortMs));
        for (final x in ant) {
          items.add(TtsItem(text: x.textL2, langCode: widget.langL2, pauseMsAfter: s.pauseShortMs));
          if (x.textL1.trim().isNotEmpty) {
            items.add(TtsItem(text: x.textL1, langCode: widget.langL1, pauseMsAfter: s.pauseShortMs));
          }
        }
      }
    }

    setState(() => playing = true);
    await tts.stop();
    await tts.speakSequence(items);
    if (mounted) setState(() => playing = false);
  }

  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }

  // ---------- UI widgets ----------
  Widget _speakButtons({required String textL2, required String textL1}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Speak L2',
          onPressed: textL2.trim().isEmpty ? null : () async => _speakL2(textL2),
          icon: const Icon(Icons.volume_up),
        ),
        IconButton(
          tooltip: 'Spell L2 (normal speed)',
          onPressed: textL2.trim().isEmpty ? null : () async => _spellOnlyL2(textL2),
          icon: const Icon(Icons.spellcheck),
        ),
        IconButton(
          tooltip: 'Speak L1',
          onPressed: textL1.trim().isEmpty ? null : () async => _speakL1(textL1),
          icon: const Icon(Icons.record_voice_over),
        ),
      ],
    );
  }

  Widget _pairCard({
    required String title,
    required String textL2,
    required String textL1,
    bool dense = false,
  }) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(dense ? 10 : 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(textL2),
                const SizedBox(height: 6),
                Text(textL1),
              ]),
            ),
            _speakButtons(textL2: textL2, textL1: textL1),
          ],
        ),
      ),
    );
  }

  Widget _listSection({
    required String title,
    required List<_PairItem> items,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...items.map((x) {
          return Card(
            child: ListTile(
              title: Text(x.textL2),
              subtitle: x.textL1.trim().isEmpty ? null : Text(x.textL1),
              trailing: _speakButtons(textL2: x.textL2, textL1: x.textL1),
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final w2 = _word(widget.wordL2);
    final w1 = _word(widget.wordL1);

    final defs = _pairedDefinitions();
    final firstDef = defs.isNotEmpty ? defs.first : null;

    final sents = _pairedSentences();
    final syn = _pairedListById(_syns(widget.wordL2), _syns(widget.wordL1));
    final ant = _pairedListById(_ants(widget.wordL2), _ants(widget.wordL1));

    final speedText = _speedLabel(widget.settings.speechSpeed);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Word Detail'),
        actions: [
          TextButton.icon(
            onPressed: _toggleSpeedQuick,
            icon: const Icon(Icons.flash_on),
            label: Text(speedText),
          ),
          IconButton(
            tooltip: 'Stop',
            icon: const Icon(Icons.stop_circle),
            onPressed: () async {
              await tts.stop();
              if (mounted) setState(() => playing = false);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('$w2  ⇄  $w1', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(
                        '$speedText • Queue: ON',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: playing ? null : _autoPlay,
                            child: const Text('Auto Play'),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: () async {
                              await tts.stop();
                              if (mounted) setState(() => playing = false);
                            },
                            child: const Text('Stop'),
                          ),
                        ],
                      ),
                    ]),
                  ),
                  _speakButtons(textL2: w2, textL1: w1),
                ],
              ),
            ),
          ),

          if (firstDef != null)
            _pairCard(
              title: 'Definition',
              textL2: firstDef.textL2,
              textL1: firstDef.textL1,
            ),

          const SizedBox(height: 8),
          const Text('Sentences', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          ...sents.map((x) => _pairCard(
                title: 'Sentence',
                textL2: x.textL2,
                textL1: x.textL1,
                dense: true,
              )),

          _listSection(title: 'Synonyms', items: syn),
          _listSection(title: 'Antonyms', items: ant),

          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

class _PairItem {
  final int id;
  final String textL2;
  final String textL1;

  _PairItem({
    required this.id,
    required this.textL2,
    required this.textL1,
  });
}
