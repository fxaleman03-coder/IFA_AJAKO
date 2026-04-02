import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

const String _suggestionsPath = 'build/odu_patch_suggestions.json';
const String _contentPath = 'assets/odu_content.json';
const String _outJsonPath = 'build/tanda1_patch_candidates.json';
const String _outMdPath = 'build/tanda1_patch_candidates.md';

const String _requiredFlag = 'DESC_MARKERS_IN_NACE';
const String _excludedConfidence = 'manual_review';
const int _selectionLimit = 20;
const int _previewChars = 300;
const int _maxBoundedCaptureChars = 2500;

const String _oduWordRegexFragment = r'od(?:ù|u|o)';
const String _descripcionWordRegexFragment = r'descripci(?:ó|o)n';

const String _eshuHeaderPattern =
    r'(?mi)^\s*(?:\d{1,3}\s*[-.)]\s*)?(?:AQU[ÍI]\s*:\s*)?ESHU(?:\b|[\s:\-–—])';

const String _eshuStopMarkerInner =
    r'(?:EN\s+ESTE\s+'
    '$_oduWordRegexFragment'
    r'|'
    '$_descripcionWordRegexFragment'
    r'|EWES|OBRAS|DICE\s+IF[ÁA]|PAT(A|Á)K(I|Í)E|HISTORIAS|REZO|SUYERE|ESHU\s+DEL\s+'
    '$_oduWordRegexFragment'
    r')';

const String _eshuStopMarkerPattern =
    r'(?mi)^\s*'
    '$_eshuStopMarkerInner'
    r'\b';

