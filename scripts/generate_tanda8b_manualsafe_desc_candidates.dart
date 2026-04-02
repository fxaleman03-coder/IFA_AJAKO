import 'dart:convert';
import 'dart:io';

const String _inputPath = 'assets/odu_content_patched.json';
const String _outJsonPath = 'build/tanda8b_manualsafe_desc_candidates.json';
const String _outMdPath = 'build/tanda8b_manualsafe_desc_candidates.md';

const int _maxCaptureChars = 4500;
const int _previewChars = 1200;
const int _contaminationScanChars = 800;

const List<String> _targetOduKeys = <String>[
  'IWORI BOFUN',
  'OJUANI BOFUN',
  'OSHE YEKUN',
];

const String _strongStopAlternation =
    r'EWES\b|OBRAS\b|DICE\s+IF[ÁA]\b|REZO\b|SUYERE\b|PAT(?:A|Á)K(?:I|Í)E|HISTORIAS?\b|ESHU\b';

const String _enEsteNaceStop = r'EN\s+ESTE\s+OD(?:Ù|U|O)\s+NACE\b';

const List<_AnchorSpec> _anchorSpecs = <_AnchorSpec>[
  _AnchorSpec(
    key: 'descripcion_del_odu',
    label: 'DESCRIPCIÓN DEL OD(O/U/Ù)',
    body: r'DESCRIPCI(?:Ó|O)N\s+DEL\s+OD(?:Ù|U|O)',
    regex: r'^\s*DESCRIPCI(?:Ó|O)N\s+DEL\s+OD(?:Ù|U|O)\b',
    isEsteOduFamily: false,
  ),
  _AnchorSpec(
    key: 'este_es_el_odu',
    label: 'ESTE ES EL ODU',
    body: r'ESTE\s+ES\s+EL\s+OD(?:Ù|U|O)',
    regex: r'^\s*ESTE\s+ES\s+EL\s+OD(?:Ù|U|O)\b',
    isEsteOduFamily: true,
  ),
  _AnchorSpec(
    key: 'este_odu',
    label: 'ESTE ODU',
    body: r'ESTE\s+OD(?:Ù|U|O)',
    regex: r'^\s*ESTE\s+OD(?:Ù|U|O)\b',
    isEsteOduFamily: true,
  ),
  _AnchorSpec(
    key: 'este_ifa',
    label: 'ESTE IFÁ / ESTE IFA',
    body: r'ESTE\s+IF[ÁA]|ESTE\s+IFA',
    regex: r'^\s*ESTE\s+IF[ÁA]\b|^\s*ESTE\s+IFA\b',
    isEsteOduFamily: false,
  ),
  _AnchorSpec(
    key: 'este_signo',
    label: 'ESTE SIGNO',
    body: r'ESTE\s+SIGNO',
    regex: r'^\s*ESTE\s+SIGNO\b',
    isEsteOduFamily: false,
  ),
];

