// <-- BARU (seluruh file)
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/app_config.dart';
import 'export_service.dart';

/// Kirim ("Deploy") rekap pekanan 1 Kelas+Halaqoh ke Firestore, biar bisa
/// ditampilkan di Portal Ortu — beda dari mirror [SantriRecord] harian
/// yang otomatis jalan tiap simpan laporan (1 dokumen = 1 laporan mentah
/// per hari); ini rekap MINGGUAN yang sudah digabung per-santri (lewat
/// [ExportService.weeklyRowsGroupedBySantriFor]), sengaja manual (tombol
/// "Deploy", bukan otomatis) karena guru yang paling tahu kapan rekap
/// pekan itu "final"/siap dibagikan ke orang tua.
///
/// Disimpan di `schools/{schoolId}/weeklyRecaps/{docId}` — **SATU
/// DOKUMEN PER SANTRI** (BUKAN 1 dokumen isi array semua santri
/// sekelas). Ini keputusan desain PENTING soal privasi: kalau 1 dokumen
/// isinya array seluruh Kelas+Halaqoh, rules Firestore cuma bisa
/// membatasi akses baca level "kelas+halaqoh cocok" -- begitu 1 orang
/// tua boleh baca dokumen itu buat lihat progress anaknya, dia SECARA
/// TEKNIS ikut ke-download juga data (nama, catatan guru, dst) semua
/// anak lain sekelas, cuma disembunyikan di UI doang (bisa kelihatan
/// lewat DevTools/network inspector). Dengan 1 dokumen per santri, rules
/// bisa cocokin `namaAnak` juga (persis pola `santriRecords`, lihat
/// firestore.rules) -- orang tua CUMA BISA baca dokumen anaknya sendiri,
/// dibatasi beneran di data, bukan cuma UI.
///
/// [_docId] tetap DETERMINISTIK (kelas+halaqoh+pekan+bulan+nama) supaya
/// tekan "Deploy" lagi buat pekan yang sama otomatis MENIMPA dokumen
/// lama per santri (bukan numpuk). Field `namaAnakLower` sengaja
/// didenormalisasi (lowercase) di samping `namaAnak` asli -- dipakai
/// query case-insensitive di Portal Ortu, karena `Student.nama` (data
/// master) dan `namaAnak` yang diketik guru di form laporan bisa saja
/// beda kapitalisasi (`.where()` Firestore selalu exact-match).
class WeeklyRecapDeployService {
  WeeklyRecapDeployService._();
  static final WeeklyRecapDeployService instance = WeeklyRecapDeployService._();

  String _slug(String raw) => raw
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  String _docId({
    required String kelas,
    required String halaqoh,
    required int weekIndex,
    required String bulanLabel,
    required String namaAnak,
  }) {
    return '${_slug(kelas)}_${_slug(halaqoh)}_w${weekIndex}_${_slug(bulanLabel)}_${_slug(namaAnak)}';
  }

  /// Lempar exception apa adanya kalau gagal (BEDA dari service mirror
  /// lain yang fire-and-forget/`catchError((_){})`).
  Future<void> deployWeeklyRecap({
    required String kelas,
    required String halaqoh,
    required int weekIndex,
    required String bulanLabel,
    required String rangeLabel,
    required String periode,
    required String? guruPembimbing,
    required List<SantriWeeklyRow> rows,
    required String? deployedByNama,
  }) async {
    if (rows.isEmpty) return;

    // Batch, bukan loop N kali .set() satu-satu -- 1 round-trip network
    // buat semua santri di grup ini, dan Firestore batch bersifat
    // atomik (semua berhasil atau semua gagal bareng, tidak ada
    // kondisi "separuh santri ke-deploy, separuh nggak" kalau koneksi
    // putus di tengah).
    final batch = FirebaseFirestore.instance.batch();
    final col = FirebaseFirestore.instance
        .collection('schools')
        .doc(kSchoolId)
        .collection('weeklyRecaps');

    for (final r in rows) {
      final docId = _docId(
        kelas: kelas,
        halaqoh: halaqoh,
        weekIndex: weekIndex,
        bulanLabel: bulanLabel,
        namaAnak: r.namaAnak,
      );
      batch.set(col.doc(docId), {
        'kelas': kelas,
        'halaqoh': halaqoh,
        'weekIndex': weekIndex,
        'bulanLabel': bulanLabel,
        'rangeLabel': rangeLabel,
        'periode': periode,
        'guruPembimbing': guruPembimbing,
        // <-- BERUBAH: dulu 'rows': [ {...semua santri...} ]. Sekarang
        // field santri ditulis LANGSUNG di root dokumen (1 dokumen =
        // 1 santri = 1 pekan), bukan array lagi.
        'namaAnak': r.namaAnak,
        'namaAnakLower': r.namaAnak.trim().toLowerCase(),
        'tanggalLabel': r.tanggalLabel,
        'capaian': r.capaian,
        'totalBaris': r.totalBaris,
        'keterangan': r.keterangan,
        'catatan': r.catatan,
        'deployedAt': FieldValue.serverTimestamp(),
        'deployedByNama': deployedByNama,
      });
    }

    // <-- BARU: timeout 20 detik. Kalau koneksi lemot/nyangkut, guru
    // ditahan lama nunggu tanpa kepastian ("muter-muter" di UI) --
    // sekarang batas maksimal 20 detik, lewat itu dianggap gagal dengan
    // pesan yang jelas (bukan cuma "loading selamanya"), dan tombol
    // Deploy di UI ([_DeployChip]) balik ke state normal + nampilin
    // SnackBar peringatan lewat catch block yang sudah ada.
    await batch.commit().timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw TimeoutException('Deploy rekap pekanan timeout 20 detik'),
    );
  }
}
