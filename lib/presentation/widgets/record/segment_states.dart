import 'package:flutter/material.dart';

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

  void dispose() {
    ayatMulaiCtrl.dispose();
    ayatSelesaiCtrl.dispose();
  }
}
