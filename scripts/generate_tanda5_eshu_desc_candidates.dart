import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';

const String _contentPath = 'assets/odu_content_patched.json';
const String _patchesPath = 'assets/odu_patches.json';
const String _outJsonPath = 'build/tanda5_eshu_desc_candidates.json';
const String _outMdPath = 'build/tanda5_eshu_desc_candidates.md';

const int _maxCaptureChars = 3500;
const int _previewChars = 300;
const int _descripcionShortThreshold = 300;
const int _shortCaptureThreshold = 900;

const String _startAnchorPattern =
    r'^\s*(?:DESCRIPC\w*|ESTE\s+(?:ES\s+EL\s+OD(?:U|O)|OD(?:U|O)|SIGNO|IF[ÁA]))[\s\S]{0,60}';
const String _stopMarkerPattern =
    r'^\s*(?:EWES|OBRAS|DICE\s+IF[ÁA]|PAT(?:A|Á)K(?:I|Í)E|HISTORIAS|REZO|SUYERE|ESHU\b|EN\s+ESTE\s+OD(?:Ù|U|O))\b';
const String _boundedExtractionPattern =
    r'^\s*(?:DESCRIPC\w*|ESTE\s+(?:ES\s+EL\s+OD(?:U|O)|OD(?:U|O)|SIGNO|IF[ÁA]))[\s\S]{0,3500}?(?=^\s*(?:EWES|OBRAS|DICE\s+IF[ÁA]|PAT(?:A|Á)K(?:I|Í)E|HISTORIAS|REZO|SUYERE|ESHU\b|EN\s+ESTE\s+OD(?:Ù|U|O))\b|$(?![\s\S]))';

final RegExp _candidateAnchorRegex = RegExp(
  r'ESTE\s+ES\s+EL\s+OD(?:U|O)|ESTE\s+ODU|ESTE\s+SIGNO|ESTE\s+IF[ÁA]|DESCRIPC',
  caseSensitive: false,
);

final RegExp _startAnchorRegex = RegExp(
  _startAnchorPattern,
  caseSensitive: false,
  multiLine: true,
  dotAll: true,
);

final RegExp _stopMarkerRegex = RegExp(
  _stopMarkerPattern,
  caseSensitive: false,
  multiLine: true,
  dotAll: true,
);

final RegExp _rawBoundedRegex = RegExp(
  _boundedExtractionPattern,
  caseSensitive: false,
  multiLine: true,
  dotAll: true,
);

