import '../models/santri_record.dart';
import '../models/student.dart';

/// Menyamakan kelas/halaqoh/nama pada laporan dengan data master siswa. Dengan begitu perubahan di
/// master (ganti nama halaqoh, pindah siswa lewat Import Excel) langsung tercermin di kartu, rekap,
/// ekspor, filter, dan akses guru TANPA menulis ulang laporan lama. Murni in-memory.
///
/// Prioritas pencocokan: `studentId` di laporan; cadangan: nama yang unik di master (nama kembar
/// dilewati supaya tidak salah pasang).
class RecordIdentityResolver {
  Map<String, ({String kelas, String halaqoh})> _byName = {};
  Map<String, Student> _byId = {};
  Set<String> _matched = {};

  /// Laporan [recordId] berhasil dihubungkan ke siswa master pada [apply] terakhir.
  bool isMatched(String recordId) => _matched.contains(recordId);

  /// Perbarui direktori siswa. Mengembalikan true bila isinya berubah (cache turunan harus dihitung ulang).
  bool updateDirectory(Iterable<Student> students) {
    final byName = <String, List<Student>>{};
    for (final s in students) {
      byName.putIfAbsent(s.nama.trim().toLowerCase(), () => []).add(s);
    }
    final nextByName = <String, ({String kelas, String halaqoh})>{
      for (final e in byName.entries)
        if (e.value.length == 1) e.key: (kelas: e.value.first.kelas, halaqoh: e.value.first.halaqoh),
    };
    final nextById = {for (final s in students) s.id: s};

    var same = nextByName.length == _byName.length && nextById.length == _byId.length;
    if (same) {
      for (final e in nextByName.entries) {
        final old = _byName[e.key];
        if (old == null || old.kelas != e.value.kelas || old.halaqoh != e.value.halaqoh) {
          same = false;
          break;
        }
      }
    }
    if (same) {
      for (final e in nextById.entries) {
        final old = _byId[e.key];
        if (old == null ||
            old.kelas != e.value.kelas ||
            old.halaqoh != e.value.halaqoh ||
            old.nama != e.value.nama) {
          same = false;
          break;
        }
      }
    }
    if (same) return false;
    _byName = nextByName;
    _byId = nextById;
    return true;
  }

  /// [all] dengan identitas disamakan ke master. Laporan yang sudah sama dipakai apa adanya; yang
  /// beda diganti salinan; yang tak bisa dihubungkan dibiarkan.
  List<SantriRecord> apply(List<SantriRecord> all) {
    if (_byName.isEmpty && _byId.isEmpty) {
      _matched = {};
      return all;
    }
    final matched = <String>{};
    final out = <SantriRecord>[];
    for (final r in all) {
      final byId = r.studentId == null ? null : _byId[r.studentId];
      final byName = _byName[r.namaAnak.trim().toLowerCase()];
      final kelas = byId?.kelas ?? byName?.kelas;
      final halaqoh = byId?.halaqoh ?? byName?.halaqoh;
      if (kelas == null || halaqoh == null) {
        out.add(r);
        continue;
      }
      matched.add(r.id);
      final nama = byId?.nama;
      if (kelas == r.kelas && halaqoh == r.halaqoh && (nama == null || nama == r.namaAnak)) {
        out.add(r);
      } else {
        out.add(r.copyWith(kelas: kelas, halaqoh: halaqoh, namaAnak: nama));
      }
    }
    _matched = matched;
    return out;
  }
}
