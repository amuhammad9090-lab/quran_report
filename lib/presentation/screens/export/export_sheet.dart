import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/enums.dart';
import '../../../data/models/santri_monthly_recap.dart';
import '../../../data/models/santri_record.dart';
import '../../../data/services/download_notification_service.dart';
import '../../../data/services/export_service.dart';
import '../../../data/services/platform_file/exported_file.dart';
import '../../../providers/records_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/misc_widgets.dart';

Future<void> showExportSheet(
    BuildContext context, {
      List<SantriRecord>? records,
      List<ExportKelasHalaqohSection<SantriRecord>>? groupedSections,
      List<ExportKelasHalaqohSection<SantriMonthlyRecap>>? groupedMonthlySections,
      int? totalWeeks,
      String? judul,
      String? periode,
      String? guruPembimbing,
      bool includeTanggal = false,
      String? fixedTanggalLabel,
    }) {
  return showModalBottomSheet(
    context: context,
    constraints: const BoxConstraints(maxWidth: 640),
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ExportSheet(
      fixedRecords: records,
      groupedSections: groupedSections,
      groupedMonthlySections: groupedMonthlySections,
      totalWeeks: totalWeeks,
      judul: judul,
      periode: periode,
      guruPembimbing: guruPembimbing,
      includeTanggal: includeTanggal,
      fixedTanggalLabel: fixedTanggalLabel,
    ),
  );
}

class ExportSheet extends StatefulWidget {
  final List<SantriRecord>? fixedRecords;
  final List<ExportKelasHalaqohSection<SantriRecord>>? groupedSections;
  final List<ExportKelasHalaqohSection<SantriMonthlyRecap>>? groupedMonthlySections;
  final int? totalWeeks;
  final String? judul;
  final String? periode;
  final String? guruPembimbing;
  final bool includeTanggal;
  final String? fixedTanggalLabel;

  const ExportSheet({
    super.key,
    this.fixedRecords,
    this.groupedSections,
    this.groupedMonthlySections,
    this.totalWeeks,
    this.judul,
    this.periode,
    this.guruPembimbing,
    this.includeTanggal = false,
    this.fixedTanggalLabel,
  });

