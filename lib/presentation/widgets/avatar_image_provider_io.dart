import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// Implementasi Android/iOS/desktop — path biasa (hasil
/// `ProfilePhotoService` versi io) dibaca lewat [FileImage]. Tetap jaga2
/// buat kasus [photoPath] ternyata data URI base64 (mis. akun yang
/// fotonya sempat diset lewat Web lalu datanya "ikut" ke device lain lewat
/// sinkronisasi manual) — didekode jadi [MemoryImage] juga di sini,
/// supaya tetap tampil alih-alih coba dibuka sebagai path file yang jelas
/// tidak akan pernah ada.
ImageProvider? resolveAvatarImage(String? photoPath) {
  if (photoPath == null || photoPath.isEmpty) return null;
  if (photoPath.startsWith('data:')) {
    final bytes = _decodeDataUri(photoPath);
    return bytes == null ? null : MemoryImage(bytes);
  }
  return FileImage(File(photoPath));
}

/// BUG FIX: ganti/hapus foto profil sebelumnya nggak langsung kelihatan di
/// UI (baru update abis app di-kill total) — penyebabnya `FileImage`
/// nge-cache hasil decode gambar pakai KEY YANG CUMA DIBEDAKAN DARI PATH
/// FILE-nya (lihat `FileImageKey`), BUKAN dari isi file. Sementara
/// `ProfilePhotoService`/`saveProfilePhoto` SENGAJA nyimpen ke path yang
/// SAMA PERSIS tiap kali user ganti foto (deterministik per userId, biar
/// gampang di-manage & gak numpuk file lama) — jadi begitu file di path
/// itu ditimpa isinya, `PaintingBinding.imageCache` masih nyimpen decode
/// LAMA di bawah key path yang sama itu & terus makein itu, walau byte di
/// disk udah beda (termasuk abis di-crop ulang, hasilnya kelihatan sama
/// terus). Cache itu cuma kehapus kalau proses app-nya bener2 restart
/// (makanya "keganti pas RAM dibersihin"). Panggil ini SETELAH file
/// ditimpa/dihapus supaya Flutter kepaksa decode ulang dari disk.
void evictAvatarImageCache(String? photoPath) {
  if (photoPath == null || photoPath.isEmpty || photoPath.startsWith('data:')) return;
  PaintingBinding.instance.imageCache.evict(FileImage(File(photoPath)));
}

Uint8List? _decodeDataUri(String dataUri) {
  final commaIndex = dataUri.indexOf(',');
  if (commaIndex == -1) return null;
  try {
    return base64Decode(dataUri.substring(commaIndex + 1));
  } catch (_) {
    return null;
  }
}
