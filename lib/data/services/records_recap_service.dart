import '../../core/utils/week_utils.dart';
import '../models/enums.dart';
import '../models/records_view_models.dart';
import '../models/santri_monthly_recap.dart';
import '../models/santri_record.dart';

/// Kalkulasi baca-saja (ringkasan, rekap, pengelompokan) atas SATU snapshot
/// laporan yang sudah discope. Hasil di-memo per instance; [RecordsProvider]
/// membuat instance baru tiap data/scope berubah, jadi cache otomatis kosong.
class RecordsRecapService {
  RecordsRecapService(this._records);

  final List<SantriRecord> _records;

  // --- Ringkasan header ---
  int? _totalSantri;
  int? _totalHadir;
  int? _totalBarisSetoran;

  void _ensureSummary() {
    if (_totalSantri != null) return;
    _totalSantri = _records.map((r) => r.namaAnak).toSet().length;
    _totalHadir = _records
        .where((r) => r.keterangan == Keterangan.hadir || r.keterangan.isSanksiTanpaSetoran)
        .length;
    _totalBarisSetoran = _records.fold<int>(0, (sum, r) => sum + (r.totalBaris ?? 0));
  }

  int get totalSantri {
    _ensureSummary();
    return _totalSantri!;
  }

  // "Hadir" = fisiknya hadir, termasuk 3 keterangan sanksi (Tidak Setoran/Tahsin/Murojaah);
  // beda dari Izin Sakit/Izin/Izin Lomba/Izin Pelatihan/Alpa yang tidak hadir.
  int get totalHadir {
    _ensureSummary();
    return _totalHadir!;
  }

  int get totalBarisSetoran {
    _ensureSummary();
    return _totalBarisSetoran!;
  }

  // Tahsin+Tahfizh dihitung di KEDUA total (punya kedua komponen), agar kartu ringkasan
  // mencerminkan semua laporan yang punya komponen itu.
  bool _hasTahfizhComponent(SantriRecord r) =>
      r.status == HafalanStatus.tahfizh || r.status == HafalanStatus.tahsinTahfizh;
  bool _hasTahsinComponent(SantriRecord r) =>
      r.status == HafalanStatus.tahsin || r.status == HafalanStatus.tahsinTahfizh;

  /// Total ayat tersetor per pekan (Senin–Minggu, [WeekUtils.startOfWeek]) untuk [weekCount]
  /// pekan terakhir termasuk pekan ini (chart "Ayat Tersetor/Minggu"); bukan "pekan dalam
  /// bulan" karena rentangnya bisa lintas bulan. Terurut terlama -> terbaru.
  List<WeeklyAyatPoint> weeklyAyatSummary({int weekCount = 6}) {
    final thisWeekStart = WeekUtils.startOfWeek(DateTime.now());
    final totals = List<int>.filled(weekCount, 0);

    for (final r in _records) {
      final recordWeekStart = WeekUtils.startOfWeek(r.tanggal);
      final diffWeeks = thisWeekStart.difference(recordWeekStart).inDays ~/ 7;
      final index = weekCount - 1 - diffWeeks; // 0 = pekan terlama
      if (index >= 0 && index < weekCount) {
        totals[index] += r.jumlahAyat;
      }
    }

    return List.generate(weekCount, (i) {
      final weekStart = thisWeekStart.subtract(Duration(days: (weekCount - 1 - i) * 7));
      return WeeklyAyatPoint(weekStart: weekStart, total: totals[i]);
    });
  }

  // --- Ringkasan "Hari Ini" untuk Home & Profile ---
  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  List<SantriRecord> get _todayRecords => _records.where((r) => _isToday(r.tanggal)).toList();

  int get laporanBaruHariIni => _todayRecords.length;
  int get totalBarisHariIni => _todayRecords.fold(0, (sum, r) => sum + (r.totalBaris ?? 0));
  int get santriAktifHariIni => _todayRecords.map((r) => r.namaAnak).toSet().length;

