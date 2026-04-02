import 'dart:convert';
import 'dart:io';

const String _defaultSourcePath = 'assets/odu_content.json';
const String _defaultPatchPath = 'assets/odu_patches.json';
const String _defaultOutputPath = 'build/odu_content_patched.json';
const String _defaultMovedLogPath = 'build/odu_patch_moved_log.json';

void main() {
  const sourcePath = String.fromEnvironment(
    'ODU_PATCH_SOURCE_PATH',
    defaultValue: _defaultSourcePath,
  );
  const patchPath = String.fromEnvironment(
    'ODU_PATCH_PATH',
    defaultValue: _defaultPatchPath,
  );
  const outputPath = String.fromEnvironment(
    'ODU_PATCH_OUTPUT_PATH',
    defaultValue: _defaultOutputPath,
  );
  const movedLogPath = String.fromEnvironment(
    'ODU_PATCH_MOVED_LOG_PATH',
    defaultValue: _defaultMovedLogPath,
  );

  final sourceFile = File(sourcePath);
  final patchFile = File(patchPath);

  if (!sourceFile.existsSync()) {
    stderr.writeln('Source file not found: $sourcePath');
    exitCode = 1;
    return;
  }
  if (!patchFile.existsSync()) {
    stderr.writeln('Patch file not found: $patchPath');
    exitCode = 1;
    return;
  }

  final sourceDecoded = jsonDecode(sourceFile.readAsStringSync());
  final patchDecoded = jsonDecode(patchFile.readAsStringSync());
  if (sourceDecoded is! Map || patchDecoded is! Map) {
    stderr.writeln('Invalid JSON format in source or patch file.');
    exitCode = 1;
    return;
  }

  final sourceRoot = Map<String, dynamic>.from(sourceDecoded);
  final patchesRoot = Map<String, dynamic>.from(patchDecoded);
  final rawOdu = sourceRoot['odu'];
  if (rawOdu is! Map) {
    stderr.writeln('Invalid source: "odu" must be a map.');
    exitCode = 1;
    return;
  }

  final oduMap = Map<String, dynamic>.from(rawOdu);
  final normalizedOduLookup = <String, String>{
    for (final key in oduMap.keys.whereType<String>())
      _normalizeOduKey(key): key,
  };

  final movedLogEntries = <Map<String, dynamic>>[];
  final warnings = <String>[];
  var touchedOduCount = 0;

  for (final patchEntry in patchesRoot.entries) {
    final patchOduKey = patchEntry.key;
    if (patchOduKey.startsWith('_')) {
      continue;
    }
    final patchValue = patchEntry.value;
    if (patchValue is! Map) {
      warnings.add(
        'Patch entry "$patchOduKey" ignored: expected object, got ${patchValue.runtimeType}.',
      );
      continue;
    }
    final canonicalPatchKey = _normalizeOduKey(patchOduKey);
    final sourceOduKey = normalizedOduLookup[canonicalPatchKey];
    if (sourceOduKey == null) {
      warnings.add('Patch entry "$patchOduKey" ignored: Odù key not found.');
      continue;
    }

    final oduNodeRaw = oduMap[sourceOduKey];
    if (oduNodeRaw is! Map) {
      warnings.add(
        'Odù "$sourceOduKey" ignored: expected object node, got ${oduNodeRaw.runtimeType}.',
      );
      continue;
    }
    final oduNode = Map<String, dynamic>.from(oduNodeRaw);
    final contentRaw = oduNode['content'];
    if (contentRaw is! Map) {
      warnings.add('Odù "$sourceOduKey" ignored: missing "content" object.');
      continue;
    }
    final content = Map<String, dynamic>.from(contentRaw);

    final patchMap = Map<String, dynamic>.from(patchValue);
    final applied = _applyPatchToOdu(
      oduKey: sourceOduKey,
      content: content,
      patchMap: patchMap,
      movedLogEntries: movedLogEntries,
      warnings: warnings,
    );
    if (applied) {
      touchedOduCount++;
      oduNode['content'] = content;
      oduMap[sourceOduKey] = oduNode;
    }
  }

  sourceRoot['odu'] = oduMap;
  Directory('build').createSync(recursive: true);
  File(
    outputPath,
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(sourceRoot));
  File(movedLogPath).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'source_path': sourcePath,
      'patch_path': patchPath,
      'output_path': outputPath,
      'touched_odu_count': touchedOduCount,
      'operation_count': movedLogEntries.length,
      'warnings': warnings,
      'moved_log': movedLogEntries,
    }),
  );

  for (final warning in warnings) {
    stdout.writeln('WARN: $warning');
  }
  stdout.writeln('Touched Odù entries: $touchedOduCount');
  stdout.writeln('Operations logged: ${movedLogEntries.length}');
  stdout.writeln('Patched JSON written to: $outputPath');
  stdout.writeln('Moved log written to: $movedLogPath');
}

