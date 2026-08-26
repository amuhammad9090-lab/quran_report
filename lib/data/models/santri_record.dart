import '../../core/utils/text_utils.dart';
import 'enums.dart';

/// Satu segmen Tahfizh (hafalan baru): 1 surah + rentang ayat + hasil
/// generate barisnya sendiri. Laporan bisa punya LEBIH DARI SATU segmen
/// kalau santri setoran nyambung lintas surah dalam 1 pertemuan (mis.
/// abis akhir Al-Baqarah, lanjut awal Ali 'Imran).
class TahfizhSegment {
  final int surahNumber;
  final String surahName;
  final int ayatMulai;
  final int ayatSelesai;
  final int totalBaris; // baris baru hasil generate KHUSUS segmen ini
  final List<String> lineIds; // id baris fisik yang dihitung di segmen ini

  const TahfizhSegment({
    required this.surahNumber,
    required this.surahName,
    required this.ayatMulai,
    required this.ayatSelesai,
    required this.totalBaris,
    required this.lineIds,
  });

  String get partText => '$surahName • Ayat $ayatMulai–$ayatSelesai';

  Map<String, dynamic> toJson() => {
        'surahNumber': surahNumber,
        'surahName': surahName,
        'ayatMulai': ayatMulai,
        'ayatSelesai': ayatSelesai,
        'totalBaris': totalBaris,
        'lineIds': lineIds,
      };

  factory TahfizhSegment.fromJson(Map<String, dynamic> json) => TahfizhSegment(
        surahNumber: json['surahNumber'] as int,
        surahName: json['surahName'] as String,
        ayatMulai: json['ayatMulai'] as int,
        ayatSelesai: json['ayatSelesai'] as int,
        totalBaris: json['totalBaris'] as int? ?? 0,
        lineIds: (json['lineIds'] as List?)?.map((e) => e as String).toList() ?? const [],
      );
}

/// Satu segmen "bentuk Tilawah": surah + rentang ayat TANPA hitung baris.
/// Dipakai untuk Tahsin bermode Tilawah, bagian Tahsin di Tahsin+Tahfizh
/// (saat modenya Tilawah), dan Muroja'ah/Tasmi'. Bisa lebih dari satu
/// segmen dengan alasan yang sama seperti [TahfizhSegment].
class TilawahSegment {
  final int surahNumber;
  final String surahName;
  final int ayatMulai;
  final int ayatSelesai;

  const TilawahSegment({
    required this.surahNumber,
    required this.surahName,
    required this.ayatMulai,
    required this.ayatSelesai,
  });

  String get partText => '$surahName • Ayat $ayatMulai–$ayatSelesai';

  Map<String, dynamic> toJson() => {
        'surahNumber': surahNumber,
        'surahName': surahName,
        'ayatMulai': ayatMulai,
        'ayatSelesai': ayatSelesai,
      };

  factory TilawahSegment.fromJson(Map<String, dynamic> json) => TilawahSegment(
        surahNumber: json['surahNumber'] as int,
        surahName: json['surahName'] as String,
        ayatMulai: json['ayatMulai'] as int,
        ayatSelesai: json['ayatSelesai'] as int,
      );
}

/// Satu baris laporan capaian hafalan/tahsin seorang santri pada satu tanggal.
class SantriRecord {
  final String id;
  final DateTime tanggal;
  final DateTime? createdAt; // waktu laporan ini benar-benar diinput (buat jam di kartu)
  final String kelas; // contoh: "789"
  final String halaqoh; // contoh: "ABCD"
  final String namaAnak;
  final HafalanStatus status;
  final Keterangan keterangan;

