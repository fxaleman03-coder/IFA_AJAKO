import 'dart:convert';
import 'dart:io';

const String _inputPath = 'assets/odu_content_patched.json';
const String _outJsonPath = 'build/tanda8_structural_audit.json';
const String _outMdPath = 'build/tanda8_structural_audit.md';

const int _maxResults = 20;
const int _previewBeforeChars = 600;
const int _previewAfterChars = 1200;

const List<String> _sectionOrder = <String>['nace', 'eshu', 'obras', 'diceIfa'];

class _AnchorSpec {
  const _AnchorSpec({
    required this.label,
    required this.pattern,
  });

  final String label;
  final String pattern;

  RegExp get regex => RegExp(
    pattern,
    caseSensitive: false,
    multiLine: true,
    dotAll: true,
  );
}

const List<_AnchorSpec> _anchorSpecs = <_AnchorSpec>[
  _AnchorSpec(label: 'ESTE ES EL ODU', pattern: r'ESTE\s+ES\s+EL\s+OD[ÙUO]\b'),
  _AnchorSpec(label: 'DESCRIPC', pattern: r'DESCRIPC'),
  _AnchorSpec(label: 'DESCRIPCION', pattern: r'DESCRIPCION'),
  _AnchorSpec(label: 'DESCRIPCIÓN', pattern: r'DESCRIPCIÓN'),
  _AnchorSpec(label: 'ESTE ODU', pattern: r'ESTE\s+OD[ÙUO]\b'),
  _AnchorSpec(label: 'ESTE SIGNO', pattern: r'ESTE\s+SIGNO\b'),
  _AnchorSpec(label: 'ESTE IFÁ', pattern: r'ESTE\s+IFÁ\b'),
  _AnchorSpec(label: 'ESTE IFA', pattern: r'ESTE\s+IFA\b'),
];

