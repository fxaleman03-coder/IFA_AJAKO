import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';

const String _suggestionsPath = 'build/odu_patch_suggestions.json';
const String _contentPath = 'assets/odu_content.json';
const String _patchesPath = 'assets/odu_patches.json';
const String _inputTanda3Path = 'build/tanda3_patch_candidates.json';
const String _outJsonPath = 'build/tanda3_patch_candidates.json';
const String _outMdPath = 'build/tanda3_patch_candidates.md';

const int _selectionLimit = 20;
const int _previewChars = 300;
const int _maxBoundedCaptureChars = 2500;

const Set<String> _requiredAnyFlags = <String>{
  'DESC_EMPTY_BUT_NACE_LONG',
  'DESC_MARKERS_IN_NACE',
};

const String _excludedConfidence = 'manual_review';

const String _stopMarkerInner =
    r'(?:EN\s+ESTE\s+OD(?:O|U|Ù)|'
    r'DESCRIPCI(?:Ó|O)N(?:\s+DEL\s+OD(?:O|U|Ù))?|'
    r'EWE(?:S)?|EW[ÉE]|EVES?|'
    r'OBRA(?:S)?|EB[ÓO]|'
    r'DICE\s+IF[ÁA]|IF[ÁA]\s+DICE|'
    r'PAT(?:A|Á)K(?:I|Í)E(?:S)?|PATAK[ÍI]?|HISTORIA(?:S)?|'
    r'REZO|SUYERE|ORIKI|'
    r'ESHU\s+DEL\s+OD(?:O|U|Ù))';

const String _tier1PrefixPattern =
    r'^\s*(?:(?:[•"\-])\s*)*'
    r'(?:\d{1,3}\s*[-.)]\s*)?'
    r'(?:AQU[ÍI]\s*:\s*)?'
    r'ESHU(?:\b|[\s:\-])';

final RegExp _tier1EshuHeaderRegex = RegExp(
  _tier1PrefixPattern,
  caseSensitive: false,
  multiLine: true,
);

final RegExp _tier2EshuWordRegex = RegExp(
  r'\bESHU\b',
  caseSensitive: false,
);

final RegExp _tier2EshuContextRegex = RegExp(
  r'(?:ELEGBA|ARONI|MANIB|ELEGUA|ELEGÚA|ELEGBA\.|:)',
  caseSensitive: false,
);

final RegExp _stopMarkerRegex = RegExp(
  r'^\s*'
  '$_stopMarkerInner'
  r'\b',
  caseSensitive: false,
  multiLine: true,
);

const String _tier1RegexWithStop =
    '$_tier1PrefixPattern'
    r'[\s\S]{0,2500}?(?=^\s*(?:'
    '$_stopMarkerInner'
    r')\b)';

const String _tier1RegexWithoutStop =
    '$_tier1PrefixPattern'
    r'[\s\S]{0,2500}';

const String _tier2RegexWithStop =
    r'ESHU(?=[\s\S]{0,120}(?:ELEGBA|ARONI|MANIB|ELEGUA|ELEGÚA|ELEGBA\.|:))'
    r'[\s\S]{0,2500}?(?=^\s*(?:'
    '$_stopMarkerInner'
    r')\b)';

const String _tier2RegexWithoutStop =
    r'ESHU(?=[\s\S]{0,120}(?:ELEGBA|ARONI|MANIB|ELEGUA|ELEGÚA|ELEGBA\.|:))'
    r'[\s\S]{0,2500}';

