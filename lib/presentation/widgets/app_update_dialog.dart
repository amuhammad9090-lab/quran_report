import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';

import '../../core/utils/web_update.dart';
import '../../data/services/app_update_service.dart';

/// Panggil sekali setelah login (mis. di initState MainShell):
///   WidgetsBinding.instance.addPostFrameCallback(
///     (_) => checkForAppUpdate(context));
/// Nomor build web yang sedang jalan, di-set saat build:
///   flutter build web --release --dart-define=APP_BUILD=2
/// (samakan dengan angka setelah "+" di pubspec). Kalau tidak di-set (0),
/// cek update web dilewati.
/// SEMENTARA: tampilkan hasil cek update di SnackBar buat debugging.
/// Set false (atau hapus) kalau fitur sudah beres.
const bool kShowUpdateDebug = false;

const int kRunningWebBuild = int.fromEnvironment('APP_BUILD', defaultValue: 0);

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

Future<void> _checkWebUpdate(BuildContext context,
    {bool manual = false}) async {
  if (kRunningWebBuild <= 0) {
    if (manual) _toast(context, 'Cek update web belum diaktifkan.');
    return;
  }
  final latest = await fetchLatestWebBuild();
  if (!context.mounted) return;
  if (latest == null || latest <= kRunningWebBuild) {
    if (manual) {
      _toast(
          context,
          latest == null
              ? 'Gagal mengecek pembaruan. Coba lagi nanti.'
              : 'Anda sudah memakai versi terbaru.');
    }
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Versi baru tersedia'),
      content: const Text(
          'Ada pembaruan aplikasi. Muat ulang sekarang untuk memakai versi terbaru?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Nanti'),
        ),
        FilledButton(
          onPressed: () => reloadToLatest(),
          child: const Text('Muat ulang'),
        ),
      ],
    ),
  );
}

/// [manual] = true kalau dipanggil dari tombol "Cek pembaruan" (di Pengaturan):
/// selalu kasih feedback, termasuk saat sudah versi terbaru.
Future<void> checkForAppUpdate(BuildContext context,
    {bool manual = false}) async {
  if (kIsWeb) return _checkWebUpdate(context, manual: manual);
  final info = await AppUpdateService.check();
  if (!context.mounted) return;
  if (kShowUpdateDebug) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 12),
      content: Text('[update] ${AppUpdateService.lastStatus}'),
    ));
  }
  if (info == null) {
    if (manual) {
      final s = AppUpdateService.lastStatus;
      final failed = s.startsWith('gagal') ||
          s.contains('tidak ditemukan') ||
          s.contains('apkUrl kosong');
      _toast(
          context,
          failed
              ? 'Gagal mengecek pembaruan. Coba lagi nanti.'
              : 'Anda sudah memakai versi terbaru.');
    }
    return;
  }
  await showDialog<void>(
    context: context,
    barrierDismissible: !info.forced,
    builder: (_) => _UpdateDialog(info: info),
  );
}

class _UpdateDialog extends StatefulWidget {
  final AppUpdateInfo info;
  const _UpdateDialog({required this.info});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog>
    with WidgetsBindingObserver {
  bool _busy = false;
  double _progress = 0;
  String? _error;
  String? _info;
  // true begitu download selesai / installer atau layar izin dibuka.
  // Setelah itu kita tidak dapat callback apa pun dari Android kalau user
  // membatalkan, jadi dialog dibuka kembali saat app kembali ke depan.
  bool _installStarted = false;
  StreamSubscription<OtaEvent>? _sub;

  bool get _canDismiss => !widget.info.forced && (!_busy || _progress >= 1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _installStarted) {
      _installStarted = false;
      _sub?.cancel();
      _sub = null;
      if (!mounted) return;
      setState(() {
        _busy = false;
        _progress = 0;
        _info = 'Instalasi belum selesai. Tekan "Coba lagi" untuk melanjutkan.';
      });
    }
  }

  void _start() {
    _sub?.cancel();
    _installStarted = false;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
      _progress = 0;
    });

    _sub = OtaUpdate()
        .execute(
          widget.info.apkUrl,
          destinationFilename: 'quran_report.apk',
        )
        .listen(
      (event) {
        if (!mounted) return;
        switch (event.status) {
          case OtaStatus.DOWNLOADING:
            final pct = double.tryParse(event.value ?? '0') ?? 0;
            if (pct >= 100) _installStarted = true;
            setState(() => _progress = pct / 100);
          case OtaStatus.INSTALLING:
            // Android menampilkan layar install sendiri.
            _installStarted = true;
            setState(() => _progress = 1);
          case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
            _fail('Izin "Install aplikasi tidak dikenal" belum diberikan.');
          default:
            debugPrint('[update] OTA ${event.status.name}: ${event.value}');
            _fail('Gagal (${event.status.name}): ${event.value ?? '-'}');
        }
      },
      onError: (e) {
        debugPrint('[update] OTA stream error: $e');
        _fail('Gagal mengunduh update: $e');
      },
    );
  }

  void _fail(String msg) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = msg;
    });
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final title = info.latestVersionName.isEmpty
        ? 'Update tersedia'
        : 'Update ${info.latestVersionName} tersedia';

    return PopScope(
      canPop: _canDismiss,
      child: AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(info.forced
                ? 'Versi ini sudah tidak didukung. Silakan update untuk melanjutkan.'
                : 'Versi baru aplikasi sudah tersedia. Mau update sekarang?'),
            if (info.changelog.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(info.changelog),
            ],
            if (_busy) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress > 0 ? _progress : null),
              const SizedBox(height: 6),
              Text(_progress >= 1
                  ? 'Membuka installer…'
                  : 'Mengunduh… ${(_progress * 100).toInt()}%'),
            ],
            if (_info != null) ...[
              const SizedBox(height: 12),
              Text(_info!),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
        actions: [
          if (_canDismiss)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Nanti'),
            ),
          FilledButton(
            onPressed: _busy ? null : _start,
            child: Text(_error != null || _info != null
                ? 'Coba lagi'
                : 'Update sekarang'),
          ),
        ],
      ),
    );
  }
}
