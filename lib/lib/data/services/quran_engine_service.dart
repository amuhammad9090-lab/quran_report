import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Satu baris mushaf hasil generate, siap ditampilkan di kolom "Baris".
class GeneratedLine {
  final int pageNumber;
  final int lineNumber;
  final String lineId;
  final String ayatRangeText;
  final bool alreadyCounted;

  GeneratedLine({
    required this.pageNumber,
    required this.lineNumber,
    required this.lineId,
    required this.ayatRangeText,
    this.alreadyCounted = false,
  });
}

/// Hasil generate: baris baru (yang dihitung ke laporan ini) dan info
/// baris yang sudah pernah dihitung di laporan sebelumnya untuk santri
/// yang sama (dikecualikan biar tidak dobel hitung).
class GeneratedLinesResult {
  final List<GeneratedLine> newLines;
  final List<GeneratedLine> alreadyCountedLines;
  final bool available;

  GeneratedLinesResult({
    required this.newLines,
    required this.alreadyCountedLines,
    required this.available,
  });

  int get totalBaris => newLines.length;
  int get totalPhysicalLines => newLines.length + alreadyCountedLines.length;
  List<String> get newLineIds => newLines.map((e) => e.lineId).toList();

  static final empty =
      GeneratedLinesResult(newLines: [], alreadyCountedLines: [], available: false);
}

/// Representasi internal satu baris mushaf, dinormalisasi dari kedua
/// skema dataset (legacy `segments` maupun baru `ayats` + continuation).
class _AyatMark {
  final int surah;
  final int ayah;
  final int endMarker; // 0 = nyambung ke baris berikutnya; == ayah => selesai di baris ini
  const _AyatMark(this.surah, this.ayah, this.endMarker);
}

class _NormalizedLine {
  final int pageNumber;
  final int lineNumber;
  final String lineId;
  final List<_AyatMark> ayats;
  const _NormalizedLine({
    required this.pageNumber,
    required this.lineNumber,
    required this.lineId,
    required this.ayats,
  });
}

const Map<int, String> kSurahNames = {
  1: "Al-Fatihah", 2: "Al-Baqarah", 3: "Ali 'Imran", 4: "An-Nisa",
  5: "Al-Ma'idah", 6: "Al-An'am", 7: "Al-A'raf", 8: "Al-Anfal",
  9: "At-Taubah", 10: "Yunus", 11: "Hud", 12: "Yusuf", 13: "Ar-Ra'd",
  14: "Ibrahim", 15: "Al-Hijr", 16: "An-Nahl", 17: "Al-Isra", 18: "Al-Kahf",
  19: "Maryam", 20: "Taha", 21: "Al-Anbiya", 22: "Al-Hajj", 23: "Al-Mu'minun",
  24: "An-Nur", 25: "Al-Furqan", 26: "Ash-Shu'ara", 27: "An-Naml",
  28: "Al-Qasas", 29: "Al-'Ankabut", 30: "Ar-Rum", 31: "Luqman",
  32: "As-Sajdah", 33: "Al-Ahzab", 34: "Saba", 35: "Fatir", 36: "Ya-Sin",
  37: "As-Saffat", 38: "Sad", 39: "Az-Zumar", 40: "Ghafir", 41: "Fussilat",
  42: "Ash-Shura", 43: "Az-Zukhruf", 44: "Ad-Dukhan", 45: "Al-Jathiyah",
  46: "Al-Ahqaf", 47: "Muhammad", 48: "Al-Fath", 49: "Al-Hujurat",
  50: "Qaf", 51: "Adh-Dhariyat", 52: "At-Tur", 53: "An-Najm", 54: "Al-Qamar",
  55: "Ar-Rahman", 56: "Al-Waqi'ah", 57: "Al-Hadid", 58: "Al-Mujadilah",
  59: "Al-Hashr", 60: "Al-Mumtahanah", 61: "As-Saff", 62: "Al-Jumu'ah",
  63: "Al-Munafiqun", 64: "At-Taghabun", 65: "At-Talaq", 66: "At-Tahrim",
  67: "Al-Mulk", 68: "Al-Qalam", 69: "Al-Haqqah", 70: "Al-Ma'arij",
  71: "Nuh", 72: "Al-Jinn", 73: "Al-Muzzammil", 74: "Al-Muddaththir",
  75: "Al-Qiyamah", 76: "Al-Insan", 77: "Al-Mursalat", 78: "An-Naba",
  79: "An-Nazi'at", 80: "'Abasa", 81: "At-Takwir", 82: "Al-Infitar",
  83: "Al-Mutaffifin", 84: "Al-Inshiqaq", 85: "Al-Buruj", 86: "At-Tariq",
  87: "Al-A'la", 88: "Al-Ghashiyah", 89: "Al-Fajr", 90: "Al-Balad",
  91: "Ash-Shams", 92: "Al-Layl", 93: "Ad-Duha", 94: "Ash-Sharh",
  95: "At-Tin", 96: "Al-'Alaq", 97: "Al-Qadr", 98: "Al-Bayyinah",
  99: "Az-Zalzalah", 100: "Al-'Adiyat", 101: "Al-Qari'ah",
  102: "At-Takathur", 103: "Al-'Asr", 104: "Al-Humazah", 105: "Al-Fil",
  106: "Quraysh", 107: "Al-Ma'un", 108: "Al-Kawthar", 109: "Al-Kafirun",
  110: "An-Nasr", 111: "Al-Masad", 112: "Al-Ikhlas", 113: "Al-Falaq",
  114: "An-Nas",
};

