import 'package:flutter/material.dart';
import '../../services/settings_controller.dart';

class SettingsPage extends StatelessWidget {
  final SettingsController settings;
  const SettingsPage({super.key, required this.settings});

  String _speedLabel(SpeechSpeed s) {
    switch (s) {
      case SpeechSpeed.slow3x:
        return 'Slow -3';
      case SpeechSpeed.slow2x:
        return 'Slow -2';
      case SpeechSpeed.slow1x:
        return 'Slow -1';
      case SpeechSpeed.normal:
        return 'Normal';
      case SpeechSpeed.fast1x:
        return 'Fast +1';
      case SpeechSpeed.fast2x:
        return 'Fast +2';
      case SpeechSpeed.fast3x:
        return 'Fast +3';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Speech Speed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: SpeechSpeed.values.map((speed) {
                  return ChoiceChip(
                    label: Text(_speedLabel(speed)),
                    selected: settings.speechSpeed == speed,
                    onSelected: (_) => settings.update(() => settings.speechSpeed = speed),
                  );
                }).toList(),
              ),

              const Divider(height: 28),

              const Text('Auto Play', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              _intStepper(
                title: 'Confirm L2 repeats',
                subtitle: 'بعد L1 كم مرة يعيد L2 (1 = L2,L1,L2)',
                value: settings.confirmL2Repeats,
                min: 1,
                max: 3,
                onChanged: (v) => settings.update(() => settings.confirmL2Repeats = v),
              ),

              _intStepper(
                title: 'Sentences to play',
                subtitle: 'افتراضي 3',
                value: settings.maxSentencesToPlay,
                min: 1,
                max: 5,
                onChanged: (v) => settings.update(() => settings.maxSentencesToPlay = v),
              ),

              _intStepper(
                title: 'Sentence repeat',
                subtitle: 'تكرار كل جملة',
                value: settings.sentenceRepeat,
                min: 1,
                max: 3,
                onChanged: (v) => settings.update(() => settings.sentenceRepeat = v),
              ),

              const Divider(height: 28),

              const Text('Pauses (ms)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              _intStepper(
                title: 'Short pause',
                value: settings.pauseShortMs,
                min: 0,
                max: 1200,
                step: 50,
                onChanged: (v) => settings.update(() => settings.pauseShortMs = v),
              ),

              _intStepper(
                title: 'Medium pause',
                value: settings.pauseMediumMs,
                min: 0,
                max: 1500,
                step: 50,
                onChanged: (v) => settings.update(() => settings.pauseMediumMs = v),
              ),

              _intStepper(
                title: 'Long pause',
                value: settings.pauseLongMs,
                min: 0,
                max: 2000,
                step: 50,
                onChanged: (v) => settings.update(() => settings.pauseLongMs = v),
              ),

              const Divider(height: 28),

              SwitchListTile(
                title: const Text('Include Synonyms in Auto Play'),
                value: settings.speakSynonyms,
                onChanged: (v) => settings.update(() => settings.speakSynonyms = v),
              ),
              SwitchListTile(
                title: const Text('Include Antonyms in Auto Play'),
                value: settings.speakAntonyms,
                onChanged: (v) => settings.update(() => settings.speakAntonyms = v),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _intStepper({
    required String title,
    String? subtitle,
    required int value,
    required int min,
    required int max,
    int step = 1,
    required ValueChanged<int> onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: value - step >= min ? () => onChanged(value - step) : null,
            icon: const Icon(Icons.remove),
          ),
          Text('$value'),
          IconButton(
            onPressed: value + step <= max ? () => onChanged(value + step) : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