  // --- Dataset dropdown form (Kelas/Halaqoh) ---
  // Dari data ter-scope, di-trim lalu di-dedupe agar "VII Istanbul " dan "VII Istanbul"
  // tidak jadi dua chip. Di UI digabung dengan master santri (lihat record_form_sheet).
  List<String> get distinctKelas => _records
      .map((r) => r.kelas.trim())
      .where((v) => v.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  List<String> get distinctHalaqoh => _records
      .map((r) => r.halaqoh.trim())
      .where((v) => v.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  /// `lineId` yang sudah pernah dihitung di laporan tahfizh sebelumnya untuk santri
  /// [namaAnak] (case-insensitive, trimmed). [excludeRecordId] agar record yang sedang
  /// diedit tidak mengecualikan barisnya sendiri.
  Set<String> lineHistoryFor(String namaAnak, {String? excludeRecordId}) {
    final key = namaAnak.trim().toLowerCase();
    if (key.isEmpty) return {};

    final ids = <String>{};
    for (final r in _records) {
      if (r.id == excludeRecordId) continue;
      if (r.namaAnak.trim().toLowerCase() != key) continue;
      if (r.lineIds == null) continue;
      ids.addAll(r.lineIds!);
    }
    return ids;
  }

  // --- Daftar santri unik (halaman "Daftar Santri" di Statistik) ---
  // Kelas/halaqoh dari record TERBARU santri itu, bukan record pertama.
  List<SantriSummary>? _santriList;
  List<SantriSummary> get santriList {
    if (_santriList != null) return _santriList!;
    final latestBySantri = <String, SantriRecord>{};
    for (final r in _records) {
      final key = r.namaAnak.trim().toLowerCase();
      if (key.isEmpty) continue;
      final existing = latestBySantri[key];
      if (existing == null || r.tanggal.isAfter(existing.tanggal)) {
        latestBySantri[key] = r;
      }
    }
    final list = latestBySantri.values
        .map((r) => SantriSummary(nama: r.namaAnak, kelas: r.kelas, halaqoh: r.halaqoh))
        .toList()
      ..sort((a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));
    _santriList = list;
    return list;
  }

  /// Semua laporan satu santri (match nama, case-insensitive), terbaru duluan.
  /// Di-cache per nama — dipanggil berulang dari Detail Santri & tab Laporan.
  final Map<String, List<SantriRecord>> _recordsForSantriCache = {};
  List<SantriRecord> recordsForSantri(String namaAnak) {
    final key = namaAnak.trim().toLowerCase();
    return _recordsForSantriCache.putIfAbsent(key, () {
      final list = _records.where((r) => r.namaAnak.trim().toLowerCase() == key).toList()
        ..sort((a, b) => b.tanggal.compareTo(a.tanggal));
      return list;
    });
  }

  /// Kelompokkan [records] per tanggal (jam diabaikan), terbaru duluan.
  /// Dipakai bareng [DateGroupCard] di Detail Santri, Kehadiran, dan Rekap Bulanan/Pekanan.
  static Map<DateTime, List<SantriRecord>> groupByDate(List<SantriRecord> records) {
    final map = <DateTime, List<SantriRecord>>{};
    for (final r in records) {
      final key = DateTime(r.tanggal.year, r.tanggal.month, r.tanggal.day);
      map.putIfAbsent(key, () => []).add(r);
    }
    final sortedKeys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final k in sortedKeys) k: map[k]!};
  }

  /// Semua laporan, terbaru duluan — dipakai halaman Kehadiran (di-cache).
  List<SantriRecord>? _allSortedByDateDesc;
  List<SantriRecord> get allSortedByDateDesc {
    if (_allSortedByDateDesc == null) {
      _allSortedByDateDesc = List<SantriRecord>.from(_records)
        ..sort((a, b) => b.tanggal.compareTo(a.tanggal));
    }
    return _allSortedByDateDesc!;
  }

  // --- Rekap bulan/pekan/hari ---
  // Di-memo per instance (key = string tanggal) karena dipanggil berulang tiap build
  // (Rekap Bulanan/Pekan/Harian, Generate Rekap Bulanan/Pekanan).
  final Map<String, List<SantriRecord>> _recordsInMonthCache = {};
  final Map<String, List<SantriRecord>> _recordsInMonthWeekCache = {};
  final Map<String, List<SantriRecord>> _recordsOnDateCache = {};
  final Map<String, List<MonthWeekSummary>> _monthWeekSummariesCache = {};
  final Map<String, List<SantriMonthlyRecap>> _monthlySantriRecapsCache = {};

