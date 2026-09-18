import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/week_utils.dart';
import '../../../data/models/santri_record.dart';
import '../../../data/services/export_service.dart';
import '../../../data/services/weekly_recap_deploy_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/records_provider.dart';
import '../../widgets/misc_widgets.dart';
import '../../widgets/weekly_santri_recap_table.dart';
import '../export/export_sheet.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Hasil "Generate Laporan Pekanan" — menghimpun SEMUA laporan sepekan
/// (semua hari, semua Kelas & Halaqoh), dikelompokkan per Kelas+Halaqoh
/// (tiap grup = 1 tabel kecil), dibuka dari tombol "Generate Laporan
/// Pekanan" di dalam kartu "Pekan N" yang lagi di-expand pada
/// RekapBulananScreen (lihat `_PekanExpandedBody`).
///
/// Beda dari tabel harian (lihat ExportStyleRecordsTable &
/// RekapHarianDetailScreen, yang 1 baris = 1 laporan): tabel di sini
/// (baik yang ditampilkan di layar lewat [WeeklySantriRecapTable] maupun
/// hasil export-nya) 1 baris = 1 SANTRI — semua laporannya sepekan
/// digabung: kolom Capaian dipecah per jenis (Tahsin/Tahfizh/
/// Tahsin+Tahfizh/Muroja'ah, masing2 cuma tampil kalau memang ada
/// tertulis di laporan hariannya) dan kolom Baris di-SUM dari SEMUA
/// laporan santri itu sepekan (lihat
/// ExportService.weeklyRowsGroupedBySantriFor). Kolom "Hari/Tanggal"
/// menunjukkan tanggal laporan TERAKHIR MILIK SANTRI ITU SENDIRI dalam
/// pekan tsb — jadi tiap santri bisa beda tanggal sesuai kapan dia
/// terakhir setor. (Dulu semua baris dipaksa memakai SATU tanggal
/// lintas kelas; lihat catatan bug di [_lastFilledLabel].)
///
/// Hasil export-nya 1 dokumen berisi semua grup (1 tabel per Kelas+
/// Halaqoh, bukan 1 tabel besar gabungan) + baris Guru Pembimbing per
/// grup kalau ada (lihat ExportService.exportGroupedPdf/Word/Excel).
class GenerateRekapPekananScreen extends StatelessWidget {
  final List<SantriRecord> records;
  final int weekIndex;
  final String bulanLabel;
  final String rangeLabel;
  final MonthWeekRange range;
  const GenerateRekapPekananScreen({
    super.key,
    required this.records,
    required this.weekIndex,
    required this.bulanLabel,
    required this.rangeLabel,
    required this.range,
  });

  /// Label tanggal laporan TERAKHIR di pekan ini, digabung dari SEMUA
  /// kelas/halaqoh — HANYA untuk teks informasi di header layar
  /// ("terakhir diisi ..."), BUKAN untuk mengisi kolom Hari/Tanggal
  /// tiap baris santri.
  ///
  /// --- CATATAN BUG "semua santri & semua kelas tanggalnya sama" ---
  /// Dulu nilai ini dikirim sebagai `fixedTanggalLabel` ke
  /// [WeeklySantriRecapTable], `showExportSheet`, DAN
  /// `weeklyRowsGroupedBySantriFor` — akibatnya SATU tanggal (tanggal
  /// laporan paling akhir di seluruh pekan, lintas kelas) menimpa kolom
  /// Hari/Tanggal SEMUA baris. Jadi kalau ada kelas lain yang setor hari
  /// Rabu, santri yang sebenarnya setor hari Selasa pun ikut tertulis
  /// Rabu — di preview, di hasil export, DAN di rekap yang dikirim ke
  /// Portal Ortu (`tanggalLabel` di dokumen `weeklyRecaps`).
  ///
  /// SEKARANG: `fixedTanggalLabel` sengaja TIDAK dipakai lagi di layar
  /// ini (dibiarkan null), supaya
  /// [ExportService.weeklyRowsGroupedBySantriFor] memakai perilaku
  /// fallback-nya yang memang sudah benar: tanggal laporan TERAKHIR
  /// MILIK SANTRI ITU SENDIRI di pekan tsb. Parameternya sendiri tidak
  /// dihapus dari ExportService/WeeklySantriRecapTable karena masih
  /// dipakai layar lain (Rekap Harian) yang memang butuh 1 tanggal
  /// seragam.
  String? _lastFilledLabel(List<SantriRecord> all) {
    if (all.isEmpty) return null;
    final latest = all.reduce((a, b) => a.tanggal.isAfter(b.tanggal) ? a : b);
    return ExportService.instance.hariTanggalTextFor(latest.tanggal);
  }

