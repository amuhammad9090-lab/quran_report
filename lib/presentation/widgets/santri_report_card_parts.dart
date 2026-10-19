// Bagian pendukung SantriReportCard: menu aksi (bottom sheet) dan panel info pekan.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../core/utils/week_utils.dart';
import '../../providers/records_provider.dart';

void showSantriCardActions(
  BuildContext context, {
  required SantriCardInfo info,
  required bool isInsideFolder,
  VoidCallback? onPindah,
  VoidCallback? onHapus,
}) {
  final cs = Theme.of(context).colorScheme;
  showModalBottomSheet(
    context: context,
    constraints: const BoxConstraints(maxWidth: 640),
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Material(
          color: Theme.of(ctx).bottomSheetTheme.backgroundColor,
          borderRadius: BorderRadius.circular(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: cs.primaryContainer,
                      child: Text(
                        info.nama.isNotEmpty ? info.nama[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        info.nama,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 18, indent: 18, endIndent: 18),
              if (onPindah != null)
                ListTile(
                  leading: Icon(
                    isInsideFolder ? LucideIcons.folderMinus : LucideIcons.folderInput,
                    color: isInsideFolder ? cs.error : cs.secondary,
                  ),
                  title: Text(
                    isInsideFolder ? 'Keluarkan dari Folder' : 'Pindahkan ke Folder',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    onPindah();
                  },
                ),
              if (onHapus != null)
                ListTile(
                  leading: Icon(LucideIcons.trash2, color: cs.error),
                  title: Text('Hapus',
                      style: TextStyle(fontWeight: FontWeight.w600, color: cs.error)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onHapus();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Panel info satu pekan di bawah kartu santri (laporan hari yang disasar + tombol buka form).
class WeekInfoPanel extends StatelessWidget {
  final SantriCardInfo info;
  final DateTime thisMonth;
  final int weekIndex;
  final void Function(int weekIndex) onTapWeek;
  const WeekInfoPanel({
    super.key,
    required this.info,
    required this.thisMonth,
    required this.weekIndex,
    required this.onTapWeek,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Tanggal yang beneran bakal disasar kalau tombol di panel ini
    // ditekan (onTapWeek -> _openWeek di pemanggil) — SAMA PERSIS logic-nya
    // (pekan berjalan -> hari ini, pekan lewat -> hari Senin pekan itu),
    // biar info & tombol yang ditampilkan gak menjanjikan laporan yang
    // ternyata gak kebuka pas ditekan. Makanya dicek per-HARI PERSIS
    // ([recordForSantriOnDate]) — BUKAN ambil laporan terbaru di pekan itu
    // (bisa beda hari dari yang akan dibuka) — lihat catatan panjang di
    // RecordsProvider.recordForSantriOnDate.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentWeek = WeekUtils.weekOfMonth(now);
    final range = WeekUtils.monthWeekRange(thisMonth, weekIndex);
    final isCurrentWeek = weekIndex == currentWeek &&
        !today.isBefore(range.start) &&
        !today.isAfter(range.end);
    final targetDate = isCurrentWeek ? today : range.start;
    final record = context.watch<RecordsProvider>().recordForSantriOnDate(
          info.nama,
          targetDate,
        );
    final rangeStr = WeekUtils.rangeLabel(range);
    final targetDateLabel = isCurrentWeek
        ? 'Hari ini, ${DateFormat('d MMM yyyy', 'id_ID').format(targetDate)}'
        : DateFormat('EEEE, d MMM yyyy', 'id_ID').format(targetDate);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.calendarDays, size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  'Pekan $weekIndex • $rangeStr',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              targetDateLabel,
              style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            if (record == null)
              Text(
                'Belum ada laporan di hari itu.',
                style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
              )
            else ...[
              Row(
                children: [
                  Icon(LucideIcons.bookmark, size: 14, color: cs.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      record.capaianText,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (record.totalBaris != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      '${record.totalBaris} baris',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.primary),
                    ),
                  ],
                ],
              ),
              if (record.nilai != null && record.nilai!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(LucideIcons.hash, size: 13, color: cs.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Nilai: ${record.nilai!.trim()}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => onTapWeek(weekIndex),
                icon: Icon(record == null ? LucideIcons.circlePlus : LucideIcons.penLine, size: 17),
                label: Text(record == null ? 'Buat Laporan' : 'Lihat / Ubah Laporan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
