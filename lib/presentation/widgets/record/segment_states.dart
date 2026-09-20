import 'package:flutter/material.dart';

import '../../../data/models/santri_record.dart';
import '../../../data/services/quran_engine_service.dart';

/// State 1 segmen Tahfizh di form (surah + rentang ayat + hasil generate barisnya sendiri);
/// form bisa punya >1 segmen kalau setoran nyambung lintas surah dalam 1 pertemuan.
class TahfizhSegState {
  int? surahNumber;
  final TextEditingController ayatMulaiCtrl = TextEditingController();
  final TextEditingController ayatSelesaiCtrl = TextEditingController();
  GeneratedLinesResult? generated;

  // Fallback manual untuk juz yang belum ada di dataset baris (kini Juz 1-10 & 26-30). Dipakai
  // HANYA kalau generate balik `available: false`; lineIds otomatis kosong, jadi tidak ikut
  // logic exclude-baris-yang-sudah-dihitung.
  final TextEditingController manualBarisCtrl = TextEditingController();

  /// Generate sudah jalan tapi dataset belum meng-cover surah ini (jumlah baris diisi manual).
  bool get datasetUnavailable => generated != null && !generated!.available;

  /// Siap disimpan: generate sukses dari dataset, ATAU dataset belum cover surah itu tapi jumlah
  /// baris manual sudah diisi.
  bool get isReady {
    if (surahNumber == null || generated == null) return false;
    if (generated!.available) return true;
    final manual = int.tryParse(manualBarisCtrl.text.trim());
    return manual != null && manual > 0;
  }

  /// Segmen yang disimpan ke laporan. Fallback manual: baris dari input manual dan lineIds
  /// sengaja kosong (tak ada mapping baris fisik untuk di-exclude di laporan berikutnya).
  TahfizhSegment toSegment() {
    final useManual = generated == null || !generated!.available;
    final manualBaris = useManual ? (int.tryParse(manualBarisCtrl.text.trim()) ?? 0) : 0;
    return TahfizhSegment(
      surahNumber: surahNumber!,
      surahName: kSurahNames[surahNumber!]!,
      ayatMulai: int.parse(ayatMulaiCtrl.text.trim()),
      ayatSelesai: int.parse(ayatSelesaiCtrl.text.trim()),
      totalBaris: useManual ? manualBaris : (generated?.totalBaris ?? 0),
      lineIds: useManual ? const [] : (generated?.newLineIds ?? const []),
    );
  }

  void dispose() {
    ayatMulaiCtrl.dispose();
    ayatSelesaiCtrl.dispose();
    manualBarisCtrl.dispose();
  }
}

/// State 1 segmen "bentuk Tilawah" (surah + rentang ayat, tanpa generate
/// baris) — dipakai Tahsin-mode-Tilawah & Muroja'ah/Tasmi'.
class TilawahSegState {
  int? surahNumber;
  final TextEditingController ayatMulaiCtrl = TextEditingController();
  final TextEditingController ayatSelesaiCtrl = TextEditingController();

  /// Segmen terisi lengkap (surah + kedua ayat); yang belum terisi dilewati saat menyimpan.
  bool get isFilled =>
      surahNumber != null &&
      ayatMulaiCtrl.text.trim().isNotEmpty &&
      ayatSelesaiCtrl.text.trim().isNotEmpty;

  TilawahSegment toSegment() => TilawahSegment(
        surahNumber: surahNumber!,
        surahName: kSurahNames[surahNumber!]!,
        ayatMulai: int.tryParse(ayatMulaiCtrl.text.trim()) ?? 0,
        ayatSelesai: int.tryParse(ayatSelesaiCtrl.text.trim()) ?? 0,
      );

  void dispose() {
    ayatMulaiCtrl.dispose();
    ayatSelesaiCtrl.dispose();
  }
}
