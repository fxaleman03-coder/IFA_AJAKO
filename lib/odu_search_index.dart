import 'dart:convert';

import 'package:flutter/services.dart';

import 'odu_query_parser.dart';
import 'odu_search_normalization.dart';

String normalizeSearchText(String value) => normalizeSearchTextShared(value);

List<String> tokenizeSearchText(String value) =>
    tokenizeSearchTextShared(value);

class OduSearchEntry {
  const OduSearchEntry({
    required this.key,
    required this.name,
    required this.normalizedName,
    required this.aliases,
    required this.preview,
    required this.normalizedNameTokens,
    required this.aliasTokens,
    required this.keywordTokens,
    required this.topics,
    required this.topicScoreMap,
    required this.sectionTokens,
    required this.sectionTextMap,
    required this.sectionBigrams,
    required this.sectionTrigrams,
  });

  final String key;
  final String name;
  final String normalizedName;
  final List<String> aliases;
  final String preview;
  final Set<String> normalizedNameTokens;
  final Set<String> aliasTokens;
  final Set<String> keywordTokens;
  final List<String> topics;
  final Map<String, int> topicScoreMap;
  final Map<String, Set<String>> sectionTokens;
  final Map<String, String> sectionTextMap;
  final Map<String, Set<String>> sectionBigrams;
  final Map<String, Set<String>> sectionTrigrams;

  factory OduSearchEntry.fromJson(Map<String, dynamic> json) {
    final aliasesRaw = json['aliases'];
    final aliases = aliasesRaw is List
        ? aliasesRaw.whereType<String>().toList(growable: false)
        : const <String>[];

    Set<String> toTokenSet(Object? raw, String fallbackSource) {
      if (raw is List) {
        return raw.whereType<String>().toSet();
      }
      return tokenizeSearchTextShared(fallbackSource).toSet();
    }

    final key = json['key'] is String ? json['key'] as String : '';
    final name = json['name'] is String ? json['name'] as String : '';
    final normalizedName = json['normalizedName'] is String
        ? json['normalizedName'] as String
        : normalizeSearchTextShared(name);

    final sectionTokensRaw = json['sectionTokens'];
    final sectionTokens = <String, Set<String>>{};
    if (sectionTokensRaw is Map) {
      sectionTokensRaw.forEach((key, value) {
        if (key is! String) return;
        sectionTokens[key] = (value is List)
            ? value.whereType<String>().toSet()
            : <String>{};
      });
    }

    final sectionTextMapRaw = json['sectionTextMap'];
    final sectionTextMap = <String, String>{};
    if (sectionTextMapRaw is Map) {
      sectionTextMapRaw.forEach((key, value) {
        if (key is! String || value is! String) return;
        sectionTextMap[key] = value;
      });
    }

    Map<String, Set<String>> parseSectionGramMap(Object? raw) {
      final out = <String, Set<String>>{};
      if (raw is! Map) return out;
      raw.forEach((key, value) {
        if (key is! String || value is! List) return;
        out[key] = value.whereType<String>().toSet();
      });
      return out;
    }

    final sectionBigrams = parseSectionGramMap(json['sectionBigrams']);
    final sectionTrigrams = parseSectionGramMap(json['sectionTrigrams']);

    final topicScoreRaw = json['topicScoreMap'];
    final topicScoreMap = <String, int>{};
    if (topicScoreRaw is Map) {
      topicScoreRaw.forEach((key, value) {
        if (key is! String) return;
        if (value is int) {
          topicScoreMap[key] = value;
        } else if (value is num) {
          topicScoreMap[key] = value.toInt();
        }
      });
    }

    final topicsRaw = json['topics'];
    final topics = topicsRaw is List
        ? topicsRaw.whereType<String>().toList(growable: false)
        : const <String>[];

    return OduSearchEntry(
      key: key,
      name: name,
      normalizedName: normalizedName,
      aliases: aliases,
      preview: json['preview'] is String ? json['preview'] as String : '',
      normalizedNameTokens: toTokenSet(
        json['normalizedNameTokens'],
        normalizedName,
      ),
      aliasTokens: toTokenSet(json['aliasTokens'], aliases.join(' ')),
      keywordTokens: toTokenSet(
        json['keywordTokens'],
        json['preview']?.toString() ?? '',
      ),
      topics: topics,
      topicScoreMap: topicScoreMap,
      sectionTokens: sectionTokens,
      sectionTextMap: sectionTextMap,
      sectionBigrams: sectionBigrams,
      sectionTrigrams: sectionTrigrams,
    );
  }
}

