// <-- BARU (seluruh file)
import 'dart:async';

import 'package:flutter/material.dart';

import '../core/access/access_scope.dart';
import '../core/utils/text_utils.dart';
import '../data/models/kelas_halaqoh.dart';
import '../data/models/parent_note.dart';
import '../data/services/parent_note_service.dart';
import '../data/services/parent_reply_notification_service.dart';

/// State notifikasi "Catatan dari Orang Tua" (bell icon di Home + halaman
/// Notifikasi). Men-scope hasilnya persis seperti [RecordsProvider]
/// men-scope SantriRecord: admin lihat semua, guru pembimbing hanya
/// lihat catatan yang kelas+halaqoh-nya cocok salah satu assignment-nya.
/// Sengaja TIDAK pakai `guruOwnerId` buat filter (lihat catatan panjang
/// soal ini di [AccessScope]) — dua guru yang sama-sama mengampu
/// kelas+halaqoh yang sama harus sama-sama kebagian notifikasinya.
///
/// <-- BERUBAH (audit optimasi Firestore read, BAGIAN D): dulu SEMUA
/// role (termasuk guru pembimbing) berlangganan [ParentNoteService.watchAll]
/// (baca SELURUH koleksi `parentNotes` di sekolah), lalu di-filter
/// kelas+halaqoh SECARA IN-MEMORY di [notes] getter -- artinya guru yang
/// cuma mengampu 1-2 kelas tetap membaca (dan terus mendengarkan
/// perubahan) SEMUA catatan milik kelas lain juga. Sekarang:
/// - ADMIN: tetap 1 listener global ([ParentNoteService.watchAll]) --
///   memang seharusnya begitu (akses global).
/// - GURU PEMBIMBING: satu listener Firestore-side per assignment EXACT
///   kelas+halaqoh (lihat [_resubscribe]) -- bukan `kelas IN [...] AND
///   halaqoh IN [...]` (itu menghasilkan cross-product yang salah, lihat
///   catatan [KelasHalaqoh]/[AccessScope]).
///
/// CATATAN KEAMANAN (BAGIAN I audit): filtering Firestore-side di atas
/// adalah OPTIMASI BACA, BUKAN batas keamanan. Firestore Rules
/// (`parentNotes.allow read: if isGuruApp()`) saat ini mengizinkan
/// SEMUA sesi app guru (yang otentikasinya sama-sama anonim, tidak ada
/// identitas per-guru di level Firestore) membaca seluruh koleksi kalau
/// mereka mau -- query yang dipersempit di sini cuma mengurangi apa yang
/// AKTUAL diminta/didengarkan oleh app, bukan mencegah guru lain
/// (hipotetis) query manual ke seluruh koleksi. Membuat rules yang benar
/// -benar membedakan "guru mana" akan butuh identitas Firebase Auth
/// per-guru (bukan anonim bersama) -- itu perubahan arsitektur besar di
/// luar cakupan audit ini (lihat laporan akhir untuk detail).
class ParentNotesProvider extends ChangeNotifier {
  List<ParentNote> _all = [];
  AccessScope? _scope;
  bool _hasError = false;
  bool _started = false;

  /// Listener admin (global) -- hanya salah satu dari ini atau
  /// [_pairSubs] yang aktif dalam satu waktu, tidak pernah dua-duanya.
  StreamSubscription<List<ParentNote>>? _adminSub;

  /// Listener guru, satu per (kelas, varian-halaqoh) -- lihat
  /// [_resubscribe]/[_halaqohVariants]. Key = "kelas|halaqohVariant".
  final Map<String, StreamSubscription<List<ParentNote>>> _pairSubs = {};
  final Map<String, List<ParentNote>> _pairNotes = {};

  // <-- BARU: deteksi catatan yang BENAR-BENAR baru, buat trigger
  // [ParentReplyNotificationService] (lihat dokumentasi lengkap di
  // [_handleIncomingSnapshot]). Global buat SELURUH umur provider ini
  // (tidak direset tiap resubscribe/ganti mode admin-guru) -- sengaja,
  // supaya catatan yang sudah pernah kelihatan sekali TIDAK PERNAH
  // memicu notifikasi lagi cuma gara-gara listener-nya dibuat ulang.
  final Set<String> _seenNoteIds = {};

