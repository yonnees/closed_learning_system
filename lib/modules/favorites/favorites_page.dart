// lib/modules/favorites/favorites_page.dart
import 'package:flutter/material.dart';

import '../../data/language_loader.dart';
import '../../services/settings_controller.dart';
import '../../services/favorites_service.dart';
import '../../data/language_loader.dart';
import '../favorites/favorite_word_detail_page.dart';

class FavoritesPage extends StatefulWidget {
  final SettingsController settings;
  const FavoritesPage({super.key, required this.settings});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  static const langs = ['english', 'arabic', 'spanish'];

  late String nativeLang;
  late String targetLang;

  Set<int> _ids = {};
  Map<int, Map<String, String>> _meta = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // default to uiLanguage as nativeLang, and english as target if different
    nativeLang = widget.settings.uiLanguage ?? 'english';
    targetLang = nativeLang == 'english' ? 'arabic' : 'english';
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final ids = await FavoritesService.instance.getFavorites(
      nativeLang: nativeLang,
      targetLang: targetLang,
    );
    final meta = await FavoritesService.instance.getFavoritesMeta(
      nativeLang: nativeLang,
      targetLang: targetLang,
    );
    if (!mounted) return;
    setState(() {
      _ids = ids;
      _meta = meta;
      _loading = false;
    });
  }

  Future<void> _remove(int id) async {
    await FavoritesService.instance.removeFavorite(
      nativeLang: nativeLang,
      targetLang: targetLang,
      id: id,
    );
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed from Favorites')));
    }
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

  @override
  Widget build(BuildContext context) {
    final pad = widget.settings.tilePadding().toDouble();
    final gap = widget.settings.gridSpacing().toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(pad),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(pad),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: nativeLang,
                        decoration: const InputDecoration(labelText: 'Native (L1)'),
                        items: langs.map((l) => DropdownMenuItem(value: l, child: Text(_prettyLang(l)))).toList(),
                        onChanged: (v) {
                          setState(() => nativeLang = v ?? nativeLang);
                          _load();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: targetLang,
                        decoration: const InputDecoration(labelText: 'Target (L2)'),
                        items: langs.map((l) => DropdownMenuItem(value: l, child: Text(_prettyLang(l)))).toList(),
                        onChanged: (v) {
                          setState(() => targetLang = v ?? targetLang);
                          _load();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _ids.isEmpty
                      ? Center(child: Text('No favorites for ${_prettyLang(nativeLang)} → ${_prettyLang(targetLang)}'))
                      : ListView.separated(
                          itemCount: _ids.length,
                          separatorBuilder: (_, __) => SizedBox(height: gap),
                          itemBuilder: (context, index) {
                            final id = _ids.elementAt(index);
                            final meta = _meta[id];
                            final l2Text = meta != null && meta['l2']!.isNotEmpty ? meta['l2']! : 'ID $id';
                            final l1Text = meta != null && meta['l1']!.isNotEmpty ? meta['l1']! : '';
                            return Card(
                              child: ListTile(
                                title: Text(l2Text),
                                subtitle: l1Text.isNotEmpty ? Text(l1Text) : null,
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _remove(id),
                                ),
                                onTap: () {
                                  // open detail (use FavoriteWordDetailPage)
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => FavoriteWordDetailPage(
                                        settings: widget.settings,
                                        targetLang: targetLang,
                                        nativeLang: nativeLang,
                                        wordId: id,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
