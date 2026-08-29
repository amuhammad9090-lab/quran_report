import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../providers/records_provider.dart';
import '../../widgets/export_style_records_table.dart';
import '../../widgets/misc_widgets.dart';

/// Detail laporan SATU HARI (mis. Senin) dalam sebuah Pekan — dibuka dari
/// tap salah satu baris hari di dalam kartu "Pekan N" yang lagi di-expand
/// pada RekapBulananScreen (lihat `_DayRow`). Isinya laporan hari itu
/// dikelompokkan per Kelas & Halaqoh, ditampilkan sebagai tabel dengan
/// kolom PERSIS sama
/// seperti hasil export (lihat [ExportStyleRecordsTable]) — TIDAK ada
/// tombol export di sini (export rekap pekanan gabungan ada di Generate
/// Laporan Pekanan, lihat GenerateRekapPekananScreen).
class RekapHarianDetailScreen extends StatelessWidget {
  final DateTime date;
  const RekapHarianDetailScreen({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecordsProvider>();
    final records = provider.recordsOnDate(date);
    final groups = provider.groupByKelasHalaqoh(records);
    final hariLabel = DateFormat('EEEE', 'id_ID').format(date);
    final tanggalLabel = DateFormat('d MMMM yyyy', 'id_ID').format(date);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            PushedPageHeader(
              title: hariLabel,
              subtitle: tanggalLabel,
            ),
            if (records.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.event_busy_rounded,
                  title: 'Belum ada laporan',
                  subtitle: 'Tidak ada laporan tercatat di hari ini.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                sliver: SliverList.list(
                  children: [
                    for (final g in groups) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Kelas ${g.kelas} — Halaqoh ${g.halaqoh}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                        ),
                      ),
                      ExportStyleRecordsTable(records: g.records),
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
