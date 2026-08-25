import 'package:flutter/material.dart';

import '../core/access/access_scope.dart';
import '../data/models/school.dart';
import '../data/models/user_account.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/local_auth_repository.dart';
import '../data/repositories/school_repository.dart';
import '../data/services/app_prefs_service.dart';
import '../data/services/auth_hash_service.dart';

/// State authentication: user yang sedang login, sekolahnya, dan session
/// restore saat app dibuka. Disuntik dengan implementasi repository lewat
/// constructor supaya gampang diganti implementasi backend nanti tanpa
/// mengubah provider ini sama sekali.
class AuthProvider extends ChangeNotifier {
  AuthProvider({
    AuthRepository? authRepository,
    SchoolRepository? schoolRepository,
  })  : _authRepo = authRepository ?? LocalAuthRepository(),
        _schoolRepo = schoolRepository ?? LocalSchoolRepository();

  final AuthRepository _authRepo;
  final SchoolRepository _schoolRepo;

  UserAccount? _currentUser;
  School? _currentSchool;
  bool _restoring = true;
  bool _loggingIn = false;
  String? _error;
  List<UserAccount> _allAccounts = [];

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
  AccessScope? get scope => _currentUser == null ? null : AccessScope(_currentUser!);

  /// Dipanggil sekali di startup (sebelum runApp, sama seperti provider
  /// lain di project ini) — coba pulihkan session dari [AppPrefsService]
  /// supaya user tidak perlu login ulang tiap buka app.
  Future<void> restoreSession() async {
    _restoring = true;
    _allAccounts = await _authRepo.allAccounts();
    final userId = AppPrefsService.instance.sessionUserId;
    if (userId != null) {
      final user = await _authRepo.findById(userId);
      if (user != null) {
        _currentUser = user;
        _currentSchool = await _schoolRepo.findById(user.schoolId);
      } else {
        // Session nyimpen id yang udah nggak valid (mis. akun dihapus) —
        // bersihin biar nggak nyangkut mencoba login otomatis terus.
        await AppPrefsService.instance.clearSession();
      }
    }
    _restoring = false;
    notifyListeners();
  }

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

  /// Cari nama guru pembimbing yang mengampu pasangan Kelas+Halaqoh
  /// tertentu (dipakai saat export rekap per kelompok, lihat
  /// RecordsProvider.groupByKelasHalaqoh). Null kalau tidak ketemu (mis.
  /// kelas/halaqoh belum/tidak di-assign ke siapa pun).
  String? guruPembimbingNameFor(String kelas, String halaqoh) {
    for (final acc in _allAccounts) {
      if (acc.role != UserRole.guruPembimbing) continue;
      final match = acc.assignments.any((a) => a.kelas == kelas && a.halaqoh == halaqoh);
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

  Future<void> logout() async {
    _currentUser = null;
    _currentSchool = null;
    await AppPrefsService.instance.clearSession();
    notifyListeners();
  }

  /// Ganti foto profil (path lokal). Belum ada picker package (lihat
  /// keputusan project) — dipakai kalau nanti mau disambungkan ke
  /// image_picker atau upload backend, abstraction-nya sudah siap di sini.
  void updatePhotoPath(String? path) {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(photoPath: path, clearPhoto: path == null);
    notifyListeners();
  }

  /// Ganti nama tampilan. Local-session-only untuk sekarang (belum ada
  /// backend buat persist permanen) — begitu backend ada, tinggal
  /// tambahkan pemanggilan API di sini, tanda tangan method tidak perlu
  /// berubah.
  void updateDisplayName(String newName) {
    if (_currentUser == null || newName.trim().isEmpty) return;
    _currentUser = _currentUser!.copyWith(displayName: newName.trim());
    notifyListeners();
  }

  /// Ganti kata sandi user yang sedang login. Verifikasi [oldPassword]
  /// dulu terhadap hash tersimpan sebelum mengganti — lihat catatan
  /// security di [AuthHashService] soal batasan hashing lokal ini.
  ///
  /// Return null kalau berhasil, atau pesan error kalau gagal (biar UI
  /// tinggal tampilkan apa adanya, tidak perlu logic tambahan).
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