  String _monthKey(DateTime month) => '${month.year}-${month.month}';
  String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<SantriRecord> recordsInMonth(DateTime month) {
    return _recordsInMonthCache.putIfAbsent(_monthKey(month), () {
      // BUG FIX: total bulan dibangun dari GABUNGAN semua Pekan milik bulan ini (definisi
      // sama dengan breakdown per-Pekan), bukan kalender murni — jadi tanggal ujung bulan
      // (mis. 31 Agustus = Pekan 1 September) konsisten di semua tempat, tidak "hilang".
      final totalWeeks = WeekUtils.weeksInMonth(month);
      final seenIds = <String>{};
      final list = <SantriRecord>[];
      for (var weekIndex = 1; weekIndex <= totalWeeks; weekIndex++) {
        for (final r in recordsInMonthWeek(month, weekIndex)) {
          if (seenIds.add(r.id)) list.add(r);
        }
      }
      list.sort((a, b) => b.tanggal.compareTo(a.tanggal));
      return list;
    });
  }

  int totalTahfizhInMonth(DateTime month) =>
      recordsInMonth(month).where(_hasTahfizhComponent).length;

  int totalTahsinInMonth(DateTime month) =>
      recordsInMonth(month).where(_hasTahsinComponent).length;

  int totalBarisInMonth(DateTime month) =>
      recordsInMonth(month).fold(0, (sum, r) => sum + (r.totalBaris ?? 0));

  // Pekan DALAM BULAN — dipakai Statistik → Rekap Bulanan → Pekan 1..6 dan indikator
  // pekan di kartu santri (lihat catatan desain di WeekUtils).
  List<SantriRecord> recordsInMonthWeek(DateTime month, int weekIndex) {
    return _recordsInMonthWeekCache.putIfAbsent('${_monthKey(month)}-$weekIndex', () {
      // Dari rentang tanggal pekan (bukan recordsInMonth + weekOfMonth): pekan boleh lintas
      // bulan (lihat WeekUtils), jadi laporan di ujung bulan yang "dimiliki" pekan bulan
      // tetangga tetap ketemu.
      final range = WeekUtils.monthWeekRange(month, weekIndex);
      return _records.where((r) {
        final d = DateTime(r.tanggal.year, r.tanggal.month, r.tanggal.day);
        return !d.isBefore(range.start) && !d.isAfter(range.end);
      }).toList()
        // BUG FIX: ascending (lama -> baru); dulu descending sehingga kolom "Capaian"
        // gabungan (Rekap Bulanan/Pekanan, tabel harian) urutannya kebalik.
        ..sort((a, b) => a.tanggal.compareTo(b.tanggal));
    });
  }

  /// Semua laporan tepat pada tanggal [date] (jam diabaikan), terurut nama — dipakai
  /// [RekapHarianDetailScreen] (tap baris hari di "Rekap Harian" pada Rekap Pekan).
  List<SantriRecord> recordsOnDate(DateTime date) {
    return _recordsOnDateCache.putIfAbsent(_dateKey(date), () {
      return _records.where((r) => _isSameDay(r.tanggal, date)).toList()
        ..sort((a, b) => a.namaAnak.toLowerCase().compareTo(b.namaAnak.toLowerCase()));
    });
  }

  /// Ringkasan tiap Pekan (1..N sesuai jumlah hari bulan itu) dalam [month] — dipakai
  /// daftar "Pekan 1 / Pekan 2 / ..." di Rekap Bulanan.
  List<MonthWeekSummary> monthWeekSummaries(DateTime month) {
    return _monthWeekSummariesCache.putIfAbsent(_monthKey(month), () {
      final total = WeekUtils.weeksInMonth(month);
      return List.generate(total, (i) {
        final weekIndex = i + 1;
        final recs = recordsInMonthWeek(month, weekIndex);
        return MonthWeekSummary(
          weekIndex: weekIndex,
          range: WeekUtils.monthWeekRange(month, weekIndex),
          santriCount: recs.map((r) => r.namaAnak.trim().toLowerCase()).toSet().length,
          laporanCount: recs.length,
          totalBaris: recs.fold(0, (sum, r) => sum + (r.totalBaris ?? 0)),
        );
      });
    });
  }

