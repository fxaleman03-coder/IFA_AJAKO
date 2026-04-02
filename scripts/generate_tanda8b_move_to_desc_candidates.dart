import 'dart:convert';
import 'dart:io';

const String _auditPath = 'build/tanda8_structural_audit.json';
const String _contentPath = 'assets/odu_content_patched.json';
const String _outJsonPath = 'build/tanda8c_split_pass_candidates.json';
const String _outMdPath = 'build/tanda8c_split_pass_candidates.md';

const int _maxAuditItems = 20;
const int _maxCaptureChars = 900;
const int _minCaptureChars = 180;
const int _previewChars = 800;

const String _forbiddenHeaderAlternation =
    r'ESHU|EWES|OBRAS|DICE\s+IF[ÁA]|DICE\s+IFA|REZO|SUYERE|PAT(?:A|Á)K(?:I|Í)E|HISTORIAS?';

const List<_AnchorSpec> _anchors = <_AnchorSpec>[
  _AnchorSpec(
    label: 'DESCRIPCIÓN DEL OD(O/U/Ù)',
    tier1Pattern: r'^\s*DESCRIPCI(?:Ó|O)N\s+DEL\s+OD(?:Ù|U|O)\b',
    rawBody: r'(?:D?ESCRIPCI(?:Ó|O)N?)\s+DEL\s+OD(?:Ù|U|O)',
    foldPhrases: <String>[
      'descripcion del odu',
      'descripcion del odo',
      'escripcion del odu',
      'escripcion del odo',
    ],
  ),
  _AnchorSpec(
    label: 'ESTE ES EL ODU',
    tier1Pattern: r'^\s*ESTE\s+ES\s+EL\s+OD(?:Ù|U|O)\b',
    rawBody: r'ESTE\s+ES\s+EL\s+OD(?:Ù|U|O)',
    foldPhrases: <String>['este es el odu', 'este es el odo'],
  ),
  _AnchorSpec(
    label: 'ESTE ODU',
    tier1Pattern: r'^\s*ESTE\s+OD(?:Ù|U|O)\b',
    rawBody: r'ESTE\s+OD(?:Ù|U|O)',
    foldPhrases: <String>['este odu', 'este odo'],
  ),
  _AnchorSpec(
    label: 'ESTE IFÁ / ESTE IFA',
    tier1Pattern: r'^\s*ESTE\s+IF[ÁA]\b|^\s*ESTE\s+IFA\b',
    rawBody: r'ESTE\s+IF[ÁA]|ESTE\s+IFA',
    foldPhrases: <String>['este ifa'],
  ),
  _AnchorSpec(
    label: 'ESTE SIGNO',
    tier1Pattern: r'^\s*ESTE\s+SIGNO\b',
    rawBody: r'ESTE\s+SIGNO',
    foldPhrases: <String>['este signo'],
  ),
];

