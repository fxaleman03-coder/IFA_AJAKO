import 'dart:convert';
import 'dart:io';

const String _sourceJsonPath = 'assets/odu_content_patched.json';
const String _buildOutputPath = 'build/odu_content_patched.json';
const String _publishOutputPath = 'assets/odu_content_patched.json';
const String _reportCsvPath = 'build/odu_order_from_pdf_report.csv';
const String _reportMdPath = 'build/odu_order_from_pdf_report.md';

final RegExp _pdfLinePattern = RegExp(r'^\s*(\d{1,3})\.\s*(.+?)\s*$');
final RegExp _headerWithNumberPattern = RegExp(
  r'ESTE\s+ES\s+EL\s+OD(?:U|O|Ù)\s*(?:#|N(?:O|º|°|\.?)?)\s*(\d{1,3})\s+DEL\s+ORDEN\s+SEÑORIAL\s+DE\s+IF[ÁA]\.?',
  caseSensitive: false,
);
final RegExp _headerBlankPattern = RegExp(
  r'ESTE\s+ES\s+EL\s+OD(?:U|O|Ù)\s*(?:#|N(?:O|º|°|\.?)?)\s*DEL\s+ORDEN\s+SEÑORIAL\s+DE\s+IF[ÁA]\.?',
  caseSensitive: false,
);
final RegExp _finalHeaderPattern = RegExp(
  r'ESTE\s+ES\s+EL\s+ODU\s*#\s*(\d{1,3})\s+DEL\s+ORDEN\s+SEÑORIAL\s+DE\s+IFÁ\.',
  caseSensitive: false,
);

const Set<String> _ignoreTokens = <String>{
  'DE',
  'DEL',
  'LA',
  'EL',
  'LOS',
  'LAS',
  'EN',
  'ESTE',
  'ES',
  'ODU',
  'ODO',
  'ODUU',
  'IFA',
  'MEJI',
  'MEYI',
};

const Map<String, String> _familyBaseAliasToCanonical = <String, String>{
  // Canonical family bases
  'OGBE': 'OGBE',
  'OYEKU': 'OYEKU',
  'OYEKUN': 'OYEKU',
  'OYECUN': 'OYEKU',
  'IWORI': 'IWORI',
  'ODI': 'ODI',
  'IROSUN': 'IROSUN',
  'IROSO': 'IROSUN',
  'OWONRIN': 'OWONRIN',
  'OJUANI': 'OWONRIN',
  'OJUANO': 'OWONRIN',
  'OBARA': 'OBARA',
  'OKANRAN': 'OKANRAN',
  'OKANA': 'OKANRAN',
  'OGUNDA': 'OGUNDA',
  'OSA': 'OSA',
  'IKA': 'IKA',
  'OTUURUPON': 'OTUURUPON',
  'OTURUPON': 'OTUURUPON',
  'OTURU': 'OTUURUPON',
  'OTRUPON': 'OTUURUPON',
  'OTURA': 'OTURA',
  'IRETE': 'IRETE',
  'OSE': 'OSE',
  'OSHE': 'OSE',
  'OFUN': 'OFUN',
  // Extra tolerated forms for principal names
  'EJIOGBE': 'OGBE',
  'BABA': 'OGBE',
};

class _PdfEntry {
  const _PdfEntry({
    required this.number,
    required this.rawName,
    required this.normalizedName,
    required this.familyBaseCanonical,
  });

  final int number;
  final String rawName;
  final String normalizedName;
  final String familyBaseCanonical;
}

class _MatchResolution {
  const _MatchResolution({
    required this.method,
    required this.confidence,
    this.entry,
    this.notes = '',
  });

  final String method; // exact|family_meji_fallback|none
  final String confidence; // HIGH|MED|NONE
  final _PdfEntry? entry;
  final String notes;
}

class _Row {
  const _Row({
    required this.oduKey,
    required this.displayName,
    required this.oldHeaderNumber,
    required this.newNumber,
    required this.matchMethod,
    required this.pdfLineMatched,
    required this.confidence,
    required this.action,
    required this.descripcionBeforeLen,
    required this.descripcionAfterLen,
    required this.notes,
    required this.familyBase,
    required this.updated,
  });

