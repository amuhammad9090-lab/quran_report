import 'dart:convert';

import 'package:flutter/widgets.dart';

/// Implementasi Web — TIDAK ADA filesystem asli, jadi [photoPath] di sini
/// SELALU berupa data URI base64 (`data:image/...;base64,...`, hasil
/// `ProfilePhotoService` versi web) atau null. Path file "asli" (kalau
/// somehow ke-set, mis. dari akun yang sama pernah dipakai di mobile)
/// tidak bisa dibaca di Web sama sekali -> fallback null (pemanggil jatuh
/// ke inisial nama, bukan crash).
ImageProvider? resolveAvatarImage(String? photoPath) {
  if (photoPath == null || photoPath.isEmpty || !photoPath.startsWith('data:')) {
    return null;
  }
  final commaIndex = photoPath.indexOf(',');
  if (commaIndex == -1) return null;
  try {
    final bytes = base64Decode(photoPath.substring(commaIndex + 1));
    return MemoryImage(bytes);
  } catch (_) {
    return null;
  }
}