/// Engine baris mushaf — mendukung dua skema dataset sekaligus:
///
/// 1. **Legacy** (`{"metadata": {...}, "pages": [...]}`) — tiap baris
///    punya `segments` berisi `ayah_start`/`ayah_end`. Tidak ada info
///    continuation, jadi aturan boundary-exclusion tidak pernah trigger
///    untuk baris dari dataset ini (perilaku identik dengan engine lama).
/// 2. **Baru** (`{"juzs": {"26": {...}, ...}}`) — tiap baris punya
///    `ayats: [[surah, ayat, ayat_akhir_atau_0]]`. Angka `0` di posisi
///    ketiga berarti ayat itu masih nyambung ke baris berikutnya.
///    Aturan boundary-exclusion mengikuti persis logic
///    `get_lines_for_range()` di quran_line_ui_juz26_30_COMBINED.py.
class QuranEngineService {
  QuranEngineService._();
  static final QuranEngineService instance = QuranEngineService._();

  final List<_NormalizedLine> _lines = [];
  final Set<int> _coveredSurahs = {};
  List<int> juzAvailable = [];
  List<int> juzMissing = [];
  bool _loaded = false;

  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;

    await _loadLegacy('assets/data/quran_line_dataset_legacy_juz1_10.json');
    await _loadNewSchema('assets/data/quran_line_dataset_juz26_30.json');

    // Urutkan ulang berdasarkan nomor halaman & baris supaya urutan mushaf
    // tetap benar walau berasal dari 2 file berbeda (penting untuk aturan
    // "baris pertama" pada boundary rule).
    _lines.sort((a, b) {
      final p = a.pageNumber.compareTo(b.pageNumber);
      if (p != 0) return p;
      return a.lineNumber.compareTo(b.lineNumber);
    });

