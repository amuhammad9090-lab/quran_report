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
  final WafaLevel? wafaLevel;
  final String? halamanWafa; // halaman buku WAFA, string biar fleksibel (mis. "12-13")

  final String? catatan;

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
    this.wafaLevel,
    this.halamanWafa,
    this.catatan,
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
    WafaLevel? wafaLevel,
    String? halamanWafa,
    String? catatan,
    bool clearTahfizh = false,
    bool clearTahsin = false,
  }) {
    return SantriRecord(
      id: id,
      tanggal: tanggal ?? this.tanggal,
      createdAt: createdAt,
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
      wafaLevel: clearTahsin ? null : (wafaLevel ?? this.wafaLevel),
      halamanWafa: clearTahsin ? null : (halamanWafa ?? this.halamanWafa),
      catatan: catatan ?? this.catatan,
    );
  }

  /// Ringkasan capaian untuk ditampilkan di kartu / laporan.
  String get capaianText {
    if (status == HafalanStatus.tahfizh) {
      if (surahName == null || ayatMulai == null || ayatSelesai == null) {
        return '-';
      }
      return '$surahName • Ayat $ayatMulai–$ayatSelesai';
    } else {
      final level = wafaLevel?.label ?? '-';
      final hal = halamanWafa ?? '-';
      return '$level • Hal. $hal';
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
        'wafaLevel': wafaLevel?.name,
        'halamanWafa': halamanWafa,
        'catatan': catatan,
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
        wafaLevel: json['wafaLevel'] != null
            ? WafaLevel.values.byName(json['wafaLevel'] as String)
            : null,
        halamanWafa: json['halamanWafa'] as String?,
        catatan: json['catatan'] as String?,
      );
}
