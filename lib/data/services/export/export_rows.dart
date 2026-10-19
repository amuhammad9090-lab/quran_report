import 'package:intl/intl.dart';

import '../../../core/utils/nilai_average.dart';
import '../../../core/utils/standar_ketuntasan.dart';
import '../../models/enums.dart';
import '../../models/santri_monthly_recap.dart';
import '../../models/santri_record.dart';

part 'export_rows_weekly.dart';

/// Satu kelompok Kelas+Halaqoh dalam sebuah dokumen export gabungan
class ExportKelasHalaqohSection<T> {
  final String kelas;
  final String halaqoh;
  final String? guruPembimbing;
  final List<T> items;
  const ExportKelasHalaqohSection({
    required this.kelas,
    required this.halaqoh,
    this.guruPembimbing,
    required this.items,
  });
}

/// 1 baris ringkasan SATU santri di "Generate Laporan Pekanan" — gabungan
/// SEMUA laporan santri itu dalam pekan tsb (bisa >1 laporan kalau ada
/// laporan lebih dari sekali dalam pekan itu).
class SantriWeeklyRow {
  final String namaAnak;
  final String tanggalLabel;
  final String capaian;
  final int totalBaris;
  final String keterangan;
  final String nilai;
  final String status;
  final String catatan;

  const SantriWeeklyRow({
    required this.namaAnak,
    required this.tanggalLabel,
    required this.capaian,
    required this.totalBaris,
    required this.keterangan,
    required this.nilai,
    required this.status,
    required this.catatan,
  });
}

/// Teks dan baris tabel untuk semua export (laporan biasa, gabungan per santri, rekap bulanan):
/// murni pemformatan tanpa Pdf/Excel/Word, jadi bisa dipakai ulang widget UI dan dites.
class ExportRows {
  const ExportRows();

  // Kop laporan resmi — tetap sama di semua format & konteks ekspor
  // (laporan biasa, per-folder, maupun rekap bulanan).
  static const judulLaporan = 'LAPORAN PEKANAN AL QURAN';
  static const namaSekolah = 'SMPIT Al Madinah Tanjungpinang';

  static const headers = [
    'No',
    'Nama Siswa',
    'Capaian Tahsin/Tahfizh',
    'Ayat/Hal',
    'Baris',
    'Keterangan',
    'Nilai',
    'Status',
    'Catatan',
  ];

  // ---- Export Rekap Kehadiran BULANAN: 1 tabel per Kelas+Halaqoh, baris = santri, kolom = tanggal 1..N ----
  static const judulKehadiran = 'REKAP KEHADIRAN SISWA';
  static const attendanceTotalLabels = ['H', 'S', 'I', 'L', 'P', 'A'];
  static const attendanceLegend =
      'Keterangan: H = Hadir (termasuk tidak setoran/tahsin/murojaah), S = Sakit, I = Izin, '
      'L = Izin Lomba, P = Izin Pelatihan, A = Alpa. Kotak kosong = tidak ada laporan di hari itu.';

  int daysInMonth(DateTime month) => DateTime(month.year, month.month + 1, 0).day;

  List<String> attendanceMonthHeaders(DateTime month) => [
        'No',
        'Nama Siswa',
        for (var d = 1; d <= daysInMonth(month); d++) '$d',
        ...attendanceTotalLabels,
      ];

  String _attendanceCode(Keterangan k) => switch (k) {
        Keterangan.hadir ||
        Keterangan.tidakSetoran ||
        Keterangan.tidakTahsin ||
        Keterangan.tidakMurojaah =>
          'H',
        Keterangan.izinSakit => 'S',
        Keterangan.izin => 'I',
        Keterangan.izinLomba => 'L',
        Keterangan.izinPelatihan => 'P',
        Keterangan.alpa => 'A',
      };

