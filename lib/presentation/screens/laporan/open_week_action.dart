// <-- BARU: seluruh file ini.
//
// Sebelumnya logic "buka form laporan buat kartu Pekan N" ini di-copy-paste
// PERSIS SAMA di 3 tempat (laporan_tab.dart, search_results_screen.dart,
// folder_detail_screen.dart) — sekarang disatukan di sini biar sekali
// dibenerin, kepakai di semua tempat.
//
// SEKALIAN bug fix: dulu kalau pekan-nya PEKAN BERJALAN, tap kartu Pekan N
// SELALU langsung buka/buatkan laporan HARI INI — walau santri ini SUDAH
// punya laporan di hari lain pekan ini yang belum "ditutup" hari ini juga.
// Skenario nyata yang kejadian: guru buat laporan Selasa (ternyata santri
// TIDAK SETORAN), besoknya Rabu santri bilang dia SEBENARNYA setoran —
// guru tap lagi kartu Pekan itu buat "membetulkan", tapi karena sekarang
// sudah hari Rabu, yang kebuka malah form laporan BARU buat hari Rabu
// (kosong), BUKAN laporan Selasa yang mau dibetulkan. Guru isi form itu
// mengira sudah "mengedit", padahal barusan bikin laporan Rabu yang
// terpisah — laporan Selasa "Tidak Setoran" yang salah itu tetap ada.
// Hasilnya di Rekap Pekanan kelihatan "nambah 1" (Selasa + Rabu, padahal
// maksudnya cuma 1 laporan yang dibetulkan).
//
// Sekarang: kalau situasinya ambigu begini (ada laporan hari lain pekan
// ini + belum ada laporan hari ini), guru DITANYA dulu mau isi laporan
// hari ini atau edit salah satu laporan hari lain itu — bukan langsung
// nebak. Kalau tidak ambigu (santri belum punya laporan lain di pekan
// ini), perilakunya SAMA PERSIS seperti sebelumnya (langsung ke hari ini,
// tanpa friksi tambahan).
//
// <-- BERUBAH: bug yang sama ternyata ada juga di jalur PEKAN YANG SUDAH
// LEWAT — sebelumnya cabang itu SELALU langsung buka/buatkan laporan di
// Senin (range.start) tanpa pernah cek laporan lain di pekan itu. Kalau
// santri ternyata sudah punya laporan di hari lain pekan lalu itu (mis.
// Selasa & Kamis) dan Senin-nya sendiri belum ada laporan, tap kartu
// Pekan bisa kebablasan BIKIN laporan baru (kosong) di Senin, padahal
// yang mau dibetulkan itu laporan Selasa/Kamis-nya. Sekarang "hari
// default" pekan itu (hari ini untuk pekan berjalan, Senin untuk pekan
// lalu) dan "laporan hari lain di pekan itu" dihitung dengan cara yang
// sama buat DUA-duanya, jadi sheet pilihan yang sama muncul di kedua
// kasus. Kasus umum (0-1 laporan di pekan itu, pas di hari default) TETAP
// langsung kebuka tanpa friksi tambahan — perilaku lama, tidak berubah.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/week_utils.dart';
import '../../../data/models/santri_record.dart';
import '../../../providers/records_provider.dart';
import '../../widgets/status_badge.dart';
import '../record_form/record_form_sheet.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Buka form laporan untuk kartu Pekan [weekIndex] milik [card] —
/// [initialFolderId] dipakai kalau ternyata belum ada laporan sama sekali
/// buat santri ini di hari yang dibuka (kartu baru dibuatkan di folder
/// ini).
Future<void> openWeekForSantri(
  BuildContext context,
  SantriCardInfo card,
  int weekIndex, {
  String? initialFolderId,
}) async {
  final provider = context.read<RecordsProvider>();
  final now = DateTime.now();
  // Bulan PEMILIK pekan hari ini (bisa beda dari now.month di 1-2 hari
  // ujung bulan) — lihat WeekUtils.ownerMonth.
  final thisMonth = WeekUtils.ownerMonth(now);
  final currentWeek = WeekUtils.weekOfMonth(now);

  final range = WeekUtils.monthWeekRange(thisMonth, weekIndex);
  final today = DateTime(now.year, now.month, now.day);
  final isCurrentWeek = weekIndex == currentWeek &&
      !today.isBefore(range.start) &&
      !today.isAfter(range.end);

  // "Hari default" pekan ini — hari ini kalau pekan yang dibuka itu pekan
  // berjalan, atau Senin (range.start) kalau pekan yang sudah lewat. Ini
  // hari yang dibuka LANGSUNG kalau ternyata gak ada laporan lain yang
  // bikin ambigu (lihat komentar panjang di atas).
  final defaultDay = isCurrentWeek ? today : range.start;
  final defaultDayExisting = provider.recordForSantriOnDate(card.nama, defaultDay);

  // Laporan santri ini di hari LAIN pekan itu (di luar hari default) —
  // buat pekan berjalan cuma hari SEBELUM hari ini yang relevan (hari
  // setelah hari ini pasti belum ada laporan apa pun, wajar). Buat pekan
  // yang sudah lewat, SEMUA hari di rentang pekan itu selain Senin
  // relevan (gak ada konsep "belum sampai harinya").
  final otherRecordsThisWeek = isCurrentWeek
      ? provider.recordsForSantriInRange(
          card.nama,
          range.start,
          today.subtract(const Duration(days: 1)),
        )
      : provider
          .recordsForSantriInRange(card.nama, range.start, range.end)
          .where((r) => !DateUtils.isSameDay(r.tanggal, defaultDay))
          .toList();

  // Kasus umum (paling sering terjadi): belum ada laporan lain di pekan
  // ini selain (mungkin) hari default -> langsung buka/isi hari default,
  // TANPA friksi tambahan — perilaku lama, tidak berubah.
  if (otherRecordsThisWeek.isEmpty) {
    _openExact(context, provider, card, defaultDay, initialFolderId, existing: defaultDayExisting);
    return;
  }

  if (!context.mounted) return;
  final pilihan = await _pilihHariSheet(
    context,
    card: card,
    defaultDay: defaultDay,
    isCurrentWeek: isCurrentWeek,
    defaultDayExisting: defaultDayExisting,
    otherDaysThisWeek: otherRecordsThisWeek,
  );
  if (pilihan == null || !context.mounted) return;

  if (pilihan.pilihHariIni) {
    _openExact(context, provider, card, defaultDay, initialFolderId, existing: defaultDayExisting);
  } else if (pilihan.record != null) {
    showRecordFormSheet(context, existing: pilihan.record, lockIdentity: true);
  }
}

