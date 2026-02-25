import 'dart:async';
import 'package:flutter/material.dart';

import '../../data/language_loader.dart';
import '../../services/settings_controller.dart';
import '../../services/tts_service.dart';
import '../../services/playback_session_service.dart';
import 'bilingual_word_detail_page.dart';

class DictionaryPage extends StatefulWidget {
  final SettingsController settings;
  const DictionaryPage({super.key, required this.settings});

  @override
  State<DictionaryPage> createState() => _DictionaryPageState();
}

class _DictionaryPageState extends State<DictionaryPage> {
  String nativeLang = 'arabic';   // L1
  String targetLang = 'english';  // L2

  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  bool loading = false;
  int _searchToken = 0;

  // نتائج البحث
  List<Map<String, dynamic>> targetResults = [];
  List<Map<String, dynamic>> nativeResults = [];

  // Club Mode (session)
  final TtsService _tts = TtsService();
  late final PlaybackSessionService _session;

  bool _clubRunning = false;
  int _clubMinutes = 10;
  bool _clubLoop = false;

  static const List<String> _langs = ['english', 'arabic', 'spanish'];

  @override
  void initState() {
    super.initState();
    _session = PlaybackSessionService(tts: _tts, settings: widget.settings);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _session.stop();
    super.dispose();
  }

