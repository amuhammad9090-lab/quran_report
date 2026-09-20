import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

/// Hasil [FirebaseAuthService.signInWithGoogle]; pesan error untuk UI ditentukan pemanggil.
enum GoogleSignInStatus {
  /// Berhasil; [GoogleSignInResult.email] terisi (trim + lowercase).
  success,

  /// User menutup account picker/popup — bukan error.
  cancelled,

  /// Error dari Firebase Auth (selain popup ditutup).
  firebaseError,

  /// Error platform Google Sign-In (jaringan, PlatformException, dkk) — sengaja tak dibedakan.
  platformError,

  /// Login sukses tapi akun Google tidak punya email yang valid.
  noEmail,
}

class GoogleSignInResult {
  final GoogleSignInStatus status;
  final String? email;
  const GoogleSignInResult(this.status, [this.email]);
}

/// Satu-satunya pintu ke Firebase Auth + Google Sign-In untuk app ini. Hanya mengurus
/// authentication (siapa user Google ini); authorization (boleh akses atau tidak) tetap urusan
/// AuthProvider + AuthRepository. Tidak pernah membuat anonymous user.
class FirebaseAuthService {
  FirebaseAuthService._();
  static final FirebaseAuthService instance = FirebaseAuthService._();

  // Instance tunggal (bukan GoogleSignIn() baru tiap panggil) agar state "akun terakhir
  // terpilih" konsisten untuk retry/signOut setelah signIn() gagal di tengah jalan.
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: const ['email']);

  /// Email (trim + lowercase) session Firebase yang dipulihkan SDK, atau null kalau belum login /
  /// email tidak valid. Memakai `authStateChanges().first` (bukan `currentUser` langsung) agar
  /// di Flutter Web tak salah kira "belum login" saat session masih dipulihkan; timeout 5 detik
  /// sebagai jaring pengaman (fallback ke `currentUser`).
  Future<String?> restoredEmail() async {
    final firebaseUser = await FirebaseAuth.instance.authStateChanges().first.timeout(
          const Duration(seconds: 5),
          onTimeout: () => FirebaseAuth.instance.currentUser,
        );
    final email = firebaseUser?.email?.trim().toLowerCase();

    if (firebaseUser != null && email != null && email.isNotEmpty) return email;
    return null;
  }

  /// Google Sign-In -> credential -> FirebaseAuth. Di web memakai `signInWithPopup` (imperative
  /// `google_sign_in.signIn()` tak didukung sejak Google Identity Services); di platform lain
  /// memakai alur google_sign_in + `signInWithCredential`.
  Future<GoogleSignInResult> signInWithGoogle() async {
    late final UserCredential credential;
    try {
      if (kIsWeb) {
        credential = await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
      } else {
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          // User membatalkan pemilihan akun — bukan error.
          return const GoogleSignInResult(GoogleSignInStatus.cancelled);
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
        // User menutup popup Google sendiri (web) — bukan error.
        return const GoogleSignInResult(GoogleSignInStatus.cancelled);
      }
      return const GoogleSignInResult(GoogleSignInStatus.firebaseError);
    } catch (_) {
      // Error platform Google Sign-In: kodenya beda per platform, jadi sengaja tak dibedakan.
      // Tidak ada user existing yang perlu di-signOut dan tidak ada anonymous fallback.
      return const GoogleSignInResult(GoogleSignInStatus.platformError);
    }

    final firebaseUser = credential.user;
    final email = firebaseUser?.email?.trim().toLowerCase();
    if (firebaseUser == null || email == null || email.isEmpty) {
      return const GoogleSignInResult(GoogleSignInStatus.noEmail);
    }
    return GoogleSignInResult(GoogleSignInStatus.success, email);
  }

  /// Sign-out dari Google dan Firebase (kegagalan masing-masing diabaikan). Sengaja TIDAK
  /// diikuti signInAnonymously: user harus login ulang dengan Google.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }
}
