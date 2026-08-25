# Laporan Hafalan — mirailabs

Aplikasi Flutter untuk mencatat & mengekspor laporan capaian hafalan (tahfizh)
dan bacaan (tahsin) Al-Qur'an santri, lengkap dengan login berbasis peran,
folder pengelompokan laporan, dan statistik/rekap bulanan.

## Setup

```bash
flutter pub get
flutter run
```

Tidak perlu `build_runner` — storage pakai Hive `Box<String>` dengan
serialisasi JSON manual (tanpa TypeAdapter codegen).

## Fitur

### Autentikasi & hak akses
- Login berbasis akun (`username`/password) — password di-hash lokal, tidak
  pernah tersimpan plaintext (lihat `AuthHashService`).
- Dua peran: **Admin** (akses global ke semua data) dan **Guru Pembimbing**
  (hanya bisa melihat/mengubah data yang kelas+halaqoh-nya cocok persis
  dengan salah satu *assignment* miliknya — lihat `AccessScope`).
- Onboarding sekali di awal, lalu session login dipulihkan otomatis tiap
  buka app (`AppPrefsService`) sampai user logout.
- Profil: ganti nama tampilan, ganti kata sandi, ganti foto profil (ambil
  dari kamera/galeri via `image_picker`, disalin ke penyimpanan permanen
  app).

### Input laporan
- Input laporan per santri: kelas, halaqoh, nama, status (Tahsin / Tahfizh
  / Tahsin+Tahfizh / Muroja'ah-Tasmi').