  final String oduKey;
  final String displayName;
  final int? oldHeaderNumber;
  final int? newNumber;
  final String matchMethod;
  final String pdfLineMatched;
  final String confidence;
  final String action; // add|replace|fill_blank|none|skip_unmatched
  final int descripcionBeforeLen;
  final int descripcionAfterLen;
  final String notes;
  final String familyBase;
  final bool updated;
}

void main(List<String> args) {
  final pdfPath = _resolvePdfPath(args);
  if (pdfPath == null) {
    stderr.writeln(
      'PDF not found. Expected one of:\n'
      '- /mnt/data/Lista de los 256-Odu-Ifa.pdf\n'
      '- ~/Downloads/Lista de los 256-Odu-Ifa.pdf\n'
      'Or pass explicit PDF path as first argument.',
    );
    exitCode = 1;
    return;
  }

  final sourceFile = File(_sourceJsonPath);
  if (!sourceFile.existsSync()) {
    stderr.writeln('Missing source JSON: $_sourceJsonPath');
    exitCode = 1;
    return;
  }

  final pdfText = _extractPdfText(pdfPath);
  if (pdfText == null) {
    stderr.writeln('Could not extract text from PDF: $pdfPath');
    exitCode = 1;
    return;
  }

  final pdfEntries = _parsePdfEntries(pdfText);
  if (pdfEntries.isEmpty) {
    stderr.writeln('No ordered Odù entries parsed from PDF.');
    exitCode = 1;
    return;
  }

  final pdfByNormalizedName = <String, List<_PdfEntry>>{};
  final pdfMejiByCanonicalFamily = <String, List<_PdfEntry>>{};
  for (final entry in pdfEntries) {
    pdfByNormalizedName.putIfAbsent(entry.normalizedName, () => <_PdfEntry>[]).add(entry);
    final parts = entry.normalizedName.split(' ');
    final isMejiEntry = parts.length == 2 && (parts[1] == 'MEJI' || parts[1] == 'MEYI');
    if (isMejiEntry) {
      pdfMejiByCanonicalFamily
          .putIfAbsent(entry.familyBaseCanonical, () => <_PdfEntry>[])
          .add(entry);
    }
  }

  final decoded = jsonDecode(sourceFile.readAsStringSync());
  if (decoded is! Map) {
    stderr.writeln('Invalid JSON root in $_sourceJsonPath');
    exitCode = 1;
    return;
  }

  final root = Map<String, dynamic>.from(decoded);
  final rawOdu = root['odu'];
  if (rawOdu is! Map) {
    stderr.writeln('Invalid JSON: root["odu"] must be an object.');
    exitCode = 1;
    return;
  }

  final oduMap = Map<String, dynamic>.from(rawOdu);
  final beforeCount = oduMap.length;
  final rows = <_Row>[];

  var updatedExact = 0;
  var updatedFallback = 0;
  var unchanged = 0;
  var unmatched = 0;
  var conflicts = 0;

  for (final entry in oduMap.entries) {
    final oduKey = entry.key;
    final node = _mapFrom(entry.value);
    final content = _mapFrom(node['content']);
    final displayName = (content['name'] as String?) ?? '';

    final descripcionRaw = (content['descripcion'] as String?) ?? '';
    final descripcion = descripcionRaw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final descripcionBeforeLen = descripcion.length;
    final oldHeaderNumber = _extractOldHeaderNumber(descripcion);

    final resolution = _resolveMatch(
      oduKey: oduKey,
      displayName: displayName,
      pdfByNormalizedName: pdfByNormalizedName,
      pdfMejiByCanonicalFamily: pdfMejiByCanonicalFamily,
    );

    final familyBase = extractFamilyBase(displayName.isNotEmpty ? displayName : oduKey) ?? '';
    if (resolution.method == 'none' || resolution.entry == null) {
      unmatched++;
      if (resolution.notes.contains('conflict')) {
        conflicts++;
      }
      rows.add(
        _Row(
          oduKey: oduKey,
          displayName: displayName,
          oldHeaderNumber: oldHeaderNumber,
          newNumber: null,
          matchMethod: 'none',
          pdfLineMatched: '',
          confidence: 'NONE',
          action: 'skip_unmatched',
          descripcionBeforeLen: descripcionBeforeLen,
          descripcionAfterLen: descripcionBeforeLen,
          notes: resolution.notes,
          familyBase: familyBase,
          updated: false,
        ),
      );
      oduMap[oduKey] = node;
      continue;
    }

    final targetNumber = resolution.entry!.number;
    final targetHeader =
        'ESTE ES EL ODU # $targetNumber DEL ORDEN SEÑORIAL DE IFÁ.';
    var updatedDescripcion = descripcion;
    var action = 'none';

    if (_headerWithNumberPattern.hasMatch(updatedDescripcion)) {
      updatedDescripcion = updatedDescripcion.replaceFirst(
        _headerWithNumberPattern,
        targetHeader,
      );
      action = 'replace';
    } else if (_headerBlankPattern.hasMatch(updatedDescripcion)) {
      updatedDescripcion = updatedDescripcion.replaceFirst(
        _headerBlankPattern,
        targetHeader,
      );
      action = 'fill_blank';
    } else {
      updatedDescripcion = updatedDescripcion.trim().isEmpty
          ? '$targetHeader\n\n'
          : '$targetHeader\n\n$updatedDescripcion';
      action = 'add';
    }

    final wasUpdated = updatedDescripcion != descripcion;
    if (!wasUpdated) {
      action = 'none';
      unchanged++;
    } else {
      if (resolution.method == 'exact') {
        updatedExact++;
      } else if (resolution.method == 'family_meji_fallback') {
        updatedFallback++;
      }
    }

    content['descripcion'] = updatedDescripcion;
    node['content'] = content;
    oduMap[oduKey] = node;

    rows.add(
      _Row(
        oduKey: oduKey,
        displayName: displayName,
        oldHeaderNumber: oldHeaderNumber,
        newNumber: wasUpdated ? targetNumber : oldHeaderNumber,
        matchMethod: resolution.method,
        pdfLineMatched: '${resolution.entry!.number}. ${resolution.entry!.rawName}',
        confidence: resolution.confidence,
        action: action,
        descripcionBeforeLen: descripcionBeforeLen,
        descripcionAfterLen: updatedDescripcion.length,
        notes: resolution.notes,
        familyBase: familyBase,
        updated: wasUpdated,
      ),
    );
  }

  root['odu'] = oduMap;
  final afterCount = (root['odu'] as Map).length;
  if (beforeCount != afterCount) {
    stderr.writeln(
      'Validation failed: Odù count changed (before=$beforeCount, after=$afterCount).',
    );
    exitCode = 1;
    return;
  }

  var validatedErrors = 0;
  for (final row in rows) {
    if (row.matchMethod == 'none' || row.newNumber == null) {
      continue;
    }
    final node = _mapFrom(oduMap[row.oduKey]);
    final content = _mapFrom(node['content']);
    final descripcion = (content['descripcion'] as String?) ?? '';
    final m = _finalHeaderPattern.firstMatch(descripcion);
    final found = m == null ? null : int.tryParse(m.group(1) ?? '');
    if (found != row.newNumber) {
      validatedErrors++;
      stderr.writeln(
        'Validation mismatch for ${row.oduKey}: expected=${row.newNumber}, found=$found',
      );
    }
  }
  if (validatedErrors > 0) {
    stderr.writeln(
      'Validation failed: $validatedErrors matched rows do not contain expected header.',
    );
    exitCode = 1;
    return;
  }

  final encoded = const JsonEncoder.withIndent('  ').convert(root);
  jsonDecode(encoded);

  Directory('build').createSync(recursive: true);
  File(_buildOutputPath).writeAsStringSync('$encoded\n', encoding: utf8);
  File(_publishOutputPath).writeAsStringSync('$encoded\n', encoding: utf8);
  File(_reportCsvPath).writeAsStringSync(_buildCsv(rows), encoding: utf8);
  File(
    _reportMdPath,
  ).writeAsStringSync(
    _buildMd(
      pdfPath: pdfPath,
      total: beforeCount,
      updatedExact: updatedExact,
      updatedFallback: updatedFallback,
      unchanged: unchanged,
      unmatched: unmatched,
      conflicts: conflicts,
      rows: rows,
    ),
    encoding: utf8,
  );

  _printExamples(rows);

  stdout.writeln('Applied Odù order headers from PDF.');
  stdout.writeln('pdf: $pdfPath');
  stdout.writeln('total: $beforeCount');
  stdout.writeln('updated_exact: $updatedExact');
  stdout.writeln('updated_family_fallback: $updatedFallback');
  stdout.writeln('unchanged: $unchanged');
  stdout.writeln('unmatched: $unmatched');
  stdout.writeln('conflicts: $conflicts');
  stdout.writeln('build_output: $_buildOutputPath');
  stdout.writeln('published_output: $_publishOutputPath');
  stdout.writeln('csv_report: $_reportCsvPath');
  stdout.writeln('md_report: $_reportMdPath');
}