void main() {
  final auditFile = File(_auditPath);
  final contentFile = File(_contentPath);
  if (!auditFile.existsSync()) {
    stderr.writeln('Missing input: $_auditPath');
    exitCode = 1;
    return;
  }
  if (!contentFile.existsSync()) {
    stderr.writeln('Missing input: $_contentPath');
    exitCode = 1;
    return;
  }

  final auditDecoded = jsonDecode(auditFile.readAsStringSync());
  final contentDecoded = jsonDecode(contentFile.readAsStringSync());
  if (auditDecoded is! Map || contentDecoded is! Map) {
    stderr.writeln('Invalid JSON in audit/content input.');
    exitCode = 1;
    return;
  }

  final auditRoot = Map<String, dynamic>.from(auditDecoded);
  final auditResultsRaw = auditRoot['results'];
  if (auditResultsRaw is! List) {
    stderr.writeln('Invalid audit JSON: missing results list.');
    exitCode = 1;
    return;
  }
  final selectedAudit = auditResultsRaw
      .whereType<Map>()
      .map((m) => Map<String, dynamic>.from(m))
      .take(_maxAuditItems)
      .toList();

  final contentRoot = Map<String, dynamic>.from(contentDecoded);
  final oduRaw = contentRoot['odu'];
  if (oduRaw is! Map) {
    stderr.writeln('Invalid content JSON: missing odu object.');
    exitCode = 1;
    return;
  }
  final oduMap = Map<String, dynamic>.from(oduRaw);

  final candidates = <_Candidate>[];
  final unresolved = <String>[];

  for (final row in selectedAudit) {
    final requestedKey = _asString(row['odu_key']);
    final confidence = _asString(row['confidence']);
    final sourceSuggested = _asString(row['recommended_source_section']);
    if (requestedKey.isEmpty) continue;

    final oduKey = _resolveOduKey(oduMap, requestedKey);
    if (oduKey == null) {
      unresolved.add(requestedKey);
      continue;
    }

    final nodeRaw = oduMap[oduKey];
    if (nodeRaw is! Map) {
      unresolved.add(oduKey);
      continue;
    }
    final node = Map<String, dynamic>.from(nodeRaw);
    final contentRaw = node['content'];
    if (contentRaw is! Map) {
      unresolved.add(oduKey);
      continue;
    }
    final content = Map<String, dynamic>.from(contentRaw);

    final sourceChoice = _resolveSourceWithFallback(
      content: content,
      suggestedSection: sourceSuggested,
    );
    if (sourceChoice == null) {
      candidates.add(
        _Candidate(
          oduKey: oduKey,
          confidence: confidence,
          sourceSectionSuggested: sourceSuggested,
          sourceSectionResolved: 'none',
          sourceJsonKey: 'none',
          anchorUsed: 'none',
          regexMoveToDesc: '',
          matchCount: 0,
          captureLen: 0,
          previewCapture: '',
          safeToApply: false,
          reason: 'source_or_anchor_not_found',
          patchOps: const <String, dynamic>{},
        ),
      );
      continue;
    }

    final extraction = _extractFirstCleanDescriptiveBlock(
      text: sourceChoice.text,
      anchorStart: sourceChoice.anchor.start,
    );
    final snippet = extraction.snippet.trim();
    final captureLen = snippet.length;
    final forbiddenHits = _findForbiddenTokens(snippet);

    final signature = _buildSignature(snippet, sourceChoice.anchor.spec.rawBody);
    final regexMoveToDesc = _buildBoundedRegexForMatch(
      anchorRawBody: sourceChoice.anchor.spec.rawBody,
      signature: signature,
    );
    final regex = RegExp(
      regexMoveToDesc,
      caseSensitive: false,
      multiLine: true,
      dotAll: true,
    );
    final matchCount = regex.allMatches(sourceChoice.text).length;

    final safe = matchCount == 1 && captureLen >= _minCaptureChars && forbiddenHits.isEmpty;
    final reasonParts = <String>[];
    if (matchCount != 1) reasonParts.add('match_count_$matchCount');
    if (captureLen < _minCaptureChars) {
      reasonParts.add('capture_too_short:$captureLen');
    }
    if (forbiddenHits.isNotEmpty) {
      reasonParts.add('forbidden_in_snippet:${forbiddenHits.join('|')}');
    }
    if (reasonParts.isEmpty) reasonParts.add('ok');

    final preview = snippet.length <= _previewChars
        ? snippet
        : snippet.substring(0, _previewChars);

    final removeKey = 'regex_remove_from_${sourceChoice.sourceJsonKey}_regex';
    final appendKey = 'append_from_${sourceChoice.sourceJsonKey}_regex';
    final patchOps = <String, dynamic>{
      sourceChoice.sourceJsonKey: <String, dynamic>{
        'move_to_desc_regex': <String>[regexMoveToDesc],
        removeKey: <String>[regexMoveToDesc],
      },
      'descripcion': <String, dynamic>{
        appendKey: <String>[regexMoveToDesc],
      },
    };

    candidates.add(
      _Candidate(
        oduKey: oduKey,
        confidence: confidence,
        sourceSectionSuggested: sourceSuggested,
        sourceSectionResolved: sourceChoice.sourceSection,
        sourceJsonKey: sourceChoice.sourceJsonKey,
        anchorUsed: sourceChoice.anchor.usedLabel,
        regexMoveToDesc: regexMoveToDesc,
        matchCount: matchCount,
        captureLen: captureLen,
        previewCapture: preview,
        safeToApply: safe,
        reason: reasonParts.join(', '),
        patchOps: patchOps,
      ),
    );
  }

  final applyReady = candidates.where((c) => c.safeToApply).toList();
  final needsReview = candidates.where((c) => !c.safeToApply).toList();

  final reasonCounts = <String, int>{};
  for (final c in needsReview) {
    for (final reason in c.reason.split(',').map((s) => s.trim())) {
      if (reason.isEmpty) continue;
      reasonCounts[reason] = (reasonCounts[reason] ?? 0) + 1;
    }
  }
  final topReasons = reasonCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final jsonOut = <String, dynamic>{
    'source_files': <String, String>{
      'audit': _auditPath,
      'content': _contentPath,
    },
    'generated_utc': DateTime.now().toUtc().toIso8601String(),
    'summary': <String, dynamic>{
      'audit_selected_count': selectedAudit.length,
      'candidate_count': candidates.length,
      'apply_ready_count': applyReady.length,
      'needs_review_count': needsReview.length,
      'unresolved_count': unresolved.length,
    },
    'apply_ready_keys': applyReady.map((c) => c.oduKey).toList(),
    'needs_review_top_reasons': topReasons
        .take(10)
        .map((e) => <String, dynamic>{'reason': e.key, 'count': e.value})
        .toList(),
    'unresolved': unresolved,
    'groups': <String, dynamic>{
      'APPLY_READY': applyReady.map((c) => c.toJson()).toList(),
      'NEEDS_REVIEW': needsReview.map((c) => c.toJson()).toList(),
    },
    'candidates': candidates.map((c) => c.toJson()).toList(),
  };

  final md = StringBuffer()
    ..writeln('# TANDA 8C Split Pass Candidates')
    ..writeln()
    ..writeln('- Input audit: `$_auditPath`')
    ..writeln('- Input content: `$_contentPath`')
    ..writeln('- Generated (UTC): `${jsonOut['generated_utc']}`')
    ..writeln()
    ..writeln('## Summary')
    ..writeln('- Audit selected: `${selectedAudit.length}`')
    ..writeln('- Candidates: `${candidates.length}`')
    ..writeln('- APPLY_READY: `${applyReady.length}`')
    ..writeln('- NEEDS_REVIEW: `${needsReview.length}`')
    ..writeln('- Unresolved: `${unresolved.length}`')
    ..writeln();

  if (topReasons.isNotEmpty) {
    md.writeln('## NEEDS_REVIEW Top Reasons');
    for (final entry in topReasons.take(10)) {
      md.writeln('- `${entry.key}`: `${entry.value}`');
    }
    md.writeln();
  }

  if (unresolved.isNotEmpty) {
    md.writeln('## Unresolved');
    for (final key in unresolved) {
      md.writeln('- `$key`');
    }
    md.writeln();
  }

  _writeGroupMd(md, 'APPLY_READY', applyReady);
  _writeGroupMd(md, 'NEEDS_REVIEW', needsReview);

  Directory('build').createSync(recursive: true);
  File(
    _outJsonPath,
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(jsonOut));
  File(_outMdPath).writeAsStringSync(md.toString());

  stdout.writeln('Generated split-pass candidates (no patches applied).');
  stdout.writeln('APPLY_READY: ${applyReady.length}');
  stdout.writeln('NEEDS_REVIEW: ${needsReview.length}');
  stdout.writeln('Wrote: $_outJsonPath');
  stdout.writeln('Wrote: $_outMdPath');
}

