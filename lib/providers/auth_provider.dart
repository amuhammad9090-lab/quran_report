import 'package:flutter/material.dart';

import '../core/access/access_scope.dart';
import '../data/models/school.dart';
import '../data/models/user_account.dart';
import '../data/repositories/api_auth_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/school_repository.dart';
import '../data/services/app_prefs_service.dart';
import '../data/services/auth_hash_service.dart';
import '../data/services/firebase_auth_service.dart';

/// State authentication: user yang login, sekolahnya, dan restore session saat app dibuka.
/// Authentication = Google Sign-In lewat [FirebaseAuthService]; authorization (role/assignment)
/// lewat [AuthRepository.findByGoogleEmail]. [login] username+password tetap ada tapi tak dipakai UI.
class AuthProvider extends ChangeNotifier {
  // Default-nya [ApiAuthRepository] (Firestore + cache Hive untuk login offline, fallback seed):
  // assignment kelas/halaqoh guru bisa diedit admin dari dalam app tanpa build ulang APK.
  AuthProvider({
    AuthRepository? authRepository,
    SchoolRepository? schoolRepository,
    FirebaseAuthService? authService,
  })  : _authRepo = authRepository ?? ApiAuthRepository.instance,
        _schoolRepo = schoolRepository ?? LocalSchoolRepository(),
        _authService = authService ?? FirebaseAuthService.instance;

  final AuthRepository _authRepo;
  final SchoolRepository _schoolRepo;
  final FirebaseAuthService _authService;

  UserAccount? _currentUser;
  School? _currentSchool;
  bool _restoring = true;
  bool _loggingIn = false;
  String? _error;
  List<UserAccount> _allAccounts = [];
  // Lihat AccessScope.adminModeActive & setAdminModeActive: hanya relevan untuk akun isAdmin,
  // tapi disimpan per device (lepas dari user) agar bisa di-load sebelum tahu siapa yang login.
  bool _adminModeActive = true;

  UserAccount? get currentUser => _currentUser;
  School? get currentSchool => _currentSchool;
  bool get isAuthenticated => _currentUser != null;
  bool get isRestoring => _restoring;
  bool get isLoggingIn => _loggingIn;
  String? get error => _error;

  /// Semua akun terdaftar (di-cache saat [restoreSession]) — dipakai buat
  /// [guruPembimbingNameFor] saat export rekap per Kelas+Halaqoh.
  List<UserAccount> get allAccounts => _allAccounts;

  /// Null kalau belum login. Dipakai provider lain (mis. RecordsProvider)
  /// buat nge-scope data — lihat catatan di [AccessScope].
  AccessScope? get scope => _currentUser == null
      ? null
      : AccessScope(_currentUser!, adminModeActive: _adminModeActive);

  /// Hanya bermakna bila [currentUser.isAdmin] true (lihat [AccessScope.adminModeActive]); tetap
  /// dikembalikan apa adanya untuk non-admin agar ProfileScreen tak perlu null-check khusus.
  bool get adminModeActive => _adminModeActive;

  /// Toggle "Mode Admin" dari Profil. Sengaja TIDAK memanggil `updateScope()` provider lain
  /// (RecordsProvider/ParentNotesProvider): pemanggil yang eksplisit (LoginScreen/ProfileScreen),
  /// supaya AuthProvider tetap independen dari provider lain.
  Future<void> setAdminModeActive(bool value) async {
    if (_adminModeActive == value) return;
    _adminModeActive = value;
    await AppPrefsService.instance.setAdminModeActive(value);
    notifyListeners();
  }

  /// Dipanggil sekali di startup (sebelum runApp): pulihkan session. Sumber kebenaran "siapa yang
  /// login" adalah session Firebase (dipulihkan SDK), dicocokkan ke [UserAccount.googleEmail];
  /// [AppPrefsService.sessionUserId] tidak dihapus tapi tak dipakai lagi di sini.
  Future<void> restoreSession() async {
    _restoring = true;
    _adminModeActive = AppPrefsService.instance.adminModeActive;
    _allAccounts = await _authRepo.allAccounts();

    final email = await _authService.restoredEmail();

    if (email != null) {
      final user = await _authRepo.findByGoogleEmail(email);
      if (user != null) {
        _currentUser = user;
        _currentSchool = await _schoolRepo.findById(user.schoolId);
      } else {
        // Authentication valid tapi email TIDAK di-whitelist admin (mis. dicabut sejak login
        // terakhir): jangan anggap berhasil dan jangan bikin anonymous fallback; sign-out
        // sekarang agar berikutnya muncul account picker lagi.
        await _authService.signOut();
      }
    }

    _restoring = false;
    notifyListeners();
  }

