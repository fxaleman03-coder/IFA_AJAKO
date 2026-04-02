import 'dart:convert';
import 'dart:io';

const String _sourcePath = 'assets/odu_content_patched.json';
const String _outJsonPath = 'build/tanda9_desc_classifier_candidates.json';
const String _outMdPath = 'build/tanda9_desc_classifier_candidates.md';
const String _outSamplePath = 'build/tanda9_apply_ready_sample.md';

const int _maxCaptureChars = 3000;
const int _previewBeforeChars = 300;
const int _previewAfterChars = 900;

final List<String> _suyereForbiddenFolded = <String>[
  'descripc',
  'obras',
  'dice ifa',
  'ewes',
  'en este odu',
  'en este odo',
];

final List<String> _rezoInvocationFolded = <String>[
  'orunmila',
  'ifa',
  'eshu',
  'olodumare',
];

final List<String> _rezoForbiddenFolded = <String>[
  'nacen',
  'ewes',
  'obras',
  'dice ifa',
  'histor',
  'patak',
  'suyere',
];

final RegExp _rezoInvocationLineSignalRegex = RegExp(
  r'\b(?:KAFEREFUN|MOYUGBA|IBORU|IBOYA|IBOSHESHE)\b',
  caseSensitive: false,
);

final RegExp _rezoRitualSignalRegex = RegExp(
  r'\bADIFAFUN\b(?:\s+\S+){0,8}',
  caseSensitive: false,
);

