import 'package:flutter/material.dart';
import '../../data/models/enums.dart';
import '../../core/theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final HafalanStatus status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.statusOn(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class KeteranganChip extends StatelessWidget {
  final Keterangan keterangan;
  final bool compact;
  const KeteranganChip({super.key, required this.keterangan, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.keteranganColorOn(context, keterangan.name);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 4 : 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(keterangan.icon, size: compact ? 12 : 14, color: color),
          const SizedBox(width: 4),
          Text(
            compact ? keterangan.shortLabel : keterangan.label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: compact ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }
}
