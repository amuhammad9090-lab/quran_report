import 'dart:convert';

import 'package:image_picker/image_picker.dart';

/// Implementasi Web — TIDAK ADA filesystem asli buat app biasa, jadi
/// "menyimpan" foto profil berarti encode bytes-nya jadi data URI base64
/// dan return STRING ITU SENDIRI (bukan path) — pemanggil
/// (`AuthProvider.updatePhotoPath`) menyimpannya apa adanya sebagai
/// `photoPath`, dan `avatar_image_provider_web.dart` yang nanti
/// decode-nya balik jadi gambar.
///
/// CATATAN UKURAN: `image_picker` sudah dibatasi maxWidth/maxHeight
/// 1024px + imageQuality 85 (lihat `ProfilePhotoService.pickAndSave`),
/// jadi data URI-nya biasanya di kisaran puluhan-ratusan KB — cukup aman
/// disimpan sebagai string biasa di Hive, TAPI kalau nanti ternyata mau
/// dukung foto resolusi lebih besar, pertimbangkan turunkan lagi
/// batasannya atau kompresi tambahan, karena base64 sendiri menambah
/// ukuran ~33% dari byte aslinya.
Future<String?> saveProfilePhoto(String userId, XFile picked) async {
  final bytes = await picked.readAsBytes();
  final mimeType = picked.mimeType ?? _guessMimeType(picked.name);
  final base64Str = base64Encode(bytes);
  return 'data:$mimeType;base64,$base64Str';
}

/// Tidak ada apapun untuk dihapus dari "disk" di Web — [photoPath] cuma
/// string biasa, sudah otomatis "terhapus" begitu field-nya ditimpa/
/// dikosongkan lewat `AuthProvider.updatePhotoPath(null)`.
Future<void> deleteProfilePhoto(String? photoPath) async {}

String _guessMimeType(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  return 'image/jpeg';
}
