import 'dart:typed_data';

/// Representasi file hasil ekspor yang PLATFORM-AGNOSTIC — dipakai
/// [ExportService] & seluruh UI ekspor (`export_sheet.dart`,
/// `generate_rekap_bulanan_screen.dart`) supaya tidak ada satupun kode di
/// atas layer ini yang menyentuh `dart:io` langsung (yang bikin app gagal
/// DI-COMPILE sama sekali untuk target Web — bukan cuma error runtime).
///
/// [bytes] SELALU terisi di semua platform, termasuk Web (yang tidak
/// punya filesystem asli) — ini sumber kebenaran utama buat "buka" /
/// "bagikan" / "simpan" file.
///
/// [path] cuma terisi di platform non-Web (mobile/desktop, lihat
/// `file_actions_io.dart`) sebagai referensi lokasi temp file yang sudah
/// ditulis ke disk — dipakai buat operasi native macam OpenFilex yang
/// butuh path asli. SELALU null di Web — jangan diasumsikan ada.
class ExportedFile {
  final Uint8List bytes;
  final String filename;
  final String? path;

  const ExportedFile({
    required this.bytes,
    required this.filename,
    this.path,
  });
}
