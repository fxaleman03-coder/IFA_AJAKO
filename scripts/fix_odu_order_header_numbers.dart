import 'dart:convert';
import 'dart:io';

const String _sourcePath = 'assets/odu_content_patched.json';
const String _buildOutputPath = 'build/odu_content_patched.json';
const String _publishOutputPath = 'assets/odu_content_patched.json';
const String _reportMdPath = 'build/odu_order_header_fix_report.md';
const String _reportCsvPath = 'build/odu_order_header_fix_report.csv';

final RegExp _oduNumberPattern = RegExp(
  r'OD(?:U|O|Ù)\s*(?:#|N(?:O|º|°|\.?)?)\s*(\d{1,3})',
  caseSensitive: false,
);

final RegExp _headerWithNumberLinePattern = RegExp(
  r'^\s*ESTE\s+ES\s+EL\s+OD(?:U|O|Ù)\s*(?:#|N(?:O|º|°|\.?)?)\s*(\d{1,3})\s+DEL\s+ORDEN\s+SEÑORIAL\s+DE\s+IF[ÁA]\.?\s*$',
  multiLine: true,
  caseSensitive: false,
);

final RegExp _headerWithoutNumberLinePattern = RegExp(
  r'^\s*ESTE\s+ES\s+EL\s+OD(?:U|O|Ù)\s*(?:#|N(?:O|º|°|\.?)?)\s*DEL\s+ORDEN\s+SEÑORIAL\s+DE\s+IF[ÁA]\.?\s*$',
  multiLine: true,
  caseSensitive: false,
);

final RegExp _incompleteHeaderCountPattern = RegExp(
  r'ESTE\s+ES\s+EL\s+OD(?:U|O|Ù)\s*(?:#|N(?:O|º|°|\.?)?)\s*DEL\s+ORDEN\s+SEÑORIAL\s+DE\s+IF[ÁA]\.?',
  caseSensitive: false,
);

class _RowReport {
  const _RowReport({
    required this.oduKey,
    required this.status,
    required this.foundNumber,
    required this.action,
    required this.oldHeaderPreview,
    required this.newHeaderPreview,
  });

  final String oduKey;
  final String status;
  final int? foundNumber;
  final String action;
  final String oldHeaderPreview;
  final String newHeaderPreview;
}

