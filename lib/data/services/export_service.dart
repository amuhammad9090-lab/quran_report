import 'package:printing/printing.dart';

import '../models/enums.dart';
import '../models/santri_monthly_recap.dart';
import '../models/santri_record.dart';
import 'export/export_excel.dart';
import 'export/export_pdf.dart';
import 'export/export_rows.dart';
import 'export/export_word.dart';
import 'platform_file/exported_file.dart';
import 'platform_file/file_actions.dart';

// Tetap diekspor dari sini supaya import lama `export_service.dart` tidak perlu diubah.
export 'export/export_rows.dart' show ExportKelasHalaqohSection, SantriWeeklyRow;

/// Pintu tunggal export & aksi file (buka, bagikan, simpan). Isinya delegasi: baris/teks tabel di
/// [ExportRows], layout tiap format di [ExportPdf], [ExportExcel], dan [ExportWord].
class ExportService {
  ExportService._();
  static final ExportService instance = ExportService._();

  static const _rows = ExportRows();
  static const _pdf = ExportPdf();
  static const _excel = ExportExcel();
  static const _word = ExportWord();

  // -------------------- Teks kolom (dipakai widget UI agar isinya sama dengan hasil export) --------------------

  String capaianLabelFor(SantriRecord r) => _rows.capaianLabelFor(r);
  String ayatHalRangeFor(SantriRecord r) => _rows.ayatHalRangeFor(r);
  String barisTextFor(SantriRecord r) => _rows.barisTextFor(r);
  String catatanTextFor(SantriRecord r) => _rows.catatanTextFor(r);
  String hariTanggalTextFor(DateTime d) => _rows.hariTanggalTextFor(d);

  List<SantriWeeklyRow> weeklyRowsGroupedBySantriFor(
    List<SantriRecord> records, {
    String? fixedTanggalLabel,
  }) =>
      _rows.weeklyRowsGroupedBySantriFor(records, fixedTanggalLabel: fixedTanggalLabel);

  // -------------------- PDF (A4 potrait) --------------------

  Future<ExportedFile> exportPdf(
    List<SantriRecord> records, {
    required String judul,
    String? kelas,
    String? halaqoh,
    String? periode,
    String? guruPembimbing,
    bool includeTanggal = false,
    String? fixedTanggalLabel,
  }) =>
      _pdf.exportPdf(
        records,
        judul: judul,
        kelas: kelas,
        halaqoh: halaqoh,
        periode: periode,
        guruPembimbing: guruPembimbing,
        includeTanggal: includeTanggal,
        fixedTanggalLabel: fixedTanggalLabel,
      );

  Future<ExportedFile> exportGroupedPdf(
    List<ExportKelasHalaqohSection<SantriRecord>> sections, {
    required String judul,
    String? periode,
    bool includeTanggal = false,
    String? fixedTanggalLabel,
  }) =>
      _pdf.exportGroupedPdf(
        sections,
        judul: judul,
        periode: periode,
        includeTanggal: includeTanggal,
        fixedTanggalLabel: fixedTanggalLabel,
      );

  Future<ExportedFile> exportGroupedMonthlyRecapPdf(
    List<ExportKelasHalaqohSection<SantriMonthlyRecap>> sections, {
    required String judul,
    required int totalWeeks,
    String? periode,
  }) =>
      _pdf.exportGroupedMonthlyRecapPdf(
        sections,
        judul: judul,
        totalWeeks: totalWeeks,
        periode: periode,
      );

  // -------------------- Excel --------------------

  Future<ExportedFile> exportExcel(
    List<SantriRecord> records, {
    required String judul,
    String? kelas,
    String? halaqoh,
    String? periode,
    String? guruPembimbing,
    bool includeTanggal = false,
    String? fixedTanggalLabel,
  }) =>
      _excel.exportExcel(
        records,
        judul: judul,
        kelas: kelas,
        halaqoh: halaqoh,
        periode: periode,
        guruPembimbing: guruPembimbing,
        includeTanggal: includeTanggal,
        fixedTanggalLabel: fixedTanggalLabel,
      );

  Future<ExportedFile> exportGroupedExcel(
    List<ExportKelasHalaqohSection<SantriRecord>> sections, {
    required String judul,
    String? periode,
    bool includeTanggal = false,
    String? fixedTanggalLabel,
  }) =>
      _excel.exportGroupedExcel(
        sections,
        judul: judul,
        periode: periode,
        includeTanggal: includeTanggal,
        fixedTanggalLabel: fixedTanggalLabel,
      );

  Future<ExportedFile> exportGroupedMonthlyRecapExcel(
    List<ExportKelasHalaqohSection<SantriMonthlyRecap>> sections, {
    required String judul,
    required int totalWeeks,
    String? periode,
  }) =>
      _excel.exportGroupedMonthlyRecapExcel(
        sections,
        judul: judul,
        totalWeeks: totalWeeks,
        periode: periode,
      );

  // -------------------- Word --------------------

