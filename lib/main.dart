import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/services/app_prefs_service.dart';
import 'data/services/download_notification_service.dart';
import 'data/services/firebase_bootstrap_status.dart';
import 'data/services/quran_engine_service.dart';
import 'data/services/storage_service.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/folders_provider.dart';
import 'providers/parent_notes_provider.dart';
import 'providers/records_provider.dart';
import 'providers/students_provider.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Mirror laporan ke Firestore buat Portal Orang Tua. Sign-in
  // ANONIM (bukan akun guru).
  try {
    // <-- BERUBAH: `if (Firebase.apps.isEmpty)` diganti jadi langsung
    // coba initializeApp() + tangkep KHUSUS 'duplicate-app'. Cek
    // isEmpty duluan itu race -- di Android, SDK native sudah otomatis
    // register app "[DEFAULT]" dari google-services.json SEBELUM Dart
    // main() ini jalan, jadi Firebase.apps.isEmpty kadang belum sempat
    // "lihat" itu, tetap manggil initializeApp(), lalu ditolak
    // [core/duplicate-app] (persis error yang muncul di Settings).
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } on FirebaseException catch (e) {
      if (e.code != 'duplicate-app') rethrow;
      debugPrint('Firebase app "[DEFAULT]" sudah ada duluan (native/hot-restart) -- pakai yang itu.');
    }

    final auth = FirebaseAuth.instance;
    final cached = auth.currentUser;
    if (cached == null) {
      await auth.signInAnonymously();
    } else {
      // reload() beneran nge-fetch ulang ke server -- lebih reliable
      // buat deteksi akun anonim lama yang udah invalid/kehapus
      // dibanding cuma getIdToken(true) doang.
      try {
        await cached.reload();
        final refreshedUser = auth.currentUser;
        if (refreshedUser == null) {
          await auth.signInAnonymously();
        } else {
          await refreshedUser.getIdToken(true);
        }
      } catch (_) {
        await auth.signOut();
        await auth.signInAnonymously();
      }
    }
    FirebaseBootstrapStatus.markReady();
    // <-- BERUBAH: blok `FirebaseFirestore.instance.settings = Settings(
    // webExperimentalForceLongPolling: true, persistenceEnabled: false)`
    // yang sempat ada di sini DICABUT LAGI. Awalnya dikira nge-fix
    // "server tidak merespon" di Web, tapi ternyata terbukti JUSTRU INI
    // biang keroknya -- sebelum baris Settings ini ada, Backup ke Cloud
    // pernah beneran sukses; begitu ditambahkan, SEMUA operasi Firestore
    // (termasuk yang sebelumnya jalan normal) jadi macet total/timeout,
    // di production build & Incognito sekalipun (jadi bukan soal
    // dev-mode/extension browser). Kesimpulan: kombinasi
    // `webExperimentalForceLongPolling`+`persistenceEnabled:false` ini
    // punya bug/ketidakcocokan dengan versi cloud_firestore yang dipakai
    // project ini -- dicabut total, balik ke default Settings bawaan
    // (yang sudah terbukti pernah berfungsi).
  } catch (e, st) {
    debugPrint('Firebase init/sign-in anonim GAGAL: $e');
    debugPrint('$st');
    FirebaseBootstrapStatus.markFailed(e);
  }

  if (!kIsWeb) {
    await MediaStore.ensureInitialized();
    MediaStore.appFolder = 'Quran Report';
  }

  await initializeDateFormatting('id_ID', null);
  await StorageService.instance.init();
  await AppPrefsService.instance.init();
  await QuranEngineService.instance.load();
  await DownloadNotificationService.instance.init();

  final themeProvider = ThemeProvider();
  await themeProvider.load();

  final authProvider = AuthProvider();
  await authProvider.restoreSession();

  final recordsProvider = RecordsProvider();
  await recordsProvider.load();

  recordsProvider.updateScope(authProvider.scope);

  final foldersProvider = FoldersProvider();
  await foldersProvider.load();

  final studentsProvider = StudentsProvider();
  await studentsProvider.load();

  final parentNotesProvider = ParentNotesProvider();
  parentNotesProvider.updateScope(authProvider.scope);
  // <-- SEMENTARA DIMATIKAN buat isolasi bug timeout/webchannel: baris
  // ini nyalain live listener notifikasi "Catatan dari Orang Tua"
  // (`.snapshots()` yang jalan terus dari app dibuka). Dicurigai listener
  // inilah yang bikin koneksi WebChannel jadi gak stabil (connect-putus-
  // connect-putus terus di Network tab), dan karena SEMUA operasi
  // Firestore (termasuk batch write Backup ke Cloud) numpuk ke satu
  // koneksi yang sama, backup ikut kena macet walau kodenya sendiri
  // tidak salah. Nyalain lagi baris ini begitu tes ini selesai.
  // parentNotesProvider.start();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: recordsProvider),
        ChangeNotifierProvider.value(value: foldersProvider),
        ChangeNotifierProvider.value(value: studentsProvider),
        ChangeNotifierProvider.value(value: parentNotesProvider),
      ],
      child: const QuranReportApp(),
    ),
  );
}