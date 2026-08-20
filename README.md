# Laporan Hafalan — mirailabs

Aplikasi Flutter untuk mencatat & mengekspor laporan capaian hafalan (tahfizh)
dan bacaan (tahsin) Al-Qur'an santri.

## Setup

```bash
flutter pub get
flutter run
```

Tidak perlu `build_runner` — storage pakai Hive `Box<String>` dengan
serialisasi JSON manual (tanpa TypeAdapter codegen).

## Fitur

- Input laporan per santri: kelas, halaqoh, nama, status (Tahsin/Tahfizh).
- **Tahfizh**: pilih surah + rentang ayat → tombol **Generate Baris**
  (memakai dataset `assets/data/quran_line_dataset.json`, hasil dari
  engine Python `quran_line_ui_juz1_10_26_30.py`) → menampilkan kolom baris
  per halaman mushaf + total baris.
- **Tahsin**: jenjang WAFA 1–5 + halaman (tanpa generate baris).
- Keterangan: Hadir / Izin Sakit / Izin Lomba / Izin Pelatihan / Alpa.
- Ekspor laporan ke **PDF**, **Word (.docx)**, **Excel (.xlsx)** — bisa
  semua data atau sesuai filter/pencarian aktif, lalu dibagikan via share sheet.
- Tema Terang / Gelap / Ikuti Sistem (tersimpan otomatis).
- Halaman Pengaturan & Tentang Aplikasi.

## Engine baris — dual-schema (update terbaru)

Engine (`lib/data/services/quran_engine_service.dart`) sekarang membaca **dua**
dataset sekaligus dan menormalisasi ke satu representasi internal:

- **Legacy** (`quran_line_dataset_legacy_juz1_10.json`) — Juz 1–10, skema lama
  (`segments` dengan `ayah_start`/`ayah_end`). Tidak ada info continuation,
  jadi baris dari sini tidak pernah kena aturan boundary-exclusion di bawah
  (perilaku identik engine versi sebelumnya).
- **Baru** (`quran_line_dataset_juz26_30.json`) — Juz 26–30, skema baru
  (`ayats: [[surah, ayat, ayat_akhir_atau_0]]`, `0` = ayat masih nyambung ke
  baris berikutnya). Mengikuti persis logic `get_lines_for_range()` dari
  `quran_line_ui_juz26_30_COMBINED.py`, termasuk **boundary-continuation rule**:
  baris pertama hasil pencarian dibuang kalau baris itu masih ekor ayat
  sebelumnya DAN ayat awal yang diminta nyambung terus dari baris itu (biar
  gak dobel hitung sama laporan sebelumnya).

**Beda penting dari tool Python referensi**: tool Python itu *juz-scoped*
(user pilih Juz dulu, baru surah dicari di halaman juz itu saja). Karena app
Flutter cuma minta pilih Surah (bukan Juz), engine Dart menggabungkan semua
halaman dari kedua dataset jadi satu daftar baris global. Untuk surah yang
numpang lintas 2 juz (mis. surah 51–57 antara Juz 26/27, surah 58–66 antara
Juz 26/28), ini bikin hasil Dart **lebih lengkap** — nyambung mulus lintas
batas juz — dibanding tool Python yang kepotong di batas halaman juz aktif.
Sudah divalidasi dengan fuzz-test 1400 kombinasi surah/ayat acak: 1383 identik
persis, 17 sisanya semuanya kasus lintas-juz di atas (bukan bug).

## Riwayat baris per santri (anti dobel-hitung)

`SantriRecord` sekarang menyimpan `lineIds` — daftar `line_id` fisik yang
terhitung di laporan tahfizh itu. Saat generate baris baru untuk santri yang
sama (match nama, case-insensitive), engine otomatis mengecualikan baris yang
sudah pernah dihitung di laporan-laporan sebelumnya (`RecordsProvider.lineHistoryFor()`).
UI menampilkan breakdown: **baris baru** (yang dihitung ke laporan ini) vs
**baris yang sudah pernah dihitung** (info saja, tidak masuk total).

Nama anak harus diisi dulu sebelum tombol "Generate Baris" bisa jalan, karena
riwayat baris dicek berdasarkan nama.

## Catatan penting: cakupan dataset

Dataset baris mushaf yang di-generate dari engine Python saat ini **hanya
mencakup Juz 1–10 dan 26–30**. Juz 11–25 belum tersedia (lihat
`metadata.juz_missing` di JSON). Kalau surah/ayat yang diinput berada di
luar cakupan ini, tombol "Generate Baris" akan menampilkan pesan bahwa
mapping belum tersedia — laporan tahfizh untuk surah tsb tetap bisa dicoba
lagi setelah dataset juz 11–25 digenerate menyusul (pakai script Python yang
sama, generate ulang JSON, lalu timpa `assets/data/quran_line_dataset.json`).

## Setup Android (signing release)

Sebelum `flutter build apk --release`, generate keystore lalu isi `android/key.properties`
(copy dari `android/key.properties.example`):

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Kalau `key.properties` belum ada, build release tetap jalan tapi pakai signing debug
(fallback) — jangan dipakai buat rilis ke Play Store sebelum keystore asli diisi.

Icon launcher masih placeholder (kotak teal polos). Ganti pakai `flutter_launcher_icons`
atau replace manual file `ic_launcher.png` di tiap folder `android/app/src/main/res/mipmap-*`.

**Perubahan dari config Android yang kamu kirim (masih sisa dari ExamBrowser):**
- `applicationId`/`namespace` tetap `com.mirailabs.quran_report`, tapi label & proguard
  rule dibetulin ke "Laporan Hafalan" (sebelumnya nyebut `exam_browser`/`exambrowser`).
- Izin kamera, mikrofon, storage legacy, `QUERY_ALL_PACKAGES`, dan deep link
  `exambrowser://` dibuang — gak relevan buat app laporan ini (fully local, gak ada proctoring/webview).
- Plugin `com.google.gms.google-services` dibuang karena gak ada `google-services.json`
  dan gak ada dependency Firebase — kalau dipaksa ikut, build bakal gagal.
- Dependency `play-services-location`, `work-runtime-ktx`, `okhttp`, `gson` dibuang
  (gak dipakai app ini). `multidex` juga dibuang karena minSdk modern udah gak butuh.
- `settings.gradle.kts`: path Flutter SDK yang tadinya hardcode `C:/flutter` diganti baca
  dari `local.properties` (`flutter.sdk=...`) — standar Flutter template, supaya project
  tetap portable kalau dibuka di komputer lain.
- `rootProject.name` diganti dari `exam_browser` jadi `laporan_hafalan`.

## Struktur

```
lib/
  core/            # theme, konstanta, utils (docx builder manual)
  data/
    models/        # SantriRecord, enums
    services/      # QuranEngineService, StorageService, ExportService
  providers/       # RecordsProvider, ThemeProvider
  presentation/
    screens/       # home, record_form (modal sheet), settings, about, export
    widgets/       # record_card, status_badge, filter_sheet, misc_widgets
assets/data/quran_line_dataset.json
```

## Ekspor Word (.docx)

File Word dibuat manual (OOXML minimal) lewat `DocxBuilder`
(`lib/core/utils/docx_builder.dart`) — tanpa dependency berat/template,
cukup judul + tabel data. Kalau butuh format Word lebih kompleks
(logo, header/footer halaman, dsb), builder ini bisa dikembangkan lagi.
