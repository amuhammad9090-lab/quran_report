// <-- BARU (seluruh file)
//
// Awalnya, kegagalan `Firebase.initializeApp()` di main.dart ditelan
// diam-diam lewat `catch (_) {}` -- app tetap lanjut jalan TANPA
// Firebase SAMA SEKALI, dan SEMUA operasi Firestore (backup, restore,
// notifikasi) gagal permission-denied/unavailable tanpa pesan yang jelas
// ke mana pun. Static holder ini dicek di layar yang punya fitur cloud
// (mis. Settings > Backup/Pulihkan) supaya bisa kasih pesan yang lebih
// tepat sasaran ketimbang "Cek koneksi internet" generik.
//
// <-- BERUBAH (migrasi auth: Anonymous -> Google Sign-In): [ready] DULU
// juga ikut memverifikasi sign-in anonim berhasil (SDK Firebase Auth
// otomatis login diam-diam di setiap startup, lihat main.dart versi
// sebelumnya) -- jadi `ready == false` dulu bisa juga berarti "provider
// Anonymous belum diaktifkan di Firebase Console". SEKARANG sign-in
// tidak lagi terjadi otomatis di startup (interaktif, lewat Google
// Sign-In di Login Screen -- lihat AuthProvider.signInWithGoogle), jadi
// [ready] MURNI berarti "Firebase.initializeApp() berhasil" (SDK-nya
// siap dipakai). Belum login (Google) BUKAN kegagalan bootstrap --
// itu kondisi normal yang ditangani Login Screen sendiri, bukan status
// ini. [userMessage] disesuaikan supaya tidak lagi menyebut "Anonymous".
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
      'Fitur cloud (backup, restore, notifikasi) tidak aktif: inisialisasi Firebase gagal '
      '($error). Coba restart app -- kalau masih gagal, periksa koneksi internet & '
      'konfigurasi Firebase project (google-services.json/firebase_options.dart).';
}
