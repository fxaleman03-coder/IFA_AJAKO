import 'dart:convert';
import 'dart:io';

const String _sourcePath = 'assets/odu_content.json';
const String _markdownOutPath = 'build/odu_audit_report.md';
const String _csvOutPath = 'build/odu_audit_report.csv';

const String _oduWordRegexFragment = r'od(?:ù|u|o)';
const String _descripcionWordRegexFragment = r'descripci(?:ó|o)n';

final RegExp _descripcionDelOduHeaderRegex = RegExp(
  r'\b'
  '$_descripcionWordRegexFragment'
  r'\s+del\s+'
  '$_oduWordRegexFragment'
  r'\b',
  caseSensitive: false,
);

const int _previewMaxChars = 800;
const List<_SectionSpec> _sections = <_SectionSpec>[
  _SectionSpec(key: 'nace', label: 'En este Odu nace'),
  _SectionSpec(key: 'descripcion', label: 'Descripcion del Odu'),
  _SectionSpec(key: 'ewes', label: 'Ewes del Odu'),
  _SectionSpec(key: 'eshu', label: 'Eshu del Odu'),
  _SectionSpec(key: 'obrasYEbbo', label: 'Obras del Odu'),
  _SectionSpec(key: 'diceIfa', label: 'Dice Ifa'),
  _SectionSpec(key: 'historiasYPatakies', label: 'Historias/Patakies'),
  _SectionSpec(key: 'rezoYoruba', label: 'Rezo'),
  _SectionSpec(key: 'suyereYoruba', label: 'Suyere'),
  _SectionSpec(key: 'suyereEspanol', label: 'Traduccion de Suyere'),
  _SectionSpec(key: 'rezosYSuyeres', label: 'Rezos y suyeres'),
  _SectionSpec(key: 'refranes', label: 'Refranes'),
];

const Set<String> _stopwords = <String>{
  'a',
  'acaso',
  'ahi',
  'al',
  'algo',
  'algun',
  'alguna',
  'algunas',
  'alguno',
  'algunos',
  'alla',
  'alli',
  'ambas',
  'ambos',
  'ante',
  'antes',
  'aqui',
  'asi',
  'aun',
  'aunque',
  'bajo',
  'bien',
  'cada',
  'casi',
  'como',
  'con',
  'contra',
  'cual',
  'cuales',
  'cualquier',
  'cuando',
  'cuanto',
  'de',
  'del',
  'desde',
  'donde',
  'dos',
  'e',
  'el',
  'ella',
  'ellas',
  'ellos',
  'en',
  'entre',
  'era',
  'eran',
  'eres',
  'es',
  'esa',
  'esas',
  'ese',
  'eso',
  'esos',
  'esta',
  'estaba',
  'estaban',
  'estado',
  'estais',
  'estamos',
  'estan',
  'estar',
  'estas',
  'este',
  'esto',
  'estos',
  'estoy',
  'etc',
  'fue',
  'fueron',
  'ha',
  'hace',
  'hacia',
  'han',
  'hasta',
  'hay',
  'incluso',
  'la',
  'las',
  'le',
  'les',
  'lo',
  'los',
  'mas',
  'me',
  'mi',
  'mis',
  'mismo',
  'mucho',
  'muy',
  'nada',
  'ni',
  'no',
  'nos',
  'nosotros',
  'nuestra',
  'nuestro',
  'o',
  'os',
  'otra',
  'otro',
  'para',
  'pero',
  'poco',
  'por',
  'porque',
  'que',
  'quien',
  'quienes',
  'se',
  'sea',
  'segun',
  'si',
  'sin',
  'sobre',
  'solo',
  'son',
  'su',
  'sus',
  'tal',
  'tambien',
  'te',
  'ti',
  'tiene',
  'tienen',
  'todo',
  'todos',
  'tras',
  'tu',
  'tus',
  'u',
  'un',
  'una',
  'uno',
  'unos',
  'usted',
  'ustedes',
  'y',
  'ya',
  'yo',
};

const List<String> _flagOrder = <String>[
  'NACE_TOO_LONG',
  'DESC_EMPTY_BUT_NACE_LONG',
  'SECTION_OVERLAP',
  'DESC_MARKERS_IN_NACE',
  'LIST_DENSITY_HIGH',
];