String normalizeKey(String s) {
  var out = s.toUpperCase().trim();
  const replacements = <String, String>{
    'Á': 'A',
    'À': 'A',
    'Ä': 'A',
    'Â': 'A',
    'Ã': 'A',
    'É': 'E',
    'È': 'E',
    'Ë': 'E',
    'Ê': 'E',
    'Í': 'I',
    'Ì': 'I',
    'Ï': 'I',
    'Î': 'I',
    'Ó': 'O',
    'Ò': 'O',
    'Ö': 'O',
    'Ô': 'O',
    'Õ': 'O',
    'Ú': 'U',
    'Ù': 'U',
    'Ü': 'U',
    'Û': 'U',
    'Ñ': 'N',
    'Ç': 'C',
  };
  replacements.forEach((k, v) {
    out = out.replaceAll(k, v);
  });
  out = out.replaceAll('_', ' ').replaceAll('-', ' ');
  out = out.replaceAll(RegExp(r'[^A-Z0-9 ]+'), ' ');
  out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
  return out;
}

String? extractFamilyBase(String oduKeyOrName) {
  final normalized = normalizeKey(oduKeyOrName);
  if (normalized.isEmpty) {
    return null;
  }
  final tokens = normalized.split(' ');
  for (final token in tokens) {
    if (token.isEmpty || _ignoreTokens.contains(token)) {
      continue;
    }
    return token;
  }
  return null;
}