void main() {
  final suggestionsFile = File(_suggestionsPath);
  final contentFile = File(_contentPath);
  final patchesFile = File(_patchesPath);
  final inputTanda3File = File(_inputTanda3Path);

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
  if (!patchesFile.existsSync()) {
    stderr.writeln('Missing input: $_patchesPath');
    exitCode = 1;
    return;
  }
  if (!inputTanda3File.existsSync()) {
    stderr.writeln('Missing input: $_inputTanda3Path');
    exitCode = 1;
    return;
  }

  final suggestionsDecoded = jsonDecode(suggestionsFile.readAsStringSync());
  final contentDecoded = jsonDecode(contentFile.readAsStringSync());
  final patchesDecoded = jsonDecode(patchesFile.readAsStringSync());
  final inputTanda3Decoded = jsonDecode(inputTanda3File.readAsStringSync());

  if (suggestionsDecoded is! Map ||
      contentDecoded is! Map ||
      patchesDecoded is! Map ||
      inputTanda3Decoded is! Map) {
    stderr.writeln('Invalid JSON root in one or more inputs.');
    exitCode = 1;
    return;
  }

  final suggestionsMapRaw = suggestionsDecoded['suggestions'];
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

  final patchesRoot = Map<String, dynamic>.from(patchesDecoded);
  final excludedKeys = patchesRoot.keys
      .where((key) => !key.startsWith('_'))
      .toSet();

  final inputGroupsRaw = inputTanda3Decoded['groups'];
  if (inputGroupsRaw is! Map) {
    stderr.writeln('Invalid input TANDA 3: missing "groups" object.');
    exitCode = 1;
    return;
  }
  final inputGroups = Map<String, dynamic>.from(inputGroupsRaw);
  final rawNeedsList = inputGroups['NEEDS_ADJUSTMENT'];
  if (rawNeedsList is! List) {
    stderr.writeln(
      'Invalid input TANDA 3: missing "groups.NEEDS_ADJUSTMENT" list.',
    );
    exitCode = 1;
    return;
  }

  final requestedKeys = <String>[];
  for (final item in rawNeedsList) {
    if (item is! Map) continue;
    final map = Map<String, dynamic>.from(item);
    final key = _asString(map['odu_key']);
    if (key.isNotEmpty) {
      requestedKeys.add(key);
    }
  }

  final uniqueRequestedKeys = <String>[];
  final seen = <String>{};
  for (final key in requestedKeys) {
    if (seen.add(key)) {
      uniqueRequestedKeys.add(key);
    }
    if (uniqueRequestedKeys.length >= _selectionLimit) {
      break;
    }
  }

  var filteredByFlags = 0;
  var filteredByConfidence = 0;
  var filteredByPatchExclusion = 0;

  final applyReady = <_CandidateResult>[];
  final needsAdjustment = <_CandidateResult>[];

  for (var index = 0; index < uniqueRequestedKeys.length; index++) {
    final oduKey = uniqueRequestedKeys[index];
    final suggestionRaw = suggestionsMap[oduKey];
    if (suggestionRaw is! Map) {
      continue;
    }
    final suggestion = Map<String, dynamic>.from(suggestionRaw);

    final flags = _toStringList(suggestion['flags']);
    if (!flags.any(_requiredAnyFlags.contains)) {
      continue;
    }
    filteredByFlags++;

    final confidence = _asString(suggestion['confidence']);
    if (confidence == _excludedConfidence) {
      continue;
    }
    filteredByConfidence++;

    if (excludedKeys.contains(oduKey)) {
      continue;
    }
    filteredByPatchExclusion++;

    final rawNace = _readNaceText(oduRoot, oduKey);
    final normalizedForMatching = _normalizeForMatching(rawNace);
    final anchorEvidence = _toStringList(suggestion['anchor_evidence']);

    final moveOps = _readMoveOpsFromSuggestion(suggestion);
    final opResults = <_OperationResult>[];
    for (final op in moveOps) {
      if (op.targetSection.toLowerCase() == 'eshu') {
        opResults.add(
          _resolveEshuOp(
            operationKey: op.operationKey,
            targetSection: op.targetSection,
            rawNace: rawNace,
            normalizedForMatching: normalizedForMatching,
          ),
        );
      } else {
        for (final pattern in op.regexes) {
          opResults.add(
            _runGenericRegexMatch(
              text: rawNace,
              pattern: pattern,
              operationKey: op.operationKey,
              targetSection: op.targetSection,
            ),
          );
        }
      }
    }

    final hasPositive = opResults.any((op) => op.matchCount > 0);
    final candidate = _CandidateResult(
      order: index + 1,
      oduKey: oduKey,
      flags: flags,
      confidence: confidence,
      anchorEvidence: anchorEvidence,
      operations: opResults,
      suggestedRegexTweak: _suggestRegexTweak(opResults),
    );
    if (hasPositive) {
      applyReady.add(candidate);
    } else if (anchorEvidence.isNotEmpty) {
      needsAdjustment.add(candidate);
    }
  }

  final selectedApplyReady = <_CandidateResult>[];
  final selectedNeedsAdjustment = <_CandidateResult>[];
  for (final candidate in applyReady) {
    if (selectedApplyReady.length + selectedNeedsAdjustment.length >=
        _selectionLimit) {
      break;
    }
    selectedApplyReady.add(candidate);
  }
  for (final candidate in needsAdjustment) {
    if (selectedApplyReady.length + selectedNeedsAdjustment.length >=
        _selectionLimit) {
      break;
    }
    selectedNeedsAdjustment.add(candidate);
  }

  final selectedTotal =
      selectedApplyReady.length + selectedNeedsAdjustment.length;

  final jsonOut = <String, dynamic>{
    'source_files': <String, String>{
      'suggestions': _suggestionsPath,
      'content': _contentPath,
      'patches': _patchesPath,
      'input_tanda3': _inputTanda3Path,
    },
    'generated_utc': DateTime.now().toUtc().toIso8601String(),
    'selection_criteria': <String, dynamic>{
      'input_keys_source': 'groups.NEEDS_ADJUSTMENT from previous TANDA 3',
      'input_requested_keys_count': uniqueRequestedKeys.length,
      'flags_contains_any': _requiredAnyFlags.toList()..sort(),
      'confidence_not': _excludedConfidence,
      'exclude_if_key_exists_in_patches_json': true,
      'max_candidates_total': _selectionLimit,
      'eshu_strategy': <String, dynamic>{
        'tier1': _tier1EshuHeaderRegex.pattern,
        'tier2_word': _tier2EshuWordRegex.pattern,
        'tier2_context_within_120_chars': _tier2EshuContextRegex.pattern,
        'stop_markers': _stopMarkerRegex.pattern,
        'max_capture_chars': _maxBoundedCaptureChars,
      },
    },
    'counts': <String, int>{
      'requested_keys': uniqueRequestedKeys.length,
      'excluded_keys_from_patches': excludedKeys.length,
      'after_flag_filter': filteredByFlags,
      'after_confidence_filter': filteredByConfidence,
      'after_patch_exclusion': filteredByPatchExclusion,
      'apply_ready_count': selectedApplyReady.length,
      'needs_adjustment_count': selectedNeedsAdjustment.length,
      'selected_total': selectedTotal,
    },
    'groups': <String, dynamic>{
      'APPLY_READY': selectedApplyReady.map((c) => c.toJson()).toList(),
      'NEEDS_ADJUSTMENT': selectedNeedsAdjustment
          .map((c) => c.toJson())
          .toList(),
    },
  };

  final md = StringBuffer()
    ..writeln('# TANDA 3 Patch Candidates')
    ..writeln()
    ..writeln('- Source suggestions: `$_suggestionsPath`')
    ..writeln('- Source content: `$_contentPath`')
    ..writeln('- Source patches (exclusion keys): `$_patchesPath`')
    ..writeln('- Input TANDA 3 seed: `$_inputTanda3Path`')
    ..writeln('- Generated (UTC): `${jsonOut['generated_utc']}`')
    ..writeln('- Requested keys from previous NEEDS_ADJUSTMENT: **${uniqueRequestedKeys.length}**')
    ..writeln('- Max candidates: **$_selectionLimit**')
    ..writeln('- Selected total: **$selectedTotal**')
    ..writeln()
    ..writeln('## Counts')
    ..writeln('- Excluded keys from patches: `${excludedKeys.length}`')
    ..writeln('- After flag filter: `$filteredByFlags`')
    ..writeln('- After confidence filter: `$filteredByConfidence`')
    ..writeln('- After patch exclusion: `$filteredByPatchExclusion`')
    ..writeln('- APPLY_READY count: `${selectedApplyReady.length}`')
    ..writeln('- NEEDS_ADJUSTMENT count: `${selectedNeedsAdjustment.length}`')
    ..writeln()
    ..writeln('## APPLY_READY');

  if (selectedApplyReady.isEmpty) {
    md.writeln('_No candidates selected._');
    md.writeln();
  } else {
    for (final candidate in selectedApplyReady) {
      _writeCandidateMarkdown(md, candidate, includeTweak: false);
    }
  }

  md.writeln('## NEEDS_ADJUSTMENT');
  if (selectedNeedsAdjustment.isEmpty) {
    md.writeln('_No candidates selected._');
    md.writeln();
  } else {
    for (final candidate in selectedNeedsAdjustment) {
      _writeCandidateMarkdown(md, candidate, includeTweak: true);
    }
  }

  Directory('build').createSync(recursive: true);
  File(
    _outJsonPath,
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(jsonOut));
  File(_outMdPath).writeAsStringSync(md.toString());

  stdout.writeln('Generated TANDA 3 candidates with 3-tier ESHU strategy.');
  stdout.writeln('APPLY_READY count: ${selectedApplyReady.length}');
  stdout.writeln('NEEDS_ADJUSTMENT count: ${selectedNeedsAdjustment.length}');
  stdout.writeln('Selected total: $selectedTotal');
  stdout.writeln('Wrote: $_outJsonPath');
  stdout.writeln('Wrote: $_outMdPath');
}

