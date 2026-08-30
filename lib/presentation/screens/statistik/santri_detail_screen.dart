import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'package:provider/provider.dart';

import '../../../data/models/enums.dart';
import '../../../data/models/santri_record.dart';
import '../../../providers/records_provider.dart';
import '../../widgets/misc_widgets.dart';
import '../../widgets/status_badge.dart';
import '../record_form/record_form_sheet.dart';

/// Riwayat lengkap satu santri, dikelompokkan per tanggal dalam card
/// (senada gaya grouping di Home) — bukan list detail penuh seperti tab
/// Laporan, cuma ringkasan status + capaian + keterangan per hari.
class SantriDetailScreen extends StatelessWidget {
  final String namaAnak;
  const SantriDetailScreen({super.key, required this.namaAnak});

  @override
  Widget build(BuildContext context) {
    // select, bukan watch<RecordsProvider>() polos: sekarang recordsForSantri
    // sudah di-cache stabil per _dataVersion, jadi halaman ini cuma rebuild
    // kalau data SANTRI INI beneran berubah, bukan tiap notifyListeners
    // provider (mis. filter/search berubah di tab Laporan).
    final records = context.select<RecordsProvider, List<SantriRecord>>(
      (p) => p.recordsForSantri(namaAnak),
    );
    final provider = context.read<RecordsProvider>();
    Theme.of(context).colorScheme;

    final grouped = provider.groupByDate(records);
    final dates = grouped.keys.toList();
    final latest = records.isNotEmpty ? records.first : null;

    final totalTahfizh = records.where((r) => r.status == HafalanStatus.tahfizh).length;
    final totalTahsin = records.where((r) => r.status == HafalanStatus.tahsin).length;
    final totalBaris = records.fold<int>(0, (sum, r) => sum + (r.totalBaris ?? 0));

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            PushedPageHeader(
              title: namaAnak,
              subtitle: latest != null ? 'Kelas ${latest.kelas} • Halaqoh ${latest.halaqoh}' : null,
            ),
            if (records.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.inbox_rounded,
                  title: 'Belum ada laporan',
                  subtitle: 'Santri ini belum punya catatan laporan.',
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: SummaryStatCard(
                          label: 'Tahfizh',
                          value: '$totalTahfizh',
                          icon: Icons.auto_stories_rounded,
                          color: AppColors.tahfizhOn(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SummaryStatCard(
                          label: 'Tahsin',
                          value: '$totalTahsin',
                          icon: Icons.menu_book_rounded,
                          color: AppColors.tahsinOn(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SummaryStatCard(
                          label: 'Total Baris',
                          value: '$totalBaris',
                          icon: Icons.format_list_numbered_rounded,
                          color: AppColors.purpleOn(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                sliver: SliverList.separated(
                  itemCount: dates.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final date = dates[i];
                    final items = grouped[date]!;
                    return DateGroupCard(
                      date: date,
                      rows: items
                          .map((r) => RecordSummaryRow(
                                statusIcon: r.status.icon,
                                statusColor: AppColors.statusOn(context, r.status),
                                statusLabel: r.status.label,
                                capaianText: r.capaianText,
                                keteranganChip:
                                    KeteranganChip(keterangan: r.keterangan, compact: true),
                                onTap: () => showRecordFormSheet(context, existing: r),
                                isEdited: r.isEdited,
                              ))
                          .toList(),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
