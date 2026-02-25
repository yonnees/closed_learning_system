import 'package:flutter/material.dart';
import '../../services/settings_controller.dart';

class UiSizeSettingsPage extends StatelessWidget {
  final SettingsController settings;
  const UiSizeSettingsPage({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('UI Size')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Choose UI size:', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            DropdownButton<UiSizeMode>(
              value: settings.uiSizeMode,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: UiSizeMode.compact, child: Text('Compact (Small)')),
                DropdownMenuItem(value: UiSizeMode.normal, child: Text('Normal')),
                DropdownMenuItem(value: UiSizeMode.large, child: Text('Large')),
              ],
              onChanged: (v) async {
                if (v == null) return;
                await settings.update(() => settings.uiSizeMode = v);
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'Tip: Compact increases grid columns (smaller tiles). Large decreases columns (bigger tiles).',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
