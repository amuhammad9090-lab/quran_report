/// Standar ketuntasan yang diisi admin: target baris Tahfizh per pekan dan KKM nilai Tahsin.
class KetuntasanConfig {
  /// Field target baris: key, label, nilai bawaan.
  static const barisFields = <({String key, String label, int def})>[
    (key: 'k7', label: 'Kelas 7 • Halaqoh Tahfizh', def: 10),
    (key: 'k8_A', label: 'Kelas 8 • Halaqoh A', def: 12),
    (key: 'k8_B', label: 'Kelas 8 • Halaqoh B', def: 10),
    (key: 'k8_C', label: 'Kelas 8 • Halaqoh C', def: 9),
    (key: 'k8_Tahfizh', label: 'Kelas 8 • Halaqoh Tahfizh', def: 12),
    (key: 'k9_A', label: 'Kelas 9 • Halaqoh A', def: 15),
    (key: 'k9_B', label: 'Kelas 9 • Halaqoh B', def: 12),
    (key: 'k9_C', label: 'Kelas 9 • Halaqoh C', def: 10),
    (key: 'k9_D', label: 'Kelas 9 • Halaqoh D', def: 9),
  ];

  final Map<String, int> baris;
  final double kkmTahsin1;
  final double kkmTahsin2;

  const KetuntasanConfig({
    required this.baris,
    this.kkmTahsin1 = 80,
    this.kkmTahsin2 = 80,
  });

  factory KetuntasanConfig.defaults() => KetuntasanConfig(
        baris: {for (final f in barisFields) f.key: f.def},
      );

  int? barisFor(String key) => baris[key];

  Map<String, dynamic> toJson() => {
        'baris': baris,
        'kkmTahsin1': kkmTahsin1,
        'kkmTahsin2': kkmTahsin2,
      };

  /// Field yang hilang/rusak jatuh ke nilai bawaan.
  factory KetuntasanConfig.fromJson(Map<String, dynamic> json) {
    final raw = json['baris'];
    final rawMap = raw is Map ? raw : const {};
    return KetuntasanConfig(
      baris: {
        for (final f in barisFields)
          f.key: (rawMap[f.key] is num && (rawMap[f.key] as num) > 0)
              ? (rawMap[f.key] as num).toInt()
              : f.def,
      },
      kkmTahsin1: _kkm(json['kkmTahsin1']),
      kkmTahsin2: _kkm(json['kkmTahsin2']),
    );
  }

  static double _kkm(Object? v) => (v is num && v > 0) ? v.toDouble() : 80;
}
