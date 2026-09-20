import 'package:flutter/material.dart';

import '../common/soft_icon_box.dart';

/// Item aksi cepat di dalam [WelcomeHeroCard] (mis. "Tambah Laporan").
class HeroActionItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const HeroActionItem({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SoftIconBox(
                icon: icon,
                color: Colors.white,
                background: Colors.white.withValues(alpha: 0.16),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
