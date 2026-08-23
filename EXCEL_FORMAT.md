# Format Excel — Master Data (Accounts & Students)

Dokumen ini mendeskripsikan format Excel yang dipakai sebagai sumber data
administratif (bukan dibaca langsung oleh Flutter — lihat alur di bawah).

```
EXCEL  →  Converter/Import  →  JSON  →  App / Backend
```

Saat ini (fase lokal/prototype), hasil konversi JSON-nya ditaruh sebagai
konstanta Dart di `lib/data/local_seed/local_seed_data.dart`
(`kSeedAccountsJson`, `kSeedStudentsJson`, `kSeedSchoolsJson`). Begitu
Excel asli & proses konversinya siap, tinggal replace isi 3 konstanta itu
— seluruh kode di atasnya (`LocalAuthRepository`, dst.) tidak perlu
berubah.

## Sheet 1 — `Accounts`

| Kolom | Wajib | Keterangan |
|---|---|---|
| `id` | ya | unik, mis. `usr_001` |
| `username` | ya | unik, huruf kecil, dipakai login |
| `displayName` | ya | nama yang ditampilkan, mis. `Ustadz Ahmad` |
| `password` | ya | password SEMENTARA plaintext DI EXCEL SAJA — converter WAJIB mengubahnya jadi `passwordHash` sebelum masuk JSON/app. Jangan pernah commit password plaintext ke JSON/repo. |
| `role` | ya | `admin` atau `musyrif`/`guru_alquran` (dua-duanya diterima, disamakan jadi musyrif) |
| `kelas` | musyrif: ya | dipisah koma kalau lebih dari satu, mis. `7A,7B` |
| `halaqoh` | musyrif: ya | dipisah koma, **URUTANNYA HARUS SEJAJAR DENGAN KOLOM `kelas`** — lihat peringatan di bawah |

### ⚠️ Kolom `kelas` & `halaqoh` adalah PASANGAN, bukan daftar independen

Kalau satu guru mengampu lebih dari satu kelas/halaqoh, item ke-N di
kolom `kelas` HARUS berpasangan dengan item ke-N di kolom `halaqoh` —
posisinya menentukan assignment. Ini BUKAN "kelas manapun × halaqoh
manapun".

Contoh (data asli):

```
kelas:   VII Jeddah, VIII Baghdad, VIII Kairo, IX Gazza
halaqoh: Halaqoh B,  Halaqoh C,    Halaqoh A,  Halaqoh C
```

Artinya guru ini mengampu **4 assignment spesifik**:
`(VII Jeddah, Halaqoh B)`, `(VIII Baghdad, Halaqoh C)`,
`(VIII Kairo, Halaqoh A)`, `(IX Gazza, Halaqoh C)` — dia **TIDAK**
mengampu `(VII Jeddah, Halaqoh C)` walau "VII Jeddah" dan "Halaqoh C"
sama-sama muncul di barisnya.

Converter WAJIB menghasilkan array `assignments` berpasangan (bukan dua
array kelas/halaqoh terpisah):

```json
"assignments": [
  {"kelas": "VII Jeddah", "halaqoh": "Halaqoh B"},
  {"kelas": "VIII Baghdad", "halaqoh": "Halaqoh C"},
  {"kelas": "VIII Kairo", "halaqoh": "Halaqoh A"},
  {"kelas": "IX Gazza", "halaqoh": "Halaqoh C"}
]
```

**Kalau jumlah item di kolom `kelas` dan `halaqoh` tidak sama panjang,
itu data error — converter harus menolak baris itu, bukan menebak
pasangannya.**

Contoh baris (satu assignment saja):

```
usr_001 | ahmad | Ustadz Ahmad | password-sementara | musyrif | 7A | Halaqoh 01
```

Hasil konversi ke JSON:

```json
{
  "id": "usr_001",
  "username": "ahmad",
  "displayName": "Ustadz Ahmad",
  "passwordHash": "<hasil hash, BUKAN plaintext>",
  "role": "musyrif",
  "assignments": [
    {"kelas": "7A", "halaqoh": "Halaqoh 01"}
  ]
}
```

## Sheet 2 — `Students`

| Kolom | Wajib | Keterangan |
|---|---|---|
| `id` | ya | unik, mis. `santri_001` |
| `nama` | ya | nama lengkap santri |
| `kelas` | ya | satu kelas per baris (bukan list) |
| `halaqoh` | ya | satu halaqoh per baris |

Contoh baris:

```
santri_001 | Ahmad Fauzan | 7A | Halaqoh 01
santri_002 | Ali Akbar    | 7A | Halaqoh 01
```

## Aturan Access Control

Seorang musyrif hanya bisa melihat/mengelola santri yang kombinasi
kelas+halaqoh-nya cocok PERSIS dengan salah satu `assignments` miliknya
(pasangan, bukan kelas manapun × halaqoh manapun — lihat peringatan di
atas):

```
(student.kelas, student.halaqoh) ∈ user.assignments
```

Lihat `lib/core/access/access_scope.dart` untuk implementasinya.

## Catatan Migrasi ke Backend

Saat backend sudah ada:
1. Proses konversi Excel → JSON tetap sama, tapi hasilnya dikirim ke
   endpoint import backend (bukan ditaruh sebagai konstanta Dart).
2. `LocalAuthRepository`/`LocalStudentRepository`/`LocalSchoolRepository`
   diganti implementasi `Api...Repository` yang memanggil endpoint
   tersebut. Tidak ada perubahan di provider/UI.
3. Verifikasi password HARUS dipindah ke server (lihat catatan security
   di `lib/data/services/auth_hash_service.dart`).