  /// 1 baris per santri (urut nama): No, Nama, kode kehadiran tiap tanggal 1..N, lalu total H,S,I,L,P,A.
  /// Kalau 1 santri punya >1 laporan di hari yang sama, yang terakhir diinput yang dipakai.
  List<List<String>> buildAttendanceMonthRows(List<SantriRecord> records, DateTime month) {
    final days = daysInMonth(month);
    final byKey = <String, List<SantriRecord>>{};
    final display = <String, String>{};
    for (final r in records) {
      if (r.tanggal.year != month.year || r.tanggal.month != month.month) continue;
      final key = r.namaAnak.trim().toLowerCase();
      byKey.putIfAbsent(key, () => []).add(r);
      display[key] = r.namaAnak.trim();
    }
    final keys = byKey.keys.toList()
      ..sort((a, b) => (display[a] ?? a).toLowerCase().compareTo((display[b] ?? b).toLowerCase()));

    final rows = <List<String>>[];
    for (var i = 0; i < keys.length; i++) {
      final recs = List<SantriRecord>.from(byKey[keys[i]]!)
        ..sort((a, b) => (a.createdAt ?? a.tanggal).compareTo(b.createdAt ?? b.tanggal));
      final codes = List<String>.filled(days + 1, '');
      for (final r in recs) {
        codes[r.tanggal.day] = _attendanceCode(r.keterangan);
      }
      final counts = {for (final l in attendanceTotalLabels) l: 0};
      for (var d = 1; d <= days; d++) {
        if (codes[d].isNotEmpty) counts[codes[d]] = counts[codes[d]]! + 1;
      }
      rows.add([
        '${i + 1}',
        display[keys[i]] ?? keys[i],
        for (var d = 1; d <= days; d++) codes[d],
        for (final l in attendanceTotalLabels) '${counts[l]}',
      ]);
    }
    return rows;
  }

  static const headersWithTanggal = [
    'No',
    'Hari/Tanggal',
    'Nama Siswa',
    'Capaian Tahsin/Tahfizh',
    'Ayat/Hal',
    'Baris',
    'Keterangan',
    'Nilai',
    'Status',
    'Catatan',
  ];

  /// Teks ringkas bagian Tahsin saja (WAFA atau Tilawah)
  String _tahfizhSurahNames(SantriRecord r) {
    final segs = r.tahfizhSegmentsEffective;
    return segs.isEmpty ? '-' : segs.map((s) => s.surahName).join(', ');
  }

  String _tahfizhAyatRanges(SantriRecord r) {
    final segs = r.tahfizhSegmentsEffective;
    return segs.isEmpty ? '-' : segs.map((s) => '${s.ayatMulai}-${s.ayatSelesai}').join(', ');
  }

  String _tahsinPartLabel(SantriRecord r) {
    final mode = r.tahsinMode ?? TahsinMode.wafa;
    if (mode == TahsinMode.tilawah) {
      final segs = r.tilawahSegmentsEffective;
      return segs.isEmpty
          ? 'Tilawah'
          : 'Tilawah - ${segs.map((s) => s.surahName).join(', ')}';
    }
    return r.wafaLevel?.label ?? '-';
  }

  String _tahsinPartRange(SantriRecord r) {
    final mode = r.tahsinMode ?? TahsinMode.wafa;
    if (mode == TahsinMode.tilawah) {
      final segs = r.tilawahSegmentsEffective;
      return segs.isEmpty
          ? '-'
          : segs.map((s) => '${s.ayatMulai}-${s.ayatSelesai}').join(', ');
    }
    final hal = r.halamanWafa?.trim();
    return (hal == null || hal.isEmpty) ? '-' : hal;
  }

  String _capaianLabel(SantriRecord r) {
    switch (r.status) {
      case HafalanStatus.tahfizh:
        return '${r.status.label} - ${_tahfizhSurahNames(r)}';
      case HafalanStatus.tahsin:
        return '${r.status.label} - ${_tahsinPartLabel(r)}';
      case HafalanStatus.tahsinTahfizh:
        return '${r.status.label} - ${_tahsinPartLabel(r)} & ${_tahfizhSurahNames(r)}';
      case HafalanStatus.murojaahTasmi:
        final segs = r.tilawahSegmentsEffective;
        return segs.isEmpty
            ? r.status.label
            : '${r.status.label} - ${segs.map((s) => s.surahName).join(', ')}';
    }
  }

  // Cuma rentang angkanya (ayat X-Y, atau halaman WAFA-nya) — nama surah
  // sudah ikut di kolom "Capaian Tahsin/Tahfizh".
  String _ayatHalRange(SantriRecord r) {
    switch (r.status) {
      case HafalanStatus.tahfizh:
        return _tahfizhAyatRanges(r);
      case HafalanStatus.tahsin:
        return _tahsinPartRange(r);
      case HafalanStatus.tahsinTahfizh:
        return '${_tahsinPartRange(r)} + ${_tahfizhAyatRanges(r)}';
      case HafalanStatus.murojaahTasmi:
        final segs = r.tilawahSegmentsEffective;
        return segs.isEmpty
            ? '-'
            : segs.map((s) => '${s.ayatMulai}-${s.ayatSelesai}').join(', ');
    }
  }

  // Baris cuma dihitung buat status yang punya bagian hafalan baru
  // (Tahfizh, atau bagian Tahfizh di Tahsin+Tahfizh) — hasil generate.
  String _barisText(SantriRecord r) =>
      (r.status == HafalanStatus.tahfizh || r.status == HafalanStatus.tahsinTahfizh)
          ? '${r.totalBaris ?? 0}'
          : '-';

