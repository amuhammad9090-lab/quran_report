import '../../data/models/enums.dart';
import '../../data/models/santri_record.dart';

/// Ringkasan 1 hari untuk baris "Rekap Harian", mis. "32 laporan, 22 tahfizh, 18 tahsin, 5 murojaah".
/// Hanya jenis yang ada yang ditulis. Laporan "Tahsin+Tahfizh" dihitung di tahsin DAN tahfizh,
/// jadi jumlah per jenis bisa lebih besar dari jumlah laporan.
String daySummaryText(List<SantriRecord> records) {
  if (records.isEmpty) return 'Belum ada laporan';
  var tahfizh = 0, tahsin = 0, murojaah = 0;
  for (final r in records) {
    switch (r.status) {
      case HafalanStatus.tahfizh:
        tahfizh++;
      case HafalanStatus.tahsin:
        tahsin++;
      case HafalanStatus.tahsinTahfizh:
        tahfizh++;
        tahsin++;
      case HafalanStatus.murojaahTasmi:
        murojaah++;
    }
  }
  return [
    '${records.length} laporan',
    if (tahfizh > 0) '$tahfizh tahfizh',
    if (tahsin > 0) '$tahsin tahsin',
    if (murojaah > 0) '$murojaah murojaah',
  ].join(', ');
}
