import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/enums.dart';
import '../../../data/models/santri_record.dart';
import '../../../data/services/export_service.dart';
import '../../../providers/records_provider.dart';

Future<void> showExportSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const ExportSheet(),
  );
}

class ExportSheet extends StatefulWidget {
  const ExportSheet({super.key});

  @override
  State<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<ExportSheet> {
  bool _useFilteredOnly = true;
  bool _loading = false;
  ExportFormat? _loadingFormat;

  Future<void> _doExport(ExportFormat format) async {
    final provider = context.read<RecordsProvider>();
    final List<SantriRecord> records = _useFilteredOnly ? provider.filtered : provider.all;

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
      const judul = 'Laporan Capaian Hafalan Al-Quran';
      File file;
      switch (format) {
        case ExportFormat.pdf:
          file = await ExportService.instance.exportPdf(records, judul: judul);
          break;
        case ExportFormat.word:
          file = await ExportService.instance.exportWord(records, judul: judul);
          break;
        case ExportFormat.excel:
          file = await ExportService.instance.exportExcel(records, judul: judul);
          break;
      }
      await ExportService.instance.shareFile(file, subject: judul);
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final provider = context.watch<RecordsProvider>();
    final count = _useFilteredOnly ? provider.filtered.length : provider.all.length;

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
            Text('Ekspor Laporan', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              '$count data akan diekspor',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 16),
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
                    title: const Text('Sesuai filter/pencarian aktif', style: TextStyle(fontSize: 13.5)),
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
            const SizedBox(height: 20),
            _ExportOptionTile(
              icon: Icons.picture_as_pdf_rounded,
              color: const Color(0xFFD64545),
              title: 'PDF',
              subtitle: 'Untuk cetak & bagikan cepat',
              loading: _loading && _loadingFormat == ExportFormat.pdf,
              onTap: _loading ? null : () => _doExport(ExportFormat.pdf),
            ),
            const SizedBox(height: 10),
            _ExportOptionTile(
              icon: Icons.description_rounded,
              color: const Color(0xFF2F80B4),
              title: 'Word (.docx)',
              subtitle: 'Bisa diedit lebih lanjut',
              loading: _loading && _loadingFormat == ExportFormat.word,
              onTap: _loading ? null : () => _doExport(ExportFormat.word),
            ),
            const SizedBox(height: 10),
            _ExportOptionTile(
              icon: Icons.grid_on_rounded,
              color: const Color(0xFF2E9E5B),
              title: 'Excel (.xlsx)',
              subtitle: 'Untuk rekap & olah data lanjutan',
              loading: _loading && _loadingFormat == ExportFormat.excel,
              onTap: _loading ? null : () => _doExport(ExportFormat.excel),
            ),
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
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
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
