/// Folder untuk mengelompokkan beberapa laporan santri (mis. per kelas,
/// per bulan, atau per keperluan tertentu).
class ReportFolder {
  final String id;
  final String nama;
  final DateTime createdAt;

  ReportFolder({
    required this.id,
    required this.nama,
    required this.createdAt,
  });

  ReportFolder copyWith({String? nama}) => ReportFolder(
        id: id,
        nama: nama ?? this.nama,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nama': nama,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ReportFolder.fromJson(Map<String, dynamic> json) => ReportFolder(
        id: json['id'] as String,
        nama: json['nama'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