void _writeGroupMd(StringBuffer md, String title, List<_Candidate> items) {
  md.writeln('## $title');
  if (items.isEmpty) {
    md.writeln('_No candidates._');
    md.writeln();
    return;
  }

  for (final c in items) {
    md.writeln('### `${c.oduKey}`');
    md.writeln('- confidence: `${c.confidence}`');
    md.writeln('- source_section_suggested: `${c.sourceSectionSuggested}`');
    md.writeln('- source_section_resolved: `${c.sourceSectionResolved}`');
    md.writeln('- source_json_key: `${c.sourceJsonKey}`');
    md.writeln('- anchor_used: `${c.anchorUsed}`');
    md.writeln('- match_count: `${c.matchCount}`');
    md.writeln('- capture_len: `${c.captureLen}`');
    md.writeln('- SAFE_TO_APPLY: `${c.safeToApply}`');
    md.writeln('- reason: `${c.reason}`');
    md.writeln('- regex_move_to_desc:');
    md.writeln('```regex');
    md.writeln(c.regexMoveToDesc);
    md.writeln('```');
    md.writeln('- regex_remove_from_source:');
    md.writeln('```regex');
    md.writeln(c.regexMoveToDesc);
    md.writeln('```');
    md.writeln('- patch ops (output only):');
    md.writeln('```json');
    md.writeln(const JsonEncoder.withIndent('  ').convert(c.patchOps));
    md.writeln('```');
    md.writeln('- preview_capture (first 800 chars):');
    md.writeln('```text');
    md.writeln(c.previewCapture);
    md.writeln('```');
    md.writeln();
  }
}