_MatchResolution _resolveMatch({
  required String oduKey,
  required String displayName,
  required Map<String, List<_PdfEntry>> pdfByNormalizedName,
  required Map<String, List<_PdfEntry>> pdfMejiByCanonicalFamily,
}) {
  final exactCandidates = <String>{
    ..._exactCandidatesFromName(displayName),
    ..._exactCandidatesFromName(oduKey),
  }.where((e) => e.isNotEmpty).toList();

  final exactHits = <_PdfEntry>[];
  final seenExact = <int>{};
  for (final candidate in exactCandidates) {
    final entries = pdfByNormalizedName[candidate];
    if (entries == null) {
      continue;
    }
    for (final entry in entries) {
      if (seenExact.add(entry.number)) {
        exactHits.add(entry);
      }
    }
  }

  if (exactHits.length == 1) {
    return _MatchResolution(
      method: 'exact',
      confidence: 'HIGH',
      entry: exactHits.first,
      notes: 'exact_candidate_match',
    );
  }
  if (exactHits.length > 1) {
    return _MatchResolution(
      method: 'none',
      confidence: 'NONE',
      notes:
          'conflict_exact_multiple_matches:${exactHits.map((e) => e.number).toList()..sort()}',
    );
  }

  // Family-only fallback to <CANONICAL FAMILY> MEJI.
  final familyBaseRaw = extractFamilyBase(displayName.isNotEmpty ? displayName : oduKey);
  if (familyBaseRaw == null) {
    return const _MatchResolution(
      method: 'none',
      confidence: 'NONE',
      notes: 'no_family_base',
    );
  }
  final canonicalFamily = _familyBaseAliasToCanonical[familyBaseRaw];
  if (canonicalFamily == null) {
    return _MatchResolution(
      method: 'none',
      confidence: 'NONE',
      notes: 'family_not_mapped:$familyBaseRaw',
    );
  }

  final familyMejiHits = pdfMejiByCanonicalFamily[canonicalFamily] ?? const <_PdfEntry>[];
  if (familyMejiHits.length == 1) {
    return _MatchResolution(
      method: 'family_meji_fallback',
      confidence: 'MED',
      entry: familyMejiHits.first,
      notes: 'fallback_family_meji:$familyBaseRaw->$canonicalFamily',
    );
  }
  if (familyMejiHits.length > 1) {
    return _MatchResolution(
      method: 'none',
      confidence: 'NONE',
      notes:
          'conflict_family_meji_multiple:${familyMejiHits.map((e) => e.number).toList()..sort()}',
    );
  }

  return _MatchResolution(
    method: 'none',
    confidence: 'NONE',
    notes: 'family_meji_not_found:$canonicalFamily',
  );
}

