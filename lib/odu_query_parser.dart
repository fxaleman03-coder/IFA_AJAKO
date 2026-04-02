import 'odu_search_normalization.dart';

class OduTopicDefinition {
  const OduTopicDefinition({
    required this.id,
    required this.label,
    required this.synonyms,
    required this.hints,
  });

  final String id;
  final String label;
  final List<String> synonyms;
  final List<String> hints;

  List<String> get normalizedTerms => {
    normalizeSearchTextShared(id),
    normalizeSearchTextShared(label),
    ...synonyms.map(normalizeSearchTextShared),
    ...hints.map(normalizeSearchTextShared),
  }.where((e) => e.isNotEmpty).toList(growable: false);

  factory OduTopicDefinition.fromJson(String id, Map<String, dynamic> json) {
    return OduTopicDefinition(
      id: id,
      label: json['label']?.toString().trim().isNotEmpty == true
          ? json['label']!.toString().trim()
          : id,
      synonyms: (json['synonyms'] is List)
          ? (json['synonyms'] as List)
                .whereType<String>()
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList(growable: false)
          : const <String>[],
      hints: (json['hints'] is List)
          ? (json['hints'] as List)
                .whereType<String>()
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList(growable: false)
          : const <String>[],
    );
  }
}

class ParsedOduQuery {
  const ParsedOduQuery({
    required this.normalizedQuery,
    required this.tokens,
    required this.positiveTokens,
    required this.negativeTokens,
    required this.requestedTopics,
    required this.sectionBoost,
    required this.isConceptIntent,
  });

  final String normalizedQuery;
  final List<String> tokens;
  final List<String> positiveTokens;
  final List<String> negativeTokens;
  final List<String> requestedTopics;
  final String? sectionBoost;
  final bool isConceptIntent;
}

class OduQueryParser {
  const OduQueryParser({required this.topicsById});

  final Map<String, OduTopicDefinition> topicsById;

  static const Set<String> _queryScaffoldStopWords = <String>{
    'odu',
    'odoo',
    'oduo',
    'que',
    'habla',
    'hablan',
    'donde',
    'sobre',
    'con',
    'para',
    'de',
    'del',
    'al',
    'el',
    'la',
    'los',
    'las',
    'un',
    'una',
    'y',
    'en',
  };

  static const Set<String> _negativeMarkers = <String>{'sin', 'no', 'exclude'};

  static final RegExp _conceptIntentPattern = RegExp(
    r'\b(?:odu\s+)?(?:que\s+)?(?:habla(?:n)?\s+de|sobre|con|para)\b',
  );

  static final Map<String, String> _sectionIntentPatterns = <String, String>{
    r'\brezo(?:s)?\s+de\b': 'rezoYoruba',
    r'\bsuyere(?:s)?\s+de\b': 'suyereYoruba',
    r'\bpatak(?:i|ie|ies|ines)\s+de\b': 'historiasYPatakies',
    r'\bhistori(?:a|as)\s+de\b': 'historiasYPatakies',
  };

  static final Map<String, Set<String>> _sectionCueTokens =
      <String, Set<String>>{
        'rezoYoruba': {'rezo', 'rezos'},
        'suyereYoruba': {'suyere', 'suyeres'},
        'historiasYPatakies': {
          'pataki',
          'patakie',
          'patakies',
          'historia',
          'historias',
        },
        'descripcion': {'descripcion', 'descripciondelodu'},
        'diceIfa': {'dice', 'ifa'},
        'eshu': {'eshu'},
        'obras': {'obras', 'obra', 'ebo', 'ebbo'},
        'ewes': {'ewes', 'ewe', 'hierba', 'hierbas'},
      };

  ParsedOduQuery parse(String rawQuery, {String? sectionBoostOverride}) {
    final normalizedQuery = normalizeSearchTextShared(rawQuery);
    final tokens = tokenizeSearchTextShared(normalizedQuery);

    final sectionBoost =
        sectionBoostOverride ?? _detectSectionBoost(normalizedQuery);
    final negativeTokens = _extractNegativeTokens(tokens);
    final requestedTopics = _detectTopics(normalizedQuery, tokens);
    final isConceptIntent = _conceptIntentPattern.hasMatch(normalizedQuery);

    final positiveTokenSet = <String>{};
    for (final token in tokens) {
      if (_queryScaffoldStopWords.contains(token)) {
        continue;
      }
      if (_negativeMarkers.contains(token)) {
        continue;
      }
      if (negativeTokens.contains(token)) {
        continue;
      }
      if (sectionBoost != null &&
          (_sectionCueTokens[sectionBoost]?.contains(token) ?? false)) {
        continue;
      }
      positiveTokenSet.add(token);
    }

    return ParsedOduQuery(
      normalizedQuery: normalizedQuery,
      tokens: tokens,
      positiveTokens: positiveTokenSet.toList(growable: false),
      negativeTokens: negativeTokens,
      requestedTopics: requestedTopics,
      sectionBoost: sectionBoost,
      isConceptIntent: isConceptIntent,
    );
  }

  String? _detectSectionBoost(String normalizedQuery) {
    for (final entry in _sectionIntentPatterns.entries) {
      if (RegExp(entry.key).hasMatch(normalizedQuery)) {
        return entry.value;
      }
    }
    return null;
  }

  List<String> _extractNegativeTokens(List<String> tokens) {
    final negatives = <String>{};
    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (!_negativeMarkers.contains(token)) {
        continue;
      }
      if (i + 1 < tokens.length) {
        final next = tokens[i + 1];
        if (next.isNotEmpty && !_negativeMarkers.contains(next)) {
          negatives.add(next);
        }
      }
    }
    return negatives.toList(growable: false);
  }

  List<String> _detectTopics(String normalizedQuery, List<String> tokens) {
    final tokenSet = tokens.toSet();
    final matched = <String>{};
    for (final topic in topicsById.values) {
      for (final term in topic.normalizedTerms) {
        if (term.isEmpty) continue;
        if (term.contains(' ')) {
          final pattern = RegExp('\\b${_escapeRegExp(term)}\\b');
          if (pattern.hasMatch(normalizedQuery)) {
            matched.add(topic.id);
            break;
          }
        } else if (tokenSet.contains(term)) {
          matched.add(topic.id);
          break;
        }
      }
    }
    return matched.toList(growable: false);
  }

  String _escapeRegExp(String input) {
    return input.replaceAllMapped(
      RegExp(r'[\\^\$\.\|\?\*\+\(\)\[\]\{\}]'),
      (match) => '\\${match.group(0)}',
    );
  }
}
