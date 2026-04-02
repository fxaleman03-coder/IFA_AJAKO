import 'dart:convert';
import 'dart:io';

const String _auditPath = 'build/tanda8_structural_audit.json';
const String _contentPath = 'assets/odu_content_patched.json';
const String _outJsonPath = 'build/tanda8c_v3_candidates.json';
const String _outMdPath = 'build/tanda8c_v3_candidates.md';

const List<String> _targetOdu = <String>[
  'OJUANI BOFUN',
  'OSHE YEKUN',
];

const int _maxCaptureChars = 4500;
const int _previewChars = 800;

const String _stopAlternation =
    r'ESHU(?:\b|[\s:\-–—])|EWES\b|OBRAS\b|DICE\s+IF[ÁA]\b|DICE\s+IFA\b|REZO\b|SUYERE\b|PAT(?:A|Á)K(?:I|Í)E|HISTORIAS?\b|EN\s+ESTE\s+OD(?:U|O|Ù)\b';

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

const List<_AnchorSpec> _anchors = <_AnchorSpec>[
  _AnchorSpec(
    label: 'DESCRIPCIÓN DEL OD(U/O/Ù)',
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
    label: 'ESTE ES EL OD(U/O/Ù)',
    tier1Pattern: r'^\s*ESTE\s+ES\s+EL\s+OD(?:Ù|U|O)\b',
    rawBody: r'ESTE\s+ES\s+EL\s+OD(?:Ù|U|O)',
    foldPhrases: <String>['este es el odu', 'este es el odo'],
  ),
  _AnchorSpec(
    label: 'ESTE OD(U/O/Ù)',
    tier1Pattern: r'^\s*ESTE\s+OD(?:Ù|U|O)\b',
    rawBody: r'ESTE\s+OD(?:Ù|U|O)',
    foldPhrases: <String>['este odu', 'este odo'],
  ),
  _AnchorSpec(
    label: 'ESTE IFÁ/IFA',
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
    stderr.writeln('Invalid JSON in audit/content.');
    exitCode = 1;
    return;
  }

  final auditRoot = Map<String, dynamic>.from(auditDecoded);
  final auditResultsRaw = auditRoot['results'];
  final suggestedByOdu = <String, String>{};
  if (auditResultsRaw is List) {
    for (final rowRaw in auditResultsRaw.whereType<Map>()) {
      final row = Map<String, dynamic>.from(rowRaw);
      final key = _asString(row['odu_key']);
      if (key.isEmpty) continue;
      suggestedByOdu[key] = _asString(row['recommended_source_section']);
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

  for (final requested in _targetOdu) {
    final oduKey = _resolveOduKey(oduMap, requested);
    if (oduKey == null) {
      unresolved.add(requested);
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

    final suggested = suggestedByOdu[oduKey] ?? 'nace';
    final resolved = _resolveSourceSection(content, suggested);
    if (resolved == null) {
      candidates.add(
        _Candidate(
          oduKey: oduKey,
          sourceSection: 'nace',
          sourceJsonKey: 'nace',
          anchorUsed: 'none',
          regexMoveToDesc: '',
          matchCount: 0,
          stopMarkerFound: false,
          stopMarker: null,
          truncated: true,
          captureLen: 0,
          previewCapture: '',
          safeToApply: false,
          reason: 'source_or_anchor_not_found',
        ),
      );
      continue;
    }

    final extraction = _extractWithStop(
      text: resolved.sourceText,
      anchorStart: resolved.anchor.matchStart,
    );
    final snippet = extraction.snippet;
    final captureLen = snippet.length;

    final anchorLine = _extractLineAt(resolved.sourceText, resolved.anchor.matchStart);
    final signature = _buildSignatureAfterAnchor(
      text: resolved.sourceText,
      anchorMatchEnd: resolved.anchor.matchEnd,
      anchorLine: anchorLine,
    );
    final signatureRegex = _toWhitespaceFlexibleRegex(signature);

    final regexMoveToDesc = _buildFinalRegex(
      anchorLine: anchorLine,
      signatureRegex: signatureRegex,
    );

    final regex = RegExp(
      regexMoveToDesc,
      caseSensitive: false,
      multiLine: true,
      dotAll: true,
    );
    final matchCount = regex.allMatches(resolved.sourceText).length;

    final safe = matchCount == 1 && extraction.stopMarkerFound && !extraction.truncated;
    final reasons = <String>[];
    if (matchCount != 1) reasons.add('match_count_$matchCount');
    if (!extraction.stopMarkerFound) reasons.add('stop_marker_not_found');
    if (extraction.truncated) reasons.add('truncated');
    if (reasons.isEmpty) reasons.add('ok');

    final preview = snippet.length <= _previewChars
        ? snippet
        : snippet.substring(0, _previewChars);

    final sourceKey = resolved.sourceJsonKey;
    final removeKey = 'remove_from_${sourceKey}_regex';
    final appendKey = 'append_from_${sourceKey}_regex';

    final patchOps = <String, dynamic>{
      sourceKey: <String, dynamic>{
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
        sourceSection: resolved.sourceSection,
        sourceJsonKey: sourceKey,
        anchorUsed: resolved.anchor.usedLabel,
        regexMoveToDesc: regexMoveToDesc,
        matchCount: matchCount,
        stopMarkerFound: extraction.stopMarkerFound,
        stopMarker: extraction.stopMarker,
        truncated: extraction.truncated,
        captureLen: captureLen,
        previewCapture: preview.trim(),
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
    ..writeln('# TANDA 8C V3 Candidates')
    ..writeln()
    ..writeln('- Input content: `$_contentPath`')
    ..writeln('- Generated (UTC): `${jsonOut['generated_utc']}`')
    ..writeln('- APPLY_READY: `${applyReady.length}`')
    ..writeln('- NEEDS_REVIEW: `${needsReview.length}`')
    ..writeln()
    ..writeln('## Candidates');

  for (final c in candidates) {
    md.writeln('### `${c.oduKey}`');
    md.writeln('- source_section: `${c.sourceSection}`');
    md.writeln('- source_json_key: `${c.sourceJsonKey}`');
    md.writeln('- anchor_used: `${c.anchorUsed}`');
    md.writeln('- regex_move_to_desc:');
    md.writeln('```regex');
    md.writeln(c.regexMoveToDesc);
    md.writeln('```');
    md.writeln('- match_count: `${c.matchCount}`');
    md.writeln('- stop_marker_found: `${c.stopMarkerFound}`');
    md.writeln('- stop_marker: `${c.stopMarker ?? 'none'}`');
    md.writeln('- truncated: `${c.truncated}`');
    md.writeln('- capture_len: `${c.captureLen}`');
    md.writeln('- SAFE_TO_APPLY: `${c.safeToApply}`');
    md.writeln('- reason: `${c.reason}`');
    md.writeln('- preview_capture (first 800 chars):');
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

  stdout.writeln('Generated TANDA 8C v3 candidates (no patches applied).');
  stdout.writeln('APPLY_READY: ${applyReady.length}');
  stdout.writeln('NEEDS_REVIEW: ${needsReview.length}');
  stdout.writeln('Wrote: $_outJsonPath');
  stdout.writeln('Wrote: $_outMdPath');
}

_ResolvedSource? _resolveSourceSection(
  Map<String, dynamic> content,
  String suggestedSection,
) {
  final order = <String>[];
  if (suggestedSection.isNotEmpty) order.add(suggestedSection);
  for (final s in <String>['nace', 'eshu', 'obras', 'diceIfa']) {
    if (!order.contains(s)) order.add(s);
  }

  for (final section in order) {
    final sourceJsonKey = _resolveSourceJsonKey(section, content);
    if (sourceJsonKey == null) continue;
    final raw = _asString(content[sourceJsonKey]);
    if (raw.trim().isEmpty || raw.trim() == '-') continue;
    final anchor = _findAnchorTiered(raw);
    if (anchor != null) {
      return _ResolvedSource(
        sourceSection: section,
        sourceJsonKey: sourceJsonKey,
        sourceText: raw,
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
  // Tier 1
  for (final spec in _anchors) {
    final re = RegExp(
      spec.tier1Pattern,
      caseSensitive: false,
      multiLine: true,
      dotAll: true,
    );
    final m = re.firstMatch(raw);
    if (m != null) {
      return _AnchorHit(
        spec: spec,
        matchStart: m.start,
        matchEnd: m.end,
        usedLabel: 'tier1:${spec.label}',
      );
    }
  }

  // Tier 2
  final folded = fold(raw);
  for (final spec in _anchors) {
    if (!spec.foldPhrases.any(folded.contains)) continue;
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

_Extraction _extractWithStop({
  required String text,
  required int anchorStart,
}) {
  final hardEnd = _min(text.length, anchorStart + _maxCaptureChars);
  final stopRegex = RegExp(
    '^\\s*(?:$_stopAlternation).*\$',
    caseSensitive: false,
    multiLine: true,
    dotAll: true,
  );

  int? stopIndex;
  String? stopLine;
  for (final m in stopRegex.allMatches(text)) {
    if (m.start <= anchorStart) continue;
    if (m.start > hardEnd) break;
    stopIndex = m.start;
    stopLine = (m.group(0) ?? '').trim();
    break;
  }

  var stopFound = false;
  var truncated = false;
  var end = hardEnd;
  if (stopIndex != null) {
    stopFound = true;
    end = stopIndex;
  } else if (hardEnd >= text.length) {
    stopFound = true;
    stopLine = 'EOF';
    end = text.length;
  } else {
    truncated = true;
  }

  final snippet = text.substring(anchorStart, end).trim();
  return _Extraction(
    snippet: snippet,
    stopMarkerFound: stopFound,
    stopMarker: stopLine,
    truncated: truncated,
  );
}

String _extractLineAt(String text, int index) {
  final start = _lineStart(text, index);
  final endPos = text.indexOf('\n', index);
  final end = endPos == -1 ? text.length : endPos;
  return _normalizeSpaces(text.substring(start, end));
}

String _buildSignatureAfterAnchor({
  required String text,
  required int anchorMatchEnd,
  required String anchorLine,
}) {
  final start = anchorMatchEnd >= text.length ? text.length : anchorMatchEnd;
  final tail = text.substring(start);
  var nonEmpty = tail
      .split('\n')
      .map(_normalizeSpaces)
      .where((l) => l.isNotEmpty)
      .toList();
  if (nonEmpty.isEmpty) return '';
  final anchorFold = fold(anchorLine);
  if (nonEmpty.length > 1 && anchorFold.contains(fold(nonEmpty.first))) {
    nonEmpty = nonEmpty.sublist(1);
  }
  if (nonEmpty.isEmpty) return '';

  var signature = nonEmpty.first;
  if (signature.length < 18 || _isGeneric(signature)) {
    if (nonEmpty.length > 1) {
      signature = _normalizeSpaces('${nonEmpty[0]} ${nonEmpty[1]}');
    }
  }
  if (signature.length > 200) {
    signature = signature.substring(0, 200).trim();
  }
  return signature;
}

bool _isGeneric(String line) {
  final f = fold(line);
  const generic = <String>[
    'este odu',
    'este es el odu',
    'este ifa',
    'este signo',
    'descripcion del odu',
    'descripcion del odo',
  ];
  return generic.any((g) => f == g || f.startsWith('$g '));
}

String _toWhitespaceFlexibleRegex(String text) {
  final normalized = _normalizeSpaces(text);
  if (normalized.isEmpty) return '';
  return normalized.split(RegExp(r'\s+')).map(RegExp.escape).join(r'\s+');
}

String _buildFinalRegex({
  required String anchorLine,
  required String signatureRegex,
}) {
  final escapedAnchorLine = RegExp.escape(anchorLine);
  final sigPart = signatureRegex.isEmpty ? '' : '(?:$signatureRegex)';
  return '^\\s*$escapedAnchorLine(?:\\n[\\s\\S]{0,300}?)?$sigPart[\\s\\S]{0,$_maxCaptureChars}?'
      '(?=^\\s*(?:$_stopAlternation)\\b|(?![\\s\\S]))';
}

String fold(String s) {
  final lowered = s.toLowerCase();
  final noDia = _removeDiacritics(lowered);
  return noDia.replaceAll(RegExp(r'\s+'), ' ').trim();
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

String _normalizeSpaces(String s) =>
    s.replaceAll('\u00A0', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

int _lineStart(String text, int index) {
  var i = index;
  while (i > 0 && text.codeUnitAt(i - 1) != 10) {
    i--;
  }
  return i;
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

class _Extraction {
  const _Extraction({
    required this.snippet,
    required this.stopMarkerFound,
    required this.stopMarker,
    required this.truncated,
  });

  final String snippet;
  final bool stopMarkerFound;
  final String? stopMarker;
  final bool truncated;
}

class _Candidate {
  const _Candidate({
    required this.oduKey,
    required this.sourceSection,
    required this.sourceJsonKey,
    required this.anchorUsed,
    required this.regexMoveToDesc,
    required this.matchCount,
    required this.stopMarkerFound,
    required this.stopMarker,
    required this.truncated,
    required this.captureLen,
    required this.previewCapture,
    required this.safeToApply,
    required this.reason,
    this.patchOps = const <String, dynamic>{},
  });

  final String oduKey;
  final String sourceSection;
  final String sourceJsonKey;
  final String anchorUsed;
  final String regexMoveToDesc;
  final int matchCount;
  final bool stopMarkerFound;
  final String? stopMarker;
  final bool truncated;
  final int captureLen;
  final String previewCapture;
  final bool safeToApply;
  final String reason;
  final Map<String, dynamic> patchOps;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'odu_key': oduKey,
      'source_section': sourceSection,
      'source_json_key': sourceJsonKey,
      'anchor_used': anchorUsed,
      'regex_move_to_desc': regexMoveToDesc,
      'regex_remove_from_source': regexMoveToDesc,
      'regex_append_to_descripcion': regexMoveToDesc,
      'match_count': matchCount,
      'stop_marker_found': stopMarkerFound,
      'stop_marker': stopMarker,
      'truncated': truncated,
      'capture_len': captureLen,
      'preview_capture': previewCapture,
      'safe_to_apply': safeToApply,
      'reason': reason,
      'patch_ops': patchOps,
    };
  }
}
