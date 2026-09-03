// <-- BARU (seluruh file)
import 'dart:async';

import 'package:flutter/material.dart';

import '../core/access/access_scope.dart';
import '../core/utils/text_utils.dart';
import '../data/models/parent_note.dart';
import '../data/services/parent_note_service.dart';

/// State notifikasi "Catatan dari Orang Tua" (bell icon di Home + halaman
/// Notifikasi). Mendengarkan live stream dari [ParentNoteService], lalu
/// men-scope hasilnya persis seperti [RecordsProvider] men-scope
/// SantriRecord: admin lihat semua, guru pembimbing hanya lihat catatan
/// yang kelas+halaqoh-nya cocok salah satu assignment-nya. Sengaja TIDAK
/// pakai `guruOwnerId` buat filter (lihat catatan panjang soal ini di
/// [AccessScope]) — dua guru yang sama-sama mengampu kelas+halaqoh yang
/// sama harus sama-sama kebagian notifikasinya.
class ParentNotesProvider extends ChangeNotifier {
  List<ParentNote> _all = [];
  AccessScope? _scope;
  StreamSubscription<List<ParentNote>>? _sub;
  bool _hasError = false;

  /// True kalau stream Firestore-nya sempat gagal (mis. device offline).
  /// Dipakai halaman Notifikasi buat nampilin pesan yang sesuai, BUKAN
  /// buat nge-block UI lain — fitur laporan utama tetap harus jalan
  /// normal walau notifikasi gagal connect.
  bool get hasError => _hasError;

  List<ParentNote> get notes {
    if (_scope == null) return const [];
    return _all
        .where((n) => _scope!.canAccessKelasHalaqoh(n.kelas, normalizeHalaqoh(n.halaqoh)))
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
  /// Firestore. Beda dari RecordsProvider.load() yang cuma sekali baca,
  /// di sini subscription-nya HIDUP TERUS selama app jalan supaya badge
  /// unread ke-update live begitu ada catatan baru masuk, tanpa guru
  /// perlu buka halaman Notifikasi dulu.
  void start() {
    _sub?.cancel();
    _sub = ParentNoteService.instance.watchAll().listen(
      (notes) {
        _all = notes;
        _hasError = false;
        notifyListeners();
      },
      onError: (_) {
        // Jangan lempar/crash — cukup tandai error, badge tetap tampil
        // apa adanya (data terakhir yang berhasil ke-load, kalau ada).
        _hasError = true;
        notifyListeners();
      },
    );
  }

  /// Dipanggil dari flow auth (restoreSession/login/logout) — pola sama
  /// persis dengan RecordsProvider.updateScope, lihat pemanggilnya di
  /// main.dart & login_screen.dart.
  void updateScope(AccessScope? scope) {
    _scope = scope;
    notifyListeners();
  }

  Future<void> markAsRead(ParentNote note) async {
    if (note.isRead) return;
    // Optimistic update lokal dulu biar badge langsung berkurang tanpa
    // nunggu round-trip Firestore — begitu stream `watchAll()` dapat
    // konfirmasi baliknya, list ini akan ketiban ulang otomatis dengan
    // data server (yang seharusnya sama).
    _optimisticUpdate(note.id, isRead: true);
    await ParentNoteService.instance.markAsRead(note.id);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
