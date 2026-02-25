import 'package:flutter/material.dart';

class SentenceItem extends StatelessWidget {
  final String s2;
  final String s1;
  final bool sameLang;
  final VoidCallback? onSpeakL2;
  final VoidCallback? onSpeakL1;

  const SentenceItem({
    super.key,
    required this.s2,
    required this.s1,
    required this.sameLang,
    required this.onSpeakL2,
    required this.onSpeakL1,
  });

  @override
  Widget build(BuildContext context) {
    final t2 = s2.trim();
    final t1 = s1.trim();

    if (t2.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('• $t2')),
            IconButton(
              tooltip: 'Speak sentence (L2)',
              icon: const Icon(Icons.volume_up),
              onPressed: onSpeakL2,
            ),
          ],
        ),
        if (!sameLang && t1.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 14, bottom: 8),
            child: Row(
              children: [
                Expanded(child: Text(t1, style: TextStyle(color: Colors.grey[800]))),
                IconButton(
                  tooltip: 'Speak sentence (L1)',
                  icon: const Icon(Icons.volume_up),
                  onPressed: onSpeakL1,
                ),
              ],
            ),
          )
        else
          const SizedBox(height: 8),
      ],
    );
  }
}
