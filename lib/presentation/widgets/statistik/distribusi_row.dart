import 'package:flutter/material.dart';

/// Satu baris distribusi keterangan (mis. "Hadir • 12 laporan • 80%" +
/// bar progres) — dipakai [StatistikTab] & [RekapBulananScreen] (dulu
/// ke-copy identik di dua tempat, sekarang cukup satu sumber di sini).
class DistribusiRow extends StatelessWidget {
  final String label;
  final int count;
  final double ratio;
  final Color color;

  const DistribusiRow({
    super.key,
    required this.label,
    required this.count,
    required this.ratio,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const Spacer(),
            Text(
              '$count laporan • ${(ratio * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}
