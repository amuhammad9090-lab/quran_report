import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/app_config.dart';
import '../../core/utils/text_utils.dart';
import '../models/kelas_halaqoh.dart';
import '../models/student.dart';
import '../models/user_account.dart';

/// Satu perubahan pada satu laporan di cloud (hasil [RecordAlignmentService.plan]).
class AlignOp {
  /// Dokumen laporan yang jadi sumber (akun + id dokumen, id = [recordId]).
  final String fromAccountId;

  /// Akun tujuan: akun guru yang sekarang memegang halaqoh siswa ini (sama dengan [fromAccountId]
  /// kalau laporan tidak perlu dipindah).
  final String toAccountId;
  final String recordId;

  /// Isi dokumen yang akan ditulis ke [toAccountId] (label + id siswa sudah diperbarui).
  final Map<String, dynamic> data;

  /// Akun lain yang menyimpan salinan laporan yang sama (dobel) dan akan dihapus.
  final List<String> deleteFromAccountIds;

  const AlignOp({
    required this.fromAccountId,
    required this.toAccountId,
    required this.recordId,
    required this.data,
    required this.deleteFromAccountIds,
  });

  bool get isMove => fromAccountId != toAccountId;
}

/// Perubahan satu dokumen rekap pekanan (`weeklyRecaps`) yang dibaca Portal Ortu.
class RecapOp {
  final String fromAccountId;
  final String oldId;
  final String toAccountId;
  final String newId;

  /// Isi dokumen baru; null = hanya hapus dokumen lama (dokumen tujuan sudah ada).
  final Map<String, dynamic>? data;
  const RecapOp({
    required this.fromAccountId,
    required this.oldId,
    required this.toAccountId,
    required this.newId,
    required this.data,
  });
}

class AlignmentPlan {
  final List<AlignOp> ops;
  final List<RecapOp> recapOps;
  final int checked; // jumlah dokumen laporan yang dibaca
  final int relabel; // label kelas/halaqoh/nama/id yang diperbarui (tanpa pindah akun)
  final int move; // dipindah ke akun guru yang sekarang memegang halaqoh
  final int duplicates; // salinan dobel yang dibersihkan
  final int noGuru; // halaqoh tanpa guru: label diperbarui, akun tidak dipindah
  final int unmatched; // tidak cocok siswa mana pun di master: dilewati
  const AlignmentPlan({
    required this.ops,
    this.recapOps = const [],
    required this.checked,
    required this.relabel,
    required this.move,
    required this.duplicates,
    required this.noGuru,
    required this.unmatched,
  });

  bool get isEmpty => ops.isEmpty && recapOps.isEmpty;
}

/// Alat admin: menyelaraskan SEMUA laporan di cloud dengan data master siswa dan penugasan guru.
///
/// - Label `kelas`/`halaqoh`/`namaAnak` + `kelasHalaqoh` + `studentId` ditulis ulang mengikuti
///   master (jadi bisa disortir/difilter di Firestore dan cocok dengan aturan Portal Orang Tua).
/// - Laporan dipindah ke akun guru yang sekarang memegang halaqoh siswa itu (serah terima), dan
///   folderId dikosongkan karena folder milik akun lama. Halaqoh tanpa guru: tidak dipindah.
/// - Salinan dobel (id sama di beberapa akun) dibersihkan.
/// Hanya dokumen yang benar-benar berubah yang ditulis. Pembacaan: 1 read per dokumen laporan.
class RecordAlignmentService {
  RecordAlignmentService._();
  static final RecordAlignmentService instance = RecordAlignmentService._();

  CollectionReference<Map<String, dynamic>> get _accounts =>
      FirebaseFirestore.instance.collection('schools').doc(kSchoolId).collection('accounts');

  /// Akun tujuan untuk [student]. Utamakan `student.guruAccountId` (itu yang dibaca Portal Ortu)
  /// selama akun itu masih memegang halaqoh-nya; kalau tidak, guru pembimbing diutamakan dan
  /// admin jadi cadangan.
  String? _guruFor(List<UserAccount> accounts, Student student) {
    final target = KelasHalaqoh(kelas: student.kelas, halaqoh: normalizeHalaqoh(student.halaqoh));
    final preferred = student.guruAccountId;
    if (preferred != null) {
      for (final a in accounts) {
        if (a.id == preferred && a.assignments.contains(target)) return a.id;
      }
    }
    String? fallback;
    for (final a in accounts) {
      if (!a.assignments.contains(target)) continue;
      if (!a.isAdmin && !a.isPengawas) return a.id;
      fallback ??= a.id;
    }
    return fallback;
  }

