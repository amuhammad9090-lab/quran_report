// <-- PENTING: `hide AuthProvider` -- package `firebase_auth` punya
// class abstract-nya SENDIRI bernama `AuthProvider` (induk dari
// `GoogleAuthProvider` dkk), yang akan bentrok nama dengan `class
// AuthProvider extends ChangeNotifier` di file ini kalau tidak
// disembunyikan (sama pola importnya seperti main.dart).
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/access/access_scope.dart';
import '../data/models/school.dart';
import '../data/models/user_account.dart';
import '../data/repositories/api_auth_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/school_repository.dart';
import '../data/services/app_prefs_service.dart';
import '../data/services/auth_hash_service.dart';

/// State authentication: user yang sedang login, sekolahnya, dan session
/// restore saat app dibuka. Disuntik dengan implementasi repository lewat
/// constructor supaya gampang diganti implementasi backend nanti tanpa
/// mengubah provider ini sama sekali.
///
/// <-- BERUBAH (migrasi auth: Anonymous -> Google Sign-In). Authentication
/// (siapa user ini) sekarang Google Sign-In lewat Firebase Auth
/// ([signInWithGoogle]/[restoreSession]/[logout] di bawah) -- BUKAN lagi
/// Firebase Anonymous Auth (yang cuma bootstrap identity Firestore, tidak
/// tahu-menahu siapa gurunya, lihat main.dart versi sebelumnya) DAN BUKAN
/// lagi username+password ([login] di bawah TETAP ada, tidak dihapus,
/// tapi TIDAK ADA LAGI pemanggil dari UI -- lihat LoginScreen).
///
/// Authorization (boleh/tidaknya akses Quran Report, role, assignment)
/// TETAP SAMA PERSIS seperti sebelumnya: [UserAccount] dari
/// `schools/{id}/accounts` lewat [_authRepo], [AccessScope] dihitung dari
/// situ. SATU-SATUNYA yang berubah adalah BAGAIMANA kita tahu
/// [UserAccount] mana yang sedang login -- dulu dari [AppPrefsService.
/// sessionUserId] (id akun yang disimpan manual pas [login] sukses),
/// sekarang dari [FirebaseAuth.currentUser.email] dicocokkan ke
/// [UserAccount.googleEmail] lewat [AuthRepository.findByGoogleEmail]
/// (lihat dokumentasi lengkap di situ soal kenapa ini dua langkah
/// authentication+authorization yang terpisah).
class AuthProvider extends ChangeNotifier {
  // <-- BERUBAH: default-nya sekarang [ApiAuthRepository] (Firestore +
  // cache Hive lokal buat login offline, fallback ke seed kalau belum
  // pernah online sama sekali) -- bukan lagi [LocalAuthRepository] (seed
  // doang). Assignment kelas/halaqoh guru sekarang bisa diedit admin
  // dari dalam app tanpa build ulang APK -- lihat ApiAuthRepository.
  AuthProvider({
    AuthRepository? authRepository,
    SchoolRepository? schoolRepository,
  })  : _authRepo = authRepository ?? ApiAuthRepository.instance,
        _schoolRepo = schoolRepository ?? LocalSchoolRepository();

  final AuthRepository _authRepo;
  final SchoolRepository _schoolRepo;

