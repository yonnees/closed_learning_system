import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import '../../../data/language_loader.dart';
import '../../../services/settings_controller.dart';
import '../../../services/tts_service.dart';
import 'sentence_item.dart';
import 'bilingual_pairs_wrap.dart';

/// WordDetailPanel
/// Reusable panel to show a single word (L2) with L1, definition, sentences,
/// synonyms/antonyms and Speak/Spell controls.
/// Place this file at: lib/modules/learn/widgets/word_detail_panel.dart
class WordDetailPanel extends StatefulWidget {
  final SettingsController settings;
  final TtsService tts;
  final String targetLang; // L2
  final String nativeLang; // L1
  final int wordId;
  final bool disabled;

  const WordDetailPanel({
    super.key,
    required this.settings,
    required this.tts,
    required this.targetLang,
    required this.nativeLang,
    required this.wordId,
    this.disabled = false,
  });

  @override
  State<WordDetailPanel> createState() => _WordDetailPanelState();
}

class _WordDetailPanelState extends State<WordDetailPanel> {
  Map<String, dynamic>? _l2;
  Map<String, dynamic>? _l1;
  bool _loading = true;
  bool _mounted = true;
  late final String _lc2;
  late final String _lc1;

  @override
  void initState() {
    super.initState();
    _lc2 = LanguageLoader.langCode(widget.targetLang);
    _lc1 = LanguageLoader.langCode(widget.nativeLang);
    _load();
  }

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final l2 = await LanguageLoader.loadWordById(widget.targetLang, widget.wordId);
      final l1 = (widget.targetLang == widget.nativeLang)
          ? l2
          : await LanguageLoader.loadWordById(widget.nativeLang, widget.wordId);