  // Per-subscription (bukan global) -- true kalau subscription itu
  // sudah sempat menerima snapshot pertamanya. Snapshot PERTAMA suatu
  // subscription baru selalu berisi data yang SUDAH ADA sejak awal
  // (bukan "baru datang"), jadi sengaja tidak dianggap sebagai catatan
  // baru walau id-nya belum ada di [_seenNoteIds] -- kalau tidak,
  // setiap kali resubscribe (login, toggle Mode Admin, dst.) akan salah
  // memicu notifikasi buat semua catatan lama yang belum pernah dilihat
  // scope itu.
  bool _adminFirstSnapshotDone = false;
  final Map<String, bool> _pairFirstSnapshotDone = {};

  /// True kalau stream Firestore-nya sempat gagal (mis. device offline).
  /// Dipakai halaman Notifikasi buat nampilin pesan yang sesuai, BUKAN
  /// buat nge-block UI lain — fitur laporan utama tetap harus jalan
  /// normal walau notifikasi gagal connect.
  bool get hasError => _hasError;

  /// Filter tambahan di sini (selain yang sudah dilakukan Firestore-side
  /// buat guru) SENGAJA dipertahankan sebagai jaring pengaman kecil di
  /// memori -- BUKAN pengganti Firestore Rules (lihat catatan keamanan
  /// di atas kelas ini) -- misalnya buat admin (yang datanya memang
  /// global/tidak difilter query) tetap konsisten kalau suatu saat
  /// scope-nya berubah tanpa sempat resubscribe.
  List<ParentNote> get notes {
    final scope = _scope;
    if (scope == null) return const [];
    return _all
        .where((n) => scope.canAccessKelasHalaqoh(n.kelas, normalizeHalaqoh(n.halaqoh)))
        .where((n) => !n.dismissed)
        .toList();
  }

  int get unreadCount => notes.where((n) => !n.isRead).length;

  ParentNote _withFlags(ParentNote n, {bool? isRead, bool? dismissed}) => ParentNote(
        id: n.id,
        studentId: n.studentId,
        namaAnak: n.namaAnak,
        kelas: n.kelas,
        halaqoh: n.halaqoh,
        guruOwnerId: n.guruOwnerId,
        message: n.message,
        createdAt: n.createdAt,
        isRead: isRead ?? n.isRead,
        dismissed: dismissed ?? n.dismissed,
      );

  void _optimisticUpdate(String noteId, {bool? isRead, bool? dismissed}) {
    _all = [
      for (final n in _all)
        if (n.id == noteId) _withFlags(n, isRead: isRead, dismissed: dismissed) else n,
    ];
    notifyListeners();
  }

  /// Sembunyikan satu catatan dari daftar Notifikasi -- update field
  /// `dismissed` di Firestore (lihat dokumentasi lengkap di
  /// [ParentNote.dismissed]), BUKAN delete dokumennya. Dipakai
  /// swipe-to-dismiss di [NotificationsScreen].
  Future<void> dismissNote(String noteId) async {
    _optimisticUpdate(noteId, dismissed: true);
    await ParentNoteService.instance.setDismissed(noteId, true);
  }

  /// Kebalikan [dismissNote] -- dipakai tombol "Undo" di SnackBar abis
  /// swipe, biar swipe kepencet gak sengaja gampang dibatalkan.
  Future<void> undismissNote(String noteId) async {
    _optimisticUpdate(noteId, dismissed: false);
    await ParentNoteService.instance.setDismissed(noteId, false);
  }

  /// "Hapus semua" -- sembunyikan seluruh catatan yang lagi tampil
  /// (sudah discope) sekaligus. Dipakai tombol "Hapus semua" di header
  /// [NotificationsScreen].
  Future<void> dismissAll() async {
    final ids = notes.map((n) => n.id).toList();
    for (final id in ids) {
      _optimisticUpdate(id, dismissed: true);
    }
    await Future.wait(ids.map((id) => ParentNoteService.instance.setDismissed(id, true)));
  }

