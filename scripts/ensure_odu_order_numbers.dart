import 'dart:convert';
import 'dart:io';

const String _sourcePath = 'assets/odu_content_patched.json';
const String _buildOutputPath = 'build/odu_content_patched.json';
const String _publishOutputPath = 'assets/odu_content_patched.json';
const String _reportMdPath = 'build/odu_order_number_report.md';
const String _reportCsvPath = 'build/odu_order_number_report.csv';

final RegExp _headerPattern = RegExp(
  r'^\s*ESTE\s+ES\s+EL\s+OD[UOÙ]\s*#?\s*\d*\s*DEL\s+ORDEN\s+SEÑORIAL\s+DE\s+IF[ÁA]\.?\s*$',
  caseSensitive: false,
);

class _EntryResult {
  const _EntryResult({
    required this.oduKey,
    required this.number,
    required this.action,
  });

  final String oduKey;
  final int number;
  final String action;
}

void main() {
  final sourceFile = File(_sourcePath);
  if (!sourceFile.existsSync()) {
    stderr.writeln('Missing input file: $_sourcePath');
    exitCode = 1;
    return;
  }

  final decoded = jsonDecode(sourceFile.readAsStringSync());
  if (decoded is! Map) {
    stderr.writeln('Invalid JSON root in $_sourcePath (expected object).');
    exitCode = 1;
    return;
  }

  final root = Map<String, dynamic>.from(decoded);
  final oduRaw = root['odu'];
  if (oduRaw is! Map) {
    stderr.writeln('Invalid JSON: "odu" must be an object.');
    exitCode = 1;
    return;
  }

  final oduMap = Map<String, dynamic>.from(oduRaw);
  final beforeCount = oduMap.length;
  final results = <_EntryResult>[];

  var totalAdded = 0;
  var totalReplaced = 0;
  var totalUpdated = 0;

  final entries = oduMap.entries.toList(growable: false);
  for (var index = 0; index < entries.length; index++) {
    final entry = entries[index];
    final oduKey = entry.key;
    final oduNumber = index + 1;
    final expectedHeader =
        'ESTE ES EL ODU # $oduNumber DEL ORDEN SEÑORIAL DE IFÁ.';

    if (entry.value is! Map) {
      results.add(_EntryResult(oduKey: oduKey, number: oduNumber, action: 'skip_invalid_entry'));
      continue;
    }

    final node = Map<String, dynamic>.from(entry.value as Map);
    final contentRaw = node['content'];
    if (contentRaw is! Map) {
      results.add(_EntryResult(oduKey: oduKey, number: oduNumber, action: 'skip_missing_content'));
      oduMap[oduKey] = node;
      continue;
    }

    final content = Map<String, dynamic>.from(contentRaw);
    final descripcion = (content['descripcion'] as String?) ?? '';
    final normalizedDescripcion = descripcion
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final lines = normalizedDescripcion.split('\n');
    final inspectLimit = lines.length < 3 ? lines.length : 3;

    var action = 'unchanged';
    var headerFoundAt = -1;
    for (var i = 0; i < inspectLimit; i++) {
      if (_headerPattern.hasMatch(lines[i])) {
        headerFoundAt = i;
        break;
      }
    }

    if (headerFoundAt >= 0) {
      if (lines[headerFoundAt].trim() != expectedHeader) {
        lines[headerFoundAt] = expectedHeader;
        content['descripcion'] = lines.join('\n');
        action = 'replaced';
        totalReplaced++;
        totalUpdated++;
      }
    } else {
      final updatedDescripcion = normalizedDescripcion.trim().isEmpty
          ? '$expectedHeader\n\n'
          : '$expectedHeader\n\n$normalizedDescripcion';
      content['descripcion'] = updatedDescripcion;
      action = 'added';
      totalAdded++;
      totalUpdated++;
    }

    node['content'] = content;
    oduMap[oduKey] = node;
    results.add(_EntryResult(oduKey: oduKey, number: oduNumber, action: action));
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

  final encoded = const JsonEncoder.withIndent('  ').convert(root);
  jsonDecode(encoded); // Final parse validation.

  Directory('build').createSync(recursive: true);
  File(_buildOutputPath).writeAsStringSync('$encoded\n');
  File(_publishOutputPath).writeAsStringSync('$encoded\n');

  final reportMd = _buildMarkdownReport(
    totalOdu: beforeCount,
    totalUpdated: totalUpdated,
    totalAdded: totalAdded,
    totalReplaced: totalReplaced,
  );
  File(_reportMdPath).writeAsStringSync(reportMd);

  final reportCsv = _buildCsvReport(
    totalOdu: beforeCount,
    totalUpdated: totalUpdated,
    totalAdded: totalAdded,
    totalReplaced: totalReplaced,
    results: results,
  );
  File(_reportCsvPath).writeAsStringSync(reportCsv);

  stdout.writeln('Order Number Pass completed.');
  stdout.writeln('total_odu: $beforeCount');
  stdout.writeln('total_updated: $totalUpdated');
  stdout.writeln('total_added: $totalAdded');
  stdout.writeln('total_replaced: $totalReplaced');
  stdout.writeln('Wrote: $_buildOutputPath');
  stdout.writeln('Published: $_publishOutputPath');
  stdout.writeln('Report: $_reportMdPath');
  stdout.writeln('CSV: $_reportCsvPath');
}

String _buildMarkdownReport({
  required int totalOdu,
  required int totalUpdated,
  required int totalAdded,
  required int totalReplaced,
}) {
  return '''
# Odù Order Number Report

- total_odu: `$totalOdu`
- total_updated: `$totalUpdated`
- total_added: `$totalAdded`
- total_replaced: `$totalReplaced`
''';
}

String _buildCsvReport({
  required int totalOdu,
  required int totalUpdated,
  required int totalAdded,
  required int totalReplaced,
  required List<_EntryResult> results,
}) {
  final buffer = StringBuffer();
  buffer.writeln('metric,value');
  buffer.writeln('total_odu,$totalOdu');
  buffer.writeln('total_updated,$totalUpdated');
  buffer.writeln('total_added,$totalAdded');
  buffer.writeln('total_replaced,$totalReplaced');
  buffer.writeln();
  buffer.writeln('odu_key,number,action');
  for (final row in results) {
    final safeKey = row.oduKey.replaceAll('"', '""');
    buffer.writeln('"$safeKey",${row.number},${row.action}');
  }
  return buffer.toString();
}