void main() {
  final contentFile = File(_contentPath);
  final patchesFile = File(_patchesPath);

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

  final contentDecoded = jsonDecode(contentFile.readAsStringSync());
  final patchesDecoded = jsonDecode(patchesFile.readAsStringSync());
  if (contentDecoded is! Map || patchesDecoded is! Map) {
    stderr.writeln('Invalid JSON root in one or more inputs.');
    exitCode = 1;
    return;
  }

  final contentRoot = Map<String, dynamic>.from(contentDecoded);
  final oduRaw = contentRoot['odu'];
  if (oduRaw is! Map) {
    stderr.writeln('Invalid content payload: missing "odu" object.');
    exitCode = 1;
    return;
  }
  final oduMap = Map<String, dynamic>.from(oduRaw);

  final patchesRoot = Map<String, dynamic>.from(patchesDecoded);
  final excludedKeys = patchesRoot.keys.where((k) => !k.startsWith('_')).toSet();

  final applyReady = <_Candidate>[];
  final needsReview = <_Candidate>[];

  var candidateWithAnchors = 0;
  var skippedByPatches = 0;
  var skippedByDescripcionLength = 0;

  final sortedKeys = oduMap.keys.whereType<String>().toList()..sort();
  for (final oduKey in sortedKeys) {
    if (excludedKeys.contains(oduKey)) {
      skippedByPatches++;
      continue;
    }

    final nodeRaw = oduMap[oduKey];
    if (nodeRaw is! Map) continue;
    final node = Map<String, dynamic>.from(nodeRaw);
    final contentNodeRaw = node['content'];
    if (contentNodeRaw is! Map) continue;
    final contentNode = Map<String, dynamic>.from(contentNodeRaw);

    final rawEshu = _asString(contentNode['eshu']);
    final rawDescripcion = _asString(contentNode['descripcion']);
    final descripcionLen = rawDescripcion.trim().length;
    if (descripcionLen >= _descripcionShortThreshold) {
      skippedByDescripcionLength++;
      continue;
    }
    if (!_candidateAnchorRegex.hasMatch(rawEshu)) {
      continue;
    }
    candidateWithAnchors++;

    final normalizedForMatching = _normalizeForMatching(rawEshu);
    final extraction = _extractBlocks(normalizedForMatching);
    final rawMatches = _rawBoundedRegex.allMatches(rawEshu).toList();
    final rawMatchCount = rawMatches.length;

    final anyStopFound = extraction.blocks.any((b) => b.stopFound);
    final anyTruncated = extraction.blocks.any((b) => b.truncated);
    final captureShort = extraction.blocks.isNotEmpty &&
        extraction.blocks.every((b) => b.length <= _shortCaptureThreshold);
    final estimatedMovedChars = extraction.blocks.fold<int>(
      0,
      (sum, b) => sum + b.length,
    );

    final candidate = _Candidate(
      oduKey: oduKey,
      descripcionLength: descripcionLen,
      eshuLength: rawEshu.length,
      matchCount: rawMatchCount,
      stopMarkerFound: anyStopFound,
      truncated: anyTruncated,
      captureShort: captureShort,
      estimatedMovedChars: estimatedMovedChars,
      previewSnippet: _buildPreview(rawEshu, extraction, rawMatches),
      patchOps: _buildPatchOps(_boundedExtractionPattern),
      suggestedNote: _suggestNote(rawMatchCount, anyStopFound, anyTruncated),
    );

    final isApplyReady = rawMatchCount > 0 && !anyTruncated;
    if (isApplyReady) {
      applyReady.add(candidate);
    } else {
      needsReview.add(candidate);
    }
  }

  final jsonOut = <String, dynamic>{
    'source_files': <String, String>{
      'content': _contentPath,
      'patches': _patchesPath,
    },
    'generated_utc': DateTime.now().toUtc().toIso8601String(),
    'selection_criteria': <String, dynamic>{
      'exclude_keys_present_in_patches': true,
      'descripcion_length_lt': _descripcionShortThreshold,
      'eshu_anchor_any': <String>[
        'ESTE ES EL OD(U/O)',
        'ESTE ODU',
        'ESTE SIGNO',
        'ESTE IFÁ / ESTE IFA',
        'DESCRIPC*',
      ],
      'bounded_capture_chars': _maxCaptureChars,
      'short_capture_threshold': _shortCaptureThreshold,
      'apply_ready_rule': 'match_count > 0 AND not truncated',
    },
    'regex_templates': <String, String>{
      'start_anchor': _startAnchorPattern,
      'stop_marker': _stopMarkerPattern,
      'bounded_extraction': _boundedExtractionPattern,
    },
    'counts': <String, int>{
      'total_odu_entries': sortedKeys.length,
      'excluded_by_existing_patches': skippedByPatches,
      'excluded_by_descripcion_length': skippedByDescripcionLength,
      'candidates_with_eshu_anchor': candidateWithAnchors,
      'apply_ready': applyReady.length,
      'needs_review': needsReview.length,
      'total_candidates': applyReady.length + needsReview.length,
    },
    'groups': <String, dynamic>{
      'APPLY_READY': applyReady.map((c) => c.toJson()).toList(),
      'NEEDS_REVIEW': needsReview.map((c) => c.toJson()).toList(),
    },
  };

  final md = StringBuffer()
    ..writeln('# TANDA 5 ESHU -> DESCRIPCION Candidates')
    ..writeln()
    ..writeln('- Source content: `$_contentPath`')
    ..writeln('- Source patches (key exclusion): `$_patchesPath`')
    ..writeln('- Generated (UTC): `${jsonOut['generated_utc']}`')
    ..writeln()
    ..writeln('## Counts')
    ..writeln('- Total Odù entries: `${sortedKeys.length}`')
    ..writeln('- Excluded by existing patches: `$skippedByPatches`')
    ..writeln('- Excluded by descripcion length >= $_descripcionShortThreshold: $skippedByDescripcionLength')
    ..writeln('- Candidates with ESHU anchors: `$candidateWithAnchors`')
    ..writeln('- APPLY_READY: `${applyReady.length}`')
    ..writeln('- NEEDS_REVIEW: `${needsReview.length}`')
    ..writeln()
    ..writeln('## Regex Templates')
    ..writeln('- Start anchor: `$_startAnchorPattern`')
    ..writeln('- Stop marker: `$_stopMarkerPattern`')
    ..writeln('- Bounded extraction: `$_boundedExtractionPattern`')
    ..writeln();

  md.writeln('## APPLY_READY');
  if (applyReady.isEmpty) {
    md.writeln('_No candidates._');
    md.writeln();
  } else {
    for (final c in applyReady) {
      _writeCandidateMd(md, c, includeNote: false);
    }
  }

  md.writeln('## NEEDS_REVIEW');
  if (needsReview.isEmpty) {
    md.writeln('_No candidates._');
    md.writeln();
  } else {
    for (final c in needsReview) {
      _writeCandidateMd(md, c, includeNote: true);
    }
  }

  Directory('build').createSync(recursive: true);
  File(
    _outJsonPath,
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(jsonOut));
  File(_outMdPath).writeAsStringSync(md.toString());

  stdout.writeln('Generated TANDA 5 candidates (no patches applied).');
  stdout.writeln('APPLY_READY: ${applyReady.length}');
  stdout.writeln('NEEDS_REVIEW: ${needsReview.length}');
  stdout.writeln('Wrote: $_outJsonPath');
  stdout.writeln('Wrote: $_outMdPath');
}

