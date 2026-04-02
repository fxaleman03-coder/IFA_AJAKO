import 'dart:convert';
import 'dart:io';

const String _contaminationReportPath =
    'build/eshu_marker_contamination_report.json';
const String _patchedContentPath = 'assets/odu_content_patched.json';
const String _patchesPath = 'assets/odu_patches.json';
const String _outJsonPath = 'build/tanda6_refactored_candidates.json';
const String _outMdPath = 'build/tanda6_refactored_candidates.md';

const int _maxCaptureChars = 3500;
const int _previewChars = 900;
const int _maxStopLines = 12;

const String _stopMarkerAlternation =
    r'EN\s+ESTE\s+OD(?:Ù|U|O)|DESCRIPCI\w*|EWES\b|OBRAS\b|DICE\s+IF[ÁA]|PAT(?:A|Á)K(?:I|Í)E|REZO\s*:|SUYERE\s*:|HISTORIAS?\s*:|ESHU\b';

final RegExp _stopMarkerLineRegex = RegExp(
  '^\\s*(?:$_stopMarkerAlternation)\\b.*\$',
  caseSensitive: false,
  multiLine: true,
  dotAll: true,
);

final RegExp _anyStrictHeaderRegex = RegExp(
  r'^\s*(?:REZO|SUYERE|HISTORIAS?)\s*:',
  caseSensitive: false,
  multiLine: true,
  dotAll: true,
);

final RegExp _forbiddenInsideSnippetRegex = RegExp(
  r'DESCRIPC|OBRAS|DICE\s+IF|EWES',
  caseSensitive: false,
  multiLine: true,
  dotAll: true,
);

final RegExp _historLexicalFalsePositiveRegex = RegExp(
  r'HISTORIADOR(?:ES)?|HISTORIC[OA]S?',
  caseSensitive: false,
  multiLine: true,
  dotAll: true,
);

final Map<String, _MarkerConfig> _markerConfigByReportMarker =
    <String, _MarkerConfig>{
      'REZO': _MarkerConfig(
        reportMarker: 'REZO',
        startToken: 'REZO',
        strictHeaderRegex: RegExp(
          r'^\s*REZO\s*:',
          caseSensitive: false,
          multiLine: true,
          dotAll: true,
        ),
        inlineWordRegex: RegExp(
          r'REZO',
          caseSensitive: false,
          multiLine: true,
          dotAll: true,
        ),
        sourceOpKey: 'move_to_rezo_regex',
        targetAlias: 'rezo',
        targetContentKey: 'rezoYoruba',
        targetAppendOpKey: 'append_from_eshu_regex',
        existingTargetAliases: const <String>['rezo', 'rezoyoruba'],
      ),
      'SUYERE': _MarkerConfig(
        reportMarker: 'SUYERE',
        startToken: 'SUYERE',
        strictHeaderRegex: RegExp(
          r'^\s*SUYERE\s*:',
          caseSensitive: false,
          multiLine: true,
          dotAll: true,
        ),
        inlineWordRegex: RegExp(
          r'SUYERE',
          caseSensitive: false,
          multiLine: true,
          dotAll: true,
        ),
        sourceOpKey: 'move_to_suyere_regex',
        targetAlias: 'suyere',
        targetContentKey: 'suyereYoruba',
        targetAppendOpKey: 'append_from_eshu_regex',
        existingTargetAliases: const <String>['suyere', 'suyereyoruba'],
      ),
      'HISTOR': _MarkerConfig(
        reportMarker: 'HISTOR',
        startToken: 'HISTORIAS?',
        strictHeaderRegex: RegExp(
          r'^\s*HISTORIAS?\s*:',
          caseSensitive: false,
          multiLine: true,
          dotAll: true,
        ),
        inlineWordRegex: RegExp(
          r'HISTOR\w*',
          caseSensitive: false,
          multiLine: true,
          dotAll: true,
        ),
        sourceOpKey: 'move_to_historias_regex',
        targetAlias: 'historias',
        targetContentKey: 'historiasYPatakies',
        targetAppendOpKey: 'append_from_eshu_regex',
        existingTargetAliases: const <String>[
          'historias',
          'historiasypatakies',
          'patakies',
        ],
      ),
    };

