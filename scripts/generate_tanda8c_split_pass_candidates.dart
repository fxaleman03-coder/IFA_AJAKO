import 'dart:convert';
import 'dart:io';

const String _auditPath = 'build/tanda8_structural_audit.json';
const String _contentPath = 'assets/odu_content_patched.json';
const String _outJsonPath = 'build/tanda8c_v2_signature_candidates.json';
const String _outMdPath = 'build/tanda8c_v2_signature_candidates.md';

const List<String> _targetOdu = <String>[
  'IWORI BOFUN',
  'OJUANI BOFUN',
  'OSHE YEKUN',
];

const int _signatureWindowChars = 300;
const int _captureTailChars = 1200;
const int _minCaptureLen = 180;
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
  final suggestedByOdu = <String, String>{};
  if (auditResultsRaw is List) {
    for (final itemRaw in auditResultsRaw.whereType<Map>()) {
      final item = Map<String, dynamic>.from(itemRaw);
      final key = _asString(item['odu_key']);
      if (key.isEmpty) continue;
      suggestedByOdu[key] = _asString(item['recommended_source_section']);
    }
  }

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

  for (final requestedKey in _targetOdu) {
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
    final suggestedSection =
        suggestedByOdu[oduKey] ?? suggestedByOdu[requestedKey] ?? 'nace';

    final resolved = _resolveSourceAndAnchor(
      content: content,
      suggestedSection: suggestedSection,
    );

    if (resolved == null) {
      candidates.add(
        _Candidate(
          oduKey: oduKey,
          sourceSectionSuggested: suggestedSection,
          sourceSectionResolved: 'none',
          sourceJsonKey: 'none',
          anchorUsed: 'none',
          signature: '',
          signatureEscaped: '',
          regexFinal: '',
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

    final signature = _buildSignature(
      text: resolved.sourceText,
      anchorMatchStart: resolved.anchor.matchStart,
      anchorMatchEnd: resolved.anchor.matchEnd,
    );
    final signatureRegex = _signatureToRegex(signature);
    final signatureEscaped = signatureRegex.length <= 120
        ? signatureRegex
        : signatureRegex.substring(0, 120);

    final regexFinal = _buildFinalRegex(
      anchorBody: resolved.anchor.spec.rawBody,
      signatureRegex: signatureRegex,
    );

    final regex = RegExp(
      regexFinal,
      caseSensitive: false,
      multiLine: true,
      dotAll: true,
    );
    final matches = regex.allMatches(resolved.sourceText).toList();
    final matchCount = matches.length;

    final snippet = _extractSnippetByBoundaries(
      text: resolved.sourceText,
      anchorStart: resolved.anchor.matchStart,
    );
    final captureLen = snippet.length;
    final forbiddenHits = _findForbiddenHits(snippet);

    final safe = matchCount == 1 && captureLen >= _minCaptureLen && forbiddenHits.isEmpty;
    final reasons = <String>[];
    if (matchCount != 1) reasons.add('match_count_$matchCount');
    if (captureLen < _minCaptureLen) reasons.add('capture_too_short:$captureLen');
    if (forbiddenHits.isNotEmpty) {
      reasons.add('forbidden_in_snippet:${forbiddenHits.join('|')}');
    }
    if (reasons.isEmpty) reasons.add('ok');

    final preview = snippet.length <= _previewChars
        ? snippet
        : snippet.substring(0, _previewChars);

    final removeKey = 'regex_remove_from_${resolved.sourceJsonKey}_regex';
    final appendKey = 'append_from_${resolved.sourceJsonKey}_regex';
    final patchOps = <String, dynamic>{
      resolved.sourceJsonKey: <String, dynamic>{
        'move_to_desc_regex': <String>[regexFinal],
        removeKey: <String>[regexFinal],
      },
      'descripcion': <String, dynamic>{
        appendKey: <String>[regexFinal],
      },
    };

    candidates.add(
      _Candidate(
        oduKey: oduKey,
        sourceSectionSuggested: suggestedSection,
        sourceSectionResolved: resolved.sourceSection,
        sourceJsonKey: resolved.sourceJsonKey,
        anchorUsed: resolved.anchor.usedLabel,
        signature: signature,
        signatureEscaped: signatureEscaped,
        regexFinal: regexFinal,
        matchCount: matchCount,
        captureLen: captureLen,
        previewCapture: preview,
        safeToApply: safe,
        reason: reasons.join(', '),
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
      'target_count': _targetOdu.length,
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
    ..writeln('# TANDA 8C V2 Signature Candidates')
    ..writeln()
    ..writeln('- Input audit: `$_auditPath`')
    ..writeln('- Input content: `$_contentPath`')
    ..writeln('- Generated (UTC): `${jsonOut['generated_utc']}`')
    ..writeln()
    ..writeln('## Summary')
    ..writeln('- Targets: `${_targetOdu.join(', ')}`')
    ..writeln('- Candidates: `${candidates.length}`')
    ..writeln('- APPLY_READY: `${applyReady.length}`')
    ..writeln('- NEEDS_REVIEW: `${needsReview.length}`')
    ..writeln('- Unresolved: `${unresolved.length}`')
    ..writeln();

  if (topReasons.isNotEmpty) {
    md.writeln('## NEEDS_REVIEW Reasons');
    for (final item in topReasons.take(10)) {
      md.writeln('- `${item.key}`: `${item.value}`');
    }
    md.writeln();
  }

  _writeGroup(md, 'APPLY_READY', applyReady);
  _writeGroup(md, 'NEEDS_REVIEW', needsReview);

  Directory('build').createSync(recursive: true);
  File(
    _outJsonPath,
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(jsonOut));
  File(_outMdPath).writeAsStringSync(md.toString());

  stdout.writeln('Generated split-pass v2 signature candidates (no patches applied).');
  stdout.writeln('APPLY_READY: ${applyReady.length}');
  stdout.writeln('NEEDS_REVIEW: ${needsReview.length}');
  stdout.writeln('Wrote: $_outJsonPath');
  stdout.writeln('Wrote: $_outMdPath');
}

void _writeGroup(StringBuffer md, String title, List<_Candidate> items) {
  md.writeln('## $title');
  if (items.isEmpty) {
    md.writeln('_No candidates._');
    md.writeln();
    return;
  }
  for (final c in items) {
    md.writeln('### `${c.oduKey}`');
    md.writeln('- source_section: `${c.sourceSectionResolved}`');
    md.writeln('- source_section_suggested: `${c.sourceSectionSuggested}`');
    md.writeln('- anchor_used: `${c.anchorUsed}`');
    md.writeln('- firma: `${c.signature}`');
    md.writeln('- firma_escaped (<=120): `${c.signatureEscaped}`');
    md.writeln('- regex_final:');
    md.writeln('```regex');
    md.writeln(c.regexFinal);
    md.writeln('```');
    md.writeln('- match_count: `${c.matchCount}`');
    md.writeln('- capture_len: `${c.captureLen}`');
    md.writeln('- SAFE_TO_APPLY: `${c.safeToApply}`');
    md.writeln('- reason: `${c.reason}`');
    md.writeln('- preview_capture (first 800 chars):');
    md.writeln('```text');
    md.writeln(c.previewCapture);
    md.writeln('```');
    md.writeln();
  }
}

_ResolvedSource? _resolveSourceAndAnchor({
  required Map<String, dynamic> content,
  required String suggestedSection,
}) {
  final ordered = <String>[];
  if (suggestedSection.isNotEmpty) ordered.add(suggestedSection);
  for (final s in <String>['nace', 'eshu', 'obras', 'diceIfa']) {
    if (!ordered.contains(s)) ordered.add(s);
  }

  for (final section in ordered) {
    final jsonKey = _resolveJsonKey(section, content);
    if (jsonKey == null) continue;
    final raw = _asString(content[jsonKey]);
    if (raw.trim().isEmpty || raw.trim() == '-') continue;
    final anchor = _findAnchorTiered(raw);
    if (anchor != null) {
      return _ResolvedSource(
        sourceSection: section,
        sourceJsonKey: jsonKey,
        sourceText: raw,
        anchor: anchor,
      );
    }
  }
  return null;
}

String? _resolveJsonKey(String section, Map<String, dynamic> content) {
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
  // Tier 1 exact-ish regex on raw lines
  for (final spec in _anchors) {
    final regex = RegExp(
      spec.tier1Pattern,
      caseSensitive: false,
      multiLine: true,
      dotAll: true,
    );
    final m = regex.firstMatch(raw);
    if (m != null) {
      return _AnchorHit(
        spec: spec,
        matchStart: m.start,
        matchEnd: m.end,
        usedLabel: 'tier1:${spec.label}',
      );
    }
  }

  // Tier 2 folded-contains + tolerant raw confirmation
  final folded = fold(raw);
  for (final spec in _anchors) {
    final containsPhrase = spec.foldPhrases.any(folded.contains);
    if (!containsPhrase) continue;
    final tolerant = RegExp(
      '^\\s*(?:${spec.rawBody})\\b',
      caseSensitive: false,
      multiLine: true,
      dotAll: true,
    );
    final m = tolerant.firstMatch(raw);
    if (m != null) {
      return _AnchorHit(
        spec: spec,
        matchStart: m.start,
        matchEnd: m.end,
        usedLabel: 'tier2:${spec.label}',
      );
    }
  }
  return null;
}

String fold(String s) {
  final lowered = s.toLowerCase();
  final noDia = _removeDiacritics(lowered);
  return noDia.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _buildSignature({
  required String text,
  required int anchorMatchStart,
  required int anchorMatchEnd,
}) {
  final lines = <String>[];

  // Remainder in anchor line first
  final anchorLineEnd = _lineEnd(text, anchorMatchStart);
  final remainder = text.substring(
    anchorMatchEnd,
    anchorLineEnd == -1 ? text.length : anchorLineEnd,
  );
  final remClean = _normalizeSpaces(remainder);
  if (remClean.isNotEmpty) lines.add(remClean);

  // Next non-empty lines
  final startNext = anchorLineEnd == -1 ? text.length : anchorLineEnd + 1;
  final tail = startNext < text.length ? text.substring(startNext) : '';
  for (final rawLine in tail.split('\n')) {
    final clean = _normalizeSpaces(rawLine);
    if (clean.isEmpty) continue;
    lines.add(clean);
    if (lines.length >= 4) break;
  }

  String signature = '';
  if (lines.isNotEmpty) {
    signature = lines.first;
  }
  if (signature.length < 18 || _isGenericSignature(signature)) {
    if (lines.length >= 2) {
      signature = _normalizeSpaces('${lines[0]} ${lines[1]}');
    }
  }
  if (signature.length < 18 || _isGenericSignature(signature)) {
    final phrase = _extractDistinctPhrase(text, anchorMatchStart, 220);
    if (phrase.isNotEmpty) {
      signature = signature.isEmpty ? phrase : _normalizeSpaces('$signature $phrase');
    }
  }
  if (signature.length > 220) {
    signature = signature.substring(0, 220).trim();
  }
  return signature;
}

bool _isGenericSignature(String s) {
  final f = fold(s);
  if (f.isEmpty) return true;
  const genericBits = <String>[
    'este odu',
    'este es el odu',
    'este ifa',
    'este signo',
    'descripcion del odu',
    'descripcion del odo',
  ];
  return genericBits.any((g) => f == g || f.startsWith('$g '));
}

String _extractDistinctPhrase(String text, int from, int maxChars) {
  final end = _min(text.length, from + maxChars);
  if (from >= end) return '';
  final window = text.substring(from, end);
  final cleaned = _normalizeSpaces(window);
  if (cleaned.isEmpty) return '';
  final sentenceParts = cleaned.split(RegExp(r'(?<=[\.\!\?;:])\s+'));
  for (final part in sentenceParts) {
    final p = _normalizeSpaces(part);
    if (p.length >= 24 && !_isGenericSignature(p)) {
      return p.length > 140 ? p.substring(0, 140).trim() : p;
    }
  }
  return cleaned.length > 120 ? cleaned.substring(0, 120).trim() : cleaned;
}

String _signatureToRegex(String signature) {
  final normalized = _normalizeSpaces(signature);
  if (normalized.isEmpty) return '';
  final tokens = normalized.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  if (tokens.isEmpty) return '';
  return tokens.map(RegExp.escape).join(r'\s+');
}

String _buildFinalRegex({
  required String anchorBody,
  required String signatureRegex,
}) {
  final sigPart = signatureRegex.isEmpty ? '' : '(?:$signatureRegex)';
  return '^\\s*(?:$anchorBody)\\b[\\s\\S]{0,$_signatureWindowChars}?$sigPart[\\s\\S]{0,$_captureTailChars}';
}

String _extractSnippetByBoundaries({
  required String text,
  required int anchorStart,
}) {
  final hardEnd = _min(text.length, anchorStart + _captureTailChars);
  var end = hardEnd;

  final window = text.substring(anchorStart, hardEnd);

  final doubleNl = RegExp(r'\n\s*\n', dotAll: true).firstMatch(window);
  if (doubleNl != null) {
    end = _min(end, anchorStart + doubleNl.start);
  }

  final forbiddenLine = RegExp(
    '^\\s*(?:$_forbiddenHeaderAlternation)\\b.*\$',
    caseSensitive: false,
    multiLine: true,
    dotAll: true,
  );
  for (final m in forbiddenLine.allMatches(text)) {
    if (m.start <= anchorStart) continue;
    if (m.start > hardEnd) break;
    end = _min(end, m.start);
    break;
  }

  if (end < anchorStart) return '';
  return text.substring(anchorStart, end).trim();
}

List<String> _findForbiddenHits(String snippet) {
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

String _normalizeSpaces(String value) {
  return value
      .replaceAll('\u00A0', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

int _lineEnd(String text, int index) => text.indexOf('\n', index);

String _asString(dynamic v) {
  if (v == null) return '';
  if (v is String) return v;
  return v.toString();
}

String? _resolveOduKey(Map<String, dynamic> oduMap, String requested) {
  if (oduMap.containsKey(requested)) return requested;
  final reqFold = fold(requested);
  for (final key in oduMap.keys.whereType<String>()) {
    if (fold(key) == reqFold) return key;
  }
  return null;
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
    required this.matchStart,
    required this.matchEnd,
    required this.usedLabel,
  });

  final _AnchorSpec spec;
  final int matchStart;
  final int matchEnd;
  final String usedLabel;
}

class _ResolvedSource {
  const _ResolvedSource({
    required this.sourceSection,
    required this.sourceJsonKey,
    required this.sourceText,
    required this.anchor,
  });

  final String sourceSection;
  final String sourceJsonKey;
  final String sourceText;
  final _AnchorHit anchor;
}

class _Candidate {
  const _Candidate({
    required this.oduKey,
    required this.sourceSectionSuggested,
    required this.sourceSectionResolved,
    required this.sourceJsonKey,
    required this.anchorUsed,
    required this.signature,
    required this.signatureEscaped,
    required this.regexFinal,
    required this.matchCount,
    required this.captureLen,
    required this.previewCapture,
    required this.safeToApply,
    required this.reason,
    required this.patchOps,
  });

  final String oduKey;
  final String sourceSectionSuggested;
  final String sourceSectionResolved;
  final String sourceJsonKey;
  final String anchorUsed;
  final String signature;
  final String signatureEscaped;
  final String regexFinal;
  final int matchCount;
  final int captureLen;
  final String previewCapture;
  final bool safeToApply;
  final String reason;
  final Map<String, dynamic> patchOps;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'odu_key': oduKey,
      'source_section_suggested': sourceSectionSuggested,
      'source_section_resolved': sourceSectionResolved,
      'source_json_key': sourceJsonKey,
      'anchor_used': anchorUsed,
      'signature': signature,
      'signature_escaped': signatureEscaped,
      'regex_final': regexFinal,
      'regex_move_to_desc': regexFinal,
      'regex_remove_from_source': regexFinal,
      'regex_append_to_descripcion': regexFinal,
      'match_count': matchCount,
      'capture_len': captureLen,
      'preview_capture': previewCapture,
      'safe_to_apply': safeToApply,
      'reason': reason,
      'patch_ops': patchOps,
    };
  }
}
