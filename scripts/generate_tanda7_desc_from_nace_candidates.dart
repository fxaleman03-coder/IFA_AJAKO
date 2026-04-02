import 'dart:convert';
import 'dart:io';

const String _suggestionsPath = 'build/odu_patch_suggestions.json';
const String _patchedContentPath = 'assets/odu_content_patched.json';
const String _patchesPath = 'assets/odu_patches.json';
const String _outJsonPath = 'build/tanda7_desc_from_nace_candidates.json';
const String _outMdPath = 'build/tanda7_desc_from_nace_candidates.md';

const int _maxCaptureChars = 6000;
const int _maxCandidates = 20;
const int _previewChars = 600;

const List<String> _requiredFlags = <String>[
  'DESC_EMPTY_BUT_NACE_LONG',
  'DESC_MARKERS_IN_NACE',
  'NACE_TOO_LONG',
];

const String _descriptionAnchorAlternation =
    r'(?:AQU[ÍI]\s*:\s*)?(?:DESCRIPCI[ÓO]N\s+DEL\s+OD(?:Ù|U|O)|ESTE\s+ES\s+EL\s+OD(?:Ù|U|O)|ESTE\s+OD(?:Ù|U|O)|ESTE\s+SIGNO|ESTE\s+IF[ÁA])\b';

const String _stopMarkerAlternation =
    r'EN\s+ESTE\s+OD(?:Ù|U|O)\b|DESCRIPCI\w*|EWES\b|ESHU\b|OBRAS\b|DICE\s+IF[ÁA]\b|PAT(?:A|Á)K(?:I|Í)E|HISTORIAS?|REZO\b|SUYERE\b';

final RegExp _firstAnchorRegex = RegExp(
  r'^\s*(?:AQU[ÍI]\s*:\s*)?(?:DESCRIPCI[ÓO]N)\s+DEL\s+OD(?:Ù|U|O)\b|^\s*(?:AQU[ÍI]\s*:\s*)?ESTE\s+ES\s+EL\s+OD(?:Ù|U|O)\b|^\s*(?:AQU[ÍI]\s*:\s*)?ESTE\s+OD(?:Ù|U|O)\b|^\s*(?:AQU[ÍI]\s*:\s*)?ESTE\s+SIGNO\b|^\s*(?:AQU[ÍI]\s*:\s*)?ESTE\s+IF[ÁA]\b',
  caseSensitive: false,
  multiLine: true,
  dotAll: true,
);

final RegExp _anchorPrefixRegex = RegExp(
  '^\\s*$_descriptionAnchorAlternation',
  caseSensitive: false,
  multiLine: false,
  dotAll: true,
);

final RegExp _stopMarkerLineRegex = RegExp(
  '^\\s*(?:$_stopMarkerAlternation)\\b.*\$',
  caseSensitive: false,
  multiLine: true,
  dotAll: true,
);

