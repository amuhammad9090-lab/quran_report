import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/week_utils.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/santri_monthly_recap.dart';
import '../../../data/services/download_notification_service.dart';
import '../../../data/services/export_service.dart';
import '../../../providers/records_provider.dart';
import '../../widgets/misc_widgets.dart';

/// Hasil "Generate" dari Rekap Bulanan — menghimpun laporan tiap santri
/// dari Pekan 1 s/d Pekan terakhir bulan itu jadi SATU baris per santri,
/// supaya guru pembimbing bisa lihat progres sebulan penuh sekaligus
/// tanpa bolak-balik buka tiap Pekan. Bisa langsung diekspor lewat tombol
/// di pojok kanan atas (PDF/Word/Excel, format tabel Nama x Pekan).
///
/// Daftarnya dikelompokkan per Kelas & Halaqoh (bukan list nama santri
/// campur semua) — tiap kelompok dapat tabelnya sendiri, biar guru
/// pembimbing bisa langsung lihat/scroll kelompoknya sendiri tanpa perlu
/// nyari-nyari di antara ratusan santri kelas/halaqoh lain.
class GenerateRekapBulananScreen extends StatelessWidget {
  final DateTime month;
  const GenerateRekapBulananScreen({super.key, required this.month});

  /// Kelompokkan [recaps] per pasangan Kelas+Halaqoh, urut alfabetis
  /// (kelas dulu, baru halaqoh); dalam tiap kelompok urut nama santri.
  Map<String, List<SantriMonthlyRecap>> _groupByKelasHalaqoh(List<SantriMonthlyRecap> recaps) {
    final map = <String, List<SantriMonthlyRecap>>{};
    for (final r in recaps) {
      final key = '${r.kelas}||${r.halaqoh}';
      map.putIfAbsent(key, () => []).add(r);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));
    }
    final sortedKeys = map.keys.toList()
      ..sort((a, b) {
        final pa = a.split('||');
        final pb = b.split('||');
        final byKelas = pa[0].compareTo(pb[0]);
        return byKelas != 0 ? byKelas : pa[1].compareTo(pb[1]);
      });
    return {for (final k in sortedKeys) k: map[k]!};
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecordsProvider>();
    final recaps = provider.monthlySantriRecaps(month);
    final totalWeeks = WeekUtils.weeksInMonth(month);
    final bulanLabel = DateFormat('MMMM yyyy', 'id_ID').format(month);
    final groups = _groupByKelasHalaqoh(recaps);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            PushedPageHeader(
              title: 'Generate Rekap Bulanan',
              subtitle: bulanLabel,
              trailing: recaps.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () => _showMonthlyExportSheet(
                        context,
                        recaps: recaps,
                        totalWeeks: totalWeeks,
                        bulanLabel: bulanLabel,
                      ),
                      icon: const Icon(Icons.ios_share_rounded),
                      tooltip: 'Export Rekap Bulanan',
                    ),
            ),
            if (recaps.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Belum ada capaian untuk digabung',
                  subtitle:
                      'Isi dulu laporan santri di salah satu Pekan bulan ini, baru rekap bulanan bisa di-generate.',
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    '${recaps.length} santri • gabungan Pekan 1-$totalWeeks',
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
                    for (final entry in groups.entries) ...[
                      _KelasHalaqohHeader(
                        kelas: entry.value.first.kelas,
                        halaqoh: entry.value.first.halaqoh,
                        count: entry.value.length,
                      ),
                      const SizedBox(height: 8),
                      _MonthlyRecapTable(recaps: entry.value, totalWeeks: totalWeeks),
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

class _KelasHalaqohHeader extends StatelessWidget {
  final String kelas;
  final String halaqoh;
  final int count;
  const _KelasHalaqohHeader({required this.kelas, required this.halaqoh, required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        SoftIconBox(icon: Icons.groups_2_rounded, color: cs.primary, size: 15, padding: 7, radius: 10),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Kelas $kelas • Halaqoh $halaqoh',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '$count santri',
          style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

Future<void> _showMonthlyExportSheet(
  BuildContext context, {
  required List<SantriMonthlyRecap> recaps,
  required int totalWeeks,
  required String bulanLabel,
}) {
  return showModalBottomSheet(
    context: context,
    constraints: const BoxConstraints(maxWidth: 640),
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MonthlyExportSheet(
      recaps: recaps,
      totalWeeks: totalWeeks,
      bulanLabel: bulanLabel,
    ),
  );
}

class _MonthlyExportSheet extends StatefulWidget {
  final List<SantriMonthlyRecap> recaps;
  final int totalWeeks;
  final String bulanLabel;

  const _MonthlyExportSheet({
    required this.recaps,
    required this.totalWeeks,
    required this.bulanLabel,
  });

  @override
  State<_MonthlyExportSheet> createState() => _MonthlyExportSheetState();
}

// `with InlineMessageMixin` — sheet ini SENGAJA tidak punya Scaffold
// sendiri (sama seperti ExportSheet), jadi ScaffoldMessenger.of(context)
// bakal nemu Scaffold HALAMAN DI BALIK sheet ini dan pesannya kegambar
// ketutup di belakang, gak kelihatan user. Lihat InlineMessageMixin buat
// penjelasan lengkap.
class _MonthlyExportSheetState extends State<_MonthlyExportSheet> with InlineMessageMixin<_MonthlyExportSheet> {
  bool _loading = false;
  ExportFormat? _loadingFormat;
  File? _exportedFile;
  ExportFormat? _exportedFormat;

  String _extFor(ExportFormat f) => switch (f) {
        ExportFormat.pdf => 'pdf',
        ExportFormat.word => 'docx',
        ExportFormat.excel => 'xlsx',
      };

  Future<void> _doExport(ExportFormat format) async {
    setState(() {
      _loading = true;
      _loadingFormat = format;
    });

    try {
      final judul = 'Rekap Bulanan - ${widget.bulanLabel}';
      File file;
      switch (format) {
        case ExportFormat.pdf:
          file = await ExportService.instance.exportMonthlyRecapPdf(
            widget.recaps,
            judul: judul,
            totalWeeks: widget.totalWeeks,
            periode: widget.bulanLabel,
          );
          break;
        case ExportFormat.word:
          file = await ExportService.instance.exportMonthlyRecapWord(
            widget.recaps,
            judul: judul,
            totalWeeks: widget.totalWeeks,
            periode: widget.bulanLabel,
          );
          break;
        case ExportFormat.excel:
          file = await ExportService.instance.exportMonthlyRecapExcel(
            widget.recaps,
            judul: judul,
            totalWeeks: widget.totalWeeks,
            periode: widget.bulanLabel,
          );
          break;
      }

      await ExportService.instance.openFile(file);

      if (!mounted) return;
      setState(() {
        _exportedFile = file;
        _exportedFormat = format;
      });
    } catch (e) {
      if (mounted) {
        showInlineMessage('Gagal ekspor: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingFormat = null;
        });
      }
    }
  }

  Future<void> _share() async {
    if (_exportedFile == null) return;
    await ExportService.instance.shareFile(_exportedFile!, subject: 'Rekap Bulanan - ${widget.bulanLabel}');
  }

  Future<void> _saveToDevice() async {
    if (_exportedFile == null || _exportedFormat == null) return;
    try {
      final ext = _extFor(_exportedFormat!);
      final filename = 'Rekap Bulanan - ${widget.bulanLabel}';
      await ExportService.instance.saveToDevice(
        _exportedFile!,
        filename: filename,
        ext: ext,
      );
      // Sama seperti ExportSheet: sekalian munculin notifikasi sistem
      // "Unduhan selesai" (bisa diketuk buat langsung buka lagi filenya),
      // bukan cuma pesan sesaat di dalam app.
      await DownloadNotificationService.instance.notifySaved(
        fileName: '$filename.$ext',
        file: _exportedFile!,
      );
      if (mounted) {
        showInlineMessage('Tersimpan ke Download.');
      }
    } catch (e) {
      if (mounted) {
        showInlineMessage('Gagal menyimpan: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).bottomSheetTheme.backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            if (inlineMessage != null) ...[
              InlineMessageBanner(message: inlineMessage!),
              const SizedBox(height: 12),
            ],
            if (_exportedFile == null) ...[
              Text('Export Rekap Bulanan',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                '${widget.recaps.length} santri, gabungan Pekan 1-${widget.totalWeeks} akan diekspor',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ExportOptionTile(
                icon: Icons.picture_as_pdf_rounded,
                color: AppColors.redOn(context),
                title: 'PDF',
                subtitle: 'Untuk cetak & bagikan cepat',
                loading: _loading && _loadingFormat == ExportFormat.pdf,
                onTap: _loading ? null : () => _doExport(ExportFormat.pdf),
              ),
              const SizedBox(height: 10),
              ExportOptionTile(
                icon: Icons.description_rounded,
                color: AppColors.blueOn(context),
                title: 'Word (.docx)',
                subtitle: 'Bisa diedit lebih lanjut',
                loading: _loading && _loadingFormat == ExportFormat.word,
                onTap: _loading ? null : () => _doExport(ExportFormat.word),
              ),
              const SizedBox(height: 10),
              ExportOptionTile(
                icon: Icons.grid_on_rounded,
                color: AppColors.greenOn(context),
                title: 'Excel (.xlsx)',
                subtitle: 'Untuk rekap & olah data lanjutan',
                loading: _loading && _loadingFormat == ExportFormat.excel,
                onTap: _loading ? null : () => _doExport(ExportFormat.excel),
              ),
            ] else ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: Icon(Icons.check_rounded, color: cs.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Berhasil diekspor', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        Text('File sudah dibuka otomatis.',
                            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _share,
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: const Text('Bagikan'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saveToDevice,
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Simpan'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tabel scroll horizontal: 1 baris = 1 santri (dalam SATU kelompok
/// Kelas/Halaqoh — lihat pemanggilnya di [GenerateRekapBulananScreen]),
/// kolom Pekan 1..N menampilkan ringkasan capaiannya tiap pekan. Santri
/// yang belum lengkap laporannya di semua Pekan ditandai indikator kuning
/// di sisi kiri baris. Kolom Kelas/Halaqoh SENGAJA tidak ada lagi di sini
/// (dulu ada) — sekarang sudah tersirat dari header kelompok di atas
/// tabel ini, jadi tidak perlu diulang tiap baris.
class _MonthlyRecapTable extends StatelessWidget {
  final List<SantriMonthlyRecap> recaps;
  final int totalWeeks;
  const _MonthlyRecapTable({required this.recaps, required this.totalWeeks});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(cs.primaryContainer.withValues(alpha: 0.5)),
          columnSpacing: 20,
          columns: [
            const DataColumn(label: Text('Nama', style: TextStyle(fontWeight: FontWeight.w800))),
            for (var w = 1; w <= totalWeeks; w++)
              DataColumn(label: Text('Pekan $w', style: const TextStyle(fontWeight: FontWeight.w800))),
            const DataColumn(label: Text('Total Baris', style: TextStyle(fontWeight: FontWeight.w800))),
            const DataColumn(label: Text('Keterangan', style: TextStyle(fontWeight: FontWeight.w800))),
          ],
          rows: [
            for (final r in recaps)
              DataRow(
                cells: [
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!r.isCompleteThrough(totalWeeks))
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(Icons.circle, size: 8, color: AppColors.orangeOn(context)),
                          ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 140),
                          child: Text(r.nama,
                              style: const TextStyle(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                  for (var w = 1; w <= totalWeeks; w++)
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Text(r.capaianForWeek(w), overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  DataCell(Text('${r.totalBaris}')),
                  DataCell(
                    Text(
                      r.keteranganSummaryText,
                      style: TextStyle(
                        color: r.keteranganCounts.isEmpty ? cs.onSurfaceVariant : AppColors.orangeOn(context),
                        fontWeight: r.keteranganCounts.isEmpty ? FontWeight.normal : FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