void main() {
  final file = File(_inputPath);
  if (!file.existsSync()) {
    stderr.writeln('Missing input: $_inputPath');
    exitCode = 1;
    return;
  }

  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    stderr.writeln('Invalid JSON root in $_inputPath');
    exitCode = 1;
    return;
  }

  final oduRaw = decoded['odu'];
  if (oduRaw is! Map) {
    stderr.writeln('Invalid JSON: missing "odu" object.');
    exitCode = 1;
    return;
  }
  final oduMap = Map<String, dynamic>.from(oduRaw);

  final candidates = <_Candidate>[];
  final missingTargets = <String>[];

  for (final target in _targetOduKeys) {
    final canonicalKey = _resolveOduKey(oduMap, target);
    if (canonicalKey == null) {
      missingTargets.add(target);
      continue;
    }

    final nodeRaw = oduMap[canonicalKey];
    if (nodeRaw is! Map) {
      missingTargets.add(target);
      continue;
    }

    final node = Map<String, dynamic>.from(nodeRaw);
    final contentRaw = node['content'];
    if (contentRaw is! Map) {
      missingTargets.add(target);
      continue;
    }

    final content = Map<String, dynamic>.from(contentRaw);
    final nace = _asString(content['nace']);

    final anchorHit = _findAnchor(nace);
    if (anchorHit == null) {
      candidates.add(
        _Candidate(
          oduKey: canonicalKey,
          anchorUsed: 'none',
          regexMoveToDesc: '',
          regexRemoveFromNace: '',
          matchCount: 0,
          stopMarkerFound: false,
          stopMarkerLine: null,
          truncated: false,
          contamination: false,
          contaminationTokens: const <String>[],
          previewCapture: '',
          captureLen: 0,
          safeToApply: false,
          reason: 'anchor_not_found_in_nace',
          splitProposal: null,
          tweak: 'Revisar manualmente el inicio real del bloque descriptivo.',
        ),
      );
      continue;
    }

    final includeEnEsteNaceStop = !anchorHit.spec.isEsteOduFamily;
    final stopAlternation = _buildStopAlternation(
      includeEnEsteNaceStop: includeEnEsteNaceStop,
    );
    final stopLineRegex = RegExp(
      '^\\s*(?:$stopAlternation).*\$',
      caseSensitive: false,
      multiLine: true,
      dotAll: true,
    );

    final mainRegex = _buildMainRegex(
      anchorBody: anchorHit.spec.body,
      stopAlternation: stopAlternation,
    );
    final mainRegExp = RegExp(
      mainRegex,
      caseSensitive: false,
      multiLine: true,
      dotAll: true,
    );
    final matchCount = mainRegExp.allMatches(nace).length;

    final extraction = _extractSnippet(
      nace: nace,
      anchorStart: anchorHit.start,
      stopLineRegex: stopLineRegex,
    );

    final contaminationCheck = _checkContamination(
      extraction.snippet,
      scanChars: _contaminationScanChars,
    );
    final contamination = contaminationCheck.tokens.isNotEmpty;
    final captureLen = extraction.snippet.length;
    final previewCapture = captureLen <= _previewChars
        ? extraction.snippet
        : extraction.snippet.substring(0, _previewChars);

    final safeToApply =
        matchCount == 1 &&
        extraction.stopMarkerFound &&
        !extraction.truncated &&
        !contamination &&
        captureLen >= 200;

    final reasons = <String>[];
    if (matchCount != 1) reasons.add('match_count_$matchCount');
    if (!extraction.stopMarkerFound) reasons.add('no_stop_marker_found');
    if (extraction.truncated) reasons.add('truncated_capture');
    if (contamination) reasons.add('contamination_in_first_800');
    if (captureLen < 200) reasons.add('capture_too_short');
    final reason = reasons.isEmpty ? 'ok' : reasons.join(', ');

    _SplitProposal? splitProposal;
    if (contamination) {
      final split1 = _buildSplitRegexPart1(anchorBody: anchorHit.spec.body);
      final split2 = _buildSplitRegexPart2(
        anchorBody: anchorHit.spec.body,
        stopAlternation: stopAlternation,
      );
      splitProposal = _SplitProposal(
        regexPart1: split1,
        regexPart2: split2,
        rationale:
            'Contamination detectada: dividir en primer párrafo corto y resto acotado por stop marker.',
      );
    }

    final tweak = _suggestTweak(
      safeToApply: safeToApply,
      stopMarkerFound: extraction.stopMarkerFound,
      truncated: extraction.truncated,
      contamination: contamination,
      matchCount: matchCount,
      captureLen: captureLen,
    );

    candidates.add(
      _Candidate(
        oduKey: canonicalKey,
        anchorUsed: anchorHit.spec.label,
        regexMoveToDesc: mainRegex,
        regexRemoveFromNace: mainRegex,
        matchCount: matchCount,
        stopMarkerFound: extraction.stopMarkerFound,
        stopMarkerLine: extraction.stopMarkerLine,
        truncated: extraction.truncated,
        contamination: contamination,
        contaminationTokens: contaminationCheck.tokens,
        previewCapture: previewCapture.trim(),
        captureLen: captureLen,
        safeToApply: safeToApply,
        reason: reason,
        splitProposal: splitProposal,
        tweak: tweak,
      ),
    );
  }

  final applyReady = candidates.where((c) => c.safeToApply).toList();
  final needsReview = candidates.where((c) => !c.safeToApply).toList();

  final jsonOut = <String, dynamic>{
    'source_file': _inputPath,
    'generated_utc': DateTime.now().toUtc().toIso8601String(),
    'target_odu_keys': _targetOduKeys,
    'summary': <String, dynamic>{
      'target_count': _targetOduKeys.length,
      'resolved_count': candidates.length,
      'missing_targets': missingTargets,
      'apply_ready_count': applyReady.length,
      'needs_review_count': needsReview.length,
    },
    'safety_rules': <String>[
      'No patches applied.',
      'Match count computed against raw nace from assets/odu_content_patched.json.',
      'SAFE_TO_APPLY requires match_count==1, stop_marker_found, !truncated, !contamination, capture_len>=200.',
      'If contamination, propose split regexes instead of forcing APPLY_READY.',
    ],
    'groups': <String, dynamic>{
      'APPLY_READY': applyReady.map((c) => c.toJson()).toList(),
      'NEEDS_REVIEW': needsReview.map((c) => c.toJson()).toList(),
    },
    'candidates': candidates.map((c) => c.toJson()).toList(),
  };

  final md = StringBuffer()
    ..writeln('# TANDA 8B Manual-Safe Desc Candidates')
    ..writeln()
    ..writeln('- Source: `$_inputPath`')
    ..writeln('- Generated (UTC): `${jsonOut['generated_utc']}`')
    ..writeln('- Targets: `${_targetOduKeys.join(', ')}`')
    ..writeln('- APPLY_READY: `${applyReady.length}`')
    ..writeln('- NEEDS_REVIEW: `${needsReview.length}`')
    ..writeln();

  for (final c in candidates) {
    md.writeln('## `${c.oduKey}`');
    md.writeln('- anchor_used: `${c.anchorUsed}`');
    md.writeln('- match_count: `${c.matchCount}`');
    md.writeln('- stop_marker_found: `${c.stopMarkerFound}`');
    md.writeln('- stop_marker_line: `${c.stopMarkerLine ?? 'none'}`');
    md.writeln('- truncated: `${c.truncated}`');
    md.writeln('- contamination: `${c.contamination}`');
    md.writeln(
      '- contamination_tokens: `${c.contaminationTokens.isEmpty ? 'none' : c.contaminationTokens.join(', ')}`',
    );
    md.writeln('- capture_len: `${c.captureLen}`');
    md.writeln('- SAFE_TO_APPLY: `${c.safeToApply}`');
    if (!c.safeToApply) {
      md.writeln('- reason_not_safe: `${c.reason}`');
      md.writeln('- tweak: `${c.tweak}`');
    } else {
      md.writeln('- reason_not_safe: `n/a`');
      md.writeln('- tweak: `none`');
    }
    md.writeln('- regex_move_to_desc:');
    md.writeln('```regex');
    md.writeln(c.regexMoveToDesc);
    md.writeln('```');
    md.writeln('- regex_remove_from_nace:');
    md.writeln('```regex');
    md.writeln(c.regexRemoveFromNace);
    md.writeln('```');
    if (c.splitProposal != null) {
      md.writeln('- split_proposal:');
      md.writeln('  - rationale: `${c.splitProposal!.rationale}`');
      md.writeln('  - regex_part1:');
      md.writeln('```regex');
      md.writeln(c.splitProposal!.regexPart1);
      md.writeln('```');
      md.writeln('  - regex_part2:');
      md.writeln('```regex');
      md.writeln(c.splitProposal!.regexPart2);
      md.writeln('```');
    }
    md.writeln('- preview_capture (first 1200 chars):');
    md.writeln('```text');
    md.writeln(c.previewCapture);
    md.writeln('```');
    md.writeln();
  }

  Directory('build').createSync(recursive: true);
  File(
    _outJsonPath,
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(jsonOut));
  File(_outMdPath).writeAsStringSync(md.toString());

  stdout.writeln('Generated manual-safe TANDA 8B candidates (no patches applied).');
  stdout.writeln('Resolved targets: ${candidates.length}');
  stdout.writeln('APPLY_READY: ${applyReady.length}');
  stdout.writeln('NEEDS_REVIEW: ${needsReview.length}');
  if (missingTargets.isNotEmpty) {
    stdout.writeln('Missing targets: ${missingTargets.join(', ')}');
  }
  stdout.writeln('Wrote: $_outJsonPath');
  stdout.writeln('Wrote: $_outMdPath');
}

