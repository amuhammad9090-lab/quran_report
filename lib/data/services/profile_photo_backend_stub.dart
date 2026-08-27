import 'package:image_picker/image_picker.dart';

/// Fallback aman kalau di-compile buat target yang bukan dart:io atau
/// dart:html — selalu gagal "diam-diam" (return null / no-op), bukan
/// crash.
Future<String?> saveProfilePhoto(String userId, XFile picked) async => null;

Future<void> deleteProfilePhoto(String? photoPath) async {}
