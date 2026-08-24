import 'package:intl/intl.dart';

/// Definisi "pekan" ISO-8601 (Senin-Minggu) — dipakai di halaman Profile
/// buat label "Pekan tanggal sekian". Fitur Rekap Pekanan (yang dulu juga
/// pakai definisi ini) sudah DIHAPUS, diganti Rekap Bulanan → Pekan
/// (lihat bagian "Pekan DALAM BULAN" di bawah).
class WeekUtils {
  WeekUtils._();

  /// Tanggal Senin dari pekan yang memuat [date] (jam dinolkan).
  static DateTime startOfWeek(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  /// Tanggal Minggu dari pekan yang memuat [date].
  static DateTime endOfWeek(DateTime date) =>
      startOfWeek(date).add(const Duration(days: 6));

  /// Nomor pekan ISO-8601 (1-53) — tidak lagi dipakai di [weekLabel] (diganti
  /// tanggal mulai pekan biar lebih gampang dikenali orang), tapi tetap
  /// disimpan kalau nanti ada kebutuhan lain yang butuh angka pekan.
  static int isoWeekNumber(DateTime date) {
    final d = DateTime.utc(date.year, date.month, date.day);
    final thursday = d.add(Duration(days: 4 - d.weekday));
    final firstDayOfYear = DateTime.utc(thursday.year, 1, 1);
    return ((thursday.difference(firstDayOfYear).inDays) / 7).floor() + 1;
  }

  /// Label pekan pakai tanggal mulai (Senin), mis. "Pekan 17 Agustus 2026" —
  /// bukan lagi "Pekan ke-34". Nomor urut pekan dalam setahun kurang
  /// informatif buat guru pembimbing dibanding tanggal aslinya.
  static String weekLabel(DateTime anyDateInWeek) =>
      'Pekan ${DateFormat('d MMMM yyyy', 'id_ID').format(startOfWeek(anyDateInWeek))}';

  // --- Pekan DALAM BULAN (dipakai fitur Laporan/Rekap Bulanan → Pekan) ---
  //
  // Ini definisi pekan yang BERBEDA dari [startOfWeek]/[isoWeekNumber] di
  // atas (yang Senin-Minggu lintas-bulan, cuma dipakai Profile sekarang) —
  // meskipun sekarang keduanya sama-sama Senin-Minggu UTUH.
  //
  // Pekan-dalam-bulan sekarang SELALU 7 hari penuh, Senin-Minggu, TIDAK
  // PERNAH dipotong lagi di batas bulan. Yang dulu dipotong (pekan
  // pertama/terakhir bulan) sekarang malah dianggap "milik" bulan
  // tetangga: satu pekan Senin-Minggu yang lintas dua bulan jadi milik
  // bulan mana pun yang kebagian HARI LEBIH BANYAK (mayoritas dari 7
  // hari — nggak mungkin seri). Misalnya Sab 1 & Min 2 Agustus ikut
  // pekan Senin 27 Juli - Minggu 2 Agustus, yang mayoritas harinya (5
  // dari 7) di bulan Juli → jadi "Pekan 5 Juli", BUKAN "Pekan 1
  // Agustus". Pekan 1 Agustus yang sebenarnya = Senin 3 - Minggu 9.
  // Sebaliknya pekan Senin 31 Agustus - Minggu 6 September mayoritas
  // harinya (6 dari 7) di September → jadi "Pekan 1 September".

  /// Bulan (year+month, tanggal diabaikan/dianggap 1) yang jadi "pemilik"
  /// pekan Senin-Minggu yang memuat [date] — lihat penjelasan di atas.
  static DateTime ownerMonth(DateTime date) {
    final mon = startOfWeek(date);
    final sun = mon.add(const Duration(days: 6));
    if (mon.year == sun.year && mon.month == sun.month) {
      return DateTime(mon.year, mon.month);
    }
    final lastDayOfMonMonth = DateTime(mon.year, mon.month + 1, 0).day;
    final daysInMonMonth = lastDayOfMonMonth - mon.day + 1;
    final daysInSunMonth = 7 - daysInMonMonth;
    return daysInMonMonth >= daysInSunMonth
        ? DateTime(mon.year, mon.month)
        : DateTime(sun.year, sun.month);
  }

  /// Tanggal Senin dari pekan PERTAMA yang dimiliki bulan [year]-[month].
  static DateTime _firstOwnedMonday(int year, int month) {
    final firstDay = DateTime(year, month, 1);
    final mon0 = startOfWeek(firstDay);
    final owner = ownerMonth(firstDay);
    return (owner.year == year && owner.month == month)
        ? mon0
        : mon0.add(const Duration(days: 7));
  }

  /// Nomor pekan (Senin-Minggu, pekan penuh 7 hari) DALAM BULAN yang
  /// MEMILIKI pekan dari [date] — perhatikan bulan pemilik itu bisa beda
  /// dari `date.month` sendiri buat 1-2 hari di ujung bulan (lihat
  /// [ownerMonth]).
  static int weekOfMonth(DateTime date) {
    final mon = startOfWeek(date);
    final owner = ownerMonth(date);
    final firstMon = _firstOwnedMonday(owner.year, owner.month);
    return (mon.difference(firstMon).inDays ~/ 7) + 1;
  }

  /// Jumlah pekan dalam bulan [month] (4-5, tergantung jumlah hari di
  /// bulan itu DAN hari apa tanggal 1-nya jatuh).
  static int weeksInMonth(DateTime month) {
    var cursor = _firstOwnedMonday(month.year, month.month);
    var count = 0;
    while (true) {
      final owner = ownerMonth(cursor);
      if (owner.year != month.year || owner.month != month.month) break;
      count++;
      cursor = cursor.add(const Duration(days: 7));
    }
    return count;
  }

  /// Tanggal awal & akhir pekan ke-[weekIndex] (1-based, Senin-Minggu,
  /// SELALU 7 hari penuh — boleh lintas ke bulan tetangga) milik bulan
  /// [month].
  static MonthWeekRange monthWeekRange(DateTime month, int weekIndex) {
    final start = _firstOwnedMonday(month.year, month.month)
        .add(Duration(days: (weekIndex - 1) * 7));
    return MonthWeekRange(start: start, end: start.add(const Duration(days: 6)));
  }

  /// Label pendek "Pekan 1", "Pekan 2", dst.
  static String monthWeekLabel(int weekIndex) => 'Pekan $weekIndex';

  static const _bulanPendek = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  /// Label rentang tanggal singkat buat [range], mis. "3–9 Agu" (dalam
  /// satu bulan) atau "27 Jul – 2 Agu" (pekan yang lintas bulan, sekarang
  /// bisa terjadi karena pekan tidak dipotong lagi di batas bulan — lihat
  /// catatan di atas). Sertakan nama bulan di kedua sisi kalau lintas
  /// bulan biar nggak ambigu.
  static String rangeLabel(MonthWeekRange range) {
    final sameMonth = range.start.year == range.end.year && range.start.month == range.end.month;
    if (range.start.day == range.end.day && sameMonth) {
      return '${range.start.day} ${_bulanPendek[range.start.month]}';
    }
    if (sameMonth) {
      return '${range.start.day}–${range.end.day} ${_bulanPendek[range.end.month]}';
    }
    return '${range.start.day} ${_bulanPendek[range.start.month]} – '
        '${range.end.day} ${_bulanPendek[range.end.month]}';
  }
}

/// Rentang tanggal sederhana (dipakai [WeekUtils.monthWeekRange]) — bukan
/// pakai `DateTimeRange` dari Flutter Material supaya utils ini tetap
/// ringan/tidak menambah dependency baru di file non-widget ini.
class MonthWeekRange {
  final DateTime start;
  final DateTime end;
  const MonthWeekRange({required this.start, required this.end});
}