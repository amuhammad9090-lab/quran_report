import 'package:intl/intl.dart';

import '../../models/enums.dart';
import '../../models/santri_monthly_recap.dart';
import '../../models/santri_record.dart';

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
  final String catatan;

  const SantriWeeklyRow({
    required this.namaAnak,
    required this.tanggalLabel,
    required this.capaian,
    required this.totalBaris,
    required this.keterangan,
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
    'Nama Murid',
    'Capaian Tahsin/Tahfizh',
    'Ayat/Hal',
    'Baris',
    'Keterangan',
    'Catatan',
  ];

  // ---- Export Rekap Kehadiran BULANAN: 1 tabel per Kelas+Halaqoh, baris = santri, kolom = tanggal 1..N ----
  static const judulKehadiran = 'REKAP KEHADIRAN SANTRI';
  static const attendanceTotalLabels = ['H', 'S', 'I', 'L', 'P', 'A'];
  static const attendanceLegend =
      'Keterangan: H = Hadir (termasuk tidak setoran/tahsin/murojaah), S = Sakit, I = Izin, '
      'L = Izin Lomba, P = Izin Pelatihan, A = Alpa. Kotak kosong = tidak ada laporan di hari itu.';

  int daysInMonth(DateTime month) => DateTime(month.year, month.month + 1, 0).day;

  List<String> attendanceMonthHeaders(DateTime month) => [
        'No',
        'Nama Murid',
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
    'Nama Murid',
    'Capaian Tahsin/Tahfizh',
    'Ayat/Hal',
    'Baris',
    'Keterangan',
    'Catatan',
  ];

  /// Teks ringkas bagian Tahsin saja (WAFA atau Tilawah)
  String _tahfizhSurahNames(SantriRecord r) {
    final segs = r.tahfizhSegmentsEffective;
    return segs.isEmpty ? '-' : segs.map((s) => s.surahName).join(', ');
  }

  String _tahfizhAyatRanges(SantriRecord r) {
    final segs = r.tahfizhSegmentsEffective;
    return segs.isEmpty ? '-' : segs.map((s) => '${s.ayatMulai}-${s.ayatSelesai}').join(' + ');
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
          : segs.map((s) => '${s.ayatMulai}-${s.ayatSelesai}').join(' + ');
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
            : segs.map((s) => '${s.ayatMulai}-${s.ayatSelesai}').join(' + ');
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

  String hariTanggalTextFor(DateTime d) => _hariTanggalText(d);

  // ---- Generate Laporan Pekanan: gabung per SANTRI ----
  // Beda dari buildRows/buildRowsWithTanggal (1 baris = 1 LAPORAN): 1 baris = 1 SANTRI, Capaian dipecah per
  // jenis dan Baris di-SUM dari semua laporan santri itu (dipakai GenerateRekapPekananScreen).
  static const weeklyHeaders = [
    'No',
    'Hari/Tanggal',
    'Nama Murid',
    'Capaian',
    'Baris',
    'Keterangan',
    'Catatan',
  ];

  // Detail 1 laporan TANPA prefix label status: label ditulis SEKALI per jenis di gabungan
  // per-jenis (beda dari _capaianLabel yang selalu memberi prefix status).
  String _tahsinDetailNoLabel(SantriRecord r) {
    final label = _tahsinPartLabel(r);
    final range = _tahsinPartRange(r);
    return range == '-' ? label : '$label ($range)';
  }

  String _tahfizhDetailNoLabel(SantriRecord r) {
    final names = _tahfizhSurahNames(r);
    final ranges = _tahfizhAyatRanges(r);
    return ranges == '-' ? names : '$names ($ranges)';
  }

  String _murojaahDetailNoLabel(SantriRecord r) {
    final segs = r.tilawahSegmentsEffective;
    if (segs.isEmpty) return '-';
    return segs.map((s) => '${s.surahName} (${s.ayatMulai}-${s.ayatSelesai})').join(' + ');
  }

  // Gabung SEMUA laporan jenis yang sama dalam 1 pekan jadi 1 blok "Label: ..." — 1 laporan tetap 1
  // baris ("Tahsin: xxx"), >1 dipecah per baris (1 baris = 1 hari setoran) agar rapi di Excel
  // (pola sama dengan SantriMonthlyRecap.capaianForWeek).
  String _joinCategoryPerLine(String label, Iterable<String> details) {
    final list = details.toList();
    if (list.isEmpty) return '';
    if (list.length == 1) return '$label: ${list.first}';
    return '$label:\n${list.join('\n')}';
  }

  String _weeklyCapaianForSantri(List<SantriRecord> recs) {
    final lines = <String>[];
    final tahsin = recs.where((r) => r.status == HafalanStatus.tahsin).toList();
    if (tahsin.isNotEmpty) {
      lines.add(_joinCategoryPerLine('Tahsin', tahsin.map(_tahsinDetailNoLabel)));
    }
    final tahfizh = recs.where((r) => r.status == HafalanStatus.tahfizh).toList();
    if (tahfizh.isNotEmpty) {
      lines.add(_joinCategoryPerLine('Tahfizh', tahfizh.map(_tahfizhDetailNoLabel)));
    }
    final gabungan = recs.where((r) => r.status == HafalanStatus.tahsinTahfizh).toList();
    if (gabungan.isNotEmpty) {
      lines.add(_joinCategoryPerLine(
        'Tahsin+Tahfizh',
        gabungan.map((r) => '${_tahsinDetailNoLabel(r)} & ${_tahfizhDetailNoLabel(r)}'),
      ));
    }
    final murojaah = recs.where((r) => r.status == HafalanStatus.murojaahTasmi).toList();
    if (murojaah.isNotEmpty) {
      lines.add(_joinCategoryPerLine("Muroja'ah/Tasmi'", murojaah.map(_murojaahDetailNoLabel)));
    }
    return lines.isEmpty ? '-' : lines.join('\n');
  }

  // Sama polanya seperti SantriMonthlyRecap.keteranganSummaryText: Hadir
  // tidak dihitung (bukan "keterangan" yang perlu disorot), '-' kalau
  // semua laporan pekan itu Hadir.
  String _weeklyKeteranganForSantri(List<SantriRecord> recs) {
    final counts = <Keterangan, int>{};
    for (final r in recs) {
      if (r.keterangan == Keterangan.hadir) continue;
      counts[r.keterangan] = (counts[r.keterangan] ?? 0) + 1;
    }
    if (counts.isEmpty) return '-';
    final entries = counts.entries.toList()..sort((a, b) => a.key.index.compareTo(b.key.index));
    return entries.map((e) => '${e.value}x ${e.key.shortLabel}').join(', ');
  }

  String _weeklyCatatanForSantri(List<SantriRecord> recs) {
    final notes = recs.map((r) => r.catatan?.trim() ?? '').where((c) => c.isNotEmpty).toList();
    return notes.isEmpty ? '-' : notes.join('; ');
  }

  /// Kumpulkan [records] (biasanya 1 Kelas+Halaqoh dalam 1 pekan) jadi 1 baris per SANTRI (lihat
  /// [SantriWeeklyRow]). Tanggal = [fixedTanggalLabel] bila diisi, kalau tidak tanggal laporan TERAKHIR
  /// santri itu di pekan tsb. Terurut nama (case-insensitive).
  List<SantriWeeklyRow> weeklyRowsGroupedBySantriFor(
      List<SantriRecord> records, {
        String? fixedTanggalLabel,
      }) {
    final byKey = <String, List<SantriRecord>>{};
    final displayName = <String, String>{};
    for (final r in records) {
      final key = r.namaAnak.trim().toLowerCase();
      byKey.putIfAbsent(key, () => []).add(r);
      displayName[key] = r.namaAnak.trim();
    }
    final keys = byKey.keys.toList()
      ..sort((a, b) => (displayName[a] ?? a).toLowerCase().compareTo((displayName[b] ?? b).toLowerCase()));

    return [
      for (final key in keys)
        _buildWeeklyRow(
          nama: displayName[key] ?? key,
          recs: List<SantriRecord>.from(byKey[key]!)..sort((a, b) => a.tanggal.compareTo(b.tanggal)),
          fixedTanggalLabel: fixedTanggalLabel,
        ),
    ];
  }

  SantriWeeklyRow _buildWeeklyRow({
    required String nama,
    required List<SantriRecord> recs,
    String? fixedTanggalLabel,
  }) {
    return SantriWeeklyRow(
      namaAnak: nama,
      tanggalLabel: fixedTanggalLabel ?? _hariTanggalText(recs.last.tanggal),
      capaian: _weeklyCapaianForSantri(recs),
      totalBaris: recs.fold<int>(0, (sum, r) => sum + (r.totalBaris ?? 0)),
      keterangan: _weeklyKeteranganForSantri(recs),
      catatan: _weeklyCatatanForSantri(recs),
    );
  }

  // Versi teks List<List<String>> dari [weeklyRowsGroupedBySantriFor] untuk export (Pdf/Excel/Word);
  // sumber logic-nya SAMA sehingga preview dan hasil export identik.
  List<List<String>> buildWeeklyRowsText(
      List<SantriRecord> records, {
        String? fixedTanggalLabel,
      }) {
    final rows = weeklyRowsGroupedBySantriFor(records, fixedTanggalLabel: fixedTanggalLabel);
    return [
      for (var i = 0; i < rows.length; i++)
        [
          '${i + 1}',
          rows[i].tanggalLabel,
          rows[i].namaAnak,
          rows[i].capaian,
          '${rows[i].totalBaris}',
          rows[i].keterangan,
          rows[i].catatan,
        ],
    ];
  }

  /// Ringkasan "Nx <jenis>" per santri untuk semua Keterangan SELAIN Hadir
  /// (Izin Sakit, Izin Lomba, Izin Pelatihan, Alpa)
  List<MapEntry<String, String>> keteranganSummaryPerSantri(List<SantriRecord> records) {
    final byName = <String, Map<Keterangan, int>>{};
    for (final r in records) {
      if (r.keterangan == Keterangan.hadir) continue;
      final name = r.namaAnak.trim();
      if (name.isEmpty) continue;
      final counts = byName.putIfAbsent(name, () => {});
      counts[r.keterangan] = (counts[r.keterangan] ?? 0) + 1;
    }
    final names = byName.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [
      for (final name in names)
        MapEntry(
          name,
          (byName[name]!.entries.toList()..sort((a, b) => a.key.index.compareTo(b.key.index)))
              .map((e) => '${e.value}x ${e.key.shortLabel}')
              .join(', '),
        ),
    ];
  }

  List<String> monthlyHeaders(int totalWeeks) => [
    'No',
    'Nama Murid',
    for (var w = 1; w <= totalWeeks; w++) 'Pekan $w',
    'Total Baris',
    'Keterangan',
  ];

  List<List<String>> monthlyRows(List<SantriMonthlyRecap> recaps, int totalWeeks) {
    final rows = <List<String>>[];
    for (var i = 0; i < recaps.length; i++) {
      final r = recaps[i];
      rows.add([
        '${i + 1}',
        r.nama,
        for (var w = 1; w <= totalWeeks; w++) r.capaianForWeek(w),
        '${r.totalBaris}',
        r.keteranganSummaryText,
      ]);
    }
    return rows;
  }
}

/// Nama file dasar dari [s] (huruf kecil, non-alfanumerik jadi `_`) + timestamp.
String exportFileSlug(String s) {
  final base = s.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  final ts = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
  return '${base}_$ts';
}
