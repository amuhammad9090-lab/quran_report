import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../data/models/santri_record.dart';
import '../../../data/services/quran_engine_service.dart';
import '../../../providers/records_provider.dart';
import '../../widgets/record/segment_states.dart';

/// Konfirmasi lalu hapus laporan [existing]; menutup sheet bila dihapus. [nama] = nama santri yang
/// sedang terpilih di form (jatuh ke nama laporan bila null).
Future<void> confirmDeleteRecord(BuildContext context, SantriRecord existing, String? nama) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Hapus laporan ini?'),
      content: Text(
        'Laporan ${nama ?? existing.namaAnak} tanggal '
        '${DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(existing.tanggal)} '
        'akan dihapus permanen dan tidak bisa dikembalikan.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
          child: const Text('Hapus'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  await context.read<RecordsProvider>().delete(existing.id);
  if (context.mounted) Navigator.of(context).pop();
}

/// Validasi nama + rentang ayat semua segmen Tahfizh sebelum generate baris. Hasil: [ranges]
/// (surah, mulai, selesai per segmen) bila valid, selain itu [error] berisi pesan untuk guru.
({List<(int surah, int start, int end)>? ranges, String? error}) validateTahfizhRanges(
  String? nama,
  List<TahfizhSegState> segs,
) {
  if (nama == null || nama.trim().isEmpty) {
    return (ranges: null, error: 'Pilih nama siswa dulu.');
  }
  final ranges = <(int surah, int start, int end)>[];
  for (final seg in segs) {
    if (seg.surahNumber == null ||
        seg.ayatMulaiCtrl.text.trim().isEmpty ||
        seg.ayatSelesaiCtrl.text.trim().isEmpty) {
      return (ranges: null, error: 'Pilih surah dan isi rentang ayat dulu (semua segmen).');
    }
    final start = int.tryParse(seg.ayatMulaiCtrl.text.trim());
    final end = int.tryParse(seg.ayatSelesaiCtrl.text.trim());
    if (start == null || end == null || start < 1 || end < start) {
      return (ranges: null, error: 'Rentang ayat tidak valid.');
    }
    ranges.add((seg.surahNumber!, start, end));
  }
  return (ranges: ranges, error: null);
}

/// Generate baris untuk SEMUA segmen Tahfizh (1 surah per panggilan [QuranEngineService.generateLines])
/// lalu isi `segs[i].generated`. Baris dari segmen sebelumnya (dan [history]) ikut di-exclude di
/// segmen berikutnya (jaga-jaga overlap di batas transisi surah). Mengembalikan true bila ada
/// surah yang datanya belum tersedia.
bool generateTahfizhLines(
  List<TahfizhSegState> segs,
  List<(int surah, int start, int end)> ranges,
  Set<String> history,
) {
  final excludeSoFar = {...history};
  var anyUnavailable = false;
  for (var i = 0; i < ranges.length; i++) {
    final (surah, start, end) = ranges[i];
    final result = QuranEngineService.instance.generateLines(
      surah: surah,
      start: start,
      end: end,
      excludeLineIds: excludeSoFar,
    );
    segs[i].generated = result;
    excludeSoFar.addAll(result.newLineIds);
    if (!result.available) anyUnavailable = true;
  }
  return anyUnavailable;
}
