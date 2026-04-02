import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

const String _suggestionsPath = 'build/odu_patch_suggestions.json';
const String _contentPath = 'assets/odu_content.json';
const String _outJsonPath = 'build/tanda2_patch_candidates.json';
const String _outMdPath = 'build/tanda2_patch_candidates.md';

const int _selectionLimit = 15;
const int _previewChars = 300;
const int _maxBoundedCaptureChars = 2500;
const String _excludedConfidence = 'manual_review';

const Set<String> _requiredAnyFlags = <String>{
  'DESC_EMPTY_BUT_NACE_LONG',
  'DESC_MARKERS_IN_NACE',
};

const Set<String> _excludedOduKeys = <String>{
  'OKANA YABILE',
  'IWORI MEJI',
  'OBARA KASIKA',
  'OGBE ROSO',
  'OJUANI HERMOSO',
  'OJUANI POKON',
  'OKANA SA',
  'OSA MEJI',
};

const String _oduWordRegexFragment = r'od(?:ù|u|o)';
const String _descripcionWordRegexFragment = r'descripci(?:ó|o)n';

const String _eshuStopMarkerInner =
    r'(?:EN\s+ESTE\s+'
    '$_oduWordRegexFragment'
    r'|'
    '$_descripcionWordRegexFragment'
    r'|EWES|OBRAS|DICE\s+IF[ÁA]|PAT(A|Á)K(I|Í)E|HISTORIAS|REZO|SUYERE|ESHU\s+DEL\s+'
    '$_oduWordRegexFragment'
    r')';

const String _eshuBoundedRegex =
    r'(?mis)^\s*(?:\d{1,3}\s*[-.)]\s*)?(?:AQU[ÍI]\s*:\s*)?ESHU(?:\b|[\s:\-–—])[\s\S]{0,2500}?(?=^\s*'
    '$_eshuStopMarkerInner'
    r'\b|(?![\s\S]))';

final RegExp _eshuHeaderRegex = RegExp(
  r'^\s*(?:\d{1,3}\s*[-.)]\s*)?(?:AQU[ÍI]\s*:\s*)?ESHU(?:\b|[\s:\-–—])',
  caseSensitive: false,
  multiLine: true,
);

final RegExp _eshuStopRegex = RegExp(
  r'^\s*'
  '$_eshuStopMarkerInner'
  r'\b',
  caseSensitive: false,
  multiLine: true,
);

