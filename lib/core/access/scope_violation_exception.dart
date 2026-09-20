/// Dilempar [RecordsProvider.upsert] saat guru pembimbing menyimpan laporan untuk
/// kelas/halaqoh di luar assignment-nya — enforcement sungguhan di level data,
/// bukan cuma UI (lihat AccessScope & bagian I spesifikasi access control).
class ScopeViolationException implements Exception {
  final String message;
  ScopeViolationException(this.message);
  @override
  String toString() => message;
}