  // <-- BARU (migrasi auth). Instance tunggal, dipakai [signInWithGoogle]
  // & [logout] -- SENGAJA bukan `GoogleSignIn()` baru tiap dipanggil,
  // supaya state "akun mana yang terakhir kepilih" konsisten (mis. kalau
  // signIn() gagal di tengah jalan, instance yang sama dipakai lagi buat
  // retry/logout, bukan instance baru yang belum tahu apa-apa).
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: const ['email']);

  UserAccount? _currentUser;
  School? _currentSchool;
  bool _restoring = true;
  bool _loggingIn = false;
  String? _error;
  List<UserAccount> _allAccounts = [];
  // <-- BARU: lihat AccessScope.adminModeActive & setAdminModeActive di
  // bawah. Cuma relevan buat akun isAdmin==true, tapi disimpan lepas
  // dari user (per device) biar gampang di-load duluan sebelum tau siapa
  // yang login.
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

  /// <-- BARU. Cuma benar-benar berarti kalau [currentUser.isAdmin] true
  /// (lihat [AccessScope.adminModeActive]) — tapi tetap disediakan
  /// walaupun user bukan admin (return apa adanya) supaya ProfileScreen
  /// tidak perlu null-check khusus.
  bool get adminModeActive => _adminModeActive;

  /// <-- BARU. Toggle "Mode Admin" dari Profil. TIDAK memanggil
  /// `updateScope()` provider lain (RecordsProvider/ParentNotesProvider)
  /// sendiri — sengaja dibiarkan eksplisit dari pemanggil (lihat pola
  /// yang sama di LoginScreen/ProfileScreen), supaya AuthProvider tetap
  /// independen dari provider lain.
  Future<void> setAdminModeActive(bool value) async {
    if (_adminModeActive == value) return;
    _adminModeActive = value;
    await AppPrefsService.instance.setAdminModeActive(value);
    notifyListeners();
  }

  /// Dipanggil sekali di startup (sebelum runApp, sama seperti provider
  /// lain di project ini) — coba pulihkan session.
  ///
  /// <-- BERUBAH (migrasi auth): dulu sumber kebenaran "siapa yang lagi
  /// login" adalah [AppPrefsService.sessionUserId] (id akun yang kita
  /// simpan sendiri pas [login] sukses). Sekarang sumber kebenarannya
  /// [FirebaseAuth.currentUser] -- Firebase SDK sendiri yang menyimpan &
  /// memulihkan session Google ini (persis instruksi migrasi: "Firebase
  /// Auth harus mempertahankan session Google... Startup berikutnya:
  /// currentUser != null -> gunakan session -> load account ->
  /// dashboard"). [AppPrefsService.sessionUserId]/[clearSession] TIDAK
  /// dihapus (lihat AppPrefsService), cuma tidak dipakai lagi di sini.
  ///
  /// Dipakai [FirebaseAuth.authStateChanges().first] (BUKAN langsung baca
  /// [FirebaseAuth.currentUser]) supaya di Flutter Web (yang restore
  /// session-nya sedikit async, beda dari Android/iOS yang biasanya udah
  /// siap sinkron) kita tidak salah kira "belum login" padahal session-nya
  /// masih dalam proses dipulihkan SDK. Dikasih timeout pendek sebagai
  /// jaring pengaman (fallback ke [FirebaseAuth.currentUser] apa adanya)
  /// kalau stream itu karena suatu hal tidak kunjung emit.
  Future<void> restoreSession() async {
    _restoring = true;
    _adminModeActive = AppPrefsService.instance.adminModeActive;
    _allAccounts = await _authRepo.allAccounts();

    final firebaseUser = await FirebaseAuth.instance.authStateChanges().first.timeout(
          const Duration(seconds: 5),
          onTimeout: () => FirebaseAuth.instance.currentUser,
        );
    final email = firebaseUser?.email?.trim().toLowerCase();

    if (firebaseUser != null && email != null && email.isNotEmpty) {
      final user = await _authRepo.findByGoogleEmail(email);
      if (user != null) {
        _currentUser = user;
        _currentSchool = await _schoolRepo.findById(user.schoolId);
      } else {
        // Authentication Firebase-nya valid, tapi TIDAK ADA akun yang
        // di-whitelist admin untuk email ini (mis. dicabut admin sejak
        // login terakhir) -- authorization gagal, JANGAN anggap
        // "berhasil login" dan JANGAN diam-diam bikin anonymous fallback
        // (dilarang eksplisit oleh spesifikasi migrasi). Sign-out
        // Firebase + Google SEKARANG juga, supaya user diarahkan balik
        // ke Login Screen dan tombol "Masuk dengan Google" berikutnya
        // menampilkan account picker lagi (bukan diam-diam pakai sesi
        // yang sama yang sudah terbukti tidak terdaftar).
        await _signOutFirebaseAndGoogle();
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

  /// <-- BARU (migrasi auth: Anonymous -> Google Sign-In). SATU-SATUNYA
  /// jalur login sekarang (lihat [LoginScreen]). Alurnya SESUAI
  /// spesifikasi migrasi:
  ///
  /// Google Sign-In -> Google credential -> FirebaseAuth.signInWithCredential
  /// -> Firebase User (siapa?) -> [AuthRepository.findByGoogleEmail]
  /// (boleh akses?) -> [UserAccount]/[AccessScope] -> Dashboard.
  ///
  /// Return `true` kalau berhasil (email Google terdaftar & dapat
  /// [UserAccount]). Return `false` untuk SEMUA kegagalan lain (user
  /// batal pilih akun, tidak ada internet, error Firebase, ATAU
  /// authentication sukses tapi authorization gagal) -- [error] diisi
  /// pesan yang sesuai tiap kasus supaya UI bisa membedakannya kalau
  /// perlu, TIDAK PERNAH membuat anonymous fallback dalam kondisi
  /// apapun.
  Future<bool> signInWithGoogle() async {
    _loggingIn = true;
    _error = null;
    notifyListeners();

    late final UserCredential credential;
    try {
      if (kIsWeb) {
        // <-- BARU: google_sign_in.signIn() SUDAH TIDAK DIDUKUNG di
        // Flutter Web sejak Google migrasi ke Google Identity Services
        // (GIS) -- imperative signIn() SELALU throw di web, apapun
        // kondisi internetnya, makanya user Web/PWA (mis. Chrome Android)
        // sebelumnya selalu kena pesan salah kaprah "Periksa koneksi
        // internet Anda". Fix: di web pakai FirebaseAuth signInWithPopup
        // langsung (skip google_sign_in sama sekali di jalur ini), yang
        // memang jalur resmi Firebase Auth buat web.
        credential = await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
      } else {
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          // User membatalkan pemilihan akun (menutup dialog picker) --
          // BUKAN error, cukup balik ke Login Screen apa adanya.
          _loggingIn = false;
          _error = null;
          notifyListeners();
          return false;
        }

        final googleAuth = await googleUser.authentication;
        final oauthCredential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        credential = await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') {
        // Sama seperti googleUser == null di atas: user nutup popup
        // Google sendiri (di web) -- BUKAN error.
        _loggingIn = false;
        _error = null;
        notifyListeners();
        return false;
      }
      _loggingIn = false;
      _error = 'Gagal masuk dengan Google. Silakan coba lagi.';
      notifyListeners();
      return false;
    } catch (_) {
      // Payung buat error platform Google Sign-In (network/PlatformException
      // dkk) -- SENGAJA tidak dibedakan detail kodenya di sini (beda-beda
      // per platform), yang penting: TIDAK signOut user existing (tidak
      // ada yang perlu di-signOut, belum pernah signIn), TIDAK bikin
      // anonymous user, cukup laporkan gagal.
      _loggingIn = false;
      _error = 'Gagal masuk dengan Google. Periksa koneksi internet Anda.';
      notifyListeners();
      return false;
    }

    final firebaseUser = credential.user;
    final email = firebaseUser?.email?.trim().toLowerCase();
    if (firebaseUser == null || email == null || email.isEmpty) {
      _loggingIn = false;
      _error = 'Akun Google ini tidak memiliki alamat email yang valid.';
      notifyListeners();
      return false;
    }

    final user = await _authRepo.findByGoogleEmail(email);
    if (user == null) {
      // Authentication SUKSES, authorization GAGAL (lihat dokumentasi
      // panjang di AuthRepository.findByGoogleEmail) -- account Firestore
      // TIDAK otomatis dibuat, role TIDAK otomatis diberikan. Sign-out
      // supaya sesi Google/Firebase yang tidak berhak ini tidak
      // "menggantung" -- percobaan berikutnya menampilkan account picker
      // lagi (mis. kalau user salah pilih akun Google).
      await _signOutFirebaseAndGoogle();
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

  Future<void> _signOutFirebaseAndGoogle() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }

  /// Cari nama guru pembimbing yang mengampu pasangan Kelas+Halaqoh
  /// tertentu (dipakai saat export rekap per kelompok, lihat
  /// RecordsProvider.groupByKelasHalaqoh). Null kalau tidak ketemu (mis.
  /// kelas/halaqoh belum/tidak di-assign ke siapa pun).
  String? guruPembimbingNameFor(String kelas, String halaqoh) {
    // Dulu ada filter `if (acc.role != UserRole.guruPembimbing) continue;`
    // di sini — niatnya cuma nampilin guru yang emang berperan sbg
    // pembimbing, TAPI di data sekolah ini ada admin (mis. Muhammad
    // Hosri) yang juga MERANGKAP jadi guru pembimbing beberapa Kelas+
    // Halaqoh (assignments-nya keisi persis kayak guru biasa). Filter
    // role itu bikin admin yang merangkap ini ke-skip TOTAL dari
    // pencarian, padahal assignments-nya valid — makanya baris "Guru
    // Pembimbing" hilang di export walau data assignment-nya sudah
    // benar. Sekarang siapapun (admin ATAU guru_pembimbing) yang punya
    // assignment cocok ke Kelas+Halaqoh ini dianggap guru pembimbing-nya
    // — role cuma soal akses fitur admin, bukan penentu siapa yang
    // membimbing kelas mana.
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

  /// Muat ulang [allAccounts] dari repository — dipanggil abis admin
  /// ngedit assignment guru lewat layar Kelola Akun Guru. Kalau akun yang
  /// lagi login ikut ke-edit, [currentUser]/[scope] ikut disegerin juga di
  /// sini, biar assignment barunya langsung kepakai tanpa perlu
  /// logout-login dulu.
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

  /// <-- BERUBAH (migrasi auth). Dulu cuma bersihin [AppPrefsService.
  /// sessionUserId]. Sekarang HARUS signOut dari Firebase Auth & Google
  /// Sign-In juga (lihat [_signOutFirebaseAndGoogle]) -- SESUAI
  /// spesifikasi migrasi bagian LOGOUT: "JANGAN: signOut() ->
  /// signInAnonymously()... User harus login kembali menggunakan
  /// Google." TIDAK ADA pemanggilan signInAnonymously/anonymous fallback
  /// apapun di sini maupun di [_signOutFirebaseAndGoogle].
  Future<void> logout() async {
    _currentUser = null;
    _currentSchool = null;
    await AppPrefsService.instance.clearSession();
    await _signOutFirebaseAndGoogle();
    notifyListeners();
  }

  /// Ganti foto profil (path lokal). Persist ke [_authRepo] (override Hive
  /// per-device — lihat catatan bug fix lengkap di
  /// `AppPrefsService.photoOverrides`), BUKAN cuma update in-memory
  /// seperti sebelumnya — itu yang bikin foto baru "balik seperti semula"
  /// begitu app ditutup total lalu dibuka lagi.
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