- **Tahfizh**: pilih surah + rentang ayat → tombol **Generate Baris**
  (memakai dataset `assets/data/*.json`, hasil dari engine Python
  referensi) → menampilkan kolom baris per halaman mushaf + total baris.
  Nama santri harus diisi dulu sebelum tombol ini aktif, karena riwayat
  baris dicek berdasarkan nama (anti dobel-hitung, lihat bagian
  [Riwayat baris](#riwayat-baris-per-santri-anti-dobel-hitung) di bawah).
- **Tahsin**: dua sub-mode — **WAFA** (jenjang 1–5 + halaman) atau
  **Tilawah** (surah + rentang ayat, tanpa hitung baris).
- **Tahsin+Tahfizh**: gabungan keduanya dalam satu laporan.
- **Muroja'ah/Tasmi'**: mengulang hafalan lama (surah + rentang ayat).
- Keterangan kehadiran: Hadir / Izin Sakit / Izin Lomba / Izin Pelatihan /
  Tanpa Keterangan (Alpa).

### Laporan & Folder
- Tab Laporan: satu kartu per santri (bukan per laporan pekanan), tap
  kolom pekan untuk buka/isi laporan pekan itu.
- Mode pilih-banyak (centang) untuk hapus atau pindahkan beberapa kartu
  santri sekaligus.
- **Folder**: kelompokkan kartu santri ke dalam folder buatan sendiri
  (drag & drop kartu ke folder, atau lewat sheet "Pindahkan ke Folder").
  Folder detail punya mode pilih-banyak yang sama untuk keluarkan/hapus.
- Pencarian nama santri & filter (kelas, halaqoh, status, keterangan).
- FAB (tombol "+") di tab Laporan nyembul jadi dua aksi cepat: **Buat
  Folder** dan **Buat Laporan**.

### Statistik
- Tab Statistik: ringkasan rasio Tahfizh vs Tahsin bulan berjalan, plus
  tiga pintu masuk halaman detail:
  - **Daftar Santri** — rekap per santri.
  - **Kehadiran** — rekap Hadir/Izin/Alpa dikelompokkan per tanggal, bisa
    difilter per jenis keterangan.
  - **Rekap Bulanan** — lihat progres per pekan dalam sebulan, per
    Kelas+Halaqoh, sampai fitur **Generate Rekap Bulanan** (satu baris per
    santri, kolom Pekan 1..N) yang bisa langsung diekspor.

### Ekspor
- Ekspor ke **PDF**, **Word (.docx)**, **Excel (.xlsx)** — bisa semua
  data, sesuai filter/pencarian aktif, per folder, per Kelas+Halaqoh
  (dengan nama guru pembimbing otomatis di kop laporan), atau hasil
  Generate Rekap Bulanan.
- Setelah file dibuat, otomatis dicoba dibuka dengan aplikasi bawaan
  perangkat; lanjut bisa **Bagikan** (share sheet) atau **Simpan** salinan
  ke penyimpanan perangkat.

### Lainnya
- Tema Terang / Gelap / Ikuti Sistem (tersimpan otomatis).
- Halaman Notifikasi (masih placeholder — belum ada sumber data
  notifikasi asli, disiapkan untuk pengingat laporan/santri baru ke
  depannya).
- Halaman Pengaturan & Tentang Aplikasi.

## Engine baris — dual-schema

Engine (`lib/data/services/quran_engine_service.dart`) membaca **dua**
dataset sekaligus dan menormalisasi ke satu representasi internal:

- **Legacy** (`quran_line_dataset_legacy_juz1_10.json`) — Juz 1–10, skema
  lama (`segments` dengan `ayah_start`/`ayah_end`). Tidak ada info
  continuation, jadi baris dari sini tidak pernah kena aturan
  boundary-exclusion di bawah (perilaku identik engine versi sebelumnya).
- **Baru** (`quran_line_dataset_juz26_30.json`) — Juz 26–30, skema baru
  (`ayats: [[surah, ayat, ayat_akhir_atau_0]]`, `0` = ayat masih nyambung
  ke baris berikutnya). Mengikuti persis logic `get_lines_for_range()`
  dari tool Python referensi, termasuk **boundary-continuation rule**:
  baris pertama hasil pencarian dibuang kalau baris itu masih ekor ayat
  sebelumnya DAN ayat awal yang diminta nyambung terus dari baris itu
  (biar gak dobel hitung sama laporan sebelumnya).

Berbeda dari tool Python referensi yang *juz-scoped*, engine Dart
menggabungkan semua halaman dari kedua dataset jadi satu daftar baris
global, sehingga surah yang numpang lintas 2 juz tetap nyambung mulus.

## Riwayat baris per santri (anti dobel-hitung)

`SantriRecord` menyimpan `lineIds` — daftar `line_id` fisik yang terhitung
di laporan tahfizh itu. Saat generate baris baru untuk santri yang sama
(match nama, case-insensitive), engine otomatis mengecualikan baris yang
sudah pernah dihitung di laporan-laporan sebelumnya
(`RecordsProvider.lineHistoryFor()`). UI menampilkan breakdown: **baris
baru** (dihitung ke laporan ini) vs **baris yang sudah pernah dihitung**
(info saja, tidak masuk total).

## Catatan penting: cakupan dataset

Dataset baris mushaf yang di-generate dari engine Python saat ini **hanya
mencakup Juz 1–10 dan 26–30**. Juz 11–25 belum tersedia
(`metadata.juz_missing`). Kalau surah/ayat yang diinput berada di luar
cakupan ini, tombol "Generate Baris" akan menampilkan pesan bahwa mapping
belum tersedia — laporan tahfizh untuk surah tsb tetap bisa dicoba lagi
setelah dataset juz 11–25 digenerate menyusul, lalu menimpa file JSON di
`assets/data/`.

## Hak akses & data (AccessScope)

Aturan akses (`lib/core/access/access_scope.dart`) dihitung dari akun yang
sedang login lalu diterapkan di level data (provider), bukan cuma
menyaring tampilan widget:

- **Admin** — akses global ke semua laporan & santri.
- **Guru Pembimbing** — hanya laporan/santri yang kelas+halaqoh-nya cocok
  persis dengan salah satu *assignment* (pasangan Kelas+Halaqoh) miliknya.
  Satu guru bisa mengampu beberapa kelas & halaqoh berbeda tanpa otomatis
  berarti boleh akses semua kombinasi silang di antaranya.

`SantriRecord` yang ada tidak punya `studentId` (nama/kelas/halaqoh selama
ini teks bebas), jadi scoping dilakukan lewat kecocokan kelas+halaqoh,
bukan lewat `ownerId` (field itu tetap ada untuk keperluan audit/masa
depan).

## Struktur

```
lib/
  app.dart                 # MaterialApp, tema, routing awal (Splash)
  main.dart                # bootstrap: init storage/services/providers
  core/
    access/                 # AccessScope — aturan hak akses admin/guru
    theme/                  # AppTheme, AppColors
    utils/                  # DocxBuilder manual, WeekUtils, text utils
  data/
    local_seed/              # data seed lokal (akun/sekolah awal)
    models/                  # SantriRecord, Folder, UserAccount, School,
                              # Student, KelasHalaqoh, SantriMonthlyRecap, enums
    repositories/            # Auth/School/Student repository (abstraksi,
                              # implementasi Local* siap diganti backend)
    services/                 # QuranEngineService, StorageService,
                              # AppPrefsService, AuthHashService,
                              # ProfilePhotoService, ExportService
  providers/                 # Auth, Records, Folders, Students, Theme
  presentation/
    screens/
      auth/                   # splash, onboarding, login
      home/                   # main_shell (bottom nav 4 tab), beranda
      laporan/                # tab Laporan, buat laporan, pencarian
      folder/                  # detail folder, form folder, pindah folder
      statistik/                # tab Statistik, daftar santri, kehadiran,
                                 # rekap bulanan (+ generate & per pekan)
      record_form/              # sheet input/edit laporan
      export/                    # sheet pilihan format ekspor
      profile/ settings/ about/ notifications/
    widgets/                    # record_card, santri_report_card,
                                 # folder_card, speed_dial_fab, dst.
assets/data/*.json            # dataset baris mushaf (legacy + skema baru)
```

## Ekspor Word (.docx)

File Word dibuat manual (OOXML minimal) lewat `DocxBuilder`
(`lib/core/utils/docx_builder.dart`) — tanpa dependency berat/template,
cukup judul + tabel data. Kalau butuh format Word lebih kompleks (logo,
header/footer halaman, dsb), builder ini bisa dikembangkan lagi.

## Setup Android (signing release)

Sebelum `flutter build apk --release`, generate keystore lalu isi
`android/key.properties` (copy dari `android/key.properties.example`):

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Kalau `key.properties` belum ada, build release tetap jalan tapi pakai
signing debug (fallback) — jangan dipakai buat rilis ke Play Store
sebelum keystore asli diisi.

Icon launcher masih placeholder (kotak teal polos). Ganti pakai
`flutter_launcher_icons` atau replace manual file `ic_launcher.png` di
tiap folder `android/app/src/main/res/mipmap-*`.