    juzAvailable = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 26, 27, 28, 29, 30];
    juzMissing = List.generate(15, (i) => i + 11); // 11..25

    _loaded = true;
  }

  Future<void> _loadLegacy(String path) async {
    try {
      final raw = await rootBundle.loadString(path);
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final pages = data['pages'] as List<dynamic>;

      for (final page in pages) {
        final pageNumber = page['page_number'] as int;
        for (final line in (page['lines'] as List)) {
          final marks = <_AyatMark>[];
          for (final seg in (line['segments'] as List)) {
            final surah = seg['surah_number'] as int;
            final start = seg['ayah_start'] as int;
            final end = seg['ayah_end'] as int;
            _coveredSurahs.add(surah);
            // Skema lama tidak punya info continuation → setiap ayat pada
            // baris ini dianggap "selesai di baris ini" (endMarker == ayah),
            // sehingga boundary-exclusion rule tidak pernah aktif untuk
            // baris dari dataset legacy (identik dengan behavior lama).
            for (var a = start; a <= end; a++) {
              marks.add(_AyatMark(surah, a, a));
            }
          }
          _lines.add(_NormalizedLine(
            pageNumber: pageNumber,
            lineNumber: line['line_number'] as int,
            lineId: line['line_id'] as String,
            ayats: marks,
          ));
        }
      }
    } catch (_) {
      // File belum ada / gagal load — abaikan, cakupan surah terkait
      // otomatis dianggap tidak tersedia.
    }
  }

  Future<void> _loadNewSchema(String path) async {
    try {
      final raw = await rootBundle.loadString(path);
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final juzs = data['juzs'] as Map<String, dynamic>;

      for (final entry in juzs.entries) {
        final juzData = entry.value as Map<String, dynamic>;
        final pages = juzData['pages'] as List<dynamic>;

        for (final page in pages) {
          final pageNumber = page['page_number'] as int;
          for (final line in (page['lines'] as List)) {
            final marks = <_AyatMark>[];
            for (final triplet in (line['ayats'] as List? ?? [])) {
              final t = triplet as List;
              final surah = t[0] as int;
              final ayah = t[1] as int;
              final endMarker = t[2] as int;
              _coveredSurahs.add(surah);
              marks.add(_AyatMark(surah, ayah, endMarker));
            }
            _lines.add(_NormalizedLine(
              pageNumber: pageNumber,
              lineNumber: line['line_number'] as int,
              lineId: line['line_id'] as String,
              ayats: marks,
            ));
          }
        }
      }
    } catch (_) {
      // ignore
    }
  }

  bool isSurahCovered(int surahNumber) => _coveredSurahs.contains(surahNumber);

  /// Generate baris setoran untuk surah [surah], ayat [start] s.d [end],
  /// mengikuti persis logic `get_lines_for_range()`:
  /// - satu baris fisik cuma dihitung sekali;
  /// - baris multi-ayat tetap 1 baris;
  /// - ayat yang melintasi beberapa baris, semua baris terpakainya ikut;
  /// - baris pertama dikecualikan kalau itu masih ekor ayat sebelumnya
  ///   DAN ayat awal yang diminta nyambung terus dari baris itu;
  /// - [excludeLineIds] = baris yang sudah pernah dihitung di laporan
  ///   sebelumnya untuk santri yang sama (dikecualikan dari total baru,
  ///   tapi tetap ditampilkan sebagai info "sudah dihitung").
  GeneratedLinesResult generateLines({
    required int surah,
    required int start,
    required int end,
    Set<String> excludeLineIds = const {},
  }) {
    if (!_loaded) return GeneratedLinesResult.empty;

    final candidates = <_NormalizedLine>[];
    final seen = <String>{};

    for (final line in _lines) {
      if (seen.contains(line.lineId)) continue;
      final hasRequestedText =
          line.ayats.any((m) => m.surah == surah && m.ayah >= start && m.ayah <= end);
      if (hasRequestedText) {
        seen.add(line.lineId);
        candidates.add(line);
      }
    }

    if (candidates.isEmpty) {
      return GeneratedLinesResult(newLines: [], alreadyCountedLines: [], available: false);
    }

    // --- Boundary continuation rule (persis seperti Python) ---
    final first = candidates.first;
    final hasPreviousAyah =
        first.ayats.any((m) => m.surah == surah && m.ayah < start);
    final startMarkers =
        first.ayats.where((m) => m.surah == surah && m.ayah == start).toList();
    final startContinues = startMarkers.any((m) => m.endMarker == 0);

    var finalCandidates = candidates;
    if (hasPreviousAyah && startMarkers.isNotEmpty && startContinues) {
      finalCandidates = candidates.sublist(1);
    }

    final newLines = <GeneratedLine>[];
    final alreadyCounted = <GeneratedLine>[];

    for (final line in finalCandidates) {
      final rangeAyats = line.ayats
          .where((m) => m.surah == surah && m.ayah >= start && m.ayah <= end)
          .map((m) => m.ayah)
          .toSet()
          .toList()
        ..sort();
      final ayatText = rangeAyats.isEmpty
          ? '-'
          : (rangeAyats.length == 1 ? 'Ayat ${rangeAyats.first}' : 'Ayat ${rangeAyats.join(', ')}');

      final gLine = GeneratedLine(
        pageNumber: line.pageNumber,
        lineNumber: line.lineNumber,
        lineId: line.lineId,
        ayatRangeText: ayatText,
        alreadyCounted: excludeLineIds.contains(line.lineId),
      );

      if (excludeLineIds.contains(line.lineId)) {
        alreadyCounted.add(gLine);
      } else {
        newLines.add(gLine);
      }
    }

    return GeneratedLinesResult(
      newLines: newLines,
      alreadyCountedLines: alreadyCounted,
      available: finalCandidates.isNotEmpty,
    );
  }

  String coverageText() => 'Dataset aktif: Juz ${juzAvailable.join(", ")}';

  String missingText() =>
      juzMissing.isEmpty ? 'Seluruh 30 juz tersedia.' : 'Belum tersedia: Juz ${juzMissing.join(", ")}';
}