void main() {
  final started = DateTime.now();
  final sourceFile = File(_sourcePath);
  if (!sourceFile.existsSync()) {
    stderr.writeln('Source file not found: $_sourcePath');
    exitCode = 1;
    return;
  }

  final raw = sourceFile.readAsStringSync();
  final decoded = jsonDecode(raw);
  if (decoded is! Map) {
    stderr.writeln('Invalid JSON root. Expected object.');
    exitCode = 1;
    return;
  }

  final root = Map<String, dynamic>.from(decoded);
  final oduRaw = root['odu'];
  if (oduRaw is! Map) {
    stderr.writeln('Invalid "odu" structure. Expected object map.');
    exitCode = 1;
    return;
  }

  final oduMap = Map<String, dynamic>.from(oduRaw);
  final results = <_OduAuditResult>[];

  for (final entry in oduMap.entries) {
    final key = entry.key;
    final value = entry.value;
    if (value is! Map) {
      continue;
    }
    final oduEntry = Map<String, dynamic>.from(value);
    final contentRaw = oduEntry['content'];
    if (contentRaw is! Map) {
      continue;
    }
    final content = Map<String, dynamic>.from(contentRaw);
    final displayName = _readString(content, 'name', fallback: key);

    final sectionStats = <String, _SectionStats>{};
    for (final section in _sections) {
      final text = _readString(content, section.key);
      sectionStats[section.key] = _buildSectionStats(text);
    }

    final naceStats = sectionStats['nace'] ?? _SectionStats.empty();
    final descStats = sectionStats['descripcion'] ?? _SectionStats.empty();

    final naceTokenSet = _tokenSet(naceStats.text);
    final descTokenSet = _tokenSet(descStats.text);
    final jaccard = _jaccard(naceTokenSet, descTokenSet);
    final markerHits = _sectionMarkerHitsInNace(naceStats.text);
    final listItems = _countNumberedItems(naceStats.text);
    final listDensity = naceStats.wordCount == 0
        ? 0.0
        : listItems / naceStats.wordCount;

    final flags = <String>[];
    final naceLong = naceStats.wordCount > 450 || naceStats.charCount > 2500;
    if (naceLong) {
      flags.add('NACE_TOO_LONG');
    }

    final descShort = descStats.wordCount < 80 || descStats.charCount < 500;
    if (descShort && naceLong) {
      flags.add('DESC_EMPTY_BUT_NACE_LONG');
    }

    if (jaccard > 0.25) {
      flags.add('SECTION_OVERLAP');
    }

    if (markerHits.isNotEmpty) {
      flags.add('DESC_MARKERS_IN_NACE');
    }

    if (listItems >= 18 || (listItems >= 10 && listDensity > 0.02)) {
      flags.add('LIST_DENSITY_HIGH');
    }

    results.add(
      _OduAuditResult(
        key: key,
        displayName: displayName,
        sectionStats: sectionStats,
        flags: flags,
        markerHits: markerHits,
        jaccardNaceDesc: jaccard,
        naceNumberedItemCount: listItems,
        naceListDensity: listDensity,
      ),
    );
  }

  results.sort((a, b) => a.key.compareTo(b.key));
  final flagged = results.where((row) => row.flags.isNotEmpty).toList();
  final flagCounts = <String, int>{for (final flag in _flagOrder) flag: 0};
  for (final row in flagged) {
    for (final flag in row.flags) {
      flagCounts[flag] = (flagCounts[flag] ?? 0) + 1;
    }
  }

  Directory('build').createSync(recursive: true);
  File(_markdownOutPath).writeAsStringSync(
    _buildMarkdownReport(
      sourcePath: _sourcePath,
      generatedAt: DateTime.now().toUtc(),
      results: results,
      flagged: flagged,
      flagCounts: flagCounts,
    ),
  );
  File(_csvOutPath).writeAsStringSync(_buildCsvReport(results));

  final elapsed = DateTime.now().difference(started);
  stdout.writeln('Odù audited: ${results.length}');
  stdout.writeln('Flagged Odù: ${flagged.length}');
  for (final flag in _flagOrder) {
    stdout.writeln('  $flag: ${flagCounts[flag] ?? 0}');
  }
  stdout.writeln('Markdown report: $_markdownOutPath');
  stdout.writeln('CSV report: $_csvOutPath');
  stdout.writeln('Completed in ${elapsed.inMilliseconds} ms');
}

