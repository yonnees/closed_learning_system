// lib/modules/learn/favorite_word_detail_page.dart
import 'package:flutter/material.dart';

import '../../data/language_loader.dart';
import '../../services/settings_controller.dart';
import '../../services/tts_service.dart';
import '../../services/playback_session_service.dart';
import '../../services/favorites_service.dart';

class FavoriteWordDetailPage extends StatefulWidget {
  final SettingsController settings;
  final String targetLang; // L2
  final String nativeLang; // L1
  final int wordId;

  const FavoriteWordDetailPage({
    super.key,
    required this.settings,
    required this.targetLang,
    required this.nativeLang,
    required this.wordId,
  });

  @override
  State<FavoriteWordDetailPage> createState() => _FavoriteWordDetailPageState();
}

class _FavoriteWordDetailPageState extends State<FavoriteWordDetailPage> {
  final TtsService _tts = TtsService();
  late final PlaybackSessionService _session;

  // use singleton instance
  final FavoritesService _fav = FavoritesService.instance;

  Map<String, dynamic>? _l2;
  Map<String, dynamic>? _l1;
  bool _loading = true;

  // favorite state
  bool _isFav = false;
  bool _favLoaded = false;

  @override
  void initState() {
    super.initState();
    _session = PlaybackSessionService(tts: _tts, settings: widget.settings);
    _loadAll();
  }

  @override
  void dispose() {
    _session.stop();
    _tts.stop();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await _loadWord();
    await _loadFavStatus();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _loadWord() async {
    try {
      final l2 = await LanguageLoader.loadWordById(widget.targetLang, widget.wordId);
      final l1 = widget.targetLang == widget.nativeLang
          ? l2
          : await LanguageLoader.loadWordById(widget.nativeLang, widget.wordId);
      if (!mounted) return;
      setState(() {
        _l2 = l2;
        _l1 = l1;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _l2 = null;
        _l1 = null;
      });
    }
  }

  Future<void> _loadFavStatus() async {
    try {
      final set = await FavoritesService.instance.getFavorites(
        nativeLang: widget.nativeLang,
        targetLang: widget.targetLang,
      );
      final fav = set.contains(widget.wordId);
      if (!mounted) return;
      setState(() {
        _isFav = fav;
        _favLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isFav = false;
        _favLoaded = true;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final l2Text = _l2 != null ? (_l2!['word'] ?? '').toString() : '';
    final l1Text = _l1 != null ? (_l1!['word'] ?? '').toString() : '';

    // debug prints before calling the service
    // ignore: avoid_print
    print('FAVPAGE: toggleFavorite -> native="${widget.nativeLang}", target="${widget.targetLang}", id=${widget.wordId}');
    // ignore: avoid_print
    print('FAVPAGE: normalized codes -> native=${LanguageLoader.langCode(widget.nativeLang)}, target=${LanguageLoader.langCode(widget.targetLang)}');
    // ignore: avoid_print
    print('FAVPAGE: l1="$l1Text" l2="$l2Text"');

    try {
      await FavoritesService.instance.toggleFavorite(
        nativeLang: widget.nativeLang,
        targetLang: widget.targetLang,
        id: widget.wordId,
        l1: l1Text,
        l2: l2Text,
      );
      await _loadFavStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isFav ? 'Added to Favorites' : 'Removed from Favorites'),
          duration: const Duration(milliseconds: 700),
        ),
      );
    } catch (e) {
      // ignore: avoid_print
      print('FAVPAGE: toggleFavorite threw: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update favorite')));
    }
  }

  String _word(Map<String, dynamic>? m) => (m?['word'] ?? '').toString();

  String _firstDef(Map<String, dynamic>? m) {
    final defs = (m?['definitions'] is List) ? (m!['definitions'] as List) : const [];
    if (defs.isEmpty) return '';
    final first = defs.first;
    if (first is String) return first;
    if (first is Map && first.containsKey('text')) return (first['text'] ?? '').toString();
    return first.toString();
  }

  Future<void> _applySpeed() async {
    await _tts.configure(
      speechRate: widget.settings.speechRateValue,
      pitch: widget.settings.pitch,
      volume: widget.settings.volume,
    );
  }

  Future<void> _speak(String text, String langCode) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await _tts.stop();
    await _applySpeed();
    await _tts.speak(t, langCode);
  }

  @override
  Widget build(BuildContext context) {
    final pad = widget.settings.tilePadding().toDouble();

    final w2 = _word(_l2);
    final w1 = _word(_l1);
    final def2 = _firstDef(_l2);
    final def1 = _firstDef(_l1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorite Word'),
        actions: [
          IconButton(
            tooltip: _favLoaded
                ? (_isFav ? 'Remove from Favorites' : 'Add to Favorites')
                : 'Loading...',
            icon: _favLoaded
                ? Icon(_isFav ? Icons.star : Icons.star_outline, color: _isFav ? Colors.amber[700] : null)
                : const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            onPressed: _favLoaded ? _toggleFavorite : null,
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(pad),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
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
                                tooltip: 'Speak (L2)',
                                icon: const Icon(Icons.volume_up),
                                onPressed: () => _speak(w2, LanguageLoader.langCode(widget.targetLang)),
                              ),
                            ],
                          ),
                          if (widget.targetLang != widget.nativeLang && w1.trim().isNotEmpty) ...[
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
                                  tooltip: 'Speak (L1)',
                                  icon: const Icon(Icons.volume_up),
                                  onPressed: () => _speak(w1, LanguageLoader.langCode(widget.nativeLang)),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
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
                                    onPressed: () => _speak(def2, LanguageLoader.langCode(widget.targetLang)),
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
                                    onPressed: () => _speak(def1, LanguageLoader.langCode(widget.nativeLang)),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  bool get _sameLang => widget.targetLang == widget.nativeLang;
}