void main() {
  final reportFile = File(_contaminationReportPath);
  final contentFile = File(_patchedContentPath);
  final patchesFile = File(_patchesPath);

  if (!reportFile.existsSync()) {
    stderr.writeln('Missing input report: $_contaminationReportPath');
    exitCode = 1;
    return;
  }
  if (!contentFile.existsSync()) {
    stderr.writeln('Missing input content: $_patchedContentPath');
    exitCode = 1;
    return;
  }
  if (!patchesFile.existsSync()) {
    stderr.writeln('Missing input patches: $_patchesPath');
    exitCode = 1;
    return;
  }

  final reportDecoded = jsonDecode(reportFile.readAsStringSync());
  final contentDecoded = jsonDecode(contentFile.readAsStringSync());
  final patchesDecoded = jsonDecode(patchesFile.readAsStringSync());
  if (reportDecoded is! Map ||
      contentDecoded is! Map ||
      patchesDecoded is! Map) {
    stderr.writeln('Invalid JSON format in one or more inputs.');
    exitCode = 1;
    return;
  }

  final reportRoot = Map<String, dynamic>.from(reportDecoded);
  final hitsRaw = reportRoot['hits'];
  if (hitsRaw is! List) {
    stderr.writeln('Invalid contamination report: missing "hits" list.');
    exitCode = 1;
    return;
  }

  final contentRoot = Map<String, dynamic>.from(contentDecoded);
  final oduRaw = contentRoot['odu'];
  if (oduRaw is! Map) {
    stderr.writeln('Invalid patched content: missing "odu" object.');
    exitCode = 1;
    return;
  }
  final oduMap = Map<String, dynamic>.from(oduRaw);
  final normalizedContentKeyLookup = <String, String>{
    for (final key in oduMap.keys.whereType<String>()) _normalizeKey(key): key,
  };

  final patchesRoot = Map<String, dynamic>.from(patchesDecoded);
  final normalizedPatches = <String, Map<String, dynamic>>{};
  for (final entry in patchesRoot.entries) {
    if (entry.key.startsWith('_') || entry.value is! Map) continue;
    normalizedPatches[_normalizeKey(entry.key)] = Map<String, dynamic>.from(
      entry.value as Map,
    );
  }

  final candidatesByKey = <String, _Candidate>{};
  final falsePositiveReasonCounts = <String, int>{};
  final strictHeaderMatchesByUnit = <String, int>{};

  var skippedAlreadyPatchedForMarker = 0;
  var skippedUnknownMarker = 0;
  var skippedMissingOdu = 0;
  var duplicateHitsCollapsed = 0;

  final hits = hitsRaw.whereType<Map>().map(Map<String, dynamic>.from).toList();
  for (var hitIndex = 0; hitIndex < hits.length; hitIndex++) {
    final hit = hits[hitIndex];
    final oduKeyRaw = _asString(hit['odu_key']).trim();
    final reportMarker = _asString(hit['marker']).trim().toUpperCase();
    if (oduKeyRaw.isEmpty || reportMarker.isEmpty) continue;

    final config = _markerConfigByReportMarker[reportMarker];
    if (config == null) {
      skippedUnknownMarker++;
      _increment(falsePositiveReasonCounts, 'unknown_marker');
      continue;
    }

    final normalizedOdu = _normalizeKey(oduKeyRaw);
    final canonicalOduKey = normalizedContentKeyLookup[normalizedOdu];
    if (canonicalOduKey == null) {
      skippedMissingOdu++;
      _increment(falsePositiveReasonCounts, 'missing_odu');
      continue;
    }

    final unitKey = '$canonicalOduKey|${config.reportMarker}';
    if (candidatesByKey.containsKey(unitKey) ||
        strictHeaderMatchesByUnit.containsKey(unitKey)) {
      duplicateHitsCollapsed++;
      continue;
    }

    final nodeRaw = oduMap[canonicalOduKey];
    if (nodeRaw is! Map) {
      skippedMissingOdu++;
      _increment(falsePositiveReasonCounts, 'missing_odu_node');
      continue;
    }
    final node = Map<String, dynamic>.from(nodeRaw);
    final contentRaw = node['content'];
    if (contentRaw is! Map) {
      skippedMissingOdu++;
      _increment(falsePositiveReasonCounts, 'missing_content');
      continue;
    }
    final content = Map<String, dynamic>.from(contentRaw);
    final eshuRaw = _asString(content['eshu']);
    final descripcionRaw = _asString(content['descripcion']);

    final strictHeaders = config.strictHeaderRegex.allMatches(eshuRaw).toList();
    strictHeaderMatchesByUnit[unitKey] = strictHeaders.length;

    final patchForOdu = normalizedPatches[normalizedOdu];
    if (patchForOdu != null &&
        _hasExistingEshuTargetOpForMarker(patchForOdu, config)) {
      skippedAlreadyPatchedForMarker++;
      _increment(falsePositiveReasonCounts, 'already_patched_for_marker');
      continue;
    }

    if (strictHeaders.isEmpty) {
      if (config.reportMarker == 'HISTOR' &&
          _historLexicalFalsePositiveRegex.hasMatch(eshuRaw)) {
        _increment(falsePositiveReasonCounts, 'histor_lexical_false_positive');
      } else if (config.inlineWordRegex.hasMatch(eshuRaw)) {
        _increment(falsePositiveReasonCounts, 'inline_or_missing_colon');
      } else {
        _increment(falsePositiveReasonCounts, 'no_valid_header');
      }
      continue;
    }

    final boundedRegexPattern = _buildBoundedRegexPattern(config.startToken);
    final boundedRegex = RegExp(
      boundedRegexPattern,
      caseSensitive: false,
      multiLine: true,
      dotAll: true,
    );
    final boundedMatches = boundedRegex.allMatches(eshuRaw).toList();

    final firstHeader = strictHeaders.first;
    final firstHeaderIndex = firstHeader.start;
    final stopLines = _collectStopLinesAfter(eshuRaw, firstHeaderIndex);
    final stopFound = stopLines.isNotEmpty;
    final nearestStopDistance = stopFound
        ? stopLines.first.distanceChars
        : null;

    final expectedEnd = stopFound
        ? stopLines.first.index
        : _min(eshuRaw.length, firstHeaderIndex + _maxCaptureChars);
    final boundedSnippet = eshuRaw
        .substring(firstHeaderIndex, expectedEnd)
        .trim();

    final truncated =
        !stopFound && (firstHeaderIndex + _maxCaptureChars) < eshuRaw.length;
    final multipleHeadersInside =
        _anyStrictHeaderRegex.allMatches(boundedSnippet).length > 1;
    final forbiddenWordsInside = _forbiddenInsideSnippetRegex.hasMatch(
      boundedSnippet,
    );
    final noStopMarkerFound = !stopFound;
    final ambiguousBoundary = multipleHeadersInside || noStopMarkerFound;

    final reviewReasons = <String>[];
    if (boundedMatches.isEmpty) {
      reviewReasons.add('match_count=0');
    }
    if (truncated) {
      reviewReasons.add('truncated_capture');
    }
    if (multipleHeadersInside) {
      reviewReasons.add('multiple_headers_inside_snippet');
    }
    if (noStopMarkerFound) {
      reviewReasons.add('no_stop_marker_found');
    }
    if (ambiguousBoundary) {
      reviewReasons.add('ambiguous_boundary');
    }
    if (forbiddenWordsInside) {
      reviewReasons.add('forbidden_words_in_snippet');
    }

    final matchCount = boundedMatches.length;
    final applyReady =
        matchCount > 0 &&
        !truncated &&
        !forbiddenWordsInside &&
        !multipleHeadersInside &&
        !noStopMarkerFound;

    final candidate = _Candidate(
      oduKey: canonicalOduKey,
      marker: config.reportMarker,
      startToken: config.startToken,
      strictHeaderPattern: config.strictHeaderRegex.pattern,
      boundedRegex: boundedRegexPattern,
      hitIndex: hitIndex,
      markerIndex: _asInt(hit['index']),
      strictHeaderCountInEshu: strictHeaders.length,
      eshuLength: eshuRaw.length,
      descripcionLength: descripcionRaw.length,
      matchCount: matchCount,
      stopMarkerFound: stopFound,
      nearestStopMarkerDistanceChars: nearestStopDistance,
      truncated: truncated,
      multipleHeadersInsideSnippet: multipleHeadersInside,
      forbiddenWordsInsideSnippet: forbiddenWordsInside,
      ambiguousBoundary: ambiguousBoundary,
      applyReady: applyReady,
      reviewReasons: reviewReasons,
      previewSnippet: _trimPreview(boundedSnippet),
      stopMarkersAfterHeader: stopLines
          .take(_maxStopLines)
          .map((s) => s.toJson())
          .toList(),
      patchOps: _buildPatchOps(config, boundedRegexPattern),
      targetSectionAlias: config.targetAlias,
      targetContentKey: config.targetContentKey,
    );

    candidatesByKey[unitKey] = candidate;
  }

  final allCandidates = candidatesByKey.values.toList()
    ..sort((a, b) {
      final byKey = a.oduKey.compareTo(b.oduKey);
      if (byKey != 0) return byKey;
      return a.marker.compareTo(b.marker);
    });
  final applyReady = allCandidates.where((c) => c.applyReady).toList();
  final needsReview = allCandidates.where((c) => !c.applyReady).toList();

  final totalStrictHeaderMatches = strictHeaderMatchesByUnit.values.fold<int>(
    0,
    (sum, count) => sum + count,
  );
  final rejectedFalsePositivesCount = falsePositiveReasonCounts.values
      .fold<int>(0, (sum, count) => sum + count);

  final jsonOut = <String, dynamic>{
    'source_files': <String, String>{
      'contamination_report': _contaminationReportPath,
      'patched_content': _patchedContentPath,
      'patches': _patchesPath,
    },
    'generated_utc': DateTime.now().toUtc().toIso8601String(),
    'strict_rules': <String, dynamic>{
      'valid_rezo_header': r'(?mi)^\s*REZO\s*:',
      'valid_suyere_header': r'(?mi)^\s*SUYERE\s*:',
      'valid_historias_header': r'(?mi)^\s*HISTORIAS?\s*:',
      'reject_lexical_examples': <String>[
        'HISTORIADORES',
        'HISTORICO',
        '7 SUYERE',
        'inline marker without header colon',
      ],
      'forbidden_words_inside_snippet': <String>[
        'DESCRIPC',
        'OBRAS',
        'DICE IF',
        'EWES',
      ],
      'max_capture_chars': _maxCaptureChars,
    },
    'regex_templates': <String, String>{
      'start_anchor': r'^\s*(REZO|SUYERE|HISTORIAS?)\s*:',
      'stop_markers': _stopMarkerAlternation,
      'bounded_capture':
          r'(?mis)^\s*(REZO|SUYERE|HISTORIAS?)\s*:[\s\S]{0,3500}?(?=^\s*(EN\s+ESTE\s+OD(?:Ù|U|O)|DESCRIPCI\w*|EWES\b|OBRAS\b|DICE\s+IF[ÁA]|PAT(?:A|Á)K(?:I|Í)E|REZO\s*:|SUYERE\s*:|HISTORIAS?\s*:|ESHU\b)\b|$(?![\s\S]))',
    },
    'summary': <String, dynamic>{
      'total_scanned': hits.length,
      'total_strict_header_matches': totalStrictHeaderMatches,
      'apply_ready': applyReady.length,
      'needs_review': needsReview.length,
      'total_candidates': allCandidates.length,
      'rejected_false_positives_count': rejectedFalsePositivesCount,
      'rejected_false_positives_by_reason': falsePositiveReasonCounts,
      'skipped_already_patched_for_marker': skippedAlreadyPatchedForMarker,
      'skipped_unknown_marker': skippedUnknownMarker,
      'skipped_missing_odu': skippedMissingOdu,
      'duplicate_hits_collapsed': duplicateHitsCollapsed,
    },
    'groups': <String, dynamic>{
      'APPLY_READY': applyReady.map((c) => c.toJson()).toList(),
      'NEEDS_REVIEW': needsReview.map((c) => c.toJson()).toList(),
    },
  };

  final md = StringBuffer()
    ..writeln('# TANDA 6 Refactored Candidates')
    ..writeln()
    ..writeln('- Contamination input: `$_contaminationReportPath`')
    ..writeln('- Content input: `$_patchedContentPath`')
    ..writeln('- Patches input: `$_patchesPath`')
    ..writeln('- Generated (UTC): `${jsonOut['generated_utc']}`')
    ..writeln()
    ..writeln('## Strict Rules')
    ..writeln('- `(?mi)^\\s*REZO\\s*:`')
    ..writeln('- `(?mi)^\\s*SUYERE\\s*:`')
    ..writeln('- `(?mi)^\\s*HISTORIAS?\\s*:`')
    ..writeln(
      '- Reject lexical/inline markers (`HISTORIADORES`, `HISTORICO`, `7 SUYERE`, no colon headers).',
    )
    ..writeln()
    ..writeln('## Summary')
    ..writeln('- Total scanned: `${hits.length}`')
    ..writeln('- Total strict header matches: `$totalStrictHeaderMatches`')
    ..writeln('- APPLY_READY: `${applyReady.length}`')
    ..writeln('- NEEDS_REVIEW: `${needsReview.length}`')
    ..writeln('- Total candidates: `${allCandidates.length}`')
    ..writeln('- Rejected false positives: `$rejectedFalsePositivesCount`')
    ..writeln('- Rejected by reason:')
    ..writeln(_formatReasonCounts(falsePositiveReasonCounts))
    ..writeln(
      '- Skipped already patched for marker: `$skippedAlreadyPatchedForMarker`',
    )
    ..writeln('- Duplicate hits collapsed: `$duplicateHitsCollapsed`')
    ..writeln();

  _writeGroupMd(md, 'APPLY_READY', applyReady);
  _writeGroupMd(md, 'NEEDS_REVIEW', needsReview);

  Directory('build').createSync(recursive: true);
  File(
    _outJsonPath,
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(jsonOut));
  File(_outMdPath).writeAsStringSync(md.toString());

  stdout.writeln(
    'Generated refactored TANDA 6 candidates (no patches applied).',
  );
  stdout.writeln('Total scanned: ${hits.length}');
  stdout.writeln('Strict header matches: $totalStrictHeaderMatches');
  stdout.writeln('APPLY_READY: ${applyReady.length}');
  stdout.writeln('NEEDS_REVIEW: ${needsReview.length}');
  stdout.writeln('Rejected false positives: $rejectedFalsePositivesCount');
  stdout.writeln('Wrote: $_outJsonPath');
  stdout.writeln('Wrote: $_outMdPath');
}