final RegExp _rezoHeaderForbiddenRegex = RegExp(
  r'\bREZO\s*:',
  caseSensitive: false,
  multiLine: true,
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
  final oduKeys = oduMap.keys.whereType<String>().toList()..sort();

  final candidates = <Map<String, dynamic>>[];
  final seenCandidates = <String>{};

  var totalScanned = 0;
  var suyereDetected = 0;
  var rezoDetected = 0;

  for (final oduKey in oduKeys) {
    final nodeRaw = oduMap[oduKey];
    if (nodeRaw is! Map) continue;
    final node = Map<String, dynamic>.from(nodeRaw);
    final contentRaw = node['content'];
    if (contentRaw is! Map) continue;
    final content = Map<String, dynamic>.from(contentRaw);

    final descripcion = _asString(content['descripcion']);
    final normalizedDescripcion = _normalizeNewlines(descripcion);
    totalScanned++;
    if (normalizedDescripcion.trim().isEmpty) {
      continue;
    }

    final lines = _lineInfos(normalizedDescripcion);

    // 1) Detect strict suyere-like blocks from short-line consecutive runs.
    final suyereBlocks = _detectSuyereBlocks(
      lines: lines,
      rawText: normalizedDescripcion,
    );
    for (final block in suyereBlocks) {
      suyereDetected++;
      final candidate = _toCandidate(
        oduKey: oduKey,
        proposedTarget: 'suyereYoruba',
        descripcionRaw: normalizedDescripcion,
        block: block,
      );
      final dedupeKey =
          '$oduKey|${candidate['proposed_target']}|${candidate['regex_move']}';
      if (seenCandidates.add(dedupeKey)) {
        candidates.add(candidate);
      }
    }

    // 2) Detect strict rezo-like paragraph blocks.
    final rezoBlocks = _detectRezoBlocks(rawText: normalizedDescripcion);
    for (final block in rezoBlocks) {
      final candidate = _toCandidate(
        oduKey: oduKey,
        proposedTarget: 'rezoYoruba',
        descripcionRaw: normalizedDescripcion,
        block: block,
      );
      // Rezo v2 doctrinal rule: if it's not unequivocally safe, do not emit.
      if (!((candidate['SAFE_TO_APPLY'] as bool?) ?? false)) {
        continue;
      }
      final dedupeKey =
          '$oduKey|${candidate['proposed_target']}|${candidate['regex_move']}';
      if (seenCandidates.add(dedupeKey)) {
        rezoDetected++;
        candidates.add(candidate);
      }
    }
  }

  final applyReady = candidates
      .where((c) => (c['SAFE_TO_APPLY'] as bool?) ?? false)
      .toList();
  final needsReview = candidates
      .where((c) => !((c['SAFE_TO_APPLY'] as bool?) ?? false))
      .toList();

  final jsonOut = <String, dynamic>{
    'source_file': _sourcePath,
    'generated_utc': DateTime.now().toUtc().toIso8601String(),
    'summary': <String, dynamic>{
      'total_scanned': totalScanned,
      'suyere_detected': suyereDetected,
      'rezo_detected': rezoDetected,
      'apply_ready_count': applyReady.length,
      'needs_review_count': needsReview.length,
    },
    'groups': <String, dynamic>{
      'APPLY_READY': applyReady,
      'NEEDS_REVIEW': needsReview,
    },
    'candidates': candidates,
  };

  final md = StringBuffer()
    ..writeln('# TANDA 9 Desc Classifier Candidates')
    ..writeln()
    ..writeln('- Source: `$_sourcePath`')
    ..writeln('- Generated (UTC): `${jsonOut['generated_utc']}`')
    ..writeln('- total_scanned: `${jsonOut['summary']['total_scanned']}`')
    ..writeln('- suyere_detected: `${jsonOut['summary']['suyere_detected']}`')
    ..writeln('- rezo_detected: `${jsonOut['summary']['rezo_detected']}`')
    ..writeln('- apply_ready_count: `${jsonOut['summary']['apply_ready_count']}`')
    ..writeln('- needs_review_count: `${jsonOut['summary']['needs_review_count']}`')
    ..writeln()
    ..writeln('## Candidates');

  if (candidates.isEmpty) {
    md.writeln('_No strict candidates found._');
  } else {
    for (final c in candidates) {
      md.writeln('### `${c['odu_key']}` -> `${c['proposed_target']}`');
      md.writeln('- match_count: `${c['match_count']}`');
      md.writeln('- repetition_ratio: `${c['repetition_ratio']}`');
      md.writeln(
        '- contains_invocation_tokens: `${c['contains_invocation_tokens']}`',
      );
      md.writeln('- SAFE_TO_APPLY: `${c['SAFE_TO_APPLY']}`');
      md.writeln('- reason: `${c['reason']}`');
      md.writeln('- regex_move:');
      md.writeln('```regex');
      md.writeln(c['regex_move']);
      md.writeln('```');
      md.writeln('- preview_before_300:');
      md.writeln('```text');
      md.writeln(c['preview_before_300']);
      md.writeln('```');
      md.writeln('- preview_after_900:');
      md.writeln('```text');
      md.writeln(c['preview_after_900']);
      md.writeln('```');
      md.writeln();
    }
  }

  Directory('build').createSync(recursive: true);
  File(_outJsonPath).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(jsonOut),
  );
  File(_outMdPath).writeAsStringSync(md.toString());
  File(_outSamplePath).writeAsStringSync(_buildApplyReadySampleMd(applyReady));

  stdout.writeln('Generated TANDA 9 description classifier candidates.');
  stdout.writeln('Wrote: $_outJsonPath');
  stdout.writeln('Wrote: $_outMdPath');
  stdout.writeln('Wrote: $_outSamplePath');
}