  /// <-- BERUBAH: sudah tidak dipanggil dari [LoginScreen] manapun sejak
  /// migrasi ke Google Sign-In (lihat [signInWithGoogle]) -- SENGAJA
  /// TIDAK dihapus, lihat dokumentasi lengkap di [AuthRepository.login].
  Future<bool> login(String username, String password) async {
    _loggingIn = true;
    _error = null;
    notifyListeners();

    final user = await _authRepo.login(username, password);
    if (user == null) {
      _loggingIn = false;
      _error = 'Username atau kata sandi salah.';
      notifyListeners();
      return false;
    }

    _currentUser = user;
    _currentSchool = await _schoolRepo.findById(user.schoolId);
    await AppPrefsService.instance.setSessionUserId(user.id);
    _loggingIn = false;
    notifyListeners();
    return true;
  }

  /// SATU-SATUNYA jalur login (lihat [LoginScreen]): Google Sign-In -> Firebase User
  /// ([FirebaseAuthService]) -> [AuthRepository.findByGoogleEmail] -> [UserAccount]/[AccessScope].
  /// Return true hanya bila berhasil; semua kegagalan mengisi [error], tanpa anonymous fallback.
  Future<bool> signInWithGoogle() async {
    _loggingIn = true;
    _error = null;
    notifyListeners();

    final result = await _authService.signInWithGoogle();
    switch (result.status) {
      case GoogleSignInStatus.cancelled:
        // User membatalkan pemilihan akun/popup — bukan error, balik ke Login Screen apa adanya.
        _loggingIn = false;
        _error = null;
        notifyListeners();
        return false;
      case GoogleSignInStatus.firebaseError:
        _loggingIn = false;
        _error = 'Gagal masuk dengan Google. Silakan coba lagi.';
        notifyListeners();
        return false;
      case GoogleSignInStatus.platformError:
        _loggingIn = false;
        _error = 'Gagal masuk dengan Google. Periksa koneksi internet Anda.';
        notifyListeners();
        return false;
      case GoogleSignInStatus.noEmail:
        _loggingIn = false;
        _error = 'Akun Google ini tidak memiliki alamat email yang valid.';
        notifyListeners();
        return false;
      case GoogleSignInStatus.success:
        break;
    }

    final email = result.email!;
    final user = await _authRepo.findByGoogleEmail(email);
    if (user == null) {
      // Authentication sukses tapi authorization gagal (lihat AuthRepository.findByGoogleEmail):
      // akun tidak dibuat otomatis, role tidak diberikan. Sign-out agar sesi tak berhak tidak
      // menggantung dan percobaan berikutnya menampilkan account picker lagi.
      await _authService.signOut();
      _loggingIn = false;
      _error = 'Tidak ada akses. Akun Google ini ($email) belum terdaftar sebagai pengguna Quran Report.';
      notifyListeners();
      return false;
    }

    _currentUser = user;
    _currentSchool = await _schoolRepo.findById(user.schoolId);
    _loggingIn = false;
    _error = null;
    notifyListeners();
    return true;
  }

  /// Nama guru pembimbing yang mengampu pasangan Kelas+Halaqoh (export rekap per kelompok, lihat
  /// RecordsProvider.groupByKelasHalaqoh); null kalau belum/tidak di-assign ke siapa pun.
  String? guruPembimbingNameFor(String kelas, String halaqoh) {
    // Tanpa filter role: admin yang merangkap guru pembimbing (assignments terisi seperti guru biasa)
    // tetap harus ketemu, kalau tidak baris "Guru Pembimbing" hilang di export. Siapa pun (admin atau
    // guru_pembimbing) dengan assignment cocok dianggap pembimbingnya; role hanya soal akses admin.
    final kelasKey = kelas.trim().toLowerCase();
    final halaqohKey = halaqoh.trim().toLowerCase();
    for (final acc in _allAccounts) {
      final match = acc.assignments.any((a) =>
          a.kelas.trim().toLowerCase() == kelasKey &&
          a.halaqoh.trim().toLowerCase() == halaqohKey);
      if (match) return acc.displayName;
    }
    return null;
  }

