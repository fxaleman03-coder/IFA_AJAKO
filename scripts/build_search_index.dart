import 'dart:convert';
import 'dart:io';

import 'package:libreta_de_ifa/odu_search_normalization.dart';

const _defaultInputPath = 'assets/odu_content_patched.json';
const _defaultAliasesPath = 'assets/aliases.json';
const _defaultTopicsPath = 'assets/topics.json';
const _defaultOutputPath = 'assets/search_index.json';

const Set<String> _keywordStopWords = <String>{
  'de',
  'del',
  'la',
  'las',
  'los',
  'el',
  'en',
  'y',
  'o',
  'a',
  'al',
  'un',
  'una',
  'unos',
  'unas',
  'que',
  'se',
  'es',
  'por',
  'para',
  'con',
  'su',
  'sus',
  'lo',
  'le',
  'les',
  'ya',
  'no',
  'si',
  'como',
  'mas',
  'este',
  'esta',
  'estos',
  'estas',
  'the',
  'and',
  'for',
  'with',
  'this',
  'that',
  'from',
  'you',
  'your',
  'are',
  'not',
  'all',
  'has',
  'have',
  'its',
};

const _sectionWeights = <String, int>{
  'descripcion': 5,
  'diceIfa': 5,
  'eshu': 3,
  'obras': 3,
  'historiasYPatakies': 3,
  'ewes': 3,
  'rezoYoruba': 1,
  'suyereYoruba': 1,
};

const _phraseSections = <String>[
  'descripcion',
  'diceIfa',
  'eshu',
  'obras',
  'historiasYPatakies',
];
const _maxSectionNgrams = 1200;

List<String> tokenizeForIndex(String value, {bool removeStopWords = true}) {
  final normalized = normalizeSearchTextShared(value);
  if (normalized.isEmpty) {
    return const [];
  }
  final out = <String>[];
  for (final token in normalized.split(' ')) {
    if (token.isEmpty) {
      continue;
    }
    if (token.length < 3) {
      if (token == 'ifa' || token == 'odu') {
        out.add(token);
      }
      continue;
    }
    if (removeStopWords && _keywordStopWords.contains(token)) {
      continue;
    }
    out.add(token);
  }
  return out;
}

String _previewFromSections(Map<String, dynamic> content) {
  const fields = <String>[
    'descripcion',
    'diceIfa',
    'obras',
    'obrasYEbbo',
    'ewes',
    'eshu',
    'historiasYPatakies',
    'nace',
    'rezoYoruba',
    'suyereYoruba',
  ];
  for (final field in fields) {
    final value = content[field];
    if (value is String && value.trim().isNotEmpty) {
      return value.replaceAll(RegExp(r'\s+'), ' ').trim();
    }
  }
  return '';
}

Map<String, List<String>> _loadEntryAliases(Map<String, dynamic> rawAliases) {
  final raw = rawAliases['entryAliases'];
  if (raw is! Map) {
    return const {};
  }
  final out = <String, List<String>>{};
  raw.forEach((key, value) {
    if (key is! String || value is! List) {
      return;
    }
    final aliases = value.whereType<String>().map((e) => e.trim()).toList();
    if (aliases.isEmpty) {
      return;
    }
    out[normalizeSearchTextShared(key)] = aliases;
  });
  return out;
}

Map<String, List<String>> _loadFamilyAliases(Map<String, dynamic> rawAliases) {
  final raw = rawAliases['familyAliases'];
  if (raw is! Map) {
    return const {};
  }
  final out = <String, List<String>>{};
  raw.forEach((key, value) {
    if (key is! String || value is! List) {
      return;
    }
    final aliases = value.whereType<String>().map((e) => e.trim()).toList();
    if (aliases.isEmpty) {
      return;
    }
    out[normalizeSearchTextShared(key)] = aliases;
  });
  return out;
}

class TopicDefinition {
  TopicDefinition({
    required this.id,
    required this.label,
    required this.synonyms,
    required this.hints,
  }) : normalizedTerms = {
         normalizeSearchTextShared(id),
         normalizeSearchTextShared(label),
         ...synonyms.map(normalizeSearchTextShared),
         ...hints.map(normalizeSearchTextShared),
       }.where((e) => e.isNotEmpty).toList(growable: false);

  final String id;
  final String label;
  final List<String> synonyms;
  final List<String> hints;
  final List<String> normalizedTerms;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'synonyms': synonyms,
    'hints': hints,
  };
}

