// <-- BARU (seluruh file)
//
// ID sekolah dipakai buat mirror data laporan ke Firestore (project
// Portal Orang Tua, `quran-reportweb`). HARUS SAMA PERSIS dengan
// `schoolId` yang dipakai di project `quran_report_parent`
// (lihat scripts/students_seed.json & lib/data/local_seed/local_seed_data.dart
// di project ini — sudah hardcode nilai yang sama).
const kSchoolId = 'smpit_al_madinah_tanjungpinang';

/// <-- BARU (skema per-guru nested, lihat firestore.rules): accountId
/// guru yang SEDANG login, dipakai semua service yang datanya sekarang
/// nested di bawah `accounts/{accountId}/...` (RecordsRemoteSource,
/// AppPrefsService, ParentNoteService, WeeklyRecapDeployService) buat
/// bangun path Firestore-nya. Diisi/dikosongkan di titik transisi auth
/// yang SAMA PERSIS seperti RecordsProvider.updateScope()/
/// ParentNotesProvider.updateScope() (lihat main.dart, login_screen.dart,
/// profile_screen.dart, main_shell.dart) — sengaja variabel global biasa
/// (bukan lewat Provider) karena service-service di atas singleton biasa
/// yang dipanggil dari banyak tempat non-widget (mis. fire-and-forget
/// mirror), bukan hanya dari widget tree.
String? currentGuruAccountId;
