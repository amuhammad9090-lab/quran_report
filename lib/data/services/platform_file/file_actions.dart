/// Titik masuk TUNGGAL buat operasi file platform-spesifik (simpan/buka/
/// bagikan) — [ExportService] & pemanggilnya cukup `import` file ini,
/// implementasi asli yang dipilih Dart compiler sendiri sesuai target:
///
/// - `dart.library.io` ada  -> Android/iOS/desktop -> [file_actions_io.dart]
///   (dart:io, MediaStore, OpenFilex — persis logic lama, cuma dipindah)
/// - `dart.library.html` ada -> Web -> [file_actions_web.dart]
///   (trigger download lewat Blob + anchor element, sesuai konvensi web)
/// - keduanya nggak ada (kasus langka/masa depan) -> [file_actions_stub.dart]
///   (no-op aman, bukan crash)
///
/// CATATAN: kalau proyek ini nanti pindah ke Dart/Flutter versi yang
/// SEPENUHNYA menghapus `dart:html` (diganti `package:web` +
/// `dart:js_interop`), ganti kondisi `dart.library.html` di bawah jadi
/// `dart.library.js_interop`, dan tulis ulang `file_actions_web.dart`
/// pakai `package:web`. Per Flutter versi saat ini, `dart:html` masih
/// didukung penuh di stable channel.
library;
export 'file_actions_stub.dart'
    if (dart.library.io) 'file_actions_io.dart'
    if (dart.library.html) 'file_actions_web.dart';
