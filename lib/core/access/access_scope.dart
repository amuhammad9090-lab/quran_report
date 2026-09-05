import '../../data/models/kelas_halaqoh.dart';
import '../../data/models/santri_record.dart';
import '../../data/models/student.dart';
import '../../data/models/user_account.dart';

/// Representasi "apa yang boleh dilihat/diubah user ini" — dihitung sekali
/// dari [UserAccount] yang sedang login, lalu dipakai di level DATA
/// (provider/repository), bukan cuma nge-filter tampilan di widget.
///
/// Aturan (sesuai spesifikasi & data sekolah asli): admin = akses global.
/// Guru Pembimbing = hanya data yang kelas+halaqoh-nya cocok PERSIS dengan salah
/// satu [UserAccount.assignments] miliknya — PASANGAN, bukan cross-
/// product dua list independen. Lihat dokumentasi di [KelasHalaqoh] untuk
/// kenapa ini penting: data guru asli membuktikan satu guru bisa
/// mengampu beberapa kelas & halaqoh berbeda TANPA itu berarti dia boleh
/// akses semua kombinasi silang antara kelas-kelasnya dan halaqoh-
/// halaqohnya.
///
/// Catatan desain: [SantriRecord] existing tidak punya `studentId` (nama/
/// kelas/halaqoh selama ini teks bebas yang diketik guru pembimbing). Supaya data
/// lama (yang jelas tidak punya field itu) tidak jadi tidak-bisa-diakses,
/// scoping dilakukan lewat kecocokan kelas+halaqoh — bukan lewat
/// `ownerId`/`studentId`. Field `ownerId` yang ditambahkan ke
/// [SantriRecord] tetap dipertahankan untuk keperluan audit/masa depan,
/// tapi BUKAN dasar keputusan akses saat ini.
///
/// <-- BARU: [adminModeActive]. Akun admin yang JUGA guru pembimbing
/// (punya [UserAccount.assignments] sendiri) sekarang bisa "matiin" akses
/// globalnya lewat toggle "Mode Admin" di Profil (lihat ProfileScreen &
/// AuthProvider.setAdminModeActive) — dipakai pas admin itu lagi mau
/// kerja SEBAGAI guru pembimbing biasa (fokus cuma ke kelas/halaqoh
/// sendiri di form/folder/statistik), tanpa harus logout-login akun
/// beda. [user.isAdmin] TETAP true (identitas akun tidak berubah), yang
/// berubah cuma [isAdmin] getter di bawah ini (dipakai SEMUA pengecekan
/// akses) jadi ikut mempertimbangkan toggle ini. Default true supaya
/// admin TANPA assignment sendiri (murni admin, gak punya kelas/halaqoh
/// pribadi) tidak keneemu kesulitan tidak sengaja "mematikan" akses
/// globalnya sendiri sampai tidak bisa lihat apa-apa.
class AccessScope {
  final UserAccount user;
  final bool adminModeActive;
  const AccessScope(this.user, {this.adminModeActive = true});

  bool get isAdmin => user.isAdmin && adminModeActive;

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