List<TopicDefinition> _loadTopics(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Topics JSON not found: $path');
    exitCode = 1;
    return const [];
  }
  final decoded = jsonDecode(file.readAsStringSync(encoding: utf8));
  if (decoded is! Map<String, dynamic>) {
    stderr.writeln('Unsupported topics schema.');
    exitCode = 1;
    return const [];
  }
  final rawTopics = decoded['topics'];
  if (rawTopics is! List) {
    stderr.writeln('Unsupported topics schema: "topics" list missing.');
    exitCode = 1;
    return const [];
  }
  final out = <TopicDefinition>[];
  for (final item in rawTopics) {
    if (item is! Map) continue;
    final map = Map<String, dynamic>.from(item);
    final id = map['id']?.toString().trim() ?? '';
    if (id.isEmpty) continue;
    final label = (map['label']?.toString().trim() ?? id);
    final synonyms = (map['synonyms'] is List)
        ? (map['synonyms'] as List)
              .whereType<String>()
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    final hints = (map['hints'] is List)
        ? (map['hints'] as List)
              .whereType<String>()
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    out.add(
      TopicDefinition(id: id, label: label, synonyms: synonyms, hints: hints),
    );
  }
  return out;
}

String _replaceFamilyToken({
  required String source,
  required String canonicalFamily,
  required String aliasFamily,
}) {
  final normalized = normalizeSearchTextShared(source);
  if (normalized.isEmpty) {
    return source;
  }
  final tokens = normalized.split(' ');
  if (tokens.isEmpty) {
    return source;
  }

  final replaced = <String>[...tokens];
  if (tokens.first == canonicalFamily) {
    replaced[0] = aliasFamily;
    return replaced.join(' ');
  }
  if (tokens.length > 1 &&
      tokens.first == 'baba' &&
      tokens[1] == canonicalFamily) {
    replaced[1] = aliasFamily;
    return replaced.join(' ');
  }
  return source;
}

String _readArg(List<String> args, String name, String defaultValue) {
  final prefix = '$name=';
  final hit = args.firstWhere(
    (arg) => arg.startsWith(prefix),
    orElse: () => '',
  );
  if (hit.isEmpty) {
    return defaultValue;
  }
  return hit.substring(prefix.length);
}

String _escapeRegex(String input) {
  return input.replaceAllMapped(
    RegExp(r'[\\^\$\.\|\?\*\+\(\)\[\]\{\}]'),
    (match) => '\\${match.group(0)}',
  );
}

int _countPhraseOccurrences(String text, String phrase) {
  if (text.isEmpty || phrase.isEmpty) {
    return 0;
  }
  final pattern = RegExp('\\b${_escapeRegex(phrase)}\\b');
  return pattern.allMatches(text).length;
}

List<String> _phraseTokens(String normalizedText) {
  if (normalizedText.isEmpty) {
    return const <String>[];
  }
  return normalizedText
      .split(' ')
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
}

List<String> _buildNgrams(
  List<String> tokens,
  int n, {
  int cap = _maxSectionNgrams,
}) {
  if (tokens.length < n) {
    return const <String>[];
  }
  final out = <String>[];
  final seen = <String>{};
  for (var i = 0; i <= tokens.length - n; i++) {
    final gram = tokens.sublist(i, i + n).join(' ');
    if (seen.add(gram)) {
      out.add(gram);
      if (out.length >= cap) {
        break;
      }
    }
  }
  return out;
}

