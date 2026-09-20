import 'package:flutter/material.dart';

import '../common/soft_icon_box.dart';

/// Satu item statistik polos (ikon + angka + label), dipakai berjajar
/// dengan garis pemisah tipis di dalam [SectionCard].
class StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const StatItem({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SoftIconBox(icon: icon, color: color),
        const SizedBox(height: 10),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