Set<String> _exactCandidatesFromName(String rawName) {
  final out = <String>{};
  final normalized = normalizeKey(rawName);
  if (normalized.isEmpty) {
    return out;
  }

  out.add(normalized);

  final tokens = normalized.split(' ');
  if (tokens.isNotEmpty && tokens.first == 'BABA' && tokens.length > 1) {
    out.add(tokens.sublist(1).join(' '));
  }
  if (tokens.length == 2 && (tokens[1] == 'MEJI' || tokens[1] == 'MEYI')) {
    out.add(tokens.first);
    out.add('${tokens.first} MEJI');
  }
  if (tokens.length == 1) {
    final mapped = _familyBaseAliasToCanonical[tokens.first];
    if (mapped != null) {
      out.add(mapped);
      out.add('$mapped MEJI');
    }
  }
  return out;
}

List<_PdfEntry> _parsePdfEntries(String text) {
  final entries = <_PdfEntry>[];
  final normalizedText = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  for (final rawLine in normalizedText.split('\n')) {
    final line = rawLine.replaceAll('\u000c', '').trim();
    if (line.isEmpty) {
      continue;
    }
    final m = _pdfLinePattern.firstMatch(line);
    if (m == null) {
      continue;
    }
    final number = int.tryParse(m.group(1) ?? '');
    if (number == null || number < 1 || number > 256) {
      continue;
    }
    final name = (m.group(2) ?? '').trim().replaceAll(RegExp(r'[.]+$'), '');
    final normalizedName = normalizeKey(name);
    if (normalizedName.isEmpty) {
      continue;
    }
    final familyBase = extractFamilyBase(normalizedName);
    final canonicalFamily = familyBase == null
        ? null
        : _familyBaseAliasToCanonical[familyBase];
    if (canonicalFamily == null) {
      continue;
    }
    entries.add(
      _PdfEntry(
        number: number,
        rawName: name,
        normalizedName: normalizedName,
        familyBaseCanonical: canonicalFamily,
      ),
    );
  }
  return entries;
}

String? _resolvePdfPath(List<String> args) {
  if (args.isNotEmpty) {
    final explicit = File(args.first);
    if (explicit.existsSync()) {
      return explicit.path;
    }
  }

  final home = Platform.environment['HOME'] ?? '';
  final candidates = <String>[
    '/mnt/data/Lista de los 256-Odu-Ifa.pdf',
    if (home.isNotEmpty) '$home/Downloads/Lista de los 256-Odu-Ifa.pdf',
    'Lista de los 256-Odu-Ifa.pdf',
  ];
  for (final path in candidates) {
    final file = File(path);
    if (file.existsSync()) {
      return file.path;
    }
  }
  return null;
}

String? _extractPdfText(String pdfPath) {
  try {
    final result = Process.runSync('pdftotext', <String>['-layout', pdfPath, '-']);
    if (result.exitCode != 0) {
      return null;
    }
    final out = (result.stdout ?? '').toString();
    if (out.trim().isEmpty) {
      return null;
    }
    return out;
  } catch (_) {
    return null;
  }
}

