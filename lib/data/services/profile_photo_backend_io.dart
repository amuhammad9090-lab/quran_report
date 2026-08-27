import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Implementasi Android/iOS/desktop — SAMA PERSIS dengan logic
/// `ProfilePhotoService` yang lama sebelum dipisah per-platform (lihat
/// `profile_photo_service.dart`).
Future<String?> saveProfilePhoto(String userId, XFile picked) async {
  final dir = await getApplicationDocumentsDirectory();
  final photosDir = Directory('${dir.path}/profile_photos');
  if (!await photosDir.exists()) {
    await photosDir.create(recursive: true);
  }

  // Ekstensi ikut file asli (biasanya .jpg/.jpeg/.png) supaya tidak salah
  // decode; nama file tetap deterministik per user.
  final ext = picked.path.contains('.') ? picked.path.split('.').last : 'jpg';
  final savedPath = '${photosDir.path}/$userId.$ext';

  // Hapus dulu kalau ada foto lama dengan ekstensi berbeda (mis. ganti
  // dari .png ke .jpg), biar tidak ada file basi nyangkut di storage.
  final existing = photosDir.listSync().whereType<File>().where(
        (f) => f.path.split('/').last.split('.').first == userId,
      );
  for (final f in existing) {
    await f.delete();
  }

  final savedFile = await File(picked.path).copy(savedPath);
  return savedFile.path;
}

/// Hapus file foto profil (kalau ada) dari storage lokal. Menangani baik
/// path file asli maupun (secara defensif) data URI base64 yang somehow
/// nyangkut di [photoPath] — data URI bukan path file, jadi dilewati
/// begitu saja (tidak ada apapun untuk dihapus dari disk).
Future<void> deleteProfilePhoto(String? photoPath) async {
  if (photoPath == null || photoPath.isEmpty || photoPath.startsWith('data:')) return;
  final file = File(photoPath);
  if (await file.exists()) {
    await file.delete();
  }
}