  // --- Tahfizh fields ---
  // surahNumber/surahName/ayatMulai/ayatSelesai di bawah ini merepresentasikan
  // SEGMEN PERTAMA saja — dipertahankan buat backward compatibility (laporan
  // lama sebelum ada multi-surah, dan konsumen lama yang belum di-update).
  // Sumber kebenaran buat tampilan lengkap (bisa >1 surah) ada di
  // [tahfizhSegments] / getter [tahfizhSegmentsEffective] di bawah.
  final int? surahNumber;
  final String? surahName;
  final int? ayatMulai;
  final int? ayatSelesai;
  // totalBaris & lineIds SELALU agregat (jumlah/gabungan) dari SEMUA segmen
  // Tahfizh — bukan cuma segmen pertama — supaya statistik/rekap yang baca
  // 2 field ini apa adanya (tanpa tahu soal multi-surah) tetap benar.
  final int? totalBaris; // hasil generate dari engine (baris BARU, sudah dikurangi riwayat)
  final List<String>? lineIds; // id baris fisik yang dihitung di laporan ini
  // Daftar lengkap semua segmen Tahfizh (>= 1 elemen kalau status ada
  // bagian Tahfizh-nya). Null/kosong pada data lama -> lihat
  // [tahfizhSegmentsEffective] yang otomatis fallback ke field tunggal di atas.
  final List<TahfizhSegment>? tahfizhSegments;

  // --- Tahsin fields ---
  // Sub-mode Tahsin (WAFA atau Tilawah). Null = data lama sebelum ada
  // mode ini -> selalu dianggap WAFA (backward compatible).
  final TahsinMode? tahsinMode;
  final WafaLevel? wafaLevel;
  final String? halamanWafa; // halaman buku WAFA, string biar fleksibel (mis. "12-13")

  // --- Tilawah fields (dipakai saat Tahsin bermode Tilawah, saat status
  // Tahsin+Tahfizh bagian Tahsin-nya bermode Tilawah, ATAU saat status
  // Muroja'ah/Tasmi' — semuanya sama bentuknya: surah + rentang ayat,
  // TANPA hitung baris/generate. Field terpisah dari surahNumber/ayatMulai/
  // ayatSelesai di atas supaya Tahsin+Tahfizh bisa menyimpan KEDUANYA
  // sekaligus (bagian tilawah & bagian hafalan baru) tanpa bentrok.
  final int? tilawahSurahNumber;
  final String? tilawahSurahName;
  final int? tilawahAyatMulai;
  final int? tilawahAyatSelesai;
  // Daftar lengkap semua segmen Tilawah (WAFA tidak masuk sini). Sama
  // seperti [tahfizhSegments]: null/kosong pada data lama -> fallback ke
  // field tunggal tilawah* di atas lewat [tilawahSegmentsEffective].
  final List<TilawahSegment>? tilawahSegments;

  final String? catatan;

  // Folder tempat laporan ini disimpan (null = tidak di dalam folder mana pun,
  // tampil di section "Laporan" biasa).
  final String? folderId;

  // Id user (guru pembimbing) yang membuat laporan ini. OPSIONAL & backward
  // compatible — laporan lama (sebelum ada auth) tidak punya ini dan
  // TETAP bisa dibaca/ditampilkan normal (null). Field ini untuk
  // keperluan audit/riwayat ke depan; access control TIDAK mengandalkan
  // field ini (lihat AccessScope — scoping dari kelas+halaqoh).
  final String? ownerId;

  SantriRecord({
    required this.id,
    required this.tanggal,
    this.createdAt,
    required this.kelas,
    required this.halaqoh,
    required this.namaAnak,
    required this.status,
    required this.keterangan,
    this.surahNumber,
    this.surahName,
    this.ayatMulai,
    this.ayatSelesai,
    this.totalBaris,
    this.lineIds,
    this.tahfizhSegments,
    this.tahsinMode,
    this.wafaLevel,
    this.halamanWafa,
    this.tilawahSurahNumber,
    this.tilawahSurahName,
    this.tilawahAyatMulai,
    this.tilawahAyatSelesai,
    this.tilawahSegments,
    this.catatan,
    this.folderId,
    this.ownerId,
  });