  @override
  Widget build(BuildContext context) {
    // read, bukan watch: `records` sudah dikirim lewat constructor (bukan
    // ditarik dari provider), dan groupByKelasHalaqoh() murni fungsi dari
    // argumennya (tidak baca state RecordsProvider) — jadi widget ini
    // sebenarnya tidak pernah perlu ikut rebuild waktu RecordsProvider
    // notifyListeners() (mis. filter/search di layar lain).
    final recordsProvider = context.read<RecordsProvider>();
    final authProvider = context.watch<AuthProvider>();

    final sorted = List<SantriRecord>.from(records)
      ..sort((a, b) {
        final byDate = a.tanggal.compareTo(b.tanggal);
        if (byDate != 0) return byDate;
        return a.namaAnak.toLowerCase().compareTo(b.namaAnak.toLowerCase());
      });
    final lastFilledLabel = _lastFilledLabel(sorted);
    final groups = recordsProvider.groupByKelasHalaqoh(sorted);
    final periodeText = WeekUtils.periodeLabel(weekIndex, range);

    final exportSections = [
      for (final g in groups)
        ExportKelasHalaqohSection<SantriRecord>(
          kelas: g.kelas,
          halaqoh: g.halaqoh,
          guruPembimbing: authProvider.guruPembimbingNameFor(g.kelas, g.halaqoh),
          items: g.records,
        ),
    ];

    // <-- BARU: dihitung sekali di sini (bukan inline di dalam onDeploy)
    // biar bisa dipakai DUA kali -- buat body deploy-nya sendiri DAN
    // buat nampilin jumlah santri di snackbar/tooltip _DeployChip --
    // tanpa nge-generate rows-nya dua kali per grup.
    final weeklyRowsPerGroup = [
      for (final g in groups)
        // TANPA fixedTanggalLabel — tiap santri pakai tanggal laporan
        // terakhirnya sendiri (lihat catatan bug di [_lastFilledLabel]).
        ExportService.instance.weeklyRowsGroupedBySantriFor(g.records),
    ];

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            PushedPageHeader(
              title: 'Generate Laporan Pekanan',
              subtitle: 'Pekan $weekIndex • $rangeLabel • $bulanLabel',
            ),
            if (sorted.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: LucideIcons.wandSparkles,
                  title: 'Belum ada laporan untuk digabung',
                  subtitle: 'Isi dulu laporan santri di salah satu hari pekan ini.',
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    '${sorted.length} laporan • ${groups.length} kelompok Kelas/Halaqoh'
                        '${lastFilledLabel != null ? ' • terakhir diisi $lastFilledLabel' : ''}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                sliver: SliverList.list(
                  children: [
                    for (var i = 0; i < groups.length; i++) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Kelas ${groups[i].kelas}',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Halaqoh ${groups[i].halaqoh}',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            AppActionChip(
                              icon: LucideIcons.upload,
                              label: 'Export',
                              color: AppColors.deployOn(context),
                              tooltip: 'Export Kelas ${groups[i].kelas} — Halaqoh ${groups[i].halaqoh}',
                              onTap: () => showExportSheet(
                                context,
                                groupedSections: [exportSections[i]],
                                judul: 'Laporan Pekanan - Kelas ${groups[i].kelas} '
                                    'Halaqoh ${groups[i].halaqoh} - Pekan $weekIndex $bulanLabel',
                                periode: '$periodeText'
                                    '${lastFilledLabel != null ? ' (terakhir diisi $lastFilledLabel)' : ''}',
                                includeTanggal: true,
                                // fixedTanggalLabel SENGAJA tidak diisi —
                                // tiap santri pakai tanggalnya sendiri.
                              ),
                            ),
                            const SizedBox(width: 8),
                            _DeployChip(
                              tooltip: 'Kirim rekap Kelas ${groups[i].kelas} — Halaqoh '
                                  '${groups[i].halaqoh} ke Portal Ortu',
                              santriCount: weeklyRowsPerGroup[i].length,
                              onDeploy: () => WeeklyRecapDeployService.instance.deployWeeklyRecap(
                                kelas: groups[i].kelas,
                                halaqoh: groups[i].halaqoh,
                                weekIndex: weekIndex,
                                bulanLabel: bulanLabel,
                                rangeLabel: rangeLabel,
                                periode: periodeText,
                                guruPembimbing: authProvider.guruPembimbingNameFor(
                                  groups[i].kelas,
                                  groups[i].halaqoh,
                                ),
                                rows: weeklyRowsPerGroup[i],
                                deployedByNama: authProvider.currentUser?.displayName,
                                weekStart: range.start,
                                weekEnd: range.end,
                              ),
                            ),
                          ],
                        ),
                      ),
                      WeeklySantriRecapTable(
                        records: groups[i].records,
                        // fixedTanggalLabel SENGAJA tidak diisi — lihat
                        // catatan bug di [_lastFilledLabel].
                      ),
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
/// Tombol "Deploy" — kirim rekap pekanan 1 Kelas+Halaqoh ke Firestore
/// (buat Portal Ortu, lihat [WeeklyRecapDeployService]). Beda dari
/// Export yang instan (langsung buka sheet, tidak ada proses async),
/// Deploy butuh nunggu round-trip ke Firestore.
class _DeployChip extends StatefulWidget {
  final String tooltip;
  final int santriCount;
  final Future<void> Function() onDeploy;
  const _DeployChip({
    required this.tooltip,
    required this.santriCount,
    required this.onDeploy,
  });

  @override
  State<_DeployChip> createState() => _DeployChipState();
}

class _DeployChipState extends State<_DeployChip> {
  bool _loading = false;

  Future<void> _handleTap() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.onDeploy();
      if (!mounted) return;
      // <-- BERUBAH: ikut nampilin jumlah santri yang barusan terkirim
      // (grup Kelas+Halaqoh ini doang, bukan seluruh sekolah).
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Rekap pekanan terkirim ke Portal Ortu (${widget.santriCount} santri).',
          ),
        ),
      );
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Waktu habis (20 detik), server tidak merespons. Cek koneksi internet, lalu coba lagi.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal kirim: $e. Cek koneksi internet, lalu coba lagi.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deployColor = AppColors.deployOn(context);
    return AppActionChip(
      icon: LucideIcons.cloudUpload,
      label: 'Kirim',
      color: deployColor,
      tooltip: widget.tooltip,
      onTap: _loading ? null : _handleTap,
      leadingOverride: _loading
          ? SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2, color: deployColor),
            )
          : null,
    );
  }
}