  /// Nomor pekan dalam [month] yang sudah punya laporan untuk santri [namaAnak]
  /// (case-insensitive) — indikator "✓1 ✓2 3 4 5" di kartu santri.
  Set<int> weeksWithReportForSantriInMonth(String namaAnak, DateTime month) {
    final key = namaAnak.trim().toLowerCase();
    final total = WeekUtils.weeksInMonth(month);
    final result = <int>{};
    for (var weekIndex = 1; weekIndex <= total; weekIndex++) {
      final hasReport = recordsInMonthWeek(month, weekIndex)
          .any((r) => r.namaAnak.trim().toLowerCase() == key);
      if (hasReport) result.add(weekIndex);
    }
    return result;
  }

  /// Rekap gabungan PER SANTRI satu bulan penuh (fitur "Generate Rekap Bulanan"), dibangun
  /// dari [recordsInMonthWeek] tiap pekan agar konsisten dengan Rekap Bulanan → Pekan
  /// (termasuk laporan ujung bulan). Terurut nama (case-insensitive).
  List<SantriMonthlyRecap> monthlySantriRecaps(DateTime month) {
    final cached = _monthlySantriRecapsCache[_monthKey(month)];
    if (cached != null) return cached;

    final totalWeeks = WeekUtils.weeksInMonth(month);

    final recordsByKeyWeek = <String, Map<int, List<SantriRecord>>>{};
    final namaByKey = <String, String>{};
    final kelasByKey = <String, String>{};
    final halaqohByKey = <String, String>{};
    // Laporan terbaru per santri; dipakai memilih nama/kelas/halaqoh yang ditampilkan.
    final latestSeen = <String, DateTime>{};

    for (var weekIndex = 1; weekIndex <= totalWeeks; weekIndex++) {
      for (final r in recordsInMonthWeek(month, weekIndex)) {
        final key = r.namaAnak.trim().toLowerCase();
        recordsByKeyWeek.putIfAbsent(key, () => {}).putIfAbsent(weekIndex, () => []).add(r);
        // Nama/kelas/halaqoh diambil dari laporan TERBARU santri (bukan pekan pertama)
        // agar ikut berubah kalau santri pindah kelas/halaqoh di tengah bulan.
        if (!namaByKey.containsKey(key) || r.tanggal.isAfter(latestSeen[key] ?? DateTime(0))) {
          namaByKey[key] = r.namaAnak.trim();
          kelasByKey[key] = r.kelas;
          halaqohByKey[key] = r.halaqoh;
          latestSeen[key] = r.tanggal;
        }
      }
    }

    final result = <SantriMonthlyRecap>[];
    for (final key in recordsByKeyWeek.keys) {
      final byWeek = recordsByKeyWeek[key]!;
      final allRecords = byWeek.values.expand((l) => l).toList();
      final keteranganCounts = <Keterangan, int>{};
      // Hitung juga berapa kali status "memang 0 baris" (Tahsin murni / Muroja'ah-Tasmi'),
      // dipakai SantriMonthlyRecap.keteranganSummaryText agar kolom Keterangan menjelaskan
      // KENAPA baris-nya 0 (bukan bolong laporan).
      final zeroBarisStatusCounts = <HafalanStatus, int>{};
      for (final r in allRecords) {
        if (r.keterangan != Keterangan.hadir) {
          keteranganCounts[r.keterangan] = (keteranganCounts[r.keterangan] ?? 0) + 1;
        }
        if (r.status.isZeroBarisByDesign) {
          zeroBarisStatusCounts[r.status] = (zeroBarisStatusCounts[r.status] ?? 0) + 1;
        }
      }
      result.add(SantriMonthlyRecap(
        nama: namaByKey[key] ?? key,
        kelas: kelasByKey[key] ?? '-',
        halaqoh: halaqohByKey[key] ?? '-',
        recordsByWeek: byWeek,
        totalBaris: allRecords.fold(0, (sum, r) => sum + (r.totalBaris ?? 0)),
        keteranganCounts: keteranganCounts,
        zeroBarisStatusCounts: zeroBarisStatusCounts,
      ));
    }
    result.sort((a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));
    _monthlySantriRecapsCache[_monthKey(month)] = result;
    return result;
  }