void main() {
  final suggestionsFile = File(_suggestionsPath);
  final contentFile = File(_contentPath);

  if (!suggestionsFile.existsSync()) {
    stderr.writeln('Missing input: $_suggestionsPath');
    exitCode = 1;
    return;
  }
  if (!contentFile.existsSync()) {
    stderr.writeln('Missing input: $_contentPath');
    exitCode = 1;
    return;
  }

  final suggestionsDecoded = jsonDecode(suggestionsFile.readAsStringSync());
  final contentDecoded = jsonDecode(contentFile.readAsStringSync());

  if (suggestionsDecoded is! Map || contentDecoded is! Map) {
    stderr.writeln('Invalid JSON root in one or more inputs.');
    exitCode = 1;
    return;
  }

  final suggestionsRoot = Map<String, dynamic>.from(suggestionsDecoded);
  final suggestionsMapRaw = suggestionsRoot['suggestions'];
  if (suggestionsMapRaw is! Map) {
    stderr.writeln(
      'Invalid suggestions payload: missing "suggestions" object.',
    );
    exitCode = 1;
    return;
  }
  final suggestionsMap = Map<String, dynamic>.from(suggestionsMapRaw);

  final contentRoot = Map<String, dynamic>.from(contentDecoded);
  final oduRootRaw = contentRoot['odu'];
  if (oduRootRaw is! Map) {
    stderr.writeln('Invalid content payload: missing "odu" object.');
    exitCode = 1;
    return;
  }
  final oduRoot = Map<String, dynamic>.from(oduRootRaw);

  final allEntries = suggestionsMap.entries.toList();

  var checkedByFlags = 0;
  var checkedByConfidence = 0;
  var checkedByExclude = 0;
  var checkedByPositiveMatch = 0;

  final eligible = <_CandidateResult>[];

  for (var i = 0; i < allEntries.length; i++) {
    final entry = allEntries[i];
    final oduKey = entry.key;
    final value = entry.value;
    if (value is! Map) continue;

    final suggestion = Map<String, dynamic>.from(value);
    final flags = _toStringList(suggestion['flags']);
    final confidence = _asString(suggestion['confidence']);

    final hasRequiredFlag = flags.any(_requiredAnyFlags.contains);
    if (!hasRequiredFlag) {
      continue;
    }
    checkedByFlags++;

    if (confidence == _excludedConfidence) {
      continue;
    }
    checkedByConfidence++;

    if (_excludedOduKeys.contains(oduKey)) {
      continue;
    }
    checkedByExclude++;

    final naceText = _readNaceText(oduRoot, oduKey);
    final moveOps = _readMoveOpsFromSuggestion(suggestion);

    final operationResults = <_OperationResult>[];
    for (final op in moveOps) {
      if (op.operationKey == 'move_to_eshu_regex') {
        final bounded = _extractBoundedEshuBlocks(
          naceText,
          maxChars: _maxBoundedCaptureChars,
        );
        if (bounded.blocks.isNotEmpty) {
          operationResults.add(
            _OperationResult(
              operationKey: op.operationKey,
              targetSection: op.targetSection,
              regex: _eshuBoundedRegex,
              matchCount: bounded.blocks.length,
              estimatedMovedCharCount: bounded.blocks.fold<int>(
                0,
                (sum, block) => sum + block.length,
              ),
              previewSnippet: _truncate(bounded.blocks.first),
            ),
          );
        }
      } else {
        for (final pattern in op.regexes) {
          final result = _runRegexMatch(
            text: naceText,
            pattern: pattern,
            operationKey: op.operationKey,
            targetSection: op.targetSection,
          );
          if (result.matchCount > 0) {
            operationResults.add(result);
          }
        }
      }
    }

    if (operationResults.isEmpty) {
      continue;
    }
    checkedByPositiveMatch++;

    final anchorEvidence = _toStringList(suggestion['anchor_evidence']);
    eligible.add(
      _CandidateResult(
        order: i + 1,
        oduKey: oduKey,
        flags: flags,
        confidence: confidence,
        anchorEvidence: anchorEvidence,
        operations: operationResults,
      ),
    );
  }

  // Keep deterministic ordering from source suggestions file.
  eligible.sort((a, b) => a.order.compareTo(b.order));

  final selected = eligible.take(_selectionLimit).toList();

  final jsonOut = <String, dynamic>{
    'source_files': <String, String>{
      'suggestions': _suggestionsPath,
      'content': _contentPath,
    },
    'generated_utc': DateTime.now().toUtc().toIso8601String(),
    'selection_criteria': <String, dynamic>{
      'flags_contains_any': _requiredAnyFlags.toList()..sort(),
      'confidence_not': _excludedConfidence,
      'exclude_odus': _excludedOduKeys.toList()..sort(),
      'real_match_count_gt_0': true,
      'selection_limit': _selectionLimit,
      'ordering': 'source_suggestions_order',
    },
    'counts': <String, int>{
      'suggestions_total': allEntries.length,
      'after_flag_filter': checkedByFlags,
      'after_confidence_filter': checkedByConfidence,
      'after_exclusion_filter': checkedByExclude,
      'after_real_match_filter': checkedByPositiveMatch,
      'selected': selected.length,
    },
    'candidates': selected.map((c) => c.toJson()).toList(),
  };

  final mdBuffer = StringBuffer();
  mdBuffer.writeln('# TANDA 2 Structural Patch Candidates');
  mdBuffer.writeln();
  mdBuffer.writeln('- Source suggestions: `$_suggestionsPath`');
  mdBuffer.writeln('- Source content: `$_contentPath`');
  mdBuffer.writeln('- Generated (UTC): `${jsonOut['generated_utc']}`');
  mdBuffer.writeln('- Selection limit: **$_selectionLimit**');
  mdBuffer.writeln('- Selected: **${selected.length}**');
  mdBuffer.writeln();
  mdBuffer.writeln('## Filters');
  mdBuffer.writeln(
    '- Flags contains any: `${(_requiredAnyFlags.toList()..sort()).join(' | ')}`',
  );
  mdBuffer.writeln('- Confidence != `$_excludedConfidence`');
  mdBuffer.writeln('- Excluded odù keys: `${_excludedOduKeys.join(' | ')}`');
  mdBuffer.writeln('- Real regex match against `assets/odu_content.json`: `match_count > 0`');
  mdBuffer.writeln();
  mdBuffer.writeln('## Counts');
  mdBuffer.writeln('- Suggestions total: `${allEntries.length}`');
  mdBuffer.writeln('- After flag filter: `$checkedByFlags`');
  mdBuffer.writeln('- After confidence filter: `$checkedByConfidence`');
  mdBuffer.writeln('- After exclusion filter: `$checkedByExclude`');
  mdBuffer.writeln('- After real-match filter: `$checkedByPositiveMatch`');
  mdBuffer.writeln('- Selected: `${selected.length}`');
  mdBuffer.writeln();

  for (final candidate in selected) {
    mdBuffer.writeln('## `${candidate.oduKey}`');
    mdBuffer.writeln('- Flags: ${candidate.flags.join(' | ')}');
    mdBuffer.writeln('- Confidence: ${candidate.confidence}');
    mdBuffer.writeln(
      '- Anchor evidence: ${candidate.anchorEvidence.isEmpty ? '(none)' : candidate.anchorEvidence.join(' ; ')}',
    );
    mdBuffer.writeln('- Proposed move operations (`match_count > 0` only):');
    mdBuffer.writeln(
      '| # | Target section | Operation | Regex | Match count | Est. moved chars | Preview (first $_previewChars chars) |',
    );
    mdBuffer.writeln('|---|---|---|---|---:|---:|---|');

    var opIndex = 1;
    for (final op in candidate.operations) {
      final preview = op.previewSnippet
          .replaceAll('\n', r'\n')
          .replaceAll('|', r'\|');
      final regex = op.regex.replaceAll('|', r'\|');
      mdBuffer.writeln(
        '| $opIndex | `${op.targetSection}` | `${op.operationKey}` | `$regex` | ${op.matchCount} | ${op.estimatedMovedCharCount} | $preview |',
      );
      opIndex++;
    }
    mdBuffer.writeln();
  }

  Directory('build').createSync(recursive: true);
  File(
    _outJsonPath,
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(jsonOut));
  File(_outMdPath).writeAsStringSync(mdBuffer.toString());

  stdout.writeln('Generated TANDA 2 with real match filter.');
  stdout.writeln('Suggestions total: ${allEntries.length}');
  stdout.writeln('After flags: $checkedByFlags');
  stdout.writeln('After confidence: $checkedByConfidence');
  stdout.writeln('After exclusions: $checkedByExclude');
  stdout.writeln('After real matches: $checkedByPositiveMatch');
  stdout.writeln('Selected: ${selected.length}');
  stdout.writeln('Wrote: $_outJsonPath');
  stdout.writeln('Wrote: $_outMdPath');
}