Map<String, dynamic> _toCandidate({
  required String oduKey,
  required String proposedTarget,
  required String descripcionRaw,
  required _DetectedBlock block,
}) {
  final rawForMatch = _normalizeNewlines(descripcionRaw);
  final capture = block.text.length > _maxCaptureChars
      ? block.text.substring(0, _maxCaptureChars)
      : block.text;
  final truncated = block.text.length > _maxCaptureChars;
  final regexMove = RegExp.escape(capture);
  final regex = RegExp(regexMove, multiLine: true, dotAll: true);
  final matchCount = regex.allMatches(rawForMatch).length;

  final safeToApply = matchCount == 1 && !truncated;
  final reason = safeToApply
      ? 'strict_${proposedTarget}_classification'
      : (truncated ? 'capture_exceeds_3000_chars' : 'match_count_$matchCount');

  final beforeStart = block.start > _previewBeforeChars
      ? block.start - _previewBeforeChars
      : 0;
  final afterEnd = (block.start + _previewAfterChars) < rawForMatch.length
      ? block.start + _previewAfterChars
      : rawForMatch.length;

  return <String, dynamic>{
    'odu_key': oduKey,
    'proposed_target': proposedTarget,
    'match_count': matchCount,
    'repetition_ratio': double.parse(block.repetitionRatio.toStringAsFixed(3)),
    'contains_invocation_tokens': block.tokenHitCount > 0,
    'preview_before_300': rawForMatch.substring(beforeStart, block.start),
    'preview_after_900': rawForMatch.substring(block.start, afterEnd),
    'SAFE_TO_APPLY': safeToApply,
    'reason': reason,
    'regex_move': regexMove,
    'capture_len': block.text.length,
    'classification': block.classification,
    'signal_counts': <String, int>{
      'tokens': block.tokenHitCount,
      'short_lines': block.shortLineStreak,
      'invocation_hit': block.invocationHitCount + (block.ritualSignal ? 1 : 0),
    },
    'block_first_250': _firstChars(block.text, 250),
    'block_last_250': _lastChars(block.text, 250),
  };
}

List<_DetectedBlock> _detectSuyereBlocks({
  required List<_LineInfo> lines,
  required String rawText,
}) {
  final blocks = <_DetectedBlock>[];
  var i = 0;
  while (i < lines.length) {
    final line = lines[i];
    final trimmed = line.trimmed;
    if (trimmed.isEmpty || trimmed.length > 60) {
      i++;
      continue;
    }

    final startIndex = i;
    while (i < lines.length) {
      final current = lines[i].trimmed;
      if (current.isEmpty || current.length > 60) {
        break;
      }
      i++;
    }
    final endIndex = i - 1;
    final runLength = endIndex - startIndex + 1;
    if (runLength < 2) {
      continue;
    }

    final runLines = lines.sublist(startIndex, endIndex + 1);
    final trimmedLines = runLines.map((l) => l.trimmed).toList();
    final repeatedCount = _countRepeatedLineOccurrences(trimmedLines);
    final repetitionRatio = repeatedCount / trimmedLines.length;
    final hasRepeatedLine = repeatedCount > 0;

    final start = runLines.first.start;
    final end = runLines.last.end;
    final text = rawText.substring(start, end);
    final folded = _fold(text);
    final hasForbidden = _containsAnyFolded(folded, _suyereForbiddenFolded);
    final tokenHitCount = _countCoreTokenHits(folded);
    final invocationHitCount = _countInvocationLineHits(trimmedLines);
    final shortLineStreak = _maxConsecutiveShortLines(trimmedLines, 80);

    final qualifies =
        hasRepeatedLine &&
        repetitionRatio >= 0.4 &&
        !hasForbidden &&
        trimmedLines.length >= 2;

    if (!qualifies) {
      continue;
    }

    blocks.add(
      _DetectedBlock(
        start: start,
        end: end,
        text: text,
        repetitionRatio: repetitionRatio,
        classification: 'suyere_strict',
        tokenHitCount: tokenHitCount,
        shortLineStreak: shortLineStreak,
        invocationHitCount: invocationHitCount,
        ritualSignal: false,
      ),
    );
  }
  return blocks;
}