  /// Laporan (jika ada) santri [namaAnak] pada tanggal PERSIS [date] — dicek per-HARI, bukan
  /// per-pekan (BUG FIX: per-pekan membuka laporan Senin sebagai edit saat mengisi Selasa
  /// dan menimpanya). Dipakai laporan_tab _openWeek, search_results_screen, folder_detail_screen.
  SantriRecord? recordForSantriOnDate(String namaAnak, DateTime date) {
    final key = namaAnak.trim().toLowerCase();
    for (final r in _records) {
      if (r.namaAnak.trim().toLowerCase() == key && _isSameDay(r.tanggal, date)) {
        return r;
      }
    }
    return null;
  }

  /// Semua laporan santri [namaAnak] pada rentang [start]..[end] (inklusif, kalender biasa,
  /// bukan kepemilikan pekan), terurut lama -> baru. Dipakai openWeekForSantri untuk
  /// mendeteksi laporan di hari LAIN pekan berjalan (lihat open_week_action.dart).
  List<SantriRecord> recordsForSantriInRange(String namaAnak, DateTime start, DateTime end) {
    if (end.isBefore(start)) return const [];
    final key = namaAnak.trim().toLowerCase();
    return _records.where((r) {
      if (r.namaAnak.trim().toLowerCase() != key) return false;
      final d = DateTime(r.tanggal.year, r.tanggal.month, r.tanggal.day);
      return !d.isBefore(start) && !d.isAfter(end);
    }).toList()
      ..sort((a, b) => a.tanggal.compareTo(b.tanggal));
  }

  /// Kelompokkan [records] per pasangan Kelas+Halaqoh (Rekap Bulanan, per Kelas & Halaqoh),
  /// terurut Kelas lalu Halaqoh; isi tiap grup terurut tanggal terlama lalu nama.
  static List<KelasHalaqohGroup> groupByKelasHalaqoh(List<SantriRecord> records) {
    // Key = kelas+halaqoh di-trim & lowercase HANYA untuk perbandingan (menutup bug "duplicate
    // Halaqoh" akibat spasi/kapital beda); label yang ditampilkan tetap data asli yang di-trim.
    final map = <String, List<SantriRecord>>{};
    final displayKelas = <String, String>{};
    final displayHalaqoh = <String, String>{};
    for (final r in records) {
      final kelasTrim = r.kelas.trim();
      final halaqohTrim = r.halaqoh.trim();
      final key = '${kelasTrim.toLowerCase()}|${halaqohTrim.toLowerCase()}';
      map.putIfAbsent(key, () => []).add(r);
      displayKelas.putIfAbsent(key, () => kelasTrim);
      displayHalaqoh.putIfAbsent(key, () => halaqohTrim);
    }
    final groups = map.entries.map((e) {
      final list = List<SantriRecord>.from(e.value)
        ..sort((a, b) {
          final byDate = a.tanggal.compareTo(b.tanggal);
          if (byDate != 0) return byDate;
          return a.namaAnak.toLowerCase().compareTo(b.namaAnak.toLowerCase());
        });
      return KelasHalaqohGroup(
        kelas: displayKelas[e.key]!,
        halaqoh: displayHalaqoh[e.key]!,
        records: list,
      );
    }).toList()
      ..sort((a, b) {
        final byKelas = a.kelas.toLowerCase().compareTo(b.kelas.toLowerCase());
        if (byKelas != 0) return byKelas;
        return a.halaqoh.toLowerCase().compareTo(b.halaqoh.toLowerCase());
      });
    return groups;
  }
}
