import 'dart:convert';

/// Hashing password LOKAL untuk kebutuhan prototype `LocalAuthRepository`.
///
/// ==================== PENTING — BACA SEBELUM PAKAI ====================
/// Ini BUKAN algoritma cryptographic-grade (bukan bcrypt/argon2/scrypt).
/// Sengaja dibuat tanpa dependency tambahan (tidak butuh package `crypto`)
/// supaya tidak nambah dependency baru tanpa persetujuan eksplisit. Untuk
/// implementasi lokal/prototype ini cukup — tujuannya cuma memastikan
/// tidak ada password plaintext yang tersimpan di JSON/Hive.
///
/// KETIKA MIGRASI KE BACKEND PRODUCTION:
/// - Hapus service ini dari alur login.
/// - Verifikasi password harus dilakukan SERVER-SIDE dengan algoritma
///   yang proper (bcrypt/argon2), bukan di client.
/// - `AuthRepository` abstraction sudah didesain supaya penggantian ini
///   tidak menyentuh UI/provider sama sekali.
/// ========================================================================
class AuthHashService {
  AuthHashService._();
  static final AuthHashService instance = AuthHashService._();

  // "Pepper" tetap — cuma buat bikin hash lokal ini nggak identik dengan
  // hash generik di internet. BUKAN pengganti salt per-user yang proper.
  static const _pepper = 'quran_report_local_proto_v1';

  /// FNV-1a 64-bit — cepat, deterministik, tanpa dependency eksternal.
  ///
  /// Dipakai [BigInt] (bawaan `dart:core`) buat aritmatika 64-bit-nya,
  /// BUKAN literal `int` 64-bit langsung. Soalnya waktu di-compile ke Web,
  /// Dart merepresentasikan `int` sebagai `double` JavaScript yang cuma
  /// presisi sampai 53-bit — literal/mask 64-bit di atas itu bakal
  /// kepotong/berubah nilai dan hasil hash-nya beda antara native & web.
  /// `BigInt` presisinya arbitrary, jadi hasilnya pasti identik di kedua
  /// platform (dan hash yang udah kesimpen dari versi native tetap valid).
  String hash(String plainPassword) {
    final fnvOffsetBasis = BigInt.parse('cbf29ce484222325', radix: 16);
    final fnvPrime = BigInt.parse('100000001b3', radix: 16);
    final mask64 = (BigInt.one << 64) - BigInt.one;

    BigInt h = fnvOffsetBasis;
    final bytes = utf8.encode('$_pepper:$plainPassword');
    for (final b in bytes) {
      h = (h ^ BigInt.from(b)) & mask64;
      h = (h * fnvPrime) & mask64;
    }
    return h.toRadixString(16).padLeft(16, '0');
  }

  bool verify(String plainPassword, String expectedHash) {
    return hash(plainPassword) == expectedHash;
  }
}