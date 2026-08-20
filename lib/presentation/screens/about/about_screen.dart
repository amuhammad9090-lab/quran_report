import 'package:flutter/material.dart';
import '../../../data/services/quran_engine_service.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final engine = QuranEngineService.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Tentang Aplikasi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.auto_stories_rounded,
                  color: Colors.white, size: 42),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Laporan Hafalan',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Versi 1.0.0',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 24),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aplikasi pencatatan laporan capaian hafalan (tahfizh) dan '
                    'bacaan (tahsin) Al-Qur\'an santri, lengkap dengan generator '
                    'baris setoran otomatis berbasis pemetaan baris mushaf rasm '
                    'Utsmani (Madinah 15 baris).',
                    style: TextStyle(fontSize: 13.5, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.dataset_rounded, size: 18, color: cs.primary),
                      const SizedBox(width: 8),
                      const Text('Cakupan Dataset Baris',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    engine.isLoaded ? engine.coverageText() : 'Juz 1-10, 26-30',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    engine.isLoaded
                        ? engine.missingText()
                        : 'Belum tersedia: Juz 11-25',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.memory_rounded, size: 18, color: cs.primary),
                      const SizedBox(width: 8),
                      const Text('Teknologi',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _TechChip(label: 'Flutter'),
                      _TechChip(label: 'Dart'),
                      _TechChip(label: 'Hive'),
                      _TechChip(label: 'Provider'),
                      _TechChip(label: 'PDF & Excel Export'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Dikembangkan oleh',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'A',
                          style: TextStyle(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Arie Muhammad',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14.5),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Developer',
                              style: TextStyle(
                                  fontSize: 12.5, color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: cs.outlineVariant.withValues(alpha: 0.4)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.apartment_rounded,
                          size: 18, color: cs.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text(
                        'Studio',
                        style: TextStyle(
                            fontSize: 12.5, color: cs.onSurfaceVariant),
                      ),
                      const Spacer(),
                      Text(
                        'MiraiLabs',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TechChip extends StatelessWidget {
  final String label;
  const _TechChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: cs.primary,
        ),
      ),
    );
  }
}