bool _applyPatchToOdu({
  required String oduKey,
  required Map<String, dynamic> content,
  required Map<String, dynamic> patchMap,
  required List<Map<String, dynamic>> movedLogEntries,
  required List<String> warnings,
}) {
  var touched = false;
  final sectionPatchByCanonical = <String, Map<String, dynamic>>{};
  // Tracks source-pattern pairs already moved to avoid noisy warnings when
  // paired append_from/remove_from operations intentionally no-op afterward.
  final movedPatternBySource = <String>{};

  final sortedPatchEntries = patchMap.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));

  for (final sectionEntry in sortedPatchEntries) {
    final sectionAlias = sectionEntry.key;
    if (sectionAlias.startsWith('_')) {
      continue;
    }
    final rawSectionPatch = sectionEntry.value;
    if (rawSectionPatch is! Map) {
      warnings.add(
        'Odù "$oduKey": section "$sectionAlias" ignored (expected object).',
      );
      continue;
    }
    final sectionKey = _canonicalSectionKey(sectionAlias);
    if (sectionKey == null) {
      warnings.add(
        'Odù "$oduKey": section "$sectionAlias" ignored (unknown section).',
      );
      continue;
    }
    sectionPatchByCanonical[sectionKey] = Map<String, dynamic>.from(
      rawSectionPatch,
    );
  }

  final deferredOps = <_PatchOp>[];

  for (final sectionKey in sectionPatchByCanonical.keys.toList()..sort()) {
    final sectionPatch = sectionPatchByCanonical[sectionKey]!;
    final keepRegexes = _parseRegexList(
      sectionPatch['keep_regex'],
      warnings: warnings,
      warningPrefix: 'Odù "$oduKey", section "$sectionKey", keep_regex',
    );

    for (final pattern in _parsePatternList(sectionPatch['remove_regex'])) {
      final regExp = _buildPattern(pattern, warnings, oduKey, sectionKey);
      if (regExp == null) {
        continue;
      }
      final sourceText = _getSectionText(content, sectionKey);
      final extraction = _extractMatches(
        text: sourceText,
        regex: regExp,
        keepRegexes: keepRegexes,
      );
      _setSectionText(content, sectionKey, extraction.remainingText);
      if (extraction.matches.isEmpty) {
        warnings.add(
          'Odù "$oduKey", section "$sectionKey": remove_regex matched nothing: $pattern',
        );
        continue;
      }
      touched = true;
      movedLogEntries.add(<String, dynamic>{
        'odu': oduKey,
        'operation': 'remove',
        'source_section': sectionKey,
        'target_section': null,
        'pattern': pattern,
        'match_count': extraction.matches.length,
        'skipped_by_keep': extraction.skippedByKeep,
        'sample': extraction.matches.take(3).map(_sample).toList(),
      });
    }

    for (final moveEntry in sectionPatch.entries) {
      final moveKey = moveEntry.key;
      if (moveKey.startsWith('move_to_') && moveKey.endsWith('_regex')) {
        final targetAlias = moveKey.substring(
          'move_to_'.length,
          moveKey.length - '_regex'.length,
        );
        final targetSection = _canonicalSectionKey(targetAlias);
        if (targetSection == null) {
          warnings.add(
            'Odù "$oduKey", section "$sectionKey": unknown move target "$targetAlias".',
          );
          continue;
        }
        for (final pattern in _parsePatternList(moveEntry.value)) {
          final regExp = _buildPattern(pattern, warnings, oduKey, sectionKey);
          if (regExp == null) continue;
          final sourceText = _getSectionText(content, sectionKey);
          final extraction = _extractMatches(
            text: sourceText,
            regex: regExp,
            keepRegexes: keepRegexes,
          );
          _setSectionText(content, sectionKey, extraction.remainingText);
          if (extraction.matches.isEmpty) {
            warnings.add(
              'Odù "$oduKey", section "$sectionKey": move_to target "$targetSection" matched nothing: $pattern',
            );
            continue;
          }
          final movedText = _joinBlocks(extraction.matches);
          _setSectionText(
            content,
            targetSection,
            _mergeBlocks(<String>[
              _getSectionText(content, targetSection),
              movedText,
            ]),
          );
          touched = true;
          movedPatternBySource.add('$sectionKey|$pattern');
          movedLogEntries.add(<String, dynamic>{
            'odu': oduKey,
            'operation': 'move_append',
            'source_section': sectionKey,
            'target_section': targetSection,
            'pattern': pattern,
            'match_count': extraction.matches.length,
            'skipped_by_keep': extraction.skippedByKeep,
            'sample': extraction.matches.take(3).map(_sample).toList(),
          });
        }
      } else if ((moveKey.startsWith('prepend_from_') ||
              moveKey.startsWith('append_from_')) &&
          moveKey.endsWith('_regex')) {
        final prefix = moveKey.startsWith('prepend_from_')
            ? 'prepend_from_'
            : 'append_from_';
        final sourceAlias = moveKey.substring(
          prefix.length,
          moveKey.length - '_regex'.length,
        );
        final sourceSection = _canonicalSectionKey(sourceAlias);
        if (sourceSection == null) {
          warnings.add(
            'Odù "$oduKey", section "$sectionKey": unknown ${prefix.startsWith('prepend') ? 'prepend' : 'append'} source "$sourceAlias".',
          );
          continue;
        }
        for (final pattern in _parsePatternList(moveEntry.value)) {
          deferredOps.add(
            _PatchOp(
              oduKey: oduKey,
              sourceSection: sourceSection,
              targetSection: sectionKey,
              pattern: pattern,
              operation: prefix.startsWith('prepend')
                  ? 'move_prepend'
                  : 'move_append',
            ),
          );
        }
      } else if (moveKey.startsWith('remove_from_') &&
          moveKey.endsWith('_regex')) {
        final sourceAlias = moveKey.substring(
          'remove_from_'.length,
          moveKey.length - '_regex'.length,
        );
        final sourceSection = _canonicalSectionKey(sourceAlias);
        if (sourceSection == null) {
          warnings.add(
            'Odù "$oduKey", section "$sectionKey": unknown remove source "$sourceAlias".',
          );
          continue;
        }
        for (final pattern in _parsePatternList(moveEntry.value)) {
          deferredOps.add(
            _PatchOp(
              oduKey: oduKey,
              sourceSection: sourceSection,
              targetSection: null,
              pattern: pattern,
              operation: 'remove',
            ),
          );
        }
      }
    }
  }

  for (final op in deferredOps.where((op) => op.operation != 'remove')) {
    final sourceSectionPatch = sectionPatchByCanonical[op.sourceSection];
    final keepRegexes = sourceSectionPatch == null
        ? const <RegExp>[]
        : _parseRegexList(
            sourceSectionPatch['keep_regex'],
            warnings: warnings,
            warningPrefix:
                'Odù "${op.oduKey}", section "${op.sourceSection}", keep_regex',
          );
    final regExp = _buildPattern(
      op.pattern,
      warnings,
      op.oduKey,
      op.sourceSection,
    );
    if (regExp == null) continue;

    final sourceText = _getSectionText(content, op.sourceSection);
    final extraction = _extractMatches(
      text: sourceText,
      regex: regExp,
      keepRegexes: keepRegexes,
    );
    _setSectionText(content, op.sourceSection, extraction.remainingText);
    if (extraction.matches.isEmpty) {
      if (movedPatternBySource.contains('${op.sourceSection}|${op.pattern}')) {
        continue;
      }
      warnings.add(
        'Odù "${op.oduKey}", ${op.operation} from "${op.sourceSection}" to "${op.targetSection}" matched nothing: ${op.pattern}',
      );
      continue;
    }
    final movedText = _joinBlocks(extraction.matches);
    if (op.targetSection != null) {
      final targetSection = op.targetSection!;
      if (op.operation == 'move_prepend') {
        _setSectionText(
          content,
          targetSection,
          _mergeBlocks(<String>[movedText, _getSectionText(content, targetSection)]),
        );
      } else {
        _setSectionText(
          content,
          targetSection,
          _mergeBlocks(<String>[_getSectionText(content, targetSection), movedText]),
        );
      }
    }
    touched = true;
    movedPatternBySource.add('${op.sourceSection}|${op.pattern}');
    movedLogEntries.add(<String, dynamic>{
      'odu': op.oduKey,
      'operation': op.operation,
      'source_section': op.sourceSection,
      'target_section': op.targetSection,
      'pattern': op.pattern,
      'match_count': extraction.matches.length,
      'skipped_by_keep': extraction.skippedByKeep,
      'sample': extraction.matches.take(3).map(_sample).toList(),
    });
  }

  for (final op in deferredOps.where((op) => op.operation == 'remove')) {
    final sourceSectionPatch = sectionPatchByCanonical[op.sourceSection];
    final keepRegexes = sourceSectionPatch == null
        ? const <RegExp>[]
        : _parseRegexList(
            sourceSectionPatch['keep_regex'],
            warnings: warnings,
            warningPrefix:
                'Odù "${op.oduKey}", section "${op.sourceSection}", keep_regex',
          );
    final regExp = _buildPattern(
      op.pattern,
      warnings,
      op.oduKey,
      op.sourceSection,
    );
    if (regExp == null) continue;

    final sourceText = _getSectionText(content, op.sourceSection);
    final extraction = _extractMatches(
      text: sourceText,
      regex: regExp,
      keepRegexes: keepRegexes,
    );
    _setSectionText(content, op.sourceSection, extraction.remainingText);
    if (extraction.matches.isEmpty) {
      // If this same source/pattern was already moved, an explicit remove_from_* can legitimately no-op.
      if (!movedPatternBySource.contains('${op.sourceSection}|${op.pattern}')) {
        warnings.add(
          'Odù "${op.oduKey}", remove from "${op.sourceSection}" matched nothing: ${op.pattern}',
        );
      }
      continue;
    }
    touched = true;
    movedLogEntries.add(<String, dynamic>{
      'odu': op.oduKey,
      'operation': op.operation,
      'source_section': op.sourceSection,
      'target_section': null,
      'pattern': op.pattern,
      'match_count': extraction.matches.length,
      'skipped_by_keep': extraction.skippedByKeep,
      'sample': extraction.matches.take(3).map(_sample).toList(),
    });
  }

  return touched;
}

