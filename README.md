# Laporan Hafalan — mirailabs

Aplikasi Flutter untuk mencatat & mengekspor laporan capaian hafalan (tahfizh)
dan bacaan (tahsin) Al-Qur'an santri, lengkap dengan login berbasis peran,
folder pengelompokan laporan, statistik/rekap bulanan, dan sinkronisasi cloud
dua arah dengan **Portal Orang Tua**.

Berjalan di **Android, Web (untuk pengguna iOS/iPhone via Safari), iOS,
macOS, dan Windows** — satu codebase, satu project Firebase (`quran-reportweb`).

## Setup

```bash
flutter pub get
flutter run
```

Tidak perlu `build_runner` — storage lokal pakai Hive `Box<String>` dengan
serialisasi JSON manual (tanpa TypeAdapter codegen).

### Setup Firebase (wajib untuk fitur cloud)

Project ini pakai Firebase project **`quran-reportweb`** (project yang sama
dengan Portal Orang Tua — satu Firestore, dua aplikasi berbeda). Kalau
`lib/firebase_options.dart` belum ada atau perlu di-generate ulang (mis. di
mesin/PC baru):

```bash
flutterfire configure --project=quran-reportweb
```

Pilih platform: android, ios, macos, web, windows. Untuk Android, pastikan
`android/app/google-services.json` ikut ter-copy (file ini **tidak** masuk
git — lihat `.gitignore` — jadi harus di-download ulang dari Firebase
Console tiap setup di mesin baru: Project settings → app `quran_report
(android)` → download `google-services.json`).

Rules & indexes Firestore ada di root repo (`firestore.rules`,
`firestore.indexes.json`), di-deploy lewat:

```bash
firebase deploy --only firestore:rules --project quran-reportweb
```

## Fitur

### Autentikasi & hak akses
- Login berbasis akun (`username`/password) — password di-hash lokal, tidak
  pernah tersimpan plaintext (lihat `AuthHashService`).
- Dua peran: **Admin** (akses global ke semua data) dan **Guru Pembimbing**
  (hanya bisa melihat/mengubah data yang kelas+halaqoh-nya cocok persis
  dengan salah satu *assignment* miliknya — lihat `AccessScope`).
- **Mode Admin (toggle di Profil)** — akun Admin yang JUGA punya assignment
  sendiri (jadi guru pembimbing sekaligus) bisa "matiin" akses globalnya
  lewat satu toggle di halaman Profil, buat fokus kerja di kelas/halaqoh
  sendiri saja (form laporan, folder, statistik) tanpa harus logout-login
  akun beda. Default aktif (perilaku admin klasik: akses semua). Lihat
  `AccessScope.adminModeActive` & `AuthProvider.setAdminModeActive`.
- Onboarding sekali di awal, lalu session login dipulihkan otomatis tiap
  buka app (`AppPrefsService`) sampai user logout.
- Profil: ganti nama tampilan, ganti kata sandi, ganti foto profil (ambil
  dari kamera/galeri via `image_picker`, disalin ke penyimpanan permanen
  app — di web, disimpan sebagai data URI base64).

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
  Nama folder disusun otomatis dari Kelas + Halaqoh yang dipilih.
- Kartu/laporan yang folder tujuannya sudah tidak ada lagi di device ini
  (mis. hasil restore dari Cloud yang folder-nya belum sempat ikut
  ke-backup) ditampilkan lewat banner terpisah "Laporan Tanpa Folder" —
  tetap ketemu & bisa diselamatkan, tidak hilang begitu saja.
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
- Semua angka di tab ini SCOPED mengikuti `AccessScope` yang sedang aktif
  (assignment sendiri, atau semua data kalau Mode Admin aktif).

### Ekspor
- Ekspor ke **PDF**, **Word (.docx)**, **Excel (.xlsx)** — bisa semua
  data, sesuai filter/pencarian aktif, per folder, per Kelas+Halaqoh
  (dengan nama guru pembimbing otomatis di kop laporan), atau hasil
  Generate Rekap Bulanan.
- Setelah file dibuat, otomatis dicoba dibuka dengan aplikasi bawaan
  perangkat; lanjut bisa **Bagikan** (share sheet) atau **Simpan** salinan
  ke penyimpanan perangkat. Di Web, pakai Web Share API dengan fallback
  ke download langsung kalau browser tidak mendukung.

### Sinkronisasi & Backup Cloud (Firestore)
- App ini pakai Firestore project `quran-reportweb` sebagai **mirror /
  cloud backup** dari data lokal (Hive) — bukan sumber utama. Guru
  pembimbing sign-in **anonim** ke Firebase Auth (`isGuruApp()` di
  `firestore.rules`) supaya bisa nulis ke Firestore tanpa perlu akun
  email/password terpisah dari login lokal.
