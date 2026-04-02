import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'odu_models.dart';

const String _usePatchedOduContentRaw = String.fromEnvironment(
  'USE_PATCHED_ODU_CONTENT',
  defaultValue: 'auto',
);
final bool usePatchedOduContent = _resolveUsePatchedContentMode(
  _usePatchedOduContentRaw,
);
const String _useOduContentV2Raw = String.fromEnvironment(
  'USE_ODU_CONTENT_V2',
  defaultValue: '0',
);
final bool useOduContentV2 = _parseBoolDefine(_useOduContentV2Raw);
const String patchedOduAssetPath = String.fromEnvironment(
  'PATCHED_ODU_ASSET_PATH',
  defaultValue: 'assets/odu_content_patched.json',
);
const String oduContentV2AssetPath = String.fromEnvironment(
  'ODU_CONTENT_V2_ASSET_PATH',
  defaultValue: 'assets/odu_content_v2_ready.json',
);
const String oduKeyCompatMapAssetPath = String.fromEnvironment(
  'ODU_KEY_COMPAT_MAP_ASSET_PATH',
  defaultValue: 'assets/odu_key_compat_map.json',
);
bool _didPrintOjuaniPokonDebug = false;

class OduContentRepository {
  OduContentRepository._();

  static final OduContentRepository instance = OduContentRepository._();

  Map<String, OduData>? _cache;
  Map<String, String> _v2CompatMap = const <String, String>{};
  Future<void>? _loading;

  bool get isLoaded => _cache != null;

  Future<void> preload() => _ensureLoaded();

  Future<OduData> getByKey(
    String normalizedKey, {
    required String fallbackName,
  }) async {
    await _ensureLoaded();
    final cache = _cache;
    if (cache == null) {
      return OduData.empty(fallbackName);
    }

    final pending = <String>[
      _normalizeLookupKey(normalizedKey),
      _normalizeLookupKey(fallbackName),
    ];
    final originalLookupKey = _normalizeLookupKey(
      normalizedKey.isNotEmpty ? normalizedKey : fallbackName,
    );
    final visited = <String>{};

    while (pending.isNotEmpty) {
      final key = _normalizeLookupKey(pending.removeLast());
      if (!visited.add(key)) {
        continue;
      }

      final value = cache[key];
      if (value != null) {
        return value;
      }

      if (useOduContentV2) {
        final compatResolved = _v2CompatMap[key];
        if (compatResolved != null && compatResolved.isNotEmpty) {
          if (kDebugMode) {
            debugPrint(
              '[ODU][V2_COMPAT] original="$originalLookupKey" '
              'lookup="$key" resolved="$compatResolved"',
            );
          }
          pending.add(compatResolved);
        }
      }

      final alias = _legacyOduAliases[key];
      if (alias != null) {
        pending.add(alias);
      }
      pending.addAll(_alternateLookupKeys(key));
    }

    return OduData.empty(fallbackName);
  }

  Future<void> _ensureLoaded() async {
    if (_cache != null) {
      return;
    }
    _loading ??= _load();
    await _loading;
  }

  Future<void> _load() async {
    try {
      final fallbackPreferredPath = usePatchedOduContent
          ? patchedOduAssetPath
          : 'assets/odu_content.json';
      final preferredAssetPath = useOduContentV2
          ? oduContentV2AssetPath
          : fallbackPreferredPath;
      final loadedAsset = await _loadOduAssetWithFallback(
        preferredAssetPath,
        fallbackAssetPath: fallbackPreferredPath,
      );
      _v2CompatMap = useOduContentV2 ? await _loadV2CompatMap() : const {};
      debugPrint(
        '[ODU] Using asset: ${loadedAsset.pathUsed} '
        '(v2=$useOduContentV2, patched=$usePatchedOduContent)',
      );
      final decoded = await compute(_decodeOduJson, loadedAsset.raw);
      if (kDebugMode) {
        debugPrint('[ODU] Resolved asset path: ${loadedAsset.pathUsed}');
        debugPrint('[ODU] v2 mode active: $useOduContentV2');
        _debugPrintOjuaniPokonCheckOnce(
          decoded,
          resolvedAssetPath: loadedAsset.pathUsed,
        );
      }
      final oduMap = decoded['odu'];
      final result = <String, OduData>{};
      if (oduMap is Map) {
        oduMap.forEach((key, value) {
          if (key is! String) {
            return;
          }
          final normalizedKey = _normalizeLookupKey(key);
          if (value is Map<String, dynamic>) {
            final parsed = OduData.fromJson(
              value,
              fallbackName: _fallbackNameFrom(value, key),
            );
            result[normalizedKey] = parsed;
            final fallbackName = _fallbackNameFrom(value, key);
            result.putIfAbsent(_normalizeLookupKey(fallbackName), () => parsed);
          } else if (value is Map) {
            final parsed = OduData.fromJson(
              Map<String, dynamic>.from(value),
              fallbackName: _fallbackNameFrom(value, key),
            );
            result[normalizedKey] = parsed;
            final fallbackName = _fallbackNameFrom(value, key);
            result.putIfAbsent(_normalizeLookupKey(fallbackName), () => parsed);
          }
        });
      }
      if (kDebugMode) {
        _debugPrintOkanaYabileCheck(result);
        if (useOduContentV2) {
          debugPrint('[ODU][V2_COMPAT] loaded aliases: ${_v2CompatMap.length}');
        }
      }
      _cache = result;
      debugPrint('[ODU] Total Odù loaded: ${result.length}');
    } catch (_) {
      _cache = <String, OduData>{};
      _v2CompatMap = const <String, String>{};
    }
  }
}