class OduScoredResult {
  const OduScoredResult({
    required this.entry,
    required this.score,
    this.why,
    this.topicHits = const <String, int>{},
    this.matchedTokens = const <String>[],
    this.matchedSections = const <String>[],
    this.matchedPhraseTypes = const <String>[],
  });

  final OduSearchEntry entry;
  final int score;
  final String? why;
  final Map<String, int> topicHits;
  final List<String> matchedTokens;
  final List<String> matchedSections;
  final List<String> matchedPhraseTypes;
}

class OduSearchResults {
  const OduSearchResults({
    required this.nameMatches,
    required this.aliasMatches,
    required this.topicMatches,
    required this.keywordMatches,
    required this.resolvedTopics,
    required this.highlightTokens,
    this.sectionBoost,
  });

  final List<OduScoredResult> nameMatches;
  final List<OduScoredResult> aliasMatches;
  final List<OduScoredResult> topicMatches;
  final List<OduScoredResult> keywordMatches;
  final List<OduTopicDefinition> resolvedTopics;
  final List<String> highlightTokens;
  final String? sectionBoost;

  bool get isEmpty =>
      nameMatches.isEmpty &&
      aliasMatches.isEmpty &&
      topicMatches.isEmpty &&
      keywordMatches.isEmpty;
}

class OduSearchIndex {
  const OduSearchIndex({
    required this.entriesByKey,
    required this.nameIndex,
    required this.aliasIndex,
    required this.keywordIndex,
    required this.topicIndex,
    required this.topicsById,
  });

  final Map<String, OduSearchEntry> entriesByKey;
  final Map<String, Set<String>> nameIndex;
  final Map<String, Set<String>> aliasIndex;
  final Map<String, Set<String>> keywordIndex;
  final Map<String, Set<String>> topicIndex;
  final Map<String, OduTopicDefinition> topicsById;

  static const Set<String> _genericBoosterTokens = <String>{
    'eshu',
    'ifa',
    'orunmila',
    'odu',
    'orisha',
    'elegba',
    'eleggua',
    'elegua',
  };
  static const int _maxGroupResults = 40;
  static const _phrasePrioritySections = <String>{
    'eshu',
    'descripcion',
    'diceIfa',
    'historiasYPatakies',
    'obras',
  };

