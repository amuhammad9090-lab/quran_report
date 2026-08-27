// ignore_for_file: deprecated_member_use
// dart:html dipakai dengan sengaja di sini (bukan lupa migrasi) — lihat
// catatan di file_actions.dart soal kapan ini perlu diganti package:web.
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import 'exported_file.dart';

/// Implementasi Web — browser TIDAK punya filesystem asli buat app biasa,
/// jadi "menyimpan"/"membuka" file selalu berarti TRIGGER DOWNLOAD lewat
/// Blob URL + elemen <a download> (pola standar web, sama yang dipakai
/// hampir semua web app buat export file). [ExportedFile.path] selalu
/// null di sini (lihat exported_file.dart) — semua operasi murni pakai
/// [ExportedFile.bytes].

Future<ExportedFile> persistExportedFile(String filename, List<int> bytes) async {
  // Tidak ada "menyimpan ke disk" beneran di Web — bytes-nya sendiri
  // sudah cukup buat semua operasi berikutnya (download/share).
  return ExportedFile(bytes: Uint8List.fromList(bytes), filename: filename, path: null);
}

/// Browser tidak punya konsep "buka file pakai app lain" seperti mobile —
/// treat sebagai download langsung, app/viewer yang membuka file hasil
/// download itu sepenuhnya di luar kendali web app (tergantung OS/browser
/// pengguna).
Future<void> openExportedFile(ExportedFile file) async {
  _downloadBlob(file.bytes, file.filename);
}

/// Web Share API (kalau browser & konteksnya support — umumnya cuma di
/// HTTPS + browser mobile) lewat share_plus, dengan fallback ke download
/// langsung kalau tidak didukung/gagal (mis. browser desktop lama).
Future<void> shareExportedFile(ExportedFile file, {String? subject}) async {
  try {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(file.bytes, name: file.filename)],
        subject: subject,
      ),
    );
  } catch (_) {
    _downloadBlob(file.bytes, file.filename);
  }
}

Future<void> saveExportedFileToDevice(
  ExportedFile file, {
  required String filename,
  required String ext,
}) async {
  _downloadBlob(file.bytes, '$filename.$ext');
}

void _downloadBlob(List<int> bytes, String filename) {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