String _buildMarkdownReport({
  required String sourcePath,
  required DateTime generatedAt,
  required List<_OduAuditResult> results,
  required List<_OduAuditResult> flagged,
  required Map<String, int> flagCounts,
}) {
  final sb = StringBuffer();
  sb.writeln('# Odù Section Audit Report');
  sb.writeln();
  sb.writeln('- Source: `$sourcePath`');
  sb.writeln('- Generated (UTC): `${generatedAt.toIso8601String()}`');
  sb.writeln('- Total Odù audited: **${results.length}**');
  sb.writeln('- Flagged Odù: **${flagged.length}**');
  sb.writeln();
  sb.writeln('## Flag Counts');
  for (final flag in _flagOrder) {
    sb.writeln('- $flag: ${flagCounts[flag] ?? 0}');
  }
  sb.writeln();

  final rankedFlagged = List<_OduAuditResult>.from(flagged)
    ..sort((a, b) {
      final byFlags = b.flags.length.compareTo(a.flags.length);
      if (byFlags != 0) return byFlags;
      final aNace = a.sectionStats['nace']?.wordCount ?? 0;
      final bNace = b.sectionStats['nace']?.wordCount ?? 0;
      return bNace.compareTo(aNace);
    });

  sb.writeln('## Top 10 Flagged Odù');
  if (rankedFlagged.isEmpty) {
    sb.writeln('_No flagged Odù._');
  } else {
    sb.writeln('| # | Odù key | Name | Flags |');
    sb.writeln('|---|---|---|---|');
    for (var i = 0; i < rankedFlagged.length && i < 10; i++) {
      final row = rankedFlagged[i];
      sb.writeln(
        '| ${i + 1} | `${row.key}` | ${_mdInline(row.displayName)} | `${row.flags.join(' | ')}` |',
      );
    }
  }
  sb.writeln();

  sb.writeln('## Detailed Audit');
  for (final row in results) {
    sb.writeln();
    sb.writeln('### `${row.key}` (${_mdInline(row.displayName)})');
    sb.writeln('- Flags: ${row.flags.isEmpty ? 'None' : row.flags.join(', ')}');
    sb.writeln(
      '- Nace/Descripcion Jaccard overlap: `${row.jaccardNaceDesc.toStringAsFixed(3)}`',
    );
    sb.writeln('- Nace list items: `${row.naceNumberedItemCount}`');
    sb.writeln(
      '- Nace list density: `${row.naceListDensity.toStringAsFixed(4)}`',
    );
    sb.writeln(
      '- Marker hits in Nace: ${row.markerHits.isEmpty ? 'None' : row.markerHits.join(', ')}',
    );
    sb.writeln();
    sb.writeln('| Section | Words | Chars | Signature words (top 10) |');
    sb.writeln('|---|---:|---:|---|');
    for (final section in _sections) {
      final stats = row.sectionStats[section.key] ?? _SectionStats.empty();
      sb.writeln(
        '| ${section.label} | ${stats.wordCount} | ${stats.charCount} | ${_mdInline(stats.topWords.join(', '))} |',
      );
    }
    sb.writeln();
    sb.writeln('#### Preview Snippets (first $_previewMaxChars chars)');
    for (final section in _sections) {
      final stats = row.sectionStats[section.key] ?? _SectionStats.empty();
      sb.writeln();
      sb.writeln('- ${section.label}:');
      sb.writeln('```text');
      sb.writeln(_preview(stats.text, maxChars: _previewMaxChars));
      sb.writeln('```');
    }
  }
  return sb.toString();
}

String _buildCsvReport(List<_OduAuditResult> results) {
  final header = <String>[
    'odu_key',
    'display_name',
    'flag_count',
    'flags',
    'jaccard_nace_desc',
    'nace_numbered_items',
    'nace_list_density',
    'marker_hits_in_nace',
    for (final section in _sections) ...<String>[
      '${section.key}_words',
      '${section.key}_chars',
      '${section.key}_top_words',
      '${section.key}_preview',
    ],
  ];
  final rows = <String>[header.map(_csvCell).join(',')];
  for (final result in results) {
    final row = <String>[
      result.key,
      result.displayName,
      result.flags.length.toString(),
      result.flags.join('|'),
      result.jaccardNaceDesc.toStringAsFixed(6),
      result.naceNumberedItemCount.toString(),
      result.naceListDensity.toStringAsFixed(6),
      result.markerHits.join('|'),
      for (final section in _sections) ...<String>[
        (result.sectionStats[section.key]?.wordCount ?? 0).toString(),
        (result.sectionStats[section.key]?.charCount ?? 0).toString(),
        (result.sectionStats[section.key]?.topWords.join('|') ?? ''),
        _preview(
          result.sectionStats[section.key]?.text ?? '',
          maxChars: _previewMaxChars,
        ),
      ],
    ];
    rows.add(row.map(_csvCell).join(','));
  }
  return rows.join('\n');
}

String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';

_SectionStats _buildSectionStats(String rawText) {
  final text = _normalizeNewlines(rawText).trim();
  final words = _wordMatches(text).length;
  final chars = text.length;
  final topWords = _topWords(text, limit: 10);
  return _SectionStats(
    text: text,
    wordCount: words,
    charCount: chars,
    topWords: topWords,
  );
}