  @override
  State<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<ExportSheet> {
  bool _useFilteredOnly = true;
  bool _loading = false;
  ExportFormat? _loadingFormat;

  // Fix snackbar "membelakangi" (v1)
  String? _inlineMessage;
  Timer? _inlineMessageTimer;

  void _showSnack(String message) {
    _inlineMessageTimer?.cancel();
    setState(() => _inlineMessage = message);
    _inlineMessageTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _inlineMessage = null);
    });
  }

  @override
  void dispose() {
    _inlineMessageTimer?.cancel();
    super.dispose();
  }

  // Diisi begitu ekspor sukses — sheet pindah ke tampilan "selesai" dengan
  // tombol Bagikan & Simpan ke Perangkat.
  ExportedFile? _exportedFile;
  ExportFormat? _exportedFormat;
  String? _exportedJudul;

  bool get _isFixed => widget.fixedRecords != null ||
      widget.groupedSections != null ||
      widget.groupedMonthlySections != null;

  String _extFor(ExportFormat f) => switch (f) {
    ExportFormat.pdf => 'pdf',
    ExportFormat.word => 'docx',
    ExportFormat.excel => 'xlsx',
  };

  Future<void> _doExport(ExportFormat format) async {
    final groupedMonthly = widget.groupedMonthlySections;
    final grouped = widget.groupedSections;

    if (groupedMonthly != null) {
      final totalSantri = groupedMonthly.fold<int>(0, (sum, s) => sum + s.items.length);
      if (totalSantri == 0) {
        _showSnack('Tidak ada data untuk diekspor.');
        return;
      }
      await _runExport(format, judulDefault: 'Rekap Bulanan Al Quran', build: (judul) {
        switch (format) {
          case ExportFormat.pdf:
            return ExportService.instance.exportGroupedMonthlyRecapPdf(
              groupedMonthly,
              judul: judul,
              totalWeeks: widget.totalWeeks!,
              periode: widget.periode,
            );
          case ExportFormat.word:
            return ExportService.instance.exportGroupedMonthlyRecapWord(
              groupedMonthly,
              judul: judul,
              totalWeeks: widget.totalWeeks!,
              periode: widget.periode,
            );
          case ExportFormat.excel:
            return ExportService.instance.exportGroupedMonthlyRecapExcel(
              groupedMonthly,
              judul: judul,
              totalWeeks: widget.totalWeeks!,
              periode: widget.periode,
            );
        }
      });
      return;
    }

    if (grouped != null) {
      final total = grouped.fold<int>(0, (sum, s) => sum + s.items.length);
      if (total == 0) {
        _showSnack('Tidak ada data untuk diekspor.');
        return;
      }
      await _runExport(format, judulDefault: 'Laporan Pekanan Al Quran', build: (judul) {
        switch (format) {
          case ExportFormat.pdf:
            return ExportService.instance.exportGroupedPdf(
              grouped,
              judul: judul,
              periode: widget.periode,
              includeTanggal: widget.includeTanggal,
              fixedTanggalLabel: widget.fixedTanggalLabel,
            );
          case ExportFormat.word:
            return ExportService.instance.exportGroupedWord(
              grouped,
              judul: judul,
              periode: widget.periode,
              includeTanggal: widget.includeTanggal,
              fixedTanggalLabel: widget.fixedTanggalLabel,
            );
          case ExportFormat.excel:
            return ExportService.instance.exportGroupedExcel(
              grouped,
              judul: judul,
              periode: widget.periode,
              includeTanggal: widget.includeTanggal,
              fixedTanggalLabel: widget.fixedTanggalLabel,
            );
        }
      });
      return;
    }

    final provider = context.read<RecordsProvider>();
    final List<SantriRecord> records =
        widget.fixedRecords ?? (_useFilteredOnly ? provider.filtered : provider.all);

    if (records.isEmpty) {
      _showSnack('Tidak ada data untuk diekspor.');
      return;
    }

    await _runExport(format, judulDefault: 'Laporan Pekanan Al Quran', build: (judul) {
      switch (format) {
        case ExportFormat.pdf:
          return ExportService.instance.exportPdf(
            records,
            judul: judul,
            periode: widget.periode,
            guruPembimbing: widget.guruPembimbing,
            includeTanggal: widget.includeTanggal,
            fixedTanggalLabel: widget.fixedTanggalLabel,
          );
        case ExportFormat.word:
          return ExportService.instance.exportWord(
            records,
            judul: judul,
            periode: widget.periode,
            guruPembimbing: widget.guruPembimbing,
            includeTanggal: widget.includeTanggal,
            fixedTanggalLabel: widget.fixedTanggalLabel,
          );
        case ExportFormat.excel:
          return ExportService.instance.exportExcel(
            records,
            judul: judul,
            periode: widget.periode,
            guruPembimbing: widget.guruPembimbing,
            includeTanggal: widget.includeTanggal,
            fixedTanggalLabel: widget.fixedTanggalLabel,
          );
      }
    });
  }

  /// Inti proses export yang SAMA buat ketiga mode (flat records / grouped
  /// pekanan / grouped bulanan)
  Future<void> _runExport(
    ExportFormat format, {
    required String judulDefault,
    required Future<ExportedFile> Function(String judul) build,
  }) async {
    setState(() {
      _loading = true;
      _loadingFormat = format;
    });

    try {
      final judul = widget.judul ?? judulDefault;
      final file = await build(judul);

      try {
        await ExportService.instance.openFile(file);
      } catch (_) {
        // Diamkan -- file tetap berhasil dibuat, lanjut ke layar selesai.
      }

      if (!mounted) return;
      setState(() {
        _exportedFile = file;
        _exportedFormat = format;
        _exportedJudul = judul;
      });
    } catch (e) {
      if (mounted) {
        _showSnack('Gagal ekspor: $e');
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
    await ExportService.instance.shareFile(_exportedFile!, subject: _exportedJudul);
  }

  Future<void> _saveToDevice() async {
    if (_exportedFile == null || _exportedFormat == null) return;
    try {
      final ext = _extFor(_exportedFormat!);
      final fileName = '${_exportedJudul ?? 'laporan'}.$ext';
      await ExportService.instance.saveToDevice(
        _exportedFile!,
        filename: _exportedJudul ?? 'laporan',
        ext: ext,
      );

      await DownloadNotificationService.instance.notifySaved(
        fileName: fileName,
        file: _exportedFile!,
      );
      if (mounted) {
        _showSnack('Tersimpan ke Download.');
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Gagal menyimpan: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final provider = context.watch<RecordsProvider>();
    final count = widget.groupedMonthlySections != null
        ? widget.groupedMonthlySections!.fold<int>(0, (sum, s) => sum + s.items.length)
        : widget.groupedSections != null
            ? widget.groupedSections!.fold<int>(0, (sum, s) => sum + s.items.length)
            : widget.fixedRecords?.length ??
                (_useFilteredOnly ? provider.filtered.length : provider.all.length);

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
            if (_inlineMessage != null) ...[
              _InlineMessageBanner(message: _inlineMessage!),
              const SizedBox(height: 12),
            ],
              if (_exportedFile == null) ...[
                Text('Ekspor Laporan',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  '$count data akan diekspor',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
                const SizedBox(height: 16),
                if (!_isFixed)
                  Material(
                    // Sebelumnya Container(decoration: BoxDecoration(color,
                    // borderRadius)) — diganti Material supaya RadioListTile
                    // di dalamnya (2 baris di bawah) punya Material terdekat
                    // yang benar, nggak ketutup DecoratedBox lagi.
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          RadioListTile<bool>(
                            value: true,
                            // ignore: deprecated_member_use
                            groupValue: _useFilteredOnly,
                            // ignore: deprecated_member_use
                            onChanged: (v) => setState(() => _useFilteredOnly = v ?? true),
                            title: const Text('Sesuai filter/pencarian aktif',
                                style: TextStyle(fontSize: 13.5)),
                            dense: true,
                          ),
                          RadioListTile<bool>(
                            value: false,
                            // ignore: deprecated_member_use
                            groupValue: _useFilteredOnly,
                            // ignore: deprecated_member_use
                            onChanged: (v) => setState(() => _useFilteredOnly = v ?? false),
                            title: const Text('Semua data', style: TextStyle(fontSize: 13.5)),
                            dense: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                SizedBox(height: _isFixed ? 4 : 20),
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
                // --- Selesai: file sudah dibuat & otomatis kebuka ---
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check_rounded, color: cs.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Berhasil diekspor',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
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

/// Banner pesan singkat (pengganti SnackBar) yang jadi BAGIAN dari layout
/// [ExportSheet] sendiri -- lihat catatan di [_ExportSheetState._showSnack]
/// kenapa SnackBar/ScaffoldMessenger dihindari di sheet ini.
class _InlineMessageBanner extends StatelessWidget {
  final String message;
  const _InlineMessageBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline_rounded, size: 17, color: cs.primary),
          const SizedBox(width: 10),
          Flexible(
            child: Text(message, style: const TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}
