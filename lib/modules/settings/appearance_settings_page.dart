import 'package:flutter/material.dart';
import '../../services/settings_controller.dart';

class AppearanceSettingsPage extends StatefulWidget {
  final SettingsController settings;
  const AppearanceSettingsPage({super.key, required this.settings});

  @override
  State<AppearanceSettingsPage> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {

  void update(void Function() fn) {
    setState(() => fn());
    widget.settings.save();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;

    return Scaffold(
      appBar: AppBar(title: const Text("Appearance")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          const Text("Text Size", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'compact', label: Text("Small")),
              ButtonSegment(value: 'normal', label: Text("Normal")),
              ButtonSegment(value: 'large', label: Text("Large")),
            ],
            selected: {s.uiSizeMode},
            onSelectionChanged: (v) => update(() => s.uiSizeMode = v.first),
          ),

          const SizedBox(height: 24),

          const Text("App Color", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          Wrap(
            spacing: 10,
            children: ['blue','green','red','purple','orange'].map((c) {
              return ChoiceChip(
                label: Text(c),
                selected: s.appColor == c,
                onSelected: (_) => update(() => s.appColor = c),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          SwitchListTile(
            title: const Text("Dark Mode"),
            value: s.darkMode,
            onChanged: (v) => update(() => s.darkMode = v),
          ),
        ],
      ),
    );
  }
}