List<String> _wordMatches(String text) =>
    RegExp(r"[A-Za-zÁÉÍÓÚÜÑáéíóúüñÀÈÌÒÙàèìòùÂÊÎÔÛâêîôûÃÕãõÇçẸỌṢẹọṣŃṄńṅ']+")
        .allMatches(text)
        .map((m) => m.group(0) ?? '')
        .where((w) => w.isNotEmpty)
        .toList();

List<String> _topWords(String text, {required int limit}) {
  final counts = <String, int>{};
  for (final token in _contentTokens(text)) {
    counts[token] = (counts[token] ?? 0) + 1;
  }
  final sorted = counts.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      if (byCount != 0) return byCount;
      return a.key.compareTo(b.key);
    });
  return sorted.take(limit).map((e) => '${e.key}:${e.value}').toList();
}

Set<String> _tokenSet(String text) => _contentTokens(text).toSet();

Iterable<String> _contentTokens(String text) sync* {
  for (final raw in _wordMatches(text)) {
    final token = _normalizeToken(raw);
    if (token.length < 3) continue;
    if (_stopwords.contains(token)) continue;
    if (RegExp(r'^\d+$').hasMatch(token)) continue;
    yield token;
  }
}

String _normalizeToken(String input) {
  return input
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ì', 'i')
      .replaceAll('î', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ò', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ù', 'u')
      .replaceAll('û', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll('ç', 'c')
      .replaceAll('ẹ', 'e')
      .replaceAll('ọ', 'o')
      .replaceAll('ṣ', 's')
      .replaceAll('ń', 'n')
      .replaceAll('ṅ', 'n');
}

double _jaccard(Set<String> a, Set<String> b) {
  if (a.isEmpty && b.isEmpty) return 0.0;
  final intersection = a.intersection(b).length;
  final union = a.union(b).length;
  if (union == 0) return 0.0;
  return intersection / union;
}

List<String> _sectionMarkerHitsInNace(String naceText) {
  final normalizedRaw = _normalizeNewlines(naceText);
  final normalized = _normalizeToken(normalizedRaw);
  final hits = <String>[];

  if (_descripcionDelOduHeaderRegex.hasMatch(normalizedRaw) ||
      normalized.contains('descripcion')) {
    hits.add('descripcion');
  }
  if (normalized.contains('dice ifa')) {
    hits.add('dice ifa');
  }
  if (normalized.contains('ewes')) {
    hits.add('ewes');
  }
  if (normalized.contains('eshu')) {
    hits.add('eshu');
  }
  if (normalized.contains('obras')) {
    hits.add('obras');
  }
  if (normalized.contains('pataki')) {
    hits.add('pataki');
  }
  if (normalized.contains('historias')) {
    hits.add('historias');
  }
  return hits;
}

int _countNumberedItems(String text) {
  final normalized = _normalizeNewlines(text);
  final lineStarts = RegExp(
    r'^\s*(?:\d{1,3}\s*(?:[.)]|-\s)|[•"\-]\s*\d{1,3}\s*(?:[.)]|-\s))',
    multiLine: true,
  ).allMatches(normalized).length;
  final inlineStarts = RegExp(
    r'\b\d{1,3}\s*(?:[.)]|-\s)',
    multiLine: true,
  ).allMatches(normalized).length;
  return lineStarts + (inlineStarts ~/ 4);
}

String _preview(String text, {required int maxChars}) {
  final normalized = _normalizeNewlines(text).trim();
  if (normalized.isEmpty) return '-';
  if (normalized.length <= maxChars) return normalized;
  return '${normalized.substring(0, maxChars)}...';
}

String _normalizeNewlines(String text) =>
    text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

String _readString(
  Map<String, dynamic> map,
  String key, {
  String fallback = '',
}) {
  final value = map[key];
  if (value is String) return value;
  return fallback;
}

String _mdInline(String text) => text.replaceAll('|', '\\|');

class _SectionSpec {
  const _SectionSpec({required this.key, required this.label});

  final String key;
  final String label;
}

class _SectionStats {
  const _SectionStats({
    required this.text,
    required this.wordCount,
    required this.charCount,
    required this.topWords,
  });

  factory _SectionStats.empty() =>
      const _SectionStats(text: '', wordCount: 0, charCount: 0, topWords: []);

  final String text;
  final int wordCount;
  final int charCount;
  final List<String> topWords;
}

class _OduAuditResult {
  const _OduAuditResult({
    required this.key,
    required this.displayName,
    required this.sectionStats,
    required this.flags,
    required this.markerHits,
    required this.jaccardNaceDesc,
    required this.naceNumberedItemCount,
    required this.naceListDensity,
  });

  final String key;
  final String displayName;
  final Map<String, _SectionStats> sectionStats;
  final List<String> flags;
  final List<String> markerHits;
  final double jaccardNaceDesc;
  final int naceNumberedItemCount;
  final double naceListDensity;
}
