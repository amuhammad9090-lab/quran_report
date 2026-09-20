import 'package:flutter/material.dart';

/// Icon app (mark hijau berbentuk buku + kubah masjid) — asetnya sendiri
/// sudah berupa kotak membulat (squircle) dengan sudut transparan, jadi
/// cukup ditampilkan langsung pakai [ClipRRect] tanpa dus tambahan.
class AppIconMark extends StatelessWidget {
  final double size;
  final double borderRadius;
  const AppIconMark({super.key, this.size = 84, this.borderRadius = 22});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset('assets/images/app_icon.png', width: size, height: size, fit: BoxFit.cover),
    );
  }
}
