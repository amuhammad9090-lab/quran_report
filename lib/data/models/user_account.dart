import 'kelas_halaqoh.dart';

/// Role akses user. Admin = akses global, Musyrif = hanya data
/// assignment (kelas+halaqoh) miliknya sendiri.
enum UserRole {
  admin,
  musyrif;

  String get label => switch (this) {
        UserRole.admin => 'Admin',
        UserRole.musyrif => 'Musyrif',
      };

  static UserRole fromName(String name) {
    final n = name.trim().toLowerCase();
    if (n == 'admin') return UserRole.admin;
    // 'musyrif' dan 'guru_alquran' (label asli data sekolah) dianggap
    // sama. Nilai lain yang tidak dikenal juga fallback ke musyrif
    // (bukan admin) supaya defaultnya selalu yang PALING TERBATAS,
    // bukan yang paling luas aksesnya.
    return UserRole.musyrif;
  }
}

/// Akun user (musyrif/admin) — dipakai oleh [AuthRepository].
///
/// `passwordHash` TIDAK PERNAH menyimpan plaintext (lihat
/// `AuthHashService`). Field ini murni model data, tidak tahu-menahu soal
/// mekanisme hashing/verifikasi.
class UserAccount {
  final String id;
  final String username;
  final String displayName;
  final String passwordHash;
  final UserRole role;

  /// Assignment kelas+halaqoh yang diampu, sebagai PASANGAN (lihat
  /// dokumentasi [KelasHalaqoh] — kenapa ini bukan dua list terpisah).
  /// Untuk admin biasanya kosong (akses global, tidak dibatasi list ini).
  final List<KelasHalaqoh> assignments;

  final String schoolId;

  /// Path foto profil LOKAL (belum ada backend upload). Null = pakai
  /// fallback avatar inisial nama.
  final String? photoPath;

  const UserAccount({
    required this.id,
    required this.username,
    required this.displayName,
    required this.passwordHash,
    required this.role,
    this.assignments = const [],
    required this.schoolId,
    this.photoPath,
  });

  bool get isAdmin => role == UserRole.admin;

  /// Kelas unik yang diampu (union dari [assignments]) — cuma buat
  /// keperluan TAMPILAN (mis. chip ringkasan di Profile). JANGAN dipakai
  /// buat keputusan akses — pakai [assignments] langsung / AccessScope.
  List<String> get distinctKelas => assignments.map((a) => a.kelas).toSet().toList();

  /// Halaqoh unik yang diampu — sama catatannya seperti [distinctKelas].
  List<String> get distinctHalaqoh => assignments.map((a) => a.halaqoh).toSet().toList();

  UserAccount copyWith({
    String? displayName,
    List<KelasHalaqoh>? assignments,
    String? photoPath,
    bool clearPhoto = false,
  }) {
    return UserAccount(
      id: id,
      username: username,
      displayName: displayName ?? this.displayName,
      passwordHash: passwordHash,
      role: role,
      assignments: assignments ?? this.assignments,
      schoolId: schoolId,
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'displayName': displayName,
        'passwordHash': passwordHash,
        'role': role.name,
        'assignments': assignments.map((a) => a.toJson()).toList(),
        'schoolId': schoolId,
        'photoPath': photoPath,
      };

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    List<KelasHalaqoh> parsedAssignments;
    if (json['assignments'] is List) {
      // Bentuk baru (benar): list pasangan {kelas, halaqoh}.
      parsedAssignments = (json['assignments'] as List)
          .map((e) => KelasHalaqoh.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } else {
      // Fallback data lama (dua list terpisah, SALAH secara semantik —
      // lihat dokumentasi KelasHalaqoh) — di-zip apa adanya berdasarkan
      // index biar tidak crash, tapi ini cuma best-effort migration,
      // bukan jaminan hasilnya benar kalau data lama itu sendiri sudah
      // ambigu.
      final kelasList = (json['kelas'] as List?)?.map((e) => e.toString()).toList() ?? const [];
      final halaqohList = (json['halaqoh'] as List?)?.map((e) => e.toString()).toList() ?? const [];
      final len = kelasList.length < halaqohList.length ? kelasList.length : halaqohList.length;
      parsedAssignments = [
        for (var i = 0; i < len; i++) KelasHalaqoh(kelas: kelasList[i], halaqoh: halaqohList[i]),
      ];
    }

    return UserAccount(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['displayName'] as String,
      passwordHash: json['passwordHash'] as String,
      role: UserRole.fromName(json['role'] as String? ?? 'musyrif'),
      assignments: parsedAssignments,
      // schoolId opsional di data lama — default ke sekolah pertama supaya
      // tidak crash kalau field belum ada (backward compatible).
      schoolId: json['schoolId'] as String? ?? 'smpit_al_madinah_tanjungpinang',
      photoPath: json['photoPath'] as String?,
    );
  }
}