_BoundedExtraction _extractBoundedEshuBlocks(
  String source, {
  required int maxChars,
}) {
  final text = source.replaceAll('\r\n', '\n');
  final headers = _eshuHeaderRegex.allMatches(text).toList();
  if (headers.isEmpty) {
    return const _BoundedExtraction(blocks: <String>[]);
  }

  final blocks = <String>[];

  for (var i = 0; i < headers.length; i++) {
    final start = headers[i].start;
    final nextHeaderStart = i + 1 < headers.length
        ? headers[i + 1].start
        : text.length;
    final stop = _firstStopIndex(
      text: text,
      from: start + 1,
      toExclusive: nextHeaderStart,
    );

    final end = stop ?? math.min(start + maxChars, nextHeaderStart);
    if (end <= start) continue;

    final block = text.substring(start, end).trim();
    if (block.isEmpty) continue;
    blocks.add(block);
  }

  return _BoundedExtraction(blocks: blocks);
}

int? _firstStopIndex({
  required String text,
  required int from,
  required int toExclusive,
}) {
  if (from >= toExclusive) return null;
  final slice = text.substring(from, toExclusive);
  final match = _eshuStopRegex.firstMatch(slice);
  if (match == null) return null;
  return from + match.start;
}

String _readNaceText(Map<String, dynamic> oduRoot, String oduKey) {
  final nodeRaw = oduRoot[oduKey];
  if (nodeRaw is! Map) return '';
  final node = Map<String, dynamic>.from(nodeRaw);
  final contentRaw = node['content'];
  if (contentRaw is! Map) return '';
  final content = Map<String, dynamic>.from(contentRaw);
  return _asString(content['nace']).replaceAll('\r\n', '\n');
}