void _openExact(
  BuildContext context,
  RecordsProvider provider,
  SantriCardInfo card,
  DateTime date,
  String? initialFolderId, {
  SantriRecord? existing,
}) {
  final found = existing ?? provider.recordForSantriOnDate(card.nama, date);
  if (found != null) {
    showRecordFormSheet(context, existing: found, lockIdentity: true);
    return;
  }
  showRecordFormSheet(
    context,
    presetKelas: card.kelas,
    presetHalaqoh: card.halaqoh,
    presetNama: card.nama,
    presetTanggal: date,
    lockIdentity: true,
    initialFolderId: initialFolderId,
  );
}

class _PilihHari {
  final bool pilihHariIni;
  final SantriRecord? record;
  const _PilihHari.hariIni() : pilihHariIni = true, record = null;
  const _PilihHari.laporan(SantriRecord r) : pilihHariIni = false, record = r;
}

Future<_PilihHari?> _pilihHariSheet(
  BuildContext context, {
  required SantriCardInfo card,
  required DateTime defaultDay,
  required bool isCurrentWeek,
  required SantriRecord? defaultDayExisting,
  required List<SantriRecord> otherDaysThisWeek,
}) {
  // <-- BARU: wording sheet dibedain dikit tergantung [isCurrentWeek] —
  // buat pekan berjalan tetap "hari ini" persis kayak sebelumnya (biar
  // gak ada yang berubah dari sisi guru buat kasus yang udah bener), buat
  // pekan yang sudah lewat pakai nama hari + tanggal eksplisit (mis.
  // "Senin, 7 September") soalnya "hari ini" gak pas buat pekan lalu.
  final defaultDayLabel = isCurrentWeek
      ? 'hari ini'
      : DateFormat('EEEE, d MMMM', 'id_ID').format(defaultDay);
  final defaultDayShort = isCurrentWeek
      ? 'hari ini'
      : DateFormat('EEEE', 'id_ID').format(defaultDay);

  return showModalBottomSheet<_PilihHari>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isCurrentWeek ? 'Pekan ini sudah ada laporan lain' : 'Pekan itu sudah ada laporan lain',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '${card.nama} sudah punya laporan di hari lain pekan ${isCurrentWeek ? "ini" : "itu"}. '
                'Mau isi laporan $defaultDayLabel, atau betulkan salah satu laporan di bawah?',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 12),
              for (final r in otherDaysThisWeek)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    title: Text(DateFormat('EEEE, d MMMM', 'id_ID').format(r.tanggal)),
                    subtitle: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        StatusBadge(status: r.status),
                        KeteranganChip(keterangan: r.keterangan, compact: true),
                      ],
                    ),
                    trailing: const Icon(LucideIcons.penLine),
                    onTap: () => Navigator.pop(ctx, _PilihHari.laporan(r)),
                  ),
                ),
              const SizedBox(height: 4),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.pop(ctx, const _PilihHari.hariIni()),
                icon: Icon(defaultDayExisting != null ? LucideIcons.penLine : LucideIcons.circlePlus),
                label: Text(
                  defaultDayExisting != null
                      ? 'Lanjut edit laporan $defaultDayShort (${DateFormat('d MMMM', 'id_ID').format(defaultDay)})'
                      : 'Buat laporan baru untuk $defaultDayShort (${DateFormat('d MMMM', 'id_ID').format(defaultDay)})',
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}