  /// Dipanggil sekali di startup (main.dart) — mulai dengar stream
  /// Firestore sesuai scope yang sudah diset lewat [updateScope]
  /// sebelumnya (lihat main.dart -- updateScope dipanggil DULU baru
  /// start()). Beda dari RecordsProvider.load() yang cuma sekali baca,
  /// di sini subscription-nya HIDUP TERUS selama app jalan supaya badge
  /// unread ke-update live begitu ada catatan baru masuk, tanpa guru
  /// perlu buka halaman Notifikasi dulu.
  void start() {
    _started = true;
    _resubscribe();
  }

  /// Dipanggil dari flow auth (restoreSession/login/logout/toggle Mode
  /// Admin) — pola sama persis dengan RecordsProvider.updateScope,
  /// lihat pemanggilnya di main.dart, login_screen.dart & profile_screen.dart.
  ///
  /// <-- BERUBAH: dulu cuma nyimpen [_scope] baru (filtering di-scope
  /// belakangan di [notes] getter, dari data yang SAMA buat semua role).
  /// Sekarang scope berubah = SUMBER datanya sendiri (listener mana yang
  /// aktif) ikut berubah -- lihat [_resubscribe]. Kalau dipanggil
  /// SEBELUM [start] (persis urutan di main.dart), cuma nyimpen scope-nya
  /// dulu -- listener yang sebenarnya baru dibuat sekali di [start],
  /// biar tidak subscribe-lalu-langsung-cancel-lalu-subscribe-lagi pas
  /// startup.
  void updateScope(AccessScope? scope) {
    _scope = scope;
    if (_started) {
      _resubscribe();
    } else {
      notifyListeners();
    }
  }

  /// <-- BARU: satu-satunya tempat yang membuat/membatalkan
  /// subscription. Selalu membatalkan SEMUA listener lama dulu (admin
  /// maupun per-pasangan guru) sebelum membuat yang baru sesuai scope
  /// SEKARANG -- supaya tidak pernah ada listener ganda/nyangkut dari
  /// scope sebelumnya (BAGIAN D acceptance criteria: "Tidak ada
  /// duplicate listener", "Listener dibatalkan ketika scope
  /// berubah/logout/dispose").
  void _resubscribe() {
    _cancelAllSubs();

    final scope = _scope;
    if (scope == null) {
      // Logout / belum ada sesi -- tidak ada apa pun yang perlu
      // didengarkan.
      _all = [];
      notifyListeners();
      return;
    }

    if (scope.isAdmin) {
      _adminSub = ParentNoteService.instance.watchAll().listen(
        (notes) {
          _handleIncomingSnapshot(notes, isFirstSnapshot: !_adminFirstSnapshotDone);
          _adminFirstSnapshotDone = true;
          _all = notes;
          _hasError = false;
          notifyListeners();
        },
        onError: (_) {
          _hasError = true;
          notifyListeners();
        },
      );
      return;
    }

    // Guru pembimbing: satu listener Firestore-side per assignment EXACT
    // kelas+halaqoh (bukan whereIn kelas × whereIn halaqoh -- itu
    // cross-product yang salah, lihat AccessScope/KelasHalaqoh).
    final assignments = <KelasHalaqoh>{...scope.user.assignments};
    if (assignments.isEmpty) {
      _all = [];
      notifyListeners();
      return;
    }

    for (final assignment in assignments) {
      for (final halaqohVariant in _halaqohVariants(assignment.halaqoh)) {
        final key = '${assignment.kelas}|$halaqohVariant';
        if (_pairSubs.containsKey(key)) continue; // jangan duplicate listener
        _pairNotes[key] = const [];
        _pairFirstSnapshotDone[key] = false;
        _pairSubs[key] = ParentNoteService.instance
            .watchForPair(assignment.kelas, halaqohVariant)
            .listen(
          (notes) {
            _handleIncomingSnapshot(notes, isFirstSnapshot: !(_pairFirstSnapshotDone[key] ?? false));
            _pairFirstSnapshotDone[key] = true;
            _pairNotes[key] = notes;
            _hasError = false;
            _recomputeMergedNotes();
          },
          onError: (_) {
            _hasError = true;
            notifyListeners();
          },
        );
      }
    }
  }