Future<Map<String, String>> _loadV2CompatMap() async {
  try {
    final raw = await rootBundle.loadString(oduKeyCompatMapAssetPath);
    final decoded = json.decode(raw);
    if (decoded is! Map) {
      return const <String, String>{};
    }
    final map = <String, String>{};
    decoded.forEach((key, value) {
      if (key is! String || value is! String) {
        return;
      }
      final normalizedFrom = _normalizeLookupKey(key);
      final normalizedTo = _normalizeLookupKey(value);
      if (normalizedFrom.isEmpty || normalizedTo.isEmpty) {
        return;
      }
      map[normalizedFrom] = normalizedTo;
    });
    return map;
  } catch (_) {
    debugPrint(
      'Could not load Odù compatibility map "$oduKeyCompatMapAssetPath".',
    );
    return const <String, String>{};
  }
}

Future<({String raw, String pathUsed})> _loadOduAssetWithFallback(
  String preferredAssetPath,
  {
    String fallbackAssetPath = 'assets/odu_content.json',
  }
) async {
  if (preferredAssetPath == fallbackAssetPath) {
    final raw = await rootBundle.loadString(preferredAssetPath);
    return (raw: raw, pathUsed: preferredAssetPath);
  }
  try {
    final raw = await rootBundle.loadString(preferredAssetPath);
    return (raw: raw, pathUsed: preferredAssetPath);
  } catch (_) {
    debugPrint(
      'Could not load Odù asset "$preferredAssetPath". Falling back to $fallbackAssetPath.',
    );
    final raw = await rootBundle.loadString(fallbackAssetPath);
    return (raw: raw, pathUsed: fallbackAssetPath);
  }
}

String _normalizeLookupKey(String value) =>
    value.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();

bool _parseBoolDefine(String raw) {
  final normalized = raw.trim().toLowerCase();
  return normalized == '1' ||
      normalized == 'true' ||
      normalized == 'yes' ||
      normalized == 'on';
}

bool _resolveUsePatchedContentMode(String raw) {
  final normalized = raw.trim().toLowerCase();
  if (normalized == 'auto') {
    return kDebugMode;
  }
  return _parseBoolDefine(normalized);
}

void _debugPrintOkanaYabileCheck(Map<String, OduData> cache) {
  final check = cache[_normalizeLookupKey('OKANA YABILE')];
  if (check == null) {
    debugPrint('[ODU][OKANA YABILE] entry not found in loaded asset.');
    return;
  }
  final nace = check.content.nace;
  final descripcion = check.content.descripcion;
  final marker = RegExp(r'AQU[ÍI]', caseSensitive: false);
  final naceHasAqui = marker.hasMatch(nace);
  final descripcionHasAqui = marker.hasMatch(descripcion);
  debugPrint(
    '[ODU][OKANA YABILE] nace[0:60]="${_debugSlice(nace, 60)}"',
  );
  debugPrint(
    '[ODU][OKANA YABILE] descripcion[0:60]="${_debugSlice(descripcion, 60)}"',
  );
  debugPrint(
    '[ODU][OKANA YABILE] AQUÍ in nace=$naceHasAqui, AQUÍ in descripcion=$descripcionHasAqui',
  );
}

String _debugSlice(String text, int maxChars) {
  if (text.isEmpty) return '';
  final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.length <= maxChars) return compact;
  return compact.substring(0, maxChars);
}

void _debugPrintOjuaniPokonCheckOnce(
  Map<String, dynamic> decoded, {
  required String resolvedAssetPath,
}) {
  if (_didPrintOjuaniPokonDebug) {
    return;
  }
  _didPrintOjuaniPokonDebug = true;

  final oduRaw = decoded['odu'];
  if (oduRaw is! Map) {
    debugPrint(
      '[ODU][OJUANI POKON] asset=$resolvedAssetPath, entry not found (missing odu map).',
    );
    return;
  }

  final oduMap = Map<String, dynamic>.from(oduRaw);
  final entryRaw = oduMap['OJUANI POKON'];
  if (entryRaw is! Map) {
    debugPrint(
      '[ODU][OJUANI POKON] asset=$resolvedAssetPath, entry not found.',
    );
    return;
  }

  final entry = Map<String, dynamic>.from(entryRaw);
  final contentRaw = entry['content'];
  if (contentRaw is! Map) {
    debugPrint(
      '[ODU][OJUANI POKON] asset=$resolvedAssetPath, entry has no content map.',
    );
    return;
  }

  final content = Map<String, dynamic>.from(contentRaw);
  final nace = (content['nace'] is String) ? content['nace'] as String : '';
  final descripcion = (content['descripcion'] is String)
      ? content['descripcion'] as String
      : '';

  debugPrint('[ODU][OJUANI POKON] asset=$resolvedAssetPath');
  debugPrint('[ODU][OJUANI POKON] nace_length=${nace.length}');
  debugPrint('[ODU][OJUANI POKON] descripcion_length=${descripcion.length}');
  debugPrint(
    '[ODU][OJUANI POKON] nace_first120="${_debugSlice(nace, 120)}"',
  );
  debugPrint(
    '[ODU][OJUANI POKON] descripcion_first120="${_debugSlice(descripcion, 120)}"',
  );
}