_OperationResult _resolveEshuOp({
  required String operationKey,
  required String targetSection,
  required String rawNace,
  required String normalizedForMatching,
}) {
  final tier1Starts = _tier1EshuHeaderRegex
      .allMatches(normalizedForMatching)
      .map((m) => m.start)
      .toList();

  if (tier1Starts.isNotEmpty) {
    final tier1HasStop = _hasStopWithinWindow(
      normalizedForMatching,
      startIndex: tier1Starts.first,
    );
    final tier1Regex = tier1HasStop ? _tier1RegexWithStop : _tier1RegexWithoutStop;
    final tier1Result = _runRegexWithMeta(
      text: rawNace,
      pattern: tier1Regex,
      operationKey: operationKey,
      targetSection: targetSection,
      method: tier1HasStop
          ? 'tier1_bounded_stop_match'
          : 'tier1_bounded_cap_match',
      needsManualReview: !tier1HasStop,
    );
    if (tier1Result.matchCount > 0) {
      return tier1Result;
    }
  }

  final tier2Starts = _findTier2Starts(normalizedForMatching);
  if (tier2Starts.isNotEmpty) {
    final tier2HasStop = _hasStopWithinWindow(
      normalizedForMatching,
      startIndex: tier2Starts.first,
    );
    final tier2Regex = tier2HasStop ? _tier2RegexWithStop : _tier2RegexWithoutStop;
    final tier2Result = _runRegexWithMeta(
      text: rawNace,
      pattern: tier2Regex,
      operationKey: operationKey,
      targetSection: targetSection,
      method: tier2HasStop
          ? 'tier2_bounded_stop_match'
          : 'tier2_bounded_cap_match',
      needsManualReview: !tier2HasStop,
    );
    if (tier2Result.matchCount > 0) {
      return tier2Result;
    }
  }

  final fallbackPreview = _fallbackEshuPreview(
    normalizedForMatching,
    tier1Starts: tier1Starts,
    tier2Starts: tier2Starts,
  );
  return _OperationResult(
    operationKey: operationKey,
    targetSection: targetSection,
    regex: _tier2RegexWithoutStop,
    matchCount: 0,
    previewSnippet: fallbackPreview,
    estimationMethod: 'tier1_tier2_no_match',
    needsManualReview: true,
  );
}