  Future<ExportedFile> exportWord(
    List<SantriRecord> records, {
    required String judul,
    String? kelas,
    String? halaqoh,
    String? periode,
    String? guruPembimbing,
    bool includeTanggal = false,
    String? fixedTanggalLabel,
  }) =>
      _word.exportWord(
        records,
        judul: judul,
        kelas: kelas,
        halaqoh: halaqoh,
        periode: periode,
        guruPembimbing: guruPembimbing,
        includeTanggal: includeTanggal,
        fixedTanggalLabel: fixedTanggalLabel,
      );

  Future<ExportedFile> exportGroupedWord(
    List<ExportKelasHalaqohSection<SantriRecord>> sections, {
    required String judul,
    String? periode,
    bool includeTanggal = false,
    String? fixedTanggalLabel,
  }) =>
      _word.exportGroupedWord(
        sections,
        judul: judul,
        periode: periode,
        includeTanggal: includeTanggal,
        fixedTanggalLabel: fixedTanggalLabel,
      );

  Future<ExportedFile> exportGroupedMonthlyRecapWord(
    List<ExportKelasHalaqohSection<SantriMonthlyRecap>> sections, {
    required String judul,
    required int totalWeeks,
    String? periode,
  }) =>
      _word.exportGroupedMonthlyRecapWord(
        sections,
        judul: judul,
        totalWeeks: totalWeeks,
        periode: periode,
      );

  // -------------------- Pilih format --------------------
  // Dipakai layar/sheet export: satu pintu per jenis dokumen, format dipilih lewat [format].

  Future<ExportedFile> exportRecords(
    ExportFormat format,
    List<SantriRecord> records, {
    required String judul,
    String? periode,
    String? guruPembimbing,
    bool includeTanggal = false,
    String? fixedTanggalLabel,
  }) =>
      switch (format) {
        ExportFormat.pdf => exportPdf(
            records,
            judul: judul,
            periode: periode,
            guruPembimbing: guruPembimbing,
            includeTanggal: includeTanggal,
            fixedTanggalLabel: fixedTanggalLabel,
          ),
        ExportFormat.word => exportWord(
            records,
            judul: judul,
            periode: periode,
            guruPembimbing: guruPembimbing,
            includeTanggal: includeTanggal,
            fixedTanggalLabel: fixedTanggalLabel,
          ),
        ExportFormat.excel => exportExcel(
            records,
            judul: judul,
            periode: periode,
            guruPembimbing: guruPembimbing,
            includeTanggal: includeTanggal,
            fixedTanggalLabel: fixedTanggalLabel,
          ),
      };

  Future<ExportedFile> exportGrouped(
    ExportFormat format,
    List<ExportKelasHalaqohSection<SantriRecord>> sections, {
    required String judul,
    String? periode,
    bool includeTanggal = false,
    String? fixedTanggalLabel,
  }) =>
      switch (format) {
        ExportFormat.pdf => exportGroupedPdf(
            sections,
            judul: judul,
            periode: periode,
            includeTanggal: includeTanggal,
            fixedTanggalLabel: fixedTanggalLabel,
          ),
        ExportFormat.word => exportGroupedWord(
            sections,
            judul: judul,
            periode: periode,
            includeTanggal: includeTanggal,
            fixedTanggalLabel: fixedTanggalLabel,
          ),
        ExportFormat.excel => exportGroupedExcel(
            sections,
            judul: judul,
            periode: periode,
            includeTanggal: includeTanggal,
            fixedTanggalLabel: fixedTanggalLabel,
          ),
      };

  Future<ExportedFile> exportGroupedMonthlyRecap(
    ExportFormat format,
    List<ExportKelasHalaqohSection<SantriMonthlyRecap>> sections, {
    required String judul,
    required int totalWeeks,
    String? periode,
  }) =>
      switch (format) {
        ExportFormat.pdf => exportGroupedMonthlyRecapPdf(
            sections,
            judul: judul,
            totalWeeks: totalWeeks,
            periode: periode,
          ),
        ExportFormat.word => exportGroupedMonthlyRecapWord(
            sections,
            judul: judul,
            totalWeeks: totalWeeks,
            periode: periode,
          ),
        ExportFormat.excel => exportGroupedMonthlyRecapExcel(
            sections,
            judul: judul,
            totalWeeks: totalWeeks,
            periode: periode,
          ),
      };

  // -------------------- Buka / Bagikan / Simpan --------------------

  /// Buka file lewat aplikasi bawaan perangkat (PDF viewer, Word, Excel, dst), dipanggil otomatis
  /// begitu file selesai dibuat. Di Web ini menjadi trigger download (lihat file_actions_web.dart).
  Future<void> openFile(ExportedFile file) => openExportedFile(file);

  Future<void> shareFile(ExportedFile file, {String? subject}) =>
      shareExportedFile(file, subject: subject);

  /// Simpan salinan file ke penyimpanan perangkat (folder Download publik di Android / lokasi
  /// pilihan user di iOS / trigger download browser di Web).
  Future<void> saveToDevice(ExportedFile file, {required String filename, required String ext}) =>
      saveExportedFileToDevice(file, filename: filename, ext: ext);

  Future<void> printPdfDirectly(List<SantriRecord> records, {required String judul}) async {
    final file = await exportPdf(records, judul: judul);
    await Printing.layoutPdf(onLayout: (_) async => file.bytes);
  }
}