Map<String, String> _extractSections(Map<String, dynamic> content) {
  String read(String key) {
    final value = content[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    return '';
  }

  final obras = read('obras').isNotEmpty ? read('obras') : read('obrasYEbbo');

  return <String, String>{
    'descripcion': read('descripcion'),
    'diceIfa': read('diceIfa'),
    'eshu': read('eshu'),
    'obras': obras,
    'ewes': read('ewes'),
    'historiasYPatakies': read('historiasYPatakies'),
    'rezoYoruba': read('rezoYoruba'),
    'suyereYoruba': read('suyereYoruba'),
  };
}

void main(List<String> args) {
  final inputPath = _readArg(args, '--input', _defaultInputPath);
  final aliasesPath = _readArg(args, '--aliases', _defaultAliasesPath);
  final topicsPath = _readArg(args, '--topics', _defaultTopicsPath);
  final outputPath = _readArg(args, '--output', _defaultOutputPath);

  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    stderr.writeln('Input JSON not found: $inputPath');
    exitCode = 1;
    return;
  }
  final aliasesFile = File(aliasesPath);
  if (!aliasesFile.existsSync()) {
    stderr.writeln('Aliases JSON not found: $aliasesPath');
    exitCode = 1;
    return;
  }

  final topics = _loadTopics(topicsPath);
  if (exitCode != 0) {
    return;
  }

  final decoded = jsonDecode(inputFile.readAsStringSync(encoding: utf8));
  if (decoded is! Map<String, dynamic>) {
    stderr.writeln('Unsupported input schema: root is not an object.');
    exitCode = 1;
    return;
  }
  final oduRaw = decoded['odu'];
  if (oduRaw is! Map) {
    stderr.writeln('Unsupported input schema: root.odu is not an object.');
    exitCode = 1;
    return;
  }

  final aliasesRaw = jsonDecode(aliasesFile.readAsStringSync(encoding: utf8));
  if (aliasesRaw is! Map<String, dynamic>) {
    stderr.writeln('Unsupported aliases schema.');
    exitCode = 1;
    return;
  }

  final entryAliases = _loadEntryAliases(aliasesRaw);
  final familyAliases = _loadFamilyAliases(aliasesRaw);

  final nameIndex = <String, Set<String>>{};
  final aliasIndex = <String, Set<String>>{};
  final keywordIndex = <String, Set<String>>{};
  final topicIndex = <String, Set<String>>{};
  final entries = <Map<String, dynamic>>[];

  void addIndexToken(Map<String, Set<String>> index, String token, String key) {
    final set = index.putIfAbsent(token, () => <String>{});
    set.add(key);
  }

  final sortedKeys = oduRaw.keys.whereType<String>().toList()..sort();
  for (final key in sortedKeys) {
    final rawEntry = oduRaw[key];
    if (rawEntry is! Map) {
      continue;
    }
    final entry = Map<String, dynamic>.from(rawEntry);
    final contentRaw = entry['content'];
    final content = contentRaw is Map<String, dynamic>
        ? contentRaw
        : contentRaw is Map
        ? Map<String, dynamic>.from(contentRaw)
        : <String, dynamic>{};

    final name =
        (content['name'] is String &&
            (content['name'] as String).trim().isNotEmpty)
        ? (content['name'] as String).trim()
        : key;

    final normalizedName = normalizeSearchTextShared(name);
    final normalizedNameTokens = tokenizeForIndex(
      normalizedName,
      removeStopWords: false,
    ).toSet().toList()..sort();
    final normalizedKey = normalizeSearchTextShared(key);

    final aliases = <String>{key, name};
    final directAliases = entryAliases[normalizedKey] ?? const [];
    aliases.addAll(directAliases);

    final nameTokens = normalizedName.split(' ');
    final familyToken = nameTokens.isNotEmpty
        ? (nameTokens.first == 'baba' && nameTokens.length > 1
              ? nameTokens[1]
              : nameTokens.first)
        : '';
    final familyAliasList = familyAliases[familyToken] ?? const [];
    for (final familyAlias in familyAliasList) {
      final aliasNormalized = normalizeSearchTextShared(familyAlias);
      final fromName = _replaceFamilyToken(
        source: name,
        canonicalFamily: familyToken,
        aliasFamily: aliasNormalized,
      );
      final fromKey = _replaceFamilyToken(
        source: key,
        canonicalFamily: familyToken,
        aliasFamily: aliasNormalized,
      );
      aliases.add(fromName);
      aliases.add(fromKey);
    }

    final normalizedAliases =
        aliases
            .map(normalizeSearchTextShared)
            .where((alias) => alias.isNotEmpty && alias != normalizedName)
            .toSet()
            .toList()
          ..sort();

    final aliasTokens = <String>{};
    for (final alias in normalizedAliases) {
      aliasTokens.addAll(tokenizeForIndex(alias, removeStopWords: false));
    }

    for (final token in normalizedNameTokens) {
      addIndexToken(nameIndex, token, key);
    }
    for (final token in aliasTokens) {
      addIndexToken(aliasIndex, token, key);
    }

    final sections = _extractSections(content);
    final sectionTokens = <String, List<String>>{};
    final sectionTokenSets = <String, List<String>>{};
    final sectionTextMap = <String, String>{};
    final sectionBigrams = <String, List<String>>{};
    final sectionTrigrams = <String, List<String>>{};

    final normalizedSections = <String, String>{};
    for (final sectionEntry in sections.entries) {
      final normalizedSection = normalizeSearchTextShared(sectionEntry.value);
      normalizedSections[sectionEntry.key] = normalizedSection;
      final tokens = tokenizeForIndex(
        sectionEntry.value,
        removeStopWords: false,
      );
      sectionTokens[sectionEntry.key] = tokens;
      final unique = tokens.toSet().toList()..sort();
      sectionTokenSets[sectionEntry.key] = unique;

      if (_phraseSections.contains(sectionEntry.key)) {
        sectionTextMap[sectionEntry.key] = normalizedSection;
        final phraseTokens = _phraseTokens(normalizedSection);
        sectionBigrams[sectionEntry.key] = _buildNgrams(phraseTokens, 2);
        sectionTrigrams[sectionEntry.key] = _buildNgrams(phraseTokens, 3);
      }
    }

    final keywordSources = <String>[...sections.values];

    final patakies = entry['patakies'];
    if (patakies is List) {
      keywordSources.addAll(patakies.whereType<String>());
    }
    final patakiesContent = entry['patakiesContent'];
    if (patakiesContent is Map) {
      for (final value in patakiesContent.values.whereType<String>()) {
        keywordSources.add(value);
      }
    }

    final keywordTokens = <String>{};
    for (final source in keywordSources) {
      keywordTokens.addAll(tokenizeForIndex(source));
    }

    for (final token in keywordTokens) {
      addIndexToken(keywordIndex, token, key);
    }

    final topicScores = <String, int>{};

    for (final topic in topics) {
      var topicScore = 0;
      for (final sectionEntry in normalizedSections.entries) {
        final sectionKey = sectionEntry.key;
        final sectionText = sectionEntry.value;
        if (sectionText.isEmpty) continue;
        final weight = _sectionWeights[sectionKey] ?? 1;
        final sectionTokenList = sectionTokens[sectionKey] ?? const <String>[];

        for (final term in topic.normalizedTerms) {
          if (term.isEmpty) continue;
          var matches = 0;
          if (term.contains(' ')) {
            matches = _countPhraseOccurrences(sectionText, term);
          } else {
            for (final token in sectionTokenList) {
              if (token == term) {
                matches++;
              }
            }
          }
          if (matches > 0) {
            topicScore += matches * weight;
          }
        }
      }
      if (topicScore > 0) {
        topicScores[topic.id] = topicScore;
      }
    }

    final topTopics = topicScores.entries.toList()
      ..sort((a, b) {
        if (a.value != b.value) {
          return b.value.compareTo(a.value);
        }
        return a.key.compareTo(b.key);
      });

    final trimmedTopTopics = topTopics.take(12).toList(growable: false);
    final trimmedTopicMap = <String, int>{
      for (final e in trimmedTopTopics) e.key: e.value,
    };

    for (final topicEntry in trimmedTopTopics) {
      addIndexToken(topicIndex, topicEntry.key, key);
    }

    final preview = _previewFromSections(content);
    entries.add({
      'key': key,
      'name': name,
      'normalizedName': normalizedName,
      'normalizedNameTokens': normalizedNameTokens,
      'aliases': normalizedAliases,
      'aliasTokens': aliasTokens.toList()..sort(),
      'preview': preview.length > 220 ? preview.substring(0, 220) : preview,
      'keywordTokens': keywordTokens.toList()..sort(),
      'topics': trimmedTopTopics.map((e) => e.key).toList(growable: false),
      'topicScoreMap': trimmedTopicMap,
      'sectionTokens': sectionTokenSets,
      'sectionTextMap': sectionTextMap,
      'sectionBigrams': sectionBigrams,
      'sectionTrigrams': sectionTrigrams,
    });
  }

  Map<String, List<String>> finalizeIndex(Map<String, Set<String>> source) {
    final out = <String, List<String>>{};
    final tokens = source.keys.toList()..sort();
    for (final token in tokens) {
      final values = source[token]!.toList()..sort();
      out[token] = values;
    }
    return out;
  }

  final payload = <String, dynamic>{
    'version': 2,
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'source': inputPath,
    'aliasesSource': aliasesPath,
    'topicsSource': topicsPath,
    'entryCount': entries.length,
    'topicsCatalog': {for (final topic in topics) topic.id: topic.toJson()},
    'entries': entries,
    'nameIndex': finalizeIndex(nameIndex),
    'aliasIndex': finalizeIndex(aliasIndex),
    'keywordIndex': finalizeIndex(keywordIndex),
    'topicIndex': finalizeIndex(topicIndex),
  };

  final outputFile = File(outputPath);
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(payload),
    encoding: utf8,
  );

  stdout.writeln('Search index generated: $outputPath');
  stdout.writeln('Entries: ${entries.length}');
  stdout.writeln('Topics catalog: ${topics.length}');
  stdout.writeln('Name tokens: ${nameIndex.length}');
  stdout.writeln('Alias tokens: ${aliasIndex.length}');
  stdout.writeln('Keyword tokens: ${keywordIndex.length}');
  stdout.writeln('Topic keys: ${topicIndex.length}');
}
