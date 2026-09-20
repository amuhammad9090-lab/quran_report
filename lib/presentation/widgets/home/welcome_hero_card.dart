import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Kartu sambutan hijau tua di puncak Home — identitas utama halaman.
/// Opsional menampung baris aksi cepat (mis. Tambah Laporan/Ekspor Data)
/// dipisah garis tipis, meniru layout referensi desain.
class WelcomeHeroCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? actions;
  const WelcomeHeroCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B3B2E), Color(0xFF0E5C46)],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -14,
            top: -6,
            child: Icon(
              LucideIcons.bookOpen,
              size: 96,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              if (actions != null) ...[
                const SizedBox(height: 18),
                Divider(color: Colors.white.withValues(alpha: 0.18), height: 1),
                const SizedBox(height: 18),
                actions!,
              ],
            ],
          ),
        ],
      ),
    );
  }
}