String _normalizeForMatching(String input) {
  var text = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  text = text.replaceAll('“', '"').replaceAll('”', '"');
  text = text.replaceAll('–', '-').replaceAll('—', '-');
  text = text.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
  return text;
}

_ExtractionResult _extractBlocks(String normalizedText) {
  final starts = _startAnchorRegex.allMatches(normalizedText).toList();
  if (starts.isEmpty) {
    return const _ExtractionResult(blocks: <_Block>[]);
  }

  final blocks = <_Block>[];
  var lastConsumedEnd = -1;

  for (final startMatch in starts) {
    final start = startMatch.start;
    if (start < lastConsumedEnd) {
      continue;
    }
    final maxEnd = math.min(normalizedText.length, start + _maxCaptureChars);
    final stopSearchStart = math.min(start + 1, maxEnd);
    var stopIndex = -1;
    var stopFound = false;
    if (stopSearchStart < maxEnd) {
      final slice = normalizedText.substring(stopSearchStart, maxEnd);
      final stopMatch = _stopMarkerRegex.firstMatch(slice);
      if (stopMatch != null) {
        stopIndex = stopSearchStart + stopMatch.start;
        stopFound = true;
      }
    }

    final end = stopFound ? stopIndex : maxEnd;
    if (end <= start) {
      continue;
    }

    final truncated = !stopFound && maxEnd < normalizedText.length;
    final blockText = normalizedText.substring(start, end).trim();
    if (blockText.isEmpty) {
      continue;
    }
    blocks.add(
      _Block(
        text: blockText,
        stopFound: stopFound,
        truncated: truncated,
        length: blockText.length,
      ),
    );
    lastConsumedEnd = end;
  }

  return _ExtractionResult(blocks: blocks);
}

Map<String, dynamic> _buildPatchOps(String regex) {
  return <String, dynamic>{
    'eshu': <String, dynamic>{
      'move_to_desc_regex': <String>[regex],
      'remove_from_eshu_regex': <String>[regex],
    },
    'descripcion': <String, dynamic>{
      'append_from_eshu_regex': <String>[regex],
    },
  };
}