void main() {
  final inputFile = File(_inputPath);
  if (!inputFile.existsSync()) {
    stderr.writeln('Missing input: $_inputPath');
    exitCode = 1;
    return;
  }

  final decoded = jsonDecode(inputFile.readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    stderr.writeln('Invalid JSON root in $_inputPath');
    exitCode = 1;
    return;
  }

  final oduRaw = decoded['odu'];
  if (oduRaw is! Map) {
    stderr.writeln('Invalid JSON: missing "odu" object');
    exitCode = 1;
    return;
  }

  final oduMap = Map<String, dynamic>.from(oduRaw);
  final results = <_AuditRow>[];

  for (final entry in oduMap.entries) {
    final oduKey = entry.key.toString();
    final nodeRaw = entry.value;
    if (nodeRaw is! Map) continue;

    final node = Map<String, dynamic>.from(nodeRaw);
    final contentRaw = node['content'];
    if (contentRaw is! Map) continue;
    final content = Map<String, dynamic>.from(contentRaw);

    final descripcion = _asString(content['descripcion']);
    final nace = _asString(content['nace']);
    final eshu = _asString(content['eshu']);
    final obras = _asString(content['obras']);
    final diceIfa = _resolveDiceIfa(content);

    final descripcionLength = _effectiveLength(descripcion);
    final naceLength = nace.length;
    final eshuLength = eshu.length;

    final sectionTexts = <String, String>{
      'nace': nace,
      'eshu': eshu,
      'obras': obras,
      'diceIfa': diceIfa,
    };

    final allHits = <_AnchorHit>[];
    for (final section in _sectionOrder) {
      final text = sectionTexts[section] ?? '';
      if (text.isEmpty) continue;
      allHits.addAll(_collectAnchorHits(text: text, section: section));
    }
    if (allHits.isEmpty) continue;

    final naceHits = allHits.where((h) => h.section == 'nace').toList();
    final eshuHits = allHits.where((h) => h.section == 'eshu').toList();
    final nonNaceHits = allHits
        .where((h) => h.section == 'eshu' || h.section == 'obras' || h.section == 'diceIfa')
        .toList();

    final high = descripcionLength < 300 && naceLength > 1800 && naceHits.isNotEmpty;

    final medium =
        !high &&
        descripcionLength < 500 &&
        naceLength > 1800 &&
        (nonNaceHits.isNotEmpty || naceHits.isNotEmpty || eshuHits.isNotEmpty);

    if (!high && !medium) continue;

    allHits.sort((a, b) {
      final bySection = _sectionOrder
          .indexOf(a.section)
          .compareTo(_sectionOrder.indexOf(b.section));
      if (bySection != 0) return bySection;
      return a.start.compareTo(b.start);
    });

    final first = allHits.first;
    final sourceText = sectionTexts[first.section] ?? '';
    final beforeStart = _max(0, first.start - _previewBeforeChars);
    final afterEnd = _min(sourceText.length, first.start + _previewAfterChars);
    final before = sourceText.substring(beforeStart, first.start);
    final after = sourceText.substring(first.start, afterEnd);

    final uniqueAnchors = allHits.map((h) => h.anchorLabel).toSet().toList()
      ..sort((a, b) => a.compareTo(b));
    final sectionsWithAnchors = allHits.map((h) => h.section).toSet().toList()
      ..sort((a, b) => _sectionOrder.indexOf(a).compareTo(_sectionOrder.indexOf(b)));

    final confidence = high ? 'HIGH' : 'MEDIUM';

    results.add(
      _AuditRow(
        oduKey: oduKey,
        descripcionLength: descripcionLength,
        naceLength: naceLength,
        eshuLength: eshuLength,
        anchorsFound: uniqueAnchors,
        sectionsWithAnchors: sectionsWithAnchors,
        firstAnchorSection: first.section,
        firstAnchorLabel: first.anchorLabel,
        firstAnchorIndex: first.start,
        previewBefore600: before,
        previewAfter1200: after,
        recommendedFixTarget: 'descripcion',
        recommendedSourceSection: first.section,
        confidence: confidence,
        highProbabilityMove: high,
      ),
    );
  }

  results.sort((a, b) {
    final aRank = a.confidence == 'HIGH' ? 0 : 1;
    final bRank = b.confidence == 'HIGH' ? 0 : 1;
    final byRank = aRank.compareTo(bRank);
    if (byRank != 0) return byRank;
    final byDesc = a.descripcionLength.compareTo(b.descripcionLength);
    if (byDesc != 0) return byDesc;
    final byNace = b.naceLength.compareTo(a.naceLength);
    if (byNace != 0) return byNace;
    return a.oduKey.compareTo(b.oduKey);
  });

  final selected = results.take(_maxResults).toList();
  final highCount = selected.where((r) => r.confidence == 'HIGH').length;
  final mediumCount = selected.where((r) => r.confidence == 'MEDIUM').length;

  final jsonOut = <String, dynamic>{
    'source_file': _inputPath,
    'generated_utc': DateTime.now().toUtc().toIso8601String(),
    'criteria': <String, dynamic>{
      'high': <String>[
        'descripcion.length < 300',
        'nace.length > 1800',
        'nace contains one or more configured anchors',
      ],
      'medium': <String>[
        'descripcion.length < 500',
        'nace.length > 1800',
        'anchor in eshu/obras/diceIfa or nace',
      ],
      'anchors': _anchorSpecs.map((a) => a.label).toList(),
      'ordered_sections_for_first_anchor': _sectionOrder,
      'preview_before_chars': _previewBeforeChars,
      'preview_after_chars': _previewAfterChars,
      'max_results': _maxResults,
      'sort': 'HIGH first (descripcion asc, nace desc), then MEDIUM',
    },
    'summary': <String, dynamic>{
      'scanned_odu_count': oduMap.length,
      'matched_criteria_count': results.length,
      'selected_count': selected.length,
      'high_count': highCount,
      'medium_count': mediumCount,
    },
    'results': selected.map((r) => r.toJson()).toList(),
  };

  final md = StringBuffer()
    ..writeln('# TANDA 8 Structural Audit')
    ..writeln()
    ..writeln('- Source: `$_inputPath`')
    ..writeln('- Generated (UTC): `${jsonOut['generated_utc']}`')
    ..writeln('- Selected (max $_maxResults): `${selected.length}`')
    ..writeln('- HIGH: `$highCount`')
    ..writeln('- MEDIUM: `$mediumCount`')
    ..writeln()
    ..writeln('## Results');

  if (selected.isEmpty) {
    md.writeln('_No matches found._');
  } else {
    for (final row in selected) {
      md.writeln('### `${row.oduKey}`');
      md.writeln('- confidence: `${row.confidence}`');
      md.writeln('- HIGH_PROBABILITY_MOVE: `${row.highProbabilityMove}`');
      md.writeln('- descripcion_length: `${row.descripcionLength}`');
      md.writeln('- nace_length: `${row.naceLength}`');
      md.writeln('- eshu_length: `${row.eshuLength}`');
      md.writeln('- anchors_found_sections: `${row.sectionsWithAnchors.join(', ')}`');
      md.writeln('- anchors_found: `${row.anchorsFound.join(', ')}`');
      md.writeln('- first_anchor_section: `${row.firstAnchorSection}`');
      md.writeln('- first_anchor_label: `${row.firstAnchorLabel}`');
      md.writeln('- recommended_fix_target: `${row.recommendedFixTarget}`');
      md.writeln('- recommended_source_section: `${row.recommendedSourceSection}`');
      md.writeln('- preview (600 before + 1200 after first anchor):');
      md.writeln('```text');
      md.writeln(row.previewBefore600);
      md.writeln('<<<ANCHOR>>>');
      md.writeln(row.previewAfter1200);
      md.writeln('```');
      md.writeln();
    }
  }

  Directory('build').createSync(recursive: true);
  File(
    _outJsonPath,
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(jsonOut));
  File(_outMdPath).writeAsStringSync(md.toString());

  stdout.writeln('Generated structural audit (no patches applied).');
  stdout.writeln('Selected: ${selected.length}');
  stdout.writeln('HIGH: $highCount');
  stdout.writeln('MEDIUM: $mediumCount');
  stdout.writeln('Wrote: $_outJsonPath');
  stdout.writeln('Wrote: $_outMdPath');
}

