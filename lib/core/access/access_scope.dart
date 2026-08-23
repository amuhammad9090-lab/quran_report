import '../../data/models/kelas_halaqoh.dart';
import '../../data/models/santri_record.dart';
import '../../data/models/student.dart';
import '../../data/models/user_account.dart';

/// Representasi "apa yang boleh dilihat/diubah user ini" — dihitung sekali
/// dari [UserAccount] yang sedang login, lalu dipakai di level DATA
/// (provider/repository), bukan cuma nge-filter tampilan di widget.
///
/// Aturan (sesuai spesifikasi & data sekolah asli): admin = akses global.
/// Musyrif = hanya data yang kelas+halaqoh-nya cocok PERSIS dengan salah
/// satu [UserAccount.assignments] miliknya — PASANGAN, bukan cross-
/// product dua list independen. Lihat dokumentasi di [KelasHalaqoh] untuk
/// kenapa ini penting: data guru asli membuktikan satu guru bisa
/// mengampu beberapa kelas & halaqoh berbeda TANPA itu berarti dia boleh
/// akses semua kombinasi silang antara kelas-kelasnya dan halaqoh-
/// halaqohnya.
///
/// Catatan desain: [SantriRecord] existing tidak punya `studentId` (nama/
/// kelas/halaqoh selama ini teks bebas yang diketik musyrif). Supaya data
/// lama (yang jelas tidak punya field itu) tidak jadi tidak-bisa-diakses,
/// scoping dilakukan lewat kecocokan kelas+halaqoh — bukan lewat
/// `ownerId`/`studentId`. Field `ownerId` yang ditambahkan ke
/// [SantriRecord] tetap dipertahankan untuk keperluan audit/masa depan,
/// tapi BUKAN dasar keputusan akses saat ini.
class AccessScope {
  final UserAccount user;
  const AccessScope(this.user);

  bool get isAdmin => user.isAdmin;

  bool canAccessKelasHalaqoh(String kelas, String halaqoh) {
    if (isAdmin) return true;
    return user.assignments.contains(KelasHalaqoh(kelas: kelas, halaqoh: halaqoh));
  }

  bool canAccessRecord(SantriRecord record) =>
      canAccessKelasHalaqoh(record.kelas, record.halaqoh);

  bool canAccessStudent(Student student) =>
      canAccessKelasHalaqoh(student.kelas, student.halaqoh);

  List<SantriRecord> scopeRecords(List<SantriRecord> all) {
    if (isAdmin) return all;
    return all.where(canAccessRecord).toList();
  }

  List<Student> scopeStudents(List<Student> all) {
    if (isAdmin) return all;
    return all.where(canAccessStudent).toList();
  }
}