  // ---------- Search ----------
  void _onQueryChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      _runSearch(text);
    });
  }

  bool _containsArabic(String s) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(s);
  }

  String _prettyLang(String lang) {
    switch (lang) {
      case 'english':
        return 'English';
      case 'arabic':
        return 'Arabic';
      case 'spanish':
        return 'Spanish';
      default:
        return lang;
    }
  }

  Future<void> _runSearch(String text) async {
    final query = text.trim();

    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        loading = false;
        targetResults = [];
        nativeResults = [];
      });
      return;
    }

    final myToken = ++_searchToken;
    if (!mounted) return;
    setState(() => loading = true);

    try {
      final isArabic = _containsArabic(query);

      // لو كتب عربي: ابحث عربي فقط
      if (isArabic) {
        final rAr = await LanguageLoader.searchByPrefix(
          lang: 'arabic',
          query: query,
          limit: 80,
        );

        if (!mounted || myToken != _searchToken) return;

        setState(() {
          loading = false;
          // لو الهدف عربي اعرضها في قسم الهدف، غير كذا اعرضها كقسم واحد تحت (Native)
          targetResults = (targetLang == 'arabic') ? rAr : [];
          nativeResults = (targetLang == 'arabic') ? [] : rAr;
        });
        return;
      }

      // غير عربي: ابحث في L2 ثم L1
      final primary = targetLang;
      final secondary = (nativeLang == primary) ? null : nativeLang;

      final futures = <Future<List<Map<String, dynamic>>>>[
        LanguageLoader.searchByPrefix(lang: primary, query: query, limit: 60),
        if (secondary != null)
          LanguageLoader.searchByPrefix(lang: secondary, query: query, limit: 60),
      ];

      final lists = await Future.wait(futures);

      if (!mounted || myToken != _searchToken) return;

      final primaryList = lists.isNotEmpty ? lists[0] : <Map<String, dynamic>>[];
      final secondaryList = lists.length > 1 ? lists[1] : <Map<String, dynamic>>[];

      // منع تكرار IDs في القسم الثاني
      final seenIds = <int>{};
      for (final w in primaryList) {
        final id = w['id'];
        if (id is int) seenIds.add(id);
      }

      final filteredSecondary = <Map<String, dynamic>>[];
      for (final w in secondaryList) {
        final id = w['id'];
        if (id is int && !seenIds.contains(id)) {
          filteredSecondary.add(w);
        }
      }

      setState(() {
        loading = false;
        targetResults = primaryList;
        nativeResults = filteredSecondary;
      });
    } catch (_) {
      if (!mounted || myToken != _searchToken) return;
      setState(() {
        loading = false;
        targetResults = [];
        nativeResults = [];
      });
    }
  }

  // ---------- Open Word Detail ----------
  Future<void> _openWord(int id) async {
    final l2 = await LanguageLoader.loadWordById(targetLang, id);
    final l1 = await LanguageLoader.loadWordById(nativeLang, id);

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BilingualWordDetailPage(
          wordL2: l2,
          wordL1: l1,
          langL2: LanguageLoader.langCode(targetLang),
          langL1: LanguageLoader.langCode(nativeLang),
          settings: widget.settings,
        ),
      ),
    );
  }

  // ---------- Club Mode UI ----------
  void _openClubModeSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        int minutes = _clubMinutes;
        bool loop = _clubLoop;

        final options = <int>[10, 15, 20, 30, 45, 60, 0]; // 0 = بدون مؤقت

        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.headphones),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Club Mode (Hands-free)',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (_clubRunning)
                        FilledButton.tonal(
                          onPressed: () async {
                            await _session.stop();
                            if (!mounted) return;
                            setState(() => _clubRunning = false);
                            Navigator.pop(ctx);
                          },
                          child: const Text('Stop'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<int>(
                    value: minutes,
                    decoration: const InputDecoration(
                      labelText: 'Timer',
                      border: OutlineInputBorder(),
                    ),
                    items: options.map((m) {
                      final label = (m == 0) ? 'No timer (until stop)' : '$m minutes';
                      return DropdownMenuItem(value: m, child: Text(label));
                    }).toList(),
                    onChanged: (v) => setLocal(() => minutes = v ?? 10),
                  ),

                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: const Text('Loop (repeat after finishing 5000)'),
                    value: loop,
                    onChanged: (v) => setLocal(() => loop = v),
                  ),

                  const SizedBox(height: 8),
                  Text(
                    'Synonyms/Antonyms in session follow Settings (Auto Play options).',
                    style: TextStyle(color: Colors.grey[700]),
                  ),

                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: Icon(_clubRunning ? Icons.hourglass_top : Icons.play_arrow),
                      label: Text(_clubRunning ? 'Running…' : 'Start'),
                      onPressed: _clubRunning
                          ? null
                          : () async {
                              setState(() {
                                _clubMinutes = minutes;
                                _clubLoop = loop;
                                _clubRunning = true;
                              });

                              Navigator.pop(ctx);

                              await _session.startSession(
                                targetLang: targetLang,
                                nativeLang: nativeLang,
                                minutes: minutes,
                                loop: loop,
                              );

                              if (mounted) setState(() => _clubRunning = false);
                            },
                    ),
                  ),

                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------- UI helpers ----------
  Widget _sectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Text('($count)', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> list) {
    return Column(
      children: list.map((w) {
        final id = w['id'];
        final wordText = LanguageLoader.wordText(w);
        final pos = (w['part_of_speech'] ?? '').toString();
        final lvl = (w['level'] ?? '').toString();

        return ListTile(
          title: Text(wordText),
          subtitle: Text([if (pos.isNotEmpty) pos, if (lvl.isNotEmpty) lvl].join(' • ')),
          trailing: const Icon(Icons.chevron_right),
          onTap: (id is int) ? () => _openWord(id) : null,
        );
      }).toList(),
    );
  }

  Widget _langDropdown(String label, String value, ValueChanged<String> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: _langs
          .map((l) => DropdownMenuItem(value: l, child: Text(_prettyLang(l))))
          .toList(),
      onChanged: (v) {
        if (v == null) return;
        onChanged(v);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l1Label = _prettyLang(nativeLang);
    final l2Label = _prettyLang(targetLang);

    final query = _controller.text.trim();
    final isArabic = _containsArabic(query);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dictionary'),
        actions: [
          IconButton(
            tooltip: _clubRunning ? 'Club Mode (Stop)' : 'Club Mode',
            icon: Icon(_clubRunning ? Icons.stop_circle : Icons.headphones),
            onPressed: _openClubModeSheet,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _langDropdown('Native (L1)', nativeLang, (v) {
                    setState(() => nativeLang = v);
                    _runSearch(_controller.text);
                  }),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _langDropdown('Target (L2)', targetLang, (v) {
                    setState(() => targetLang = v);
                    _runSearch(_controller.text);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Search (Prefix): $l2Label then $l1Label',
                hintText: 'pen / abil / قدرة ...',
                border: const OutlineInputBorder(),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          _runSearch('');
                          setState(() {});
                        },
                      ),
              ),
              onChanged: (t) {
                setState(() {});
                _onQueryChanged(t);
              },
            ),

            const SizedBox(height: 10),
            if (loading) const LinearProgressIndicator(),
            const SizedBox(height: 10),

            Expanded(
              child: (targetResults.isEmpty && nativeResults.isEmpty)
                  ? Center(
                      child: Text(
                        query.isEmpty
                            ? 'Type to search'
                            : (isArabic ? 'No Arabic results (prefix search)' : 'No results (prefix search)'),
                      ),
                    )
                  : ListView(
                      children: [
                        if (isArabic) ...[
                          _sectionHeader(
                            targetLang == 'arabic' ? 'Target (L2) Arabic' : 'Arabic results',
                            targetLang == 'arabic' ? targetResults.length : nativeResults.length,
                          ),
                          _buildList(targetLang == 'arabic' ? targetResults : nativeResults),
                        ] else ...[
                          _sectionHeader('Target (L2) $l2Label', targetResults.length),
                          _buildList(targetResults),
                          const Divider(height: 24),
                          _sectionHeader('Native (L1) $l1Label', nativeResults.length),
                          _buildList(nativeResults),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