const Map<String, String> _legacyOduAliases = <String, String>{
  // Legacy Meji spelling compatibility.
  'BABA EJIOGBE': 'BABA OGBE',
  'OYECUN MEJI': 'OYEKUN MEJI',
  'IROSUN MEJI': 'IROSO MEJI',
  'OCANA MEJI': 'OKANA MEJI',
  'OSE MEJI': 'OSHE MEJI',

  // OYEKUN legacy/generic naming compatibility.
  'OYEKUN OGBE': 'OYEKUN NILOGBE',
  'OYEKUN IWORI': 'OYEKUN PITI',
  'OYEKUN ODI': 'OYEKUN DI',
  'OYEKUN ROSO': 'OYEKUN BIROSO',
  'OYEKUN IROSO': 'OYEKUN BIROSO',
  'OYEKUN OJUANI': 'OYEKUN JUANI',
  'OYEKUN PELEKAN': 'OYEKUN PELEKA',
  'OYEKUN OKANA': 'OYEKUN PELEKA',
  'OYEKUN OGUNDA': 'OYEKUN TEKUNDA',
  'OYEKUN OSA': 'OYEKUN BIRIKUSA',
  'OYEKUN IKA': 'OYEKUN BIKA',
  'OYEKUN OTRUPON': 'OYEKUN BATRUPON',
  'OYEKUN OTURA': 'OYEKUN TESIA',
  'OYEKUN IRETE': 'OYEKUN BIRETE',
  'OYEKUN OSHE': 'OYEKUN PAKIOSHE',
  'OYEKUN OFUN': 'OYEKUN BEDURA',

  // IWORI spelling compatibility.
  'IWORI BOGBE': 'IWORI BOGDE',
  'IWORI BIKA': 'IWORI BOKA',
  'OJUANI BOKA': 'IWORI BOKA',
  'IWORI OTRUPON': 'IWORI BATRUPON',
  'IWORI OTURA': 'IWORI TURALE',

  // OFUN legacy/generic naming compatibility.
  'ORANGUN': 'OFUN NALBE',
  'OFUN ORANGUN': 'OFUN NALBE',
  'OFUN OGBE': 'OFUN NALBE',
  'OFUN OYEKUN': 'OFUN YEMILO',
  'OFUN IWORI': 'OFUN GANDO',
  'OFUN ODI': 'OFUN DI',
  'OFUN IROSO': 'OFUN BIROSO',
  'OFUN OJUANI': 'OFUN FUNI',
  'OFUN OBARA': 'OFUN SUSU',
  'OFUN OKANA': 'OFUN KANA',
  'OFUN OGUNDA': 'OFUN FUNDA',
  'OFUN OSA': 'OFUN SA',
  'OFUN IKA': 'OFUN KAMALA',
  'OFUN OTRUPON': 'OFUN BATRUPON',
  'OFUN OTURA': 'OFUN TEMPOLA',
  'OFUN IRETE': 'OFUN BIRETE',
  'OFUN OSHE': 'OFUN SHE',
  'OFUN OSE': 'OFUN SHE',
};

List<String> _alternateLookupKeys(String key) {
  if (key.isEmpty) {
    return const [];
  }
  final variants = <String>{};

  void addVariant(String value) {
    final normalized = _normalizeLookupKey(value);
    if (normalized.isNotEmpty && normalized != key) {
      variants.add(normalized);
    }
  }

  const replacements = <List<String>>[
    <String>['OYECUN', 'OYEKUN'],
    <String>['OYEKUN', 'OYECUN'],
    <String>[' DI', ' ODI'],
    <String>[' ODI', ' DI'],
    <String>[' PITI', ' IWORI'],
    <String>[' IWORI', ' PITI'],
    <String>[' NILOGBE', ' OGBE'],
    <String>[' OGBE', ' NILOGBE'],
  ];

  for (final pair in replacements) {
    final from = pair[0];
    final to = pair[1];
    if (key.contains(from)) {
      addVariant(key.replaceFirst(from, to));
    }
  }

  return variants.toList();
}

Map<String, dynamic> _decodeOduJson(String raw) {
  final decoded = json.decode(raw);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  if (decoded is Map) {
    return Map<String, dynamic>.from(decoded);
  }
  return <String, dynamic>{};
}

String _fallbackNameFrom(Map<dynamic, dynamic> value, String fallback) {
  final content = value['content'];
  if (content is Map && content['name'] is String) {
    return content['name'] as String;
  }
  return fallback;
}
