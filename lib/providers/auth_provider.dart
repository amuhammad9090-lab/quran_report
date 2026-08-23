import 'package:flutter/material.dart';

import '../core/access/access_scope.dart';
import '../data/models/school.dart';
import '../data/models/user_account.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/local_auth_repository.dart';
import '../data/repositories/school_repository.dart';
import '../data/services/app_prefs_service.dart';

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

  UserAccount? get currentUser => _currentUser;
  School? get currentSchool => _currentSchool;
  bool get isAuthenticated => _currentUser != null;
  bool get isRestoring => _restoring;
  bool get isLoggingIn => _loggingIn;
  String? get error => _error;

  /// Null kalau belum login. Dipakai provider lain (mis. RecordsProvider)
  /// buat nge-scope data — lihat catatan di [AccessScope].
  AccessScope? get scope => _currentUser == null ? null : AccessScope(_currentUser!);

  /// Dipanggil sekali di startup (sebelum runApp, sama seperti provider
  /// lain di project ini) — coba pulihkan session dari [AppPrefsService]
  /// supaya user tidak perlu login ulang tiap buka app.
  Future<void> restoreSession() async {
    _restoring = true;
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
}
