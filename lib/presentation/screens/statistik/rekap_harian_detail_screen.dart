import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../data/models/santri_record.dart';
import '../../../providers/records_provider.dart';
import '../../widgets/export_style_records_table.dart';
import '../../widgets/misc_widgets.dart';
import 'package:solar_icons/solar_icons.dart';

/// Detail laporan SATU HARI (mis. Senin) dalam sebuah Pekan — dibuka dari
/// tap salah satu baris hari di dalam kartu "Pekan N" yang lagi di-expand
/// pada RekapBulananScreen (lihat `_DayRow`).
class RekapHarianDetailScreen extends StatelessWidget {
  final DateTime date;
  const RekapHarianDetailScreen({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final records = context.select<RecordsProvider, List<SantriRecord>>(
      (p) => p.recordsOnDate(date),
    );
    final provider = context.read<RecordsProvider>();
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
                  icon: SolarIconsBold.calendar,
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
