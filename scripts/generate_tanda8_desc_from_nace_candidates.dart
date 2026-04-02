import 'dart:convert';
import 'dart:io';

const String _patchedContentPath = 'assets/odu_content_patched.json';
const String _outJsonPath = 'build/tanda8_desc_from_nace_candidates.json';
const String _outMdPath = 'build/tanda8_desc_from_nace_candidates.md';

const int _maxCaptureChars = 4500;
const int _maxCandidates = 12;
const int _previewChars = 900;

const String _baseStopAlternation =
    r'EWES\b|OBRAS\b|DICE\s+IF[ÁA]\b|DICE\s+IFA\b|ESHU\b|REZO\b|SUYERE\b|HISTORIAS?\b|PATAK[ÍI]ES?\b|EN\s+ESTE\s+OD[ÙUO].*NACE\b';
const String _generalEnEsteStopPattern = r'EN\s+ESTE\s+OD[ÙUO]\b';

const String _forbiddenCaptureTokens =
    r'\bOBRAS\b|DICE\s+IFA?\b|\bEWES\b|\bREZO\b|\bSUYERE\b|\bESHU\b|HISTOR|PATAKI';

void main() {
  final contentFile = File(_patchedContentPath);
  if (!contentFile.existsSync()) {
    stderr.writeln('Missing input: $_patchedContentPath');
    exitCode = 1;
    return;
  }

  final decoded = jsonDecode(contentFile.readAsStringSync());
  if (decoded is! Map) {
    stderr.writeln('Invalid JSON format in $_patchedContentPath');
    exitCode = 1;
    return;
  }

  final root = Map<String, dynamic>.from(decoded);
  final oduRaw = root['odu'];
  if (oduRaw is! Map) {
    stderr.writeln('Invalid patched content JSON: missing "odu" object.');
    exitCode = 1;
    return;
  }
  final oduMap = Map<String, dynamic>.from(oduRaw);

  final candidates = <_Candidate>[];
  var scanned = 0;
  var excludedByDescripcionLength = 0;
  var excludedByNoAnchor = 0;
  var excludedByRegexNoMatch = 0;
  var excludedByMissingContent = 0;

  final oduEntries = oduMap.entries.toList()
    ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));

  for (final entry in oduEntries) {
    final oduKey = entry.key.toString();
    final nodeRaw = entry.value;
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
    scanned++;

    if (!(descripcionChars == 0 || descripcionChars < 300)) {
      excludedByDescripcionLength++;
      continue;
    }

    final anchorHit = _findEarliestAnchorHit(nace);
    if (anchorHit == null) {
      excludedByNoAnchor++;
      continue;
    }

    final includeGeneralEnEste = !anchorHit.spec.isEsteOduFamily;
    final stopAlternation = _buildStopAlternation(
      includeGeneralEnEste: includeGeneralEnEste,
    );
    final stopLineRegex = RegExp(
      '^\\s*(?:$stopAlternation).*\$',
      caseSensitive: false,
      multiLine: true,
      dotAll: true,
    );

    final regex = _buildBoundedRegexPattern(
      anchorBody: anchorHit.spec.body,
      stopAlternation: stopAlternation,
    );
    final boundedRegex = RegExp(
      regex,
      caseSensitive: false,
      multiLine: true,
      dotAll: true,
    );
    final matchCount = boundedRegex.allMatches(nace).length;
    if (matchCount <= 0) {
      excludedByRegexNoMatch++;
      continue;
    }

    final extraction = _extractBoundedFromAnchor(
      nace: nace,
      anchorStart: anchorHit.start,
      stopLineRegex: stopLineRegex,
    );

    final preview = extraction.snippet.length <= _previewChars
        ? extraction.snippet
        : extraction.snippet.substring(0, _previewChars);
    final captureChars = extraction.snippet.length;
    final hasForbiddenTokens = _containsForbiddenTokens(extraction.snippet);

    final safeToApply =
        matchCount == 1 &&
        extraction.stopMarkerFound &&
        !extraction.truncated &&
        !hasForbiddenTokens &&
        captureChars >= 200;

    final reasons = <String>[];
    if (matchCount != 1) reasons.add('match_count_$matchCount');
    if (!extraction.stopMarkerFound) reasons.add('no_stop_marker_found');
    if (extraction.truncated) reasons.add('truncated_capture');
    if (hasForbiddenTokens) reasons.add('forbidden_tokens_in_capture');
    if (captureChars < 200) reasons.add('capture_too_short');

    candidates.add(
      _Candidate(
        oduKey: oduKey,
        naceChars: naceChars,
        descripcionChars: descripcionChars,
        anchorUsed: anchorHit.spec.label,
        regex: regex,
        matchCount: matchCount,
        preview: preview.trim(),
        safeToApply: safeToApply,
        reason: reasons.isEmpty ? 'ok' : reasons.join(', '),
        truncated: extraction.truncated,
        stopMarkerFound: extraction.stopMarkerFound,
        stopMarkerLine: extraction.stopMarkerLine,
        firstAnchorIndex: anchorHit.start,
        captureChars: captureChars,
      ),
    );
  }

  candidates.sort((a, b) {
    final aEmpty = a.descripcionChars == 0 ? 1 : 0;
    final bEmpty = b.descripcionChars == 0 ? 1 : 0;
    final byEmpty = bEmpty.compareTo(aEmpty);
    if (byEmpty != 0) return byEmpty;
    final bySafe = b.safeToApply ? 1 : 0;
    final bySafeA = a.safeToApply ? 1 : 0;
    final bySafety = bySafe.compareTo(bySafeA);
    if (bySafety != 0) return bySafety;
    final byNace = b.naceChars.compareTo(a.naceChars);
    if (byNace != 0) return byNace;
    return a.oduKey.compareTo(b.oduKey);
  });

  final selected = candidates.take(_maxCandidates).toList();
  final applyReady = selected.where((c) => c.safeToApply).toList();
  final needsReview = selected.where((c) => !c.safeToApply).toList();

  final jsonOut = <String, dynamic>{
    'source_files': <String, String>{'patched_content': _patchedContentPath},
    'generated_utc': DateTime.now().toUtc().toIso8601String(),
    'selection_criteria': <String, dynamic>{
      'descripcion_chars_rule': '== 0 OR < 300',
      'requires_anchor_in_nace': true,
      'limit': _maxCandidates,
      'capture_limit_chars': _maxCaptureChars,
      'safe_to_apply_rules': <String>[
        'match_count == 1',
        'stop_marker_found == true',
        'truncated == false',
        'capture_len >= 200',
        'forbidden_tokens_in_capture == false',
      ],
    },
    'regex_templates': <String, String>{
      'stop_markers_base': _baseStopAlternation,
      'stop_marker_en_este_conditional': _generalEnEsteStopPattern,
      'forbidden_capture_tokens': _forbiddenCaptureTokens,
    },
    'summary': <String, dynamic>{
      'scanned_odu_count': scanned,
      'excluded_by_descripcion_length': excludedByDescripcionLength,
      'excluded_by_no_anchor_in_nace': excludedByNoAnchor,
      'excluded_by_regex_no_match': excludedByRegexNoMatch,
      'excluded_by_missing_content': excludedByMissingContent,
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
    ..writeln('# TANDA 8 Desc-From-Nace Candidates')
    ..writeln()
    ..writeln('- Source content: `$_patchedContentPath`')
    ..writeln('- Generated (UTC): `${jsonOut['generated_utc']}`')
    ..writeln()
    ..writeln('## Summary')
    ..writeln('- Scanned Odù: `$scanned`')
    ..writeln(
      '- Excluded by descripcion length (>= 300): `$excludedByDescripcionLength`',
    )
    ..writeln('- Excluded by missing anchor in nace: `$excludedByNoAnchor`')
    ..writeln('- Excluded by regex no match: `$excludedByRegexNoMatch`')
    ..writeln('- Excluded by missing content: `$excludedByMissingContent`')
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

  stdout.writeln('Generated TANDA 8 candidates (no patches applied).');
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
    md.writeln('- anchor_used: `${c.anchorUsed}`');
    md.writeln('- match_count: `${c.matchCount}`');
    md.writeln('- capture_chars: `${c.captureChars}`');
    md.writeln('- descripcion_chars: `${c.descripcionChars}`');
    md.writeln('- nace_chars: `${c.naceChars}`');
    md.writeln('- stop_marker_detected: `${c.stopMarkerLine ?? 'none'}`');
    md.writeln('- SAFE_TO_APPLY: `${c.safeToApply}`');
    md.writeln('- reason: `${c.reason}`');
    md.writeln('- regex exacta:');
    md.writeln('```regex');
    md.writeln(c.regex);
    md.writeln('```');
    md.writeln('- preview (first 900 chars):');
    md.writeln('```text');
    md.writeln(c.preview);
    md.writeln('```');
    md.writeln();
  }
}

