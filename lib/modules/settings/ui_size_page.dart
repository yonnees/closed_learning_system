import 'package:flutter/material.dart';
import '../../services/settings_controller.dart';

class UiSizePage extends StatelessWidget {
  final SettingsController settings;
  const UiSizePage({super.key, required this.settings});

  String _label(UiSizeMode m) {
    switch (m) {
      case UiSizeMode.compact:
        return 'Compact';
      case UiSizeMode.normal:
        return 'Normal';
      case UiSizeMode.large:
        return 'Large';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('UI Size')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: DropdownButton<UiSizeMode>(
          value: settings.uiSizeMode,
          isExpanded: true,
          items: UiSizeMode.values
              .map((m) => DropdownMenuItem(value: m, child: Text(_label(m))))
              .toList(),
          onChanged: (v) async {
            if (v == null) return;
            await settings.update(() => settings.uiSizeMode = v);
          },
        ),
      ),
    );
  }
}
