/// Cek versi web terbaru lewat version.json (dibuat otomatis oleh
/// `flutter build web`) + muat ulang bersih (hapus service worker & cache).
/// Implementasi web pakai package:web; platform lain no-op.
library;

export 'web_update_io.dart' if (dart.library.js_interop) 'web_update_web.dart';