List<_DetectedBlock> _detectRezoBlocks({required String rawText}) {
  final blocks = <_DetectedBlock>[];
  final spans = _paragraphSpans(rawText);
  for (final span in spans) {
    final text = rawText.substring(span.start, span.end).trim();
    if (text.length < 220) {
      continue;
    }

    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) continue;

    final repeatedCount = _countRepeatedLineOccurrences(lines);
    if (repeatedCount > 0) {
      continue;
    }

    final folded = _fold(text);
    final tokenHitCount = _countCoreTokenHits(folded);
    if (tokenHitCount < 2) {
      continue;
    }

    final invocationLineHits = _countInvocationLineHits(lines);
    final ritualSignal = _rezoRitualSignalRegex.hasMatch(text);
    final shortLineStreak = _maxConsecutiveShortLines(lines, 80);
    final hasSignal =
        invocationLineHits > 0 || ritualSignal || shortLineStreak >= 3;
    if (!hasSignal) {
      continue;
    }

    final hasForbiddenFolded = _containsAnyFolded(folded, _rezoForbiddenFolded);
    final hasForbiddenRezoHeader = _rezoHeaderForbiddenRegex.hasMatch(text);
    if (hasForbiddenFolded || hasForbiddenRezoHeader) {
      continue;
    }

    blocks.add(
      _DetectedBlock(
        start: span.start,
        end: span.end,
        text: text,
        repetitionRatio: 0,
        classification: 'rezo_v2_strict',
        tokenHitCount: tokenHitCount,
        shortLineStreak: shortLineStreak,
        invocationHitCount: invocationLineHits,
        ritualSignal: ritualSignal,
      ),
    );
  }
  return blocks;
}

List<_LineInfo> _lineInfos(String text) {
  final lines = <_LineInfo>[];
  var offset = 0;
  for (final line in text.split('\n')) {
    final start = offset;
    final end = start + line.length;
    lines.add(_LineInfo(start: start, end: end, text: line));
    offset = end + 1;
  }
  return lines;
}

List<_Span> _paragraphSpans(String text) {
  final spans = <_Span>[];
  final separator = RegExp(r'\n\s*\n+', multiLine: true);
  var cursor = 0;
  for (final match in separator.allMatches(text)) {
    final span = _trimSpan(text, cursor, match.start);
    if (span != null) spans.add(span);
    cursor = match.end;
  }
  final tail = _trimSpan(text, cursor, text.length);
  if (tail != null) spans.add(tail);
  return spans;
}

_Span? _trimSpan(String text, int start, int end) {
  var s = start;
  var e = end;
  while (s < e && _isWhitespace(text.codeUnitAt(s))) {
    s++;
  }
  while (e > s && _isWhitespace(text.codeUnitAt(e - 1))) {
    e--;
  }
  if (s >= e) return null;
  return _Span(start: s, end: e);
}

int _countRepeatedLineOccurrences(List<String> lines) {
  final counts = <String, int>{};
  for (final line in lines) {
    final normalized = line.replaceAll(RegExp(r'\s+'), ' ').trim();
    counts.update(normalized, (v) => v + 1, ifAbsent: () => 1);
  }
  var repeated = 0;
  for (final count in counts.values) {
    if (count > 1) {
      repeated += count;
    }
  }
  return repeated;
}

int _countCoreTokenHits(String foldedText) {
  var hits = 0;
  for (final token in _rezoInvocationFolded) {
    if (_containsFoldedWord(foldedText, token)) {
      hits++;
    }
  }
  return hits;
}

bool _containsFoldedWord(String foldedText, String token) {
  final pattern = RegExp(
    '(^|[^a-z0-9])${RegExp.escape(token)}([^a-z0-9]|\$)',
    caseSensitive: false,
  );
  return pattern.hasMatch(foldedText);
}

int _countInvocationLineHits(List<String> lines) {
  var count = 0;
  for (final line in lines) {
    if (_rezoInvocationLineSignalRegex.hasMatch(line)) {
      count++;
    }
  }
  return count;
}

int _maxConsecutiveShortLines(List<String> lines, int maxLen) {
  var current = 0;
  var best = 0;
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isNotEmpty && trimmed.length <= maxLen) {
      current++;
      if (current > best) {
        best = current;
      }
    } else {
      current = 0;
    }
  }
  return best;
}

