import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/services/quran_engine_service.dart';

/// Panel "Kolom Baris" hasil generate baris Tahfizh: total baris baru, info baris yang sudah
/// pernah dihitung (tidak dihitung dobel), dan daftar baris baru (Hal. X — Baris Y).
class GeneratedLinesPanel extends StatelessWidget {
  final GeneratedLinesResult result;

  const GeneratedLinesPanel({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      // Material(shape) — bukan Container(decoration) — supaya ListTile "Hal. X — Baris Y"
      // di dalamnya (ListView di bawah) punya Material terdekat yang benar dan tidak
      // tertutup DecoratedBox; tampilan background+border tetap identik.
      color: cs.primaryContainer.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Icon(LucideIcons.list, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kolom Baris',
                    style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${result.totalBaris} baris baru',
                    style: TextStyle(
                        color: cs.onPrimary, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          if (result.alreadyCountedLines.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.history, size: 15, color: AppColors.tahsinOn(context)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${result.alreadyCountedLines.length} baris sudah pernah dihitung di laporan sebelumnya (tidak dihitung dobel)',
                        style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.tahsinOn(context),
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (result.newLines.isEmpty && result.alreadyCountedLines.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Text(
                'Semua baris di rentang ini sudah pernah dihitung sebelumnya.',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ),
          if (result.newLines.isNotEmpty) ...[
            const Divider(height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: result.newLines.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 14, endIndent: 14),
                itemBuilder: (context, i) {
                  final l = result.newLines[i];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 13,
                      backgroundColor: cs.primary.withValues(alpha: 0.15),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700, color: cs.primary),
                      ),
                    ),
                    title: Text('Hal. ${l.pageNumber} — Baris ${l.lineNumber}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(l.ayatRangeText, style: const TextStyle(fontSize: 12)),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
