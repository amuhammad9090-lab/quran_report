import 'dart:typed_data';

import 'exported_file.dart';

/// Fallback aman kalau di-compile buat target yang bukan dart:io atau
/// dart:html (kasus sangat langka) — no-op, bukan crash, supaya app
/// setidaknya tetap jalan (fitur ekspor cuma diam-diam nggak ngapa-ngapain
/// alih-alih bikin seluruh app gagal build).
Future<ExportedFile> persistExportedFile(String filename, List<int> bytes) async {
  return ExportedFile(bytes: Uint8List.fromList(bytes), filename: filename, path: null);
}

Future<void> openExportedFile(ExportedFile file) async {}

Future<void> shareExportedFile(ExportedFile file, {String? subject}) async {}

Future<void> saveExportedFileToDevice(
  ExportedFile file, {
  required String filename,
  required String ext,
}) async {}
