import 'package:image_picker/image_picker.dart';

import 'profile_photo_backend_stub.dart'
    if (dart.library.io) 'profile_photo_backend_io.dart'
    if (dart.library.html) 'profile_photo_backend_web.dart' as backend;

/// Ambil foto profil dari kamera/galeri lalu simpan.
///
/// - Di Android/iOS/desktop: disalin permanen ke app documents directory
///   (folder `profile_photos/`), return berupa PATH FILE ASLI.
/// - Di Web: TIDAK ADA filesystem asli untuk app biasa, jadi hasilnya
///   di-encode sebagai data URI base64 (`data:image/...;base64,...`) dan
///   STRING ITU SENDIRI yang disimpan sebagai `photoPath` (langsung di
///   Hive/local storage lewat `AuthProvider.updatePhotoPath`, tidak ada
///   "file" beneran yang tertulis ke device).
///
/// PENTING: file yang dikembalikan `image_picker` (`XFile.path`) sering
/// nunjuk ke lokasi cache sementara yang bisa dibersihkan OS kapan saja —
/// jadi TIDAK aman disimpan langsung sebagai `photoPath` permanen (di
/// platform io). Lihat implementasi masing2 platform di
/// `profile_photo_backend_io.dart` / `profile_photo_backend_web.dart`.
class ProfilePhotoService {
  ProfilePhotoService._();
  static final ProfilePhotoService instance = ProfilePhotoService._();

  final ImagePicker _picker = ImagePicker();

  /// [userId] dipakai sebagai nama file/identifier supaya tiap akun punya
  /// foto sendiri-sendiri dan foto baru otomatis menimpa yang lama (di
  /// platform io — tidak berlaku di Web karena tidak ada file tersimpan
  /// terpisah di sana, semuanya cuma string di `photoPath`).
  Future<String?> pickAndSave({
    required String userId,
    required ImageSource source,
  }) async {
    final XFile? picked = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return null;
    return backend.saveProfilePhoto(userId, picked);
  }

  /// Hapus file foto profil dari storage lokal — no-op di Web (tidak ada
  /// file tersendiri yang perlu dihapus, `photoPath` cuma string biasa
  /// yang akan ditimpa/dikosongkan lewat `AuthProvider.updatePhotoPath`).
  Future<void> delete(String? photoPath) => backend.deleteProfilePhoto(photoPath);
}