Map<String, dynamic> _mapFrom(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return <String, dynamic>{};
}

int? _extractOldHeaderNumber(String descripcion) {
  final m = _headerWithNumberPattern.firstMatch(descripcion);
  if (m == null) {
    return null;
  }
  return int.tryParse(m.group(1) ?? '');
}

String _buildCsv(List<_Row> rows) {
  final sb = StringBuffer();
  sb.writeln(
    'odu_key,display_name,old_header_number,new_number,match_method,pdf_line_matched,confidence,notes,action,descripcion_before_len,descripcion_after_len,family_base',
  );
  for (final row in rows) {
    final oduKey = row.oduKey.replaceAll('"', '""');
    final displayName = row.displayName.replaceAll('"', '""');
    final oldHeader = row.oldHeaderNumber?.toString() ?? '';
    final newNumber = row.newNumber?.toString() ?? '';
    final pdfLine = row.pdfLineMatched.replaceAll('"', '""');
    final notes = row.notes.replaceAll('"', '""');
    final familyBase = row.familyBase.replaceAll('"', '""');
    sb.writeln(
      '"$oduKey","$displayName",$oldHeader,$newNumber,${row.matchMethod},"$pdfLine",${row.confidence},"$notes",${row.action},${row.descripcionBeforeLen},${row.descripcionAfterLen},"$familyBase"',
    );
  }
  return sb.toString();
}

String _buildMd({
  required String pdfPath,
  required int total,
  required int updatedExact,
  required int updatedFallback,
  required int unchanged,
  required int unmatched,
  required int conflicts,
  required List<_Row> rows,
}) {
  final unmatchedRows = rows.where((r) => r.matchMethod == 'none').toList()
    ..sort((a, b) => a.oduKey.compareTo(b.oduKey));

  final sb = StringBuffer()
    ..writeln('# Odù Order From PDF Report')
    ..writeln()
    ..writeln('- pdf_source: `$pdfPath`')
    ..writeln('- total: `$total`')
    ..writeln('- updated_exact: `$updatedExact`')
    ..writeln('- updated_family_fallback: `$updatedFallback`')
    ..writeln('- unchanged: `$unchanged`')
    ..writeln('- unmatched: `$unmatched`')
    ..writeln('- conflicts: `$conflicts`')
    ..writeln()
    ..writeln('## Unmatched')
    ..writeln();

  if (unmatchedRows.isEmpty) {
    sb.writeln('_None_');
  } else {
    for (final row in unmatchedRows) {
      sb.writeln(
        '- `${row.oduKey}`'
        ' familyBase=`${row.familyBase}`'
        ' notes=`${row.notes}`',
      );
    }
  }
  return sb.toString();
}

void _printExamples(List<_Row> rows) {
  final exact = rows
      .where((r) => r.updated && r.matchMethod == 'exact')
      .take(5)
      .toList();
  final fallback = rows
      .where((r) => r.updated && r.matchMethod == 'family_meji_fallback')
      .take(5)
      .toList();
  final unmatched = rows.where((r) => r.matchMethod == 'none').take(10).toList();

  stdout.writeln('--- sample_exact (max 5) ---');
  if (exact.isEmpty) {
    stdout.writeln('none');
  } else {
    for (final row in exact) {
      stdout.writeln(
        '${row.oduKey} -> #${row.newNumber} via ${row.matchMethod} [${row.pdfLineMatched}]',
      );
    }
  }

  stdout.writeln('--- sample_fallback (max 5) ---');
  if (fallback.isEmpty) {
    stdout.writeln('none');
  } else {
    for (final row in fallback) {
      stdout.writeln(
        '${row.oduKey} -> #${row.newNumber} via ${row.matchMethod} [${row.familyBase}]',
      );
    }
  }

  stdout.writeln('--- sample_unmatched (max 10) ---');
  if (unmatched.isEmpty) {
    stdout.writeln('none');
  } else {
    for (final row in unmatched) {
      stdout.writeln(
        '${row.oduKey} familyBase=${row.familyBase} notes=${row.notes}',
      );
    }
  }
}