  DateTime _timeOf(Map<String, dynamic> d) =>
      DateTime.tryParse((d['editedAt'] ?? d['createdAt'] ?? d['tanggal'] ?? '') as String) ??
      DateTime.fromMillisecondsSinceEpoch(0);

  /// Hitung rencana perubahan (belum menulis apa pun).
  Future<AlignmentPlan> plan({
    required List<Student> students,
    required List<UserAccount> accounts,
  }) async {
    final byId = {for (final s in students) s.id: s};
    final nameCount = <String, int>{};
    for (final s in students) {
      final k = s.nama.trim().toLowerCase();
      nameCount[k] = (nameCount[k] ?? 0) + 1;
    }
    final uniqueByName = {
      for (final s in students)
        if (nameCount[s.nama.trim().toLowerCase()] == 1) s.nama.trim().toLowerCase(): s,
    };

    // Baca semua laporan di semua akun (1 query per akun).
    final snaps = await Future.wait([
      for (final a in accounts)
        _accounts.doc(a.id).collection('laporan').get().timeout(const Duration(seconds: 90)),
    ]);
    final copies = <String, List<({String accountId, Map<String, dynamic> data})>>{};
    var checked = 0;
    for (var i = 0; i < accounts.length; i++) {
      for (final doc in snaps[i].docs) {
        checked++;
        final data = doc.data();
        final id = (data['id'] as String?) ?? doc.id;
        copies.putIfAbsent(id, () => []).add((accountId: accounts[i].id, data: data));
      }
    }

    final ops = <AlignOp>[];
    var relabel = 0, move = 0, duplicates = 0, noGuru = 0, unmatched = 0;

    for (final entry in copies.entries) {
      // Versi terbaru yang jadi acuan isi; kalau seri, pilih yang sudah ada di akun tujuan nanti.
      final list = [...entry.value]..sort((a, b) => _timeOf(b.data).compareTo(_timeOf(a.data)));
      final newest = list.first;
      final data = newest.data;

      final sid = data['studentId'] as String?;
      final nameKey = ((data['namaAnak'] as String?) ?? '').trim().toLowerCase();
      final student = (sid != null ? byId[sid] : null) ?? uniqueByName[nameKey];
      if (student == null) {
        unmatched++;
        continue;
      }

      final guruId = _guruFor(accounts, student);
      if (guruId == null) noGuru++;
      // Tanpa guru: tetap di akun yang sekarang (pilih akun salinan terbaru).
      final targetAccount = guruId ?? newest.accountId;

      final labelChanged = data['kelas'] != student.kelas ||
          data['halaqoh'] != student.halaqoh ||
          data['namaAnak'] != student.nama ||
          data['studentId'] != student.id ||
          data['kelasHalaqoh'] != buildKelasHalaqohKey(student.kelas, student.halaqoh);
      final others = [
        for (final c in list)
          if (c.accountId != targetAccount) c.accountId,
      ];
      final hasTargetCopy = list.any((c) => c.accountId == targetAccount);
      final needsMove = !hasTargetCopy;

      if (!labelChanged && !needsMove && others.isEmpty) continue;

      final newData = <String, dynamic>{
        ...data,
        'kelas': student.kelas,
        'halaqoh': student.halaqoh,
        'namaAnak': student.nama,
        'studentId': student.id,
        'kelasHalaqoh': buildKelasHalaqohKey(student.kelas, student.halaqoh),
      };
      newData.remove('syncedAt');
      // Folder milik akun lama tidak terlihat oleh guru baru -> kosongkan saat pindah akun.
      if (needsMove) newData['folderId'] = null;

      if (needsMove) {
        move++;
      } else if (labelChanged) {
        relabel++;
      }
      if (others.isNotEmpty && !needsMove) duplicates += others.length;

      ops.add(AlignOp(
        fromAccountId: newest.accountId,
        toAccountId: targetAccount,
        recordId: entry.key,
        data: newData,
        deleteFromAccountIds: others,
      ));
    }

    final recapOps = await _planRecaps(accounts, students, uniqueByName);

    return AlignmentPlan(
      ops: ops,
      recapOps: recapOps,
      checked: checked,
      relabel: relabel,
      move: move,
      duplicates: duplicates,
      noGuru: noGuru,
      unmatched: unmatched,
    );
  }

