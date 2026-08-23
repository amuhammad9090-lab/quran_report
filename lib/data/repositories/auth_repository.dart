import '../models/user_account.dart';

/// Abstraction sumber data authentication. Implementasi saat ini
/// [LocalAuthRepository] baca dari seed lokal; nanti tinggal diganti
/// `ApiAuthRepository` (panggil backend) — kode di atas layer ini
/// (`AuthProvider`, UI) tidak perlu tahu/berubah.
abstract class AuthRepository {
  /// Return [UserAccount] kalau username+password valid, null kalau tidak.
  Future<UserAccount?> login(String username, String password);

  /// Dipakai buat restore session (cari user by id yang tersimpan).
  Future<UserAccount?> findById(String id);

  /// Semua akun terdaftar — dipakai buat mencari nama guru pembimbing
  /// suatu Kelas+Halaqoh saat export rekap per kelompok (lihat
  /// AuthProvider.guruPembimbingNameFor).
  Future<List<UserAccount>> allAccounts();
}