String _buildStopAlternation({required bool includeGeneralEnEste}) {
  if (!includeGeneralEnEste) {
    return _baseStopAlternation;
  }
  return '$_baseStopAlternation|$_generalEnEsteStopPattern';
}

String _buildBoundedRegexPattern({
  required String anchorBody,
  required String stopAlternation,
}) {
  return '^\\s*(?:$anchorBody)\\b[\\s\\S]{0,$_maxCaptureChars}?(?=^\\s*(?:$stopAlternation)\\b|\$(?![\\s\\S]))';
}

bool _containsForbiddenTokens(String text) {
  final folded = _foldDiacritics(text).toUpperCase();
  return RegExp(_forbiddenCaptureTokens, caseSensitive: false).hasMatch(folded);
}

_AnchorHit? _findEarliestAnchorHit(String nace) {
  _AnchorHit? earliest;
  for (final spec in _anchorSpecs) {
    for (final match in spec.lineRegex.allMatches(nace)) {
      final hit = _AnchorHit(spec: spec, start: match.start);
      if (earliest == null || hit.start < earliest.start) {
        earliest = hit;
      }
      break;
    }
  }
  return earliest;
}

_ExtractionState _extractBoundedFromAnchor({
  required String nace,
  required int anchorStart,
  required RegExp stopLineRegex,
}) {
  final maxEnd = _min(anchorStart + _maxCaptureChars, nace.length);

  int? stopIndex;
  String? stopLine;
  for (final stopMatch in stopLineRegex.allMatches(nace)) {
    if (stopMatch.start <= anchorStart) {
      continue;
    }
    stopIndex = stopMatch.start;
    stopLine = stopMatch.group(0)?.trim();
    break;
  }

  var hasStopWithinLimit = false;
  var end = maxEnd;
  if (stopIndex != null && stopIndex <= maxEnd) {
    hasStopWithinLimit = true;
    end = stopIndex;
  }
  final snippet = nace.substring(anchorStart, end).trim();
  final truncated = !hasStopWithinLimit && maxEnd < nace.length;

  return _ExtractionState(
    snippet: snippet,
    stopMarkerFound: hasStopWithinLimit,
    stopMarkerLine: hasStopWithinLimit ? stopLine : null,
    truncated: truncated,
  );
}

