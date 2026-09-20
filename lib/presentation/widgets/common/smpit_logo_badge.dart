import 'package:flutter/material.dart';

/// Logo SMPIT Al Madinah, selalu persegi (1:1). Default dibungkus kartu putih agar
/// terbaca di background apa pun; matikan [withBackground] untuk Splash
/// yang sudah gradient hijau.
class SmpitLogoBadge extends StatelessWidget {
  final double size;
  final bool withBackground;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const SmpitLogoBadge({
    super.key,
    this.size = 56,
    this.withBackground = true,
    this.padding = const EdgeInsets.all(8),
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final logo = Image.asset('assets/images/logo_smpit.png', fit: BoxFit.contain);

    if (!withBackground) {
      return SizedBox(width: size, height: size, child: logo);
    }

    return Container(
      width: size,
      height: size,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: logo,
    );
  }
}