const String _eshuBoundedRegex =
    r'^\s*(?:\d{1,3}\s*[-.)]\s*)?(?:AQU[ÍI]\s*:\s*)?ESHU(?:\b|[\s:\-–—])[\s\S]{0,2500}?(?=^\s*'
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

  final eligible = <_CandidateResult>[];
  var order = 0;

  for (final entry in suggestionsMap.entries) {
    final oduKey = entry.key;
    final value = entry.value;
    order++;
    if (value is! Map) continue;
    final suggestion = Map<String, dynamic>.from(value);

    final flags = _toStringList(suggestion['flags']);
    final confidence = _asString(suggestion['confidence']);
    final anchorEvidence = _toStringList(suggestion['anchor_evidence']);

    final isEligible =
        flags.contains(_requiredFlag) &&
        confidence != _excludedConfidence &&
        anchorEvidence.isNotEmpty;
    if (!isEligible) {
      continue;
    }

    final naceText = _readNaceText(oduRoot, oduKey);
    final moveOps = _readMoveOpsFromSuggestion(suggestion);

    final plannedOps = <_OperationResult>[];
    for (final op in moveOps) {
      if (op.operationKey == 'move_to_eshu_regex') {
        final bounded = _extractBoundedEshuBlocks(
          naceText,
          maxChars: _maxBoundedCaptureChars,
        );
        plannedOps.add(
          _OperationResult(
            operationKey: op.operationKey,
            targetSection: op.targetSection,
            regex: _eshuBoundedRegex,
            matchCount: bounded.blocks.length,
            estimatedMovedCharCount: bounded.blocks.fold<int>(
              0,
              (int sum, String block) => sum + block.length,
            ),
            previewSnippet: bounded.blocks.isEmpty
                ? ''
                : _truncate(bounded.blocks.first),
            estimationMethod: 'bounded_eshu_match',
            needsManualReview:
                bounded.blocks.isNotEmpty && bounded.noStopBlocks > 0,
            boundedNoStopBlocks: bounded.noStopBlocks,
            boundedTruncatedBlocks: bounded.truncatedBlocks,
          ),
        );
      } else {
        for (final pattern in op.regexes) {
          final result = _runRegexMatch(
            text: naceText,
            pattern: pattern,
            operationKey: op.operationKey,
            targetSection: op.targetSection,
          );
          plannedOps.add(result);
        }
      }
    }

    final hasPositiveMatch = plannedOps.any((op) => op.matchCount > 0);

    eligible.add(
      _CandidateResult(
        order: order,
        oduKey: oduKey,
        flags: flags,
        confidence: confidence,
        anchorEvidence: anchorEvidence,
        operations: plannedOps,
        hasPositiveMatch: hasPositiveMatch,
      ),
    );
  }

  eligible.sort((a, b) {
    if (a.hasPositiveMatch != b.hasPositiveMatch) {
      return a.hasPositiveMatch ? -1 : 1;
    }
    return a.order.compareTo(b.order);
  });

  final selected = eligible.take(_selectionLimit).toList();

  final jsonOut = <String, dynamic>{
    'source_files': <String, String>{
      'suggestions': _suggestionsPath,
      'content': _contentPath,
    },
    'generated_utc': DateTime.now().toUtc().toIso8601String(),
    'selection_criteria': <String, dynamic>{
      'required_flag': _requiredFlag,
      'confidence_not': _excludedConfidence,
      'anchor_evidence_not_empty': true,
      'limit': _selectionLimit,
      'prefer_match_count_gt_0': true,
    },
    'eshu_matching': <String, dynamic>{
      'header_pattern': _eshuHeaderPattern,
      'stop_marker_pattern': _eshuStopMarkerPattern,
      'bounded_regex': _eshuBoundedRegex,
      'max_capture_chars_without_stop': _maxBoundedCaptureChars,
      'notes':
          'When no stop marker is found, capture is capped and marked needs_manual_review=true.',
    },
    'selected_count': selected.length,
    'selected_with_positive_match': selected
        .where((c) => c.hasPositiveMatch)
        .length,
    'candidates': selected.map((c) => c.toJson()).toList(),
  };

  final mdBuffer = StringBuffer();
  mdBuffer.writeln('# TANDA 1 Structural Patch Candidates');
  mdBuffer.writeln();
  mdBuffer.writeln('- Source suggestions: `$_suggestionsPath`');
  mdBuffer.writeln('- Source content: `$_contentPath`');
  mdBuffer.writeln('- Generated (UTC): `${jsonOut['generated_utc']}`');
  mdBuffer.writeln('- Selected candidates: **${selected.length}**');
  mdBuffer.writeln(
    '- Selected with `match_count > 0`: **${selected.where((c) => c.hasPositiveMatch).length}**',
  );
  mdBuffer.writeln();
  mdBuffer.writeln('## Eshu Bounded Matching');
  mdBuffer.writeln('- Header: `$_eshuHeaderPattern`');
  mdBuffer.writeln('- Stop marker: `$_eshuStopMarkerPattern`');
  mdBuffer.writeln(
    '- Safety cap without stop marker: `$_maxBoundedCaptureChars` chars',
  );
  mdBuffer.writeln();

  for (final candidate in selected) {
    mdBuffer.writeln('## `${candidate.oduKey}`');
    mdBuffer.writeln('- Flags: ${candidate.flags.join(' | ')}');
    mdBuffer.writeln('- Confidence: ${candidate.confidence}');
    mdBuffer.writeln(
      '- Anchor evidence: ${candidate.anchorEvidence.isEmpty ? '(none)' : candidate.anchorEvidence.join(' ; ')}',
    );
    mdBuffer.writeln('- Has positive match: `${candidate.hasPositiveMatch}`');
    mdBuffer.writeln('- Proposed move operations:');
    mdBuffer.writeln(
      '| # | Target section | Operation | Regex | Match count | Est. moved chars | Method | Needs manual review | Preview (first $_previewChars chars) |',
    );
    mdBuffer.writeln('|---|---|---|---|---:|---:|---|---|---|');
    if (candidate.operations.isEmpty) {
      mdBuffer.writeln(
        '| 1 | `-` | `-` | `-` | 0 | 0 | `none` | `false` | _No move ops in suggestion_ |',
      );
    } else {
      var index = 1;
      for (final op in candidate.operations) {
        final preview = op.previewSnippet
            .replaceAll('\n', r'\n')
            .replaceAll('|', r'\|');
        final regex = op.regex.replaceAll('|', r'\|');
        mdBuffer.writeln(
          '| $index | `${op.targetSection}` | `${op.operationKey}` | `$regex` | ${op.matchCount} | ${op.estimatedMovedCharCount} | `${op.estimationMethod}` | `${op.needsManualReview}` | $preview |',
        );
        index++;
      }
    }
    mdBuffer.writeln();
  }

  Directory('build').createSync(recursive: true);
  File(
    _outJsonPath,
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(jsonOut));
  File(_outMdPath).writeAsStringSync(mdBuffer.toString());

  stdout.writeln('Eligible by criteria: ${eligible.length}');
  stdout.writeln('Selected candidates: ${selected.length}');
  stdout.writeln(
    'Selected with match_count > 0: ${selected.where((c) => c.hasPositiveMatch).length}',
  );
  stdout.writeln('Wrote: $_outJsonPath');
  stdout.writeln('Wrote: $_outMdPath');
}