String _asString(dynamic value) {
  if (value == null) return '';
  if (value is String) return value;
  return value.toString();
}

int _effectiveLength(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed == '-') return 0;
  return trimmed.length;
}

int _min(int a, int b) => a < b ? a : b;

String _foldDiacritics(String value) {
  return value
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('Á', 'A')
      .replaceAll('É', 'E')
      .replaceAll('Í', 'I')
      .replaceAll('Ó', 'O')
      .replaceAll('Ú', 'U')
      .replaceAll('ü', 'u')
      .replaceAll('Ü', 'U')
      .replaceAll('ñ', 'n')
      .replaceAll('Ñ', 'N')
      .replaceAll('ù', 'u')
      .replaceAll('Ù', 'U');
}

class _AnchorSpec {
  _AnchorSpec({
    required this.key,
    required this.label,
    required this.body,
    required this.isEsteOduFamily,
  }) : lineRegex = RegExp(
         '^\\s*(?:$body)\\b',
         caseSensitive: false,
         multiLine: true,
         dotAll: true,
       );

  final String key;
  final String label;
  final String body;
  final bool isEsteOduFamily;
  final RegExp lineRegex;
}

final List<_AnchorSpec> _anchorSpecs = <_AnchorSpec>[
  _AnchorSpec(
    key: 'descripcion_del_odu',
    label: 'DESCRIPCION DEL OD(O/U/Ù)',
    body: r'DESCRIPCI[ÓO]N\s+DEL\s+OD[ÙUO]|DESCRIPCI[ÓO]N\s+DEL\s+ODO',
    isEsteOduFamily: false,
  ),
  _AnchorSpec(
    key: 'este_es_el_odu',
    label: 'ESTE ES EL ODU',
    body: r'ESTE\s+ES\s+EL\s+OD[ÙUO]',
    isEsteOduFamily: true,
  ),
  _AnchorSpec(
    key: 'este_odu',
    label: 'ESTE ODU',
    body: r'ESTE\s+OD[ÙUO]',
    isEsteOduFamily: true,
  ),
  _AnchorSpec(
    key: 'este_ifa',
    label: 'ESTE IFA/IFÁ',
    body: r'ESTE\s+IF[ÁA]|ESTE\s+IFA',
    isEsteOduFamily: false,
  ),
  _AnchorSpec(
    key: 'este_signo',
    label: 'ESTE SIGNO',
    body: r'ESTE\s+SIGNO',
    isEsteOduFamily: false,
  ),
];

