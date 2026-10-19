import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../widgets/common/soft_icon_box.dart';

/// Banner "lagi difilter tanggal X" — tampil kalau [RecordsProvider.filterDate]
/// aktif (mis. abis tap "Lihat Semua" di kartu "Ringkasan Hari Ini" pada tab
/// Home, lihat `BerandaTab.goToToday`).
///
/// BUG FIX: sebelumnya filter tanggal ini SAMA SEKALI tidak kelihatan di tab
/// Laporan (cuma titik merah generik di ikon filter, dan filter tanggal juga
/// tidak muncul sebagai chip apa pun di [FilterSheet]) — jadi begitu user
/// tap "Lihat Semua" dari Home, tab Laporan diam-diam KETERUSAN cuma
/// nampilin laporan hari itu doang, tapi user nggak sadar kenapa (kelihatan
/// kayak tab Laporan "nyangkut" di satu tanggal terus tiap dibuka, sampai
/// nggak sengaja ketemu tombol "Reset" di Filter Lainnya yang nge-reset
/// SEMUA filter sekaligus, bukan cuma tanggalnya). Banner ini bikin filter
/// tanggal EKSPLISIT kelihatan + ada tombol hapus KHUSUS buat filter ini
/// saja (filter lain seperti Status/Kelas/Halaqoh tetap dibiarkan aktif).
class DateFilterBanner extends StatelessWidget {
  final DateTime date;
  final VoidCallback onClear;
  const DateFilterBanner({super.key, required this.date, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final label = isToday
        ? 'Hari ini — ${DateFormat('d MMMM yyyy', 'id_ID').format(date)}'
        : DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date);

    return Material(
      color: cs.primary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(LucideIcons.calendarDays, size: 18, color: cs.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Menampilkan laporan tanggal: $label',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: cs.primary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            InkWell(
              onTap: onClear,
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(LucideIcons.circleX, size: 16, color: cs.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Banner peringatan yang tampil di tab Laporan begitu ada kartu santri
/// yang folder tujuannya sudah tidak ada lagi (lihat
/// [RecordsProvider.orphanedFolderCards] dan [OrphanedRecordsScreen]).
class OrphanedRecordsBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const OrphanedRecordsBanner({super.key, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.errorContainer.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              SoftIconBox(icon: LucideIcons.folderMinus, color: cs.error),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$count kartu tanpa folder',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: cs.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Laporannya masih aman. Tekan untuk pindahkan ke folder lain.',
                      style: TextStyle(fontSize: 11.5, color: cs.onErrorContainer.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, color: cs.onErrorContainer),
            ],
          ),
        ),
      ),
    );
  }
}