- Perubahan (buat/edit/hapus laporan & folder) otomatis di-mirror ke
  Firestore setiap kali terjadi (`StorageService._mirrorToFirestore`,
  dkk.) — tidak perlu aksi manual buat data yang dibuat SETELAH fitur ini
  aktif.
- **Settings → Backup ke Cloud**: dorong ULANG *semua* laporan & folder
  lokal ke Firestore sekaligus (batch write). Dipakai terutama buat data
  LAMA yang sudah ada sebelum fitur mirror-otomatis ini aktif (mirror
  otomatis di atas cuma nangkep perubahan baru, bukan backfill data lama).
- **Settings → Pulihkan dari Cloud**: tarik balik data dari Firestore ke
  device ini (device baru, ganti HP, dsb). **Discoped** sesuai
  `AccessScope` guru yang sedang login — guru pembimbing biasa cuma
  narik record kelas+halaqoh yang jadi tanggung jawabnya (tidak ikut
  menyedot data guru lain), admin (dengan Mode Admin aktif) narik semua.
  Folder tetap ditarik semua (belum ada scoping untuk `reportFolders`,
  karena field kelas/halaqoh tidak ada di model folder).
- Dialog loading di kedua fitur ini diproteksi `PopScope(canPop: false)`
  supaya tidak sengaja ke-dismiss lewat tombol back Android saat koneksi
  lambat.
- **Settings → Hapus Semua Data**: hapus semua data LOKAL di device ini
  (tidak menghapus data di cloud).

### Integrasi Portal Orang Tua
- **Portal Orang Tua** adalah aplikasi terpisah (repo & Firebase Hosting
  site berbeda) yang dipakai wali santri untuk login (email sintetis
  `username@quranreport-parent.app` + password lewat Firebase Auth
  sungguhan) dan melihat laporan anaknya — **berbagi Firestore project
  yang sama** (`quran-reportweb`) dengan app guru ini.
- Data santri master (`students`) diisi lewat script seed terpisah
  (read-only dari kedua app) — field `nama`/`kelas`/`halaqoh` di situ
  HARUS format persis sama dengan yang diketik guru pembimbing di
  `namaAnak`/`kelas`/`halaqoh` (exact match, case-sensitive) di
  `firestore.rules`, kalau tidak laporan tidak akan kelihatan di Portal
  Orang Tua walau datanya ada.
- **Catatan Orang Tua** (`parentNotes`) — dua arah: wali santri bisa kirim
  catatan singkat ke guru (lewat Portal Ortu), guru melihatnya sebagai
  notifikasi/badge di app ini (`ParentNotesProvider`, sudah discoped
  sesuai kelas+halaqoh guru yang login).

### Lainnya
- Tema Terang / Gelap / Ikuti Sistem (tersimpan otomatis).
- Halaman Notifikasi — menampilkan Catatan Orang Tua yang masuk dari
  Portal Ortu (lihat bagian Integrasi di atas).
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

- **Admin** — akses global ke semua laporan & santri, SELAMA toggle
  **Mode Admin** di Profil sedang aktif (`adminModeActive`, default
  `true`). Kalau dimatikan, admin yang juga punya assignment sendiri
  diperlakukan sama seperti Guru Pembimbing biasa di bawah — berlaku
  konsisten di form laporan, folder, DAN statistik (satu sumber
  kebenaran: `AccessScope.isAdmin`, bukan toggle lokal per-layar lagi).
- **Guru Pembimbing** — hanya laporan/santri yang kelas+halaqoh-nya cocok
  persis dengan salah satu *assignment* (pasangan Kelas+Halaqoh) miliknya.
  Satu guru bisa mengampu beberapa kelas & halaqoh berbeda tanpa otomatis
  berarti boleh akses semua kombinasi silang di antaranya.

`SantriRecord` yang ada tidak punya `studentId` (nama/kelas/halaqoh selama
ini teks bebas), jadi scoping dilakukan lewat kecocokan kelas+halaqoh,
bukan lewat `ownerId` (field itu tetap ada untuk keperluan audit/masa
depan). Aturan yang sama diterapkan ulang di sisi server lewat
`firestore.rules` (`isGuruApp()`, `isAdmin()`) — jadi bukan cuma
penyaringan tampilan client, cloud backup/restore juga tunduk aturan yang
sama (lihat `StorageService.restoreFromFirestore`).

## Struktur