class _AnchorHit {
  const _AnchorHit({required this.spec, required this.start});

  final _AnchorSpec spec;
  final int start;
}

class _ExtractionState {
  const _ExtractionState({
    required this.snippet,
    required this.stopMarkerFound,
    required this.stopMarkerLine,
    required this.truncated,
  });

  final String snippet;
  final bool stopMarkerFound;
  final String? stopMarkerLine;
  final bool truncated;
}

class _Candidate {
  const _Candidate({
    required this.oduKey,
    required this.naceChars,
    required this.descripcionChars,
    required this.anchorUsed,
    required this.regex,
    required this.matchCount,
    required this.preview,
    required this.safeToApply,
    required this.reason,
    required this.truncated,
    required this.stopMarkerFound,
    required this.stopMarkerLine,
    required this.firstAnchorIndex,
    required this.captureChars,
  });

  final String oduKey;
  final int naceChars;
  final int descripcionChars;
  final String anchorUsed;
  final String regex;
  final int matchCount;
  final String preview;
  final bool safeToApply;
  final String reason;
  final bool truncated;
  final bool stopMarkerFound;
  final String? stopMarkerLine;
  final int firstAnchorIndex;
  final int captureChars;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'odu_key': oduKey,
      'nace_chars': naceChars,
      'descripcion_chars': descripcionChars,
      'anchor_used': anchorUsed,
      'regex': regex,
      'match_count': matchCount,
      'capture_chars': captureChars,
      'preview': preview,
      'safe_to_apply': safeToApply,
      'reason': reason,
      'truncated': truncated,
      'stop_marker_found': stopMarkerFound,
      'stop_marker_line': stopMarkerLine,
      'first_anchor_index': firstAnchorIndex,
      'patch_ops': <String, dynamic>{
        'nace': <String, dynamic>{
          'move_to_desc_regex': <String>[regex],
          'remove_from_nace_regex': <String>[regex],
        },
        'descripcion': <String, dynamic>{
          'append_from_nace_regex': <String>[regex],
        },
      },
    };
  }
}
