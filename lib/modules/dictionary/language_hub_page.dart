import 'package:flutter/material.dart';

import '../../services/settings_controller.dart';
import '../dictionary/dictionary_page.dart';
import '../home/coming_soon_page.dart';
import '../learn/learn_entry_page.dart';
import '../progress/progress_page.dart';
import '../favorites/favorites_page.dart';

// ✅ Review/SRS page (غيّر المسار إذا اسم ملفك مختلف)
import '../review/review_entry_page.dart';


class LanguageHubPage extends StatelessWidget {
  final SettingsController settings;
  const LanguageHubPage({super.key, required this.settings});

  String? _second(String en, String ar, String es) {
    final lang = settings.uiLanguage ?? 'english';
    if (lang == 'english') return null;
    if (lang == 'arabic') return ar;
    if (lang == 'spanish') return es;
    return null;
  }

  int _autoColumns(double width, int preferred) {
    const minTile = 140.0;
    final auto = (width / minTile).floor().clamp(2, 9);
    return preferred.clamp(2, auto);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        final titleSecond = _second('Language Hub', 'مركز اللغة', 'Centro de Idiomas');

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Language Hub'),
                if (titleSecond != null)
                  Text(
                    titleSecond,
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                  ),
              ],
            ),
          ),
          body: Padding(
            padding: EdgeInsets.all(settings.tilePadding()),
            child: Material(
              color: Colors.transparent,
              child: LayoutBuilder(
                builder: (context, c) {
                  final cols = _autoColumns(c.maxWidth, settings.gridCountHub());
                  final spacing = settings.gridSpacing();

                  final tileW = (c.maxWidth - (spacing * (cols - 1))) / cols;
                  final boxSize = (tileW * 0.55).clamp(52.0, 110.0);
                  final iconSize = (boxSize * 0.55).clamp(22.0, 64.0);

                  return GridView.count(
                    crossAxisCount: cols,
                    mainAxisSpacing: spacing,
                    crossAxisSpacing: spacing,
                    children: [
                      _appIconTile(
                        context,
                        icon: Icons.school,
                        en: 'Learn',
                        ar: 'تعلّم',
                        es: 'Aprender',
                        boxSize: boxSize,
                        iconSize: iconSize,
                        baseColor: Colors.indigo,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => LearnEntryPage(settings: settings)),
                          );
                        },
                      ),

                      _appIconTile(
                        context,
                        icon: Icons.menu_book,
                        en: 'Dictionary',
                        ar: 'قاموس',
                        es: 'Diccionario',
                        boxSize: boxSize,
                        iconSize: iconSize,
                        baseColor: Colors.teal,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => DictionaryPage(settings: settings)),
                          );
                        },
                      ),

                      _appIconTile(
                        context,
                        icon: Icons.headphones,
                        en: 'Club Mode',
                        ar: 'وضع الاستماع',
                        es: 'Modo Audio',
                        boxSize: boxSize,
                        iconSize: iconSize,
                        baseColor: Colors.orange,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ComingSoonPage(title: 'Club Mode')),
                          );
                        },
                      ),

                      _appIconTile(
                        context,
                        icon: Icons.quiz,
                        en: 'Tests',
                        ar: 'اختبارات',
                        es: 'Pruebas',
                        boxSize: boxSize,
                        iconSize: iconSize,
                        baseColor: Colors.pink,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ComingSoonPage(title: 'Tests')),
                          );
                        },
                      ),

                      // ✅ Review/SRS now real
                      _appIconTile(
                        context,
                        icon: Icons.autorenew,
                        en: 'Review / SRS',
                        ar: 'مراجعة ذكية',
                        es: 'Repaso',
                        boxSize: boxSize,
                        iconSize: iconSize,
                        baseColor: Colors.purple,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ReviewEntryPage(settings: settings)),
                          );
                        },
                      ),

                      _appIconTile(
                        context,
                        icon: Icons.insights,
                        en: 'My Progress',
                        ar: 'تقدّمي',
                        es: 'Progreso',
                        boxSize: boxSize,
                        iconSize: iconSize,
                        baseColor: Colors.blue,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ProgressPage(settings: settings)),
                          );
                        },
                      ),

                      // ✅ Favorites real
                      _appIconTile(
                        context,
                        icon: Icons.star,
                        en: 'Favorites',
                        ar: 'المفضلة',
                        es: 'Favoritos',
                        boxSize: boxSize,
                        iconSize: iconSize,
                        baseColor: Colors.amber,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => FavoritesPage(settings: settings)),
                          );
                        },
                      ),

                      _appIconTile(
                        context,
                        icon: Icons.videogame_asset,
                        en: 'Games',
                        ar: 'ألعاب',
                        es: 'Juegos',
                        boxSize: boxSize,
                        iconSize: iconSize,
                        baseColor: Colors.green,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ComingSoonPage(title: 'Games')),
                          );
                        },
                      ),

                      _appIconTile(
                        context,
                        icon: Icons.forum,
                        en: 'Scenes / Chat',
                        ar: 'مشاهد / دردشة',
                        es: 'Escenas / Chat',
                        boxSize: boxSize,
                        iconSize: iconSize,
                        baseColor: Colors.blueGrey,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ComingSoonPage(title: 'Scenes / Chat')),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _appIconTile(
    BuildContext context, {
    required IconData icon,
    required String en,
    required String ar,
    required String es,
    required double boxSize,
    required double iconSize,
    required Color baseColor,
    required VoidCallback onTap,
  }) {
    final second = _second(en, ar, es);

    return InkResponse(
      onTap: onTap,
      radius: boxSize,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: boxSize,
            width: boxSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(boxSize * 0.28),
              color: baseColor.withOpacity(0.14),
            ),
            child: Icon(icon, size: iconSize, color: baseColor),
          ),
          const SizedBox(height: 8),
          Text(
            en,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          if (second != null) ...[
            const SizedBox(height: 2),
            Text(
              second,
              textAlign: TextAlign.center,
              textDirection: (settings.uiLanguage == 'arabic') ? TextDirection.rtl : TextDirection.ltr,
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
