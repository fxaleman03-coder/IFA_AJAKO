import 'dart:convert';
import 'dart:io';

const String _sourcePath = 'assets/odu_content_patched.json';
const String _outJsonPath = 'build/tanda_desc_quote_to_suyere_candidates.json';
const String _outMdPath = 'build/tanda_desc_quote_to_suyere_candidates.md';

final RegExp _quotedBlockRegex = RegExp(
  r'[“"]([\s\S]{1,1600}?)[”"]',
  multiLine: true,
  dotAll: true,
);

void main() {
  final sourceFile = File(_sourcePath);
  if (!sourceFile.existsSync()) {
    stderr.writeln('Missing input: $_sourcePath');
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
    stderr.writeln('Invalid JSON: "odu" must be an object.');
    exitCode = 1;
    return;
  }

  final oduMap = Map<String, dynamic>.from(rawOdu);
  final applyReady = <Map<String, dynamic>>[];
  final needsReview = <Map<String, dynamic>>[];
  var scannedOduCount = 0;
  var scannedQuotedBlocks = 0;

  final sortedKeys = oduMap.keys.whereType<String>().toList()..sort();
  for (final oduKey in sortedKeys) {
    final oduNode = oduMap[oduKey];
    if (oduNode is! Map) continue;
    final content = Map<String, dynamic>.from(oduNode['content'] as Map? ?? {});
    final descripcion = _asString(content['descripcion']);
    if (descripcion.trim().isEmpty) continue;

    scannedOduCount++;
    final quoteMatches = _quotedBlockRegex.allMatches(descripcion).toList();
    scannedQuotedBlocks += quoteMatches.length;

    var blockIndex = 0;
    for (final match in quoteMatches) {
      blockIndex++;
      final fullBlock = match.group(0) ?? '';
      final inner = match.group(1) ?? '';
      final lines = _nonEmptyLines(inner);
      final shortLineCount = lines.where((line) => line.length <= 80).length;
      final repeatedLineCount = _repeatedLineCount(lines);
      final hasPossibleSuyereShape =
          lines.length >= 2 && shortLineCount >= 2 && repeatedLineCount >= 1;

      if (!hasPossibleSuyereShape) {
        continue;
      }

      final regexEscapedBlock = RegExp.escape(fullBlock);
      final pattern = regexEscapedBlock;
      final rawPattern = RegExp(pattern, multiLine: true, dotAll: true);
      final matchCount = rawPattern.allMatches(descripcion).length;
      final safeToApply = matchCount == 1;
      final reason = safeToApply
          ? 'ok'
          : 'match_count_$matchCount (expected 1)';

      final candidate = <String, dynamic>{
        'odu_key': oduKey,
        'source_section': 'descripcion',
        'target_section': 'suyereYoruba',
        'quote_block_index': blockIndex,
        'line_count': lines.length,
        'short_line_count': shortLineCount,
        'repeated_line_count': repeatedLineCount,
        'regex_move_to_suyere': pattern,
        'match_count': matchCount,
        'safe_to_apply': safeToApply,
        'reason': reason,
        'preview': _truncate(fullBlock, 700),
        'patch_ops': <String, dynamic>{
          'descripcion': <String, dynamic>{
            'move_to_suyere_regex': <String>[pattern],
            'remove_from_descripcion_regex': <String>[pattern],
          },
          'suyereYoruba': <String, dynamic>{
            'append_from_descripcion_regex': <String>[pattern],
          },
        },
      };

      if (safeToApply) {
        applyReady.add(candidate);
      } else {
        needsReview.add(candidate);
      }
    }
  }

  final jsonOut = <String, dynamic>{
    'generated_at': DateTime.now().toUtc().toIso8601String(),
    'source_path': _sourcePath,
    'summary': <String, dynamic>{
      'odu_scanned': scannedOduCount,
      'quoted_blocks_scanned': scannedQuotedBlocks,
      'apply_ready_count': applyReady.length,
      'needs_review_count': needsReview.length,
    },
    'groups': <String, dynamic>{
      'APPLY_READY': applyReady,
      'NEEDS_REVIEW': needsReview,
    },
  };

  Directory('build').createSync(recursive: true);
  File(_outJsonPath).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(jsonOut),
  );
  File(_outMdPath).writeAsStringSync(_buildMarkdown(jsonOut));

  stdout.writeln('Generated quote-block audit candidates (no patches applied).');
  stdout.writeln('APPLY_READY: ${applyReady.length}');
  stdout.writeln('NEEDS_REVIEW: ${needsReview.length}');
  stdout.writeln('JSON: $_outJsonPath');
  stdout.writeln('MD: $_outMdPath');
}

String _buildMarkdown(Map<String, dynamic> root) {
  final summary = Map<String, dynamic>.from(root['summary'] as Map? ?? {});
  final groups = Map<String, dynamic>.from(root['groups'] as Map? ?? {});
  final applyReady = (groups['APPLY_READY'] as List<dynamic>? ?? const [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
  final needsReview = (groups['NEEDS_REVIEW'] as List<dynamic>? ?? const [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  final sb = StringBuffer()
    ..writeln('# Descripcion Quote Block Audit')
    ..writeln('')
    ..writeln('- Source: `$_sourcePath`')
    ..writeln('- Odu scanned: `${summary['odu_scanned'] ?? 0}`')
    ..writeln('- Quote blocks scanned: `${summary['quoted_blocks_scanned'] ?? 0}`')
    ..writeln('- APPLY_READY: `${summary['apply_ready_count'] ?? 0}`')
    ..writeln('- NEEDS_REVIEW: `${summary['needs_review_count'] ?? 0}`')
    ..writeln('');

  void writeGroup(String title, List<Map<String, dynamic>> rows) {
    sb.writeln('## $title');
    sb.writeln('');
    if (rows.isEmpty) {
      sb.writeln('_None_');
      sb.writeln('');
      return;
    }
    for (final row in rows) {
      sb.writeln('### ${row['odu_key']}');
      sb.writeln('- source_section: `${row['source_section']}`');
      sb.writeln('- target_section: `${row['target_section']}`');
      sb.writeln('- match_count: `${row['match_count']}`');
      sb.writeln('- safe_to_apply: `${row['safe_to_apply']}`');
      sb.writeln('- reason: `${row['reason']}`');
      sb.writeln('- regex_move_to_suyere:');
      sb.writeln('```regex');
      sb.writeln(row['regex_move_to_suyere']);
      sb.writeln('```');
      sb.writeln('- preview:');
      sb.writeln('```text');
      sb.writeln(row['preview']);
      sb.writeln('```');
      sb.writeln('');
    }
  }

  writeGroup('APPLY_READY', applyReady);
  writeGroup('NEEDS_REVIEW', needsReview);
  return sb.toString();
}

List<String> _nonEmptyLines(String text) => text
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n')
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .toList();

int _repeatedLineCount(List<String> lines) {
  if (lines.isEmpty) return 0;
  final seen = <String, int>{};
  for (final line in lines) {
    final key = line.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    seen.update(key, (v) => v + 1, ifAbsent: () => 1);
  }
  return seen.values.fold<int>(0, (sum, count) => sum + (count > 1 ? count - 1 : 0));
}

String _asString(dynamic value) => value is String ? value : '';

String _truncate(String text, int maxChars) {
  if (text.length <= maxChars) return text;
  return '${text.substring(0, maxChars)}...';
}
