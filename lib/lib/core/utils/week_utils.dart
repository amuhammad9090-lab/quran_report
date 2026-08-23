/// Definisi "pekan" yang dipakai KONSISTEN di seluruh aplikasi (Statistik
/// Pekanan & Profile): pekan mulai hari Senin, penomoran pakai standar
/// ISO-8601 (pekan pertama tahun = pekan yang memuat hari Kamis pertama).
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

  /// Nomor pekan ISO-8601 (1-53).
  static int isoWeekNumber(DateTime date) {
    final d = DateTime.utc(date.year, date.month, date.day);
    final thursday = d.add(Duration(days: 4 - d.weekday));
    final firstDayOfYear = DateTime.utc(thursday.year, 1, 1);
    return ((thursday.difference(firstDayOfYear).inDays) / 7).floor() + 1;
  }

  static String weekLabel(DateTime anyDateInWeek) =>
      'Pekan ke-${isoWeekNumber(anyDateInWeek)}';

  /// Label rentang tanggal "12–18 Agu 2026" untuk header Rekap Pekanan.
  static String rangeLabel(DateTime weekStart) {
    const bulan = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    final end = weekStart.add(const Duration(days: 6));
    final sameMonth = weekStart.month == end.month;
    final startStr = sameMonth
        ? '${weekStart.day}'
        : '${weekStart.day} ${bulan[weekStart.month]}';
    return '$startStr–${end.day} ${bulan[end.month]} ${end.year}';
  }
}
