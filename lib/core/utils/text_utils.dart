/// Normalisasi nilai `halaqoh` mentah dari sumber data (seed, input lama,
/// dsb).
library;

String normalizeHalaqoh(String raw) {
  final trimmed = raw.trim();
  final match = RegExp(r'^halaqoh\s*', caseSensitive: false).firstMatch(trimmed);
  if (match == null) return trimmed;
  return trimmed.substring(match.end).trim();
}

// <-- BARU: seluruh fungsi ini. Title-case sederhana, mis. "ahmad zakwan
// al khairi" -> "Ahmad Zakwan Al Khairi" — dipakai sebagai fallback
// TAMPILAN nama kartu santri waktu kapitalisasi aslinya benar-benar tidak
// ketemu (lihat RecordsProvider.laporanCards & catatan lengkap soal kartu
// "identitas kosong" yang kapitalisasinya cuma ada di
// AppPrefsService.activatedIdentityDisplay). Sebelumnya fallback-nya
// langsung pakai identityKey apa adanya (yang emang sengaja lowercase
// buat perbandingan, lihat [reportIdentityKey]) — makanya nama santri
// bisa kelihatan huruf kecil semua. Ini BUKAN jaminan 100% sama persis
// kapitalisasi asli yang diketik guru (mis. singkatan/nama majemuk),
// cuma jaring pengaman kosmetik terakhir SEBELUM data aslinya sempat
// dipulihkan (lihat Pengaturan -> "Pulihkan dari Cloud").
String toTitleCase(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed
      .split(RegExp(r'\s+'))
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');
}