void main() {
  final suggestionsFile = File(_suggestionsPath);
  final contentFile = File(_patchedContentPath);
  final patchesFile = File(_patchesPath);

  if (!suggestionsFile.existsSync()) {
    stderr.writeln('Missing input: $_suggestionsPath');
    exitCode = 1;
    return;
  }
  if (!contentFile.existsSync()) {
    stderr.writeln('Missing input: $_patchedContentPath');
    exitCode = 1;
    return;
  }
  if (!patchesFile.existsSync()) {
    stderr.writeln('Missing input: $_patchesPath');
    exitCode = 1;
    return;
  }

  final suggestionsDecoded = jsonDecode(suggestionsFile.readAsStringSync());
  final contentDecoded = jsonDecode(contentFile.readAsStringSync());
  final patchesDecoded = jsonDecode(patchesFile.readAsStringSync());
  if (suggestionsDecoded is! Map ||
      contentDecoded is! Map ||
      patchesDecoded is! Map) {
    stderr.writeln('Invalid JSON format in one or more inputs.');
    exitCode = 1;
    return;
  }

  final suggestionsRoot = Map<String, dynamic>.from(suggestionsDecoded);
  final suggestionsRaw = suggestionsRoot['suggestions'];
  if (suggestionsRaw is! Map) {
    stderr.writeln('Invalid suggestions JSON: missing "suggestions" object.');
    exitCode = 1;
    return;
  }
  final suggestions = Map<String, dynamic>.from(suggestionsRaw);

  final contentRoot = Map<String, dynamic>.from(contentDecoded);
  final oduRaw = contentRoot['odu'];
  if (oduRaw is! Map) {
    stderr.writeln('Invalid patched content JSON: missing "odu" object.');
    exitCode = 1;
    return;
  }
  final oduMap = Map<String, dynamic>.from(oduRaw);
  final normalizedContentLookup = <String, String>{
    for (final key in oduMap.keys.whereType<String>())
      _normalizeOduKey(key): key,
  };

  final patchesRoot = Map<String, dynamic>.from(patchesDecoded);
  final normalizedPatchLookup = <String, Map<String, dynamic>>{};
  for (final entry in patchesRoot.entries) {
    if (entry.key.startsWith('_') || entry.value is! Map) continue;
    normalizedPatchLookup[_normalizeOduKey(entry.key)] =
        Map<String, dynamic>.from(entry.value as Map);
  }

  final candidates = <_Candidate>[];
  var scannedByFlags = 0;
  var excludedByDescripcionLength = 0;
  var excludedByExistingDescMovePatch = 0;
  var excludedByMissingContent = 0;
  var excludedByNoAnchorInNace = 0;
  var excludedByRegexNoMatch = 0;

  final suggestionEntries = suggestions.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));

  for (final entry in suggestionEntries) {
    final suggestionKey = entry.key;
    final suggestionValue = entry.value;
    if (suggestionValue is! Map) continue;
    final suggestion = Map<String, dynamic>.from(suggestionValue);

    final flags = (suggestion['flags'] is List)
        ? List<String>.from(suggestion['flags'] as List)
        : const <String>[];
    if (!_hasRequiredFlag(flags)) {
      continue;
    }
    scannedByFlags++;

    final normalizedSuggestionKey = _normalizeOduKey(suggestionKey);
    final canonicalOduKey = normalizedContentLookup[normalizedSuggestionKey];
    if (canonicalOduKey == null) {
      excludedByMissingContent++;
      continue;
    }

    final patchEntry = normalizedPatchLookup[normalizedSuggestionKey];
    if (patchEntry != null && _hasExistingDescMovePatch(patchEntry)) {
      excludedByExistingDescMovePatch++;
      continue;
    }

    final nodeRaw = oduMap[canonicalOduKey];
    if (nodeRaw is! Map) {
      excludedByMissingContent++;
      continue;
    }
    final node = Map<String, dynamic>.from(nodeRaw);
    final contentRaw = node['content'];
    if (contentRaw is! Map) {
      excludedByMissingContent++;
      continue;
    }
    final content = Map<String, dynamic>.from(contentRaw);

    final nace = _asString(content['nace']);
    final descripcion = _asString(content['descripcion']);
    final descripcionChars = _effectiveLength(descripcion);
    final naceChars = nace.length;

    if (!(descripcionChars == 0 || descripcionChars < 400)) {
      excludedByDescripcionLength++;
      continue;
    }

    final firstAnchor = _firstAnchorRegex.firstMatch(nace);
    if (firstAnchor == null) {
      excludedByNoAnchorInNace++;
      continue;
    }

    final boundedRegex = _buildBoundedRegexPattern();
    final boundedRegExp = RegExp(
      boundedRegex,
      caseSensitive: false,
      multiLine: true,
      dotAll: true,
    );
    final allMatches = boundedRegExp.allMatches(nace).toList();
    final matchCount = allMatches.length;
    if (matchCount <= 0) {
      excludedByRegexNoMatch++;
      continue;
    }

    final extractionState = _extractFromFirstAnchor(
      nace: nace,
      firstAnchorIndex: firstAnchor.start,
    );
    final previewRaw = extractionState.snippet;
    final preview = previewRaw.length <= _previewChars
        ? previewRaw
        : previewRaw.substring(0, _previewChars);
    final previewBeginsWithAnchor = _anchorPrefixRegex.hasMatch(previewRaw);

    final isApplyReady =
        matchCount == 1 &&
        !extractionState.truncated &&
        previewBeginsWithAnchor;
    final needsManualReview = !isApplyReady;
    final reviewReasons = <String>[];
    if (matchCount != 1) {
      reviewReasons.add('match_count_$matchCount');
    }
    if (extractionState.truncated) {
      reviewReasons.add('truncated_capture');
    }
    if (!previewBeginsWithAnchor) {
      reviewReasons.add('preview_not_starting_with_description_anchor');
    }
    if (!extractionState.stopMarkerFound) {
      reviewReasons.add('no_stop_marker_found');
    }

    final candidate = _Candidate(
      oduKey: canonicalOduKey,
      suggestionKey: suggestionKey,
      flags: flags,
      naceChars: naceChars,
      descripcionChars: descripcionChars,
      regex: boundedRegex,
      matchCount: matchCount,
      preview: preview.trim(),
      needsManualReview: needsManualReview,
      reviewReason: reviewReasons.join(', '),
      applyReady: isApplyReady,
      truncated: extractionState.truncated,
      stopMarkerFound: extractionState.stopMarkerFound,
      firstAnchorIndex: firstAnchor.start,
    );
    candidates.add(candidate);
  }

  candidates.sort((a, b) {
    final aEmptyDesc = a.descripcionChars == 0 ? 1 : 0;
    final bEmptyDesc = b.descripcionChars == 0 ? 1 : 0;
    final byEmptyDesc = bEmptyDesc.compareTo(aEmptyDesc);
    if (byEmptyDesc != 0) return byEmptyDesc;
    final byNaceChars = b.naceChars.compareTo(a.naceChars);
    if (byNaceChars != 0) return byNaceChars;
    return a.oduKey.compareTo(b.oduKey);
  });

  final selected = candidates.take(_maxCandidates).toList();
  final applyReady = selected.where((c) => c.applyReady).toList();
  final needsReview = selected.where((c) => !c.applyReady).toList();

  final jsonOut = <String, dynamic>{
    'source_files': <String, String>{
      'suggestions': _suggestionsPath,
      'patched_content': _patchedContentPath,
      'patches': _patchesPath,
    },
    'generated_utc': DateTime.now().toUtc().toIso8601String(),
    'selection_criteria': <String, dynamic>{
      'required_flags_any': _requiredFlags,
      'descripcion_chars_rule': '== 0 OR < 400',
      'exclude_if_desc_move_patch_exists': true,
      'limit': _maxCandidates,
      'prioritization': 'descripcion empty first, then nace_chars descending',
      'capture_limit_chars': _maxCaptureChars,
    },
    'regex_templates': <String, String>{
      'description_anchor': _descriptionAnchorAlternation,
      'stop_markers': _stopMarkerAlternation,
      'bounded_capture': _buildBoundedRegexPattern(),
    },
    'summary': <String, dynamic>{
      'scanned_by_flags': scannedByFlags,
      'excluded_by_descripcion_length': excludedByDescripcionLength,
      'excluded_by_existing_desc_move_patch': excludedByExistingDescMovePatch,
      'excluded_by_missing_content': excludedByMissingContent,
      'excluded_by_no_anchor_in_nace': excludedByNoAnchorInNace,
      'excluded_by_regex_no_match': excludedByRegexNoMatch,
      'eligible_before_limit': candidates.length,
      'selected_count': selected.length,
      'apply_ready_count': applyReady.length,
      'needs_review_count': needsReview.length,
    },
    'groups': <String, dynamic>{
      'APPLY_READY': applyReady.map((c) => c.toJson()).toList(),
      'NEEDS_REVIEW': needsReview.map((c) => c.toJson()).toList(),
    },
    'candidates': selected.map((c) => c.toJson()).toList(),
  };

  final md = StringBuffer()
    ..writeln('# TANDA 7 Desc-From-Nace Candidates')
    ..writeln()
    ..writeln('- Suggestions source: `$_suggestionsPath`')
    ..writeln('- Patched content source: `$_patchedContentPath`')
    ..writeln('- Patches source: `$_patchesPath`')
    ..writeln('- Generated (UTC): `${jsonOut['generated_utc']}`')
    ..writeln()
    ..writeln('## Summary')
    ..writeln('- Scanned by flags: `$scannedByFlags`')
    ..writeln(
      '- Excluded by descripcion length: `$excludedByDescripcionLength`',
    )
    ..writeln(
      '- Excluded by existing desc move patch: `$excludedByExistingDescMovePatch`',
    )
    ..writeln('- Excluded by missing content: `$excludedByMissingContent`')
    ..writeln('- Excluded by no anchor in nace: `$excludedByNoAnchorInNace`')
    ..writeln('- Excluded by regex no match: `$excludedByRegexNoMatch`')
    ..writeln('- Eligible before limit: `${candidates.length}`')
    ..writeln('- Selected: `${selected.length}`')
    ..writeln('- APPLY_READY: `${applyReady.length}`')
    ..writeln('- NEEDS_REVIEW: `${needsReview.length}`')
    ..writeln();

  _writeGroupMd(md, 'APPLY_READY', applyReady);
  _writeGroupMd(md, 'NEEDS_REVIEW', needsReview);

  Directory('build').createSync(recursive: true);
  File(
    _outJsonPath,
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(jsonOut));
  File(_outMdPath).writeAsStringSync(md.toString());

  stdout.writeln('Generated TANDA 7 candidates (no patches applied).');
  stdout.writeln('Selected: ${selected.length}');
  stdout.writeln('APPLY_READY: ${applyReady.length}');
  stdout.writeln('NEEDS_REVIEW: ${needsReview.length}');
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
    md.writeln('### `${c.oduKey}`');
    md.writeln('- flags: `${c.flags.join(' | ')}`');
    md.writeln('- nace_chars: `${c.naceChars}`');
    md.writeln('- descripcion_chars: `${c.descripcionChars}`');
    md.writeln('- match_count: `${c.matchCount}`');
    md.writeln('- apply_ready: `${c.applyReady}`');
    md.writeln('- needs_manual_review: `${c.needsManualReview}`');
    md.writeln('- needs_manual_review_reason: `${c.reviewReason}`');
    md.writeln('- truncated: `${c.truncated}`');
    md.writeln('- stop_marker_found: `${c.stopMarkerFound}`');
    md.writeln('- first_anchor_index: `${c.firstAnchorIndex}`');
    md.writeln('- regex:');
    md.writeln('```regex');
    md.writeln(c.regex);
    md.writeln('```');
    md.writeln('- preview (first 600 chars):');
    md.writeln('```text');
    md.writeln(c.preview);
    md.writeln('```');
    md.writeln();
  }
}

