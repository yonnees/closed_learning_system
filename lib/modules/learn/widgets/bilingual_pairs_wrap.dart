import 'package:flutter/material.dart';
import 'speak_chip.dart';

class BilingualPairsWrap extends StatelessWidget {
  final String title;

  /// L2 items: [{id, text}]
  final List<Map<String, dynamic>> l2Items;

  /// L1 map by id: id -> text
  final Map<int, String> l1MapById;

  final bool sameLang;

  /// Speak single item: (text, isL2)
  final void Function(String text, bool isL2)? onSpeakSingle;

  const BilingualPairsWrap({
    super.key,
    required this.title,
    required this.l2Items,
    required this.l1MapById,
    required this.sameLang,
    required this.onSpeakSingle,
  });

  @override
  Widget build(BuildContext context) {
    if (l2Items.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final x in l2Items)
                  _Pair(
                    x: x,
                    l1MapById: l1MapById,
                    sameLang: sameLang,
                    onSpeakSingle: onSpeakSingle,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pair extends StatelessWidget {
  final Map<String, dynamic> x;
  final Map<int, String> l1MapById;
  final bool sameLang;
  final void Function(String text, bool isL2)? onSpeakSingle;

  const _Pair({
    required this.x,
    required this.l1MapById,
    required this.sameLang,
    required this.onSpeakSingle,
  });

  @override
  Widget build(BuildContext context) {
    final t2 = (x['text'] ?? '').toString();
    final id = x['id'];
    final t1 = (!sameLang && id is int) ? (l1MapById[id] ?? '') : '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SpeakChip(
          text: t2,
          tooltip: 'Speak (L2)',
          onSpeak: onSpeakSingle == null ? null : () => onSpeakSingle!(t2, true),
        ),
        if (!sameLang && t1.trim().isNotEmpty)
          SpeakChip(
            text: t1,
            tooltip: 'Speak (L1)',
            onSpeak: onSpeakSingle == null ? null : () => onSpeakSingle!(t1, false),
          ),
      ],
    );
  }
}
