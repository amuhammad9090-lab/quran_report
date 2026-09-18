import '../models/user_account.dart';

/// Abstraction sumber data authentication. Implementasi saat ini
/// [LocalAuthRepository] baca dari seed lokal; nanti tinggal diganti
/// `ApiAuthRepository` (panggil backend) — kode di atas layer ini
/// (`AuthProvider`, UI) tidak perlu tahu/berubah.
abstract class AuthRepository {
  /// Return [UserAccount] kalau username+password valid, null kalau tidak.
  ///
  /// <-- BERUBAH (migrasi auth): TIDAK lagi dipanggil dari jalur login
  /// manapun di UI (lihat [findByGoogleEmail]) sejak migrasi ke Google
  /// Sign-In -- SENGAJA TIDAK dihapus (bukan dead code yang "aman
  /// dihapus", lihat AuthProvider.changePassword yang masih memverifikasi
  /// [UserAccount.passwordHash] lewat mekanisme yang sama), cuma sudah
  /// tidak ada pemanggil dari [LoginScreen] lagi.
  Future<UserAccount?> login(String username, String password);

  /// <-- BARU (migrasi auth: Anonymous -> Google Sign-In). Cari akun yang
  /// [UserAccount.googleEmail]-nya cocok [email] (dibandingkan
  /// case-insensitive -- [email] SEBAIKNYA sudah di-lowercase pemanggil,
  /// lihat [AuthProvider.signInWithGoogle]). Null kalau tidak ada akun
  /// manapun yang di-whitelist admin untuk email Google ini -- INI status
  /// "authentication sukses, authorization gagal" (lihat dokumentasi
  /// lengkap di [ApiAuthRepository.findByGoogleEmail]), bukan error.
  Future<UserAccount?> findByGoogleEmail(String email);

  /// Dipakai buat restore session (cari user by id yang tersimpan).
  Future<UserAccount?> findById(String id);

  /// Semua akun terdaftar — dipakai buat mencari nama guru pembimbing
  /// suatu Kelas+Halaqoh saat export rekap per kelompok (lihat
  /// AuthProvider.guruPembimbingNameFor).
  Future<List<UserAccount>> allAccounts();

  /// Ganti password (dalam bentuk hash — lihat [AuthHashService]) akun
  /// [userId]. Return true kalau akun ketemu & berhasil diupdate.
  Future<bool> updatePasswordHash(String userId, String newHash);

  /// Ganti path foto profil (null = hapus foto) akun [userId], DAN
  /// persist perubahannya (bukan cuma cache in-memory) — lihat catatan
  /// bug fix di [AppPrefsService.photoOverrides]. Return true kalau akun
  /// ketemu & berhasil diupdate.
  Future<bool> updatePhotoPath(String userId, String? photoPath);
}
