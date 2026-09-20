import 'package:flutter/material.dart';

/// Ikon di dalam kotak bulat bertinta warna — dipakai sebagai leading/prefix
/// yang seragam di semua kolom form (tanggal, dropdown, input teks) biar
/// "satu bahasa desain" dari atas sampai bawah.
class FieldIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const FieldIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 38,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.29),
      ),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}
