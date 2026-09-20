import 'package:flutter/material.dart';

/// Kartu section form (Tanggal, Identitas Santri, Status Capaian,
/// Keterangan, dst) — judul kecil + ikon di atas, konten di bawah, dibungkus
/// card senada dengan card lain di aplikasi (bukan cuma label polos).
class FormSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const FormSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: cs.primary),
                const SizedBox(width: 7),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}
