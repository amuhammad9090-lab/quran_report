import 'package:uuid/uuid.dart';

import '../../../data/models/enums.dart';
import '../../../data/models/santri_record.dart';
import '../../widgets/record/segment_states.dart';

/// Merakit [SantriRecord] dari isian form yang SUDAH tervalidasi. Murni (tanpa setState/context):
/// [RecordFormSheet._submit] yang bertugas validasi lalu memanggil ini.
///
/// [isiStatusCapaian] = false (mis. izin/sakit, atau "Hadir tanpa capaian") mengosongkan semua
/// field capaian. totalBaris/lineIds tetap AGREGAT semua segmen Tahfizh agar konsumen lama
/// (statistik/rekap) benar; field singular (surahNumber, dst) diisi dari segmen PERTAMA untuk
/// backward compat.
SantriRecord buildRecordFromForm({
  required SantriRecord? existing,
  required String? initialFolderId,
  required String? ownerId,
  required DateTime tanggal,
  required String kelas,
  required String halaqoh,
  required String nama,
  required HafalanStatus status,
  required Keterangan keterangan,
  required bool isiStatusCapaian,
  required List<TahfizhSegState> tahfizhSegs,
  required TahsinMode tahsinMode,
  required WafaLevel? wafaLevel,
  required String halamanWafa,
  required List<TilawahSegState> tilawahSegs,
  required String catatan,
  required String nilai,
}) {
  final isTahfizhPart =
      isiStatusCapaian && (status == HafalanStatus.tahfizh || status == HafalanStatus.tahsinTahfizh);
  final isTahsinPart =
      isiStatusCapaian && (status == HafalanStatus.tahsin || status == HafalanStatus.tahsinTahfizh);
  final isTahsinWafa = isTahsinPart && tahsinMode == TahsinMode.wafa;
  final isTahsinTilawah = isTahsinPart && tahsinMode == TahsinMode.tilawah;
  final isMurojaah = isiStatusCapaian && status == HafalanStatus.murojaahTasmi;
  // Field "tilawah" (surah+ayat, tanpa generate) dipakai bareng oleh Tahsin-mode-Tilawah DAN
  // Muroja'ah/Tasmi'.
  final isTilawahShaped = isTahsinTilawah || isMurojaah;

  final tahfizhSegments = isTahfizhPart ? tahfizhSegs.map((s) => s.toSegment()).toList() : null;
  final tilawahSegments = isTilawahShaped
      ? tilawahSegs.where((s) => s.isFilled).map((s) => s.toSegment()).toList()
      : null;
  final tilawahFirst = tilawahSegments?.isNotEmpty == true ? tilawahSegments!.first : null;

  final isEdit = existing != null;
  return SantriRecord(
    id: existing?.id ?? const Uuid().v4(),
    tanggal: tanggal,
    createdAt: existing?.createdAt ?? DateTime.now(),
    // Diedit = laporan yang sudah ada dan barusan disimpan ulang -> catat waktunya sekarang
    // buat badge "Diedit" di kartu. Laporan baru (bukan edit): tetap null.
    editedAt: isEdit ? DateTime.now() : null,
    kelas: kelas.trim(),
    halaqoh: halaqoh.trim(),
    namaAnak: nama.trim(),
    status: status,
    keterangan: keterangan,
    surahNumber: tahfizhSegments?.first.surahNumber,
    surahName: tahfizhSegments?.first.surahName,
    ayatMulai: tahfizhSegments?.first.ayatMulai,
    ayatSelesai: tahfizhSegments?.first.ayatSelesai,
    totalBaris: tahfizhSegments?.fold<int>(0, (a, s) => a + s.totalBaris),
    lineIds: tahfizhSegments?.expand((s) => s.lineIds).toSet().toList(),
    tahfizhSegments: tahfizhSegments,
    tahsinMode: isTahsinPart ? tahsinMode : null,
    wafaLevel: isTahsinWafa ? wafaLevel : null,
    halamanWafa: isTahsinWafa ? halamanWafa.trim() : null,
    tilawahSurahNumber: tilawahFirst?.surahNumber,
    tilawahSurahName: tilawahFirst?.surahName,
    tilawahAyatMulai: tilawahFirst?.ayatMulai,
    tilawahAyatSelesai: tilawahFirst?.ayatSelesai,
    tilawahSegments: tilawahSegments,
    catatan: catatan.trim().isEmpty ? null : catatan.trim(),
    nilai: nilai.trim().isEmpty ? null : nilai.trim(),
    folderId: existing?.folderId ?? initialFolderId,
    // Dicatat untuk audit "siapa yang input laporan ini". Laporan lama yang diedit tetap memakai
    // ownerId aslinya agar jejak pembuat PERTAMA tidak tertimpa.
    ownerId: existing?.ownerId ?? ownerId,
  );
}
