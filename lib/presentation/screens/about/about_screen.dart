import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/quran_engine_service.dart';
import '../../widgets/misc_widgets.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final engine = QuranEngineService.instance;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const PushedPageHeader(
              title: 'Tentang Aplikasi',
              titleFontSize: 17,
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              sliver: SliverList.list(
                children: [
                  const _HeroCard(),
                  const SizedBox(height: 20),
                  const _AboutDescriptionCard(),
                  const SizedBox(height: 16),
                  Card(
                    child: Column(
                      children: [
                        const _InfoRow(
                          icon: Icons.person_outline_rounded,
                          label: 'Developer',
                          value: 'Arie Muhammad',
                        ),
                        _rowDivider(context),
                        const _InfoRow(
                          icon: Icons.apartment_rounded,
                          label: 'Studio',
                          value: 'MiraiLabs',
                        ),
                        _rowDivider(context),
                        const _InfoRow(
                          icon: Icons.memory_rounded,
                          label: 'Technology',
                          value: 'Flutter • Dart • Provider • Hive • Firebase',
                        ),
                        _rowDivider(context),
                        const _InfoRow(
                          icon: Icons.flag_outlined,
                          label: 'Focus',
                          value: 'Akurasi • Kemudahan • Kecepatan',
                        ),
                        _rowDivider(context),
                        _InfoRow(
                          icon: Icons.dataset_rounded,
                          label: 'Cakupan Dataset Baris',
                          value: engine.isLoaded
                              ? engine.coverageText()
                              : 'Juz 1-10, 26-30',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const _Footer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _rowDivider(BuildContext context) => Divider(
        height: 1,
        indent: 18,
        endIndent: 18,
        color: Theme.of(context).dividerTheme.color,
      );
}

/// Kartu identitas utama
class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = isDark
        ? const [Color(0xFF0B3B2E), Color(0xFF0E5C46)]
        : const [AppColors.splashGradientStart, AppColors.splashGradientEnd];

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -22,
              child: Icon(
                Icons.nights_stay_rounded,
                size: 140,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            Positioned(
              left: -22,
              bottom: -26,
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 84,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const AppIconMark(size: 66, borderRadius: 16),
                        ),
                        const SizedBox(width: 14),
                        Container(
                          height: 40,
                          width: 1,
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                        const SizedBox(width: 14),
                        const SmpitLogoBadge(size: 62, borderRadius: 15),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Quran Report',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Powered by SMPIT Al Madinah\nTanjungpinang',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                      ),
                      child: const Text(
                        'Versi 1.0.0',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu deskripsi "Tentang" — paragrafnya di-justify (rata kanan-kiri)
/// sesuai permintaan, biar terasa lebih rapi & formal kayak dokumen resmi
/// (bukan rata kiri biasa yang pinggir kanannya berantakan).
class _AboutDescriptionCard extends StatelessWidget {
  const _AboutDescriptionCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SoftIconBox(
                  icon: Icons.info_outline_rounded,
                  color: cs.primary,
                  size: 16,
                  padding: 8,
                  radius: 10,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Tentang',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Laporan Hafalan adalah aplikasi pencatatan capaian hafalan '
              '(tahfizh) dan bacaan (tahsin) Al-Qur\'an santri, lengkap dengan '
              'generator baris setoran otomatis berbasis pemetaan baris mushaf '
              'rasm Utsmani (Madinah 15 baris).',
              textAlign: TextAlign.justify,
              style: TextStyle(fontSize: 14.5, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Baris info ikon + label + value — polanya niru referensi desain
/// (icon, label kecil, value bold di bawahnya), tapi warna & bentuk kotak
/// ikon tetap pakai aturan UI aplikasi ini (soft tint, bukan flat icon).
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SoftIconBox(icon: icon, color: cs.primary, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14.5, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Footer penutup — quote-nya sekarang dikasih garis kecil kiri-kanan
/// (gaya "pull quote"), lebih terasa seperti aksen tipografi yang
/// disengaja, bukan sekadar teks italic nyempil di bawah.
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(Icons.favorite_rounded, color: cs.error, size: 20),
        const SizedBox(height: 10),
        const Text(
          'Dibuat untuk kemudahan para guru pembimbing',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
        ),
        const SizedBox(height: 6),
        Text(
          '© 2026 MiraiLabs  •  Arie Muhammad',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 22, height: 1, color: cs.outlineVariant),
            const SizedBox(width: 10),
            Text(
              '"Mudah. Terstruktur. Istiqomah."',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 10),
            Container(width: 22, height: 1, color: cs.outlineVariant),
          ],
        ),
      ],
    );
  }
}
