/// Titik masuk TUNGGAL buat resolve foto profil (`UserAccount.photoPath`)
/// jadi `ImageProvider` yang bisa dipakai `CircleAvatar.backgroundImage` —
/// dipakai di `profile_screen.dart`, `edit_profile_screen.dart`, dan
/// `beranda_tab.dart`, supaya TIDAK ADA satupun dari ketiganya yang
/// menyentuh `dart:io`/`File` langsung (yang bikin app gagal DI-COMPILE
/// untuk target Web, bukan cuma error runtime).
///
/// [photoPath] bisa berisi salah satu dari:
/// - path file asli (hasil `ProfilePhotoService` di platform io) ->
///   dibaca lewat `FileImage` (cuma tersedia di [avatar_image_provider_io]).
/// - data URI base64 `data:image/...;base64,...` (hasil
///   `ProfilePhotoService` di Web, lihat `profile_photo_service_web.dart`)
///   -> di-decode jadi `MemoryImage`, jalan di SEMUA platform.
/// - null/kosong -> null (pemanggil fallback ke inisial nama).
///
/// Lihat juga catatan `dart.library.html` vs `dart.library.js_interop` di
/// `platform_file/file_actions.dart` — kondisi yang sama berlaku di sini.
library;
export 'avatar_image_provider_stub.dart'
    if (dart.library.io) 'avatar_image_provider_io.dart'
    if (dart.library.html) 'avatar_image_provider_web.dart';
