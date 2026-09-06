// <-- BARU (seluruh file)
//
// Sebelumnya, kegagalan `Firebase.initializeApp()` /
// `FirebaseAuth.instance.signInAnonymously()` di main.dart ditelan diam-
// diam lewat `catch (_) {}` -- kalau sign-in anonim gagal (mis. provider
// "Anonymous" belum diaktifkan di Firebase Console > Authentication >
// Sign-in method), app tetap lanjut jalan TANPA login sama sekali, dan
// SEMUA operasi Firestore (backup, restore, notifikasi) gagal
// permission-denied -- karena semua rule di firestore.rules butuh
// `request.auth != null`. Errornya sendiri tidak pernah kelihatan di
// mana pun, jadi kelihatannya seperti masalah rules padahal sebenarnya
// app belum pernah berhasil "login" ke Firebase sama sekali.
//
// Static holder ini dicek di layar yang punya fitur cloud (mis. Settings
// > Backup/Pulihkan) supaya bisa kasih pesan yang lebih tepat sasaran
// ketimbang "Cek koneksi internet" generik saat penyebabnya sebenarnya
// auth, bukan jaringan.
class FirebaseBootstrapStatus {
  FirebaseBootstrapStatus._();

  static bool ready = false;
  static Object? error;

  static void markReady() {
    ready = true;
    error = null;
  }

  static void markFailed(Object e) {
    ready = false;
    error = e;
  }

  /// Pesan siap-pakai buat SnackBar/dialog kalau `ready == false`.
  static String get userMessage =>
      'Fitur cloud (backup, restore, notifikasi) tidak aktif: autentikasi Firebase gagal '
      '($error). Ini biasanya karena provider "Anonymous" belum diaktifkan di Firebase '
      'Console > Authentication > Sign-in method -- restart app setelah diaktifkan.';
}
