import 'dart:convert';

import '../../../data/models/enums.dart';
import '../../../data/models/santri_record.dart';
import '../../widgets/record/segment_states.dart';

/// Serialisasi/deserialisasi murni untuk draf laporan baru dan prefill segmen saat edit.
/// State form tetap di [RecordFormSheet]; file ini hanya mengubah data <-> Map/segmen.

/// Snapshot isian form saat ini sebagai Map JSON-able (disimpan ke AppPrefsService).
Map<String, dynamic> recordDraftSnapshot({
  required DateTime tanggal,
  required String? kelas,
  required String? halaqoh,
  required String? nama,
  required HafalanStatus status,
  required Keterangan keterangan,
  required List<TahfizhSegState> tahfizhSegs,
  required TahsinMode tahsinMode,
  required WafaLevel? wafaLevel,
  required String halamanWafa,
  required List<TilawahSegState> tilawahSegs,
  required String catatan,
  required String nilai,
}) =>
    {
      'tanggal': tanggal.toIso8601String(),
      'kelas': kelas,
      'halaqoh': halaqoh,
      'nama': nama,
      'status': status.name,
      'keterangan': keterangan.name,
      'tahfizhSegs': tahfizhSegs
          .map((s) => {
                'surahNumber': s.surahNumber,
                'ayatMulai': s.ayatMulaiCtrl.text,
                'ayatSelesai': s.ayatSelesaiCtrl.text,
              })
          .toList(),
      'tahsinMode': tahsinMode.name,
      'wafaLevel': wafaLevel?.name,
      'halamanWafa': halamanWafa,
      'tilawahSegs': tilawahSegs
          .map((s) => {
                'surahNumber': s.surahNumber,
                'ayatMulai': s.ayatMulaiCtrl.text,
                'ayatSelesai': s.ayatSelesaiCtrl.text,
              })
          .toList(),
      'catatan': catatan,
      'nilai': nilai,
    };

/// Parse draf tersimpan; null bila kosong, korup, atau belum ada isian berarti
/// (kelas/halaqoh/nama/catatan semuanya kosong).
Map<String, dynamic>? parseRestorableDraft(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final looksNonEmpty = ((map['kelas'] as String?) ?? '').isNotEmpty ||
        ((map['halaqoh'] as String?) ?? '').isNotEmpty ||
        ((map['nama'] as String?) ?? '').isNotEmpty ||
        ((map['catatan'] as String?) ?? '').isNotEmpty;
    return looksNonEmpty ? map : null;
  } catch (_) {
    // Draf korup/format lama — abaikan, jangan bikin form crash.
    return null;
  }
}

/// Segmen Tahfizh dari draf; null bila tidak ada.
List<TahfizhSegState>? tahfizhSegsFromDraft(Object? raw) {
  if (raw is! List || raw.isEmpty) return null;
  return raw.map((r) {
    final m = r as Map<String, dynamic>;
    return TahfizhSegState()
      ..surahNumber = m['surahNumber'] as int?
      ..ayatMulaiCtrl.text = (m['ayatMulai'] as String?) ?? ''
      ..ayatSelesaiCtrl.text = (m['ayatSelesai'] as String?) ?? '';
  }).toList();
}

/// Segmen Tilawah dari draf; null bila tidak ada.
List<TilawahSegState>? tilawahSegsFromDraft(Object? raw) {
  if (raw is! List || raw.isEmpty) return null;
  return raw.map((r) {
    final m = r as Map<String, dynamic>;
    return TilawahSegState()
      ..surahNumber = m['surahNumber'] as int?
      ..ayatMulaiCtrl.text = (m['ayatMulai'] as String?) ?? ''
      ..ayatSelesaiCtrl.text = (m['ayatSelesai'] as String?) ?? '';
  }).toList();
}

/// Segmen Tahfizh dari laporan yang diedit; null bila laporan tak punya segmen.
List<TahfizhSegState>? tahfizhSegsFromRecord(SantriRecord e) {
  final segs = e.tahfizhSegmentsEffective;
  if (segs.isEmpty) return null;
  return segs
      .map((s) => TahfizhSegState()
        ..surahNumber = s.surahNumber
        ..ayatMulaiCtrl.text = s.ayatMulai.toString()
        ..ayatSelesaiCtrl.text = s.ayatSelesai.toString()
        // Segmen lama tanpa lineIds berarti dulu memakai fallback manual: prefill lagi supaya
        // user tak perlu mengetik ulang bila generate ulang gagal lagi.
        ..manualBarisCtrl.text = (s.lineIds.isEmpty && s.totalBaris > 0) ? s.totalBaris.toString() : '')
      .toList();
}

/// Segmen Tilawah dari laporan yang diedit; null bila laporan tak punya segmen.
List<TilawahSegState>? tilawahSegsFromRecord(SantriRecord e) {
  final segs = e.tilawahSegmentsEffective;
  if (segs.isEmpty) return null;
  return segs
      .map((s) => TilawahSegState()
        ..surahNumber = s.surahNumber
        ..ayatMulaiCtrl.text = s.ayatMulai.toString()
        ..ayatSelesaiCtrl.text = s.ayatSelesai.toString())
      .toList();
}
