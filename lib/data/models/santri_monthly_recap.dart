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

  const SantriMonthlyRecap({
    required this.nama,
    required this.kelas,
    required this.halaqoh,
    required this.recordsByWeek,
    required this.totalBaris,
    required this.keteranganCounts,
  });

  /// Ringkasan capaian santri ini pada Pekan [weekIndex], gabungan semua
  /// laporan di pekan itu (dipisah "; " kalau lebih dari satu) — '-' kalau
  /// pekan itu belum ada laporan sama sekali.
  String capaianForWeek(int weekIndex) {
    final recs = recordsByWeek[weekIndex];
    if (recs == null || recs.isEmpty) return '-';
    return recs.map((r) => r.capaianText).join('; ');
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

  /// Teks ringkas "1x Izin Sakit, 2x Alpa" dari [keteranganCounts],
  /// terurut sesuai urutan enum Keterangan — '-' kalau tidak ada sama
  /// sekali (semua Hadir).
  String get keteranganSummaryText {
    if (keteranganCounts.isEmpty) return '-';
    final entries = keteranganCounts.entries.toList()
      ..sort((a, b) => a.key.index.compareTo(b.key.index));
    return entries.map((e) => '${e.value}x ${e.key.shortLabel}').join(', ');
  }
}
