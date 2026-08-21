import 'package:flutter/material.dart';
import '../../../data/services/quran_engine_service.dart';
import '../../widgets/misc_widgets.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final engine = QuranEngineService.instance;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const PushedPageHeader(
              title: 'Tentang Aplikasi',
              subtitle: 'Informasi seputar aplikasi ini',
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              sliver: SliverList.list(
                children: [
          Center(
            child: Container(
              width: 96,
              height: 96,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.auto_stories_rounded,
                    color: Colors.white, size: 34),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Laporan Hafalan',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Versi 1.0.0',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 18, color: cs.primary),
                      const SizedBox(width: 8),
                      const Text('Tentang',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Laporan Hafalan adalah aplikasi pencatatan capaian hafalan '
                    '(tahfizh) dan bacaan (tahsin) Al-Qur\'an santri, lengkap dengan '
                    'generator baris setoran otomatis berbasis pemetaan baris mushaf '
                    'rasm Utsmani (Madinah 15 baris).',
                    style: TextStyle(fontSize: 13.5, height: 1.55),
                  ),
                ],
              ),
            ),
          ),
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
                  value: 'Flutter • Dart • Provider • Hive',
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
          const SizedBox(height: 28),
          // Footer penutup — dirapikan jadi satu grup dengan ritme spacing
          // presisi (10 / 6 / 6 / 14), baris copyright & credit digabung
          // satu baris biar nggak dempet dan nggak dobel-center.
          Center(
            child: Column(
              children: [
                Icon(Icons.favorite_rounded, color: cs.error, size: 22),
                const SizedBox(height: 10),
                const Text(
                  'Dibuat untuk kemudahan para musyrif/ah',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                const SizedBox(height: 6),
                Text(
                  '© 2026 MiraiLabs  •  Arie Muhammad',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                Text(
                  '"Mudah. Terstruktur. Istiqomah."',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 12.5,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
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
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13.5, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
