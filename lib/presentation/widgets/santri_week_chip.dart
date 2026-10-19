import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/utils/week_utils.dart';

/// Satu kolom "PEKAN N" — 3 kemungkinan tampilan: sudah ada laporan
/// (centang hijau), pekan berjalan tapi belum diisi (outline "+", diajak
/// isi), atau pekan lain yang belum diisi (netral, angka pekan biasa).
/// Tap = toggle panel info pekan itu (lihat [SantriReportCard]), BUKAN
/// langsung buka form lagi -- makanya outline ganti warna kalau
/// [isExpanded] true, biar user tau panel yang lagi kebuka pekan mana.
class WeekChip extends StatelessWidget {
  final int weekIndex;
  final bool filled;
  final bool isCurrent;
  final bool isExpanded;
  final MonthWeekRange range;
  final VoidCallback? onTap;

  const WeekChip({super.key, 
    required this.weekIndex,
    required this.filled,
    required this.isCurrent,
    required this.isExpanded,
    required this.range,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = (filled || isCurrent || isExpanded) ? cs.primary : cs.onSurfaceVariant;
    // <-- BERUBAH: sebelumnya "filled" (pekan udah diisi) pakai tint yang
    // SAMA level-nya (alpha 0.12) kayak _ActionChip (tombol "Buat
    // Laporan"/"Tambah Laporan" di atasnya, alpha 0.08) — dua-duanya sama
    // warna (cs.primary) dan sama-sama flat tanpa border, jadi kurang
    // kebeda pas dipandang sekilas walau maksudnya beda (satu tombol aksi,
    // satu status "sudah kelar"). Dinaikin tint-nya + dikasih border tipis
    // KHUSUS pas filled, biar kerasa kayak badge yang "solid/mantap" —
    // tetap satu keluarga warna (cs.primary/ijo brand), cuma levelnya
    // dibedain, bukan gonta-ganti hue.
    final bg = filled
        ? cs.primary.withValues(alpha: 0.18)
        : (isCurrent ? cs.primary.withValues(alpha: 0.06) : cs.surfaceContainerHighest.withValues(alpha: 0.35));

    // Prioritas border: expanded (lagi dibuka) & current-belum-diisi
    // (ajakan "isi sekarang") tetap paling nonjol seperti sebelumnya —
    // border tebal solid. Filled (sudah diisi, kondisi diam/tidak lagi
    // butuh perhatian) dapat border tipis transparan, sekadar penegas
    // "badge", bukan ajakan aksi.
    final Border? border;
    if (isExpanded || (isCurrent && !filled)) {
      border = Border.all(color: cs.primary, width: 1.3);
    } else if (filled) {
      border = Border.all(color: cs.primary.withValues(alpha: 0.35), width: 1);
    } else {
      border = null;
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: border,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                filled ? LucideIcons.circleCheck : (isCurrent ? LucideIcons.circlePlus : Icons.circle_outlined),
                size: 15,
                color: accent,
              ),
              const SizedBox(height: 3),
              Text(
                'P$weekIndex',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: accent),
              ),
              Text(
                '${range.start.day}-${range.end.day}',
                style: TextStyle(fontSize: 8.5, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