_SourceChoice? _resolveSourceWithFallback({
  required Map<String, dynamic> content,
  required String suggestedSection,
}) {
  final order = <String>[];
  if (suggestedSection.isNotEmpty) order.add(suggestedSection);
  for (final s in <String>['nace', 'eshu', 'obras', 'diceIfa']) {
    if (!order.contains(s)) order.add(s);
  }

  for (final section in order) {
    final jsonKey = _resolveSourceJsonKey(section, content);
    if (jsonKey == null) continue;
    final raw = _asString(content[jsonKey]);
    if (raw.trim().isEmpty || raw.trim() == '-') continue;
    final anchor = _findAnchorTiered(raw);
    if (anchor != null) {
      return _SourceChoice(
        sourceSection: section,
        sourceJsonKey: jsonKey,
        text: raw,
        anchor: anchor,
      );
    }
  }
  return null;
}

String? _resolveSourceJsonKey(String section, Map<String, dynamic> content) {
  if (section == 'nace') return content.containsKey('nace') ? 'nace' : null;
  if (section == 'eshu') return content.containsKey('eshu') ? 'eshu' : null;
  if (section == 'obras') {
    for (final key in <String>['obras', 'obrasYEbbo', 'obras_ebbo']) {
      if (content.containsKey(key)) return key;
    }
    return null;
  }
  if (section == 'diceIfa') {
    for (final key in <String>['diceIfa', 'diceifa', 'dice_ifa', 'diceIfaYoruba']) {
      if (content.containsKey(key)) return key;
    }
    return null;
  }
  return null;
}

_AnchorHit? _findAnchorTiered(String raw) {
  // Tier 1: strict raw regex
  for (final spec in _anchors) {
    final regex = RegExp(
      spec.tier1Pattern,
      caseSensitive: false,
      multiLine: true,
      dotAll: true,
    );
    final match = regex.firstMatch(raw);
    if (match != null) {
      return _AnchorHit(
        spec: spec,
        start: match.start,
        usedLabel: 'tier1:${spec.label}',
      );
    }
  }

  // Tier 2: folded contains + tolerant raw confirmation
  final folded = fold(raw);
  for (final spec in _anchors) {
    final hasPhrase = spec.foldPhrases.any(folded.contains);
    if (!hasPhrase) continue;
    final tolerant = RegExp(
      '^\\s*(?:${spec.rawBody})\\b',
      caseSensitive: false,
      multiLine: true,
      dotAll: true,
    );
    final match = tolerant.firstMatch(raw);
    if (match != null) {
      return _AnchorHit(
        spec: spec,
        start: match.start,
        usedLabel: 'tier2:${spec.label}',
      );
    }
  }
  return null;
}