String _readNaceText(Map<String, dynamic> oduRoot, String oduKey) {
  final nodeRaw = oduRoot[oduKey];
  if (nodeRaw is! Map) return '';
  final node = Map<String, dynamic>.from(nodeRaw);
  final contentRaw = node['content'];
  if (contentRaw is! Map) return '';
  final content = Map<String, dynamic>.from(contentRaw);
  final nace = _asString(content['nace']);
  return nace.replaceAll('\r\n', '\n');
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
      estimationMethod: 'regex_match',
      needsManualReview: false,
      boundedNoStopBlocks: 0,
      boundedTruncatedBlocks: 0,
    );
  } on FormatException {
    return _OperationResult(
      operationKey: operationKey,
      targetSection: targetSection,
      regex: pattern,
      matchCount: 0,
      estimatedMovedCharCount: 0,
      previewSnippet: '',
      estimationMethod: 'regex_invalid',
      needsManualReview: true,
      boundedNoStopBlocks: 0,
      boundedTruncatedBlocks: 0,
    );
  }
}

_BoundedExtraction _extractBoundedEshuBlocks(
  String source, {
  required int maxChars,
}) {
  final text = source.replaceAll('\r\n', '\n');
  final headers = _eshuHeaderRegex.allMatches(text).toList();
  if (headers.isEmpty) {
    return const _BoundedExtraction(
      blocks: <String>[],
      noStopBlocks: 0,
      truncatedBlocks: 0,
    );
  }

  final blocks = <String>[];
  var noStopBlocks = 0;
  var truncatedBlocks = 0;

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

    late final int end;
    if (stop != null) {
      end = stop;
    } else {
      noStopBlocks++;
      final capped = math.min(start + maxChars, nextHeaderStart);
      end = capped;
      if (capped < nextHeaderStart) {
        truncatedBlocks++;
      }
    }

    if (end <= start) continue;

    final block = text.substring(start, end).trim();
    if (block.isEmpty) continue;
    blocks.add(block);
  }

  return _BoundedExtraction(
    blocks: blocks,
    noStopBlocks: noStopBlocks,
    truncatedBlocks: truncatedBlocks,
  );
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
    required this.estimationMethod,
    required this.needsManualReview,
    required this.boundedNoStopBlocks,
    required this.boundedTruncatedBlocks,
  });

  final String operationKey;
  final String targetSection;
  final String regex;
  final int matchCount;
  final int estimatedMovedCharCount;
  final String previewSnippet;
  final String estimationMethod;
  final bool needsManualReview;
  final int boundedNoStopBlocks;
  final int boundedTruncatedBlocks;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'operation_key': operationKey,
      'target_section': targetSection,
      'regex': regex,
      'match_count': matchCount,
      'estimated_moved_char_count': estimatedMovedCharCount,
      'preview_snippet': previewSnippet,
      'estimation_method': estimationMethod,
      'needs_manual_review': needsManualReview,
      'bounded_no_stop_blocks': boundedNoStopBlocks,
      'bounded_truncated_blocks': boundedTruncatedBlocks,
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
    required this.hasPositiveMatch,
  });

  final int order;
  final String oduKey;
  final List<String> flags;
  final String confidence;
  final List<String> anchorEvidence;
  final List<_OperationResult> operations;
  final bool hasPositiveMatch;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'odu_key': oduKey,
      'flags': flags,
      'confidence': confidence,
      'anchor_evidence': anchorEvidence,
      'has_positive_match': hasPositiveMatch,
      'operations': operations.map((op) => op.toJson()).toList(),
    };
  }
}

class _BoundedExtraction {
  const _BoundedExtraction({
    required this.blocks,
    required this.noStopBlocks,
    required this.truncatedBlocks,
  });

  final List<String> blocks;
  final int noStopBlocks;
  final int truncatedBlocks;
}