  SantriRecord copyWith({
    DateTime? tanggal,
    String? kelas,
    String? halaqoh,
    String? namaAnak,
    HafalanStatus? status,
    Keterangan? keterangan,
    int? surahNumber,
    String? surahName,
    int? ayatMulai,
    int? ayatSelesai,
    int? totalBaris,
    List<String>? lineIds,
    List<TahfizhSegment>? tahfizhSegments,
    TahsinMode? tahsinMode,
    WafaLevel? wafaLevel,
    String? halamanWafa,
    int? tilawahSurahNumber,
    String? tilawahSurahName,
    int? tilawahAyatMulai,
    int? tilawahAyatSelesai,
    List<TilawahSegment>? tilawahSegments,
    String? catatan,
    String? folderId,
    bool clearTahfizh = false,
    bool clearTahsin = false,
    bool clearTilawah = false,
    bool clearFolder = false,
  }) {
    return SantriRecord(
      id: id,
      tanggal: tanggal ?? this.tanggal,
      createdAt: createdAt,
      ownerId: ownerId,
      kelas: kelas ?? this.kelas,
      halaqoh: halaqoh ?? this.halaqoh,
      namaAnak: namaAnak ?? this.namaAnak,
      status: status ?? this.status,
      keterangan: keterangan ?? this.keterangan,
      surahNumber: clearTahfizh ? null : (surahNumber ?? this.surahNumber),
      surahName: clearTahfizh ? null : (surahName ?? this.surahName),
      ayatMulai: clearTahfizh ? null : (ayatMulai ?? this.ayatMulai),
      ayatSelesai: clearTahfizh ? null : (ayatSelesai ?? this.ayatSelesai),
      totalBaris: clearTahfizh ? null : (totalBaris ?? this.totalBaris),
      lineIds: clearTahfizh ? null : (lineIds ?? this.lineIds),
      tahfizhSegments: clearTahfizh ? null : (tahfizhSegments ?? this.tahfizhSegments),
      tahsinMode: clearTahsin ? null : (tahsinMode ?? this.tahsinMode),
      wafaLevel: clearTahsin ? null : (wafaLevel ?? this.wafaLevel),
      halamanWafa: clearTahsin ? null : (halamanWafa ?? this.halamanWafa),
      tilawahSurahNumber:
          clearTilawah ? null : (tilawahSurahNumber ?? this.tilawahSurahNumber),
      tilawahSurahName: clearTilawah ? null : (tilawahSurahName ?? this.tilawahSurahName),
      tilawahAyatMulai: clearTilawah ? null : (tilawahAyatMulai ?? this.tilawahAyatMulai),
      tilawahAyatSelesai:
          clearTilawah ? null : (tilawahAyatSelesai ?? this.tilawahAyatSelesai),
      tilawahSegments: clearTilawah ? null : (tilawahSegments ?? this.tilawahSegments),
      catatan: catatan ?? this.catatan,
      folderId: clearFolder ? null : (folderId ?? this.folderId),
    );
  }

  /// Semua segmen Tahfizh laporan ini. Kalau [tahfizhSegments] belum ada
  /// (data lama sebelum fitur multi-surah), otomatis di-generate 1 segmen
  /// dari field tunggal surahNumber/surahName/ayatMulai/ayatSelesai +
  /// totalBaris/lineIds — jadi laporan lama tetap kebaca normal.
  List<TahfizhSegment> get tahfizhSegmentsEffective {
    if (tahfizhSegments != null && tahfizhSegments!.isNotEmpty) return tahfizhSegments!;
    if (surahNumber != null && surahName != null && ayatMulai != null && ayatSelesai != null) {
      return [
        TahfizhSegment(
          surahNumber: surahNumber!,
          surahName: surahName!,
          ayatMulai: ayatMulai!,
          ayatSelesai: ayatSelesai!,
          totalBaris: totalBaris ?? 0,
          lineIds: lineIds ?? const [],
        ),
      ];
    }
    return const [];
  }

