/// Rata-rata nilai (isian "Nilai" di laporan diketik bebas, jadi diambil angka depannya).
class NilaiAverage {
  NilaiAverage._();

  static final _leadingNumber = RegExp(r'^\s*(\d+(?:[.,]\d+)?)');

  /// Angka di awal teks nilai ("85", "87,5", "90 (baik)"); null kalau bukan angka.
  static double? parse(String? raw) {
    final m = _leadingNumber.firstMatch(raw ?? '');
    if (m == null) return null;
    return double.tryParse(m.group(1)!.replaceAll(',', '.'));
  }

  /// Rata-rata semua angka yang bisa dibaca; null kalau tidak ada.
  static double? mean(Iterable<double> values) {
    final list = values.toList();
    if (list.isEmpty) return null;
    return list.fold<double>(0, (a, b) => a + b) / list.length;
  }

  /// Rata-rata nilai harian (satu pekan).
  static double? ofValues(Iterable<String?> raw) =>
      mean([for (final v in raw) if (parse(v) != null) parse(v)!]);

  /// Format: maksimal 1 desimal, koma sebagai pemisah, tanpa ",0".
  static String format(double v) {
    final s = v.toStringAsFixed(1);
    return (s.endsWith('.0') ? s.substring(0, s.length - 2) : s).replaceAll('.', ',');
  }

  /// Teks rata-rata nilai harian; kalau tidak ada angka tapi ada teks (mis. "A"), teksnya digabung koma; '-' kalau kosong.
  static String summaryText(Iterable<String?> raw) {
    final avg = ofValues(raw);
    if (avg != null) return format(avg);
    final texts = [for (final v in raw) if ((v ?? '').trim().isNotEmpty) v!.trim()];
    return texts.isEmpty ? '-' : texts.join(', ');
  }
}
