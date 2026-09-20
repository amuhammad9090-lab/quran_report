import 'package:flutter/material.dart';

/// Kotak ikon bertinta lembut — satu-satunya gaya "ikon dalam kotak warna soft"
/// di seluruh aplikasi (Home, form, pengaturan, tentang).
/// Jangan bikin versi manual lain di file screen.
class SoftIconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color? background;
  final double size;
  final double padding;
  final double radius;

  const SoftIconBox({
    super.key,
    required this.icon,
    required this.color,
    this.background,
    this.size = 20,
    this.padding = 9,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, size: size, color: color),
    );
  }
}