void _writeGroupMd(StringBuffer md, String group, List<_Candidate> candidates) {
  md.writeln('## $group');
  if (candidates.isEmpty) {
    md.writeln('_No candidates._');
    md.writeln();
    return;
  }
  for (final c in candidates) {
    md.writeln('### `${c.oduKey}` - `${c.marker}`');
    md.writeln('- marker_index_from_report: `${c.markerIndex}`');
    md.writeln(
      '- strict_header_matches_in_eshu: `${c.strictHeaderCountInEshu}`',
    );
    md.writeln('- target section alias: `${c.targetSectionAlias}`');
    md.writeln('- target content key: `${c.targetContentKey}`');
    md.writeln('- match_count: `${c.matchCount}`');
    md.writeln('- stop_marker_found: `${c.stopMarkerFound}`');
    md.writeln(
      '- nearest_stop_marker_distance_chars: `${c.nearestStopMarkerDistanceChars ?? 'none'}`',
    );
    md.writeln('- truncated: `${c.truncated}`');
    md.writeln(
      '- multiple_headers_inside_snippet: `${c.multipleHeadersInsideSnippet}`',
    );
    md.writeln(
      '- forbidden_words_inside_snippet: `${c.forbiddenWordsInsideSnippet}`',
    );
    md.writeln('- ambiguous_boundary: `${c.ambiguousBoundary}`');
    md.writeln('- apply_ready: `${c.applyReady}`');
    if (c.reviewReasons.isNotEmpty) {
      md.writeln('- review_reasons: `${c.reviewReasons.join(', ')}`');
    }
    md.writeln('- regex: `${c.boundedRegex}`');
    md.writeln('- stop_markers_after_header:');
    if (c.stopMarkersAfterHeader.isEmpty) {
      md.writeln('  - none');
    } else {
      for (final stop in c.stopMarkersAfterHeader) {
        md.writeln('  - [${stop['distance_chars']}] ${stop['line_text']}');
      }
    }
    md.writeln('- patch_ops:');
    md.writeln('```json');
    md.writeln(const JsonEncoder.withIndent('  ').convert(c.patchOps));
    md.writeln('```');
    md.writeln('- preview_snippet:');
    md.writeln('```text');
    md.writeln(c.previewSnippet);
    md.writeln('```');
    md.writeln();
  }
}