String fold(String input) {
  final lower = input.toLowerCase();
  final without = _removeDiacritics(lower);
  return without.replaceAll(RegExp(r'\s+'), ' ').trim();
}

_Extraction _extractFirstCleanDescriptiveBlock({
  required String text,
  required int anchorStart,
}) {
  final hardEnd = _min(anchorStart + _maxCaptureChars, text.length);
  var end = hardEnd;

  final window = text.substring(anchorStart, hardEnd);

  final doubleNl = RegExp(r'\n\s*\n', dotAll: true).firstMatch(window);
  if (doubleNl != null) {
    end = _min(end, anchorStart + doubleNl.start);
  }

  final forbiddenHeaderRegex = RegExp(
    '^\\s*(?:$_forbiddenHeaderAlternation)\\b.*\$',
    caseSensitive: false,
    multiLine: true,
    dotAll: true,
  );
  for (final m in forbiddenHeaderRegex.allMatches(text)) {
    if (m.start <= anchorStart) continue;
    if (m.start > hardEnd) break;
    end = _min(end, m.start);
    break;
  }

  // If forbidden tokens appear anywhere in current snippet window, cut before that line.
  final tokenRegex = RegExp(
    r'(?:ESHU|EWES|OBRAS|DICE\s+IF[ÁA]|DICE\s+IFA|REZO|SUYERE|PAT(?:A|Á)K(?:I|Í)E|HISTORIAS?|PATAKI|PATÁKI)\b',
    caseSensitive: false,
    multiLine: true,
    dotAll: true,
  );
  for (final m in tokenRegex.allMatches(text)) {
    if (m.start <= anchorStart) continue;
    if (m.start > end) break;
    final lineStart = _lineStart(text, m.start);
    if (lineStart > anchorStart) {
      end = _min(end, lineStart);
      break;
    }
  }

  if (end < anchorStart) end = anchorStart;
  return _Extraction(snippet: text.substring(anchorStart, end).trimRight());
}

int _lineStart(String text, int index) {
  var i = index;
  while (i > 0 && text.codeUnitAt(i - 1) != 10) {
    i--;
  }
  return i;
}

String _buildSignature(String snippet, String anchorBody) {
  if (snippet.isEmpty) return '';
  var norm = snippet.replaceAll('\r', '');
  final anchorStartRegex = RegExp(
    '^\\s*(?:$anchorBody)\\b\\s*',
    caseSensitive: false,
    multiLine: false,
    dotAll: true,
  );
  norm = norm.replaceFirst(anchorStartRegex, '');
  norm = norm.trimLeft();
  if (norm.isEmpty) return '';
  final take = _min(120, norm.length);
  return norm.substring(0, take);
}

String _buildBoundedRegexForMatch({
  required String anchorRawBody,
  required String signature,
}) {
  final signatureLookahead = signature.isEmpty
      ? ''
      : '(?=[\\s\\S]{0,260}${RegExp.escape(signature)})';
  return '^\\s*(?:$anchorRawBody)\\b$signatureLookahead[\\s\\S]{0,$_maxCaptureChars}';
}

List<String> _findForbiddenTokens(String snippet) {
  final folded = _removeDiacritics(snippet).toUpperCase();
  final checks = <String, RegExp>{
    'ESHU': RegExp(r'\bESHU\b'),
    'EWES': RegExp(r'\bEWES\b'),
    'OBRAS': RegExp(r'\bOBRAS?\b'),
    'DICE IFA': RegExp(r'DICE\s+IFA\b'),
    'REZO': RegExp(r'\bREZO\b'),
    'SUYERE': RegExp(r'\bSUYERE\b'),
    'PATAKI': RegExp(r'PATAKI|PATAK'),
    'HISTORIA': RegExp(r'HISTORIA|HISTORIAS'),
  };
  final hits = <String>[];
  for (final e in checks.entries) {
    if (e.value.hasMatch(folded)) hits.add(e.key);
  }
  return hits;
}