  static Future<OduSearchIndex> load({
    String assetPath = 'assets/search_index.json',
  }) async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Search index asset has invalid JSON schema.');
    }
    return OduSearchIndex.fromJson(decoded);
  }

  factory OduSearchIndex.fromJson(Map<String, dynamic> json) {
    final entries = <String, OduSearchEntry>{};
    final entriesRaw = json['entries'];
    if (entriesRaw is List) {
      for (final item in entriesRaw) {
        if (item is! Map) continue;
        final entry = OduSearchEntry.fromJson(Map<String, dynamic>.from(item));
        if (entry.key.isEmpty) continue;
        entries[entry.key] = entry;
      }
    }

    Map<String, Set<String>> parseIndex(Object? rawIndex) {
      final out = <String, Set<String>>{};
      if (rawIndex is! Map) {
        return out;
      }
      rawIndex.forEach((key, value) {
        if (key is! String || value is! List) return;
        final values = value.whereType<String>().toSet();
        out[key] = values;
      });
      return out;
    }

    final topicsById = <String, OduTopicDefinition>{};
    final topicsRaw = json['topicsCatalog'];
    if (topicsRaw is Map) {
      topicsRaw.forEach((key, value) {
        if (key is! String || value is! Map) return;
        final topic = OduTopicDefinition.fromJson(
          key,
          Map<String, dynamic>.from(value),
        );
        topicsById[key] = topic;
      });
    }

    return OduSearchIndex(
      entriesByKey: entries,
      nameIndex: parseIndex(json['nameIndex']),
      aliasIndex: parseIndex(json['aliasIndex']),
      keywordIndex: parseIndex(json['keywordIndex']),
      topicIndex: parseIndex(json['topicIndex']),
      topicsById: topicsById,
    );
  }

  String _primaryNameToken(String normalizedName) {
    final tokens = tokenizeSearchTextShared(normalizedName);
    if (tokens.isEmpty) {
      return '';
    }
    if (tokens.first == 'baba' && tokens.length > 1) {
      return tokens[1];
    }
    return tokens.first;
  }

  int _levenshteinDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final prev = List<int>.generate(b.length + 1, (i) => i);
    final curr = List<int>.filled(b.length + 1, 0);
    for (var i = 1; i <= a.length; i++) {
      curr[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        final deletion = prev[j] + 1;
        final insertion = curr[j - 1] + 1;
        final substitution = prev[j - 1] + cost;
        var best = deletion < insertion ? deletion : insertion;
        if (substitution < best) best = substitution;
        curr[j] = best;
      }
      for (var j = 0; j <= b.length; j++) {
        prev[j] = curr[j];
      }
    }
    return prev[b.length];
  }

  bool _isAliasNearToken(String queryToken, String candidate) {
    if (queryToken == candidate) {
      return true;
    }
    if (candidate.startsWith(queryToken) || queryToken.startsWith(candidate)) {
      return true;
    }
    if (queryToken.length >= 5 && candidate.length >= 5) {
      final lengthDelta = (queryToken.length - candidate.length).abs();
      if (lengthDelta <= 1 &&
          _levenshteinDistance(queryToken, candidate) <= 1) {
        return true;
      }
    }
    return false;
  }

  List<Set<String>> _buildTokenGroups(List<String> queryTokens) {
    final groups = queryTokens.map((token) => <String>{token}).toList();
    if (groups.isEmpty) {
      return const [];
    }
    for (var i = 0; i < queryTokens.length; i++) {
      final token = queryTokens[i];
      final variants = groups[i];
      for (final entry in entriesByKey.values) {
        final matchedAliasTokens = entry.aliasTokens
            .where((candidate) => _isAliasNearToken(token, candidate))
            .toList(growable: false);
        if (matchedAliasTokens.isEmpty) {
          continue;
        }
        variants.addAll(matchedAliasTokens);
        final familyToken = _primaryNameToken(entry.normalizedName);
        if (familyToken.length >= 4) {
          variants.add(familyToken);
        }
      }
    }
    return groups;
  }

  Set<String> _candidatesFromIndexByGroups(
    Map<String, Set<String>> index,
    List<Set<String>> groups,
  ) {
    if (groups.isEmpty) {
      return const <String>{};
    }
    Set<String>? accumulator;
    for (final group in groups) {
      final groupKeys = <String>{};
      for (final variant in group) {
        final hits = index[variant];
        if (hits != null) {
          groupKeys.addAll(hits);
        }
      }
      if (groupKeys.isEmpty) {
        return const <String>{};
      }
      accumulator = accumulator == null
          ? groupKeys
          : accumulator.intersection(groupKeys);
      if (accumulator.isEmpty) {
        return const <String>{};
      }
    }
    return accumulator ?? const <String>{};
  }

  Set<String> _candidatesFromTopics(List<String> topicIds) {
    if (topicIds.isEmpty) {
      return const <String>{};
    }
    Set<String>? accumulator;
    for (final topicId in topicIds) {
      final hits = topicIndex[topicId];
      if (hits == null || hits.isEmpty) {
        return const <String>{};
      }
      accumulator = accumulator == null
          ? <String>{...hits}
          : accumulator.intersection(hits);
      if (accumulator.isEmpty) {
        return const <String>{};
      }
    }
    return accumulator ?? const <String>{};
  }

  bool _matchesTokenGroups(
    Set<String> haystackTokens,
    List<Set<String>> groups,
  ) {
    if (groups.isEmpty) {
      return false;
    }
    for (final group in groups) {
      var groupMatched = false;
      for (final variant in group) {
        if (haystackTokens.contains(variant)) {
          groupMatched = true;
          break;
        }
      }
      if (!groupMatched) {
        return false;
      }
    }
    return true;
  }

  ({List<String> required, List<String> generic}) _partitionQueryTokens(
    List<String> tokens,
  ) {
    final required = <String>[];
    final generic = <String>[];
    for (final token in tokens) {
      if (_genericBoosterTokens.contains(token)) {
        generic.add(token);
      } else {
        required.add(token);
      }
    }
    return (required: required, generic: generic);
  }

  Set<String> _entryAllTokens(OduSearchEntry entry) {
    return <String>{
      ...entry.normalizedNameTokens,
      ...entry.aliasTokens,
      ...entry.keywordTokens,
    };
  }

  List<String> _uniquePreserveOrder(Iterable<String> tokens) {
    final seen = <String>{};
    final out = <String>[];
    for (final token in tokens) {
      if (token.isEmpty) continue;
      if (seen.add(token)) {
        out.add(token);
      }
    }
    return out;
  }

  List<String> _queryNgrams(List<String> tokens, int n) {
    if (tokens.length < n) {
      return const <String>[];
    }
    final out = <String>[];
    for (var i = 0; i <= tokens.length - n; i++) {
      out.add(tokens.sublist(i, i + n).join(' '));
    }
    return out;
  }

  String _escapeRegExp(String input) {
    return input.replaceAllMapped(
      RegExp(r'[\\^\$\.\|\?\*\+\(\)\[\]\{\}]'),
      (match) => '\\${match.group(0)}',
    );
  }

  bool _hasNearBigram(String sectionText, String first, String second) {
    if (sectionText.isEmpty || first.isEmpty || second.isEmpty) {
      return false;
    }
    final pattern = RegExp(
      '\\b${_escapeRegExp(first)}\\b(?:\\s+\\w+){0,2}\\s+\\b${_escapeRegExp(second)}\\b',
    );
    return pattern.hasMatch(sectionText);
  }

  ({
    int score,
    Set<String> sections,
    Set<String> tokens,
    Set<String> phraseTypes,
  })
  _phraseScore(
    OduSearchEntry entry,
    ParsedOduQuery parsed,
    List<String> requiredTokens,
    List<String> genericTokens,
  ) {
    final phraseTokens = _uniquePreserveOrder(
      parsed.positiveTokens.where(
        (token) =>
            requiredTokens.contains(token) || genericTokens.contains(token),
      ),
    );
    if (phraseTokens.length < 2) {
      return (
        score: 0,
        sections: <String>{},
        tokens: <String>{},
        phraseTypes: <String>{},
      );
    }

    final targetFullPhrase = phraseTokens.join(' ');
    final bigrams = <String>{
      ..._queryNgrams(phraseTokens, 2),
      ..._queryNgrams(requiredTokens, 2),
    };
    final trigrams = <String>{
      ..._queryNgrams(phraseTokens, 3),
      ..._queryNgrams(requiredTokens, 3),
    };

    var score = 0;
    final hitSections = <String>{};
    final hitTokens = <String>{};
    final hitTypes = <String>{};

    for (final section in _phrasePrioritySections) {
      final sectionText = entry.sectionTextMap[section] ?? '';
      if (sectionText.isEmpty) continue;

      var sectionHadPhraseHit = false;

      if (targetFullPhrase.split(' ').length >= 2 &&
          sectionText.contains(targetFullPhrase)) {
        score += 120;
        sectionHadPhraseHit = true;
        hitSections.add(section);
        hitTokens.add(targetFullPhrase);
        hitTypes.add('substring');
      }

      final sectionBigrams = entry.sectionBigrams[section] ?? const <String>{};
      for (final gram in bigrams) {
        if (sectionBigrams.contains(gram)) {
          score += 60;
          sectionHadPhraseHit = true;
          hitSections.add(section);
          hitTokens.add(gram);
          hitTypes.add('bigram');
        }
      }

      // Near-phrase fallback for two-word phrases with light spacing/noise.
      for (final gram in bigrams) {
        if (sectionBigrams.contains(gram)) {
          continue;
        }
        final parts = gram.split(' ');
        if (parts.length != 2) {
          continue;
        }
        if (_hasNearBigram(sectionText, parts[0], parts[1])) {
          score += 35;
          sectionHadPhraseHit = true;
          hitSections.add(section);
          hitTokens.add(gram);
          hitTypes.add('near');
        }
      }

      final sectionTrigrams =
          entry.sectionTrigrams[section] ?? const <String>{};
      for (final gram in trigrams) {
        if (sectionTrigrams.contains(gram)) {
          score += 90;
          sectionHadPhraseHit = true;
          hitSections.add(section);
          hitTokens.add(gram);
          hitTypes.add('trigram');
        }
      }

      if (sectionHadPhraseHit && section == 'eshu') {
        score += 40;
      } else if (sectionHadPhraseHit &&
          (section == 'descripcion' || section == 'diceIfa')) {
        score += 20;
      }
    }

    return (
      score: score,
      sections: hitSections,
      tokens: hitTokens,
      phraseTypes: hitTypes,
    );
  }

  int _genericBoosterScore(OduSearchEntry entry, List<String> genericTokens) {
    if (genericTokens.isEmpty) {
      return 0;
    }
    final all = _entryAllTokens(entry);
    var hits = 0;
    for (final token in genericTokens) {
      if (all.contains(token)) {
        hits++;
      }
    }
    if (hits == 0) {
      return 0;
    }
    return hits * 4;
  }

  int _nameScore(
    OduSearchEntry entry,
    ParsedOduQuery parsed,
    List<Set<String>> tokenGroups,
  ) {
    if (tokenGroups.isEmpty ||
        !_matchesTokenGroups(entry.normalizedNameTokens, tokenGroups)) {
      return 0;
    }
    var score = 0;
    if (entry.normalizedName == parsed.normalizedQuery) {
      score = 100;
    } else if (entry.normalizedName.contains(parsed.normalizedQuery)) {
      score = 70;
    }
    if (score > 0 &&
        hasWordStartMatch(entry.normalizedName, parsed.positiveTokens)) {
      score += 10;
    }
    return score;
  }

  int _aliasScore(
    OduSearchEntry entry,
    ParsedOduQuery parsed,
    List<Set<String>> tokenGroups,
  ) {
    if (tokenGroups.isEmpty) {
      return 0;
    }

    var best = 0;
    var hasWordStart = false;

    for (final alias in entry.aliases) {
      final normalizedAlias = normalizeSearchTextShared(alias);
      final aliasTokens = tokenizeSearchTextShared(normalizedAlias).toSet();
      if (!_matchesTokenGroups(aliasTokens, tokenGroups)) {
        continue;
      }

      var current = 0;
      if (normalizedAlias == parsed.normalizedQuery) {
        current = 60;
      } else if (normalizedAlias.contains(parsed.normalizedQuery)) {
        current = 40;
      } else {
        for (final group in tokenGroups) {
          final exactVariant = group.any(
            (variant) => normalizedAlias == variant,
          );
          if (exactVariant) {
            current = 60;
            break;
          }
          final containsVariant = group.any(
            (variant) =>
                variant.length >= 3 && normalizedAlias.contains(variant),
          );
          if (containsVariant && current < 40) {
            current = 40;
          }
        }
      }

      if (current > 0 &&
          hasWordStartMatch(normalizedAlias, parsed.positiveTokens)) {
        hasWordStart = true;
      }
      if (current > best) {
        best = current;
      }
    }

    if (best == 0) {
      return 0;
    }
    return best + (hasWordStart ? 10 : 0);
  }

  int _keywordScore(
    OduSearchEntry entry,
    ParsedOduQuery parsed,
    List<Set<String>> tokenGroups,
  ) {
    if (tokenGroups.isEmpty ||
        !_matchesTokenGroups(entry.keywordTokens, tokenGroups)) {
      return 0;
    }
    var score = 15;
    final normalizedPreview = normalizeSearchTextShared(entry.preview);
    if (normalizedPreview.contains(parsed.normalizedQuery) ||
        hasWordStartMatch(normalizedPreview, parsed.positiveTokens)) {
      score += 10;
    }
    return score;
  }

  ({int score, Map<String, int> hits}) _topicScore(
    OduSearchEntry entry,
    ParsedOduQuery parsed,
  ) {
    final hits = <String, int>{};
    for (final topicId in parsed.requestedTopics) {
      final topicScore = entry.topicScoreMap[topicId] ?? 0;
      if (topicScore > 0) {
        hits[topicId] = topicScore;
      }
    }
    if (hits.isEmpty) {
      return (score: 0, hits: const <String, int>{});
    }

    var score = hits.values.fold<int>(0, (sum, value) => sum + value) * 4;
    if (parsed.isConceptIntent &&
        parsed.requestedTopics.any(
          (topicId) => entry.topics.take(3).contains(topicId),
        )) {
      score += 30;
    }
    return (score: score, hits: hits);
  }

  int _sectionBoostScore(
    OduSearchEntry entry,
    ParsedOduQuery parsed,
    List<Set<String>> tokenGroups,
  ) {
    final section = parsed.sectionBoost;
    if (section == null || tokenGroups.isEmpty) {
      return 0;
    }
    final tokens = entry.sectionTokens[section];
    if (tokens == null || tokens.isEmpty) {
      return 0;
    }
    return _matchesTokenGroups(tokens, tokenGroups) ? 20 : 0;
  }

  bool _containsNegativeToken(
    OduSearchEntry entry,
    List<String> negativeTokens,
  ) {
    if (negativeTokens.isEmpty) {
      return false;
    }
    for (final token in negativeTokens) {
      if (entry.keywordTokens.contains(token)) {
        return true;
      }
      for (final section in entry.sectionTokens.values) {
        if (section.contains(token)) {
          return true;
        }
      }
    }
    return false;
  }

  String _buildTopicWhy(Map<String, int> topicHits) {
    final sorted = topicHits.entries.toList()
      ..sort((a, b) {
        if (a.value != b.value) {
          return b.value.compareTo(a.value);
        }
        return a.key.compareTo(b.key);
      });

    final parts = sorted
        .take(2)
        .map((entry) {
          final label = topicsById[entry.key]?.label ?? entry.key;
          return '$label (score ${entry.value})';
        })
        .toList(growable: false);

    return 'Topic: ${parts.join(', ')}';
  }

  List<OduScoredResult> _sortByScoreThenName(
    Iterable<OduScoredResult> results,
  ) {
    final list = results.toList();
    list.sort((a, b) {
      if (a.score != b.score) {
        return b.score.compareTo(a.score);
      }
      return a.entry.name.compareTo(b.entry.name);
    });
    return list;
  }

  OduSearchResults search(String query, {String? sectionBoostOverride}) {
    final parser = OduQueryParser(topicsById: topicsById);
    final parsed = parser.parse(
      query,
      sectionBoostOverride: sectionBoostOverride,
    );

    final emptyResult = OduSearchResults(
      nameMatches: const <OduScoredResult>[],
      aliasMatches: const <OduScoredResult>[],
      topicMatches: const <OduScoredResult>[],
      keywordMatches: const <OduScoredResult>[],
      resolvedTopics: parsed.requestedTopics
          .map((id) => topicsById[id])
          .whereType<OduTopicDefinition>()
          .toList(growable: false),
      highlightTokens: parsed.positiveTokens,
      sectionBoost: parsed.sectionBoost,
    );

    if (parsed.normalizedQuery.isEmpty) {
      return emptyResult;
    }

    if (parsed.positiveTokens.isEmpty && parsed.requestedTopics.isEmpty) {
      return emptyResult;
    }

    final tokenPartition = _partitionQueryTokens(parsed.positiveTokens);
    final nonGenericTokens = _uniquePreserveOrder(tokenPartition.required);
    final genericTokens = _uniquePreserveOrder(tokenPartition.generic);

    List<String> requiredTokens;
    if (parsed.positiveTokens.length > 1 && nonGenericTokens.isNotEmpty) {
      // Multi-token query: enforce rare/non-generic tokens, generic tokens are boosters.
      requiredTokens = nonGenericTokens;
    } else if (nonGenericTokens.isNotEmpty) {
      requiredTokens = nonGenericTokens;
    } else {
      // Generic-only query fallback (bounded by existing indexed candidates).
      requiredTokens = parsed.positiveTokens;
    }

    final tokenGroups = _buildTokenGroups(requiredTokens);

    final nameCandidates = _candidatesFromIndexByGroups(nameIndex, tokenGroups);
    final aliasCandidates = _candidatesFromIndexByGroups(
      aliasIndex,
      tokenGroups,
    );
    final keywordCandidates = _candidatesFromIndexByGroups(
      keywordIndex,
      tokenGroups,
    );
    final topicCandidates = _candidatesFromTopics(parsed.requestedTopics);

    final mutableNameCandidates = <String>{...nameCandidates};
    final mutableAliasCandidates = <String>{...aliasCandidates};
    final mutableKeywordCandidates = <String>{...keywordCandidates};

    if (tokenGroups.isNotEmpty) {
      for (final entry in entriesByKey.values) {
        if (_matchesTokenGroups(entry.normalizedNameTokens, tokenGroups)) {
          mutableNameCandidates.add(entry.key);
        }
        if (_matchesTokenGroups(entry.aliasTokens, tokenGroups)) {
          mutableAliasCandidates.add(entry.key);
        }
        if (_matchesTokenGroups(entry.keywordTokens, tokenGroups)) {
          mutableKeywordCandidates.add(entry.key);
        }
      }
    }

    final allCandidates = <String>{
      ...mutableNameCandidates,
      ...mutableAliasCandidates,
      ...mutableKeywordCandidates,
      ...topicCandidates,
    };

    if (allCandidates.isEmpty) {
      return emptyResult;
    }

    final nameScored = <OduScoredResult>[];
    final aliasScored = <OduScoredResult>[];
    final topicScored = <OduScoredResult>[];
    final keywordScored = <OduScoredResult>[];

    for (final key in allCandidates) {
      final entry = entriesByKey[key];
      if (entry == null) continue;

      if (_containsNegativeToken(entry, parsed.negativeTokens)) {
        continue;
      }

      final allEntryTokens = _entryAllTokens(entry);
      if (parsed.positiveTokens.length > 1 && nonGenericTokens.isNotEmpty) {
        // Rare-token requirement: all non-generic tokens must match.
        if (!_matchesTokenGroups(allEntryTokens, tokenGroups)) {
          continue;
        }
      }

      final nameScore = _nameScore(entry, parsed, tokenGroups);
      final aliasScore = _aliasScore(entry, parsed, tokenGroups);
      final keywordScore = _keywordScore(entry, parsed, tokenGroups);
      final topicEval = _topicScore(entry, parsed);
      final sectionBoost = _sectionBoostScore(entry, parsed, tokenGroups);
      final phraseEval = _phraseScore(
        entry,
        parsed,
        requiredTokens,
        genericTokens,
      );
      final genericBoost = _genericBoosterScore(entry, genericTokens);

      final base = [
        nameScore,
        aliasScore,
        keywordScore,
        topicEval.score,
        phraseEval.score,
      ].fold<int>(0, (best, value) => value > best ? value : best);
      if (base == 0 && sectionBoost == 0 && genericBoost == 0) {
        continue;
      }

      final totalScore = base + sectionBoost + genericBoost;
      final topicWhy = topicEval.hits.isEmpty
          ? null
          : _buildTopicWhy(topicEval.hits);

      final matchedTokens = <String>{
        ...requiredTokens.where(allEntryTokens.contains),
        ...genericTokens.where(allEntryTokens.contains),
        ...phraseEval.tokens,
      }.toList(growable: false)..sort();

      final matchedSections = <String>{
        ...phraseEval.sections,
        if (sectionBoost > 0 && parsed.sectionBoost != null)
          parsed.sectionBoost!,
      }.toList(growable: false)..sort();

      final matchedPhraseTypes = phraseEval.phraseTypes.toList(growable: false)
        ..sort();

      if (nameScore > 0) {
        nameScored.add(
          OduScoredResult(
            entry: entry,
            score: totalScore,
            why: topicWhy,
            topicHits: topicEval.hits,
            matchedTokens: matchedTokens,
            matchedSections: matchedSections,
            matchedPhraseTypes: matchedPhraseTypes,
          ),
        );
      } else if (aliasScore > 0) {
        aliasScored.add(
          OduScoredResult(
            entry: entry,
            score: totalScore,
            why: topicWhy,
            topicHits: topicEval.hits,
            matchedTokens: matchedTokens,
            matchedSections: matchedSections,
            matchedPhraseTypes: matchedPhraseTypes,
          ),
        );
      } else if (topicEval.score > 0) {
        topicScored.add(
          OduScoredResult(
            entry: entry,
            score: totalScore,
            why: topicWhy,
            topicHits: topicEval.hits,
            matchedTokens: matchedTokens,
            matchedSections: matchedSections,
            matchedPhraseTypes: matchedPhraseTypes,
          ),
        );
      } else if (keywordScore > 0 || phraseEval.score > 0 || genericBoost > 0) {
        keywordScored.add(
          OduScoredResult(
            entry: entry,
            score: totalScore,
            why: topicWhy,
            topicHits: topicEval.hits,
            matchedTokens: matchedTokens,
            matchedSections: matchedSections,
            matchedPhraseTypes: matchedPhraseTypes,
          ),
        );
      }
    }

    final sortedName = _sortByScoreThenName(nameScored);
    final sortedAlias = _sortByScoreThenName(aliasScored);
    final sortedTopic = _sortByScoreThenName(topicScored);
    final sortedKeyword = _sortByScoreThenName(keywordScored);

    final assigned = <String>{};
    final dedupName = sortedName
        .where((item) => assigned.add(item.entry.key))
        .take(_maxGroupResults)
        .toList(growable: false);
    final dedupAlias = sortedAlias
        .where((item) => assigned.add(item.entry.key))
        .take(_maxGroupResults)
        .toList(growable: false);
    final dedupTopic = sortedTopic
        .where((item) => assigned.add(item.entry.key))
        .take(_maxGroupResults)
        .toList(growable: false);
    final dedupKeyword = sortedKeyword
        .where((item) => assigned.add(item.entry.key))
        .take(_maxGroupResults)
        .toList(growable: false);

    final highlightTokens = <String>{...parsed.positiveTokens};
    for (final topicId in parsed.requestedTopics) {
      final topic = topicsById[topicId];
      if (topic == null) continue;
      highlightTokens.addAll(tokenizeSearchTextShared(topic.label));
      for (final synonym in topic.synonyms) {
        highlightTokens.addAll(tokenizeSearchTextShared(synonym));
      }
    }

    return OduSearchResults(
      nameMatches: dedupName,
      aliasMatches: dedupAlias,
      topicMatches: dedupTopic,
      keywordMatches: dedupKeyword,
      resolvedTopics: parsed.requestedTopics
          .map((id) => topicsById[id])
          .whereType<OduTopicDefinition>()
          .toList(growable: false),
      highlightTokens: highlightTokens.toList(growable: false),
      sectionBoost: parsed.sectionBoost,
    );
  }
}