String _buildPreview(
  String rawEshu,
  _ExtractionResult extraction,
  List<RegExpMatch> rawMatches,
) {
  if (rawMatches.isNotEmpty) {
    return _truncate(rawMatches.first.group(0) ?? '');
  }
  if (extraction.blocks.isNotEmpty) {
    return _truncate(extraction.blocks.first.text);
  }
  final anchor = _candidateAnchorRegex.firstMatch(rawEshu);
  if (anchor == null) {
    return '';
  }
  final start = anchor.start;
  final end = math.min(rawEshu.length, start + _previewChars);
  return _truncate(rawEshu.substring(start, end));
}

String _suggestNote(int rawMatchCount, bool stopFound, bool truncated) {
  if (rawMatchCount == 0) {
    return 'No raw bounded match. Review line-start anchor and allow optional prefix tokens before DESCRIPCION/ESTE ODU.';
  }
  if (!stopFound && truncated) {
    return 'Matched but truncated at max length. Add a stronger stop marker for this Odù before applying.';
  }
  if (!stopFound) {
    return 'Matched without stop marker (short capture). Validate manually before applying.';
  }
  return 'Matched with stop marker.';
}

void _writeCandidateMd(
  StringBuffer md,
  _Candidate c, {
  required bool includeNote,
}) {
  md.writeln('### `${c.oduKey}`');
  md.writeln('- descripcion_length: `${c.descripcionLength}`');
  md.writeln('- eshu_length: `${c.eshuLength}`');
  md.writeln('- match_count: `${c.matchCount}`');
  md.writeln('- stop_marker_found: `${c.stopMarkerFound}`');
  md.writeln('- truncated: `${c.truncated}`');
  md.writeln('- capture_short: `${c.captureShort}`');
  md.writeln('- estimated_moved_chars: `${c.estimatedMovedChars}`');
  if (includeNote) {
    md.writeln('- note: ${c.suggestedNote}');
  }
  md.writeln('- patch ops:');
  md.writeln('```json');
  md.writeln(const JsonEncoder.withIndent('  ').convert(c.patchOps));
  md.writeln('```');
  md.writeln('- preview_snippet:');
  md.writeln('```text');
  md.writeln(c.previewSnippet);
  md.writeln('```');
  md.writeln();
}

String _asString(dynamic value) {
  if (value == null) return '';
  if (value is String) return value;
  return value.toString();
}

String _truncate(String value) {
  final compact = value.trim();
  if (compact.length <= _previewChars) {
    return compact;
  }
  return compact.substring(0, _previewChars);
}

class _Candidate {
  const _Candidate({
    required this.oduKey,
    required this.descripcionLength,
    required this.eshuLength,
    required this.matchCount,
    required this.stopMarkerFound,
    required this.truncated,
    required this.captureShort,
    required this.estimatedMovedChars,
    required this.previewSnippet,
    required this.patchOps,
    required this.suggestedNote,
  });

  final String oduKey;
  final int descripcionLength;
  final int eshuLength;
  final int matchCount;
  final bool stopMarkerFound;
  final bool truncated;
  final bool captureShort;
  final int estimatedMovedChars;
  final String previewSnippet;
  final Map<String, dynamic> patchOps;
  final String suggestedNote;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'odu_key': oduKey,
      'descripcion_length': descripcionLength,
      'eshu_length': eshuLength,
      'match_count': matchCount,
      'stop_marker_found': stopMarkerFound,
      'truncated': truncated,
      'capture_short': captureShort,
      'estimated_moved_chars': estimatedMovedChars,
      'preview_snippet': previewSnippet,
      'patch_ops': patchOps,
      'note': suggestedNote,
    };
  }
}

class _ExtractionResult {
  const _ExtractionResult({required this.blocks});

  final List<_Block> blocks;
}

class _Block {
  const _Block({
    required this.text,
    required this.stopFound,
    required this.truncated,
    required this.length,
  });

  final String text;
  final bool stopFound;
  final bool truncated;
  final int length;
}