List<_RawMoveOp> _readMoveOpsFromSuggestion(Map<String, dynamic> suggestion) {
  final patchOpsRaw = suggestion['patch_ops'];
  if (patchOpsRaw is! Map) return const <_RawMoveOp>[];
  final patchOps = Map<String, dynamic>.from(patchOpsRaw);
  final naceRaw = patchOps['nace'];
  if (naceRaw is! Map) return const <_RawMoveOp>[];
  final naceOps = Map<String, dynamic>.from(naceRaw);

  final result = <_RawMoveOp>[];
  for (final entry in naceOps.entries) {
    final key = entry.key;
    if (!key.startsWith('move_to_') || !key.endsWith('_regex')) {
      continue;
    }
    final target = key.substring(
      'move_to_'.length,
      key.length - '_regex'.length,
    );
    final regexes = _toStringList(
      entry.value,
    ).where((s) => s.trim().isNotEmpty).toList();
    if (regexes.isEmpty) continue;
    result.add(
      _RawMoveOp(operationKey: key, targetSection: target, regexes: regexes),
    );
  }
  return result;
}

_OperationResult _runRegexMatch({
  required String text,
  required String pattern,
  required String operationKey,
  required String targetSection,
}) {
  try {
    final regExp = RegExp(pattern, caseSensitive: false, multiLine: true);
    final matches = regExp.allMatches(text).toList();
    final movedChars = matches.fold<int>(
      0,
      (int sum, Match m) => sum + (m.group(0)?.length ?? 0),
    );
    return _OperationResult(
      operationKey: operationKey,
      targetSection: targetSection,
      regex: pattern,
      matchCount: matches.length,
      estimatedMovedCharCount: movedChars,
      previewSnippet: matches.isEmpty
          ? ''
          : _truncate(matches.first.group(0) ?? ''),
    );
  } on FormatException {
    return _OperationResult(
      operationKey: operationKey,
      targetSection: targetSection,
      regex: pattern,
      matchCount: 0,
      estimatedMovedCharCount: 0,
      previewSnippet: '',
    );
  }
}

List<String> _toStringList(dynamic value) {
  if (value is List) {
    return value.map((e) => _asString(e)).where((e) => e.isNotEmpty).toList();
  }
  final single = _asString(value);
  if (single.isEmpty) return const <String>[];
  return <String>[single];
}

String _asString(dynamic value) {
  if (value == null) return '';
  if (value is String) return value;
  return value.toString();
}

String _truncate(String value) {
  final trimmed = value.trim();
  if (trimmed.length <= _previewChars) {
    return trimmed;
  }
  return trimmed.substring(0, _previewChars);
}

class _RawMoveOp {
  const _RawMoveOp({
    required this.operationKey,
    required this.targetSection,
    required this.regexes,
  });

  final String operationKey;
  final String targetSection;
  final List<String> regexes;
}

class _OperationResult {
  const _OperationResult({
    required this.operationKey,
    required this.targetSection,
    required this.regex,
    required this.matchCount,
    required this.estimatedMovedCharCount,
    required this.previewSnippet,
  });

  final String operationKey;
  final String targetSection;
  final String regex;
  final int matchCount;
  final int estimatedMovedCharCount;
  final String previewSnippet;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'operation_key': operationKey,
      'target_section': targetSection,
      'regex': regex,
      'match_count': matchCount,
      'estimated_moved_char_count': estimatedMovedCharCount,
      'preview_snippet': previewSnippet,
    };
  }
}

class _CandidateResult {
  const _CandidateResult({
    required this.order,
    required this.oduKey,
    required this.flags,
    required this.confidence,
    required this.anchorEvidence,
    required this.operations,
  });

  final int order;
  final String oduKey;
  final List<String> flags;
  final String confidence;
  final List<String> anchorEvidence;
  final List<_OperationResult> operations;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'odu_key': oduKey,
      'flags': flags,
      'confidence': confidence,
      'anchor_evidence': anchorEvidence,
      'operations': operations.map((o) => o.toJson()).toList(),
    };
  }
}

class _BoundedExtraction {
  const _BoundedExtraction({required this.blocks});

  final List<String> blocks;
}
