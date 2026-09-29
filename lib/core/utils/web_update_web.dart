import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Ambil build_number terbaru dari version.json di server.
/// null kalau gagal (offline, file tidak ada, dsb) — gagal cek update
/// tidak boleh mengganggu app.
Future<int?> fetchLatestWebBuild() async {
  try {
    final url = 'version.json?t=${DateTime.now().millisecondsSinceEpoch}';
    final resp = await web.window
        .fetch(url.toJS, web.RequestInit(cache: 'no-store'))
        .toDart;
    if (!resp.ok) return null;
    final text = (await resp.text().toDart).toDart;
    final json = jsonDecode(text) as Map<String, dynamic>;
    return int.tryParse('${json['build_number']}');
  } catch (_) {
    return null;
  }
}

/// Hapus service worker + cache Flutter, lalu reload halaman, supaya
/// yang dimuat benar-benar build terbaru (bukan sisa cache).
Future<void> reloadToLatest() async {
  try {
    final regs =
        await web.window.navigator.serviceWorker.getRegistrations().toDart;
    for (final r in regs.toDart) {
      await r.unregister().toDart;
    }
    final keys = await web.window.caches.keys().toDart;
    for (final k in keys.toDart) {
      await web.window.caches.delete(k.toDart).toDart;
    }
  } catch (_) {}
  web.window.location.reload();
}
