// lib/modules/home/home_page.dart  ✅ (Progress رجع ComingSoon)
import 'package:flutter/material.dart';
import '../../services/settings_controller.dart';
import '../dictionary/language_hub_page.dart';
import 'coming_soon_page.dart';
import '../settings/language_picker_page.dart';
import '../settings/ui_size_page.dart';

class HomePage extends StatelessWidget {
  final SettingsController settings;
  const HomePage({super.key, required this.settings});

  int _autoColumns(double width, int preferred) {
    const minTile = 140.0; // ✅ المطلوب
    final auto = (width / minTile).floor().clamp(2, 8);
    return preferred.clamp(2, auto);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Closed Learning System'),
            actions: [
              IconButton(
                icon: const Icon(Icons.tune),
                tooltip: 'UI Size',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => UiSizePage(settings: settings)),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.language),
                onPressed: () async {
                  await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => LanguagePickerPage(settings: settings)),
                  );
                },
              ),
            ],
          ),
          body: Padding(
            padding: EdgeInsets.all(settings.tilePadding()),
            child: Material(
              color: Colors.transparent,
              child: LayoutBuilder(
                builder: (context, c) {
                  final cols = _autoColumns(c.maxWidth, settings.gridCountHome());
                  final spacing = settings.gridSpacing();

                  // حجم الخانة التقريبي
                  final tileW = (c.maxWidth - (spacing * (cols - 1))) / cols;

                  // حجم مربع الأيقونة (يتكيف)
                  final boxSize = (tileW * 0.55).clamp(52.0, 110.0);
                  final iconSize = (boxSize * 0.55).clamp(22.0, 64.0);

                  return GridView.count(
                    crossAxisCount: cols,
                    mainAxisSpacing: spacing,
                    crossAxisSpacing: spacing,
                    children: [
                      _appIconTile(
                        context,
                        icon: Icons.menu_book,
                        title: 'Dictionary',
                        boxSize: boxSize,
                        iconSize: iconSize,
                        baseColor: Colors.teal,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => LanguageHubPage(settings: settings)),
                          );
                        },
                      ),
                      _appIconTile(
                        context,
                        icon: Icons.public,
                        title: 'Virtual World',
                        boxSize: boxSize,
                        iconSize: iconSize,
                        baseColor: Colors.indigo,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ComingSoonPage(title: 'Virtual World')),
                          );
                        },
                      ),
                      _appIconTile(
                        context,
                        icon: Icons.insights,
                        title: 'Progress',
                        boxSize: boxSize,
                        iconSize: iconSize,
                        baseColor: Colors.purple,
                        onTap: () {
                          // ✅ رجعناه ComingSoon لأن Progress الحقيقي داخل Hub
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ComingSoonPage(title: 'Progress')),
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
    required String title,
    required double boxSize,
    required double iconSize,
    required Color baseColor,
    required VoidCallback onTap,
  }) {
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
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