String? _resolveOduKey(Map<String, dynamic> oduMap, String target) {
  if (oduMap.containsKey(target)) return target;
  final normalizedTarget = _normalize(target);
  for (final key in oduMap.keys.whereType<String>()) {
    if (_normalize(key) == normalizedTarget) return key;
  }
  return null;
}

_AnchorHit? _findAnchor(String nace) {
  for (final spec in _anchorSpecs) {
    final match = RegExp(
      spec.regex,
      caseSensitive: false,
      multiLine: true,
      dotAll: true,
    ).firstMatch(nace);
    if (match != null) {
      return _AnchorHit(spec: spec, start: match.start);
    }
  }
  return null;
}

String _buildStopAlternation({required bool includeEnEsteNaceStop}) {
  if (!includeEnEsteNaceStop) {
    return _strongStopAlternation;
  }
  return '$_strongStopAlternation|$_enEsteNaceStop';
}

String _buildMainRegex({
  required String anchorBody,
  required String stopAlternation,
}) {
  return '^\\s*(?:$anchorBody)\\b[\\s\\S]{0,$_maxCaptureChars}?(?=^\\s*(?:$stopAlternation).*|\$(?![\\s\\S]))';
}

String _buildSplitRegexPart1({required String anchorBody}) {
  return '^\\s*(?:$anchorBody)\\b[\\s\\S]{0,900}?(?=\\n\\s*\\n|\$(?![\\s\\S]))';
}

