import 'package:flutter/material.dart';

class SpeakChip extends StatelessWidget {
  final String text;
  final VoidCallback? onSpeak;
  final String? tooltip;

  const SpeakChip({
    super.key,
    required this.text,
    required this.onSpeak,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final t = text.trim();
    if (t.isEmpty) return const SizedBox.shrink();

    // ✅ ActionChip يجعل "الشيپ كله" قابل للضغط (أفضل من IconButton داخل Chip)
    return Tooltip(
      message: tooltip ?? 'Speak',
      child: ActionChip(
        onPressed: onSpeak,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(t, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 6),
            const Icon(Icons.volume_up, size: 18),
          ],
        ),
      ),
    );
  }
}