List<_StopLine> _collectStopLinesAfter(String text, int startIndex) {
  final lines = <_StopLine>[];
  for (final match in _stopMarkerLineRegex.allMatches(text)) {
    if (match.start <= startIndex) continue;
    lines.add(
      _StopLine(
        index: match.start,
        distanceChars: match.start - startIndex,
        lineText: _lineAt(text, match.start),
      ),
    );
  }
  return lines;
}

String _lineAt(String text, int index) {
  final lineStart = text.lastIndexOf('\n', index);
  final from = lineStart == -1 ? 0 : lineStart + 1;
  final nextNewline = text.indexOf('\n', index);
  final to = nextNewline == -1 ? text.length : nextNewline;
  return text.substring(from, to).trim();
}

String _buildBoundedRegexPattern(String startToken) {
  return '^\\s*($startToken)\\s*:[\\s\\S]{0,$_maxCaptureChars}?(?=^\\s*(?:$_stopMarkerAlternation)\\b|\$(?![\\s\\S]))';
}

Map<String, dynamic> _buildPatchOps(
  _MarkerConfig config,
  String boundedRegexPattern,
) {
  return <String, dynamic>{
    'eshu': <String, dynamic>{
      config.sourceOpKey: <String>[boundedRegexPattern],
      'remove_from_eshu_regex': <String>[boundedRegexPattern],
    },
    config.targetAlias: <String, dynamic>{
      config.targetAppendOpKey: <String>[boundedRegexPattern],
    },
  };
}