void main() {
  final sourceFile = File(_sourcePath);
  if (!sourceFile.existsSync()) {
    stderr.writeln('Missing source file: $_sourcePath');
    exitCode = 1;
    return;
  }

  final decoded = jsonDecode(sourceFile.readAsStringSync());
  if (decoded is! Map) {
    stderr.writeln('Invalid JSON root in $_sourcePath');
    exitCode = 1;
    return;
  }
  final root = Map<String, dynamic>.from(decoded);
  final rawOdu = root['odu'];
  if (rawOdu is! Map) {
    stderr.writeln('Invalid JSON shape: root["odu"] must be an object.');
    exitCode = 1;
    return;
  }
  final oduMap = Map<String, dynamic>.from(rawOdu);
  final beforeCount = oduMap.length;

  final detectedNumbers = <String, Set<int>>{};
  for (final entry in oduMap.entries) {
    final oduKey = entry.key;
    final content = _contentMap(entry.value);
    final descripcion = (content['descripcion'] as String?) ?? '';
    final nace = (content['nace'] as String?) ?? '';

    final numbers = <int>{};
    numbers.addAll(_extractNumbers(descripcion));
    numbers.addAll(_extractNumbers(nace));
    detectedNumbers[oduKey] = numbers;
  }

  final reports = <_RowReport>[];
  var totalUpdated = 0;
  var totalAdded = 0;
  var totalReplaced = 0;
  var totalConflicts = 0;
  var totalMissingNumber = 0;
  var totalOkAlready = 0;

  for (final entry in oduMap.entries) {
    final oduKey = entry.key;
    final node = _nodeMap(entry.value);
    final content = _contentMap(node['content']);
    final descripcion = (content['descripcion'] as String?) ?? '';
    final availableNumbers = detectedNumbers[oduKey] ?? const <int>{};

    final oldHeaderPreview = _firstHeaderPreview(descripcion);
    var newHeaderPreview = oldHeaderPreview;

    if (availableNumbers.length > 1) {
      totalConflicts++;
      reports.add(
        _RowReport(
          oduKey: oduKey,
          status: 'CONFLICT',
          foundNumber: null,
          action: 'no_change_multiple_numbers:${availableNumbers.toList()..sort()}',
          oldHeaderPreview: oldHeaderPreview,
          newHeaderPreview: newHeaderPreview,
        ),
      );
      oduMap[oduKey] = node;
      continue;
    }

    final foundNumber = availableNumbers.isEmpty ? null : availableNumbers.first;
    final canonicalHeader = foundNumber == null
        ? null
        : 'ESTE ES EL ODU # $foundNumber DEL ORDEN SEÑORIAL DE IFÁ.';

    final hasHeaderWithNumber = _headerWithNumberLinePattern.hasMatch(descripcion);
    if (hasHeaderWithNumber) {
      totalOkAlready++;
      reports.add(
        _RowReport(
          oduKey: oduKey,
          status: 'OK_ALREADY',
          foundNumber: foundNumber,
          action: 'no_change',
          oldHeaderPreview: oldHeaderPreview,
          newHeaderPreview: newHeaderPreview,
        ),
      );
      oduMap[oduKey] = node;
      continue;
    }

    final hasHeaderWithoutNumber = _headerWithoutNumberLinePattern.hasMatch(
      descripcion,
    );

    if (hasHeaderWithoutNumber) {
      if (canonicalHeader == null) {
        totalMissingNumber++;
        reports.add(
          _RowReport(
            oduKey: oduKey,
            status: 'MISSING_NUMBER',
            foundNumber: null,
            action: 'incomplete_header_kept',
            oldHeaderPreview: oldHeaderPreview,
            newHeaderPreview: newHeaderPreview,
          ),
        );
        oduMap[oduKey] = node;
        continue;
      }

      final updatedDescripcion = descripcion.replaceFirst(
        _headerWithoutNumberLinePattern,
        canonicalHeader,
      );
      content['descripcion'] = updatedDescripcion;
      node['content'] = content;
      oduMap[oduKey] = node;
      totalUpdated++;
      totalReplaced++;
      newHeaderPreview = canonicalHeader;
      reports.add(
        _RowReport(
          oduKey: oduKey,
          status: 'REPLACED_BLANK',
          foundNumber: foundNumber,
          action: 'replace_incomplete_header',
          oldHeaderPreview: oldHeaderPreview,
          newHeaderPreview: newHeaderPreview,
        ),
      );
      continue;
    }

    if (canonicalHeader == null) {
      totalMissingNumber++;
      reports.add(
        _RowReport(
          oduKey: oduKey,
          status: 'MISSING_NUMBER',
          foundNumber: null,
          action: 'header_not_added_no_number_available',
          oldHeaderPreview: oldHeaderPreview,
          newHeaderPreview: newHeaderPreview,
        ),
      );
      oduMap[oduKey] = node;
      continue;
    }

    final normalizedDescripcion = descripcion
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final updatedDescripcion = normalizedDescripcion.trim().isEmpty
        ? '$canonicalHeader\n\n'
        : '$canonicalHeader\n\n$normalizedDescripcion';
    content['descripcion'] = updatedDescripcion;
    node['content'] = content;
    oduMap[oduKey] = node;
    totalUpdated++;
    totalAdded++;
    newHeaderPreview = canonicalHeader;
    reports.add(
      _RowReport(
        oduKey: oduKey,
        status: 'ADDED_HEADER',
        foundNumber: foundNumber,
        action: 'prepend_header',
        oldHeaderPreview: oldHeaderPreview,
        newHeaderPreview: newHeaderPreview,
      ),
    );
  }

  root['odu'] = oduMap;
  final afterCount = (root['odu'] as Map).length;
  if (beforeCount != afterCount) {
    stderr.writeln(
      'Validation failed: Odù count mismatch (before=$beforeCount, after=$afterCount).',
    );
    exitCode = 1;
    return;
  }

  final encoded = const JsonEncoder.withIndent('  ').convert(root);
  jsonDecode(encoded);

  Directory('build').createSync(recursive: true);
  File(_buildOutputPath).writeAsStringSync('$encoded\n', encoding: utf8);
  File(_publishOutputPath).writeAsStringSync('$encoded\n', encoding: utf8);

  final incompleteRemaining = reports.isEmpty
      ? 0
      : _countIncompleteHeadersFromRoot(root);

  final md = _buildMarkdownReport(
    total: beforeCount,
    updated: totalUpdated,
    added: totalAdded,
    replacedBlank: totalReplaced,
    conflicts: totalConflicts,
    missingNumber: totalMissingNumber,
    okAlready: totalOkAlready,
    incompleteHeaderRemaining: incompleteRemaining,
    reports: reports,
  );
  File(_reportMdPath).writeAsStringSync(md, encoding: utf8);

  final csv = _buildCsvReport(reports);
  File(_reportCsvPath).writeAsStringSync(csv, encoding: utf8);

  stdout.writeln('Order header fix completed.');
  stdout.writeln('total=$beforeCount');
  stdout.writeln('updated=$totalUpdated');
  stdout.writeln('added=$totalAdded');
  stdout.writeln('replaced_blank=$totalReplaced');
  stdout.writeln('conflicts=$totalConflicts');
  stdout.writeln('missing_number=$totalMissingNumber');
  stdout.writeln('ok_already=$totalOkAlready');
  stdout.writeln('incomplete_header_remaining=$incompleteRemaining');
  stdout.writeln('Wrote: $_buildOutputPath');
  stdout.writeln('Published: $_publishOutputPath');
  stdout.writeln('Report: $_reportMdPath');
  stdout.writeln('CSV: $_reportCsvPath');
}