String _removeDiacritics(String s) {
  return s
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('à', 'a')
      .replaceAll('è', 'e')
      .replaceAll('ì', 'i')
      .replaceAll('ò', 'o')
      .replaceAll('ù', 'u')
      .replaceAll('ä', 'a')
      .replaceAll('ë', 'e')
      .replaceAll('ï', 'i')
      .replaceAll('ö', 'o')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll('Á', 'A')
      .replaceAll('É', 'E')
      .replaceAll('Í', 'I')
      .replaceAll('Ó', 'O')
      .replaceAll('Ú', 'U')
      .replaceAll('À', 'A')
      .replaceAll('È', 'E')
      .replaceAll('Ì', 'I')
      .replaceAll('Ò', 'O')
      .replaceAll('Ù', 'U')
      .replaceAll('Ä', 'A')
      .replaceAll('Ë', 'E')
      .replaceAll('Ï', 'I')
      .replaceAll('Ö', 'O')
      .replaceAll('Ü', 'U')
      .replaceAll('Ñ', 'N');
}

String _asString(dynamic value) {
  if (value == null) return '';
  if (value is String) return value;
  return value.toString();
}

String? _resolveOduKey(Map<String, dynamic> oduMap, String requested) {
  if (oduMap.containsKey(requested)) return requested;
  final reqFold = fold(requested);
  for (final key in oduMap.keys.whereType<String>()) {
    if (fold(key) == reqFold) return key;
  }
  return null;
}

int _min(int a, int b) => a < b ? a : b;

class _AnchorSpec {
  const _AnchorSpec({
    required this.label,
    required this.tier1Pattern,
    required this.rawBody,
    required this.foldPhrases,
  });

  final String label;
  final String tier1Pattern;
  final String rawBody;
  final List<String> foldPhrases;
}

class _AnchorHit {
  const _AnchorHit({
    required this.spec,
    required this.start,
    required this.usedLabel,
  });

  final _AnchorSpec spec;
  final int start;
  final String usedLabel;
}

class _SourceChoice {
  const _SourceChoice({
    required this.sourceSection,
    required this.sourceJsonKey,
    required this.text,
    required this.anchor,
  });

  final String sourceSection;
  final String sourceJsonKey;
  final String text;
  final _AnchorHit anchor;
}

class _Extraction {
  const _Extraction({required this.snippet});
  final String snippet;
}

class _Candidate {
  const _Candidate({
    required this.oduKey,
    required this.confidence,
    required this.sourceSectionSuggested,
    required this.sourceSectionResolved,
    required this.sourceJsonKey,
    required this.anchorUsed,
    required this.regexMoveToDesc,
    required this.matchCount,
    required this.captureLen,
    required this.previewCapture,
    required this.safeToApply,
    required this.reason,
    required this.patchOps,
  });

  final String oduKey;
  final String confidence;
  final String sourceSectionSuggested;
  final String sourceSectionResolved;
  final String sourceJsonKey;
  final String anchorUsed;
  final String regexMoveToDesc;
  final int matchCount;
  final int captureLen;
  final String previewCapture;
  final bool safeToApply;
  final String reason;
  final Map<String, dynamic> patchOps;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'odu_key': oduKey,
      'confidence': confidence,
      'source_section_suggested': sourceSectionSuggested,
      'source_section_resolved': sourceSectionResolved,
      'source_json_key': sourceJsonKey,
      'anchor_used': anchorUsed,
      'regex_move_to_desc': regexMoveToDesc,
      'regex_remove_from_source': regexMoveToDesc,
      'regex_append_to_descripcion': regexMoveToDesc,
      'match_count': matchCount,
      'capture_len': captureLen,
      'preview_capture': previewCapture,
      'safe_to_apply': safeToApply,
      'reason': reason,
      'patch_ops': patchOps,
    };
  }
}
