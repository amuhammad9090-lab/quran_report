import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/enums.dart';
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
      String? judul,
      String? periode,
      String? guruPembimbing,
      bool includeTanggal = false,
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

  // Fix snackbar "membelakangi" (v1) -> "nyisain space kosong" (v2):
  // - v1 (lama banget): pakai ScaffoldMessenger.of(context) punya HALAMAN
  //   DI BALIK sheet (karena sheet ini sendiri gak punya Scaffold) ->
  //   SnackBar kegambar di belakang sheet.
  // - v2 (percobaan sebelumnya): dibungkus Scaffold lokal biar punya
  //   ScaffoldMessenger sendiri -> SnackBar-nya emang jadi kegambar di
  //   depan, TAPI widget Scaffold SELALU melebar mengisi constraints
  //   penuh yang dikasih parent-nya (constraints.biggest), TERLEPAS dari
  //   seberapa tinggi body-nya sendiri. Karena sheet ini dibuka dengan
  //   isScrollControlled: true (constraints tinggi maksimalnya = hampir
  //   1 layar penuh), Scaffold jadi ikut setinggi itu juga, padahal
  //   konten aslinya (Container di bawah) cuma butuh tinggi secukupnya
  //   -> nyisa ruang kosong transparan di bawah kartu putihnya.
  // Fix final: JANGAN pakai Scaffold/ScaffoldMessenger sama sekali di
  // sini. Pesannya ditampilkan sebagai banner kecil biasa, jadi BAGIAN
  // dari Column konten sheet ini sendiri (lihat build() -> _InlineBanner)
  // -- otomatis selalu di depan (karena memang bagian dari layout sheet,
  // bukan overlay terpisah) dan otomatis nggak nambah tinggi kosong
  // (karena ukurannya ngikutin isi teksnya doang, sama seperti
  // widget-widget lain di Column ini).
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
      _showSnack('Tidak ada data untuk diekspor.');
      return;
    }

    setState(() {
      _loading = true;
      _loadingFormat = format;
    });

    try {
      final judul = widget.judul ?? 'Laporan Pekanan Al Quran';
      ExportedFile file;
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

      // Begitu file jadi, COBA buka otomatis pakai aplikasi bawaan
      // perangkat. Ini cuma kenyamanan tambahan -- filenya sendiri sudah
      // berhasil dibuat & tersimpan di penyimpanan internal app duluan
      // (lihat ExportService._saveBytes di atas), jadi kalau gagal dibuka
      // otomatis (mis. gak ada app pembuka terpasang, atau device lagi
      // bermasalah), itu TIDAK BOLEH menggagalkan seluruh proses ekspor.
      // Sebelumnya kegagalan di sini ketangkep sama catch di bawah dan
      // bikin user nyangka ekspornya gagal total -- padahal filenya ada,
      // cuma gak sempat kebuka -- akibatnya user gak pernah nyampe ke
      // tombol "Bagikan"/"Simpan" sama sekali.
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
      // Bug fix #1: sebelumnya cuma SnackBar di dalam app -- sekarang juga
      // munculin notifikasi sistem "Unduhan selesai" (lihat
      // DownloadNotificationService), sama kayak pola download di app lain
      // pada umumnya, dan bisa diketuk buat langsung buka filenya lagi.
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