Map<String, dynamic> _nodeMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return <String, dynamic>{};
}

Map<String, dynamic> _contentMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return <String, dynamic>{};
}

Set<int> _extractNumbers(String text) {
  final numbers = <int>{};
  for (final match in _oduNumberPattern.allMatches(text)) {
    final raw = match.group(1);
    if (raw == null) {
      continue;
    }
    final parsed = int.tryParse(raw);
    if (parsed != null) {
      numbers.add(parsed);
    }
  }
  return numbers;
}

String _firstHeaderPreview(String descripcion) {
  final normalized = descripcion.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final lines = normalized.split('\n');
  for (final line in lines.take(6)) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    if (_headerWithNumberLinePattern.hasMatch(trimmed) ||
        _headerWithoutNumberLinePattern.hasMatch(trimmed)) {
      return trimmed;
    }
  }
  return '';
}

int _countIncompleteHeadersFromRoot(Map<String, dynamic> root) {
  final rawOdu = root['odu'];
  if (rawOdu is! Map) {
    return 0;
  }
  var count = 0;
  for (final value in rawOdu.values) {
    final node = _nodeMap(value);
    final content = _contentMap(node['content']);
    final descripcion = (content['descripcion'] as String?) ?? '';
    if (_incompleteHeaderCountPattern.hasMatch(descripcion)) {
      count++;
    }
  }
  return count;
}

String _buildMarkdownReport({
  required int total,
  required int updated,
  required int added,
  required int replacedBlank,
  required int conflicts,
  required int missingNumber,
  required int okAlready,
  required int incompleteHeaderRemaining,
  required List<_RowReport> reports,
}) {
  final buffer = StringBuffer()
    ..writeln('# Odù Order Header Fix Report')
    ..writeln()
    ..writeln('- total: `$total`')
    ..writeln('- updated: `$updated`')
    ..writeln('- added: `$added`')
    ..writeln('- replaced_blank: `$replacedBlank`')
    ..writeln('- conflicts: `$conflicts`')
    ..writeln('- missing_number: `$missingNumber`')
    ..writeln('- ok_already: `$okAlready`')
    ..writeln('- incomplete_header_remaining: `$incompleteHeaderRemaining`')
    ..writeln()
    ..writeln('## Rows')
    ..writeln()
    ..writeln(
      '| odu_key | status | found_number | action | old_header_preview | new_header_preview |',
    )
    ..writeln(
      '|---|---|---:|---|---|---|',
    );

  for (final row in reports) {
    final foundNumber = row.foundNumber?.toString() ?? '';
    final oldPreview = row.oldHeaderPreview.replaceAll('|', r'\|');
    final newPreview = row.newHeaderPreview.replaceAll('|', r'\|');
    buffer.writeln(
      '| `${row.oduKey}` | `${row.status}` | `$foundNumber` | `${row.action}` | `$oldPreview` | `$newPreview` |',
    );
  }

  return buffer.toString();
}

String _buildCsvReport(List<_RowReport> reports) {
  final buffer = StringBuffer();
  buffer.writeln(
    'odu_key,status,found_number,action,old_header_preview,new_header_preview',
  );
  for (final row in reports) {
    final foundNumber = row.foundNumber?.toString() ?? '';
    final oldPreview = row.oldHeaderPreview.replaceAll('"', '""');
    final newPreview = row.newHeaderPreview.replaceAll('"', '""');
    buffer.writeln(
      '"${row.oduKey.replaceAll('"', '""')}",'
      '${row.status},'
      '$foundNumber,'
      '"${row.action.replaceAll('"', '""')}",'
      '"$oldPreview",'
      '"$newPreview"',
    );
  }
  return buffer.toString();
}
