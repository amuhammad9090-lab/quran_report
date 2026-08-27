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

Uint8List? _decodeDataUri(String dataUri) {
  final commaIndex = dataUri.indexOf(',');
  if (commaIndex == -1) return null;
  try {
    return base64Decode(dataUri.substring(commaIndex + 1));
  } catch (_) {
    return null;
  }
}