RegExp? _buildPattern(
  String pattern,
  List<String> warnings,
  String oduKey,
  String sectionKey,
) {
  try {
    return RegExp(pattern, multiLine: true, dotAll: true, caseSensitive: false);
  } catch (_) {
    warnings.add(
      'Odù "$oduKey", section "$sectionKey": invalid regex "$pattern".',
    );
    return null;
  }
}

List<String> _parsePatternList(dynamic raw) {
  if (raw is List) {
    return raw
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const <String>[];
}

List<RegExp> _parseRegexList(
  dynamic raw, {
  required List<String> warnings,
  required String warningPrefix,
}) {
  final patterns = _parsePatternList(raw);
  final regexes = <RegExp>[];
  for (final pattern in patterns) {
    try {
      regexes.add(
        RegExp(pattern, multiLine: true, dotAll: true, caseSensitive: false),
      );
    } catch (_) {
      warnings.add('$warningPrefix invalid regex "$pattern".');
    }
  }
  return regexes;
}

String _getSectionText(Map<String, dynamic> content, String sectionKey) {
  final value = content[sectionKey];
  if (value is String) {
    return value;
  }
  return '';
}

void _setSectionText(
  Map<String, dynamic> content,
  String sectionKey,
  String value,
) {
  content[sectionKey] = _cleanupText(value);
}

String? _canonicalSectionKey(String raw) {
  final normalized = raw
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]'), '')
      .trim();

  switch (normalized) {
    case 'nace':
      return 'nace';
    case 'descripcion':
    case 'desc':
      return 'descripcion';
    case 'ewes':
      return 'ewes';
    case 'eshu':
      return 'eshu';
    case 'obrasyebbo':
    case 'obras':
    case 'ebbo':
      return 'obrasYEbbo';
    case 'diceifa':
      return 'diceIfa';
    case 'historias':
    case 'historiasypatakies':
    case 'patakies':
      return 'historiasYPatakies';
    case 'rezoyoruba':
    case 'rezo':
      return 'rezoYoruba';
    case 'suyereyoruba':
    case 'suyere':
      return 'suyereYoruba';
    case 'suyereespanol':
    case 'traduccion':
      return 'suyereEspanol';
    case 'rezosysuyeres':
      return 'rezosYSuyeres';
    case 'refranes':
      return 'refranes';
    default:
      return null;
  }
}