      if (!_mounted) return;
      setState(() {
        _l2 = l2;
        _l1 = l1;
      });
    } catch (_) {
      if (!_mounted) return;
      setState(() {
        _l2 = null;
        _l1 = null;
      });
    } finally {
      if (!_mounted) return;
      setState(() => _loading = false);
    }
  }

  // helpers
  String _word(Map<String, dynamic>? m) => (m?['word'] ?? '').toString();

  String _firstDef(Map<String, dynamic>? m) {
    final defs = (m?['definitions'] is List) ? (m!['definitions'] as List) : const [];
    if (defs.isEmpty) return '';
    return (defs.first['text'] ?? '').toString();
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

  Map<int, String> _mapByIdText(Map<String, dynamic>? m, String key) {
    final out = <int, String>{};
    final list = _list(m, key);
    for (final x in list) {
      final id = x['id'];
      if (id is int) out[id] = (x['text'] ?? '').toString();
    }
    return out;
  }

  Future<void> _applySpeed() async {
    await widget.tts.configure(
      speechRate: widget.settings.speechRateValue,
      pitch: widget.settings.pitch,
      volume: widget.settings.volume,
    );
  }

  Future<void> _speak(String text, String langCode, {int pauseAfterMs = 0}) async {
    final t = text.trim();
    if (t.isEmpty) return;
    if (widget.disabled) return;

    await widget.tts.stop();
    await _applySpeed();

    // Use speakSequence if available
    try {
      await widget.tts.speakSequence([
        TtsItem(text: t, langCode: langCode, pauseMsAfter: pauseAfterMs),
      ]);
    } catch (_) {
      // fallback: single speak call if speakSequence not implemented
      await widget.tts.speak(t, langCode);
    }
  }

  Future<void> _speakSpelling(String word, String langCode) async {
    final w = word.trim();
    if (w.isEmpty) return;
    if (widget.disabled) return;

    final chars = w.split('').where((c) => RegExp(r'[A-Za-z0-9]').hasMatch(c)).toList();
    if (chars.isEmpty) return;

    final spellingText = chars.join(' ');
    await widget.tts.stop();
    await _applySpeed();
    await widget.tts.speak(spellingText, langCode);
  }

  @override
  Widget build(BuildContext context) {
    final pad = widget.settings.tilePadding().toDouble();
    final gap = widget.settings.gridSpacing().toDouble();

    final count = widget.settings.maxSentencesToPlay.clamp(1, 5);

    if (_loading) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(pad),
          child: SizedBox(height: 140, child: Center(child: CircularProgressIndicator())),
        ),
      );
    }

    final w2 = _word(_l2);
    final w1 = _word(_l1);
    final def2 = _firstDef(_l2);
    final def1 = _firstDef(_l1);
    final s2 = _sentences(_l2, count);
    final s1 = (widget.targetLang == widget.nativeLang) ? <String>[] : _sentences(_l1, count);

    final syn2 = _list(_l2, 'synonyms');
    final ant2 = _list(_l2, 'antonyms');

    return Card(
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // word row
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
                  onPressed: widget.disabled ? null : () => _speak(w2, _lc2, pauseAfterMs: widget.settings.pauseShortMs),
                ),
                IconButton(
                  tooltip: 'Spell (L2)',
                  icon: const Icon(Icons.spellcheck),
                  onPressed: widget.disabled ? null : () => _speakSpelling(w2, _lc2),
                ),
              ],
            ),

            if (w1.trim().isNotEmpty && widget.targetLang != widget.nativeLang) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(w1, style: TextStyle(fontSize: 18, color: Colors.grey[800])),
                  ),
                  IconButton(
                    tooltip: 'Speak translation (L1)',
                    icon: const Icon(Icons.volume_up),
                    onPressed: widget.disabled ? null : () => _speak(w1, _lc1, pauseAfterMs: widget.settings.pauseShortMs),
                  ),
                ],
              ),
            ],

            SizedBox(height: gap),

            // Definition
            if (def2.trim().isNotEmpty || (def1.trim().isNotEmpty && widget.targetLang != widget.nativeLang))
              Column(
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
                          onPressed: widget.disabled ? null : () => _speak(def2, _lc2, pauseAfterMs: widget.settings.pauseShortMs),
                        ),
                      ],
                    ),
                  if (def1.trim().isNotEmpty && widget.targetLang != widget.nativeLang) ...[
                    const Divider(),
                    Row(
                      children: [
                        Expanded(child: Text(def1)),
                        IconButton(
                          tooltip: 'Speak definition (L1)',
                          icon: const Icon(Icons.volume_up),
                          onPressed: widget.disabled ? null : () => _speak(def1, _lc1, pauseAfterMs: widget.settings.pauseShortMs),
                        ),
                      ],
                    ),
                  ],
                  SizedBox(height: gap),
                ],
              ),

            // Sentences
            if (s2.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sentences', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  for (int i = 0; i < s2.length; i++)
                    SentenceItem(
                      s2: s2[i],
                      s1: (i < s1.length) ? s1[i] : '',
                      sameLang: widget.targetLang == widget.nativeLang,
                      onSpeakL2: widget.disabled ? null : () => _speak(s2[i], _lc2, pauseAfterMs: widget.settings.pauseShortMs),
                      onSpeakL1: (widget.disabled || widget.targetLang == widget.nativeLang || i >= s1.length)
                          ? null
                          : () => _speak(s1[i], _lc1, pauseAfterMs: widget.settings.pauseShortMs),
                    ),
                  SizedBox(height: gap),
                ],
              ),

            // Synonyms / Antonyms
            BilingualPairsWrap(
              title: 'Synonyms (Manual)',
              l2Items: syn2,
              l1MapById: _mapByIdText(_l1, 'synonyms'),
              sameLang: widget.targetLang == widget.nativeLang,
              onSpeakSingle: (text, isL2) async {
                if (widget.disabled) return;
                await _speak(text, isL2 ? _lc2 : _lc1, pauseAfterMs: widget.settings.pauseShortMs);
              },
            ),

            SizedBox(height: gap),

            BilingualPairsWrap(
              title: 'Antonyms (Manual)',
              l2Items: ant2,
              l1MapById: _mapByIdText(_l1, 'antonyms'),
              sameLang: widget.targetLang == widget.nativeLang,
              onSpeakSingle: (text, isL2) async {
                if (widget.disabled) return;
                await _speak(text, isL2 ? _lc2 : _lc1, pauseAfterMs: widget.settings.pauseShortMs);
              },
            ),
          ],
        ),
      ),
    );
  }
}
