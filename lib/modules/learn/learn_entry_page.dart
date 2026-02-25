import 'package:flutter/material.dart';
import '../../services/settings_controller.dart';
import 'learn_levels_page.dart';

class LearnEntryPage extends StatefulWidget {
  final SettingsController settings;

  // ✅ optional presets (does NOT change default behavior)
  final String? presetNativeLang;
  final String? presetTargetLang;

  const LearnEntryPage({
    super.key,
    required this.settings,
    this.presetNativeLang,
    this.presetTargetLang,
  });

  @override
  State<LearnEntryPage> createState() => _LearnEntryPageState();
}

class _LearnEntryPageState extends State<LearnEntryPage> {
  static const langs = ['english', 'arabic', 'spanish'];

  late String nativeLang; // L1
  late String targetLang; // L2

  @override
  void initState() {
    super.initState();
    nativeLang = widget.presetNativeLang ?? (widget.settings.uiLanguage ?? 'english');
    targetLang = widget.presetTargetLang ?? 'english';
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
    final second = widget.settings.uiLanguage;
    final secondIsEnglish = second == null || second == 'english';

    String t(String en, String ar, String es) {
      if (secondIsEnglish) return en;
      if (second == 'arabic') return '$en\n$ar';
      if (second == 'spanish') return '$en\n$es';
      return en;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(t('Learn', 'تعلّم', 'Aprender')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                t('Choose Languages', 'اختر اللغات', 'Elige los idiomas'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              value: nativeLang,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: t('Native Language (L1)', 'اللغة الأم (L1)', 'Idioma nativo (L1)'),
              ),
              items: langs.map((l) => DropdownMenuItem(value: l, child: Text(_prettyLang(l)))).toList(),
              onChanged: (v) => setState(() => nativeLang = v ?? nativeLang),
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: targetLang,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: t('Target Language (L2)', 'اللغة الهدف (L2)', 'Idioma objetivo (L2)'),
              ),
              items: langs.map((l) => DropdownMenuItem(value: l, child: Text(_prettyLang(l)))).toList(),
              onChanged: (v) => setState(() => targetLang = v ?? targetLang),
            ),

            const SizedBox(height: 12),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                (nativeLang == targetLang)
                    ? t(
                        'Same language selected: will play once.',
                        'تم اختيار نفس اللغة: سيتم العرض والنطق مرة واحدة.',
                        'Mismo idioma: se mostrará y se reproducirá مرة واحدة.',
                      )
                    : t('Bilingual mode: L2 + L1', 'وضع ثنائي: (L2 + L1)', 'Modo bilingüe: L2 + L1'),
                style: TextStyle(color: Colors.grey[700]),
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.arrow_forward),
                label: Text(t('Continue', 'متابعة', 'Continuar')),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LearnLevelsPage(
                        settings: widget.settings,
                        targetLang: targetLang,
                        nativeLang: nativeLang,
                      ),
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