List<int> _findTier2Starts(String normalized) {
  final starts = <int>[];
  var cursor = 0;
  final lines = normalized.split('\n');
  for (final line in lines) {
    var searchOffset = 0;
    while (searchOffset < line.length) {
      final segment = line.substring(searchOffset);
      final match = _tier2EshuWordRegex.firstMatch(segment);
      if (match == null) {
        break;
      }
      final absoluteLineStart = searchOffset + match.start;
      final windowStart = absoluteLineStart;
      final windowEnd = math.min(line.length, absoluteLineStart + 120);
      final window = line.substring(windowStart, windowEnd);
      if (_tier2EshuContextRegex.hasMatch(window)) {
        starts.add(cursor + absoluteLineStart);
        break;
      }
      searchOffset = absoluteLineStart + 4;
    }
    cursor += line.length + 1;
  }
  return starts;
}

bool _hasStopWithinWindow(
  String normalized, {
  required int startIndex,
}) {
  if (startIndex < 0 || startIndex >= normalized.length) {
    return false;
  }
  final searchFrom = math.min(startIndex + 1, normalized.length);
  final searchTo = math.min(startIndex + _maxBoundedCaptureChars, normalized.length);
  if (searchFrom >= searchTo) {
    return false;
  }
  final slice = normalized.substring(searchFrom, searchTo);
  return _stopMarkerRegex.hasMatch(slice);
}