  /// Tulis rencana ke Firestore (batch <= 400 operasi). Mengembalikan jumlah laporan yang diubah.
  /// `syncedAt` diisi jam server supaya pemulihan hemat di HP guru ikut menarik perubahan ini.
  Future<int> apply(AlignmentPlan plan) async {
    const maxWrites = 400;
    var batch = FirebaseFirestore.instance.batch();
    var count = 0;
    var written = 0;

    Future<void> flush() async {
      if (count == 0) return;
      await batch.commit().timeout(const Duration(seconds: 60));
      batch = FirebaseFirestore.instance.batch();
      count = 0;
    }

    for (final op in plan.ops) {
      final needed = 1 + op.deleteFromAccountIds.length;
      if (count + needed > maxWrites) await flush();
      final target = _accounts.doc(op.toAccountId).collection('laporan').doc(op.recordId);
      batch.set(target, {...op.data, 'syncedAt': FieldValue.serverTimestamp()});
      count++;
      for (final acc in op.deleteFromAccountIds) {
        batch.delete(_accounts.doc(acc).collection('laporan').doc(op.recordId));
        count++;
      }
      written++;
    }
    for (final op in plan.recapOps) {
      final needed = op.data == null ? 1 : 2;
      if (count + needed > maxWrites) await flush();
      CollectionReference<Map<String, dynamic>> col(String acc) =>
          _accounts.doc(acc).collection('weeklyRecaps');
      final data = op.data;
      if (data != null) {
        batch.set(col(op.toAccountId).doc(op.newId), data);
        count++;
      }
      final inPlace = op.fromAccountId == op.toAccountId && op.oldId == op.newId;
      if (!inPlace) {
        batch.delete(col(op.fromAccountId).doc(op.oldId));
        count++;
      }
      written++;
    }
    await flush();
    return written;
  }

  String _slug(String raw) => raw
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  /// Rekap pekanan: kelas/halaqoh disamakan dengan master dan dipindah ke akun guru tujuan,
  /// dengan id dokumen mengikuti format deploy ([WeeklyRecapDeployService]) supaya "Deploy"
  /// ulang menimpa dokumen ini, bukan menggandakan. Kalau dokumen tujuan sudah ada, yang lama
  /// cukup dihapus.
  Future<List<RecapOp>> _planRecaps(
    List<UserAccount> accounts,
    List<Student> students,
    Map<String, Student> uniqueByName,
  ) async {
    final snaps = await Future.wait([
      for (final a in accounts)
        _accounts.doc(a.id).collection('weeklyRecaps').get().timeout(const Duration(seconds: 90)),
    ]);
    final existing = <String>{
      for (var i = 0; i < accounts.length; i++)
        for (final d in snaps[i].docs) '${accounts[i].id}/${d.id}',
    };
    final ops = <RecapOp>[];
    final claimed = <String>{};
    for (var i = 0; i < accounts.length; i++) {
      for (final doc in snaps[i].docs) {
        final data = doc.data();
        final key = ((data['namaAnakLower'] as String?) ?? (data['namaAnak'] as String?) ?? '')
            .trim()
            .toLowerCase();
        final student = uniqueByName[key];
        if (student == null) continue;
        final target = _guruFor(accounts, student) ?? accounts[i].id;
        final labelOk = data['kelas'] == student.kelas && data['halaqoh'] == student.halaqoh;
        if (labelOk && target == accounts[i].id) continue;

        final newId = '${_slug(student.kelas)}_${_slug(student.halaqoh)}_w${data['weekIndex']}_'
            '${_slug((data['bulanLabel'] as String?) ?? '')}_${_slug((data['namaAnak'] as String?) ?? student.nama)}';
        final targetKey = '$target/$newId';
        final sameDoc = target == accounts[i].id && newId == doc.id;
        final writeNew = !sameDoc && !existing.contains(targetKey) && claimed.add(targetKey);
        final newData = {
          ...data,
          'kelas': student.kelas,
          'halaqoh': student.halaqoh,
          'namaAnak': student.nama,
          'namaAnakLower': student.nama.trim().toLowerCase(),
        };
        if (sameDoc) {
          ops.add(RecapOp(
            fromAccountId: accounts[i].id,
            oldId: doc.id,
            toAccountId: target,
            newId: newId,
            data: newData,
          ));
          continue;
        }
        ops.add(RecapOp(
          fromAccountId: accounts[i].id,
          oldId: doc.id,
          toAccountId: target,
          newId: newId,
          data: writeNew ? newData : null,
        ));
      }
    }
    return ops;
  }
}
