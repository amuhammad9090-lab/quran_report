import 'enums.dart';

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
  final int? surahNumber;
  final String? surahName;
  final int? ayatMulai;
  final int? ayatSelesai;
  final int? totalBaris; // hasil generate dari engine (baris BARU, sudah dikurangi riwayat)
  final List<String>? lineIds; // id baris fisik yang dihitung di laporan ini

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
    this.tahsinMode,
    this.wafaLevel,
    this.halamanWafa,
    this.tilawahSurahNumber,
    this.tilawahSurahName,
    this.tilawahAyatMulai,
    this.tilawahAyatSelesai,
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
    TahsinMode? tahsinMode,
    WafaLevel? wafaLevel,
    String? halamanWafa,
    int? tilawahSurahNumber,
    String? tilawahSurahName,
    int? tilawahAyatMulai,
    int? tilawahAyatSelesai,
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
      tahsinMode: clearTahsin ? null : (tahsinMode ?? this.tahsinMode),
      wafaLevel: clearTahsin ? null : (wafaLevel ?? this.wafaLevel),
      halamanWafa: clearTahsin ? null : (halamanWafa ?? this.halamanWafa),
      tilawahSurahNumber:
          clearTilawah ? null : (tilawahSurahNumber ?? this.tilawahSurahNumber),
      tilawahSurahName: clearTilawah ? null : (tilawahSurahName ?? this.tilawahSurahName),
      tilawahAyatMulai: clearTilawah ? null : (tilawahAyatMulai ?? this.tilawahAyatMulai),
      tilawahAyatSelesai:
          clearTilawah ? null : (tilawahAyatSelesai ?? this.tilawahAyatSelesai),
      catatan: catatan ?? this.catatan,
      folderId: clearFolder ? null : (folderId ?? this.folderId),
    );
  }

  /// Teks ringkas bagian Tahsin saja (WAFA atau Tilawah) — dipakai baik
  /// untuk status Tahsin murni maupun sebagai salah satu bagian dari
  /// Tahsin+Tahfizh.
  String get _tahsinPartText {
    final mode = tahsinMode ?? TahsinMode.wafa; // null = data lama -> WAFA
    if (mode == TahsinMode.tilawah) {
      if (tilawahSurahName == null || tilawahAyatMulai == null || tilawahAyatSelesai == null) {
        return 'Tilawah • -';
      }
      return 'Tilawah • $tilawahSurahName • Ayat $tilawahAyatMulai–$tilawahAyatSelesai';
    }
    final level = wafaLevel?.label ?? '-';
    final hal = halamanWafa ?? '-';
    return '$level • Hal. $hal';
  }

  /// Teks ringkas bagian Tahfizh saja (hafalan baru, hasil generate baris).
  String get _tahfizhPartText {
    if (surahName == null || ayatMulai == null || ayatSelesai == null) return '-';
    return '$surahName • Ayat $ayatMulai–$ayatSelesai';
  }

  /// Teks ringkas untuk status Muroja'ah/Tasmi' (selalu bentuk Tilawah).
  String get _murojaahPartText {
    if (tilawahSurahName == null || tilawahAyatMulai == null || tilawahAyatSelesai == null) {
      return '-';
    }
    return '$tilawahSurahName • Ayat $tilawahAyatMulai–$tilawahAyatSelesai';
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
        'tahsinMode': tahsinMode?.name,
        'wafaLevel': wafaLevel?.name,
        'halamanWafa': halamanWafa,
        'tilawahSurahNumber': tilawahSurahNumber,
        'tilawahSurahName': tilawahSurahName,
        'tilawahAyatMulai': tilawahAyatMulai,
        'tilawahAyatSelesai': tilawahAyatSelesai,
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
        halaqoh: json['halaqoh'] as String,
        namaAnak: json['namaAnak'] as String,
        status: HafalanStatus.values.byName(json['status'] as String),
        keterangan: Keterangan.values.byName(json['keterangan'] as String),
        surahNumber: json['surahNumber'] as int?,
        surahName: json['surahName'] as String?,
        ayatMulai: json['ayatMulai'] as int?,
        ayatSelesai: json['ayatSelesai'] as int?,
        totalBaris: json['totalBaris'] as int?,
        lineIds: (json['lineIds'] as List?)?.map((e) => e as String).toList(),
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
        catatan: json['catatan'] as String?,
        folderId: json['folderId'] as String?,
        // Field baru — data lama pasti belum punya ini, default null aman
        // (backward compatible, tidak ada migration destructive).
        ownerId: json['ownerId'] as String?,
      );
}
