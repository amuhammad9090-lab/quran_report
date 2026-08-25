import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Ambil foto profil dari kamera/galeri lalu simpan salinannya secara
/// permanen di app documents directory (folder `profile_photos/`).
///
/// PENTING: file yang dikembalikan `image_picker` (`XFile.path`) sering
/// nunjuk ke lokasi cache sementara yang bisa dibersihkan OS kapan saja —
/// jadi TIDAK aman disimpan langsung sebagai `photoPath` permanen. Di
/// sini filenya di-copy dulu ke lokasi yang stabil, baru path itu yang
/// dipakai/disimpan (lihat `AuthProvider.updatePhotoPath`).
class ProfilePhotoService {
  ProfilePhotoService._();
  static final ProfilePhotoService instance = ProfilePhotoService._();

  final ImagePicker _picker = ImagePicker();

  /// [userId] dipakai sebagai nama file supaya tiap akun punya foto
  /// sendiri-sendiri dan foto baru otomatis menimpa (overwrite) yang lama
  /// — tidak numpuk file yatim di storage.
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

    final dir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${dir.path}/profile_photos');
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    // Ekstensi ikut file asli (biasanya .jpg/.jpeg/.png) supaya tidak
    // salah decode; nama file tetap deterministik per user.
    final ext = picked.path.contains('.') ? picked.path.split('.').last : 'jpg';
    final savedPath = '${photosDir.path}/$userId.$ext';

    // Hapus dulu kalau ada foto lama dengan ekstensi berbeda (mis. ganti
    // dari .png ke .jpg), biar tidak ada file basi nyangkut di storage.
    if (await photosDir.exists()) {
      final existing = photosDir.listSync().whereType<File>().where(
            (f) => f.path.split('/').last.split('.').first == userId,
          );
      for (final f in existing) {
        await f.delete();
      }
    }

    final savedFile = await File(picked.path).copy(savedPath);
    return savedFile.path;
  }

  /// Hapus file foto profil (kalau ada) dari storage lokal.
  Future<void> delete(String? photoPath) async {
    if (photoPath == null) return;
    final file = File(photoPath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