  // Hari+tanggal digabung 1 kolom, mis. "Senin, 17 Agu 2026".
  String _hariTanggalText(DateTime d) =>
      '${DateFormat('EEEE', 'id_ID').format(d)}, ${DateFormat('d MMM yyyy', 'id_ID').format(d)}';

  // Catatan bebas dari form Buat Laporan — sama persis field yang diisi
  // guru pembimbing di sana (SantriRecord.catatan), bukan kolom baru
  // yang beda sumber.
  String _catatanText(SantriRecord r) {
    final c = r.catatan?.trim();
    return (c == null || c.isEmpty) ? '-' : c;
  }

  /// Kolom Nilai = isian "Nilai" di form laporan (ketik bebas); '-' kalau kosong.
  String _nilaiText(SantriRecord r) {
    final v = r.nilai?.trim() ?? '';
    return v.isEmpty ? '-' : v;
  }

  /// Nilai 1 siswa dalam 1 pekan = rata-rata nilai harian ('-' kalau tidak ada nilai).
  String nilaiSummaryFor(List<SantriRecord> recs) => NilaiAverage.summaryText(recs.map((r) => r.nilai));

  /// Kolom Status harian = ketuntasan dari keterangan laporan (lihat [StandarKetuntasan]).
  String _statusText(SantriRecord r) => StandarKetuntasan.harianText(r);

  String joinUnique(Iterable<String> values) {
    final set = values.map((v) => v.trim()).where((v) => v.isNotEmpty).toSet().toList()..sort();
    return set.join(', ');
  }

  List<List<String>> buildRows(List<SantriRecord> records) {
    final rows = <List<String>>[];
    for (var i = 0; i < records.length; i++) {
      final r = records[i];
      rows.add([
        '${i + 1}',
        r.namaAnak,
        _capaianLabel(r),
        _ayatHalRange(r),
        _barisText(r),
        r.keterangan.label,
        _nilaiText(r),
        _statusText(r),
        _catatanText(r),
      ]);
    }
    return rows;
  }

  /// Versi [buildRows] dengan kolom Hari/Tanggal gabungan. Bila [fixedTanggalLabel] diisi, SEMUA baris
  /// memakai label itu (bukan tanggal tiap record) — dipakai Generate Laporan Pekanan yang menampilkan
  /// tanggal laporan TERAKHIR dalam pekan itu (lihat GenerateRekapPekananScreen).
  List<List<String>> buildRowsWithTanggal(List<SantriRecord> records, {String? fixedTanggalLabel}) {
    final rows = <List<String>>[];
    for (var i = 0; i < records.length; i++) {
      final r = records[i];
      rows.add([
        '${i + 1}',
        fixedTanggalLabel ?? _hariTanggalText(r.tanggal),
        r.namaAnak,
        _capaianLabel(r),
        _ayatHalRange(r),
        _barisText(r),
        r.keterangan.label,
        _nilaiText(r),
        _statusText(r),
        _catatanText(r),
      ]);
    }
    return rows;
  }

  // Wrapper publik untuk widget UI yang harus menampilkan isi kolom PERSIS seperti hasil export
  // (mis. [ExportStyleRecordsTable]), agar sumber logic tetap satu dan tidak diduplikasi di widget.
  String capaianLabelFor(SantriRecord r) => _capaianLabel(r);

  String ayatHalRangeFor(SantriRecord r) => _ayatHalRange(r);

  String barisTextFor(SantriRecord r) => _barisText(r);

  String catatanTextFor(SantriRecord r) => _catatanText(r);

  String statusTextFor(SantriRecord r) => _statusText(r);
  String nilaiTextFor(SantriRecord r) => _nilaiText(r);

  String hariTanggalTextFor(DateTime d) => _hariTanggalText(d);

  // ---- Generate Laporan Pekanan: gabung per SANTRI ----
  // Beda dari buildRows/buildRowsWithTanggal (1 baris = 1 LAPORAN): 1 baris = 1 SANTRI, Capaian dipecah per
  // jenis dan Baris di-SUM dari semua laporan santri itu (dipakai GenerateRekapPekananScreen).
  static const weeklyHeaders = [
    'No',
    'Hari/Tanggal',
    'Nama Siswa',
    'Capaian',
    'Baris',
    'Keterangan',
    'Nilai',
    'Status',
    'Catatan',
  ];
}

/// Nama file dasar dari [s] (huruf kecil, non-alfanumerik jadi `_`) + timestamp.
String exportFileSlug(String s) {
  final base = s.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  final ts = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
  return '${base}_$ts';
}
