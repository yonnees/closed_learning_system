// lib/modules/review/review_session_page.dart
import 'package:flutter/material.dart';

import '../../data/language_loader.dart';
import '../../services/settings_controller.dart';
import '../../services/tts_service.dart';
import '../../services/srs_service.dart';
import '../../services/favorites_service.dart';

class ReviewSessionPage extends StatefulWidget {
  final SettingsController settings;
  final String nativeLang;
  final String targetLang;
  final List<int> ids;

  const ReviewSessionPage({
    super.key,
    required this.settings,
    required this.nativeLang,
    required this.targetLang,
    required this.ids,
  });

  @override
  State<ReviewSessionPage> createState() => _ReviewSessionPageState();
}

class _ReviewSessionPageState extends State<ReviewSessionPage> {
  final SrsService _srs = SrsService();
  final TtsService _tts = TtsService();

  int _i = 0;
  bool _loading = true;

  Map<String, dynamic>? _l2;
  Map<String, dynamic>? _l1;

  bool get _sameLang => widget.nativeLang == widget.targetLang;
  int get _wordId => widget.ids[_i];

  // favorites
  Set<int> _favorites = {};
  bool _favoritesLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadWord();
    _loadFavorites();
  }

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
    await FavoritesService.instance.toggleFavorite(
      nativeLang: widget.nativeLang,
      targetLang: widget.targetLang,
      id: id,
    );
    await _loadFavorites();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_favorites.contains(id) ? 'Added to Favorites' : 'Removed from Favorites'),
        duration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  String _word(Map<String, dynamic>? m) => (m?['word'] ?? '').toString();
  String _firstDef(Map<String, dynamic>? m) {
    final defs = (m?['definitions'] is List) ? (m!['definitions'] as List) : const [];
    if (defs.isEmpty) return '';
    return (defs.first['text'] ?? '').toString();
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

  Future<void> _loadWord() async {
    setState(() => _loading = true);

    final l2 = await LanguageLoader.loadWordById(widget.targetLang, _wordId);
    final l1 = _sameLang ? l2 : await LanguageLoader.loadWordById(widget.nativeLang, _wordId);

    if (!mounted) return;
    setState(() {
      _l2 = l2;
      _l1 = l1;
      _loading = false;
    });
  }

  Future<void> _grade(SrsGrade g) async {
    await _srs.grade(
      nativeLang: widget.nativeLang,
      targetLang: widget.targetLang,
      wordId: _wordId,
      grade: g,
    );

    if (_i >= widget.ids.length - 1) {
      if (!mounted) return;
      Navigator.pop(context);
      return;
    }

    setState(() => _i++);
    await _loadWord();
  }

  @override
  Widget build(BuildContext context) {
    final pad = widget.settings.tilePadding().toDouble();
    final gap = widget.settings.gridSpacing().toDouble();

    final w2 = _word(_l2);
    final w1 = _word(_l1);
    final d2 = _firstDef(_l2);
    final d1 = _firstDef(_l1);

    final lc2 = LanguageLoader.langCode(widget.targetLang);
    final lc1 = LanguageLoader.langCode(widget.nativeLang);

    return Scaffold(
      appBar: AppBar(
        title: Text('Review • ${_i + 1}/${widget.ids.length}'),
        actions: [
          if (_favoritesLoaded)
            IconButton(
              tooltip: _favorites.contains(_wordId) ? 'Remove from Favorites' : 'Add to Favorites',
              icon: Icon(
                _favorites.contains(_wordId) ? Icons.star : Icons.star_outline,
                color: _favorites.contains(_wordId) ? Colors.amber[700] : null,
              ),
              onPressed: () => _toggleFavorite(_wordId),
            ),
          IconButton(
            tooltip: 'Stop',
            icon: const Icon(Icons.stop_circle),
            onPressed: () => Navigator.pop(context),
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
                                onPressed: () => _speak(w2, lc2),
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
                                  tooltip: 'Speak (L1)',
                                  icon: const Icon(Icons.volume_up),
                                  onPressed: () => _speak(w1, lc1),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: gap),

                  if (d2.trim().isNotEmpty || (!_sameLang && d1.trim().isNotEmpty))
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(pad),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Definition', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            if (d2.trim().isNotEmpty)
                              Row(
                                children: [
                                  Expanded(child: Text(d2)),
                                  IconButton(
                                    tooltip: 'Speak definition (L2)',
                                    icon: const Icon(Icons.volume_up),
                                    onPressed: () => _speak(d2, lc2),
                                  ),
                                ],
                              ),
                            if (!_sameLang && d1.trim().isNotEmpty) ...[
                              const Divider(),
                              Row(
                                children: [
                                  Expanded(child: Text(d1)),
                                  IconButton(
                                    tooltip: 'Speak definition (L1)',
                                    icon: const Icon(Icons.volume_up),
                                    onPressed: () => _speak(d1, lc1),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                  SizedBox(height: gap),

                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(pad),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('How was it?', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _grade(SrsGrade.again),
                                  child: const Text('Again'),
                                ),
                              ),
                              SizedBox(width: gap),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _grade(SrsGrade.hard),
                                  child: const Text('Hard'),
                                ),
                              ),
                              SizedBox(width: gap),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _grade(SrsGrade.good),
                                  child: const Text('Good'),
                                ),
                              ),
                              SizedBox(width: gap),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _grade(SrsGrade.easy),
                                  child: const Text('Easy'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Again = 10min • Hard/Good/Easy schedule next review automatically.',
                            style: TextStyle(color: Colors.grey[700], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
