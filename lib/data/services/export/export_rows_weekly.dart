part of 'export_rows.dart';

/// Baris Generate Laporan Pekanan (per santri) dan rekap bulanan. Dipisah dari [ExportRows]
/// supaya file tidak membengkak; cara pemanggilan TIDAK berubah.
extension ExportRowsWeeklyMonthly on ExportRows {
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
    return segs.map((s) => '${s.surahName} (${s.ayatMulai}-${s.ayatSelesai})').join(', ');
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
      nilai: nilaiSummaryFor(recs),
      status: StandarKetuntasan.manualPekan(recs),
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
          rows[i].nilai,
          rows[i].status,
          rows[i].catatan,
        ],
    ];
  }

  /// Ringkasan "Nx `<jenis>`" per santri untuk semua Keterangan SELAIN Hadir
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
    'Nama Siswa',
    for (var w = 1; w <= totalWeeks; w++) 'Pekan $w',
    'Total Baris',
    'Keterangan',
    'Nilai',
    'Status',
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
        r.nilaiSummaryText,
        r.tuntasSummaryText,
      ]);
    }
    return rows;
  }
}