bool _hasRequiredFlag(List<String> flags) {
  for (final flag in flags) {
    if (_requiredFlags.contains(flag)) {
      return true;
    }
  }
  return false;
}

bool _hasExistingDescMovePatch(Map<String, dynamic> patchEntry) {
  for (final sectionEntry in patchEntry.entries) {
    final sectionKey = sectionEntry.key;
    final sectionValue = sectionEntry.value;
    if (sectionValue is! Map) continue;
    final sectionMap = Map<String, dynamic>.from(sectionValue);
    final normalizedSection = _normalizeSectionAlias(sectionKey);
    for (final opKey in sectionMap.keys) {
      if (opKey == 'move_to_desc_regex' ||
          opKey == 'move_to_descripcion_regex') {
        return true;
      }
      if ((normalizedSection == 'descripcion' || normalizedSection == 'desc') &&
          (opKey.startsWith('append_from_') ||
              opKey.startsWith('prepend_from_')) &&
          opKey.endsWith('_regex')) {
        return true;
      }
    }
  }
  return false;
}

_ExtractionState _extractFromFirstAnchor({
  required String nace,
  required int firstAnchorIndex,
}) {
  final maxEnd = _min(firstAnchorIndex + _maxCaptureChars, nace.length);
  var stopMarkerFound = false;
  var stopIndex = -1;

  for (final stopMatch in _stopMarkerLineRegex.allMatches(nace)) {
    if (stopMatch.start <= firstAnchorIndex) continue;
    stopMarkerFound = true;
    stopIndex = stopMatch.start;
    break;
  }

  final end = stopMarkerFound ? stopIndex : maxEnd;
  final snippet = nace.substring(firstAnchorIndex, end).trim();
  final truncated = !stopMarkerFound && maxEnd < nace.length;

  return _ExtractionState(
    snippet: snippet,
    stopMarkerFound: stopMarkerFound,
    truncated: truncated,
  );
}