String _normalizeOduKey(String key) => key
    .toUpperCase()
    .replaceAll('_', ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

_ExtractionResult _extractMatches({
  required String text,
  required RegExp regex,
  required List<RegExp> keepRegexes,
}) {
  final normalized = _normalizeNewlines(text);
  if (normalized.isEmpty) {
    return _ExtractionResult(
      remainingText: '',
      matches: const <String>[],
      skippedByKeep: 0,
    );
  }

  final keepSpans = _collectKeepSpans(normalized, keepRegexes);
  final matches = regex.allMatches(normalized).toList();
  if (matches.isEmpty) {
    return _ExtractionResult(
      remainingText: _cleanupText(normalized),
      matches: const <String>[],
      skippedByKeep: 0,
    );
  }

  final buffer = StringBuffer();
  final extracted = <String>[];
  var cursor = 0;
  var skippedByKeep = 0;

  for (final match in matches) {
    if (match.start == match.end) {
      continue;
    }
    if (_overlapsKeep(match.start, match.end, keepSpans)) {
      skippedByKeep++;
      continue;
    }
    if (match.start < cursor) {
      continue;
    }
    buffer.write(normalized.substring(cursor, match.start));
    extracted.add(normalized.substring(match.start, match.end));
    cursor = match.end;
  }
  buffer.write(normalized.substring(cursor));

  return _ExtractionResult(
    remainingText: _cleanupText(buffer.toString()),
    matches: extracted.map(_cleanupText).where((s) => s.isNotEmpty).toList(),
    skippedByKeep: skippedByKeep,
  );
}

List<_Span> _collectKeepSpans(String text, List<RegExp> keepRegexes) {
  if (keepRegexes.isEmpty) return const <_Span>[];
  final spans = <_Span>[];
  for (final regex in keepRegexes) {
    for (final match in regex.allMatches(text)) {
      if (match.start == match.end) {
        continue;
      }
      spans.add(_Span(match.start, match.end));
    }
  }
  if (spans.isEmpty) return const <_Span>[];
  spans.sort((a, b) => a.start.compareTo(b.start));
  final merged = <_Span>[];
  for (final span in spans) {
    if (merged.isEmpty || span.start > merged.last.end) {
      merged.add(span);
      continue;
    }
    final previous = merged.removeLast();
    merged.add(
      _Span(previous.start, span.end > previous.end ? span.end : previous.end),
    );
  }
  return merged;
}

bool _overlapsKeep(int start, int end, List<_Span> spans) {
  for (final span in spans) {
    if (end <= span.start) continue;
    if (start >= span.end) continue;
    return true;
  }
  return false;
}

String _cleanupText(String text) {
  var cleaned = _normalizeNewlines(text);
  cleaned = cleaned.replaceAll(RegExp(r'[ \t]+\n'), '\n');
  cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return cleaned.trim();
}

String _normalizeNewlines(String text) =>
    text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

String _joinBlocks(List<String> blocks) => _mergeBlocks(blocks);

String _mergeBlocks(List<String> blocks) {
  final cleaned = blocks
      .map(_cleanupText)
      .where((text) => text.isNotEmpty)
      .toList();
  return cleaned.join('\n\n');
}

String _sample(String text) {
  final normalized = _cleanupText(text);
  if (normalized.length <= 220) {
    return normalized;
  }
  return '${normalized.substring(0, 220)}...';
}

class _PatchOp {
  const _PatchOp({
    required this.oduKey,
    required this.sourceSection,
    required this.targetSection,
    required this.pattern,
    required this.operation,
  });

  final String oduKey;
  final String sourceSection;
  final String? targetSection;
  final String pattern;
  final String operation;
}

class _ExtractionResult {
  const _ExtractionResult({
    required this.remainingText,
    required this.matches,
    required this.skippedByKeep,
  });

  final String remainingText;
  final List<String> matches;
  final int skippedByKeep;
}

class _Span {
  const _Span(this.start, this.end);

  final int start;
  final int end;
}