List<_AnchorHit> _collectAnchorHits({
  required String text,
  required String section,
}) {
  final hits = <_AnchorHit>[];
  for (final spec in _anchorSpecs) {
    for (final m in spec.regex.allMatches(text)) {
      hits.add(
        _AnchorHit(
          section: section,
          anchorLabel: spec.label,
          start: m.start,
        ),
      );
    }
  }
  return hits;
}

String _resolveDiceIfa(Map<String, dynamic> content) {
  final keys = <String>['diceIfa', 'diceifa', 'dice_ifa', 'diceIfaYoruba'];
  for (final key in keys) {
    if (content.containsKey(key)) return _asString(content[key]);
  }
  return '';
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
int _max(int a, int b) => a > b ? a : b;

class _AnchorHit {
  const _AnchorHit({
    required this.section,
    required this.anchorLabel,
    required this.start,
  });

  final String section;
  final String anchorLabel;
  final int start;
}

class _AuditRow {
  const _AuditRow({
    required this.oduKey,
    required this.descripcionLength,
    required this.naceLength,
    required this.eshuLength,
    required this.anchorsFound,
    required this.sectionsWithAnchors,
    required this.firstAnchorSection,
    required this.firstAnchorLabel,
    required this.firstAnchorIndex,
    required this.previewBefore600,
    required this.previewAfter1200,
    required this.recommendedFixTarget,
    required this.recommendedSourceSection,
    required this.confidence,
    required this.highProbabilityMove,
  });

  final String oduKey;
  final int descripcionLength;
  final int naceLength;
  final int eshuLength;
  final List<String> anchorsFound;
  final List<String> sectionsWithAnchors;
  final String firstAnchorSection;
  final String firstAnchorLabel;
  final int firstAnchorIndex;
  final String previewBefore600;
  final String previewAfter1200;
  final String recommendedFixTarget;
  final String recommendedSourceSection;
  final String confidence;
  final bool highProbabilityMove;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'odu_key': oduKey,
      'descripcion_length': descripcionLength,
      'nace_length': naceLength,
      'eshu_length': eshuLength,
      'anchor_found_in_sections': sectionsWithAnchors,
      'anchors_found': anchorsFound,
      'first_anchor_section': firstAnchorSection,
      'first_anchor_label': firstAnchorLabel,
      'first_anchor_index': firstAnchorIndex,
      'preview_before_600': previewBefore600,
      'preview_after_1200': previewAfter1200,
      'recommended_fix_target': recommendedFixTarget,
      'recommended_source_section': recommendedSourceSection,
      'confidence': confidence,
      'high_probability_move': highProbabilityMove,
    };
  }
}
