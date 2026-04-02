import 'dart:convert';
import 'dart:io';

const String _inputPath = 'assets/odu_content_patched.json';
const String _outJsonPath = 'build/eshu_marker_contamination_report.json';
const String _outMdPath = 'build/eshu_marker_contamination_report.md';

const int _previewBefore = 250;
const int _previewAfter = 350;

final List<_MarkerSpec> _markers = <_MarkerSpec>[
  _MarkerSpec(label: 'DESCRIPC', regex: RegExp(r'DESCRIPC', caseSensitive: false)),
  _MarkerSpec(label: 'EWES', regex: RegExp(r'EWES', caseSensitive: false)),
  _MarkerSpec(label: 'OBRAS', regex: RegExp(r'OBRAS', caseSensitive: false)),
  _MarkerSpec(label: 'DICE IF', regex: RegExp(r'DICE\s+IF', caseSensitive: false)),
  _MarkerSpec(label: 'REZO', regex: RegExp(r'REZO', caseSensitive: false)),
  _MarkerSpec(label: 'SUYERE', regex: RegExp(r'SUYERE', caseSensitive: false)),
  _MarkerSpec(label: 'PATAK', regex: RegExp(r'PATAK', caseSensitive: false)),
  _MarkerSpec(label: 'HISTOR', regex: RegExp(r'HISTOR', caseSensitive: false)),
];

void main() {
  final inputFile = File(_inputPath);
  if (!inputFile.existsSync()) {
    stderr.writeln('Missing input file: $_inputPath');
    exitCode = 1;
    return;
  }

  final decoded = jsonDecode(inputFile.readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    stderr.writeln('Invalid JSON root in $_inputPath');
    exitCode = 1;
    return;
  }

  final oduRaw = decoded['odu'];
  if (oduRaw is! Map) {
    stderr.writeln('Invalid payload: missing "odu" map in $_inputPath');
    exitCode = 1;
    return;
  }

  final Map<String, dynamic> oduMap = Map<String, dynamic>.from(oduRaw);
  final List<_Hit> hits = <_Hit>[];
  final Map<String, int> markerCounts = <String, int>{};

  final List<String> keys = oduMap.keys.whereType<String>().toList()..sort();
  for (final String oduKey in keys) {
    final dynamic nodeRaw = oduMap[oduKey];
    if (nodeRaw is! Map) continue;
    final Map<String, dynamic> node = Map<String, dynamic>.from(nodeRaw);
    final dynamic contentRaw = node['content'];
    if (contentRaw is! Map) continue;
    final Map<String, dynamic> content = Map<String, dynamic>.from(contentRaw);

    final String eshu = _asString(content['eshu']);
    if (eshu.trim().isEmpty || eshu.trim() == '-') {
      continue;
    }

    final String descripcion = _asString(content['descripcion']);

    for (final _MarkerSpec marker in _markers) {
      final Iterable<RegExpMatch> matches = marker.regex.allMatches(eshu);
      for (final RegExpMatch match in matches) {
        final int index = match.start;
        final int from = (index - _previewBefore).clamp(0, eshu.length);
        final int to = (index + _previewAfter).clamp(0, eshu.length);
        final String preview = eshu.substring(from, to).trim();

        final _Hit hit = _Hit(
          oduKey: oduKey,
          marker: marker.label,
          index: index,
          preview: preview,
          eshuLength: eshu.length,
          descripcionLength: descripcion.length,
        );
        hits.add(hit);
        markerCounts[marker.label] = (markerCounts[marker.label] ?? 0) + 1;
      }
    }
  }

  hits.sort((a, b) {
    final int byKey = a.oduKey.compareTo(b.oduKey);
    if (byKey != 0) return byKey;
    final int byIndex = a.index.compareTo(b.index);
    if (byIndex != 0) return byIndex;
    return a.marker.compareTo(b.marker);
  });

  final Map<String, dynamic> jsonOut = <String, dynamic>{
    'source_file': _inputPath,
    'generated_utc': DateTime.now().toUtc().toIso8601String(),
    'marker_patterns': _markers.map((m) => m.label).toList(),
    'preview_window': <String, int>{
      'before_chars': _previewBefore,
      'after_chars': _previewAfter,
    },
    'summary': <String, dynamic>{
      'odu_scanned': keys.length,
      'total_hits': hits.length,
      'marker_counts': markerCounts,
    },
    'hits': hits.map((h) => h.toJson()).toList(),
  };

  final StringBuffer md = StringBuffer()
    ..writeln('# ESHU Marker Contamination Report')
    ..writeln()
    ..writeln('- Source: `$_inputPath`')
    ..writeln('- Generated (UTC): `${jsonOut['generated_utc']}`')
    ..writeln('- Odù scanned: `${keys.length}`')
    ..writeln('- Total hits: `${hits.length}`')
    ..writeln()
    ..writeln('## Marker Counts');

  if (markerCounts.isEmpty) {
    md.writeln('- No matches found.');
  } else {
    final List<MapEntry<String, int>> sortedCounts = markerCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final MapEntry<String, int> entry in sortedCounts) {
      md.writeln('- `${entry.key}`: ${entry.value}');
    }
  }

  md.writeln();
  md.writeln('## Hits');
  if (hits.isEmpty) {
    md.writeln('_No contamination markers found inside ESHU._');
  } else {
    for (final _Hit hit in hits) {
      md.writeln('### `${hit.oduKey}` @ ${hit.index} (`${hit.marker}`)');
      md.writeln('- eshu_length: `${hit.eshuLength}`');
      md.writeln('- descripcion_length: `${hit.descripcionLength}`');
      md.writeln('- preview:');
      md.writeln('```text');
      md.writeln(hit.preview);
      md.writeln('```');
      md.writeln();
    }
  }

  Directory('build').createSync(recursive: true);
  File(_outJsonPath)
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(jsonOut));
  File(_outMdPath).writeAsStringSync(md.toString());

  stdout.writeln('Generated contamination report (no patches applied).');
  stdout.writeln('Total hits: ${hits.length}');
  stdout.writeln('Wrote: $_outJsonPath');
  stdout.writeln('Wrote: $_outMdPath');
}

String _asString(dynamic value) {
  if (value == null) return '';
  if (value is String) return value;
  return value.toString();
}

class _MarkerSpec {
  const _MarkerSpec({required this.label, required this.regex});

  final String label;
  final RegExp regex;
}

class _Hit {
  const _Hit({
    required this.oduKey,
    required this.marker,
    required this.index,
    required this.preview,
    required this.eshuLength,
    required this.descripcionLength,
  });

  final String oduKey;
  final String marker;
  final int index;
  final String preview;
  final int eshuLength;
  final int descripcionLength;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'odu_key': oduKey,
      'marker': marker,
      'index': index,
      'preview': preview,
      'eshu_length': eshuLength,
      'descripcion_length': descripcionLength,
    };
  }
}