String _buildSplitRegexPart2({
  required String anchorBody,
  required String stopAlternation,
}) {
  return '^\\s*(?:$anchorBody)\\b[\\s\\S]{0,900}?\\n\\s*\\n[\\s\\S]{0,3600}?(?=^\\s*(?:$stopAlternation).*|\$(?![\\s\\S]))';
}

_ExtractionState _extractSnippet({
  required String nace,
  required int anchorStart,
  required RegExp stopLineRegex,
}) {
  final maxEnd = _min(anchorStart + _maxCaptureChars, nace.length);
  int? stopIndex;
  String? stopLine;

  for (final m in stopLineRegex.allMatches(nace)) {
    if (m.start <= anchorStart) continue;
    stopIndex = m.start;
    stopLine = m.group(0)?.trim();
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

_ContaminationCheck _checkContamination(String snippet, {required int scanChars}) {
  final probe = snippet.length <= scanChars
      ? snippet
      : snippet.substring(0, scanChars);
  final folded = _foldDiacritics(probe).toUpperCase();

  final tokenChecks = <String, RegExp>{
    'ESHU': RegExp(r'\bESHU\b'),
    'EWES': RegExp(r'\bEWES\b'),
    'OBRAS': RegExp(r'\bOBRAS?\b'),
    'DICE IFA': RegExp(r'DICE\s+IFA\b'),
    'REZO': RegExp(r'\bREZO\b'),
    'SUYERE': RegExp(r'\bSUYERE\b'),
    'HISTOR': RegExp(r'HISTOR'),
  };

  final found = <String>[];
  for (final entry in tokenChecks.entries) {
    if (entry.value.hasMatch(folded)) {
      found.add(entry.key);
    }
  }

  return _ContaminationCheck(tokens: found);
}

String _suggestTweak({
  required bool safeToApply,
  required bool stopMarkerFound,
  required bool truncated,
  required bool contamination,
  required int matchCount,
  required int captureLen,
}) {
  if (safeToApply) return 'none';
  if (contamination) {
    return 'Dividir el bloque en 2 regex: primer párrafo (<=900 chars) y resto hasta stop marker.';
  }
  if (!stopMarkerFound) {
    return 'Agregar un stop marker fuerte específico de sección para acotar el final del bloque.';
  }
  if (truncated) {
    return 'Reducir alcance del bloque o introducir stop marker intermedio para evitar truncamiento.';
  }
  if (matchCount != 1) {
    return 'Hacer el anchor inicial más específico para obtener match_count == 1.';
  }
  if (captureLen < 200) {
    return 'Anchor demasiado corto; iniciar desde un marcador descriptivo más estable.';
  }
  return 'Revisar límites del regex de forma manual.';
}

String _asString(dynamic value) {
  if (value == null) return '';
  if (value is String) return value;
  return value.toString();
}

String _normalize(String s) => _foldDiacritics(s).toUpperCase().trim();

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
      .replaceAll('ù', 'u')
      .replaceAll('Ù', 'U')
      .replaceAll('ñ', 'n')
      .replaceAll('Ñ', 'N');
}

int _min(int a, int b) => a < b ? a : b;

class _AnchorSpec {
  const _AnchorSpec({
    required this.key,
    required this.label,
    required this.body,
    required this.regex,
    required this.isEsteOduFamily,
  });

  final String key;
  final String label;
  final String body;
  final String regex;
  final bool isEsteOduFamily;
}

class _AnchorHit {
  const _AnchorHit({
    required this.spec,
    required this.start,
  });

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

class _ContaminationCheck {
  const _ContaminationCheck({required this.tokens});
  final List<String> tokens;
}

class _SplitProposal {
  const _SplitProposal({
    required this.regexPart1,
    required this.regexPart2,
    required this.rationale,
  });

  final String regexPart1;
  final String regexPart2;
  final String rationale;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'regex_part1': regexPart1,
      'regex_part2': regexPart2,
      'rationale': rationale,
    };
  }
}

