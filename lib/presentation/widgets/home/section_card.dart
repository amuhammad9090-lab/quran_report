import 'package:flutter/material.dart';

/// Kartu putih dengan judul + tautan "Lihat Semua" — bungkus untuk section
/// seperti "Ringkasan Hari Ini" dan "Kategori Cepat".
class SectionCard extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  final Widget child;

  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.onSeeAll,
  });

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
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
                  ),
                ),
                if (onSeeAll != null)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onSeeAll,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          'Lihat Semua',
                          style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
