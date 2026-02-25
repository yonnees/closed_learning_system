import 'package:flutter/material.dart';
import '../../services/settings_controller.dart';

class LanguagePickerPage extends StatelessWidget {
  final SettingsController settings;
  const LanguagePickerPage({super.key, required this.settings});

  String _title2(String lang) {
    switch (lang) {
      case 'arabic':
        return 'العربية';
      case 'spanish':
        return 'Español';
      case 'english':
      default:
        return 'English';
    }
  }

  // ✅ نصوص بسيطة حسب لغة الواجهة الحالية (اختياري)
  String _t(String key) {
    final ui = settings.uiLanguage; // 'english' | 'arabic' | 'spanish'
    switch (key) {
      case 'title':
        if (ui == 'arabic') return 'اختر لغة الواجهة';
        if (ui == 'spanish') return 'Elige el idioma de la interfaz';
        return 'Choose System Language';
      case 'hint':
        if (ui == 'arabic') return 'اختر لغة واجهة التطبيق:';
        if (ui == 'spanish') return 'Elige el idioma de la interfaz:';
        return 'Choose the UI language:';
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = const ['english', 'arabic', 'spanish'];

    return Scaffold(
      appBar: AppBar(title: Text(_t('title'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_t('hint'), style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 14),
          ...options.map((lang) {
            return Card(
              child: ListTile(
                title: Text(lang[0].toUpperCase() + lang.substring(1)),
                subtitle: Text(_title2(lang)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await settings.update(() => settings.uiLanguage = lang);
                  if (!context.mounted) return;

                  // ✅ مهم جدًا: نخليها bool مثل قبل عشان BootGate ما يعلق
                  Navigator.pop(context, true);
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}
