/// Item search, the same rule as the server (`SearchItems` in LeoCore):
/// every word the user types must appear anywhere in at least one field, so
/// "wheel" matches like *wheel* and "front wheel" finds "Wheel Front 10in".
/// A "*" inside a word matches anything ("wh*l"). Case is ignored.
bool itemMatches(String query, Iterable<String> fields) {
  final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.replaceAll('*', '').isNotEmpty);
  if (words.isEmpty) return true;
  final fs = [for (final f in fields) if (f.isNotEmpty) f.toLowerCase()];
  for (final w in words) {
    final re = RegExp(w.split('*').where((p) => p.isNotEmpty).map(RegExp.escape).join('.*'));
    if (!fs.any(re.hasMatch)) return false;
  }
  return true;
}
