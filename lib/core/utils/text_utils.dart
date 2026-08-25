/// Normalisasi nilai `halaqoh` mentah dari sumber data (seed, input lama,
/// dsb).
library;

String normalizeHalaqoh(String raw) {
  final trimmed = raw.trim();
  final match = RegExp(r'^halaqoh\s*', caseSensitive: false).firstMatch(trimmed);
  if (match == null) return trimmed;
  return trimmed.substring(match.end).trim();
}