String _buildBoundedRegexPattern() {
  return '^\\s*$_descriptionAnchorAlternation[\\s\\S]{0,$_maxCaptureChars}?(?=^\\s*(?:$_stopMarkerAlternation)\\b|\\\$(?![\\s\\S]))';
}

int _effectiveLength(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed == '-') return 0;
  return trimmed.length;
}

String _asString(dynamic value) {
  if (value == null) return '';
  if (value is String) return value;
  return value.toString();
}

int _min(int a, int b) => a < b ? a : b;

String _normalizeOduKey(String key) => key
    .toUpperCase()
    .replaceAll('_', ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String _normalizeSectionAlias(String key) =>
    key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').trim();

class _ExtractionState {
  const _ExtractionState({
    required this.snippet,
    required this.stopMarkerFound,
    required this.truncated,
  });

  final String snippet;
  final bool stopMarkerFound;
  final bool truncated;
}

class _Candidate {
  const _Candidate({
    required this.oduKey,
    required this.suggestionKey,
    required this.flags,
    required this.naceChars,
    required this.descripcionChars,
    required this.regex,
    required this.matchCount,
    required this.preview,
    required this.needsManualReview,
    required this.reviewReason,
    required this.applyReady,
    required this.truncated,
    required this.stopMarkerFound,
    required this.firstAnchorIndex,
  });

  final String oduKey;
  final String suggestionKey;
  final List<String> flags;
  final int naceChars;
  final int descripcionChars;
  final String regex;
  final int matchCount;
  final String preview;
  final bool needsManualReview;
  final String reviewReason;
  final bool applyReady;
  final bool truncated;
  final bool stopMarkerFound;
  final int firstAnchorIndex;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'odu_key': oduKey,
      'suggestion_key': suggestionKey,
      'flags': flags,
      'nace_chars': naceChars,
      'descripcion_chars': descripcionChars,
      'regex': regex,
      'match_count': matchCount,
      'preview': preview,
      'apply_ready': applyReady,
      'needs_manual_review': needsManualReview,
      'needs_manual_review_reason': reviewReason,
      'truncated': truncated,
      'stop_marker_found': stopMarkerFound,
      'first_anchor_index': firstAnchorIndex,
    };
  }
}