bool _hasExistingEshuTargetOpForMarker(
  Map<String, dynamic> patchForOdu,
  _MarkerConfig config,
) {
  final eshuPatch = _extractSectionPatch(patchForOdu, 'eshu');
  if (eshuPatch != null) {
    if (eshuPatch.containsKey(config.sourceOpKey)) {
      return true;
    }
    for (final alias in config.existingTargetAliases) {
      if (eshuPatch.containsKey('move_to_${alias}_regex')) {
        return true;
      }
    }
  }

  for (final alias in config.existingTargetAliases) {
    final targetPatch = _extractSectionPatch(patchForOdu, alias);
    if (targetPatch != null &&
        targetPatch.containsKey(config.targetAppendOpKey)) {
      return true;
    }
  }
  return false;
}

Map<String, dynamic>? _extractSectionPatch(
  Map<String, dynamic> patchForOdu,
  String alias,
) {
  final normalizedAlias = _normalizeSectionAlias(alias);
  for (final entry in patchForOdu.entries) {
    if (_normalizeSectionAlias(entry.key) != normalizedAlias) continue;
    final value = entry.value;
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
  }
  return null;
}

void _increment(Map<String, int> map, String key) {
  map[key] = (map[key] ?? 0) + 1;
}

int _min(int a, int b) => a < b ? a : b;