  /// Semua segmen Tilawah laporan ini (dipakai Tahsin-mode-Tilawah &
  /// Muroja'ah/Tasmi'). Fallback yang sama seperti [tahfizhSegmentsEffective]
  /// buat laporan lama.
  List<TilawahSegment> get tilawahSegmentsEffective {
    if (tilawahSegments != null && tilawahSegments!.isNotEmpty) return tilawahSegments!;
    if (tilawahSurahNumber != null &&
        tilawahSurahName != null &&
        tilawahAyatMulai != null &&
        tilawahAyatSelesai != null) {
      return [
        TilawahSegment(
          surahNumber: tilawahSurahNumber!,
          surahName: tilawahSurahName!,
          ayatMulai: tilawahAyatMulai!,
          ayatSelesai: tilawahAyatSelesai!,
        ),
      ];
    }
    return const [];
  }

  /// Teks ringkas bagian Tahsin saja (WAFA atau Tilawah) — dipakai baik
  /// untuk status Tahsin murni maupun sebagai salah satu bagian dari
  /// Tahsin+Tahfizh.
  String get _tahsinPartText {
    final mode = tahsinMode ?? TahsinMode.wafa; // null = data lama -> WAFA
    if (mode == TahsinMode.tilawah) {
      final segs = tilawahSegmentsEffective;
      if (segs.isEmpty) return 'Tilawah • -';
      return 'Tilawah • ${segs.map((s) => s.partText).join(' + ')}';
    }
    final level = wafaLevel?.label ?? '-';
    final hal = halamanWafa ?? '-';
    return '$level • Hal. $hal';
  }

  /// Teks ringkas bagian Tahfizh saja (hafalan baru, hasil generate baris).
  /// Kalau lebih dari 1 surah (setoran nyambung lintas surah), digabung
  /// dengan " + ", mis. "Al-Baqarah • Ayat 280–286 + Ali 'Imran • Ayat 1–5".
  String get _tahfizhPartText {
    final segs = tahfizhSegmentsEffective;
    if (segs.isEmpty) return '-';
    return segs.map((s) => s.partText).join(' + ');
  }

  /// Teks ringkas untuk status Muroja'ah/Tasmi' (selalu bentuk Tilawah).
  String get _murojaahPartText {
    final segs = tilawahSegmentsEffective;
    if (segs.isEmpty) return '-';
    return segs.map((s) => s.partText).join(' + ');
  }

  /// Total jumlah ayat yang disetorkan di laporan ini — dijumlahkan dari
  /// SEMUA segmen (Tahfizh + Tilawah, keduanya bisa ada bareng di status
  /// Tahsin+Tahfizh), dipakai buat chart "Ayat Tersetor/Minggu" di tab
  /// Statistik. Rentang ayatMulai..ayatSelesai dihitung inklusif kedua
  /// ujungnya (mis. ayat 5–8 = 4 ayat).
  int get jumlahAyat {
    int rangeCount(int mulai, int selesai) =>
        selesai >= mulai ? (selesai - mulai + 1) : 0;
    final tahfizh = tahfizhSegmentsEffective.fold<int>(
      0,
      (sum, s) => sum + rangeCount(s.ayatMulai, s.ayatSelesai),
    );
    final tilawah = tilawahSegmentsEffective.fold<int>(
      0,
      (sum, s) => sum + rangeCount(s.ayatMulai, s.ayatSelesai),
    );
    return tahfizh + tilawah;
  }

