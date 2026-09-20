import '../../core/utils/week_utils.dart';
import 'santri_record.dart';

/// Ringkasan satu santri unik (daftar santri di Statistik), diambil dari
/// record TERBARU santri itu (kelas/halaqoh bisa berubah).
class SantriSummary {
  final String nama;
  final String kelas;
  final String halaqoh;
  const SantriSummary({required this.nama, required this.kelas, required this.halaqoh});
}

/// Ringkasan satu pekan DALAM BULAN (Pekan 1..6) untuk Rekap Bulanan → daftar
/// Pekan, lihat [RecordsProvider.monthWeekSummaries].
class MonthWeekSummary {
  final int weekIndex;
  final MonthWeekRange range;
  final int santriCount;
  final int laporanCount;
  final int totalBaris;
  const MonthWeekSummary({
    required this.weekIndex,
    required this.range,
    required this.santriCount,
    required this.laporanCount,
    required this.totalBaris,
  });
}

/// Data 1 kartu santri di tab Laporan — mewakili SATU santri (bukan satu
/// laporan/pekan), lihat [RecordsProvider.laporanCards]. Identitas dikunci
/// oleh [identityKey] = "kelas|halaqoh|nama" (lowercase, trimmed).
class SantriCardInfo {
  final String identityKey;
  final String nama;
  final String kelas;
  final String halaqoh;

  /// Nomor pekan (bulan berjalan) yang sudah punya laporan — indikator "✓1 ✓2 3 4 5".
  final Set<int> weeksWithReportThisMonth;
  final int totalWeeksThisMonth;

  /// Laporan terbaru santri ini (semua waktu); null bila kartu baru diaktifkan
  /// dan belum pernah diisi laporan.
  final SantriRecord? latestRecord;

  /// Hanya berarti bila [latestRecord] null: folder tujuan yang dipilih user saat
  /// kartu kosong dipindah (null = belum di folder mana pun), lihat
  /// [RecordsProvider.moveIdentityToFolder].
  final String? emptyCardFolderId;

  const SantriCardInfo({
    required this.identityKey,
    required this.nama,
    required this.kelas,
    required this.halaqoh,
    required this.weeksWithReportThisMonth,
    required this.totalWeeksThisMonth,
    required this.latestRecord,
    this.emptyCardFolderId,
  });

  bool get hasAnyReport => latestRecord != null;

  /// Folder "rumah" kartu saat ini: dari laporan terbaru bila ada, kalau tidak dari
  /// [emptyCardFolderId]. Null = "Tanpa Folder" (lihat [RecordsProvider.cardsInFolder]).
  String? get currentFolderId => hasAnyReport ? latestRecord!.folderId : emptyCardFolderId;
}

/// Kunci identitas "kelas|halaqoh|nama" yang dipakai konsisten di [RecordsProvider]
/// (kartu Laporan & aktivasi identitas); trim + lowercase agar tidak ganda gara-gara
/// beda kapital/spasi.
String reportIdentityKey(String kelas, String halaqoh, String nama) =>
    '${kelas.trim().toLowerCase()}|${halaqoh.trim().toLowerCase()}|${nama.trim().toLowerCase()}';

/// Satu kelompok laporan milik 1 pasangan Kelas+Halaqoh dalam suatu periode
/// (Rekap Bulanan), lihat [RecordsProvider.groupByKelasHalaqoh].
class KelasHalaqohGroup {
  final String kelas;
  final String halaqoh;
  final List<SantriRecord> records;
  const KelasHalaqohGroup({
    required this.kelas,
    required this.halaqoh,
    required this.records,
  });

  int get totalBaris => records.fold(0, (sum, r) => sum + (r.totalBaris ?? 0));
}

/// Satu titik data pekanan chart "Ayat Tersetor/Minggu" (tab Statistik), lihat
/// [RecordsProvider.weeklyAyatSummary]. [weekStart] = Senin pekan itu
/// ([WeekUtils.startOfWeek]), dipakai untuk label rentang via [WeekUtils.rangeLabel].
class WeeklyAyatPoint {
  final DateTime weekStart;
  final int total;
  const WeeklyAyatPoint({required this.weekStart, required this.total});
}