```
lib/
  app.dart                 # MaterialApp, tema, routing awal (Splash)
  main.dart                # bootstrap: init Firebase/storage/services/providers
  firebase_options.dart    # config Firebase per platform (generated, JANGAN edit manual)
  core/
    access/                 # AccessScope — aturan hak akses admin/guru + Mode Admin
    theme/                  # AppTheme, AppColors
    utils/                  # DocxBuilder manual, WeekUtils, text utils
  data/
    local_seed/              # data seed lokal (akun/sekolah awal)
    models/                  # SantriRecord, Folder, UserAccount, School,
                              # Student, KelasHalaqoh, SantriMonthlyRecap, enums
    repositories/            # Auth/School/Student repository (abstraksi,
                              # implementasi Local* siap diganti backend)
    services/                 # QuranEngineService, StorageService (+ mirror
                              # & restore Firestore), AppPrefsService,
                              # AuthHashService, ProfilePhotoService,
                              # ExportService, DownloadNotificationService
      platform_file/          # abstraksi save/share file lintas platform
                              # (_io / _web / _stub conditional import)
  providers/                 # Auth (+ Mode Admin), Records, Folders,
                              # Students, ParentNotes, Theme
  presentation/
    screens/
      auth/                   # splash, onboarding, login
      home/                   # main_shell (bottom nav 4 tab), beranda
      laporan/                # tab Laporan, buat laporan, pencarian
      folder/                  # detail folder, form folder, pindah folder,
                                 # laporan tanpa folder (orphaned)
      statistik/                # tab Statistik, daftar santri, kehadiran,
                                 # rekap bulanan (+ generate & per pekan)
      record_form/              # sheet input/edit laporan
      export/                    # sheet pilihan format ekspor
      profile/ settings/ about/ notifications/
    widgets/                    # record_card, santri_report_card,
                                 # folder_card, speed_dial_fab, dst.
assets/data/*.json            # dataset baris mushaf (legacy + skema baru)
web/                           # entrypoint Flutter Web (index.html, manifest.json)
firebase.json                 # config Hosting (+ cache headers) & Firestore
firestore.rules                # aturan akses Firestore (isGuruApp/isAdmin)
firestore.indexes.json         # index Firestore
scripts/                       # skrip Node.js sekali-pakai (lihat bagian Scripts)
```

## Scripts (Node.js, sekali pakai — bukan Cloud Function)

Folder `scripts/` isinya skrip maintenance data yang dijalankan manual
lewat `node`, pakai Firebase Admin SDK (`service-account.json`, JANGAN
commit ke git). Dipakai kalau ada masalah konsistensi data di Firestore
yang gak bisa/gak praktis dibenerin lewat Console satu-satu:

- `fix_halaqoh.js` — normalisasi field `halaqoh` di collection `students`
  dari format panjang ("Halaqoh B") ke format pendek ("B"), biar match
  sama konvensi yang dipakai app guru di `santriRecords`. Idempotent,
  aman dijalankan ulang.
- `fix_username_auth.js` — ganti email Firebase Auth santri (dipakai
  buat login Portal Ortu) menyusul field `username` di Firestore
  `santriAccounts` yang diubah manual — dua tempat ini TIDAK otomatis
  sinkron kalau diedit langsung dari Firestore Console.

```bash
cd scripts
npm install firebase-admin
node fix_halaqoh.js            # cek dulu tanpa nulis apa-apa (kalau skrip ada mode dry-run)
node fix_username_auth.js <UID> <username_baru>
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
sebelum keystore asli diisi. **Baik `key.properties` maupun file
`.jks`-nya sendiri TIDAK masuk git** — backup manual di tempat aman
(bukan email/chat biasa) kalau pindah/ganti mesin kerja, karena kalau
hilang, APK yang sudah ter-install di HP guru tidak akan pernah bisa
di-update lagi (harus uninstall+install ulang semua).

Icon launcher masih placeholder (kotak teal polos). Ganti pakai
`flutter_launcher_icons` atau replace manual file `ic_launcher.png` di
tiap folder `android/app/src/main/res/mipmap-*`.

## Setup Web (deploy ke Firebase Hosting)

App guru web di-deploy ke Hosting **site terpisah** (`quran-report-guru`)
dari default site project `quran-reportweb` (yang dipakai Portal Orang
Tua) — lihat field `"site"` di `firebase.json`. **Jangan hapus/ubah field
ini** sebelum ngecek `firebase hosting:sites:list --project
quran-reportweb` — deploy ke site yang salah bisa menimpa Portal Ortu.

```bash
flutter build web --release
firebase deploy --only hosting --project quran-reportweb
```

`firebase.json` sudah diset dengan `Cache-Control: no-cache` untuk
`index.html`/`main.dart.js`/`flutter_service_worker.js` (Flutter Web
default TIDAK content-hash nama filenya, jadi CDN/carrier caching yang
agresif bisa bikin user stuck di versi lama walau sudah di-deploy ulang —
lihat komentar di `firebase.json`).
