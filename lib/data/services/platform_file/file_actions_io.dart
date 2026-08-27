import 'dart:io';
import 'dart:typed_data';

import 'package:media_store_plus/media_store_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'exported_file.dart';

/// Implementasi Android/iOS/desktop — SAMA PERSIS dengan logic lama yang
/// dulu langsung nempel di `ExportService` (cuma dipindah ke sini biar
/// `export_service.dart` sendiri jadi platform-agnostic). Lihat
/// `file_actions.dart` buat penjelasan kenapa file ini dipisah.

Future<ExportedFile> persistExportedFile(String filename, List<int> bytes) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes, flush: true);
  return ExportedFile(bytes: Uint8List.fromList(bytes), filename: filename, path: file.path);
}

/// Buka file langsung pakai aplikasi bawaan perangkat (PDF viewer, Word,
/// Excel, dst).
Future<void> openExportedFile(ExportedFile file) async {
  if (file.path == null) return;
  await OpenFilex.open(file.path!);
}

Future<void> shareExportedFile(ExportedFile file, {String? subject}) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [
        file.path != null
            ? XFile(file.path!)
            : XFile.fromData(file.bytes, name: file.filename),
      ],
      subject: subject,
    ),
  );
}

/// Simpan salinan file ke penyimpanan perangkat (folder Download publik
/// di Android / lokasi yang dipilih user di iOS). CATATAN: [MediaStore]
/// dari package `media_store_plus` ini murni Android — di iOS/desktop
/// panggilan ini berpotensi no-op/error tergantung dukungan plugin,
/// keterbatasan yang SUDAH ADA dari sebelum refactor ini, bukan regresi
/// baru.
Future<void> saveExportedFileToDevice(
  ExportedFile file, {
  required String filename,
  required String ext,
}) async {
  if (file.path == null) return;
  await MediaStore().saveFile(
    tempFilePath: file.path!,
    dirType: DirType.download,
    dirName: DirName.download,
  );
}
