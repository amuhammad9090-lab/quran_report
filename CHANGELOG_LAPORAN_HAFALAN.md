# Update Laporan Hafalan — 23 Agustus 2026

## 1. Rename "Musyrif" → "Guru Pembimbing"
- Data di `data_guru_dan_murid.xlsx` sudah dicek: 301 santri & 9 akun **sama
  persis** dengan data yang sudah ada di seed (password hash pun cocok
  100%, sudah diverifikasi ulang pakai algoritma hash yang sama persis
  dengan `auth_hash_service.dart`). Satu-satunya perbedaan: field `role`
  di Excel sekarang `guru_pembimbing`, bukan `musyrif` lagi.
- Jadi ini murni rename istilah, **bukan ganti data guru/santri**.
- Diubah: enum `UserRole` (`musyrif` → `guruPembimbing`), label tampilan
  di Profile, teks di layar Login/Onboarding/About, dan 8 akun di seed
  data. `UserRole.fromName()` tetap terima nilai lama (`musyrif`,
  `guru_alquran`) untuk backward compatibility kalau ada data lokal lama
  di HP yang belum ke-update.

## 2. Nama santri di-filter per kelas+halaqoh
- Sebelumnya field "Nama Anak" menampilkan gabungan SEMUA santri dari
  semua kelas/halaqoh yang bisa diakses user — sekarang wajib pilih
  Kelas & Halaqoh dulu, baru daftar nama santri muncul, **cuma santri di
  kombinasi kelas+halaqoh itu**.
- Kalau Kelas/Halaqoh diganti setelah Nama sudah dipilih, dan nama lama
  ternyata bukan santri di kombinasi baru, otomatis direset (nggak
  nyangkut data yang salah).

## 3. Admin yang juga Guru Pembimbing (kasus `hosri`) dibatasi juga
- Sekarang: kalau akun admin **punya assignment kelas+halaqoh sendiri**
  (kayak `hosri`), dropdown Kelas/Halaqoh/Nama Santri di form laporan
  **default dibatasi ke assignment miliknya sendiri saja** — sama seperti
  guru pembimbing biasa.
- Ditambah toggle kecil "Mode Admin" (cuma muncul buat admin yang punya
  assignment sendiri) buat sewaktu-waktu perlu input laporan di luar
  kelasnya sendiri (misal bantu koreksi data guru lain) — defaultnya OFF.
- Admin murni (tanpa assignment sendiri sama sekali) tetap bebas pilih
  semua kelas seperti biasa, karena memang nggak punya "kelas sendiri"
  yang bisa jadi default.
- Enforcement akses data (siapa boleh baca/tulis apa) TIDAK berubah —
  ini murni soal kolom pilihan mana yang ditawarkan di form.

## 4. Kelas / Halaqoh / Nama Santri — nggak bisa diketik bebas lagi
- Widget lama (`DropdownMenu` + `enableFilter: true`) diganti total ke
  widget baru `SelectField` (pakai `DropdownButtonFormField`) yang
  **cuma bisa pilih dari daftar**, nggak ada text-input sama sekali.

## 5. Warning "bukan orang yang bersangkutan" pindah ke dalam bottom sheet
- Snackbar sekarang pakai `ScaffoldMessenger` lokal punya sheet-nya
  sendiri (bukan punya halaman di belakangnya) — jadi muncul DI DALAM
  bottom sheet, di depan, nggak ketutup/membelakangi lagi.
- Warning ini muncul otomatis kalau kombinasi Kelas+Halaqoh yang dipilih
  BUKAN salah satu assignment resmi user yang login (cuma bisa terjadi
  kalau pakai Mode Admin di atas). Laporan yang disimpan lewat jalur ini
  juga otomatis dicatat `ownerId`-nya (siapa sebenarnya yang input) buat
  keperluan audit ke depan.

## 6. Draft laporan otomatis tersimpan
- Setiap perubahan di form laporan BARU (bukan edit) otomatis kesimpen
  sebagai draft lokal (Hive, lewat `AppPrefsService`) dengan sedikit
  debounce (~0.5 detik), jadi kalau bottom sheet ke-tutup nggak sengaja
  (swipe/tap di luar) sebelum sempat tekan Simpan, isian nggak hilang.
- Begitu buka "Laporan Baru" lagi, kalau ada draft yang belum sempat
  disimpan, muncul banner di atas form: **"Lanjutkan"** (isi ulang semua
  field dari draft) atau **"Buang"** (mulai kosong, hapus draft).
- Draft otomatis dibersihkan begitu laporan berhasil disimpan.
- Fitur ini SENGAJA cuma untuk laporan baru, bukan edit — biar nggak ada
  risiko draft lama nyampur/nimpa data laporan yang sedang diedit.

---

## File yang berubah
- `lib/data/models/user_account.dart`
- `lib/data/local_seed/local_seed_data.dart`
- `lib/presentation/screens/auth/login_screen.dart`
- `lib/presentation/screens/auth/onboarding_screen.dart`
- `lib/presentation/screens/about/about_screen.dart`
- `lib/core/access/access_scope.dart` (komentar)
- `lib/providers/records_provider.dart` (komentar)
- `lib/data/models/santri_record.dart` (komentar)
- `lib/data/services/app_prefs_service.dart` (fitur draft baru)
- `lib/presentation/widgets/misc_widgets.dart` (`SelectField` baru,
  `DropdownTypeField` lama dihapus)
- `lib/presentation/screens/record_form/record_form_sheet.dart`
  (rewrite besar — poin 2–6 di atas)

## Yang perlu dicoba manual
1. Login sebagai `hosri` (admin + guru pembimbing) → buka "Laporan Baru"
   → pastikan Kelas/Halaqoh default cuma nampilin assignment `hosri`
   sendiri, ada toggle "Mode Admin", dan nyalain togglenya buat cek opsi
   jadi lengkap semua kelas + snackbar warning muncul di dalam sheet.
2. Login sebagai guru pembimbing biasa (misal `adir`) → pastikan nggak
   ada toggle admin & tetap dibatasi assignment sendiri seperti biasa.
3. Pilih Kelas+Halaqoh → cek daftar Nama Santri cuma santri di
   kombinasi itu, nggak nyampur kelas lain.
4. Isi sebagian form laporan baru → tutup sheet dengan swipe/tap di luar
   (jangan tekan Simpan) → buka "Laporan Baru" lagi → pastikan banner
   draft muncul & "Lanjutkan" ngembaliin isian tadi persis.
