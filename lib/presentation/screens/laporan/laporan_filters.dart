// Logika filter kartu di tab Laporan (dipisah dari state supaya tab tetap ramping).
import '../../../core/utils/week_utils.dart';
import '../../../providers/records_provider.dart';

/// Predikat pencocokan search + filter kelas/halaqoh/status/keterangan/
/// tanggal untuk SATU kartu — dipisah dari [filteredCards] supaya bisa
/// dipakai ulang buat menghitung berapa kartu di DALAM sebuah folder
/// yang cocok filter aktif (lihat [matchingCountInFolder]), tanpa
/// duplikat logic-nya.
bool cardMatchesFilters(
    SantriCardInfo c, RecordsProvider provider, DateTime thisMonth, String q) {
  if (q.isNotEmpty && !c.nama.toLowerCase().contains(q)) return false;
  if (provider.filterKelas != null && c.kelas != provider.filterKelas) return false;
  if (provider.filterHalaqoh != null && c.halaqoh != provider.filterHalaqoh) return false;
  if (provider.filterStatus != null ||
      provider.filterKeterangan != null ||
      provider.filterDate != null) {
    final recs = provider.recordsInMonth(thisMonth).where(
            (r) => r.namaAnak.trim().toLowerCase() == c.nama.trim().toLowerCase());
    final matches = recs.any((r) =>
    (provider.filterStatus == null || r.status == provider.filterStatus) &&
        (provider.filterKeterangan == null || r.keterangan == provider.filterKeterangan) &&
        (provider.filterDate == null ||
            (r.tanggal.year == provider.filterDate!.year &&
                r.tanggal.month == provider.filterDate!.month &&
                r.tanggal.day == provider.filterDate!.day)));
    if (!matches) return false;
  }
  return true;
}

/// Kartu santri yang cocok dengan pencarian & filter kelas/halaqoh aktif
/// (dipakai bersama dengan Bottom Sheet Filter yang sudah ada).
List<SantriCardInfo> filteredCards(RecordsProvider provider) {
  final q = provider.searchQuery.trim().toLowerCase();
  final thisMonth = WeekUtils.ownerMonth(DateTime.now());
  return provider.laporanCards.where((c) {
    if (c.currentFolderId != null) return false;
    return cardMatchesFilters(c, provider, thisMonth, q);
  }).toList();
}

/// Jumlah kartu DI DALAM folder [folderId] yang cocok filter/pencarian
/// aktif saat ini — dipakai buat badge di [FolderCard] (lihat
/// [LaporanFolderSection]), supaya kartu yang "nyangkut" di dalam folder
/// (dan karena itu tidak ikut ditampilkan sebagai kartu lepas oleh
/// [filteredCards]) tetap kelihatan ketauan ada yang cocok, tanpa harus
/// membuka folder itu satu-satu.
int matchingCountInFolder(String folderId, RecordsProvider provider) {
  // Null kalau tidak ada filter/pencarian aktif sama sekali -- badge-nya
  // sengaja TIDAK ditampilkan dalam kondisi ini (lihat LaporanFolderSection),
  // jadi hitungannya juga tidak perlu dikerjakan.
  if (!provider.hasActiveFilters) return 0;
  final q = provider.searchQuery.trim().toLowerCase();
  final thisMonth = WeekUtils.ownerMonth(DateTime.now());
  return provider.laporanCards
      .where((c) => c.currentFolderId == folderId)
      .where((c) => cardMatchesFilters(c, provider, thisMonth, q))
      .length;
}
