import 'enums.dart';
import 'santri_record.dart';

/// Rekap gabungan SATU santri untuk satu bulan penuh — menghimpun seluruh
/// laporannya dari Pekan 1 s/d Pekan terakhir bulan itu (lihat
/// [RecordsProvider.monthlySantriRecaps]). Dipakai fitur "Generate Rekap
/// Bulanan" (Rekap Bulanan → tombol Generate) supaya guru pembimbing bisa
/// lihat/ekspor progres tiap santri sebulan penuh dalam satu baris,
/// bukan bolak-balik buka tiap Pekan satu-satu.
class SantriMonthlyRecap {
  final String nama;
  final String kelas;
  final String halaqoh;

  /// Semua laporan santri ini bulan itu, dikelompokkan per nomor Pekan
  /// (1..N). Bisa lebih dari satu laporan per Pekan (jarang, tapi
  /// mungkin) — makanya List, bukan SantriRecord tunggal.
  final Map<int, List<SantriRecord>> recordsByWeek;

  /// Total baris tahfizh (hasil generate) terkumpul sebulan penuh.
  final int totalBaris;

  /// Jumlah tiap jenis Keterangan non-Hadir (Izin Sakit/Lomba/Pelatihan,
  /// Alpa) sebulan penuh — Hadir sengaja tidak dihitung di sini karena
  /// bukan "keterangan" yang perlu disorot.
  final Map<Keterangan, int> keteranganCounts;

  /// <-- BARU: jumlah laporan sebulan penuh yang status-nya MEMANG tidak
  /// menghasilkan baris hafalan baru (Tahsin murni & Muroja'ah/Tasmi',
  /// lihat [HafalanStatus.isZeroBarisByDesign]) — dipakai
  /// [keteranganSummaryText] supaya kolom Keterangan tidak cuma nampilin
  /// sanksi ("Tdk Setoran" dst), tapi juga status "0 baris"-nya ITU KENAPA
  /// (Tahsin/Murojaah), biar tidak disalahartikan santrinya bolong laporan.
  final Map<HafalanStatus, int> zeroBarisStatusCounts;

  const SantriMonthlyRecap({
    required this.nama,
    required this.kelas,
    required this.halaqoh,
    required this.recordsByWeek,
    required this.totalBaris,
    required this.keteranganCounts,
    this.zeroBarisStatusCounts = const {},
  });

  /// Ringkasan capaian santri ini pada Pekan [weekIndex], gabungan semua
  /// laporan di pekan itu — SATU LAPORAN PER BARIS (dipisah baris baru,
  /// bukan "; " lagi) supaya tiap baris menunjukkan hari setoran yang
  /// berbeda & rapi kalau dibuka di Excel (lihat juga
  /// ExportService._weeklyCapaianForSantri, pola yang sama) — '-' kalau
  /// pekan itu belum ada laporan sama sekali. Urutan baris sudah
  /// kronologis (tanggal lama -> baru), lihat
  /// RecordsProvider.recordsInMonthWeek.
  String capaianForWeek(int weekIndex) {
    final recs = recordsByWeek[weekIndex];
    if (recs == null || recs.isEmpty) return '-';
    return recs.map((r) => r.capaianText).join('\n');
  }

  /// True kalau santri ini sudah punya laporan di SEMUA pekan 1..[totalWeeks]
  /// bulan itu — dipakai buat indikator "lengkap" di layar Generate Rekap
  /// Bulanan.
  bool isCompleteThrough(int totalWeeks) {
    for (var w = 1; w <= totalWeeks; w++) {
      if (recordsByWeek[w] == null || recordsByWeek[w]!.isEmpty) return false;
    }
    return true;
  }

  /// Teks ringkas kolom Keterangan, mis. "2x Tahsin, 1x Murojaah, 1x Tdk
  /// Setoran" — gabungan [zeroBarisStatusCounts] (status yang baris-nya 0
  /// karena memang bukan hafalan baru: Tahsin/Murojaah) DULU, baru
  /// [keteranganCounts] (sanksi/izin/alpa) — '-' kalau kedua-duanya kosong
  /// (semua laporan Tahfizh/Tahsin+Tahfizh dengan baris & semua Hadir).
  String get keteranganSummaryText {
    final parts = <String>[];
    if (zeroBarisStatusCounts.isNotEmpty) {
      final statusEntries = zeroBarisStatusCounts.entries.toList()
        ..sort((a, b) => a.key.index.compareTo(b.key.index));
      parts.addAll(statusEntries.map((e) => '${e.value}x ${e.key.shortLabel}'));
    }
    if (keteranganCounts.isNotEmpty) {
      final entries = keteranganCounts.entries.toList()
        ..sort((a, b) => a.key.index.compareTo(b.key.index));
      parts.addAll(entries.map((e) => '${e.value}x ${e.key.shortLabel}'));
    }
    return parts.isEmpty ? '-' : parts.join(', ');
  }
}