String _trimPreview(String text) {
  final compact = text.trim();
  if (compact.length <= _previewChars) return compact;
  return compact.substring(0, _previewChars).trim();
}

String _formatReasonCounts(Map<String, int> reasonCounts) {
  if (reasonCounts.isEmpty) return '  - none';
  final sorted = reasonCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final buffer = StringBuffer();
  for (final entry in sorted) {
    buffer.writeln('  - `${entry.key}`: ${entry.value}');
  }
  return buffer.toString().trimRight();
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? -1;
  return -1;
}

String _asString(dynamic value) {
  if (value == null) return '';
  if (value is String) return value;
  return value.toString();
}

String _normalizeKey(String key) => key
    .toUpperCase()
    .replaceAll('_', ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String _normalizeSectionAlias(String key) =>
    key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').trim();

class _MarkerConfig {
  const _MarkerConfig({
    required this.reportMarker,
    required this.startToken,
    required this.strictHeaderRegex,
    required this.inlineWordRegex,
    required this.sourceOpKey,
    required this.targetAlias,
    required this.targetContentKey,
    required this.targetAppendOpKey,
    required this.existingTargetAliases,
  });

  final String reportMarker;
  final String startToken;
  final RegExp strictHeaderRegex;
  final RegExp inlineWordRegex;
  final String sourceOpKey;
  final String targetAlias;
  final String targetContentKey;
  final String targetAppendOpKey;
  final List<String> existingTargetAliases;
}

class _StopLine {
  const _StopLine({
    required this.index,
    required this.distanceChars,
    required this.lineText,
  });

  final int index;
  final int distanceChars;
  final String lineText;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'index': index,
      'distance_chars': distanceChars,
      'line_text': lineText,
    };
  }
}