  /// Ringkasan capaian untuk ditampilkan di kartu / laporan.
  String get capaianText {
    switch (status) {
      case HafalanStatus.tahfizh:
        return _tahfizhPartText;
      case HafalanStatus.tahsin:
        return _tahsinPartText;
      case HafalanStatus.tahsinTahfizh:
        return '$_tahsinPartText + $_tahfizhPartText';
      case HafalanStatus.murojaahTasmi:
        return _murojaahPartText;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tanggal': tanggal.toIso8601String(),
        'createdAt': createdAt?.toIso8601String(),
        'kelas': kelas,
        'halaqoh': halaqoh,
        'namaAnak': namaAnak,
        'status': status.name,
        'keterangan': keterangan.name,
        'surahNumber': surahNumber,
        'surahName': surahName,
        'ayatMulai': ayatMulai,
        'ayatSelesai': ayatSelesai,
        'totalBaris': totalBaris,
        'lineIds': lineIds,
        'tahfizhSegments': tahfizhSegments?.map((s) => s.toJson()).toList(),
        'tahsinMode': tahsinMode?.name,
        'wafaLevel': wafaLevel?.name,
        'halamanWafa': halamanWafa,
        'tilawahSurahNumber': tilawahSurahNumber,
        'tilawahSurahName': tilawahSurahName,
        'tilawahAyatMulai': tilawahAyatMulai,
        'tilawahAyatSelesai': tilawahAyatSelesai,
        'tilawahSegments': tilawahSegments?.map((s) => s.toJson()).toList(),
        'catatan': catatan,
        'folderId': folderId,
        'ownerId': ownerId,
      };

  factory SantriRecord.fromJson(Map<String, dynamic> json) => SantriRecord(
        id: json['id'] as String,
        tanggal: DateTime.parse(json['tanggal'] as String),
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
        kelas: json['kelas'] as String,
        halaqoh: normalizeHalaqoh(json['halaqoh'] as String),
        namaAnak: json['namaAnak'] as String,
        status: HafalanStatus.values.byName(json['status'] as String),
        keterangan: Keterangan.values.byName(json['keterangan'] as String),
        surahNumber: json['surahNumber'] as int?,
        surahName: json['surahName'] as String?,
        ayatMulai: json['ayatMulai'] as int?,
        ayatSelesai: json['ayatSelesai'] as int?,
        totalBaris: json['totalBaris'] as int?,
        lineIds: (json['lineIds'] as List?)?.map((e) => e as String).toList(),
        // Field baru (multi-surah) — data lama belum punya ini, default
        // null aman: tahfizhSegmentsEffective otomatis fallback ke field
        // tunggal surahNumber/dst di atas (backward compatible).
        tahfizhSegments: (json['tahfizhSegments'] as List?)
            ?.map((e) => TahfizhSegment.fromJson(e as Map<String, dynamic>))
            .toList(),
        // Field baru (tahsinMode & tilawah*) — data lama belum punya ini,
        // default null aman (backward compatible): tahsinMode null berarti
        // "WAFA" (lihat _tahsinPartText), tilawah* null berarti belum
        // pernah diisi bentuk Tilawah sama sekali.
        tahsinMode: json['tahsinMode'] != null
            ? TahsinMode.values.byName(json['tahsinMode'] as String)
            : null,
        wafaLevel: json['wafaLevel'] != null
            ? WafaLevel.values.byName(json['wafaLevel'] as String)
            : null,
        halamanWafa: json['halamanWafa'] as String?,
        tilawahSurahNumber: json['tilawahSurahNumber'] as int?,
        tilawahSurahName: json['tilawahSurahName'] as String?,
        tilawahAyatMulai: json['tilawahAyatMulai'] as int?,
        tilawahAyatSelesai: json['tilawahAyatSelesai'] as int?,
        tilawahSegments: (json['tilawahSegments'] as List?)
            ?.map((e) => TilawahSegment.fromJson(e as Map<String, dynamic>))
            .toList(),
        catatan: json['catatan'] as String?,
        folderId: json['folderId'] as String?,
        // Field baru — data lama pasti belum punya ini, default null aman
        // (backward compatible, tidak ada migration destructive).
        ownerId: json['ownerId'] as String?,
      );
}