class _Candidate {
  const _Candidate({
    required this.oduKey,
    required this.anchorUsed,
    required this.regexMoveToDesc,
    required this.regexRemoveFromNace,
    required this.matchCount,
    required this.stopMarkerFound,
    required this.stopMarkerLine,
    required this.truncated,
    required this.contamination,
    required this.contaminationTokens,
    required this.previewCapture,
    required this.captureLen,
    required this.safeToApply,
    required this.reason,
    required this.splitProposal,
    required this.tweak,
  });

  final String oduKey;
  final String anchorUsed;
  final String regexMoveToDesc;
  final String regexRemoveFromNace;
  final int matchCount;
  final bool stopMarkerFound;
  final String? stopMarkerLine;
  final bool truncated;
  final bool contamination;
  final List<String> contaminationTokens;
  final String previewCapture;
  final int captureLen;
  final bool safeToApply;
  final String reason;
  final _SplitProposal? splitProposal;
  final String tweak;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'odu_key': oduKey,
      'anchor_used': anchorUsed,
      'regex_move_to_desc': regexMoveToDesc,
      'regex_remove_from_nace': regexRemoveFromNace,
      'match_count': matchCount,
      'stop_marker_found': stopMarkerFound,
      'stop_marker_line': stopMarkerLine,
      'truncated': truncated,
      'contamination': contamination,
      'contamination_tokens': contaminationTokens,
      'capture_len': captureLen,
      'preview_capture': previewCapture,
      'safe_to_apply': safeToApply,
      'reason': reason,
      'split_proposal': splitProposal?.toJson(),
      'tweak': tweak,
      'patch_ops': <String, dynamic>{
        'nace': <String, dynamic>{
          'move_to_desc_regex': <String>[regexMoveToDesc],
          'remove_from_nace_regex': <String>[regexRemoveFromNace],
        },
        'descripcion': <String, dynamic>{
          'append_from_nace_regex': <String>[regexMoveToDesc],
        },
      },
    };
  }
}