String _normalizeForMatching(String input) {
  var text = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  text = text.replaceAll('“', '"').replaceAll('”', '"');
  text = text.replaceAll('–', '-').replaceAll('—', '-');
  final lines = text.split('\n');
  final normalizedLines = lines
      .map((line) => line.replaceAll(RegExp(r'[ \t]{2,}'), ' '))
      .toList();
  return normalizedLines.join('\n');
}

_OperationResult _runRegexWithMeta({
  required String text,
  required String pattern,
  required String operationKey,
  required String targetSection,
  required String method,
  required bool needsManualReview,
}) {
  try {
    final regex = RegExp(
      pattern,
      caseSensitive: false,
      multiLine: true,
      dotAll: true,
    );
    final matches = regex.allMatches(text).toList();
    final preview = matches.isNotEmpty ? _truncate(matches.first.group(0) ?? '') : '';
    return _OperationResult(
      operationKey: operationKey,
      targetSection: targetSection,
      regex: pattern,
      matchCount: matches.length,
      previewSnippet: preview,
      estimationMethod: method,
      needsManualReview: needsManualReview,
    );
  } on FormatException {
    return _OperationResult(
      operationKey: operationKey,
      targetSection: targetSection,
      regex: pattern,
      matchCount: 0,
      previewSnippet: '',
      estimationMethod: 'regex_invalid',
      needsManualReview: true,
    );
  }
}

_OperationResult _runGenericRegexMatch({
  required String text,
  required String pattern,
  required String operationKey,
  required String targetSection,
}) {
  try {
    final regex = RegExp(
      pattern,
      caseSensitive: false,
      multiLine: true,
      dotAll: true,
    );
    final matches = regex.allMatches(text).toList();
    return _OperationResult(
      operationKey: operationKey,
      targetSection: targetSection,
      regex: pattern,
      matchCount: matches.length,
      previewSnippet: matches.isNotEmpty
          ? _truncate(matches.first.group(0) ?? '')
          : _previewFromMarker(text, targetSection),
      estimationMethod: matches.isNotEmpty ? 'regex_match' : 'no_match',
      needsManualReview: matches.isEmpty,
    );
  } on FormatException {
    return _OperationResult(
      operationKey: operationKey,
      targetSection: targetSection,
      regex: pattern,
      matchCount: 0,
      previewSnippet: _previewFromMarker(text, targetSection),
      estimationMethod: 'regex_invalid',
      needsManualReview: true,
    );
  }
}

String _fallbackEshuPreview(
  String normalized, {
  required List<int> tier1Starts,
  required List<int> tier2Starts,
}) {
  final start = tier1Starts.isNotEmpty
      ? tier1Starts.first
      : tier2Starts.isNotEmpty
      ? tier2Starts.first
      : -1;
  if (start < 0 || start >= normalized.length) {
    return '';
  }
  final end = math.min(normalized.length, start + _previewChars);
  return _truncate(normalized.substring(start, end));
}

