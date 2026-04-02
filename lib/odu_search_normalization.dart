String normalizeSearchTextShared(String value) {
  if (value.isEmpty) return '';
  var out = value.toLowerCase();
  const replacements = <String, String>{
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
    'à': 'a',
    'è': 'e',
    'ì': 'i',
    'ò': 'o',
    'ù': 'u',
    'â': 'a',
    'ê': 'e',
    'î': 'i',
    'ô': 'o',
    'û': 'u',
    'ã': 'a',
    'õ': 'o',
    'ç': 'c',
    'Á': 'a',
    'É': 'e',
    'Í': 'i',
    'Ó': 'o',
    'Ú': 'u',
    'Ü': 'u',
    'Ñ': 'n',
    'À': 'a',
    'È': 'e',
    'Ì': 'i',
    'Ò': 'o',
    'Ù': 'u',
    'Â': 'a',
    'Ê': 'e',
    'Î': 'i',
    'Ô': 'o',
    'Û': 'u',
    'Ã': 'a',
    'Õ': 'o',
    'Ç': 'c',
  };
  replacements.forEach((key, replacement) {
    out = out.replaceAll(key, replacement);
  });
  out = out.replaceAll('_', ' ').replaceAll('-', ' ');
  out = out.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
  out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
  return out;
}

List<String> tokenizeSearchTextShared(String value) {
  final normalized = normalizeSearchTextShared(value);
  if (normalized.isEmpty) return const [];
  return normalized
      .split(' ')
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
}

String foldSearchTextKeepingLength(String value) {
  if (value.isEmpty) return '';
  var out = value.toLowerCase();
  const replacements = <String, String>{
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
    'à': 'a',
    'è': 'e',
    'ì': 'i',
    'ò': 'o',
    'ù': 'u',
    'â': 'a',
    'ê': 'e',
    'î': 'i',
    'ô': 'o',
    'û': 'u',
    'ã': 'a',
    'õ': 'o',
    'ç': 'c',
  };
  replacements.forEach((key, replacement) {
    out = out.replaceAll(key, replacement);
  });
  out = out
      .split('')
      .map((char) {
        if (RegExp(r'[a-z0-9\s]').hasMatch(char)) {
          return char;
        }
        if (char == '_' || char == '-') {
          return ' ';
        }
        return ' ';
      })
      .join();
  return out;
}

bool hasWordStartMatch(String haystackNormalized, List<String> queryTokens) {
  if (haystackNormalized.isEmpty || queryTokens.isEmpty) {
    return false;
  }
  final words = haystackNormalized.split(' ');
  for (final queryToken in queryTokens) {
    if (queryToken.isEmpty) continue;
    for (final word in words) {
      if (word.startsWith(queryToken)) {
        return true;
      }
    }
  }
  return false;
}