  /// Data lama/hasil import Excel kadang menyimpan halaqoh dengan prefix
  /// "Halaqoh " (lihat `normalizeHalaqoh` & catatan serupa di
  /// SantriRecord/Student/ParentNote) -- query Firestore exact-match
  /// TIDAK menormalisasi otomatis waktu dibandingkan, jadi di sini kita
  /// dengarkan KEDUA kemungkinan representasi supaya catatan tidak
  /// diam-diam hilang cuma gara-gara beda format string. Ini TETAP exact
  /// pasangan kelas+halaqoh yang SAMA (bukan melebarkan scope ke
  /// kelas/halaqoh lain) -- cuma toleran ke 2 varian tulisan dari
  /// assignment yang sama.
  Set<String> _halaqohVariants(String normalized) {
    if (normalized.isEmpty) return {normalized};
    return {normalized, 'Halaqoh $normalized'};
  }

  void _recomputeMergedNotes() {
    final merged = <String, ParentNote>{};
    for (final list in _pairNotes.values) {
      for (final n in list) {
        merged[n.id] = n;
      }
    }
    final result = merged.values.toList()
      ..sort((a, b) {
        final at = a.createdAt;
        final bt = b.createdAt;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return bt.compareTo(at);
      });
    _all = result;
    notifyListeners();
  }

  /// <-- BARU: dipanggil dari SETIAP snapshot listener Firestore yang
  /// SUDAH ADA (admin & tiap pair guru) -- BUKAN listener/query tambahan
  /// (B15: "tidak ada listener tambahan yang tidak perlu"), cuma numpang
  /// baca hasil listener yang memang sudah didengarkan buat keperluan
  /// [notes]/[unreadCount] itu sendiri.
  ///
  /// [isFirstSnapshot]=true berarti ini snapshot PERTAMA dari
  /// subscription ybs (lihat [_adminFirstSnapshotDone]/
  /// [_pairFirstSnapshotDone]) -- semua id-nya dicatat ke [_seenNoteIds]
  /// TANPA memicu notifikasi (itu data lama, bukan "baru datang").
  /// Snapshot BERIKUTNYA baru dibandingkan ke [_seenNoteIds] global --
  /// id yang belum pernah tercatat = catatan yang BENAR-BENAR baru saja
  /// dikirim orang tua, dan itu yang memicu
  /// [ParentReplyNotificationService.notifyNewReply].
  ///
  /// SENGAJA tidak peduli `isRead`/`dismissed` di sini -- catatan yang
  /// baru saja dibuat Portal Ortu selalu `isRead: false, dismissed:
  /// false` (lihat model), jadi setiap id baru pasti memang balasan baru
  /// yang belum pernah dilihat siapa pun.
  void _handleIncomingSnapshot(List<ParentNote> notes, {required bool isFirstSnapshot}) {
    if (isFirstSnapshot) {
      _seenNoteIds.addAll(notes.map((n) => n.id));
      return;
    }
    for (final note in notes) {
      if (_seenNoteIds.add(note.id)) {
        // .add() balikin true kalau id ini memang belum ada di set
        // (baru ditambahkan barusan) -- persis penanda "baru".
        ParentReplyNotificationService.instance.notifyNewReply(note);
      }
    }
  }

  void _cancelAllSubs() {
    _adminSub?.cancel();
    _adminSub = null;
    _adminFirstSnapshotDone = false;
    for (final sub in _pairSubs.values) {
      sub.cancel();
    }
    _pairSubs.clear();
    _pairNotes.clear();
    _pairFirstSnapshotDone.clear();
  }

  Future<void> markAsRead(ParentNote note) async {
    if (note.isRead) return;
    // Optimistic update lokal dulu biar badge langsung berkurang tanpa
    // nunggu round-trip Firestore — begitu stream terkait dapat
    // konfirmasi baliknya, list ini akan ketiban ulang otomatis dengan
    // data server (yang seharusnya sama).
    _optimisticUpdate(note.id, isRead: true);
    await ParentNoteService.instance.markAsRead(note.id);
  }

  @override
  void dispose() {
    _cancelAllSubs();
    super.dispose();
  }
}
