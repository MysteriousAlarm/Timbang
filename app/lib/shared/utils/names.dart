/// Loose key for matching names typed by people: case, spaces, accents and punctuation
/// do not matter ("Pechay (Native)" == "pechay native", "Alfonso Castañeda" == "alfonso castaneda").
String normKey(String s) => s
    .toLowerCase()
    .replaceAll('ñ', 'n')
    .replaceAll(RegExp('[áàâä]'), 'a')
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[íìîï]'), 'i')
    .replaceAll(RegExp('[óòôö]'), 'o')
    .replaceAll(RegExp('[úùûü]'), 'u')
    .replaceAll(RegExp('[^a-z0-9]'), '');

/// Index of the first row (among the first [scan]) that looks like the header, so title rows
/// such as "PROVINCE OF NUEVA VIZCAYA / Price monitoring" above it are skipped.
int findHeaderRow(
  List<List<String>> table,
  bool Function(List<String> keys) isHeader, {
  int scan = 15,
}) {
  for (var i = 0; i < table.length && i < scan; i++) {
    if (isHeader([for (final c in table[i]) normKey(c)])) return i;
  }
  return 0;
}