  /// Fallback: cari nama akun dari [id] (mis. `ownerId` record) kalau
  /// [guruPembimbingNameFor] tidak ketemu (assignment sudah berubah sejak
  /// laporan dibuat).
  String? displayNameForId(String? id) {
    if (id == null) return null;
    for (final acc in _allAccounts) {
      if (acc.id == id) return acc.displayName;
    }
    return null;
  }

  /// Muat ulang [allAccounts] dari repository, dipanggil setelah admin mengedit assignment guru
  /// (Kelola Akun Guru). Bila akun yang login ikut teredit, [currentUser]/[scope] ikut disegarkan
  /// agar assignment barunya langsung terpakai tanpa logout-login.
  Future<void> reloadAccounts() async {
    _allAccounts = await _authRepo.allAccounts();
    if (_currentUser != null) {
      for (final acc in _allAccounts) {
        if (acc.id == _currentUser!.id) {
          _currentUser = acc;
          break;
        }
      }
    }
    notifyListeners();
  }

  /// Bersihkan session lokal DAN sign-out dari Firebase Auth + Google; tanpa signInAnonymously
  /// atau anonymous fallback apa pun — user harus login ulang dengan Google.
  Future<void> logout() async {
    _currentUser = null;
    _currentSchool = null;
    await AppPrefsService.instance.clearSession();
    await _authService.signOut();
    notifyListeners();
  }

  /// Ganti foto profil (path lokal). Dipersist ke [_authRepo] (override Hive per-device, lihat
  /// `AppPrefsService.photoOverrides`), bukan cuma in-memory, supaya foto baru tak "balik seperti
  /// semula" setelah app ditutup total.
  Future<void> updatePhotoPath(String? path) async {
    final user = _currentUser;
    if (user == null) return;
    final ok = await _authRepo.updatePhotoPath(user.id, path);
    if (!ok) return;
    _currentUser = user.copyWith(photoPath: path, clearPhoto: path == null);
    // Jaga konsistensi cache allAccounts, sama pola seperti changePassword
    // di bawah — supaya guruPembimbingNameFor dkk tidak kepakai data foto
    // basi dalam satu sesi yang sama.
    _allAccounts = [
      for (final acc in _allAccounts) if (acc.id == user.id) _currentUser! else acc,
    ];
    notifyListeners();
  }

  /// Ganti nama tampilan. Untuk sekarang hanya lokal-sesi (belum ada backend untuk persist
  /// permanen); saat backend ada, cukup tambah pemanggilan API di sini tanpa ubah signature.
  void updateDisplayName(String newName) {
    if (_currentUser == null || newName.trim().isEmpty) return;
    _currentUser = _currentUser!.copyWith(displayName: newName.trim());
    notifyListeners();
  }

  /// Ganti kata sandi user yang login; [oldPassword] diverifikasi dulu terhadap hash tersimpan
  /// (lihat batasan hashing lokal di [AuthHashService]). Return null bila berhasil, atau pesan
  /// error yang siap ditampilkan UI.
  Future<String?> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final user = _currentUser;
    if (user == null) return 'Sesi tidak valid, silakan login ulang.';

    if (!AuthHashService.instance.verify(oldPassword, user.passwordHash)) {
      return 'Kata sandi lama tidak sesuai.';
    }
    if (newPassword.trim().length < 4) {
      return 'Kata sandi baru minimal 4 karakter.';
    }
    if (newPassword == oldPassword) {
      return 'Kata sandi baru tidak boleh sama dengan yang lama.';
    }

    final newHash = AuthHashService.instance.hash(newPassword);
    final ok = await _authRepo.updatePasswordHash(user.id, newHash);
    if (!ok) return 'Gagal memperbarui kata sandi, coba lagi.';

    _currentUser = user.copyWith(passwordHash: newHash);
    // Jaga konsistensi cache allAccounts juga, meski nggak berpengaruh ke
    // guruPembimbingNameFor (yang cuma pakai displayName), biar tidak ada
    // versi data yang beda-beda dalam satu sesi.
    _allAccounts = [
      for (final acc in _allAccounts) if (acc.id == user.id) _currentUser! else acc,
    ];
    notifyListeners();
    return null;
  }
}