bool _containsAnyFolded(String foldedText, List<String> foldedTokens) {
  for (final token in foldedTokens) {
    if (foldedText.contains(token)) return true;
  }
  return false;
}

String _firstChars(String text, int count) {
  if (text.length <= count) return text;
  return text.substring(0, count);
}

String _lastChars(String text, int count) {
  if (text.length <= count) return text;
  return text.substring(text.length - count);
}

String _buildApplyReadySampleMd(List<Map<String, dynamic>> applyReady) {
  final sample = applyReady.take(20).toList();
  final sb = StringBuffer()
    ..writeln('# TANDA 9 Apply-Ready Sample')
    ..writeln()
    ..writeln('- Source: `$_outJsonPath`')
    ..writeln('- Selected sample size: `${sample.length}`')
    ..writeln();

  if (sample.isEmpty) {
    sb.writeln('_No SAFE_TO_APPLY candidates found._');
    return sb.toString();
  }

  for (final c in sample) {
    final signals = Map<String, dynamic>.from(c['signal_counts'] as Map? ?? {});
    sb.writeln('## `${c['odu_key']}` -> `${c['proposed_target']}`');
    sb.writeln('- tokens: `${signals['tokens'] ?? 0}`');
    sb.writeln('- short_lines: `${signals['short_lines'] ?? 0}`');
    sb.writeln('- invocation_hit: `${signals['invocation_hit'] ?? 0}`');
    sb.writeln('- first_250:');
    sb.writeln('```text');
    sb.writeln(c['block_first_250'] ?? '');
    sb.writeln('```');
    sb.writeln('- last_250:');
    sb.writeln('```text');
    sb.writeln(c['block_last_250'] ?? '');
    sb.writeln('```');
    sb.writeln();
  }
  return sb.toString();
}

String _asString(dynamic value) => value is String ? value : '';

String _normalizeNewlines(String text) =>
    text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

String _fold(String input) {
  final lower = input.toLowerCase();
  final sb = StringBuffer();
  for (final rune in lower.runes) {
    sb.write(_diacriticFoldMap[rune] ?? String.fromCharCode(rune));
  }
  return sb
      .toString()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool _isWhitespace(int codeUnit) =>
    codeUnit == 0x20 ||
    codeUnit == 0x09 ||
    codeUnit == 0x0A ||
    codeUnit == 0x0D ||
    codeUnit == 0x0B ||
    codeUnit == 0x0C;

const Map<int, String> _diacriticFoldMap = <int, String>{
  0x00E1: 'a', // á
  0x00E9: 'e', // é
  0x00ED: 'i', // í
  0x00F3: 'o', // ó
  0x00FA: 'u', // ú
  0x00FC: 'u', // ü
  0x00F1: 'n', // ñ
  0x00C1: 'a', // Á
  0x00C9: 'e', // É
  0x00CD: 'i', // Í
  0x00D3: 'o', // Ó
  0x00DA: 'u', // Ú
  0x00DC: 'u', // Ü
  0x00D1: 'n', // Ñ
  0x00F2: 'o', // ò
  0x00F9: 'u', // ù
  0x00D2: 'o', // Ò
  0x00D9: 'u', // Ù
};

class _LineInfo {
  const _LineInfo({
    required this.start,
    required this.end,
    required this.text,
  });

  final int start;
  final int end;
  final String text;

  String get trimmed => text.trim();
}

class _Span {
  const _Span({required this.start, required this.end});

  final int start;
  final int end;
}

class _DetectedBlock {
  const _DetectedBlock({
    required this.start,
    required this.end,
    required this.text,
    required this.repetitionRatio,
    required this.classification,
    required this.tokenHitCount,
    required this.shortLineStreak,
    required this.invocationHitCount,
    required this.ritualSignal,
  });

  final int start;
  final int end;
  final String text;
  final double repetitionRatio;
  final String classification;
  final int tokenHitCount;
  final int shortLineStreak;
  final int invocationHitCount;
  final bool ritualSignal;
}
