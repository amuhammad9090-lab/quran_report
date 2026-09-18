/// Folder untuk mengelompokkan beberapa laporan santri (mis. per kelas,
/// per bulan, atau per keperluan tertentu).
class ReportFolder {
  final String id;
  final String nama;
  final DateTime createdAt;
  // <-- BARU: siapa (UserAccount.id) yang bikin folder ini. NULLABLE demi
  // kompatibilitas folder lama (dibuat sebelum field ini ada) -- folder
  // ber-ownerId null dianggap folder lama/global, TETAP kelihatan buat
  // semua orang (lihat AccessScope.scopeFolders) supaya guru yang sudah
  // pakai folder lama itu tidak tiba-tiba kehilangan aksesnya. Folder
  // BARU (dibuat setelah field ini ada) selalu keisi ownerId-nya, dan
  // cuma kelihatan buat pembuatnya sendiri kalau lagi mode guru (BUKAN
  // mode admin) -- lihat folder_form_sheet.dart & AccessScope.
  final String? ownerId;

  ReportFolder({
    required this.id,
    required this.nama,
    required this.createdAt,
    this.ownerId,
  });

  ReportFolder copyWith({String? nama}) => ReportFolder(
        id: id,
        nama: nama ?? this.nama,
        createdAt: createdAt,
        ownerId: ownerId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nama': nama,
        'createdAt': createdAt.toIso8601String(),
        'ownerId': ownerId,
      };

  factory ReportFolder.fromJson(Map<String, dynamic> json) => ReportFolder(
        id: json['id'] as String,
        nama: json['nama'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        ownerId: json['ownerId'] as String?,
      );
}