String _previewFromMarker(String text, String targetSection) {
  RegExp? marker;
  switch (targetSection.toLowerCase()) {
    case 'eshu':
      marker = RegExp(r'ESHU(?:\b|[\s:\-])', caseSensitive: false);
      break;
    case 'desc':
    case 'descripcion':
      marker = RegExp(
        r'descripci(?:ó|o)n\s+del\s+od(?:ù|u|o)|este\s+es\s+el\s+odu',
        caseSensitive: false,
      );
      break;
    case 'ewes':
      marker = RegExp(r'EW(?:E|ES|É|EVES?)\b', caseSensitive: false);
      break;
    case 'obras':
      marker = RegExp(r'OBRA(?:S)?|EB[ÓO]\b', caseSensitive: false);
      break;
    case 'diceifa':
    case 'dice_ifa':
      marker = RegExp(r'DICE\s+IF[ÁA]|IF[ÁA]\s+DICE', caseSensitive: false);
      break;
    default:
      marker = null;
  }
  if (marker == null) return '';
  final match = marker.firstMatch(text);
  if (match == null) return '';
  final start = match.start;
  final end = math.min(text.length, start + _previewChars);
  return _truncate(text.substring(start, end));
}

String _suggestRegexTweak(List<_OperationResult> operations) {
  if (operations.any((op) => op.estimationMethod == 'regex_invalid')) {
    return 'Use Dart-compatible regex (avoid inline flags like `(?mis)`); rely on RegExp options in code.';
  }
  if (operations.any((op) => op.targetSection.toLowerCase() == 'eshu')) {
    return 'Prefer tiered ESHU anchors (line-start first, then embedded + context) with 2500-char bounded capture and expanded stop markers.';
  }
  if (operations.any((op) => op.targetSection.toLowerCase().contains('desc'))) {
    return 'Anchor on `descripci(?:ó|o)n del od(?:o|u|ù)` (or `ESTE ES EL ODU`) and stop before next known section header.';
  }
  return 'Tighten start anchor and add conservative stop markers with bounded capture.';
}

void _writeCandidateMarkdown(
  StringBuffer md,
  _CandidateResult candidate, {
  required bool includeTweak,
}) {
  md.writeln('### `${candidate.oduKey}`');
  md.writeln('- Flags: ${candidate.flags.join(' | ')}');
  md.writeln('- Confidence: ${candidate.confidence}');
  md.writeln(
    '- Anchor evidence: ${candidate.anchorEvidence.isEmpty ? '(none)' : candidate.anchorEvidence.join(' ; ')}',
  );
  if (includeTweak) {
    md.writeln('- Suggested regex tweak: ${candidate.suggestedRegexTweak}');
  }
  md.writeln(
    '| # | Target section | Operation | Regex | Match count | Estimation method | Needs manual review | Preview snippet |',
  );
  md.writeln('|---|---|---|---|---:|---|---|---|');
  var index = 1;
  for (final op in candidate.operations) {
    final regex = op.regex.replaceAll('|', r'\|');
    final preview = op.previewSnippet
        .replaceAll('\n', r'\n')
        .replaceAll('|', r'\|');
    md.writeln(
      '| $index | `${op.targetSection}` | `${op.operationKey}` | `$regex` | ${op.matchCount} | `${op.estimationMethod}` | `${op.needsManualReview}` | $preview |',
    );
    index++;
  }
  md.writeln();
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
    required this.previewSnippet,
    required this.estimationMethod,
    required this.needsManualReview,
  });

  final String operationKey;
  final String targetSection;
  final String regex;
  final int matchCount;
  final String previewSnippet;
  final String estimationMethod;
  final bool needsManualReview;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'operation_key': operationKey,
      'target_section': targetSection,
      'regex': regex,
      'match_count': matchCount,
      'preview_snippet': previewSnippet,
      'estimation_method': estimationMethod,
      'needs_manual_review': needsManualReview,
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
    required this.suggestedRegexTweak,
  });

  final int order;
  final String oduKey;
  final List<String> flags;
  final String confidence;
  final List<String> anchorEvidence;
  final List<_OperationResult> operations;
  final String suggestedRegexTweak;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'odu_key': oduKey,
      'flags': flags,
      'confidence': confidence,
      'anchor_evidence': anchorEvidence,
      'operations': operations.map((o) => o.toJson()).toList(),
      'suggested_regex_tweak': suggestedRegexTweak,
    };
  }
}
