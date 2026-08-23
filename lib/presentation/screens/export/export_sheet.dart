import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/enums.dart';
import '../../../data/models/santri_record.dart';
import '../../../data/services/export_service.dart';
import '../../../providers/records_provider.dart';
import '../../../core/theme/app_colors.dart';

Future<void> showExportSheet(
  BuildContext context, {
  List<SantriRecord>? records,
  String? judul,
  String? periode,
  String? guruPembimbing,
  bool includeTanggal = false,
}) {
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ExportSheet(
      fixedRecords: records,
      judul: judul,
      periode: periode,
      guruPembimbing: guruPembimbing,
      includeTanggal: includeTanggal,
    ),
  );
}

class ExportSheet extends StatefulWidget {
  // Kalau diisi (mis. dari halaman folder), sheet ini export data yang
  // sudah ditentukan dari luar, dan opsi "filter aktif / semua data"
  // disembunyikan.
  final List<SantriRecord>? fixedRecords;
  final String? judul;
  // Baris kecil opsional di bawah kop laporan (mis. nama folder atau
  // bulan rekap) — nggak ditampilkan kalau kosong.
  final String? periode;
  // Nama guru pembimbing (dicetak sebagai baris tambahan di kop laporan) —
  // dipakai khusus export rekap per Kelas+Halaqoh (lihat
  // KelasHalaqohGroupCard). Null = tidak ditampilkan.
  final String? guruPembimbing;
  // True kalau laporan yang diekspor bisa mencakup lebih dari 1
  // hari/tanggal (mis. rekap pekanan per kelompok) -> tabel export
  // menyertakan kolom Hari & Tanggal per baris.
  final bool includeTanggal;

  const ExportSheet({
    super.key,
    this.fixedRecords,
    this.judul,
    this.periode,
    this.guruPembimbing,
    this.includeTanggal = false,
  });

  @override
  State<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<ExportSheet> {
  bool _useFilteredOnly = true;
  bool _loading = false;
  ExportFormat? _loadingFormat;

  // Diisi begitu ekspor sukses — sheet pindah ke tampilan "selesai" dengan
  // tombol Bagikan & Simpan ke Perangkat.
  File? _exportedFile;
  ExportFormat? _exportedFormat;
  String? _exportedJudul;

  bool get _isFixed => widget.fixedRecords != null;

  String _extFor(ExportFormat f) => switch (f) {
        ExportFormat.pdf => 'pdf',
        ExportFormat.word => 'docx',
        ExportFormat.excel => 'xlsx',
      };

  Future<void> _doExport(ExportFormat format) async {
    final provider = context.read<RecordsProvider>();
    final List<SantriRecord> records =
        widget.fixedRecords ?? (_useFilteredOnly ? provider.filtered : provider.all);

    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data untuk diekspor.')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _loadingFormat = format;
    });

    try {
      final judul = widget.judul ?? 'Laporan Pekanan Al Quran';
      File file;
      switch (format) {
        case ExportFormat.pdf:
          file = await ExportService.instance.exportPdf(
            records,
            judul: judul,
            periode: widget.periode,
            guruPembimbing: widget.guruPembimbing,
            includeTanggal: widget.includeTanggal,
          );
          break;
        case ExportFormat.word:
          file = await ExportService.instance.exportWord(
            records,
            judul: judul,
            periode: widget.periode,
            guruPembimbing: widget.guruPembimbing,
            includeTanggal: widget.includeTanggal,
          );
          break;
        case ExportFormat.excel:
          file = await ExportService.instance.exportExcel(
            records,
            judul: judul,
            periode: widget.periode,
            guruPembimbing: widget.guruPembimbing,
            includeTanggal: widget.includeTanggal,
          );
          break;
      }

      // Begitu file jadi, langsung dibuka pakai aplikasi bawaan perangkat.
      await ExportService.instance.openFile(file);

      if (!mounted) return;
      setState(() {
        _exportedFile = file;
        _exportedFormat = format;
        _exportedJudul = judul;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal ekspor: $e')),
        );
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
      await ExportService.instance.saveToDevice(
        _exportedFile!,
        filename: _exportedJudul ?? 'laporan',
        ext: _extFor(_exportedFormat!),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tersimpan ke perangkat.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final provider = context.watch<RecordsProvider>();
    final count = widget.fixedRecords?.length ??
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                  ),
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
              SizedBox(height: _isFixed ? 4 : 20),
              _ExportOptionTile(
                icon: Icons.picture_as_pdf_rounded,
                color: AppColors.redOn(context),
                title: 'PDF',
                subtitle: 'Untuk cetak & bagikan cepat',
                loading: _loading && _loadingFormat == ExportFormat.pdf,
                onTap: _loading ? null : () => _doExport(ExportFormat.pdf),
              ),
              const SizedBox(height: 10),
              _ExportOptionTile(
                icon: Icons.description_rounded,
                color: AppColors.blueOn(context),
                title: 'Word (.docx)',
                subtitle: 'Bisa diedit lebih lanjut',
                loading: _loading && _loadingFormat == ExportFormat.word,
                onTap: _loading ? null : () => _doExport(ExportFormat.word),
              ),
              const SizedBox(height: 10),
              _ExportOptionTile(
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

class _ExportOptionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool loading;
  final VoidCallback? onTap;

  const _ExportOptionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (loading)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              else
                Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
