import 'package:flutter/material.dart';
import 'services/settings_controller.dart';
import 'modules/home/home_page.dart';
import 'modules/settings/language_picker_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = SettingsController();
  await settings.load();

  runApp(MyApp(settings: settings));
}

class MyApp extends StatelessWidget {
  final SettingsController settings;
  const MyApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Closed Learning System',
      debugShowCheckedModeBanner: false,
      home: BootGate(settings: settings),
    );
  }
}

class BootGate extends StatefulWidget {
  final SettingsController settings;
  const BootGate({super.key, required this.settings});

  @override
  State<BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<BootGate> {
  bool _asked = false;

  @override
  void initState() {
    super.initState();

    // ✅ مهم: افتح صفحة اللغة بعد أول frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeAskLanguage();
    });
  }

  Future<void> _maybeAskLanguage() async {
    if (_asked) return;
    _asked = true;

    if (widget.settings.uiLanguage != null) return;

    final chosen = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LanguagePickerPage(settings: widget.settings),
      ),
    );

    if (chosen != true) {
      await widget.settings.update(() => widget.settings.uiLanguage = 'english');
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return HomePage(settings: widget.settings);
  }
}