class _Candidate {
  const _Candidate({
    required this.oduKey,
    required this.marker,
    required this.startToken,
    required this.strictHeaderPattern,
    required this.boundedRegex,
    required this.hitIndex,
    required this.markerIndex,
    required this.strictHeaderCountInEshu,
    required this.eshuLength,
    required this.descripcionLength,
    required this.matchCount,
    required this.stopMarkerFound,
    required this.nearestStopMarkerDistanceChars,
    required this.truncated,
    required this.multipleHeadersInsideSnippet,
    required this.forbiddenWordsInsideSnippet,
    required this.ambiguousBoundary,
    required this.applyReady,
    required this.reviewReasons,
    required this.previewSnippet,
    required this.stopMarkersAfterHeader,
    required this.patchOps,
    required this.targetSectionAlias,
    required this.targetContentKey,
  });

  final String oduKey;
  final String marker;
  final String startToken;
  final String strictHeaderPattern;
  final String boundedRegex;
  final int hitIndex;
  final int markerIndex;
  final int strictHeaderCountInEshu;
  final int eshuLength;
  final int descripcionLength;
  final int matchCount;
  final bool stopMarkerFound;
  final int? nearestStopMarkerDistanceChars;
  final bool truncated;
  final bool multipleHeadersInsideSnippet;
  final bool forbiddenWordsInsideSnippet;
  final bool ambiguousBoundary;
  final bool applyReady;
  final List<String> reviewReasons;
  final String previewSnippet;
  final List<Map<String, dynamic>> stopMarkersAfterHeader;
  final Map<String, dynamic> patchOps;
  final String targetSectionAlias;
  final String targetContentKey;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'odu_key': oduKey,
      'marker': marker,
      'start_token': startToken,
      'strict_header_pattern': strictHeaderPattern,
      'bounded_regex': boundedRegex,
      'hit_index': hitIndex,
      'marker_index': markerIndex,
      'strict_header_count_in_eshu': strictHeaderCountInEshu,
      'target_section_alias': targetSectionAlias,
      'target_content_key': targetContentKey,
      'eshu_length': eshuLength,
      'descripcion_length': descripcionLength,
      'match_count': matchCount,
      'stop_marker_found': stopMarkerFound,
      'nearest_stop_marker_distance_chars': nearestStopMarkerDistanceChars,
      'truncated': truncated,
      'multiple_headers_inside_snippet': multipleHeadersInsideSnippet,
      'forbidden_words_inside_snippet': forbiddenWordsInsideSnippet,
      'ambiguous_boundary': ambiguousBoundary,
      'apply_ready': applyReady,
      'review_reasons': reviewReasons,
      'preview_snippet': previewSnippet,
      'stop_markers_after_header': stopMarkersAfterHeader,
      'patch_ops': patchOps,
    };
  }
}
