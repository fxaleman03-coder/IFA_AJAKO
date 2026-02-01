import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:icloud_kv_storage/icloud_kv_storage.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'odu_data.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(TranslationService.instance.preload());
  runApp(const LibretaIfaApp());
}

final ValueNotifier<AppLanguage> appLanguage =
    ValueNotifier<AppLanguage>(AppLanguage.es);
final GlobalKey<_HomeScreenState> homeKey = GlobalKey<_HomeScreenState>();

enum AppLanguage { es, en }

const String _localNetworkTranslationUrl =
    'http://fxaleman03gmailcoms-MacBook-Pro.local:8787/translate';

List<String> _translationApiCandidates() {
  const configured =
      String.fromEnvironment('TRANSLATION_API_URL', defaultValue: '');
  final candidates = <String>[];
  if (configured.isNotEmpty) {
    candidates.add(configured);
  }
  if (Platform.isMacOS) {
    candidates.add('http://127.0.0.1:8787/translate');
    candidates.add('http://localhost:8787/translate');
    candidates.add(_localNetworkTranslationUrl);
  } else if (Platform.isAndroid) {
    candidates.add('http://10.0.2.2:8787/translate');
    candidates.add(_localNetworkTranslationUrl);
  } else if (Platform.isIOS) {
    candidates.add(_localNetworkTranslationUrl);
  }
  return candidates;
}

class AppStrings {
  const AppStrings(this.language);

  final AppLanguage language;

  String get appTitle =>
      language == AppLanguage.es ? 'IFA AJAKO' : 'IFA AJAKO';
  String get consultas =>
      language == AppLanguage.es ? 'Consultas' : 'Consultations';
  String get odu => 'Odu';
  String get nuevaConsulta =>
      language == AppLanguage.es ? 'Nueva consulta' : 'New consultation';
  String get guardar => language == AppLanguage.es ? 'Guardar' : 'Save';
  String get cancelar => language == AppLanguage.es ? 'Cancelar' : 'Cancel';
  String get sinConsultas =>
      language == AppLanguage.es ? 'Sin consultas' : 'No consultations yet';
  String get nombreCompleto =>
      language == AppLanguage.es ? 'Nombre Completo' : 'Full Name';
  String get fecha => language == AppLanguage.es ? 'Fecha' : 'Date';
  String get hijoDe =>
      language == AppLanguage.es ? 'Hijo de' : 'Child of';
  String get omoOlo =>
      language == AppLanguage.es ? 'OMO/OLO' : 'OMO/OLO';
  String get seleccionaFecha =>
      language == AppLanguage.es ? 'Selecciona fecha' : 'Select date';
  String get idioma => language == AppLanguage.es ? 'Idioma' : 'Language';
  String get volver => language == AppLanguage.es ? 'Volver' : 'Back';
  String get odusMeji =>
      language == AppLanguage.es ? 'Odu Meji' : 'Meji Odus';
  String get encabezadoConsulta => language == AppLanguage.es
      ? 'Encabezado de la consulta'
      : 'Consultation header';
  String get odunToyale =>
      language == AppLanguage.es ? 'Odu Toyale' : 'Odu Toyale';
  String get oduOkuta =>
      language == AppLanguage.es ? 'Odu Okuta' : 'Odu Okuta';
  String get oduTomala =>
      language == AppLanguage.es ? 'Odu Tomala' : 'Odu Tomala';
  String get detalleConsulta => language == AppLanguage.es
      ? 'Detalle de la consulta'
      : 'Consultation details';
  String get notas =>
      language == AppLanguage.es ? 'Notas' : 'Notes';
  String get editar =>
      language == AppLanguage.es ? 'Editar' : 'Edit';
  String get eliminar =>
      language == AppLanguage.es ? 'Eliminar' : 'Delete';
  String get exportarPdf =>
      language == AppLanguage.es ? 'Exportar PDF' : 'Export PDF';
  String get sincronizarIcloud =>
      language == AppLanguage.es ? 'Sincronizar iCloud' : 'Sync iCloud';
  String get syncCompletada =>
      language == AppLanguage.es ? 'Sincronización completada' : 'Sync completed';
  String get syncSinCambios =>
      language == AppLanguage.es ? 'Sin cambios' : 'No changes';
  String get syncAhora =>
      language == AppLanguage.es ? 'Sync ahora' : 'Sync now';
  String get contenidoPendiente => language == AppLanguage.es
      ? 'Contenido pendiente'
      : 'Content coming soon';
  String get guardarCambios =>
      language == AppLanguage.es ? 'Guardar cambios' : 'Save changes';
  String get rezo => language == AppLanguage.es ? 'REZO' : 'PRAYER';
  String get suyere => language == AppLanguage.es ? 'SUYERE' : 'SUYERE';
  String get enEsteSignoNace => language == AppLanguage.es
      ? 'EN ESTE SIGNO NACE'
      : 'IN THIS SIGN IS BORN';
  String get descripcionSigno => language == AppLanguage.es
      ? 'DESCRIPCION DEL SIGNO'
      : 'SIGN DESCRIPTION';
  String get ewesSigno =>
      language == AppLanguage.es ? 'EWES DEL SIGNO' : 'HERBS OF THE SIGN';
  String get eshuSigno =>
      language == AppLanguage.es ? 'ESHU DEL SIGNO' : 'ESHU OF THE SIGN';
  String get rezosSuyeres => language == AppLanguage.es
      ? 'REZOS Y SUYERES'
      : 'PRAYERS AND SUYERES';
  String get obrasSigno =>
      language == AppLanguage.es ? 'OBRAS DEL SIGNO' : 'WORKS OF THE SIGN';
  String get diceIfa =>
      language == AppLanguage.es ? 'DICE IFA' : 'IFA SAYS';
  String get refranes =>
      language == AppLanguage.es ? 'REFRANES' : 'PROVERBS';
  String get historiasPatakies => language == AppLanguage.es
      ? 'HISTORIAS Y PATAKIES'
      : 'STORIES AND PATAKIES';
  String get patakiLabel =>
      language == AppLanguage.es ? 'PATAKI' : 'PATAKI';
  String get traduccionLabel =>
      language == AppLanguage.es ? 'TRADUCCIÓN' : 'TRANSLATION';
  String get ensenanzasLabel =>
      language == AppLanguage.es ? 'ENSEÑANZAS' : 'TEACHINGS';
  String get traduciendo =>
      language == AppLanguage.es ? 'Traduciendo…' : 'Translating…';
  String get traduccionNoConfig => language == AppLanguage.es
      ? 'Traducción no configurada'
      : 'Translation not configured';
}

class TranslationService {
  TranslationService._();

  static final TranslationService instance = TranslationService._();
  final Map<String, String> _cache = {};
  final Map<String, Future<String>> _inflight = {};
  bool _loaded = false;
  static const int _cacheVersion = 2;
  final int _maxConcurrent = 3;
  int _active = 0;
  final List<Completer<void>> _waiters = [];

  bool get isEnabled => _translationApiCandidates().isNotEmpty;

  Future<void> preload() async {
    await _loadCache();
  }

  Future<String> translate(
    String text, {
    String source = 'es',
    String target = 'en',
  }) async {
    if (text.trim().isEmpty || source == target) {
      return text;
    }
    if (!isEnabled) {
      return text;
    }
    await _loadCache();
    final key = _cacheKey(text, source, target);
    final cached = _cache[key];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    final inflight = _inflight[key];
    if (inflight != null) {
      return inflight;
    }
    final future = _translateRemote(text, source, target);
    _inflight[key] = future;
    final result = await future;
    _inflight.remove(key);
    if (result.trim().isNotEmpty && result != text) {
      _cache[key] = result;
      await _saveCache();
    }
    return result;
  }

  String? cachedTranslate(
    String text, {
    String source = 'es',
    String target = 'en',
  }) {
    if (!_loaded) {
      return null;
    }
    final key = _cacheKey(text, source, target);
    final cached = _cache[key];
    if (cached == null || cached.isEmpty) {
      return null;
    }
    if (cached == text) {
      return null;
    }
    return cached;
  }

  Future<String?> cachedTranslateAsync(
    String text, {
    String source = 'es',
    String target = 'en',
  }) async {
    await _loadCache();
    return cachedTranslate(text, source: source, target: target);
  }

  String _cacheKey(String text, String source, String target) {
    return 'v$_cacheVersion:$source->$target:${_fnv1a32(text)}';
  }

  int _fnv1a32(String text) {
    var hash = 0x811c9dc5;
    for (final codeUnit in text.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash;
  }

  Future<File> _cacheFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/translations_cache.json');
  }

  Future<void> _loadCache() async {
    if (_loaded) {
      return;
    }
    try {
      final file = await _cacheFile();
      if (!await file.exists()) {
        _loaded = true;
        return;
      }
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        for (final entry in decoded.entries) {
          final value = entry.value;
          if (value is String && value.isNotEmpty) {
            _cache[entry.key] = value;
          }
        }
      }
      _loaded = true;
    } catch (_) {
      // Ignore cache read failures.
      _loaded = false;
    }
  }

  Future<void> _saveCache() async {
    try {
      final file = await _cacheFile();
      await file.writeAsString(jsonEncode(_cache));
    } catch (_) {
      // Ignore cache write failures.
    }
  }

  Future<String> _translateRemote(
    String text,
    String source,
    String target,
  ) async {
    try {
      final candidates = _translationApiCandidates();
      if (candidates.isEmpty) {
        return text;
      }
      await _acquire();
      for (final candidate in candidates) {
        try {
          final uri = Uri.parse(candidate);
          final client = HttpClient();
          client.connectionTimeout = const Duration(seconds: 15);
          final request = await client.postUrl(uri);
          request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
          request.add(utf8.encode(jsonEncode({
            'text': text,
            'source': source,
            'target': target,
          })));
          final response = await request.close();
          final responseBody = await response.transform(utf8.decoder).join();
          if (response.statusCode != 200) {
            continue;
          }
          final decoded = jsonDecode(responseBody);
          final translated = decoded is Map<String, dynamic>
              ? decoded['translation'] as String? ?? ''
              : '';
          if (translated.trim().isEmpty) {
            continue;
          }
          return translated;
        } catch (_) {
          continue;
        }
      }
      return text;
    } catch (_) {
      return text;
    } finally {
      _release();
    }
  }

  Future<void> _acquire() async {
    if (_active < _maxConcurrent) {
      _active += 1;
      return;
    }
    final completer = Completer<void>();
    _waiters.add(completer);
    await completer.future;
    _active += 1;
  }

  void _release() {
    if (_active > 0) {
      _active -= 1;
    }
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete();
    }
  }
}

class LibretaIfaApp extends StatelessWidget {
  const LibretaIfaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Libreta de IFA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          secondary: const Color(0xFFF9A825),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF2E7D32),
          secondary: const Color(0xFFF9A825),
          tertiary: const Color(0xFF7CB342),
          surface: const Color(0xFFF7F5EF),
          background: const Color(0xFFF7F5EF),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F5EF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2E7D32),
          foregroundColor: Colors.white,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFFF7F5EF),
          indicatorColor: const Color(0xFFF9A825),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(color: Color(0xFF2E7D32)),
          ),
        ),
      ),
      home: HomeScreen(key: homeKey),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _sections = 2;
  static const _icloudDataKey = 'consultas_json';
  static const _icloudUpdatedKey = 'consultas_updated_at';
  static const _icloudDeletedKey = 'consultas_deleted_ids';

  final _icloud = CKKVStorage();
  int _sectionIndex = 0;
  final List<Consulta> _consultas = [];
  final Set<int> _deletedConsultaIds = {};
  bool _loadingConsultas = true;
  bool _showConsultas = false;
  DateTime? _consultaFilterDate;
  int? _selectedConsultaId;
  DateTime _localConsultasUpdatedAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _loadConsultas();
    if (Platform.isIOS || Platform.isMacOS) {
      _icloud.onCloudKitKVUpdateCallBack(
        onCallBack: (_) async => _syncFromIcloud(),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, language, _) {
        final strings = AppStrings(language);
        return Scaffold(
          appBar: AppBar(
            title: Text(strings.appTitle),
            leading: _sectionIndex == 1
                ? IconButton(
                    tooltip: strings.volver,
                    onPressed: _goHome,
                    icon: const Icon(Icons.arrow_back),
                  )
                : null,
            bottom: const _LanguageTabBar(),
          ),
          body: SafeArea(
            child: IndexedStack(
              index: _sectionIndex,
              children: [
                ConsultasScreen(
                  strings: strings,
                  consultas: _consultas,
                  isLoading: _loadingConsultas,
                  showList: _showConsultas,
                  filterDate: _consultaFilterDate,
                  selectedId: _selectedConsultaId,
                  onSyncNow: () => _showSyncNow(strings),
                  onSelectForPdf: (consulta) {
                    setState(() => _selectedConsultaId = consulta.id);
                    _exportConsultasPdf(strings);
                  },
                  onEdit: (consulta) => _openConsultaEditor(
                    strings,
                    existing: consulta,
                  ),
                  onDelete: (consulta) => _confirmDelete(strings, consulta),
                ),
                OduScreen(
                  onBackToHome: _goHome,
                ),
              ],
            ),
          ),
          floatingActionButton: _sectionIndex == 0
              ? FloatingActionButton.extended(
                  onPressed: () => _openConsultaEditor(strings),
                  icon: const Icon(Icons.add),
                  label: Text(strings.nuevaConsulta),
                )
              : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _sectionIndex,
            onDestinationSelected: (index) {
              if (index < _sections) {
                setState(() => _sectionIndex = index);
                if (index == 0) {
                  _openConsultasFilter();
                }
              }
            },
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.book_outlined),
                selectedIcon: const Icon(Icons.book),
                label: strings.consultas,
              ),
              NavigationDestination(
                icon: const Icon(Icons.auto_awesome_outlined),
                selectedIcon: const Icon(Icons.auto_awesome),
                label: strings.odu,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openConsultaEditor(
    AppStrings strings, {
    Consulta? existing,
  }) async {
    final consulta = await Navigator.of(context).push<Consulta>(
      MaterialPageRoute(
        builder: (_) => ConsultaEditorScreen(
          existing: existing,
        ),
      ),
    );

    if (consulta == null) {
      _goHome();
      return;
    }

    setState(() {
      final index =
          _consultas.indexWhere((item) => item.id == consulta.id);
      if (index == -1) {
        _consultas.insert(0, consulta);
      } else {
        _consultas[index] = consulta;
      }
      _deletedConsultaIds.remove(consulta.id);
      _sectionIndex = 0;
      _showConsultas = false;
      _selectedConsultaId = null;
    });

    await _saveConsultas();
  }

  Future<void> _openConsultasFilter() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (picked == null) {
      _goHome();
      return;
    }
    final hasMatches = _consultas.any((consulta) {
      return consulta.fecha.year == picked.year &&
          consulta.fecha.month == picked.month &&
          consulta.fecha.day == picked.day;
    });
    if (!hasMatches) {
      if (mounted) {
        _goHome();
      }
      return;
    }
    setState(() {
      _consultaFilterDate = picked;
      _showConsultas = true;
    });
  }

  void _goHome() {
    setState(() {
      _sectionIndex = 0;
      _showConsultas = false;
      _consultaFilterDate = null;
      _selectedConsultaId = null;
    });
  }

  void goHomeExternal() => _goHome();

  void goOduExternal() {
    setState(() {
      _sectionIndex = 1;
      _showConsultas = false;
      _consultaFilterDate = null;
      _selectedConsultaId = null;
    });
  }

  Future<void> _confirmDelete(AppStrings strings, Consulta consulta) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.eliminar),
        content: Text(consulta.nombreCompleto.isEmpty
            ? strings.eliminar
            : consulta.nombreCompleto),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.cancelar),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.eliminar),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    setState(() {
      _consultas.removeWhere((item) => item.id == consulta.id);
      _deletedConsultaIds.add(consulta.id);
      if (_selectedConsultaId == consulta.id) {
        _selectedConsultaId = null;
      }
    });
    await _saveConsultas();
  }

  Future<File> _consultasFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/consultas.json');
  }

  Future<void> _loadConsultas() async {
    try {
      final file = await _consultasFile();
      if (!await file.exists()) {
        await _syncFromIcloud();
        setState(() => _loadingConsultas = false);
        return;
      }
      _localConsultasUpdatedAt = await file.lastModified();
      final raw = await file.readAsString();
      final data = jsonDecode(raw);
      if (data is List) {
        _consultas
          ..clear()
          ..addAll(
            data.map((entry) {
              if (entry is Map) {
                return Consulta.fromJson(
                  Map<String, dynamic>.from(entry),
                );
              }
              return null;
            }).whereType<Consulta>(),
          );
      } else if (data is Map) {
        final consultasRaw = data['consultas'];
        final deletedRaw = data['deletedIds'];
        _deletedConsultaIds
          ..clear()
          ..addAll(
            deletedRaw is List
                ? deletedRaw.whereType<num>().map((e) => e.toInt())
                : const <int>{},
          );
        if (consultasRaw is List) {
          _consultas
            ..clear()
            ..addAll(
              consultasRaw.map((entry) {
                if (entry is Map) {
                  return Consulta.fromJson(
                    Map<String, dynamic>.from(entry),
                  );
                }
                return null;
              }).whereType<Consulta>(),
            );
          _consultas.removeWhere((item) => _deletedConsultaIds.contains(item.id));
        }
      }
      await _syncFromIcloud();
    } catch (_) {
      // Keep in-memory list if parsing fails.
    } finally {
      if (mounted) {
        setState(() => _loadingConsultas = false);
      }
    }
  }

  Future<void> _saveConsultas() async {
    final file = await _consultasFile();
    final payload = <String, dynamic>{
      'consultas': _consultas.map((item) => item.toJson()).toList(),
      'deletedIds': _deletedConsultaIds.toList(),
    };
    await file.writeAsString(jsonEncode(payload));
    _localConsultasUpdatedAt = DateTime.now();
    await _syncToIcloud();
  }

  Future<void> _exportConsultasJson(AppStrings strings) async {
    if (_consultas.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.sinConsultas)),
        );
      }
      return;
    }
    final content = jsonEncode(_consultas.map((c) => c.toJson()).toList());
    try {
      String path;
      if (Platform.isIOS) {
        path =
            '${(await getApplicationDocumentsDirectory()).path}/consultas.json';
        await File(path).writeAsString(content);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Preparando exportación...')),
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await Share.shareXFiles([XFile(path)], text: 'consultas.json');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('JSON: $path')),
          );
        }
        return;
      } else {
        FileSaveLocation? location;
        try {
          location = await getSaveLocation(
            suggestedName: 'consultas.json',
            acceptedTypeGroups: const [
              XTypeGroup(label: 'JSON', extensions: ['json']),
            ],
          );
        } catch (_) {
          location = null;
        }
        if (location == null) {
          final choice = await showDialog<String>(
            context: context,
            builder: (dialogContext) => SimpleDialog(
              title: Text(strings.sincronizarIcloud),
              children: [
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(dialogContext, 'downloads'),
                  child: const Text('Descargas'),
                ),
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(dialogContext, 'icloud'),
                  child: const Text('iCloud Drive'),
                ),
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(dialogContext, null),
                  child: Text(strings.cancelar),
                ),
              ],
            ),
          );
          if (choice == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Exportación cancelada')),
              );
            }
            return;
          }
          final baseDir = choice == 'downloads'
              ? Directory('${Platform.environment['HOME']}/Downloads/IFA')
              : Directory(
                  '${Platform.environment['HOME']}/Library/Mobile Documents/com~apple~CloudDocs/IFA',
                );
          await baseDir.create(recursive: true);
          path = '${baseDir.path}/consultas.json';
        } else {
          path = location.path;
        }
        await File(path).writeAsString(content);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('JSON: $path')),
        );
      }
      if (!Platform.isIOS) {
        await OpenFilex.open(path);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al exportar JSON')),
        );
      }
    }
  }

  Future<void> _importConsultasJson(AppStrings strings) async {
    const typeGroup = XTypeGroup(
      label: 'JSON',
      extensions: ['json'],
    );
    try {
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Importación cancelada')),
          );
        }
        return;
      }
      final raw = await file.readAsString();
      final data = jsonDecode(raw);
      if (data is! List) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('JSON inválido')),
          );
        }
        return;
      }
      final parsed = data.map((entry) {
        if (entry is Map) {
          return Consulta.fromJson(Map<String, dynamic>.from(entry));
        }
        return null;
      }).whereType<Consulta>().toList();
      setState(() {
        final merged = <int, Consulta>{
          for (final existing in _consultas) existing.id: existing,
          for (final incoming in parsed) incoming.id: incoming,
        };
        _consultas
          ..clear()
          ..addAll(merged.values);
        _consultaFilterDate = null;
        _showConsultas = true;
        _selectedConsultaId = null;
      });
      await _saveConsultas();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Importación completada')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al importar JSON')),
        );
      }
    }
  }

  Future<void> _showSyncNow(AppStrings strings) async {
    await showDialog<void>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(strings.syncAhora),
        children: [
          SimpleDialogOption(
            onPressed: () async {
              Navigator.of(context).pop();
              final changed = await _syncFromIcloud(forceMerge: true);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      changed ? strings.syncCompletada : strings.syncSinCambios,
                    ),
                  ),
                );
              }
            },
            child: Text(strings.sincronizarIcloud),
          ),
        ],
      ),
    );
  }

  Future<bool> _syncFromIcloud({bool forceMerge = false}) async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      return false;
    }
    try {
      final remoteJson = await _icloud.getString(_icloudDataKey);
      if (remoteJson == null || remoteJson.isEmpty) {
        await _syncToIcloud();
        return false;
      }
      final remoteDeletedRaw = await _icloud.getString(_icloudDeletedKey);
      final data = jsonDecode(remoteJson);
      List<Consulta> remoteList = [];
      final remoteDeleted = <int>{};

      if (data is List) {
        remoteList = data.map((entry) {
          if (entry is Map) {
            return Consulta.fromJson(Map<String, dynamic>.from(entry));
          }
          return null;
        }).whereType<Consulta>().toList();
      } else if (data is Map) {
        final consultasRaw = data['consultas'];
        final deletedRaw = data['deletedIds'];
        if (consultasRaw is List) {
          remoteList = consultasRaw.map((entry) {
            if (entry is Map) {
              return Consulta.fromJson(Map<String, dynamic>.from(entry));
            }
            return null;
          }).whereType<Consulta>().toList();
        }
        if (deletedRaw is List) {
          remoteDeleted.addAll(
            deletedRaw.whereType<num>().map((e) => e.toInt()),
          );
        }
      }

      if (remoteDeleted.isEmpty &&
          remoteDeletedRaw != null &&
          remoteDeletedRaw.isNotEmpty) {
        try {
          final decoded = jsonDecode(remoteDeletedRaw);
          if (decoded is List) {
            remoteDeleted.addAll(
              decoded.whereType<num>().map((e) => e.toInt()),
            );
          }
        } catch (_) {}
      }
      final previousDeleted = Set<int>.from(_deletedConsultaIds);
      _deletedConsultaIds
        ..addAll(remoteDeleted);

      final merged = <int, Consulta>{
        for (final remote in remoteList) remote.id: remote,
        for (final local in _consultas) local.id: local,
      };

      final mergedList = merged.values
          .where((consulta) => !_deletedConsultaIds.contains(consulta.id))
          .toList();
      final deletedChanged =
          previousDeleted.length != _deletedConsultaIds.length ||
              previousDeleted.any((id) => !_deletedConsultaIds.contains(id));
      final changed = mergedList.length != _consultas.length ||
          _consultas.any((item) => !merged.containsKey(item.id)) ||
          deletedChanged;

      if (changed || forceMerge) {
        if (mounted) {
          setState(() {
            _consultas
              ..clear()
              ..addAll(mergedList);
            _consultaFilterDate = null;
            _showConsultas = true;
            _selectedConsultaId = null;
          });
        } else {
          _consultas
            ..clear()
            ..addAll(mergedList);
        }
        await _saveConsultas();
        return true;
      }
      return false;
    } catch (_) {
      // Ignore iCloud sync failures and rely on local storage.
      return false;
    }
  }

  Future<void> _syncToIcloud() async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      return;
    }
    try {
      final payload = jsonEncode({
        'consultas': _consultas.map((c) => c.toJson()).toList(),
        'deletedIds': _deletedConsultaIds.toList(),
      });
      await _icloud.writeString(key: _icloudDataKey, value: payload);
      await _icloud.writeString(
        key: _icloudDeletedKey,
        value: jsonEncode(_deletedConsultaIds.toList()),
      );
      await _icloud.writeString(
        key: _icloudUpdatedKey,
        value: _localConsultasUpdatedAt.millisecondsSinceEpoch.toString(),
      );
    } catch (_) {
      // Ignore iCloud sync failures and rely on local storage.
    }
  }

  Future<void> _exportConsultasPdf(AppStrings strings) async {
    final pdf = pw.Document();
    final pdfCourier = pw.Font.courier();
    final pdfCourierBold = pw.Font.courierBold();
    pw.ImageProvider? logoImage;
    try {
      final data = await DefaultAssetBundle.of(context)
          .load('assets/logo.png');
      logoImage = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      logoImage = null;
    }

    final selected = _consultas
        .where((consulta) => consulta.id == _selectedConsultaId)
        .toList();

    if (selected.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.sinConsultas)),
        );
      }
      return;
    }

    for (final consulta in selected) {
      pdf.addPage(
        pw.Page(
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          consulta.nombreCompleto.isEmpty
                              ? strings.nombreCompleto
                              : consulta.nombreCompleto,
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '${strings.fecha}: ${_formatDatePdf(consulta.fecha, strings.language)}',
                        ),
                      ],
                    ),
                  ),
                  if (logoImage != null)
                    pw.Container(
                      width: 64,
                      height: 64,
                      alignment: pw.Alignment.topRight,
                      child: pw.Image(logoImage),
                    ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                consulta.hijoDe.isEmpty
                    ? strings.hijoDe
                    : '${strings.hijoDe}: ${consulta.hijoDe}',
              ),
              pw.Text(
                consulta.omoOlo.isEmpty
                    ? strings.omoOlo
                    : '${strings.omoOlo}: ${consulta.omoOlo}',
              ),
              pw.SizedBox(height: 12),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          '${strings.oduTomala}:',
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.Divider(),
                        pw.Text(
                          consulta.oduTomala.isEmpty
                              ? '-'
                              : consulta.oduTomala,
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            font: pdfCourierBold,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          '${strings.oduOkuta}:',
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.Divider(),
                        pw.Text(
                          consulta.oduOkuta.isEmpty
                              ? '-'
                              : consulta.oduOkuta,
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            font: pdfCourierBold,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          '${strings.odunToyale}:',
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.Divider(),
                        pw.Text(
                          consulta.odunToyale.isEmpty
                              ? '-'
                              : consulta.odunToyale,
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            font: pdfCourierBold,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(),
              pw.SizedBox(height: 12),
              pw.Text('${strings.detalleConsulta}:'),
              pw.Divider(),
              pw.Text(
                consulta.detalleConsulta.isEmpty
                    ? '-'
                    : consulta.detalleConsulta,
              ),
            ],
          ),
        ),
      );
    }

    final bytes = await pdf.save();
    if (Platform.isIOS) {
      await Printing.layoutPdf(
        onLayout: (format) async => bytes,
        name: 'consultas_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      return;
    }

    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${directory.path}/consultas_$timestamp.pdf');
    await file.writeAsBytes(bytes);
    await OpenFilex.open(file.path);
  }
}

class _LanguageTabBar extends StatelessWidget implements PreferredSizeWidget {
  const _LanguageTabBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, language, _) {
        return DefaultTabController(
          length: 2,
          initialIndex: language == AppLanguage.es ? 0 : 1,
          child: TabBar(
            tabs: const [
              Tab(text: 'ES'),
              Tab(text: 'EN'),
            ],
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: const Color(0xFFF9A825),
            onTap: (index) {
              final next = index == 0 ? AppLanguage.es : AppLanguage.en;
              if (next != language) {
                appLanguage.value = next;
              }
            },
          ),
        );
      },
    );
  }
}

class ConsultasScreen extends StatelessWidget {
  const ConsultasScreen({
    super.key,
    required this.strings,
    required this.consultas,
    required this.isLoading,
    required this.showList,
    required this.onEdit,
    required this.onDelete,
    required this.filterDate,
    required this.selectedId,
    required this.onSyncNow,
    required this.onSelectForPdf,
  });

  final AppStrings strings;
  final List<Consulta> consultas;
  final bool isLoading;
  final bool showList;
  final ValueChanged<Consulta> onEdit;
  final ValueChanged<Consulta> onDelete;
  final DateTime? filterDate;
  final int? selectedId;
  final VoidCallback onSyncNow;
  final ValueChanged<Consulta> onSelectForPdf;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!showList) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/logo.png',
              width: 180,
              height: 180,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onSyncNow,
              icon: const Icon(Icons.sync),
              label: Text(strings.syncAhora),
            ),
          ],
        ),
      );
    }
    final filtered = filterDate == null
        ? consultas
        : consultas.where((consulta) {
            return consulta.fecha.year == filterDate!.year &&
                consulta.fecha.month == filterDate!.month &&
                consulta.fecha.day == filterDate!.day;
          }).toList();
    if (filtered.isEmpty) {
      return Center(child: Text(strings.sinConsultas));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: onSyncNow,
              icon: const Icon(Icons.sync),
              label: Text(strings.syncAhora),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final consulta = filtered[index];
              return _ConsultaCard(
                consulta: consulta,
                strings: strings,
                isSelected: selectedId == consulta.id,
                onSelectForPdf: () => onSelectForPdf(consulta),
                onEdit: () => onEdit(consulta),
                onDelete: () => onDelete(consulta),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ConsultaCard extends StatelessWidget {
  const _ConsultaCard({
    required this.consulta,
    required this.strings,
    required this.isSelected,
    required this.onSelectForPdf,
    required this.onEdit,
    required this.onDelete,
  });

  final Consulta consulta;
  final AppStrings strings;
  final bool isSelected;
  final VoidCallback onSelectForPdf;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isSelected
          ? Theme.of(context).colorScheme.secondaryContainer
          : null,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    consulta.nombreCompleto.isEmpty
                        ? strings.nombreCompleto
                        : consulta.nombreCompleto,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Image.asset(
                  'assets/logo.png',
                  width: 56,
                  height: 56,
                  fit: BoxFit.contain,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${strings.fecha}: ${_formatDate(consulta.fecha)}',
            ),
            const SizedBox(height: 4),
            Text(
              consulta.hijoDe.isEmpty
                  ? strings.hijoDe
                  : '${strings.hijoDe}: ${consulta.hijoDe}',
            ),
            const SizedBox(height: 4),
            Text(
              consulta.omoOlo.isEmpty
                  ? strings.omoOlo
                  : '${strings.omoOlo}: ${consulta.omoOlo}',
            ),
            const SizedBox(height: 12),
            Text(
              strings.encabezadoConsulta,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text('${strings.odunToyale}:'),
            const Divider(),
            Text(
              consulta.odunToyale.isEmpty ? '-' : consulta.odunToyale,
              style: const TextStyle(
                fontFamily: 'Courier New',
                fontFamilyFallback: ['Courier', 'Menlo', 'monospace'],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text('${strings.oduOkuta}:'),
            const Divider(),
            Text(
              consulta.oduOkuta.isEmpty ? '-' : consulta.oduOkuta,
              style: const TextStyle(
                fontFamily: 'Courier New',
                fontFamilyFallback: ['Courier', 'Menlo', 'monospace'],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text('${strings.oduTomala}:'),
            const Divider(),
            Text(
              consulta.oduTomala.isEmpty ? '-' : consulta.oduTomala,
              style: const TextStyle(
                fontFamily: 'Courier New',
                fontFamilyFallback: ['Courier', 'Menlo', 'monospace'],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              strings.detalleConsulta,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Divider(),
            const SizedBox(height: 6),
            Text(
              consulta.detalleConsulta.isEmpty ? '-' : consulta.detalleConsulta,
            ),
            const SizedBox(height: 12),
            const Divider(),
            Align(
              alignment: Alignment.centerRight,
              child: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'delete') {
                    onDelete();
                  } else if (value == 'pdf') {
                    onSelectForPdf();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text(strings.editar),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(strings.eliminar),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'pdf',
                    child: Text(strings.exportarPdf),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Consulta {
  Consulta({
    required this.id,
    required this.nombreCompleto,
    required this.fecha,
    required this.hijoDe,
    required this.omoOlo,
    required this.odunToyale,
    required this.oduOkuta,
    required this.oduTomala,
    required this.detalleConsulta,
  });

  final int id;
  final String nombreCompleto;
  final DateTime fecha;
  final String hijoDe;
  final String omoOlo;
  final String odunToyale;
  final String oduOkuta;
  final String oduTomala;
  final String detalleConsulta;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombreCompleto': nombreCompleto,
        'fecha': fecha.toIso8601String(),
        'hijoDe': hijoDe,
        'omoOlo': omoOlo,
        'odunToyale': odunToyale,
        'oduOkuta': oduOkuta,
        'oduTomala': oduTomala,
        'detalleConsulta': detalleConsulta,
      };

  static Consulta fromJson(Map<String, dynamic> json) {
    return Consulta(
      id: json['id'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      nombreCompleto: (json['nombreCompleto'] as String?) ?? '',
      fecha: DateTime.tryParse(json['fecha'] as String? ?? '') ??
          DateTime.now(),
      hijoDe: (json['hijoDe'] as String?) ?? '',
      omoOlo: (json['omoOlo'] as String?) ?? '',
      odunToyale: (json['odunToyale'] as String?) ?? '',
      oduOkuta: (json['oduOkuta'] as String?) ?? '',
      oduTomala: (json['oduTomala'] as String?) ?? '',
      detalleConsulta: (json['detalleConsulta'] as String?) ?? '',
    );
  }
}

class ConsultaEditorScreen extends StatefulWidget {
  const ConsultaEditorScreen({
    super.key,
    this.existing,
  });

  final Consulta? existing;

  @override
  State<ConsultaEditorScreen> createState() => _ConsultaEditorScreenState();
}

class _ConsultaEditorScreenState extends State<ConsultaEditorScreen> {
  late final TextEditingController _nombreController;
  late final TextEditingController _hijoController;
  late final TextEditingController _omoOloController;
  late final TextEditingController _toyaleController;
  late final TextEditingController _okutaController;
  late final TextEditingController _tomalaController;
  late final TextEditingController _detalleController;
  late DateTime _fecha;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nombreController =
        TextEditingController(text: existing?.nombreCompleto ?? '');
    _hijoController = TextEditingController(text: existing?.hijoDe ?? '');
    _omoOloController = TextEditingController(text: existing?.omoOlo ?? '');
    _toyaleController =
        TextEditingController(text: existing?.odunToyale ?? '');
    _okutaController = TextEditingController(text: existing?.oduOkuta ?? '');
    _tomalaController =
        TextEditingController(text: existing?.oduTomala ?? '');
    _detalleController =
        TextEditingController(text: existing?.detalleConsulta ?? '');
    _fecha = existing?.fecha ?? DateTime.now();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _hijoController.dispose();
    _omoOloController.dispose();
    _toyaleController.dispose();
    _okutaController.dispose();
    _tomalaController.dispose();
    _detalleController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _fecha = picked);
    }
  }

  void _save() {
    final existing = widget.existing;
    final consulta = Consulta(
      id: existing?.id ?? DateTime.now().millisecondsSinceEpoch,
      nombreCompleto: _nombreController.text.trim(),
      fecha: _fecha,
      hijoDe: _hijoController.text.trim(),
      omoOlo: _omoOloController.text.trim(),
      odunToyale: _toyaleController.text.trim(),
      oduOkuta: _okutaController.text.trim(),
      oduTomala: _tomalaController.text.trim(),
      detalleConsulta: _detalleController.text.trim(),
    );
    Navigator.of(context).pop(consulta);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, language, _) {
        final strings = AppStrings(language);
        return Scaffold(
          appBar: AppBar(
            title: Text(
              widget.existing == null ? strings.nuevaConsulta : strings.editar,
            ),
            bottom: const _LanguageTabBar(),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.encabezadoConsulta,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nombreController,
                        decoration:
                            InputDecoration(labelText: strings.nombreCompleto),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _hijoController,
                        decoration: InputDecoration(labelText: strings.hijoDe),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _omoOloController,
                        decoration: InputDecoration(labelText: strings.omoOlo),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child:
                                Text('${strings.fecha}: ${_formatDate(_fecha)}'),
                          ),
                          TextButton(
                            onPressed: _pickDate,
                            child: Text(strings.seleccionaFecha),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 700) {
                    return Column(
                      children: [
                        _OduNoteField(
                          label: strings.odunToyale,
                          controller: _toyaleController,
                        ),
                        const SizedBox(height: 12),
                        _OduNoteField(
                          label: strings.oduOkuta,
                          controller: _okutaController,
                        ),
                        const SizedBox(height: 12),
                        _OduNoteField(
                          label: strings.oduTomala,
                          controller: _tomalaController,
                        ),
                      ],
                    );
                  }
                  return Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Expanded(
                        child: _OduNoteField(
                          label: strings.odunToyale,
                          controller: _toyaleController,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _OduNoteField(
                          label: strings.oduOkuta,
                          controller: _okutaController,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _OduNoteField(
                          label: strings.oduTomala,
                          controller: _tomalaController,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                strings.detalleConsulta,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _detalleController,
                minLines: 6,
                maxLines: 12,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _save,
                child: Text(widget.existing == null
                    ? strings.guardar
                    : strings.guardarCambios),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OduNoteField extends StatelessWidget {
  const _OduNoteField({
    required this.label,
    required this.controller,
  });

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          style: const TextStyle(
            fontFamily: 'Courier New',
            fontFamilyFallback: ['Courier', 'Menlo', 'monospace'],
            fontWeight: FontWeight.bold,
          ),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}

class OduScreen extends StatelessWidget {
  const OduScreen({
    super.key,
    required this.onBackToHome,
  });

  final VoidCallback onBackToHome;

  @override
  Widget build(BuildContext context) {
    final mejiEntries = oduEntries.where((entry) => entry.isMeji).toList();
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, language, _) {
        final strings = AppStrings(language);
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final crossAxisCount = width >= 900
                        ? 5
                        : width >= 640
                            ? 4
                            : 3;
                    final tileRatio = width < 420 ? 0.72 : 0.8;
                return GridView.builder(
                  itemCount: mejiEntries.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: tileRatio,
                  ),
                      itemBuilder: (context, index) {
                        final item = mejiEntries[index];
                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MejiIconsScreen(entry: item),
                              ),
                            );
                          },
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final avatarSize =
                                  (constraints.maxHeight * 0.62)
                                      .clamp(64.0, 110.0);
                              return Container(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    _OduSignAvatar(
                                      pattern: item.marks,
                                      isMeji: item.isMeji,
                                      size: avatarSize,
                                    ),
                                    const SizedBox(height: 6),
                                    Flexible(
                                      child: Text(
                                        item.name,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(fontSize: 9),
                                        maxLines: 4,
                                        softWrap: true,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class MejiIconsScreen extends StatelessWidget {
  const MejiIconsScreen({
    super.key,
    required this.entry,
  });

  final OduEntry entry;

  @override
  Widget build(BuildContext context) {
    final prefix = _mejiPrefixFromName(entry.name);
    final subSigns = oduEntries
        .where(
          (entry) =>
              !entry.isMeji &&
              _normalizeOduName(entry.name).startsWith(prefix),
        )
        .toList();
    final iconEntries = [entry, ...subSigns];

    return Scaffold(
      appBar: AppBar(
        title: Text(entry.name),
        bottom: const _LanguageTabBar(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final crossAxisCount = width >= 900
                ? 5
                : width >= 640
                    ? 4
                    : 3;
            final tileRatio = width < 420 ? 0.72 : 0.8;
            return GridView.builder(
              itemCount: iconEntries.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: tileRatio,
              ),
              itemBuilder: (context, index) {
                final item = iconEntries[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    final target = item.isMeji
                        ? MejiDetailScreen(
                            entry: item,
                          )
                        : OduDetailScreen(
                            entry: item,
                          );
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => target),
                    );
                  },
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final avatarSize = (constraints.maxHeight * 0.62)
                          .clamp(64.0, 110.0);
                      return Container(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            _OduSignAvatar(
                              pattern: item.marks,
                              isMeji: item.isMeji,
                              size: avatarSize,
                            ),
                            const SizedBox(height: 6),
                            Flexible(
                              child: Text(
                                item.name,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(fontSize: 9),
                                maxLines: 4,
                                softWrap: true,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class MejiDetailScreen extends StatelessWidget {
  const MejiDetailScreen({
    super.key,
    required this.entry,
  });

  final OduEntry entry;

  @override
  Widget build(BuildContext context) {
    final contentKey = _normalizeOduName(entry.name);
    final content = _oduContentByName[contentKey] ?? OduContent.empty(entry.name);

    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, language, _) {
        final strings = AppStrings(language);
        return Scaffold(
          appBar: AppBar(
            title: Text(entry.name),
            actions: [
              IconButton(
                tooltip: 'Home',
                onPressed: () {
                  homeKey.currentState?.goOduExternal();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                icon: const Icon(Icons.home),
              ),
            ],
            bottom: const _LanguageTabBar(),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      entry.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _OduSignAvatar(pattern: entry.marks, isMeji: true),
                ],
              ),
              const SizedBox(height: 20),
              _OduSection(
                title: strings.rezo,
                body: content.rezoYoruba,
                language: strings.language,
                strings: strings,
              ),
              _OduSection(
                title: strings.suyere,
                body: content.suyereYoruba,
                subtitle: content.suyereEspanol,
                language: strings.language,
                strings: strings,
                translateSubtitle: true,
              ),
              _OduExpandableSection(
                title: strings.enEsteSignoNace,
                body: content.nace,
                language: strings.language,
                strings: strings,
              ),
              _OduExpandableSection(
                title: strings.descripcionSigno,
                body: content.descripcion,
                language: strings.language,
                strings: strings,
              ),
              _OduExpandableSection(
                title: strings.ewesSigno,
                body: content.ewes,
                language: strings.language,
                strings: strings,
              ),
              _OduExpandableSection(
                title: strings.eshuSigno,
                body: content.eshu,
                language: strings.language,
                strings: strings,
              ),
              _OduExpandableSection(
                title: strings.rezosSuyeres,
                body: content.rezosYSuyeres,
                language: strings.language,
                strings: strings,
              ),
              _OduExpandableSection(
                title: strings.obrasSigno,
                body: content.obrasYEbbo,
                language: strings.language,
                strings: strings,
              ),
              _OduExpandableSection(
                title: strings.diceIfa,
                body: content.diceIfa,
                language: strings.language,
                strings: strings,
              ),
              _OduExpandableSection(
                title: strings.refranes,
                body: content.refranes,
                language: strings.language,
                strings: strings,
              ),
              _PatakiesSection(
                strings: strings,
                oduName: entry.name,
                fallback: content.historiasYPatakies,
              ),
            ],
          ),
        );
      },
    );
  }
}

class OduDetailScreen extends StatelessWidget {
  const OduDetailScreen({
    super.key,
    required this.entry,
  });

  final OduEntry entry;

  @override
  Widget build(BuildContext context) {
    final content = _oduContentFor(entry.name);
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, language, _) {
        final strings = AppStrings(language);
        return Scaffold(
          appBar: AppBar(
            title: Text(entry.name),
            actions: [
              IconButton(
                tooltip: 'Home',
                onPressed: () {
                  homeKey.currentState?.goOduExternal();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                icon: const Icon(Icons.home),
              ),
            ],
            bottom: const _LanguageTabBar(),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      entry.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _OduSignAvatar(pattern: entry.marks, isMeji: entry.isMeji),
                ],
              ),
              const SizedBox(height: 20),
              _OduSection(
                title: strings.rezo,
                body: content.rezoYoruba,
                language: strings.language,
                strings: strings,
              ),
              _OduSection(
                title: strings.suyere,
                body: content.suyereYoruba,
                subtitle: content.suyereEspanol,
                language: strings.language,
                strings: strings,
                translateSubtitle: true,
              ),
              _OduExpandableSection(
                title: strings.enEsteSignoNace,
                body: content.nace,
                language: strings.language,
                strings: strings,
              ),
              _OduExpandableSection(
                title: strings.descripcionSigno,
                body: content.descripcion,
                language: strings.language,
                strings: strings,
              ),
              _OduExpandableSection(
                title: strings.ewesSigno,
                body: content.ewes,
                language: strings.language,
                strings: strings,
              ),
              _OduExpandableSection(
                title: strings.eshuSigno,
                body: content.eshu,
                language: strings.language,
                strings: strings,
              ),
              _OduExpandableSection(
                title: strings.rezosSuyeres,
                body: content.rezosYSuyeres,
                language: strings.language,
                strings: strings,
              ),
              _OduExpandableSection(
                title: strings.obrasSigno,
                body: content.obrasYEbbo,
                language: strings.language,
                strings: strings,
              ),
              _OduExpandableSection(
                title: strings.diceIfa,
                body: content.diceIfa,
                language: strings.language,
                strings: strings,
              ),
              _OduExpandableSection(
                title: strings.refranes,
                body: content.refranes,
                language: strings.language,
                strings: strings,
              ),
              _PatakiesSection(
                strings: strings,
                oduName: entry.name,
                fallback: content.historiasYPatakies,
              ),
            ],
          ),
        );
      },
    );
  }
}

class OduContent {
  const OduContent({
    required this.name,
    required this.rezoYoruba,
    required this.suyereYoruba,
    required this.suyereEspanol,
    required this.nace,
    required this.descripcion,
    required this.ewes,
    required this.eshu,
    required this.rezosYSuyeres,
    required this.obrasYEbbo,
    required this.diceIfa,
    required this.refranes,
    required this.historiasYPatakies,
  });

  final String name;
  final String rezoYoruba;
  final String suyereYoruba;
  final String suyereEspanol;
  final String nace;
  final String descripcion;
  final String ewes;
  final String eshu;
  final String rezosYSuyeres;
  final String obrasYEbbo;
  final String diceIfa;
  final String refranes;
  final String historiasYPatakies;

  static OduContent empty(String name) => OduContent(
        name: name,
        rezoYoruba: '',
        suyereYoruba: '',
        suyereEspanol: '',
        nace: '',
        descripcion: '',
        ewes: '',
        eshu: '',
        rezosYSuyeres: '',
        obrasYEbbo: '',
        diceIfa: '',
        refranes: '',
        historiasYPatakies: '',
    );
}

OduContent _oduContentFor(String name) {
  final key = _normalizeOduName(name);
  return _oduContentByName[key] ?? OduContent.empty(name);
}

const _oduContentByName = <String, OduContent>{
  'BABA OGBE': OduContent(
    name: 'BABA EJIOGBE',
    rezoYoruba: '''BABA EJIOGBE ALALEKUN OMONI LEKUN OKO AYA LOLA OMO ODUWA
BOSHUN OMO ENI

KOSHE ILEKE RISHI KAMU ILEKE OMO LORI ADIFAFUN ALADESHE
IMPAPAPARO TIMBABELEDI

AGOGO.

BABA EJIOGBE ALOKUYE IRE MOWADE ABATA BUTU AYE ERU OSHE
BANU OBARANIREGUN IRU
OBATALA OGBONI ASIFAFUN GBOGBO ORUN GBOGBO LOWO ESHU OMA
ATOTOLO OLE AFEKAN
ADIFAFUN OBATALA OSHEREIGBO OBI ITANA AMBIAMA ITANA AMBIAMA
EYELE MEDILOGUN ELEBO.''',
    suyereYoruba: '''ASHINIMA ASHINIMA IKU FURIBUYEMA
ASHINIMA ASHINIMA ARUN FURIBUYEMA
ASHINIMA ASHINIMA OFO FURIBUYEMA
ASHINIMA ASHINIMA EYO FURIBUYEMA
ASHINIMA ASHINIMA EWO FURIBUYEMA
ASHINIMA ASHINIMA ONA FURIBUYEMA
ASHINIMA ASHINIMA ARAYE FURIBUYEMA
AWO OSHEMINIE, OSHEMINIE...''',
    suyereEspanol: '',
    nace: '''1. ORÍ.
2. IDEÚ.
3. OSUN.
4. LOS RÍOS.
5. EL ITÁ DE OSHA.
6. LA ORGANIZACIÓN.
7. EL DÍA Y LA FUERZA DE OLORUN.
8. EL SALUDO A OLORUN.
9. EL GOLPE DE ESTADO.
10. EL OSOGBO Y EL EBBÓ.
11. EL ESTADO DE LAS PROVINCIAS.
12. EL ENCANECIMIENTO PREMATURO.
13. LA CEREMONIA DE AWÁN FOGUEDÉ.
14. LOS VASOS SANGUÍNEOS Y LA LINFA.
15. FUE DONDE ARAGBÁ SE HIZO SAGRADA.
16. ES EL PRINCIPIO DE TODAS LAS COSAS.
17. LA UNIDAD Y LA LUCHA DE CONTRARIOS.
18. ISALAYE DE ODUDUWA.
19. OLOKUN.
20. EL AGBA FO GEDE.
21. LA COLUMNA VERTEBRAL Y EL ESTERNÓN.
22. QUE EL EBBÓ SE ENVUELVA EN HOJAS DE EWÉ IKOKO.
23. ES EL PRINCIPIO DE TODAS LAS COSAS Y REPRESENTA LA CREACIÓN.
24. QUE EL AWÓ DE ESTE ODUN Y LOS AWÓ OGBE ROSO NO ANDEN JUNTOS.
25. EL INTERCAMBIO DE ENERGÍA Y FLUIDOS ENTRE LOS SERES ORGÁNICOS Y SU ENTORNO.
26. EL LAVARLE LAS PATAS A LOS ANIMALES DE PLUMAS QUE SE OFRENDAN.
27. QUE EL OLUWO PUEDA COBRAR HONORARIOS RAZONABLES POR SU TRABAJO.
28. FUE DONDE OLOFIN SE ALEJÓ DE LA TIERRA POR EL HUMO DE LAS FOGATAS.
29. OLOFIN SE ROGÓ LA LERÍ CON DIECISÉIS IKORDIÉ, POR ESO VAN EN SU ADÉ.
30. QUE OLOFIN SE RETIRE DEL IGBODUN DE IFÁ DESPUÉS DE SU COMIDA AL SEXTO DÍA.
31. SE FORMÓ LA CABEZA EN LOS SERES HUMANOS Y OCUPÓ SU POSICIÓN EN EL CUERPO.
32. QUE LA CAZUELA DE OSAIN PARA EL SANTO NO LLEVE CANDELA PORQUE BABÁ SE LA QUITÓ.
33. QUE OLOFIN ACOMPAÑA AL AWÓ EL PRIMER AÑO Y ORULA DURANTE LOS PRIMEROS SIETE AÑOS.
34. QUE EL AWÓ DE ESTE ODUN DE IFÁ NO PUEDA MATAR ANIMALES SIN PREGUNTARLE A ORÚNMILA.
35. QUE ORÚNMILA SÓLO COMA ADIÉ DUNDÚN Y EL PASARLE LA MANO CON EPÓ Y MANTECA DE ADIÉ.
36. OFRECER OMÍ TUTO A LOS ORISHAS CUANDO SE INVOCAN, PUES LLEGAN DESDE LEJOS SEDIENTOS.
37. PONER UN PEDAZO DE OBÍ DEBAJO DEL DEDO GORDO DEL PIE IZQUIERDO DE LA PERSONA QUE SE ESTÁ HACIENDO ITÁ.
38. LA CONSAGRACIÓN DE ORÍ Y POR TANTO CUANDO SE SALUDA A ORÚNMILA SE TOCA EL PISO CON LA CABEZA COMO REVERENCIA.
39. SE UNIERON LAS DIFERENTES PARTES DEL CUERPO HUMANO QUE SE TRASLADA A OGUNDA EYI Y OSA MEYI LE DIO EL ESPÍRITU DE LA VIDA.
40. QUE EL BABALAWO SEA EL ÚNICO SACERDOTE QUE PUEDA SALVAR A UNA PERSONA EN ARTÍCULO DE MUERTE GRACIAS AL PACTO DE ORÚNMILA CON IKÚ.''',
    descripcion: '''• EJIOGBE ES EL MÁS IMPORTANTE DE LOS ODUS DE IFÁ, SIMBOLIZA EL PRINCIPIO MASCULINO Y SE RECONOCE COMO EL PADRE DE LOS DEMÁS ODUS, ADEMÁS, OCUPA EL PRIMER LUGAR Y ES EL SIGNO FIJO DE ORÚNMILA.
• EN EJIOGBE LAS DOS CARAS SON IDÉNTICAS, OGBE ESTÁ EN LOS DOS LADOS, POR ESO ES QUE ES LLAMADO OGBE MEJI, PERO SE RECONOCE UNIVERSALMENTE POR EJIOGBE.
• SE LLAMA EL ODU DEL LENGUAJE DOBLE PORQUE EN ÉL HABLAN TANTO LO BUENO COMO LO MALO. HAY UN BALANCE DE FUERZAS QUE SIEMPRE ES UN BUEN PRESAGIO.
• ESTE ODU REPRESENTA EL SOL (LA LUZ), ES EL PRINCIPIO Y EL FIN DE TODOS LOS PROCESOS Y EVENTOS UNIVERSALES, POR ESTA CAUSA SE LE DENOMINA (YE YESÁN).
• ES EL MESIAS DE IFA.
• ES EL HIJO DIRECTO DE METALOFIN Y DE AIYÉ.
• ES EL MESÍAS DE IFÁ Y EL PRÍNCIPE DE LOS ODUS, PORQUE ENCIERRA LOS SECRETOS DE LA CREACIÓN Y LO POSITIVO Y LO NEGATIVO, ÉL ES YIN Y EL YANG.
• SE RELACIONA CON LAS AGUAS, LAS PALMAS, LA NUEZ DE KOLÁ, LAS ESPINACAS, LA COLUMNA VERTEBRAL, EL ESTERNÓN, LOS VASOS SANGUÍNEOS Y LA LINFA.
• EN ESTE ODU NACE LA RESPIRACIÓN, EL PRINCIPIO QUE DETERMINA QUE SIN OXÍGENO NO HAY VIDA.
• NACE EL INTERCAMBIO DE ENERGÍAS Y FLUIDOS ENTRE LOS SERES ORGÁNICOS Y SU ENTORNO.
• ESTE ODU MANDA EN LA TIERRA Y ASEGURA UN BUEN AUGURIO DURANTE EL DÍA, MIENTRAS OLORUN ESTÉ ALUMBRANDO.
• ES ÉL EL ENCARGADO DE MANTENER LA VIDA DE TODO Y SU PERFECTO EQUILIBRIO.
• MIENTRAS EXISTE LUZ, ES EL REY DE LA PROCREACIÓN, PUES LA LUZ ES LA FUENTE PRINCIPAL PARA ESTE PRINCIPIO.
• EN ESTE ODU SE RIGE TODOS LOS PROCESOS Y LEYES NATURALES, A ESCALA CÓSMICA, MIENTRAS HAY UN RAYO DE LUZ SOLAR PERCEPTIBLE.
• SE RELACIONA CON LAS LLUVIAS, LOS RÍOS, LOS MARES, LAS LAGUNAS Y TODOS LOS CÚMULOS DE AGUA DULCE Y SALADA.
• SE IDENTIFICA TAMBIÉN CON LAS AVES DE RAPIÑA, ANIMALES CARROÑEROS Y LA DESCOMPOSICIÓN DE LOS CADÁVERES.
• HABLA DE LA VOLUNTAD, COMO UN ARMA PODEROSA.
• EL HOMBRE DIVIDE LA TIERRA EN CONTINENTES, ESTADO, PROVINCIAS Y PUEBLOS Y SE APROPIA DE ELLAS AUNQUE NO LE PERTENECE.
• EL PUNTO CARDINAL DE ESTE ODU ES EL ORIENTE (ESTE), DONDE SE FUNDE LA CARNE CON EL ESPÍRITU.
• ESTE ODU ESTÁ MUY RELACIONADO CON OBATALÁ PORQUE SIGNIFICA LA CABEZA Y FUE DONDE SE ESTABLECIÓ EL ORÍ EN EL CUERPO DE TODO, ADEMÁS PORQUE SIGNIFICA LA GRANDEZA Y EXTENSIÓN DEL CIELO; CON YEMAYÁ POR LA INMENSIDAD DEL MAR; CON ORÚNMILA POR LA RICA COSMOGONÍA QUE ENCIERRA.
• ES UN ODU DE GRANDEZA INFINITA PORQUE EN ÉL NACE TODO LO QUE EL HOMBRE NO PUEDE HACER POR SÍ MISMO.
• ES EL ODU DEL ASTRO QUE REPRESENTA AL TODOPODEROSO, OLORUN (EL SOL), EL QUE NOS TRAMITE EL CALOR CON SU MARAVILLOSA LUZ, LA BÓVEDA CELESTE Y LOS CUERPOS QUE EN EL SE ENCUENTRAN, SIN EL CUAL NO SERÍA POSIBLE LA VIDA. POR ESO SU COLOR ASOCIADO ES EL BLANCO Y EL NARANJA.
• ESTÁ RELACIONADO CON TODOS LOS ORISHAS, AUNQUE EN ESTE ODU NACE OLOKUN, QUE ES LA OSCURIDAD QUE REINA EN LAS PROFUNDIDADES DEL MAR.
• ES PUNTO DE REFERENCIA DE LA DICOTOMÍA ENTRE EL BIEN Y EL MAL, DOS TENDENCIAS MUY MARCADAS Y OPUESTAS, QUE UNA SIN LA OTRA NO EXISTIRÍAN. EL BIEN NO FUNDIÓ EL MAL Y VICEVERSA, PERO LA RAZÓN DE UNA ES LA OTRA.
• EN ÉL HABLAN TODOS LOS ORISHAS.
• FUE LA SEPARACIÓN DE LA TIERRA Y EL CIELO.
• AQUÍ EL BUITRE DESCIENDE SOBRE LOS CADÁVERES PARA COMÉRSELOS.
• SE CONVIRTIÓ EL PADRE DE LOS DEMÁS ODUS Y MAESTRO DEL DÍA.
• LA NOCHE (BABÁ OYEKU MEJI) SE LE OPONE COMO LA FUERZA NEGATIVA POR SU OSCURIDAD Y PENUMBRA, YA QUE TODO LO QUE NO ES CLARO, ES OPUESTO Y NOCIVO PARA ÉL.
• EN ÉL NACIÓ EL ESCALAFÓN DE IFÁ, EN EL CUAL CADA UNO EN ESTE MUNDO, LE CORRESPONDE UN LUGAR DETERMINADO.
• ES EL RENACER DE LA VIDA MATERIAL POR MOTIVOS BIEN DEFINIDOS.
• ESTE ODU HABLA DE LA LUZ Y DEL BUEN BIENESTAR GENERAL, DE LA VICTORIA SOBRE LOS ENEMIGOS, DE LOS DESPERTARES ESPIRITUALES Y DE LA PAZ DE LA MENTE. NUEVOS Y GRANDES NEGOCIOS, RELACIONES SE PUEDEN ESPERAR. HAY UNA POSIBILIDAD DE CONFRONTACIÓN, QUE REQUIERE SENTIDO COMÚN PARA TRIUNFAR.
• EL ESPIRITU QUE TRABAJA CON EJIOGBE (EL EGUN), SE LLAMA OBÁ IGBOLÁ, Y ES AL QUE HAY QUE INVOCAR CUANDO SE PRECISA AYUDA DE ESTE SIGNO. AQUÍ EL CAMINO DE ESHU-ELEGBA QUE TIENE QUE RECIBIR LA PERSONA DE MANOS DEL AWÓ, ES ESHU-ELEGBA ALAMPE.
• EN ESTE CAMINO A ORÚNMILA SE LE CONOCE COMO ABAMBONWO Y ES POR ESE NOMBRE POR EL CUAL HAY QUE LLAMARLE CUANDO SE TRABAJA CON ÉL.
• EN ESTE ODU PARA LA PROSPERIDAD Y EL VENCIMIENTO DE LAS DIFICULTADES, SE LE DEDICAN AZUCENAS A OLORUN EN UN BÚCARO SOBRE LA MESA Y CADA DÍA LA PERSONA LAS HUELE Y LE PIDE LO QUE DESEA PARA VENCER SUS DIFICULTADES.
• SE PREPARA UNA BOTELLA DE AGUARDIENTE MEZCLADA CON CORTEZA DE AYÚA. DESPUÉS DE VARIOS DÍAS SE TOMA Y ES BUENA PARA EL ASMA.
• SE MASTICA LA CORTEZA DE AYÚA PARA LOS DOLORES DE MUELAS, Y COMO AGUA COMÚN PARA DEPURAR LA SANGRE, ADEMÁS CURA LA SÍFILIS Y EL REUMATISMO.
• TOME EL JUGO DE BEJUCO UBÍ PARA DESINFECTAR LA VEJIGA, CUIDADO PORQUE ES ABORTIVO.
• TOME SUMO DE GÜIRA COMO EXPECTORANTE Y PARA LA PULMONÍA.
• INFUSIONES DE OROZUZ DE LA TIERRA PARA EL ESTÓMAGO Y EL ASMA.''',
    ewes: '''MANGLE ROJO (OBIRITITI)
PALO BOBO
MANO PILÓN
ITAMORREAL
CEIBA
ORQUÍDEA
AYÚA
BEJUCO BÍ
GÜIRO
CUNDEAMOR
CORALILLO
OROZUZ
IROKO
ROSA CIMARRONA
JOBO
ROMERILLO
ALMÁCIGO
GRANADA
ALGODÓN
PRODIGIOSA
PIÑÓN DE ROSA
ATIPONLÁ
BLEDO BLANCO
ALMENDRA
CANUTILLO''',
    eshu: '''ESHU-ELEGBA AKUELEYO:
ES EL MONSTRUO DE ESTE ODU IFÁ Y PARA PREPARAR SU CARGA SE REALIZA LO SIGUIENTE.
SE PONE UNA PALANGANA CON VARIOS CARACOLES ENTONCES SE METE AHÍ UNA ANGUILA
(EJÁ-EYO). SE DEJA QUE SE MUERA Y EN ESE INSTANTE SE LE DA 2 PALOMAS BLANCAS,
LAS CABEZAS DE ESAS DOS PALOMAS BLANCAS CON SUS PATAS Y CORAZONES VAN PARA LA
CARGA CON LA ANGUILA. EL AGUA, LOS CARACOLILLOS, TIERRA DE CANGREJO, 21 IKINES
CONSAGRADOS, ERU, OBI, KOLÁ, OBI MOTIWAO, OSUN, TIERRA DEL MONTE, TIERRA DE LA
PARTE DE DEBAJO, DEL MEDIO Y DE LA PARTE SUPERIOR DE UNA LOMA, TIERRA DE UN
POZO CIEGO, DE LA TUMBA DE UN PRESIDENTE O DE UN GENERAL, CABEZA Y PATAS DE
TINOSA, CABEZA Y PATAS DE LECHUZA, 21 PIMIENTA DE GUINEA, 21 PIMIENTAS NEGRA
(DE COCINAR), 21 PIMIENTAS DE MARAVILLA (AGUMÁ), 21 PIMIENTAS CHINAS, JUTÍA Y
PESCADO AHUMADO, MANTECA DE COROJO, MAÍZ TOSTADO, 7 AGUJAS, 7 ANZUELOS,
L PLUMA DE LORO. LOS DEMÁS INGREDIENTES SECRETOS.
A LA MASA SE LE DA UN POLLITO CHIQUITO (JIO JIO) Y UN HUEVO DE GALLINA.
ESTE ESHU-ELEGBA VIVE SOBRE UNA GUATACA Y ES DONDE SE LE DA DE COMER.

ESHU-ELEGBA OBASIN-LAYE:
ESTE ACOMPAÑA A ODUDUWA Y VIVE DENTRO DE UNA JÍCARA, Y VA SEMBRADO EN LA
CAZUELA DE BARRO (IKOKO). SE MONTA EN CARACOL COBO QUE SE LAVA ANTES CON
OMIERO DE HIERBAS DE OBATALÁ Y DE ESTE IFÁ Y DE ESHU-ELEGBA. SE ADORNA CON
UNA MANO DE 21 DILOGUNES POR SU PARTE EXTERNA SOBRE EL CEMENTO QUE QUEDA
SOBRE LA CAZUELA Y LA BASE DEL COBO.
LA CARGA LLEVA:
CAMALEÓN, CABEZA DE CODORNIZ, TIERRA DE UN BASURERO, CÁSCARA DE HUEVO DE
GALLINA Y PALOMA, TRES IKINES, CUENTAS DE TODOS LOS SANTOS, PATAS Y CORAZÓN
DE PALOMA, JUTÍA Y PESCADO AHUMADO, 21 GRANOS DE MAÍZ, 21 PIMIENTA DE
GUINEA, RAÍZ DE HIERBA CELESTINA BLANCA, ATIPONLÁ, CEIBA, ÁLAMO, PRODIGIOSA,
ALMACIGO, JOBO, LLANTÉN, ALGODÓN, BLEDO BLANCO FINITO, BAMBÚ, CURUJEY.
PALOS:
AMASA-GUAPO, CAMBIA VOZ, BATALLA, COCUYO, RAMÓN, PARAMÍ, CEDRO.
HIERBA, ORTIGUILLA, HIERBA INÁ, CARDO SANTO, PATA DE GALLINA, INTAMOREAL,
ESCOBA AMARGA. BIBUJAGUA Y TIERRA DE CANGREJO. LOS DEMÁS INGREDIENTES
SECRETOS.
REZO:
OSHÉ BILE ESHU-ELEGBA OBASIN-LAYE OSHÉ OMOLU LOROKE OGBE SA LAROYE.

ESHU-ELEGBA AGBANIKUE:
ESTE ES DE TIERRA ARARÁ. VIVE DENTRO DE UNA CAZUELA DE BARRO Y TAPADO CON
OTRA O UNA JÍCARA GRANDE.
CARGA:
TIERRA DE CANGREJO, TIERRA DE LA SUELA DE LOS ZAPATOS. CABEZA RATÓN, GALLO,
CHIVO, TRES CARACOLES PARA OJOS Y BOCA, 41 CARACOLES PARA ADORNARLO,
TIERRA DE BIBIJAGÜERA, 21 PIMIENTA DE GUINEA, JUTÍA Y PESCADO AHUMADO,
MANTECA DE COROJO, AGUARDIENTE, VINO SECO, CABEZA DE TINOSA, DE COTORRA,
PLUMA DE TINOSA, FRIJOLES CARITA, ERU, OBI, KOLÁ, OSUN, OROGBO, AIRA, UNA
PIEDRA DE LA LOMA, RAÍZ DE CEIBA, JAGÜEY, JOBO, 21 HIERBA, 9 PALOS FUERTES
PREGUNTADOS. LOS DEMÁS INGREDIENTES SECRETOS.
SE VA A UNA BIBIJAGÜERA Y SE COGE TIERRA QUE SE MEZCLA CON 21 PIMIENTAS DE
GUINEA, ACEITE, MANTECA DE COROJO, HARINA, FRIJOLES CARITAS, MAÍZ TOSTADO.
SE LE DA UN POLLITO CHIQUITO NEGRO (IIO JIO), CUYO CUERPO SE DESBARATA Y SE
LIGA CON LA MASA Y SE ENVUELVE EN TELA BLANCA.
EN LA CASA SE PONE LA MASA DENTRO DE UNA CANASTITA Y A ESTA SE LE AMARRA
UN CHIVO PEQUENO Y UN GALLO, SE LE DAN TRES VUELTAS Y SE ENTRA PARA EL
CUARTO. SE LE DA EL CHIVO Y EL GALLO A ESHU-ELEGBA DEL AWÓ ECHÁNDOLE DE
AMBOS ANIMALES A LA MASA QUE ESTA EN LA TELA BLANCA DENTRO DE LA CANASTITA.
LOS ANIMALES SE TUESTAN SU CABEZA Y EL CUERPO SE COME Y SE LE ECHAN LAS
CABEZAS TOSTADAS A LA MASA. CON LA PIEDRA SE PREPARA LA FIGURA Y EN LA
FRENTE SE LE PONE UNA CAMPANITA CHIQUITA CON SU BADAJO, A CONTINUACIÓN SU
CORONA CORRESPONDIENTE CON SUS PLUMAS DE LORO, CUENTAS DE ORÚNMILA, ETC.
Y EN EL OCCIPUCIO UNA CUCHILLA. EN EL CUELLO LLEVA 41 CARACOLES ALREDEDOR
DEL MISMO.
CUANDO ESTE MONTADO SE LAVA Y SE LE DA DE COMER UN GALLO Y UN POLLO. PARA
DARLE DE COMER SE PREPARA UNA JÍCARA CON: SIETE PIMIENTAS DE GUINEA,
MANTECA DE COROJO, HARINA, JUTÍA Y PESCADO AHUMADO, MAÍZ, QUE SE PONE AL
LADO DE ESHU-ELEGBA AGBANIKUE Y SE LE ECHA SANGRE DEL GALLO Y DEL POLLO. A
ESTA JÍCARA SE LE ECHAN LAS CABEZAS DE ESOS ANIMALES AL MOMENTO DE
SACRIFICARLOS Y DESPUÉS SE LE LLEVA A ESHU-ELEGBA A LA LOMA. ESHU-ELEGBA
AGBANIKUE SE CUBRE CON UNA CAZUELA O JÍCARA GRANDE Y VIVE ENTRE MARIWÓ.
SE CUBRE PORQUE PUEDE DEJAR CIEGO AL QUE LO MIRE DIRECTAMENTE.''',
    rezosYSuyeres: '''REZO:
ORÚNMILA NI ODI ELESE MESA, MONI ODI MESE ONI OKO MESE TIRE KO BAJA.

REZO:
BABA EJIOGBE ORÚNMILA MIGBATI OLOGBA ASHE LAWO OLODUMARE ORUBO. OLORDUMARE
MEWA FI ASHO FUN MIGBATI GBOGBO KIYE GBOGBO OTIGBA ASHE LOWO OLORDUMARE
AWON NIWO TO GBOGBO EYI TI SHINSHE LATI IBA MOWA NI AMUPE ASHO.

REZO:
BABA EJIOGBE ONI WAYU OWO OBA OÑI ODE ADIFAFUN IFE LOYA TINSHOMOBE GBOGBO
KOEYEBO AGBOBOADIE LEBO, ONI LENO OWO BOYURINA ONA DAKE
ADIFAFUN ORIBIDE, ADA, ARIDA, TUTU AGUTAN LEBO, OPOLOPO OWO
ADASILA KOSILE, INSHERI LEBO.

REZO:
BABA EJIOGBE ALALOKUN MONI LEKUN OKO, AYA LALA OMODU
ABOSHUN OMO ONIKOSHE OISHE KAMU ILEKE OMO LERI ADIFAFUN
ALADESHE IMAPAPORO TIMBALORDI AGOGO.

REZO:
BABA EJIOGBE ALALAKUN OBA ONI FAKUN BABA AUN BINIYA OKUN DABA
ALALA BI OKU BABA OTOKO BABA ARARRORO ATONO NISHE IFA BABA
OFIDEYABA LODAFUN BARABAIREGUN.

REZO:
BABA EJIOGBE IBE ALAPILI YOKO DIDO BABALAWO LODAFUN BARABA
ODDUN ONIRE DAFUN.

REZO:
ETA ONI BABALAWO LODAFUN ARDERE. AWO ARDERETE ORUBO AUN META.

REZO:
ERIN ONO BABALAWO LODAFUN AREBE OKO AWO AREBEOKO KORUBO
NI ARAYE AFIBORAN SHE UNYO. IFA ONI BABALAWO LODAFUN ADFA ORUBO AUN MEFA.
EYI ONO BABALAWO LOFAFUN BARABARIREGUN ONI BABALAWO ONI BARABANIREGUN
ORUBO AUN MESAN MEFAKI AYA OBANIRI KOBESA LASHARE. EWA ONI BABALAWO
LODAFUN BARABANIREGUN AWO BARABANIREGUN ORUBO AUN MEWA LAWAGIRO ADO
AWO LAWAGORI ILE AWO.

REZO:
BABA EJIOGBE ONI TEGUN ONI TOSAN ENLO SODE ONI YERI; ENLALO
OFE OYE ODUWA TANI AUN SOYE KETEFA AYA TOYA TAMI; OBA OPA OLOKUN
KOTAKUN KITAKUN OMI GODO AWO APALOKUN; BANILU BANLORUN GBOGBO
LOWAYU PETUKIE SODE ALAGUEDE; OMA ORIKU BABAWA.

SUYERE:
BABA EJIOGBE ORÚNMILA NIODERE LEYERI ERAN.
BABA EJIOGBE ORÚNMILA NIODERE LEYERI EKU.
BABA EJIOGBE ORÚNMILA NIODERE LEYERI EYA.
BABA EJIOGBE ORÚNMILA NIODERE LEYERI EPO.
BABA EJIOGBE ORÚNMILA NIODERE LEYERI ADIE.
BABA EJIOGBE ORÚNMILA NIODERE LEYERI EURE.
NIODERE LEYERI ASHANA IKU.
NIODERE LEYERI ASHANA ARUN.
NIODERE LEYERI ASHANA OFO.
NIODERE LEYERI ASHANA EYO, ONA, OGU, ETC.

SUYERE:
TINI YOBI ABE OBILENA ADAFUN GBOGBO TENUYEN ABANSHE; KE
ASHOKO ODUFUO BEWA.''',
    obrasYEbbo: '''OBRAS DE BABA EJIOGBE.

EBO
PORRONES META, GRANADA, CARBON, AKUKO, EYELE MEYI, OPOLOPO OWO.

EBO
AKUKO MEYI, ADIE MEYI, ATITAN DE LA PLAZA, ATITAN; ERITA MERIN, ATITAN ELESE OLE,
ATITAN ILE IBU, GBOGBO ASHE, OPOLOPO OWO.

EBBO PARA IKU UNLO:
UN ANIMAL PODRIDO QUE SE ENCUENTRE MUERTO EN LA CALLE, QUE SE PONE DENTRO
DE UNA CANASTICA. AL INTERESADO SE LE HACE SARAYEYE CON ADIE FUN FUN Y SE LE
ECHAN JUJU A LA CANASTICA. LAS DOS ADIE FUN FUN SE LE DAN A ODUDUWA. LA
CANASTICA SE PONE EN EL PORTAL DE LA CASA LOS DIAS QUE DIGA IFA.

EBBO INTORI ARUN:
LERI DE ABO, IGBA CON AÑARI, ORUN, ADIE, LA ROPA QUE TENGA PUESTA, EKU, EYA.
SE DESNUDA A LA PERSONA Y SE LE ECHA LA AÑARI POR ENCIMA PARA QUE CORRA POR
SU CUERPO, SE RECOGE Y SE VA PARA EL EBBO.

EBBO PARA AWO BABA EJIOGBE:
AKUKO, ETU, EYELE, TRES IGI DISTINTAS, UN ENI ADIE, UN ENI DE ETU, UN ENI DE
EYELE, JUJU META DE CADA UNA DE ESAS AVES, ASHO ARAE, GBOGBO ASHE, OPOLOPO
OWO.

EBBO PARA REFRESCAR EL OSHE:
AKUKO, ADIE MEYI, OSHE META, AWAAN (CANASTICA), ETA META, EKU, EYA, EPO,
OPOLOPO OWO. SARAYEYE AL INTERESADO CON EL AKUKO Y LA ADIE Y SE LE DAN A
ESHU Y A ORÚNMILA. LOS OSHE (JABONES) SE CARGAN CON LA EYERBALE DE ESHU Y
DE ORÚNMILA PARA QUE EL INTERESADO SE BAÑE CON ELLOS. LA CANASTICA
UNBEBOLO. LAS ETA META SE ENTIERRAN EN EL PATIO DE LA CASA.

PRIMER EBO
OSIADIE FIFESHU, UN GUIRO, EKU, EYA, EPO, EYA TUTO META, ABITI, OBE, TIERRA DE
UN CAMINO Y DEMAS INGREDIENTES, OPOLOPO OWO. LLEVARLO A UN CAMINO Y
PONERLO AL LADO DE UNA CASA VIEJA, REGRESAR A LA CASA DEL AWO, SALUDAR A
ELEGBA, TOMAR AGUA Y DESCANSAR UN RATO.

SEGUNDO EBO
UN JIO JIO, UN IGBON (PORRON) CON OMI, UNA ELEGUEDE, ASHO ARAE, TIERRA DE UN
CAMINO, ATITAN ILE, ATITAN BATA, EKU, EYA, EPO. LLEVARLO AL MISMO LUGAR QUE
EL ANTERIOR, REGRESARLO A CASA DEL AWO, SALUDAR A ELEGBA, TOMAR UN POCO
DE AGUA Y DESCANSAR UN RATO.

TERCER EBO
UN OWUNKO KEKE, ANA ADIE, ASHO APERI, UNA FREIDORA, UN GUIRO, 16 EYELE FUN
FUN, 16 VARAS DE ASHO FUN FUN, EKU, EYA, EPO. LLEVARLO AL MISMO LUGAR QUE
LOS ANTERIORES Y DESPUES REGRESAR PARA SU CASA.

NOTA: CUANDO BABA EJIOGBE NO COJA EBBO, SE COLOCA UNA ANGUILA DENTRO DE
UNA PALANGANA CON AGUA, SE LE PRESENTA A OBATALA CON EYELE META FUN FUN Y
SE ARRODILLA DELANTE DE BABA HASTA QUE LA ANGUILA MUERA. ENTONCES SE
COGE LA ANGUILA, SE ABRE Y SE LE DAN LAS TRES EYELE. LA LERI, ELESE Y AKOKAN
META DE LAS EYELE SE HACEN CON IYE Y SE LIGA CON IYE DE SEMILLA DE ELEGUEDE,
EWE BLEO BLANCO, ORI, EFIN. SE REZA EN ATEPON IFA; POR ESTE ODDUN Y SE
MONTA UN INSHE OZAIN (OSANYIN).

OBRA PARA ASCENDER EN EL GOBIERNO O TRABAJO:
SE HACE UNA TORRE DE ALGODON, DENTRO SE LE PONEN LAS GENERALES DE LOS QUE
TENGAN QUE VER CON EL ASUNTO DEL ASCENSO, SE LE ECHA OÑI Y EFUN. SE EMBARRAN
DOS ITANA EN OÑI E IYOBO FUN FUN Y SE LE ENCIENDEN A OBATALA AL LADO DE LA
TORRE DE JUEVES A JUEVES. ANTES DE IR A ESE LUGAR SE LE DARA OCHO EBEMISI
CON EWE: DORMIDERA Y OCHO CON CAMPANA BLANCA Y CADA VEZ QUE VAYA A ESE
LUGAR SE UNTARA EN LA CARA IYE DE EWE: DORMIDERA, CENIZAS DE JUJU DE EYELE
FUN FUN Y EFUN. CADA VEZ QUE SE TERMINE LA ITANA, SE RENUEVAN LOS JUEVES.
CUANDO SE CONSIGA EL ASCENSO SE CUMPLIRA CON OBATALA.

POR INTORI ARUN:
SE LE DA EYELE DETRAS DE ELEGBA. MARCA PROBLEMAS EN LA VALVULA MITRAL.

PARA QUITAR OGU DEL ESTOMAGO:
MAMU INFUSION DE RAIZ DE POMARROSA, RAIZ DE PEONIA Y ABANICO DE MAR.

PARA QUE EL AWO PUEDA HABLAR A IFA:
SE PREPARA UN INSHE OZAIN CON MONEDAS DE PLATA DE DIEZ CENTAVOS.

PARA RESOLVER SITUACION:
LERI DE EKU, DE EYA TUTO, OBI KOLA, OBI MOTIWAO.

PARA RESOLVER SITUACIONES O DIFICULTADES CON LAS MUJERES:
SE LE PONE A ORÚNMILA UNA JUTIA AHUMADA QUE SE AMARRA POR LA CINTURA CON UN
COLLAR DE BANDERA Y SE LE DAN DOS ADIE DUNDUN A ORÚNMILA.

OBRA PARA LA IMPOTENCIA:
SE COGEN DOS ISHERI (CLAVOS) DE MARCOS DE PUERTAS Y SE CORTAN A LA MEDIDA DEL
PENE, SE LAVAN CON OMIERO DE EWE GUENGUERE, DESPUES SE COME COMO ENSALADA.
SE HACE EBBO TETEBORU (EBBO DEL ODDUN) Y DESPUES UNO DE LOS ISHERI SE PONE
COMO REFUERZO DE OGGUN Y OTRO DENTRO DE SU IFA.

OBRA PARA EVITAR PROBLEMAS CON EL AHIJADO:
SE COGE UN AKUKO FUN-FUN SE LE LIMPIA CON EL MISMO, SE LE ABRE EL PECHO CON
EL OBE DEL PINADO Y LO CARGA CON CARACOL DE OSHA LAVADO CON ELEGBA, UN PAPEL
CON LAS GENERALES Y EL ODDUN DEL AHIJADO Y BABA EJIOGBE. SE PONE EL ARA DEL
AKUKO DELANTE DE ELEGBA Y POR LA NOCHE SE LLEVA A ENTERRAR A LA ORILLA DEL
MAR Y SE DICE:
"CUANDO ESTE AKUKO POR SI MISMO LOGRE SALIR DEL JORO-JORO ENTONCES SE
ROMPERA LA AMISTAD CON MI AHIJADO."

PARA VENCER A LOS ARAYES:
SE PONE UN PLATO PINTADO DE DUN-DUN DONDE SE PINTA BABA EJIOGBE, ENCIMA SE
COLOCA UNA IGBA CON SIETE CLASES DE BEBIDAS, ALREDEDOR DE ESTO SE PONEN 16
PEDAZOS DE OBI CON UNA ATARE SOBRE CADA UNO.
ACTO SEGUIDO SE LE DA ADIE MEYI DUN-DUN A ORÚNMILA (UNA FUNFUN Y UNA
DUN-DUN). LA ADIE DUN-DUN QUE ES LA SEGUNDA QUE SE SACRIFICA SOLO SE LE DA AL
PLATO A LOS OBI. SE ENCIENDE ITANA MEYI EN EL PLATO, QUE ES DONDE SE HACE LA
OBRA. AL TERMINO DE 16 DIAS SE RECOGE TODO Y SE BOTA EN LA ESQUINA. EL PLATO
Y LA IGBA SE GUARDAN PARA USARLA EN OTRAS COSAS.

PARA VENCER A LOS ARAYES:
SE COGEN TRES GUIROS DE CUELLO LARGO, EN UNO SE ECHA ALMAGRE, EN OTRO EFUN
Y EN EL TERCERO IYE DE CARBON DE IFA (DE OZAIN). SE PASAN POR EL TABLERO Y SE
ECHA IYEFA, SE ATAN CON TRES HILOS Y SE LES DAN TRES ADIE, UNA PUPUA AL
ALMAGRE, UNA FUN-FUN AL EFUN Y UNA DUN-DUN AL QUE CONTIENE IYE DE CARBON DE
OZAIN. DESPUES LOS TRES GUIROS SE LE PONEN A ELEGBA.

OBRA PARA LEVANTAR LA SALUD:
CON IRE ASHEGUN OTA O IRE AYE, SE RUEGA LA LERI CON: ETU MEYI, UNA FUN FUN Y
UA JABADA. SI LA PERSONA ES COMO SHANGO, KOBORI APARO MEYI Y QUE LA EYERBALE
CAIGA SOBRE SHANGO.

OBRA PARA EJIOGBE:
EN UNA CAJITA DE MADERA SE PONE UNA TINAJITA CON AGUA Y ARENA DEL RIO Y OTRA
CON AGUA Y ARENA DE MAR, APARTE SE LE PONE EFUN, ORI, EKU, EYA, AWADO. A ESTO
SE LES DA EYELE MERIN FUN FUN Y LAS LERI SE ECHAN DENTRO DE LA CAJITA Y SOBRE
LA TAPA SE PONEN DOS OBI PINTADOS DE EFUN Y SE COLOCA LA CAJITA DEBAJO DE LA
CAMA DEL INTERESADO. AL CUMPLIRSE EL AÑO DE HABERSE HECHO LA OBRA, SE
RASPAN LOS OBI EN LA CALLE, SE RELLENAN LAS CAZUELITAS CON SUS
CORRESPONDIENTES AGUAS, A LO DE ADENTRO SE LE VUELVE A DAR EYERBALE DE
EYELE MERIN FUN FUN Y SE VUELVE A SELLAR DESPUES DE ECHARLE LAS OBRAS
CORRESPONDIENTE LERI, SE CIERRA LA CAJITA Y SE LE PONE ENCIMA DOS OBI NUEVOS
PINTADOS DE EFUN Y SE VUELVE A COLOCAR DEBAJO DE LA CAMA EN LA CABECERA
DEL INTERESADO.

OBRA PARA QUE ELEGBA TRABAJE:
SE COGE UNA IGBA CON AGUA, SE PICAN 16 ILE BIEN FINITOS Y SE LE ECHA IYE O IYEFA.
SE REVUELVE CON LA PUNTA DEL IROFA REZANDO BABA EJIOGBE Y SE LE ECHA POR
ENCIMA A ELEGBA.

INSHE OZAIN PARA IRE UMBO (SUERTE):
UN PESO PLATA, AKOKAN DE ETU, INSO DE EURE, ATARE, IYEFA, OBI MOTIWAO, OBI KOLA,
ANUM, AIRA, EKU, OTI, OÑI. ANTES DE CERRARLO SE LE ECHA OMI ABARO. SE FORRA EN
INSO DE EKU. VIVE DETRAS DE ORÚNMILA.

PARA OBTENER LA SUERTE:
SE HACE EBBO CON: ABO, OWUNKO, AKUKO META, ADU-ARA, CARTERA DE PIEL, 16
MATAS, AWADO, UNA OTA, DOS TOBILLERAS DE PIEL CON OCHO CASCABELES Y OCHO
DILOGUNES CADA UNA O CON DOS CASCABELES Y DOS DILOGUNES CADA UNA. ESTO ES
DE ACUERDO A LO QUE SE PONGA EN LAS TOBILLERAS, PUES SI SE LE PONE DILOGUNES
ENTONCES DOS CASCABELES AL EBBO Y VICEVERSA. EL OWUNKO Y EL AKUKO PARA
ELEGBA, EL ABO Y UN AKUKO PARA SHANGO; UN AKUKO PARA OZAIN (OSANYIN). LA
CARTERA SE ADORNA CON JUJU DE DISTINTOS EIYE VISTOSOS Y DENTRO DE ELLA SE
ECHA TODO LO DEMAS Y SE LE PONE AL OSHA QUE HAYA DETERMINADO IFA.

PARA LA RECRIMINACION DE LOS ADEUDOS:
SE LE DA AKUKO A OGGUN, ANTES ORUBO CON EL AKUKO Y ERAN MALU. SE HACE
APAYERU Y SE LIGA CON UN POCO DE IYEFA USADO CON UN POCO DE HOJAS Y SEMILLAS
DE MARAVILLA Y SE SOPLA TRES DIAS HACIA LA CALLE, Y ASI SE LIBRARA DE LOS
ARAYES. POR ESTE IFA SE PONE DENTRO DE ORÚNMILA PEDACITOS DE ORO Y PLATA.

PARA EVITAR EL ATRASO:
16 OBI, 16 EWEREYEYE, 16 CAPULLOS DE OU, 16 PESOS PLATA, UN CALZONCILLO O
CAMISON DE CUATRO COLORES RITUALES QUE SE USA NUEVE DIAS Y DESPUES SE LE
PRESENTA A OBATALA JUNTO CON UNA ESCALERA DE 16 PASOS O ESCALONES. LOS OBI
SE PONEN A LA ORILLA DEL MAR PARA QUE LAS OLAS SE LOS LLEVEN.

OBRA A OSHOSI:
A OSHOSI SE LE ENCIENDE UNA ITANA, SE LE SOPLA ANISADO U OTI Y SE LE ECHA HUMO
DE ASHA (TABACO) Y SE LE RUEGA QUE LO LIBERE Y LE LIMPIE EL CAMINO PARA
TRIUNFAR EN LA VIDA.

PARA PROSPERAR:
SE LE DA A OBATALA ADIE MEYI FUN-FUN, A OSHUN DOS EYELE FUN Y DESPUES SE DARA
SEIS ABOMISI CON: ALBAHACA CIMARRONA, PIÑON DE ROSAS Y PRODIGIOSA Y CON ESO
MISMO RALDEA LA CASA.

PARA QUE IKU SIGA SU CAMINO:
UNA LERI DE OWUNKO, SE QUEMAN LOS PELOS Y SE UNTAN EN LA CARA Y EN SHILEKUN
ILE. DESPUES CON LA LERI Y LO DEMAS QUE MARCA IFA SE HACE EBBO. SE ABRE UN
KUTUN EN EL PISO DE LA COCINA, SE COLOCA UN ASHO FUN-FUN DONDE SE PINTA CON
OSUN NABURU OSHE TURA, BABA EJIOGBE, OTURA SHE, SOBRE ESTO SE PONEN LAS
HOJAS DE YAYA MANSA Y ENCOMA LIMAYAS DE HIERRO. EL INTERESADO CON SU LERI
TOCA TRES VECES LA LERI DEL OWUNKO USADA PARA ESTO PARA QUE ESA REEMPLACE
LA SUYA DELANTE DE IKU. SE PONE A ELEGBA AL LADO DEL KUTUN, SE LE DA OBI OMI
TUTU A LO DEL KUTUN LLAMANDO AIKU. SE SACRIFICA EL OWUNKO ECHANDOLE
EYERBALE A ELEGBA Y A LO QUE ESTA DENTRO DEL KUTUN. LA LERI DEL OWUNKO PARA
EL KUTUN. EL ARA DEL OWUNKO SE RELLENA Y SE MANDA PARA EL PIE DE UNA CEIBA.
SE ECHA OPOLOPO EPO SOBRE LA LERI DEL OWUNKO EN EL KUTUN, SE CUBRE CON UNA
IKOKO DE BARRO EN LA QUE SE PINTA UN ATENADO EGGUN Y SE ECHA AÑARI EN EL
KUTUN HASTA CUBRIR LA IKOKO, ENTONCES SE PONEN TRES OTA, ENCIMA SE PONE UNA
HORNILLA Y SE COCINA CON LEÑA DURANTE 16 DIAS PARA QUE EL CALOR DE LA
CANDELA LO MEZCLE TODO DENTRO DEL KUTUN Y ASI SE RECOCINE LA LERI DEL OWUNKO
QUE REPRESENTA A ARUN E IKU Y DEJEN TRANQUILO AL AWO BABA EJIOGBE.

SECRETO PARA OFIKALE TRUPON ODARA:
RESINA DE PINO DILUIDA EN AGUA, CON EL DEDO DEL MEDIO SE LE UNTA A LA OBINI EN
EL CLITORIS, SE REZA BABA EJIOGBE.

POMADA PARA OKO PARA OFIKALE TRUPON:
POMADA ALCANFORADA, IYE DE IGI: NO ME OLVIDES, ESPUELA DE CABALLERO Y
PARAMI. SE REZA OGBE TUA, IROSO FUN, OTURA, OKANA YEKU, OKANA SA BILARI Y
BABA EJIOGBE. SE UNTA EN EL GLANDE ANTES DE OFIKALE TRUPON.

OPARALDO DE BABA EJIOGBE:
ESTE SE HACE CON ELEGBA LLEVA TODOS LOS INGREDIENTES DE UN OPARLADO, UNA
EYELE FUN FUN, LOS ASHO RITUALES, UN JIO JIO. EN LOS ASHO SE PINTA ODI FUNKO; SE
HACE UN CIRCULO DONDE SE PINTA OTURA NIKO, BABA EJIOGBE, OKANA YEKUN. SE
PARA AL INTERESADO AL LADO DEL TRAZO DE BABA EJIOGBE CON ELEGBA DETRAS Y
DOS ITANA ENCENDIDAS. SE HACE OPARALDO CON LA EYELE Y LOS EWE: ALGARRABO,
ALBAHACA MORADA, ABERIKUNLO (ESPANTA MUERTO) Y ALGUNAS MAS SI LAS COGIO.
TERMINADO EL OPARALDO, TODO SE ENVUELVE EL EL ASHO Y DESPUES EN PAPEL
CARTUCHO, LLAMANDO A ELEGBA Y SE LE DA UN JIO JIO QUE SE BOTA EN EL NIGBE CON
EKU, EYA, EPO, AWADO, ONI, OTI, ETC.

OPARALDO META DE BABA EJIOGBE:
PRIMER OPARALDO:
A LAS SEIS DE LA MAÑANA CON: ASHO DUN DUN Y FUN FUN, UNA ITANA, OTI, EWE:
YEWERE (CIRUELA), MARPACIFICO, ALAMO, GRANADA, ALMACIGO, PARAISO, ALGARROBO,
ESPANTA MUERTO Y ALBAHACA. CON OMIERO DE TODAS ESTAS EWE SE BAÑARA, TODAS
LAS ROPAS QUE SE QUITO JUNTO CON LOS ZAPATOS VAN PARA EL RIO JUNTO CON
OPARALDO.
SEGUNDO OPARALDO:
A LAS DOCE DEL DIA. UN OSIADIE DUN DUN, FUN FUN Y PUPUA, ITANA MEYI, OTI, EWE:
ESPANTA MUERTO, ESCOBA AMARGA, ROMPE SARAGUEY Y PARAISO. SE MARCA BABA
EJIOGBE.
TERCER OPARALDO:
A LAS SEIS DE LA TARDE. UN OSAIDIE, ERAN MALU, ASHO DE NUEVE COLORES, EWE:
ALBAHACA MORADA, ALGARROBO, GRANADA, ESPANTA MUERTO Y ALBAHACA. VA
AMARRADO CON TIRAS DE ASHO. NO LE PUEDE FALTAR EL OTI NI LAS ITANAS. SE MARCA
BABA EJIOGBE. DESPUES DE TERMINADO EL TERCER OPARALDO EL INTERASADO SE
BAÑA Y SE LE RUEGA LA LERI. ESTOS TRES OPARALDOS EL MISMO DIA TIENEN UNA
VARIANTE:
SE HACE EBBO OPARALDO Y SE REZAN SOLO LOS ODDUN OMOLU. A CONTINUACION DE
HABER HECHO EL PRIMER OPARALDO, ENTRA A BAÑARSE. SE LE HACE EL SEGUNDO
OPARALDO, ENTRA A BAÑARSE. CUANDO SALGA DEL SEGUNDO BAÑO SE CONTINUA EL
EBBO REZANDO SOLO LOS OYU ODDUN O MEJIS HASTA TERMINAR EL EBBO. A
CONTINUACION SE LE HACE EL TERCER OPARALDO, SE BANA Y SE SALE A BOTAR EL EBBO
Y LOS TRES OPARALDOS QUE SE HICIERON CON JIOJIO META Y EYELE META.

OFRENDA A OBATALA A TRAVES DE BABA EJIOGBE:
PARA HACERLE UNA OFRENDA A OBATALA A TRAVES DE BABA EJIOGBE, SE PREPARA EL
PLATO COMO PARA SHANGO, SE ESCRIBE EL SIGNO BABA EJIOGBE. SE LE DA OBI OMI
TUTU PARA VER SI LO RECIBE Y SE LE PONE LA OFRENDA EN EL PLATO.

OPARALDO ESPECIAL:
SE CONFECCIONA UNA ATENA CON LA SIGUIENTE FORMA:
[[ATENA]]
LO PRIMERO QUE SE HACE ES LIMPIAR AL INTERESADO CON: EKU, EYA, EPO, EFUN, ORI,
ERAN MALU, Y SE LE PONEN TODOS LOS SIGNOS MENOS EN: EJIOGBE, OYEKUN MEYI,
IWORI MEYI, ODI MEYI. PARA ESTOS ODDUN MEYI SE COJERAN 4 TARROS O 4 PEDAZOS
DE PALMA, SE LIMPIARA AL INTERESADO Y SE COLOCARA SOBRE LOS ODDUN MEYI ANTES
MENCIONADOS.
SE PREPARA UN OMIERO CON AÑIL, ALGARROBO, ESPANTA MUERTO, GRANADA, PARA
DESPUES BORRAR LOS SIGNOS CANTANDO EL SIGUIENTE SUYERE:
OBINI LEKUN BABA EGGUN NIREGUN ORUYEREO EGGUN ONIDORUN; FAYARA OKANA
EGGUN ONILORNO FALCARA AGARA.
EN CADA TARRO DE BUEY O PEDAZO DE PALMA SE ECHA UNA BRAZA DE CANDELA,
TERMINADO DE DARLE CANDELA, CON UNA EYELE DUNDUN. SE LIMPIA A LA PERSONA Y
A UNO MISMO. SE LE HACE UNA CRUZ EN LA NUCA O IPAKO PROCEDIENDO A MATAR A LA
EYELE LO QUE SE HARA EN UNA JICARA CON EL SIGUIENTE SUYERE:
EYELE, EYELE DUN-DUN BAWA; EYE EYELE, EYELE DUN-DUN BAWA; EYE EYELE
OLORDUMARE EGGUN SONIA ABEREGUN.''',
    diceIfa: '''• HACE MUCHO QUE USTED QUIERE ENCONTRAR LA TRANQUILIDAD, PERO HAY PERSONAS QUE POR UNA CAUSA U OTRA LE TRASTORNAN TODOS SUS BUENOS IDEALES.
• USTED TUVO UN SUEÑO Y SE SORPRENDIO, SE LE APARECIO UNA PERSONA DIFUNTA QUE LE PIDE MISA. CUMPLA CON ESE DIFUNTO PARA QUE LE DE UNA SUERTE QUE DEJO EN ESTE MUNDO.
• A USTED SE LE OLVIDAN LOS SUEÑOS, CUANDO LOS RECUERDE NO LOS CUENTE A NADIE PARA QUE NO SE ATRASE.
• USTED SOÑO CON UN CAMINO MUY TORTUOSO Y AL ENCONTRAR LA SALIDA DESPERTO, SEA OBEDIENTE PARA QUE SU CAMINO O FUTURO NO SEA TORTUOSO Y DESASTROSO. RECUERDE SI EN ESE SUEÑO USTED VIO UN CAMINO SEMBRADO DE MAIZ. SI LA PERSONA DICE QUE SI: SE LE DICE, QUE LE DE GRACIAS A OBATALA PORQUE VA A TENER NOTICIAS DE UN FAMILIAR QUE ESTA EN EL EXTRANJERO.
• CUIDESE DE CHISMES Y ENREDOS PORQUE PUEDEN TERMINAR EN LIO DE JUSTICIA.
• NO SE DEJE LLEVAR POR LA TENTACION PORQUE SI SE DECIDE HACER UNA COSA MALA LO VAN COGER INFRAGANTI, PASARA UN BOCHORNO Y DEBERA RESPONDER ANTE LA JUSTICIA Y HASTA PUEDE PERDER SU TRABAJO.
• EN SU BARRIO HAY UN POLICIA O GUARDIAN QUE VIGILA PERO PRONTO SE IRA DE ALLI.
• EN SU VIDA USTED HA TENIDO O TENDRA QUE VER CON CUATRO MUJERES DISTINTAS: UNA ES VIRGEN, OTRA PEQUEÑA Y MUY CHISMOSA, LA OTRA ES BUENA PERO LA CUARTA ES LA DE COLOR DE PIEL MAS OSCURO Y LA QUE MAS LO QUIERA Y SE PREOCUPE POR USTED.
• SI USTED ABANDONO A UNA MUJER, ELLA LO MALDICE, ES HIJA DE YEMAYA QUE LE DABA LA SUERTE A USTED, CUANDO SE LA ENCUENTRE EN SU CAMINO NO LA DESPRECIE, TRATELA CON CARIÑO Y HAGALE UN REGALO PARA QUE TERMINE LA MALA VOLUNTAD QUE LE TIENE.
• USTED SE SEPARO DE UNA MUJER PORQUE LE FALTO Y LO OFENDIO MUCHO, NO LE GUARDE RENCOR PARA QUE NO SE ATRASE.
• UNA MUJER SE FUE DE SU LADO Y CUANDO VOLVIO YA USTED TENIA OTRA Y AHORA USTED ESTA CON LAS DOS.
• HAY UNA MUJER QUE PRETENDIO HACERLE UNA IMPOSICION AL MARIDO Y EL NO LO PERMITIO, SE SEPARARON Y AHORA ELLA LE ECHA POLVOS CADA VEZ QUE PUEDE, PERO COMO LOS SANTOS ESTAN CON EL HOMBRE ESA ES LA RAZON POR LO QUE NO LE HA SUCEDIDO NADA.
• USTED TIENE MUCHOS ENEMIGOS PERO ELLOS NO PODRAN HACERLE NADA PORQUE SU ANGEL LO PROTEGE.
• USTED VINO AL MUNDO PARA GOBERNAR PERO USTED HA REHUIDO ESE GOBIERNO Y ESE ES EL MOTIVO DE TODO SU ATRASO Y CONTRARIEDADES QUE ESTA PASANDO.
• SI USTED NO TIENE LOS GUERREROS, TIENE QUE RECIBIRLOS Y SI LOS TIENE, HACE MUCHO TIEMPO QUE USTED NO SE OCUPA DE ATENDERLOS COMO DEBE.
• HAY VECES QUE A USTED LE CUESTA MUCHO TRABAJO RESOLVER SUS COSAS SATISFACTORIAMENTE.
• HAY MOMENTOS QUE LE FALTA DE TODO AL EXTREMO QUE PIERDE LA FE.
• SE PASA MUCHO TRABAJO EN LA VIDA SI LA PERSONA NO OBEDECE A ORÚNMILA.
• ESAS ETAPAS DE ADVERSIDADES SON PRUEBAS DE SU ANGEL DE SU GUARDA, CUANDO SE ESTE PASANDO POR ESTA SITUACION TENGA MUCHA CALMA Y PACIENCIA PARA QUE NO FRACASE Y NO RENEGAR Y NO PERMITIR QUE NADIE LO HAGA EN SU CASA PARA QUE SU ANGEL NO LE VIRE LAS ESPALDAS. RIA Y CANTE PARA QUE SU ANGEL LE AYUDE, PORQUE ESTE IFA MARCA PARALIZACION POR ALGUN TIEMPO DE LA ACCION BIENHECHORA DE LOS ASTROS QUE GUIAN SU VIDA, POR LO QUE USTED PUEDE VERSE SIN TRABAJO, SIN CASA, ENFERMO, ETC. EN FIN ES LA PARALIZACION DE TODO LO QUE A USTED LE BENEFICIA.''',
    refranes: '''1. NACIÓ PARA GOBERNAR.
2. REY MUERTO, REY PUESTO.
3. LA CABEZA MANDA AL CUERPO.
4. LA CABEZA MANDA EN EL CUELLO.
5. TODO LO TENGO Y TODO ME FALTA.
6. EL CAMINO ES LIBRE PARA EL PERRO.
7. LA CORONA DEL GALLO ES SU CRESTA.
8. UN SOLO REY GOBIERNA A SU PUEBLO.
9. LA PIEDRA CHINA NUNCA SE ABLANDA.
10. NO TAN POBRE QUE SE LE VEA EL ANO.
11. DOS AMIGOS INSEPARABLES SE SEPARAN.
12. LAS DEUDAS CUELGAN EN NUESTRO CUELLO.
13. LA FELICIDAD EN CASA DEL POBRE, DURA POCO.
14. CARACTERES SIMILARES, FORJAN UNA AMISTAD.
15. EL MAR HIZO SACRIFICIO Y VOLVIÓ A SU HUECO.
16. SOBREVIVIRÉ A LAS FRÍAS MANOS DE LA MUERTE.
17. NADIE SE COME LA TORTUGA CON EL CARAPACHO.
18. LAS MANOS ALCANZAN MÁS ALTO QUE LA CABEZA.
19. OLODUMARE LE DA BARBA AL QUE NO TIENE QUIJADA.
20. SOLO ORÚNMILA ES CAPAZ DE CAMBIAR LOS DESTINOS.
21. ES UN ERROR NO APRENDER DE LOS ERRORES COMETIDOS.
22. EL MÉDICO PUEDE CURAR A OTRO, PERO NO A SÍ MISMO.
23. NO HAY MAL QUE DURE CIEN AÑOS, MÉDICO QUE LO ASISTA, NI CUERPO QUE LO RESISTA.
24. HAY UN MAL QUE TOCA EN EL CIELO Y EN LA TIERRA.
25. LAS CONTRADICCIONES SACAN A LA LUZ DE SU ESCONDITE.
26. PROTECTOR DE LA CIUDAD ES EL NOMBRE DE ESHU-ELEGBA.
27. NINGÚN REY ES TAN GRANDE COMO EL MISMO ORÚNMILA.
28. ESTE RÍO Y EL OTRO RÍO TIENEN UN SOLO REY, EL MAR.
29. AQUEL QUE OCULTA SUS MALES, SERÁ ENTERRADO CON ELLOS.
30. UNA LARGA DISCUSIÓN LO LLEVA A UNO TAN LEJOS COMO IFÁ.
31. NINGÚN SOMBRERO PUEDE SER MÁS FAMOSO QUE UNA CORONA.
32. NINGÚN TRAJE ES MÁS LARGO QUE EL QUE USAN LAS BRUJAS.
33. LA PALMERA TIENE MÁS INFLUENCIA QUE LOS DEMÁS ÁRBOLES.
34. NO HAY VARIEDAD DE TELAS QUE SEA SINGULAR ENTRE LAS TELAS.
35. LA MANO ALZA MÁS ALTO QUE LA CABEZA SÓLO PARA PROTEGERLA.
36. LA BOCA DE LA ARDILLA ES LO QUE HACE PERDER LA VIDA A LA BOA.
37. PALOMA QUE CON SU PLUMAJE BLANCO NACE, JAMÁS SU COLOR CAMBIA.
38. EL AZADÓN ARRASTRA AL HOGAR REGALOS DE DENTRO Y FUERA DE LA CASA.
39. LA CONCHA DE LA BABOSA SE CONSERVA DESPUÉS DE COMERSE LA CARNE.
40. NI DE ANCHO NI DE LARGO LA MANO PUEDE SER MÁS GRANDE QUE LA CABEZA.
41. NINGÚN BOSQUE ES TAN ESPESO QUE EL ÁRBOL DE IROKO NO PUEDA SER VISTO.
42. AVECES LA MUERTE ES EL RESULTADO DE IGNORAR LOS CONSEJOS DE LOS MAYORES.
43. NO HAY MAL QUE DURE CIEN AÑOS, MÉDICO QUE LO ASISTA, NI CUERPO QUE LO RESISTA.
44. EL CERDO PUEDE PASAR LA VIDA SOBRE LA PIEDRA, PERO PREFIERE VIVIR DEBAJO DE ELLA.
45. NO HAY MAL QUE DURE CIEN AÑOS, MÉDICO QUE LO ASISTA, NI CUERPO QUE LO RESISTA.
46. POR LOS CAMINOS Y CALZADAS NO HAY DISTINCIÓN, LO MISMO CAMINA EL BUENO QUE EL MALO.
47. NINGÚN PAÑO DE CABEZA PUEDE SER MÁS ANCHO QUE EL QUE USAN LOS ANCIANOS DE LA NOCHE.
48. LA SABIDURÍA, LA COMPRENSIÓN Y EL PENSAMIENTO, SON LAS FUERZAS QUE MUEVEN A LA TIERRA.
49. TODOS LOS HONORES DE LAS AGUAS QUE HAY SOBRE LA TIERRA, SON MENORES QUE EL HONOR DEL MAR.
50. QUIEN REALIZA NUMEROSOS ACTOS MISTERIOSOS DURANTE LA NIÑEZ ES CONSIDERADO UN NIÑO PRODIGIOSO.
51. EL ESCALAFÓN DE IFÁ LLEVA A CADA AWÓ AL SITIO QUE LE CORRESPONDE SEGÚN SUS MÉRITOS Y APTITUDES.
52. LLUVIA FORMA NUBES NEGRAS EN EL CIELO PARA BIEN DE LOS SORDOS Y HACER RUIDO PARA BIEN DE LOS CIEGOS.
53. SIEMPRE QUE SE ESCUCHE MÚSICA, EL SONIDO DE LA CAMPANA SERÁ MÁS ALTO QUE EL DE LOS DEMÁS INSTRUMENTOS.
54. CUANDO NACE UN NIÑO CON CABEZA GRANDE Y CUERPO CHIQUITO, ES DE SUPONER QUE ESTE CUANDO CREZCA VIVIRÁ DE ELLA.
55. EL HOMBRE RICO COME SIN QUEJA ALGUNA, EL POBRE COME VORAZMENTE, EL POBRE QUE SE ASOCIA CON UN RICO SE VUELVE IMPERTINENTE.
56. LOS OJOS SERÁN ROJOS PERO NO CIEGOS, EL PLÁTANO PARECE MADURO PERO NO ESTÁ SUAVE, EL PROBLEMA QUE CAUSA ANSIEDAD SE RESOLVERÁ, NO MATARÁ A NADIE.
57. CUANDO LA CABEZA SE TIENE SOBRE LOS HOMBROS, EL PENSAMIENTO SOBRE EL HORIZONTE Y LOS PIES EN EL AGUA SALADA, NO NOS CABE DUDA QUE ESTAMOS FRENTE AL MAR.
58. PARA PODER ENCONTRAR A UN ELEFANTE HAY QUE IR AL BOSQUE, PARA PODER ENCONTRAR A UN BÚFALO HAY QUE IR A LA PRADERA, PERO UN PÁJARO DE AIRÓN SOLO SE PUEDE ENCONTRAR AL CABO DE MUCHO TIEMPO.''',
    historiasYPatakies: '',
  ),
  'OYEKU MEJI': OduContent(
    name: 'OYEKU MEJI',
    rezoYoruba:
        'ASHE MI ASHE DODO IKU, ARUN, OFO, ARAYE KORO KOBO ONIRE PUPURU Y ARUN OLUO AGOGO ABO LEBO AKUKO LEBO',
    suyereYoruba: '''IKU YEMILO OYERE IKU YEMILO
ARUN YEMILO OYERE ARUN YEMILO
EYO YEMILO OYERE EYO YEMILO''',
    suyereEspanol: '',
    nace: '',
    descripcion: '',
    ewes: '',
    eshu: '',
    rezosYSuyeres: '',
    obrasYEbbo: '',
    diceIfa: '',
    refranes: '',
    historiasYPatakies: '',
  ),
  'IWORI MEJI': OduContent(
    name: 'IWORI MEJI',
    rezoYoruba: 'SHEKE SHEKE SHEREWE KIRI KIRI KANWILO NO UN BATI UN POM',
    suyereYoruba: '''ARONI KUIN ARONI KUIN
ARIKO MO AREO ARONI KUIN''',
    suyereEspanol: '',
    nace: '',
    descripcion: '',
    ewes: '',
    eshu: '',
    rezosYSuyeres: '',
    obrasYEbbo: '',
    diceIfa: '',
    refranes: '',
    historiasYPatakies: '',
  ),
  'ODI MEJI': OduContent(
    name: 'ODI MEJI',
    rezoYoruba:
        'ASHAMARUMA DIMA IKU KODIMA ANO KODIMA SHENKUERIMA OBATIKO TUBALE ADIFAFUN EYA TUTO KODIMO LORUBO',
    suyereYoruba: '''ADIMU DIMO DIRE MAMA
YIKI MAMA KIKI
YIKI MAMA KIKI''',
    suyereEspanol: '',
    nace: '',
    descripcion: '',
    ewes: '',
    eshu: '',
    rezosYSuyeres: '',
    obrasYEbbo: '',
    diceIfa: '',
    refranes: '',
    historiasYPatakies: '',
  ),
  'IROSO MEJI': OduContent(
    name: 'IROSO MEJI',
    rezoYoruba:
        'APARITANI AWANTA LA OSHA ABEBE KORINA KOSI MADA ADIFAFUN OLOKUN',
    suyereYoruba: '''OLOFIN LOREYEO MODUPUE LORUN
OLOFIN LOREYEO MODUPUE LORUN''',
    suyereEspanol: '',
    nace: '',
    descripcion: '',
    ewes: '',
    eshu: '',
    rezosYSuyeres: '',
    obrasYEbbo: '',
    diceIfa: '',
    refranes: '',
    historiasYPatakies: '',
  ),
  'OJUANI MEJI': OduContent(
    name: 'OJUANI MEJI',
    rezoYoruba: 'ADIFAFUN AGANGARA ADELEPEKO KO OMO OLORDUMARE',
    suyereYoruba: '''AGANGARA OMO OLORDUMARE
AGANGARA OMO OLORDUMARE
ARIKU LOWAO OMO OLORDUMARE''',
    suyereEspanol: '',
    nace: '',
    descripcion: '',
    ewes: '',
    eshu: '',
    rezosYSuyeres: '',
    obrasYEbbo: '',
    diceIfa: '',
    refranes: '',
    historiasYPatakies: '',
  ),
  'OBARA MEJI': OduContent(
    name: 'OBARA MEJI',
    rezoYoruba: 'EYEBARA ONIBARA KIKATE AWO ADIFAFUN OROPO',
    suyereYoruba: '''OBORODO KIKATE
AFEYU EYE KIKATE
OBORODO KIKATE
AFEYU EYE KIKATE''',
    suyereEspanol: '',
    nace: '',
    descripcion: '',
    ewes: '',
    eshu: '',
    rezosYSuyeres: '',
    obrasYEbbo: '',
    diceIfa: '',
    refranes: '',
    historiasYPatakies: '',
  ),
  'OKANA MEJI': OduContent(
    name: 'OKANA MEJI',
    rezoYoruba: 'SUKUTU MALA WALA OLEWALA KATIBO IRE OMO ARIKUBABAWA',
    suyereYoruba: '''ESHU BI AGADA SHUREO
ESHU BI AGADA SHUREO
ESHU BI AGADA SHUREO''',
    suyereEspanol: '',
    nace: '',
    descripcion: '',
    ewes: '',
    eshu: '',
    rezosYSuyeres: '',
    obrasYEbbo: '',
    diceIfa: '',
    refranes: '',
    historiasYPatakies: '',
  ),
  'OGUNDA MEJI': OduContent(
    name: 'OGUNDA MEJI',
    rezoYoruba:
        'TETE YISIRO OBINI ADIFAFUN ALAGUEDE A LA IBORU, EBOYA IBOSHESHE.',
    suyereYoruba: '''ERU SI BABA KERERE
BABA KERERE MAKULENGO AWO''',
    suyereEspanol: '',
    nace: '',
    descripcion: '',
    ewes: '',
    eshu: '',
    rezosYSuyeres: '',
    obrasYEbbo: '',
    diceIfa: '',
    refranes: '',
    historiasYPatakies: '',
  ),
  'OSA MEJI': OduContent(
    name: 'OSA MEJI',
    rezoYoruba:
        'ORUNMILA ADIFAYOKO LODAFUN OKE BABA BURU BURU BABA FOSHE BABA ADIFAFUN SARAYEYE',
    suyereYoruba: 'SARAYEYE BAKUNO (El objeto) AREMU',
    suyereEspanol: '',
    nace: '',
    descripcion: '',
    ewes: '',
    eshu: '',
    rezosYSuyeres: '',
    obrasYEbbo: '',
    diceIfa: '',
    refranes: '',
    historiasYPatakies: '',
  ),
  'IKA MEJI': OduContent(
    name: 'IKA MEJI',
    rezoYoruba: 'IKA NIKA OBEDE MEJI IWA YOKOKO IFA NI ADIFAFUN ELEBUTE.',
    suyereYoruba: '''MAYOKODA MAYOKODA GUANARI MAMA YOKODA GUANRI
MAYOKODA MAYOKODA GUANARI MAMA YOKODA GUANRI
MAYOKODA MAYOKODA GUANARI MAMA YOKODA GUANRI
BEBEOTUN MAYOKODA GUANARI MAMA YOKODA GUANRI
OTONARANA MAYOKODA GUANARI MAMA YOKODA GUANRI
ADIFAFUN ELEBUTE.''',
    suyereEspanol: '',
    nace: '',
    descripcion: '',
    ewes: '',
    eshu: '',
    rezosYSuyeres: '',
    obrasYEbbo: '',
    diceIfa: '',
    refranes: '',
    historiasYPatakies: '',
  ),
  'OTRUPON MEJI': OduContent(
    name: 'OTRUPON MEJI',
    rezoYoruba:
        'JEKUJEY OTORO TOROSHE KERENI PAPO OLUO PAMI OYUBONA PAMI ADIFAFUN OÑI',
    suyereYoruba: '''ONINI LASHORO ONIO, ONINI LASHORO ONIO
ONT FERUN LASHORO EKUN, ONINI LASHORO ONIO''',
    suyereEspanol: '',
    nace: '',
    descripcion: '',
    ewes: '',
    eshu: '',
    rezosYSuyeres: '',
    obrasYEbbo: '',
    diceIfa: '',
    refranes: '',
    historiasYPatakies: '',
  ),
  'OTURA MEJI': OduContent(
    name: 'OTURA MEJI',
    rezoYoruba: 'AWO NI IPAKO KEKE NI IPAKO ADIFAFUN IMALE',
    suyereYoruba: '''ANANANDE IFA WA IFA TIWA IMALE
ANANANDE IFA WA IFA TIWA IMALE
OSHE NI NIE.''',
    suyereEspanol: '',
    nace: '',
    descripcion: '',
    ewes: '',
    eshu: '',
    rezosYSuyeres: '',
    obrasYEbbo: '',
    diceIfa: '',
    refranes: '',
    historiasYPatakies: '',
  ),
  'IRETE MEJI': OduContent(
    name: 'IRETE MEJI',
    rezoYoruba: 'EYEMBERE ELOKOMBERE EYEMBERE LATIBORO ADIFAFUN PAROYE',
    suyereYoruba: '''ARIKU MANIWA, ARIKU MANIWA
ONINI BAKU ODIDEO
ARIKU MANIWA AWO, OSHE MINIE''',
    suyereEspanol: '',
    nace: '',
    descripcion: '',
    ewes: '',
    eshu: '',
    rezosYSuyeres: '',
    obrasYEbbo: '',
    diceIfa: '',
    refranes: '',
    historiasYPatakies: '',
  ),
  'OSHE MEJI': OduContent(
    name: 'OSHE MEJI',
    rezoYoruba: 'OSHE MULUKU KUNU LUSHE ADIFAFUN AKATAMPO',
    suyereYoruba: '''SHEN SHEN OLONGO MAYA ORUNLA
SHEN SHEN OLONGO MAYA VALODE''',
    suyereEspanol: '',
    nace: '',
    descripcion: '',
    ewes: '',
    eshu: '',
    rezosYSuyeres: '',
    obrasYEbbo: '',
    diceIfa: '',
    refranes: '',
    historiasYPatakies: '',
  ),
  'OFUN MEJI': OduContent(
    name: 'OFUN MEJI',
    rezoYoruba:
        'ORAGUN JEKUA BABA IFA OFUN MAFUN TALE OKAN JUJU LEDIE ADIFAFUN OLOFIN',
    suyereYoruba: '''BABA FURURU ERE REO, OKANENE LERIBO ELERIBA OBASIBA
LAGUO EYIBORERE BASIBAO ERU AYE, YAGUAO EYAGUALORO LESE KAN''',
    suyereEspanol: '',
    nace: '',
    descripcion: '',
    ewes: '',
    eshu: '',
    rezosYSuyeres: '',
    obrasYEbbo: '',
    diceIfa: '',
    refranes: '',
    historiasYPatakies: '',
  ),
  'OGBE OYEKU': OduContent(
    name: 'OGBE OYEKUN',
    rezoYoruba: '''OGBE YEKU NI BABA OMOLU AGBA OLORUN NIRE DEMU, AGOGO NILA SHENU
GBOGBO LONI NI
PARIKOKO OTENU DUNDUN NA LORİ NI PARAKIDI OTENU BATA JAD OGBE YEKU
ADIFAFUN OSANYIN, LODAFUN ORUNMILA.''',
    suyereYoruba: '''EDAFON SHURO MI ORE, EDA EWE EDA EFUN AGAYU RAUN OSOMOBO MOBO
SODOROMI YARE IYA LODE ABA.''',
    suyereEspanol: '''"EL QUE ESCAPÓ DE LA MUERTE, EL QUE VIVIÓ TANTO TIEMPO EN LA TIERRA QUE
SE COMIÓ SUS EXCRETAS, EL QUE LLEGÓ AL MUNDO Y DIO A CONOCER LOS
METALES PRECIOSOS. SE LANZÓ IFÁ PARA EL ANIMAL QUE NO MUERE DE MUERTE
SÚBITA."''',
    nace: '''1. LOS ADANES DE OSHUN.
2. ORUNGAN.
3. LOS TRES ITA DE IFA.
4. QUE LOS HUMANOS SE LIMPIARAN LOS DIENTES Y SE LAVARAN LA BOCA DESPUÉS DE LOS ALIMENTOS PARA LA HIGIENE Y BUEN ESTADO DE LA DENTADURA.
5. LA VIRTUD DE LA ORINA. ASÍ COMO EL ORGANISMO ELIMINA LAS IMPUREZAS POR LA ORINA USTED TIENE QUE DESPOJARSE DE TODO LO MALO QUE LA RODEA.''',
    descripcion: '''OGBE YEKU ES EL PADRE DE LAS COMBINACIONES. (OGBE YEKU NI
BABA AMULÚ).
SE HIZO ADIVINACIÓN PARA EL LEÓN QUE GRACIAS A SU ORINA SE
IBA A CONVERTIR EN EL REY DE LOS ANIMALES.
NACIO LA VIRTUD DE LA ORINA, ASI COMO EL ORGANISMO ELIMINA
LAS IMPUREZAS A TRAVES DE LA ORINA, USTED TIENE QUE
DESPOJARSE DE TODO LO MALO.
MAFEREFUN OSHUN; HAY QUE TOCARSE TODOS LOS DIAS DELANTE
DE OSHUN LA FRENTE CON SUS ADANES.
OGBE YEKU FUE EL QUE ESCAPÓ DE IKU.
OGBE YEKU VIVIÓ TANTO TIEMPO EN LA TIERRA QUE SE COMIÓ EL
FRUTO DEL ARBOL QUE NACIO DE LAS SEMILLAS QUE EXCRETÓ.
EL DUEÑO DE ESTE IFA MUERE DE VIEJO.
OGBE YEKU LLEGÓ AL MUNDO Y DIO A CONOCER LOS METALES
PRECIOSOS.
AQUI SE LANZÓ IFÁ PARA EL ANIMAL QUE NO MUERE DE MUERTE
SÚBITA.
OGBE YEKU ES EL QUE TIENE MAYOR EDAD ENTRE LOS OMOLUOS.
MARCA DESQUITES, OGBE YEKU LLEGARA A SER IMPORTANTE POR
LAS BUENAS O POR LAS MALAS.
MARCA DESPOJO DE CARGOS, POR LO QUE HAY QUE TENER MUCHO
CUIDADO EN EL TRABAJO O EN EL NEGOCIO.
MARCA PERSONA QUE ESTA EN UN RINCON OLVIDADA Y OBTENDRA
UN CARGO IMPORTANTE.
ESTE ODDUN NO SE ESCRIBE EN EL TABLERO, SE SUSTITUYE POR
OKANA YEKUN, YA QUE ESTE ODDUN DESCONTROLA A TODOS LOS
SIGNOS COMPUESTOS AL SER EL PADRE DE LAS COMBINACIONES.
HABLA DE PERSONA VICIOSA.
DEBE CONTROLAR EL DESENFRENO SEXUAL; EN ESTE SIGNO EL
OWUNKO SE ACOSTÓ CON LA MADRE.
EN ESTE IFA HABLA EL OWUNKO, ANIMAL QUE VIVE A LA INTEMPERIE,
NO SE BANA, POR LO CUAL APESTA, COME YERBAS, VEGETALES,
VERDURAS Y TIENE DIGESTIONES LENTAS; ASI MISMO LA PERSONA
NO TIENE CASA, TIENE EL SUDOR MUY FUERTE, DIGESTIONES
LENTAS, NO PUEDE TOMAR MUCHA AGUA EN LAS COMIDAS, COME
MUCHAS ENSALADAS, ATACA CON LA CABEZA, DUERME POCO, ES
NERVIOSA, SIEMPRE ESTA PROTESTANDO.
LO CONSIDERAN EN LA FAMILIA COMO MALA CABEZA.
HABLA DE UN ORISHA U OSHA AL QUE ADORABAN Y POR UNA CAUSA
O POR OTRA LO HAN DEJADO DE HACER Y TIENEN QUE VOLVER A
ADORARLO Y HACERLE LO QUE ERA COSTUMBRE, PARA QUE DEJE
DE DAR ONA Y PUEDAN SALIR ADELANTE.
AQUI LOS HUMANOS APRENDIERON A LIMPIARSE LOS DIENTES Y SE
LO LAVABAN A LA BOCA DESPUES DE COMER, PARA CONSERVAR LA
HIGIENE DE LA MISMA Y EL BUEN ESTADO DE LA DENTADURA.
MARCA PROBLEMAS DE CIRCULACION SANGUINEA Y PROBLEMAS
ESTOMACALES POR FALTA DE HIGIENE BUCAL.
SE PADECE DE DOLORES DE MUELAS, POR PROBLEMAS POSIBLES
DE CARIES Y OTRAS INDOLES.
EL IYEFA DE ESTE ODDUN NO SE UNTA EN LA FRENTE.
HAY SITUACIONES DE ENGANO ENTRE LA FAMILIA O ENTRE USTED Y
LA FAMILIA DE SU CONYUGE.
PUEDE SER QUE A USTED LE HAYAN TRABAJADO PARA QUE SE
CASARA CON SU CONYUGE, PUES A USTED ESA PERSONA NO LE
INTERESABA.
LA MADRE NO DESEA QUE SUS HIJOS SE CASEN, DESEA TENERLOS
SIEMPRE BAJO SU ABRIGO PORQUE QUE NADIE LES VA A CUIDAR
COMO ELLA; TAMBIEN PUEDE SER EGOISMO DE DINERO.
AQUI LAS MADRES NO SE DAN CUENTA QUE LOS HIOS NECESITAN YA
TENER RELACIONES SEXUALES.
LA PERSONA DE ESTE ODU DEBE ATENDER SUS PROBLEMAS
NERVIOSOS Y DE INSOMNIO, PARA ELLO SE TOMAN HOJAS SECAS DE
ZAPOTE EN COCIMIENTO Y ADEMAS PARA RECUPERAR LAS
FUERZAS PERDIDAS DURANTE SU LARGO DIA DE TRABAJO.
ENGAÑOS EN EL SENO FAMILIAR, ES POSIBLE QUE A LA PERSONA NO
LA HAYA CRIADO SU PADRE.
NO, LE LEVANTE LA MANO A NADIE PORQUE PUEDE MATARLO.
PARA QUE TODO LE SALGA BIEN, ATIENDA A LOS SANTOS Y A SUS
FAMILIARES DIFUNTOS.
CUIDADO CON LAS TRAMPAS EN PAPELES, DOCUMENTOS, ETC.
DOMINE SU GENIO PARA QUE NO PIERDA.
NO DISCUTA CON NADIE.
PROCURE QUE EN SU CASA REINE LA TRANQUILIDAD.
AQUI LAS MUJERES MADURAS VIVEN CON JOVENCITOS.
A ELEGBA SE LE PONE EKU Y EWO (ISHU DESBARATADO) PARA
RESOLVER SITUACIONES.
A OSHUN SE LE PONEN CINCO ZAPOTES PARA RESOLVER, ESTOS
ZAPOTES SE LE ENGANCHAN EN LOS EDANES.
USTED NO TIENE ASIENTO Y SU ANGEL DESEA QUE USTED LO
TENGA.
SE VIVE ENTRE PERSONAS QUE NO LO CONSIDERAN, NI LO
RESPETAN NI LO QUIEREN BIEN, POR LO QUE NO DEBE FIARSE DE
NADIE.
LE ESTAN HACIENDO DANO PARA DESTRUIRLE LO SUYO.
TENGA PACIENCIA Y HAGA EBBO PARA QUE GANE LA GUERRA A
TODOS SUS ENEMIGOS.
PUEDE ESTAR EMBARAZADA Y LA GENTE LE DICE QUE ES UN DANO.
SU CUERPO ESTA POR UN LADO Y SU CABEZA POR OTRO, HAGA
EBBO PARA QUE SU CABEZA TOME ASIENTO, PARA QUE NO PIERDA
LA SUERTE QUE ESTA BUSCANDO.
NO PUEDE USAR ROPA DE LISTAS Y MENOS AUN PARA SALIR A LA
CALLE A BEBER PORQUE SE
PUEDE MORIR.
USTED ESTA BUSCANDO UN CONYUGE BUENO Y NO LO ENCUENTRA.
MARCA VISITAS DE ALEYOS Y DE IKU.
ESTE ES UN IFA DE TRANSFORMACION.
NO DEJE A SUS HUOS JUGAR CON HIERROS, YA QUE SE PUEDEN HERIR O
DARSE UN MAL GOLPE.
TIENE QUE CUIDARSE EL ESTOMAGO PORQUE LE PUEDEN ECHAR BRUJERIA.
MANTENGA LA HIGIENE DE LOS DIENTES PARA QUE NO SE ENFERME DEL
ESTOMAGO.
AQUI TODOS LOS PALOS Y LOS VIENTOS HICIERON EBBO.
AQUI HABLA UN HOMBRE BRAVUCON.
ESTE ODDUN DEBE ATENDER MUCHO A OGGUN, ELEGBA Y OSHUN.
EL AWO POR ESTE IFA SE TIENE QUE PONER LOS EDANES DE OSHUN EN SU
LERI.
AQUI EL CAMELLO (EBIN) NO QUISO HACER EBBO Y OSHOSI LO MATO.
OGBE YEKU ES EL ADIVINO DEL CETRO, FUE QUIEN ADIVINÓ IFÁ PARA EL
CETRO, ANTES QUE EL CETRO MURIERA Y LOS ANCIANOS DE IWORO ESTABAN
CERCA DE LA MUERTE.
EL PAQUETE DEL EBBO NO LLEVA HOJA DE MALANGA SINO HOJA DE ZAPOTES.
AQUI CORONARON REY AL VIEJO VENDEDOR DE LA PLAZA.
EN ESTE ODU OSHUN ENCONTRO A ODUDUWA EN EL RIO.
CUIDARSE DE EXPRESAR UN JUICIO U OPINIÓN SOBRE UNA DISCUSIÓN O
SOBRE ALGO QUE LE
PREGUNTEN PARA QUE NO SE PERJUDIQUE.
CUIDADO CON EL PADRE QUE SI ESTA VIVO PUEDE MORIR EN TÉRMINO DE UN
AÑO.
CUIDADO CON LA JUSTICIA Y CON TRAMPA EN CUESTIONES DE PAPELES.
SE PADECE DEL ESTÓMAGO POSIBLE CAUSA FALTA DE HIGIENE BUCAL.
LA MADRE NO DESEA QUE EL HIJO SE CASE, PUES PIENSE QUE COMO ELLA
NADIE LO ATENDERÁ SIN DARSE CUENTA QUE EL HIO NECESITA DE
RELACIONES SEXUALES.
LA PERSONA SIEMPRE ESTA PROTESTANDO.
MARCA DEUDAS CON OSHÚN QUE ESTA BRAVA CON USTED.
SE VIVE RODEADO DE ENEMIGOS Y ENVIDIOSOS.
ORISHAS EN OGBE-YEKUN IFA: ODU, EGBE, ESHU, OBATALÁ (ORISHA-NLA),
SHANGÓ, ORÍ, OGGÚN.''',
    ewes: '''EL ZAPOTE''',
    eshu: '''ESHU EMERE.
ESTE ES EL ESHU QUE VIVE FORRADO DE CUENTAS Y CARACOLES YA OGBE YEKU
BAJO A LA TIERRA ACOMPAÑADO DE OSHUMARE.
CARGA:
ILEKAN, TIERRA DE CEMENTERIO, DE NIGBE, 7 ABERE, AFOSHE DE LERI DE AKUKO
Y DE AYAPA, OBI MOTIWAO, IKINES META. SE FORRA EN CUENTAS Y CARACOLES.''',
    rezosYSuyeres: '''REZO:
OGBE YEKU NI BABA OMILU AGBA OLOYA NIRO DEMU, AGOGO NLA SHENU GAGBA
LONI NI PARIKOKO OTENU DUNDUN NI PARASIDI OTENU BATA JAD YEKUN
ADIFAFUN OZAIN LODAFUN ORUNMILA
KAFEREFUN OJUANI MEYI.
REZO:
AKUENO OLORI ASHUBO AWO KAKA ADO ADIFAFUN ORI KAFEREFUN ORUNMILA.
REZO:
OGBE YEKU KUKUTU ADIFAFUN GUONITI AFITI BIYE LOGBU ORUNGAN.
REZO:
OGBE YEKU BABA OMOLU ABAKAKA BARA ADAN ADIFAFUN KENE UN TIO PIO BIYE
LOKE ERANKO
ALUBODE LANSHI LORUBO.
REZO:
OGBE YEKU BABA OMOLU BABA ADIFAFUN SHORO KOKO EPASIDA IKIBO OKARA
KOKO ROKO OKO
KOBERU OGBE.
REZO:
OGBE YEKU OMOLU OBA KAKA EDAN ADIFAFUN YEBEKA OKA APEINDA IKIBO
OSHOSI KAKARAKA OKO
KOBORUN OGBE LOLA OGBE TEKE OUN KOYE KOBIN ADIFAFUN KENKUN TIO PIO
EYELE LOWO ERANKO
OLUBEBE GOGBO ERANKO ETU LORUBO.
REZO:
OGBE YEKU BABA OMOLU BABA ADIFAFUN SHERE KEKE EPISANDA IKIBO SHERU
KEKE OKO KOBORU
OGBE YEKU LO TOKE OUN KOSHE KOTIN ADIFAFUN OWUNKO ITA FIRE IYE REWE
OLUBAMBA TOLI
LEBO ETU KORUBO MEDILOGUN ERAN MALU, OÑI MEDILOGUN OWO ELEBO.''',
    obrasYEbbo: '''OBRA PARA ELIMINAR BRUJERIA TOMADA:
PARA SACAR LAS BRUJERIAS DEL ESTOMAGO, DURANTE SIETE DIAS SE TOMA
COCIMIENTO DE PEREJIL CON FLORES DE ROMERILLO Y SACU-SACU LIGADO
CON LECHE CRUDA Y OTI. SI SE DIFICULTA CONSEGUIR LA RAIZ DE PEREJIL Y EL
SACU-SACU, SE UTILIZAN LAS HOJAS QUE SE MACHACAN BIEN PARA SACARLE EL
ZUMO.
OBRA PARA LA SALUD:
SE HACE EBBO CON OWUNKO Y ASHO FUN-FUN. DESPUES SE LE DA A ELEGBA.
OBRA PARA CUANDO OSHUN ESTA BRAVA PORQUE HAY DEUDA CON OSHUN:
SE HACE EBBO CON UN OWUNKO, AKUKO, ERAN MALU, UNA IKOKO, INSO DE
TIGRE, ADIE MEYI, OTA META, UNA TUZA DE MAIZ, OÑI, EKU, EYA, EPO, OMI, AÑARI,
OPOLOPO OWO. EL OWUNKO A OSHUN, SE ADORNA CON CINTAS DE COLORES Y
SE CASTRA FUERA DEL CUARTO, LA TUZA DE MAIZ SE CORTA EN TRES PARTES, SE
TRAZA CON EFUN UNA RAYA ATRAVEZADA EN EL PISO. LA TUZA CORTADA DENTRO
DE LA OTA Y EL ONI. DELANTE DE LA IKOKO SE PONE ESHU, SE LE DA UNA OSIADIE
Y TAMBIEN EYERBALE A LA IKOKO. A OSHUN EL OWUNKO Y ADIE MEYI APERI. LA
IKOKO SE LE ECHA IYEFA Y SE LLEVA A LA ESQUINA MAS PROXIMA DE LA CASA.
EBBO PARA ESTAR BIEN EN LA VEJEZ (PARA OKUNI):
AKUKO, EYELE MEYI, CEPILLO DE DIENTES, 16 COCHINOS, RAIZ DE CHINA,
OWUNKO, UN LAZO, EKU, EYA Y EL SECRETO DE LOS ADANES.
EBBO PARA ESTAR BIEN EN LA VEJEZ (PARA OBINI):
OWUNKO, ADIE MEYI, EYELE MEYI, UN LAZO, ONI Y DEMAS INGREDIENTES,
OPOLOPO OWO.
SECRETO DEL ZAPOTE PARA RESOLVER SITUACIONES:
SE LE DAN EYELE MEYI PINTADA A OZAIN, 9 EYA TUTU KEKE, LAS LERI, ELESE Y
OKOKANES DE LAS EYELE, LOS 9 EYA TUTU KEKE, HOJAS Y SEMILLAS DE ZAPOTE,
IYEFA REZADO Y UN PITIRRE SECO EN IYE, OBI MOTIWAO, IKINES META. SE
FORRAN EN CUENTAS Y CARACOLES. OBRA PARA RESOLVER CON OSHUN:
SE LE PONEN A OSHUN CINCO ZAPOTES ENGANCHADOS EN LOS EDANES.
EBBO:
AKUKO, ADIE MEYI, ETU MEYI, ERAN MALU, ONI, AWADO, UN DELANTAL CON DOS
BOLSILLOS, TEWEWE, VARETA DE OBI MEDILOGUN, IGBA, EKU, EYA, EPO,
OPOLOPO OWO.
EBBO:
LERI DE MALU, LERI DE ELEDE, AKUKO, GBOGBO AWADO, GBOGBO EPO, UNA
CACHIMBA (PARA QUE FUME POR LA NOCHE Y ECHE BASTANTE HUMO, PARA QUE
ASI VENZA A LA MUERTE Y A SUS ENEMIGOS). DESPUES DE DARLE EL AKUKO A
ELEGBA SE LLEVA LA LERI DE ELEDE AL RIO Y LA DE MALU A UNA LOMA. SI ES PARA
OBINI LLEVA ADIE MEYI, EYELE MEYI, OÑI, 16 PEDAZOS DE ERAN MALU Y A CADA
UNO SE LE ENCAJA UNA VARETA DE MARIWO Y SE ECHAN EN LA IGBA, SE LE ECHA
OÑI Y SE LE PONE DELANTE A OSHUN.
EBBO:
AKUKO, EYELE MEYI, UNA CAMPANA, UN TAMBORCITO DUN DUN, UN
TAMBORCITO BATA, GBOGBO TENUYEN, UNA BOTELLA DE OTI, UNA DE ONI, EKU,
EYA, AWADO, OPOLOPO OWO.
EBBO:
AKUKO, IGBA OKAN, OMI TUTU, CENIZAS, TRES GARABATOS, EWE IFA LAUREL,
EKU, EYA, AWADO, OPOLOPO OWO.
EBBO:
AKUKO DUN-DUN, ABEBOARDIE MEYI, JIO-JIO META, OSIADIE OKAN, UN
COFRECITO, OBI, ASHO QUE TIENE GUARDADA, EKO, UNA CORONA, UNA
CALABACITA, ENIGAN, MALAGUIDI, ITANA, EKU, EYA, AWADO, OPOLOPO OWO. EL
AKUKO DUN-DUN Y ABEBOARDIE MEYI PARA OSHUN. OSIADIE OKAN CON SUS
INGREDIENTES PARA ELEGBA. JIO-JIO META CON SUS INGREDIENTES PARA ESHU.
EBBO:
AKUKO, ETU, AWADO, TAGUE DE UN DELANTAL DE DOS BOLSILLOS, CARETA,
IGBA, DEMAS INGREDIENTES, OPOLOPO OWO.''',
    diceIfa: '''TIENE UN AMIGO QUE REALMENTE ES UN ENEMIGO Y QUE LO
QUIERE VER SUCUMBIR.
DELE GRACIAS A SU ANGEL DE LA GUARDA.
LA GENTE DICE QUE TIENE UN DANO EN EL VIENTRE PERO
REALMENTE LO QUE PASA ES QUE ESTA EMBARAZADA, ESO ES
COSA DE OSHUN.
SI TIENE TRAGEDIA CON ALGUIEN NO TENGA MIEDO QUE NO LE VA A
PASAR NADA.
NO SALGA A LA CALLE DURANTE SIETE DIAS POR LA NOCHE.
USTED NO HACE CASO A LO QUE SE LE DICE.
USTED TIENE UN ENEMIGO OCULTO QUE SI SE DESCUIDA LO
METERA EN LIOS DE JUSTICIA.
TENGA CUIDADO CON BRUJERIA QUE LE QUIEREN PONER PARA
MATARLO.
NO, LE FALTE EL RESPETO NI LE LEVANTE LA MANO A NADIE
PORQUE ES POSIBLE QUE LO MATE SU CONTRARIO.
EN SU CASA HAY UN ENFERMO QUE SE PUEDE MORIR.
USTED TENDRA QUE ASENTAR A OSHUN Y GRACIAS A ESTO TENDRA
CASA PROPIA.
TOQUESE TODOS LOS DIAS LA FRENTE CON LOS EDANES DE OSHUN
QUE ASI VERA LO QUE DESEA.
USTED ESTA ESCASO DE ROPAS, TIENE QUE HACER ROGACION CON
TELAS PARA TENER ROPA.
AQUI TODOS LOS PALOS Y LOS VIENTOS HICIERON EBBO.
USTED HA DE SER DICHOSA EN SU VEJEZ PORQUE SALDRA BIEN DE
TODAS SUS DIFICULTADES Y HA DE TENER MUCHOS ANOS DE VIDA.
TENGA CUIDADO CON UN CHISME QUE LE HA DE TRAER UN AMIGO.
EN SU CASA NO LO SOPORTAN.
CUIDESE LA DENTADURA, PUEDE PADECER DE LAS MUELAS.
EN LAS FIESTAS QUE LE INVITEN CUIDADO CON LO QUE COME Y
BEBE PORQUE HAY BRUJERIAS, SI ES POSIBLE LLEGUE TARDE.
VA A RECIBIR BUENAS NOTICIAS.
DELE GRACIAS A LOS JIMAGUAS.
NO DISCUTA TANTO.
CUIDADO CON LOCURAS.
HABLA DE PERSONA VICIOSA.
PELEAS ENTRE FAMILIAS.
CUANDO USTED DE A LUZ SE VAN A QUEDAR ASOMBRADOS.
AQUI SE MUERE DE VIEJO PERO CUIDADO CON LA JUSTICIA.
SI QUIERE QUE LAS COSAS LE SALGAN BIEN ATIENDA A LOS SANTOS
PRINCIPALMENTE A ELEGBA, OGGUN Y OSHUN.
LLEVESE CARINOSAMENTE CON SU CONYUGE Y SUS MAYORES.
DICE IFA QUE USTED TIENE UN ENEMIGO QUE LO QUIERE VER EN LA
MAS GRANDE DE LAS MISERIAS Y VEJADO.
DELE GRACIAS AL ANGEL DE LA GUARDA QUE NO HA PERMITIDO LOS
ABUSOS QUE QUIEREN COMETER CONTRA USTED.
NO TENGA MIEDO CON ESTO, PERO SI TIENE MUCHACHOS
TENGALOS RECOGIDOS Y BAJO SU CUIDADO PARA QUE NO LE
HAGAN DAÑO A SUS ESPALDAS.
NO COJA NADA QUE LE DEN DE REGALO QUE SEGURO SE LO DAN
CON MALA INTENCIÓN.
USTED ES PERSONA DE SEGUIR TODOS LOS CONSEJOS QUE LE DAN
PERO TIENE QUE MIRAR MUCHO QUIEN SE LOS DA.
NO COMA EN CASA DE NADIE Y MUCHO MENOS BEBIDAS OSCURAS,
ESPECIALMENTE CAFE.
USTED TIENE UNA AMIGA CHISMOSA, NO LE HAGA CASO DE LAS
COSAS QUE LE CUENTE, PORQUE ES MUY MENTIROSA, LO HACE
PARA GANARSE SU CONFIANZA Y SU BONDAD QUE ES MUCHA.
EL IFA DE ESTE SIGNO NUNCA SE UNTA EN LA FRENTE.
PROBABLEMENTE TENDRA QUE ASENTAR A OSHUN.
CUIDADO QUE AQUI SE PIERDEN TITULOS Y POSESIONES Y HASTA
UN DON.
NADIE SE CONVIERTE EN UNA PERSONALIDAD DE LA NOCHE A LA
MANANA.
ES UN SIGNO DE RAPIDOS CAMBIOS DE POSICIONES.
HACER EBO CON UNA GALLINA CON SUS POLLITOS.
PARA LA SALUD SE HACE EBO CON UN CHIVO NEGRO Y ASHO
FUNFUN, QUE SE LE DA A ELEGBA.
RECIBIRA UNA MUY BUENA NOTICIA.
USTED TIENE UNA AMIGA CHISMOSA, NO LE HAGA CASO DE LAS
COSAS QUE LE CUENTE,''',
    refranes: '''1. EL LIDER DE LA LARGA VIDA ES EL SACERDOTE DE EDAN. NO HAY
SERPIENTE QUE TENGA DOS COLAS. CUANDO EL FUEGO SE SOPLA,
SE EXTIENDE ALREDEDOR. LA MOSCA NO NECESITA CONOCERLO A
UNO ANTES DE TOCARLO CON SUS PATAS. DESCIENDE SOBRE LA
MUERTE.
2. EL ARCO IRIS SOLO OCUPA EL TRAMO QUE DIOS LE MANDE.
3. EL QUE DESEA QUE NO LO ENGANEN, QUE NO ENGANE.
4. PARA HACER EL MAL, NO HAY HOMBRE PEQUENO.
5. CUANDO LA BOCA NO HABLA, LAS PALABRAS NO OFENDEN.
6. LA CABEZA QUE NO TENGA QUE IR DESNUDA, ENCONTRARÁ UN
SOMBRERO CUANDO ABRA EL MERCADO.''',
    historiasYPatakies: '',
  ),
};

const _babaEjiogbePatakies = <String>[
  "1. LA CABEZA COMO UNA DIVINIDAD.",
  "2. EJIOGBE PARTE HACIA LA TIERRA.",
  "3. EL NACIMIENTO DE BABA EJIOGBE. LOS TRABAJOS TERRENALES DE EJIOGBE.",
  "4. LAS OBRAS DE EJIOGBE EN LA TIERRA.",
  "5. EL MILAGRO DEL MERCADO.",
  "6. LOS MILAGROS DEL LISIADO Y EL CIEGO.",
  "7. EL RESULTADO DE IGNORAR EL CONSEJO DE EJIOGBE.",
  "8. COMO EJIOGBE SOBREVIVIÓ LA IRA DE LOS MAYORES.",
  "9. EJIOGBE REGRESA AL CIELO PARA SER JUZGADO.",
  "10. EL MATRIMONIO DE EJIOGBE.",
  "11. EL SEGUNDO MATRIMONIO DE EJIOGBE.",
  "12. COMO EJIOGBE AYUDO A UN LITIGANTE A QUE GANARA EL CASO.",
  "13. COMO EJIOGBE HIZO QUE UNA MUJER INFECUNDA TUVIERA UN HIJO.",
  "14. COMO EJIOGBE AYUDÓ A LA MONTAÑA A RESISTIR EL ATAQUE DE SUS ENEMIGOS.",
  "15. EJIOGBE SALVA A SU HIJO DE LAS MANOS DE LA MUERTE.",
  "16. COMO LA MADRE DE EJIOGBE LO SALVÓ DE SUS ENEMIGOS.",
  "17. COMO EJIOGBE SE CONVIRTIÓ EN EL REY DE LOS OLODUS (APÓSTOLES).",
  "18. LUCHA ENTRE EJIOGBE Y OLOFEN.",
  "19. EJIOGBE LUCHA CON LA MUERTE.",
  "20. RASGOS NOTABLES DE EJIOGBE.",
  "21. LA TIERRA DE LAS DESAVENENCIAS.",
  "22. EL ACERTIJO DE LOS AWOS.",
  "23. POEMA DE EJIOGBE PARA EL PROGRESO Y LA PROSPERIDAD.",
  "24. AKPETEBI MOLESTA A EJIOGBE.",
  "25. ORÚNMILA ADIVINÓ PARA LO MÁS IMPORTANTE.",
  "26. ORÚNMILA ADIVINÓ PARA LA ORGANIZACIÓN.",
  "27. SE ADIVINÓ IFÁ PARA OLOMOAGBITI.",
  "28. ADIVINARON PARA ORÚNMILA PARA LA MEDICINA CONTRA LOS ABIKÚ.",
  "29. SE ADIVINÓ PARA EL BUITRE.",
  "30. SE ADIVINÓ PARA UNO AMPLIAMENTE CONOCIDO.",
  "31. SE ADIVINÓ PARA ORE LA ESPOSA DE AGBONNIREGUN.",
  "32. ORÚNMILA ADIVINÓ PARA QUE TUVIERAN UN RESPIRO Y HONOR.",
  "33. SE ADIVINÓ PARA ORÚNMILA CUANDO IBA HACER AMISTAD CON ESHU-ELEGBA.",
  "34. SE ADIVINÓ PARA ORÚNMILA CUANDO ENAMORABA A LA TIERRA.",
  "35. SE ADIVINÓ A ORÚNMILA CUANDO SE IBA A CASAR CON NWON LA HIJA DE LA DIOSA DEL MAR OLOKUN.",
  "36. SE ADIVINÓ PARA ÉL ESCAPARSE DE LAS BRUJAS.",
  "37. SE ADIVINÓ PARA LA MADRE DE AGBONNIREGUN.",
  "38. SE ADIVINÓ IFÁ PARA ELEREMOJÚ LA MADRE DE AGBONNIREGUN.",
  "39. SE ADIVINÓ PARA OGBONNIREGUN.",
  "40. SE ADIVINÓ IFÁ PARA EL CAMPESINO Y EL PLÁTANO.",
  "41. SE ADIVINÓ PARA CONSEGUIR ALGO BUENO EN LA VIDA.",
  "42. SE ADIVINÓ IFÁ PARA LA MODERACIÓN.",
  "43. SE ADIVINÓ IFÁ PARA SABER ESPERAR, PARA ENCONTRAR LO BUENO.",
  "44. SE ADIVINO IFÁ PARA LA ENSEÑANZA DE ODU, OBARISA Y OGÚN.",
  "45. LA RECEPCION DE OLOFIN.",
  "46. CUANDO HABÍA DOS PODEROSOS PUEBLOS.",
  "47. LAS CUATROS HIJAS SOLTERONAS DE ODUDUWA (CUANDO ORÚNMILA SE SENTÍA NOSTÁLGICO).",
  "48. CUANDO ORÚNMILA VIVÍA EN LA TIERRA DE OSHAS.",
  "49. CUANDO ORÚNMILA SE ENCONTRÓ PERSEGUIDO.",
  "50. EL QUIQUIRIQUI.",
  "51. CUANDO OLOFIN CREÓ LA TIERRA.",
  "52. LA GUERRA ENTRE EL HIJO DEL CUCHILLO(OBE) Y EL CUERPO(ARÁ).",
  "53. EL PRINCIPIO Y FIN DE TODAS LAS COSAS.",
  "54. CUANDO INLE INDISPONÍA A SUS HIJOS.",
  "55. EL QUE IMITA, FRACASA.",
  "56. LA CABEZA SIN CUERPO (SÓLO ORÚNMILA LO SALVA).",
  "57. TODOS LOS RÍOS DESEMBOCAN EN EL MAR.",
  "58. LA TRAICIÓN DE EJIOGBE A ORAGUN.",
  "59. YEMAYÁ CREA LOS REMOLINOS.",
  "60. CUANDO EL CUERPO SE CANSÓ DE LLEVAR LA CABEZA.",
  "61. CUANDO LA SOMBRA ADQUIRIÓ PODER.",
  "62. LOS DOS HERMANOS.",
  "63. EL DIA Y SU RIVAL LA NOCHE.",
  "64. CUANDO LA DESOBEDIENCIA SE CANSÓ.",
  "65. LA TIERRA ERA HIJA DE UN REY.",
  "66. EL CAMINO DE LOS PIGMEOS.",
  "67. LA JUSTICIA DIVINA.",
  "68. OBATALÁ CONDENÓ A MORIR EN LA HORCA AL GALLO.",
  "69. LA PELEA ENTRE EL MAJÁ Y EL CANGREJO.",
  "70. EL LEON REY DE LA SELVA.",
  "71. NO MATAR ANIMALES SIN CONSULTAR CON ORÚNMILA.",
  "72. OLOFIN Y LOS NIÑOS.",
  "73. PEREGRINAJE DE EJIOGBE, DONDE SE LE DIO LA VUELTA AL MUNDO.",
  "74. AQUÍ ORÚNMILA LE ENAMORÓ LA MUJER AL GALLO.",
  "75. LA ROSA ROJA Y EL SACRIFICIO EN VANO DE EJIOGBE.",
  "76. LOS SÚBDITOS DE OLOFIN.",
  "77. OLOFIN SUBIÓ A OKE A LAS CUATRO DE LA MAÑANA.",
  "78. ADÁN Y EVA.",
  "79. CUANDO ORÚNMILA NO TENÍA DONDE VIVIR.",
  "80. COMO ATANDÁ GANÓ SU LIBERTAD.",
  "81. ALGUIEN DIJO: MIS OJOS SON BUENOS. OTRO DIJO: MI CABEZA ES BUENA.",
  "82. LA DOBLE SALVACIÓN.",
  "83. EL ASHINIMÁ.",
  "84. UNA COSA PEQUEÑA PODRÁ HACERSE MUY GRANDE.",
  "85. EL ASHIBATÁ.",
  "86. LA DISPUTA ENTRE EL AGUA LA PLAZA Y LA TIERRA.",
  "87. LOS TRES PERSONAJES.",
  "88. ORERE MUJER DE ORÚNMILA.",
  "89. CUANDO OLOFIN QUISO ABANDONAR LA TIERRA.",
  "90. EL AWO KOSOBE.",
  "91. EL REINADO DE EJIOGBE.",
  "92. LA GENTE REVIRADA CONTRA ORÚNMILA.",
  "93. LA CORONACION DE EJIOGBE.",
  "94. LA MONTAÑA Y EL AWO DEL REY.",
  "95. EWE IKOKO MUJER DE ORÚNMILA.",
  "96. LOS INQUILINOS DEL GOBERNADOR.",
  "97. ORÚNMILA DESMOCHADOR DE PALMAS.",
  "98. LOS TRES HERMANOS.",
  "99. OSHUN Y EL IDEU.",
  "100. ELEGBA EL HIJO DE OLOFIN.",
  "101. LA GENTE CON PICAZON.",
  "102. LA CONFIANZA DEL OBA.",
  "103. LAS CUATRO HIJAS DE OLOFIN.",
  "104. EL PACTO DE LA TIERRA Y LA MUERTE.",
  "105. DOS LINEAS PARALELAS.",
  "106. DONDE NACIO ALA GBA NFO GEDE.",
  "107. DONDE NACIO LA GRAN VIRTUD DE LAS PALABRAS DE OBI.",
  "108. NO SE MATAN RATONES.",
  "109. EL HIJO DE OSHOSI E IKU.",
  "110. AQUI NACIO EL ITA DE SANTO Y EL GOLPE DE ESTADO.",
  "111. EL VIGILANTE MALO (AMI).",
  "112. LA PELEA DEL AKUKO E IKU.",
  "113. NO SE BURLE DE LOS BORRACHOS.",
  "114. NACIO EL RELOJ DE ARENA, EL DIA Y LA NOCHE.",
  "115. OLERGUERE EL TRAMPOSO.",
  "116. CUANDO ESHU ENSEÑO A ORÚNMILA A USAR EL ORACULO DE LA ADIVINACION.",
  "117. NACIO QUE OSUN E IFA ANDEN JUNTOS.",
  "118. BABA EJIOGBE NO COME BONIATO (KUKUNDUKU).",
  "119. PORQUE OLOFIN SE RETIRA A LOS SEIS DIAS DE LA CEREMONIA DE IFA.",
  "120. EL AURA TIÑOSA ES SAGRADA Y LA CEIBA ES DIVINA.",
  "121. EL TOQUE DE QUEDA. CUANDO ELEGBA Y OGGUN COMIERON CHIVO POR PRIMERA VEZ.",
  "122. EL PUERTO Y EL TELESCOPIO.",
  "123. EL COMIENZO DEL MUNDO. LOS SIETE PRINCIPES CORONADOS.",
  "124. EJIOGBE, EL PODER DE SU NATURALEZA.",
  "125. OYA, LA DUEÑA DEL CEMENTERIO.",
  "126. POR BABA LE QUITARON A OYA LA CANDELA.",
  "127. EL LEON Y LOS HOMBRES.",
];


const _ogbeOyecuPatakies = <String>[
  '1. SE HIZO ADIVINACION PARA ORI CUANDO ESTABA SOLA.',
  '2. SE ADIVINO PARA AGBODIWARAN Y OSEREMOGBO.',
  '3. SE ADIVINO PARA ORISHANLA.',
  '4. SE ADIVINÓ PARA EL REY QUE HABÍA SIDO DESTRONADO.',
  '5. SE ADIVINÓ PARA EL REY DE OFA.',
  '6. LA CABEZA DESNUDA.',
  '7. CUANDO ODUDUWA BAJÓ A LA CASA DE OLOFIN EN LA TIERRA.',
  '8. OGBE YEKU ADIVINÓ PARA AGBOYA.',
  '9. OGBE YEKU ADIVINÓ PARA OBALUFÓN.',
  '10. OGBE YEKU ADIVINÓ EN EL CIELO PARA EL BRONCE Y PARA EL TAMBOR.',
  '11. OGBE YEKU ADIVINÓ EN EL CIELO PARA EL TIGRE.',
  '12. OGBE YEKU ADIVINA PARA SI MISMO ANTES DE VENIR AL MUNDO.',
  '13. SE ADIVINO PARA OGBE YEKU CONTRA IKU.',
  '14. SE LE ADIVINÓ A OGBE YEKU PARA UNA LARGA VIDA.',
  '15. OGBE YEKU ADIVINO PARA EL PUERCO ESPIN (ERIZO URE) Y PARA EL CAZADOR.',
  '16. SE ADIVINÓ PARA EL HOMBRE ADULTO EN BUSCA DE LONGEVIDAD.',
  '17. SE ADIVINÓ PARA ODOGBO.',
  '18. OLOKUN Y ALAGEMO.',
  '19. EL GOBERNADOR DE OFA.',
  '20. LA CAIDA DEL REY DE OFA.',
  '21. EL GOBIERNO DE UN PUEBLO.',
  '22. LA DISPUTA DEL SOL Y LA LUNA.',
  '23. CUANDO OSHÚN SALVÓ A AGAYÚ.',
  '24. EL LEON SE HACE REY DE LA SELVA.',
  '25. LA PERSUASION.',
  '26. EL CHIVO, EL LEON Y EL TIGRE.',
  '27. CUANDO ODUDUWA SE HIZO DE LA CONFIANZA DE OLOFIN.',
  '28. ODI MEYI, OJUANI MEYI Y ORANGUN, LAS TRES MADRINAS DE CUBA.',
  '29. EL CHIVO Y LA MADRE.',
  '30. EL CAMINO DE LA TRANSFORMACION.',
  '31. CUANDO QUERIAN DESTRONAR A OLOFIN.',
  '32. NACIERON LOS TRES ITA DE IFA.',
  '33. CUANDO EL LEON VENCIO A SUS ENEMIGOS.',
  '34. EL PUEBLO SIN GOBIERNO.',
];

const _babaEjiogbePatakiesContent = <String, String>{
  '1. LA CABEZA COMO UNA DIVINIDAD.': '''EL TRABAJO MÁS IMPORTANTE DE EJIOGBE EN EL CIELO ES SU
REVELACIÓN DE CÓMO LA CABEZA, QUE ERA EN SI MISMA UNA
DIVINIDAD, LLEGÓ A OCUPAR UN LUGAR PERMANENTE EN EL CUERPO.
ORIGINALMENTE LAS DIVINIDADES FUERON CREADAS SIN LA CABEZA
COMO APARECEN HOY, PORQUE LA CABEZA MISMA ERA UNA DE LAS
DIVINIDADES.
EL AWÓ QUE HIZO ADIVINACIÓN PARA LA CABEZA, ORI-OMO ATETE NI
IRON (EN LO ADELANTE LLAMADO ORI), SE LLAMABA AMURE, AWÓ EBA
ONO, QUIEN VIVIÓ EN EL CIELO.
ORÚNMILA INVITÓ A AMURE A QUE HICIERA ADIVINACIÓN PARA ÉL
ACERCA DE CÓMO LLEGAR A TENER UNA FISONOMÍA FÍSICA COMPLETA,
PORQUE NINGUNA DE ELLAS (LAS DIVINIDADES) TENÍA UNA CABEZA EN
ESE ENTONCES. EL AWÓ LE DIJO A ORÚNMILA QUE FROTARA AMBAS
PALMAS EN ALTO Y ROGARA TENER UNA CABEZA (DUZOSORI EN
YORUBA O UHUNAWUN ARABONA EN BENIN).
SE LE DIJO QUE HICIERA SACRIFICIO CON CUATRO NUECES DE KOLÁ,
CAZUELA DE BARRO, ESPONJA Y JABÓN.
SE LE DIJO QUE GUARDARA LA NUECES DE KOLÁ EN SU LUGAR
SAGRADO SIN PARTIRLAS, PORQUE UN VISITANTE INCONSECUENTE
VENDRÍA MÁS TARDE A HACERLO.
ORI (CABEZA) TAMBIÉN INVITÓ A AMURE PARA ADIVINACIÓN Y LE DIJO
QUE SIRVIERA A SU ÁNGEL GUARDIÁN CON CUATRO NUECES DE KOLÁ,
LAS CUALES ÉL NO PODÍA COSTEAR, AUNQUE SE LE SEÑALÓ QUE SÓLO
EMPEZARÍA A PROSPERAR DESPUÉS DE REALIZADO EL SACRIFICIO.
LUEGO DE REALIZAR SU PROPIO SACRIFICIO, ORÚNMILA DEJÓ LAS
CUATROS NUECES DE KOLÁ EN UN LUGAR SAGRADO DE IFÁ COMO SE
LE HABÍA DICHO QUE HICIERA. POCO DESPUÉS ESHU- ELEGBA ANUNCIÓ
EN EL CIELO QUE ORÚNMILA TENÍA CUATRO BELLAS NUECES DE KOLÁ
EN SU LUGAR SAGRADO Y QUE ESTABA BUSCANDO UNA DIVINIDAD
PARA QUE LAS PARTIERA.
ENCABEZADAS POR OGÚN, TODAS LAS DIVINIDADES VISITARON A
ORÚNMILA UNA TRAS OTRA, PERO ÉL LE DIJO A CADA UNA DE ELLAS
QUE NO ERA LO SUFICIENTEMENTE FUERTES PARA PARTIR LAS
NUECES DE KOLÁ.
ELLAS SE SINTIERON DESAIRADAS Y SE ALEJARON DE ÉL, MOLESTAS.
HASTA EL MISMO ORISHANLA (DIOS EL HIJO) VISITÓ A ORÚNMILA, PERO
ÉSTE LO OBSEQUIÓ CON DISTINTAS Y MEJORES NUECES DE KOLÁ,
SEÑALANDO QUE LAS NUECES EN CUESTIÓN NO ESTABAN DESTINADAS
A SER PARTIDAS POR ÉL.
COMO SE SABE QUE ORISHANLA AL IGUAL QUE DIOS NUNCA PIERDE LA
CALMA, ÉSTE ACEPTÓ LAS NUECES DE KOLÁ FRESCAS QUE ORÚNMILA
LE OFRECÍA Y SE MARCHÓ.
FINALMENTE, ORÍ DECIDIÓ VISITAR A ORÚNMILA, YA QUE ERA ÉL LA
ÚNICA DIVINIDAD QUE NO HABÍA TRATADO DE PARTIR LAS MISTERIOSAS
NUECES DE KOLÁ, ESPECIALMENTE CUANDO NI SIQUIERA PODÍA
PERMITIRSE COMPRAR AQUELLAS CON QUE SE LE HABÍA REQUERIDO
SERVIR A SU ÁNGEL GUARDIÁN. ENTONCES SE DIRIGIÓ RODANDO
HASTA LA CASA DE ORÚNMILA.
TAN PRONTO COMO ORÚNMILA VIO A ORÍ ACERCARSE RODANDO A SU
CASA, SALIÓ A SU ENCUENTRO Y LO ENTRÓ CARGAD INMEDIATAMENTE,
ORÚNMILA COGIÓ LA CAZUELA DE BARRO, LA LLENÓ DE AGUA Y USÓ LA
ESPONJA Y EL JABÓN PARA LAVAR A ORÍ. LUEGO DE SECARLO
ORÚNMILA LLEVÓ A ORÍ HASTA SU LUGAR SAGRADO Y LE PIDIÓ QUE
PARTIERA LAS NUECES DE KOLÁ, PORQUE DESDE HACÍA MUCHO ÉSTAS
LE HABÍAN SIDO RESERVADAS.
LUEGO DE AGRADECER A ORÚNMILA SU HONROSO GESTO, ORÍ REZÓ
POR ORÚNMILA CON LAS NUECES DE KOLÁ, PARA QUE TODO LO QUE
ÉSTE HICIERA TUVIERA CUMPLIMIENTO Y MANIFESTACIÓN.
A CONTINUACIÓN, ORI UTILIZÓ LAS NUECES DE KOLÁ PARA ORAR POR
ÉL MISMO, PARA TENER UN LUGAR DE RESIDENCIA PERMANENTE Y
MUCHOS SEGUIDORES, ENTONCES ORÍ RODÓ HACIA ATRÁS Y
ARREMETIÓ CONTRA LAS NUECES DE KOLÁ Y ÉSTAS SE PARTIERON
CON UNA RUIDOSA EXPLOSIÓN QUE SE ESCUCHÓ A TODO LO LARGO Y
ANCHO DEL CIELO.
AL ESCUCHAR EL RUIDO DE LA EXPLOSIÓN, TODAS LAS OTRAS
DIVINIDADES COMPRENDIERON DE INMEDIATO QUE FINALMENTE
HABÍAN SIDO PARTIDAS LAS NUECES DE KOLÁ DEL LUGAR SAGRADO DE
ORÚNMILA Y TODAS SINTIERON CURIOSIDAD POR SABER QUIÉN HABÍA
LOGRADO PARTIR LAS NUECES QUE HABÍAN DESAFIADO A TODOS,
INCLUYENDO ORISHANLA.
CUANDO POSTERIORMENTE ESHU-ELEGBA ANUNCIÓ QUE HABÍA SIDO
ORÍ QUIEN HABÍA LOGRADO PARTIRLAS, TODAS LAS DIVINIDADES
CONCORDARON EN QUE LA "CABEZA'ERA LA DIVINIDAD INDICADA PARA
HACERLO. CASI INMEDIATAMENTE DESPUÉS, LA MANO, LOS PIES, EL
CUERPO, EL ESTÓMAGO, EL PECHO, EL CUELLO, ETC., QUIENES HASTA
ENTONCES HABÍAN TENIDO IDENTIDAD ESPECÍFICA, SE REUNIERON
TODOS Y DECIDIERON IRSE A VIVIR CON LA CABEZA, NO HABIENDO
COMPRENDIDO ANTES QUE ÉSTE FUERA TAN IMPORTANTE.
JUNTOS, TODOS LEVANTARON A LA CABEZA SOBRE ELLOS Y ALLÍ, EN EL
LUGAR SAGRADO DE ORÚNMILA, LA CABEZA FUE CORONADA COMO
REY DEL CUERPO.
ES A CAUSA DEL PAPEL DESEMPEÑADO POR ORÚNMILA EN SU
FORTUNA QUE LA CABEZA TOCA EL SUELO PARA DEMOSTRAR
RESPETO Y REVERENCIA A ORÚNMILA HASTA EL DÍA DE HOY.
ESTA ES TAMBIÉN LA RAZÓN DE QUE A PESAR DE SER LA MÁS JOVEN
DE TODAS LAS DIVINIDADES, ORÚNMILA SEA LA MÁS IMPORTANTE Y
POPULAR DE TODAS ELLAS.
PARA QUE EL HIJO DE EJIOGBE VIVA MUCHO TIEMPO EN LA TIERRA, ÉL
DEBE BUSCAR AWOS INTELIGENTES QUE LE PREPAREN UN JABÓN DE
BAÑO ESPECIAL EN EL CRÁNEO DE CUALQUIER ANIMAL.
EJIOGBE ES LA DIVINIDAD PATRONA DE LA CABEZA PORQUE FUE ÉL EN
EL CIELO QUIEN REALIZÓ EL SACRIFICIO QUE CONVIRTIÓ A LA CABEZA
EN EL REY DEL CUERPO.
EJIOGBE HA RESULTADO SER EL MÁS IMPORTANTE ODU DE ORÚNMILA
EN LA TIERRA A PESAR DE QUE ORIGINALMENTE ERA UNO DE LOS MÁS
JÓVENES.
ÉL PERTENECE A LA SEGUNDA GENERACIÓN DE LOS PROFETAS QUE SÉ
OFRECIERON PARA VENIR A ESTE MUNDO PARA, MEDIANTE EL
EJEMPLO, HACERLO UN MEJOR LUGAR PARA LOS QUE LO HABITAN.
ÉL FUE UN APÓSTOL DE ORÚNMILA MUY CARITATIVO, TANTO CUANDO
ESTABA EN EL CIELO COMO CUANDO VINO A ESTE MUNDO.''',
  '2. EJIOGBE PARTE HACIA LA TIERRA.': '''
MIENTRAS TANTO, ORISHANLA YA SE ENCONTRABA EN LA TIERRA Y
ESTABA CASADO CON UNA MUJER, LLAMADA AFIN, QUIEN, SIN ÉL
SABERLO, NO TENÍA MUCHOS DESEOS DE TENER UN HIJO.
PERO ORISHANLA QUERÍA DESESPERADAMENTE TENER UN HIJO EN LA
TIERRA.
AL MISMO TIEMPO EN EL CIELO, OMONIGHOROGBO HABÍA IDO ANTE EL
ALTAR DE OLODUMARE PARA DESEAR VENIR A LA TIERRA COMO HIJO
DE AFIN Y ORISHANLA.
ÉL ESTABA IGUALMENTE DETERMINADO A MOSTRAR AL MUNDO LO QUE
SÉ NECESITABA PARA SER BENÉVOLO Y DE NOBLE CORAZÓN. SUS
DESEOS FUERON CONCEDIDOS POR EL PADRE TODOPODEROSO.
LUEGO DE OBTENER EL PERMISO DE SU ÁNGEL GUARDIÁN, ÉL PARTIÓ
HACIA LA TIERRA.
''',
  '3. EL NACIMIENTO DE BABA EJIOGBE. LOS TRABAJOS TERRENALES DE EJIOGBE.': '''
ENTRE TANTO, AFÍN, LA ESPOSA DE ORISHANLA, QUEDÓ EMBARAZADA
EN LA TIERRA.
TRADICIONALMENTE, ORISHANLA TENÍA PROHIBIDO EL VINO DE PALMA,
MIENTRAS QUE SU ESPOSA AFÍN TENÍA PROHIBIDA LA SAL.
(ORISHANLA KOI MU EMO. AFIN KOI JE IYO).
EL EMBARAZO DE AFÍN NO ALIVIÓ DEL TODO LA TENSIÓN QUE EXISTÍA
ENTRE LA PAREJA. LA MUJER SE VOLVIÓ AÚN MÁS BELICOSA A MEDIDA
QUE SU EMBARAZO AVANZABA CON LOS MESES.
NUEVE MESES DESPUÉS, NACIÓ UN VARÓN, POCO DESPUÉS DEL
PARTO, ORISHANLA SE DIO CUENTA DE QUE NO HABÍA COMIDA EN LA
CASA PARA ALIMENTAR A LA MADRE LACTANTE.
RÁPIDAMENTE PARTIÓ HACIA LA GRANJA PARA RECOLECTAR ÑAMES,
QUIMBOMBÓ Y VEGETALES.
ORISHANLA SE DEMORÓ UN POCO EN REGRESAR DE LA GRANJA, LO
CUAL ENFURECIÓ A SU ESPOSA.
ELLA COMENZÓ A QUEJARSE DE QUE SU ESPOSO LA HABÍA DEJADO
PASAR HAMBRE EL MISMO DÍA EN QUE HABÍA DADO A LUZ Y SEÑALÓ
QUE ESTO ERA UNA CONFIRMACIÓN DE QUE ÉL NO SENTÍA AMOR POR
ELLA. ELLA PENSÓ QUE ERA HORA DE CONCLUIR EL MATRIMONIO
PONIENDO FIN A LA VIDA DE SU ESPOSO.
SABIENDO QUE ORISHANLA TENÍA PROHIBIDO EL VINO DE PALMA Y QUE
BEBERLO PODÍA TERMINAR SU VIDA, PROCEDIÓ A ECHAR VINO DE
PALMA EN LA OLLA DEL AGUA DE BEBER DE SU ESPOSO.
TAN PRONTO HIZO ESTO, DEJÓ AL NIÑO DE UN DÍA DE NACIDO EN LA
CAMA Y SALIÓ A VISITAR A SUS VECINOS.
ENTRE TANTO, ORISHANLA HABÍA REGRESADO DE LA GRANJA Y
PROCEDIÓ A PREPARAR COMIDA PARA SU ESPOSA.
MIENTRAS EL NAME SE COCINABA AL FUEGO, SE DIRIGIÓ AL CUARTO A
SACAR AGUA CON SU VASIJA HABITUAL, UNA CONCHA DE CARACOL, DE
LA OLLA DE AGUA ENVENENADA.
CUANDO ESTABA A PUNTO DE BEBER DEL AGUA, SU HIJO DE UN DÍA DE
NACIDO QUE ESTABA EN LA CAMA LE DIJO:
"PADRE, NO TOME DE ESA AGUA PORQUE MI MADRE ECHÓ VINO DE
PALMA EN ELLA".
AUNQUE SORPRENDIDO POR EL HECHO DE QUE UN NIÑO DE UN DÍA DE
NACIDO PUDIERA HABLAR, HIZO CASO A LA ADVERTENCIA.
ORISHANLA, SIN EMBARGO, TERMINÓ LA COMIDA PERO EN UN GESTO
DE REPRESALIA, LE ECHÓ SAL A LA SOPA A SABIENDAS DE QUE ÉSTA
ERA EL VENENO DE SU ESPOSA.
LUEGO DE GUARDAR LA COMIDA PARA SU ESPOSA, SE FUE DE LA CASA
PARA JUGAR UNA PARTIDA DE AYO CON SUS AMIGOS.
ENTRE TANTO, SU ESPOSA REGRESÓ Y SE DIRIGIÓ AL SITIO DONDE
ESTABA SU COMIDA.
CUANDO IBA A COMENZAR A COMER, EL HIJO HABLÓ DE NUEVO PARA
DECIRLE A ELLA, MADRE, NO COMA DE ESA COMIDA PORQUE MI PADRE
LE ECHÓ SAL"
CASI INMEDIATAMENTE DESPUÉS DE HABER ESCUCHADO AL NIÑO, ELLA
SE PUSO HISTÉRICA Y LE GRITÓ A LOS VECINOS QUE VINIERAN A
SALVARLA DE SU ESPOSO, QUE ESTABA TRATANDO DE MATARLA POR
HABERLE DADO UN HIJO.
SUS GRITOS ATRAJERON A ESPECTADORES DE LAS CASAS VECINAS
POCO DESPUÉS SE CONVOCÓ UNA REUNIÓN DE LAS DIVINIDADES EN
LA CASA DE ORISHANLA.
ESTE RECIBIÓ LA CITACIÓN EN EL LUGAR DONDE SE ENCONTRABA
JUGANDO AYO Y SE MANTUVO CALMADO EN TODO MOMENTO, INCLUSO
CUANDO SU ESPOSA LO ASIÓ Y TIRABA DE ÉL.
FUE OGÚN QUIEN PRESIDIÓ LA CONFERENCIA YA QUE ORISHANLA, EL
PRESIDENTE TRADICIONAL, SE ENCONTRABA EN EL BANQUILLO EN
ESTA OPORTUNIDAD.
OGÚN INVITÓ A AFÍN A QUE DIERA LO QUE HABÍA SUCEDIDO Y ELLA
NARRÓ CÓMO SU ESPOSO HABÍA ECHADO SAL A SU COMIDA, LA CUAL
ÉL SABÍA LE ESTABA PROHIBIDA.
INTERROGANDO SOBRE CÓMO SUPO QUE SE LE HABÍA ECHADO SAL A
LA SOPA Y QUE HABÍA SIDO SU ESPOSO EL CULPABLE, ELLA EXPLICÓ
QUE HABÍA SIDO INFORMADA POR SU HIJO DE UN DÍA DE NACIDO.
LAS DIVINIDADES PENSARON QUE ESTABA LOCA PORQUE NADIE PODÍA
IMAGINAR CÓMO UN NIÑO TAN PEQUEÑO PODÍA HABLARLE A SU
MADRE.
ORISHANLA FUE INVITADO A DEFENDERSE DE LAS ACUSACIONES Y,
CONTRARIO A LO ESPERADO, CONFIRMÓ QUE EFECTIVAMENTE ÉL
HABÍA ECHADO SALA LA SOPA DE SU ESPOSA.
EXPLICÓ, SIN EMBARGO, QUE LO HABÍA HECHO PARA CASTIGAR UNA
ACCIÓN SIMILAR DE ELLA EN SU CONTRA, EJECUTADA CON
ANTERIORIDAD ESE MISMO DÍA.
ACUSÓ A LA ESPOSA DE HABERLE ECHADO VINO DE PALMA A SU OLLA
DE AGUA DE BEBER CUANDO TODOS, INCLUIDA ELLA, SABÍAN QUE ÉSTE
LE ESTABA PROHIBIDO.
PREGUNTANDO SOBRE CÓMO HABÍA TENIDO CONOCIMIENTO DE LA
ALEGADA ACCIÓN DE SU ESPOSA, ÉL TAMBIÉN EXPLICÓ QUE HABÍA
SIDO SU RECIÉN NACIDO HIJO QUIEN LE HABÍA ADVERTIDO QUE NO
BEBIERA DE ESA AGUA PORQUE SU MADRE LE HABÍA ECHADO VINO DE
PALMA.
TODOS LOS OJOS SE VOLVIERON ENTONCES HACIA EL NIÑO, A QUIEN
YA SE LE CONSIDERABA UNA CRIATURA MISTERIOSA.
SIN HABER SIDO PREGUNTADO DE MANERA ESPECÍFICA, ÉSTE BRINDÓ
LOS ELEMENTOS QUE FALTABAN AL ACERTIJO AL DECIR:
"EJI MOGBE MI OGBE ENIKON "LA TRADUCCIÓN SIGNIFICA; "QUE ÉL
HABÍA VENIDO A LA TIERRA PARA SALVAR LAS VIDAS DE SUS DOS
PROGENITORES",
Y QUE ESTA ERA LA RAZÓN POR LA CUAL LE HABÍA DADO A AMBOS EL
AVISO QUE LES EVITÓ UNA MUTUA DESTRUCCIÓN.
CONSECUENTEMENTE, NO CONSTITUYÓ UNA SORPRESA EL QUE SIETE
DÍAS MÁS TARDE AL DÁRSELE UN NOMBRE SUS PADRES DECIDIERON
LLAMARLO
"EJIOGBE" O DOBLE SALVACIÓN.
ES DEBIDO A ESTE PRIMER TRABAJO DE EJIOGBE EN LA TIERRA QUE
CUANDO ÉL SALE DURANTE LA CEREMONIA DE INICIACIÓN EN EL
IGBODUN, SE REQUIERE QUE TODOS LOS MATERIALES DEL SACRIFICIO
SEAN DOBLES: 2 CHIVOS, 2 CHIVAS, 4 GALLINAS, 2 CARACOLES, 2
PESCADOS, 2 RATAS, ETC. CUANDO EJIOGBE SALE EN EL IGBODUN
SIEMPRE SE ECHA SAL Y VINO DE PALMA A LOS MATERIALES DE
INICIACIÓN, EN CONMEMORACIÓN DE LOS HECHOS OCURRIDOS EN EL
DÍA DE SU NACIMIENTO.
''',
  '4. LAS OBRAS DE EJIOGBE EN LA TIERRA.': '''EL NIÑO PRODIGIO HIZO MUCHAS COSAS MISTERIOSAS MIENTRAS CRECÍA, PERO SU PRIMER GRAN
MILAGRO LO REALIZÓ A LA EDAD DE QUINCE AÑOS, CUANDO SU MADRE LO LLEVÓ A OJA-AJIGBOMEKON,
EL ÚNICO MERCADO QUE EXISTÍA EN ESE TIEMPO Y EN EL CUAL LOS COMERCIANTES DEL CIELO Y LA
TIERRA EFECTUABAN TODA CLASE DE NEGOCIOS, DESDE LA VENTA BIENES HASTA LA ADIVINACIÓN.
TODOS LOS QUE TUVIERAN ALGÚN TIPO DE MERCANCÍA, HABILIDAD, ARTE, TECNOLOGÍA, ETC., PARA
VENDER IBAN AL MERCADO.  AWÓ NO DEBE SACRIFICAR ANIMALES POR GUSTO EN ESTE ODU Y EN ESTE
CAMINO. LA PREGUNTA SOBRE SI MATAR A LOS SIETE DÍAS RESALTA LA IMPORTANCIA DEL RESPETO
HACIA LOS SACRIFICIOS Y LA NECESIDAD DE SEGUIR PROCEDIMIENTOS ADECUADOS.''',
  '5. EL MILAGRO DEL MERCADO.': '''EN SU CAMINO AL MERCADO, ÉL SE ENCONTRÓ CON UNA MUJER. LA DETUVO Y LE DIJO QUE ELLA TENÍA
UN PROBLEMA. CUANDO ELLA SE DISPONÍA A HABLAR, ÉL LE DIJO QUE NO SE MOLESTARA EN HACERLO
PORQUE ÉL CONOCÍA SUS PROBLEMAS MEJOR QUE ELLA MISMA. EJIOGBE LE DIJO A LA MUJER QUE ELLA
ESTABA EMBARAZADA DESDE HACÍA TRES AÑOS, PERO QUE SU EMBARAZO NO SE HABÍA DESARROLLADO. LE
DIJO QUE HICIERA SACRIFICIO CON 16 CARACOLES, UNA GALLINA, UNA PALOMA, CINCO NUECES DE
KOLÁ "RISUEÑAS"Y MIEL. LE DIJO IGUALMENTE QUE ASARA UN MACHO CABRÍO, AKAR (PANECILLOS DE
FRÍJOL) Y EKÓ PARA HACER EL SACRIFICIO A ESHUELEGBA. LA MUJER TRAJO LOS MATERIALES PARA EL
SACRIFICIO Y CUANDO LO HUBO REALIZADO, EJIOGBE LE ASEGURÓ QUE SUS PROBLEMAS HABÍAN
TERMINADO. SIN EMBARGO, LE DIJO QUE LUEGO QUE HUBIERA DADO A LUZ SIN PROBLEMAS, DEBÍA
TRAER UNA PEQUEÑA BOA, UNA SERPIENTE DE LA FAMILIA CONSTRICTORA LLAMADA OKA EN YORUBA,
PARA OFRECÉRSELA EN AGRADECIMIENTO A ORÚNMILA. LE DIJO QUE AGREGARA CARACOL Y CUALQUIER
OTRA COSA QUE PUDIERA. LA MUJER HIZO EL SACRIFICIO Y SIGUIÓ SU CAMINO.''',
  '6. LOS MILAGROS DEL LISIADO Y EL CIEGO.': '''LA PRÓXIMA PERSONA CON QUIEN EJIOGBE SE ENCONTRÓ EN SU CAMINO AL MERCADO FUE UN LISIADO
LLAMADO ARO. AL IGUAL QUE HABÍA HECHO ANTES CON LA MUJER EMBARAZADA, LE DIJO A ARO QUE
ÉSTE TENÍA UN PROBLEMA, PERO EL LISIADO LE RESPONDIÓ QUE ÉL NO TENÍA NINGÚN PROBLEMA Y QUE
ERA ÉL (EJIOGBE) QUIEN LO TENÍA. EJIOGBE SACÓ SU UROKE (VARA DE ADIVINACIÓN) Y LA APUNTÓ
EN DIRECCIÓN A LAS MANOS Y PIERNAS DEL LISIADO. DE INMEDIATO, ÉSTE SE PUSO DE PIE Y
CAMINÓ. ENTONCES ARO COMPRENDIÓ QUE, LEJOS DE ESTAR TRATANDO CON UN MUCHACHO, LO ESTABA
HACIENDO CON UN SACERDOTE. ARO SE PUSO DE RODILLAS PARA AGRADECER A EJIOGBE EL HABERLO
CURADO DE UNA ENFERMEDAD CON LA CUAL HABÍA NACIDO. SIN EMBARGO, EJIOGBE LE ACONSEJÓ QUE
FUERA Y LE SIRVIERA A ORÚNMILA, PERO QUE EN EL FUTURO SE ABSTUVIERA DE ESCONDER SUS
PROBLEMAS, PORQUE ENTONCES NO SABRÍA CUÁNDO OLODUMARE DARÍA RESPUESTA A SUS PLEGARÍAS.
EJIOGBE SEÑALÓ QUE SI ALGUIEN ESCONDÍA SUS PADECIMIENTOS, ÉSTOS LO LLEVARÍAN A LA TUMBA. A
CONTINUACIÓN, EJIOGBE SE ENCONTRÓ CON UN CIEGO Y LE PREGUNTÓ SI TENÍA UN PROBLEMA. EL
CIEGO LE RESPONDIÓ QUE ÉL NO TENÍA PROBLEMA ALGUNO. UNA VEZ MÁS EJIOGBE APUNTÓ CON SU
UROKE A LOS OJOS DEL HOMBRE Y AL INSTANTE ÉSTE RECOBRÓ LA VISIÓN. EL HOMBRE, QUIEN SE
SENTÍA INUNDADO DE DICHA, FUE ACONSEJADO POR EJIOGBE QUE SE PREPARARA PARA CONVERTIRSE EN
SEGUIDOR DE ORÚNMILA, A FIN DE MINIMIZAR SUS DIFICULTADES CON EL GÉNERO HUMANO. LE DIJO
IGUALMENTE QUE AL LLEGAR A SU CASA SIRVIERA SU CABEZA CON UN GALLO. DESPUÉS DE ESTO,
EJIOGBE LLEGÓ AL MERCADO. EJIOGBE REALIZÓ LOS MILAGROS ANTERIORMENTE SIN PEDIR RECOMPENSA
ALGUNA DE LOS BENEFICIARIOS.''',
  '7. EL RESULTADO DE IGNORAR EL CONSEJO DE EJIOGBE.': '''EN EL CAMINO A LA CASA AL REGRESO DEL MERCADO, SU MADRE LO DEJÓ ATRÁS. EJIOGBE SE ENCONTRÓ
CON UNA ARDILLA A LA ORILLA DEL CAMINO. ÉL LE ACONSEJÓ A LA ARDILLA QUE HICIERA SACRIFICIO
A ESHU-ELEGBA CON UN MACHO CABRÍO, PARA QUE LAS PALABRAS PRONUNCIADAS POR SU BOCA NO LE
OCASIONARAN LA DESTRUCCIÓN. LA ARDILLA RESPONDIÓ QUE SI EL HOMBRE JOVEN DESEABA CARNE PARA
COMER, NO LA IBA OBTENER DE ÉL. LA ARDILLA SE LLAMABA OTAN EN BENI Y OKERE EN YORUBA. MUY
CERCA, ÉL TAMBIẾN VIO A LA BOA, LLAMADA OKA EN YORUBA Y ARU EN BENIN. LE DIJO A LA BOA QUE
LA MUERTE ESTABA RONDANDO Y QUE LE LLEGARÍA MEDIANTE UN VECINO LOCUAZ. PARA EVITAR LA
CALAMIDAD, LE ACONSEJÓ A LA SERPIENTE QUE SIRVIERA SU CABEZA EN UN LUGAR SECRETO CON UN
CARACOL. NO DEBÍA PERMITIR QUE NINGUNA PERSONA REPITIERA AMÉN DESPUÉS DE SUS PLEGARIAS
CUANDO SIRVIERA SU CABEZA. FINALMENTE, SE ENCONTRÓ CON EL BOSQUE ESPESO (ETI EN BENI E IYO
EN YORUBA) Y LE ACONSEJÓ QUE OFRECIERA SACRIFICIO A ESHUELEGBA PARA EVITAR PROBLEMA SIN
GARANTÍA. TAMBIÉN SE ENCONTRÓ CON LA PALMA A QUIEN LE ACONSEJÓ QUE OFRECIERA UN MACHO
CABRÍO A ESHU-ELEGBA PARA QUE LOS PROBLEMAS DE OTRO NO LE ROMPIERAN EL CUELLO. LA PALMA
HIZO EL SACRIFICIO SIN DEMORA, IYO NO LO HIZO. DESPUÉS DE ESTO, EJIOGBE FUE PARA SU CASA.
EL VIAJE HACIA Y DESDE OJA AJIGBOMEKEN NORMALMENTE SE DEMORABA ALREDEDOR DE TRES MESES.
TAN PRONTO COMO LLEGÓ A LA CASA, RECIBIÓ EL MENSAJE DE QUE LA MUJER CON QUIEN SE HABÍA
ENCONTRADO EN EL CAMINO HACIA EL MERCADO ESTABA DE PARTO. RÁPIDAMENTE CORRIÓ HACIA LA CASA
DE ÉSTA Y ELLA PARIÓ CON LA AYUDA DEL USO DE UN ENCANTAMIENTO QUE LA TRADICIÓN DE IFÁ NO
PERMITE SEA REPRODUCIDO EN ESTE LIBRO. ESE ES UNO DE LOS ENCANTAMIENTOS CON EL CUAL LOS
SACERDOTES DE IFÁ AYUDAN A PARIR A LAS MUJERES EMBARAZADAS HASTA ESTE DÍA. ELLA TUVO UN
VARÓN. TAN PRONTO COMO LA MUJER PUDO DESCANSAR EN EL LECHO, EL ESPOSO TOMÓ SU BUMERANG DE
CAZA (EKPEDE EN BENI Y EGION EN YORUBA) Y PARTIÓ HACIA EL BOSQUE EN BUSCA DE LA BOA, AL
IGUAL QUE DE CARNE PARA ALIMENTAR A SU MUJER. CUANDO LA BOA SE ENTERÓ QUE LA MUJER QUE
HABÍA ESTADO EMBARAZADA DURANTE TRES AÑOS HABÍA TENIDO UN HIJO, COMPRENDIÓ QUE EL ESPOSO
PRONTO VENDRÍA EN SU BUSCA, TAL COMO SE LE DIJO QUE EJIOGBE HABÍA ORIENTADO. MÁS BIEN
SORPRENDIDO, CORRIÓ HACIA LA CASA DE IYO (LA PARTE MÁS ESPESA DEL BOSQUE) PARA SERVIR ALLÍ
SU CABEZA EN PRIVADO. IYO LE DIO PERMISO PARA SERVIR SU CABEZA EN SU CASA. TAN PRONTO COMO
LA OKA SE SENTÓ A ORAR POR SU CABEZA, OKERE ENTRÓ EN LA CASA DE IYO. MIENTRAS OKA DECÍA
SUS ORACIONES, OKERE REPETÍA ASHÉ, ASHÉ (AMẾN). OKA RESPONDIÓ ALTERADO A OKERE QUE ÉL NO
NECESITABA EL AMÉN DE NADIE PARA SUS ORACIONES. ENTONCES SE ADENTRÓ AÚN MÁS EN LA CASA DE
IYO. AL MISMO TIEMPO, OKERE CAMBIÓ SU TONADA Y COMENZÓ A CANTAR: OKA, JOKOO KPEKPE RE KPE.
EN ESE PUNTO, EL HOMBRE CON EL BUMERANG, QUIEN SE ENCONTRABA BUSCANDO A OKA, ESCUCHÓ A LA
ARDILLA GRITAR Y COMENZÓ A RASTREAR SU POSICIÓN. COMO LA ARDILLA CONTINUABA GRITANDO
HISTÉRICAMENTE, OKA LE DISPARÓ Y ACABÓ CON SU VIDA. EL HOMBRE ENTONCES CORTÓ UNA VARA
AHORQUILLADA PARA ABRIR EL ESPESO BOSQUE. MIENTRAS CORTABA Y LIMPIABA A IYO, VIO AL LADO
DE OKA A LA ARDILLA SIN VIDA Y AL CARACOL CON EL CUAL LA BOA IBA A SERVIR SU CABEZA. ÉL LO
RECOGIÓ TODO Y PARTIÓ HACIA SU CASA. LA ESPESA HIERBA QUE EL CAZADOR CORTÓ CON UNA VARA
AHORQUILLADA SE HALLABA EN EL CUERPO DE UNA ALTA PALMA. LA PALMA SE ALEGRÓ Y RESPIRÓ NUEVA
VIDA TAN PRONTO COMO FUERON CORTADOS LOS ARBUSTOS QUE IMPEDÍAN QUE EL AIRE FRESCO LLEGARA
A SU CUERPO. ESTO SE DEBE A QUE LA PALMA FUE LA ÚNICA DEL LOTE QUE HIZO SACRIFICIO EN EL
MOMENTO ADECUADO. HASTA ESE DÍA, ES LA BOCA DE LA ARDILLA LO QUE LE HACE PERDER LA VIDA.
ES TAMBIÉN LA ARDILLA QUIEN LE DICE A LA GENTE DÓNDE SE ESCONDE LA BOA E INVARIABLEMENTE
ATRAE LA MUERTE SOBRE ÉSTE. ESTO TAMBIÉN EXPLICA POR QUÉ LA APARICIÓN DE EJIOGBE PARA UN
HOMBRE ALTO DE TEZ OSCURA EN IGBODUN SIGNIFICA PROSPERIDAD ASEGURADA PARA LA PERSONA,
DEBIDO A LA ALTA TALLA DE LA PALMA, QUIEN POR SI SOLA HIZO SACRIFICIO. SI, POR OTRO LADO,
LE SALE A UN HOMBRE PEQUEÑO DE TEZ CLARA, ÉSTE NO TRIUNFARÁ EN LA VIDA A NO SER QUE HAGA
SACRIFICIO. ESA ES LA SIGNIFICACIÓN DEL HECHO DE QUE EL PEQUEÑO PERO OSCURO IYO Y LA
ARDILLA Y LA BOA DE COLORES CLAROS NO HICIERON LOS SACRIFICIOS PRESCRITOS.''',
  '8. COMO EJIOGBE SOBREVIVIÓ LA IRA DE LOS MAYORES.': '''LA BENEVOLENCIA DEL JOVEN EJIOGBE LO HIZO TAN POPULAR QUE SU CASA ESTABA SIEMPRE LLENA DE
VISITANTES DE DÍA Y DE NOCHE. ÉL CURÓ A LOS ENFERMOS, HIZO SACRIFICIOS PARA LOS QUE ERAN
MENDIGOS DE MANERA QUE SE CONVIRTIERON EN RICOS, AYUDÓ A LAS MUJERES INFECUNDAS A TENER
HIJOS Y AYUDÓ A PARIR A TODAS LAS EMBARAZADAS QUE SOLICITABAN SU AYUDA. ESTAS ACTIVIDADES
LE GANARON LA ADMIRACIÓN DE LOS BENEFICIARIOS DE SU MAGNANIMIDAD, PERO LE ADJUDICARON LA
ENEMISTAD DE LOS AWOSES DE MÁS EDAD, QUIENES NO PODÍAN COMPARÁRSELES EN ALTRUISMO Y
BENEVOLENCIA. MUY PRONTO ÉL SE INQUIETÓ Y UNA NOCHE TUVO UN SUEÑO EN EL QUE SU ÁNGEL
GUARDIÁN LE DECÍA QUE ALGUNOS DE LOS MAYORES ESTABAN CONSPIRANDO EN SU CONTRA. CUANDO SE
DESPERTÓ A LA MAÑANA SIGUIENTE, ESTABA TAN CONFUSO QUE DECIDIÓ IR POR ADIVINACIÓN. ÉL FUE
POR ADIVINACIÓN A LOS SACERDOTES DE IFÁ SIGUIENTES AJOGODOLE EFO NI MO KPE IFA MI. OSIGI
SIGI LE EKPO USEE MI OOJAGBA IGBO ABU KELE KON LO OBE IDE. ELLOS LE ACONSEJARON QUE
HICIERA SACRIFICIO A SU IFÁ CON UNA CESTA DE CARACOLES. COMO ÉL NI SIQUIERA TENÍA DINERO
PARA COMPRAR CARACOLES, TODOS AQUELLOS A QUIENES PREVIAMENTE HABÍA AYUDADO LE TRAJERON
TODOS LOS QUE NECESITABA. LOS CARACOLES FUERON PARTIDOS Y EL LÍQUIDO DE SU INTERIOR FUE
RECOLECTADO. LOS AWOS RECOGIERON HOJAS DE ERO Y LAS MACHACARON CON EL LÍQUIDO DE LOS
CARACOLES PARA QUE EJIOGBE SE BAÑARA CON EL PREPARADO. DESPUÉS DEL SACRIFICIO, ÉL COMENZÓ
A VIVIR UNA VIDA PACÍFICA. POR ESTO CUANDO EJIOGBE APARECE DURANTE LA ADIVINACIÓN, A LA
PERSONA SE LE ACONSEJA QUE OFREZCA CARACOLES A IFÁ. CUANDO SALE EN IGBODUN, EL CHIVO PARA
LA CEREMONIA NO SE DEBERÁ OFRECER HASTA CINCO DÍAS MÁS TARDE. LO QUE SE DEBE OFRECER EN
ESE DÍA DE IGBODUN SON CARACOLES, RATA SECA Y PESCADO SECO. CUANDO EJIOGBE RECUPERÓ LA PAZ
DE ESPÍRITU DESPUÉS DE LA CEREMONIA, ÉL SE REGOCIÓ CANTANDO: UROKO IRO, ERERO LU UROKO
ERERO.''',
  '9. EJIOGBE REGRESA AL CIELO PARA SER JUZGADO.': '''ANTES DE QUE ÉL HICIERA SACRIFICIO, LOS MAYORES, QUIENES SENTÍAN QUE ÉL LES HABÍA
BLOQUEADO SUS MEDIOS DE SUBSISTENCIA MEDIANTE LA REALIZACIÓN DE MILAGROS GRATIS,
COMENZARON A IRSE PARA EL CIELO UNO TRAS OTRO PARA INFORMAR A OLODUMARE. ELLOS LO ACUSARON
DE ESTROPEAR EL MUNDO AL INTRODUCIR UN NUEVO CÓDIGO DE CONDUCTA QUE ERA TOTALMENTE
DESCONOCIDO PARA LA TIERRA. EJIOGBE, POR SU LADO, NO TENÍA VIDA PROPIA PORQUE INVERTÍA
TODO SU TIEMPO AL SERVICIO DE OTROS. CUANDO LOS NIÑOS TENÍAN CONVULSIONES, SE LE LLAMABA
PARA QUE LAS CURARA, LO CUAL HACÍA CON ENCANTAMIENTOS. AYUDABA A LAS EMBARAZADAS A PARIR,
ARREGLABA DISPUTAS ENTRE PERSONAS Y DEFENDÍA A LOS OPRIMIDOS. POCO SABÍA ÉL QUE ESTAS
ACTIVIDADES HUMANITARIAS HABÍAN MOLESTADO A LOS TRADICIONALMENTE INJUSTOS AWOS HASTA EL
PUNTO DE INCLUSO CONFABULARSE PARA MATARLO. EN ESTE PUNTO, OLODUMARE (OSALOBUA EN BENI),
EL PADRE EN EL CIELO, ORDENÓ QUE BUSCARAN A EJIOGBE. ENVIÓ A UN CABALLERO DEL CIELO A
BUSCARLO. EL CABALLERO UTILIZÓ SU PRUDENCIA PARA APLICAR UNA ESTRATEGIA CON EL FIN DE
LLEVAR A EJIOGBE AL CIELO. ANTES DE LLEGAR A LA CASA DE EJIOGBE SE QUITÓ EL UNIFORME DE
CABALLERO, LO GUARDÓ EN SU BOLSO Y FINGIÓ SER UN DESEMPLEADO EN BUSCA DE TRABAJO. AL
LLEGAR A DONDE ESTABA EJIOGBE, MUY TEMPRANO EN LA MAÑANA, LE ROGÓ QUE LE DIERA UN TRABAJO
DOMÉSTICO QUE LE PERMITIERA GANARSE LA VIDA. EJIOGBE LE INFORMÓ QUE NO DISPONÍA DE TRABAJO
PARA OFRECER PUES SU PROPIA OCUPACIÓN ERA OFRECER SERVICIOS GRATIS A LA GENTE DEL MUNDO.
CUANDO EL VISITANTE LLEGÓ, ÉL ESTABA A PUNTO DE DESAYUNAR. LO INVITÓ A QUE COMIERA CON ÉL,
PERO EL HOMBRE EXPLICÓ QUE NO TENÍA LOS REQUISITOS NECESARIOS PARA COMER DEL MISMO PLATO
QUE EJIOGBE. EL VISITANTE INSISTIÓ EN QUE COMERÍA CUALQUIER COSA QUE SOBRARA DESPUÉS QUE
EJIOGBE HUBIERA COMIDO. MIENTRAS QUE ESTA DISCUSIÓN SE ESTABA PRODUCIENDO, ALGUNOS
VISITANTES LLEGARON EN BUSCA DE AYUDA. ELLOS DIJERON QUE EL HIJO ÚNICO DE UNA FAMILIA
TENÍA CONVULSIONES Y DESEABAN QUE EJIOGBE FUERA Y REVIVIERA AL NIÑO. SIN INGERIR
ALIMENTOS, SALIÓ SEGUIDO POR EL CABALLERO DEL CIELO. LLEGÓ A LA CASA, PUSO LA RODILLA
IZQUIERDA EN EL SUELO Y REPITIÓ UN ENCANTAMIENTO DESPUÉS DE LO CUAL PRONUNCIÓ TRES VECES
EL NOMBRE DEL NIÑO Y A LA VEZ RESPONDIÓ. EL NIÑO ENTONCES ESTORNUDÓ, ABRIÓ LOS OJOS Y
PIDIÓ DE COMER. MIENTRAS TERMINABA LA OPERACIÓN DE LA CURA, OTROS VISITANTES SE LE
ACERCABAN ROGÁNDOLE QUE AYUDARA A UNA MUJER A PARIR LA CUAL SE HABÍA PASADO TODA LA NOCHE
CON DOLORES DE PARTO. FUE DERECHO HACIA LA CASA DE LA MUJER, A QUIEN SÓLO QUEDABA UN
ÚLTIMO ALIENTO CUANDO ÉL LLEGÓ.A SU ARRIBO HIZO UNA RÁPIDA ADIVINACIÓN Y LE ASEGURÓ A LA
GENTE QUE LA MUJER PARIRÍA SIN PROBLEMA. LE DIO IYEROSUN (POLVO DE ADIVINACIÓN) Y AGUA
PARA QUE SE LO TRAGARA. MIENTRAS ELLA TRAGABA EL AGUA, ÉL REPITIÓ UN ENCANTAMIENTO Y EL
NIÑO JUNTO CON LA PLACENTA SALIERON JUNTO EN EL MISMO MOMENTO. HUBO ALEGRÍA GENERAL EN LA
CASA Y, COMO ES HABITUAL, ÉL PARTIÓ SIN EXIGIR COMPENSACIÓN ALGUNA. EJIOGBE Y SU VISITANTE
REGRESARON AL HOGAR. EN ESTA OCASIÓN YA ERA BIEN PASADO EL MEDIODÍA Y ÉL AÚN NO HABÍA
DESAYUNADO. CUANDO ESTABA LLEGANDO A LA CASA ÉL SÉ ENCONTRÓ CON UNA GRAN MULTITUD
ESPERÁNDOLO. HABÍA UNA GRAN DISCUSIÓN QUE QUERÍAN QUE ÉL SOLUCIONARA. POCO A POCO FUE
SOLUCIONANDO TODAS LAS DISPUTAS, LA GENTE REGRESÓ ALEGREMENTE A SUS RESPECTIVAS CASAS Y SE
RECONCILIARON. SE SENTÓ A COMER LA COMIDA PREPARADA PARA ÉL Y NUEVAMENTE INVITÓ AL
VISITANTE QUIEN INSISTIÓ EN COMER DESPUÉS QUE ÉL. CUANDO ESTABA COMENZANDO A COMER, EL
VISITANTE FUE A LA HABITACIÓN CONTIGUA Y SE PUSO SUS ROPAS DE CABALLERO. LA VISTA DEL
HOMBRE CON LAS ROPAS CELESTIALES LE INDICÓ A EJIOGBE QUE ÉSTE ERA UN MENSAJERO DIVINO,
PROCEDENTE DEL CIELO. DE INMEDIATO DEJÓ DE COMER Y PREGUNTÓ AL CABALLERO DEL CIELO POR EL
MENSAJE QUE LE TRAÍA. EL HOMBRE EN ESE PUNTO LE INFORMÓ QUE OLODUMARE DESEABA QUE ÉL FUERA
ENSEGUIDA AL CIELO. RÁPIDAMENTE, SE VISTIÓ Y PARTIÓ HACIA EL CIELO CON EL HOMBRE. TAN
PRONTO COMO ESTUVIERON FUERA DEL PUEBLO, EL CABALLERO LO ABRAZÓ Y CASI INSTANTÁNEAMENTE SE
HALLARON AMBOS EN EL PALACIO DE OLODUMARE. AL LLEGAR, LA VOZ DE OLODUMARE PREGUNTÓ POR
OMONIGHOROGBO (EL NOMBRE CELESTIAL DE EJIOGBE ANTES DE QUE PARTIERA HACIA EL MUNDO) PARA
QUE DIERA UNA EXPLICACIÓN POR HABER CREADO TANTA CONFUSIÓN EN EL MUNDO HASTA EL PUNTO DE
MOLESTAR A LAS OTRAS DIVINIDADES EN LA TIERRA. OMONIGHOROGBO SE PUSO DE RODILLA PARA
OFRECER UNA EXPLICACIÓN, PERO ANTES DE QUE PUDIERA PRONUNCIAR PALABRA, EL MENSAJERO QUE
HABÍA SIDO ENVIADO A BUSCARLO SE OFRECIÓ PARA DAR LA EXPLICACIÓN POR ÉL. EL CABALLERO
EXPLICÓ QUE EL PADRE TODOPODEROSO EN SÍ NO HUBIERA PODIDO HACER LO QUE OMONIGHOROGBO
ESTABA HACIENDO EN LA TIERRA. ÉL RELATÓ QUE DESDE LAS HORAS DE LA MAÑANA OMONIGHOROGBO NO
HABÍA TENIDO TIEMPO SIQUIERA DE COMER ADECUADAMENTE POR HALLARSE AL BUEN SERVICIO DE LA
HUMANIDAD, SIN RECIBIR COMPENSACIÓN DE TIPO ALGUNO. EL MENSAJERO EXPLICÓ QUE FUE SU
TENTATIVA DE COMPORTARSE EN LA TIERRA AL IGUAL A ELLOS SE COMPORTABAN EN EL CIELO LO QUE
MOLESTÓ A LAS DIVINIDADES AMANTES DEL DINERO EN LA TIERRA. AL ESCUCHAR LOS DETALLES DE LAS
OBSERVACIONES DEL MENSAJERO, OLODUMARE ORDENÓ A EJIOGBE QUE SE PUSIERA DE PIE YA QUE
ESTABA CLARO QUE TODAS LAS ACUSACIONES HECHAS PREVIAMENTE EN SU CONTRA ERAN PRODUCTO DE LA
ENVIDIA Y LOS CELOS. OLODUMARE ENTONCES LE ORDENÓ QUE REGRESARA AL MUNDO Y QUE CONTINUARA
CON SUS BUENAS OBRAS, PERO QUE DESDE ESE MOMENTO EN ADELANTE ÉL DEBÍA COBRAR HONORARIOS
RAZONABLES POR SUS SERVICIOS AUNQUE DEBÍA CONTINUAR AYUDANDO A LOS NECESITADOS. ÉL
ENTONCES RECIBIÓ LA BENDICIÓN DE OLODUMARE Y ABANDONÓ EL PALACIO. ANTES DE REGRESAR AL
MUNDO, DECIDIÓ ENCONTRARSE CON LOS AWOS CELESTIALES QUE HABÍAN HECHO ADIVINACIÓN PARA ÉL
ANTES DE QUE ABANDONARA AL CIELO EN LA PRIMERA OCASIÓN. ÉL FUE A VER A: EDUWE KOKO MEJINIA
WON SARAWON KPELENJE KPELENJE EJO-MEJINJA, WON SARAWON LOROKU LOROKU. QUE SIGNIFICA:
CUANDO DOS HOJAS DE COCO PELEAN ENTRE SÍ, EL VIENTO LAS LLEVA DE UN LUGAR A OTRO. CUANDO
DOS SERPIENTES ESTÁN PELEANDO, ELLAS SE ABRAZAN UNA A LA OTRA. ELLOS LE ACONSEJARON QUE
OFRECIERA OTRO MACHO CABRÍO A ESHUELEGBA. LE DIJERON QUE SE CRUZARÍA CON UNA MUJER DE TEZ
CLARA EN LA TIERRA, CON QUIEN SE CASARÍA. DESPUÉS DE CASARSE CON ELLA, ÉL DEBÍA OFRECERLE
UN MACHO CABRÍO GRANDE UNA VEZ MÁS A ESHUELEGBA, DE MODO QUE LA MUJER NO LO DEJARA. SE LE
ASEGURÓ QUE SU MATRIMONIO CON LA MUJER LE TRAERÍA FUERZA Y PROSPERIDAD, PERO SI PERMITÍA
QUE ELLA LO DEJARA, ÉL VOLVERÍA A VIVIR EN LA PENURIA. ÉL HIZO EL SACRIFICIO A ESHU-ELEGBA
EN EL CIELO Y REGRESÓ A LA TIERRA. TAN PRONTO COMO CERRÓ LOS OJOS, TAL COMO LE DIJO EL
CABALLERO CELESTIAL, SE DESPERTÓ EN LA TIERRA. LOS VISITANTES YA ESTABAN COMENZANDO A
PREGUNTARSE POR QUÉ EJIOGBE DORMÍA TANTO ESA MAÑANA''',
  '10. EL MATRIMONIO DE EJIOGBE.': '''DESPUÉS QUE SE HUBO DESPERTADO, LA PRIMERA PERSONA QUE VIO ESA MANANA FUE UNA MUJER DE TEZ
CLARA LLAMADA EJI-ALO. SE ENAMORÓ DE ELLA ENSEGUIDA QUE LA VIO Y LA MUJER LE DIJO QUE ELLA
VENÍA A OFRECÉRSELE EN MATRIMONIO. DESPUÉS DE CASARSE CON LA MUJER, OLVIDÓ DARLE EL MACHO
CABRÍO GRANDE A ESHUELEGBA COMO SE LE HABÍA DICHO EN EL CIELO QUE HICIERA. EJI-ALO ERA LA
HIJA DE UN JEFE MUY RICO DE IFE. PRONTO QUEDÓ EMBARAZADA Y TUVO UN VARÓN QUE NACIÓ
LISIADO. EL PADRE, QUIEN ERA CAPAZ DE CURAR A OTROS LISIADOS, NO PODÍA CURAR A SU PROPIO
HIJO. DE AHÍ SALIÓ EL DICHO DE QUE: "UN MÉDICO PUEDE CURAR A OTROS PERO NO A SÍ MISMO."
EJI-ALO SE SENTÍA TAN FRUSTRADA POR EL NACIMIENTO DEL LISIADO QUE SE NEGÓ A QUEDARSE CON
EJIOGBE PARA CUIDAR DE ÉL. EVENTUALMENTE SE FUE DE LA CASA DEJANDO AL NIÑO ATRÁS.
SUBSIGUIENTEMENTE, ESHU-ELEGBA, OGÚN Y OBALUFÓN SE REUNIERON CON EJIOGBE PARA PREGUNTARLE
POR QUÉ ERA QUE DESDE HACÍA TIEMPO NO SE LE VEÍA AFUERA. ÉL RESPONDIÓ QUE EJIALO LO HABÍA
ABANDONADO CON UN NIÑO LISIADO PARA QUE FUERA ÉL QUIEN LO CUIDARA. ESHU-ELEGBA ENTONCES SE
OFRECIÓ PARA HABLAR CON UN AWÓ EN EL CIELO. LOS AWOS RESULTARON SER EDUWE KOKO Y EJO
MEJINJA, QUIENES COINCIDENTEMENTE ERAN LOS DOS AWOS QUE HABÍAN HECHO ADIVINACIÓN PARA
EJIOGBE DURANTE SU ÚLTIMO VIAJE ESPIRITUAL AL CIELO. ELLOS LE RECORDARON A EJIOGBE EL
MACHO CABRÍO GRANDE QUE LE HABÍAN DICHO QUE DIERA A ESHU-ELEGBA DESPUÉS DE HABERSE CASADO
EN LA TIERRA PARA QUE SU ESPOSA NO LO DEJARA. LOS DOS AWOS PREPARARON MEDICINA PARA LAVAR
LAS PIERNAS DEL NIÑO E INMEDIATAMENTE LA VIDA LE VOLVIÓ A LAS PIERNAS DE ÉSTE. ESO FUE
DESPUÉS DE DARLE EL MACHO CABRIO A ESHU-ELEGBA. A PESAR DEL SACRIFICIO Y DE LA CURACIÓN
DEL NIÑO, EJI-ALO NO SE RECONCILIÓ CON EJIOGBE PORQUE YA ELLA SE HABÍA CASADO CON OLUWERI.
SIN EMBARGO, UNA PARTE DE LA MEDICINA UTILIZADA PARA CURAR AL HIJO DE EJIOGBE SE PREPARÓ
CON UN ASHÉ CON EL FIN DE QUE ÉL LA USARA PARA ORDENARLE A LA ESPOSA QUE REGRESARA SI ASÍ
LO DESEABA. COMO YA ÉL SABÍA QUE ELLA SE HABÍA CASADO CON OTRO HOMBRE, PREFIRIÓ UTILIZARLA
PARA LLAMAR A EJI-ALO, DE MANERA QUE ELLA SE ENCONTRARA CON ÉL EN UN LUGAR ALEJADO DE LOS
ALREDEDORES DE IFE.ÉL TAMBIÉN UTILIZÓ SU ASHÉ PARA ORDENARLE A OLUWERI, QUIEN HABÍA
SEDUCIDO A SU ESPOSA, QUE SE ENCONTRARA CON ÉL EN EL MISMO LUGAR. TAN PRONTO COMO LA
PAREJA APARECIÓ, ÉL LOS CONJURÓ PARA QUE SE CAYERAN AL PISO Y LOS FUSIONÓ EN UN SOLO
CUERPO PARA QUE SE MOVIERAN HACIA ADELANTE PARA SIEMPRE Y MÁS NUNCA MIRARAN ATRÁS. CON
ESTO, EJI-ALO Y OLUWERI SE CONVIRTIERON EN UN RÍO, EL CUAL ACTUALMENTE SE LLAMA OLUWERI EN
EL ESTADO DE ONDO EN NIGERIA. CUANDO EJIOGBE SALE EN ADIVINACIÓN PARA UNA MUJER QUE ESTÁ
PENSANDO EN DEJAR A SU ESPOSO, A ELLA SE LE DEBERÁ ACONSEJAR QUE NO LO HAGA PUES LAS
CONSECUENCIAS DE SEGURO CONDUCIRÁN A LA MUERTE, ESPECIALMENTE SI LA MUJER ES LA ESPOSA DE
UN SACERDOTE DE IFÁ.''',
  '11. EL SEGUNDO MATRIMONIO DE EJIOGBE.': '''LA PRIMERA ESPOSA DE UN VERDADERO HIJO DE EJIOGBE NO PERMANECERÁ MUCHO TIEMPO A SU LADO A
NO SER QUE ELLA SEA DE TEZ CLARA. LA SIGUIENTE MUJER DE EJIOGBE SE LLAMABA IWERE WERE, Y
ERA UNA BRUJA. NO IMPORTA CUÁNTO TRATEN DE EVITARLO, LOS HIJOS DE EJIOGBE (ESTO ES,
AQUELLOS PARA LOS CUALES EJIOGBE APARECE DURANTE LA INICIACIÓN DE IFÁ O IGBODUN) SE CASAN,
CON MÁS FRECUENCIA, CON MUJERES QUE PERTENECEN AL MUNDO DE LA BRUJERÍA. SI ÉSTE TIENE TRES
ESPOSAS, AL MENOS DOS DE ELLAS SERÁN BRUJAS. EJIOGBE AÚN ERA MUY POBRE CUANDO SE VOLVIÓ A
CASAR Y ÉL Y SU ESPOSA SIEMPRE VIVÍAN POR DEBAJO DEL NIVEL DE POBREZA. SIEMPRE QUE MATABAN
UNA RATA, ORÚNMILA LE DABA LA CABEZA A LA ESPOSA. LO MISMO SUCEDÍA CUANDO COGÍA UN
PESCADO, UNA GALLINA O INCLUSO UN CHIVO. CUANDO PUDIERON DISPONER DE UN CHIVO, ESTABA
CLARO QUE SUS FORTUNAS ESTABAN COMENZANDO A AUMENTAR. EVENTUALMENTE ALCANZARON UNA BUENA
POSICIÓN Y PUDIERON CONSTRUIR SU PROPIA CASA, CRIAR A SUS HIJOS Y ÉL PUDO CASARSE CON
OTRAS ESPOSAS. EN ESTE PUNTO, ÉL DECIDIÓ HACER UNA COMIDA DE AGRADECIMIENTO A SU IFÁ.
ENTONCES COMPRÓ UNA VACA PARA LA COMIDA E INVITÓ A OTROS SACERDOTES QUE ERAN MIEMBROS DE
LA FAMILIA. DURANTE LA FESTIVIDAD, CUANDO LA CARNE ESTABA SIENDO REPARTIDA ENTRE LOS
INVITADOS, LA ESPOSA DE MÁS ANTIGÜEDAD ESPERABA COMO ERA HABITUAL QUE SE LE ENTREGARA LA
CABEZA DE LA VACA. DESPUÉS DE ESPERAR EN VANO QUE ESTO SUCEDIERA, LA MUJER LA TOMÓ Y LA
COLOCÓ CERCA DE ELLA. CASI AL INSTANTE, ALGUNO DE LOS SACERDOTES MÁS VENGATIVOS LA
REGAÑARON SOBRE LA BASE DE QUE LA CABEZA NO ERA LA PARTE MÁS ADECUADA DE UNA VACA PARA QUE
FUERA ENTREGADA A UNA MUJER. ENTONCES LE FUE RETIRADA LA CABEZA DE LA VACA. ELLA ESPERÓ UN
POCO PARA DAR TIEMPO A QUE EL ESPOSO INTERVINIERA Y SOLUCIONARA LA SITUACIÓN. COMO NO HUBO
UNA REACCIÓN POSITIVA POR PARTE DE ÉL, ELLA ABANDONÓ LA COMIDA Y SE FUE A SU HABITACIÓN
TRES DÍAS MÁS TARDE, LA MUJER RECOGIÓ SUS COSAS, ABANDONÓ LA CASA DE EJIOGBE Y SE FUE A
VIVIR CON SU HERMANO, LLAMADO IROKO, QUIEN POCO DESPUÉS LE DIO UN SANTUARIO. DESPUÉS QUE
TERMINARON LAS CEREMONIAS DE ACCIÓN DE GRACIAS, EJIOGBE SALIÓ A BUSCAR A LA MUJER. CUANDO
LA BUSCÓ POR TODAS PARTES Y NO LA HALLÓ, FUE A VER AL HERMANO DE ELLA, EL CUAL LE CONFIRMÓ
QUE LE HABÍA DADO REFUGIO. AL VER A IWERE WERE, EJIOGBE LE PREGUNTÓ POR QUÉ LE HABÍA
ABANDONADO TAN DESCORTÉSMENTE. CON LÁGRIMAS EN LOS OJOS, ELLA LE RECORDÓ QUE CUANDO ELLOS
ERAN POBRES, ÉL FRECUENTEMENTE LE DABA LA CABEZA DE CUALQUIER ANIMAL QUE PODÍAN MATAR PARA
COMER Y QUE NINGÚN SACERDOTE O MIEMBRO DE LA FAMILIA SE HABÍA APARECIDO EN AQUELLA ÉPOCA.
CONTINUÓ PREGUNTÁNDOLE POR QUÉ ERA QUE SÓLO CUANDO ELLOS HABÍAN ALCANZADO UNA POSICIÓN LO
SUFICIENTEMENTE CÓMODA COMO PARA COMER DE UNA VACA, LOS OTROS HABÍAN VENIDO A NEGARLE EL
PRIVILEGIO DE QUEDARSE CON LA CABEZA. ¿ POR QUÉ NINGÚN MIEMBRO DE SU FAMILIA HABÍA VENIDO
A EXIGIR LAS CABEZAS DE LA RATA, EL PESCADO, LA GALLINA ETC.? EN UN ENCANTAMIENTO POÉTICO
EXCLAMÓ: ¿QUÉ HOMBRE PUEDE VANAGLORIARSE DE SER MÁS GRANDE QUE EL ELEFANTE? ¿QUIÉN PUEDE
RECLAMAR QUE ES MÁS GRANDE QUE EL BÚFALO? ¿QUIÉN PUEDE VANAGLORIARSE DE SER MÁS INFLUYENTE
QUE EL REY? ¡NINGÚN PAÑO DE CABEZA PUEDE SER MÁS ANCHO QUE AQUELLOS UTILIZADOS POR LOS
ANCIANOS DE LA NOCHE! ¡NINGÚN TRAJE PUEDE SER TAN LARGO COMO EL QUE USAN LAS BRUJAS!
¡NINGÚN GORRO PUEDE SER MÁS FAMOSO QUE UNA CORONA! ¡EN LARGO O EN ANCHO, LA MANO NO PUEDE
SER MÁS ALTA QUE LA CABEZA! ¡LA RAMA DE LA PALMA FRECUENTEMENTE ES MÁS ALTA QUE LAS HOJAS
QUE ESTÁN EN LA CABEZA DE ÉSTA! ¡DÓNDE QUIERA QUE HAYA MÚSICA, ES EL SONIDO DE LA CAMPANA
EL QUE SE OYE MÁS ALTO QUE TODOS LOS OTROS INSTRUMENTOS! LA PALMA ES MÁS INFLUYENTE QUE
TODOS LOS OTROS ÁRBOLES DEL BOSQUE. TAN PRONTO COMO EJIOGBE ESCUCHÓ ESTE POEMA, ÉL TAMBIÉN
LLORÓ Y LE PIDIÓ A SU ESPOSA QUE LE PERDONARA. LA MUJER ENTONCES SINTIÓ PENA POR ÉL Y
ACCEDIÓ A REGRESAR A LA CASA, CON LA CONDICIÓN DE QUE ÉL LA APACIGUARA CON UNA PIEZA DE
TELA BLANCA, ALGÚN DINERO Y QUE SIRVIERA SU CABEZA CON UN CHIVO. ESTO EXPLICA POR QUÉ
CUALQUIERA QUE NAZCA MEDIANTE EJIOGBE EN IGBODUN TIENE QUE SERVIR LA CABEZA DE SU ESPOSA
MÁS ANTIGUA CON UN CHIVO CUANDO GOCE DE PROSPERIDAD. CUANDO SALE EN ADIVINACIÓN PARA UNA
PERSONA QUE NACIÓ MEDIANTE EJIOGBE, A ÉSTA SE LE PREGUNTARÁ SI YA SIRVIÓ LA CABEZA DE SU
ESPOSA CON UN CHIVO. SE LE DEBERÁ DECIR QUE SU ESPOSA MÁS ANTIGUA, SI ES AMARILLA, ES UNA
BRUJA BENEVOLENTE LA CUAL LO AYUDARÁ A PROSPERAR EN LA VIDA SIEMPRE QUE ÉL PUEDA EVITAR
DESPRECIARLA. SI, POR OTRO LADO, SALE EN LA ADIVINACIÓN PARA UN HOMBRE CUYA ESPOSA MÁS
ANTIGUA HAYA ABANDONADO LA CASA, SE LE DEBERÁ ACONSEJAR QUE VAYA Y LE RUEGUE QUE SE
RECONCILIE CON ÉL SIN DEMORA, NO SEA QUE VUELVA A VIVIR EN LA PENURIA.''',
  '12. COMO EJIOGBE AYUDO A UN LITIGANTE A QUE GANARA EL CASO.': '''TAN PRONTO COMO PROSPERÓ PUDO INVITAR A OTROS AWOS A QUE TRABAJARAN PARA ÉL. CUANDO
BABÁJAGBA LOORUN VINO A ÉL PORQUE TENÍA UN CASO, EJIOGBE INVITÓ A OTRO AWÓ LLAMADO: AJAGBA
AGBAGBA AJAGBA JAGBA, NI IRA, TOON DIFA-FUN BABÁ JAGBAJAGBA LOORUN EL AWÓ LE DIJO AL
LITIGANTE QUE HICIERA SACRIFICIO CON EL FIN DE VERSE LIBRE EN LO REFERENTE A ESE CASO. SE
LE DIJO QUE HICIERA SACRIFICIO DE DOS GALLINAS, HEBRA HILADA A MANO Y BASTANTE JENGIBRE
(UNIEN EN BENI Y ERURU EN YORUBA). ÉL PRODUJO TODOS LOS MATERIALES Y EL AWÓ LE PREPARÓ EL
SACRIFICO. LAS PLUMAS DE LA GALLINAS Y LAS SEMILLAS DE JENGIBRE FUERON COSIDAS CON LA
HEBRA PARA FORMAR UN COLLAR PARA QUE ÉL SE LO PUSIERA EN EL CUELLO Y DESPUÉS LE FUE
QUITADO CON UROKE EN EL LUGAR SAGRADO DE ESHU-ELEGBA. CUANDO EL CASO EVENTUALMENTE FUE
LLEVADO A LA CORTE Y JUZGADO, BABÁ AJAGBA GANÓ. POR LO TANTO, CUANDO EJIOGBE SALE EN
ADIVINACIÓN PARA UNA PERSONA QUE TIENE UN CASO PENDIENTE, SE LE DEBERÁ ACONSEJAR QUE HAGA
EL SACRIFICIO ANTERIORMENTE MENCIONADO EL CUAL, NO OBSTANTE, TIENE QUE HACERLO PARA ÉL UN
AWÓ QUE CONOZCA EL MODO DE REALIZARLO.''',
  '13. COMO EJIOGBE HIZO QUE UNA MUJER INFECUNDA TUVIERA UN HIJO.': '''EBITI OKPALE LIGBE OOWO LE KUURU KU ADIFA-FUN OLOMO AGBUTI. ESTOS FUERON LOS NOMBRES DE
OTROS AWOS INVITADOS POR EJIOGBE, CUANDO ÉSTE HIZO ADIVINACIÓN PARA ELERIMOJU CUANDO ELLA
VINO A VERLO PORQUE NO PODÍA TENER HIJOS. EJIOGBE LE DIJO QUE HICIERA SACRIFICIO SIN
DEMORA ALGUNA. DESPUÉS DE PREPARAR EL SACRIFICIO, EJIOGBE LE DIJO QUE LLEVARA LA OFRENDA A
UN DESAGÜE DE AGUA CORRIENTE (AGBARA EN YORUBA Y OROGHO EN BENI). ELLA HIZO COMO SE LE
INDICÓ. NO OBSTANTE, ESHU-ELEGBA ESTABA MOLESTO PORQUE ÉL NO HABÍA RECIBIDO NINGUNA PARTE
DEL SACRIFICIO, PERO ELERIMOJU, TAMBIÉN CONOCIDA COMO OLOMO AGBUTI, RESPONDIÓ QUE ELLA
PREVIAMENTE HABÍA HECHO MUCHOS SACRIFICIOS A ESHU-ELEGBA Y QUE HABÍA SIDO EN VANO.
ESHUELEGBA ENTONCES INVOCÓ A LA LLUVIA PARA QUE CAYERA, CON EL FIN DE EVITAR QUE EL
DESAGÜE DISFRUTARA DEL SACRIFICIO. LA LLUVIA CAYÓ TAN PESADAMENTE QUE LA CORRIENTE QUE
ATRAVESABA EL DESAGÜE LLEVÓ EL SACRIFICIO HASTA EL RÍO (OLOKUN), LA DIVINIDAD DEL AGUA,
QUIEN A SU VEZ LO LLEVÓ AL CIELO. MIENTRAS TANTO, EN EL CIELO, EL HIO DE OLODUMARE ESTABA
ENFERMO Y SE HABÍA INVITADO A LOS AWOS CELESTIALES PARA QUE LO CURARAN. CUANDO LOS AWOS
ESTABAN REALIZANDO LA ADIVINACIÓN ACERCA DE LA ENFERMEDAD DEL NIÑO, LE PIDIERON A
OLODUMARE QUE FUERA A LA PARTE DE ATRÁS DE SU CASA PARA QUE TRAJERA UN SACRIFICIO QUE
ESTABA VINIENDO DE LA TIERRA, PARA ELLOS UTILIZARLO EN LA CURA DEL NIÑO. CUANDO OLODUMARE
LLEGÓ A LA PARTE DE ATRÁS DE LA CASA, VIO EL SACRIFICIO DE ELERIMOJU. LO COGIÓ Y SE LO
LLEVÓ A LOS AWOS QUIENES LE ADICIONARON IYEROSUN (POLVO DE ADIVINACIÓN) Y POSTERIORMENTE
TOCARON CON ÉL LA CABEZA DEL NIÑO. CASI INMEDIATAMENTE DESPUÉS, EL NIÑO SE PUSO BIEN. TAN
PRONTO COMO EL NIÑO MEJORÓ, OLODUMARE INVITÓ A OLOKUN PARA PREGUNTARLE QUÉ ESTABA BUSCANDO
CON EL SACRIFICIO REALIZADO QUE HABÍA SALVADO A SU HIJO. OLOKUN EXPLICÓ QUE ÉL NO SABÍA DE
DÓNDE AGBARA U OROGHE (DESAGÜE) HABÍA TRAÍDO EL SACRIFICIO. OLOKUN INVITÓ AL DESAGÜE A QUE
EXPLICARA DE DÓNDE HABÍA OBTENIDO EL SACRIFICIO Y ÉSTE DIJO QUE HABÍA SIDO ELERIMOJU QUIEN
LO HABÍA REALIZADO. ENTONCES SE INVITÓ A SU ÁNGEL GUARDIÁN EN EL CIELO Y ELLA EXPLICÓ QUE
ORÚNMILA LE HABÍA ACONSEJADO A SU PROTEGIDA QUE HICIERA EL SACRIFICIO PORQUE HABÍA
PERMANECIDO INFECUNDA DESDE QUE HABÍA LLEGADO A LA TIERRA. EL ÁNGEL GUARDIÁN EXPLICÓ QUE
ELERIMOJU INCLUSO SE LAMENTABA QUE LOS HIJOS DE AQUELLOS QUE HABÍAN VENIDO AL MUNDO JUNTO
CON ELLA YA ERAN TAN GRANDES QUE LA ESTABAN ENAMORANDO. OLODUMARE ENTONCES SACÓ SU MAZA DE
AUTORIDAD Y PROCLAMÓ QUE ELERIMOJU TENDRÍA UN HIJO Y QUE, ANTES QUE MURIERA, SUS HIJOS Y
NIETOS TAMBIÉN TENDRÍAN HIJOS, LOS CUALES ELLA VERÍA CON SUS PROPIOS OJOS. ANTES DE QUE
AMANECIERA YA ELERIMOJU HABÍA TENIDO LA MENSTRUACIÓN. DESPUÉS QUE ÉSTA SE LE QUITÓ, TUVO
RELACIONES CON SU ESPOSO Y QUEDÓ EMBARAZADA. NUEVE MESES MÁS TARDE TUVO UN HIJO, A QUIEN
LLAMÓ ADEYORIJU. TUVO OTROS HIJOS MÁS, TUVO NIETOS Y BISNIETOS ANTES DE QUE REGRESARA AL
CIELO. POR LO TANTO, CUANDO EJIOGBE SALE EN ADIVINACIÓN PARA UNA MUJER QUE ESTÁ ANSIOSA
POR TENER UN HIJO, A ELLA SE LE DEBERÁ ACONSEJAR QUE HAGA EL SACRIFICIO ANTERIOR E
INVARIABLEMENTE TENDRA HIJOS ABUNDANTES.''',
  '14. COMO EJIOGBE AYUDÓ A LA MONTAÑA A RESISTIR EL ATAQUE DE SUS ENEMIGOS.': '''ENEMIGOS. AJA KULO MO, AJAA KUULU MO. ADIFAFUN OKE, OTA LE LU RUN OKOO. EBO OKE SHOOTA,
OTA LEGBEJE ADAA. EBO OKE SHOOTA. A OKE, O MONTANA, SE LE ACONSEJÓ QUE HICIERA SACRIFICIO
Y ÉL LO HIZO A CAUSA DE LOS PLANES MALVADOS DE SUS ENEMIGOS. EL MACHETE Y LA AZADA ESTABAN
TRATANDO DE DESTRUIRLO. DESPUÉS QUE LA MONTAÑA HUBO HECHO EL SACRIFICIO, LA AZADA Y EL
MACHETE SALIERON PARA DESTRUIRLO, PERO NO PUDIERON NI SIQUIERA ARAÑARLE EL CUERPO. LA
MONTAÑA INCLUSA CRECIÓ MÁS. ÉL SE REGOCIJÓ Y LE DIO LAS GRACIAS A SU ADIVINADOR.''',
  '15. EJIOGBE SALVA A SU HIJO DE LAS MANOS DE LA MUERTE.': '''ONO GBOORO MITI FEWA ESTE FUE EL SACERDOTE DE IFÁ QUE HIZO ADIVINACIÓN PARA ABATI, EL HIJO
DE EJIOGBE, CUANDO LA MUERTE HABÍA PLANIFICADO LLEVÁRSELO EN UN PLAZO DE SIETE DÍAS. A
ABATI SE LE DIJO QUE HICIERA SACRIFICIO CON UN GALLO, UNA GALLINA Y CARACOLES Y QUE LE
DIERA UN MACHO CABRÍO A ESHU-ELEGBA. LA MUERTE TRATÓ EN VANO TRES VECES DE LLEVARSE A
ABATI DE LA TIERRA, DESPUÉS DE LO CUAL LO DEJÓ PARA QUE COMPLETARA SU ESTANCIA SOBRE ÉSTA.
ENTONCES ABATI CANTÓ EL POEMA SIGUIENTE: UKU GBEMI, OTIMI; TIRI ABATI, ABATI TIRI; ARUN
GBEMI, OTIMI; TIRI ABATI, ABATI TIRI. TRADUCCIÓN LA MUERTE ME AGARRÓ Y ME SOLTÓ. LA
ENFERMEDAD ME TUVO Y ME DEJÓ. NADIE SE COME LA TORTUGA JUNTO CON EL CARAPACHO. NADIE SE
COME UN CARNERO JUNTO CON SU CUERPO. LA CONCHA DEL CARACOL SE GUARDA DESPUÉS DE COMERSE SU
CARNE. YO HE SOBREVIVIDO LOS MALVADOS PLANES DE MIS ENEMIGOS.''',
  '16. COMO LA MADRE DE EJIOGBE LO SALVÓ DE SUS ENEMIGOS.': '''EFIFI NII SHOJA OMO TEEREE TE OKPA TEERE BE EJO LEYIN OSHUDI EEREKO OSHUDI EREEKE. ESTOS
SON LOS NOMBRES DE LOS AWOS QUE HICIERON ADIVINACIÓN PARA OLAYORI, LA MADRE DE EJIOGBE,
CUANDO LA GENTE ESTABA HACIENDO COMENTARIOS SARCÁSTICOS ACERCA DE LOS BUENOS TRABAJOS QUE
ÉL REALIZABA. ELLA HIZO SACRIFICIO CON 4 PALOMAS Y 4 BOLSAS DE SAL. DESPUÉS DEL
SACRIFICIO, LA MISMA GENTE QUE ESTABA DESPRECIANDO SUS OBRAS COMENZARON A HACER
COMENTARIOS FAVORABLES A EJIOGBE. ESTO ES ASÍ PORQUE NADIE SE PONE SAL EN LA BOCA PARA
DESPUÉS HACER MALOS COMENTARIOS ACERCA DE SU SABOR. TAN PRONTO COMO LA GALLINA SE SIENTE A
DESCANSAR SOBRE SUS HUEVOS, SU VOZ CAMBIARÁ.''',
  '17. COMO EJIOGBE SE CONVIRTIÓ EN EL REY DE LOS OLODUS (APÓSTOLES).': '''(APÓSTOLES). DESPUÉS QUE LOS DIECISÉIS OLODUS HUBIERON LLEGADO AL MUNDO, LLEGÓ EL MOMENTO
DE DESIGNAR UN JEFE ENTRE ELLOS. EJIOGBE NO HABÍA SIDO EL PRIMER OLODU EN VENIR AL MUNDO.
MUCHOS OTROS LOS HABÍAN HECHO ANTES QUE ÉL. ANTE ELLOS OYEKU MEJI, QUIEN ERA EL REY DE LA
NOCHE, HABÍA ESTADO RECLAMANDO ANTIGÜEDAD. TODOS SE VOLVIERON HACIA ORISHANLÁ (DIOS EL
HIJO O EL REPRESENTANTE EN LA TIERRA) PARA QUE DESIGNARA AL REY DE LOS OLODÚS. ORISHANLÁ
LOS INVITÓ A TODOS Y LES DIO UNA RATA PARA QUE LA COMPARTIERAN. OYEKU MEJI TOMÓ UNA PATA,
IWORI MEJI TOMÓ LA OTRA PATA, ODI MEJI TOMÓ UNA MANO Y OBARA MEJI TOMÓ LA MANO RESTANTE.
LAS OTRAS PARTES FUERON COMPARTIDAS DE ACUERDO AL ORDEN DE ANTIGÜEDADD CONVENCIONAL. A
EJIOGBE, POR SER MUY JOVEN, SE LE DIO LA CABEZA DE LA RATA. EN ORDEN DE SECUENCIA,
ORISHANLÁ LE ENTREGÓ UN PESCADO, UNA GALLINA, UNA GUINEA Y FINALMENTE UN CHIVO LOS QUE
FUERON COMPARTIDOS DE ACUERDO AL ORDEN ESTABLECIDOS CON LA RATA. EN CADA CASO, EJIOGBE
RECIBIÓ LA CABEZA DE CADA UNO DE LOS ANIMALES SACRIFICADOS. FINALMENTE, ORISHANLÁ LOS
INVITÓ A QUE VOLVIERAN A VERLO EN BUSCA DE LA DECISIÓN DESPUÉS DE TRANSCURRIDOS TRES DÍAS.
CUANDO EJIOGBE LLEGÓ A SU CASA HIZO ADIVINACIÓN Y SE LE DIJO QUE DIERA UN MACHO CABRÍO A
ESHU-ELEGBA. DESPUÉS QUE ESHUELEGBA SE COMIÓ SU MACHO CABRÍO, LE DIJO A EJIOGBE QUE EN EL
DÍA SEÑALADO, ÉL DEBÍA ASAR UN TUBÉRCULO DE ÑAME PARA GUARDARLO EN SU BOLSO JUNTO CON UN
GÜIRO DE AGUA. ESHUELEGBA TAMBIÉN LE ACONSEJÓ QUE LLEGARA TARDE A LA REUNIÓN DE LOS OLODUS
EN EL PALACIO DE ORISHANLÁ. EN EL DÍA SEÑALADO, LOS OLODUS VINIERON A INVITARLO A LA
CONFERENCIA, PERO ÉL LES DIJO QUE ESTABA ASANDO ÑAME EN EL FUEGO PARA COMÉRSELO ANTES DE
IR PARA LA REUNIÓN. DESPUÉS QUE ELLOS SE MARCHARON, ÉL SACÓ EL ÑAME, LO PELÓ Y LO GUARDÓ
DENTRO DE SU BOLSO DIVINO JUNTO CON UN GÜIRO DE AGUA. EN SU CAMINO HACIA LA CONFERENCIA,
SE ENCONTRÓ CON UNA ANCIANA TAL Y COMO ESHU-ELEGBA LE HABÍA DICHO Y, DE ACUERDO CON EL
CONSEJO QUE ÉSTE LE DIERA, LE CARGÓ A LA MUJER EL MONTÓN DE LEÑA QUE ELLA LLEVABA PUES
ESTABA TAN CANSADA QUE APENAS PODÍA CAMINAR. LA MUJER, AGRADECIDA, ACEPTÓ LA AYUDA Y SE
QUEJÓ DE QUE ESTABA TERRIBLEMENTE HAMBRIENTA. AL INSTANTE, EJIOGBE SACÓ EL ÑAME QUE SE
HALLABA DENTRO DE SU BOLSO Y LE DIO DE COMER. DESPUÉS DE COMERSE EL ÑAME ELLA LE PIDIÓ
AGUA Y ÉL LE DIO EL GÜIRO DE AGUA QUE IGUALMENTE TRAÍA. PASADO ESTE MOMENTO, CARGÓ LA LEÑA
MIENTRAS QUE LA ANCIANA CAMINABA A SU LADO. EL NO SABÍA QUE LA MUJER ERA LA MADRE DE
ORISHANLÁ. ENTRE TANTO, AL VER LA MUJER QUE ÉL ESTABA APREMIADO POR EL TIEMPO, LE PREGUNTÓ
QUE A DÓNDE IBA TAN APURADO. LE RESPONDIÓ QUE YA A ÉL SE LE HABÍA HECHO TARDE PARA LLEGAR
A LA CONFERENCIA EN LA CUAL ORISHANLÁ IBA A DESIGNAR UN REY ENTRE LOS OLODUS. LE EXPRESÓ
QUE DE TODOS MODOS SE IBA A TOMAR SU TIEMPO, YA QUE ÉL ERA TODAVÍA MUY JOVEN PARA ASPIRAR
AL REINADO DE LOS DIECISÉIS OLODUS O APÓSTOLES DE ORÚNMILA. LA MUJER REACCIONÓ Y LE
ASEGURÓ QUE ÉL IBA A SER NOMBRADO REY DE LOS APÓSTOLES. AL LLEGAR A LA CASA DE LA ANCIANA,
ELLA LE DIJO QUE DEPOSITARA LA MADERA EN LA PUERTA DE ATRÁS DE LA MISMA. AL IDENTIFICAR LA
CASA DE ORISHANLÁ, FUE QUE ÉL COMPRENDIÓ QUE LA MUJER QUE ÉL HABÍA ESTADO AYUDANDO NO ERA
OTRA SINO LA MADRE DE ORISHANLÁ. ENTONCES SUSPIRÓ CON ALIVIO. ELLA LE DIJO QUE LA
ACOMPAÑARA AL INTERIOR DE LA VIVIENDA. YA ADENTRO, ELLA SACÓ DOS PIEZAS DE TELA BLANCA, LE
ATÓ UNA EN EL HOMBRO DERECHO Y LA OTRA EN EL HOMBRO IZQUIERDO. ENTONCES COLOCÓ UNA PLUMA
ROJA DE COTORRA EN LA CABEZA DE EJIOGBE Y LE PUSO YESO BLANCO EN LA PALMA DE SU MANO
DERECHA. ENTONCES LE MOSTRÓ LAS 1,460 (OTA LEGBEJE) PIEDRAS QUE SE HALLABAN AFUERA EN EL
FRENTE DE LA CASA DE ORISHANLÁ Y LE ORIENTÓ A EJIOGBE QUE FUERA Y SE PARARA ENCIMA DE LA
PIEDRA BLANCA QUE ESTABA EN EL MEDIO. CON SUS NUEVOS VESTIDOS, ÉL FUE Y SE PARÓ ALLÍ
MIENTRAS LOS OTROS ESPERABAN EN LA CÁMARA EXTERIOR DE ORISHANLÁ. PASADO ALGÚN TIEMPO,
ORISHANLÁ LES PREGUNTÓ A LOS OTROS QUE POR QUIEN ESTABAN ESPERANDO AÚN Y ELLOS
RESPONDIERON QUE ESPERABAN POR EJIOGBE. ORISHANLÁ ENTONCES LES SOLICITÓ QUE LE INFORMARAN
EL NOMBRE DEL HOMBRE QUE SE HALLABA PARADO EN LA PARTE DE AFUERA. ELLOS NO PUDIERON
RECONOCERLO COMO A EJIOGBE. ORISHANLÁ LES DIO INSTRUCCIONES PARA QUE FUERAN Y MOSTRARAN
SUS RESPETOS AL HOMBRE. UNO TRAS OTRO FUERON A POSTRARSE Y TOCARON EL SUELO CON SU CABEZA
AL PIE DE DONDE EJIOGBE SE HALLABA PARADO. DESPUÉS DE ESTO, ORISHANLÁ PROCLAMÓ FORMALMENTE
A EJIOGBE COMO REY DE LOS OLODUS DE LA CASA DE ORÚNMILA. CASI UNÁNIMEMENTE TODOS LOS OTROS
OLODUS MURMURARON MOLESTOS Y NO DISIMULARON SU DESAPROBACIÓN ANTE EL NOMBRAMIENTO DE UN
OLODU JOVEN COMO JEFE ENTRE ELLOS. EN ESE PUNTO, ORISHANLÁ LES PREGUNTÓ DE QUÉ FORMA
HABÍAN COMPARTIDO LOS ANIMALES QUE ÉL LES HABÍA ESTADO DANDO DURANTE EL PERÍODO DE PRUEBA
DE SIETE DÍAS DE DURACIÓN. ELLOS LE EXPLICARON LA FORMA EN LA CUAL LO HABÍAN HECHO. ÉL LES
PREGUNTÓ QUE QUIÉN HABÍA ESTADO RECIBIENDO LAS CABEZAS DE CADA UNO DE ESTOS ANIMALES Y
ELLOS CONFIRMARON QUE EN CADA CASO LE HABÍAN ESTADO DANDO LAS CABEZAS A EJIOGBE. ORISHANLÁ
ENTONCES EXCLAMÓ QUE ELLOS HABÍAN SIDO LOS QUE, INCONSCIENTEMENTE, HABÍAN DESIGNADO A
EJIOGBE COMO SU REY, YA QUE CUANDO LA CABEZA ESTÁ SEPARADA DEL CUERPO, EL RESTO YA NO
TIENE VIDA. CON ESTO, ELLOS SE DISPERSARON. CUANDO LOS OLODUS ABANDONARON LA CASA DE
ORISHANLÁ, DECIDIERON MANTENER A EJIOGBE A DISTANCIA. NO SÓLO SE PUSIERON DE ACUERDO PARA
NO RECONOCERLO, SINO QUE TAMBIÉN DECIDIERON QUE NO IBAN A SERVIRLO. ANTES QUE SE
DISPERSARAN EJIOGBE COMPUSO UN POEMA EL CUAL UTILIZÓ COMO UN ENCANTAMIENTO. OJA NII KI OWO
WON JAA OWUWU ONI KOO WO WON WUU. IKPE AKIKO KIIGA AKIKA DEENU IKPE ORIRE KII GUN ORIRE
DEENU ETUU KII OLO WON NI MO INU LO OTIN IRE EFO EBERI WAA CON ESTE ENCANTAMIENTO
ESPECIAL, ÉL ESPERABA NEUTRALIZAR TODAS LAS MAQUINACIONES PERVERSAS EN SU CONTRA. A ESTE
FIN UTILIZÓ HOJAS ESPECIALES. DESPUÉS DE ESE INCIDENTE, ELLOS LE MANIFESTARON QUE ANTES DE
QUE PUDIERAN ACEPTARLO COMO REY, ÉL TENÍA QUE COMER CON TODOS ELLOS CON: 200 GÜIROS DE
ÑAMES MACHACADOS 200 OLLAS DE SOPA PREPARADA CON DIFERENTES CARNES 200 GÜIROS DE VINO 200
CESTAS DE NUECES DE KOLÁ ETC., ETC. DÁNDOLE SIETE DÍAS PARA QUE PREPARARA LA COMIDA. NO
ERA NECESARIO DECIR QUE PARECÍA QUE LA TAREA ERA IMPOSIBLE DE CUMPLIR DEBIDO A QUE ELLOS
SABÍAN QUE EJIOGBE NO PODÍA COSTEAR UNA COMIDA DE ESA MAGNITUD. EJIOGBE SE SENTÓ Y SE
LAMENTÓ DE SU POBREZA Y DEL PROSPECTO DE PERMANECER COMO UN PASTOR SIN REBAÑO. ENTRE TANTO
ESHU-ELEGBA SE LE ACERCÓ PARA CONOCER LA CAUSA DE SU MELANCOLÍA Y EJIOGBE LE EXPLICÓ QUE
NO CONTABA CON LOS FONDOS PARA COSTEAR LA COMIDA TAN DETALLADA EXIGIDA POR LOS OLODUS
ANTES DE QUE PUDIERAN ACEPTAR SUBORDINARSE A ÉL. ESHU-ELEGBA RESPONDIÓ QUE EL PROBLEMA
PODÍA SER SOLUCIONADO SI EJIOGBE PUDIERA DARLE OTRO MACHO CABRÍO. EJIOGBE NO PERDIÓ TIEMPO
EN DARLE OTRO MACHO CABRÍO, ESHUELEGBA LE ACONSEJÓ QUE PREPARARA SÓLO UNA DE CADA UNA DE
LAS COSAS REQUERIDAS PARA LA COMIDA Y QUE OBTUVIERA 199 RECIPIENTES ADICIONALES PARA CADA
COSA Y QUE LOS ALINEARA EN EL RECINTO DONDE SE IBA A CELEBRAR LA COMIDA EN EL DÍA
SEÑALADO. EJIOGBE SIGUIÓ EL CONSEJO DE ESHU-ELEGBA. MIENTRAS TANTO, LOS OLODUS SE HABÍAN
ESTADO BURLANDO DE ÉL PUES SABÍAN QUE NO HABÍA MODO EN EL CUAL EJIOGBE PUDIERA COSTEAR LA
COMIDA. AL LLEGAR AL SÉPTIMO DÍA, UNO A UNO VINIERON A VISITARLO PREGUNTANDO SI ESTABA
LISTO PARA LA COMIDA. COMO PROCEDENTE DE LA COCINA NO ESCUCHABAN EL SONIDO DE LA MANO DEL
MORTERO, SUPIERON QUE DESPUÉS DE TODO NO HABRÍA COMIDA. ENTRE TANTO, DESPUÉS DE HABER
ALINEADO LOS RECIPIENTES VACÍOS, ESHU-ELEGBA FUE AL RECINTO DONDE SE IBA A CELEBRAR LA
COMIDA Y LE ORDENÓ AL PREPARADO ÚNICO QUE SE MULTIPLICARA. AL INSTANTE, TODOS LOS GÜIROS,
OLLAS, CESTAS, ETC., SE LLENARON CON PREPARADOS FRESCOS Y LA COMIDA ESTABA LISTA. TAN
PRONTO COMO OYEKU MEJI LLEGÓ AL RECINTO DONDE SE IBA A CELEBRAR LA COMIDA Y DESCUBRIÓ LO
QUE ESTABA SUCEDIENDO, SE SORPRENDIÓ DE VER QUE LA COMIDA ESTABA LISTA FINALMENTE. SIN
ESPERAR A QUE SE PRODUJERA UNA INVITACIÓN FORMAL, SE SENTÓ Y SE SIRVIÓ DE LA COMIDA. LO
SIGUIERON IWORI- MEJI, ODI-MEJI, IROSOMEJI, OJUANI-MEJI, OBARA-MEJI, OKANA-MEJI, OGUNDA-
MEJI, OSA-MEJI, IKA-MEJI, OTRUPON-MEJI, OTURA-MEJI, IRETE-MEJI OSHE-MEJI, OFUNMEJI. ANTES
DE QUE SE DIERAN CUENTA DE LO QUE ESTABA SUCEDIENDO, YA TODOS HABÍAN COMIDO Y BEBIDO HASTA
SACIARSE. DESPUÉS DE LA COMIDA, TODOS CARGARON A EJIOGBE POR ENCIMA DE SUS CABEZAS Y
COMENZARON A BAILAR EN UNA PROCESIÓN, CANTANDO: AGBEE GEEGE. AGBEE BABAA. AGBEE GEEGE.
AGBEE BABAA. BAILARON EN LA PROCESIÓN ATRAVESANDO EL PUEBLO. CUANDO LLEGARON A LA ORILLA
DEL MAR, EJIOGBE LES DIJO QUE LO BAJARAN Y CANTÓ EN ALABANZA DE LOS AWOS QUE HICIERON
ADIVINACIÓN PARA ÉL Y DEL SACRIFICIO QUE ÉL HIZO. CON ESTO, FUE FORMALMENTE CORONADO JEFE
DE LOS APÓSTOLES DE ORÚNMILA, CON EL TITULO DE AKOKO-OLOKUN. EN ESTE PUNTO, SACRIFICÓ
CUATRO CARACOLES OBTENIDOS DE LA ORILLA DEL MAR Y ESTE FUE EL ÚLTIMO SACRIFICIO QUE HIZO
ANTES DE HACERSE PRÓSPERO Y EL REINADO COMENZÓ A FLORECER.''',
  '18. LUCHA ENTRE EJIOGBE Y OLOFEN.': '''EN SU POSICIÓN DE REY DE LOS OLODUS, EJIOGBE SE HIZO MUY FAMOSO Y RICO. PREOCUPADO POR LA
PRESENCIA DE UN REY PODEROSO EN SU DOMINIO, OLOFEN, EL GOBERNANTE TRADICIONAL DE IFÉ,
ORGANIZÓ UN EJÉRCITO PARA LUCHAR CONTRA EJIOGBE. MIENTRAS TANTO, EJIOGBE TUVO UN SUEÑO EN
EL CUAL VEÍA UN ATAQUE INMINENTE SOBRE ÉL. ENTONCES INVITÓ A UN AWÓ, LLAMADO OOLE JAGIDA,
OLUPE PEROJA (UN ARREGLO FÁCIL TERMINA EN HOSTILIDAD), PARA QUE HICIERA ADIVINACIÓN PARA
ÉL. SE LE DIJO QUE BUSCARA UN PUERCOESPÍN (OKHAEN EN BENI URERE EN YORUBA) QUE DEBÍA SER
UTILIZADO PARA PREPARAR UNA COMIDA, AUNQUE SE LE COMUNICÓ QUE NO COMIERA ÉL. EL RESTO DE
LOS PRESENTES SÍ COMIERON DEL PUERCOESPÍN. DESPUÉS DE ESTO, LA CONSPIRACIÓN EN SU CONTRA
SE DESHIZO. NO MUCHO TIEMPO DESPUÉS, CUANDO OLOFEN VIO QUE EJIOGBE AÚN ANDABA POR LOS
ALREDEDORES Y QUE ERA CADA VEZ MÁS POPULAR QUE ÉL, ORGANIZÓ OTRO GRUPO DE ANCIANOS DE LA
NOCHE PARA PELEAR EN SU CONTRA. EJIOGBE FUE NUEVAMENTE AL MISMO AWÓ, QUIEN LE ACONSEJÓ QUE
BUSCARA UN ERIZO (AKIKA EN YORUBA Y EKHUI EN BENI) PARA OTRO SACRIFICIO. EL SACERDOTE DE
IFÁ LE AGREGÓ LAS HOJAS PERTINENTES Y LO UTILIZÓ PARA PREPARAR OTRA COMIDA, ADVIRTIÉNDOLE
UNA VEZ MÁS A EJIOGBE QUE NO COMIERA DE ÉL. DESPUÉS DE LA COMIDA, LOS DESIGNADOS POR EL
OLOFEN PARA LUCHAR DIABÓLICAMENTE CONTRA ÉL, SE SINTIERON MUY ABOCHORNADOS PARA DARLE LA
CARA A EJIOGBE. DESPUÉS DE CADA UNA DE LAS COMIDAS PREPARADAS, EL AWÓ HABÍA RECOLECTADO
LAS CABEZAS, LAS PIELES Y LOS HUESOS DE LOS DOS ANIMALES. CUANDO OLOFEN DESCUBRIÓ QUE
EJIOGBE AÚN ESTABA EN EL PUEBLO Y QUE SEGUÍA TAN POPULAR COMO SIEMPRE, EXHORTÓ A LA GENTE
A QUE LO EXPULSARAN ABIERTAMENTE DE ALLÍ. UNA VEZ MÁS, EJIOGBE INVITÓ AL SACERDOTE, QUIEN
LE ACONSEJÓ QUE OBTUVIERA UN MACHO CABRÍO Y UN ANTÍLOPE COMPLETO PARA UN SACRIFICIO
ESPECIAL A ESHU-ELEGBA. EJIOGBE OBTUVO LOS DOS ANIMALES, LOS CUALES FUERON UTILIZADOS PARA
HACER SACRIFICIO A ESHU-ELEGBA. EL AWÓ UTILIZÓ LA CARNE PARA PREPARAR OTRA COMIDA, DE LA
CUAL SE LE DIJO A EJIOGBE QUE NO COMIERA. LA GENTE, INCLUSO DESPUÉS DE HABER DISFRUTADO DE
LA COMIDA, INSISTIÓ EN QUE TENDRÍAN QUE EXPULSAR A EJIOGBE DE IFE. POR MUCHO QUE TRATARON,
ESTO NO SE MATERIALIZÓ. EN ESTE PUNTO, OLOFEN DECIDIÓ UTILIZAR UNA ESTRATEGIA
COMPLETAMENTE NUEVA. INVITÓ A EJIOGBE PARA QUE, PASADOS TRES DÍAS, ASISTIERA A UNA REUNIÓN
EN SU PROPIO PALACIO. EN EL DÍA SEÑALADO, OLOFEN LE PIDIÓ A SUS VERDUGOS REALES O ASESINOS
QUE PREPARARAN UNA EMBOSCADA PARA EJOGBE Y LO ASESINARAN CUANDO FUERA O REGRESARA DEL
PALACIO. ANTES DE SALIR DE SU CASA HACIA EL PALACIO DE OLOFEN, EJIOGBE FUE AL LUGAR
SAGRADO DE ESHU-ELEGBA CON NUEZ DE KOLÁ, UNA CUCHARADA DE ACEITE DE PALMA Y UN CARACOL
PARA INVOCAR A ESHUELEGBA CON UN ENCANTAMIENTO, DE MANERA QUE LO ACOMPANARA HACIA Y DESDE
LA REUNIÓN, PUES NO SABÍA QUÉ CONSPIRACIÓN LO AGUARDABA EN ESTA OCASIÓN. ANTES DE PARTIR,
HIZO SU PROPIO ODU EN EL SUELO Y REPITIÓ OTRO ENCANTAMIENTO. ATRAVESÓ TODAS LAS EMBOSCADAS
SIN QUE SE PRODUJERA INCIDENTE ALGUNO Y LLEGÓ SIN PROBLEMA AL INTERIOR DEL PALACIO. OLOFEN
SE SORPRENDIÓ AL VERLO Y COMO NO HABÍA NADA TANGIBLE QUE DISCUTIR, LA REUNIÓN TERMINÓ TAL
Y COMO HABÍA EMPEZADO. OLOFEN ESTABA SEGURO DE QUE LA EMBOSCADA LO GOLPEARÍA CUANDO
EJIOGBE SE HALLARA DE REGRESO A SU CASA. ESTANDO LOS ASESINOS ESPERANDO PARA ASESTAR EL
GOLPE FATAL SOBRE ÉL, LLEGÓ EL MOMENTO PARA QUE ESHU-ELEGB INTERVINIERA. TAN PRONTO COMO
EJIOGBE SE ACERCÓ AL LUGAR DE LA EMBOSCADA, ESHUELEGBA LLAMÓ AL ANTÍLOPE CON EL CUAL SE
HABÍA HECHO SACRIFICIO ANTERIORMENTE PARA QUE SE VOLVIERA ENTERO NUEVAMENTE Y ÉSTE SALTÓ
EN MEDIO DE LOS ASESINOS QUE ESPERABAN LA EMBOSCADA. CASI INMEDIATAMENTE, TODOS
ABANDONARON SU VIGILIA Y PERSIGUIERON AL ANTILOPE HASTA QUE LLEGARON AL PALACIO DE OLOFEN.
CUANDO EL ANTÍLOPE PENETRÓ EN EL PALACIO DE OLOFEN SE PRODUJO UNA CONFUSIÓN GENERAL Y HUBO
UNA LUCHA COMUNAL EN EL PUEBLO DE IFE. EN MEDIO DE LA CONMOCIÓN, EJIOGBE CALLADAMENTE
CAMINÓ EN PAZ HACIA SU CASA, SIN QUE FUERA MOLESTADO EN MODO ALGUNO. POR SU PARTE, OLOFEN
ACUSÓ A LOS ASESINOS QUE ENVIARA A ASECHAR A EJIOGBE DE NO CUMPLIR SUS INSTRUCCIONES, POR
LO QUE TODOS FUERON ENCERRADOS. FUE EJIOGBE QUIEN POSTERIORMENTE FUE AL PALACIO A
APACIGUAR LA CONFUSIÓN QUE HABÍA SIDO CREADA POR EL MISTERIOSO ANTÍLOPE. ÉL UTILIZÓ SU
BANDEJA DE ADIVINACIÓN Y OTRO ENCANTAMIENTO PARA DEVOLVER LA PAZ Y LA TRANQUILIDAD UNA VEZ
MÁS A IFE. DESPUÉS DE ESTO, EJIOGBE INVITÓ A TODOS LOS SACERDOTES DE IFÁ, JEFES Y MAYORES
DEL PUEBLO PARA QUE ASISTIERAN A UNA COMIDA PREPARADA CON UNA VACA, CHIVOS Y GALLINAS EN
AGRADECIMIENTO A ORÚNMILA, LA DIVINIDAD DE LA SABIDURÍA. DESPUÉS DE LA COMIDA ÉL DECIDIÓ
NUNCA MÁS HERMANARSE CON OLOFEN. ENTONCES CANTÓ EN ALABANZA DEL AWÓ QUE LO ACOMPAÑÓ
DURANTE EL TIEMPO EN QUE OLOFEN LO MOLESTÓ Y DE ESHU-ELEGBA QUIEN UTILIZÓ AL ANTÍLOPE CON
EL CUAL ÉL HIZO SACRIFICIO Y DISPERSÓ A SUS ENEMIGOS. ES POR ESTA RAZÓN QUE TODOS LOS
HIJOS DE EJIOGBE EN IGBODUN TIENEN PROHIBIDO EL PUERCOESPÍN, EL ERIZO Y EL ANTÍLOPE HASTA
ESTE DÍA DEBIDO A QUE ESTOS FUERON LOS ANIMALES QUE ÉL UTILIZÓ PARA APLASTAR LOS PLANES
MALVADOS DE OLOFEN EN SU CONTRA. ESTO TAMBIÉN EXPLICA POR QUÉ LOS HIJOS DE EJIOGBE NO SE
LLEVAN MUY BIEN CON CUALQUIER OBÁ O REY EN SUS DOMINIOS.''',
  '19. EJIOGBE LUCHA CON LA MUERTE.': '''AHORA ESTÁ CLARO QUE EJIOGBE SUFRIÓ A MANOS DE TODOS LOS ENEMIGOS IMAGINABLES DEBIDO A QUE
SE DEDICÓ A DEFENDER EL BIEN OBJETIVO. ÉL TUVO PROBLEMAS CON LOS LAICOS AL IGUAL QUE CON
LOS SACERDOTES, CON SUS FAMILIARES, CON SUS DIVINIDADES HERMANAS Y CON EL REY. LE LLEGÓ EL
TURNO A LA MUERTE DE ENFRENTARLO EN UN COMBATE. EL NOMBRE DEL AWÓ QUE HIZO ADIVINACIÓN
PARA ÉL EN ESTA OCASIÓN ERA IKU KII NILLE OLODUMARE. ARON KIIJA NILLE OLODUMARE. (LA
MUERTE Y LA ENFERMEDAD NO HACEN LA GUERRA EN LA CASA DE DIOS). A EJIOGBE SE LE DIJO QUE
MORIRÍA ANTES DE QUE TERMINARA EL AÑO A NO SER QUE HICIERA SACRIFICIO CON 200 CAMPANAS Y
UN MACHO CABRÍO A ESHU-ELEGBA. LA CAMPANA SIEMPRE SONARÁ PORQUE ELLA NO MUERE. LA CAMPANA
FUE PREPARADA POR DOS AWOS PARA QUE ÉL LA SONARA CADA MAÑANA. CON ESTO ÉL PUDO SOBREVIVIR
HASTA EL FINAL DE ESE AÑO Y MÁS AÚN. ESTE ES EL TIPO DE SACRIFICIO QUE SE HACE CUANDO
EJIOGBE APARECE EN LA ADIVINACIÓN Y PREDICE LA MUERTE DEL SOLICITANTE. CUANDO LA MUERTE
VIO QUE EJIOGBE LO HABÍA SOBREVIVIDO ESE AÑO, IDEÓ OTRO PLAN PARA ACABAR CON ÉL EN UN
PLAZO DE SIETE DÍAS. TAN PRONTO COMO LA MUERTE REAFIRMÓ SU MALVADA ESTRATEGIA, EJIOGBE
TUVO UN SUEÑO ESA NOCHE Y EN EL VEÍA A LA MUERTE REVOLOTEANDO A SU ALREDEDOR. RÁPIDAMENTE
INVITÓ A UNO DE SUS SUSTITUTOS PARA QUE HICIERAN ADIVINACIÓN PARA ÉL. EL AWÓ, LLAMADO UNA
OKE RORORA MOOTA, LE DIJO QUE LA MUERTE LO HABÍA MARCADO PARA SER SACRIFICADO EN UN PLAZO
DE SIETE DÍAS. SE LE ACONSEJÓ QUE HICIERA SACRIFICIO CON UN MACHO CABRÍO, UN GALLO Y 20
NUECES DE KOLÁ. EL MACHO CABRÍO Y EL GALLO SE LO DIERA A ESHU-ELEGBA Y DEBÍA ROMPERLE A
IFÁ UNA DE LAS 20 NUECES DE KOLÁ DURANTE UN PERÍODO DE 20 DÍAS. DEBÍA APRETAR LAS NUECES
DE KOLÁ PARTIDAS SOBRE SEMILLAS DE IFÁ (IKIN) Y MIENTRAS LO HACÍA DEBÍA RECITAR:
"PERMÍTAME VIVIR PARA PARTIR NUEZ DE KOLÁ PARA IFÁ AL DÍA SIGUIENTE; QUIEN QUIERA QUE
APRIETE NUECES DE KOLÁ PARA IKIN NUNCA MORIRÁ" AL FINAL, ÉL VIVIÓ DURANTE LOS CINCUENTA
AÑOS SIGUIENTES.''',
  '20. RASGOS NOTABLES DE EJIOGBE.': '''EN UN POEMA ESPECIAL, EJIOGBE REVELA QUE SI ÉL APARECE EN IGBODUN PARA UNA PERSONA DE TEZ
CLARA, LA PATERNIDAD DE LA PERSONA SE DEBERÁ REVISAR DE MANERA MINUCIOSA, YA QUE PUDIERA
HABER ALGUNA DUDA AL RESPECTO. ÉL INSISTE EN QUE SI NO SE EXAMINA LA VERDAD EN LO
RELACIONADO CON EL ORIGEN DEL NEÓFITO, EL RIESGO DE MUERTE PREMATURA ES MUY REAL. ÉL DICE
QUE NADIE DEBERÁ CULPAR A ORÚNMILA DE LA MUERTE A DESTIEMPO DEL INICIADO SI NO SE DICE LA
VERDAD ACERCA DE LA DUPLICIDAD DE SU PATERNIDAD. ÉL DICE QUE NO HAY MANERA EN QUE LA
PERSONA, ESPECIALMENTE SI ES DE BAJA TALLA, PUEDA PROSPERAR EN LA VIDA. POR OTRO LADO,
PROCLAMA ENFÁTICAMENTE QUE SI ÉL APARECE EN IGBODUN PARA UNA PERSONA DE TEZ OSCURA Y ALTA,
ÉSTE DEBERÁ SER UN VERDADERO HIJO DE EJIOGBE. NO SOLAMENTE PROSPERARÁ, SINO QUE SERÁ
FAMOSO Y POPULAR. A LA PERSONA SEGURAMENTE SE LE CONFERIRÁ UN TÍTULO TRADICIONAL O ESTATAL
MÁS ADELANTE EN LA VIDA SIEMPRE QUE ÉL LIMPIE EL CAMINO DE MANERA QUE IFÁ LO AYUDE. LA
PERSONA NO SERÁ DADA A HACER JUEGOS SUCIOS O A LA AMBIVALENCIA. ÉL DICE QUE EL INDICADO DE
EJIOGBE, DE BAJA TALLA Y TEZ CLARA, ES EL QUE SE DEDICA A LA TRAICIÓN Y LA MALA FE, EN
GENERAL, LOS HIJOS DE EJIOGBE TIENEN MUCHOS OBSTÁCULOS DIFÍCILES QUE CRUZAR ANTES DE VER
LA LUZ. SIN EMBARGO, TODOS LOS HIJOS DE EJIOGBE DEBERÁN LIMITARSE DE COMER LA CARNE DE LOS
ANIMALES SIGUIENTES: ANTILOPE, ERIZO Y PUERCOESPIN. LOS HIJOS DE EJIOGBE TAMBIÉN DEBERÁN
EVITAR COMER PLÁTANO Y ÑAME ROJO, CON EL FIN DE OBVIAR EL RIESGO DE DOLOR DE ESTÓMAGO.
CUANDO EJIOGBE AYUDA A ALGUIEN, LO HACE DE MANERA SINCERA. SI, POR OTRO LADO, SE LE
PROVOCA PARA QUE SE VIOLENTE, EL DESTRUYE DE MANERA IRREPARABLE. LOA HIJOS DE EJIOGBE SON,
ADEMAS, MUY PERVERSOS E INDULGENTES. AL MISMO TIEMPO, ÉL ES BASTANTE CAPAZ DE CAMBIAR
FORTUNAS YA QUE ORÚNMILA NO CREE EN IMPOSIBLES, TAL Y COMO PUEDE VERSE EN EL SIGUIENTE
POEMA: LAS PERSONAS SENSATAS NO ESCUCHAN AL PAJARO CANTAR CANTOS DE DOLOR. LAS
DIFICULTADES Y LOS PROBLEMAS LE SACAN AL HOMBRE LO MEJOR DE SÍ. LA PACIENCIA Y EL
SACRIFICIO HACEN QUE LO IMPOSIBLE SEA POSIBLE. DENME UN PROBLEMA DIFÍCIL PARA RESOLVER DE
MANERA QUE LOS QUE DUDAN PUEDAN CREER. DENME UNA GUERRA PARA PELEAR PARA QUE LOS MORTALES
PUEDAN COMPRENDER LA FUERZA DE LAS DIVINIDADES. APRENDER DE DESGRACIAS PASADAS ES DE
SABIO. NO APRENDER DE ERRORES PASADOS ES DE TONTO. LA PERSONA QUE NO HACE SACRIFICIO
VINDICA AL ADIVINADOR. TAL Y COMO EL QUE IGNORA EL CONSEJO CONVIERTE AL CONSEJERO EN
VIDENTE.''',
  '21. LA TIERRA DE LAS DESAVENENCIAS.': '''EL HOMBRE QUE APRENDE DE LAS DESAVENENCIAS Y EL HOMBRE QUE NO APRENDE DE LAS
DESAVENENCIAS, FUERON LOS DOS SUSTITUTOS DE EJIOGBE QUE HICIERON ADIVINACIÓN PARA LA
TIERRA DE LAS DESAVENENCIAS. ELLOS ACONSEJARON A LA GENTE QUE HICIERAN SACRIFICIO CON 7
PERROS, 7 TORTUGAS Y 7 CARACOLES PARA QUE PUDIERAN VERSE LIBRE DE DESAVENENCIAS
CONSTANTES. ELLOS SE REUNIERON E HICIERON EL SACRIFICIO. DOS DE CADA UNO DE LOS MATERIALES
DEL SACRIFICIO FUERON OFRECIDO A OGÚN, QUIEN CON OSANYIN SIEMPRE ESTABA FERMENTANDO
QUERELLAS PARA EL PUEBLO. DOS DE CADA UNA DE LAS VICTIMAS DEL SACRIFICIO, EXCLUYENDO LOS
CARACOLES (OSANYIN PROHÍBE LOS CARACOLES), LE FUERON DADOS A OSANYIN. CUATRO CARACOLES SE
LE OFRECIERON A LA DIVINIDAD DEL SUELO. LOS TRES PERROS RESTANTES SE PREPARARON Y SE
DEJARON SUELTOS POR EL PUEBLO. ES DEBIDO A ESTE SACRIFICIO QUE A ALGUNOS HIJOS DE EJIOGBE
SE LE ACONSEJA QUE CRÍEN PERROS. LOS PERROS PRONTO COMENZARON A REPRODUCIRSE Y A
MULTIPLICARSE. CADA VEZ QUE OGÚN COMENZABA A CREAR PROBLEMA EN EL PUEBLO, LOS PERROS
COMENZABAN A LADRARLE. MOLESTO, OGÚN COMENZABA A PERSEGUIR A UNO DE LOS PERROS PARA
MATARLO Y COMÉRSELO, ABANDONANDO ASÍ SU MISIÓN. POR OTRO LADO, CADA VEZ QUE OSANYIN SE
ACERCABA AL PUEBLO PARA CREAR CAOS, EL SUELO LIBERABA UNA GRAN CANTIDAD DE LOS CARACOLES
SIEMPRE LO MOLESTABA, POR LO QUE SE IBA CORRIENDO.''',
  '22. EL ACERTIJO DE LOS AWOS.': '''DESPUÉS DE ESCUCHAR TANTO ACERCA DE LAS ACTIVIDADES DE ORÚNMILA EN LOS DÍAS DE EJIOGBE, EL
REY DE IFE DECIDIÓ PROBARLO JUNTO CON LOS OTROS AWOS CON LA ESPERANZA DE AFECTAR O REDUCIR
SU CRECIENTE POPULARIDAD. EL REY TOMÓ UN GÜIRO E INSERTÓ EN ÉSTE LA ESPONJA Y ELJABÓN
UTILIZADOS POR UNA RECIÉN CASADA. TAMBIÉN AGREGÓ MADERA ROJA Y TEJIDO DE INDIANA DE COLOR
NEGRO (ASHO ETU) Y AMARRÓ EL GÜIRO CON UNA PIEZA DE TELA. EL REY ENTONCES LO DEPOSITÓ TODO
EN SU LUGAR SAGRADO DE IFÁ, DESPUÉS DE LO CUAL INVITÓ A LOS AWOS A QUE VINIERAN Y
REVELARAN EL CONTENIDO DEL GÜIRO. TODOS LOS AWOS TRATARON PERO FRACASARON HASTA QUE LLEGÓ
EL TURNO A UN AWÓ LLAMADO ADARO SEKU, ASHAWO KOOKUTA, OKE OLOBITUN OFIYI SHE OKPE. OGBO
OGBO-OGBO, UNO DE LOS SUSTITUTOS DE EJIOGBE, TAN PRONTO COMO SE SENTÓ, LLAMÓ CON SU VARA
DE ADIVINACIÓN (UROKE) EN LA BANDEJA DE ADIVINACIÓN (AKPAKO) Y APARECIÓ EJIOGBE. ENTONCES
DIJO QUE LOS MATERIALES A UTILIZAR PARA HACER SACRIFICIO ERAN ESPONJA Y JABÓN UTILIZADOS
PARA BAÑAR UNA NOVIA, MADERA ROJA E INDIANA DE COLOR NEGRO. EL REY OBTUVO LA RESPUESTA QUE
QUERÍA Y QUEDÓ BASTANTE SATISFECHO. ENTONCES COMPENSÓ AL AWÓ CON UN TÍTULO DE JEFATURA Y
CUATRO ESPOSAS, 2 DE TEZ CLARA Y 2 DE TEZ OSCURA.''',
  '23. POEMA DE EJIOGBE PARA EL PROGRESO Y LA PROSPERIDAD.': '''ENI- SHEE INOO NI MOO. EJI-JIJI LE EKPON AGBO OJI-EEJAA. ETA- MAA TAAKU NU, MAA TAARUN
DAANU. ERIN-BI A BAARIN, ADIFO OOYE LA AGBO. ERUN- MAARUN KAASHA, MAADA MI. EFA-EFA ULE,
EFA ONO OUNITI ERUKOO. EJE- BI AGHORO BA TII SHORO, AAKIUE. EJO- UWAAMI AAJO, EYIN MI
AAJO. ESON-UWAAMI AASUON, EYINMI AASUON. ENO- INCO WALE AYO, KUROIITA. OKONLA- ELERENI
ELENO DIIRO ALARA, ELENO DIIRO AJERO, ELENO ODIRO OBA ADO, OONI OKA SIRU ELENO DIIRU RE.
OSEMOWO AAMU UDU GHAARAN ELENO DIIRURE, ORÚNMILA OME KIKAN EEKEKUN RO RABA ELENO DIIRU RE.
TA AGO, TEERU NISO NI ILE OLOJA GBELENI SOOMI EETON NI NUULE ALADE AASOFUN OLOWARE YI
AALESIO. TRADUCCIÓN UNO- UNA PERSONA AGREGA A LO QUE YA TIENE. DOS- NO IMPORTA CUANTO SE
MUEVAN LOS TESTÍCULOS DEL CARNERO, ELLOS NO SE LE SEPARAN DEL CUERPO. TRES- YO SOBREVIVIRÉ
A LAS FRÍAS MANOS DE LA MUERTE. CUATRO- UNA LARGA DISCUSIÓN LO LLEVA A UNO TAN LEJOS COMO
IFE. CINCO- CUANDO YO COMA FUEGO, ME LO TRAGARÉ. SEIS- LA AZADA TRAE AL HOGAR REGALOS DE
DENTRO Y DE FUERA DE LA CASA. SIETE- CUANDO UN SACERDOTE SIRVE A SU DIVINIDAD, ESTO DURA
SIETE DIAS. OCHO- YO PROSPERARÉ EN LA VIDA AL IGUAL QUE EN EL MÁS ALLÁ. NUEVE- YO TENDRÉ
ÉXITO EN LA VIDA Y EN EL TIEMPO VENIDERO. DIEZ- EL AYO SOLAMENTE PUEDE JUGARSE EN SU
RECIPIENTE. ONCE- A LOS REYES DE ARA, ERO Y BENIN SÓLO SE LE OBSEQUIAN CAJAS DE REGALO
RESPETABLES. LOS REGALOS AL OONI DE IFE, OSEMAWE DE ONDO Y ORÚNMILA TAMBIÉN SON
PRESENTADOS EN MÚLTIPLOS. LAS UÑAS DE UN TIGRE NO SE UTILIZAN COMO CUCHILLOS PARA ARAÑAR
EL CUERPO HUMANO. EL PORTADOR DE OBSEQUIOS DESCARGA SU EQUIPAJE ANTE EL MAYOR A QUIEN
ESTÁN CONSIGNADOS. LA CARGA Y LA DESCARGA AL IGUAL QUE LAS IDAS Y LAS VENIDAS NUNCA
TERMINAN EN LA CASA DE LAS HORMIGAS / COMEJENES. A LA PERSONA SE LE DEBERÁ DECIR, DESPUÉS
DE LA CEREMONIA ESPECIAL QUE ACOMPAÑA ESTE POEMA, QUE EL PROGRESO Y LOS LOGROS SIEMPRE LO
ACOMPAÑARAN. SE REQUIERE DE MUCHA PERSUASIÓN ANTES DE QUE LOS AWOS ACCEDAN A REALIZAR ESTA
CEREMONIA ESPECIAL PARA LOS HIJOS DE EJIUOGBE.''',
  '24. AKPETEBI MOLESTA A EJIOGBE.': '''ERA CONOCIDO QUE EJIOGBE ERA PARTICULARMENTE PACIENTE Y TOLERANTE. UN DÍA, UNA DE SUS
ESPOSAS LO IRRITÓ TANTO QUE ABANDONÓ LA CASA MOLESTA. EN EL CAMINO, SE ENCONTRÓ CON LOS
SIGUIENTES AGENTES DE DESTRUCCIÓN, UNO TRAS OTRO, ESHUELEGBA, HECHICERIA, DUENDE,
ENFERMEDAD Y MUERTE, LOS CUALES LE PREGUNTARON HACIA DÓNDE SE DIRIGÍA CON SEMEJANTE CÓLERA
Y FURIA. ÉL LES RESPONDIÓ QUE SE IBA DE LA CASA A CAUSA DE SU ESPOSA QUIEN NO LE PERMITÍA
TENER PAZ DE ESPÍRITU. CADA UNO DE ELLOS PROMETIÓ REGRESAR A LA CASA CON ÉL PARA OCUPARSE
DE LA ESPOSA QUE LO HABÍA OFENDIDO. ESA NOCHE, LA ESPOSA TUVO UN SUEÑO QUE LE DIO TANTO
MIEDO QUE DECIDIÓ IR POR ADIVINACIÓN A LA MAÑANA SIGUIENTE. SE LE DIJO QUE LA DESGRACIA,
LA ENFERMEDAD Y LA MUERTE SÚBITA ESTABAN TRAS SU RASTRO DEBIDO A QUE ORÚNMILA HABÍA
INFORMADO DEL ASUNTO A SUS ALTOS PODERES. SE LE DIJO QUE BARRIERA Y LIMPIARA LA CASA, QUE
LLEVARA LAS ROPAS DE EJIOGBE Y QUE PREPARARA UNA COMIDA EN CINCO MÚLTIPLOS DE SOPA, ÑAME
MACHACADO, CARNE, VINOS, NUECES DE KOLÁ, AGUA, ETC., POR EL REGRESO DEL ESPOSO Y QUE DE
RODILLAS LE PRESENTARA A ÉL LA COMIDA TAN PRONTO COMO REGRESARA A LA CASA. EJIOGBE ESTUVO
ALEJADO DURANTE CINCO DÍAS. AL QUINTO DÍA, CUANDO REGRESÓ, LAS CINCO DIVINIDADES LO
ACOMPAÑARON A LA CASA. CUANDO LLEGARON A LA ENTRADA PRINCIPAL DE LA CASA, ÉL LES DIJO QUE
ESPERARAN Y FUE POR LA PUERTA DE ATRÁS. LLORANDO, LA ESPOSA QUE LO HABÍA OFENDIDO SE
ARRODILLÓ PARA ABRAZARLO Y SOLICITARLE QUE LA PERDONARA. ELLA LE DIO LA COMIDA MÚLTIPLE,
UNA POR CADA DÍA QUE ÉL ESTUVO ALEJADO. DEBIDO A SU BUEN CORAZÓN, EJIOGBE COGIÓ LA COMIDA
Y SE LA DIO A LAS CINCO DIVINIDADES QUE ESPERABAN AFUERA. DESPUÉS DE COMER, ELLAS SE
MOVIERON PARA ATACAR A LA MUJER PERO EJIOGBE LES DIO QUE ELLA HABÍA EXPIADO SUS
TRASGRESIONES POR HABER SIDO LA QUE HABÍA PREPARADO LA COMIDA QUE ELLOS RECIÉN HABÍAN
DISFRUTADO. LES RECORDÓ LA REGLA DIVINA DE QUE UNO NO MATA A QUIEN LO ALIMENTA. FUE ASÍ
COMO ÉL SALVÓ A SU ESPOSA DE LA DESTRUCCIÓN. POR LO TANTO, CUANDO EJIOGBE SALE EN LA
ADIVINACIÓN PARA UNA MUJER CASADA, A ELLA SE LE DEBERÁ DECIR QUE PREPARE LA COMIDA
MENCIONADA ANTERIORMENTE EN MÚLTIPLOS DE CINCO PORQUE ELLA HA OFENDIDO TANTO A SU ESPOSO
QUE LAS DIVINIDADES DESTRUCTORAS ESTÁN INFLUIDAS POR LA CÓLERA.''',
  '25. ORÚNMILA ADIVINÓ PARA LO MÁS IMPORTANTE.': '''ORÚNMILA NI O DI HEREHERE, MI HEREHERE LAJORI EKU, IHEREHERE NI AJORI EJA, A TOKUN TOSA LA
GBORI ERINLA KI KERE NIFE O DAIYE, A KI IGBA DU-DU TERIN A KI SE YEKETE TEFON. OJA KI
ITOJA I-GBA-LE, ELU-KELU KI ITONI, OKUN KI TOKUN. YEMIDEREGBE, YEMIDEREGBE LORUKO A
POLOKUN. ORÚNMILA NI KA WON NIBU KA WON NIRO GBOGBOROGBO LOWO YO JORI GBOGBOROGBO NI
MORIWO OPE YO JOGOMO IGBO KI-DI KI IROKO KI O MA YO, A KI IK-ERE JO, KI T-AGOGO KI O MA
YO, T-EMI YO T-EMI YO, L-AKO KE. NJE TI YESI NI O YO-RI JU? DEDERE ORAN OPE NI O YO-RI JU,
DEDERE. B-OKAN YO AJA-NA. DEDERE ORAN OPE NI O YO-RI JU, DEDERE. B-OGAN YO AJA-NA. DEDERE
ORAN OPE NI O YO-RI JU, DEDERE. T-EMI YO T-EMI YO L-AKO KE. DEDERE ORAN OPE NI O YO-RI JU,
DEDERE AKI IK-ERE JO KI T-AGOGO KI O MA YO; DEDERE ORAN OPE NI O YO-RI JU DEDERE.
TRADUCCIÓN: ORÚNMILA DICE QUE TODO DEBE REALIZARSE POCO A POCO. YO DIGO QUE POCO A POCO
DEBEMOS COMER LA CABEZA DE LA JUTÍA; POCO A POCO DEBEMOS COMERNOS LA CABEZA DEL PESCADO.
EL CUAL VIENE DEL MAR, EL QUE VIENE DEL LAGO A RECIBIR LA CABEZA DE LA VACA QUE FUE
IMPORTANTE EN IFE HACE TIEMPO. NOSOTROS NO SOMOS TAN GRANDES COMO EL ELEFANTE NI TAN
CORPULENTOS COMO EL BÚFALO. LA BANDA QUE SE USÓ POR DEBAJO NO ES TAN FINA COMO LA QUE SE
ATÓ ENCIMA. NINGÚN REY ES TAN GRANDE COMO EL ONÍ. NINGUNA SARTA DE CARACOLES ES TAN LARGA
COMO LA DE YEMIDEREGBE; YEMIDEREGBE ES COMO NOSOTROS LLAMAMOS A LA REINA DE LOS MARES.
ORÚNMILA DICE QUE DEBEMOS MEDIR LA LONGITUD Y MEDIR EL ANCHO. LA MANO ALCANZA MUCHO MAS
ALTO QUE LA CABEZA. LAS RAMAS DE LAS PALMAS JÓVENES LLEGAN MAS ALTO QUE LAS RAMAS DE LAS
PALMAS VIEJAS. NINGÚN BOSQUE ES TAN DENSO COMO PARA QUE NO SE VEA LA CEIBA. NINGUNA MÚSICA
ES TAN ALTA COMO PARA QUE EL SONIDO DEL GONG NO SEA ESCUCHADO. LO MÍO ES IMPORTANTE, LO
MÍO ES IMPORTANTE, ES EL GRITO DE HERON EL CANOSO. "ENTONCES, EL PROBLEMAS DE QUIÉN ES MÁS
IMPORTANTE?" "EL PROBLEMA DE LAS PALMAS CLARAS ES MÁS IMPORTANTE, EVIDENTEMENTE" "LOS
RETOÑOS DE OKAN, ELLOS ALCANZAN EL CAMINO;" "EL PROBLEMA DE LAS PALMAS CLARAS ES MÁS
IMPORTANTE, EVIDENTEMENTE" "LOS RETOÑOS DE OGAN, ELLOS ALCANZAN EL CAMINO;" "EL PROBLEMA
DE LAS PALMAS CLARAS ES MÁS IMPORTANTE, EVIDENTEMENTE" "LO MÍO ES IMPORTANTE, LO MÍO ES
IMPORTANTE, ES EL GRITO DE HERON EL CANOSO;" "EL PROBLEMA DE LAS PALMAS CLARAS ES MÁS
IMPORTANTE, EVIDENTEMENTE" 'NINGUNA MUSICA ES TAN ALTA COMO PARA QUE EL SONIDO DEL GONG NO
SEA ESCUCHADO'EL PROBLEMA DE LAS PALMAS CLARAS ES MAS IMPORTANTE, EVIDENTEMENTE".''',
  '26. ORÚNMILA ADIVINÓ PARA LA ORGANIZACIÓN.': '''ORÚNMILA NI O DI E-LESE M-ESE MO NI O DI E-LESE M-ESE O NI OKO MESE TI-RE KO BAJA.
ORUNMILA NO O DI E-LESE M-ESE, MO NI O DI E-LESE M-ESE, O NI OGBON-WO M-ESE TI-RE KO BA
JA. ORÚNMILA NO O DI E-LESE M-ESE, MO NI O DI E-LESE M-ESE, O NI OGOJI M-ESE TI-RE KO
BAJA. MO NI NUE BABA MI AGBONNIRE TA-NI I BA ESE TI-RE JA? O NI EWADOTA NI-KAN NI O BA ESE
TI-RE JA NITORI-TI A KI KA-WO-KA-WO K-A GBAGBE EWADOTA IFA NI O KO NI JE-KI A GBAGBE ENI-
TI O DA IFA-YI, OLUWARE SI NFE SE AHUN KAN YIO BA ESE JA NI OHUN TI O NFE SE NA YI.
TRADUCCIÓN: ORÚNMILA DICE QUE CADA UNO DEBE TOMAR SU PROPIA LÍNEA; YO DIGO QUE CADA UNO
DEBE TOMAR SU PROPIA LÍNEA; ÉL DICE QUE VEINTE CAURIS TOMAN SU LÍNEA PERO NO PUEDEN LLEGAR
AL FINAL. ORÚNMILA DICE QUE CADA UNO DEBE TOMAR SU PROPIA LÍNEA; YO DIGO QUE CADA UNO DEBE
TOMAR SU PROPIA LÍNEA; ÉL DICE QUE TREINTA CAURIS TOMAN SU LÍNEA PERO NO PUEDE LLEGAR AL
FINAL. ORÚNMILA DICE QUE CADA UNO DEBE TOMAR SU PROPIA LÍNEA; YO DIGO QUE CADA UNO DEBE
TOMAR SU PROPIA LÍNEA; ÉL DICE QUE CUARENTA CAURIS TOMAN SU LÍNEA PERO NO PUEDEN LLEGAR AL
FINAL. YO DIGO, ENTONCES, AGBONIRE, PADRE MÍO, QUIÉN PUEDE COMPLETAR SU LÍNEA". ÉL DICE,
CINCUENTA CAURIS SÓLO PUEDEN COMPLETAR SU LÍNEA, PORQUE NO PODEMOS CONTAR DINERO Y OLVIDAR
A CINCUENTA CAURIS. IFÁ DICE EL NO PERMITIRÁ QUE LA PERSONA QUE INDICA ESTA FIGURA SEA
OLVIDADA. ESTA PERSONA QUIERE HACER ALGO; Y ELLA COMPLETARÁ SU LÍNEA EN LA MEDIDA QUE
QUIERA HACERLO.''',
  '27. SE ADIVINÓ IFÁ PARA OLOMOAGBITI.': '''EBITI PA-LE N-GBE WO-LE N-GBE TU-RUTU A DA FUN OLOMOAGBITI TI O TORI OMO D-IFA, NWON NI KI
O RU-BO KOJO MERIN, EKU MERIN, ATI EJA MERIN. OLOMOAGBITI NI ORUKO TI A PE OGEDE. O GBO O
SI RU-BO. OLOMOAGBITI WA OMO TITI KO RI, O MU EJI K-ETA O LO S-ODO BABALAWO O SI BERE BI
ON O TI SE NI OMO? NWON NI KI O RU-BO, O SU RU-BO, O FI AWON N-KAN TI A DA-RUKO NWON YI
RU-BO. O SI WA DI O-L-OMO PUPO. LATI IGBA-NA NI A KO TI FE OMO WERE KU NIDI OGEDE. OMO KI
ITAN OWO YEYE, OMO WERE KO NI TAN L-ESE OGEDE. IFÁ NI NITORI OMO NI E-L-EYI SE D-IFÁ BI O
BA RU-BO OMO KO NI TAN NO ODEDE E-L-EYI LAI-LAI. TRADUCCIÓN: "LA MUERTE CASTIGÓ A LA
TIERRA SORPRENDIÉNDOLA AL TRAERLE EL POLVO", FUE EL QUE ADIVINÓ IFÁ PARA OLOMOAGBITI,
CUANDO ELLA FUE AL PIÉ DE IFÁ PORQUE DESEABA TENER HUOS. ELLOS LE DIJERON QUE DEBÍA
SACRIFICAR CUATRO OLLAS, CUATRO JUTÍAS Y CUATRO PESCADOS. OLOMOAGBITI ES LO QUE LLAMAMOS
PLÁTANO. ELLA ESCUCHÓ Y OFRECIÓ EL SACRIFICIO. OLOMOAGBITI HABIA ESTADO TRATANDO Y
TRATANDO DE TENER HIJOS, PERO NO HABIA TENIDO NINGUNO; ELLA TOMÓ CINCO CAURIS Y FUE DONDE
LOS ADIVINADORES Y LES PREGUNTÓ QUE DEBÍA HACER PARA TENER HIJOS. ELLOS LE DUERON QUE
DEBÍA HACER SACRIFICIO Y ELLA LO HIZO SACRIFICÓ LAS COSAS ANTERIORMENTE MENCIONADAS Y SE
CONVIRTIÓ EN LA MADRE DE MUCHOS HIJOS. DESDE ENTONCES SE OBSERVA QUE LA MATA DE PLÁTANOS
SIEMPRE TIENE HIJOS JÓVENES. LOS HIJOS NUNCA FALTARÁN DE LA MANO DE LA MADRE, LOS HIJOS
JÓVENES NUNCA FALTARÁN AL PIE DEL PLÁTANO. I FÁ DICE QUE POR CAUSA DE LOS NIÑOS ES QUE LA
PERSONA FUE A VERSE CON FÁ; SI ELLA HACE EL SACRIFICIO, NUNCA FALTARÁN LOS HIJOS EN SU
PUERTA.''',
  '28. ADIVINARON PARA ORÚNMILA PARA LA MEDICINA CONTRA LOS ABIKÚ.': '''ABIKÚ. IGBO NI-GBO-NA ODAN L-ODAN ORUN A DA FUN ORÚNMILA NI-JO T-IFA NLO KI OWO A-BI-KU
BOLE NI KOTO ATITAN. NI-GBA-TI ORUNMILA NSE ABI-KU, O TO AWON BABALAWO IGBO-NI-GBO-NA ATI
ODAN-L-ODAN ORUN LO, NWON SI SO FUN PE KI O RU-BO O SI RU-BO, LATI IGBA-NA NI A-BI-KU TI
DA-WO-DURO NI ARA AWON OBINRIN RE. IFA NI A-BI-KU NBA E-L-EYI JA, BI O BA SI LE RU-BO YIO
DA-WO-DURO. TRADUCCION: "BOSQUE ES EL BOSQUE DEL FUEGO"Y "MANIGUA ES LA MANIGUA DEL
SOL'FUERON LOS QUE ADIVINARON PARA ORÚNMILA EL DÍA QUE ÉL FUE BUSCANDO UNA MEDICINA CONTRA
LOS ABIKÚS POR EL ATOLLADERO EN QUE ESTABA EN SU CABANA. CUANDO ORUNMILA TUVO PROBLEMAS
POR CAUSA DE LOS ABIKÚS FUE DONDE LOS ADIVINOS "BOSQUE ES EL BOSQUE DEL FUEGO"Y "MANIGUA
ES LA MANIGUA DEL SOL: ELLOS LE DIERON QUE DEBÍA HACER UN SACRIFICIO YEL SACRIFICÓ. DESDE
ENTONCES SUS ESPOSAS DEJARON DE PARIR ABIKÚS. IFÁ DICE QUE LA PERSONA TIENE GUERRA CON LOS
ABIKÚS, SI ES CAPAZ DE SACRIFICAR, ESA GUERRA PARARÁ.''',
  '29. SE ADIVINÓ PARA EL BUITRE.': '''PATAKI: OROGBO OSUGBO AJA-NI-MORO-TIPE-TIPE A DA FUN- GUN OMO OLOJONGBOLORO A-L-AFIN BA WON GB-ODE ORA; A KI RI-OPEPE IGUN L-ATAN, OROGBO KANGE KANGERE KANGERE N-IFE, OROGBO KANGERE. IFA NI E-L-EYI YIO DI ARUGBO O NI BI A KI ITI RI OMODE IGUN, BE-NI E-L-EYI YIO DI ARUGBO. IGUN NI KIN-NI ON YIO SE TI ON YIO FI DI ARUGBO? O LO SI ODO AWON BABALAWO, NWON NI KI O RU-BO, KI O SI BU IYE RE LE ORI, NI-GBA-TI IGUN RU-BO TI O SI BU IYE RE LE ORI, ORI RE SI BERE SI FUNFUN BI ENI-PE O WU IWU ATI IGBA- NA NI ORI IGUN TI MA NFUNFUN TI O SI DABI IWU; A KI SI MO OMODE IGUN ATI AGBA YATO NITORI-TI ORI GBOGBO WON NI O PA. TRADUCCIÓN: "KOLÁ AMARGA DE LA SOCIEDAD OGBONI, TECHO MUY IMPERMEABLE DE LA HERRERÍA" FUE EL QUE ADIVINÓ IFÁ PARA EL BUITRE, EL HIO DE OLOJONGBOLORO, QUIEN GOLPEÓ EL TAMBOR DE AFIN CON LOS QUE VIVÍAN EN EL PUEBLO DE ORA. LOS HIJOS DEL BUITRE NUNCA SE VEN EN LA CASA. DÉBIL, DÉBIL LA KOLÁ AMARGA, DÉBIL EN EL PUEBLO DE IFE, DÉBIL LA KOLÁ AMARGA. IFÁ DICE QUE ESTA PERSONA VIVIRÁ HASTA QUE SEA MUY VIEJO. DICE QUE COMO NUNCA SE VEN LOS BUITRES JÓVENES, ASÍ MISMO ESTA PERSONA VIVIRÁ MUCHOS AÑOS. EL BUITRE PREGUNTÓ QUE DEBÍA HACER PARA VIVIR HASTA EDADES BIEN MAYORES. ÉL FUE DONDE LOS ADIVINOS Y LE DIJERON QUE DEBÍA HACER SACRIFICIO Y ROCIAR SOBRE SU CABEZA POLVO DIVINO. CUANDO EL BUITRE SACRIFICÓ Y ROCIÓ SOBRE SU CABEZA EL POLVO DIVINO, ESTA SE PUSO BLANCA COMO UNA PERSONA QUE EL PELO SE LE PUSO CANOSO. DESDE ENTONCES LA CABEZA DEL BUITRE SIEMPRE ESTÁ BLANCA Y PARECE COMO SI TUVIERA EL PELO CANOSO. NO SE PUEDE NOTAR LA DIFERENCIA ENTRE UN BUITRE JOVEN Y UNO VIEJO PUES LAS CABEZAS DE AMBOS ESTAN CALVAS.''',
  '30. SE ADIVINÓ PARA UNO AMPLIAMENTE CONOCIDO.': '''PATAKI: INA TIN L-EGBE ORUN, AGUNMOLA TIN L-EHIN OSU A DA F-A-MO-KA ORUKO TI A PE OJO. IFA NI E-L- EYI YIO NI ORUKO NI OHUN TI O DA IFA SI YI, YIO SI NI ORUKO SUGBON KI O RU-EBO EKU KAN EJA KAN, AKIKO TI O NI OGBE L-ORI KAN ATI ADEGBETA ATI EPO. A-O MU ORI EKU ATI EJA NA, A-O GE DIE NI-NU OGBE AKIKO NA A-O KO SI-NU EWE ELA KAN; A-O LO WON PO; A-O FI SIN GBERE EJILELOGUN SI ORI ENI-TI O WA DA IFA YI. TRADUCCIÓN: "EL TENUE FUEGO A UN LADO DEL CIELO, LA CLARA ESTRELLA DE LA TARDE EN EL CUARTO CRECIENTE DE LA LUNA"FUE EL QUE ADIVINÓ IFÁ PARA "UNO QUE ES AMPLIAMENTE CONOCIDO'EL NOMBRE QUE USAMOS PARA EL SOL IFÁ DICE QUE ESTA PERSONA TENDRÁ RENOMBRE POR ELLA MISMA, PERO DEBE SACRIFICAR UNA JUTÍA, UN PESCADO, UN GALLO CON MUCHA CRESTA, DINERO Y MANTECA DE COROJO. TOMAREMOS LAS CABEZAS DE LA JUTIA Y EL PESCADO Y UN PEDAZO DE LA CRESTA DEL GALLO. PONDREMOS TODAS ESTAS COSAS EN UNA HOJA DE ORQUÍDEA Y LO MACERAMOS TODO JUNTO. DESPUÉS LE HAREMOS A LA PERSONA VEINTIDÓS PEQUEÑAS INCISIONES EN LA CABEZA Y LE IMPONEMOS ESTA MEZCLA EN ELLA A MODO DE ROGACIÓN DE CABEZA.''',
  '31. SE ADIVINÓ PARA ORE LA ESPOSA DE AGBONNIREGUN.': '''PATAKI: IRO-FA A B-ENU GINGINNI A DA F-ORE TI ISE OBINRIN AGBONNIREGUN. IFA NI OBINRIN KAN WA TI O NYA-JU SI OKO RE, KI O MA TO-JU OKO RE GIDI-GIDI NITORI-TI ORI OKO NA NFE BA JANITORI-NA KI O NI IGBA IYAN MEFA, KI O FO ASO OKO RE, KI O SI MA PA-LE OKO RE KI O SI NI AMU OTI SEKETE KAN KI O GBE SI IDI IFA OKO RE L-ONI. ORE NI-KAN SOSO NI AYA AGBONNIREGUN NI AKOKO YI, KO SI FERAN AGBONNIREGUN RARA, BI O BA LO SI ODE, ORE A MA BU KO SI JE WA ONE DE. NI- GBA-TI AGBONNIREGUN RI IWA AYA RE YI, O MU-RA O FI TA IKU, ARUN, OFUN, ISE ATI IYA L-ORE. NI OJO NA GAN NI ORE SUN TI O SI LA ALA; NI-GBA-TI ILE MO TI O SI JI, O FI EJI-K-ETA O LO S-ODO BABALAWO PE K-O YE ON WO NWON NI ORUN TI O SUN KO DARA NITORI-PE OKO RE TI FI TA IKU, ARUN, OFUN, ISE ATI AYA L-ORE, NITORI-NA KI O ORE LO MU ASO OKO RE KI O FO, KI O PA ILE OKO RE NI EMEJI KI O SI GUN IYAN ARABA MEFA SI IDI IFA OKO RE. NI-GBA-TI ORE SE OHUN GBOGBO NWON-YI TAN, TI AGBONNIREGUN DE TI O SI RI ASO TI O FI IBO-RA TI AYA RE TI FO, TI O RI ILE TI O PA, BI O SI TI WO-LE TI O DE IDI IFA RE TI O BA ARABA IYAN MEFA NI IDI IFA, AGBONNIREGUN WA DA-HUN O NI: O SOKO, NWON NI BANI IKU MA MA P-ORE MO, O ORE N-IYAN, ORE L-OBE, ORE ARUN MA MA S-ORE MO, O ORE N-IYAN, ORE L-OBE, ORE OFUN MA MA S-ORE MO, O ORE N-IYAN, ORE L-OBE, ORE ARUN MA MA S-ORE MO, O ORE N-IYAN, ORE L-OBE, ORE OFUN MA MA S-ORE MO, O OREN-IYAN, ORE L-OBE, ORE IYA MA MAJ-ORE MO. O ORE N-IYAN, ORE L-OBE, ORE BAYI NI ORE BO L-OWO AWON OHUN TI AGBONNIREGUN TI FI LE L-OWO PE KI NWON BA ON JE NI IYA. TRADUCCIÓN: "LAS CAMPANAS DE IFÁ TIENEN UNA BOCA AFILADA"FUE EL QUE ADIVINÓ IFÁ PARA ORE, LA ESPOSA DE AGBONNIREGUN. IFÁ DICE QUE HAY UNA MUJER QUE ES INSOLENTE CON SU ESPOSO. ELLA DEBE SER MUY CONSIDERADA CON SU ESPOSO, PUES ÉL ESTÁ PLANEANDO UN CASTIGO PARA ELLA. POR LO TANTO ELLA DEBE HACER SEIS PANES DE ÑAME TRITURADO; LAVAR LA ROPA DE SU ESPOSO, LIMPIAR LAS PAREDES Y EL PISO DE SU CASA Y PONER UNA VASUA CON CERVEZA DE MAÍZ DONDE ESTÁ EL IFÁ DE SU ESPOSO. EN ESOS TIEMPOS, ORE ERA LA ÚNICA ESPOSA DE AGBONNIREGUN, PERO ELLA NO LO AMABA PLENAMENTE. CUANDO ÉL SALÍA EN PÚBLICO, ELLA LO INSULTABA Y REHUSABA PREPARARLE COMIDA. CUANDO AGBONNIREGUN VIO EL VERDADERO CARÁCTER DE SU ESPOSA LE PREPARÓ Y LE DIO UNA MEDICINA MALA PARA PROVOCARLE LA MUERTE, LA ENFERMEDAD, LA PÉRDIDA, LA POBREZA Y EL CASTIGO. EN ESOS DÍAS ORE SE ACOSTÓ Y TUVO UN SUEÑO, CUANDO SE LEVANTÓ COGIÓ CINCO CAURIS Y FUE DONDE LOS ADIVINADORES PARA QUE LA EXAMINARAN. ELLOS LE DIERON QUE HABÍA TENIDO UN MAL SUEÑO PORQUE SU ESPOSO LE HABÍA DADO A TOMAR UNA MEDICINA PARA PROVOCARLE LA MUERTE, LA ENFERMEDAD, LA PERDIDA, LA POBREZA Y EL CASTIGO. DESPUÉS DE ESTO ELLA TOMÓ LA ROPA DE ESPOSO Y LA LAVÓ, LIMPIÓ LA CASA DOS VECES Y PREPARÓ SEIS PANES DE ÑAME TRITURADO Y SE LOS PUSO EN EL IFÁ DE SU ESPOSO. CUANDO ORE HIZO TODAS ESTAS COSAS, AGBONNIREGUN REGRESÓ A LA CASA. CUANDO EL VIO QUE SU ESPOSA HABÍA LAVADO SUS ROPAS, HABÍA LIMPIADO LAS PAREDES Y LOS PISOS DE LA CASA Y LE HABÍA PUESTO SEIS PANES DE NAME MOLIDO A SU IFÁ, DIJO: "OH SHOKO; ELLOS RESPONDIERON BANI QUE LA MUERTE NO LE CAUSE MAS PROBLEMAS A ORE, OH; ORE HIZO ÑAME TRITURADO, ORE HIZO UN ESTOFADO, ORE QUE LA EPIDEMIA NO LE CAUSE MÁS PROBLEMAS A ORE, OH; ORE HIZO ÑAME TRITURADO, ORE HIZO UN ESTOFADO, ORE QUE LA PÉRDIDA NO LE CAUSE MÁS PROBLEMAS A ORE, OH; ORE HIZO ÑAME TRITURADO, ORE HIZO UN ESTOFADO, ORE QUE EL CASTIGO NO LE CAUSE MÁS PROBLEMAS A ORE,OH; ORE HIZO ÑAME TRITURADO, ORE HIZO UN ESTOFADO, ORE". FUE DE ESTA FORMA QUE ORE ESCAPÓ DE LAS COSAS QUE AGBONNIREGUN HABÍA HECHO EN SU CONTRA PARA CASTIGARLA.''',
  '32. ORÚNMILA ADIVINÓ PARA QUE TUVIERAN UN RESPIRO Y HONOR.': '''PATAKI: ORUNMILA NI O DI HIN; MO NI O DI IMI SIN-SIN O NI ENI-TI O BA FI OMI RU-BO ISE NI SIN-MI ORÚNMILA NI O DI HIN; MO NI O DI IMI SIN-SIN O NI ENI-TI O BA FI ILA RU-BO ISE NI INI OLA. ORÚNMILA NO O DI HIN, MO NI O DI IMI SIN-SIN, O NI ENI-TI O BA FI IYO RU-BO ISE NI ORAN RE DUN. IGBA OMI TUTU KAN, A-O DA IYO S-INU RE, A-O RE ILA S-INU OMI NA PELU, A-O FI IYE-ROSUN TE EJI OGBE, A-O DA S-INU RE, ENI TI O DA IFA NA YIO MU N-INU OMI NA, ENI K-ENI TI O BA FE LE MU N-INU OMI NA PELU L-EHIN NA A-O DA EYI TI O BA SIKU SI IDI ESU IFA NI ENI-TI A DA ON FUN YI NFE I-SIN-MI YIO SI NI I- SIN-MI YIO SI NI OLA PELU. TRADUCCIÓN: ORÚNMILA DICE QUE NOSOTROS DEBEMOS SUSPIRAR "HIN"(SONIDO DEL SUSPIRO), YO DIGO QUE NOSOTROS DEBEMOS TOMAR UN RESPIRO Y DESCANSAR; EL DICE QUE AQUEL QUE OFREZCA AGUA TENDRÁ UN RESPIRO. ORÚNMILA DICE QUE NOSOTROS DEBEMOS SUSPIRAR "HIN", YO DIGO QUE NOSOTROS DEBEMOS TOMAR UN RESPIRO Y DESCANSAR; ÉL DICE QUE AQUEL QUE OFREZCA QUIMBOMBÓ TENDRÁ HONOR. ORÚNMILA DICE QUE NOSOTROS DEBEMOS SUSPIRAR "HIN", YO DIGO QUE NOSOTROS DEBEMOS TOMAR UN RESPIRO Y DESCANSAR; ÉL DICE QUE AQUEL QUE OFREZCA SAL ENCONTRARÁ SATISFACCIÓN EN SUS NEGOCIOS. SE REQUIERE DE UNA JÍCARA CON AGUA FRÍA, SE LE AGRE GARÁ SAL Y RODAJAS DE QUIMBOMBÓ, MARCAMOS EJIOGBE EN EL TABLERO Y LE ECHAMOS DE ESE IYEFÁ AL AGUA. LA PERSONA QUE SE LE VIO EL SIGNO DEBE TOMAR DE ESA AGUA Y TODO AQUEL QUE DESEE TOMAR PUEDE HACERLO. DESPUÉS DERRAMAMOS DE LA QUE QUEDE AL PIE DE ESHU-ELEGBA. IFÁ DICE QUE LA PERSONA QUE SE LE VIO ESTE ODU QUIERE TENER UN RESPIRO Y LO TENDRA ADEMAS DE OBTENER HONOR.''',
  '33. SE ADIVINÓ PARA ORÚNMILA CUANDO IBA HACER AMISTAD CON ESHU-ELEGBA.': '''PATAKI: ESHU-ELEGBA. PONRIPON SIGIDI NI ISE AWO INU IGBO, OGOGORO L-AWO JAMO, B-ORE BA DUN L-A-DUN-JU A DABI IYE-KAN A DA FUN ORÚNMILA T-O NLO BA ESHU-ELEGBA D-OLUKU "A KI BA ESHU-ELEGBA D-OLUKU K-OJU OWO PON-NI ESHU-ELEGBA SE NI MO WA BA O D-OLUKU AKI BA ESHU-ELEGBA D-OLUKU K-OJU AYA PON-NI ESHU-ELEGBA SE NI MO WA BA O D-OLUKU AKI BA ESHU-ELEGBA D-OLUKU K-OJU OMO PON-NI ESHU-ELEGBA SE NI MO WA BA O D-OLUKU" A-O PA AKIKO NI A-PA-L-AIYA A-LO FO IGBIN KA SI A-O BU EPO SI A-O GBE LO SI IDI ESHU-ELEGBA. IFÁ NI E-L-EYI NFE NI ORE TITUN KAN, ORE NA YIO SE NI ANFANI. TRADUCCIÓN: PONRIPON SHIGIDI, EL ADIVINADOR DEL BOSQUE, OGOGORO EL ADIVINADOR DE IJAMO Y "SI UN AMIGO ES EXTREMADAMENTE CARIÑOSO, EL QUIERE A LOS NIÑOS COMO LA PROPIA MADRE", FUERON QUIENES ADIVINARON IFÁ PARA ORÚNMILA CUANDO IBA A HACER AMISTAD CON ESHU- ELEGBA. "AQUELLOS QUE SE AMIGAN CON ESHU-ELEGBA NO TIENEN PROBLEMAS MONETARIOS. ESHU-ELEGBA, TÚ ERES EL PRIMERO Y YO QUIERO SER TU AMIGO AQUELLOS QUE SE AMIGAN CON ESHU-ELEGBA NO TIENEN PROBLEMAS CON LAS ESPOSAS. ESHU-ELEGBA, TÚ ERES EL PRIMERO Y YO QUIERO SER TU AMIGO. AQUELLOS QUE SE AMIGAN CON ESHU-ELEGBA NO TIENEN PROBLEMAS CON TENER HIJOS. ESHU-ELEGBA, TÚ ERES EL PRIMERO Y YO QUIERO SER TU AMIGO." MATAREMOS UN GALLO, DESGARRÁNDOLO Y ABRIÉNDOLO HASTA LA PECHUGA. ROMPEREMOS UN CARACOL CON BABOSA Y LO PONEMOS CON MANTECA DE COROJO DENTRO DEL GALLO Y LO PONEMOS AL PIE DE ESHUELEGBA. IFÁ DICE QUE LA PERSONA DESEA TENER UNA NUEVA AMISTAD Y QUE ESTE NUEVO AMIGO SERÁ DE SU BENEFICIO.''',
  '34. SE ADIVINÓ PARA ORÚNMILA CUANDO ENAMORABA A LA TIERRA.': '''PATAKI: OMO-WO TORI IYAN O YO-KE, ATAPARAKO SE EHIN KOKOKO PA-BI A DA FUN ORÚNMILA TI O MA FE AIYE OMO E-L-EWU EMURE, NWON NI KI ORUNMILA RU-BO KI O BA RI AYA NA FE, EKU KAN, EGBEDOGBON, ATI AYEBO ADIE MEJI. A-LO SO ILEKE-K-ILEKE MO EKU NA NI IDI A-LO LO FI GUN-LE SI-NU IGBE, ORÚNMILA RU- BO. AIYE JE OMO OBA OBINRIN, IGBA ALSO NI AIYE RO, O SI SO PE ENI-K-ENI TI O BA RI IDI ON NI ON YIO FE. NI-GBA-TI ORÚNMILA FI EKU YI GUN-LE SI INU IGBO NI-GBA-TI O DI OWURO OJO-KEJI TI AIYE LO YA-GBE NI-NU IGBE, ESU PA-TE MO EKU NA, O DI AYE, ILEKE TI ORÚNMILA SO MO NI IDI DI SEGI, NI-GBA-TI AIYE RI EKU YI PELU SEGI NI IDI RE O BERE SI ILE KIRI, NI-BI-TI O GBE TI NLE KIRI GBOGBO IGBA ASO IDI RE TU, O SI WA NI IHOHO, NI-BI-TI O GBE TI NSA-RE KIRI NI IHOHO, NO AKOKO NA NI ORÚNMILA WA BE EBO TI O RU WO, TI O SI BA AIYE NI IHOHO. NI-GBA-TI AIYE RI ORÚNMILA, O NI O PA-RI, O NI O TI SO PE ENI-KENI TI O BA RI IDI ON NI ON YIO FE; BAYI NI AIYE DI AYA ORÚNMILA, ORÚNMILA SI LO KO GBOGBO ERU AIYE WA SI ILE ARA-RE AIYE SI JOKO TI. NI-GBA-TI ORÚNMILA FE AIYE TAN NI O BERE SI KO-RIN TI O NO TI O NO PE: "A GB-AIYE KA-LE AWA O LO MO O, E,E." IFA NI A-O RI AYA KAN FE, TI IRE YIO WA L-EHIN OBINRIN NA, A-O SI NI IGBA-HUN- IGBA-HUN LATI ESE OBINRIN NA WA. TRADUCCIÓN: "POR TRITURAR LOS NAMES LOS DEDOS SE ENCORVAN; EL PULGAR SE ENDURECE POR PARTIR LAS KOLÁ-NUTS'FUE EL QUE ADIVINÓ PARA ORÚNMILA CUANDO ESTABA ENAMORADO DE LA TIERRA, HUA DE "LA QUE TIENE EL VESTIDO AGRADABLE" ELLOS LE DUERON A ORÚNMILA QUE DEBÍA SACRIFICAR UNA JUTÍA, DINERO Y DOS GALLINAS PARA PODER CASARSE CON ELLA. EL ATARIA ALGUNOS TIPOS DE CUENTAS A LA CINTURA DE LA JUTIA Y LA EMPALARIA DENTRO DE LA TIERRA EN EL MONTE. ORÚNMILA SACRIFICÓ. LA TIERRA ERA LA HIJA DEL REY. ELLA VESTÍA DOSCIENTAS ROPAS ALREDEDOR DE SU CINTURA Y DIJO QUE SE CASARÍA CON AQUEL QUE LE VIERA LAS NALGAS DESNUDAS. EN LA MAÑANA DEL SIGUIENTE DÍA, LA TIERRA ENTRÓ AL BOSQUE A DEFECAR. ESHU-ELEGBA APLAUDIÓ Y LA JUTÍA COBRÓ VIDA Y LAS CUENTAS QUE ORÚNMILA HABÍA ATADO A LA CINTURA DE LAJUTÍA SE CONVIRTIERON EN PERLAS. CUANDO LA TIERRA VIO LA JUTIA CON LAS PERLAS EN LA CINTURA, COMENZÓ A PERSEGUIRLA. SEGÚN LA PERSEGUÍA SUS DOSCIENTOS VESTIDOS COMENZARON A CAER DE SU CINTURA Y SE QUEDÓ DESNUDA. EN ESE MOMENTO ORÚNMILA LLEGABA A REVISAR SU SACRIFICIO Y SE ENCONTRÓ CON LA TIERRA CORRIENDO DESNUDA. CUANDO LA TIERRA VIO A ORÚNMILA DIJO QUE ERA SUFICIENTE Y QUE SE CASARÍA CON EL QUE LE HUBIERA VISTO LAS NALGAS DESNUDAS. POR LO TANTO, LA TIERRA SE CONVIRTIÓ EN ESPOSA DE ORÚNMILA. ÉL LLEVÓ TODAS LAS PERTENENCIAS DE ELLA A SU CASA DONDE ELLA SE INSTALÓ. CUANDO ORÚNMILA SE CASÓ CON LA TIERRA, COMENZÓ A CANTAR Y A BAILAR REGOCIJADO: CAPTURAMOS A LA TIERRA NUNCA LA ABANDONAREMOS, OH, AY, AY. IFÁ DICE QUE LA PERSONA ENCONTRARÁ UNA MUJER PARA CASARSE Y A TRAVÉS DE ELLA, ÉL RECIBIRÁ UNA BENDICIÓN. LA MUJER LE TRAERÁ, MUCHOS TIPOS DE BENEFICIOS.''',
  '35. SE ADIVINÓ A ORÚNMILA CUANDO SE IBA A CASAR CON NWON LA HIJA DE LA DIOSA DEL MAR OLOKUN.': '''HIJA DE LA DIOSA DEL MAR OLOKUN. EJINRIN FA GBURU-GBURU WO-LU A DA FUN ORÚNMILA TI ONLO FE
EYI TORO OMO O-L-OKUN. NWON NIKI ORÚNMILA RU-BO KI O BA LE FE, AKIKO MEJI, AYEBO KAN, EKU,
EJA OKE MEJI, ATI EGBAFA; 0 RU-BO. N-IGBA-TI ORÚNMILA NLO SI ILE O-L-OKUN, O KO OKE MEJI
DANI, N-GBA-TI ORÚNMILA FI MA DE ILE O-L-OKUN, ESU SE-JU MO L-ARA, NI-GBA-TI TORO RI
ORÚNMILA, O NI ON NI ON O FE. O-L-OKUN NI GBOGBO IRUNMOLE TI O TI NFE TORO TI KO GBA. NIBO
NI ORÚNMILA MU TORO GBA? ORÚNMILA NI ON YIO MU LO BAYI NI O-L-OKUN BERE SI KE ORÚNMILA; O
NI LATI OJO TI GBOGBO IRUN-MOLE TINFE TORO, O JAJA RI ENI-TI YIO FE. NI-GBA-TI AWON IRUN-
MOLE RI PE TORO FE ORUNMILA, INU BI WON NWON MU-RA NWON FI OTUN SE AYE NWON TI OSI SE
IRAN, NWON FI OKOROKOROSE A-JIN-JIN-DORUN NI-GBA-TI ESU RI EYI, O MU OKAN N-INU AKIKO MEJI
TI ORÚNMILA FI RU-BO, O SO SI-NU AYE OTUN, O DI, O SO OKAN SI-NU IRAN OSI, O DI; AWON
IRUN-MOLE, SI TI SO FUN O-L-ODO TI YIO TU NWON PE BI NWON BA RI BABALAWO KAN TI O BA MU
OBINRIN KAN L-EHIN, KO GBODO TU WON; NI GBA-TI ORÚNMILA FI MA DE ODO O-L-ODO O DI OBINRIN
RE TORO SI-NU OKE KAN O DA OKAN DE L-ORI, O DI O GBE RU, NI-GBA-TI O DE ODO O-L-ODO, O-L-
ODO KO MO PE BABALAWO NA TI AWON IRUNMOLE WI NI, O SI TU WON GUN OKE, NI-GBA-TI ORÚNMILA
DE OJA IFE, O SO KA-LE, O TU OKE L-ORI OBINRIN, OBINRIN NA SI YO JA-DE ARA TA GBOGBO AWON
IRUN-MOLE INU SI BI WON ORÚNMILA NO, O NO, O NI: "O SOKO BANI EJINRIN FA GBURU-GBURU WO-LU
O A DA FUN EMI ORÚNMILA TI NLO FE TORO, OMO O-L-OKUN AWON IRUN-MOLE F-OTUN S-AYE O AWON
IRUN-MOLE F-OSI SE-RAN NWON FI OKOROKORO S-A-JIN-JIN-D-ORUN NWON LE F-OTUN S-AYE O KI NWON
F-OSI SE-RAN KI NWON F-OKOROKORO S-A-JIN-JIN-D-ORUN. K-O-N-ILE MA RE-LE GBAIN ORUNMILA GBE
MI S-OKE GBE MI S-ORORO RE K-AJO MA LO GBERE-GBERE. NI-BI O DA L-O DA K-AJO MA LO."" IFA
NI A-O FE OBINRIN KAN, GBOGBO ENIA NI YIO MA DOYI YI-NI KA, TI NWON YIO SI MA DI RIKISI
SI-NI KI A MA FOYA, A-LO FE OBINRIN NA. YO JA-DE ARA TA GBOGBO AWON IRUN-MOLE INU SI BI
WON ORÚNMILA NJO, O NJO, O NI: "O SOKO BANI EJINRIN FA GBURU-GBURU WO-LU O A DA FUN EMI
ORÚNMILA TI NLO FE TORO, OMO O-L-OKUN AWON IRUN-MOLE F-OTUN S-AYE O AWON IRUN-MOLE F-OSI
SE-RAN NWON FI OKOROKORO S-A-JIN-JIN-D-ORUN NWON LE F-OTUN S-AYE O KI NWON F-OSI SE-RAN KI
NWON F-OKOROKORO S-A-JIN-JIN-D-ORUN. K-O-N-ILE MA RE-LE GBAIN ORÚNMILA GBE MI S-OKE GBE MI
S-ORORO RE K-AJO MA LO GBERE-GBERE. NI-BI O DA L-O DA K-AJO MA LO." IFA NI A-O FE OBINRIN
KAN, GBOGBO ENIA NI YIO MA DOYI YI-NI KA, TI NWON YIO SI MA DI RIKISI SI-NI KI A MA FOYA,
A-LO FE OBINRIN NA. TRADUCCIÓN: "EJINRIN SE EXTIENDE Y SE EXTIENDE ANTES DE ENTRAR AL
PUEBLO"FUE EL QUE ADIVINÓ POR IFÁ PARA ORÚNMILA CUANDO ÉL SE IBA A CASAR CON NWON, HIJA DE
LA DIOSA DEL MAR OLOKUN. ELLOS DIJERON A ORÚNMILA QUE DEBÍA SACRIFICAR DOS GALLOS, UNA
GALLINA, UNA JUTÍA, UN PESCADO, DINERO, PARA QUE PUEDA CASARSE CON ELLA. ÉL HIZO EL
SACRIFICIO. CUANDO ORÚNMILA FUE A LA CASA DE LA DIOSA DEL MAR, LLEVÓ DOS BOLSAS DE DINERO.
CUANDO LLEGÓ, ESHU-ELEGBA LE GUIÑÓ LOS OJOS, CONVIRTIÉNDOLO EN ALGUIEN BUEN MOZO. CUANDO
NWON LO VIO, DIJO QUE ESE SERÍA UNO CON QUIEN A ELLA LE GUSTARÍA CASARSE. LA DIOSA DEL MAR
DIJO QUE LAS CUATROCIENTAS DEIDADES QUERÍAN CASARSE CON NWON, PERO QUE ELLA LOS HABÍA
RECHAZADO, Y ¿DÓNDE PODRÍA LLEVAR ORÚNMILA A NWON QUE PUDIERA ESCAPAR DE LA IRA DE ELLOS?.
ORÚNMILA DIJO QUE ÉL SE LLEVARÍA A NWON. ENTONCES LA DIOSA DEL MAR COMENZÓ A SER
HOSPITALARIA CON ORÚNMILA, PUES SU HIJA HABÍA ENCONTRADO AL HOMBRE CON QUIEN DESEABA
CASARSE. CUANDO LAS CUATROCIENTAS DEIDADES SE ENTERARON QUE NWON AMABA A ORÚNMILA SE
ENOJARON MUCHÍSIMO; ELLOS SE PREPARARON Y CAVARON UN HUECO A LA DERECHA, CAVARON UN ABISMO
A LA IZQUIERDA Y AL FRENTE CAVARON UN HOYO TAN PROFUNDO COMO LA ALTURA DEL CIELO. CUANDO
ESHU-ELEGBA VIO ESTO, TOMÓ LOS DOS GALLOS QUE ORÚNMILA HABÍA SACRIFICADO. TIRÓ UNO EN EL
HUECO DE LA DERECHA Y LO TAPÓ; TIRÓ EL OTRO EN EL HUECO DE LA IZQUIERDA Y LO TAPÓ, Y TIRÓ
LA GALLINA EN EL HOYO DEL FRENTE Y TAMBIÉN LO TAPÓ. LAS CUATROCIENTAS DEIDADES HABÍAN
HABLADO A LOS BARQUEROS EN EL RÍO QUE ORÚNMILA DEBÍA CRUZAR, QUE SI UN ADIVINO CON UNA
MUJER IBA DONDE ELLOS PARA QUE LES CRUZARA EL RIO, DEBIAN NO HACERLO. CUANDO ORÚNMILA SE
ESTABA ACERCANDO AL RÍO METIÓ A SU ESPOSA NWON EN UNA BOLSA Y LE TAPÓ LA CABEZA CON OTRA,
LA ATÓ FUERTEMENTE Y LA CARGÓ. AL LLEGAR, LOS BARQUEROS NO PUDIERON RECONOCER EN ÉL AL
HOMBRE QUE LAS CUATROCIENTAS DEIDADES LE HABÍAN HABLADO Y LO LLEVARON A TRAVÉS DEL RÍO.
CUANDO ORÚNMILA LLEGÓ AL MERCADO EN IFE, PUSO LA BOLSA EN EL PISO, LA DESATÓ Y SALIÓ SU
ESPOSA. LAS CUATROCIENTAS DEIDADES SE DESILUSIONARON Y SE MOLESTARON MUCHO; PERO ORÚNMILA
SE PUSO A BAILAR Y REGOCIJADO DECIA: '000000H SHOKO, BANI. EJINRIN SE EXTIENDE Y SE
EXTIENDE ANTES DE ENTRAR AL PUEBLO, OH FUE EL QUE ADIVINÓ IFÁ PARA MÍ, ORÚNMILA. CUANDO ME
IBA A CASAR CON NWON, LA HIJA DE LA DIOSA DEL MAR. LAS CUATROCIENTAS DEIDADES CAVARON UN
HUECO A LA DERECHA. LAS CUATROCIENTAS DEIDADES CAVARON UN ABISMO A LA IZQUIERDA; EN EL
FRENTE ELLOS CAVARON UN HOYO TAN PROFUNDO COMO LA ALTURA DEL CIELO. ELLOS PUDIERON CAVAR
UN HUECO A LA DERECHA, OH. ELLOS PUDIERON CAVAR UN ABISMO A LA IZQUIERDA. ELLOS PUDIERON
CAVAR UN HOYO, TAN PROFUNDO, COMO LA ALTURA DEL CIELO; ELLOS NUNCA DIJERON QUE ALGUIEN NO
PUDIERA LLEGAR A SU CASA, GBAIN. ORÚNMILA ME LLEVÓ EN SU JABA, ME LLEVÓ EN SU BOLSO, POR
LO TANTO PODEMOS ESTAR JUNTOS. POR LO QUE DONDE QUIERA QUE VAYAMOS, PODREMOS ESTAR
JUNTOS." IFA NOS DICE QUE NOS CASAREMOS. TODO EL MUNDO TRATARA DE ENROLLARNOS Y DE
CAMBIARNOS Y CONSPIRARAN CONTRA NOSOTROS; PERO NO DEBEMOS TEMER. NOS CASAREMOS.''',
  '36. SE ADIVINÓ PARA ÉL ESCAPARSE DE LAS BRUJAS.': '''O KU GBE OHUN ORO, M-A RIN DODO OHUN OJINGBIN; OLOGBO NI FI ODUN SE ARA A DA FUN OMO A-R-
ESE SANSA TU-RUPE NWON NI AYA SANSA KAN L-O GBA? NWON NI AFI-BI O BA RU OBI MERINDINLOGUN,
ABO ADIE META, AWO DUDU TUN-TUN IGBA-DE-MU TUN TUN EGBETA; KO RU-BO O SI GBA AYA NA,
L-EHIN EYI EGBO DA SI ILE, EYI SI MU KI OKUNRIN NA KU. IFA NI ENI-TI A BA DA IFA YI FUN TI
KO BA RU, ARA-IYE YIO MA BA N-KAN RE JE. TRADUCCIÓN: "ÉL ESTÁ PERDIDO DE NOSOTROS POR LA
MUERTE, ES UN GRITO LLENO DE DOLOR; CAMINARÉ, HABLANDO CONMIGO EN MUY BAJA VOZ; EL GATO ES
EL UNICO QUE VISTE CON TELA DE RAFIA"FUE QUIEN ADIVINÓ FÁ PARA "ÉL ESPARCE EL LODO CON EL
PIE GRANDE" ELLOS PREGUNTARON: ¿ÉL VA A TOMAR COMO ESPOSA UNA MUJER DEBIDUCHA? ELLOS
DUERON QUE SERÍA MALO PARA ÉL SINO SACRIFICA DIECISÉIS KOLÁ-NUTS, TRES GALLINAS, UN PLATO
NEGRO Y NUEVO, UNA JÍCARA NUEVA PARA LAS BEBIDAS Y DINERO. ÉL NO HIZO EL SACRIFICIO. TOMÓ
LA MUJER COMO ESPOSA. DESPUÉS LAS LLAGAS LO CONFINARON EN LA CASA Y MURIÓ. IFÁ DICE QUE SI
LA PERSONA QUE LE SALGA ESTE SIGNO NO REALIZA EL SACRIFICIO, LAS BRUJAS LE DESTRUIRÁN ALGO
QUE TIENE.''',
  '37. SE ADIVINÓ PARA LA MADRE DE AGBONNIREGUN.': '''OWO T'ARA ESE T'ARA OTARATARA LO DIFA F'ELEREMOJU TI ESE IYA AGBONNIREGUN WON NI KI O RU
ABO ADIYE MEJI EYELE MEJI ATI ALESAN EGBERIDELOGUN OWO KIOFIBO IFA OMO RE WON NI: UWA RE A
S'URE O GBO O RU TRADUCCIÓN: LAS MANOS PERTENECEN AL CUERPO. LOS PIES PERTENECEN AL CUERPO
OTARARA ADIVINÓ EL ORÁCULO DE IFÁ PARA ELEREMOJÚ LA MADRE DE AGBONNIREGUN SE LE PIDIÓ QUE
SACRIFICARA: 2 GALLINAS, 2 PALOMAS Y 32,000 CAURIS PARA ALIVIAR EL NACIMIENTO DEL HUO.
DUERON QUE SU VIDA SERÍA PRÓSPERA. ELLA REALIZÓ EL SACRIFICIO. OWO TARA ESE TARA Y
OTARATARA SON LOS NOMBRES DE LOS AWOS QUE ADIVINARON Y CONSULTARON EL ORÁCULO DE IFÁ PARA
ELEREMOJÚ, LA MADRE DE AGBONNIREGUN, UNO DE LOS TÍTULOS DE ALABANZA DE ORÚNMILA.
ELEREMOJÚ, LA MADRE DE AGBONNIREGUN, ESTUVO DE ACUERDO CON HACER EL SACRIFICIO PARA
ALIVIAR A SU HIJO. ELLA TUVO PROSPERIDAD PUES EN EL SACRIFICIO IFÁ LO PRONOSTICÓ.''',
  '38. SE ADIVINÓ IFÁ PARA ELEREMOJÚ LA MADRE DE AGBONNIREGUN.': '''OTITOL OMIFI-NTE LE ISA. ADIVINÓ IFÁ PARA ELEREMOJÚ, LA MADRE DE AGBONNIREGUN. IFÁ DIJO:
QUE LOS IKINIS DEL HIJO LA PODRÍAN AYUDAR A ELLA, Y SE LE PIDIÓ QUE SACRIFICARA 1 JUTÍA, 1
GALLINA, 1 CHIVO, HOJAS DE IFÁ (EGBEE 16 DE ESE TIPO) SE HACE OMIERO PARA LAVARSE LA
CABEZA. ELLA OBEDECIÓ E HIZO EL SACRIFICIO. OTRO ADIVINADOR, OTITOL OMIFI-NTE LE ESA,
TAMBIÉN ADIVINÓ PARA ELEREMOJÚ, LA MADRE DE AGBONNIREGUN. IFÁ CONFIRMÓ QUE LOS IKINIS LA
AYUDARÍAN SI ELLA CONTINUABA HACIENDO LOS SACRIFICIOS. LOS ADIVINADORES DE IFÁ SON
OSAINISTAS O MÉDICOS DE LA VEGETACIÓN, SE CREE QUE SON BIEN DUCHOS EN LA MEDICINA
TRADICIONAL. Y SE CREE QUE TODAS LAS HIERBAS Y HOJAS EN EL MUNDO PERTENECEN A IFÁ. EL
CONOCIMIENTO DE SUS VALORES ESPIRITUALES, PUEDEN ENCONTRAR EN LAS ENSEÑANZAS DE IFÁ, EN
MUCHAS OCASIONES LOS ADIVINADORES DE IFÁ PRESCRIBEN HIERBAS Y PLANTAS PARA LAS CURAS O
PREVENCIÓN DE ENFERMEDADES. EN ESTE ODU, LAS HOJAS DE EGBEE SE RECOMENDARON PARA LA CABEZA
DE LAS PERSONAS QUE LO RIGE ESTE IFÁ. ALIMENTANDO ORÍ. ORÍ: SE CONSIDERA QUE ES LA DEIDAD
MÁS IMPORTANTE EN EL SER HUMANO, PUES SE ENCUENTRA EN LA CABEZA Y ES OUIEN CONTROLA
NUESTRO DESTINO.''',
  '39. SE ADIVINÓ PARA OGBONNIREGUN.': '''SEPARADAMENTE COMIERON MANÍ SEPARADAMENTE COMEN IMUMU (NUEZ ESPECIAL) TENEMOS LA CABEZA
SOBRE LOS PIES AL ENAMORARNOS DE OBA MAKIN. SE ADIVINÓ PARA OGBONNIREGUN SE LE DIJO QUE
SACRIFICARA PARA PODER TENER HIJOS. ÉL NO PODÍA IMAGINARSE LA CANTIDAD DE HUOS QUE PODRÍA
TENER. SE LE MANDÓ A SACRIFICAR: 1 CHIVA Y HOJAS DE IFÁ. SI ÉL HACÍA SACRIFICIO, DEBÍA
COCINAR LAS HOJAS DE IFÁ PARA SUS MUJERES. EL REALIZÓ EL SACRIFICIO. HOJAS DE IFÁ: MOLER
YENMEYENME (AGBONYIN) CON CONDIMENTOS CLAVOS Y OTROS MÁS, Y LAS TROMPAS DE FALOPIO DE LA
CHIVA. SE COLOCARÁ LA SOPERA DE SOPA FRENTE AL TRONO DE IFA Y HACER QUE SE LA COMAN SUS
MUJERES. CUANDO TERMINEN DE COMER ESTO, DE SEGURO COMENZARAN A TENER HUOS. LAS MUJERES DE
AGBONNIREGUN PENSABAN QUE ERA DIFICIL QUEDAR EMBARAZADAS. LOS ADIVINADORES HICIERON
HINCAPIÉ EN EL SACRIFICIO.''',
  '40. SE ADIVINÓ IFÁ PARA EL CAMPESINO Y EL PLÁTANO.': '''OKUNKUN-BIRIMUBIRIMU ADIVINÓ IFÁ PARA ENIUNKOKUNÚ, DIJO QUE NADIE HABÍA TENIDO UNA
DELICADEZA QUE ÉL NO RESPONDÍA CON UNA MALDAD. SE LE DIJO QUE SACRIFICARA UN MACHETE Y UNA
ESCALERA. ÉL NO QUISO SACRIFICAR. ENIUNKOKUNJÚ: ES EL NOMBRE DEL CAMPESINO. TODAS LAS
COSAS BUENAS QUE OGUEDE (PLÁTANO) FACILITABA AL CAMPESINO NO LO APRECIABA. EL CAMPESINO LE
CORTÓ LA CABEZA AL PLÁTANO. FÁ A MENUDO HABLA EN PARÁBOLA, ESTA HISTORIA REFLEJA UNA
RELACIÓN ENTRE EL PLÁTANO Y EL CAMPESINO, EL PLÁTANO QUE SIGNIFICA LA VERDAD Y EL
CAMPESINO LA INGRATITUD. LAS PERSONAS CON ESTE ODU SE CONSIDERAN QUE TIENEN LA CABEZA
SUELTA Y QUE TIENEN QUE PAGAR UN ALTO COSTO POR SU FORMA DE SER.''',
  '41. SE ADIVINÓ PARA CONSEGUIR ALGO BUENO EN LA VIDA.': '''K'ÁMÁFI KÁNJÚKÁNJÚ J'AYÉ. K'ÁM'FI WÀRÀWÀRÀ N'OKÙN ORÒ. OHUN A BÁ FI S'ÀGBÁ, K'Á MÁ FI SỀ
BÍNÚ. BÍ A BÁ DÉ BI T'Ó TÚTÙ, K'Á SIMI-SIMI. K'Á WÒ WAJÚ OJÓ LO TÍTÍ. K'Á TÚN BÒ WÁ R'ÈHÌN
ỜRÀN WÒ. NÍTORÍ ÀTI SÙN ARA ENI NI. NO NOS DEJES OCUPAR EL MUNDO A LA CARRERA. NO NOS
DEJES SUJETAR LA CUERDA DE LA RIQUEZA IMPACIENTEMENTE. QUE LO QUE DEBERÍA SER TRATADO CON
UN JUICIO MADURO, NO NOS DEJES TRATARLO CON UN ESTADO INCONTROLADO DE PASIÓN. CUANDO
LLEGUEMOS A UN LUGAR FRÍO, DÉJANOS DESCANSAR PLENAMENTE. DÉJANOS DAR ATENCIÓN CONSTANTE AL
FUTURO. DÉJANOS DAR PROFUNDA CONSIDERACIÓN A LAS CONSECUENCIAS DE LAS COSAS Y ESTO A CAUSA
DE NUESTRO EVENTUAL PASO. ÉSTA ES UNA ENSEÑANZA LA CUAL NOS HABLA DE QUE DEBEMOS DE TENER
UNA MEDIDA DIRIGIDA A CONSEGUIR LO BUENO DE LA VIDA. ESTO LO REFLEJA EL HINCAPIÉ QUE HACE
EL ODU EN LA VIRTUD DEL IWÒN Ó EQUILIBRIO, Y EL AMÚWÒN Ó LA PERSONA EQUILIBRADA. NOSOTROS
NO OCUPAMOS LA TIERRA APRESURADAMENTE, DESPREOCUPADOS O DE MANERA IMPRUDENTE. NI NOSOTROS
BUSCAMOS LAS GANANCIAS MATERIALES IMPACIENTEMENTE. AUNQUE LA ÉTICA DEL ODU POSEE RIQUEZA
COMO UNA DE LAS BENDICIONES PRINCIPALES DE LA VIDA TANTO COMO UNA IMPORTANTE CONDICIÓN
PARA VIVIR UNA VERDADERA VIDA PLENA Y UN SIGNIFICADO PARA AYUDAR Y COMPARTIR CON LOS
OTROS, EXISTE UN INTERES CONTINUO DE PERSEGUIR LAS GANANCIAS MATERIALES NO EXCESIVAS Ó
CONSUMIDAS. LO BUENO O LA VIDA MORAL, LA ENSEÑANZA NOS DICE, QUE TAMBIÉN SE NECESITA QUE
NOSOTROS TRATEMOS LOS ASUNTOS IMPORTANTES CON LA RAZONABILIDAD Y LA CALMA QUE SE
REQUIERAN. ADEMAS EL TEXTO NOS SUGIERE QUE LO BUENO DE LA VIDA TAMBIEN REQUIERE QUE
NOSOTROS SEPAMOS CUANDO Y COMO DESCANSAR. ESTO PLANTEA EL DESCANSO COMO UNA CONDICIÓN
ESENCIAL NO SOLO PARA LA BUENA VIDA EN GENERAL, SINO TAMBIEN ESPECÍFICAMENTE PARA LA SERIA
MORAL Y LA REFLEXIÓN CRÍTICA. FINALMENTE, EL TEXTO NOS DICE QUE NOSOTROS DEBERÍAMOS DAR
PLENA Y DESARROLLADA ATENCIÓN AL FUTURO Y EL ESTAR CONSTANTE Y PROFUNDAMENTE INTERESADOS
EN LAS CONSECUENCIAS DE LAS COSAS. ESTA MORAL DUAL ENFATIZA AL HABLAR DE NUESTRA NECESIDAD
DE ESTAR INTERESADOS POR EL EFECTO DE NUESTRAS ACCIONES, NO SOLO EN LA CALIDAD DE LA VIDA
Y LAS RELACIONES EN EL MUNDO CONTEMPORÁNEO, SINO TAMBIÉN EN EL FUTURO DEL MUNDO Y LAS
GENERACIONES VENIDERAS. Y DE ESE MODO, ESTA MORAL PARTICULAR NO SIGNIFICA SÓLO LA CALIDAD
DE LAS RELACIONES HUMANAS, SINO LA INTEGRIDAD DEL MEDIO AMBIENTE. TAL MORAL CONCIERNE
SEGÚN NOS SUGIERE EL TEXTO. EN ABRAZAR NO SOLO LA BUENA VIDA AQUÍ, SINO TAMBIÉN ASEGURAR
NUESTRO LUGAR EN LA ETERNIDAD DANDO NUESTRO PASE EVENTUAL. EN UNA PALABRA, HABLA DE
NUESTRA NECESIDAD DE VIVIR LA VIDA QUE DEJA UN LEGADO DE BONDAD EN ESTE MUNDO LO QUE NO
SÓLO PROMETE RESPETO A LA MEMORIA EN ESTE MUNDO SINO TAMBIÉN LA VIDA ETERNA EN LA PRÓXIMA.''',
  '42. SE ADIVINÓ IFÁ PARA LA MODERACIÓN.': '''ÒRÚNMÌLA NÍ Ó DI KÉRÉKÉRÉ. ÈMI NÍ KÉRÉKÉRÉ L'ÀÁ J'ORÍ EJA. AKÍ IGBÀ TOBI T'ERIN, A KÍ SE
YÈKÈTÈ T'ÉFÒN. ỜIÁ KÍ IT'ÓJA IGBA LÉ. ELÚ K'ÉLÚ KÍ IT'ÓNI IFE. OKÙN OWÓ EYO KÍ IT'ÓKÙN
YEMIDEREGBE. YEMIDEREGBE L'ORÚKO A P'ÓLÓKUN. ỜRÚNMÌLÀ NI K'Á WÒN N'ÌBÚ K'Á WÒN N'ÌRÓ.
GBOGBOROGBO L'OWÓ YO J'ORÍ. GBOGBOROGBO NI MÀRÌWÒ OPE YO J'OGOMO IGBÓ KÍ DÍ KÍ ÌRÓKÒ KÍ Ó
MÁ YO. A KÍ IK'ERÉ JO KÍ T'AGOGO KÍ Ó MÁ YO. TRADUCCIÓN ORÚNMILA DICE QUE DEBERÍA SER
HECHO POCO A POCO. YO DIJE QUE POCO A POCO NOSOTROS COMEMOS LA CABEZA DEL PESCADO.
NOSOTROS NO SOMOS TAN LARGOS COMO EL ELEFANTE NI TAN ROBUSTOS COMO EL BÚFALO. LA FAJA
GASTADA POR DEBAJO NO ES IGUAL A LA FAJA GASTADA EN LA SUPERFICIE. NINGÚN NOBLE ES TAN
GRANDE COMO EL ONI DE IFE. NINGUNA CUERDA DE CARACOLES ES TAN LARGA COMO EL YEMIDEREGBE.
YEMIDEREGBE ES LO QUE NOSOTROS LLAMAMOS EL DUEÑO DEL MAR. ORÚNMILA DICE QUE NOSOTROS
DEBERÍAMOS MEDIR LA LONGITUD Y LA MEDIDA DE LA ANCHURA DE LAS COSAS. LA MANO ALCANZA MAS
ALTO QUE LA CABEZA. Y LAJOVEN Y FRONDOSA PALMERA SE EXTIENDE MAS ALTO QUE LA VIEJA PALMERA
FRONDOSA. PERO NINGÚN BOSQUE ES TAN DENSO QUE EL ÁRBOL DE IROKO NO PUEDE SER VISTO. Y
NINGUNA CELEBRACIÓN ES TAN ALTA QUE EL GONG NO PUEDE SER OIDO. ESTA ES UNA ENSEÑANZA SOBRE
LA MODERACIÓN EN NUESTRA CONSIDERACIÓN DE LA VIDA Y EN NUESTRA VERDADERA EVALUACIÓN DE
NUESTRAS HABILIDADES, POTENCIAS Y POSIBILIDADES. COSAS QUE DEBERÍAN DE SER HECHAS "POCO A
POCO"O "PASO A PASO", EL TEXTO NOS LO DICE. CADA MEDIDA CONSIDERADA NOS PERMITE HACER
EVALUACIONES ADECUADAS EN NUESTROS COMPROMISOS Y ENTENDIMIENTO DE LAS COSAS. PARA LA
METÁFORA DE LA FAJA POR DEBAJO DE LA SUPERFICIE REQUIERE NUESTRA IDA POR DEBAJO DE LA
SUPERFICIE PARA VER LA DIFERENCIA Y LA DISTINCIÓN. Y, REALMENTE, EL EXAMEN DE CADA
SITUACIÓN PROPIA, REQUIERE PROFUNDA REFLEXIÓN. ESTE VERSO TAMBIÉN NOS ENSEÑA QUE AUNQUE NO
DEBEMOS SOBREESTIMARNOS, NOSOTROS DEBEMOS DETERMINAR NUESTRAS POSIBILIDADES, SEGUIRLAS Y
HACER NUESTRA PROPIA CONTRIBUCIÓN AL CONJUNTO. DE ESTE MODO, NOSOTROS NO PODEMOS SER TAN
LARGOS COMO UN ELEFANTE O ROBUSTOS COMO UN BÚFALO, PERO NOSOTROS TENEMOS NUESTRAS PROPIAS
FUERZAS. NOSOTROS NO SOMOS EL REY DE IFE; NI TENEMOS LAS RIQUEZAS DEL MAR, PERO TENEMOS
REALEZA EN LA RECTITUD Y LA RIQUEZA DEL BUEN CARÁCTER. Y SI NOSOTROS NO SOMOS
INTELECTUALES, DEBEMOS CONTINUAR USANDO NUESTRAS CABEZAS PARA EL CAMINO, PODEMOS ENCONTRAR
EL TRABAJO MAS ALTO EN NUESTRAS MANOS QUE PUEDEN ALCANZAR Y HACER. ADEMÁS, LA ENSENANZA
SUGIERE QUE EXISTEN VENTAJAS DE SER JOVEN Y ANCIANO. LA VIEJA PALMERA FRONDOSA HA DEFINIDO
Y REFORZADO EL ARBOL, PEROLA JOVEN PALMERA FRONDOSA, CONSTRUIDA SOBRE LA BASE, DEBE
ENCONTRAR SU SIGNIFICADO ADELANTÁNDOSE MAS ALLÁ Y MAS ALTO. Y, FINALMENTE, EL TEXTO NOS
ENSEÑA QUE EN MEDIO DE TODO, LO DISTINTO, POR DEFINICION DESTACA. DE ESTE MODO, NINGUN
ASUNTO COMO LA DENSIDAD DEL BOSQUE, EL IROKO O ÁRBOL AFRICANO DE LA TECA DESTACARÁ SIN
REPARAR EN LA ALTITUD DE LA CELEBRACIÓN, EL GONG DESAFIARÁ SER OÍDO. EN CONCLUSIÓN,
NOSOTROS DEBEMOS CONSIDERAR LA VIDA Y LAS COSAS ANTE NOSOTROS EN UN CAMINO DE MEDIDA Y
REFLEXIÓN. Y NOSOTROS NO DEBEREMOS INMOVILIZARNOS O DESANIMARNOS POR QUE NOSOTROS NO
PODAMOS SER O HACER, SINO QUE MÁS BIEN DESCUBRIR Y LIMPIAR NUESTROS PROPIOS SENDEROS DE
POSIBILIDADES Y PERSEGUIRLOS.''',
  '43. SE ADIVINÓ IFÁ PARA SABER ESPERAR, PARA ENCONTRAR LO BUENO.': '''IMO DÉ RE. MO RÍN RERE. ÈMI NÌKAN NI MO MÒ RIN ÀRÌNKÒÓRIN. À SÈSÈ 'NKÓHUN ORÒ SÌLÈ, NI MO
WOLÉ WÉRÉ BÍ OMO OLÓHUN. ÈMI ÈÉ S'OMO OLÓHUN. TRIN ÀRÌNKÒ NI MO MÒO RÌN. TRADUCCIÓN. LLEGÓ
BIEN. VIAJO BIEN. YO SOY UNO QUE NORMALMENTE VIAJA Y ENCUENTRA FORTUNA. COMO ELLOS
ESTUVIERON FIJANDO RIQUEZAS, YO ENTRÉ SIN VACILACIÓN COMO LA DESCENDENCIA DE UN
PROPIETARIO. PERO YO NO SOY DESCENDENCIA DE UN PROPIETARIO. YO SOY SOLO UNO QUE SABE COMO
VIAJAR Y ENCUENTRA BUENA FORTUNA. ESTE ODU NOS ENSEÑA LA VIRTUD DE ESPERAR Y ENCONTRAR LO
BUENO DONDEQUIERA QUE NOSOTROS VAYAMOS. ESTO DICE QUE VIAJAR BIEN Y LLEGAR BIEN
PERMITIENDO O DEJANDO ENCONTRAR A UNO BUENA FORTUNA. EL TEXTO SUGIERE QUE LA CLAVE PARA
VIAJA Y LLEGAR BIEN ES UNA ACTITUD POSITIVA PARA ESPERAR Y ENCONTRAR LO BUENO EN EL MUNDO.
ESTO TAMBIÉN SUGIERE QUE CUANDO NOSOTROS ENCONTRAMOS LOS BUENO EN EL MUNDO NOSOTROS
DEBERÍAMOS AUDAZ Y CONFIDENCIALMENTE TENDER LA MANO PARA ABRAZARLO Y PARTICIPAR EN ELLO.
ESTE ES EL SIGNIFICADO DE LA LÍNEA QUE DICE LA PERSONA EN EL TEXTO "ENTRÉ SIN VACILACIÓN
COMO LA DESCENDENCIA DE UN PROPIETARIO": PERO COMO LA PERSONA DICE, ÉL O ELLA NO ERA
DESCENDENCIA DEL PROPIETARIO, SOLO "UNO QUE SABE COMO VIAJAR Y ENCONTRAR BUENA FORTUNA" DE
NUEVO LA LECCIÓN CLAVE AQUÍ ES QUE ENCONTRAR BUENA FORTUNA O BONDAD EN EL MUNDO EMPIEZA
CON UNA ACTITUD POSITIVA, UN SENTIDO NECESARIO DE POSIBILIDAD QUE CULMINA CON UNA AUDAZ Y
CONFIDENTE AUTOAFIRMACIÓN EN EL MOMENTO CORRECTO PARA ABRAZAR Y PARTICIPAR EN LO BUENO DEL
MUNDO. Y ESTO, POR SUPUESTO, ES UNA REAFIRMACIÓN DEL SENTIDO DE LA DELEGACIÓN HUMANA QUE
ES LA CLAVE PARA LA ÉTICA DEL ODU Y LA ESPIRITUALIDAD.''',
  '44. SE ADIVINO IFÁ PARA LA ENSEÑANZA DE ODU, OBARISA Y OGÚN.': '''A DÍFÁ FÚN ODÙ, ÒBÀRÌSÀ ÀTI ÓGÚN NUÓ TI ÀWÒN NTI'KOLE ORUN BÒ WÁ ILÉ AYÉ. ODÙ NÍ: ÎWO
OLÓDUMARÈ; Ó NÍ, ILÉ AYÉ L'ÀWON NLO YIÍ ¿ Ó NÍ, NÍGBÀTÍ ÀWON BÁ DÉ ÒH'N NKÓ? OLÓDÙMARE NÍ
KÍ WÓN Ó LO MÁA SE ILÉ AYÉ KÍ ILÉ AYÉ Ó DÁRA. Ó NÍ GBOGBO OHUN TI WON YIO BÁ SÌ MÁA, Ó NÍ
ÒUN Ó FÚN WON L'ASE TI WÓN Ó MÁA FI SEE, TI YÌO SÌ FI MÁA DÁRA. ODÙ NÍ: ÎWO OLÓDÙMARE; ILÉ
AYÉ T'ÀWON NLO YÌĨ, ÒGÚN L'ÁGBÁRA OGUN JÍJA. Ó NÍ: ÒBÀRÌSÀ, ÒUN NÁÀ L'ASE LÀTI ÌSE GBOGBO
OHUN T'Ó BÁ FÉ SE. ¿Ó NÍ KÍNI AGBÁRA TI ÒUN? OLÓDÙMARÈ NÍ "ÌWO L'Ó MÁA JÉ IYÁ WON LO
LÁÍLÁÍ. Ó NÍ ÌWO NI O Ó SÌ MÚ ILÉ AYÉ RÓ." OLÓDÙMARÈ L'Ó BÁ FÚN ÒUN L'ÁGBÁRA. NÍGBÀTÍ Ó
FÚN ÒUN L'ÁGBÁRA, Ó FÚN ÒUN L'ÁGBÁRA EYE. NI Ó GBÉ FÚN OBÌNRIN L'ASE WÍPÉ GBOGBO OHUN YÌO
WÙ, OKÙNRIN KÒ GBÓDÒ LÈ DÁ NKANNKAN SE L'ÉHÌN OBÌNRIN. ODÙ NÍ GBOGBO OHUN TI ÈNÌYÀN BÁ
NSE, TI KÒ BÁ FI TI OBÌNRIN KÚN UN, ÓNÍ Ò LÈ SE SE. ÒBÀRÌSÀ NÍ KÍ WÓN Ó MÁA FI IBÀ FÚN
OBÌNRIN Ó NÍ TI WÓN BÁ TI NFI ÌBÀ FÚN OBÌNRIN, ILÉ AYÉ YÌO MÁA TÒRÒ. E KÚNLÈ O; E KÚNLÈ
F'ÓBÌNRIN, O. OBÌNRIN L'Ó BÍ WA K'ÁWA TÓ D'ÈNÌYÀN. OGBÓN AYÉ T'ÓBÌNRIN NI. E KÚNLÈ
F'ÓBÌNRIN. OBÌNRIN L'Ó BÍ WA K'ÁWA TÓ D'ÈNÌYÀN. ÉSTA ES LA ENSEÑANZA DE IFÁ PARA ODU,
OBARISA Y OGÚN, CUANDO ELLOS VENÍAN DEL CIELO A LA TIERRA. ODU PREGUNTÓ: "OH OLODUMARE;
SEÑOR DEL CIELO, ESTA TIERRA DONDE NOSOTROS VAMOS, ¿ QUÉ SUCEDERÁ CUANDO NOSOTROS
LLEGUEMOS?" OLODUMARE LES DIJO QUE ELLOS IBAN A HACER EL MUNDO ASÍ QUE EL MUNDO SERÍA
BUENO. EL TAMBIÉN DIJO TODO LO QUE ELLOS IBAN A HACER ALLÍ, ÉL LES DARÍA EL ASE, PODER Y
AUTORIDAD, PARA REALIZARLO, ASÍ QUE SERÍA HECHO BIEN. ODU DIJO:"OH OLODUMARE ÉSTA TIERRA
DONDE VAMOS, OGÚN TIENE EL PODER PARA EMPRENDER LA GUERRA. Y OBARISA TIENE EL ASE PARA
HACER TODO LO QUE ÉL DESEA HACER. ¿CUÁL ES MI PODER? OLODUMARE DIJO: "TÚ SERÁS SU MADRE
POR SIEMPRE. Y TÚ TAMBIÉN SUSTENTARÁS EL MUNDO." OLODUMARE, ENTONCES, LE DIO EL PODER. Y
CUANDO ÉL LE DIO EL PODER, ÉL LE DIO EL PODER DEL ESPIRITU DEL PÁJARO. FUE ENTONCES CUANDO
ÉL DIO A LAS MUJERES EL PODER Y LA AUTORIDAD DE MODO QUE CADA COSA QUE LOS HOMBRES
DESEARAN HACER, ELLOS NO PODRÍAN HACERLO EXITOSAMENTE SIN LAS MUJERES. ODU DICE QUE TODO
LO QUE LA GENTE DESEARÁ HACER, SI ELLOS NO INCLUYEN A LAS MUJERES, NO SERÁ POSIBLE.
OBARISA DICE QUE LA GENTE DEBERIA SIEMPRE RESPETAR A LAS MUJERES SUMAMENTE. SI ELLOS
SIEMPRE RESPETAN A LAS MUJERES SUMAMENTE, EL MUNDO ESTARÁ EN RECTO ORDEN. RENDIR HOMENAJE;
DAR RESPETO A LAS MUJERES EFECTIVAMENTE, FUE UNA MUJER LA QUE NOS LLEVÓ DENTRO ANTES DE
QUE NOSOTROS LLEGÁSEMOS A SER RECONOCIDOS COMO SERES HUMANOS. LA SABIDURÍA DEL MUNDO
PERTENECE A LAS MUJERES. DA RESPETO A LAS MUJERES POR TANTO. EFECTIVAMENTE, FUE UNA MUJER
LA QUE NOS LLEVÓ DENTRO ANTES DE QUE NOSOTROS LLEGÁSEMOS A SER RECONOCIDOS COMO SERES
HUMANOS. ESTE VERSO ES UNA ENSENANZA SOBRE LA COOPERACIÓN EN LA CREACIÓN DEL MUNDO. ESTE,
COMO EL ODU OSE TURA, NOS PROPORCIONA UN SEGMENTO CRÍTICO DE LA NARRACIÓN DE LA CREACIÓN,
EXPONIENDO EL ORDEN DE LAS COSAS EN EL PRINCIPIO Y EL ESTABLECIMIENTO DEL PRINCIPIO DE LA
IGUALDAD FEMENINA Y MASCULINA EN LA CREACIÓN, LA ESTRUCTURA Y EL FUNCIONAMIENTO DEL MUNDO
Y DE TODAS LAS COSAS IMPORTANTES. EL ODU ABRE CON OLODUMARE, SEÑOR DEL CIELO Y FUENTE DE
TODOS LOS SERES, ENVIANDO TRES SERES DIVINOS (OGUN, OBAORISA Y ODU) PARA COMPLETAR EL
TRABAJO DE LA CREACIÓN. SOBRE ESTE PUNTO, COMO OTRO TEXTO NOS DICE, EL MUNDO ES SÓLO UNA
POSIBILIDAD PANTANOSA Y AGUADA. OLODUMARE POR ESO ENVIÓ A ALGUIEN DIVINO PARA HACER EL
MUNDO BIEN Y DARLES EL ASE Y ASÍ ELLOS PODRÍAN HACER BIEN SU TRABAJO. LA PALABRA USADA
AQUÍ ES "DARA"QUE SIGNIFICA "BIEN", NO SOLO EN EL SENTIDO DE BENEFICIOSA Y CONVENIENTE
PARA UN PROPÓSITO, SINO TAMBIÉN AGRADABLE Y DIVERTIDA. AQUÍ TENEMOS LA AFIRMACIÓN DE LA
BONDAD INHERENTE DEL MUNDO, UNA BONDAD INHERENTE QUE DIOS ORDENÓ EN EL COMIENZO DE LA
CREACIÓN. EN SEGUNDO LUGAR, NOSOTROS ESTAMOS ENSEÑANDO QUE LOS SERES DIVINOS REPRESENTAN
LO MASCULINO Y FEMENINO EN EL PRINCIPIO DEL MUNDO, CADA IGUAL TODAVÍA CON DIFERENTE PODER
Y AUTORIDAD, ASE, USADO PARA COMPLETAR LA CREACIÓN COOPERATIVAMENTE. ESPECIAL ATENCION,
SIN EMBARGO, ES DADA PARA DEFINIR EL PAPEL PRINCIPAL FEMENINO O DE LA MUJER EN EL MUNDO.
DOS PAPELES PRINCIPALES SON ASIGNADOS A LA MUJER - MADRE Y SUSTENTO DE LA TIERRA- SER
MUJER DEL MUNDO SE REFIERE CLARAMENTE A UN ESFUERZO COMBINADO CON EL PADRE DEL MUNDO PARA
REPRODUCIR Y ASEGURAR LA CONTINUIDAD Y EL ALIMENTO, EL CUIDADO Y LA ENSEÑANZA. PERO SER EL
SUSTENTO DEL MUNDO ES UN GRAN PAPEL Y RICO EN POSIBILIDADES DE INTERPRETACIÓN. SIN EMBARGO
OTROS TEXTOS HABLAN ACERCA DE QUE ÉSTE PAPEL ESTÁ POR ENCIMA DE TODO LO RELATADO POR EL
CREADOR Y GUARDIÁN DE LA CULTURA, ENSEÑANZA, REFINAMIENTO Y FLORECIMIENTO DE LA HUMANIDAD
Y EL MUNDO, EL CUAL INCLUYE UNA VASTA ESFERA DE LA RESPONSABILIDAD SOCIAL QUE SE EXTIENDE
DESDE LAS NORMAS DEL GOBERNANTE A LA EDUCACIÓN. ESTO QUE DECIMOS ES REAFIRMADO POR EL
HECHO DE QUE EN EL ODU OSHE-TURA A OSHÚN SE LE DICE QUE ES LA ENCARNACIÓN DE LA CULTURA,
LA ENSEÑANZA Y EL FLORECIMIENTO HUMANO, QUE ACOMPAÑA A LA PODEROSA DIVINIDAD MASCULINA
(ORÚNMILA) PARA HACER EL MUNDO. EL VERSO QUE AQUÍ ESTAMOS DESARROLLANDO DA VUELTAS A UNA
ENSEÑANZA SOBRE EL ESPECIAL RESPETO QUE NOSOTROS DEBERÍAMOS TENER A LAS MUJERES COMO
COMPAÑERA INDISPENSABLES PARA EL ÉXITO, TODO AQUELLO QUE LOS HOMBRES INTENTEN HACER Y PARA
EL RECTO ORDEN DEL MUNDO. FINALMENTE, EL VERSO HACE HINCAPIÉ EN EL ESPECIAL RESPETO QUE
NOSOTROS DEBERÍAMOS MANTENER A TODAS LAS MUJERES COMO MUJERES. EN UN SENTIDO, ESTA
REAFIRMACIÓN DE LA NECESIDAD DE RESPETAR A LAS MUJERES COMO MADRE Y SUSTENTO, NO SÓLO EN
EL AMPLIO SENTIDO DEL MUNDO, SINO QUE ESPECIALMENTE EN EL PERSONAL Y PROFUNDO SENTIDO
HUMANO QUE NOS TRAE EN LO PSÍQUICO Y SOCIAL, SERES CULTURALES. DE NUEVO EN LA MEJOR
TRADICIÓN DE IFÁ Y DE LA TRADICIÓN AFRICANA EN GENERAL, TODOS LOS HUMANOS, HOMBRES Y
MUJERES, TIENEN IGUAL E INHERENTE HUMANIDAD O DIGNIDAD. PERO AQUÍ EL TEXTO NOS SUGIERE DAR
UN RESPETO AÑADIDO A LAS MUJERES, POR SU PAPEL DE TRAERNOS COMO SERES ANTES DE QUE
FUÉRAMOS RECONOCIDOS COMO HUMANOS. EL TEXTO LITERALMENTE DICE "ANTES QUE FUERAMOS SERES
HUMANOS". ESTE PERIODO DE NO SER RECONOCIDOS COMO SERES HUMANOS PARECE, HACER REFERENCIA
AL PERIODO PARA LOS YORUBAS Y EL DE OTRAS SOCIEDADES AFRICANAS ANTES DE QUE EL BEBÉ HAYA
SIDO INCORPORADO A LA SOCIEDAD. ES EL MOMENTO EN QUE EL BEBÉ NO TIENE NOMBRE Y SOLO ES
POTENCIALMENTE UNA PERSONA. DESPUÉS DE SIETE U OCHO DÍAS, CUANDO EL NIÑO APARECE COMO UN
MIEMBRO PERMANENTE DE LA FAMILIA, ÉL O ELLA RECIBE UN NOMBRE Y UN ESTATUS Y DE ESE MODO,
ES" RECONOCIDO COMO SER HUMANO'NO UN ESPÍRITU O ÀBÍKÚ, UN REACIO A VIVIR EN EL MUNDO
MATERIAL. EN ESTE PERIODO DE TRANSICIÓN Y POSIBILIDADES, ES NUESTRA MADRE QUIEN NO SÓLO
NOS TRAE COMO SERES PSÍQUICOS, SINO COMO COMIENZO DEL PROCESO DE CRIANZA CULTURAL QUE
COLOCA LAS BASES DE NUESTRA INCORPORACION SOCIAL. EN UNA PALABRA, ELLA NOS MOLDEA A IMAGEN
E INTERÉS DE LA SOCIEDAD HUMANA. Y POR ESTO ELLA NOS DA PSÍQUICO Y CULTURAL NACIMIENTO POR
EL QUE EL VERSO NOS DICE QUE NOSOTROS DEBERIAMOS RESPETARLA DE ESPECIAL Y SIGNIFICATIVA
MANERA. ADEMÁS EL VERSO NOS CUENTA QUE NOSOTROS DEBERÍAMOS RESPETAR A LAS MUJERES COMO LAS
QUE POSEEN LA SABIDURÍA EN EL MUNDO. ESTO, EN LA NARRATIVA TEOLÓGICA DE IFÁ, SE REFIERE AL
PODER ESPECIAL DE CONOCIMIENTO Y ESPÍRITU PODEROSO SIMBOLIZADO POR EL PÁJARO DADO A LAS
MUJERES POR EL SEÑOR DEL CIELO, OLODUMARE, AL PRINCIPIO DE LA CREACIÓN. LA OBLIGACIÓN
MORAL AQUÍ DADA ES LA DE RESPETAR A LAS MUJERES EN SU CONJUNTO PSÍQUICAMENTE Y
CULTURALMENTE AL TRAER SERES HUMANOS. Y ESTO REAFIRMA LA IGUALDAD E INDISPENSABILIDAD DE
LAS MUJERES EN LA ESTRUCTURA Y FUNCIONAMIENTO DEL MUNDO Y DEL DESARROLLO REQUERIDO DE LA
COOPERACIÓN MASCULINA Y FEMENINA EN UN IMPORTANTE PROYECTO.''',
  '45. LA RECEPCION DE OLOFIN.': '''PATAKI: OLOFIN EXTENDIÓ UNA INVITACIÓN A TODOS LOS REYES (LOS 16 MEYIS) PARA UNA RECEPCIÓN
EN SU PALACIO. TODOS SE VISTIERON LUJOSAMENTE Y DISFRUTARON DE LA COMIDA, BEBIDA Y
ENTRETENIMIENTO, EXCEPTO BABA EJIOGBE, QUIEN, DEBIDO A SU DIFÍCIL SITUACIÓN, NO PUDO
UNIRSE A LA FIESTA. SIN EMBARGO, INGRESÓ AL PALACIO POR LA PUERTA TRASERA DESPUÉS DE QUE
LA RECEPCION HUBIERA CONCLUIDO. AL DARSE CUENTA DE QUE OLVIDARON GUARDARLE COMIDA Y AL
EXPERIMENTAR HAMBRE, SE SENTÓ JUNTO AL CUBO DE BASURA PARA DISFRUTAR DE LAS CABEZAS DE
PESCADO QUE ENCONTRÓ EN LA COCINA. OLOFIN ENTRÓ EN LA COCINA Y, AL VER A EJIOGBE, LE
PREGUNTÓ: "HIO MÍO, ¿QUÉ HACES AQUÍ?". EJIOGBE RESPONDIÓ: "PAPÁ, NO PUDE UNIRME A USTEDES
COMO ERA MI DESEO PORQUE MIRA MI SITUACIÓN, ESTOY TAN POBRE QUE NI SIQUIERA TENGO ROPA
ADECUADA PARA PONERME. SIN EMBARGO, NO QUERÍA DESAIRARTE, ASÍ QUE VINE Y ENTRÉ POR LA
PUERTA TRASERA PORQUE SABÍA QUE ME VERÍAS". AL VER LO QUE EJIOGBE ESTABA COMIENDO, OLOFIN
PREGUNTÓ: "¿NO TE GUARDARON TU COMIDA?". ÉL RESPONDIÓ: "SÍ, PAPÁ, ESTA ES LA COMIDA QUE ME
GUARDARON", Y LE MOSTRÓ LAS CABEZAS DE PESCADO. ENTONCES, OLOFIN EMPEZÓ A CANTAR: "EYA
TUTO YOMILO, EYA TUTO YOMILODUARA DUARA, EYA TUTO YOMILO". Y OLOFIN DIJO: "EJIOGBE, PUESTO
QUE COMES CABEZAS, DESDE HOY CABEZA SERÁS Y TAMBIÉN CABEZA DE TODOS LOS BABALAWOS". REZO:
S HINI YEPO SHONWENIYE SHINWINI SHINWINI LA KOTORI ONIBABALAWO ADIFAFUN ORÚNMILA UMBATINLO
ILE EYA TUTOWILAWO ORÚNMILA ORUBO. EBO AKUKO FUN-FUN FYELE MEYLEUN FUN AIKORDIF MENI
EYATUTO GANGAO ORI EFUN FPO, EKO, OKUN, EYA, AWADO, OKO MENI, GBOGBO TENUYEN, OPOLOPO OWO.
NOTA: AQUÍ ES DONDE EJIOGBE SE CONVIERTE EN EL PRIMER REY. ENSENANZAS: LA ENSEÑANZA
PRINCIPAL DE ESTA HISTORIA ES LA IMPORTANCIA DE LA HUMILDAD Y LA ACEPTACIÓN DE LAS
CIRCUNSTANCIAS, ASÍ COMO LA VALORACIÓN DE LO ESENCIAL SOBRE LO SUPERFICIAL. AQUÍ HAY
ALGUNOS PUNTOS CLAVE QUE ILUSTRAN LA LECCIÓN: HUMILDAD EN LA ADVERSIDAD: A PESAR DE LA
DIFÍCIL SITUACIÓN DE BABA EJIOGBE, DEMUESTRA HUMILDAD AL NO QUERER DESAIRAR A OLOFIN Y
DECIDIR UNIRSE A LA RECEPCIÓN DE ALGUNA MANERA. ACEPTACIÓN DE LA REALIDAD: EJIOGBE ACEPTA
SU REALIDAD Y EXPLICA HONESTAMENTE A OLOFIN POR QUÉ NO PUDO UNIRSE A LA FIESTA DE MANERA
CONVENCIONAL. EN LUGAR DE TRATAR DE APARENTAR ALGO QUE NO ES, ELIGE SER HONESTO SOBRE SU
SITUACIÓN. VALORACIÓN DE LO ESENCIAL: AUNQUE EJIOGBE NO PUDO DISFRUTAR DE LA COMIDA
PRINCIPAL DE LA RECEPCIÓN, ENCUENTRA SATISFACCIÓN Y ALEGRÍA EN LAS CABEZAS DE PESCADO QUE
LE GUARDARON. ESTO DESTACA LA IMPORTANCIA DE VALORAR LO ESENCIAL Y ENCONTRAR
CONTENTAMIENTO EN LAS PEQUENAS COSAS. RECONOCIMIENTO DE LA VERDAD: CUANDO OLOFIN DESCUBRE
LA SITUACIÓN DE EJIOGBE Y LO QUE ESTÁ COMIENDO, EN LUGAR DE REGAÑARLO, RECONOCE LA VERDAD
DE SU CONDICIÓN Y TOMA UNA DECISIÓN BASADA EN ESA VERDAD. TRANSFORMACIÓN A TRAVÉS DE LA
ACEPTACIÓN: LA TRANSFORMACIÓN DE EJIOGBE EN EL PRIMER REY SURGE NO A PARTIR DE LA
OPULENCIA DE LA RECEPCIÓN, SINO DE SU HUMILDAD, ACEPTACIÓN DE LA REALIDAD Y SU CAPACIDAD
PARA ENCONTRAR ALEGRÍA INCLUSO EN CIRCUNSTANCIAS MODESTAS. LA HISTORIA DESTACA QUE LA
VERDADERA GRANDEZA Y HONOR PROVIENEN DE LA AUTENTICIDAD, LA HUMILDAD Y LA CAPACIDAD DE
ENCONTRAR SATISFACCIÓN EN LAS CIRCUNSTANCIAS, INDEPENDIENTEMENTE DE SU COMPLEJIDAD.''',
  '46. CUANDO HABÍA DOS PODEROSOS PUEBLOS.': '''PATAKI: EXISTIAN DOS PODEROSOS PUEBLOS QUE SE ENCONTRABAN INMERSOS EN UNA GUERRA CONSTANTE
ENTRE SÍ, Y OLOFIN, CANSADO DE ESTA SITUACIÓN, ENVIÓ A DIFERENTES ORISHAS CON EL OBJETIVO
DE LOGRAR LA PAZ ENTRE AMBAS NACIONES. SIN EMBARGO, ESTAS INTERVENCIONES SOLO CONSEGUÍAN
INSTAURAR UNA PAZ TEMPORAL. ANTE TAL SITUACIÓN, OLOFIN DECIDIÓ ENVIAR A SU HIJA
PREDILECTA, OSHÚN, CON LA MISIÓN DE ALCANZAR LA PAZ PERMANENTE ENTRE LOS DOS PUEBLOS, SIN
IMPORTAR EL COSTO. OSHÚN SE VIO OBLIGADA A CONVIVIR CON LÍDERES Y SOLDADOS DE AMBOS
EJÉRCITOS EN SU BÚSQUEDA INCANSABLE POR LOGRAR LA TAN ANHELADA PAZ. SIN EMBARGO, SU
EXPERIENCIA RESULTÓ DESGASTANTE Y DESAGRADABLE, LO QUE LA LLEVÓ A RETIRARSE A UN RÍO
APARTADO. FUE EN ESTE LUGAR DONDE SURGIÓ EL AVATAR DE OSHÚN YEMÚ. YEMAYÁ, AL PERCATARSE DE
LA SITUACIÓN, ACUDIÓ EN SU BÚSQUEDA PARA BRINDARLE CUIDADOS Y ATENCIÓN EN SU HOGAR. UNA
VEZ RECUPERADA PERO SIN ADAPTARSE AL CARÁCTER SALADO DE LAS AGUAS DE YEMAYA, OSHÚN DECIDIÓ
REGRESAR A SU RÍO. ORÚNMILA, QUIEN ESTABA AL TANTO DE TODO, SE ACERCÓ AL RÍO BAJO EL
PRETEXTO DE REALIZAR UN EBÓ. FINGIENDO CAERSE, SOLICITÓ AUXILIO A OSHÚN, QUIEN ACUDIÓ EN
SU RESCATE. ORÚNMILA INSISTIÓ EN REGALARLE SU SORTIJA, GRABADA CON SU ODU DE IFÁ, Y
POSTERIORMENTE LA RECLAMÓ COMO SU LEGÍTIMA ESPOSA. EN ESTE MOMENTO NACIÓ EL ANILLO DE
COMPROMISO. CON ASTUCIA Y TERNURA, ORÚNMILA LOGRÓ HACER FELIZ A OSHÚN, CONVIRTIÉNDOSE ASÍ
ELLA EN LA PRIMERA APETEBÍ AYAFÁ. ENSEÑANZAS: LA ENSEÑANZA PRINCIPAL DE ESTA HISTORIA ES
LA BÚSQUEDA INCESANTE DE LA PAZ Y CÓMO, A TRAVÉS DE LA ASTUCIA Y LA TERNURA, SE PUEDEN
SUPERAR LAS ADVERSIDADES PARA LOGRAR LA FELICIDAD. AQUÍ HAY ALGUNOS PUNTOS CLAVE QUE
ILUSTRAN LA LECCIÓN: DIPLOMACIA Y PAZ DURADERA: A PESAR DE LOS ESFUERZOS PREVIOS DE OTROS
ORISHAS PARA LOGRAR LA PAZ ENTRE LOS DOS PUEBLOS EN GUERRA, SOLO FUE A TRAVÉS DE LA
INTERVENCIÓN PERSONAL DE OSHÚN QUE SE BUSCÓ ALCANZAR UNA PAZ DURADERA. LA SUPERACIÓN DE
DESAFÍOS: OSHÚN ENFRENTÓ DESAFÍOS Y DIFICULTADES AL CONVIVIR CON LÍDERES Y SOLDADOS DE
AMBOS EJÉRCITOS. SU RETIRADA A UN RÍO APARTADO SIMBOLIZA LA NECESIDAD DE RETIRARSE Y
REFLEXIONAR CUANDO LAS SITUACIONES SE VUELVEN DESAGRADABLES. CUIDADO Y APOYO MUTUO: LA
INTERVENCIÓN DE YEMAYÁ, AL BRINDAR CUIDADO Y ATENCIÓN A OSHÚN, DESTACA LA IMPORTANCIA DEL
CUIDADO MUTUO Y EL APOYO ENTRE AMIGOS Y FAMILIARES. INCLUSO EN MOMENTOS DIFICILES.
ADAPTABILIDAD Y ELECCIÓN PERSONAL: OSHÚN REGRESÓ A SU RÍO ORIGINAL DESPUÉS DE RECUPERARSE,
MOSTRANDO LA IMPORTANCIA DE SER FIEL A UNO MISMO Y ELEGIR ENTORNOS QUE SE ADAPTEN A LA
PROPIA NATURALEZA. EL SURGIMIENTO DEL ANILLO DE COMPROMISO: EL ASTUTO ACTO DE ORÚNMILA AL
DARLE Y LUEGO RECLAMAR LA SORTIJA DE OSHÚN COMO SÍMBOLO DE COMPROMISO DESTACA CÓMO LA
ASTUCIA Y LA TERNURA PUEDEN LLEVAR A LA FELICIDAD Y A RELACIONES SIGNIFICATIVAS. LA
PRIMERA APETEBÍ AYAFÁ: LA HISTORIA CULMINA CON OSHÚN CONVIRTIÉNDOSE EN LA PRIMERA APETEBÍ
AYAFÁ, MOSTRANDO QUE, A TRAVÉS DE LA ASTUCIA Y EL AMOR, SE PUEDEN ALCANZAR ROLES
SIGNIFICATIVOS Y FELICES EN LA VIDA.''',
  '47. LAS CUATROS HIJAS SOLTERONAS DE ODUDUWA (CUANDO ORÚNMILA SE SENTÍA NOSTÁLGICO).': '''SE SENTIA NOSTALGICO). PATAKI: A ORÚNMILA LE INVADIÓ LA NOSTALGIA DE VOLVER A VER SU
TIERRA, QUE ERA LA MISMA DE OLOKUN, ODUDUWA Y ORISHAOKO, YA QUE HABÍA PASADO MUCHO TIEMPO
DESDE QUE LA DEJO. ESTA TIERRA SE LLAMABA IFEBO, Y AL REGRESAR, SE ENCONTRO CON QUE
ESTABAN ARRESTANDO A TODOS LOS EXTRANJEROS PRESENTES, ENTRE LOS CUALES TAMBIÉN ESTABA
ORÚNMILA. EN ESE MOMENTO, SE PREGUNTÓ CÓMO ERA POSIBLE QUE DESPUÉS DE TANTO TIEMPO LE
OCURRIERA ESTO A ÉL. SIN EMBARGO, ORÚNMILA HABÍA CONSULTADO IFÁ ANTES DE PARTIR Y REALIZÓ
UN EBÓ CON 2 GALLOS, PALOMAS Y OTROS INGREDIENTES. EN MEDIO DE ESTA SITUACIÓN, ORÚNMILA
PREGUNTÓ A UN HOMBRE CUÁL ERA LA RAZÓN DE LA REDADA, Y ESTE LE RESPONDIÓ QUE ERA POR ORDEN
DEL GOBERNADOR DEL LUGAR, LLAMADO ODUDUWA, QUIEN ESTABA ENFADADO PORQUE SUS HIJAS NO
HABIAN LOGRADO CASARSE. ENTONCES, EN UNA OPORTUNIDAD QUE TUVO, ORÚNMILA SE ACERCÓ AL
GOBERNADOR Y LE DIJO QUE LOS HABÍAN ARRESTADO PORQUE OTROS QUE LO HABÍAN MIRADO NO LE
HABÍAN DICHO LA VERDAD SOBRE POR QUÉ SUS HIJAS NO SE HABÍAN CASADO. PERO ÉL SE LO DIRÍA:
LA PRIMERA HIJA ERA CIEGA, LA SEGUNDA TENÍA PROBLEMAS EN EL VIENTRE, LA TERCERA TENÍA
ENFERMEDADES PULMONARES Y LA CUARTA PREFERÍA LAS MUJERES. ODUDUWA ORDENÓ ENTONCES LA
LIBERACIÓN DE TODOS LOS EXTRANJEROS, Y DE ESTA MANERA, ORÚNMILA LOGRÓ SALVAR A SU PUEBLO.
ENSENANZAS: LA ENSEÑANZA PRINCIPAL DE ESTA HISTORIA ES LA IMPORTANCIA DE LA PREVISIÓN, LA
SABIDURÍA Y LA INTERVENCIÓN ADECUADA EN SITUACIONES DIFÍCILES PARA SUPERAR ADVERSIDADES Y
PROTEGER A LA COMUNIDAD. AQUÍ HAY ALGUNOS PUNTOS CLAVE QUE ILUSTRAN LA LECCIÓN: LA
IMPORTANCIA DE LA PREVISIÓN: ORÚNMILA, ANTES DE REGRESAR A SU TIERRA, CONSULTÓ IFÁ Y
REALIZÓ UN EBÓ. ESTO DESTACA LA IMPORTANCIA DE LA PREVISIÓN Y LA PREPARACIÓN ANTES DE
ENFRENTAR SITUACIONES DESCONOCIDAS. SABIDURÍA EN LA ADVERSIDAD: A PESAR DE SER ARRESTADO,
ORÚNMILA DEMUESTRA SABIDURÍA AL INVESTIGAR LA RAZON DETRAS DE LA REDADA. SU PREGUNTA
REVELA LA NECESIDAD DE COMPRENDER LAS CIRCUNSTANCIAS ANTES DE TOMAR MEDIDAS. INTERVENCIÓN
ASTUTA: ORÚNMILA UTILIZA SU CONOCIMIENTO PARA ABORDAR DIRECTAMENTE AL GOBERNADOR, ODUDUWA,
Y REVELAR LA VERDAD SOBRE LA SITUACIÓN MATRIMONIAL DE SUS HIJAS. SU ASTUCIA DEMUESTRA CÓMO
LA VERDAD PUEDE SER UNA HERRAMIENTA PODEROSA PARA RESOLVER PROBLEMAS. LA DIVERSIDAD DE
DESAFÍOS: LA HISTORIA DESTACA LA DIVERSIDAD DE DESAFIOS QUE ENFRENTABA LA FAMILIA DEL
GOBERNADOR (CIEGUERA, PROBLEMAS EN EL VIENTRE, ENFERMEDADES PULMONARES Y PREFERENCIA POR
MUJERES), MOSTRANDO QUE CADA SITUACIÓN ES ÚNICA Y REQUIERE UN ENFOQUE ADAPTADO. LA
RESOLUCIÓN DEL CONFLICTO: LA INTERVENCIÓN DE ORÚNMILA RESULTA EN LA LIBERACIÓN DE TODOS
LOS EXTRANJEROS, DEMOSTRANDO CÓMO LA SABIDURÍA Y LA VERDAD PUEDEN RESOLVER CONFLICTOS Y
PROTEGER A LA COMUNIDAD. EN RESUMEN, LA HISTORIA ENSEÑA QUE LA PREVISIÓN, LA SABIDURÍA, LA
VERDAD Y LA INTERVENCIÓN ESTRATÉGICA SON ELEMENTOS CLAVE PARA SUPERAR DESAFIOS Y PROTEGR A
LA COMUNIDAD''',
  '48. CUANDO ORÚNMILA VIVÍA EN LA TIERRA DE OSHAS.': '''PATAKI: ORUNMILA ESTABA EN LA TIERRA DE LOS OSHAS, PERO MANTENIA SU DISTANCIA DE ELLOS YA
QUE LOS OSHAS NO CONFIABAN EN ORÚNMILA. SIN EMBARGO, ESHU-ELEGBA, A QUIEN ORÚNMILA TRATABA
CON GRAN CONSIDERACIÓN, OBSERVABA A TRAVÉS DE UNA RENDUA TODO LO QUE SUCEDÍA EN LA TIERRA
DE LOS OSHAS Y SE LO COMUNICABA A ORÚNMILA. EN CIERTA OCASIÓN, LOS OSHAS DESAFIARON A
ORUNMILA A DEMOSTRAR SUS CONOCIMIENTOS. A PESAR DE QUE ORÚNMILA HABÍA ESTUDIADO TODO LO
QUE ESHU-ELEGBA LE CONTABA, REVELÓ A LOS OSHAS LO QUE HACÍAN SIN QUE ÉL ESTUVIERA
PRESENTE. COMO RESULTADO, A PARTIR DE ESE MOMENTO, LOS OSHAS COMENZARON A RENDIRLE
HOMENAJE A ORUNMILA. AL VER TODO LO QUE ORÚNMILA HABÍA LOGRADO, ESHU-ELEGBA LE PIDIÓ QUE
LE REALIZARA UNA CONSULTA DE IFÁ. ORÚNMILA ACEPTÓ Y LE DIJO QUE LE TRAJERA LAS HIERBAS
NECESARIAS. ESHU-ELEGBA LE PROPORCIONÓ TODO, EXCEPTO DOS CABRAS. ENTONCES, ORÚNMILA LE
DIJO: "ESTÁ BIEN, TE VOY A HACER IFÁ." PERO ESHU-ELEGBA ACLARÓ QUE FALTABAN DOS HIERBAS,
QUE ERAN OROZUZ Y CORALILLO. ORÚNMILA VERIFICÓ LA INFORMACIÓN DE ESHU-ELEGBA Y LUEGO LE
DIJO: "A PARTIR DE ESTE MOMENTO, DE CADA REGISTRO QUE REALICE, CINCO CENTAVOS SERÁN PARA
TI, PORQUE NO SE PUEDE SER TAN AVARICIOSO." ENSEÑANZAS: LA IMPORTANCIA DE LA CONFIANZA: LA
HISTORIA DESTACA LA DESCONFIANZA INICIAL QUE LOS OSHAS TENÍAN HACIA ORÚNMILA. LA CONFIANZA
ES FUNDAMENTAL EN CUALQUIER RELACIÓN, Y SU AUSENCIA PUEDE GENERAR CONFLICTOS. EL VALOR DE
LA OBSERVACIÓN Y LA INFORMACIÓN: ESHU-ELEGBA, A PESAR DE LAS RESERVAS DE LOS OSHAS HACIA
ORÚNMILA, OBSERVABA Y LE PROPORCIONABA INFORMACIÓN CLAVE. LA HISTORIA RESALTA CÓMO LA
OBSERVACIÓN Y LA INFORMACIÓN PUEDEN SER HERRAMIENTAS PODEROSAS. LA DEMOSTRACIÓN DE
CONOCIMIENTOS: ORÚNMILA TUVO LA OPORTUNIDAD DE DEMOSTRAR SUS CONOCIMIENTOS CUANDO LOS
OSHAS LO DESAFIARON. LA HISTORIA ENSEÑA QUE A VECES ES NECESARIO DEMOSTRAR HABILIDADES Y
CONOCIMIENTOS PARA GANARSE LA CONFIANZA Y EL RESPETO DE LOS DEMAS. LA RECIPROCIDAD EN LA
RELACIÓN: DESPUÉS DE QUE ORÚNMILA REVELÓ LA VERDAD SOBRE LAS ACCIONES DE LOS OSHAS, ESTOS
COMENZARON A RENDIRLE HOMENAJE. LA RECIPROCIDAD EN UNA RELACIÓN, DONDE AMBAS PARTES
CONTRIBUYEN POSITIVAMENTE, ES ESENCIAL PARA CONSTRUIR LA ARMONIA. LA GENEROSIDAD Y LA
LECCIÓN SOBRE LA AVARICIA: ORÚNMILA, AL ACEPTAR REALIZAR UNA CONSULTA DE IFÁ PARA ESHU-
ELEGBA, LE PIDIÓ QUE LE TRAJERA LAS HIERBAS NECESARIAS. SIN EMBARGO, AL ACLARAR QUE
FALTABAN DOS HIERBAS, ORÚNMILA SE DIÓ CUENTA QUE A ELEGBA SE LE DEBÍA UN PAGO JUSTO, LA
HISTORIA RESALTA LA IMPORTANCIA DE LA GENEROSIDAD Y ADVIERTE SOBRE LA AVARICIA. EN
RESUMEN, LA HISTORIA SUBRAYA VALORES COMO LA CONFIANZA, LA RECIPROCIDAD, LA DEMOSTRACIÓN
DE HABILIDADES Y LA IMPORTANCIA DE EVITAR LA AVARICIA EN LAS RELACIONES INTERPERSONALES.''',
  '49. CUANDO ORÚNMILA SE ENCONTRÓ PERSEGUIDO.': '''PATAKI: ORÚNMILA ENCONTRÓ A UNA TRIBU DE INCRÉDULOS QUE LO PERSEGUÍAN, Y AL VERSE
ACORRALADO Y PERDIDO, SACÓ SU IFÁ QUE LLEVABA ENVUELTO EN UNA FAJA ALREDEDOR DE SU
CINTURA. COLOCÓ SU IFÁ EN LA ORILLA DE UNA CUEVA, QUE RESULTÓ SER DEL CANGREJO, CON EL
OBJETIVO DE EVITAR QUE LOS INCRÉDULOS DESCUBRIERAN SU SECRETO. A PESAR DE SEGUIR
CORRIENDO, SE VIO ACORRALADO EN LA PUNTA DE UN DESPEÑADERO Y DECIDIÓ LANZARSE AL AGUA. EN
ESE MOMENTO, UN PULPO LIBERÓ SU TINTA, Y LOS INCRÉDULOS, AL VERLO, LO DIERON POR MUERTO.
DESPUÉS DE UN TIEMPO, ORÚNMILA REGRESÓ EN BUSCA DE SU IFÁ Y SE SORPRENDIÓ AL NOTAR QUE NO
ESTABA DONDE LO HABÍA DEJADO. EN SU DESESPERACIÓN, COMENZÓ A IMPLORAR, Y FUE ENTONCES
CUANDO APARECIÓ EL CANGREJO, ENTREGÁNDOLE SU IFÁ CON SUS TENAZAS. AGRADECIDO POR ESTA
ACCIÓN, ORÚNMILA LE DIJO AL CANGREJO: "NI A TI, NI A TUS HIJOS, NI A TU DESCENDENCIA JAMÁS
ME LOS COMERÉ." NOTA: ES EN ESTE MOMENTO QUE SURGE LA PROHIBICIÓN PARA LOS BABALAWOS DE
COMER PULPO O CALAMAR. ENSEÑANZAS: PROTECCIÓN DE LOS SECRETOS MEDIANTE ASTUCIA: LA LECCIÓN
PRINCIPAL DE ESTA HISTORIA RADICA EN LA PROTECCIÓN DE LOS SECRETOS IMPORTANTES A TRAVÉS DE
LA ASTUCIA Y LA TOMA DE DECISIONES ESTRATÉGICAS. ORÚNMILA, AL ENCONTRARSE ACORRALADO,
UTILIZA SU INTELIGENCIA PARA ESCONDER SU IFÁ EN UN LUGAR INESPERADO, EVITANDO ASÍ QUE LOS
INCRÉDULOS DESCUBRAN SUS CONOCIMIENTOS ESPIRITUALES. CONSECUENCIAS DE LAS DECISIONES: LA
DECISIÓN DE ORÚNMILA DE LANZARSE AL AGUA, AUNQUE RIESGOSA, RESULTA EN LA PERCEPCIÓN
EQUIVOCADA DE SU MUERTE POR PARTE DE LOS INCRÉDULOS. ESTO DEMUESTRA CÓMO LAS ELECCIONES
PUEDEN TENER CONSECUENCIAS INESPERADAS. AGRADECIMIENTO Y PROHIBICIÓN: LA GRATITUD DE
ORUNMILA HACIA EL CANGREJO POR PROTEGER SU IFÁ SE MUESTRA CUANDO LE PROMETE QUE NI ÉL NI
SU DESCENDENCIA SERÁN CONSUMIDOS. ESTO ORIGINA LA PROHIBICIÓN ENTRE LOS BABALAWOS DE COMER
CANGREJO, PULPO O CALAMAR, UNA REGLA QUE SURGE DE ESTE AGRADECIMIENTO Y PROMESA. VALOR DE
LA INTEGRIDAD Y EL RECONOCIMIENTO: EL CANGREJO, AL DEVOLVER EL IFA, DEMUESTRA UN ACTO DE
INTEGRIDAD Y RECIBE EL RECONOCIMIENTO DE ORÚNMILA. ESTO DESTACA LA IMPORTANCIA DE VALORAR
Y RESPETAR LOS ACTOS HONESTOS DE OTROS. TRASCENDENCIA DE LAS DECISIONES ESPIRITUALES: LA
HISTORIA ILUSTRA CÓMO LAS ACCIONES DE ORÚNMILA Y SU RELACIÓN CON EL CANGREJO INFLUYEN EN
LAS PRÁCTICAS ESPIRITUALES DE LOS BABALAWOS, ESTABLECIENDO UNA PROHIBICIÓN DURADERA.
SUBRAYA CÓMO LAS NARRATIVAS MITOLÓGICAS INFLUYEN EN LAS COSTUMBRES Y TRADICIONES.''',
  '50. EL QUIQUIRIQUI.': '''PATAKI: HUBO UN HOMBRE QUE COMPARTÍA SU HOGAR CON NUMEROSOS ANIMALES Y MUCHOS FAMILIARES.
EN CIERTA OCASIÓN, UNO DE SUS PARIENTES ENFERMÓ GRAVEMENTE Y LLEGÓ AL BORDE DE LA MUERTE.
AUNQUE TODOS ESTABAN SUMIDOS EN LA TRISTEZA, EL GALLO, CONOCIDO COMO QUIQUIRIQUÍ,
PERMANECÍA IMPERTURBABLE, YA QUE NO TEMÍA A LA MUERTE QUE ACECHABA. EL DUEÑO DE LA CASA,
QUIEN COMPRENDÍA EL LENGUAJE DE LOS ANIMALES, TAMBIÉN PERMANECÍA SERENO AL ENTENDER LA
ACTITUD DEL QUIQUIRIQUÍ. EN UN DÍA ESPECÍFICO, EL PERRO LE ADVIRTIÓ AL GATO QUE NO
CORRIERA, PUES LA SEÑORA DEL AMO ESTABA ENFERMA Y NO DEBÍAN ANDAR CORRETEANDO. MIENTRAS
TANTO, EL QUIQUIRIQUÍ SONREÍA Y COMENTABA: "QUÉ COBARDES SON TODOS. EN EL MOMENTO EN QUE
EL SEÑOR LOS NECESITA, NINGUNO LE SIRVE" FINALMENTE, LLEGÓ EL DÍA EN QUE LA MUERTE VINO A
BUSCAR A LA SEÑORA DEL AMO. TODOS LOS ANIMALES SE ASUSTARON Y ARMARON UN ALBOROTO,
EVITANDO A TODA COSTA ENCONTRARSE CON LA MUERTE. SIN EMBARGO, EL QUIQUIRIQUÍ, RIENDO, SE
ENFRENTÓ VALIENTEMENTE A ELLA Y, DURANTE EL FORCEJEO, UNA DE LAS PLUMAS DEL GALLO SE
ENGANCHÓ EN LA MUERTE. AL NO COMPRENDER LO QUE OCURRÍA, LA MUERTE SE ASUSTÓ Y ECHÓ A
CORRER, PERO CADA VEZ QUE VOLTEABA LA CABEZA, VEÍA LA PLUMA Y CORRÍA AÚN MÁS RÁPIDO. DE
ESTA MANERA, EL QUIQUIRIQUÍ LOGRÓ AHUYENTAR A LA MUERTE Y LA ESPOSA DEL AMO SE RECUPERÓ.
EL DUEÑO DE LA CASA SE DIO CUENTA DE QUE EL ANIMAL MÁS INTELIGENTE QUE TENÍA ERA EL
QUIQUIRIQUÍ, YA QUE ESTE TAMBIÉN COMPRENDÍA EL LENGUAJE DE LOS SANTOS. ENSENANZAS:
TRANSCENDENCIA DEL MIEDO A LA MUERTE: LA HISTORIA ILUSTRA LA VALENTIA DEL GALLO
QUIQUIRIQUÍ, QUIEN PERMANECE IMPERTURBABLE ANTE LA AMENAZA DE LA MUERTE. SU FALTA DE MIEDO
SIMBOLIZA LA TRANSCENDENCIA DEL TEMOR A LA MUERTE, UNA LECCIÓN QUE DESTACA LA IMPORTANCIA
DE ENFRENTAR LOS DESAFIOS CON VALOR. PERCEPCIÓN DE LA VALENTÍA: MIENTRAS OTROS ANIMALES Y
FAMILIARES PANIQUEAN ANTE LA MUERTE, QUIQUIRIQUÍ, CON UNA SONRISA, CRITICA SU COBARDÍA. LA
HISTORIA CONVEY LA LECCIÓN DE QUE LA VERDADERA VALENTIA SE DEMUESTRA EN EL MOMENTO DE
NECESIDAD, Y LAS ACCIONES HABLAN MÁS FUERTE QUE LAS PALABRAS. COMPRENSIÓN DEL LENGUAJE DE
LOS ANIMALES: EL DUEÑO DE LA CASA, QUE COMPRENDE EL LENGUAJE DE LOS ANIMALES, SE MANTIENE
TRANQUILO TODO EL TIEMPO. ESTO DESTACA LA IMPORTANCIA DE LA COMUNICACIÓN Y LA EMPATÍA EN
LA CREACIÓN DE CONEXIONES CON OTROS, INCLUYENDO A LOS ANIMALES. SOLUCIONES INESPERADAS A
LOS PROBLEMAS: EL MÉTODO INGENIOSO DE QUIQUIRIQUÍ PARA ENFRENTAR A LA MUERTE, USANDO UNA
PLUMA PARA ASUSTARLA, ILUSTRA LA LECCIÓN DE QUE LAS SOLUCIONES CREATIVAS E INESPERADAS
PUEDEN SER EFICACES PARA SUPERAR DESAFÍOS. INTELIGENCIA Y COMPRESIÓN: EL DUEÑO DE LA CASA
SE DA CUENTA DE QUE QUIQUIRIQUÍ, COMPRENDIENDO EL LENGUAJE DE LOS SANTOS, ES EL ANIMAL MÁS
INTELIGENTE. ESTO ENFATIZA EL VALOR DE LA INTELIGENCIA Y LA COMPRENSIÓN AL EVALUAR EL
VERDADERO VALOR Y LA CONTRIBUCIÓN DE LAS PERSONAS.''',
  '51. CUANDO OLOFIN CREÓ LA TIERRA.': '''PATAKI: CUANDO OLOFIN DECIDIÓ CREAR LA TIERRA, LANZÓ UNA SEMILLA DE NUEZ DE KOLÁ, LA CUAL
CAYÓ EN EL MAR. DE ESTA SEMILLA SURGIÓ UNA PALMA Y SIETE PRÍNCIPES QUE TOMARON POSESIÓN
DEL COGOLLO O COPO. ENTRE ELLOS SE ENCONTRABAN ORANMIYAN Y SHANGÓ, SIENDO ESTE ÚLTIMO EL
MÁS PEQUEÑO. OLOFIN LES PROPORCIONÓ PROVISIONES, Y AL REPARTIRLAS, TOMARON TODAS LAS
BUENAS Y DEJARON A SHANGÓ UNA TIERRA CON TELA Y VEINTIUNA BARRAS DE HIERRO, PENSANDO QUE
SE HABÍAN QUEDADO CON LO MEJOR. SHANGÓ, INGENIOSO, SACUDIÓ LA TIERRA FORMANDO UN MONTÍCULO
EN EL MAR. LUEGO SOLTÓ UNA GALLINA QUE EXCAVÓ LA TIERRA, Y ESTA CRECIÓ SOBRE EL MAR. ACTO
SEGUIDO, SHANGÓ SALTÓ A LA TIERRA, TOMANDO POSESIÓN DE ELLA. AL VER QUE LO QUE POSEÍA
SHANGÓ ERA MÁS EFECTIVO, YA QUE SIN TIERRAS NO PODRÍAN GOBERNAR, LOS PRÍNCIPES INTENTARON
ARREBATÁRSELAS. SIN EMBARGO, LAS VEINTIUNA BARRAS DE HIERRO SE CONVIRTIERON EN BARRAS
DEFENSIVAS. SHANGÓ, DECIDIDO, AVANZÓ CON UNA ESPADA EN MANO HACIA ELLOS, MIENTRAS LOS
PRÍNCIPES LE SUGERÍAN QUE DEBÍA COMPARTIR LA TIERRA CON ELLOS. SHANGÓ RESPONDIÓ: "ESTÁ
BIEN, COMPARTIRÉ, PERO SERÉ YO QUIEN GOBIERNE". DE ESTA MANERA, SHANGÓ REPARTIÓ LAS
TIERRAS FORMANDO LA CIUDAD DE OYO, DONDE ESTABLECIÓ SU PRIMERA DINASTÍA. ENSEÑANZAS:
DETERMINACIÓN ANTE LA ADVERSIDAD: A PESAR DE ENFRENTARSE A LA RESISTENCIA DE LOS OTROS
PRÍNCIPES, SHANGÓ MUESTRA UNA DETERMINACIÓN INQUEBRANTABLE AL DEFENDER LO QUE LE
PERTENECE. LA HISTORIA ENSEÑA LA IMPORTANCIA DE LA DETERMINACIÓN ANTE LOS DESAFIOS. VALOR
DE LOS RECURSOS ESTRATÉGICOS: LAS VEINTIUNA BARRAS DE HIERRO SE CONVIERTEN EN UNA DEFENSA
EFECTIVA, RESALTANDO LA IMPORTANCIA DE ENTENDER Y UTILIZAR ESTRATÉGICAMENTE LOS RECURSOS
DISPONIBLES, INCLUSO EN SITUACIONES APARENTEMENTE DESFAVORABLES. COMPARTIR CON LIDERAZGO:
AUNQUE SHANGÓ ACEPTA COMPARTIR LAS TIERRAS, ESTABLECE CLARAMENTE QUE ÉL SERÁ EL
GOBERNANTE. ESTA LECCIÓN RESALTA LA IMPORTANCIA DE LA COLABORACIÓN, PERO TAMBIÉN MUESTRA
LA NECESIDAD DE UN LIDERAZGO CLARO Y FUERTE EN SITUACIONES COMPARTIDAS. ESTABLECIMIENTO DE
DINASTÍA: LA CREACIÓN DE LA CIUDAD DE OYO Y LA ESTABLECIMIENTO DE LA PRIMERA DINASTÍA POR
SHANGÓ ENFATIZAN LA IMPORTANCIA DE LA VISIÓN A LARGO PLAZO Y EL IMPACTO DURADERO DE LAS
DECISIONES ESTRATÉGICAS. EN RESUMEN, LA HISTORIA ILUSTRA LECCIONES VALIOSAS SOBRE ASTUCIA,
DETERMINACIÓN, GESTIÓN DE RECURSOS, LIDERAZGO COMPARTIDO Y ESTABLECIMIENTO DE UN LEGADO
DURADERO.''',
  '52. LA GUERRA ENTRE EL HIJO DEL CUCHILLO(OBE) Y EL CUERPO(ARÁ).': '''PATAKI: EL HIJO DE OBE Y EL DE ARÁ SE ENFRENTARON EN NUMEROSAS OCASIONES, Y EN CADA
ENFRENTAMIENTO, EL HIJO DE OBE RESULTABA DERROTADO. SE SABÍA QUE ARÁ, AL COMBATIR, OBTENÍA
PODERES SOBRENATURALES DE LA TIERRA, LO QUE HACÍA IMPOSIBLE QUE OBE PUDIERA VENCERLO.
SIGUIENDO EL CONSEJO DE SU PADRE, OBE CONSULTÓ A ORÚNMILA, QUIEN LE ACONSEJÓ HACER EBÓ CON
UN CARRETE DE HILO BLANCO Y UNO NEGRO, CIEN PIEDRAS, TRES GUABINAS, OCHO BABOSAS Y UNA
JUJÚ DE KOIDÉ. ORÚNMILA LE PREDIJO QUE TENDRÍA UN SUEÑO CON UNA DONCELLA MUY HERMOSA Y QUE
LUEGO LA CONOCERÍA. ESTA DONCELLA LO AYUDARÍA A GANAR LA GUERRA DE TANTOS AÑOS QUE
SOSTENÍA CON ARÁ. SIN EMBARGO, PARA EMPRENDER ESTA EMPRESA, DEBÍA BUSCAR UN BARCO, USAR LA
CABEZA Y SEGUIR TODOS LOS CONSEJOS DADOS. ORÚNMILA LE ADVIRTIÓ QUE ARÁ VIVÍA EN UN
LABERINTO DEL CUAL NADIE SALÍA. EL HUO DE OBE SE FUE MUY CONTENTO, REALIZÓ EL EBÓ, SOÑÓ
CON LA DONCELLA Y MÁS TARDE LA CONOCIÓ. ELLA PROMETIÓ AYUDARLO, POR LO QUE PIDIÓ PRESTADO
EL BARCO A SU PADRE. SE DIRIGIÓ AL COMBATE DECISIVO LLEVANDO CONSIGO UNA BANDERA NEGRA,
CON LA CONDICIÓN DE QUE, SI GANABA, DEBÍA REGRESAR CON UNA BLANCA. PARTIÓ CON LA DONCELLA
A SU EMPRESA Y LLEGARON A LA ENTRADA DE LA CUEVA. LA DONCELLA SE DESPRENDIÓ UN HILO DE LA
SAYA Y LE PIDIÓ QUE SE LO ATARA A LA CINTURA PARA QUE PUDIERA GUIARLO Y ENCONTRAR LA
SALIDA DEL LABERINTO. AL ENTRAR, ENCONTRÓ A ARÁ DORMIDO Y, APROVECHANDO EL EBÓ, LO
SUSPENDIÓ EN EL AIRE ESTRANGULÁNDOLO, YA QUE ARÁ EN EL AIRE NO TENÍA NINGUNA FUERZA. LA
DONCELLA COMENZÓ A RECOGER EL HILO, Y EL HIJO DE OBE PUDO SALIR. SIN EMBARGO, ELLA SE
HABÍA QUEDADO COMPLETAMENTE DESNUDA. AL VERLA, OBE SE SINTIÓ COMPLETAMENTE EXTASIADO, Y
JUNTOS CONSUMARON SU AMOR. CUANDO REGRESABAN, OLVIDARON QUITAR LA BANDERA NEGRA DEBIDO A
LA EXCESIVA ALEGRÍA QUE EXPERIMENTARON. AL VER LA BANDERA NEGRA, EL PADRE ENLOQUECIÓ Y SE
ARROJÓ AL MAR. CUANDO EL HIJO DESEMBARCÓ LLENO DE ALEGRÍA, LA GENTE LE CONTÓ LO SUCEDIDO
AL PADRE, Y RECORDÓ QUE ORUNMILA LE HABIA DICHO QUE USARA LA CABEZA. EL MUCHACHO LLENO DE
DOLOR Y EN HONOR A SU PADRE SE VISTIÓ DE NEGRO, ASÍ COMO TODOS LOS QUE LE RODEABAN,
MARCANDO ASÍ EL NACIMIENTO DE LA TRADICIÓN DEL LUTO. OTRA VERSION: EL NACIMIENTO DE
AYAGUNA HUBO UN TIEMPO EN QUE SE ANUNCIÓ EL NACIMIENTO DE AYAGUNA, QUIEN ESTABA DESTINADO
A PONER FIN A LA PROLONGADA GUERRA ENTRE EJIOGBE Y UN GUERRERO LLAMADO ORAGUN, LA CUAL
HABÍA PERSISTIDO DURANTE 15 AÑOS SIN QUE OGBE PUDIERA VENCER A SU ADVERSARIO ORAGUN POSEÍA
LA HABILIDAD DE OBTENER FUERZAS SOBRENATURALES CADA VEZ QUE LUCHABA EN TIERRA, LO QUE
AGOTABA A OGBE EN LOS 15 ENFRENTAMIENTOS QUE MANTUVIERON. MIENTRAS AYAGUNA CRECÍA, TOMABA
CONOCIMIENTO DE LA RIVALIDAD ENTRE ESTOS GUERREROS Y SE PROPUSO ACABAR CON LA VENTAJA QUE
ORAGUN TENÍA. DESCUBRIÓ TODOS LOS PUNTOS VULNERABLES DE SU ENEMIGO. SIN EMBARGO, ORAGUN
VIVÍA EN UN LABERINTO DEL QUE NADIE PODÍA ESCAPAR. LOS HABITANTES DEL PUEBLO LE
ACONSEJARON A AYAGUNA QUE NO LUCHARA CONTRA ÉL, YA QUE PODÍA PERDER, CONSIDERANDO QUE
TENÍA SOLO 16 AÑOS. PERO AYAGUNA ESTABA DECIDIDO, BUSCABA LA GLORIA Y LA FORTUNA. UNA
NOCHE, TUVO UNA REVELACION CON UNA DONCELLA ENCANTADORA A QUIEN MÁS TARDE CONOCIÓ Y LE
CONTÓ SU PLAN. ELLA SE ENAMORÓ DE ÉL Y DECIDIÓ AYUDARLO. PREPARARON TODO Y AYAGUNA LE DIJO
A OGBE: "PARA ESTA EMPRESA USARÉ BARCOS; PONDRÉ UNA BANDERA NEGRA SI PIERDO Y UNA BLANCA
SI GANO, PARA QUE PUEDAS DISTINGUIRME AL REGRESAR". PARTIÓ HACIA LA CUEVA DONDE VIVÍA
ORAGUN. CUANDO LLEGÓ, LA DONCELLA LO ESPERABA Y LE ENTREGÓ UN CARRETE DE HILO,
SOSTENIÉNDOLO DE UN EXTREMO PARA QUE AYAGUNA PUDIERA GUIARSE Y SALIR DEL LABERINTO. SABÍA
QUE EN TIERRA NO PODÍA VENCER A ORAGUN, PERO LA SUERTE ESTABA DE SU LADO. SORPRENDIÓ A
ORAGUN DORMIDO Y APROVECHÓ LA SITUACIÓN, LEVANTÁNDOLO EN EL AIRE Y ESTRANGULÁNDOLO. CON EL
HILO ATADO A SU CINTURA, LOGRÓ ESCAPAR DEL LABERINTO. LA ALEGRÍA DE AYAGUNA FUE TANTA QUE
OLVIDÓ QUITAR LA BANDERA NEGRA AL REGRESAR. OGBE, QUIEN ESPERABA EN LA PLAYA, AL VER LA
BANDERA NEGRA, PENSÓ QUE AYAGUNA HABÍA PERDIDO, SE VOLVIÓ LOCO Y SE ARROJÓ AL MAR. CUANDO
AYAGUNA PREGUNTÓ POR OGBE, LE INFORMARON QUE HABÍA ENLOQUECIDO Y SE HABÍA LANZADO AL MAR.
ENTONCES COMPRENDIÓ SU DESCUIDO AL NO QUITAR LA BANDERA NEGRA. LE DIJO AL PUEBLO QUE
ORAGUN ERA UN GRAN GUERRERO, QUE INCLUSO DESPUÉS DE SER VENCIDO, HABÍA RESPETADO A OGBE.
EN HONOR A ESOS GUERREROS, CADA AÑO SE IZARÍAN DOS BANDERAS, UNA BLANCA Y UNA NEGRA, Y
TODO EL PUEBLO SE LIMPIARÍA CON ELLAS. INSTRUCCIONES: SOLO LOS HIJOS DE EJIOGBE PUEDEN
USAR ROPA NEGRA, PERO SOLO EN CASO DE PELIGRO; DE LO CONTRARIO, DEBEN OFRECÉRSELA A YEMAYÁ
OLOKUN. ENSEÑANZAS: PERSISTENCIA ANTE LA ADVERSIDAD: A PESAR DE LAS REPETIDAS DERROTAS DEL
HIJO DE OBE EN LOS ENFRENTAMIENTOS CON ARÁ, LA HISTORIA RESALTA LA IMPORTANCIA DE LA
PERSISTENCIA Y LA DETERMINACIÓN ANTE LA ADVERSIDAD. A TRAVES DEL ASESORAMIENTO DE
ORUNMILA, OBE BUSCÓ SOLUCIONES PARA SUPERAR SUS DIFICULTADES. SABIDURÍA EN LA TOMA DE
DECISIONES: LA CONSULTA A ORÚNMILA Y LA REALIZACIÓN DEL EBÓ REVELAN LA IMPORTANCIA DE
BUSCAR SABIDURÍA Y ORIENTACIÓN AL ENFRENTAR SITUACIONES DIFÍCILES. LA TOMA DE DECISIONES
INFORMADAS PUEDE MARCAR LA DIFERENCIA EN LA RESOLUCIÓN DE CONFLICTOS. ALIANZAS
ESTRATÉGICAS: LA DONCELLA, QUE APARECE EN LOS SUEÑOS Y LUEGO EN LA REALIDAD, REPRESENTA
UNA ALIANZA ESTRATÉGICA QUE CONTRIBUYE AL ÉXITO DEL HIJO DE OBE. LA HISTORIA SUBRAYA LA
IMPORTANCIA DE FORMAR ALIANZAS Y BUSCAR AYUDA CUANDO SEA NECESARIO. PREPARACIÓN PARA LOS
DESAFÍOS: EL HIO DE OBE, AL SEGUIR LAS INDICACIONES DE ORÚNMILA, SE PREPARÓ ADECUADAMENTE
PARA ENFRENTAR LOS DESAFÍOS. ESTA LECCIÓN RESALTA LA IMPORTANCIA DE LA PREPARACIÓN Y LA
CONSIDERACIÓN DE TODOS LOS ASPECTOS ANTES DE EMPRENDER UNA EMPRESA SIGNIFICATIVA.
CONSECUENCIAS DE LA ALEGRÍA DESBORDANTE: LA OMISIÓN DE QUITAR LA BANDERA NEGRA DEBIDO A LA
EXCESIVA ALEGRÍA AL REGRESAR, LLEVÓ A CONSECUENCIAS INESPERADAS. ESTO REFUERZA LA IDEA DE
QUE, INCLUSO EN MOMENTOS DE FELICIDAD, ES CRUCIAL MANTENER LA ATENCIÓN EN DETALLES
IMPORTANTES. HONOR Y RESPETO A LOS PADRES: LA HISTORIA CONCLUYE CON UN ACTO DE HONOR Y
RESPETO HACIA EL PADRE. A PESAR DE LA ALEGRÍA Y EL TRIUNFO, EL HIJO DECIDE VESTIRSE DE
NEGRO EN MEMORIA DE SU PADRE, ESTABLECIENDO ASÍ LA TRADICIÓN DEL LUTO EN LA COMUNIDAD. EN
RESUMEN, ESTA NARRATIVA OFRECE LECCIONES SOBRE PERSISTENCIA, SABIDURÍA, ALIANZAS
ESTRATEGICAS, PREPARACIÓN, CONSECUENCIAS DE LAS ACCIONES IMPULSIVAS Y EL RESPETO A LAS
TRADICIONES Y A LOS PADRES''',
  '53. EL PRINCIPIO Y FIN DE TODAS LAS COSAS.': '''PATAKI: HABÍA UN TIEMPO EN EL QUE LOS SANTOS, PERSONAS Y ANIMALES SE ODIABAN MUTUAMENTE,
LANZÁNDOSE INSULTOS INCLUSO ENTRE FAMILIARES, MADRES E HIJOS. EN ESE ENTONCES, NO EXISTÍA
UNA CREENCIA UNIFICADA Y LOS SANTOS SE ENFRENTABAN UNOS A OTROS. AUNQUE HABÍA RELIGIONES
COMO ABAKÚA Y MAYOMBE, NO HABÍA UN LÍDER O PROFETA PARA GOBERNAR. ANTE ESTA SITUACIÓN,
OLODUMARE SE DIO CUENTA DE QUE EL MUNDO ESTABA ENCAMINÁNDOSE HACIA SU DESTRUCCIÓN. POR LO
TANTO, HIZO UN LLAMADO A LAS PERSONAS QUE CONSIDERABA DESTINADAS Y RESPONSABLES DE
GOBERNAR, ENTRE ELLAS, OLOFIN, UN SANTO RESPETADO. OLODUMARE LOS REUNIÓ A TODOS Y LES
PREGUNTÓ QUÉ TRAÍAN O TENÍAN PARA GOBERNAR. ENTRE TODAS LAS RESPUESTAS, OLOFIN SOLO DIJO:
"TRAIGO CABEZAS". ANTE ESTA RESPUESTA, OLODUMARE LE ENTREGÓ EL MANDO DEL MUNDO ENTERO PARA
SU GOBIERNO. OLOFIN LE INDICÓ A OLODUMARE QUE, PARA GOBERNAR, DEBÍA OTORGARLE EL CONTROL
DE LOS ASTROS, PRINCIPALMENTE EL DEL SOL, EL MAR, EL AIRE Y LA TIERRA, ASÍ COMO UNA
PERSONA DE CONFIANZA QUE ESTUVIERA EN LA TIERRA. ESTOS LUGARES SON LOS 16 MEYIS, QUE
REPRESENTAN LAS 16 TIERRAS QUE FUNDÓ Y RECORRIÓ, Y LOS COMPUESTOS SON LOS TÉRMINOS.
RECORRIDO DEL ÚLTIMO OLOFIN, SE DIO CUENTA DE QUE LO PERSEGUÍA UN CLARO ESTÁ QUE CADA UNO
TIENE 16 LUGARES DISTINTOS. SIN EMBARGO, EN EL MUCHACHO QUE SE TRANSFORMABA EN DIFERENTES
FORMAS. ANTE ESTO, OLOFIN LO LLAMÓ Y LE PREGUNTÓ QUIÉN ERA. EL MUCHACHO RESPONDIÓ: "SOY
ELEGBA". OLOFIN LE REPLICÓ: "NO, TÚ ERES ESHU-ELEGBA". ESTE LE DIO QUE LO QUE ÉL BUSCABA
ESTABA DEBAJO DE LA TIERRA, EN EL PRIMER PUEBLO QUE HABÍA PASADO AL DARSE CUENTA DE QUE
ERA ELLLIGAR MÁS ODIADO DONDE LA GENTE ANDARA SIN CABEZAS DANDO TUMBOS, ES DECIR, ERAN
FENÓMENOS. EN EL ÚLTIMO LUGAR DONDE ESTABAN ACTUALMENTE, PRECISAMENTE INDICABA QUE HABÍA
SANTOS AMARRADOS, PRESOS O DESOBEDIENCIA AL SANTO. OLOFIN PARTIO CON EL MUCHACHO, QUIEN,
PARA SEGUIR ADELANTE, LE IBA DICIENDO MENTIRAS POR EL CAMINO, PERO DIJO UNA VERDAD QUE
HABIA VISTO: EL LUGAR QUE OLOFIN ESTABA BUSCANDO. AL ENCONTRARLO, LE OTORGÓ LA POTESTAD Y
LE PUSO EL NOMBRE PARA QUE FUERA JUNTO A ÉL A RESOLVER LOS ASUNTOS DEL MUNDO. TAMBIÉN LE
DIJO QUE MIENTRAS EXISTIERA EL MUNDO, ÉL SERÍA LA GUÍA DE TODAS LAS CUESTIONES DEL PUEBLO.
ESTE HECHO MARCO EL COMIENZO DE TODAS LAS FUTURAS POBLACIONES QUE SE FUNDARÍAN. ES DECIR,
QUE ORÚNMILA NO SERÍA NADIE SIN ÉL, Y ÉL NO SERÍA NADIE SIN ORÚNMILA. MAFEREFÚN: OLOFIN,
ESHU-ELEGBA, EGÚN Y ORÚNMILA. ENSEÑANZAS: UNIDAD Y COOPERACIÓN: LA NARRATIVA RESALTA LA
IMPORTANCIA DE LA UNIDAD Y LA COOPERACIÓN ENTRE LOS SERES, YA QUE EN EL PASADO, SANTOS,
PERSONAS Y ANIMALES SE ODIABAN MUTUAMENTE. LA CREACION DE UN LIDERAZGO UNIFICADO BAJO
OLOFIN INDICA LA NECESIDAD DE TRABAJAR JUNTOS PARA EVITAR LA DESTRUCCIÓN. ELECCIÓN DE
LÍDERES SABIOS: LA ELECCIÓN DE OLOFIN COMO LÍDER, CONOCIDO POR SU RESPETO, SUGIERE LA
IMPORTANCIA DE ELEGIR LÍDERES SABIOS Y RESPONSABLES PARA GOBERNAR. LA SABIDURÍA Y EL
RESPETO SON CUALIDADES ESENCIALES PARA GUIAR A UNA COMUNIDAD DE MANERA EFECTIVA.
CONSECUENCIAS DE LA FALTA DE DIRECCIÓN: LA HISTORIA DESTACA LAS CONSECUENCIAS NEGATIVAS DE
LA FALTA DE UNA CREENCIA UNIFICADA Y DE LÍDERES PARA GOBERNAR. ESTA FALTA DE DIRECCIÓN
CONDUJO AL ODIO Y LOS CONFLICTOS. LA NARRATIVA SUBRAYA LA NECESIDAD DE UNA GUÍA ESPIRITUAL
Y LIDERAZGO PARA MANTENER EL ORDEN Y LA ARMONÍA. POTESTAD Y RESPONSABILIDAD: LA ENTREGA
DEL MANDO DEL MUNDO A OLOFIN POR PARTE DE OLODUMARE SUGIERE QUE AQUELLOS A QUIENES SE LES
CONFÍA LA AUTORIDAD TAMBIÉN DEBEN ASUMIR LA RESPONSABILIDAD DE CUIDAR Y GOBERNAR
SABIAMENTE. EL CONTROL SOBRE ELEMENTOS COMO EL SOL, EL MAR, EL AIRE Y LA TIERRA SIMBOLIZA
LA RESPONSABILIDAD GLOBAL. RECONOCIMIENTO DE LA VERDAD: LA INTERACCIÓN CON ESHU-ELEGBA
DESTACA LA IMPORTANCIA DE RECONOCER LA VERDAD, INCLUSO CUANDO SE PRESENTA EN MEDIO DE LAS
MENTIRAS. ESTE ASPECTO RESALTA LA NECESIDAD DE DISCERNIMIENTO Y HONESTIDAD EN LA BUSQUEDA
DE SOLUCIONES Y CONOCIMIENTO. PREPARACIÓN PARA DESAFÍOS: OLOFIN SE ENFRENTA A DESAFÍOS
DURANTE SU BÚSQUEDA, COMO EL LUGAR ODIADO DONDE LA GENTE ANDA SIN CABEZAS. ESTO SUGIERE LA
IMPORTANCIA DE ESTAR PREPARADO PARA ENFRENTAR DESAFÍOS Y SUPERAR OBSTÁCULOS EN LA BÚSQUEDA
DE METAS SIGNIFICATIVAS. INTERCONEXIÓN Y DEPENDENCIA: LA RELACIÓN ENTRE ORÚNMILA Y OLOFIN
DESTACA LA IDEA DE LA INTERCONEXIÓN Y LA DEPENDENCIA MUTUA. LA AFIRMACIÓN DE QUE ORÚNMILA
NO SERÍA NADIE SIN OLOFIN Y VICEVERSA SUBRAYA LA IMPORTANCIA DE LA COLABORACIÓN Y EL APOYO
MUTUO EN LA TOMA DE DECISIONES Y LA RESOLUCIÓN DE PROBLEMAS. RECONOCIMIENTO DE LA
DIVERSIDAD: LA EXISTENCIA DE LAS 16 TIERRAS CON SUS RESPECTIVOS LUGARES COMPUESTOS SUGIERE
LA DIVERSIDAD EN EL MUNDO. ESTE ELEMENTO DESTACA LA IMPORTANCIA DE RECONOCER Y RESPETAR LA
DIVERSIDAD EN LA TOMA DE DECISIONES Y LA GOBERNANZA.''',
  '54. CUANDO INLE INDISPONÍA A SUS HIJOS.': '''PATAKI: CUANDO INLE SE ENCONTRÓ CON OLOFIN, INFLUENCIABA A SUS HIJOS DE TAL MANERA QUE, EN
LUGAR DE DARLES BUENOS CONSEJOS, LES PROPORCIONABA MALOS EJEMPLOS. AUNQUE NO ES POSIBLE
TENER HIJOS SIN MADRE, ÉL DEMOSTRARÍA QUE TAMPOCO PODÍA HABERLOS SIN PADRE. OLOFIN RETIRÓ
EL AGUA DEL CIELO, LO QUE PROVOCÓ QUE LAS PLANTAS SE SECARAN, LA TIERRA SE RAJARA Y TANTO
ANIMALES COMO PERSONAS COMENZARAN A MORIR. EN ESE MOMENTO. LOS HIJOS DE INLE EMPEZARON A
LLORAR POR LAS CALAMIDADES QUE ESTABAN OCURRIENDO Y DECIDIERON PRESENTARSE ANTE INLE PARA
TOMAR UN ACUERDO SOBRE QUIEN SE COMPROMETERÍA A LLEVAR UN MENSAJE A OLOFIN. EL PRIMERO EN
COMPROMETERSE FUE AGAYÚ, EL GAVILÁN, PERO AL PASAR DE ESTE PLANETA AL OTRO, LAS
VARIACIONES Y EL CALOR LO DEBILITARON CONSIDERABLEMENTE. LUEGO, EL ÁGUILA (ASHAÁ) ASUMIÓ
EL COMPROMISO, PERO EXPERIMENTÓ LA MISMA DIFICULTAD, DICIENDO QUE ESTABA DISPUESTA A MORIR
EN LA TIERRA QUE SUBIR ARRIBA. FINALMENTE, SE DECIDIÓ POR LA TIÑOSA (ALAKASO), QUIEN SUBIÓ
CON EL EBÓ Y SUPERÓ TODAS LAS DIFICULTADES, AUNQUE PERDIÓ EN EL VIAJE TODAS LAS PLUMAS DE
LA CABEZA. AL FIN, LOGRÓ LLEGAR AL CIELO, ENCONTRÓ LA PUERTA ABIERTA, ENTRÓ Y DESCUBRIÓ
DEPÓSITOS DE AGUA. CON GRAN SED, SE LANZÓ DE CABEZA PARA BEBERLA. OLOFIN LE PREGUNTÓ POR
QUÉ ESTABA ALLÍ, Y LA TIÑOSA LE RESPONDIÓ QUE TRAÍA UN MENSAJE DE INLE Y SUS HUOS PARA
OLOFIN. SORPRENDIDO, OLOFIN LE PIDIÓ QUE LA TRAJERAN ANTE ÉL Y LE COMUNICÓ QUE INLE LE
PEDÍA PERDÓN PARA ELLA Y SUS HIJOS, Y QUE YA ESTABA CONVENCIDO. LUEGO, OLOFIN LE DIJO A LA
TIÑOSA QUE, GRACIAS A SU INTERVENCIÓN, ESTABAN PERDONADOS, Y LE INDICÓ QUE SE FUERA,
ASEGURÁNDOLE QUE TRAS SU PARTIDA CAERÍAN LLOVIZNAS Y AGUA SUFICIENTE PARA TODOS. POR ESTA
RAZÓN, ALAKASO TIENE EL PODER DE ANUNCIAR CUÁNDO VA A LLOVER. ANTES DE SALIR, OLOFIN LE
PREGUNTÓ A LA TIÑOSA POR QUÉ TENÍA LA CABEZA SIN PLUMAS, Y ELLA LE EXPLICÓ QUE LAS HABÍA
PERDIDO EN EL VIAJE DEBIDO A LAS DIFICULTADES. ENTONCES, OLOFIN LA BENDIJO, ASEGURÁNDOLE
QUE ENCONTRARÍA LA COMIDA ANTES DE SALIR DE SU CASA Y QUE SERIA RESPETADA POR TODOS LOS
GOBIERNOS DEL MUNDO. POR ESO, ANTES DE SALIR, ELLA ENCUENTRA SU COMIDA. EBÓ: 2 PALOMAS,
AKEREBÉ, AGUA, PLUMA DE TIÑOSA, Y MUCHO DINERO. ENSEÑANZAS: INFLUENCIA DE LOS LÍDERES: LA
HISTORIA DESTACA CÓMO LA INFLUENCIA DE INLE SOBRE SUS HIJOS TENÍA UN IMPACTO NEGATIVO AL
PROPORCIONARLES MALOS EJEMPLOS EN LUGAR DE BUENOS CONSEJOS. ESTO SUBRAYA LA
RESPONSABILIDAD DE LOS LÍDERES Y LA IMPORTANCIA DE SU INFLUENCIA POSITIVA. CONSECUENCIAS
DE LA FALTA DE EQUILIBRIO: LA RETIRADA DEL AGUA POR PARTE DE OLOFIN RESULTÓ EN SEQUÍAS,
TIERRA AGRIETADA Y LA MUERTE DE PLANTAS, ANIMALES Y PERSONAS. LA HISTORIA ILUSTRA LAS
CONSECUENCIAS NEGATIVAS QUE PUEDEN SURGIR CUANDO HAY DESEQUILIBRIO EN LA NATURALEZA Y LA
NECESIDAD DE CUIDAR EL MEDIO AMBIENTE. PERDÓN Y REDENCIÓN: LA HISTORIA MUESTRA CÓMO, A
TRAVÉS DEL PERDÓN, SE PUEDE LOGRAR LA REDENCIÓN. INLE Y SUS HIJOS BUSCARON EL PERDÓN DE
OLOFIN, Y ESTE ACTO RESULTÓ EN LA RESTAURACIÓN Y EL RESTABLECIMIENTO DEL EQUILIBRIO.
SUPERACIÓN DE DESAFÍOS: LA ELECCIÓN DE LA TIÑOSA PARA LLEVAR EL MENSAJE A OLOFIN DESTACA
LA IMPORTANCIA DE ENFRENTAR Y SUPERAR LOS DESAFIOS. A PESAR DE PERDER LAS PLUMAS EN EL
VIAJE, LA TIÑOSA PERSEVERÓ Y TUVO ÉXITO EN SU MISIÓN. COMPROMISO Y SACRIFICIO: LOS
INTENTOS DE AGAYÚ Y EL ÁGUILA DE LLEVAR EL MENSAJE MUESTRAN EL COMPROMISO Y EL SACRIFICIO
EN LA BUSQUEDA DE SOLUCIONES. AUNQUE NO TUVIERON ÉXITO, SU DISPOSICIÓN PARA ARRIESGAR SUS
VIDAS DESTACA LA IMPORTANCIA DE LA DEDICACIÓN EN LA RESOLUCIÓN DE PROBLEMAS.
RECONOCIMIENTO Y BENDICIÓN: OLOFIN RECONOCIÓ Y BENDIJO A LA TIÑOSA POR SU VALENTÍA Y
ESFUERZO. ESTO RESALTA LA IMPORTANCIA DE RECONOCER Y RECOMPENSAR LOS ACTOS VALIENTES Y
POSITIVOS QUE CONTRIBUYEN AL BIENESTAR GENERAL. ESTAS LECCIONES ABORDAN TEMAS COMO
LIDERAZGO, PERDÓN, PERSEVERANCIA, COMPROMISO, RECONOCIMIENTO Y RESPETO, ENTRE OTROS
ASPECTOS FUNDAMENTALES PARA LA VIDA Y LA CONVIVENCIA.''',
  '55. EL QUE IMITA, FRACASA.': '''PATAKI: EL HALCÓN Y EL ÁGUILA GENERAN ENVIDIA ENTRE LOS DEMÁS PÁJAROS DEBIDO A SU
CAPACIDAD PARA VOLAR A ALTURAS IMPRESIONANTES. UN DÍA, IMPULSADOS POR LA ENVIDIA, LOS
OTROS PÁJAROS SE REUNIERON Y ACORDARON ORGANIZAR UNA APUESTA CON EL ÁGUILA Y EL HALCÓN. LA
APUESTA CONSISTÍA EN DETERMINAR QUIÉN LLEGARÍA PRIMERO A LA CIMA DE UNA MONTAÑA. COMO EL
TRAYECTO ERA CORTO LOS PÁJAROS MÁS PEQUEÑOS PENSARON QUE PODRÍAN VENCER FÁCILMENTE A ESTAS
DOS AVES YA QUE TENÍAN MAYOR PESO Y LES SERÍA MAS DIFÍCIL LLEGAR A LA CIMA. LLEGÓ EL DÍA
DE LA CARRERA, Y TODOS EMPRENDIERON EL VUELO. LAS AVES MÁS PEQUEÑAS LOGRARON RÁPIDAMENTE
UNA GRAN VENTAJA EN DISTANCIA, PERO SE CANSARON RÁPIDAMENTE. EN POCO TIEMPO, EL ÁGUILA Y
EL HALCÓN ALCANZARON Y CAPTURARON A TODAS LAS AVES MÁS PEQUEÑAS Y LAS DEVORARON SIN QUE
ESTAS PUDIERAN EVITARLO DEBIDO AL AGOTAMIENTO Y A LA POCA RESISTENCIA QUE PUDIERON OFRECER
PARA DEFENDERSE. AQUÍ QUEDA CLARO QUE AQUELLOS QUE INTENTAN IMITAR SIN CONSIDERAR SUS
PROPIAS LIMITACIONES ESTÁN DESTINADOS AL FRACASO. ENSEÑANZAS: ENVIDIA Y COMPETENCIA
DESMEDIDA: LA HISTORIA DESTACA CÓMO LA ENVIDIA ENTRE LOS DEMÁS PÁJAROS LLEVÓ A UNA
COMPETENCIA DESMEDIDA. LA ENVIDIA PUEDE CONDUCIR A DECISIONES IMPULSIVAS Y A SUBESTIMAR
LAS HABILIDADES DE LOS DEMÁS. SUBESTIMACIÓN DE LAS CAPACIDADES: LOS PÁJAROS MÁS PEQUEÑOS
SUBESTIMARON LAS HABILIDADES DEL ÁGUILA Y EL HALCÓN DEBIDO A SU TAMAÑO Y PESO
APARENTEMENTE SUPERIOR. LA HISTORIA RESALTA LA IMPORTANCIA DE NO SUBESTIMAR A LOS DEMÁS Y
CONSIDERAR SUS HABILIDADES REALES. CONSECUENCIAS DE LA FALTA DE ESTRATEGIA: A PESAR DE
OBTENER UNA VENTAJA INICIAL, LAS AVES MÁS PEQUEÑAS NO TENÍAN UNA ESTRATEGIA A LARGO PLAZO.
ESTO LLEVÓ AL AGOTAMIENTO Y, FINALMENTE, A SU DERROTA. LA HISTORIA ENSENA LA IMPORTANCIA
DE PLANIFICAR Y TENER UNA ESTRATEGIA CLARA. IMITACIÓN SIN REFLEXIÓN: LOS PÁJAROS MÁS
PEQUEÑOS INTENTARON IMITAR LAS ACCIONES DEL ÁGUILA Y EL HALCÓN SIN CONSIDERAR SUS PROPIAS
LIMITACIONES. ESTO LLEVÓ AL FRACASO Y A SU CAPTURA. LA LECCIÓN AQUÍ ES QUE IMITAR SIN
REFLEXIÓN PUEDE RESULTAR EN DESASTRE. RECONOCIMIENTO DE LAS FORTALEZAS Y LIMITACIONES: LA
HISTORIA DESTACA LA IMPORTANCIA DE RECONOCER LAS FORTALEZAS Y LIMITACIONES PROPIAS Y
AJENAS. ENTENDER LAS CAPACIDADES REALES DE UNO Y DE LOS DEMÁS ES CRUCIAL PARA TOMAR
DECISIONES INFORMADAS. NO DEJAR QUE LA ENVIDIA GOBIERNE LAS ACCIONES: LA ENVIDIA IMPULSÓ
LA COMPETENCIA, PERO TAMBIÉN LLEVÓ A CONSECUENCIAS DESASTROSAS. LA HISTORIA SUBRAYA CÓMO
DEJAR QUE LA ENVIDIA GOBIERNE LAS ACCIONES PUEDE CONDUCIR A RESULTADOS NEGATIVOS. LA
IMPORTANCIA DE LA RESISTENCIA Y LA RESISTENCIA: AUNQUE LAS AVES MÁS PEQUEÑAS OBTUVIERON
UNA VENTAJA INICIAL, SU FALTA DE RESISTENCIA Y RESISTENCIA LOS LLEVÓ AL AGOTAMIENTO. LA
RESISTENCIA ES CLAVE PARA SUPERAR DESAFÍOS Y ALCANZAR METAS. ESTAS ENSEÑANZAS OFRECEN
REFLEXIONES SOBRE LA IMPORTANCIA DE LA HUMILDAD, LA PLANIFICACIÓN ESTRATÉGICA, LA
AUTOEVALUACIÓN Y LA RESISTENCIA EN LA BÚSQUEDA DEL ÉXITO Y LA SUPERACIÓN DE DESAFÍOS.''',
  '56. LA CABEZA SIN CUERPO (SÓLO ORÚNMILA LO SALVA).': '''PATAKI: EN LA PLAZA, LA CABEZA YACÍA SIN CUERPO, RODEADA DE MUCHOS COCOS CON LOS QUE
COMERCIABA. EN ESE MOMENTO, SHANGÓ LLEGÓ Y LA CABEZA LE INDICÓ QUE NO PODÍA TOMAR LOS
COCOS SIN ANTES REMEDIAR SU SITUACIÓN. EXPLICÓ QUE ELLA SOLO PODÍA HABLAR Y QUE SHANGÓ
DEBÍA ENCARGARSE DE TODO LO DEMÁS. ADEMÁS, MANIFESTÓ SU ABURRIMIENTO Y CANSANCIO ANTE ESA
SITUACIÓN. SHANGÓ TOMÓ LOS COCOS SIN BRINDARLE NINGUNA SOLUCIÓN, Y LA CABEZA, MOLESTA, LO
MANDÓ A PASEO. POSTERIORMENTE, ORÚNMILA LLEGÓ A LA PLAZA Y OBSERVÓ LOS COCOS. SE LOS PIDIÓ
A LA CABEZA, Y ESTA LE RESPONDIÓ QUE LOS ENTREGARÍA TODOS A CAMBIO DE QUE LE REMEDIARA SU
SITUACIÓN. ORÚNMILA ACEPTÓ LA CONDICIÓN Y LE INDICÓ QUE DEBÍA REALIZAR UNA ROGACIÓN CON
ANIMALES, VIANDAS, 2 COCOS Y MUCHO DINERO. DURANTE LOS 16 DÍAS DE ESTA SITUACIÓN, LA
CABEZA DEBÍA ESTAR CONSUMIENDO COCO. LA CABEZA CUMPLIÓ CON EL PROCESO, Y PRIMERO LE FUE
SALIENDO EL PECHO, SEGUIDO DE LOS BRAZOS Y DEMÁS EXTREMIDADES. AL FINALIZAR LOS 16 DÍAS,
SE COMPLETÓ TODO EL CUERPO. LOS HUESOS DE LOS ANIMALES CONTRIBUYERON A FORMAR LOS HUESOS
DE LOS BRAZOS, COSTILLAS, ETC., MIENTRAS QUE LAS VIANDAS SE UTILIZARON PARA LAS PARTES DE
LAS VISCERAS Y PARTES BLANDAS DEL CUERPO. UNA VEZ COMPLETA, LA CABEZA AGRADECIÓ MUCHO A
ORÚNMILA Y LE RECONOCIÓ COMO SU PADRE, SEÑALANDO QUE ÉL HABÍA VENIDO AL MUNDO PARA
GOBERNAR, Y ESTA OPERACIÓN ERA NECESARIA PARA QUE TODO FUERA COMPLETO. LA CABEZA PROCLAMÓ:
"DESDE ESTE INSTANTE, ORÚNMILA GOBERNARÁ ELMUNDO Y TODOS TENDRÁN QUE IR A SUS PIES"
ENSEÑANZAS: RESPONSABILIDAD Y EMPATÍA: SHANGO, AL ENCONTRARSE CON LA CABEZA EN LA PLAZA,
NO ASUME LA RESPONSABILIDAD NI MUESTRA EMPATIA HACIA SU SITUACION. EN CONTRASTE, ORÚNMILA
COMPRENDE LA NECESIDAD DE LA CABEZA Y SE COMPROMETE A AYUDAR, DEMOSTRANDO EMPATÍA Y
RESPONSABILIDAD HACIA LOS DEMÁS. RECONOCIMIENTO DE LIMITACIONES: LA CABEZA RECONOCE SUS
LIMITACIONES AL EXPLICAR QUE SOLO PUEDE HABLAR Y NECESITA AYUDA PARA LAS DEMÁS ACCIONES.
ESTA HUMILDAD AL RECONOCER LAS LIMITACIONES ES FUNDAMENTAL PARA BUSCAR SOLUCIONES Y
MEJORAR LA PROPIA SITUACIÓN. CONSECUENCIAS DE LA INDIFERENCIA: LA ACTITUD INDIFERENTE DE
SHANGÓ TIENE CONSECUENCIAS NEGATIVAS, YA QUE LA CABEZA, MOLESTA POR LA FALTA DE AYUDA, LO
MANDA A PASEO. ESTO DESTACA CÓMO LA INDIFERENCIA PUEDE AFECTAR LAS RELACIONES Y GENERAR
CONFLICTOS. ACEPTAR AYUDA CON CONDICIONES: LA CABEZA, AL ACEPTAR ENTREGAR LOS COCOS A
CAMBIO DE QUE LE REMEDIAN SU SITUACIÓN, ILUSTRA LA IMPORTANCIA DE ESTABLECER CONDICIONES Y
DE QUE LAS AYUDAS SEAN MUTUAS. LA COLABORACIÓN EFECTIVA IMPLICA COMPROMISOS DE AMBAS
PARTES. PROCESO DE SUPERACIÓN: LA ROGACIÓN PRESCRITA POR ORÚNMILA SIMBOLIZA UN PROCESO DE
SUPERACIÓN A TRAVÉS DEL SACRIFICIO. LA CABEZA, AL CUMPLIR CON ESTE PROCESO, EXPERIMENTA
UNA TRANSFORMACIÓN GRADUAL QUE CULMINA EN LA COMPLETITUD DE SU CUERPO. RECONOCIMIENTO Y
GRATITUD: UNA VEZ QUE LA CABEZA ALCANZA SU TOTALIDAD, MUESTRA GRATITUD HACIA ORÚNMILA Y LO
RECONOCE COMO SU PADRE. ESTO RESALTA LA IMPORTANCIA DE RECONOCER Y AGRADECER A AQUELLOS
QUE BRINDAN AYUDA Y CONTRIBUYEN AL PROPIO BIENESTAR. GOBERNABILIDAD Y RESPETO: LA
PROCLAMACIÓN DE LA CABEZA DE QUE, A PARTIR DE ESE MOMENTO, ORÚNMILA GOBERNARÁ EL MUNDO Y
TODOS DEBEN IR A SUS PIES, DESTACA LA IMPORTANCIA DE LA GOBERNABILIDAD BASADA EN EL
RESPETO Y LA COLABORACIÓN, NO EN LA IMPOSICIÓN. ESTAS LECCIONES OFRECEN REFLEXIONES SOBRE
LA IMPORTANCIA DE LA RESPONSABILIDAD, LA EMPATÍA, LA COLABORACIÓN MUTUA, EL RECONOCIMIENTO
DE LIMITACIONES Y LA GRATITUD EN LAS RELACIONES HUMANAS.''',
  '57. TODOS LOS RÍOS DESEMBOCAN EN EL MAR.': '''PATAKI: EN ESTE ODU, YEMAYÁ Y OSHÚN ENFRENTARON DESAFÍOS QUE LLEVARON A SU SEPARACIÓN.
COMO CONSECUENCIA, OSHÚN ATRAVESÓ NUMEROSAS DIFICULTADES, Y ES EN ESTE PERÍODO TUMULTUOSO
QUE COMENZARON A SURGIR LOS RIOS. CADA VEZ QUE OSHUN PASABA LA NOCHE EN UN LUGAR, AL
LEVANTARSE, UN RÍO SE FORMABA EN ESA UBICACIÓN ESPECÍFICA. ESTE FENÓMENO EXPLICA LA
ABUNDANCIA DE RÍOS EN TODO EL MUNDO, TODOS FLUYENDO HACIA UN ÚNICO MAR. LA SEPARACIÓN
ENTRE YEMAYÁ Y OSHÚN, ADEMÁS DE AFECTAR SU RELACIÓN, TUVO UN IMPACTO SIGNIFICATIVO EN LA
CONFIGURACIÓN GEOGRÁFICA AL DAR ORIGEN A LOS NUMEROSOS CURSOS DE AGUA QUE CONVERGEN
FINALMENTE EN EL MAR. ENSEÑANZAS: SEPARACIÓN Y CONSECUENCIAS GEOGRÁFICAS: LA HISTORIA
DESTACA CÓMO LAS ACCIONES Y DECISIONES DE LOS ORISHAS AFECTAN NO SOLO SU RELACIÓN PERSONAL
SINO TAMBIÉN EL ENTORNO GEOGRÁFICO. LA SEPARACIÓN ENTRE YEMAYÁ Y OSHÚN RESULTA EN LA
FORMACIÓN DE NUMEROSOS RIOS, LO QUE SUGIERE QUE LAS DECISIONES INDIVIDUALES PUEDEN TENER
CONSECUENCIAS A GRAN ESCALA. EL ORIGEN DE LOS FENÓMENOS NATURALES: LA MITOLOGÍA YORUBA A
MENUDO UTILIZA HISTORIAS DE ORISHAS PARA EXPLICAR FENÓMENOS NATURALES. EN ESTE CASO, LA
FORMACIÓN DE RÍOS SE ATRIBUYE A LA PRESENCIA DE OSHÚN EN DIFERENTES LUGARES DURANTE UN
PERÍODO TUMULTUOSO. ESTO REFLEJA CÓMO LAS CULTURAS TRADICIONALES EXPLICAN LA NATURALEZA A
TRAVÉS DE NARRATIVAS MITOLÓGICAS. ADAPTACIÓN Y TRANSFORMACIÓN: A PESAR DE LAS
DIFICULTADES, OSHÚN SE ADAPTA A LAS CIRCUNSTANCIAS Y EXPERIMENTA UNA TRANSFORMACIÓN QUE
IMPACTA DIRECTAMENTE EN LA GEOGRAFÍA. LA CAPACIDAD DE ADAPTARSE A LOS CAMBIOS Y APRENDER
DE LAS EXPERIENCIAS DIFÍCILES ES UNA LECCIÓN VALIOSA. INTERCONEXIÓN DE ELEMENTOS
NATURALES: LA HISTORIA SUBRAYA LA INTERCONEXIÓN ENTRE LOS ELEMENTOS NATURALES. LA
SEPARACIÓN ENTRE DOS DEIDADES AFECTA LA FORMACIÓN DE RÍOS, MOSTRANDO CÓMO LOS EVENTOS EN
UN ÁMBITO PUEDEN INFLUIR EN OTROS ASPECTOS DE LA NATURALEZA. LECCIONES SOBRE RELACIONES
HUMANAS: AUNQUE LA HISTORIA SE CENTRA EN DEIDADES, PUEDE EXTRAPOLARSE A LECCIONES SOBRE
RELACIONES HUMANAS. LA TOMA DE DECISIONES PUEDE TENER UN IMPACTO MÁS AMPLIO DEL QUE
IMAGINAMOS, Y LA SEPARACIÓN O DISCORDIA PUEDE TENER CONSECUENCIAS SIGNIFICATIVAS EN VARIOS
ASPECTOS DE LA VIDA. ESTAS LECCIONES REFLEJAN LA RIQUEZA SIMBÓLICA Y CULTURAL DE LAS
HISTORIAS MITOLÓGICAS YORUBA, QUE HAN SIDO TRANSMITIDAS A LO LARGO DEL TIEMPO PARA
TRANSMITIR CONOCIMIENTOS, VALORES Y COMPRENSIÓN DEL MUNDO.''',
  '58. LA TRAICIÓN DE EJIOGBE A ORAGUN.': '''PATAKI: OLOFIN SE ENCONTRABA SUMIDO EN UN ESTADO AVANZADO DE CEGUERA CUANDO ORAGUN DECIDIÓ
VISITARLO. ORAGUN, CONOCIDO POR LLEVAR SIEMPRE UNA CHAQUETA DE CUERO, ERA RECONOCIDO POR
OLOFIN A TRAVÉS DEL TACTO CUANDO ESTE ÚLTIMO LE PASABA LA MANO. AL LLEGAR A LA RESIDENCIA
DE OLOFIN, ORAGUN GOLPEÓ LA PUERTA. OLOFIN, INQUIRIENDO SOBRE SU IDENTIDAD, RECIBIÓ LA
RESPUESTA: "SOY YO, TU HIJO ORAGUN, PADRE": OLOFIN PERMITIÓ SU ENTRADA Y LE PREGUNTÓ SOBRE
SU PROPÓSITO. "VENGO POR LO QUE ME DUISTE QUE ME IBAS A DAR, PADRE", EXPRESÓ ORAGUN. DADO
EL ESTADO DE OLOFIN, ESTE LE SUGIRIÓ QUE VOLVIERA OTRO DÍA. EJÍOGBÉ, QUE HABÍA PRESENCIADO
LA SITUACIÓN, SE PRESENTÓ AL DÍA SIGUIENTE CON UNA CHAQUETA DE CUERO SIMILAR A LA DE
ORAGUN. TRAS TOCAR LA PUERTA, OLOFIN PREGUNTÓ QUIÉN ERA, Y EJÍOGBÉ RESPONDIÓ DE MANERA
SIMILAR A ORAGUN. OLOFIN LE HIZO PASAR Y CONSULTÓ SOBRE SU DESEO. EL FALSO ORAGUN AFIRMÓ:
"LO QUE USTED ME IBA A DAR". OLOFIN, IRRITADO POR LA INSISTENCIA, CONCEDIÓ: "TE CONCEDO EL
GOBIERNO Y SERÁS EL PRIMERO POR TU BUENA CONDUCTA Y CONOCIMIENTO". EJÍOGBÉ SE RETIRÓ Y, A
LOS TRES DÍAS, SE PRESENTÓ ORAGUN. NUEVAMENTE, OLOFIN LO HIZO PASAR Y LE PREGUNTÓ SOBRE SU
PROPÓSITO. ORAGUN INSISTIÓ: "LO QUE USTED ME IBA A DAR, PADRE". OLOFIN, ENFADADO, LE DIJO:
"PERO SI TE ACABO DE DAR EL GOBIERNO DEL MUNDO Y AÚN NO ESTÁS CONFORME". ORAGUN RESPONDIÓ:
"PADRE, USTED NO ME HA DADO NADA". ENFURECIDO, OLOFIN LO MALDIJO Y LO EXPULSÓ DE SU
PALACIO. ORAGUN, AVERGONZADO Y LLOROSO, SE ENCONTRÓ CON AZOJÜANO EN EL CAMINO QUIEN AL
PREGUNTARLE POR QUÉ LLORABA, ESCUCHÓ TODA LA HISTORIA. CONVENCIDO DE CORREGIR LA
INJUSTICIA, AZOJÜANO PERSUADIÓ A ORAGUN PARA IR A LA CASA DE OLOFIN. AL LLEGAR, OLOFIN,
IDENTIFICANDO A AZOJÜANO COMO SU BUEN AMIGO, LO HIZO PASAR. AZOJÜANO EXPLICÓ: "NO DESEO
NADA PARA MÍ. VENGO A REPARAR UNA INJUSTICIA COMETIDA CONTRA TU HIJO, ORAGUN". A PESAR DE
LAMENTAR NO PODER CAMBIAR SU PALABRA, OLOFIN ACEPTÓ: "YA NO PUEDO HACER NADA, PERO DESDE
HOY, TU, ORAGUN SIEMPRE ESTARÁ DETRÁS DE EJÍOGBÉ". ENSENANZAS: LA AMBICIÓN PUEDE CONDUCIR
A LA TRAICIÓN: LA HISTORIA SUGIERE QUE LA AMBICIÓN DESMEDIDA PUEDE LLEVAR A LA TRAICIÓN.
EJÍOGBÉ, AL QUERER OBTENER EL MISMO RECONOCIMIENTO QUE ORAGUN, TRAICIONA SU CONFIANZA Y
BUSCA SU PROPIO BENEFICIO. LA IMPORTANCIA DE LA EMPATÍA: EJÍOGBÉ CARECE DE EMPATÍA HACIA
ORAGUN Y SOLO BUSCA SU PROPIO BENEFICIO. LA HISTORIA DESTACA CÓMO LA EMPATÍA Y LA
COMPRENSIÓN PUEDEN PREVENIR ACCIONES PERJUDICIALES HACIA LOS DEMÁS. LA PACIENCIA Y LA
PERSISTENCIA: ORAGUN FUE PERSISTENTE EN SU SOLICITUD, Y ESTO, AUNQUE CAUSÓ FRUSTRACIÓN,
FINALMENTE LO LLEVÓ A OBTENER LO QUE DESEABA. LA PERSISTENCIA PUEDE SER UNA CUALIDAD
VALIOSA, PERO TAMBIÉN ES CRUCIAL SABER CUÁNDO ES EL MOMENTO ADECUADO PARA INSISTIR. LA
IMPORTANCIA DE LA JUSTICIA: AZOJÜANO, AL INTERVENIR PARA CORREGIR LA INJUSTICIA COMETIDA
CONTRA ORAGUN, DESTACA LA IMPORTANCIA DE LA JUSTICIA Y CÓMO DEBEMOS ESFORZARNOS POR
RECTIFICAR SITUACIONES INCORRECTAS. LAS DECISIONES Y SUS CONSECUENCIAS: OLOFIN OTORGÓ EL
GOBIERNO A EJÍOGBÉ EN UN MOMENTO DE IRRITACIÓN, Y ESTO TUVO CONSECUENCIAS. LA HISTORIA
SUBRAYA CÓMO NUESTRAS DECISIONES, INCLUSO TOMADAS EN MOMENTOS DE EMOCIÓN, PUEDEN TENER UN
IMPACTO DURADERO. LA AMISTAD VERDADERA: AZOJÜANO DEMOSTRÓ SER UN AMIGO VERDADERO AL
INTERVENIR PARA CORREGIR LA INJUSTICIA, SIN BUSCAR NADA A CAMBIO. ESTO RESALTA LA
IMPORTANCIA DE LA AMISTAD Y CÓMO LOS VERDADEROS AMIGOS ESTÁN DISPUESTOS A AYUDAR INCLUSO
EN SITUACIONES DIFICILES. EN RESUMEN, LA HISTORIA OFRECE LECCIONES SOBRE HONESTIDAD,
PACIENCIA, JUSTICIA, CONSECUENCIAS DE DECISIONES, COMUNICACIÓN EFECTIVA Y LA IMPORTANCIA
DE LA VERDADERA AMISTAD.''',
  '59. YEMAYÁ CREA LOS REMOLINOS.': '''LOS GANSOS GOZABAN DEL FAVOR DE YEMAYÁ. NO OBSTANTE, LOS CAZADORES REGULARMENTE APARECÍAN
Y CAPTURABAN UNA ABUNDANTE CANTIDAD DE GANSOS, DESCUIDANDO LA NECESIDAD DE DEJAR
SUFICIENTES PARA ASEGURAR SU REPRODUCCIÓN. A PESAR DE LAS ADVERTENCIAS DE YEMAYÁ, EN LAS
CUALES LES INDICABA QUE NO SE LLEVARAN TODOS Y QUE DEJARAN ALGUNOS PARA GARANTIZAR SU
PROLIFERACIÓN, LOS CAZADORES HACÍAN CASO OMISO. PARA ALCANZAR LA ISLA DE LOS GANSOS, ERA
IMPRESCINDIBLE CRUZAR EL MAR. YEMAYÁ OPTÓ POR AGUARDAR SU REGRESO Y, EN EL MOMENTO
INDICADO, CREÓ IMPETUOSOS REMOLINOS QUE ABSORBIERON LOS BOTES JUNTO CON LOS CAZADORES QUE
SE ENCONTRABAN A BORDO. NOTA: RECIBIR OLOKUN ENSEÑANZAS: EQUILIBRIO Y RESPETO POR LA
NATURALEZA: LA ADVERTENCIA DE YEMAYÁ SOBRE LA NECESIDAD DE DEJAR SUFICIENTES GANSOS PARA
LA PROCREACIÓN DESTACA LA IMPORTANCIA DE MANTENER UN EQUILIBRIO EN LA RELACIÓN ENTRE LOS
SERES HUMANOS Y LA NATURALEZA. RESPETAR Y PRESERVAR LA VIDA SILVESTRE ES CRUCIAL PARA EL
SOSTENIMIENTO DE LA BIODIVERSIDAD. DESOBEDIENCIA Y CONSECUENCIAS: LA DESOBEDIENCIA POR
PARTE DE LOS CAZADORES A LAS ADVERTENCIAS DE YEMAYA LLEVA A CONSECUENCIAS NEGATIVAS. LA
HISTORIA SUBRAYA CÓMO LAS ACCIONES IRRESPONSABLES PUEDEN TENER REPERCUSIONES, NO SOLO PARA
LOS INDIVIDUOS INVOLUCRADOS, SINO TAMBIÉN PARA LA COMUNIDAD EN SU CONJUNTO. INTERVENCIÓN
DIVINA: LA CREACIÓN DE REMOLINOS POR PARTE DE YEMAYÁ PARA CASTIGAR A LOS CAZADORES RESALTA
LA IDEA DE LA INTERVENCIÓN DIVINA O CÓSMICA EN RESPUESTA A LA VIOLACIÓN DE PRINCIPIOS
ÉTICOS O NATURALES. ESTO REFUERZA LA NOCIÓN DE QUE LAS ACCIONES HUMANAS NO PASAN
DESAPERCIBIDAS Y PUEDEN PROVOCAR RESPUESTAS DIRECTAS DE LAS FUERZAS DE LA NATURALEZA O
DEIDADES. CONSECUENCIAS DE LA AVARICIA: LA CODICIA DE LOS CAZADORES, AL QUERER
APROVECHARSE AL MAXIMO DE LOS RECURSOS SIN CONSIDERAR LAS CONSECUENCIAS A LARGO PLAZO, ES
UN RECORDATORIO DE LOS PELIGROS DE LA AVARICIA. LA EXPLOTACIÓN EXCESIVA DE LOS RECURSOS
NATURALES PUEDE TENER IMPACTOS PERJUDICIALES EN EL ECOSISTEMA Y, EN ÚLTIMA INSTANCIA, EN
LA SUPERVIVENCIA HUMANA. CONEXIÓN ENTRE ACCIONES Y RESULTADOS: LA HISTORIA ENFATIZA LA
RELACIÓN DIRECTA ENTRE LAS ACCIONES DE LOS CAZADORES Y LOS RESULTADOS QUE EXPERIMENTAN.
ESTE PRINCIPIO ES APLICABLE EN DIVERSOS ASPECTOS DE LA VIDA, RESALTANDO LA IMPORTANCIA DE
TOMAR DECISIONES RESPONSABLES Y CONSCIENTES. RESPETO POR LOS AVISOS Y ADVERTENCIAS: LA
NARRATIVA DESTACA LA IMPORTANCIA DE ESCUCHAR Y RESPETAR LOS CONSEJOS Y ADVERTENCIAS, YA
SEA DE LA NATURALEZA O DE FIGURAS ESPIRITUALES. IGNORAR ESTAS SEÑALES PUEDE TENER
CONSECUENCIAS NEGATIVAS. EN RESUMEN, LA HISTORIA DE YEMAYÁ Y LOS CAZADORES OFRECE
LECCIONES VALIOSAS SOBRE LA RELACIÓN ENTRE LOS SERES HUMANOS Y LA NATURALEZA, LA
IMPORTANCIA DE LA RESPONSABILIDAD Y EL RESPETO, Y LAS CONSECUENCIAS DE LAS ACCIONES
IRRESPONSABLES.''',
  '60. CUANDO EL CUERPO SE CANSÓ DE LLEVAR LA CABEZA.': '''PATAKI: UNA VEZ, EL CUERPO SE CANSÓ DE LLEVAR LA CABEZA Y LOS PIES, HASTA QUE EL CUERPO
DIJO: "HAGAN LO QUE USTEDES SE LES ANTOJE, Y CADA UNO SE PREPARÓ PARA HACER SU VOLUNTAD.
LA CABEZA, COMO LA MÁS INTELIGENTE, EMPEZÓ A ACONSEJARLE AL CUERPO CUÁNTOS VICIOS Y
LOCURAS PODÍA DISFRUTAR, YA QUE ESTO CONSTITUÍA PLACERES Y TRIUNFOS, HASTA QUE, POR ESE
MEDIO, FUERA DEBILITÁNDOSE Y TUVIERA QUE SENTARSE EN UN LUGAR DONDE SOLO PENSARA A DÓNDE
MÁS PODÍA IR. ENTONCES, EL CUERPO EMPEZÓ A COMPORTARSE DE MANERA INDEPENDIENTE HASTA QUE
LA SEPARACIÓN ENTRE LOS DOS TOMÓ UN CARIZ QUE OLOFIN DIJO: "YO LOS HE HECHO A LOS DOS PARA
QUE EL UNO SEA PARA EL OTRO; ESTO NO PUEDE SEGUIR MÁS” Y DESDE ENTONCES, SE UNIERON POR
MANDATO DE OLOFIN. NOTA: A PESAR DE ESTE ARREGLO, HAY QUE FIJARSE EN QUE HAY SERES EN EL
MUNDO QUE, PARA DARLE TODO EL GUSTO AL CUERPO, SE PIERDEN, Y ESTO MISMO PASA CON LA
CABEZA. NOTA: AQUÍ LO ÚNICO QUE A USTED LE SIRVE ES LA CABEZA, NO LA PIERDA. SI TIENE UNA
ENFERMEDAD EN SU CUERPO POR DESCUIDO, TIENE QUE ROGARSE LA CABEZA CON OCHO COSAS
DISTINTAS. ENSEÑANZAS: COOPERACIÓN Y COMPLEMENTARIEDAD: LA HISTORIA DESTACA LA IMPORTANCIA
DE LA COOPERACIÓN Y LA COMPLEMENTARIEDAD ENTRE DIFERENTES PARTES DE UN SISTEMA. EN ESTE
CASO, EL CUERPO Y LA CABEZA ESTÁN DESTINADOS A TRABAJAR JUNTOS PARA LOGRAR UN EQUILIBRIO.
CONSECUENCIAS DE LA FALTA DE COORDINACIÓN: LA SEPARACIÓN ENTRE LA CABEZA Y EL CUERPO
RESULTA EN CAOS Y DESORDEN. ESTO RESALTA LAS CONSECUENCIAS NEGATIVAS QUE PUEDEN SURGIR
CUANDO LAS PARTES DE UN SISTEMA NO TRABAJAN EN ARMONIA. EL PAPEL DE LA INTELIGENCIA: LA
CABEZA, REPRESENTANDO LA INTELIGENCIA, TIENE LA RESPONSABILIDAD DE GUIAR AL CUERPO. SIN
EMBARGO, LA HISTORIA ADVIERTE SOBRE EL PELIGRO DE UTILIZAR LA INTELIGENCIA DE MANERA
EGOISTA, SIN CONSIDERAR EL BIENESTAR GENERAL. LA IMPORTANCIA DE LA DIRECCIÓN Y EL
PROPÓSITO: LA INTERVENCIÓN DE OLOFIN SUBRAYA LA IMPORTANCIA DE TENER UNA DIRECCIÓN CLARA Y
UN PROPÓSITO EN LA VIDA. LA FALTA DE PROPÓSITO LLEVÓ A LA SEPARACIÓN, PERO LA REUNIÓN
OCURRIÓ CUANDO SE RESTABLECIÓ UN PROPÓSITO COMPARTIDO. ADVERTENCIA CONTRA LOS EXCESOS Y
VICIOS: EL RELATO ADVIERTE SOBRE LOS PELIGROS DE ENTREGARSE A LOS EXCESOS Y VICIOS, YA QUE
ESTO PUEDE DEBILITAR LA UNIDAD Y CONDUCIR A LA PÉRDIDA DE DIRECCIÓN Y PROPÓSITO. EL CUERPO
Y LA CABEZA COMO METÁFORA DE LA VIDA: LA HISTORIA PUEDE INTERPRETARSE COMO UNA METÁFORA DE
LA VIDA, DESTACANDO LA IMPORTANCIA DE EQUILIBRAR LOS DESEOS DEL CUERPO (REPRESENTATIVOS DE
LOS PLACERES MATERIALES) CON LA DIRECCIÓN Y EL JUICIO DE LA CABEZA. CUIDADO Y ATENCIÓN
PERSONAL: LA NOTA FINAL SUBRAYA LA IMPORTANCIA DE CUIDAR TANTO DEL CUERPO COMO DE LA
MENTE. IGNORAR LA SALUD MENTAL O FÍSICA PUEDE LLEVAR A ENFERMEDADES Y DESEQUILIBRIOS. EN
RESUMEN, LA HISTORIA OFRECE LECCIONES VALIOSAS SOBRE LA COLABORACIÓN, LA INTELIGENCIA, LA
DIRECCIÓN, EL PROPÓSITO Y LA IMPORTANCIA DE MANTENER UN EQUILIBRIO ENTRE LOS ASPECTOS
FISICOS Y MENTALES DE LA VIDA.''',
  '61. CUANDO LA SOMBRA ADQUIRIÓ PODER.': '''PATAKI: LA SOMBRA SE SENTÍA AGOBIADA POR SER LA MENOS CONSIDERADA EN LA CASA DE OLOFIN.
ELLA OCUPABA UN LUGAR INFERIOR, Y NI LOS ANIMALES NI LOS HOMBRES LE PRESTABAN ATENCIÓN. SU
QUEJA ANTE ESTA INDIFERENCIA SIEMPRE OBTENÍA LA MISMA RESPUESTA: "A VER SI PARA VERTE A TI
HABRÁ QUE RENDIRTE HONORES COMO A OBATALA": ESTE MENOSPRECIADO COMENTARIO LLEVÓ A LA
SOMBRA, LLENA DE IRA, A BUSCAR A OBATALA Y CONTARLE SU SITUACIÓN. OBATALA ACONSEJÓ A LA
SOMBRA REALIZAR UN EBBO CON UN CHIVO, AGUA, TIERRA, UN GALLO, TRES CUJES, GENERO BLANCO,
EKU, EYA, EFUN MEYI TONTU, OPOLOPO OWO. LUEGO, LE INDICÓ QUE TOMARA UNA PALANGANA CON EKO,
REALIZARA ASHE Y LO DISPERSARA A LOS CUATRO VIENTOS, AL MAR, AL RÍO Y A LA TIERRA, PARA
QUE TODOS PUDIERAN VERLA DESPUÉS DE LA SALIDA DEL SOL LA SOMBRA REALIZÓ EL EBBO, Y DESDE
ENTONCES, TODO LO QUE ESTÁ EN LA TIERRA LA SOMBRA LO VIÓ, ADEMÁS ADQUIRIÓ TRES PODERES:
CONVERTIRSE EN AMIGA DE LA MUERTE. CONVERTIRSE EN PERSEGUIDORA DEL ENEMIGO. CONVERTIRSE EN
SALVADORA DEL INOCENTE. GRACIAS A ESTOS PODERES, LA SOMBRA POSEE LA HABILIDAD DE
DESCUBRIR, OCULTAR Y EN ÚLTIMA INSTANCIA, INFLIGIR LA MUERTE. ENSEÑANZAS: SUPERACIÓN DE LA
ADVERSIDAD: LA HISTORIA DE LA SOMBRA REFLEJA LA CAPACIDAD DE SUPERAR LA ADVERSIDAD Y LA
MARGINACIÓN. A PESAR DE SER MENOSPRECIADA, LA SOMBRA BUSCÓ UNA SOLUCIÓN PARA CAMBIAR SU
SITUACIÓN. CONSECUENCIAS DE LA CODICIA: EL MENOSPRECIO HACIA LA SOMBRA POR PARTE DE OTROS
PERSONAJES REVELA LAS CONSECUENCIAS DE LA CODICIA Y LA FALTA DE EMPATIA. LA HISTORIA
ILUSTRA CÓMO LA AMBICIÓN DESMESURADA PUEDE LLEVAR A MENOSPRECIAR A AQUELLOS QUE SE
CONSIDERAN INFERIORES. CONFIANZA EN LA SABIDURÍA DE LOS MAYORES: LA SOMBRA BUSCÓ EL
CONSEJO DE OBATALA, UNA FIGURA SABIA. LA HISTORIA SUGIERE LA IMPORTANCIA DE CONFIAR EN LA
SABIDURIA DE LOS MAYORES Y SEGUIR SUS CONSEJOS PARA SUPERAR LOS DESAFÍOS. EL PODER DE LOS
RITUALES Y LA ESPIRITUALIDAD: LA SOLUCIÓN OFRECIDA POR OBATALA IMPLICÓ UN RITUAL Y
ELEMENTOS SIMBÓLICOS. ESTO DESTACA LA CREENCIA EN EL PODER DE LOS RITUALES Y LA CONEXIÓN
ENTRE LA ESPIRITUALIDAD Y LA TRANSFORMACIÓN PERSONAL. RECONOCIMIENTO Y HONORES: LA SOMBRA
BUSCABA SER RECONOCIDA Y VALORADA. LA HISTORIA RESALTA LA IMPORTANCIA DEL RECONOCIMIENTO Y
EL RESPETO MUTUO EN LA SOCIEDAD, INDEPENDIENTEMENTE DE LA POSICIÓN O LA APARIENCIA.
EQUILIBRIO ENTRE PODER Y RESPONSABILIDAD: LOS TRES PODERES ADQUIRIDOS POR LA SOMBRA LLEVAN
CONSIGO UNA GRAN RESPONSABILIDAD. LA HISTORIA SUBRAYA LA NECESIDAD DE EQUILIBRAR EL PODER
CON LA RESPONSABILIDAD Y EL USO ÉTICO DE LAS HABILIDADES OTORGADAS. APRENDIZAJE DE LA
TOLERANCIA: LA SOMBRA EXPERIMENTÓ LA MARGINACIÓN Y, A SU VEZ, RECIBIÓ LA OPORTUNIDAD DE
ADQUIRIR PODERES ESPECIALES. ESTO PUEDE INTERPRETARSE COMO UNA LECCIÓN SOBRE LA
TOLERANCIA, LA COMPRENSIÓN Y LA SUPERACIÓN DE LOS PREJUICIOS. EN CONJUNTO, LA HISTORIA DE
LA SOMBRA PROPORCIONA LECCIONES VALIOSAS SOBRE LA SUPERACIÓN PERSONAL, LA SABIDURÍA DE LOS
MAYORES, LA IMPORTANCIA DEL RECONOCIMIENTO Y LA RESPONSABILIDAD QUE CONLLEVA EL PODER.''',
  '62. LOS DOS HERMANOS.': '''PATAKI: ERAN DOS HERMANOS, SIENDO EL MAYOR EL QUE OSTENTABA EL LIDERAZGO EN EL PUEBLO. SIN
EMBARGO, A PESAR DE QUE EL HERMANO MENOR NO LO DEMOSTRABA EXPLICITAMENTE, ALBERGABA
ENVIDIA HACIA EL POR LA POSICIÓN QUE OCUPABA. DE MANERA DISCRETA, DIFUNDIA RUMORES
NEGATIVOS SOBRE SU HERMANO A SUS ESPALDAS. EN CIERTO DÍA, DECIDIÓ REUNIR A TODA LA
COMUNIDAD PARA ARGUMENTAR QUE SU HERMANO MAYOR YA NO ESTABA EN CONDICIONES DE SEGUIR
GOBERNANDO, ALEGANDO QUE LA EDAD Y LAS CIRCUNSTANCIAS ACTUALES LO HACÍAN INCOMPETENTE.
INCLUSO LLEGÓ A EXPRESAR ESTO DIRECTAMENTE A SU PROPIO HERMANO. ANTE ESTO, EL HERMANO
MAYOR LE RESPONDIÓ QUE SI CREÍA QUE PODÍA HACERLO MEJOR, ÉL LE ENTREGARÍA EL MANDO Y SE
RETIRARÍA AL CAMPO, BUSCANDO TRANQUILIDAD EN SU VEJEZ. EL HERMANO MENOR ACEPTÓ EL DESAFÍO,
ASUMIENDO EL LIDERAZGO. SIN EMBARGO, SU GOBIERNO RESULTÓ SER UN DESASTRE TAN GRANDE QUE EL
PUEBLO, AL PERCATARSE DE LA SITUACIÓN, DECIDIÓ BUSCAR AL ANTIGUO LÍDER. AL ENCONTRARLO, EL
HERMANO MAYOR CONDICIONÓ SU REGRESO AL PODER: SI QUERÍAN QUE ÉL GOBERNARA NUEVAMENTE,
DEBÍAN ENTREGARLE EL GOBIERNO EN SU TOTALIDAD. ENSEÑANZAS: ENVIDIA Y DESLEALTAD: LA
ENVIDIA Y LA DESLEALTAD ENVIDIA Y DESLEALTAD: LA ENVIDIA Y LA DESLEALTAD ENTRE HERMANOS
PUEDEN DAR LUGAR A CONFLICTOS Y SITUACIONES PERJUDICIALES. LA HISTORIA DESTACA CÓMO LAS
EMOCIONES NEGATIVAS PUEDEN CONDUCIR A ACCIONES QUE AFECTAN NO SOLO LA RELACIÓN ENTRE LOS
HERMANOS, SINO TAMBIÉN A LA COMUNIDAD EN GENERAL. CONSECUENCIAS DE LA FALTA DE
EXPERIENCIA: EL HECHO DE QUE EL HERMANO MENOR NO DEMOSTRARA TENER LAS HABILIDADES
NECESARIAS PARA GOBERNAR MUESTRA LAS CONSECUENCIAS DE OTORGAR RESPONSABILIDADES A ALGUIEN
QUE CARECE DE LA EXPERIENCIA O LAS CAPACIDADES REQUERIDAS. ESTO SUBRAYA LA IMPORTANCIA DE
EVALUAR CUIDADOSAMENTE LA IDONEIDAD DE LAS PERSONAS PARA ROLES DE LIDERAZGO. LA
IMPORTANCIA DE LA EVALUACIÓN: LA COMUNIDAD, AL RECONOCER QUE EL NUEVO LIDER NO ESTABA
CUMPLIENDO CON LAS EXPECTATIVAS, TOMÓ LA DECISIÓN DE REVERTIR LA SITUACIÓN Y BUSCAR AL
ANTIGUO LÍDER. ESTO DESTACA LA IMPORTANCIA DE EVALUAR Y CORREGIR DECISIONES CUANDO SEA
NECESARIO, EN LUGAR DE PERSISTIR EN UN RUMBO QUE NO ES BENEFICIOSO. EL VALOR DE LA
HUMILDAD: EL HERMANO MAYOR DEMOSTRÓ HUMILDAD AL OFRECER ENTREGAR EL MANDO SI SU HERMANO
PODÍA HACERLO MEJOR. SIN EMBARGO, TAMBIÉN SE MUESTRA LA IMPORTANCIA DE EVALUAR CON
REALISMO LAS CAPACIDADES PROPIAS Y AJENAS ANTES DE ASUMIR RESPONSABILIDADES
SIGNIFICATIVAS. LA RESPONSABILIDAD DEL LIDERAZGO: EL LÍDER, AL REGRESAR AL PODER,
ESTABLECIÓ CONDICIONES CLARAS PARA SU LIDERAZGO, DESTACANDO LA IMPORTANCIA DE TENER EL
CONTROL COMPLETO PARA IMPLEMENTAR DECISIONES EFECTIVAS. ESTO RESALTA LA RESPONSABILIDAD
OUE CONLLEVA EL LIDERAZGO Y CÓMO LAS CONDICIONES ADECUADAS SON ESENCIALES PARA UN GOBIERNO
EFECTIVO. APRENDIZAJE A TRAVÉS DE LA EXPERIENCIA: LA HISTORIA REFLEJA CÓMO, A VECES, LAS
LECCIONES MÁS IMPORTANTES SE APRENDEN A TRAVÉS DE LA EXPERIENCIA. TANTO EL HERMANO MAYOR
COMO LA COMUNIDAD EXPERIMENTARON LAS CONSECUENCIAS DE SUS DECISIONES Y ACCIONES, BRINDANDO
OPORTUNIDADES PARA EL APRENDIZAJE Y LA MEJORA. EN CONJUNTO, ESTAS LECCIONES OFRECEN UNA
REFLEXIÓN SOBRE TEMAS COMO LA FAMILIA, EL LIDERAZGO, LA HUMILDAD Y LA RESPONSABILIDAD,
PROPORCIONANDO ENSEÑANZAS VALIOSAS PARA QUIENES BUSCAN COMPRENDER MEJOR LAS DINÁMICAS
SOCIALES Y PERSONALES.''',
  '63. EL DIA Y SU RIVAL LA NOCHE.': '''PATAKI: ANTIGUAMENTE, EL DÍA POSEÍA MÁS PODER QUE EN LA ACTUALIDAD, Y SU ETERNO RIVAL
SIEMPRE FUE LA NOCHE. LA LECHUZA, RECONOCIDA POR SU AGUDA INTELIGENCIA, DESEMPEÑABA EL
PAPEL DE SECRETARIA DEL DIA, A QUIEN ESTE CONFIABA TODOS SUS SECRETOS. EL MONO ERA EL
AMIGO MÁS LEAL DE LA LECHUZA; EN AQUELLOS TIEMPOS, EL MONO HABLABA Y LA LECHUZA VELABA POR
EL DÍA. UN DIA, EL MONO CONVOCO A LA LECHUZA PARA IDEAR UN PLAN: PRIVAR A LA NOCHE DE SU
LUZ Y HACER QUE PAGARA TRIBUTOS POR DISFRUTAR DE LA LUZ SOLAR. EL DÍA CONTABA CON EL
RESPALDO DE LOS DEMÁS ASTROS, EXCEPTO LA LUNA, LA MÁS ORGULLOSA DE TODOS. EL DÍA ENCOMENDO
A LA LECHUZA LA TAREA DE REDACTAR UNA CARTA INVITANDO A LA LUNA A LA FIESTA. LA LETRA
DEBÍA SER ESCRITA CON ÁCIDO DE TAL MANERA QUE, AL LEERLA, LA LUNA PERDIERA LA VISTA, Y LA
LECHUZA, AL ELABORAR LA CARTA, DEBÍA LLEVAR UNA CARETA DEBIDO AL RESPLANDOR. EL DIA Y LA
LECHUZA SE AISLARON PARA QUE NADIE SUPIERA CUANDO LA LECHUZA IBA A ENTREGAR LA CARTA A LA
LUNA. SIN EMBARGO, AL ENCONTRARSE CON EL MONO, LA LECHUZA LE REVELÓ EL PLAN. LA ASTUTA
TIÑOSA, QUE ESTABA ESCUCHANDO, SALIÓ VOLANDO Y LE CONTÓ TODO A LA LUNA. ESTA, DE
INMEDIATO, SALIÓ EN DEFENSA DE LA NOCHE, LANZANDO TODA SU LUZ FRÍA. EN RESPUESTA, EL SOL
SALIÓ EN DEFENSA DEL DÍA, DESENCADENÁNDOSE UNA FEROZ LUCHA QUE RESULTÓ EN PURA DISCORDIA.
CUANDO EL DÍA SE ENTERÓ DE LA TRAICIÓN DEL MONO Y LA LECHUZA, COMPRENDIÓ QUE LO SUCEDIDO
ESTABA JUSTIFICADO, YA QUE LO QUE SE VA A HACER NO DEBE CONFIARSE A NADIE. EL DÍA LLAMÓ A
LA LECHUZA Y LE ANUNCIÓ QUE MIENTRAS EXISTIERA EL MUNDO, ELLA NO VOLVERÍA A VER LA LUZ DEL
DÍA, Y QUE NADA DE LO QUE OCURRIERA DEBÍA SER REVELADO. LA LECHUZA, AL LEER LA CARTA,
QUEDÓ CIEGA, Y EL MONO, AL VER ESTO, EMITIÓ UN GRITO Y QUEDÓ SIN HABLA PARA SIEMPRE,
DESPUES DE QUE EL DIA LE ADMINISTRARA UN LÍQUIDO PREPARADO. ASI, POR SU INDISCRECIÓN, UNO
PERDIÓ LA LUZ DEL DÍA Y EL OTRO PERDIÓ LA CAPACIDAD DE HABLAR. ENSEÑANZAS: LEALTAD Y
CONFIANZA: EL MONO Y LA LECHUZA ERAN AMIGOS LEALES DEL DÍA, PERO LA LECHUZA TRAICIONÓ LA
CONFIANZA AL REVELAR EL PLAN AL MONO. LA HISTORIA DESTACA LA IMPORTANCIA DE LA LEALTAD Y
LA CONFIANZA EN LAS RELACIONES, YA QUE LA TRAICIÓN PUEDE TENER CONSECUENCIAS GRAVES.
CONSECUENCIAS DE LA TRAICIÓN: TANTO LA LECHUZA COMO EL MONO SUFRIERON GRAVES CONSECUENCIAS
POR TRAICIONAR AL DÍA. LA LECHUZA PERDIÓ LA VISTA Y EL MONO PERDIÓ LA CAPACIDAD DE HABLAR.
ESTO SUBRAYA EL MENSAJE DE QUE LAS ACCIONES TIENEN CONSECUENCIAS, Y LA TRAICIÓN PUEDE
RESULTAR EN PÉRDIDAS SIGNIFICATIVAS. LA IMPORTANCIA DE LA PRUDENCIA: EL DÍA CONFIÓ EN LA
LECHUZA CON UN PLAN ESTRATÉGICO, PERO LA LECHUZA REVELÓ EL SECRETO AL MONO. LA HISTORIA
ENSEÑA LA IMPORTANCIA DE SER PRUDENTE AL CONFIAR EN OTROS CON INFORMACIÓN DELICADA, Y CÓMO
LA INDISCRECIÓN PUEDE LLEVAR A RESULTADOS DESASTROSOS. LA SOBERBIA Y LA VANIDAD: LA LUNA,
AL SER LA MÁS ORGULLOSA DE TODOS LOS ASTROS, SE DEFENDIÓ CONTRA LA CONSPIRACIÓN DE PRIVAR
A LA NOCHE DE SU LUZ. ESTO SUGIERE UNA LECCIÓN SOBRE CÓMO LA SOBERBIA Y LA VANIDAD PUEDEN
CONDUCIR A LA DEFENSA DE LO QUE UNO VALORA, INCLUSO EN DETRIMENTO DE OTROS. LA
JUSTIFICACIÓN DE LAS ACCIONES: AUNQUE EL DÍA COMPRENDIÓ LA TRAICIÓN DEL MONO Y LA LECHUZA,
TAMBIÉN COMPRENDIÓ QUE ALGUNAS ACCIONES DEBEN MANTENERSE EN SECRETO. ESTO PODRÍA
INTERPRETARSE COMO UNA LECCIÓN SOBRE LA JUSTIFICACIÓN DE LAS ACCIONES Y LA NECESIDAD DE
MANTENER CIERTOS SECRETOS PARA EVITAR CONFLICTOS INNECESARIOS. EN RESUMEN, LA HISTORIA
ENFATIZA VALORES COMO LA LEALTAD, LA PRUDENCIA Y LAS CONSECUENCIAS DE LA TRAICIÓN. CADA
PERSONAJE ENFRENTA LAS REPERCUSIONES DE SUS ACCIONES, SIRVIENDO COMO UNA NARRATIVA QUE
SUBRAYA LA IMPORTANCIA DE LAS DECISIONES ÉTICAS Y LAS RELACIONES DE CONFIANZA.''',
  '64. CUANDO LA DESOBEDIENCIA SE CANSÓ.': '''PATAKI: HUBO UNA ÉPOCA EN LA QUE LA DESOBEDIENCIA SE CANSÓ. ORÚNMILA, OBEDECIENDO A SU
PADRE LA NATURALEZA, NEGÓ TODOS LOS MOVIMIENTOS NECESARIOS PARA LA VIDA. EL TIEMPO PASABA
Y LA COMIDA SE AGOTABA; LOS ANIMALES MORÍAN, LAS PLANTAS Y LOS RÍOS SE SECABAN, NO LLOVÍA,
EL VIENTO PERMANECÍA EN CALMA, NO IMPULSABA LA CIRCULACIÓN DE LOS ASTROS. EN RESUMEN, LA
SITUACIÓN ERA ESPANTOSA. ENTONCES, LA TIÑOSA, LA MÁS ATREVIDA DE TODAS LAS AVES Y
MENSAJERA DE OLOFIN, DIJO: "ASÍ PENSANDO, NOS MORIREMOS SIN DEFENSA ALGUNA. YO ME DECIDO A
HACER ALGO, PASE LO QUE PASE." ELEVÓ EL VUELO Y SE REMONTÓ HASTA QUE LLEGÓ A UN DESIERTO.
YA CANSADA DE VOLAR, BAJÓ Y SE ENCONTRÓ CON UN HOMBRE QUE SE LLAMABA "TODO LO TENGO". SIN
EMBARGO, A ESTE HOMBRE LE FALTABA UNA PIERNA, UN OJO, UNA OREJA Y UNA MANO. AL CONOCER LA
TIÑOSA EL NOMBRE DEL HOMBRE, SE BURLÓ Y LE DIJO: "CHICO, A TI TE FALTA LO QUE TODOS
TENEMOS." EL HOMBRE LE CONTESTÓ QUE ESO NO ERA DE ÉL, QUE SOLO GUARDABA EL SECRETO. LA
TIÑOSA LOGRÓ QUE EL HOMBRE LE ENSEÑARA LOS SECRETOS QUE ESTABAN DENTRO DE LOS TRES
GUIRITOS, LOS CUALES ERAN: EL AIRE, EL AGUA, EL SOL, EL VIENTO, PERO EN EL ÚLTIMO ESTABA
LA CANDELA, Y LE DIJO QUE LO QUE CONTENIA ERA LO QUE ESCASEABA. PROBANDO UN POCO DE
TIERRA, LE DUO: "TOO TOO ASHE" Y SALIÓ EL CONTENIDO. LA TIÑOSA HIZO ELOGIOS DE ÉL, Y EN
ESE MOMENTO FORJÓ UNA BUENA AMISTAD Y COMENZÓ A CONTARLE UNA SERIE DE MENTIRAS AL HOMBRE,
QUE SE QUEDÓ PROFUNDAMENTE DORMIDO, MOMENTO QUE APROVECHÓ PARA ROBARLE SUS SECRETOS. LA
TIÑOSA EMPRENDIÓ EL VUELO Y EMPEZÓ A TOCAR AL VIENTO, LUEGO AL SOL, Y CUANDO FUE A TOCAR A
LA CANDELA, ESTA LA QUEMO, PERDIENDO LA TIÑOSA LA PLUMA Y SU CORONA, QUEDÁNDOSE SIN PLUMAS
EN LA CABEZA. CUANDO EL HOMBRE SE DESPERTÓ Y DESCUBRIÓ EL ROBO, SALIÓ A CONTÁRSELO A
OLOFIN Y ESTE, COMO CASTIGO, LE DIJO: "BUENO, DESDE AHORA, MIENTRAS QUE EL MUNDO SEA
MUNDO, ESTARÁS EN LA TIERRA Y TENDRÁS DE AMIGOS A LAS PLANTAS, QUE SERÁN TUS ALIMENTOS. Y
A LA TINOSA, POR ATREVIDA, LE COSTARÁ NO TENER PARADERO FIJO Y NO SE ALIMENTARÁ MÁS QUE DE
ANIMALES MUERTOS, Y EL AGUA LA AHOGARÁ." ENSEÑANZAS: DESOBEDIENCIA Y CONSECUENCIAS: LA
HISTORIA COMIENZA CON LA DESOBEDIENCIA, LO QUE LLEVA A CONSECUENCIAS DESASTROSAS PARA LA
NATURALEZA Y LA VIDA EN GENERAL. ESTO ENSEÑA SOBRE LA IMPORTANCIA DE SEGUIR LAS LEYES Y
ARMONIZAR CON LA NATURALEZA PARA EVITAR CONSECUENCIAS NEGATIVAS. LA ASTUCIA Y LA VALENTÍA:
LA TINOSA REPRESENTA LA ASTUCIA Y LA VALENTÍA AL DECIDIRSE A HACER ALGO PARA CAMBIAR LA
SITUACIÓN. SIN EMBARGO, SU ATREVIMIENTO Y ASTUCIA LA LLEVAN A SU PROPIA CAÍDA. LA HISTORIA
SUGIERE QUE LA ASTUCIA DEBE IR DE LA MANO CON LA RESPONSABILIDAD Y LA ÉTICA. LA TRAICIÓN Y
SUS CONSECUENCIAS: LA TIÑOSA, AL ROBAR LOS SECRETOS MIENTRAS EL HOMBRE DORMÍA, MUESTRA EL
PELIGRO DE LA TRAICIÓN. LAS ACCIONES TRAICIONERAS TIENEN REPERCUSIONES, Y LA PÉRDIDA DE LA
PLUMA Y LA CORONA SIMBOLIZA LA PÉRDIDA DE ESTATUS Y PRIVILEGIOS DEBIDO A LA TRAICIÓN. EL
CASTIGO Y LA JUSTICIA DIVINA: OLOFIN IMPONE CASTIGOS PROPORCIONALES A LAS ACCIONES
COMETIDAS. EL HOMBRE SE QUEDA EN LA TIERRA, CONECTADO A LAS PLANTAS PARA SU SUSTENTO,
MIENTRAS QUE LA TINOSA PIERDE SU CAPACIDAD DE TENER UN PARADERO FIJO Y ENFRENTA
DIFICULTADES PARA ALIMENTARSE. ESTO REFLEJA LA IDEA DE QUE LAS ACCIONES, YA SEAN BUENAS O
MALAS, TRAEN CONSIGO CONSECUENCIAS JUSTAS. EN RESUMEN, LA HISTORIA OFRECE LECCIONES SOBRE
OBEDIENCIA, ETICA, RESPONSABILIDAD, CONSECUENCIAS DE ACCIONES IMPULSIVAS Y LA IMPORTANCIA
DE VIVIR EN ARMONÍA CON LA NATURALEZA. CADA PERSONAJE Y EVENTO EN LA HISTORIA CONTRIBUYE A
TRANSMITIR ESTOS MENSAJES MORALES.''',
  '65. LA TIERRA ERA HIJA DE UN REY.': '''PATAKI: EN ESTE RELATO, LA TIERRA, SIENDO LA HIJA DE UN REY, TENÍA UNA PECULIAR COSTUMBRE
DE LLEVAR ALREDEDOR DE SU CINTURA 200 PAÑUELOS. DECÍA QUE SE CASARÍA CON AQUEL QUE LOGRARA
VER SUS NALGAS DESNUDAS, Y ESTA NOTICIA SE PROPAGÓ POR TODO EL TERRITORIO. AL DÍA
SIGUIENTE, ORÚNMILA, RESIDENTE EN ESE LUGAR, CONSULTÓ IFÁ Y DE INMEDIATO RECORDÓ LAS
PALABRAS DE LA TIERRA, LA HIJA DEL REY. ORÚNMILA REALIZÓ EBÓ Y LAS CEREMONIAS MENCIONADAS
ANTERIORMENTE. AL SOLTAR LA RATA CON TODAS ESAS CUENTAS, SE DESATO UN ALBOROTO, CON LA
GENTE INTENTANDO VER A LA RATA QUE HUIA HACIA EL MONTE. AL ESCUCHAR LOS COMENTARIOS DE LA
GENTE, LA TIERRA SALIÓ A VER LA RATA, Y COMENZÓ UNA TENSA PERSECUCIÓN ENTRE LOS MATOJOS Y
ARBUSTOS. A CADA PASO QUE DABA LA TIERRA POR EL INTRINCADO CAMINO, IBA PERDIENDO SUS
PAÑUELOS, QUEDANDO COMPLETAMENTE DESNUDA. ORÚNMILA, QUE ESTABA CERCA, AL VERLA QUEDÓ
ESTUPEFACTO ANTE ESA VISIÓN. SIN EMBARGO, REACCIONANDO, SE ACERCÓ A ELLA. CUANDO LA TIERRA
LO VIO, LE PREGUNTÓ QUÉ HACÍA ALLÍ, Y ORÚNMILA LE RECORDÓ QUE ELLA HABÍA DICHO QUE SE
CASARÍA CON QUIEN LE VIERA SUS NALGAS DESNUDAS. LA MUJER COMPRENDIÓ QUE ERA CIERTO, FUE A
BUSCAR SUS PERTENENCIAS Y DECIDIÓ VIVIR CON ORÚNMILA. CUANDO SE CASÓ CON LA TIERRA,
COMENZÓ A CANTAR Y BAILAR ALEGREMENTE, DICIENDO QUE HABIAN CAPTURADO A LA TIERRA Y NUNCA
LA ABANDONARÍAN. REZO: IFÁ NI KAFERREFUN ESHU-ELEGBÁ, KAFERREFUN OSANYIN, LODAFUN ILAGUERE
ADIFAFUN ORÚNMILA. EBÓ: 2 POLLOS, 2 GALLINAS, UNA RATA CON UN COLLAR DE CUENTAS ALREDEDOR
DE LA CINTURA, CONCHAS, UNA MUÑECA CON PAÑUELOS ALREDEDOR DE LA CINTURA, TRAMPA, JUTÍA Y
PESCADO AHUMADO, MAÍZ TOSTADO, COCO, VELA, MIEL DE ABEJAS, AGUARDIENTE, CASCARILLA, MUCHO
DINERO. DISTRIBUCIÓN: UN POLLO CON SUS INGREDIENTES PARA ESHU-ELEGBÁ. UN POLLO CON SUS
INGREDIENTES PARA OSANYIN, EN EL MONTE SI ES POSIBLE. DOS GALLINAS CON SUS INGREDIENTES
PARA ORÚNMILA. NOTA: SE LE DA SANGRE AL EBÓ, ENVIÁNDOLO AL MONTE JUNTO CON EL RESTO DE LOS
ARTÍCULOS DEL EBÓ. LA RATA CON SUS CUENTAS Y CONCHAS SE SUELTA EN EL MONTE. ENSEÑANZAS:
CUMPLIMIENTO DE PROMESAS: LA TIERRA ESTABLECE UN REQUISITO INUSUAL PARA EL MATRIMONIO, Y
AL FINAL, CUMPLE SU PALABRA AL CASARSE CON ORÚNMILA. LA IMPORTANCIA DE CUMPLIR LAS
PROMESAS Y COMPROMISOS ES EVIDENTE EN LA HISTORIA. SABIDURÍA Y ASTUCIA: ORÚNMILA, AL
CONSULTAR IFÁ Y RECORDAR LAS PALABRAS DE LA TIERRA, DEMUESTRA SABIDURÍA Y ASTUCIA. LA
HISTORIA SUGIERE QUE EL CONOCIMIENTO Y LA INTELIGENCIA SON HERRAMIENTAS VALIOSAS PARA
SUPERAR DESAFIOS Y RESOLVER SITUACIONES COMPLICADAS. CONSECUENCIAS DE LA DESOBEDIENCIA: LA
TIERRA, AL PERSEGUIR A LA RATA Y PERDER SUS PAÑUELOS, ENFRENTA LAS CONSECUENCIAS DE SUS
ACCIONES. ESTO PUEDE INTERPRETARSE COMO UNA LECCIÓN SOBRE CÓMO LAS DECISIONES IMPULSIVAS
PUEDEN TENER REPERCUSIONES INESPERADAS. APRENDER DE LAS LECCIONES: ORÚNMILA, AL RECORDAR
LAS PALABRAS DE LA TIERRA, DEMUESTRA LA IMPORTANCIA DE APRENDER DE LAS EXPERIENCIAS Y
APLICAR ESE CONOCIMIENTO PARA ABORDAR SITUACIONES FUTURAS. VALOR DE LA FIDELIDAD Y LA
UNIÓN: A PESAR DE LA PECULIARIDAD DE LA SITUACIÓN, LA TIERRA DECIDE QUEDARSE CON ORÚNMILA
DESPUÉS DE CUMPLIR CON SU CONDICIÓN. ESTO PUEDE INTERPRETARSE COMO UN MENSAJE SOBRE EL
VALOR DE LA FIDELIDAD Y LA UNIÓN EN EL MATRIMONIO. EN CONJUNTO. ESTAS ENSEÑANZAS OFRECEN
UNA PERSPECTIVA SOBRE LA IMPORTANCIA DE LA SABIDURÍA, LA FIDELIDAD, EL CUMPLIMIENTO DE
PROMESAS Y LAS CONSECUENCIAS DE NUESTRAS ACCIONES EN EL TEJIDO DE LA VIDA Y LAS
RELACIONES.''',
  '66. EL CAMINO DE LOS PIGMEOS.': '''PATAKI: EN LA TIERRA DE SIWAINLE, VIVÍA UN AWÓ DE ORÚNMILA LLAMADO GEOKUE AWÓ EL CUAL ERA
DE ODU BABÁ EJIOGBE. ESTE AWÓ SOLO RECIBÍA DE SUS SEMEJANTES MAL AGRADECIMIENTOS Y NADIE
COMPRENDIA SUS AGRADECIMIENTOS LOS FAVORES Y OBRAS QUE REALIZABA CON ELLOS, POR LO QUE
DECIDIÓ EMIGRAR Y SALIR A CAMINAR LAS DISTINTAS TIERRAS DE LOS ALREDEDORES, Y EN TODAS LE
SUCEDIÓ LO MISMO. DESPUÉS DE MUCHO PEREGRINAR LLEGÓ A UNA TIERRA DONDE LOS HOMBRES ERAN DE
MUY PEQUEÑA ESTATURA, ERAN PIGMEOS, A EJIOGBE LO ACOGIERON MUY BIEN Y ENSEGUIDA LE DIERON
TRABAJO. SE PUSO A TRABAJAR EN UN MATADERO DE ESE PUEBLO DONDE COMPARTÍA ESE TRABAJO CON
SUS LABORES DE AWÓ, PRONTO TUVO MUCHOS AHIJADOS ENTRE ESOS HOMBRES Y PARECÍA QUE LA
FELICIDAD LE SONREÍA, PERO UN DÍA EN QUE GREOKUE AWÓ SE VIO SU SIGNO, BABÁ EJIOGBE Y LA
DUDA DE SU SEMEJANTE VOLVIÓ A SURGIR EN SU MENTE Y ÉL SE DUO: "TENGO QUE PROBAR A MIS
AHIJADOS Y A TODAS AQUELLAS PERSONAS QUE DE UNA FORMA U OTRA ME DEBEN FAVORES". ENTONCES
COGIÓ Y SE EMBARRÓ CON SANGRE DEL MATADERO Y SALIÓ A RECORRER LAS CASAS DE SUS AHIJADOS ÉL
TOCABA Y ÉSTOS ABRÍAN Y AL VERLO LLENO DE SANGRE LE PREGUNTABAN QUE LE PASABA, Y ÉSTE
FINGIENDO DECÍA, HE MATADO AL HIJO DEL REY, ENTONCES TODOS LLENOS DE MIEDO LE DECÍAN, POR
FAVOR SIGA SU CAMINO QUE USTED ME PERJUDICA, Y GEREOKE AWÓ OMÓ EJIOGBE TENÍA EL CORAZÓN
ACONGOJADO AL VER QUE TODOS SUS AFECTOS ERAN FALSOS ENTONCES MUY TRISTE COGIÓ RUMBO A LAS
LOMAS DONDE HABÍA UNA CASITA SOLITARIA PINTADA DE BLANCO, ALLÁ CUAL EL NUNCA HABÍA IDO,
TOCÓ LA PUERTA Y LE ABRIÓ UN ANCIANO CANOSO EL QUE AL VERLO TODO LLENO DE SANGRE LE
PREGUNTO LO QUE LE SUCEDE, Y EJIOGBE LE DIJO LO MISMO QUE LE HABÍA DICHO A LOS DEMÁS, EL
VIEJO LO INVITA A PASAR PARA QUE LAVARA SUS ROPAS Y LO ALIMENTÓ, Y TODOS LOS DÍAS LE
DECÍA, NO SE MUEVA HIJO QUE YO VOY A SALIR AL PUEBLO PARA VER COMO ANDA LA SITUACIÓN Y
TRAERLE NOTICIAS. HASTA QUE PASARON 16 DÍAS Y LA CONCIENCIA DE EJIOGBE LE FUE REMORDIENDO
QUE SU FALTA ESTABA AFECTANDO AL VIEJO QUE SE ESMERABA EN ATENDERLO, HASTA QUE LE CONFESÓ
LA VERDAD AL ANCIANO QUE LE RESPONDIÓ, YO LO SABÍA TODO PERO NECESITABA DARTE UNA PRUEBA
DE QUE NO ESTABAS SOLO Y QUE ME TIENES A MÍ QUE SOY BABÁ FURUKU OSHALOFUN, EL VERDADERO
DUEÑO DE ESTAS TIERRAS Y EL QUE TE VA A CONSAGRAR EN LA CABEZA LO QUE TU NECESITAS, LE
DIJO, ARRODÍLLATE Y SACÓ DE SU BOLSA 16 IÑO Y LOS MACHACÓ CON ERÚ, OBÍ, KOLÁ, OBÍ MOTIWAO
Y SE LO PUSO EN LA CABEZA Y LE DIJO, PON TU IFÁ EN EL SUELO, PERO PRIMERO ESCRIBE BABÁ
EJIOGBE Y COGIÓ UN GALLO BLANCO. PERO ANTES COGIÓ UNA EJE BIMBEN UNTADO DE MUCHA MANTECA
DE CACAO, Y LO PUSO SOBRE EL IFÁ DE EJIOGBE Y LE PUSO EL GALLO EN LA CABEZA Y LE REZÓ:
"BABÁ EJIOGBE BOSHE ADIFAFUN EJÁ TUTU YOMILO BABÁ ORORO BABÁ OTO TO MOKANEYI ADELE NI IFÁ
OLORUN OTOTO KOLA YEKUN OTOTO MOLAYEIFAN BABÁ ELERI-IPIN ONO BALERI MOLA EFUN ADELENIFA
ERI ODARA". ENTONCES COGIÓ UN CUCHILLO DE CAÑA BRAVA QUE TENÍA EN LA MANO FORRADO DE
FLEQUES DE OBATALÁ Y SHANGÓ Y MATÓ AL GALLO EN SU CABEZA Y QUE FUERA CAYENDO EN EL EJÁ
BIMBÉ Y EL IFÁ Y LE CANTABA: "ERI EYENI AKUKO FOKUN IFÁ NIFA MOKUAYE" Y LE ECHÓ MUCHA MIEL
DE ABEJAS Y OMIERO DE HIERBA ARAGBA DE IROKO, BLEDO FINO, PRODIGIOSA, ATIPONLÁ, HIERBA
SAPO, GUENGUERÉ, ALGODÓN, ENTONCES LE PUSO TELA BLANCA EN LA CABEZA, Y LO METIÓ EN EL EJÁ
BIMBÉ Y LO MANDÓ AL MAR Y LE DIJO: HOY TODO EL DÍA TIENES QUE ESTAR DÁNDOTE BAÑOS CON ESTE
OMIERO, Y TRAJO ARENA DE ALLÍ. AL TERCER DÍA OMO EJIOGBE SE HIZO OSODE CON SU IFÁ Y SE VIO
SU SIGNO DONDE OBATALÁ LE DIJO, COGE ESA ARENA, EL GALLO Y LA TELA BLANCA QUE TENÍAS EN LA
CABEZA Y TE HACES EBÓ-IGBIN Y LO LLEVAS A ESA ARAGBA Y LE CANTAS, "ERUPINTEBO MEYIRO
EJIOGBE OBANI IKÚ ASHEGUN OLÚO INDIRI OLOFIN". ASÍ EJIOGBE RECUPERÓ LAS GANAS DE VIVIR Y
PUDO RECUPERAR EL GRAN PODER DE LA ESTABILIDAD Y LA ORGANIZACIÓN DE LA TIERRA Y DESDE
ENTONCES VIVIÓ FELIZ AUNQUE SABÍA QUE ERAN FALSOS CON ÉL. REZO: ADIFAFUN ORNMILA, UMBATI
UNLO, OBÁ ASHE LOWO OLODUMARE ORUBO SIWA FI ASHÉ OKUNI, KEKERE OKUNI, UMBATI GBOGBO AIYE
GERGOKUE OTIACRASHE, LOWO OLORDUMARE NIWO SI NIWO OTO GBOGBO EYITE OWO SHINSHE DATIGBA A
NAWA NI OUN IFE ASHE LODAFUN OBATALÁ BABÁ FURUKU OSHALOFUN. EBÓ: AKUKÓ FUNFUN, ILEKE
FUNFUN, OBÉ DE CAÑA BRAVA, ADOFÁ MALÚ, EYE NI MALÚ EKÚ, EJÁ, ORÍ, AWADÓ, OBÍ, OÑÍ, ITANÁ,
OWÓ MEDILOGUN. ENSEÑANZAS: INGRATITUD Y DESCONFIANZA: LA HISTORIA DESTACA EL TEMA DE LA
INGRATITUD Y LA DESCONFIANZA QUE EXPERIMENTA GEOKUE AWÓ. A PESAR DE SUS BUENAS ACCIONES,
NO RECIBE EL RECONOCIMIENTO NI LA GRATITUD DE QUIENES DEBERIAN APRECIARLO. ESTO REFLEJA LA
REALIDAD DE QUE, A VECES, LAS ACCIONES GENEROSAS PUEDEN SER MALINTERPRETADAS O PASADAS POR
ALTO. PRUEBAS DE SINCERIDAD: GEOKUE AWÓ DECIDE PONER A PRUEBA A SUS AHUADOS Y A LAS
PERSONAS QUE LE DEBEN FAVORES. ESTA ACCIÓN RESALTA LA IMPORTANCIA DE EVALUAR LA SINCERIDAD
Y LA LEALTAD DE AQUELLOS QUE NOS RODEAN, ESPECIALMENTE EN MOMENTOS DE DUDA. CONSECUENCIAS
DE LA IMPULSIVIDAD: LA HISTORIA MUESTRA LAS CONSECUENCIAS DE LA IMPULSIVIDAD DE GEOKUE AWÓ
AL FINGIR UN ACTO TAN IMPACTANTE COMO EL ASESINATO DEL HIJO DEL REY. ESTO SIRVE COMO
LECCIÓN SOBRE CÓMO LAS DECISIONES IMPULSIVAS PUEDEN TENER REPERCUSIONES INESPERADAS Y
PERJUDICIALES. ARREPENTIMIENTO Y PERDÓN: LA CONFESIÓN DE GEOKUE AWÓ AL ANCIANO REVELA UN
SENTIDO DE ARREPENTIMIENTO. LA HISTORIA SUGIERE QUE EL ARREPENTIMIENTO Y LA HONESTIDAD SON
PASOS CRUCIALES HACIA LA REDENCIÓN. EL ANCIANO DEMUESTRA COMPRENSIÓN Y PERDÓN, ENSEÑANDO
ASÍ LA IMPORTANCIA DE DAR SEGUNDAS OPORTUNIDADES. PRUEBAS ESPIRITUALES: EL ANCIANO, QUE
RESULTA SER BABÁ FURUKU OSHALOFUN, SOMETE A GEOKUE AWÓ A PRUEBAS ESPIRITUALES PARA
DEMOSTRARLE QUE NO ESTÁ SOLO Y QUE CUENTA CON EL RESPALDO DIVINO. ESTO SUBRAYA LA CREENCIA
EN LAS PRUEBAS ESPIRITUALES COMO PARTE DEL CAMINO HACIA EL CRECIMIENTO PERSONAL Y
ESPIRITUAL. RENOVACIÓN Y RENACIMIENTO: EL PROCESO DE LIMPIEZA Y CONSAGRACIÓN DE GEOKUE AWÓ
SIMBOLIZA UN RENACIMIENTO Y UNA RENOVACIÓN. DESPUÉS DE ENFRENTAR SUS ERRORES Y SUPERAR LAS
PRUEBAS, RECUPERA LA ESTABILIDAD Y LA FELICIDAD EN SU VIDA. EN CONJUNTO, ESTAS ENSEÑANZAS
OFRECEN UNA PERSPECTIVA INTEGRAL SOBRE LA IMPORTANCIA DE LA CONFIANZA, LA HONESTIDAD, LA
PACIENCIA Y EL CRECIMIENTO ESPIRITUAL EN LA VIDA DE UNA PERSONA. ADEMÁS, RESALTA LA IDEA
DE QUE, A PESAR DE LOS DESAFÍOS Y LAS DECEPCIONES, SIEMPRE HAY OPORTUNIDADES PARA LA
REDENCIÓN Y LA RENOVACIÓN.''',
  '67. LA JUSTICIA DIVINA.': '''PATAKI: HABÍA UN INDIVIDUO QUE POR MUCHO TIEMPO CREYÓ EN LA JUSTICIA DIVINA DE DIOS, PERO
POR ESTARSE FUANDO EN ALGUNAS COSAS, QUE A SU JUICIO ESTABAN ACONTECIENDO SIN MOTIVOS AL
PARECER JUSTIFICADOS, DE ACUERDO CON LAS COSAS MÁS PERFECTAS DEL OMNIPOTENTE, COMENZÓ A
DUDAR DE LA JUSTICIA DE DIOS, Y UN BUEN DÍA RECOGIÓ SUS COSAS Y PREGUNTANDO LLEGÓ HASTA EL
MISMO OLOFIN. COMO DIOS ES EL QUE TODO LO GUÍA, SE OCUPÓ DE QUE EL INDIVIDUO EN CUESTIÓN
PUDIERA LLEGAR HASTA DONDE ÉL ESTABA, Y DESPUÉS PREGUNTÁNDOLE A LO QUE VENÍA, COSA QUE
ESTE SABÍA DEMASIADO, DIOS LE PROPUSO A DICHO PERSONAJE QUE REGRESARA AL MUNDO DE LA
VERDAD, Y AL EFECTO, LE PROPORCIONÓ COMIDA PARA ALGÚN TIEMPO Y UNA MONTURA NUEVA (UNA MULA
EQUIPADA), EL INDIVIDUO EN CUESTIÓN SALIÓ A CABALGAR. DESPUÉS DE PRESENCIAR ALGUNAS COSAS
QUE SEGÚN SUS CRITERIOS NO TENÍAN MOTIVOS DE SUCEDE, LLEGÓ A UNA ARBOLEDA AL PARECER
CONSERVADA PARA DESCANSAR LOS VIAJEROS, DESPUÉS DE ESCOGER EL LUGAR QUE LE PARECÍA MÁS
PROPICIO ACAMPÓ, QUITÓ LA MONTURA A LA MULA Y SE DISPUSO A PREPARAR SU COMIDA, PERO
MIENTRAS HACÍA ESO SE DIO CUENTA DE LA LLEGADA DE OTRO VIAJERO AL MISMO LUGAR Y QUE
DESPUÉS DE QUITAR LA MONTURA A SU CABALGADURA, SE PONÍA A CONTAR UNA GRAN CANTIDAD DE
DINERO, Y MIENTRAS ESO SUCEDÍA LLEGABA DETRÁS OTRO HOMBRE QUE SACANDO UN CUCHILLO SE LO
CLAVABA DESPIADADAMENTE, RECOGÍA EL DINERO Y PARTÍA AL GALOPE. AL PRESENCIAR ESTO QUE LE
PARECÍA BASTANTE CRUEL, EMPEZÓ A RECOGER SU EQUIPAJE CON IDEA DE REGRESAR DONDE OLOFIN,
PARA DECIRLE QUE EL DEFINITIVAMENTE NO CREÍA EN EL, NI EN SU JUSTICIA MIENTRAS TUVIERAN
ACOMETIÉNDOSE TALES HECHOS, EN ESO SE PERSONÓ OTRO INDIVIDUO QUE AL COMPROBAR QUE EL
SUJETO ANTERIORMENTE AGREDIDO TENIA UN CUCHILLO CLAVADO EN SUS ESPALDAS TRATÓ DE
QUITÁRSELO Y EN ESO LLEGÓ LA POLICÍA Y LO DETIENE, DESPUÉS DE CONVERSAR UN RATO ENTRE
ELLOS SACAN UNA CUERDA Y LO AHORCAN, Y ESTO SI QUE COLMÓ LA COPA DEL INCRÉDULO O DUDOSO
HOMBRE. ENSILLANDO LA MULA SE FUE A VER A DIOS, QUE YA LO ESTABA ESPERANDO CON UNA SERIE
DE DOCUMENTOS Y DESPUÉS DE ESCUCHARLO LE DIJO: MIRA HIJO LA JUSTICIA DIVINA SIEMPRE LLEGA,
Y LE MOSTRÓ COMO EL QUE FUE HERIDO EN LA CASA DEL QUE LO APUÑALEÓ MATÁNDOLO Y RECOGIÓ SU
DINERO, POR CAUSA DEL ROBO HABÍA MUERTO EL PADRE DEL QUE LO HIRIÓ Y AL QUE TRATÓ DE
SACARLE EL CUCHILLO HABÍA SIDO SOCIO EN EL ASALTO POR LO QUE SE ACORDÓ CON LAS LEYES
DIVINAS LA PENA DEL MATADOR QUE TENÍA QUE SER LA MUERTE, Y ASÍ SE CUMPLÍA LA JUSTICIA.
ENSEÑANZAS: DUDA Y DESCONFIANZA: LA NARRATIVA DESTACA CÓMO LA DUDA Y LA DESCONFIANZA EN LA
JUSTICIA DIVINA PUEDEN SURGIR EN UNA PERSONA, INCLUSO CUANDO CREE EN LA EXISTENCIA DE UN
SER SUPREMO. LA FALTA DE COMPRENSIÓN DE LOS DESIGNIOS DIVINOS PUEDE LLEVAR A LA PÉRDIDA DE
FE. PERSPECTIVA LIMITADA: EL PROTAGONISTA JUZGA LOS ACONTECIMIENTOS DESDE SU
PROPIAPERSPECTIVA LIMITADA Y SIN CONOCER COMPLETAMENTE LAS RAZONES DETRÁS DE LAS ACCIONES
DIVINAS. ESTO SIRVE COMO RECORDATORIO DE LA IMPORTANCIA DE MANTENER UNA MENTE ABIERTA Y
RECONOCER NUESTRAS LIMITACIONES AL INTERPRETAR EVENTOS. INTERVENCIÓN DIVINA: A PESAR DE
LAS DUDAS DEL INDIVIDUO, DIOS INTERVIENE PROPORCIONÁNDOLE UNA EXPERIENCIA EN LA QUE PUEDE
PRESENCIAR Y COMPRENDER LA VERDAD DETRÁS DE LOS SUCESOS APARENTEMENTE INJUSTOS. ESTO
RESALTA LA IDEA DE QUE A VECES ES NECESARIO CONFIAR EN UN PLAN MÁS GRANDE QUE NO SIEMPRE
ES EVIDENTE A PRIMERA VISTA. CONSECUENCIAS DE LA ACCIÓN: LA HISTORIA MUESTRA CÓMO LAS
ACCIONES DE LAS PERSONAS, INCLUSO AQUELLAS QUE PARECEN CRUELES Y SIN SENTIDO, PUEDEN TENER
CONSECUENCIAS QUE SE AJUSTAN A LAS LEYES DIVINAS. CADA EVENTO SE ENTRELAZA EN UN TEJIDO
MÁS AMPLIO DE JUSTICIA. LECCIONES MORALES: LA TRAMA SUBRAYA LA IMPORTANCIA DE APRENDER
LECCIONES MORALES Y ESPIRITUALES DE LAS EXPERIENCIAS. AUNQUE EL PROTAGONISTA INICIALMENTE
DUDA DE LA JUSTICIA DIVINA, AL FINAL, COMPRENDE QUE HAY UN PROPÓSITO Y UNA RAZÓN DETRÁS DE
CADA ACONTECIMIENTO, INCLUSO AQUELLOS QUE PARECEN TRÁGICOS O INJUSTOS. JUSTICIA DIVINA: LA
HISTORIA DESTACA QUE, SEGÚN LA PERSPECTIVA DIVINA, LA JUSTICIA SIEMPRE SE CUMPLE. LAS
ACCIONES DE CADA INDIVIDUO TIENEN CONSECUENCIAS QUE, DE ALGUNA MANERA, CONTRIBUYEN A UN
EQUILIBRIO CÓSMICO MÁS GRANDE. EN RESUMEN, LA NARRATIVA SUBRAYA LA IMPORTANCIA DE CONFIAR
EN LA JUSTICIA DIVINA, INCLUSO CUANDO LOS EVENTOS PARECEN INEXPLICABLES DESDE UNA
PERSPECTIVA HUMANA. TAMBIÉN RESALTA LA NECESIDAD DE COMPRENDER QUE NUESTRAS PERCEPCIONES
LIMITADAS PUEDEN NO CAPTAR COMPLETAMENTE LA SABIDURÍA DIVINA.''',
  '68. OBATALÁ CONDENÓ A MORIR EN LA HORCA AL GALLO.': '''PATAKI: EN LA TIERRA ADIE MIYEREN QUE GOBERNABA OBATALÁ ESTABA TERMINANTEMENTE PROHIBIDO
MATAR RATONES Y ÉSTOS VIVÍAN EN UNA CUEVA QUE ERA UN SANTUARIO Y AQUEL QUE LOS MATABA
PAGABA CON SU VIDA POR DECRETO DE OBATALÁ. EN ESTA TIERRA VIVÍA EL GALLO QUE ERA UN HOMBRE
IMPORTANTE Y TENÍA MUCHO PRESTIGIO ENTRE LOS HOMBRES DE ESA TIERRA Y OBATALÁ LO ESTIMABA
MUCHO. EL GALLO SIEMPRE ESTABA EN CASA DE ORÚNMILA, QUE EN ESA TIERRA SE LLAMABA AWÓ ORUN
Y CUANDO UN DÍA ORÚNMILA LE HIZO OSODE POR PRIMERA VEZ AL GALLO LE VIO BABA EJIOGBE Y LE
DIJO: "TIENES TRES COSAS DE LAS QUE DEBES CUIDARTE PARA NO PERDERTE QUE SON":''',
  '69. LA PELEA ENTRE EL MAJÁ Y EL CANGREJO.': '''PATAKI: UN DÍA LA PALOMA LE PRESTÓ DINERO AL CANGREJO Y DESDE ENTONCES TODOS LOS DÍAS
QUERÍA COBRAR, PERO EL CANGREJO NO SE LOS DEVOLVÍA PORQUE NO TENÍA. EL MAJÁ POR GANAR LA
AMISTAD DE LA PALOMA SE BRINDÓ A COBRAR Y FUE DIRECTAMENTE A LA CASA DEL CANGREJO Y METIÓ
SU CABEZA DENTRO DE LA CUEVA Y COMENZÓ A BUSCAR AL CANGREJO, ÉSTE AL VERLO COMENZÓ A
DEFENDERSE CON SUS TENAZAS Y ASÍ PUDO ATRAPAR LA CABEZA DEL MAJÁ, QUE AL SENTIR LA PRESIÓN
Y NO PODERSE ZAFAR COMENZÓ HACER FUERZA CON SUS PATAS Y EL RABO, LA PALOMA VEÍA ESTO Y
CREYÓ QUE ERA EL MAJÁ QUIEN ESTABA GANANDO LA PELEA, POR LOS LATIGAZOS QUE ESTE DABA CON
SU RABO FUERA DE LA CUEVA. AL FIN EL MAJÁ LOGRÓ SACAR LA CABEZA FUERA DE LA CUEVA Y LA
PALOMA OBSERVÓ COMO LA TENÍA TODA ENSANGRENTADA Y CON PROFUNDAS HERIDAS, EL MAJÁ DIJO:
"POR TU CULPA MIRA CON EL CANGREJO ME HA PUESTO LA CABEZA"" LA PALOMA LE DIJO: "CUANDO VI
LOS LATIGAZOS QUE ESTABAS DANDO FUERA DE LA CUEVA PENSÉ QUE ERAS TÚ EL QUE ESTABA GANANDO
LA PELEA. SI TU NO PODÍAS PARA QUE TE METES." DICE IFÁ: QUE USTED NO SE META EN PROBLEMAS
AJENOS Y NO COBRE NI LLEVA RECADOS. NO SE PUEDE METER EN NINGUNA CASA POR MUCHA CONFIANZA
QUE TENGA. NO PUEDE ENTRAR EN CASAS OSCURAS. DE COMIDA O PAGUE LA DEUDA CON OBATALÁ. NO
DEJE QUE LOS NIÑOS ARRASTREN COSAS EN SU CASA. ENSEÑANZAS: PRUDENCIA EN LOS PRÉSTAMOS: LA
HISTORIA DESTACA LA IMPORTANCIA DE SER PRUDENTE AL PRESTAR DINERO. AUNQUE LA PALOMA PRESTÓ
DINERO AL CANGREJO, ESTE NO PODÍA DEVOLVERLO, LO QUE GENERÓ CONFLICTOS. CUIDADO CON
INVOLUCRARSE EN ASUNTOS AJENOS: EL MAJÁ, AL INTENTAR AYUDAR Y COBRAR LA DEUDA EN LUGAR DE
LA PALOMA, SE METIÓ EN UN PROBLEMA INNECESARIO. LA ENSEÑANZA ES QUE UNO DEBE SER CAUTELOSO
AL INVOLUCRARSE EN ASUNTOS AJENOS, ESPECIALMENTE FINANCIEROS. NO JUZGAR SIN ENTENDER LA
SITUACIÓN: LA PALOMA, AL OBSERVAR LA PELEA ENTRE EL MAJÁ Y EL CANGREJO, JUZGÓ MAL LA
SITUACIÓN AL PENSAR QUE EL MAJÁ ESTABA GANANDO. LA LECCIÓN ES NO JUZGAR SIN ENTENDER
COMPLETAMENTE LA SITUACIÓN. EVITAR METERSE EN LUGARES OSCUROS: LA HISTORIA MENCIONA QUE NO
SE PUEDE ENTRAR EN CASAS OSCURAS. ESTO PUEDE INTERPRETARSE COMO UN CONSEJO PARA EVITAR
SITUACIONES O LUGARES DESCONOCIDOS O PELIGROSOS. OFRECER SOLUCIONES EN LUGAR DE PROBLEMAS:
LA RESPUESTA DE LA PALOMA AL MAJÁ REFLEJA LA IMPORTANCIA DE OFRECER SOLUCIONES EN LUGAR DE
EMPEORAR LA SITUACIÓN. EL MAJÁ, AL INTENTAR AYUDAR, TERMINÓ EMPEORANDO LAS COSAS. PROTEGER
EL ENTORNO DOMÉSTICO: EL ATAQUE DEL MAJA A LA CASA DEL CANGREJO RESALTA LA IMPORTANCIA DE
UNA SEGURIDAD EN EL HOGAR Y MANTENER EL ENTORNO DOMÉSTICO SEGURO Y ORDENADO. EN RESUMEN,
LA HISTORIA ENFATIZA LA IMPORTANCIA DE LA PRUDENCIA FINANCIERA, LA PRECAUCIÓN AL
INVOLUCRARSE EN ASUNTOS AJENOS, LA COMPRENSIÓN ANTES DE JUZGAR, Y LA NECESIDAD DE OFRECER
SOLUCIONES EN LUGAR DE EMPEORAR LOS PROBLEMAS. TAMBIẾN DESTACA LA IMPORTANCIA DE CUMPLIR
CON LAS OBLIGACIONES FINANCIERAS Y PROTEGER EL ENTORNO DOMESTICO.''',
  '70. EL LEON REY DE LA SELVA.': '''PATAKI: ORÚNMILA SABIA QUE EL LEON ERA EL REY DE LA SELVA Y LE DIJO QUE EL TENIA QUE PASAR
HAMBRE, MISERA Y NECESIDADES COMO LOS DEMAS ANIMALES. EL LEON LE CONTESTO: "YO SOY EL REY
DE LA SELVA Y LO TENGO TODO". ORUNMILA SE PUSO DE ACUERDO CON ELEGBA PARA QUE EL LEON
FUERA A HACERSE EBBO Y LO CONSIGUIO. ORÚNMILA LE HIZO EBBO AL LEON Y LE PUSO UN CENCERRO
EN EL CUELLO. EL LEON REGRESO A LA SELVA Y CUANDO FUE A COMER NO LO PUDO HACER PORQUE EL
SONIDO QUE PRODUCIA EL CENCERRO LO DENUNCIABA Y NO PODIA CAPTURAR A SUS PRESAS, COMENZANDO
A PASAR HAMBRE, MISERIA Y NECESIDADES. DIAS DESPUES EL LEON VOLVIO A CASA DE ORÚNMILA A
DECIRLE QUE EL TENIA RAZON Y LO PERDONARA PUES ESTABA PASANDO HAMBRE, MISERA Y
NECESIDADES. ORÚNMILA LE QUITO EL CENCERRO Y CUANDO VOLVIO A LA SELVA LO PRIMERO QUE VIO
FUE A UN TIGRE, LO ATACÓ Y SE LO PUDO COMER. ORÚNMILA LE HIZO ESO AL LEON PORQUE ESTE SE
CONSIDERABA EL MAS PODEROSO DEL MUNDO Y ASI LE HIZO SABER QUE EL NO ERA EL MAS PODEROSO Y
QUE EN LA TIERRA NO HABIA QUIEN SE HUBIERA LIBRADO DE ESAS TRES COSAS DEL DESTINO.
ENSEÑANZAS: HUMILDAD Y RESPETO: LA HISTORIA DESTACA LA IMPORTANCIA DE LA HUMILDAD Y EL
RESPETO HACIA LAS LEYES DEL DESTINO. AUNQUE EL LEÓN SE CONSIDERABA EL REY DE LA SELVA,
ORÚNMILA LE ENSEÑÓ QUE TODOS, INCLUSO EL REY, ESTÁN SUJETOS A LAS LEYES DEL DESTINO.
CONSECUENCIAS DE LA SOBERBIA: EL LEÓN, AL PENSAR QUE LO TENÍA TODO Y NO NECESITABA SEGUIR
LAS RECOMENDACIONES DE ORÚNMILA, EXPERIMENTÓ LAS CONSECUENCIAS DE SU SOBERBIA. LA HISTORIA
ADVIERTE SOBRE LOS PELIGROS DE SUBESTIMAR LAS LECCIONES Y CONSEJOS. APRENDER DE LAS
EXPERIENCIAS: EL LEÓN, AL PASAR HAMBRE Y NECESIDADES, APRENDIÓ LA LECCIÓN DE LA HUMILDAD.
LA HISTORIA RESALTA LA IMPORTANCIA DE APRENDER DE LAS EXPERIENCIAS Y RECONOCER CUANDO SE
HAN COMETIDO ERRORES. LA SABIDURÍA DE ORÚNMILA: LA HISTORIA RESALTA LA SABIDURÍA DE
ORÚNMILA AL IDEAR UNA LECCIÓN PRÁCTICA PARA EL LEÓN. UTILIZÓ UN CENCERRO PARA MOSTRARLE AL
LEÓN QUE SU CREENCIA EN SER INVULNERABLE Y TENERLO TODO ERA ERRONEA. EN RESUMEN, LA
HISTORIA ENFATIZA LA IMPORTANCIA DE LA HUMILDAD, EL RESPETO HACIA LAS LEYES DEL DESTINO,
APRENDER DE LAS EXPERIENCIAS, RECONOCER LA PROPIA SOBERBIA, Y LA SABIDURÍA DE AQUELLOS QUE
OFRECEN CONSEJOS. TAMBIÉN DESTACA QUE NADIE ESTÁ EXENTO DE LAS TRES COSAS DEL DESTINO Y
QUE EL PERDÓN Y LA ENSEÑANZA SON PODEROSOS INSTRUMENTOS PARA LA CORRECCIÓN Y EL
CRECIMIENTO PERSONAL.''',
  '71. NO MATAR ANIMALES SIN CONSULTAR CON ORÚNMILA.': '''PATAKI: EN ESTE CAMINO ES DONDE HABÍA UN PUEBLO EN LA TIERRA TAKUA EN LA QUE VIVÍAN TRES
AWÓ, UNO ERA DE MÁS CLARA INTELIGENCIA QUE LOS DEMÁS Y ÉSTE LE TRABAJABA AL GOBERNADOR,
POR LO CUAL LOS OTROS DOS AWÓ ESTABAN LUCHANDO CON ÉL Y PORFIANDO PRODUCTO DE LA ENVIDIA.
UN DÍA SE LE PRESENTÓ UN INDIVIDUO MANDADO POR ESHUELEGBA A CADA UNO DE LOS AWÓ PARA QUE
SE ACABARA LA LUCHA, CUANDO LE HICIERON OSODE LE SALIÓ ESTE ODU OSOBO A CADA UN DE LOS
ALEYOS. DOS DE LOS AWOS DESPUÉS DE HACERLES EBÓ MATARON LOS ANIMALES SIN CONSULTAR CON
ORÚNMILA. EL OTRO AWÓ QUE SE LLAMABA IFÁ SHURÉ, NO LOS MATÓ ESE DÍA, SINO QUE LE PREGUNTÓ
A ORÚNMILA Y ÉSTE LE ORIENTÓ EL DÍA QUE DEBÍA HACERLO, PARA NO TENER DIFICULTADES ÉL NI LA
PERSONA QUE ESTABA ATENDIENDO, EN CAMBIO LOS AWÓ QUE HABÍAN SACRIFICADO LOS ANIMALES ESE
MISMO DÍA, LES FUE MAL, UNO SE ENFERMO ESTANDO ASI MUCHO TIEMPO Y EL OTRO MURIÓ. ESO PASÓ
PORQUE LA MUERTE IBA CADA TRES O SIETE DÍAS A LA CASA DE LOS IWOROS Y DE LOS AWOS QUE
VIVÍAN ALLÍ. NOTA: EL AWÓ NO DEBE MATAR ANIMALES POR GUSTO EN ÉSTE ODU Y POR ÉSTE CAMINO,
SE PREGUNTA SI SE MATA A LOS SIETE DIAS. ENSEÑANZAS:
1. EVITAR LA ENVIDIA Y LA RIVALIDAD:
LA HISTORIA RESALTA LOS PELIGROS DE LA ENVIDIA Y LA RIVALIDAD ENTRE LOS AWÓ. LA LUCHA Y LA
CONTIENDA ENTRE ELLOS SURGIERON DE LA ENVIDIA Y LLEVARON A CONSECUENCIAS NEGATIVAS.
2. IMPORTANCIA DE LA CONSULTA A ORÚNMILA: LA HISTORIA DESTACA LA IMPORTANCIA DE LA
CONSULTA A ORÚNMILA ANTES DE TOMAR DECISIONES SIGNIFICATIVAS, ESPECIALMENTE EN ASUNTOS
RELACIONADOS CON SACRIFICIOS. IFÁ SHURÉ EVITÓ PROBLEMAS AL PREGUNTAR Y SEGUIR EL CONSEJO
DE ORÚNMILA.
3. CONSECUENCIAS DE ACTUAR SIN CONSULTA: LOS DOS AWÓS QUE SACRIFICARON ANIMALES SIN
CONSULTAR A ORÚNMILA EXPERIMENTARON CONSECUENCIAS NEGATIVAS, INCLUYENDO ENFERMEDAD Y
MUERTE. ESTO SUBRAYA LA IMPORTANCIA DE LA CONSULTA ANTES DE REALIZAR SACRIFICIOS U OTRAS
ACCIONES IMPORTANTES.
4. RESPETO HACIA LOS SACRIFICIOS: LA NOTA FINAL ENFATIZA QUE EL AWÓ NO DEBE SACRIFICAR
ANIMALES POR GUSTO EN ESTE ODU Y EN ESTE CAMINO. LA PREGUNTA SOBRE SI MATAR A LOS SIETE
DÍAS RESALTA LA IMPORTANCIA DEL RESPETO HACIA LOS SACRIFICIOS Y LA NECESIDAD DE SEGUIR
PROCEDIMIENTOS ADECUADOS.''',
  '72. OLOFIN Y LOS NIÑOS.': '''PATAKI: OLOFIN UN DÍA SE LLEVÓ A LOS NIÑOS PARA EL CIELO, PORQUE AQUÍ EN LA TIERRA LOS
MALTRATABAN Y EN CASTIGO LE SUSPENDIO EL AGUA A LA TIERRA PONIENDO A ESHU-ELEGBA DE
GUARDIÁN. CUANDO SE TERMINÓ EL AGUA EN LA TIERRA, PUES NO LLOVÍA, LA SITUACIÓN SE PUSO
DESESPERADA, EN POCO TIEMPO PARA LOS HABITANTES DE LA TIERRA Y LOS SANTOS SE REUNIERON Y
DECIDIERON IR AL CIELO A PEDIRLE A OLOFIN QUE PERDONARA A SUS HIJOS, PERO ERA IMPOSIBLE
LLEGAR HASTA ÉL. YEMAYÁ SE TRANSFORMO EN UN TIÑOSA AQUÍ EN LA TIERRA Y FUE DIRECTAMENTE AL
CIELO A VER A OLOFIN. CUANDO YEMAYÁ LLEGÓ AL CIELO ESTABA SUMAMENTE FATIGADA Y SEDIENTA Y
SE PUSO A BEBER AGUA EN UN CHARCO PESTILENTE QUE ENCONTRÓ OLOFIN AL VERLA SE COMPADECIÓ DE
ELLA Y SE ACORDÓ DE SUS HIJOS QUE ESTABAN EN LA TIERRA Y DECIDIÓ PERDONARLOS Y DE
INMEDIATO MANDÓ EL AGUA, PERO POCO A POCO PARA QUE NO HUBIERA DESGRACIA. POR ESO ES QUE
CUANDO LOS SANTOS VIENEN SE LES DA AGUA PORQUE VIENEN SEDIENTOS. ENSEÑANZAS: MISERICORDIA
Y PERDÓN: LA HISTORIA DESTACA LA MISERICORDIA Y EL PERDÓN DE OLOFIN HACIA LOS NIÑOS QUE
ESTABAN SIENDO MALTRATADOS EN LA TIERRA. A PESAR DEL CASTIGO INICIAL DE SUSPENDER EL AGUA,
OLOFIN MUESTRA COMPASIÓN AL PERDONAR A SUS HIJOS CUANDO YEMAYÁ INTERCEDE POR ELLOS.
INTERCESIÓN: LA CAPACIDAD DE INTERCEDER Y ABOGAR POR OTROS SE DESTACA A TRAVÉS DE LA
FIGURA DE YEMAYA. SU VALIENTE VIAJE AL CIELO, A PESAR DE LAS DIFICULTADES EN EL CAMINO,
DEMUESTRA EL PODER DE LA INTERCESIÓN EN SITUACIONES DESESPERADAS. COMPASIÓN Y EMPATÍA: LA
REACCIÓN COMPASIVA DE OLOFIN AL VER A YEMAYÁ FATIGADA Y SEDIENTA RESALTA LA IMPORTANCIA DE
LA COMPASIÓN Y LA EMPATÍA HACIA LOS DEMÁS. ESTE ACTO DE COMPASIÓN LLEVA AL PERDÓN Y AL
RESTABLECIMIENTO DEL AGUA EN LA TIERRA. PRUDENCIA EN LA RESTAURACIÓN: OLOFIN DECIDE
RESTAURAR EL AGUA GRADUALMENTE PARA EVITAR POSIBLES DESGRACIAS. ESTA ELECCIÓN MUESTRA LA
PRUDENCIA Y LA SABIDURÍA EN LA TOMA DE DECISIONES, INCLUSO CUANDO SE OTORGA EL PERDÓN.
SIMBOLISMO DEL AGUA: EL AGUA SE PRESENTA COMO UN ELEMENTO SIMBOLICO QUE REPRESENTA LA
VIDA, LA PURIFICACIÓN Y LA RENOVACIÓN. AL DAR AGUA A LOS SANTOS QUE VISITAN EL CIELO, SE
SIMBOLIZA LA NECESIDAD DE REFRESCAR Y PURIFICAR EL ESPÍRITU. EN RESUMEN, LA HISTORIA
RESALTA VALORES COMO EL PERDON, LA INTERCESIÓN, LA COMPASION Y LA SABIDURÍA EN LA TOMA DE
DECISIONES, UTILIZANDO ELEMENTOS SIMBÓLICOS COMO EL AGUA PARA TRANSMITIR LECCIONES
ESPIRITUALES Y ÉTICAS.''',
  '73. PEREGRINAJE DE EJIOGBE, DONDE SE LE DIO LA VUELTA AL MUNDO.': '''PATAKI: ESTE ERA UN AWÓ HIJO DE EJIOGBE QUE TENÍA MUCHOS ENEMIGOS QUE LE ECHABAN
HECHICERÍA EN CUALQUIER TIERRA QUE IBA, TENIA QUE SALIR ENSEGUIDA POR LA BRUJERIA QUE LE
ENSEÑABAN LOS ENEMIGOS QUE NO LO DEJABAN TRANQUILO. ESTE AWÓ SIEMPRE SE HACÍA OSODE PERO
NO HACÍA NUNCA EBÓ COMPLETO Y ESHU-ELEGBA SIEMPRE LE PEDÍA ALGO Y NO SE LO DABA E
IGUALMENTE LE PASABA CON OBATALÁ. EL AWÓ SE VIO TAN MAL QUE TENIA QUE IR AL A LA PLAZA A
ROBAR PARA PODER COMER, PERO LA POLICIA HACIA TIEMPO QUE LE PERSEGUÍA POR QUE LOS ENEMIGOS
DABAN PARTE. SUCEDIÓ UN DÍA EN LA NOCHE CUANDO DORMÍA AWÓ SOÑÓ CON OLOFIN, DONDE ESTE LE
DECÍA QUE LE DIERA 2 COCOS JUNTO CON ESHU-ELEGBA Y QUE LUEGO OSODE Y QUE LO QUE IFÁ LE
DIJERA QUE LO HICIERA COMPLETO. CUANDO SE DESPERTÓ, SE DIO LOS DOS COCOS A SU CABEZA Y SE
HIZO OSODE Y SE VIO EJIOGBE QUE LE MARCÓ EBÓ CON 3 PALOMAS BLANCAS Y 3 CABEZAS DE JUTÍAS,
3 CABEZAS DE PESCADO, FLECHA, IFÁ LE MARCÓ QUE LO LLEVARA A TRES PUNTOS DISTINTOS DEL MAR
Y CUANDO REGRESARA DE LLEVAR EL EBÓ. SE HICIERA SARAYEYE CON UN 3 HUEVOS Y LOS ECHARA UNO
EN LA PLAZA, EL OTRO EN EL RÍO, Y EL TERCERO EN LA LOMA Y CUANDO HICIERA 7 DÍAS TENÍA QUE
IRSE DE ESA TIERRA. AL REALIZAR LA IDA DE ESA TIERRA PARA OTRA, EL AWÓ SE FUE ENTERANDO
QUE SUS ENEMIGOS POCO A POCO SE MORÍAN. EN LA NUEVA TIERRA EL AWÓ MEJORÓ UN POCO DE
SUERTE, A LOS 16 DÍAS DE ESTAR EN ESA TIERRA TUVO UN SUEÑO CON ORÚNMILA, DONDE ÉSTE LE
INDICÓ TODO LO QUE LE PASABA(TRABAJO), ETC., Y QUE EN TODO LO QUE SE METÍA, LE SALÍA MAL,
QUE LA POLICÍA LO PERSEGUÍA. EL AWÓ CUANDO PASÓ EL SUEÑO SE DIO CUENTAS DE QUE TODO ERA
CIERTO, LO QUE EL SUEÑO LE INDICABA PUESTO QUE TODAVIA IBA A CADA RATO A LA PLAZA A ROBAR.
SE HIZO OSODE Y SE VIO EJIOGBE: TRAGEDIA CON LA JUSTICIA A TRAVÉS DE LOS ENEMIGOS (EYO
INTORI ASHELÚ LESE ARAYÉ) Y QUE HICIERA EBÓ CON: 5 PLUMAS DE TIÑOSA, 25 PIMIENTA DE
GUINEA, 25 GUJAS, JUTÍA Y PESCADO AHUMADO, 5 GALLINAS, TELA NEGRA Y BLANCA, 5 CARACOLES
AYÉ, CORAZÓN DE TIÑOSA, TODO LO QUE SE COME, MUCHO DINERO. ENTONCES LE DIJO QUE EL EBÓ LO
LLEVARA AL RÍO, ADEMÁS QUE TENÍA QUE HACER UN 2 INSHE-OSANYIN CON 5 PLUMAS DE TIÑOSA, A
CADA PLUMA LE TENÍA QUE PONER 5 AGUJAS, 5 PIMIENTAS DE GUINEA Y PLUMA DE CADA GALLINA PARA
CADA UNA DE LAS PLUMAS DE TIÑOSA, ADEMÁS UN AYE, HILO NEGRO Y BLANCO, IYEFÁ QUE ESTE
INSHE-OSANYIN TENÍA QUE IR AL PIE DE ESHU-ELEGBA Y OSHÚN O DETRÁS DE LA PUERTA DE LA CASA.
EL OTRO INSHE-OSANYIN ERA PARA LLEVARLO ENCIMA, Y LLEVABA: CORAZÓN DE TIÑOSA, HILO BLANCO
Y NEGRO, PALOS FUERTES, UNA GUIRA, 5 GALLINAS SON PARA OSHUN EN EL RIO Y LLAMAR CON AGOGO
A OSHÚN EN EL RÍO, EL AGOGO VA EN EL EBÓ JUNTO CON LO DEMÁS. CUANDO EL AWÓ HIZO EL EBÓ, NO
CERRABA Y CANSADO DE PREGUNTAR, SE PUSO EL OSUN EN LA CABEZA Y ENTONCES IFÁ LE DIJO QUE A
LOS 3 DÍAS TENÍA QUE HACERSE OSODE Y IRSE PARA OTRA TIERRA, ÉL OBEDECIENDO SE FUE PARA
OTRA TIERRA Y CUANDO OSODE VIO EJIOGBE, OSALO-FORBEYÓ Y OGBE-TUA, PERDIDA A TRAVÉS DE
ALEYOS (INTORÍ OFO LESE ALEYO), EL AWÓ SE SENTÍA ENFERMO DE SU CABEZA Y SE FUE A DORMIR
SIN TERMINAR OSODE Y SUEÑA CON ESHU-ELEGBA, EL SUEÑO ERA DURO Y SE DESPERTÓ, ENTONCES EL
AWÓ ASUSTADO SE FUE A CONTINUAR EL OSODE.IFÁ LE DIO QUE HICIERA EBÓ CON: 1 POLLO, 21
PIMIENTA DE GUINEA, 3 AGUJAS, 3 VAINAS DE EJESE, UN PASHAN(CUJE) DE HIERBA AROMA, 1 VELA.
QUE ANTES DE HACER EL EBO LE ENCIENDE LA VELA A ESHU-ELEGBA, ADEMÁS OTRO CUJE DE ALMÂCIGO,
ALAMO. CUANDO EL AWÓ TERMINÓ, COGIÓ EL ÓKPELE Y SE LO PUSO A ESHU-ELEGBA Y TOMO EL POLLO
PARA DÁRSELO, COMO IFÁ LO HABÍA DICHO, ASI MISMO SEGÚN LAS INDICACIONES DE IFÁ LE METIÓ
LAS AGUJAS POR ANO Y LOS NOMBRES DE LOS ENEMIGOS, LAS 21 ATARE POR DETRÁS Y CON EL CUJE DE
HIERBA AROMA EJECUTARLOS Y PONERLES LAS TRES VAINITAS DE EJESE A ESHU-ELEGBA. NOTA: LA
SANGRE QUE DA EL POLLO AL MATARLO CON EL CUJE SE LO DA A ESHUELEGBA Y QUE COGIERA EL POLLO
Y LO METIERA EN EL EBÓ Y QUE DESPUÉS LO LLEVARA AL MONTE Y ASI LO HIZO. DONDE IFÁ LE DIJO
QUE CUANDO REGRESÓ QUE LUEGO SE BAÑARA CON HIERBA, Y ASI DE ESE MODO SE FUERON ACABANDO
LOS ENEMIGOS ANTES DEL AÑO. EL AWÓ SE ASUSTÓ Y COGIÓ UN HUEVO DE GALLINA, UN POLLO, UNA
VELA, SE HIZO SARAYEYE CON EL HUEVO Y SE LO DIO A OKE Y CON EL JIO JIO SE HIZO TAMBIÉN
SARAYEYE, LO ABRIÓ Y SE LO PUSO A ESHU-ELEGBA JUNTO CON UNA VELA Y LUEGO SE HIZO ROGACIÓN
DE CABEZA(KO-BORI) CON DOS PALOMAS BLANCAS, 2 COCOS, DOS VELAS CASCARILLA, HIERBAS:
ALGODÓN, BLEDO BLANCO, FRESCURA, AGOGO Y 16 ERU. DESPUÉS DE ESTO SE FUE A DORMIR Y TUVO UN
SUEÑO CON ESHU-ELEGBA, OLOKUN, SHANGÓ Y ORÚNMILA Y EGUN DE SU PADRE, DONDE LE DECÍAN QUE
HABÍA VENCIDO A SUS ENEMIGOS, PERO QUE TENÍA QUE DAR UNA CHIVA A ORÚNMILA Y DARLE DE COMER
A OSHA Y A EGUN. EL AWÓ AL DÍA SIGUIENTE LE DIO MO-FOORIBALE A ORÚNMILA Y A OSHA BIEN
TEMPRANO, LE ENCENDIÓ 2 VELAS AL EGUN DE SU PADRE, ROGÁNDOLES QUE LE AYUDARAN A CUMPLIR
CON TODOS ELLOS, DESPUÉS DE ESTA OPERACIÓN SE HIZO OSODE Y SE VIO EJIOGBE, IFÁ LE MARCÓ LO
MISMO QUE EN EL SUEÑO, PERO ADICIONÁNDOLE QUE TENÍA QUE DARLE DE COMER A ESHU-ELEGBA UN
CHIVO, A LOS EGUNS CARNERO Y CARNERA, ANTES DE IRSE PARA LA NUEVA TIERRA Y QUE CUANDO
LLEGARA TENIA QUE HACER EBO CON: 2 GALLOS, 6 GALLINAS, 5 PALOMAS, GUINEO, PATO, 3 POLLOS,
SARA-EKÓ, JUTÍA Y PESCADO AHUMADO, QUIMBOMBÓ, HARINA DE MAÍZ, FRUOLES, MIEL DE ABEJAS, 2
CODORNICES, HARINA A SHANGÓ, POLLO A ESHU-ELEGBA, POLLO PARA PARALDO. TODOS LOS ANIMALES
DE ORUGBO SON PARA OSHA Y ORÚNMILA, POLLO PARA ESHUELEGBA EN ITA META Y QUE TODOS LOS
ANIMALES LOS LLEVARA A SU DESTINO. EBÓ: 2 CODORNICES, HARINA CON QUIMBOMBÓ SE LE DARÁ A
SHANGÓ, Y SE LO LLEVARÁ A UNA PALMA Y QUE HABLE ALLÍ CON SHANGÓ, QUE COGIERA UNA POLLONA Y
SE LA DIERA A INLE AAFOKAN YERI QUE CUANDO SALIERA EL SOL HICIERA NANGAREO, COGIERA UN
GALLO SE LO DIERA A ESHU-ELEGBA, OGÚN, OSHOSI Y OSUN, Y A OSANYIN LE DIERA GALLO, A
ODUDUWA 4 PALOMAS. CUANDO EL AWÓ LLEGÓ A LA PALMA PUSO EL ENCARGO DE SHANGÓ, SE LE
PRESENTÓ 2 HOMBRES LE DIERON MO-FORIBALE Y LE CONTARON TODO LO QUE PASABA EN AQUELLAS
TIERRAS Y LO MAL QUE ESTABAN ALLÍ QUE HABÍA MUERTE, ENFERMEDAD, PERDIDA, Y LUTO, ETC,
ELLOS LE DIJERON QUE LO IBAN A LLEVAR DONDE ESTABA EL OBÁ DE ALLÍ PERO COMO ERA MUY TARDE
TUVO UN SUEÑO CON ESHU-ELEGBA, SHANGÓ Y ELLOS EN EL SUEÑO LE DUERON QUE IBAN A CADA RATO A
HACER OSODE Y VER A EJIOGBE. IFÁ LE DUO QUE LO VENDRÍA A BUSCAR PERO QUE ANTES DE IR TENÍA
QUE PONERLE SARA-EKÓ A TODOS LOS ORISHAS Y A ORÚNMILA. ASÍ LO HIZO Y LLEGARON LOS ORISHAS
A BUSCARLO Y FUE DONDE ESTABA EL OBÁ OFO ELEDA PERO IFÁ HABLÓ CON SU OMÓ (IKÚ). EL AWÓ LE
DUO AL OBÁ QUE ANTES DE DE DOS DÍAS TENÍA QUE HACERLE EBÓ A SU HIJO QUE NO SE MURIERA, Y
LE SIGNIFICÓ QUE TODAS LAS COSA ANDABAN CON PERDIDAS(OFO) QUE HABÍA IDO LA MUERTE(IKÚ),
ENFERMEDAD(ARUN), PERDIDA(OFO), TRAGEDIA(EYÓ), QUE EL EBÓ DE SU HIJO ERA CON: 1 PALOMA. EL
AWÓ SE FUE PARA SU OSODE Y VIO EJIOGBE, AQUEL DIA LLEGARON A CASA DEL AWO PARA DARLE
GRACIAS POR LA COMIDA QUE ÉL LE HABÍA DADO Y PARA SABER COMO ESTABA. ENTONCES EL AWÓ LE
CONTÓ A LOS TRES OSHAS LO QUE HABÍA PASADO CON EL OBÁ OFO ELEDA, YESTOS LE DIJERON QUE SE
LO DEJARA DE SU CUENTA QUE ANTES DE 7 DÍAS EL HIJO DEL OBÁ MORIRÍA, VISTO ESTO EL OBÁ
MANDÓ A BUSCAR A LOS HOMBRES VIEJOS PARA QUE ELLOS FUERAN A BUSCAR AL AWÓ, PERO ÉSTE SE
HABÍA ROGADO LA CABEZA Y TUVO UN SUEÑO CON SHANGÓ, ESHU-ELEGBA Y OLUO-POPO, DONDE LE
DECÍAN LO QUE ELLOS LE HABÍAN HECHO. LOS HOMBRES VIEJOS, TANTO LE ROGARON AL AWÓ QUE ESTE
ACCEDIÓ, DONDE LOS HOMBRES VIEJOS LES DUERON QUE ELLOS QUERÍAN QUE ÉL ACONSEJARA AL OBÁ
QUE YOKO OSHA Y DESPUÉS UNTEFÁ ORÚNMILA, PARA QUE ÉL NO SE MURIERA COMO SU HIJO. ESTANDO
DURMIENDO DICHO AWÓ, LLEGARON LOS HOMBRES VIEJOS, EL AWÓ FUE ACOMPAÑADO POR ELLOS Y CUANDO
EL OSODE AL OBÁ LE SALIÓ: ONA LESE OSHA Y UNTEFÁ ORÚNMILA, TAMBIÉN LE DIJO AL OBÁ QUE
PRIMERO HICIERA EBÓ CON 16 PALOMAS QUE SON PARA OLOFIN, JUTÍA Y PESCADO AHUMADO,
CASCARILLA, MANTECA DE CACAO, TELA BLANCA, Y QUE DESPUÉS TENÍA QUE IR PARA LA TIERRA DE
IFÁ. SALIERON PARA ESE LUGAR Y EL OBÁ YOKO-OSHA Y UNTEFA A LOS 7 DÍAS DESPUÉS. CUANDO
ACABARON DE UNTEFA EL OBÁ RECIBE UN MENSAJE DONDE LE DECÍAN QUE EN SU TIERRA LAS COSAS
MARCHABAN DE LO MEJOR PERO QUE SHANGÓ, ESHU-ELEGBA Y OLUO- POPO SE HABÍAN QUEDADO ALLÍ
ARREGLANDO TODO, CUANDO EL OBÁ SE ENTERÓ LE DIJO AL AWÓ QUE TENÍA QUE IR CON ÉL PARA ALLÁ.
CUANDO LLEGARON EL OBÁ NOMBRÓ AL AWÓ JEFE DE AQUEL LUGAR DESPUÉS DE DAR UNA FIESTA EN
EXTREMO ESPLÉNDIDA. EL AWÓ MANDÓ A BUSCAR A ESHU-ELEGBA Y LE DIJO PARA EMPEZAR A IFA HAY
QUE DARLE DE COMER, PERO A TI PRIMERO, MANDÓ A BUSCAR A SHANGÓ Y LE DIJO A TI TAMBIÉN HAY
QUE DARTE COMIDA ANTES DE EMPEZAR CUALQUIER IFÁ A OLUO-POPO LE DIJO Y USTED ES ELJEFE DE
LA ENFERMEDAD, PARA CUALQUIER MOTIVO DE ESA ÍNDOLE HAY QUE CONTAR CONTIGO Y A CADA UNO DE
LOS VIEJOS LE DIO UN PUESTO PARA CUIDAR ILEKAN, SURGIENDO ASI DAN IMOLE DE OGBENI. NOTA:
ESTE CAMINO ES DE EJIOGBE PERO SE PUEDE APLICAR POR OTRO SIGNO SI LO COGE ORÚNMILA. SE
COGE UN PLATO LLANO Y OTRO HONDO UN PEDAZO DE TELA ROJA SE DESBARATA LA LETRA CON: GALLO
BLANCO, Y DEMÁS SE MATA EL GALLO EN EL PLATO PONIENDO EL NOMBRE DE LA PERSONA DENTRO. SE
LE PONE MANTECA DE COROJO Y MIEL DE ABEJAS A LAS DOS ALAS, PATAS Y A LA CABEZA. SE LE DA
EL PLATO A LA PERSONA Y SE LE DICE, QUE UN ALA Y UNA PATA LA PONGA EN CADA ESQUINA DE SU
CASA Y LA CABEZA DEL GALLO, LA METE EN UNA JARRA CON AGUA Y POR LA NOCHE LA VOTA PARA LA
CALLE LLAMANDO EL NOMBRE DE LA PERSONA, EN NOMBRE DE SHANGÓ Y OTROS SANTOS. QUE COJA AL
OTRO DÍA POR LA MAÑANA LLEVE EL PLATO CON LA TELA AL MONTE, ALLÍ LO PONEN LLAMANDO A LA
PERSONA PIDIENDO LO QUE DESEA. EL PLATO HONDO LO PONE DEBAJO DE LA CAMA DEL INTERESADO
PONIENDO EL NOMBRE DEL QUE DESEA Y UNA FLOR ROSADA DEBAJO Y LO DEJA AHÍ MÁS DE DOS DÍAS SI
HACE FALTA. REZO: BABÁ AFOFÓ BABÁ ARORÓ ADIFAFUN OSHÚN LORDAFUN ORÚNMILA KAFEREFUN OLOKUN
LODAFUN OLOFIN, SHANGÓ, OLÚO POPO, OWO PIPO, ESHU-ELEGBA, OLOKUN, OLUOPOPO, ALAFIA,
ORÚNMILA UNYEN OGÚ. NOTA: LOS HIJOS DE EJIOGBE SON MUY ADICTOS A ROBAR DE VEZ EN CUANDO Y
A MIRAR (OLO Y OYU). ENSENANZAS: RESPONSABILIDAD POR ACCIONES PASADAS: LAS ACCIONES
PASADAS PUEDEN AFECTAR EL PRESENTE. LOS PROBLEMAS ENFRENTADOS POR EL AWÓ ERAN CONSECUENCIA
DE SUS ACCIONES PREVIAS, LO QUE RESALTA LA IMPORTANCIA DE TOMAR RESPONSABILIDAD POR
NUESTRAS DECISIONES. RESPETO A LA ESPIRITUALIDAD: EL RELATO MUESTRA CÓMO LA CONEXIÓN CON
LA ESPIRITUALIDAD Y EL RESPETO POR LAS DEIDADES Y RITUALES SAGRADOS PUEDEN MARCAR LA
DIFERENCIA EN LA VIDA DE ALGUIEN. LOS RITUALES Y LAS OFRENDAS TENÍAN UN IMPACTO DIRECTO EN
SU SUERTE Y PROTECCIÓN. APRENDER DE LOS SUEÑOS Y LOS ORÁCULOS: LA IMPORTANCIA DE PRESTAR
ATENCIÓN A LOS MENSAJES EN LOS SUEÑOS Y LAS CONSULTAS A LOS ORÁCULOS ES UN PUNTO CLAVE. EL
AWÓ ENCONTRÓ GUÍA Y DIRECCIÓN A TRAVÉS DE ESTAS VISIONES Y CONSULTAS PARA RESOLVER SUS
PROBLEMAS. RENOVACIÓN Y CAMBIO: A PESAR DE LOS DESAFÍOS, EL AWÓ TUVO LA VALENTÍA DE BUSCAR
UN NUEVO COMIENZO. EL CAMBIO DE LUGAR LE TRAJO MEJORAS SIGNIFICATIVAS Y UNA OPORTUNIDAD
PARA DEJAR ATRÁS LAS DIFICULTADES DEL PASADO. LA IMPORTANCIA DE LA GRATITUD Y EL RESPETO:
EL RECONOCIMIENTO A LAS DEIDADES Y EL AGRADECIMIENTO POR LA AYUDA RECIBIDA FUERON
ELEMENTOS FUNDAMENTALES PARA SUPERAR LOS PROBLEMAS. LA GRATITUD Y EL RESPETO HACIA LAS
FUERZAS SUPERIORES FUERON CLAVE EN SU CAMINO HACIA LA ESTABILIDAD. RESOLUCIÓN DE
CONFLICTOS: AUNQUE LA HISTORIA INVOLUCRA CONFLICTOS Y ENEMIGOS, MUESTRA CÓMO LAS PRÁCTICAS
ESPIRITUALES Y LA ORIENTACIÓN PUEDEN CONDUCIR A LA RESOLUCIÓN PACÍFICA DE PROBLEMAS Y
ALIVIAR TENSIONES. EN RESUMEN, LA HISTORIA ENFATIZA LA IMPORTANCIA DE LA RESPONSABILIDAD
PERSONAL, LA CONEXION CON LO ESPIRITUAL, LA ADAPTABILIDAD ANTE LOS DESAFIOS Y LA BUSQUEDA
DE ORIENTACIÓN PARA SUPERAR OBSTÁCULOS Y ENCONTRAR LA PAZ Y LA PROSPERIDAD.''',
  '74. AQUÍ ORÚNMILA LE ENAMORÓ LA MUJER AL GALLO.': '''PATAKI: ACONTECIÓ QUE ORÚNMILA ESTABA MAL DE SITUACIÓN Y DECIDIÓ IR A OTRO PUEBLO A VER SI
PODÍA MEJORAR Y ENCONTRAR DESENVOLVIMIENTO HASTA QUE LLEGÓ A UN PUEBLO Y SE ENCONTRÓ A UN
LEONCITO Y LE PREGUNTÓ, COMO SE LLAMABA Y ÉSTE LE RESPONDIÓ. LEONCITO, MI PADRE SE LLAMA
LEÓN Y MI MADRE SE LLAMA LEONA Y ORÚNMILA DIO, ESTA TIERRA NO ME CONVIENE Y SIGUIÓ SU
CAMINO EN BUSCA DE OTRO LUGAR. LLEGÓ A OTRO PUEBLO SE ENCONTRÓ CON UN LEOPARDITO Y LE
PREGUNTÓ POR SU NOMBRE Y ESTE LE DIO, ME LLAMO LEOPARDITO, MI MADRE SE LLAMA LEOPARDA Y MI
PADRE LEOPARDO, Y ORÚNMILA SE DIJO ESTE PUEBLO TAMPOCO ME CONVIENE Y SIGUIÓ SU CAMINO
LLEGANDO A OTRO PUEBLO DONDE SE ENCONTRÓ A UN POLLITO A QUIEN LE PREGUNTÓ QUE COMO SE
LLAMABA Y ÉSTE LE RESPONDIÓ: MI MADRE SE LLAMA GALLINA NEGRA Y MI PADRE GALLO Y MIS
HERMANOS EL MAYOR POLLON Y MI HERMANA POLLONA. ¿Y DÓNDE VIVES POLLITO? VENGO DE LA LOMA.
¿ME PUEDES TÚ LLEVAR A TU CASA? SI, COMO NO, SÍGAME, Y ORÚNMILA SIGUIENDO AL POLLITO ECHÓ
A ANDAR HASTA QUE LLEGARON A LA CASA DONDE ESPERABA LA GALLINA. ORÚNMILA AL VER AQUELLA
MUJER TAN HERMOSA Y ATRACTIVA, SE QUEDÓ IMPRESIONADO CON ELLA Y LE DIJO: "SEÑORA SI USTED
ME PERMITIERA PASAR UN MOMENTO PARA ASEARME Y COMER ALGO PUES LLEVO DÍAS SI HACERLO", Y
ELLA LE RESPONDIÓ: "BUENO PARA ESO TIENE QUE VER AL GALLO, MI ESPOSO PARA QUE ÉSTE LO
AUTORICE, ASI QUE ESPERE AFUERA'" ESTO LE CAYÓ MALA ORÚNMILA, PUES PRESUMÍA DE QUE LAS
MUJERES NO SE LE RESISTÍAN, PERO ÉL IGNORABA QUE LA GALLINA ERA UNA MUJER DE ORDEN Y
DECIDIÓ ESPERAR. AL RATO DE ESTAR ALLÍ VIO UNA PERSONA QUE VENÍA POR EL CAMINO Y SE DIJO:
"ESTE DEBE SER EL GALLO PUES CAMINA IGUAL QUE EL POLLITO", Y LE SALIÓ AL PASO Y LE CONTÓ
LO QUE HABÍA HABLADO CON LA GALLINA Y EL GALLO LE DIJO: "BIEN TE PUEDES QUEDAR." PERO
CUANDO EL GALLO DIJO ESTO, A LA GALLINA NO LE AGRADÓ. ELLA ESTABA LUCIENDOSE COMO UNA GRAN
SEÑORA DE SU CASA Y ORÚNMILA ESTABA PROFUNDAMENTE IMPRESIONADO POR LA GALLINA. DESPUÉS DE
BAÑARSE, SE SENTARON A LA MESA Y ORÚNMILA COMENZÓ A HACER CHISTES SIN QUE LA GALLINA
PUSIERA EL MÁS MÍNIMO INTERÉS. DESPUÉS DE TOMAR CAFÉ LA GALLINA Y EL GALLO SE RETIRARON A
DESCANSAR PUESTO QUE EL GALLO ERA TRABAJADOR Y SE TENÍA QUE LEVANTAR MUY TEMPRANO. EL
GALLO SE LEVANTÓ AL ALBA Y ORÚNMILA QUE ESTABA DISGUSTADO GRANDEMENTE POR LA INDIFERENCIA
DE LA GALLINA, APROVECHÓ QUE EL GALLO SE ESTABA BAÑANDO Y ENTRÓ EN EL CUARTO DE LA GALLINA
TRATANDO DE BESARLA PERO ÉSTA SE RESISTIÓ Y AMENAZÓ CON LLAMAR AL GALLO.CUANDO EL GALLO
SALIÓ DEL BAÑO DESAYUNARON Y LE DIJO: "BUENO AMIGO YO ME VOY PARA EL TRABAJO Y NO LO PUEDO
DEJAR AQUÍ, YO LE ENSEÑARÉ DONDE PUEDE CONSEGUIR TRABAJO Y DONDE PUEDE DORMIR." ASI LO
HICIERON, PERO ORÚNMILA NO QUEDÓ CONFORME PUESTO QUE NINGUNA MUJER SE LE HABÍA RESISTIDO,
ASI QUE PARA VENGAR SU DIGNIDAD HERIDA SE TRAZÓ UN PLAN Y SE FUE PARA EL PUEBLO SIGUIENTE
Y ALLÍ SACA SU ÓKPUELE Y SE HACE OSODE SALIENDO BABÁ EJIOGBE, CUANDO LA GENTE VIERON
AQUELLO EMPEZARON A PROCLAMAR AL ADIVINO, ORÚNMILA LES HABLÓ Y LE DIJO QUE LOS IBA SACAR
ADELANTE Y EMPEZÓ A HACER EBÓ Y TODO EL PUEBLO ADQUIRIÓ MUCHO DESENVOLVIMIENTO, PERO
ORÚNMILA NO DEJABA DE PENSAR EN LA GALLINA. UN DÍA MANDO A REUNIR A TODOS EN EL PUEBLO Y
LES DIJO: "USTEDES TIENEN QUE IR AL PUEBLO DE AQUÍ AL LADO Y MATAR A TODO EL MUNDO MENOS A
LA MUJER QUE VIVE EN LA LOMA, A ESA LA TRAEN VIVA. AL JEFE DE AQUEL PUEBLO ORÚNMILA LE
HABÍA CONSAGRADO EN IFÁ Y SE LLAMABA OFUN-SUSU Y EL FUE AL FRENTE DE LO GUERREROS Y
ACABARON CON TODOS Y COGIERON A LA GALLINA NEGRA Y SE LA LLEVARON A ORÚNMILA. CUANDO ÉSTA
LO TUVO DELANTE COMENZÓ A OFENDERLO, Y ORÚNMILA LE DIJO: "TANTO QUE ME HICISTE SUFRIR Y
AHORA TE TENGO", PERO LA GALLINA SEGUÍA NEGÁNDOSE A LAS CARICIAS DE ORÚNMILA ESCUPIÉNDOLE
Y ABOFETEÁNDOLE, ENTONCES MANDÓ A OFUN SUSU QUE LA AMARRARA Y SE LA COMIÓ. OLOFIN QUE
SABÍA LO QUE ESTABA PASANDO LE DIJO A ORÚNMILA: "POR EL ABUSO QUE HAS COMETIDO MIENTRAS EL
MUNDO SEA MUNDO TU SOLO COMERÁS GALLINAS NEGRAS Y A TI, OFUN-SUSU, TE PERSEGUIRÁ LA
MALDICIÓN DE LA GALLINA NEGRA Y SOLO PODRÁS COMER PARA TRANQUILIDAD DE TU PUEBLO GALLINA
BLANCA." OFUN-SUSU SE PUSO BRAVO, COMO UN LOCO Y HUBO QUE DARLE URGENTE GALLINA BLANCA
RÁPIDO EN SU CABEZA PARA APLACAR LA TIERRA DE BABÁ EJIOGBE Y OFUNSUSU, ENTONCES OLOFIN LE
DIJO A ORÚNMILA: "PARA RECORDARTE TU COMPROMISO CON LAS MUJERES PONLE A CADA UNA PLUMAS DE
GALLINA EN SU CABEZA Y LE DICES: JUJU LERÍ ADIE APETEVÍ ABANA", Y ENTONCES LE DIJO A
ORÚNMILA, PARA QUE IFÁ NO SE PONGA OFO COGE MANTECA DE COROJO Y LA LIGAS CON GRASA DE
GALLINA Y PÁSALE LA MANO A TU IFÁ CON TODO ESTO. NOTA: SE DESEAN TODAS LAS MUJERES, AÚN
LAS QUE TIENEN COMPROMISO, SE VIOLAN LAS MUJERES. NACE QUE ORÚNMILA SOLO COMA GALLINA
NEGRA POR SENTENCIA DE OLOFIN Y EL PASARLE LA MANO A IFÁ CON MANTECA DE COROJO Y GRASA DE
GALLINA LIGADA, PARA QUE NO SE PONGA OFO, EN RECORDACIÓN AL ABUSO QUE COMETIÓ CON LA
GALLINA NEGRA LA MUJER DEL GALLO. REZO: ORUNMILA SHOKOFOBAE INLE ADIE ERU OTERKOKO BOKORO
LA ADIE ERU DADA DEL OLOAKEYEBI. ORÚNMILA YIO ADIE ERU ORÚNMILA TROFA ABANÍ KOTO TOSHEGUN
ODA ABANI IFÁ LASHE ADIFAFUN OLOFIN. EBÓ: 1 GALLO, 2 GALLINAS NEGRAS, JUTÍA Y PESCADO
AHUMADO, MAIZ TOSTADO, AGUARDIENTE, VELAS, MUÑECO HEMBRA Y MACHO, MUCHO DINERO.
ENSEÑANZAS: RESPETO HACIA LOS DEMÁS: LA HISTORIA RESALTA LA IMPORTANCIA DE RESPETAR LA
AUTONOMÍA Y LA DECISIÓN DE LOS DEMÁS. ORÚNMILA INTENTA IMPONER SU VOLUNTAD SOBRE LA
GALLINA, PERO ELLA SE MANTIENE FIRME EN SUS PRINCIPIOS. CONSECUENCIAS DE LA ARROGANCIA Y
EL ABUSO: ORÚNMILA, AL TRATAR DE FORZAR SU VOLUNTAD SOBRE LA GALLINA, SUFRE CONSECUENCIAS
NEGATIVAS. LA ARROGANCIA Y EL ABUSO DE PODER PUEDEN TENER REPERCUSIONES EN LA VIDA DE LAS
PERSONAS. JUSTICIA Y CASTIGO: LA HISTORIA PRESENTA UN SENTIDO DE JUSTICIA EN EL CASTIGO
QUE RECIBE ORÚNMILA POR SU COMPORTAMIENTO INAPROPIADO. LA GALLINA ES LLEVADA ANTE ÉL COMO
PARTE DE UNA RECOMPENSA, PERO ESTA RECOMPENSA INMERECIDA SE VUELVE EN SU CONTRA. EL
RESPETO POR LAS DECISIONES DE PAREJA: LA HISTORIA TAMBIÉN DESTACA LA IMPORTANCIA DE
RESPETAR LAS DECISIONES Y LA PRIVACIDAD DE LAS PAREJAS. ORÚNMILA INTENTA INTERFERIR EN LA
RELACIÓN ENTRE LA GALLINA Y EL GALLO, LO QUE RESULTA EN UN CASTIGO. EL USO ADECUADO DE LA
ADIVINACIÓN Y EL PODER: ORÚNMILA INICIALMENTE UTILIZA SU HABILIDAD DE ADIVINACIÓN PARA
VENGANZA PERSONAL, LO CUAL RESULTA EN CONSECUENCIAS NEGATIVAS. SIN EMBARGO, AL FINAL,
RECIBE UNA GUÍA SOBRE CÓMO USAR SU PODER DE MANERA MÁS RESPONSABLE Y RESPETUOSA. LA
IMPORTANCIA DE APRENDER DE LAS LECCIONES: AUNQUE ORÚNMILA SUFRE LAS CONSECUENCIAS DE SUS
ACCIONES, AL FINAL RECIBE UNA LECCIÓN SOBRE LA IMPORTANCIA DE RECORDAR Y APRENDER DE SUS
ERRORES. LA SIMBOLOGÍA DE LOS RITUALES: LOS RITUALES AL FINAL DE LA HISTORIA, COMO EL USO
DE PLUMAS DE GALLINA EN LA CABEZA Y EL ACTO DE PASARLE LA MANO A IFÁ CON MANTECA DE COROJO
Y GRASA DE GALLINA, SON SÍMBOLOS DE ARREPENTIMIENTO Y RECORDATORIO DE LA LECCIÓN
APRENDIDA.''',
  '75. LA ROSA ROJA Y EL SACRIFICIO EN VANO DE EJIOGBE.': '''PATAKI: HABÍA UNA VEZ UN HOMBRE QUE SE ENAMORÓ PERDIDAMENTE DE UNA PRINCESA Y TANTO LA
ASEDIÓ HASTA QUE LE DIJO UN DÍA QUE ESTABA PERDIDAMENTE ENAMORADO DE ELLA, Y ELLA LE DIJO
QUE ÉL NO ERA DE SU ALTURA, QUE ERA INFERIOR PORQUE ELLA ERA UNA PRINCESA Y LE DIJO ADEMÁS
QUE SOLO LA OBTENDRÍA CUANDO FUERA LO SUFICIENTEMENTE RICO PARA ASÍ HACERLA FELIZ. DICHO
HOMBRE SE FUE PARA TIERRAS LEJANAS DONDE PASANDO TRABAJOS Y SINSABORES POCO A POCO SE FUE
HACIENDO RICO. UN DIA DESPUÉS DE CAMINAR AQUELLA TIERRA SE ADENTRÓ EN EL BOSQUE PARA
TRATAR DE AUMENTAR SU FORTUNA CON LA RIQUEZA DEL MISMO Y ALLÍ TERMINÓ DE HACERSE
INMENSAMENTE RICO. TRABAJANDO ASÍ DE ESTA FORMA CADA VEZ QUE SE ACORDABA DE SU AMADA LO
EMBARGABA UNA GRAN TRISTEZA Y SE PONÍA A CANTAR UNA EXTRAÑA MELODÍA LA QUE FUE ESCUCHADA
POR UN RUISEÑOR QUE VIVÍA EN AQUELLOS PARAJES Y QUE ARROBADO POR AQUELLA MELODÍA ENTABLÓ
AMISTAD CON DICHO HOMBRE. EL HOMBRE LE CONTÓ SUS PENAS AL RUISEÑOR Y ESTE LE PIDIÓ QUE LE
ENSEÑARA LA MELODÍA Y ASÍ SE HICIERON GRANDES AMIGOS, PERO UN BUEN DÍA EL HOMBRE
DESAPARECIÓ Y EL RUISEÑOR SE PUSO MUY TRISTE. CUANDO EL HOMBRE LLEGÓ A SU TIERRA
INMEDIATAMENTE SE PRESENTÓ ANTE SU AMADA CONTÁNDOLE TODO LO QUE HABÍA PASADO Y QUE YA ERA
MUY RICO Y QUE VENÍA PARA CASARSE CON ELLA, ENTONCES ELLA LE DUO QUE ÉL DEBERÍA DE TRAERLE
UNA ROSA ROJA PARA FORMALIZAR EL MATRIMONIO, ELLA SABÍA MUY BIEN QUE EN TODAS AQUELLAS
TIERRAS NO HABÍA NINGUNA RASA ROJA Y SE LO DIJO PARA DEMORAR EL MATRIMONIO. EL POBRE
HOMBRE NO SE DABA CUENTA DE QUE AQUELLO ERA UNA BURLA DE PARTE DE ELLA Y QUE ESTA NO LO
AMABA. EL SALE A BUSCAR LA ROSA ROJA PENSANDO QUE LA CONSEGUIRIA FACIL, PERO POR MUCHO QUE
ANDABA NO LA ENCONTRABA ENTONCES DESCONSOLADO Y ABATIDO SE DIRIGIÓ AL BOSQUE Y TAN PRONTO
LLEGA SE PONE A SILBAR AQUELLA EXTRAÑA MELODÍA, LA QUE AL INSTANTE FUE OÍDA POR EL
RUISEÑOR QUE MUY CONTENTO SALE A SU ENCUENTRO Y TAN SOLO DE VERLO COMPRENDE EL ESTADO DE
ANGUSTIA EN QUE SE ENCUENTRA SU AMIGO EL RUISEÑOR LE DICE QUE DESDE QUE ÉL SE HABÍA
MARCHADO SE ENCONTRABA MUY TRISTE YA QUE NO OÍA SU MELODÍA Y NO NOTABA SU PRESENCIA, EL
HOMBRE LE CUENTA POR LA ANGUSTIA QUE PASABA Y CUAL ES EL VERDADERO PROBLEMA QUE LO HA
LLEVADO AL BOSQUE. ENTONCES EL RUISEÑOR TOMA UNA ROSA BLANCA Y LE DICE: MIRA LLÉVALE ESTA
ROSA Y SI ELLA TE AMA ENCONTRARÁ ESTA ROSA MUY BELLA, PERO EL LE DICE QUE NO, QUE TIENE
QUE SER UNA ROSA ROJA, EL RUISEÑOR LE DICE, MIRA, VE A DESCANSAR, QUE VOY A ROGAR PARA QUE
MAÑANA TU ENCUENTRES UNA ROSA ROJA, CUANDO EL HOMBRE CANSADO Y ABATIDO POR LA FATIGA SE
QUEDÓ DORMIDO, EL RUISEÑOR SE ENCARAMA ENCIMA DE UNA FLOR BLANCA Y CON SU ESPINA SE
TRASPASA EL CORAZÓN, TIÑENDO CON SU SANGRE LA ROSA BLANCA, Y QUEDANDO ESTA COMPLETAMENTE
ROJA. EL HOMBRE POR LA MAÑANA DESPIERTA Y LO PRIMERO QUE VE ES AQUELLA ROSA ROJA BELLÍSIMA
Y LA ARRANCA Y SALE CORRIENDO PARA EL PALACIO, SIN PERCATARSE QUE A LOS PIES DEL ROSAL
ESTÁ SU AMIGO EL RUISEÑOR, TENDIDO EN EL SUELO MUERTO, SOLO PENSÓ QUE SE HABÍA HECHO UN
MILAGRO POR LOS RUEGOS DE SU AMIGO, Y NO PERCATÁNDOSE DEL SACRIFICIO DE SU AMIGO, EL
HOMBRE SE PRESENTÓ A LOS PIES DE SU AMADA CON AQUELLA BELLA ROSA ROJA Y ELLA LE DICE
ENTONCES, NUNCA TE QUISE, SOLO TE PUSE ESTA CONDICIÓN PENSANDO QUE NUNCA LLEGARÍA A
ALCANZARLA PERO LA REALIDAD ES QUE NO TE AMO Y POR LO TANTO NO PUEDO CASARME CONTIGO,
CUANDO EL HOMBRE OYÓ ESTO COMPRENDIÓ QUE TODOS SUS SACRIFICIOS HABIAN SIDO EN VANO. NOTA:
A LA PERSONA QUE LE SALGA ESTE IFÁ SE LE DICE QUE TODO EL SACRIFICIO QUE PUEDA HACER POR
LOS DEMÁS SERÁ EN VANO, PUEDE HASTA PERDER LA VIDA SIN PERCATARSE QUE LOS DEMÁS POR MUCHO
QUE ÉL SE SACRIFIQUE, NUNCA LO TENDRÁN EN CUENTA. ENSENANZAS: SACRIFICIOS NO
CORRESPONDIDOS: LA HISTORIA ILUSTRA EL TEMA DE SACRIFICIOS NO CORRESPONDIDOS. EL HOMBRE,
PROFUNDAMENTE ENAMORADO, SUPERA ADVERSIDADES, SE VUELVE RICO E INCLUSO PIERDE A UN QUERIDO
AMIGO PARA GANARSE EL AMOR DE LA PRINCESA. VALOR DE LOS SENTIMIENTOS: LA HISTORIA RESALTA
LA IMPORTANCIA DE EXPRESAR LOS SENTIMIENTOS. A TRAVÉS DE LA MELODÍA Y LAS CONFESIONES, EL
HOMBRE ENCUENTRA CONSUELO Y COMPRENSIÓN, DEMOSTRANDO QUE COMPARTIR LAS EMOCIONES PUEDE
FORTALECER LOS LAZOS. SACRIFICIO Y DESILUSIÓN: EL SACRIFICIO FINAL DEL RUISEÑOR, QUE DA SU
VIDA PARA TEÑIR UNA ROSA BLANCA DE ROJO, SIMBOLIZA EL SACRIFICIO DESINTERESADO, PERO
TAMBIÉN SEÑALA LA DESILUSIÓN CUANDO EL HOMBRE NO COMPRENDE LA VERDADERA NATURALEZA DEL
AMOR DE LA PRINCESA. DESAFÍOS DE LA BÚSQUEDA DEL AMOR: LA BÚSQUEDA DEL HOMBRE DE UNA ROSA
ROJA SIMBOLIZA LOS DESAFÍOS Y OBSTÁCULOS EN LA BÚSQUEDA DEL AMOR. LA HISTORIA ADVIERTE
SOBRE LA IMPORTANCIA DE RECONOCER CUANDO LAS CONDICIONES IMPUESTAS SON IMPOSIBLES DE
CUMPLIR. LECCIONES DE DESAPEGO: LA HISTORIA ENSEÑA SOBRE DESAPEGARSE DE EXPECTATIVAS
IRREALES. A PESAR DE LOS SACRIFICIOS, EL HOMBRE ENFRENTA LA DURA REALIDAD DE QUE LOS
ESFUERZOS PUEDEN SER EN VANO CUANDO NO SON APRECIADOS O CORRESPONDIDOS. REFLEXIÓN SOBRE EL
VERDADERO VALOR: LA HISTORIA CONCLUYE CON LA REVELACIÓN DE QUE LOS SACRIFICIOS DEL HOMBRE
FUERON EN VANO, DESTACANDO LA IMPORTANCIA DE REFLEXIONAR SOBRE EL VERDADERO VALOR DE LAS
ACCIONES Y EL AMOR ANTES DE COMPROMETERSE PROFUNDAMENTE. EN RESUMEN, LA HISTORIA ABORDA
TEMAS UNIVERSALES DE AMOR, SACRIFICIO, AMISTAD Y DESILUSIÓN, PROPORCIONANDO LECCIONES
SOBRE LA COMPLEJIDAD DE LAS RELACIONES HUMANAS Y LA IMPORTANCIA DE COMPRENDER Y VALORAR
LOS SENTIMIENTOS PROPIOS Y AJENOS.''',
  '76. LOS SÚBDITOS DE OLOFIN.': '''PATAKI: LOS SÚBDITOS DE OLOFIN TENÍAN POR COSTUMBRE TODAS LAS MAÑANAS IR A SUS PIES A
PEDIRLE LA BENDICIÓN LE BESABAN LAS MANOS, LOS PIES Y LA TÚNICA SAGRADA, DEMOSTRANDO ASÍ
UNA VERDADERA Y MÍSTICA ADORACIÓN AL PADRE, A TAL EXTREMO QUE ESTE CREÍA QUE ESA ADORACIÓN
DE AFECTO Y CARIÑO NACÍA DE LO MÁS PROFUNDO DEL CORAZÓN, Y QUE POR CONSIGUIENTE ERAN
SINCEROS Y ABNEGADOS FIELES. EJOGBE QUE A MENUDO FRECUENTABA LAS FIESTAS Y LOS LUGARES DE
REUNIÓN Y HASTA LOS HOGARES DE MUCHOS DE ELLOS, LLEGÓ A COMPRENDER QUE ERAN EGOÍSTAS,
SOBERBIOS, ENVIDIOSOS, HIPÓCRITAS Y QUE CADA CUAL TRATABA DE VIVIR LO MEJOR POSIBLE AUNQUE
PARA ELLO TUVIERAN QUE PERJUDICAR A LOS DEMÁS. UNA MAÑANA CUANDO LOS SÚBDITOS ESTABAN
RINDIÉNDOLE LA ACOSTUMBRADA PLEITESÍA A OLOFIN EJIOGBE LE DICE: PAPÁ USTED NO SABE QUE ESA
MUESTRA DE AFECTO Y CARIÑO ES PURA HIPOCRESÍA, A LO QUE OLOFIN LE RESPONDIÓ, OBSERVA CON
QUE DEVOCIÓN ME RINDEN HOMENAJE Y ESTO ES PRUEBA FEHACIENTE DE QUE ACATAN CON ALEGRIA LOS
PRECEPTOS MORALES QUE YO LES HE DICTADO PARA SU FELICIDAD Y LA DE SUS DESCENDIENTES, SI
FUERAN MALOS E HIPÓCRITAS COMO TU ME DICES ENTONCES ELLOS NO PODRÍAN OFRECERME ESAS
PRUEBAS DE GRATITUD. EJIOGBE NO QUEDÓ CONFORME Y CADA MAÑANA LE HACÍA PARECIDAS
INSINUACIONES AL PADRE OLOFIN Y ÉSTE NO CREYÉNDOLE SE HACÍA EL DESENTENDIDO. UNA MAÑANA
OLOFIN YA CANSADO DE OÍR TALES INSINUACIONES ESPERÓ A QUE LOS SÚBDITOS LE RINDIERAN MO-
FORIBALE Y LOS PARÓ Y EN PRESENCIA DE EJIOGBE LES PREGUNTÓ: SÚBDITOS MÍOS, YO DESEO SABER
SI USTEDES ME AMAN Y OBEDECEN LOS MANDATOS QUE PARA VUESTRA FELICIDAD Y LA DE LOS SUYOS YO
OS HE ENSENADO. ENTONCES LOS SUBDITOS PONIENDOSE DE RODILLAS DELANTE DE OLOFIN
RESPONDIERON. PAPÁ NOSOTROS LOS AMAMOS Y RESPETAMOS, ACEPTAMOS Y OBEDECEMOS SUS MANDATOS
PUES BIEN SABEMOS QUE ES PARA NUESTRA FELICIDAD. CUANDO LOS SÚBDITOS SE RETIRARON EJIOGBE
LE DUO A OLOFIN, PAPÁ NO ESTOY DE ACUERDO CON NADA DE ESO, TODA ESTA DEMOSTRACIÓN ES PURA
HIPOCRESÍA, PUES SI ELLOS SON MALOS LOS UNOS CON LOS OTROS, NO PUEDEN AMARLO A USTED COMO
ELLOS EXPRESAN, Y CON SU PERMISO, MAÑANA LE DEMOSTRARÉ DE UNA VEZ Y POR SIEMPRE QUE YO
TENGO TODA LA RAZÓN. AL SIGUIENTE DÍA CUANDO LLEGÓ LA HORA DE LA ADORACIÓN, EJIOGBE
PREPARÓ UNA CANASTA LLENA DE MONEDAS DE ORO Y SE PUSO A LA DERECHA DE OLOFIN, CUANDO LOS
SÚBDITOS SE IBAN A PONER DE RODILLAS PARA DEMOSTRAR LA ADORACIÓN POR OLOFIN, EJIOGBE DANDO
UN PASO AL FRENTE Y LEVANTANDO LA CANASTA SOBRE SU CABEZA LA LANZÓ HACIA ATRÁS, LOS
SÚBDITOS AL VER LA CANTIDAD DE MONEDAS DE MONEDAS DE ORO QUE HABÍA EN EL PISO SE
ABALANZARON HACIA ALLÍ Y EJIOGBE TUBO QUE APARTAR A OLOFIN RÁPIDAMENTE, PARA QUE CON SU
APURO LOS SÚBDITOS NO LO FUERAN A TUMBAR O A DARLE UN MAL GOLPE. EN ESE MOMENTO OLOFIN
COMPRENDIÓ LAS RAZONES DE EJIOGBE Y SENTENCIÓ, EJIOGBE ES VERDAD QUE SON MALOS Y QUE NO SE
AMAN LOS UNOS A LOS OTROS Y HAN DEMOSTRADO QUE SON FALSOS E HIPÓCRITAS. ENSEÑANZAS: LA
VERDADERA NATURALEZA DE LAS PERSONAS: LA HISTORIA RESALTA LA DUALIDAD ENTRE LAS
APARIENCIAS Y LA REALIDAD. AUNQUE LOS SÚBDITOS DE OLOFIN MOSTRABAN DEVOCIÓN Y RESPETO EN
PÚBLICO, SU VERDADERA NATURALEZA EGOÍSTA, SOBERBIA Y ENVIDIOSA SE REVELÓ CUANDO FUERON
TENTADOS CON RIQUEZAS. HONESTIDAD Y SINCERIDAD: EJIOGBE REPRESENTA LA HONESTIDAD Y LA
SINCERIDAD AL CUESTIONAR LA AUTENTICIDAD DE LA DEVOCIÓN DE LOS SÚBDITOS. A PESAR DE LA
APARENTE MUESTRA DE AFECTO, ÉL BUSCÓ LA VERDAD Y DEMOSTRÓ QUE LA HIPOCRESÍA NO PUEDE
OCULTARSE POR MUCHO TIEMPO. CONSECUENCIAS DE LA DESLEALTAD: LA DESLEALTAD DE LOS SÚBDITOS
HACIA OLOFIN TUVO CONSECUENCIAS INMEDIATAS CUANDO FUERON TENTADOS CON LA CANASTA DE
MONEDAS DE ORO. ESTO DESTACA CÓMO LAS ACCIONES DESHONESTAS PUEDEN LLEVAR A LA TRAICIÓN Y A
LA PÉRDIDA DE LA CONFIANZA. EL PAPEL DEL LÍDER: OLOFIN, COMO LÍDER, INICIALMENTE NO
RECONOCIÓ LAS INSINUACIONES DE EJIOGBE Y CONFIABA EN LA DEVOCIÓN APARENTE DE SUS SÚBDITOS.
SIN EMBARGO, AL FINAL, COMPRENDIÓ LA VERDAD Y RECONOCIÓ LA NECESIDAD DE EVALUAR LA LEALTAD
DE SUS SEGUIDORES. LA IMPORTANCIA DE LA PRUEBA: LA HISTORIA MUESTRA CÓMO UNA PRUEBA
INESPERADA PUEDE REVELAR LA VERDADERA NATURALEZA DE LAS PERSONAS. EL ACTO DE LANZAR LA
CANASTA DE MONEDAS DE ORO PROPORCIONÓ UNA OPORTUNIDAD PARA QUE LOS SÚBDITOS MOSTRARAN SU
VERDADERO CARÁCTER. APRENDER DE LAS LECCIONES: OLOFIN, AL COMPRENDER LA REALIDAD DE LA
SITUACIÓN, APRENDIÓ UNA LECCIÓN SOBRE LA IMPORTANCIA DE EVALUAR LA SINCERIDAD DE AQUELLOS
QUE LO RODEAN, LA EXPERIENCIA LE PERMITIÓ VER MÁS ALLÁ DE LAS APARIENCIAS Y TOMAR
DECISIONES INFORMADAS. LA PERCEPCION DEL LIDER: LA HISTORIA DESTACA LA IMPORTANCIA DE QUE
UN LIDER SEA CONSCIENTE DE LA REALIDAD Y NO SE DEJE LLEVAR SOLO POR LAS APARIENCIAS.
OLOFIN INICIALMENTE CREÍA EN LA DEVOCIÓN DE SUS SÚBDITOS, PERO LA PRUEBA PRESENTADA POR
EJIOGBE CAMBIÓ SU PERCEPCIÓN. CONSECUENCIAS DE LA FALSEDAD: LA HISTORIA SUBRAYA LAS
CONSECUENCIAS NEGATIVAS DE LA FALSEDAD Y LA HIPOCRESÍA. LA REVELACIÓN DE LA VERDADERA
NATURALEZA DE LOS SÚBDITOS LLEVÓ A UNA PÉRDIDA DE CONFIANZA Y A LA CONFIRMACIÓN DE LAS
SOSPECHAS DE EJIOGBE. LA IMPORTANCIA DE LA INTEGRIDAD: LA INTEGRIDAD Y LA SINCERIDAD SON
CUALIDADES CRUCIALES EN LAS RELACIONES Y EN EL LIDERAZGO. LA HISTORIA MUESTRA CÓMO LA
FALTA DE ESTAS CUALIDADES PUEDE CONDUCIR A LA DESCONFIANZA Y A LA DESILUSIÓN.''',
  '77. OLOFIN SUBIÓ A OKE A LAS CUATRO DE LA MAÑANA.': '''PATAKI: TRES AWOSES DISTINTOS A TRAVÉS DE LAS MALAS ARTES, MANDARON A ORÚNMILA AL MUNDO
CON LA ORDEN DE ENGANAR A LOS PRIMEROS HIJOS QUE OLOFIN HABÍA MANDADO AL MUNDO. ORÚNMILA
CUMPLIÓ ORDEN Y COMENZÓ A PREDICAR LA DOCTRINA A LOS PRIMEROS HUOS DE OLOFIN, ESTOS CON
DIFERENTE O CON VERDADERA FE, SE ARRODILLARON DELANTE DE ORÚNMILA, Y TODO LOS DÍAS LE
HACÍAN TODOS LOS HONORES QUE PRECISABAN. ORÚNMILA EN SU PRÉDICA LES DECÍA, QUE UN DÍA LE
VERÍAN LLEGAR O VENIR, PERO QUE PARA ELLO, PRIMERO TENDRIAN QUE CONSTRUIRLE UNA CASA, PARA
VERLO, Y ACTO SEGUIDO LES COMENZÓ A EXPLICAR QUE COSA ERA LA CASA. ASI LO HICIERON LOS
HOMBRES. ENTONCES ORÚNMILA SUBIÓ AL CIELO(AYIGUO) Y LE DIJO A OLOFIN, QUE SUS HIJOS NO LE
QUERÍAN VER NI CONOCER. OLOFIN LE DIJO A ORÚNMILA, PADRE ETERNO SI QUIERE BAJAR, TIENE QUE
HACER EBÓ CON: MANTECA DE CACAO, CASCARILLA, 8 AGUJAS, JUTÍA Y PESCADO AHUMADO, GALLO PARA
ESHUELEGBA Y QUE LO LLEVARA A 4 CAMINOS. ASI LO HIZO OLOFIN Y EN UN PUNTO ESTABA UN CIEGO
ESCONDIDO DENTRO DEL MONTE Y CUANDO OLOFIN ESTABA PONIENDO EL EBÓ, EL CIEGO SE HINCÓ UN
PIE, DONDE POR ESE MOTIVO EMPEZÓ A PEDIR AYUDA PARA QUE LE QUITARA LO QUE LE HACÍA DAÑO EN
EL PIE Y QUE DARÍA LO QUE LE PIDIERAN. OLOFIN ACUDIÓ A LA LLAMADA Y EL CIEGO LE CONTÓ QUE
SE HABÍA ENTERRADO UNA ESPINA EN UN PIE, OLOFIN LE SACÓ LA ESPINA Y LE DIJO AL CIEGO: "YO
NECESITO SABER DE MIS HIJOS" Y EL CIEGO LE PREGUNTÓ, QUE EN QUE SITIO ESTABA PARADO,
OLOFIN LE RESPONDIÓ QUE EN LOS 4 CAMINOS O 4 PUNTOS. ENTONCES EL CIEGO LE DIJO, QUE
SUBIERA ENCIMA DE OKE Y MIRARA PARA EL OTRO LADO, OLOFIN SUBIÓ A LAS 4 DE LA MAÑANA Y
CUANDO AMANECIÓ SE DIO CUENTA DE QUE LOS HOMBRES LE HABIAN CONSTRUIDO UNA CASA, PERO AL
VER QUE ESTOS NO PROFESABAN VERDADERA FÉ DECIDIÓ QUE VISITARÍA ESTA CASA CUANDO NADIE
ESTUVIERA PRESENTE PARA MANTENERSE OCULTO A LA VISTA DE TODOS. REZO: EMI TOBALE BOKUN
OGUGUBELE BUI GUI AKOOLA AKOLOKO KOMIKOKO QUE ADAFUN, IBETINE OMO AYALORUN AGUERE ELEBO
EYELE NI ORI, EFU ABERE EMYO AKUKO FIFESHU-ELEGBA EBEDILOGUN OWO. ENSEÑANZAS: ENGAÑO Y
MANIPULACIÓN: TRES AWOSES UTILIZARON ARTIMAÑAS PARA ENVIAR A ORÚNMILA AL MUNDO CON LA
ORDEN DE ENGAÑAR A LOS PRIMEROS HIJOS DE OLOFIN. ESTO DESTACA LA PRESENCIA DE LA
MANIPULACIÓN Y LA ASTUCIA EN LA HISTORIA. OBEDIENCIA: ORÚNMILA, A PESAR DE LA ORDEN
ENGAÑOSA, CUMPLIÓ LA TAREA DE PREDICAR LA DOCTRINA A LOS PRIMEROS HUOS DE OLOFIN. LA
OBEDIENCIA INICIAL DEMUESTRA LA LEALTAD Y EL DEBER HACIA LA TAREA ASIGNADA. FE Y
ADORACIÓN: LOS PRIMEROS HIJOS DE OLOFIN MOSTRARON DIFERENTES NIVELES DE FE AL ARRODILLARSE
Y RENDIR HONORES A ORÚNMILA. ESTO REFLEJA LA DIVERSIDAD EN LA RESPUESTA DE LAS PERSONAS A
LAS ENSEÑANZAS ESPIRITUALES. CONSTRUCCIÓN DE LA CASA COMO REQUISITO: ORÚNMILA INSTRUYE A
LOS HOMBRES A CONSTRUIRLE UNA CASA PARA PODER VERLO. ESTE ACTO SIMBOLIZA LA NECESIDAD DE
CREAR UN ESPACIO DEDICADO A LO DIVINO, Y CÓMO LAS ACCIONES DE LOS SEGUIDORES PUEDEN SER
PARTE INTEGRAL DE LA CONEXIÓN ESPIRITUAL. PRUEBA DE LEALTAD DE OLOFIN: OLOFIN, AL
ENTERARSE DE QUE SUS HIJOS NO QUERÍAN VERLO NI CONOCERLO, ESTABLECIÓ CONDICIONES PARA SU
DESCENSO. ESTO INCLUÍA UN EBÓ CON ELEMENTOS ESPECIFICOS, RESALTANDO LA IDEA DE QUE EL
ACCESO A LO DIVINO A MENUDO REQUIERE SACRIFICIOS Y ACTOS DE DEVOCIÓN. AYUDA INESPERADA DEL
CIEGO: LA PRESENCIA DEL CIEGO ESCONDIDO EN EL MONTE AGREGA UN ELEMENTO INESPERADO A LA
HISTORIA. SU INTERVENCIÓN ALIVIÓ EL DOLOR DE OLOFIN Y PROPORCIONÓ INFORMACIÓN VALIOSA,
MOSTRANDO CÓMO LA AYUDA PUEDE VENIR DE FUENTES INESPERADAS. IMPORTANCIA DE LA DIRECCIÓN
ESPIRITUAL: OLOFIN BUSCÓ LA AYUDA DE ORÚNMILA PARA CONOCER MÁS SOBRE SUS HIJOS. ESTO
DESTACA LA IMPORTANCIA DE LA ORIENTACIÓN ESPIRITUAL Y LA BÚSQUEDA DE CONOCIMIENTO MÁS ALLÁ
DE LO EVIDENTE. SACRIFICIO COMO REQUISITO PARA EL DESCENSO DIVINO: OLOFIN, SIGUIENDO LAS
INSTRUCCIONES DE ORÚNMILA, REALIZÓ UN EBÓ ANTES DE SU DESCENSO. ESTO SUBRAYA LA IDEA DE
QUE EL DESCENSO DE LO DIVINO A MENUDO ESTÁ ASOCIADO CON RITUALES Y SACRIFICIOS. EVALUACIÓN
DE LA FE DE LOS SEGUIDORES: OLOFIN, AL DARSE CUENTA DE QUE LOS HOMBRES HABIAN CONSTRUIDO
UNA CASA PERO NO PROFESABAN VERDADERA FE, DECIDE VISITAR LA CASA CUANDO NADIE ESTÉ
PRESENTE. ESTO SUGIERE LA IMPORTANCIA DE LA SINCERIDAD Y LA AUTENTICIDAD EN LA CONEXIÓN
ESPIRITUAL. LA HISTORIA OFRECE LECCIONES SOBRE LEALTAD, FE, SACRIFICIO Y LA NECESIDAD DE
UNA CONEXIÓN GENUINA CON LO DIVINO.''',
  '78. ADÁN Y EVA.': '''PATAKI: ADÁN Y EVA ERAN COMPAÑEROS Y SE LES ORDENÓ QUE HICIERAN EBÓ PARA QUE, CON LA
MULTIPLICACIÓN DE LOS HUMANOS AL NACER, NO SURGIERA LA GUERRA A CAUSA DE LA ENVIDIA Y LA
AMBICIÓN. EVA CUMPLIÓ CON LA ORDEN Y REALIZÓ SU EBÓ, PERO ADÁN NO LO HIZO. CUANDO EMPEZÓ A
CRECER LA POBLACIÓN HUMANA, SURGIÓ LA ENVIDIA Y LA AMBICIÓN, Y JUNTO CON ELLAS, NACIÓ LA
LUCHA ENTRE LOS SERES HUMANOS. CUANDO ADÁN FINALMENTE REGRESÓ A LA CASA DE ORÚNMILA, YA
ERA DEMASIADO TARDE PARA ÉL. DESDE ENTONCES, EL HOMBRE HA DERRAMADO SU SANGRE EN LA
GUERRA, MIENTRAS QUE LA MUJER MENSTRÚA MENSUALMENTE, SIN PARTICIPAR DIRECTAMENTE EN ESTOS
CONFLICTOS. ENSEÑANZAS: OBEDIENCIA A LAS INDICACIONES DIVINAS: LA HISTORIA DESTACA LA
IMPORTANCIA DE SEGUIR LAS INDICACIONES Y RITUALES DIVINOS, COMO EL EBÓ, COMO MEDIO PARA
PREVENIR CONFLICTOS Y GUERRAS EN LA HUMANIDAD. RESPONSABILIDAD COMPARTIDA: ADÁN Y EVA
REPRESENTAN TANTO AL HOMBRE COMO A LA MUJER, SUBRAYANDO LA RESPONSABILIDAD COMPARTIDA EN
PRESERVAR LA ARMONÍA Y PREVENIR LOS CONFLICTOS EN LA SOCIEDAD. CONSECUENCIAS DE LA
DESOBEDIENCIA: LA NEGATIVA DE ADÁN A REALIZAR EL EBÓ REPRESENTA LA DESOBEDIENCIA A LAS
INSTRUCCIONES DIVINAS Y CONLLEVA CONSECUENCIAS NEGATIVAS, COMO EL SURGIMIENTO DE LA
ENVIDIA, LA AMBICIÓN Y LAS GUERRAS ENTRE LOS SERES HUMANOS. CONTRASTE DE RESPUESTAS: LA
HISTORIA DESTACA CÓMO, ANTE LOS CONFLICTOS, LOS HOMBRES A MENUDO SE VEN INVOLUCRADOS EN LA
VIOLENCIA Y LA GUERRA, MIENTRAS QUE LAS MUJERES, SIMBOLIZADAS POR EVA, PASAN POR PROCESOS
NATURALES COMO LA MENSTRUACIÓN, MOSTRANDO UNA DIFERENCIA EN LAS RESPUESTAS ANTE LAS
TENSIONES. REFLEXIÓN SOBRE LAS DECISIONES TARDÍAS: LA SITUACIÓN DE ADÁN, QUE REGRESA A
ORÚNMILA DESPUÉS DE QUE YA ERA TARDE, REFLEJA LA IMPORTANCIA DE LA PRONTITUD Y LA
REFLEXIÓN EN LA TOMA DE DECISIONES, ASÍ COMO LAS CONSECUENCIAS DE NO ACTUAR A TIEMPO. EN
RESUMEN, LA HISTORIA PROPORCIONA LECCIONES SOBRE OBEDIENCIA A LO DIVINO, RESPONSABILIDAD
COMPARTIDA, CONSECUENCIAS DE LA DESOBEDIENCIA Y REFLEXIÓN SOBRE LAS DECISIONES,
CONTRIBUYENDO A LA COMPRENSIÓN DE CÓMO MANTENER LA PAZ Y LA ARMONÍA EN LA SOCIEDAD.''',
  '79. CUANDO ORÚNMILA NO TENÍA DONDE VIVIR.': '''PATAKI: ORÚNMILA, ENFRENTÁNDOSE A LA ADVERSIDAD DE NO TENER UN LUGAR DONDE RESIDIR,
EXPERIMENTÓ EL RECHAZO EN CADA INTENTO DE ESTABLECERSE. EN SU BÚSQUEDA DE UN NUEVO HOGAR,
SE ENCONTRÓ CON OSHÚN, Y JUNTOS SE ENCONTRARON PASEANDO POR LA ORILLA DEL MAR. MIENTRAS
ESTABAN ALLÍ, OSHÚN PRESENCIÓ UNA ESCENA CRÍTICA: UNA BALLENA AMENAZABA A UNOS MACAOS. SIN
VACILAR, OSHÚN UTILIZÓ SUS CINCO ADANES, ARROJÁNDOLOS VALIENTEMENTE HACIA LA BALLENA,
LOGRANDO ASÍ VENCERLA Y PONER FIN A LA AMENAZA. EN MUESTRA DE AGRADECIMIENTO, LOS MACAOS
LIBERARON SUS CARAPACHOS, LOS CUALES OFRECIERON GENEROSAMENTE A ORÚNMILA COMO SÍMBOLO DE
GRATITUD, PERMITIÉNDOLE ESTABLECERSE JUNTO A OSHÚN. EBO: DOS CARAPACHOS DE MACAOS CARGADOS
CON TIERRA DE LA CASA, ERU, OBI, KOLÁ, OBI MOTIWAO, ORO, PLATA, JUTIA, PESCADO AHUMADO,
MAIZ TOSTADO, NUMEROSAS HIERBAS Y ARENA. DESPUÉS DE CARGAR ESTOS ELEMENTOS, ESTOS RESIDEN
DE MANERA SIMBÓLICA DENTRO DEL IFÁ DEL AWÓ. COMO PARTE DEL PROCESO RITUAL, SE PREGUNTA:
¿DE QUÉ COLOR SE FORRAN ESTAS CUENTAS? ENSEÑANZAS: PERSEVERANCIA EN LA ADVERSIDAD:
ORÚNMILA, ENFRENTÁNDOSE AL RECHAZO Y LA FALTA DE UN LUGAR DONDE RESIDIR, DEMOSTRÓ
PERSEVERANCIA EN SUS CONTINUOS INTENTOS DE ESTABLECERSE. ALIANZAS SIGNIFICATIVAS: EN SU
BÚSQUEDA, SE ENCONTRÓ CON OSHÚN, LO QUE DESTACA LA IMPORTANCIA DE FORMAR ALIANZAS
SIGNIFICATIVAS EN MOMENTOS DE DIFICULTAD. VALENTIA ANTE LOS DESAFIOS: OSHUN, AL PRESENCIAR
LA AMENAZA DE LA BALLENA A LOS MACAOS, ACTUÓ CON VALENTÍA AL UTILIZAR SUS ADANES PARA
VENCER LA SITUACIÓN Y PONER FIN A LA AMENAZA. GRATITUD Y GENEROSIDAD: LOS MACAOS, EN
AGRADECIMIENTO POR HABER SIDO SALVADOS, DEMOSTRARON GRATITUD Y GENEROSIDAD AL OFRECER SUS
CARAPACHOS A ORÚNMILA COMO MUESTRA DE AGRADECIMIENTO. LA IMPORTANCIA DE LA AYUDA MUTUA: LA
COLABORACIÓN ENTRE ORÚNMILA Y OSHÚN, ASÍ COMO LA RESPUESTA POSITIVA DE LOS MACAOS, RESALTA
LA IMPORTANCIA DE LA AYUDA MUTUA Y LA SOLIDARIDAD EN TIEMPOS DIFÍCILES.''',
  '80. COMO ATANDÁ GANÓ SU LIBERTAD.': '''PATAKI: ATANDÁ FUE EL PRIMER ESCLAVO AWÓ CON EL ODU DE EJÍOGBÉ QUE LLEGÓ A CUBA. GRACIAS A
SU INTELIGENCIA Y HABILIDAD, SE CONVIRTIÓ EN EL PRIMER ESCLAVO AL QUE LE OTORGARON LA
LIBERTAD. UNO DE LOS TERRATENIENTES MÁS ADINERADOS DE LA REGIÓN CONOCIÓ A ATANDÁ, LO
COMPRÓ Y LO LLEVÓ A SU HACIENDA. ALLÍ, LE QUITÓ LAS CADENAS Y LO DESIGNÓ PARA ABRIR Y
CERRAR LA PUERTA DE LA MANSIÓN. EN UNA OCASIÓN, SE LLEVÓ A CABO UNA GRAN RECEPCIÓN A LA
QUE ASISTIERON LOS TERRATENIENTES MÁS RICOS DE LA REGIÓN. ATANDÁ FUE EL ENCARGADO DE
SERVIRLES EN LA MESA, Y SU COMPOSTURA CAUSÓ TANTO ASOMBRO ENTRE LOS HACENDADOS QUE FUE LA
ADMIRACIÓN DE TODOS. EL DUEÑO DE LA HACIENDA, FRENTE A TODOS LOS PRESENTES, ENTREGÓ A
ATANDÁ EL SALVOCONDUCTO, DONDE FIRMABA LA LIBERTAD DEL ESCLAVO Y DE TODOS LOS SUYOS. LE
INDICÓ A ATANDÁ QUE SI LEÍA ESE SALVOCONDUCTO, OBTENDRÍA LA LIBERTAD. COMO ATANDÁ NO
CONOCÍA LA LENGUA CASTELLANA, SE LE OCURRIÓ REALIZAR UN ÓKPUELE CON 8 CÁSCARAS DE NARANJA,
QUE TAMBIÉN HABÍAN SIDO SERVIDAS EN LA MESA. DE ESTA MANERA, ATANDÁ LE HIZO SABER AL
TERRATENIENTE QUE ÉL PODÍA LEERLE EL PRESENTE, PASADO Y FUTURO A TODOS LOS PRESENTES.
REALIZÓ ESTA HAZAÑA CON GRAN SABIDURÍA, DEJANDO ASOMBRADOS A TODOS. LLEGARON A LA
CONCLUSIÓN Y ACUERDO MUTUO DE QUE DEBIDO A SU SABIDURÍA, ERA APROPIADO ENTREGARLE EL
SALVOCONDUCTO DE SU LIBERTAD. ASÍ, ATANDÁ QUEDÓ AL FRENTE DE LA FINCA Y DE TODA LA
SERVIDUMBRE. ENSEÑANZAS: INTELIGENCIA Y HABILIDAD COMO CAMINO A LA LIBERTAD: LA HISTORIA
DE ATANDÁ DESTACA COMO SU INTELIGENCIA Y HABILIDAD FUERON LOS IMPULSORES CLAVE QUE LO
LLEVARON A CONVERTIRSE EN EL PRIMER AWO ESCLAVO AL QUE LE OTORGARON LA LIBERTAD. ESTO
RESALTA LA IMPORTANCIA DE LAS CUALIDADES INDIVIDUALES PARA SUPERAR LA ADVERSIDAD.
OPORTUNIDADES EN MEDIO DE LA ADVERSIDAD: A PESAR DE SU CONDICIÓN INICIAL COMO ESCLAVO,
ATANDÁ TUVO LA OPORTUNIDAD DE DEMOSTRAR SU VALÍA CUANDO FUE COMPRADO POR UNO DE LOS
TERRATENIENTES MÁS RICOS DE LA REGIÓN. ESTE HECHO RESALTA CÓMO LAS OPORTUNIDADES PUEDEN
SURGIR INCLUSO EN SITUACIONES DIFÍCILES. LA IMPORTANCIA DE LA COMPOSTURA Y LA ADMIRACIÓN:
LA COMPOSTURA DE ATANDÁ DURANTE LA RECEPCIÓN, QUE CAUSÓ ASOMBRO ENTRE LOS HACENDADOS,
SUBRAYA LA IMPORTANCIA DE LA CONDUCTA Y CÓMO PUEDE GENERAR ADMIRACIÓN Y RESPETO, INCLUSO
EN CIRCUNSTANCIAS DESAFIANTES. SIMBOLISMO DEL ÓKPUELE: EL USO DEL ÓKPUELE CON 8 CÁSCARAS
DE NARANJA, QUE ATANDÁ UTILIZÓ PARA COMUNICARSE SIN CONOCER LA LENGUA CASTELLANA, MUESTRA
LA IMPORTANCIA DE LA CREATIVIDAD Y LA ADAPTABILIDAD PARA SUPERAR BARRERAS LINGÜÍSTICAS Y
DE COMUNICACIÓN. SABIDURÍA COMO CAMINO HACIA LA LIBERTAD: LA ACTUACIÓN SABIA DE ATANDÁ, AL
HACERLE SABER AL TERRATENIENTE QUE PODÍA LEER EL PRESENTE, PASADO Y FUTURO, DESTACA CÓMO
LA SABIDURÍA PUEDE SER UN INSTRUMENTO PODEROSO PARA OBTENER LA LIBERTAD Y EL RESPETO.
LIDERAZGO DE ATANDÁ: AL QUEDAR AL FRENTE DE LA FINCA Y TODA LA SERVIDUMBRE, ATANDÁ SE
CONVIERTE EN UN LÍDER, DEMOSTRANDO QUE LAS CUALIDADES INDIVIDUALES PUEDEN ABRIR CAMINO
HACIA ROLES DE LIDERAZGO, INCLUSO EN CIRCUNSTANCIAS INICIALES DESFAVORABLES. LA HISTORIA
DE ATANDÁ NOS DEJA VALIOSAS LECCIONES SOBRE LA IMPORTANCIA DE LA INTELIGENCIA, LA
SABIDURÍA Y LA CONDUCTA EN LA BÚSQUEDA DE LA LIBERTAD Y EL RECONOCIMIENTO EN SITUACIONES
DESAFIANTES.''',
  '81. ALGUIEN DIJO: MIS OJOS SON BUENOS. OTRO DIJO: MI CABEZA ES BUENA.': '''BUENA. PATAKI: CUANDO OJO Y CABEZA VINIERON AL MUNDO, OJO ERA EL MAYOR Y CABEZA EL MENOR.
UN DÍA SU PADRE, EL CREADOR DE TODAS LAS COSAS, LLENO UNA CALABAZA DE CARNE DE CARNERO Y
DE PASTA ROJA HECHA CON EL ACEITE DE PALMA(EPÓ) Y LA ENVOLVIÓ EN UNA PRECIOSA TELA DE
SEDA. LA SEGUNDA CALABAZA LA LLENO DE ORO, DINERO, Y ALGUNAS PERLAS PRECIOSAS. ENTONCES LA
CUBRIÓ CON ARENA Y DESPUÉS CON TRAPOS SUCIOS. ENTONCES INVITÓ A SUS DOS HIJOS, PARA QUE
ESCOGIERAN UNA CALABAZA CADA UNO A SU VOLUNTAD. OJO ESCOGIÓ LA CALABAZA RODEADA CON LA
BELLA SEDA Y CABEZA PREFIRIÓ LA OTRA. OJO ABRIÓ LA CALABAZA Y ENCONTRÓ LA CARNE Y LA PASTA
E INVITO A SUS AMIGOS A COMER JUNTOS. CABEZA DESEMPAQUETÓ SU CALABAZA, Y, DESPUÉS DE
ABIERTA, ENCONTRÓ ARENA. ¿CÓMO PAPÁ PUDO PONERME ARENA EN ESTA CALABAZA? ¿NO PUSO NADA DE
COMIDA QUE PUEDA COMER?. ¿QUE LE DARÍA A MI HERMANO? ¿ESTE ES EL TRATO QUE ME DA MI PADRE?
¡SIN EMBARGO DEBE HABER ALGO BUENO! ¡NO OBSTANTE VOY A GUARDARLA! Y LA LLEVÓ LEJOS CON
ESMERO A SU CASA. UNA VEZ EN LA CASA, CABEZA INTRIGADO, SÉ PREGUNTÓ SI LA CALABAZA
SOLAMENTE CONTENÍA ARENA, LA ABRIÓ DE NUEVO, Y ENCONTRÓ BAJO LA ARENA EL DINERO; ENTONCES
EL ORO BAJO EL DINERO; Y BAJO EL ORO ALGUNAS PERLAS PRECIOSAS. Y DIJO: -¡MI CALABAZA VALE
INFINITAMENTE MÁS QUE LA DE MI HERMANO! Y CABEZA SE VOLVIÓ RICO. ALGÚN TIEMPO DESPUÉS EL
CREADOR, LLAMÓ A SUS NIÑOS A PREGUNTARLES: -¡EH, PUES! ¿QUÉ HAN ENCONTRADO EN SUS
CALABAZAS? OJO CONTESTÓ: - YO, EL MAYOR, ENCONTRÉ LA CARNE DE CARNERO Y LA PASTA DE EPÓ.
RESPONDIÓ CABEZA: - EN MI CALABAZA, HAY TODO LO QUE REPRESENTA LA RIQUEZA. ENTONCES SU
PADRE DIJO: - OJO, ERES DEMASIADO ÁVIDO. LA VISTA DE LA BELLEZA TE ATRAJO, Y QUERÍAS
TENERLA. CABEZA, QUE REFLEXIONO, SUPO QUE LA CALABAZA ESTABA RODEADA DE TRAPOS, PERO QUE
EN EL INTERIOR ESTABA ESCONDIDA UNA RIQUEZA. CABEZA, DE AQUÍ EN ADELANTE SERÁ EL MAYOR, Y
TU OJO SERÁS SU SEGUNDO. DE AQUÍ EN ADELANTE LA CABEZA SÉ NOMBRARÁ PRIMERO. DESDE
ENTONCES, CUANDO UNO TIENE SUERTE, SÉ DICE: MI CABEZA ES BUENA Y NUNCA SE DICE: MIS OJOS
SON BUENOS. CANCIÓN: TA-CE DOKPO WE NO WA NU, BO TA YI VO. OLI GBO GE, GBO GE, GBO GE! OI
EE! OLI TA DOKPO, O GBO GE, GBO GE, GBO GE! TRADUCCIÓN TENGO UNA SOLO CABEZA QUE PIENSA, Y
VINIERON DIEZ CABEZAS MÁS. MI CABEZA ES FUERTE Y PENSANTE, ¡OH! CABEZA. TENGO UNA SOLA
CABEZA, ¡PERO FUERTE Y PENSANTE! ENSEÑANZAS: EVALUACIÓN MÁS ALLÁ DE LAS APARIENCIAS: LA
HISTORIA DESTACA QUE LA ELECCIÓN DE OJO, BASADA ÚNICAMENTE EN LA BELLEZA EXTERNA DE LA
CALABAZA ENVUELTA EN SEDA, LLEVÓ A UNA ELECCIÓN SUPERFICIAL. EN CONTRASTE, LA CABEZA, A
PESAR DE LA APARIENCIA EXTERNA DESCUIDADA DE SU CALABAZA, DESCUBRIÓ UNA RIQUEZA OCULTA AL
TOMARSE EL TIEMPO DE EXPLORAR MÁS ALLÁ DE LO EVIDENTE. REFLEXIÓN Y PACIENCIA:LA CABEZA
DEMOSTRÓ PACIENCIA Y REFLEXIÓN AL CUESTIONAR LA ELECCIÓN DE SU PADRE Y, EN LUGAR DE
RECHAZAR DE INMEDIATO LA CALABAZA QUE PARECIA CONTENER SOLO ARENA, DECIDIÓ EXAMINARLA MÁS
A FONDO. ESTA REFLEXIÓN LE PERMITIÓ DESCUBRIR LA VERDADERA RIQUEZA QUE YACÍA OCULTA.
VALORACIÓN DE LA SABIDURÍA SOBRE LA APARIENCIA: LA NARRATIVA SUGIERE QUE LA SABIDURÍA DE
CABEZA SUPERÓ LA APARENTE BELLEZA SUPERFICIAL QUE ATRAJO A OJO. ESTA VALORACIÓN DE LA
INTELIGENCIA SOBRE LA APARIENCIA EXTERNA LLEVÓ A CABEZA A OBTENER BENEFICIOS SUSTANCIALES
Y A SER RECONOCIDO COMO EL MAYOR. LECCIONES SOBRE LA AVARICIA: LA ADVERTENCIA DEL CREADOR
SOBRE LA AVARICIA, RESALTADA CUANDO LE REPROCHA A OJO POR SU CODICIA Y ATRACCIÓN HACIA LA
BELLEZA, SIRVE COMO UNA LECCIÓN SOBRE LOS PELIGROS DE DEJARSE LLEVAR POR DESEOS
SUPERFICIALES Y LA IMPORTANCIA DE LA MODERACIÓN. INVERSIONES ESTRATÉGICAS Y RECOMPENSAS:
LA HISTORIA SUBRAYA QUE, A VECES, LAS INVERSIONES QUE NO PARECEN VALIOSAS A PRIMERA VISTA
PUEDEN LLEVAR A RECOMPENSAS SIGNIFICATIVAS. LA ELECCIÓN ESTRATÉGICA DE CABEZA AL
SELECCIONAR LA CALABAZA MENOS ATRACTIVA RESULTÓ EN UNA RIQUEZA SORPRENDENTE.''',
  '82. LA DOBLE SALVACIÓN.': '''PATAKI: EJIOGBE TENÍA UNA MUJER QUE LE DIO A LUZ A DOS GEMELOS EN SU PRIMERA MATERNIDAD.
DOS MESES DESPUÉS DE ESTE NACIMIENTO, LA MADRE TUVO RELACIONES CON OTRO HOMBRE QUE DESEABA
TOMAR TODO LO POSIBLE Y QUEDARSE CON ELLA. SIGUIENDO EL CONSEJO DE SU SEDUCTOR, DECIDIÓ
PONER VENENO QUE PODRÍA MATAR A SU MARIDO Y LO COLOCÓ EN SU COMIDA. AL DÍA SIGUIENTE, ELLA
PREPARÓ LA COMIDA. AL MOMENTO DE COLOCAR LA SALSA ENVENENADA, LE DIJO AL MARIDO QUE FUERA
AL CAMPO. ELLA HIZO DOS PORCIONES, VERTIÉNDOLAS EN DOS RECIPIENTES DIFERENTES DE SALSA. EN
EL PRIMER RECIPIENTE, ESTABA EL VENENO DESTINADO AL MARIDO Y RESERVÓ EL SEGUNDO PARA ELLA
SIN VENENO Y LO ASEGURÓ EN OTRO LUGAR. CUANDO EL MARIDO REGRESÓ Y DUO QUE TENÍA HAMBRE,
ELLA LE INDICÓ EL LUGAR DONDE ESTABA EL RECIPIENTE CON LA SALSA ENVENENADA (AKASSA).
RESULTA QUE EN EL MOMENTO EN QUE ELLA ENVENENÓ LA SALSA, ZISU, EL MAYOR DE LOS GEMELOS, SE
DIO CUENTA DEL HECHO. LA MUJER SALIÓ AFUERA Y EL MARIDO ENTRÓ A TOMAR EL RECIPIENTE. ZISU
ENTONCES SE PARÓ Y LE DIJO A SU PADRE: "LA SALSA HA SIDO ENVENENADA POR MI MADRE", Y
AGREGÓ QUE ESTABA OBLIGADO A DENUNCIAR EL HECHO, DE MANERA QUE NADIE DIJERA EN EL PAÍS
QUE, POR CULPA DE ÉL, LA DESGRACIA HABÍA ENTRADO EN SU FAMILIA. INDICÓ ENTONCES A SU PADRE
CUÁL ERA LA SALSA COMESTIBLE, Y EL PADRE CAMBIÓ LOS DOS RECIPIENTES. EN EL MOMENTO DEL
CAMBIO, EL SEGUNDO NIÑO, LLAMADO SAGBO, SE DIO CUENTA DEL HECHO. EN ESE MOMENTO, LA MADRE
VOLVIÓ DEL JARDÍN Y ENTRÓ A COMER. SAGBO, EL SEGUNDO GEMELO, SE PARÓ Y DIJO LO QUE ESTABA
PASANDO. LA MUJER LLAMÓ A TODO EL MUNDO Y GRITÓ: "¡MI MARIDO QUIERE ENVENENARME! LOS
VECINOS SE REUNIERON Y LA MUJER CONTÓ TODO LO QUE PASABA. EL CASO LLEGÓ ANTE OLOFIN. EL
MARIDO ESTABA EMPLAZADO. EL OBÁ LE PREGUNTÓ SOBRE LOS HECHOS QUE SU ESPOSA DECÍA Y LE
ORDENÓ QUE TRAJERA A SUS NIÑOS, AUNQUE SOLO TENIAN DOS MESES DE EDAD, PARA COMPARECER ANTE
EL PALACIO Y HACER JUSTICIA. OLOFIN ORDENÓ QUE SUBIERAN LOS NINOS Y QUE RESPONDIERAN LAS
PREGUNTAS. ZISU FUE INTERROGADO PRIMERO Y DIJO QUE SU MADRE LE HABÍA PUESTO LA SALSA
ENVENENADA A SU PADRE. SIN EMBARGO, CONSIDERÓ SU PROPIO NACIMIENTO Y EL DE SU HERMANO, Y
PENSÓ QUE NO LE GUSTARÍA UNA DESGRACIA EN LA CASA. DIJO QUE SI SU VIEJO PADRE MORÍA CUANDO
APENAS ELLOS TENÍAN DOS MESES, SERÍA UNA GRAN PENA. ESTA FUE LA RAZÓN QUE LO LLEVÓ A
CONTARLE EL HECHO A SU PADRE. EL SEGUNDO NIÑO DECLARÓ QUE SU PADRE HABÍA CAMBIADO LA
COMIDA DE SU MADRE Y LE HABIA PUESTO UN RECIPIENTE ENVENENADO A SU MADRE CON LA INTENCIÓN
DE MATAR A SU ESPOSA Y QUE SI POR CASUALIDAD SU MADRE HUBIERA MUERTO, ALGUIEN HABRÍA DICHO
QUE SU NACIMIENTO LLEVÓ LA DESGRACIA A LA CASA. OLOFIN LE DIJO AL PADRE DE LOS GEMELOS QUE
ESTOS ESTABAN PROHIBIDOS POR DOS PUEBLOS Y QUE SE LLAMARÍAN DE AHORA EN ADELANTE: OBEJI.
NOTA: SI EL CONSULTADO ES VÍCTIMA DE CUALQUIER TRAMPA, TENDRÁ TIEMPO PARA DESBARATARLA.
REFRÁN: "GBETO WE WELE WE GA: DOS PERSONAS TOMAN SU DEFENSA". ENSEÑANZAS: LA TRAICIÓN Y LA
CODICIA: LA HISTORIA COMIENZA CON LA TRAICIÓN DE LA MUJER DE EJIOGBE, QUIEN, MOTIVADA POR
LA CODICIA Y EL DESEO DE QUEDARSE CON OTRO HOMBRE, DECIDE ENVENENAR A SU ESPOSO. ESTA
ACCIÓN MUESTRA CÓMO LA AVARICIA Y LA TRAICIÓN PUEDEN SURGIR INCLUSO EN RELACIONES
APARENTEMENTE SÓLIDAS. LA VIGILANCIA Y LA INTERVENCIÓN DIVINA: A TRAVÉS DE LOS GEMELOS,
ZISU Y SAGBO, SE DESTACA LA IMPORTANCIA DE LA VIGILANCIA Y LA INTERVENCIÓN DIVINA EN
MOMENTOS CRÍTICOS. ZISU SE DA CUENTA DEL INTENTO DE ENVENENAMIENTO Y TOMA LA VALIENTE
DECISIÓN DE DENUNCIARLO, EVITANDO ASÍ UNA TRAGEDIA EN LA FAMILIA. LA HISTORIA SUGIERE QUE,
A VECES, LAS FUERZAS SUPERIORES PUEDEN INTERVENIR PARA PREVENIR EL MAL. LA IMPORTANCIA DE
LA VERDAD: ZISU, AL REVELAR LA VERDAD SOBRE EL ENVENENAMIENTO, DEMUESTRA EL VALOR DE LA
HONESTIDAD Y LA TRANSPARENCIA, INCLUSO CUANDO ENFRENTA DILEMAS DIFÍCILES. LA VERDAD SE
CONVIERTE EN UN ELEMENTO CRUCIAL PARA DESENTRAÑAR LA TRAMA Y PERMITIR QUE SE HAGA
JUSTICIA. LA JUSTICIA DIVINA: LA HISTORIA DESTACA CÓMO EL CASO LLEGA ANTE OLOFIN, UN LÍDER
ESPIRITUAL, PARA BUSCAR JUSTICIA. ESTE ASPECTO REFLEJA LA CREENCIA EN LA JUSTICIA DIVINA Y
CÓMO LAS ACCIONES DE LAS PERSONAS EVENTUALMENTE SON JUZGADAS POR FUERZAS SUPERIORES. LAS
CONSECUENCIAS DE LA MALDAD: EL HECHO DE QUE LOS GEMELOS SEAN LLAMADOS OBEJI (PROHIBIDOS
POR DOS PUEBLOS) SUGIERE QUE LA MALDAD Y LA TRAICIÓN TIENEN CONSECUENCIAS QUE TRASCIENDEN
A LA FAMILIA INMEDIATA. LA SOCIEDAD REACCIONA IMPONIENDO UNA RESTRICCIÓN A LOS GEMELOS,
SIMBOLIZANDO LA REPULSA HACIA LA MALDAD. EL REFRÁN COMO LECCIÓN FINAL: EL REFRÁN "GBETO WE
WELE WE GA: DOS PERSONAS TOMAN SU DEFENSA" ENFATIZA LA IMPORTANCIA DE LA SOLIDARIDAD Y EL
APOYO MUTUO. PUEDE INTERPRETARSE COMO UNA LECCIÓN SOBRE CÓMO, AL UNIRSE Y DEFENDER LA
VERDAD, SE PUEDE SUPERAR LA ADVERSIDAD. EN CONJUNTO, LA HISTORIA RESALTA LA COMPLEJIDAD DE
LAS RELACIONES HUMANAS, LA IMPORTANCIA DE LA VERDAD Y LA JUSTICIA, ASÍ COMO LAS
CONSECUENCIAS DE LA MALDAD EN EL TEJIDO SOCIAL.''',
  '83. EL ASHINIMÁ.': '''PATAKI: OBATALÁ, EN UN DÍA DETERMINADO, EMITIÓ LA ORDEN DE QUE LA MUERTE TRAJERA LAS
CABEZAS DE TODAS LAS PERSONAS CUYA PIEL FUERA ROJA. ANTE ESTA AMENAZA, IFA, CON EL
OBJETIVO DE EVITAR ESTA DESGRACIA PARA SUS SERES QUERIDOS Y TODA SU FAMILIA, DECIDIÓ
REALIZAR UNA CONSULTA. EN ESTE CONTEXTO, EJIOGBE OSOBO IKÚ EMERGIÓ COMO RESULTADO DE LA
ADIVINACIÓN, Y SE RECOMENDÓ LLEVAR A CABO UN SACRIFICIO COMPUESTO POR DAGBLA HOZA
(GRANADA), TIERRA CON AGUA, DOS CHIVOS, DOS GALLINAS, DOS PALOMAS Y DOS PEDAZOS DE TELA.
ADEMÁS, TODA LA FAMILIA DE IFA SE PURIFICÓ UTILIZANDO EL AGUA DE ASHINIMÁ. AL DÍA
SIGUIENTE, LA MUERTE SE PRESENTÓ ANTE ELLOS, PERO PARA SORPRESA DE TODOS, ESTABAN
COMPLETAMENTE NEGROS. FUE DE ESTA MANERA QUE LA FAMILIA DE IFA LOGRÓ ESCAPAR DE LA MATANZA
DE IKU, ORDENADA POR OBATALÁ. NOTA: EN UNA OCASIÓN, IFA ERA UN PERSONAJE DE COLOR ROJO, LO
QUE AÑADE UN MATIZ INTRIGANTE A ESTA HISTORIA LLENA DE ELEMENTOS SIMBÓLICOS Y RITUALES.
ENSENANZAS: PREVISIÓN Y CONSULTA• ANTE LA AMENAZA DE OBATALÁ DE LLEVARSE LAS CABEZAS DE
AQUELLOS CON PIEL ROJA, IFA MUESTRA LA IMPORTANCIA DE LA PREVISIÓN Y LA CONSULTA PARA
EVITAR DESGRACIAS. LA BÚSQUEDA DE ORIENTACIÓN Y LA TOMA DE MEDIDAS PREVENTIVAS SON
ESENCIALES PARA SALVAGUARDAR A LA FAMILIA Y SERES QUERIDOS. SACRIFICIO Y PURIFICACIÓN: LA
HISTORIA DESTACA LA NECESIDAD DE SACRIFICIOS Y PURIFICACIONES COMO MEDIO PARA
CONTRARRESTAR FUERZAS NEGATIVAS. EL RITUAL COMPUESTO POR DAGBLA HOZA, TIERRA CON AGUA,
CHIVOS, GALLINAS, PALOMAS Y AGUA DE ASHINIMÁ ILUSTRA LA IMPORTANCIA DE LOS ACTOS
SIMBÓLICOS PARA CONTRARRESTAR LAS AMENAZAS ESPIRITUALES. RESULTADO INESPERADO: A PESAR DE
LAS APARENTES AMENAZAS DE LA MUERTE, LA FAMILIA DE IFA LOGRA UN RESULTADO INESPERADO AL
PRESENTARSE COMPLETAMENTE NEGROS AL DIA SIGUIENTE. ESTO SUBRAYA LA IMPREVISIBILIDAD DE LAS
SOLUCIONES DIVINAS Y CÓMO LAS ACCIONES CORRECTAS PUEDEN CONDUCIR A RESULTADOS
SORPRENDENTES. SIMBOLISMO DE COLOR: LA TRANSFORMACIÓN DE IFA DE UN PERSONAJE DE COLOR ROJO
A NEGRO AGREGA UN MATIZ INTRIGANTE. EL CAMBIO DE COLOR PUEDE INTERPRETARSE COMO UNA
METAMORFOSIS ESPIRITUAL, SUBRAYANDO LA NATURALEZA DINÁMICA Y CAMBIANTE DE LAS FUERZAS
ESPIRITUALES. PROTECCIÓN DIVINA: LA HISTORIA SUGIERE QUE, A TRAVÉS DE LA CONSULTA Y LA
ACCIÓN CORRECTA, SE PUEDE OBTENER PROTECCIÓN DIVINA INCLUSO EN SITUACIONES POTENCIALMENTE
MORTALES. LA INTERVENCIÓN DE IFA Y LA PRESENTACIÓN DE LA FAMILIA COMO NEGRA REVELAN LA
INFLUENCIA POSITIVA DE LAS FUERZAS ESPIRITUALES. EN CONJUNTO, LA NARRATIVA RESALTA LA
IMPORTANCIA DE LA SABIDURÍA, LOS RITUALES Y LA CONEXIÓN CON LO DIVINO PARA SUPERAR LAS
ADVERSIDADES Y PROTEGERSE CONTRA AMENAZAS ESPIRITUALES.''',
  '84. UNA COSA PEQUEÑA PODRÁ HACERSE MUY GRANDE.': '''NU MASO ATE NA DO YA NU ME FUE EL AWO QUE ADIVINÓ PARA TITIGOTI, EL PÁJARO PEQUEÑO
HABLADOR CON LAS PLUMAS GRISES, EL CUAL DECLARÓ UN DÍA A AJINAKU EL ELEFANTE QUE LO
DERROTARÍA EN UN COMBATE SINGULAR. ¿AJINAKU SE ASOMBRA: - ¿QUE? ¿TAN PEQUENO COMO ERES?
¡NADA PUEDES CONTRA MI! ¡SI! DIJO TITIGOTI AL ELEFANTE QUE LE PEGARÉ Y LO DERROTARÉ. PERO
AJINAKU COMENZÓ REÍRSE, Y SÉ NEGÓ A IR A COMBATE. TITIGOTI FUE POR UNAS PIEDRAS ROJASIZE],
LAS PULVERIZO CON AGUA E HIZO UNA CREMA QUE SÉ APRECIA A SANGRE. VERTIÓ ESTE PRODUCTO EN
RECIPIENTE (CALABAZA PEQUEÑA EN FORMA DE BOTELLA ATAKUGWE). CON CASCARILLA(EFUN) MEZCLADA
EN AGUA, HIZO UNA PASTA QUE VERTIÓ EN OTRA BOTELLA PEQUEÑA. FINALMENTE, AMASÓ CARBÓN EN
AGUA, Y VERTIÓ EL OSCURO LÍQUIDO EN UNA TERCERA BOTELLA PEQUEÑA. EL OBA DE PAÍS SÉ LLAMABA
ODUDUWA. ODUDUWA, SE ACOMPAÑÓ DE TODOS LOS ANIMALES DEL BOSQUE, A VER CÓMO TITIGOTI
PELEARÍA CON AJINAKU. YEL PÁJARO PEQUEÑO GRIS DESAFÍO A AJINAKU Y LE DUO: - ESTOY BIEN.
¡VAMOS A COMBATIR! Y TITIGOTI, CON SUS TRES BOTELLAS PEQUEÑAS, SÉ SUBIÓ EN LA CABEZA DEL
ELEFANTE, QUE COMENZÓ REÍR Y ESTE LANZÓ SUS COLMILLOS PARA COGERLO. PERO TITIGOTI HIZO
PIRUETAS ABRUPTAS Y EL ELEFANTE NO PODÍA ENCONTRARLO; Y TITIGOTI SÉ ESCONDIÓ EN LA OREJA
DE AJINAKU, QUE LE HIZO COSQUILLAS. PERO SÉ POSO TAMBIÉN EL PÁJARO EN SUS OJOS. ENTONCES
AJINAKU SÉ VOLVIÓ NERVIOSO YA QUE NO PODÍA AGARRAR AL PÁJARO. TITIGOTI RÁPIDAMENTE, VERTIÓ
EL LIQUIDO ROJO EN LA CIMA DE CABEZA. Y VOLÓ HACIA ODUDUWA, Y LE PIDIÓ ENVIAR A UN MÉDICO
PARA QUE EXAMINARA A AJINAKU, Y ESTE DIJO: TIENE UNA LESIÓN SANGRIENTA EN LA CABEZA.
AJINAKU COMENZÓ REÍRSE. ¡ODUDUWA LE PREGUNTÓ QUE SÉ ACERCARA, Y ESTE VIO LA SANGRE: -
¡ESTÁS AVERGONZADO! ¿CÓMO USTED PERMITIÓ ESTAR EN UN ESTADO TAL POR UN PÁJARO TAN PEQUEÑO?
AJINAKU LLORÓ, PORQUE NO SENTIA NINGÚN DOLOR ¡ERA FALSO! Y TOCÓ SU CABEZA CON SU TROMPA
QUE SÉ MANCHO TODA DE ROJO. ENTONCES EL ENOJO TOMA A AJINAKU. Y DECIDIÓ MATAR A TITIGOTI Y
ESTE HACÍA ACROBACIA EN LA CABEZA DEL ELEFANTE. - ¡DÉJAME ALCANZARTE! ODUDUWA LE MIRÓ LA
CARA: - ¡QUE VERGUENZA! Y TODOS LOS ANIMALES MIRABAN. TITIGOTI EXCLAMÓ SÚBITO: ⁃ AJINAKU,
SI NO PONES ATENCIÓN AHORA, TE VOY A ROMPER LA CABEZA Y TU CEREBRO SALDRÁ. ⁃ ¡NUNCA! DIJO
AJINAKU. Y REDOBLO LA LUCHA. EN ESE MOMENTO, TITIGOTI VERTIÓ LA CALABAZA DE AGUA
BLANQUECINA EN LA CABEZA DE AJINAKU, Y ODUDUWA LO MIRO, AJINAKU QUERÍA CONTINUAR LA LUCHA
NO OBSTANTE, ENVIARON QUE ALGUIEN VIERA SU CABEZA Y LA PERSONA DECLARÓ: - EL CEREBRO ESTA
FUERA. Y ODUDUWA LLAMO A AJINAKU Y VIO LA PASTA BLANCA EN SU CABEZA, Y AJINAKU, PASO SU
TROMPA POR SU CABEZA, Y VINO MANCHADA DE BLANCO. Y ENTRO EN FURIA Y PROTESTO QUE NO TENIA
NINGÚN DOLOR. EN SU EXCITACIÓN SÉ NEGÓ A PERMITIR QUE TITIGOTI VOLVIERA A SU HOGAR; JURÓ
MATARLO YA. TITIGOTI LE DIJO: - CUANDO QUIERA. Y DIJO: -ES SÓLO UN NIÑO, NO ES BUENO
CUANDO PIENSA. AJINAKU TOMO LA LUCHA, SIN SER HÁBIL PARA ALCANZAR AL RÁPIDO PÁJARO QUE
VUELVE OTRA VEZ A SU CABEZA. DESPUÉS DE UN MOMENTO TITIGOTI DECIDIÓ VERTER EL NEGRO
LIQUIDO EN LA FRENTE DEL ELEFANTE. ENTONCES FUE A VERLO ODUDUWA, Y DIJO: YA ESTA BUENO. NO
PUEDE CONTINUAR ASÍ, Y TITIGOTI DUJO: NO LUCHO CON UNA PERSONA AGONIZANTE. Y TODOS VIERON
EL LÍQUIDO OSCURO Y PASTOSO QUE CAÍA DE LA FRENTE DE AJINAKU. Y AJINAKU PENSÓ QUE SÉ ME
MORÍA. ESTABA DEMASIADO AVERGONZADO. Y SÉ MARTILLEO LA CABEZA CONTRA LOS ÁRBOLES HASTA QUE
SE MATÓ. POR ESTO SÉ DICE QUE LAS PEQUEÑAS COSAS PEQUEÑAS PUEDEN VOLVERSE GRANDES. CANTO:
TITIGOTI I MA SO ATE BO HU AJINAKU N BU AGBANGBA!... AGETE, AGETE, DU DO AGETE! N BU
AGBANGBA! AGETE! TITIGOTI TIENE QUE MATAR AJINAKU TENGO QUE MATAR ALGO GRANDE COMO LA
¡TIERRA! ¡ALEGRIA, ALEGRIA, EL SIGNO DIJO QUE TENDRIA ALEGRIA! TENGO QUE MATAR ALGO GRANDE
COMO LA ¡TIERRA! ¡ALEGRÍA! ENSENANZAS: LA ASTUCIA PUEDE VENCER A LA FUERZA BRUTA: AUNQUE
AJINAKU ES MUCHO MÁS GRANDE Y MÁS FUERTE QUE TITIGOTI, ESTE ÚLTIMO UTILIZA SU ASTUCIA Y
HABILIDADES PARA EVADIR LOS ATAQUES DEL ELEFANTE Y FINALMENTE LO DERROTA. NO SUBESTIMES A
LOS DEMÁS: AJINAKU INICIALMENTE SUBESTIMA A TITIGOTI DEBIDO A SU PEQUEÑO TAMAÑO, PERO
APRENDE QUE LA VERDADERA FUERZA NO SIEMPRE SE ENCUENTRA EN EL TAMAÑO FÍSICO. EL ORGULLO
PUEDE LLEVAR A LA DERROTA: LA NEGATIVA DE AJINAKU A ACEPTAR LA DERROTA Y SU ORGULLO
RESULTAN EN SU PROPIA CAÍDA. SU DESPRECIO INICIAL HACIA TITIGOTI LO LLEVA A DESAFIARLO, Y
SU FALTA DE HUMILDAD CONDUCE A SU DERROTA. EL ENGAÑO Y LA ESTRATEGIA PUEDEN SER PODEROSOS:
TITIGOTI UTILIZA DIVERSAS ESTRATEGIAS, COMO EL USO DE LÍQUIDOS DE COLORES PARA SIMULAR
LESIONES EN AJINAKU, LO QUE DEMUESTRA QUE EL ENGAÑO Y LA ESTRATEGIA PUEDEN SER
HERRAMIENTAS EFECTIVAS EN UNA CONFRONTACIÓN. LA IMPORTANCIA DE LA HUMILDAD: AUNQUE
TITIGOTI DEMUESTRA SER ASTUTO Y EXITOSO, MUESTRA HUMILDAD AL NO LUCHAR CONTRA UNA PERSONA
AGONIZANTE Y AL RECONOCER QUE NO ES BUENO CUANDO AJINAKU ESTÁ DECIDIDO A LUCHAR HASTA EL
FINAL. LAS CONSECUENCIAS DE LA ARROGANCIA: LA ARROGANCIA DE AJINAKU Y SU DESPRECIO INICIAL
HACIA TITIGOTI LE LLEVAN A SU PROPIA DESTRUCCIÓN. LA HISTORIA DESTACA LAS CONSECUENCIAS
NEGATIVAS DE LA ARROGANCIA Y LA FALTA DE RESPETO HACIA LOS DEMÁS. EN GENERAL, ESTA
HISTORIA PUEDE SER INTERPRETADA COMO UNA REFLEXIÓN SOBRE LA IMPORTANCIA DE LA ASTUCIA, LA
HUMILDAD Y EL RESPETO MUTUO EN LA VIDA COTIDIANA, TRANSMITIDA A TRAVÉS DE LAS EXPERIENCIAS
DE LOS PERSONAJES EN UN CONTEXTO MITOLÓGICO.''',
  '85. EL ASHIBATÁ.': '''PATAKI: EN LA ALBUFERA (LAGO), EXISTE UNA PLANTA PEQUEÑA FLOTANTE LLAMADA AFUTU
(ASHIBATA). ACTUALMENTE, AFUTU NUNCA HA TENIDO HIJOS. QUEDA SOLA EN LA SUPERFICIE DEL
AGUA, SIEMPRE MARCHANDO HACIA ATRÁS. LLENA DE SUFRIMIENTO, DECIDIÓ BUSCAR AL OLUWO ALUFI
PARA CONSULTAR SU DESTINO Y COMPARTIR CON ÉL SUS DOLORES Y SUFRIMIENTOS EXTREMADAMENTE
PESADOS. EL OLUWO ALUFI LE ENVIÓ LOS ELEMENTOS DEL SACRIFICIO Y AFUTU LOS LLEVÓ A CABO.
DESPUÉS DEL SACRIFICIO, COMENZÓ A VER A SUS HIJOS. TOMÓ HILO Y LOS COSIÓ A SU CUERPO,
CONSTITUYENDO ASÍ UNA MADEJA CON ELLOS. ESTO EXPLICA POR QUÉ, CUANDO ALGUIEN TIRA DE UN
AFUTU (ASHIBATA) DEL AGUA, VIENE UN HILO LARGO Y ES DIFÍCIL SACARLA, Y NUNCA SE VOLTEA.
CANCIÓN DE AFUTU: ¡MI SACRIFICIO FUE EXITOSO! ¡BIEN! SI EL VIENTO INTENTA VOLTEARME, MIS
HIJOS ME TIRAN Y ME SOSTIENEN. ENSEÑANZAS: RESILIENCIA ANTE LA SOLEDAD: AFUTU, LA PLANTA
FLOTANTE EN LA ALBUFERA, ENFRENTA LA SOLEDAD Y LA FALTA DE DESCENDENCIA. A PESAR DE SU
SITUACIÓN, PERSISTE, MARCHANDO HACIA ATRÁS EN LA SUPERFICIE DEL AGUA, MOSTRANDO UNA
RESILIENCIA NOTABLE ANTE LA ADVERSIDAD. BÚSQUEDA DE SIGNIFICADO Y AYUDA: ANTE EL
SUFRIMIENTO Y LA CARGA EMOCIONAL PESADA, AFUTU TOMA LA DECISIÓN DE BUSCAR AL OLUWO ALUFI
PARA CONSULTAR SU DESTINO. ESTO RESALTA LA IMPORTANCIA DE BUSCAR SIGNIFICADO Y APOYO
CUANDO SE ENFRENTA A DIFICULTADES Y DESAFIOS. EL PODER DEL SACRIFICIO Y LA CONSULTA: LA
RESPUESTA DE OLUWO ALUFI A LA BÚSQUEDA DE AFUTU DESTACA LA IMPORTANCIA DEL SACRIFICIO Y LA
CONSULTA EN LA SUPERACIÓN DE OBSTÁCULOS. LOS ELEMENTOS DEL SACRIFICIO SIRVEN COMO MEDIO
PARA CAMBIAR SU DESTINO Y ALIVIAR SUS PENAS. TRANSFORMACIÓN Y CREACIÓN DE VÍNCULOS:
DESPUÉS DEL SACRIFICIO, AFUTU EXPERIMENTA UNA TRANSFORMACIÓN AL VER A SUS HIJOS. LA ACCIÓN
DE COSERLOS A SU CUERPO SIMBOLIZA LA CREACIÓN DE VÍNCULOS FUERTES Y LA CONEXIÓN CON LA
DESCENDENCIA, MOSTRANDO QUE, INCLUSO EN LA AUSENCIA BIOLÓGICA, SE PUEDEN ESTABLECER LAZOS
SIGNIFICATIVOS. METÁFORA DE LA RESISTENCIA: LA EXPLICACIÓN DE POR QUÉ AFUTU, CUANDO SE
TIRA DEL AGUA, VIENE CON UN HILO LARGO Y NO SE VOLTEA, SIRVE COMO UNA METÁFORA PODEROSA.
PUEDE INTERPRETARSE COMO LA RESISTENCIA ANTE LOS INTENTOS DE DESESTABILIZACIÓN, MOSTRANDO
LA FUERZA Y LA CAPACIDAD DE AFUTU PARA MANTENERSE FIRME. EN RESUMEN, LA HISTORIA DE AFUTU
RESALTA LA RESILIENCIA, LA BÚSQUEDA DE SIGNIFICADO, LA IMPORTANCIA DE SACRIFICIOS Y
CONSULTAS, LA TRANSFORMACIÓN PERSONAL Y LA METÁFORA DE LA RESISTENCIA ANTE LAS
DIFICULTADES. ESTAS ENSEÑANZAS PUEDEN APLICARSE A LA VIDA COTIDIANA, RECORDÁNDONOS LA
CAPACIDAD DE SUPERAR DESAFÍOS Y ENCONTRAR SIGNIFICADO INCLUSO EN SITUACIONES APARENTEMENTE
DIFÍCILES.''',
  '86. LA DISPUTA ENTRE EL AGUA LA PLAZA Y LA TIERRA.': '''PATAKI: AQUÍ, TRES CAMINOS ENTRARON EN UNA DISPUTA: TIERRA, PLAZA Y AGUA, CADA UNO
DESEANDO SER EL PRIMERO. SURGIÓ UNA ACALORADA DISCUSIÓN ENTRE ELLOS, Y EL AJA (EL PERRO),
AL ESCUCHAR SUS DESACUERDOS, INTERVINO CON SABIDURÍA, DICIENDO: "ESTÁN PELEANDO EN VANO,
YA QUE NINGUNO PUEDE SER EL PRIMERO. LOS TRES TIENEN EL MISMO DERECHO Y DEBEN VIVIR EN
ARMONÍA PARA PROSPERAR JUNTOS". AL ESCUCHAR ESTAS PALABRAS, LOS TRES CAMINOS, INTRIGADOS,
PIDIERON AL AJA UNA MEJOR EXPLICACIÓN. CON PACIENCIA, EL PERRO CONTINUÓ SU SABIA
ENSEÑANZA: "LOS TRES TIENEN EL MISMO DERECHO PORQUE LA INTERDEPENDENCIA ENTRE LA TIERRA,
LA PLAZA Y EL AGUA ES CRUCIAL. SI EL AGUA NO CAE SOBRE LA TIERRA, ESTA NO PRODUCE, LO QUE
AFECTARÍA DIRECTAMENTE LA OFERTA EN LA PLAZA. SI NO HUBIERA TIERRA, EL AGUA NO TENDRÍA UN
LECHO DONDE CAER Y FERTILIZAR, ESENCIAL PARA LA PRODUCCIÓN. LA PLAZA, POR SU PARTE,
DEPENDE DE LA TIERRA Y EL AGUA PARA OFRECER LOS FRUTOS PRODUCIDOS. EN RESUMEN, TODOS ESTÁN
CONECTADOS Y DEBEN COLABORAR PARA PROSPERAR". LAS PALABRAS DEL AJA RESONARON EN LOS TRES
CAMINOS, DEJÁNDOLOS CONFORMES Y CONVENCIDOS DE LA IMPORTANCIA DE TRABAJAR JUNTOS. EN
AGRADECIMIENTO, LA TIERRA EXPRESÓ AL PERRO: "POR MUY LEJOS QUE VAYAS, NUNCA TE PERDERÁS".
LA PLAZA AGREGÓ: "CUANDO NO TENGAS NADA QUE COMER, VEN A MÍ; INCLUSO ENCONTRARÁS UN
HUESO". EL AGUA CONCLUYÓ: "SI ALGUNA VEZ CAES AL AGUA, NUNCA TE AHOGARAS" ASÍ, TODOS
AGRADECIERON AL PERRO Y ESTABLECIERON UNA AMISTAD BASADA EN LA COMPRENSIÓN MUTUA Y LA
COOPERACIÓN, ENTENDIENDO QUE SU PROSPERIDAD DEPENDIA DE LA ARMONIA ENTRE ELLOS.
ENSEÑANZAS: INTERDEPENDENCIA: LA HISTORIA RESALTA CÓMO LA TIERRA, LA PLAZA Y EL AGUA
DEPENDEN UNOS DE OTROS PARA FUNCIONAR CORRECTAMENTE. CADA UNO TIENE UN PAPEL VITAL EN EL
CICLO QUE GARANTIZA LA PROSPERIDAD DE TODOS. COLABORACIÓN SOBRE LA COMPETENCIA: AUNQUE
INICIALMENTE ENTRARON EN DISPUTA DESEANDO SER EL PRIMERO, APRENDEN QUE LA COMPETENCIA NO
ES LA SOLUCIÓN. LA COLABORACIÓN Y EL TRABAJO CONJUNTO SON ESENCIALES PARA MANTENER UN
EQUILIBRIO ARMONIOSO. RECONOCIMIENTO DE FORTALEZAS MUTUAS: CADA ELEMENTO RECONOCE Y
APRECIA LAS FORTALEZAS DE LOS OTROS. LA TIERRA ASEGURA AL PERRO QUE NUNCA SE PERDERÁ, LA
PLAZA PROMETE PROVEER ALIMENTOS, INCLUSO EN TIEMPOS DIFÍCILES, Y EL AGUA GARANTIZA
SEGURIDAD. ESTA ACEPTACIÓN Y RECONOCIMIENTO FORTALECEN SU UNIDAD. COMPRENDER LA CONEXIÓN
ENTRE ELEMENTOS: LA HISTORIA DESTACA CÓMO LA PROSPERIDAD DE LA PLAZA DEPENDE DE LA
PRODUCCIÓN DE LA TIERRA Y EL AGUA, Y CÓMO LA TIERRA NECESITA EL AGUA PARA FERTILIZAR. ESTA
COMPRENSIÓN MUTUA FORTALECE SU COLABORACIÓN. AGRADECIMIENTO Y AMISTAD: LA GRATITUD Y LA
AMISTAD SURGEN COMO RESULTADO DE LA COMPRENSIÓN Y LA COLABORACIÓN. CADA ELEMENTO AGRADECE
AL PERRO POR SU SABIDURÍA, ESTABLECIENDO UNA RELACIÓN DE RESPETO Y APRECIO MUTUO. EN
RESUMEN, LA HISTORIA ENSEÑA QUE EL ÉXITO Y LA ARMONÍA SE ALCANZAN MEJOR CUANDO RECONOCEMOS
Y VALORAMOS LA CONTRIBUCIÓN DE CADA PARTE, COLABORAMOS EN LUGAR DE COMPETIR, Y ENTENDEMOS
LA INTERDEPENDENCIA QUE EXISTE ENTRE NOSOTROS.''',
  '87. LOS TRES PERSONAJES.': '''PATAKI: HACÍA VARIAS NOCHES QUE ORÚNMILA NO PODÍA DORMIR A CAUSA DE UN EXTRAÑO RUIDO QUE
SENTIA. UNA NOCHE, FINALMENTE, COMPROBO QUE ERA EKUTE QUIEN LE CAUSABA EL TRASTORNO.
EKUTE, LE HABLÓ DICIENDO: "MAÑANA, TRES PERSONAS VENDRÁN A VISITARTE. A LA PRIMERA, QUE ES
ESHU, LE DICES QUE PASE A OCUPAR SU PUESTO. A LA SEGUNDA, LE OFRECES EKU EYA, PUES ES
OGUN. Y A LA TERCERA, QUE ES UNA MUJER RELACIONADA CON OSHUN, LE PREPARAS OSHINSHIN". AL
DÍA SIGUIENTE, TAL COMO PREDIJO EKUTE, TRES VISITANTES LLEGARON A CASA DE ORÚNMILA. CON
SABIDURÍA, ORÚNMILA CUMPLIÓ LAS INSTRUCCIONES. INVITÓ A ESHU A PASAR Y TOMAR SU ASIENTO,
OFRECIÓ A OGUN EKU EYA, Y PREPARÓ OSHINSHIN PARA LA MUJER RELACIONADA CON OSHUN.
ENSEÑANZAS: ESTE EPISODIO RESALTA LA IMPORTANCIA DE LA CONEXIÓN ESPIRITUAL Y LA
COMUNICACIÓN CON LAS DEIDADES. ORÚNMILA, AL ESCUCHAR A EKUTE Y SEGUIR SUS INSTRUCCIONES,
DEMOSTRÓ SU RESPETO Y DEVOCIÓN A LAS ENTIDADES DIVINAS. LA HISTORIA TAMBIÉN ENSEÑA SOBRE
LA NECESIDAD DE RECONOCER Y HONRAR A CADA DEIDAD SEGÚN SUS PROPIAS PREFERENCIAS Y
RITUALES.''',
  '88. ORERE MUJER DE ORÚNMILA.': '''PATAKI: ORERE TAMBIÉN FUE MUJER DE ORÚNMILA, Y UN DÍA, ESTE LA ABANDONÓ PARA IRSE CON
OTRA, LO QUE HIZO QUE ORÚNMILA SE VIERA UN POCO ATRASADO EN SU SITUACIÓN. UN DÍA, ORÚNMILA
SALIÓ Y SE ENCONTRÓ CON ORERE, QUE ESTABA EN MUY MALAS CONDICIONES. A PESAR DE LAS
CIRCUNSTANCIAS, ORÚNMILA, MOVIDO POR LA COMPASIÓN, LE REGALÓ DOS MONEDAS. ESTE PEQUEÑO
ACTO DE GENEROSIDAD MARCÓ EL FINAL DE LA MALA VOLUNTAD QUE HABÍA EXISTIDO DENTRO DE ÉL.
DESDE ENTONCES, ORÚNMILA EMPEZÓ A VER MEJORÍAS EN SU SITUACIÓN. ENSEÑANZAS: LA ACCIÓN DE
AYUDAR A ORERE NO SOLO ALIVIÓ LAS CONDICIONES DE SU EXESPOSA, SINO QUE TAMBIÉN TUVO UN
IMPACTO POSITIVO EN LA VIDA Y FORTUNA DE ORÚNMILA. LA GENEROSIDAD Y LA EMPATIA LE
BRINDARON UN RENACIMIENTO PERSONAL, MARCANDO EL INICIO DE UNA NUEVA ETAPA EN SU VIDA LLENA
DE PROSPERIDAD Y BIENESTAR.''',
  '89. CUANDO OLOFIN QUISO ABANDONAR LA TIERRA.': '''PATAKI: HUBO UNA OCASIÓN EN QUE OLOFIN CONSIDERÓ ABANDONAR LA TIERRA Y DEJAR A ORÚNMILA A
CARGO. EN ESTE MOMENTO, APARECIÓ IKU, QUE ANHELABA GOBERNAR LA TIERRA. COMO OLOFIN NO
PODÍA HACER DISCRIMINACIÓN ENTRE SUS HIJOS, DECIDIÓ SOMETERLOS A UNA PRUEBA CONSISTENTE EN
PERMANECER TRES DIAS SIN COMER. AL LLEGAR AL SEGUNDO DIA DE LA PRUEBA, ORÚNMILA SE
ENCONTRABA HAMBRIENTO. EN ESE INSTANTE, APARECIÓ ESHU Y LE PREGUNTO: "ORÚNMILA, ¿NO TIENES
HAMBRE?" ORÚNMILA RESPONDIÓ: "YA ESTOY TAN DÉBIL QUE APENAS PUEDO VER". ESHU LE PROPUSO:
"¿QUIERES COCINAR?". ORÚNMILA CONTESTÓ: "NO PUEDO HACERLO PORQUE ESTOY SOMETIDO A UNA
PRUEBA DE OLOFIN". AL SER ORÚNMILA HONESTO, ESHU LE ASEGURÓ: "NO TE PREOCUPES, GUARDARÉ EL
SECRETO, YA QUE YO SOY EL VIGILANTE DE USTEDES. MATA UN AKUKO PARA COMER" SIN EMBARGO,
ORÚNMILA RESPONDIÓ: "YO PREFIERO COMER ADIE EN VEZ DE AKUKO". ESHU PROPUSO: "ENTONCES,
MATA UNA ADIE PARA TI Y UN AKUKO PARA MÍ". ASÍ LO HIZO ORÚNMILA Y, DESPUÉS DE TERMINAR DE
COMER, ENTERRARON CUIDADOSAMENTE LOS RESTOS Y LIMPIARON TODO EL ESPACIO. EN ESE MOMENTO,
APARECIÓ IKU, QUE ESTABA HAMBRIENTA, Y AL NO ENCONTRAR ALIMENTO, DECIDIÓ BUSCAR EN LOS
BASUREROS. ESHU, HABILIDOSO VIGILANTE, LO SORPRENDIÓ MIENTRAS COMÍA EN ESTE LUGAR
INADECUADO, Y ASÍ IKU PERDIÓ LA PRUEBA. HONESTIDAD: ORÚNMILA, AL SER HONESTO ACERCA DE SU
SITUACIÓN ANTE ESHU, DEMOSTRÓ INTEGRIDAD Y FIDELIDAD A LA PRUEBA A LA QUE ESTABA SOMETIDO
POR OLOFIN. LA HONESTIDAD, INCLUSO EN SITUACIONES DIFICILES, ES ESENCIAL. INTERVENCIÓN DE
ESHU: ESHU, EN ESTE RELATO, DESEMPEÑA EL PAPEL DE VIGILANTE. SU INTERVENCIÓN PROPORCIONA
UN RECORDATORIO DE QUE A VECES LAS SOLUCIONES PUEDEN VENIR DE FUENTES INESPERADAS Y QUE,
INCLUSO EN CIRCUNSTANCIAS DIFICILES, HAY POSIBILIDADES DE AYUDA. CONSECUENCIAS DE LAS
ACCIONES: LA LLEGADA DE IKU, HAMBRIENTA Y DESESPERADA POR COMIDA, ILUSTRA LAS
CONSECUENCIAS DE SUS ACCIONES. ESHU, COMO VIGILANTE, OBSERVA Y ACTÚA SEGÚN LA SITUACIÓN,
LO QUE DESTACA LA NOCIÓN DE QUE NUESTRAS ACCIONES PUEDEN TENER CONSECUENCIAS, TANTO
POSITIVAS COMO NEGATIVAS. EN RESUMEN, LA HISTORIA SUBRAYA LA IMPORTANCIA DE LA HONESTIDAD,
LA SOLIDARIDAD, EL DISCERNIMIENTO EN LAS ELECCIONES Y LA COMPRENSIÓN DE LAS CONSECUENCIAS
DE NUESTRAS ACCIONES. ESTAS ENSEÑANZAS PUEDEN APLICARSE A LA VIDA DIARIA, RECORDÁNDONOS LA
IMPORTANCIA DE LA INTEGRIDAD Y LA COMPASIÓN EN NUESTRAS INTERACCIONES CON LOS DEMÁS.''',
  '90. EL AWO KOSOBE.': '''PATAKI: AWO KOSOBE DESTACABA POR SU CARÁCTER CAPRICHOSO, PERVERSO Y SOBERBIO. EN UNA
OCASIÓN, SHANGO LE PIDIÓ UN ABO, PERO DE MANERA ARROGANTE, KOSOBE SE NEGÓ A DÁRSELO. ANTE
ESTA AFRENTA, SHANGO BUSCÓ EL APOYO DE YEMAYA, Y JUNTOS DECIDIERON CASTIGAR LA ACTITUD DE
KOSOBE PRENDIENDO FUEGO A SU ILE. DESDE AQUEL DÍA, LA VIDA DE KOSOBE SE LLENÓ DE
DIFICULTADES Y DESESPERACIÓN. BUSCANDO SOLUCIONES, ACUDIÓ A ORÚNMILA PARA QUE LO GUIARA.
ORÚNMILA, CON SABIDURÍA DIVINA, CONSULTÓ IFA Y LE REVELÓ A KOSOBE LO QUE DEBÍA HACER PARA
CAMBIAR SU DESTINO. ORÚNMILA LE INDICÓ QUE REALIZARA UNA ROGACIÓN CON UN AKUKO, CUATRO
EYELE FUN FUN, DOS ADIE FUN FUN Y LA RELIQUIA QUE GUARDAS COMO RECUERDO DE LOS ATRIBUTOS
DE TU ALTAR QUE FUE LO UNICO QUE SALVASTE DEL FUEGO QUE DESTRUYO TU ILE. POSTERIORMENTE,
KOSOBE TUVO QUE REALIZAR EL RITUAL DE KOFIBORI Y DARSE TRES BAÑOS CON ALBAHACA CIMARRONA,
PIÑON DE ROSAS Y PRODIGIOSA. ADEMÁS, CON ESE MISMO OMIERO, DEBÍA BALDEAR SU ILE,
RENUNCIANDO A SUS CAPRICHOS, PERVERSIONES Y ARROGANCIA. ASIMISMO, ORÚNMILA LE INSTRUYÓ A
SALDAR SU DEUDA CON SHANGO, PAGÁNDOLE EL ABO QUE LE DEBÍA. CUMPLIENDO CON TODAS LAS OBRAS
ORDENADAS POR ORÚNMILA, EL AWO KOSOBE EXPERIMENTÓ UNA TRANSFORMACIÓN EN SU FORTUNA. LA
PROSPERIDAD VOLVIÓ A SU VIDA, ENSEÑÁNDOLE LA IMPORTANCIA DE LA HUMILDAD, LA RECTITUD Y EL
PAGO DE DEUDAS PENDIENTES. ESTE EPISODIO DESTACA COMO, A TRAVES DE LA CORRECCIÓN DE
COMPORTAMIENTOS NEGATIVOS Y EL CUMPLIMIENTO DE RITUALES PRESCRITOS, UNO PUEDE CAMBIAR SU
DESTINO Y ENCONTRAR NUEVAMENTE LA ARMONÍA EN SU EXISTENCIA. ENSEÑANZAS: CONSECUENCIAS DE
LA ARROGANCIA Y LA NEGATIVA: LA NEGATIVA DE AWO KOSOBE A CUMPLIR CON LA PETICIÓN DE SHANGO
Y SU ACTITUD CAPRICHOSA Y SOBERBIA LLEVARON A CONSECUENCIAS NEGATIVAS. ESTO RESALTA LA
IMPORTANCIA DE LA HUMILDAD Y EL RESPETO HACIA LAS DEIDADES Y LAS DECISIONES DE OTROS.
CASTIGO DIVINO: LA INTERVENCIÓN DE SHANGO Y YEMAYA, QUEMANDO EL ILE DE KOSOBE, MUESTRA
CÓMO LAS ACCIONES IRRESPETUOSAS PUEDEN TENER CONSECUENCIAS SEVERAS Y RECIBIR CASTIGO
DIVINO. ESTO REFUERZA LA IDEA DE QUE EL RESPETO Y LA REVERENCIA HACIA LAS FUERZAS DIVINAS
SON ESENCIALES. GUÍA DE ORÚNMILA: ORÚNMILA, COMO ORÁCULO DIVINO, OFRECE GUÍA Y SOLUCIONES
PARA RECTIFICAR LA SITUACIÓN DE KOSOBE. LAS RECOMENDACIONES DE REALIZAR RITUALES
ESPECIFICOS, CAMBIOS EN SU COMPORTAMIENTO Y SALDAR DEUDAS REFLEJAN LA IMPORTANCIA DE
SEGUIR LAS INSTRUCCIONES DIVINAS PARA CAMBIAR EL DESTINO. RENOVACIÓN PERSONAL: EL PROCESO
DE REALIZAR LAS OBRAS PRESCRITAS, INCLUYENDO BAÑOS RITUALES Y CAMBIOS EN SU ACTITUD,
SIMBOLIZA UNA RENOVACIÓN PERSONAL. KOSOBE TIENE LA OPORTUNIDAD DE DEJAR ATRÁS SUS MALOS
HÁBITOS Y ADOPTAR UNA NUEVA FORMA DE VIDA, DESTACANDO LA CAPACIDAD DE TRANSFORMACIÓN Y
REDENCIÓN PERSONAL. PAGAR DEUDAS Y RECTIFICAR ERRORES: LA INSTRUCCIÓN DE PAGAR LA DEUDA
PENDIENTE CON SHANGO ENFATIZA LA IMPORTANCIA DE RECTIFICAR LOS ERRORES DEL PASADO Y
CUMPLIR CON LAS OBLIGACIONES PENDIENTES. ESTE ACTO ES CRUCIAL PARA RESTABLECER EL
EQUILIBRIO Y LA ARMONÍA EN LA VIDA DE KOSOBE. PROSPERIDAD A TRAVÉS DE LA CORRECCIÓN: AL
SEGUIR LAS ENSEÑANZAS Y REALIZAR LAS OBRAS RECOMENDADAS, AWO KOSOBE EXPERIMENTA UNA MEJORA
EN SU FORTUNA. ESTO RESALTA LA IDEA DE QUE LA CORRECCIÓN DE COMPORTAMIENTOS NEGATIVOS Y EL
CUMPLIMIENTO DE RITUALES PUEDEN CONDUCIR A LA PROSPERIDAD Y LA RESTAURACIÓN DEL BIENESTAR.
EN RESUMEN, LA HISTORIA DE AWO KOSOBE SUBRAYA LA IMPORTANCIA DE LA HUMILDAD, EL RESPETO A
LO DIVINO, LA RECTIFICACIÓN DE ERRORES PASADOS Y LA CAPACIDAD DE CAMBIO Y TRANSFORMACIÓN
PERSONAL PARA ALCANZAR LA PROSPERIDAD Y EL EQUILIBRIO EN LA VIDA.''',
  '91. EL REINADO DE EJIOGBE.': '''PATAKI: EJIOGBE, DEBIDO A LOS NUMEROSOS ENEMIGOS QUE TENIA A CAUSA DE LA ENVIDIA, NO PODIA
VIVIR EN SU REINO. EN UN DETERMINADO DÍA, DECIDIÓ PARTIR HACIA OTRA TIERRA, Y DESDE SU
PARTIDA, LAS COSAS COMENZARON A DESMORONARSE EN SU PUEBLO, YA QUE CADA PERSONA HACÍA LO
QUE LE VENÍA EN GANA. ANTE ESTA SITUACIÓN, EL REY LAMENTABA LA AUSENCIA DE EJIOGBE. UN
DÍA, A TRAVÉS DE ESHU, SE SUPO EN EL PUEBLO QUE EN UNA TIERRA LEJANA HABÍA UN HOMBRE MUY
PARECIDO A EJIOGBE. EL REY LO MANDÓ A BUSCAR, OFRECIÉNDOLE EL MANDO ABSOLUTO CON AMPLIOS
PODERES PARA QUE, SIN NINGÚN OBSTÁCULO, LLEVARA A CABO SU OBRA DE GOBIERNO. ENTERADO DE LA
OFERTA DEL REY, EJIOGBE CONSULTÓ CON OLOFIN, QUIEN LE RESPONDIÓ: "TODO LO QUE HAGA EN BIEN
DE LA HUMANIDAD, YO LO APROBARÉ": EJOGBE REGRESO A SU TIERRA PARA GOBERNARLA, Y LO PRIMERO
QUE HIZO FUE ELIMINAR A TODOS SUS ENEMIGOS. NOTA: RECIBA A ELEGBA Y NUNCA DEJE DE HACER EL
BIEN, QUE OLOFIN LO PREMIARÁ. SE LE OFRECE UN AKUKO A LA BASURA DE LA CASA PARA RESOLVER
UN ASUNTO IMPORTANTE QUE TIENE PENDIENTE. EBO: COMIDA A LA BASURA O LO QUE PIDA PARA VER
EL FIN DE SUS ENEMIGOS. EBO ABO A OLOKUN CON TRES TINAJAS. LO HACEN TRES AWOSES PARA QUE
LA PERSONA SE LEVANTE. ENSEÑANZAS: CONSECUENCIAS DE LA ENVIDIA Y LA MALDAD: LA PARTIDA DE
EJIOGBE DE SU REINO DEBIDO A LA ENVIDIA DE SUS ENEMIGOS MUESTRA CÓMO LAS ACCIONES
NEGATIVAS Y LA MALICIA PUEDEN TENER UN IMPACTO PERJUDICIAL EN LA VIDA DE UNA PERSONA.
RESPONSABILIDAD DEL LIDERAZGO: EL HECHO DE QUE EL REY BUSCARA A ALGUIEN CON CUALIDADES
SIMILARES A LAS DE EJIOGBE PARA LIDERAR SU PUEBLO RESALTA LA IMPORTANCIA DE TENER LIDERES
COMPETENTES Y CAPACES EN EL PODER. IMPORTANCIA DE LA APROBACIÓN DIVINA: LA CONSULTA DE
EJIOGBE CON OLOFIN ANTES DE REGRESAR A GOBERNAR SU TIERRA DESTACA LA IMPORTANCIA DE BUSCAR
LA APROBACIÓN DIVINA EN LAS DECISIONES IMPORTANTES. EL COMPROMISO DE HACER EL BIEN EN
BENEFICIO DE LA HUMANIDAD TAMBIÉN ES UN ASPECTO CRUCIAL. ELIMINACIÓN DE OBSTÁCULOS: LA
ACCIÓN DE EJIOGBE AL REGRESAR Y ELIMINAR A SUS ENEMIGOS DESTACA LA NECESIDAD DE ABORDAR Y
SUPERAR LOS OBSTÁCULOS PARA LOGRAR EL ÉXITO Y LA ESTABILIDAD. RECOMPENSAS POR EL BIEN: LA
NOTA SOBRE RECIBIR A ELEGBA Y LA PROMESA DE QUE OLOFIN PREMIARÁ EL BIEN RESALTA LA
CREENCIA EN QUE HACER EL BIEN Y SEGUIR PRINCIPIOS ÉTICOS CONLLEVA RECOMPENSAS POSITIVAS.
EN CONJUNTO, LA HISTORIA SUBRAYA LA IMPORTANCIA DE LA MORALIDAD, LA RESPONSABILIDAD, LA
APROBACIÓN DIVINA Y EL ESFUERZO PARA SUPERAR DESAFÍOS EN EL CAMINO HACIA EL ÉXITO Y LA
PROSPERIDAD. ADEMÁS, DESTACA LA CREENCIA EN EL PODER DE LAS PRÁCTICAS ESPIRITUALES PARA
INFLUIR POSITIVAMENTE EN LA VIDA DE UNA PERSONA.''',
  '92. LA GENTE REVIRADA CONTRA ORÚNMILA.': '''PATAKI: LA GENTE POR ENVIDIA SE REVIRÓ EN CONTRA DE ORÚNMILA Y ACORDARON CON IKÚ SU
ASESINATO. IKÚ LLEGÓ AL ILE DE ORÚNMILA Y LO ENCONTRÓ PARADO EN LA PUERTA, PERO NO LO
RECONOCIÓ PORQUE ORÚNMILA LE HABÍA DADO DE COMER A SU LERI Y HABÍA REALIZADO UN EBBO CON
AKUKÓ Y UN OWUNKO CUYOS PELOS QUEMÓ PARA FORMAR UNA GRASA NEGRA PARA UNTARSE EN TODA LA
CARA PARA DESFIGURARSE. CUANDO IKÚ LLEGÓ, LE PREGUNTÓ SI ALLÍ VIVÍA UN HOMBRE COLORADO, A
LO QUE ORÚNMILA CONTESTÓ QUE NO, QUE EL ÚNICO QUE VIVÍA ALLÍ ERA ÉL. IKÚ SE RETIRÓ, PERO
REGRESÓ MÁS TARDE AL ENTERARSE DE QUE ESE ERA EL ILE QUE BUSCABA. CUANDO LLEGÓ POR SEGUNDA
VEZ, ORÚNMILA YA HABÍA TERMINADO DE COCINAR LA COMIDA Y LA INVITÓ A COMER Y BEBER. IKÚ
COMIÓ Y BEBIÓ TANTO QUE SE QUEDÓ DORMIDA, MOMENTO QUE APROVECHÓ ORÚNMILA PARA QUITARLE LA
MANDARRIA CON LA QUE ELLA MATABA A LA GENTE. CUANDO IKÚ DESPERTÓ, PREGUNTÓ DE INMEDIATO
POR LA MANDARRIA, A LO QUE ORÚNMILA CONTESTÓ QUE NO LA HABÍA VISTO. LA MUERTE LE SUPLICÓ
TANTO QUE LLEGÓ A PROMETERLE QUE NO LO MATARÍA A ÉL NI A NINGUNO DE SUS HIJOS A MENOS QUE
FUERA ÉL QUIEN SE LO ORDENARA O ENTREGARA. FUE ASÍ COMO ORÚNMILA VENCIÓ A LA MUERTE. NOTA:
ESTA ES LA RAZÓN O EL MOTIVO POR EL CUAL LOS AWOSES PUEDEN SALVAR A CUALQUIERA QUE ESTÉ EN
ARTÍCULO DE MUERTE. EBO: LERI DE OWUNKO, UTILIZANDO LOS PELOS QUEMADOS QUE SE UNTAN EN LA
CARA Y SE COLOCAN EN LA PUERTA DEL ILE PARA QUE LA MUERTE SIGA SU CAMINO Y KOBORI ELEDA.
ENSEÑANZAS: ASTUCIA PARA ENFRENTAR LA ADVERSIDAD: ORÚNMILA, AL VERSE AMENAZADO POR LA
ENVIDIA Y LA CONSPIRACIÓN EN SU CONTRA, DEMOSTRÓ ASTUCIA AL DISFRAZARSE PARA ENGAÑAR A LA
MUERTE. ESTA ASTUCIA LE PERMITIÓ GANAR TIEMPO Y ENCONTRAR UNA SOLUCIÓN. PREPARACIÓN Y
PLANIFICACIÓN: ORÚNMILA ANTICIPÓ EL PELIGRO Y TOMÓ MEDIDAS PARA PROTEGERSE. REALIZÓ UN
EBBO CON AKUKÓ Y OWUNKO, UTILIZANDO LOS PELOS DEL OWUNKO PARA CREAR UNA GRASA QUE SE
APLICÓ EN LA CARA. ESTA PREPARACIÓN FUE CRUCIAL PARA SU ESTRATEGIA DE DEFENSA. NEGOCIACIÓN
Y DIPLOMACIA: CUANDO IKÚ LLEGÓ, ORÚNMILA NO RECURRIÓ A LA CONFRONTACIÓN DIRECTA. EN LUGAR
DE ESO, NEGOCIÓ CON LA MUERTE, LOGRANDO QUE IKÚ LE PROMETIERA NO CAUSARLE DAÑO NI A ÉL NI
A SUS HUOS A MENOS QUE ÉL MISMO LO ORDENARA O ENTREGARA. ESTA HABILIDAD DIPLOMÁTICA FUE
FUNDAMENTAL PARA SU VICTORIA. CAPACIDAD DE CAMBIAR EL DESTINO: LA HISTORIA DESTACA LA
CREENCIA EN QUE LOS AWOSES, A TRAVÉS DE SUS CONOCIMIENTOS Y ACCIONES, PUEDEN CAMBIAR EL
DESTINO DE AQUELLOS QUE ENFRENTAN LA AMENAZA DE LA MUERTE. ESTO SUBRAYA LA IDEA DE QUE EL
PODER ESPIRITUAL Y LAS PRÁCTICAS CORRECTAS PUEDEN INFLUIR EN EL CURSO DE LA VIDA. EN
RESUMEN, LA HISTORIA ENSEÑA SOBRE LA IMPORTANCIA DE LA ASTUCIA, LA PREPARACIÓN, LA
NEGOCIACIÓN, LA PERSISTENCIA, LA CAPACIDAD DE CAMBIAR EL DESTINO Y LAS PRÁCTICAS RITUALES
PARA ENFRENTAR Y SUPERAR SITUACIONES DIFÍCILES.''',
  '93. LA CORONACION DE EJIOGBE.': '''PATAKI: HABIA DOS PUEBLOS INMERSOS EN INTENSAS PELEAS, Y EN EL FRAGOR DE LAS LUCHAS, LOS
REYES DE AMBAS NACIONES CAYERON PRISIONEROS. EN AQUELLOS TIEMPOS, ERA COMÚN EL INTERCAMBIO
DE PRISIONEROS COMO PARTE DE UN PACTO, PERO SURGIÓ UN PROBLEMA CUANDO UNA DE LAS FACCIONES
BELIGERANTES DIO MUERTE AL REY ENEMIGO. CUANDO LLEGÓ EL MOMENTO DE LLEVAR A CABO EL
INTERCAMBIO, SE ENCONTRARON SIN SABER CÓMO CUMPLIR CON LO ACORDADO. SIN EMBARGO, POR
COINCIDENCIA, EN UNO DE LOS PUEBLOS IMPLICADOS EXISTÍA UN HOMBRE QUE ERA IDÉNTICO AL REY
FALLECIDO, Y NO ERA OTRO QUE EJÍOGBE. SE EMITIÓ UNA ORDEN DE CAPTURA EN SU CONTRA, LO CUAL
LO LLEVÓ A HUIR Y REFUGIARSE EN LO MÁS INTRINCADO DEL MONTE, TEMIENDO QUE LO BUSCARAN PARA
ASESINARLO O ENCARCELARLO. DESPUÉS DE UNA INTENSA BÚSQUEDA, LOGRARON ENCONTRARLO, LO
TOMARON PRISIONERO Y LO CONDUJERON HACIA LA CAPITAL DE AQUEL REINO. EN EL CAMINO, EL
PRISIONERO SUPLICABA A SUS CAPTORES QUE LO LIBERARAN, ARGUMENTANDO QUE NO HABÍA HECHO NADA
CONTRA NADIE Y QUE NO HABÍA VIOLADO NINGUNA LEY DE SU PUEBLO. LOS CAPTORES LO TRATARON CON
CORTESÍA Y ATENCIONES, ASEGURÁNDOLE QUE NO LO MATARÍAN NI LO ENVIARÍAN A LA CÁRCEL, SINO
QUE LO CONDUCÍAN AL PALACIO DEL REY PARA HACERLE UN GRAN FAVOR QUE LO ENRIQUECERÍA. AL
LLEGAR AL PALACIO, VISTIERON AL PRISIONERO CON LAS ROPAS Y ATRIBUTOS DEL REY ENEMIGO
ASESINADO POR ELLOS, LOGRANDO QUE SE ASEMEJARA DE MANERA SORPRENDENTE A AQUEL MONARCA.
ASÍ, LO INTERCAMBIARON POR SU PROPIO REY, Y EJÍOGBE SE CONVIRTIÓ EN EL NUEVO MONARCA DE
ESA TIERRA. ESTA ES LA CORONACIÓN DE EJÍOGBE, QUIEN NO PUDO SER REY EN SU PROPIA TIERRA.
POR ESTA RAZON SE DICE: "AL REY MUERTO, REY PUESTO." ENSENANZAS: REFUGIO Y ESTRATEGIA: LA
DECISIÓN DE EJÍOGBE DE REFUGIARSE EN LO MÁS INTRINCADO DEL MONTE ILUSTRA LA NECESIDAD DE
BUSCAR REFUGIO Y ESTRATEGIAS INTELIGENTES CUANDO SE ENFRENTA A DESAFÍOS O PELIGROS
INMINENTES. INJUSTICIA Y MANIPULACIÓN: LA HISTORIA DESTACA CÓMO LOS CAPTORES MANIPULARON
LA SITUACIÓN PARA SUS PROPIOS FINES, CAMBIANDO A EJÍOGBE POR SU PROPIO REY. ESTO RESALTA
LA PRESENCIA DE LA INJUSTICIA Y LA MANIPULACIÓN EN LAS RELACIONES POLÍTICAS Y SOCIALES.
OPORTUNIDAD Y CORONACIÓN: LA CORONACIÓN DE EJÍOGBE COMO REY EN LA TIERRA ENEMIGA SUGIERE
QUE LAS OPORTUNIDADES PUEDEN SURGIR DE LAS SITUACIONES MÁS INESPERADAS. LA ASTUCIA Y LA
ADAPTABILIDAD PUEDEN CONVERTIR DESAFIOS EN TRIUNFOS. REFRÁN "AL REY MUERTO, REY PUESTO":
EL REFRÁN AL FINAL DE LA HISTORIA, "AL REY MUERTO, REY PUESTO", RESALTA COMO EN EL JUEGO
POLÍTICO, ESPECIALMENTE EN TIEMPOS DE CONFLICTOS Y LUCHAS, LA SUCESIÓN PUEDE OCURRIR DE
MANERAS SORPRENDENTES Y A VECES CUESTIONABLES. EN CONJUNTO, LA HISTORIA OFRECE REFLEXIONES
SOBRE LA IDENTIDAD, ESTRATEGIA, MANIPULACIÓN, OPORTUNIDADES Y LOS JUEGOS POLÍTICOS,
PROPORCIONANDO UNA VISIÓN MÁS AMPLIA DE LAS COMPLEJIDADES DE LAS RELACIONES HUMANAS Y LAS
DINÁMICAS SOCIALES.''',
  '94. LA MONTAÑA Y EL AWO DEL REY.': '''PATAKI: LA MONTAÑA, AUNQUE ERA HIJA DE LA VIRGEN DE LAS MERCEDES, SE COMPORTABA COMO UNA
DE ESAS HUAS DESAMORADAS QUE NUNCA SE PREOCUPABA POR COMPLACER O ALEGRAR A SU MADRE. NO,
LE MOSTRABA RESPETO Y CAÍA FRECUENTEMENTE EN FALTAS DE CONSIDERACIÓN Y FALTA DE RESPETO
HACIA ELLA. LA VIRGEN, AL OBSERVAR LA DESVIACIÓN DE SU HIJA, UN DÍA LA MALDUO, DESEÁNDOLE
ENFERMEDAD Y MUERTE. AL CONOCER LA MALDICIÓN, EL ÁNGEL DE LA GUARDA DE LA MONTAÑA LA MANDÓ
A BUSCAR Y LE REVELÓ EL MAL QUE SU MADRE LE DESEABA: ENFERMARSE DE VIRUELAS Y MORIR.
ATERRADA, LA MONTAÑA ACUDIÓ A CASA DEL AWO DEL REY Y LE RELATÓ LO QUE LE SUCEDÍA. EL AWO
REALIZÓ UNA CONSULTA DE IFÁ Y LE PRESCRIBIÓ QUE USARA TRES ATUENDOS DIFERENTES DURANTE EL
DÍA PARA QUE LA ENFERMEDAD (LAS VIRUELAS) NO LA AFECTARA. LE INDICÓ QUE USARA UN HÁBITO
BLANCO POR LA MAÑANA, UNO ROJO AL MEDIODÍA Y OTRO NEGRO POR LA NOCHE. DESPUÉS DE REALIZAR
LA ROGACIÓN, DEBÍA LLEVAR ESTOS PAÑUELOS A SU MADRE. ENTERADA LA MADRE DE LA MONTAÑA DE
QUE EL PADRINO DE SU HIJA ERA EL AWO DEL REY, DECIDIÓ PERDONARLA Y LE ACONSEJÓ QUE
SIGUIERA UNA RUTINA ESPECÍFICA: VESTIRSE CON EL HÁBITO BLANCO POR LAS MAÑANAS, EL ROJO A
LAS DOS DEL DÍA Y EL NEGRO POR LAS NOCHES PARA PROTEGERSE DE SUS ENEMIGOS, ADEMÁS DE
BAÑARSE CON CAÑA DE LIMÓN. CABE DESTACAR QUE ESTA ROGACIÓN SE REALIZA CON TRES PAÑUELOS O
PEDAZOS DE TELA, UNO BLANCO, UNO ROJO Y OTRO NEGRO. SE PARTE UN EKO EN TRES PARTES Y SE
COLOCA UN PEDAZO EN CADA PAÑUELO. AQUELLOS QUE TIENEN A LA MADRE VIVA LOS COLOCARÁN EN LA
PUERTA DE LA CALLE DE LA CASA DE LA MADRE. MIENTRAS QUE AQUELLOS CUYAS MADRES HAN
FALLECIDO LOS COLOCARÁN EN LA PUERTA DE LA IGLESIA DE LAS MERCEDES. ENSENANZAS: DESAMOR Y
FALTA DE RESPETO: LA MONTAÑA, A PESAR DE SER HIJA DE LA VIRGEN DE LAS MERCEDES, ACTUABA
COMO UNA HIJA DESAMORADA. SU FALTA DE PREOCUPACIÓN POR COMPLACER A SU MADRE Y LAS
FRECUENTES FALTAS DE RESPETO ILUSTRAN CÓMO LAS RELACIONES PUEDEN VERSE AFECTADAS POR LA
INDIFERENCIA Y LA FALTA DE CONSIDERACIÓN. CONSECUENCIAS DE LA DESVIACIÓN: LA HISTORIA
RESALTA LAS CONSECUENCIAS DE APARTARSE DEL CAMINO CORRECTO. LA MALDICIÓN DE LA VIRGEN,
DESEANDO ENFERMEDAD Y MUERTE A SU PROPIA HIJA, SUBRAYA CÓMO LAS ACCIONES NEGATIVAS PUEDEN
ATRAER CONSECUENCIAS SEVERAS. BÚSQUEDA DE AYUDA Y CONSEJO: ANTE LA ADVERSIDAD, LA MONTAÑA
BUSCÓ LA AYUDA DEL AWO DEL REY, REVELANDO LA IMPORTANCIA DE BUSCAR ORIENTACIÓN Y APOYO
CUANDO SE ENFRENTA A DESAFÍOS SIGNIFICATIVOS. LA CONSULTA DE IFA Y LA PRESCRIPCIÓN DE
ACCIONES ESPECIFICAS DEMUESTRAN CÓMO LA SABIDURÍA PUEDE PROPORCIONAR SOLUCIONES. PERDÓN Y
ORIENTACIÓN: LA MADRE, AL ENTERARSE DE QUE EL AWO DEL REY ERA EL PADRINO DE SU HIJA,
DECIDE PERDONARLA Y OFRECERLE ORIENTACIÓN SOBRE CÓMO PROTEGERSE DE LOS MALES. ESTE ASPECTO
DESTACA LA POSIBILIDAD DE REDENCIÓN Y CONSEJO INCLUSO DESPUÉS DE COMETER ERRORES. EN
RESUMEN, LA HISTORIA ENSEÑA SOBRE LAS CONSECUENCIAS DE LA FALTA DE AMOR Y RESPETO, LA
IMPORTANCIA DE BUSCAR AYUDA Y ORIENTACIÓN, EL VALOR DE LOS RITUALES Y LA PROTECCIÓN
ESPIRITUAL, ASÍ COMO LA POSIBILIDAD DE REDENCIÓN Y CONSEJO INCLUSO DESPUÉS DE COMETER
ERRORES.''',
  '95. EWE IKOKO MUJER DE ORÚNMILA.': '''PATAKI: EWE IKOKO, EN UN TIEMPO PASADO, FUE LA ESPOSA DE ORÚNMILA. SIN EMBARGO, SUS
ACCIONES Y OFENSAS LLEGARON A TAL EXTREMO QUE UN DÍA, CANSADO DE LA SITUACIÓN, ORÚNMILA
TOMÓ LA DECISIÓN DE SEPARARSE DE ELLA Y LA DESTERRÓ, ECHÁNDOLE SHEPE. ANTE ESTA RUPTURA,
EWE IKOKO, DESESPERADA POR RECUPERAR LA BENEVOLENCIA DE ORÚNMILA, BUSCÓ LA AYUDA DE
DIVERSAS PERSONAS PARA INTERCEDER EN SU FAVOR. CON EL TIEMPO, ORÚNMILA, MOVIDO POR LA
COMPASIÓN Y LA RESIGNACIÓN, ACCEDIÓ A PERDONAR A EWE IKOKO, PERO ESTABLECIÓ UNA CONDICIÓN
ESTRICTA: NO VOLVER A VIVIR JUNTOS. SIN EMBARGO, LE CONCEDIÓ LA GRACIA DE QUE TODOS LOS
EBOSES (OFRENDAS Y RITUALES) A PARTIR DE ESE MOMENTO SE ENVOLVIERAN CON SU ROPA,
ESPECÍFICAMENTE CON HOJAS DE MALANGA. ESTA DECISIÓN TENÍA COMO PROPÓSITO ASEGURAR QUE LAS
OFRENDAS FUERAN BIEN RECIBIDAS POR ORÚNMILA, A PESAR DE LA SEPARACIÓN. POR LO TANTO, LA
TRADICIÓN DE ENVOLVER LOS EBOSES EN HOJAS DE MALANGA SE ORIGINÓ COMO UN GESTO DE
RECONCILIACIÓN ENTRE ORÚNMILA Y EWE IKOKO, MARCANDO UN COMPROMISO SIMBÓLICO CON LA PAZ Y
LA ARMONÍA, AUNQUE LA CONVIVENCIA DIRECTA YA NO FUERA POSIBLE. ASÍ, CADA VEZ QUE SE
REALIZA UN EBÓ, SE RINDE HOMENAJE A ESTA HISTORIA, RECORDANDO LA IMPORTANCIA DE LA
RECONCILIACIÓN Y EL PERDÓN, INCLUSO EN MEDIO DE SITUACIONES DIFICILES. ENSEÑANZAS: EL
PODER DEL PERDÓN: A PESAR DE LAS OFENSAS, ORÚNMILA DEMOSTRÓ COMPASIÓN Y RESIGNACIÓN AL
PERDONAR A EWE IKOKO. ESTA PARTE DE LA HISTORIA DESTACA EL PODER DEL PERDÓN COMO UN ACTO
DE GENEROSIDAD Y LA CAPACIDAD DE SUPERAR CONFLICTOS. CONDICIONES PARA LA RECONCILIACIÓN:
LA IMPOSICIÓN DE CONDICIONES POR PARTE DE ORÚNMILA PARA EL PERDÓN MUESTRA LA IMPORTANCIA
DE ESTABLECER LÍMITES CLAROS AL BUSCAR LA RECONCILIACIÓN. ESTABLECER CONDICIONES PUEDE SER
UNA MANERA DE GARANTIZAR QUE LAS RELACIONES SEAN SALUDABLES Y RESPETUOSAS. COMPROMISO
SIMBÓLICO: LA CONDICIÓN DE ORÚNMILA DE QUE LOS EBOSES SE ENVUELVAN EN HOJAS DE MALANGA
COMO GESTO SIMBOLICO DESTACA LA IMPORTANCIA DE LOS RITUALES Y SIMBOLISMOS EN LA REPARACIÓN
DE RELACIONES. ESTE COMPROMISO SIMBÓLICO SIRVE COMO RECORDATORIO CONSTANTE DE LA HISTORIA
Y DEL COMPROMISO CON LA PAZ. EN RESUMEN, LA HISTORIA DE EWE IKOKO Y ORÚNMILA OFRECE
LECCIONES SOBRE RESPONSABILIDAD POR LAS ACCIONES, EL PODER DEL PERDÓN, LA IMPORTANCIA DE
ESTABLECER CONDICIONES CLARAS EN LA RECONCILIACIÓN, EL SIMBOLISMO EN LOS COMPROMISOS Y LA
BUSQUEDA DE APOYO EXTERNO EN MOMENTOS DIFICILES.''',
  '96. LOS INQUILINOS DEL GOBERNADOR.': '''PATAKI: HABIA UNA VEZ UN GOBERNADOR QUE POSEIA NUMEROSAS PROPIEDADES (ILES), Y EN CIERTA
OCASIÓN, TODOS SUS INQUILINOS SE SUBLEVARON Y SE NEGARON A PAGARLE LOS ALQUILERES. FRENTE
A ESTA SITUACIÓN, EL GOBERNADOR DECIDIÓ ACUDIR A LA CASA DE ORÚNMILA EN BUSCA DE
ORIENTACIÓN. EN LA CONSULTA DE IFÁ, ORÚNMILA LE REVELÓ ESTE IFA Y RECOMENDÓ LA REALIZACIÓN
DE UN EBBO QUE INVOLUCRABA SIETE AKUKO (GALLOS), TIERRAS DE LAS ESQUINAS DE LOS ILES,
ENTRE OTROS ELEMENTOS. POSTERIORMENTE, SE LLEVÓ A CABO EL RITUAL, DONDE SE OFRECIÓ UN
AKUKO A ESHU, OTRO A OGGÚN, Y DOS A YEMAYÁ. ADEMÁS, SE COLOCÓ UNO EN CADA ESQUINA DE SU
CASA Y EL ÚLTIMO EN LA PUERTA. ESTA CEREMONIA ESTABA DESTINADA A CAMBIAR LA PERSPECTIVA DE
LOS INQUILINOS Y, AL VER ESTAS OFRENDAS Y RITUALES, SINTIERON UN TEMOR PROFUNDO, CAMBIANDO
SU ACTITUD Y DECIDIENDO PAGAR LOS ALQUILERES POR TEMOR A LAS POSIBLES CONSECUENCIAS, COMO
LA PRESENCIA DE LA SANGRE DERRAMADA EN EL RITUAL. BÚSQUEDA DE SOLUCIONES ESPIRITUALES:
ANTE LOS DESAFÍOS Y CONFLICTOS, LA HISTORIA DESTACA LA IMPORTANCIA DE RECURRIR A
SOLUCIONES ESPIRITUALES. EL GOBERNADOR, AL ENFRENTAR LA INSUBORDINACIÓN DE SUS INQUILINOS,
BUSCÓ LA AYUDA DE ORÚNMILA Y SE SOMETIÓ A LAS INDICACIONES DE IFÁ PARA RESOLVER LA
SITUACIÓN. USO DE LA SABIDURÍA Y LA ESTRATEGIA: LA HISTORIA RESALTA LA SABIDURÍA DE
ORÚNMILA AL PROPORCIONAR UNA SOLUCIÓN ESTRATÉGICA AL GOBERNADOR. LA UBICACIÓN ESPECÍFICA
DE LAS OFRENDAS, COMO EN LAS ESQUINAS Y LA PUERTA, MOSTRÓ UNA COMPRENSIÓN PROFUNDA DE CÓMO
INFLUIR EN LA PERCEPCIÓN Y EL COMPORTAMIENTO DE LOS INQUILINOS. TEMOR Y RESPETO COMO
INSTRUMENTOS DE CAMBIO: LA REACCIÓN DE LOS INQUILINOS AL TEMOR DE LAS POSIBLES
CONSECUENCIAS, COMO LA SANGRE DERRAMADA EN EL RITUAL, DESTACA CÓMO EL TEMOR Y EL RESPETO
PUEDEN SER PODEROSOS INSTRUMENTOS DE CAMBIO EN LAS ACTITUDES Y COMPORTAMIENTOS DE LAS
PERSONAS. EN RESUMEN, ESTA HISTORIA ENSEÑA SOBRE LA IMPORTANCIA DE LA ESPIRITUALIDAD EN LA
RESOLUCIÓN DE CONFLICTOS, EL PODER DE LOS RITUALES Y OFRENDAS, EL USO DE LA SABIDURÍA
ESTRATEGICA, LA INFLUENCIA DEL TEMOR Y EL RESPETO, Y LAS CONSECUENCIAS DE LAS ACCIONES EN
LA TOMA DE DECISIONES Y EL CAMBIO DE COMPORTAMIENTO.''',
  '97. ORÚNMILA DESMOCHADOR DE PALMAS.': '''PATAKI: EN UNA OCASIÓN, ORÚNMILA, QUE DESEMPEÑABA EL OFICIO DE DESMOCHAR PALMAS, SE
ENCONTRABA ENCARAMADO EN UNA DE ELLAS CUANDO, INESPERADAMENTE, PERDIÓ EL EQUILIBRIO Y CAYÓ
DESDE UNA GRAN ALTURA. EN EL INSTANTE PREVIO A TOCAR EL SUELO, DE MANERA SORPRENDENTE, EL
OKPELE SE DESLIZÓ DE SU BOLSILLO Y ATERRIZÓ SOBRE ÉL, EVITÁNDOLE CUALQUIER DAÑO. ESTE
EPISODIO ASOMBROSO NO SOLO RESALTA LA DESTREZA Y HABILIDAD DE ORÚNMILA EN EL EJERCICIO DE
SUS LABORES COMO DESMOCHADOR DE PALMAS, SINO TAMBIÉN REVELA UNA CONEXIÓN ESPECIAL CON EL
OKPELE, UN INSTRUMENTO ADIVINATORIO CRUCIAL EN LA TRADICIÓN YORUBA. LA PRESENCIA DE ESTE
OBJETO EN EL MOMENTO PRECISO, COMO SI TUVIERA VIDA PROPIA, SUGIERE UNA PROTECCIÓN DIVINA O
LA INTERVENCIÓN DE FUERZAS ESPIRITUALES. ENSEÑANZAS: PROTECCIÓN DIVINA EN MOMENTOS
CRÍTICOS: LA HISTORIA DE ORÚNMILA Y LA CAÍDA DESDE LA PALMA RESALTA LA IDEA DE QUE,
INCLUSO EN LOS MOMENTOS MÁS CRÍTICOS O PELIGROSOS DE LA VIDA, LA PROTECCIÓN DIVINA PUEDE
INTERVENIR. LA PRESENCIA DEL OKPELE EN EL MOMENTO JUSTO SIMBOLIZA LA CONEXIÓN ESPECIAL
ENTRE LO ESPIRITUAL Y LO HUMANO, OFRECIENDO SALVAGUARDA CUANDO MÁS SE NECESITA.
IMPORTANCIA DE LAS HERRAMIENTAS ESPIRITUALES: LA HISTORIA DESTACA LA IMPORTANCIA DE LAS
HERRAMIENTAS ESPIRITUALES, COMO EL OKPELE, EN LA VIDA COTIDIANA. ESTAS HERRAMIENTAS NO
SOLO CUMPLEN FUNCIONES PRÁCTICAS, COMO LA ADIVINACIÓN, SINO QUE TAMBIÉN PUEDEN ACTUAR COMO
MEDIADORES DE LA INTERVENCIÓN DIVINA, BRINDANDO ORIENTACIÓN Y PROTECCIÓN. CONECTIVIDAD
ESPIRITUAL: LA HISTORIA SUBRAYA LA IDEA DE UNA CONEXIÓN ESPIRITUAL CONSTANTE. EL OKPELE,
COMO UN SIMBOLO DE ESTA CONEXIÓN, NO SOLO ES UNA HERRAMIENTA ADIVINATORIA, SINO TAMBIÉN UN
MEDIO A TRAVÉS DEL CUAL LO ESPIRITUAL PUEDE MANIFESTARSE EN EL MUNDO MATERIAL.
RECONOCIMIENTO DE LA INTERVENCIÓN DIVINA: ES ESENCIAL RECONOCER Y VALORAR LOS SIGNOS DE
INTERVENCIÓN DIVINA EN NUESTRAS VIDAS. LA HISTORIA NOS INVITA A REFLEXIONAR SOBRE LOS
EVENTOS QUE PARECEN MILAGROSOS O INEXPLICABLES, RECORDÁNDONOS QUE A VECES LA GUÍA Y
PROTECCIÓN ESPIRITUAL SE MANIFIESTAN DE MANERAS SORPRENDENTES. EN CONJUNTO, ESTAS
LECCIONES NOS INSTAN A ESTAR CONSCIENTES DE LO ESPIRITUAL EN NUESTRAS VIDAS DIARIAS,
VALORAR LAS HERRAMIENTAS ESPIRITUALES Y RECONOCER LA PRESENCIA DE LA PROTECCIÓN DIVINA,
ESPECIALMENTE EN MOMENTOS CRÍTICOS O INESPERADOS.''',
  '98. LOS TRES HERMANOS.': '''PATAKI: HABÍA UNA VEZ TRES HERMANOS, CADA UNO CON SU PROPIO CAMINO EN LA VIDA. UNO DE
ELLOS ERA UN TALENTOSO ARTISTA, EL SEGUNDO SE DEDICABA A LA CAZA, MIENTRAS QUE EL TERCERO
EJERCÍA COMO COMERCIANTE. SIN EMBARGO, ESTE ÚLTIMO HERMANO VIVÍA CONSTANTEMENTE ABRUMADO
POR LA TRISTEZA, YA QUE ENFRENTABA CONFLICTOS CON CASI TODO EL MUNDO, INCLUSO CON SU
PROPIA FAMILIA. DECIDIO TOMAR UNA DRÁSTICA DECISIÓN Y SE TRASLADO A UN LUGAR DISTANTE SIN
QUE NADIE SE PERCATARA DE SU PARTIDA. AL LLEGAR A ESTE NUEVO DESTINO, OPTÓ POR CAMBIAR SU
NOMBRE. DADA SU INTELIGENCIA Y HABILIDADES COMERCIALES, SE ESTABLECIÓ EN ESTE NUEVO LUGAR
Y, PARA SORPRESA DE MUCHOS, COMENZÓ A PROSPERAR RÁPIDAMENTE EN EL ÁMBITO COMERCIAL. CON EL
PASO DEL TIEMPO, EN SU PUEBLO NATAL COMENZARON A BUSCARLO PARA QUE RECLAMARA UNA GRAN
HERENCIA QUE LE PERTENECÍA, PERO NO LOGRARON LOCALIZARLO. FUE ENTONCES CUANDO UNA PERSONA,
SIN SABER EXACTAMENTE CÓMO, INDICÓ QUE HABÍA VISTO A ALGUIEN IDÉNTICO AL INDIVIDUO QUE
ESTABAN BUSCANDO EN OTRO PUEBLO. CON LA ESPERANZA DE ENCONTRARLO, ENVIARON A UN HOMBRE CON
LA TAREA DE LOCALIZARLO Y CONVENCERLO DE REGRESAR PARA RECLAMAR LA HERENCIA. AUNQUE FUE UN
DESAFÍO, ESTE HOMBRE LOGRÓ IDENTIFICAR AL BUSCADO Y PERSUADIRLO PARA QUE REGRESARA A SU
TIERRA NATAL. CUANDO FINALMENTE VOLVIÓ, RECIBIÓ LA HERENCIA QUE LE CORRESPONDÍA. DESDE ESE
MOMENTO, VIVIÓ UNA VIDA LLENA DE FELICIDAD Y ALEGRÍA JUNTO A SU PUEBLO. SE ATRIBUYÓ A ESHU
EL MÉRITO DE HABER ENCONTRADO AL PERDIDO, POR LO QUE EL GALLO DEL SACRIFICIO DEL RITUAL SE
LE OFRECIÓ A ESHU COMO MUESTRA DE AGRADECIMIENTO. ENSENANZAS: SUPERACIÓN PERSONAL: EL
TERCER HERMANO ENFRENTABA DESAFÍOS Y CONFLICTOS EN SU ENTORNO, PERO EN LUGAR DE
RESIGNARSE, DECIDIÓ CAMBIAR SU VIDA. LA IMPORTANCIA DEL CAMBIO: A VECES, CAMBIAR DE
ENTORNO Y ADOPTAR UN ENFOQUE DIFERENTE PUEDE TENER UN IMPACTO SIGNIFICATIVO EN LA VIDA DE
UNA PERSONA. EL CAMBIO DE NOMBRE Y LA REUBICACIÓN PERMITIERON AL COMERCIANTE DEJAR ATRÁS
LAS DIFICULTADES Y CONSTRUIR UNA NUEVA REALIDAD. BÚSQUEDA DE LA FELICIDAD: LA HISTORIA
DESTACA QUE LA BÚSQUEDA DE LA FELICIDAD Y LA PAZ INTERIOR A VECES IMPLICA DISTANCIARSE DE
SITUACIONES NEGATIVAS. AL ALEJARSE DE SU PUEBLO NATAL, EL COMERCIANTE ENCONTRÓ UN LUGAR
DONDE PUDO FLORECER Y EXPERIMENTAR LA ALEGRÍA. AYUDA DE OTROS: LA INTERVENCIÓN DEL HOMBRE
ENVIADO PARA PERSUADIR AL COMERCIANTE DE REGRESAR MUESTRA LA IMPORTANCIA DE LA AYUDA Y EL
APOYO DE OTROS EN MOMENTOS CRUCIALES. A VECES, UNA MANO AMIGA PUEDE MARCAR LA DIFERENCIA
EN LA VIDA DE ALGUIEN. RECONCILIACIÓN Y CONEXIÓN: A PESAR DE LA DISTANCIA Y LA APARENTE
RUPTURA, EL REGRESO DEL COMERCIANTE PERMITIÓ UNA RECONCILIACIÓN CON SU PUEBLO, LA CONEXIÓN
CON SUS RAÍCES Y LA ACEPTACIÓN DE LA HERENCIA NO SOLO LE BRINDARON BENEFICIOS MATERIALES,
SINO TAMBIÉN UNA RELACIÓN RESTAURADA CON SU COMUNIDAD. RECONOCIMIENTO DE ESHU: LA
ATRIBUCIÓN DEL MÉRITO A ESHU POR HABER ENCONTRADO AL PERDIDO RESALTA LA IMPORTANCIA DE
RECONOCER LAS FUERZAS ESPIRITUALES Y DE EXPRESAR GRATITUD POR LAS BENDICIONES RECIBIDAS.
EN RESUMEN, ESTA HISTORIA ENFATIZA LA CAPACIDAD DE SUPERACIÓN, LA IMPORTANCIA DE LA
BÚSQUEDA DE LA FELICIDAD, LA INFLUENCIA POSITIVA DEL CAMBIO, EL VALOR DE LA AYUDA MUTUA,
LA RECONEXIÓN CON LAS RAÍCES Y LA GRATITUD HACIA LAS FUERZAS ESPIRITUALES.''',
  '99. OSHUN Y EL IDEU.': '''PATAKI: OSHUN, LA HERMANA DE YEMAYA, HABÍA TENIDO UNA DISPUTA CON ELLA Y DECIDIÓ
ESTABLECER SU PROPIO REINO. A SU PASO, SE FORMABAN RIOS. EN UN ENCUENTRO CON INLE,
FORMARON SU REINO JUNTOS, Y DE ESA UNIÓN NACIÓ UN HIJO. SIN EMBARGO, INLE NO SE PREOCUPABA
POR OSHUN, Y ASÍ COMENZÓ SU MISERIA. ENFRENTANDO DIFICULTADES Y SINTIÉNDOSE ABANDONADA,
OSHUN LLORABA POR SU MALA SUERTE. UN DÍA, SHANGO LLEGÓ A LA CASA DE OSHUN Y, AL VERLA TAN
TRISTE Y DESATENDIDA, LE PREGUNTÓ LA CAUSA. OSHUN LE CONTÓ SU SITUACIÓN, Y SHANGO LE
RECOMENDÓ QUE FUERA A CASA DE ORÚNMILA. AUNQUE INICIALMENTE SE NEGÓ DEBIDO A LA FALTA DE
UN VESTIDO ADECUADO, SHANGO LA CONVENCIÓ DE QUE FUERA. ORÚNMILA LE REALIZÓ UN OSODE Y LE
REVELÓ LA SITUACIÓN. CONSIDERANDO A INLE, LE DIJO: "DILE A TU ESPOSO QUE VENGA A MI CASA,
DESEO HABLAR CON ÉL: OSHUN REGRESÓ SOLA, YA QUE INLE SE NEGÓ A ACOMPAÑARLA. ORÚNMILA LO
MANDÓ A BUSCAR CON ELEGBA, PERO INLE TAMPOCO LO VISITÓ. ANTE ESE DESPRECIO, ORÚNMILA MARCÓ
ROGACIÓN PARA OSHUN, CONSISTENTE EN REALIZAR TRES EBO EN EL MISMO DÍA. EL PRIMER EBO
INCLUÍA UN AKUKO, GIO GIO, UN GUIRITO, EYA TUTO META, EKI, EYA, EPO. ORÚNMILA LO LLEVÓ Y
LE INDICÓ QUE LO COLOCARA CERCA DE UN ANTIGUO CASTILLO, ADVIRTIÉNDOLE QUE NO SE ASUSTARA.
TRES HERMANOS TRILLIZOS Y UN IDEU VIVÍAN ALLÍ. AL VER A OSHUN, SURGIERON CELOS ENTRE
ELLOS, DESENCADENANDO UNA PELEA MORTAL POR SU ATENCIÓN. ASUSTADA, OSHUN REGRESÓ
RÁPIDAMENTE Y CONTÓ LO SUCEDIDO A ORÚNMILA. ESTE LE HIZO UN SEGUNDO EBO CON AKUKO, GIO
GIO, ELEGUEDE, ETC., ORDENÁNDOLE LLEVARLO AL MISMO LUGAR. AUNQUE TEMEROSA, OSHUN FUE
CONVENCIDA. AL PONER SU EBO NUEVAMENTE, LOS TRES HOMBRES RESTANTES SE ENFRENTARON ENTRE
ELLOS, MURIENDO UNO ANTE LOS OJOS DE OSHUN, QUIEN VOLVIÓ HORRORIZADA A CONTARLE TODO A
ORÚNMILA. ESTE LE ORDENÓ HACER UN TERCER EBO CON OWUNKO, AKUKO, 16 EYELE FUN FUN, UNA
MANTA AMARILLA, UNA FREIDORA, UNA PLUMA DE LORO, UN GUIRITO, ASHO FUN FUN, ETC. Y LLEVARLO
AL MISMO LUGAR QUE LOS ANTERIORES. MUY ASUSTADA, OSHUN REGRESÓ AL CASTILLO. EL IDEU SALIÓ
A SU ENCUENTRO Y LE DIJO QUE NO HUYERA, YA QUE ALLÍ ESTABA SU FELICIDAD Y LAS RIQUEZAS DEL
PALACIO SERÍAN SUYAS. AL MORIR POR SUS HERIDAS, LE DEJÓ TODO, CUMPLIÉNDOSE LA PROFECÍA DE
ORÚNMILA. NOTA: EN EL REGISTRO, ORÚNMILA LE INDICÓ QUE HICIERA TRES EBO EN EL MISMO DÍA
PARA CAMBIAR SU SUERTE Y ALCANZAR RIQUEZAS Y ESTABILIDAD EN LA VIDA. ENSEÑANZAS:
SUPERACIÓN PERSONAL: A PESAR DE LOS DESAFÍOS Y LA TRISTEZA QUE ENFRENTABA, OSHUN TOMÓ LA
INICIATIVA DE CAMBIAR SU DESTINO. SU DECISIÓN DE BUSCAR AYUDA MUESTRA LA IMPORTANCIA DE LA
SUPERACIÓN PERSONAL FRENTE A LAS ADVERSIDADES. IMPORTANCIA DEL CAMBIO: OSHUN EXPERIMENTÓ
UN CAMBIO SIGNIFICATIVO AL ALEJARSE DE SU ENTORNO ORIGINAL. CAMBIAR SU NOMBRE Y
TRASLADARSE A UN NUEVO LUGAR CONTRIBUYÓ A SU PROSPERIDAD Y FELICIDAD. BÚSQUEDA DE LA
FELICIDAD: LA HISTORIA DESTACA LA IMPORTANCIA DE BUSCAR LA FELICIDAD Y LA PAZ INTERIOR,
INCLUSO SI ESO IMPLICA DISTANCIARSE DE SITUACIONES NEGATIVAS. OSHUN ENCONTRÓ SU ALEGRÍA AL
EMBARCARSE EN UN NUEVO CAMINO. AYUDA DE OTROS: LA INTERVENCIÓN DE SHANGO Y ORÚNMILA
DESTACA LA IMPORTANCIA DE LA AYUDA Y EL APOYO DE OTROS EN MOMENTOS CRÍTICOS. A VECES, UNA
GUÍA EXTERNA PUEDE MARCAR LA DIFERENCIA EN LA VIDA DE ALGUIEN. RECONOCIMIENTO DE LO
ESPIRITUAL: LA HISTORIA SUBRAYA LA INFLUENCIA DE LO ESPIRITUAL EN LA VIDA COTIDIANA. EL
PAPEL DE ORÚNMILA Y ESHU EN LA RESOLUCIÓN DE LOS PROBLEMAS DE OSHUN RESALTA LA IMPORTANCIA
DE RECONOCER Y VALORAR LAS FUERZAS ESPIRITUALES EN NUESTRAS VIDAS. ACEPTACIÓN DE LA GUÍA
ESPIRITUAL: OSHUN INICIALMENTE SE RESISTIÓ A LA ORIENTACIÓN DE ORÚNMILA DEBIDO A LA FALTA
DE UN VESTIDO APROPIADO. SIN EMBARGO, FINALMENTE ACEPTÓ, DESTACANDO LA IMPORTANCIA DE
ESTAR ABIERTOS A LA GUÍA ESPIRITUAL INCLUSO EN MOMENTOS DE VULNERABILIDAD. CONSECUENCIAS
DE LAS DECISIONES: LA HISTORIA MUESTRA CÓMO LAS DECISIONES DE OSHUN Y LA ACTITUD DE INLE
TUVIERON CONSECUENCIAS SIGNIFICATIVAS EN SUS VIDAS. RESALTA LA IMPORTANCIA DE TOMAR
DECISIONES INFORMADAS Y CONSIDERAR LAS REPERCUSIONES. EN RESUMEN, ESTA HISTORIA ENSEÑA
SOBRE LA IMPORTANCIA DE LA SUPERACIÓN PERSONAL, LA BÚSQUEDA DE LA FELICIDAD, LA AYUDA
MUTUA, LA RECONCILIACIÓN, EL RECONOCIMIENTO DE LO ESPIRITUAL Y LAS CONSECUENCIAS DE
NUESTRAS DECISIONES EN LA VIDA.''',
  '100. ELEGBA EL HIJO DE OLOFIN.': '''PATAKI: EL HIJO DE OLOFIN SE ENCONTRABA SUMAMENTE APESADUMBRADO DEBIDO A LA GRAVE
ENFERMEDAD DE SU PADRE, PARA LA CUAL NO PARECÍA HABER CURA. ELEGBÁ, AL PERCATARSE DE SU
TRISTEZA, LE PREGUNTÓ LA RAZÓN DE SU PESAR. EL JOVEN RESPONDIÓ QUE SU PADRE ESTABA
GRAVEMENTE ENFERMO Y LOS MÉDICOS AFIRMABAN QUE NO HABÍA REMEDIO. ELEGBÁ LE PROPUSO: "¿Y
QUÉ ME DARÍAS SI LOGRO CURAR A TU PADRE?" EL MUCHACHO CONTESTÓ: "LO QUE DESEES". ELEGBÁ LE
INDICÓ: "ENTONCES, VE A LA ORILLA DE LA PLAYA. ALLÍ ENCONTRARÁS A UNA MUJER CORPULENTA
SENTADA SOBRE UN PILÓN. BAJO EL PILÓN SE ENCUENTRA EL SECRETO PARA CURAR A TU PADRE. SIN
EMBARGO, ANTES TENDRÁS QUE LUCHAR CON LA MUJER Y DERRIBARLA DEL PILÓN PARA OBTENER EL
SECRETO" EL HIJO DE OLOFIN FUE A LA PLAYA, LIBRÓ UNA BATALLA CON LA MUJER OBESA, LA
VENCIÓ, TOMÓ EL SECRETO Y SE LO LLEVÓ A SU PADRE, QUIEN SE CURÓ. AL TERCER DÍA, EL HIJO DE
OLOFIN BUSCÓ A ELEGBÁ PARA EXPRESARLE SU GRATITUD Y OFRECERLE LO QUE DESEARA. CUANDO SE
ENCONTRÓ CON ELEGBÁ, ESTE LE DIJO: "SOLO DESEO QUE OLOFIN ME CONCEDA ESTAR SIEMPRE DETRÁS
DEL SHILEKUN DEL ILE, DE MANERA QUE TODO AQUEL QUE ENTRE Y SALGA ME SALUDE PRIMERO A MÍ":
EL HIJO DE OLOFIN HABLÓ CON SU PADRE, QUIEN CONCEDIÓ A ELEGBÁ LO QUE SOLICITABA. NOTA: EL
SECRETO ERA EÑÍ EYELE. ENSEÑANZAS: SACRIFICIO POR EL BIENESTAR DE OTROS: ELEGBA ESTABA
DISPUESTO A HACER LO QUE FUERA NECESARIO PARA CURAR A SU PADRE. SU DISPOSICION PARA LUCHAR
Y OBTENER EL SECRETO MUESTRA EL SACRIFICIO PERSONAL EN BENEFICIO DE UN SER QUERIDO. LA
IMPORTANCIA DE LA DETERMINACIÓN: A PESAR DE LOS DESAFÍOS Y LA DIFICULTAD DE LA TAREA,
ELEGBA DEMOSTRÓ DETERMINACIÓN Y VALENTÍA AL ENFRENTARSE A LA MUJER EN LA PLAYA. SU
PERSISTENCIA CONDUJO AL ÉXITO Y LA CURACIÓN DE SU PADRE. RECOMPENSAS POR LA AYUDA
DESINTERESADA: ELEGBÁ, AL AYUDAR A CURAR AL PADRE, NO PIDIÓ RIQUEZAS O FAVORES
EXTRAVAGANTES. SU MODESTA SOLICITUD DE ESTAR DETRÁS DEL SHILEKUN DEL ILE RESALTA LA IDEA
DE QUE LAS RECOMPENSAS POR ACTOS DESINTERESADOS NO SIEMPRE SON MATERIALES, SINO QUE PUEDEN
SER GESTOS SIMBÓLICOS DE RESPETO. EL PAPEL DE LA SABIDURÍA EN LA RESOLUCIÓN DE PROBLEMAS:
ELEGBÁ, AL PROPORCIONAR LA SOLUCIÓN PARA LA CURACIÓN, MOSTRÓ SU SABIDURÍA Y CONOCIMIENTO.
LA HISTORIA ENFATIZA LA IMPORTANCIA DE RECURRIR A LA SABIDURÍA Y ORIENTACIÓN EN MOMENTOS
DE DIFICULTAD. EN RESUMEN, ESTA HISTORIA SUBRAYA VALORES COMO EL SACRIFICIO, LA
DETERMINACIÓN, LA SABIDURÍA, LA GRATITUD Y EL CUMPLIMIENTO DE PROMESAS, BRINDANDO
LECCIONES SIGNIFICATIVAS SOBRE LA CONDUCTA ÉTICA Y LAS RECOMPENSAS DE ACCIONES POSITIVAS.''',
  '101. LA GENTE CON PICAZON.': '''PATAKI: HUBO UN TIEMPO EN EL QUE, CUANDO LA GENTE EXPERIMENTABA PICAZÓN, SOLÍAN DIRIGIRSE
A UNA LOMA CERCANA PARA RASCARSE. LA NOTICIA DE ESTE REMEDIO SE EXTENDIÓ RÁPIDAMENTE, Y
PRONTO LA CANTIDAD DE PERSONAS QUE ACUDÍAN A LA LOMA AUMENTÓ CONSIDERABLEMENTE. ANTE ESTA
SITUACIÓN, LA LOMA DECIDIÓ CONSULTAR A ORÚNMILA PARA ENTENDER LO QUE ESTABA SUCEDIENDO.
ORÚNMILA, A TRAVÉS DE UN RITUAL DE ADIVINACIÓN CONOCIDO COMO OSODE, EXAMINÓ LA SITUACIÓN
DE LA LOMA Y REVELÓ UN IFÁ ESPECÍFICO QUE INDICABA LA NECESIDAD DE REALIZAR UN EBBO CON
OTAS (PIEDRAS) Y UTILIZAR COLORES ESPECÍFICOS A SU ALREDEDOR. LA LOMA, SIGUIENDO LAS
INDICACIONES DE ORÚNMILA, LLEVÓ A CABO EL RITUAL CON LAS OTAS Y LOS COLORES RECOMENDADOS.
COMO RESULTADO, LAS OTAS COMENZARON A MULTIPLICARSE, CREANDO UNA BARRERA QUE EVENTUALMENTE
HIZO QUE FUERA IMPOSIBLE PARA LA GENTE LLEGAR A LA CIMA DE LA LOMA. LA SITUACIÓN SE VOLVIÓ
TAN INTENSA QUE LA LOMA SE CONVIRTIÓ EN UN LUGAR INACCESIBLE PARA AQUELLOS QUE BUSCABAN
ALIVIO PARA SUS PICAZONES. ESTE EPISODIO DESTACA LA PODEROSA INFLUENCIA DE LO ESPIRITUAL
EN LA VIDA COTIDIANA Y CÓMO LAS ACCIONES GUIADAS POR LA SABIDURÍA DE ORÚNMILA PUEDEN TENER
CONSECUENCIAS SIGNIFICATIVAS. ADEMÁS, LA HISTORIA SUBRAYA LA IMPORTANCIA DE SEGUIR LAS
INDICACIONES DE LOS RITUALES Y RESALTA CÓMO LAS SOLUCIONES APARENTEMENTE SIMPLES PUEDEN
TRANSFORMARSE EN SITUACIONES COMPLEJAS CON EL TIEMPO. CONSECUENCIAS DE LA ACCIÓN
ESPIRITUAL: LA HISTORIA RESALTA CÓMO LAS ACCIONES ESPIRITUALES, EN ESTE CASO, EL RITUAL DE
LA LOMA CON LAS OTAS Y LOS COLORES, TUVIERON CONSECUENCIAS SIGNIFICATIVAS EN LA VIDA
COTIDIANA DE LA GENTE. MUESTRA CÓMO LO ESPIRITUAL PUEDE INFLUIR EN LO TANGIBLE. RESPETO A
LO SAGRADO: LA LOMA, AL CONSULTAR A ORÚNMILA Y SEGUIR SUS INSTRUCCIONES, MUESTRA UN
RESPETO POR LO SAGRADO Y RECONOCE LA IMPORTANCIA DE BUSCAR ORIENTACIÓN ESPIRITUAL PARA
RESOLVER PROBLEMAS APARENTEMENTE MUNDANOS. EFECTOS INESPERADOS: A PESAR DE QUE LA
INTENCIÓN ORIGINAL PODRÍA HABER SIDO ALIVIAR LAS PICAZONES DE LA GENTE, LAS CONSECUENCIAS
INESPERADAS DE LAS ACCIONES ESPIRITUALES LLEVARON A UN RESULTADO QUE AFECTÓ EL ACCESO A LA
LOMA. ESTO DESTACA LA COMPLEJIDAD DE LAS INTERACCIONES ENTRE LO ESPIRITUAL Y LO MATERIAL.
NECESIDAD DE EQUILIBRIO: LA MULTIPLICACION DE OTAS Y LA IMPOSIBILIDAD DE QUE LA GENTE
LLEGARA A LA LOMA ILUSTRAN LA NECESIDAD DE EQUILIBRIO EN LAS ACCIONES ESPIRITUALES.
DEMUESTRA QUE INCLUSO SOLUCIONES BIEN INTENCIONADAS PUEDEN TENER CONSECUENCIASQUE
REQUIEREN CONSIDERACIÓN. EN RESUMEN, LA HISTORIA NOS ENSEÑA SOBRE LA IMPORTANCIA DE LA
SABIDURÍA ESPIRITUAL, EL RESPETO A LO SAGRADO Y CÓMO LAS ACCIONES EN EL ÁMBITO ESPIRITUAL
PUEDEN TENER UN IMPACTO PROFUNDO EN LA REALIDAD TANGIBLE, CON RESULTADOS QUE A VECES
PUEDEN SER IMPREVISTOS.''',
  '102. LA CONFIANZA DEL OBA.': '''PATAKI: EJÍOGBE, A PESAR DE TENER LA CONFIANZA DEL REY (OBÁ), SE VIO ENVUELTO EN
CONFLICTOS CON ÉL DEBIDO A LAS INTRIGAS DE SUS SIETE ARAYÉS. EN UNA OCASIÓN, SALIÓ A CAZAR
Y OBTUVO UN AWÁNÍ Y UN ELUBÓ, ANUNCIANDO SU ÉXITO PARA QUE LOS RECOGIERAN. SIN EMBARGO,
ESHU ESCONDIÓ LA PRESA, Y CUANDO FUERON A BUSCARLA, NO LA ENCONTRARON, LO QUE PROVOCÓ QUE
EL OBÁ LO CONSIDERARA UN MENTIROSO. TRES DÍAS DESPUÉS, EN OTRA CACERÍA, EJÍOGBE MATÓ A UN
AYANAKÚ (ELEFANTE), PERO NUEVAMENTE ENFRENTÓ LA DESCONFIANZA Y LA ACUSACIÓN DE MENTIR AL
DAR CUENTA DE SU LOGRO. LA NATURALEZA ESQUIVA DEL AYANAKÚ, QUE NUNCA MUERE EN EL MISMO
LUGAR, GENERÓ UNA GRAN CONTROVERSIA, FORZANDO A EJOGBE A HUIR Y REFUGIARSE EN LAS
MONTANAS, DONDE PASÓ VARIOS AÑOS. CUANDO MURIÓ EL OBÁ, EL GOBIERNO SE REUNIÓ PARA ELEGIR A
UN NUEVO LÍDER. EJÍOGBE, POR SU PARECIDO CON EL DIFUNTO REY, FUE BUSCADO EN LAS MONTAÑAS.
AL ENCONTRARLO, SU DESCONFIANZA LO HIZO HUIR, PERO LOS BUSCADORES LE MOSTRARON LA CORONA
(ADE) Y, A PESAR DE SU ESCEPTICISMO, LOGRARON CONVENCERLO. VISTIERON A EJÍOGBE CON SUS
ROPAJES Y LE COLOCARON LA CORONA, AUNQUE SUS SIETE ARAYÉS ESTABAN CELEBRANDO, ELOGIÁNDOLO
Y ASEGURÁNDOLE QUE SIEMPRE HABÍA ACTUADO CORRECTAMENTE, Y QUE TODO LO QUE HABÍA CAZADO
ESTABA AL OTRO LADO DEL RÍO. EJÍOGBE, IGNORANDO LAS ALABANZAS DE LOS ARAYÉS ESE DÍA,
POSTERIORMENTE ORDENÓ QUE LES CORTARAN LAS CABEZAS (LERI) Y LOS CUELLOS (OTOKÚ) COMO
CASTIGO POR SUS INTRIGAS Y DESLEALTAD. ENSENANZAS: DESCONFIANZA E INTRIGA: LA NARRATIVA
DESTACA COMO LA DESCONFIANZA E INTRIGA PUEDEN SURGIR INCLUSO EN SITUACIONES EN LAS QUE SE
PRESUME CONFIANZA. LOS SIETE ARAYES DE EJÍOGBE REPRESENTAN LA DESCONFIANZA Y LA DISCORDIA
QUE PUEDEN INFILTRARSE EN RELACIONES APARENTEMENTE SOLIDAS. CONSECUENCIAS DE LA
DESLEALTAD: LA HISTORIA ILUSTRA LAS CONSECUENCIAS DE LA DESLEALTAD Y LA TRAICIÓN. LOS
ARAYÉS, AL SEMBRAR DUDAS SOBRE LA HONESTIDAD DE EJÍOGBE, GENERARON CONFLICTOS QUE LO
LLEVARON A HUIR Y REFUGIARSE EN LAS MONTAÑAS. SUPERACIÓN DE DESAFÍOS: A PESAR DE LOS
CONFLICTOS Y DESCONFIANZAS, EJOGBE TUVO QUE ENFRENTAR DESAFÍOS EN SU VIDA. SU HUIDA Y
POSTERIOR REGRESO COMO CANDIDATO AL TRONO DEMUESTRAN LA CAPACIDAD DE SUPERAR OBSTÁCULOS Y
ADAPTARSE A CIRCUNSTANCIAS CAMBIANTES. VALOR Y CONVICCIÓN: LA HISTORIA DESTACA EL VALOR Y
LA CONVICCIÓN DE EJÍOGBE. A PESAR DE LA DESCONFIANZA INICIAL, SE SOMETE AL PROCESO DE
ELECCIÓN DEL NUEVO LÍDER Y DEMUESTRA CORAJE AL ENFRENTARSE A LOS DESAFÍOS. RESPONSABILIDAD
Y CASTIGO: LA DECISIÓN DE EJÍOGBE DE CORTAR LAS CABEZAS DE SUS ARAYÉS SUBRAYA LA
RESPONSABILIDAD Y EL CASTIGO POR LAS ACCIONES DESLEALES. INDICA QUE, INCLUSO EN
SITUACIONES ESPIRITUALES O MÍSTICAS, LAS ACCIONES TIENEN CONSECUENCIAS Y SE ESPERA QUE SE
ASUMA LA RESPONSABILIDAD. EN RESUMEN, LA HISTORIA DE EJÍOGBE NOS BRINDA VALIOSAS LECCIONES
SOBRE LA CONFIANZA, LA DESLEALTAD, LA SUPERACIÓN DE DESAFÍOS, LA RESPONSABILIDAD Y LA
ACEPTACIÓN DE LA REALIDAD.''',
  '103. LAS CUATRO HIJAS DE OLOFIN.': '''PATAKI: OLOFIN TENÍA CUATRO HIJAS DE OLOFIN, Y TODAS EXPRESARON SU DESEO DE CASARSE CON
ORÚNMILA. LA PRIMERA HIJA, AL EMPRENDER LA BÚSQUEDA DE ORÚNMILA, SE ENCONTRÓ CON ESHU. AL
PREGUNTARLE POR ORÚNMILA, ESHU, EN SU CARACTERÍSTICO ESTILO JUGUETÓN, LE DIJO QUE ORÚNMILA
HABÍA FALLECIDO. CON GRAN TRISTEZA, LA HIJA DE OLOFIN TAMBIÉN SE MURIÓ. LA SEGUNDA HIJA,
ANSIOSA POR ENCONTRAR A ORÚNMILA, SE TOPÓ CON OGGUN. AL REALIZAR LA MISMA PREGUNTA, OGGUN
LE RESPONDIÓ DE MANERA SIMILAR, AFIRMANDO QUE ORÚNMILA YA NO ESTABA EN ESTE MUNDO.
DESALENTADA POR ESTA NOTICIA, LA SEGUNDA HIJA TAMBIEN SE MURIÓ. LA TERCERA HIJA SE
ENCONTRÓ CON INLE Y, AL PREGUNTARLE POR ORÚNMILA, RECIBIÓ LA MISMA RESPUESTA FATAL. INLE
LE DIJO QUE ORÚNMILA HABÍA PARTIDO DE ESTE MUNDO. SIGUIENDO EL DESTINO DE SUS HERMANAS, LA
TERCERA HIJA TAMBIÉN SE MURIÓ. LA ÚLTIMA HUA, LLAMADA OMO AYA LERUN, SE ENFRENTÓ A LA
MISMA SITUACIÓN. SIN EMBARGO, A DIFERENCIA DE SUS HERMANAS, DECIDIÓ NO DEJARSE LLEVAR POR
LA TRISTE NOTICIA Y CONTINUÓ SU CAMINO CON DETERMINACIÓN. PERSISTENTE, OMO AYA LERUN
FINALMENTE ENCONTRÓ A ORÚNMILA Y, CONTRA TODO PRONÓSTICO, SE CASÓ CON ÉL. ESTA HISTORIA
DESTACA LA IMPORTANCIA DE LA PERSEVERANCIA, LA FE Y LA DETERMINACIÓN INCLUSO EN MEDIO DE
LAS ADVERSIDADES. MIENTRAS QUE LAS TRES PRIMERAS HUAS SUCUMBIERON A LA DESESPERANZA AL
RECIBIR NOTICIAS DESALENTADORAS, LA ÚLTIMA HUA DEMOSTRÓ QUE LA VERDADERA RECOMPENSA VIENE
PARA AQUELLOS QUE PERSISTEN Y MANTIENEN VIVA LA ESPERANZA. EN ÚLTIMA INSTANCIA, OMO AYA
LERUN ENCONTRÓ LA FELICIDAD AL SEGUIR SU CAMINO CON VALENTÍA Y CONFIANZA EN SU DESTINO.
REZO: SHEKOMORI OMO ALABAADIFAFUN OMO AYERESHEKETIRI OMO EMERIONAGUN OMO AYA LORUN. EBO
AKUKO, ADIE MEYI, ERAN MALU, ISHERI YAREKE, OMI, EKU, EPO, OWO LA MEJO. NOTA: LA ERAN MALU
SE AMARRA CON YARAKO, SE CLAVA CON ISHERIEN LA MANIGUA O SABANA PARA QUE ALAKOSO SE LA
LLEVE. IRE AYA UMBO WA. ENSEÑANZAS: PERSEVERANCIA Y DETERMINACIÓN: LA ÚLTIMA HIJA, OMO AYA
LERUN, ENSEÑA LA IMPORTANCIA DE LA PERSEVERANCIA Y LA DETERMINACIÓN. A PESAR DE LAS
NOTICIAS DESALENTADORAS, NO SE RINDIÓ Y CONTINUÓ SU BÚSQUEDA, LO QUE FINALMENTE LA LLEVÓ
AL ÉXITO. FE EN EL DESTINO: LA HISTORIA DESTACA LA FE EN EL DESTINO Y LA CREENCIA DE QUE,
A PESAR DE LOS OBSTÁCULOS, LAS COSAS PUEDEN CAMBIAR. OMO AYA LERUN CONFIÓ EN QUE SU CAMINO
LA LLEVARÍA A ORÚNMILA A PESAR DE LAS APARENTES DIFICULTADES. NO DEJARSE DESANIMAR POR
RUMORES: LAS TRES PRIMERAS HIJAS, AL CREER EN LAS NOTICIAS DE ESHU, OGGUN Y INLE,
RESPECTIVAMENTE, SE DESANIMARON Y TOMARON DECISIONES PRECIPITADAS. LA HISTORIA ADVIERTE
SOBRE LOS PELIGROS DE DEJARSE LLEVAR POR RUMORES SIN VERIFICAR LA INFORMACIÓN. EN RESUMEN,
LA HISTORIA DE LAS HIJAS DE OLOFIN DESTACA LECCIONES VALIOSAS SOBRE LA PERSEVERANCIA, LA
FE EN EL DESTINO, LA IMPORTANCIA DE NO DEJARSE DESANIMAR POR RUMORES Y LA CONFIANZA EN LA
INTUICIÓN COMO GUÍA EN LA TOMA DE DECISIONES.''',
  '104. EL PACTO DE LA TIERRA Y LA MUERTE.': '''PATAKI: LA TIERRA Y LA MUERTE SELLARON UN PACTO DEBIDO A LA SITUACIÓN EN LA QUE SE
ENCONTRABAN. LA MUERTE NO TENÍA DÓNDE ENTERRAR LOS CUERPOS A LOS QUE ARREBATABA LA VIDA, Y
LA TIERRA, POR SU PARTE, SOPORTABA LA CARGA DE AQUELLOS QUE CAMINABAN SOBRE ELLA Y DE TODO
LO QUE PRODUCÍA, DISTRIBUYENDO A CADA SER LO QUE LE CORRESPONDÍA. EN ESTE CONTEXTO, LA
TIERRA ACEPTÓ EL PACTO PROPUESTO POR LA MUERTE, ESTABLECIENDO QUE A PARTIR DE ESE MOMENTO,
TODO EL MUNDO DEBERÍA PAGAR UN TRIBUTO QUE CONSISTIRÍA EN TODO LO QUE SE CONSUMIERA.
AQUELLOS QUE NO CUMPLIERAN CON ESTE TRIBUTO SERIAN RESPONSABILIDAD DE LA MUERTE, QUIEN SE
ENCARGARIA DE COBRAR SUS DEUDAS. ESTE ACUERDO ES LA RAZÓN POR LA CUAL LA TIERRA OCUPA UN
LUGAR FUNDAMENTAL, YA QUE TODOS DISFRUTAN DE SUS BENEFICIOS A PESAR DE QUE RARA VEZ SE
RECONOCE SU IMPORTANCIA. LA TIERRA PROPORCIONA PARA TODOS, SIENDO ADEMÁS EL HOGAR A DONDE
OLOFIN ENVÍA A TODOS SUS HIJOS. LA MUERTE AGREGÓ UNA CLÁUSULA AL PACTO, PROPONIENDO QUE SU
HERMANA, LA ENFERMEDAD, TAMBIÉN TUVIERA UN PAPEL EN ESTE ACUERDO. LA ENFERMEDAD SERÍA LA
ENCARGADA DE PREPARAR LOS FINES QUE SE PERSEGUÍAN. DE ESTA MANERA, EL PACTO ASEGURA QUE
TANTO RICOS COMO POBRES, REYES COMO HUMILDES, SABIOS COMO ORGULLOSOS, Y TODOS POR IGUAL,
PAGUEN LAS CONSECUENCIAS DE SUS ACCIONES. ENSENANZAS: INTERDEPENDENCIA Y EQUILIBRIO: LA
HISTORIA ILUSTRA LA NECESIDAD DE UN EQUILIBRIO EN LA INTERACCIÓN ENTRE LA TIERRA Y LA
MUERTE. AMBAS ENTIDADES DEPENDEN UNA DE LA OTRA PARA MANTENER LA ARMONÍA EN EL CICLO DE LA
VIDA Y LA MUERTE. RESPONSABILIDAD COMPARTIDA: EL PACTO ESTABLECIDO ENTRE LA TIERRA Y LA
MUERTE DESTACA LA IMPORTANCIA DE ASUMIR RESPONSABILIDADES COMPARTIDAS. LA TIERRA ACEPTA LA
CARGA DE PROPORCIONAR A TODOS, MIENTRAS QUE LA MUERTE SE ENCARGA DE COBRAR LOS TRIBUTOS DE
AQUELLOS QUE NO CUMPLEN. RECONOCIMIENTO DE LA IMPORTANCIA DE LA TIERRA: AUNQUE LA TIERRA
DESEMPEÑA UN PAPEL CRUCIAL EN LA VIDA DE TODOS, A MENUDO SE PASA POR ALTO. LA HISTORIA
RESALTA LA IMPORTANCIA DE RECONOCER Y VALORAR LOS RECURSOS PROPORCIONADOS POR LA TIERRA.
EL PAPEL DE LA ENFERMEDAD: LA INCLUSIÓN DE LA ENFERMEDAD EN EL PACTO SUBRAYA LA
COMPLEJIDAD DE LAS FUERZAS NATURALES QUE AFECTAN LA VIDA. LA SALUD Y EL BIENESTAR ESTÁN
INTERRELACIONADOS CON LA TIERRA Y LA MUERTE, DEMOSTRANDO QUE LAS ENFERMEDADES SON PARTE
INTEGRAL DEL CICLO DE LA VIDA. CONSECUENCIAS DE LAS ACCIONES: EL PACTO ASEGURA QUE TODAS
LAS PERSONAS, INDEPENDIENTEMENTE DE SU ESTATUS, RIQUEZA O CONOCIMIENTO, ENFRENTEN LAS
CONSECUENCIAS DE SUS ACCIONES. ESTO REFLEJA LA IDEA DE QUE LA VIDA Y LA MUERTE SON
EXPERIENCIAS COMPARTIDAS POR TODA LA HUMANIDAD. EN RESUMEN, LA HISTORIA DESTACA LA
NECESIDAD DE RECONOCER LA INTERDEPENDENCIA ENTRE LOS ELEMENTOS FUNDAMENTALES DE LA VIDA Y
LA IMPORTANCIA DE ASUMIR RESPONSABILIDADES PARA MANTENER EL EQUILIBRIO EN EL MUNDO.
ADEMÁS, SUBRAYA LA IDEA DE QUE TODASLAS ACCIONES TIENEN CONSECUENCIAS, INDEPENDIENTEMENTE
DE LA POSICION O ESTATUS DE LAS PERSONAS.''',
  '105. DOS LINEAS PARALELAS.': '''PATAKI: BABA EJIOGBE TENÍA DOS HIJOS: AJERO, UN VARÓN, Y OGUEYAN, UNA MUJER. ELLOS VIVÍAN
JUNTOS HASTA QUE, CAPRICHOS DEL DESTINO MEDIANTE, VINO UNA GUERRA Y FUERON APRESADOS Y
CONVERTIDOS EN ESCLAVOS, VENDIÉNDOLOS A CADA UNO LEJOS DE SU TIERRA NATAL. AJERO FUE
VENDIDO A UN CONVENTO DE FRAILES, DONDE SU SABIDURÍA LO HIZO MUY ESTIMADO. TODOS LOS
FRAILES, INCLUIDO EL PRIOR, LO APRECIABAN. AL MORIR EL PRIOR, AJERO FUE DESIGNADO COMO EL
LÍDER DE TODOS LOS FRAILES, CONVIRTIÉNDOSE EN LA FIGURA MÁS IMPORTANTE DE AQUELLA TIERRA,
SIENDO EL HIJO DE BABA EJIOGBE. POR OTRO LADO, OGUEYAN, SU HERMANA, FUE VENDIDA A UN
CONVENTO DE MONJAS, DONDE SU BONDAD Y PACIENCIA LA HICIERON MUY QUERIDA. A MEDIDA QUE
FALLECÍAN LAS MONJAS, LA MADRE SUPERIORA, ANTES DE SU MUERTE, LE DEJÓ TODA LA FORTUNA QUE
POSEÍA, CONVIRTIÉNDOLA EN LA MUJER MÁS RICA DEL LUGAR. A PESAR DE VIVIR DISTANCIADOS, LOS
DOS HERMANOS SE RECORDABAN MUTUAMENTE, PERO NUNCA SE ENCONTRARON. SIN EMBARGO, COMO AMBOS
ERAN PERSONAS RELIGIOSAS, EN SUS PREDICACIONES CADA UNO PENSABA EN EL OTRO. A TRAVÉS DE
SUS PENSAMIENTOS, SE COMUNICABAN HASTA QUE FINALMENTE SE REUNIERON EN EL OTRO MUNDO, JUNTO
A SU PADRE, BABA EJIOGBE. ENSEÑANZAS: SEPARACIÓN Y DESTINO: LA HISTORIA DESTACA CÓMO
EVENTOS INESPERADOS Y CIRCUNSTANCIAS, EN ESTE CASO, UNA GUERRA, PUEDEN SEPARAR A SERES
QUERIDOS Y LLEVARLOS POR CAMINOS DIFERENTES. LA VIDA DE AJERO Y OGUEYAN TOMÓ RUMBOS
INESPERADOS DEBIDO A CAPRICHOS DEL DESTINO. FORTALEZA INDIVIDUAL: A PESAR DE SER VENDIDOS
COMO ESCLAVOS, TANTO AJERO COMO OGUEYAN DEMOSTRARON FORTALEZA INDIVIDUAL Y HABILIDADES
ÚNICAS EN SUS RESPECTIVOS ENTORNOS RELIGIOSOS. SUS ACCIONES Y VIRTUDES LOS DESTACARON EN
SUS COMUNIDADES. RECONOCIMIENTO Y RECOMPENSA: LA HISTORIA ILUSTRA CÓMO EL RECONOCIMIENTO
DE LAS HABILIDADES Y LA BONDAD DE AJERO Y OGUEYAN LLEVÓ A LA RECOMPENSA Y AL
RECONOCIMIENTO SOCIAL. AMBOS ALCANZARON POSICIONES SIGNIFICATIVAS EN SUS COMUNIDADES, UNO
COMO LIDER DE FRAILES Y LA OTRA COMO LA MUJER MAS RICA DEL LUGAR. COMUNICACIÓN A TRAVÉS
DEL PENSAMIENTO: AUNQUE VIVÍAN SEPARADOS, LA CONEXIÓN ENTRE LOS HERMANOS A TRAVÉS DE SUS
PENSAMIENTOS Y ORACIONES DEMUESTRA LA FUERZA DE LOS LAZOS FAMILIARES Y CÓMO LA
ESPIRITUALIDAD PUEDE SER UN MEDIO DE CONEXIÓN INCLUSO EN LA DISTANCIA. REENCUENTRO EN EL
OTRO MUNDO: LA HISTORIA CONCLUYE CON UN REENCUENTRO EN EL MÁS ALLÁ, SUGIRIENDO LA IDEA DE
QUE, A PESAR DE LAS DISTANCIAS FÍSICAS Y LAS EXPERIENCIAS INDIVIDUALES, LAS RELACIONES
FAMILIARES PUEDEN PERDURAR Y REUNIRSE EN UN PLANO ESPIRITUAL. EN RESUMEN, LA HISTORIA
SUBRAYA TEMAS DE SEPARACIÓN, FORTALEZA INDIVIDUAL, RECONOCIMIENTO, CONEXIÓN ESPIRITUAL Y
REENCUENTRO EN EL CONTEXTO DE LA VIDA Y MÁS ALLÁ. EBO: AKUKO, EYELE MEYI FUN-FUN,
MALAGUIDI MEYI, UNA GORRACON 16 CARACOLES.''',
  '106. DONDE NACIO ALA GBA NFO GEDE.': '''PATAKI: EN LOS ALBORES DEL MUNDO, ORÚNMILA DESCENDIÓ A LA TIERRA CON LA MISIÓN DE
ENCONTRAR ILE IFE Y ENSEÑAR A SUS HABITANTES, QUIENES ERAN SEGUIDORES DE ODUDUWA, SOBRE
CÓMO VIVIR Y SEGUIR LAS LEYES DE IFÁ, QUE OLOFIN HABÍA DICTADO PARA SER ACATADAS.
ORÚNMILA, CONOCIDO COMO ATAGORO LAYE EN ESE MOMENTO, DESCENDIÓ DE ONIKA, JUNTO AL ILE DE
OLOKUN, PORQUE TODOS LOS CAMINOS DE DICHA TIERRA CONDUCÍAN A LO PREFERIDO POR OLOFIN, QUE
ERA ILE IFE. UBICÁNDOSE JUNTO A LA PLAYA CON SU FÁ, SE PREPARÓ PARA SU VIAJE. ANTES DE
PARTIR, REALIZÓ UN OSODE (ATEFA) CON SU IFÁ Y SE VIO A SÍ MISMO COMO BABA EJIOGBE,
ALIMENTANDO A SU IFÁ CON DOS GALLINAS Y UNA PALOMA SOBRE LA ARENA. INICIÓ SU VIAJE A LO
LARGO DE LA ORILLA DEL MAR, ENFRENTÁNDOSE A DIVERSAS PERSONAS Y RELIGIONES EN SU BÚSQUEDA
INFRUCTUOSA DE LA CIUDAD DE ILE IFE. DESPUÉS DE CAMINAR POR 15 TIERRAS DIFERENTES, DECIDIÓ
TOMAR EL ÚLTIMO CAMINO RESTANTE; LA RUTA DE ARENA QUE CAMBIABA CONSTANTEMENTE DE FORMA POR
LOS EMBATES DEL AIRE. DESPUÉS DE VARIOS DÍAS DE CAMINAR POR EL LARGO DESIERTO DE ENORMES
MONTAÑAS DE ARENA Y ENCONTRARSE EXHAUSTO, VIO UN POZO DE AGUA CERCANO, RODEADO DE ÁRBOLES.
SACÓ SU IFÁ, SE ARRODILLÓ ANTE ÉL Y AGRADECIÓ A OLOFIN POR PROPORCIONARLE EL POZO DE AGUA.
MIENTRAS ESTABA MEDIO DORMIDO Y LLORANDO, LE EXPRESÓ A OLOFIN SU DESEO DE REGRESAR AL
PUNTO DE PARTIDA DEBIDO AL AGOTAMIENTO Y LA FALTA DE ÉXITO EN ENCONTRAR ILE IFE. ENTONCES,
UNA VOZ LE DIJO A ORUNMILA: "DADO KOMAWE ATERERE LAYE OMO EJIOGBE" (MIENTRAS MAS MIRAS,
MENOS VES; TIENES LAS COSAS DELANTE Y NO LAS VES). LA VOZ LE INDICÓ SUMERGIR SU IFÁ EN EL
AGUA DEL POZO, LAVARSE LA CARA Y LA ESPALDA PARA ACLARAR SU VISTA Y REFRESCAR EL CAMINO
RECORRIDO. ESCUCHÓ UNA CANCIÓN: "ALA GBA NFO GEDE OJUALA GBA NFO GEDE OFO". CUANDO
ORÚNMILA ABRIÓ LOS OJOS, YA NO TENÍA NIEBLA EN ELLOS Y VIO LA ENTRADA DE LA CIUDAD DE ILE
IFE A TRAVÉS DE LOS ÁRBOLES DEL OASIS. LA VOZ LE INDICÓ COMPLETAR SU MISIÓN Y COMPARTIR LA
CEREMONIA Y EL CANTO DEL SUYERE CON SUS DESCENDIENTES PARA EVITARLES EXPERIENCIAS
SIMILARES. ORÚNMILA RINDIÓ HOMENAJE AL ESPÍRITU DE OLOFIN Y ENCONTRÓ TRES ÁRBOLES EN ESE
LUGAR, QUE SE UTILIZARON PARA EL IGBODUN EN LAS CONSAGRACIONES DE LOS HOMBRES DE ILE IFE.
NOTA: POR ESO SE HACE ESTA CEREMONIA DE ARAGBA, EN LAS CONSAGRACIONES DE IFA. EJIOGBE LE
SEÑALA AL AWO, QUE TIENE QUE ABRIR LOS OJOS, PUES A VECES SE ENTRETIENE Y ESTANDO DELANTE
DE LAS COSAS NO LAS VE. REZO: ADIFAFUN ATERERE LAYE WUAYA AWOS SALUAYE AWO SALUIKU. BETE
AWO SALU ERON ADIFAFUN YAKAGBA LERI IKUA IYAMETA GBOGBO IWI KUYA ANI GBOGBO IWIFALO INLE
IFAORÚNMILA AWO OFUYANO ONI GBOGBO ONIKA ILE OLOFINGBOGBO ONIKA ILE OLOFIN KAFEREFUN
ORÚNMILA. EBO: AKUKO, ADIE MEYI DUN-DUN, EYELE META, IGBA OYIN, OPOLO.PO OWO. ENSEÑANZAS:
PERSISTENCIA Y DETERMINACIÓN: ORÚNMILA ENFRENTÓ MUCHOS DESAFÍOS Y CAMINÓ POR DIVERSAS
TIERRAS EN SU BÚSQUEDA. A PESAR DE LAS DIFICULTADES, PERSISTIÓ EN SU OBJETIVO Y CONTINUÓ
SU VIAJE HASTA ENCONTRAR EL CAMINO CORRECTO. LA HISTORIA DESTACA LA IMPORTANCIA DE LA
PERSEVERANCIA FRENTE A LAS ADVERSIDADES. LA GUÍA ESPIRITUAL: LA VOZ QUE ACONSEJÓ A
ORÚNMILA Y LE PROPORCIONÓ LAS INSTRUCCIONES NECESARIAS PARA ACLARAR SU VISTA REPRESENTA LA
IMPORTANCIA DE LA GUÍA ESPIRITUAL EN LA VIDA. LA CONEXIÓN CON LO DIVINO Y LA ACEPTACIÓN DE
LA ORIENTACIÓN PUEDEN AYUDAR A SUPERAR OBSTÁCULOS Y ENCONTRAR EL CAMINO CORRECTO. LA
IMPORTANCIA DE CUMPLIR CON LA MISIÓN: ORÚNMILA FUE ENVIADO CON UNA MISIÓN ESPECÍFICA, Y A
PESAR DE LOS DESAFÍOS, LOGRÓ COMPLETARLA. LA HISTORIA RESALTA LA IMPORTANCIA DE CUMPLIR
CON NUESTRAS RESPONSABILIDADES Y PROPÓSITOS EN LA VIDA. LA NECESIDAD DE COMPARTIR
CONOCIMIENTO: ORÚNMILA RECIBIÓ LA INSTRUCCIÓN DE COMPARTIR LA CEREMONIA Y EL CANTO DEL
SUYERE CON SUS DESCENDIENTES. ESTO DESTACA LA IMPORTANCIA DE TRANSMITIR CONOCIMIENTO Y
SABIDURÍA A LAS GENERACIONES FUTURAS PARA QUE PUEDAN ENFRENTAR SUS PROPIOS DESAFÍOS. EN
CONJUNTO, LA HISTORIA ENSEÑA LECCIONES SOBRE LA PERSEVERANCIA, LA SABIDURÍA, LA
ORIENTACIÓN ESPIRITUAL, EL CUMPLIMIENTO DE LA MISIÓN Y LA TRANSMISIÓN DE CONOCIMIENTO,
VALORES QUE PUEDEN APLICARSE EN LA VIDA COTIDIANA.''',
  '107. DONDE NACIO LA GRAN VIRTUD DE LAS PALABRAS DE OBI.': '''PATAKI: EN ESTE CAMINO, CADA UNO DE LOS SANTOS EN LA CORTE DE OLORUN TENÍA SU GUÍA
INDIVIDUAL PARA VIVIR Y HABLAR. ESTA DIVERSIDAD EN LA COMUNICACIÓN LLEVÓ A QUE NO HUBIERA
ENTENDIMIENTO ENTRE ELLOS, Y LOS SERES HUMANOS TAMPOCO LOGRABAN ENTENDERSE NI
RELACIONARSE. SIN EMBARGO, HUBO UN HOMBRE, OBI, QUE SIEMPRE ACOMPAÑABA A OBATALA Y ESTABA
DISPUESTO A LUCHAR POR LA CAUSA DE LA HUMANIDAD PARA REDIMIRSE ANTE OLORUN POR ACCIONES DE
ORGULLO Y DESPRECIO HACIA SUS SEMEJANTES. OBI PROPUSO A ORÚNMILA ABORDAR EL PROBLEMA DE LA
FALTA DE COMUNICACIÓN ENTRE LOS ORISHAS. ORÚNMILA, JUNTO CON OSHAGRIÑAN, ACEPTÓ LA
PROPUESTA Y DECIDIERON REALIZAR UNA REUNIÓN EN LA TIERRA DE BABA EJOGBE AWO PRUN NIGAGA.
OSHAGRIÑAN, CON EL PODER DE ODUDUWA Y OLORUN SOBRE LA TIERRA, CONVOCÓ A TODOS LOS ORISHAS
Y ORISHAS AL ILE DE OBI PARA ABORDAR EL ASUNTO. EN LA REUNIÓN, OSHAGRIÑAN INSTÓ A CADA UNO
A CONTRIBUIR CON SUS CONOCIMIENTOS PARA FORMAR UNA GRAN FAMILIA QUE PERMITIERA EL PROGRESO
HUMANO Y LA PROTECCIÓN MUTUA. PROPUSO ESTABLECER UNA FORMA DE COMUNICARSE CON LOS HOMBRES
Y EL CIELO. OBATALA SUGIRIÓ QUE EL VÍNCULO SE REALIZARA A TRAVÉS DE OBI, YA QUE ESTE
SIEMPRE DEBÍA PERMANECER EN EL SUELO COMO CASTIGO POR SU ORGULLO, SEGÚN EL MANDATO DE
OLORUN. OBATALA EXPLICÓ QUE LOS DIOSES NO PODÍAN REZAR, ACEPTAR NI ESCUCHAR LO PLANTEADO
POR LOS HOMBRES DIRECTAMENTE. GBOGBO ORUMALE DEBÍA PLANTEAR SUS PREOCUPACIONES A TRAVÉS DE
OBI, QUIEN INTERCEDERÍA POR ELLOS PARA EVITAR DESGRACIAS Y ADVERTIR SOBRE POSIBLES
REMEDIOS. BABALUAYE (ASOJUANO) SE OPUSO INICIALMENTE A ESTA IDEA, PERO FUE OBLIGADO A
ACEPTARLA POR EL PODER DE OBATALA. TODOS LOS DEMÁS ORISHAS ACEPTARON EL ACUERDO Y
RECIBIERON EL PODER DE OBATALA, RECONOCIENDO A OBI Y SU ÁRBOL COMO SU REPRESENTACIÓN MÁS
VALIOSA Y ESPECIAL. OBATALA ESTABLECIÓ QUE NINGÚN SANTO PODÍA RECHAZAR A OBI, SIN IMPORTAR
EL ORIGEN O LA ÍNDOLE DE LA PREGUNTA O COMUNICACIÓN RECIBIDA. DIRIGIÉNDOSE A TODOS LOS
ORISHAS ORUMALES, OBATALA ENFATIZÓ: "OBI UNSORO, OBI KOSI OFO" LO QUE SIGNIFICA QUE LAS
PALABRAS DE OBI NO SE PERDERÍAN. DESDE ENTONCES, OBI SE CONVIRTIÓ EN EL VEHÍCULO DE
COMUNICACIÓN ENTRE ORISHAS, IFA Y EL HOMBRE. NOTA: AQUI NACE EL SECRETO DE PONER UN PEDAZO
DE OBI DEBAJODEL PIE IZQUIERDO DE LA PERSONA QUE SE HACE IFA, PUES PERMITE QUE SE PONGA EN
CONTACTO, LA DIVINIDAD CONSULTADA, CON EL ESPIRITU DE LA PERSONA A TRAVES DEL HOMBRE, EL
OBI Y LA TIERRA. REZO: ADIFAFUN OBATALA, OSHANGRIÑAN, BELELE ORISHA TOYAN IWIOBI LAYO
OLODA AWON IYOKUN LERU AKIYU IDABA ORISHA AYABELELE AYA SHEBI GUANALE GBIGBO ORUMALE EKE
ATI EYONIBE IWIO OBI DAAWO UN SORO ELESE IWI OBI GBOGBO ORISHA LA WA TOMI BEKUN BEKURE
OBALU AYE KOSEDA NI OBEIPORI EGGUN LALALA EGGUN NI AWO ORISHA EBBO AROKO BUKEDE
BELELEASHIRI IFA, ASHIRI ORISHA EBEFUN OBI ABON AFIO OPA LESE OBI SI ARANA GBOGBO EGGUN
GBOGBO ORISHA LA WA TOMI BABA ABERE NI LORUN ABERE NI KAYE ORANKUSIN ORAN EGGUN ORAN
ORISHA ORAN ORAN AWON OMO. FA OLORAN LOBI IKUSI GBOGBO ERUMALE IBIDAJUN ITANI IFA META
UNSORO OBI UNSORO OBI KOSO OFO, ASHIRIN IYASI MIMO OLOBON LESE IWI ARAGBA KAFEREFUN GBOGBO
ERUMALE ORISHA LAWA TOMI GBOGBO OSHA KOLABA OMO NI OLOFIN LODAFUN OBATALA ADAFUN BABA
OSHAGRIÑAN OLOWERE IWI ARAGBA. EBO AKUKO, ADIE, EYELE, OBI, GBOGBO ASHO, GBOGBO ILEKE
ORISHA, OPOLOPO OWO. NOTA: EN ESTE CAMINO DE EJIOGBE NACE, EL QUE LA PALABRA DE OBI NO SE
PIERDA Y NACE QUE SE PONGA UN PEDAZO DE OBI DEBAJO DEL PIE IZQUIERDO DE TODA PERSONA QUE
VAYA A HACER ITA, TANTO DE OSHA COMO DE IFA. ESTE PEDAZO DE OBI TIENE SU SECRETO Y
CEREMONIA Y NO SE BOTA COMO SE HACE CORRIENTEMENTE. ESTE PEDAZO DE OBI RECIBE EL NOMBRE DE
AFI OPA Y PERMITE QUE EL ESPIRITU DE IMPORI QUE VIVE EN EL DEDO GORDO DE CADA PIE SE PONGA
EN CONTACTO CON LA DIVINIDAD QUE ES CONSULTADA EN EL ITA. ESTE PEDAZO DE OBI DESPUES QUE
SE TERMINE EL ITA, SECRETAMENTE SE PONE AL PIE DE OBATALA Y ENTONCES SE LE DA UNA EYELE SI
SE TRATA DE UN SOLO ORISHA DE OBATALA, A ESTE SE LE ADICIONA: EKU, EYA, AWADO Y SI ES
OBATALA ORI. SI ES ELEGBA, OGGUN, OSHOSI, SHANGO, OYA O AGAYU: EPO, SI ES OSHUN MIEL
(OYIN) Y SI ES YEMAYA MELAO. CUANDO SE TRATE DE UN SANTO QUE NO SEA OBATALA LLEVA LOS
INGREDIENTES MENOS LA EYELE. ENTONCES ESTE PEDAZO DE OBI CON TODOS LOS INGREDIENTES Y LA
EYELE, SI SE TRATA DE OBATALA, SE ENVUELVE EN UNA TELA FUN FUN Y SE LLEVA AL PIE DE ARAGBA
POR EL LADO IZQUIERDO O PONIENTE. ALLI SE LE DA CUENTA AL MUNDO DE LOS EGGUN Y SE LE DA
OBI OMI TUTO PARA VER SI QUIEREN ALGUNA OFRENDA, ENTONCES POR LA PARTE DEL NACIENTE DE
ARAGBA, SE ABRE UN KUTUN, DESPUES DE DARLE OBI A ARAGBA, LLAMANDO A OLOFIN, ODUDUWA Y
OBATALA OSHAGRIÑAN, DANDOLE CUENTA QUE SE HA HECHO ITA PARA FULANO DE TAL IYAGO EÑI.
ENTONCES SE METE TODO LO QUE ESTA EN EL PAÑO FUN FUN EN EL KUTUN Y SE TAPA, DEJANDO
ENCENDIDA LA ITANA ESTO SE HACE DANDO CUENTA A EGGUN, ORUN, OLOFIN, ODUDUWA, OBATALA
OSHAGRIÑAN, QUE EN LA TIERRA SE HA HECHO ITA, PARA HABLARLE A UN HOMBRE DE LOS PRINCIPIOS
SECRETOS DE LA VIDA EN EL CAMPO DE ORISHA O DE IFA. SE HACE PARA QUE ESTOS PODERES Y
ORISHAS NO SE OFENDAN PORQUE SE HA PERTURBADO LA PAZ DE SU RECOGIMIENTO. ES PERJUDICIAL
PARA LA PERSONA QUE SE HA HECHO EL ITA QUE SE BOTE ESTE PEDAZO DE OBI, COMO SE ESTA
HACIENDO O SE UTILICE EN OTRAS PERSONAS QUE SALIERON EN ESE ITA. ESTO QUE ANTERIORMENTE
HEMOS DESCRITO, SI SE REALIZA AL PIE DE LA LETRA, LE DA UN PUNTO DE DEFENSA A LA PERSONA
QUE SE HA HECHO ITA DADO QUE SE DA CUENTA A OLOFIN Y A TODAS LAS DEMAS DEIDADES DE UNA
LETRA QUE TRAE UNOS PRINCIPIOS SOBRE LA PERSONA POR LO QUE ESTA RECIBE EL BENEPLACITO DE
EGGUN Y DEMAS PODERES ASTRALES, PARA AFIANZAR Y RECONOCER SU PODER EN EL ITA DE LA TIERRA.
ENSEÑANZAS: LA IMPORTANCIA DE LA COLABORACIÓN: ANTE LA NECESIDAD DE MEJORAR LA
COMUNICACIÓN, UN HOMBRE LLAMADO OBI, DISPUESTO A REDIMIRSE, PROPUSO ABORDAR EL PROBLEMA.
ESTA INICIATIVA DEMUESTRA LA IMPORTANCIA DE LA COLABORACIÓN PARA RESOLVER DESAFÍOS
COMUNES. REUNIONES PARA EL CAMBIO: LA DECISIÓN DE ORÚNMILA Y OSHAGRIÑAN DE REALIZAR UNA
REUNIÓN EN LA TIERRA DE BABA EJIOGBE AWO PRUN NIGAGA MUESTRA CÓMO LAS REUNIONES
ESTRATÉGICAS PUEDEN SER FUNDAMENTALES PARA ABORDAR PROBLEMAS IMPORTANTES. RECONOCIMIENTO
DE ERRORES Y REDENCIÓN: LA DISPOSICIÓN DE OBI A LUCHAR POR LA CAUSA DE LA HUMANIDAD PARA
REDIMIRSE ANTE OLORUN POR SUS ACCIONES DE ORGULLO Y DESPRECIO RESALTA LA IMPORTANCIA DE
RECONOCER ERRORES Y BUSCAR REDENCIÓN. CONTRIBUCIONES INDIVIDUALES: OSHAGRIÑAN INSTÓ A CADA
SANTO A CONTRIBUIR CON SUS CONOCIMIENTOS PARA FORMAR UNA GRAN FAMILIA QUE PERMITIERA EL
PROGRESO HUMANO Y LA PROTECCIÓN MUTUA. ESTO DESTACA LA IMPORTANCIA DE LAS CONTRIBUCIONES
INDIVIDUALES PARA EL BIEN COMÚN. INTERCESIÓN POR LA HUMANIDAD: LA FUNCIÓN DE OBI COMO
INTERMEDIARIO PARA PLANTEAR PREOCUPACIONES A LOS DIOSES Y RECIBIR ORIENTACIÓN RESALTA LA
IDEA DE LA INTERCESIÓN DE ESTE EN BENEFICIO DE LA HUMANIDAD.''',
  '108. NO SE MATAN RATONES.': '''PATAKI: ACONTECIÓ UNA VEZ QUE SE ANUNCIÓ EL NACIMIENTO DE OBATALA, Y EL REY DE AQUELLA
TIERRA, TEMIENDO LA PROFECÍA, MANDÓ A SUS SOLDADOS A MATAR A LOS PADRES DEL NIÑO. ESHU,
QUE CONOCÍA LA DECISIÓN DEL MONARCA, SE ADELANTÓ Y LES ADVIRTIÓ A LOS PADRES DEL NIÑO
SOBRE EL PELIGRO INMINENTE, INSTÁNDOLOS A HUIR PARA SALVAR A LA CRIATURA. A PESAR DE LOS
ESFUERZOS DE LOS PADRES, EL REY INICIÓ UNA TENAZ PERSECUCIÓN, OBLIGÁNDOLOS A ABANDONAR AL
RECIÉN NACIDO. EL NIÑO, OBATALA, CRECIÓ EN CONSTANTE FUGA. UN DÍA, LOS SOLDADOS DEL REY LO
ACORRALARON, Y PARECÍA QUE TODO ESTABA PERDIDO. SIN EMBARGO, EN ESE MOMENTO CRÍTICO, SE
ENCONTRABA UNA GRAN CEIBA DONDE LOS RATONES TENÍAN SUS GUARIDAS. AL VER A OBATALA EN
APUROS, LOS RATONES LE OFRECIERON REFUGIO DICIÉNDOLE: "OIGA, VENGA ACÁ, MÉTASE AQUÍ: ASI
OBATALA SE ESCONDIÓ EN EL INTERIOR DE LA CEIBA. LAS RATAS, CADA DÍA, SALÍAN POR LA MAÑANA
LLEVÁNDOLE PAN, QUESO, Y MÁS, DURANTE LOS 16 DÍAS QUE DURÓ LA PERSECUCIÓN. FINALMENTE,
PASÓ EL PELIGRO, Y OBATALA PUDO SALIR DE SU ESCONDITE. EN AGRADECIMIENTO, OBATALA BENDIJO
AL EKUTE (RATÓN), DICIÉNDOLE: "MIENTRAS EL MUNDO SEA MUNDO, A TI NO TE FALTARÁ CASA NI
COMIDA." TO IBAN ESHU. NOTA: LOS DESCENDIENTES O HIJOS DE BABA EJIOGBE NO MATAN RATONES NI
LE PONEN TRAMPAS. ENSEÑANZAS: PROTECCIÓN DIVINA: LA HISTORIA RESALTA LA PROTECCIÓN DIVINA
HACIA OBATALA DESDE SU NACIMIENTO, CON ESHU INTERVINIENDO PARA SALVARLO DE LA PERSECUCIÓN
Y LOS RATONES PROPORCIONANDOLE REFUGIO.: AYUDA INESPERADA: LA AYUDA DE LOS RATONES MUESTRA
CÓMO, A VECES, LA ASISTENCIA PUEDE PROVENIR DE LUGARES INESPERADOS. AUNQUE PEQUENOS, LOS
RATONES JUGARON UN PAPEL CRUCIAL EN LA SALVACIÓN DE OBATALA.: AGRADECIMIENTO Y
BENDICIONES: LA ACTITUD AGRADECIDA DE OBATALA HACIA LOS RATONES, EXPRESADA MEDIANTE SU
BENDICIÓN, DESTACA LA IMPORTANCIA DE RECONOCER Y AGRADECER LA AYUDA RECIBIDA, INCLUSO
CUANDO PROVIENE DE FUENTES INESPERADAS.: COLABORACIÓN Y UNIDAD: LA HISTORIA IMPULSA LA
IDEA DE QUE TODOS LOS SERES, INCLUSO AQUELLOS APARENTEMENTE INSIGNIFICANTES COMO LOS
RATONES, PUEDEN CONTRIBUIR A UN BIEN COMÚN. RESALTA LA IMPORTANCIA DE LA COLABORACIÓN Y LA
UNIDAD EN LA SUPERACIÓN DE DESAFIOS.: ESTAS LECCIONES TRANSMITEN VALORES COMO LA GRATITUD,
LA COLABORACIÓN, LA PERSISTENCIA Y LA APRECIACIÓN DE LA AYUDA DIVINA Y LA CONTRIBUCIÓN DE
TODAS LAS CRIATURAS EN LA CREACIÓN.''',
  '109. EL HIJO DE OSHOSI E IKU.': '''PATAKI: HABÍA UN HIJO DE OSHOSI QUE ANHELABA ADENTRARSE EN EL MONTE DE ONIKOROGBO PARA LA
CAZA. ANTES DE EMPRENDER SU VIAJE, DECIDIÓ REGISTRARSE EN LA CASA DE ORÚNMILA, QUIEN LE
REALIZÓ UN OSODE Y LE REVELÓ EL IFA BABA EJIOGBE. ORÚNMILA LE ADVIRTIÓ: "DEBES HACER EBBO
CON TODAS LAS EÑÍ ADIE QUE TENGAS EN CASA PARA EVITAR ENCONTRARTE CON IKU (LA MUERTE)" SIN
EMBARGO, EL HIJO DE OSHOSI NO PRESTÓ ATENCIÓN Y DESESTIMÓ LA NECESIDAD DE REALIZAR EL
EBBO. AL DÍA SIGUIENTE, SE ADENTRÓ EN EL MONTE EN BUSCA DE PRESAS, PERO NO LOGRÓ ENCONTRAR
NINGÚN ANIMAL PARA CAZAR. DESPUÉS DE MUCHO CAMINAR, SE ENCONTRÓ CON IKU Y,
SORPRENDENTEMENTE, ENTABLARON AMISTAD Y SALIERON JUNTOS DE CAZA. A LO LARGO DE SU
TRAVESÍA, NO ENCONTRARON NINGÚN ANIMAL HASTA QUE FINALMENTE HALLARON DOS EÑÍ DE GUNUGUN.
KU LE DIJO AL CAZADOR: "PUEDES LLEVÁRTELOS. AUNQUE EL CAZADOR PROPUSO DIVIDIRLOS, IKU SE
NEGÓ. CUANDO EL CAZADOR REGRESÓ A CASA, COCINÓ LOS DOS HUEVOS Y LOS COMPARTIÓ CON SU
FAMILIA. DESPUÉS DE TERMINAR LA COMIDA, APARECIÓ IKU Y LE DIJO AL CAZADOR: "HE VENIDO POR
MI PARTE PORQUE HAY HAMBRE EN ISALE ORUN Y NO TENEMOS NADA QUE COMER." EL CAZADOR
RESPONDIÓ CON PESAR: "¡AY DE MÍ! YA NOS HEMOS COMIDO LOS EÑÍ DE GUNUGUN." IKU, SIN
VACILAR, SE LLEVÓ AL CAZADOR Y A TODA SU FAMILIA. ENSENANZAS: IMPORTANCIA DE ESCUCHAR
CONSEJOS: EL HIJO DE OSHOSI RECIBIÓ UN CONSEJO SABIO DE ORÚNMILA ANTES DE EMPRENDER SU
VIAJE AL MONTE. SIN EMBARGO, DESESTIMÓ LA ADVERTENCIA Y NO REALIZÓ EL EBBO RECOMENDADO.
ESTO RESALTA LA IMPORTANCIA DE ESCUCHAR A LOS CONSEJEROS Y PRESTAR ATENCION A LA SABIDURIA
QUE SE COMPARTE. CONSECUENCIAS DE LA DESOBEDIENCIA: LA HISTORIA MUESTRA LAS CONSECUENCIAS
DE NO SEGUIR LAS RECOMENDACIONES DE LOS MAYORES O DE AQUELLOS CON MAYOR CONOCIMIENTO. LA
DESOBEDIENCIA A LAS ADVERTENCIAS PUEDE LLEVAR A SITUACIONES DESAFORTUNADAS Y, EN ESTE
CASO, A ENCONTRARSE CON LA MUERTE (IKU). LA AMISTAD CON LA MUERTE: EL HECHO DE QUE EL
CAZADOR ENTABLARA AMISTAD CON IKU DURANTE SU VIAJE ES SIMBÓLICO. A VECES, LAS MALAS
DECISIONES O ACCIONES PUEDEN LLEVARNOS A SITUACIONES PELIGROSAS O AUTODESTRUCTIVAS. LA
MUERTE, PERSONIFICADA EN LA HISTORIA, PUEDE CONVERTIRSE EN COMPAÑÍA CUANDO IGNORAMOS
ADVERTENCIAS Y TOMAMOS DECISIONES IMPRUDENTES. COMPARTIR Y SUS CONSECUENCIAS: EL CAZADOR
COMPARTIÓ LOS HUEVOS CON SU FAMILIA, LO CUAL ES UN ACTO DE GENEROSIDAD. SIN EMBARGO, LAS
CONSECUENCIAS DE SUS ACCIONES FUERON INESPERADAS. ESTO PUEDE ILUSTRAR CÓMO NUESTRAS
DECISIONES, INCLUSO LAS BENEVOLENTES, PUEDEN TENER CONSECUENCIAS QUE NO ANTICIPAMOS. EN
RESUMEN, LA HISTORIA DESTACA LA IMPORTANCIA DE LA PRUDENCIA, LA ESCUCHA ATENTA, EL RESPETO
POR LAS TRADICIONES Y LA REFLEXIÓN SOBRE LAS DECISIONES PASADAS PARA EVITAR CONSECUENCIAS
NEGATIVAS EN LA VIDA.''',
  '110. AQUI NACIO EL ITA DE SANTO Y EL GOLPE DE ESTADO.': '''PATAKI: HABÍA UN REY LLAMADO ADOMILÉ QUE GOBERNABA SUS TIERRAS CON GRAN CUIDADO Y
ABUNDANCIA. SIN EMBARGO, DEBIDO A SU AVANZADA EDAD, LA GENTE EMPEZÓ A DIFUNDIR RUMORES DE
QUE ADOMILÉ ERA DEMASIADO VIEJO PARA LIDERAR Y QUE ERA NECESARIO NOMBRAR A OTRO REY. SU
RIVAL, LOSA, SE PRESENTABA COMO UNA OPCIÓN MÁS JOVEN QUE TRAERÍA MAYOR PROSPERIDAD A LA
CIUDAD, GENERANDO ASÍ UN CRECIENTE DESCONTENTO. ADOMILÉ, SIENDO AWO, CONSULTÓ A ORÚNMILA Y
LE SALIÓ EL ODDUN CORRESPONDIENTE. ENVIÓ A SU HOMBRE DE CONFIANZA PARA INVESTIGAR LA
SITUACIÓN. ESTE INFORMÓ QUE LA GENTE AMENAZABA CON LA GUERRA SI ADOMILÉ NO RENUNCIABA. A
PESAR DE LA PRESIÓN, ADOMILÉ DECIDIÓ RETIRARSE, PERO NO ANTES DE ADVERTIR A SU CRIADO QUE
SE CUIDARA Y PERMANECIERA PARA INFORMARLE SOBRE EL ESTADO DEL PUEBLO. LOSA TOMÓ EL PODER,
PERO PRONTO COMENZARON A ESCASEAR LOS ALIMENTOS Y LA POBLACIÓN SUFRÍA. EN LA TIERRA DE ILÉ
TAKUA, LA GENTE AMANECÍA MUERTA. EL CRIADO DE CONFIANZA SE COMUNICÓ CON ADOMILÉ A TRAVÉS
DE OZAIN, UN HERMOSO PÁJARO NEGRO. EL PÁJARO VOLABA HASTA LA ESTANCIA DE ADOMILÉ, SE
POSABA EN UNA MATA Y CANTABA, MIENTRAS ADOMILÉ REALIZABA ASUNTOS. LA SITUACIÓN SE VOLVIÓ
INSOSTENIBLE, Y LA GENTE SE SUBLEVÓ, PIDIENDO QUE ADOMILÉ RETOMARA EL PODER. FUERON A
BUSCARLO, Y EL CRIADO LIBERÓ AL PÁJARO. LOS SOLDADOS DE LOSA, SIGUIENDO ÓRDENES,
INTENTARON ATACAR AL PÁJARO, PERO AL SER PROPIEDAD DE OZAIN, NO LO AFECTARON. EL PÁJARO
CANTÓ REVELANDO QUE LOSA ESTABA MATANDO A LA GENTE. ADOMILÉ REGRESÓ A LA CIUDAD, FUE
RECIBIDO CON HOMENAJES Y PIDIÓ UN MOMENTO. ANTES DE RETOMAR EL PODER, INSISTIÓ EN
ALIMENTAR AL SANTO Y CONSULTAR A IFÁ PARA DETERMINAR SI PODÍA O NO GOBERNAR. COMO UN
ANCIANO SABIO, CONVOCÓ A LOS IYALOSHAS Y REALIZÓ SACRIFICIOS. LOSA, AL NO ENTENDER LOS
RITUALES, DESECHÓ LAS CABEZAS Y VÍSCERAS. ADOMILÉ, CON LAS CABEZAS Y LAS CRUCES, REALIZÓ
LA CONSULTA, Y OBATALA DECLARÓ: "TO IBAN ESHU, PARA GOBERNAR HACE FALTA CABEZA: DESDE ESE
MOMENTO, ADOMILÉ VOLVIÓ A GOBERNAR DE MANERA FORMAL. ENSEÑANZAS: SABIDURÍA EN LA TOMA DE
DECISIONES: ADOMILÉ, A PESAR DE LA PRESIÓN Y LOS RUMORES, TOMÓ DECISIONES SABIAS AL
CONSULTAR A ORÚNMILA Y SEGUIR LAS INDICACIONES DE IFÁ. ESTO DESTACA LA IMPORTANCIA DE LA
SABIDURÍA Y LA REFLEXIÓN ANTES DE TOMAR DECISIONES SIGNIFICATIVAS, ESPECIALMENTE EN
SITUACIONES DE CRISIS. CONSECUENCIAS DE LA DESOBEDIENCIA: LOSA, AL IGNORAR LOS RITUALES Y
DESECHAR ELEMENTOS SAGRADOS, MUESTRA LAS CONSECUENCIAS DE NO COMPRENDER O DESPRECIAR LAS
PRÁCTICAS ESPIRITUALES. LA HISTORIA ENFATIZA QUE EL DESCONOCIMIENTO O LA FALTA DE RESPETO
HACIA CIERTOS ASPECTOS PUEDEN LLEVAR A SITUACIONES PROBLEMÁTICAS. RECONOCIMIENTO DE
ERRORES Y CORRECCIÓN: ADOMILÉ, AL RECONOCER QUE LA SITUACIÓN NO ERA CUESTIÓN DE GUERRA
SINO DE RETIRARSE, MUESTRA HUMILDAD Y LA CAPACIDAD DE RECONOCER ERRORES. ADEMÁS, SU
REGRESO AL PODER DESPUÉS DE LA CONSULTA RITUAL DEMUESTRA LA POSIBILIDAD DE CORREGIR
SITUACIONES ADVERSAS MEDIANTE ACCIONES REFLEXIVAS Y RECTIFICADORAS. RESPETO POR LAS
CREENCIAS Y PRÁCTICAS ESPIRITUALES: LA HISTORIA RESALTA LA IMPORTANCIA DEL RESPETO HACIA
LAS CREENCIAS Y PRACTICAS ESPIRITUALES, YA QUE DESPRECIAR O MALINTERPRETAR ELEMENTOS
SAGRADOS PUEDE TENER CONSECUENCIAS NEGATIVAS. EN RESUMEN, ESTA HISTORIA SUBRAYA LA
IMPORTANCIA DE LA SABIDURÍA, LA CONSULTA ESPIRITUAL, EL RESPETO POR LAS TRADICIONES Y LA
CAPACIDAD DE RECONOCER Y CORREGIR ERRORES PARA SUPERAR DESAFÍOS Y LIDERAR DE MANERA
EFECTIVA.''',
  '111. EL VIGILANTE MALO (AMI).': '''PATAKI: AMI, EL GUARDIÁN DE LA CASA DE OBATALÁ, ERA CONOCIDO POR SU COMPORTAMIENTO
MALÉVOLO. DESAFIABA LAS INSTRUCCIONES DE BABA, PUES CUANDO LOS HIJOS DE OBATALÁ RECIBÍAN
AGUA PURIFICADORA PARA LIMPIARSE DE LAS EPIDEMIAS, AMI NO DUDABA EN ARREBATÁRSELA Y
ROCIÁRSELA ENCIMA. SU ACTITUD ERA UNA AFRENTA A LAS PRÁCTICAS SAGRADAS DE PURIFICACIÓN. UN
DÍA, BABA DECIDIÓ ENVIAR A ESHU CON UN CUBO DE AGUA DE LIMPIEZA PARA VER SI PODÍA CORREGIR
LA CONDUCTA DE AMI. ESHU, ASTUTO COMO SIEMPRE, LLEVÓ A CABO UNA ESTRATEGIA INGENIOSA. AL
ENCONTRARSE CON AMI, SIMULÓ QUE EL CUBO SE LE IBA A CAER Y LO DEJÓ CAER CON APARENTE
DESCUIDO, OCULTÁNDOSE RÁPIDAMENTE. AMI, CREYENDO QUE ESTABA ANTE UNA TAREA CRUCIAL, BAJÓ
APRESURADAMENTE PARA RECOGER EL CUBO Y ARRUINAR SU CONTENIDO. EN ESE MOMENTO, ESHU SALIÓ
DE SU ESCONDITE Y BLOQUEÓ LA SALIDA DE AMI, TAPÁNDOLE EL CAMINO. DESDE ESE DÍA, EL
MALÉVOLO GUARDIÁN DESAPARECIÓ DE LAS ESQUINAS DE LA CASA DE OBATALÁ. SU CONSTANTE
VIGILANCIA Y ACCIONES PERJUDICIALES QUEDARON DETENIDAS GRACIAS A LA INTERVENCIÓN ASTUTA DE
ESHU. ESTA HISTORIA DESTACA LA ASTUCIA DE ESHU PARA CORREGIR UNA CONDUCTA NEGATIVA Y
RESTAURAR LA PUREZA EN LA CASA DE OBATALÁ. ADEMÁS, SUBRAYA LA IMPORTANCIA DE LA
INTERVENCIÓN DIVINA PARA CORREGIR ACCIONES MALINTENCIONADAS Y PRESERVAR LA INTEGRIDAD DE
LAS PRÁCTICAS ESPIRITUALES. ENSEÑANZAS: ASTUCIA COMO INSTRUMENTO CORRECTIVO: LA HISTORIA
DESTACA CÓMO LA ASTUCIA DE ESHU FUE UTILIZADA COMO UN MEDIO PARA CORREGIR LA CONDUCTA
EQUIVOCADA DE AMI. A VECES, LA INTELIGENCIA Y LA ASTUCIA PUEDEN SER HERRAMIENTAS EFICACES
PARA ABORDAR SITUACIONES PROBLEMÁTICAS. CONSECUENCIAS DE LAS ACCIONES MALÉVOLAS: AMI
REPRESENTABA UN GUARDIÁN MALÉVOLO QUE ACTUABA EN CONTRA DE LAS PRÁCTICAS SAGRADAS DE
PURIFICACIÓN ORDENADAS POR OBATALÁ. LA HISTORIA ILUSTRA QUE LAS ACCIONES MALÉVOLAS
EVENTUALMENTE TIENEN CONSECUENCIAS, Y LA INTERVENCIÓN DIVINA PUEDE SER NECESARIA PARA
RECTIFICARLAS. APRENDIZAJE A TRAVÉS DE LA EXPERIENCIA: AMI APRENDIÓ DE MANERA IMPACTANTE A
TRAVÉS DE LA EXPERIENCIA. AL CAER EN LA TRAMPA DE ESHU, SE DIO CUENTA DE LA MAGNITUD DE
SUS ACCIONES Y DEJÓ DE REALIZAR ACTOS MALÉVOLOS. LA EXPERIENCIA A MENUDO SIRVE COMO UN
MAESTRO EFICAZ. LA SABIDURÍA DE SEGUIR INSTRUCCIONES DIVINAS: LA HISTORIA REFLEJA LA
IMPORTANCIA DE SEGUIR LAS INSTRUCCIONES DIVINAS. OBATALÁ ENVIÓ A ESHU CON UNA MISIÓN
ESPECÍFICA PARA CORREGIR LA CONDUCTA DE AMI, LO QUE RESALTA LA IMPORTANCIA DE OBEDECER LAS
DIRECTRICES ESPIRITUALES PARA MANTENER LA ARMONÍA Y LA PUREZA. SUPERACIÓN DE OBSTÁCULOS
CON INGENIO: ESHU UTILIZÓ SU INGENIO PARA SUPERAR EL OBSTÁCULO DE AMI Y CORREGIR SU
COMPORTAMIENTO. LA HISTORIA SUGIERE QUE ENFRENTAR DESAFÍOS A TRAVÉS DE LA ASTUCIA Y LA
INTELIGENCIA PUEDE SER UNA FORMA EFECTIVA DE SUPERAR OBSTÁCULOS. EN RESUMEN, LA HISTORIA
DE AMI Y ESHU PROPORCIONA LECCIONES SOBRE LA CORRECCIÓN DE COMPORTAMIENTOS MALÉVOLOS, LA
INTERVENCIÓN DIVINA, LA IMPORTANCIA DE SEGUIR INSTRUCCIONES ESPIRITUALES Y LA SUPERACIÓN
DE OBSTÁCULOS MEDIANTE LA ASTUCIA.ESHU, SE DIO CUENTA DE LA MAGNITUD DE SUS ACCIONES Y
DEJÓ DE REALIZAR ACTOS MALÉVOLOS. LA EXPERIENCIA A MENUDO SIRVE COMO UN MAESTRO EFICAZ. LA
SABIDURÍA DE SEGUIR INSTRUCCIONES DIVINAS: LA HISTORIA REFLEJA LA IMPORTANCIA DE SEGUIR
LAS INSTRUCCIONES DIVINAS. OBATALÁ ENVIÓ A ESHU CON UNA MISIÓN ESPECÍFICA PARA CORREGIR LA
CONDUCTA DE AMI, LO QUE RESALTA LA IMPORTANCIA DE OBEDECER LAS DIRECTRICES ESPIRITUALES
PARA MANTENER LA ARMONÍA Y LA PUREZA. SUPERACIÓN DE OBSTÁCULOS CON INGENIO: ESHU UTILIZÓ
SU INGENIO PARA SUPERAR EL OBSTÁCULO DE AMI Y CORREGIR SU COMPORTAMIENTO. LA HISTORIA
SUGIERE QUE ENFRENTAR DESAFÍOS A TRAVÉS DE LA ASTUCIA Y LA INTELIGENCIA PUEDE SER UNA
FORMA EFECTIVA DE SUPERAR OBSTÁCULOS. EN RESUMEN, LA HISTORIA DE AMI Y ESHU PROPORCIONA
LECCIONES SOBRE LA CORRECCIÓN DE COMPORTAMIENTOS MALÉVOLOS, LA INTERVENCIÓN DIVINA, LA
IMPORTANCIA DE SEGUIR INSTRUCCIONES ESPIRITUALES Y LA SUPERACIÓN DE OBSTÁCULOS MEDIANTE LA
ASTUCIA.''',
  '112. LA PELEA DEL AKUKO E IKU.': '''PATAKI: HABÍA UNA VEZ UN AWO QUE SE DEDICABA CON DEVOCIÓN A LA CRIANZA DE DIVERSOS
ANIMALES. SU HABILIDAD PARA CUIDAR Y CRIAR DIFERENTES ESPECIES ERA RECONOCIDA EN LA
COMUNIDAD. SIN EMBARGO, UN DÍA CAYÓ ENFERMO GRAVEMENTE, Y SU SITUACIÓN SE VOLVIÓ TAN
CRÍTICA QUE TODOS LOS ANIMALES QUE LO RODEABAN SINTIERON UN TEMOR PROFUNDO Y DECIDIERON
ABANDONARLO, EXCEPTO UN VALIENTE AKUKO FUN FUN, UN GALLO BLANCO. A PESAR DEL PELIGRO QUE
REPRESENTABA LA ENFERMEDAD, EL AKUKO FUN FUN PERMANECIÓ AL LADO DEL AWO ENFERMO. EL AWO,
AGRADECIDO POR LA LEALTAD DEL GALLO, SE SORPRENDIÓ AL VER QUE, EN LUGAR DE HUIR COMO LOS
DEMÁS ANIMALES, EL AKUKO FUN FUN SE QUEDÓ CON ÉL, DEMOSTRANDO SU VALENTÍA Y DETERMINACIÓN.
CUANDO LLEGÓ EL MOMENTO INEVITABLE Y LA FIGURA DE IKU, LA MUERTE, APARECIÓ PARA LLEVARSE
AL AWO, EL AKUKO FUN FUN NO DUDÓ EN HACERLE FRENTE. DESAFIANTE, LE DIJO A IKU QUE ANTES DE
LLEVARSE AL AWO, PRIMERO TENDRÍA QUE VENCERLO A ÉL. LA PELEA COMENZÓ, Y EL AKUKO DESPLEGÓ
SU VALENTÍA Y SABIDURÍA ESPIRITUAL. DURANTE LA LUCHA, EL AKUKO FUN FUN COMENZÓ A SOLTAR
JUJUS, Y UNA DE ELLAS SE CLAVÓ EN EL CUELLO DE IKU. LA MOLESTIA CAUSADA POR LA JUJÚ HIZO
QUE IKU MOVIERA LA CABEZA EN UN INTENTO DESESPERADO POR QUITÁRSELO, PERO NO PODÍA ENTENDER
LA NATURALEZA DEL MALEFICIO. MOLESTA Y CONFUNDIDA, IKU FINALMENTE SE RETIRÓ, Y EL AKUKO
FUN FUN EMERGIÓ VICTORIOSO, SALVANDO ASÍ LA VIDA DEL AWO. EBO AKUKO FUN-FUN KEKERE, COLLAR
DE JUJU, EKU, EYA, AWADO, OPOLOPO OWO. PROCEDIMENTO: SE LIMPIA AL ENFERMO QUE ESTA EN CAMA
Y SE LE HACE UN COLLAR DE JUJU PARA QUE LO USE HASTA QUE SE LEVANTE Y EL AKUKO LO TIENE EN
LA CASA HASTA QUE SE MUERA. ENSEÑANZAS: LEALTAD INQUEBRANTABLE: LA LEALTAD DEL AKUKO FUN
FUN AL PERMANECER AL LADO DEL AWO ENFERMO, INCLUSO CUANDO OTROS ANIMALES LO ABANDONARON,
DESTACA LA IMPORTANCIA DE LA LEALTAD INQUEBRANTABLE EN TIEMPOS DIFÍCILES. LA VERDADERA
AMISTAD Y LEALTAD SE MANIFIESTAN CUANDO LAS CIRCUNSTANCIAS SON ADVERSAS. CORAJE Y
DETERMINACIÓN: LA VALENTÍA DEL AKUKO FUN FUN AL ENFRENTARSE A LA MUERTE PERSONIFICADA
(IKU) RESALTA LA IMPORTANCIA DEL CORAJE Y LA DETERMINACIÓN ANTE LAS ADVERSIDADES. A VECES,
ENFRENTARSE A LOS DESAFIOS CON VALENTIA PUEDE RESULTAR EN LA SUPERACIÓN DE SITUACIONES
APARENTEMENTE IMPOSIBLES. RECONOCIMIENTO Y GRATITUD: EL EBO REALIZADO EN AGRADECIMIENTO
POR LA PROTECCIÓN DEL AKUKO FUN FUN RESALTA LA IMPORTANCIA DEL RECONOCIMIENTO Y LA
GRATITUD POR LAS ACCIONES VALIENTES Y DESINTERESADAS. MOSTRAR GRATITUD FORTALECE LOS LAZOS
Y FOMENTA LA RECIPROCIDAD EN LAS RELACIONES. EN RESUMEN, LA HISTORIA DEL AWO Y EL AKUKO
FUN FUN ENSEÑA SOBRE LA LEALTAD, EL CORAJE, LA SABIDURÍA ESPIRITUAL, LA GRATITUD, LA
FUERZA DE LA COMUNIDAD Y LA INTRINCADA RELACIÓN ENTRE LO ESPIRITUAL Y LO MUNDANO. ESTAS
LECCIONES PUEDEN APLICARSE TANTO EN EL ÁMBITO ESPIRITUAL COMO EN LA VIDA COTIDIANA.''',
  '113. NO SE BURLE DE LOS BORRACHOS.': '''PATAKI: ORÚNMILA, A PESAR DE SU GRAN SABIDURÍA Y PODER ESPIRITUAL, TENÍA UN ENEMIGO
FORMIDABLE QUE REPRESENTABA UNA AMENAZA CONSTANTE EN SU VIDA. ESTE ENEMIGO, CUYA FUERZA
ERA TAL QUE ORÚNMILA NO PODÍA DESAFIAR DIRECTAMENTE, CONSPIRABA CONSTANTEMENTE PARA ACABAR
CON ÉL. CONSCIENTE DE LA PELIGROSA SITUACIÓN, ORÚNMILA SE MANTENÍA ALERTA, REALIZANDO
CONSULTAS CONTINUAS Y TOMANDO PRECAUCIONES PARA PROTEGERSE DE LA TRAICIÓN QUE ACECHABA. EN
UNA OCASIÓN CRUCIAL, ORÚNMILA DECIDIÓ REALIZARSE UN OSODE, UNA ADIVINACIÓN SAGRADA QUE
REVELARIA LOS SECRETOS DEL DESTINO. FUE ENTONCES CUANDO EMERGIÓ EL ODU QUE SEÑALABA QUE UN
BORRACHO SE ENFERMARÍA. INTRIGADO POR LA REVELACIÓN, ORÚNMILA COMPRENDIÓ QUE ESTE EVENTO
APARENTEMENTE TRIVIAL PODRÍA CONTENER LA CLAVE PARA DESCUBRIR LA IDENTIDAD DE SU ENEMIGO
Y, LO QUE ES MÁS IMPORTANTE, CÓMO CONTRARRESTAR SU MALÉVOLO PLAN. ORUNMILA ES SOLICITADO
EN CASA DE OBATALA AL ENCONTRARSE ESTE ENFERMO Y LUEGO DE DARLE LA SOLUCIÓN A SU PROBLEMA
LE COMENTA LA SITUACIÓN DE GUERRA QUE TENÍA CON UN ENEMIGO OCULTO. OBATALA ENTONCES DECIDE
HACERSE PASAR POR UN BORRACHO, SUMERGIÉNDOSE EN UNA SITUACIÓN EN LA QUE SU ESTADO
ALCOHÓLICO LE PERMITIRÍA PERCIBIR Y COMPRENDER ASPECTOS OCULTOS DE SU ENTORNO. EN EL
TRANSCURSO DE LA FARSA DE HACERSE EL BORRACHO, COMO NADIE LE PRESTABA ATENCIÓN E INCLUSO
SE BURLABAN DE ÉL, OBATALA CONSIGUIÓ IDENTIFICAR A LOS ENEMIGOS DE ORUNMILA QUE HABLARON
DE TODOS SUS PLANES YA QUE ESTABAN CONVENCIDOS QUE EL BORRACHO NO LES ESCUCHABA. FUE ASÍ
COMO ORÚNMILA LOGRÓ IDENTIFICAR A SU ENEMIGO Y DESCUBRIR LOS DETALLES DE LA TRAICIÓN QUE
SE CERNÍA SOBRE ÉL Y GANARLE LA GUERRA A SU ENEMIGO. ENSEÑANZAS: HUMILDAD Y ADAPTABILIDAD:
ORÚNMILA, A PESAR DE SU GRAN SABIDURÍA, DEMOSTRÓ HUMILDAD AL NO SUBESTIMAR LA IMPORTANCIA
DE UN OSODE, INCLUSO CUANDO ENFRENTABA A UN ENEMIGO FORMIDABLE. LA HISTORIA DESTACA LA
ADAPTABILIDAD DE ORÚNMILA AL BUSCAR RESPUESTAS EN LUGARES APARENTEMENTE INESPERADOS, COMO
LA REVELACION DE QUE UN BORRACHO SE ENFERMARIA. UTILIZACIÓN DE ROLES INUSUALES: LA
DECISIÓN DE OBATALA DE REPRESENTAR EL PAPEL DE UN BORRACHO MUESTRA CÓMO LA ADOPCIÓN DE
ROLES INUSUALES PUEDE SER UNA ESTRATEGIA EFECTIVA PARA OBTENER INFORMACIÓN VALIOSA. A
VECES, SUMERGIRSE EN SITUACIONES APARENTEMENTE DESFAVORABLES PUEDE REVELAR VERDADES
OCULTAS. LA FUERZA DE LA ESTRATEGIA: LA ESTRATEGIA DE OBATALA AL HACERSE PASAR POR UN
BORRACHO DEMUESTRA CÓMO LA INTELIGENCIA Y LA ASTUCIA PUEDEN SER ARMAS PODEROSAS CONTRA
ENEMIGOS APARENTEMENTE INVULNERABLES. LA HISTORIA RESALTA LA IMPORTANCIA DE PENSAR DE
MANERA ESTRATÉGICA EN LA RESOLUCIÓN DE PROBLEMAS. LECCIONES SOBRE CONFIDENCIALIDAD: LA
HISTORIA ENFATIZA LA IMPORTANCIA DE LA CONFIDENCIALIDAD AL REVELAR QUE LOS ENEMIGOS DE
ORUNMILA HABLARON ABIERTAMENTE DE SUS PLANES CREYENDO QUE EL BORRACHO NO LES ESCUCHABA.
ESTO SUBRAYA CÓMO LA DISCRECIÓN Y LA PRIVACIDAD SON FUNDAMENTALES EN SITUACIONES
ESTRATÉGICAS. LA COLABORACIÓN ENTRE ORISHAS: LA INTERVENCIÓN DE OBATALÁ EN LA FARSA DEL
BORRACHO MUESTRA CÓMO LOS ORISHAS PUEDEN COLABORAR PARA PROTEGERSE MUTUAMENTE. LA
COOPERACIÓN ENTRE LAS DEIDADES ESPIRITUALES DESTACA LA UNIDAD Y LA SOLIDARIDAD. EN
RESUMEN, LA HISTORIA DE ORÚNMILA Y SU ESTRATEGIA PARA DESCUBRIR A SUS ENEMIGOS OFRECE
LECCIONES SOBRE HUMILDAD, ADAPTABILIDAD, LA IMPORTANCIA DE LA ADIVINACIÓN, ESTRATEGIA,
CAPACIDAD DE OBSERVACIÓN Y COLABORACIÓN ENTRE LOS ORISHAS PARA ENFRENTAR Y SUPERAR
AMENAZAS. EBO: AKUKO, EYELE MEYI, TRES CLAVOS, TIERRA DE LA PUERTA YDE TRES ESQUINAS, TRES
PIEDRAS, UNA BOTELLA DE OTI, YESA BEBIDA SE ECHA ALREDEDOR DE BABA.''',
  '114. NACIO EL RELOJ DE ARENA, EL DIA Y LA NOCHE.': '''PATAKI: ORÚNMILA, AL OBSERVAR LA ARDUA LABOR DEL SOL TODOS LOS DÍAS, REFLEXIONÓ SOBRE LA
NECESIDAD DE ENCONTRAR UNA MANERA DE MANTENER EL EQUILIBRIO EN EL MUNDO. TEMÍA QUE LA
PERSISTENTE EXPOSICIÓN AL CALOR PUDIERA GENERAR CONSECUENCIAS EXTREMAS, COMO QUE LOS SERES
HUMANOS SE VOLVIERAN SALVAJES POR EL CALOR O MURIERAN DE FRÍO. DECIDIDO A ENCONTRAR UNA
SOLUCIÓN, SE DIRIGIÓ UN DÍA A LA PLAYA EN BUSCA DE RESPUESTAS. EN LA PLAYA, ORÚNMILA
RECOGIÓ 16 PEQUEÑAS PIEDRAS Y COMENZÓ A PASARLAS DE UNA MANO A OTRA, ALTERNANDO SU MIRADA
ENTRE EL CIELO Y EL MAR. MIENTRAS REALIZABA ESTE ACTO, TRAZÓ CUATRO LÍNEAS EN LA ARENA,
DOS A CADA LADO, MARCANDO ASÍ EL INICIO DE UN ODU SIGNIFICATIVO. AL COMPLETAR ESTE RITUAL,
ORÚNMILA NOTÓ UNA SOMBRA O UNA PRESENCIA INUSUAL QUE SE ACERCABA DESDE EL MAR HACIA DONDE
ÉL SE ENCONTRABA. CON CURIOSIDAD, ORÚNMILA ESPERÓ LA LLEGADA DE ESTA ENTIDAD MISTERIOSA,
QUE RESULTÓ SER OLOKUN. EN ESE MOMENTO, ORÚNMILA REALIZÓ REZOS Y LLAMÓ A ESA FUERZA DEL
MAR PARA EXPRESAR SUS DESEOS PARA EL BIENESTAR DE TODOS. OLOKUN, EN SENAL DE DISPOSICIÓN,
SE PUSO A SU SERVICIO. ORUNMILA, UTILIZANDO DOS GUIROS SECOS QUE TENIA A MANO, EXTRAJO LAS
SEMILLAS MOJADAS CON AGUA DE MAR Y COLOCÓ ARENA EN UNO DE ELLOS. LUEGO, COLOCÓ EL GUIRO
CON ARENA SOBRE EL OTRO, UNIENDO LOS DOS AGUJEROS Y ATÁNDOLOS CON TIRAS DE MAJAGUA.
REALIZÓ MÁS REZOS Y DEJÓ LOS GUIROS EN ESA DISPOSICIÓN ANTES DE REGRESAR A SU HOGAR.
MIENTRAS SE ALEJABA, LA SOMBRA O ENTIDAD DEL MAR TAMBIÉN DESAPARECIÓ. AL DÍA SIGUIENTE,
ORÚNMILA REGRESÓ A LA PLAYA Y NOTÓ QUE LA ARENA DEL GUIRO SUPERIOR SE HABÍA VACIADO EN EL
INFERIOR. ESTA OBSERVACIÓN LO CONVENCIÓ DE QUE ESTA PRÁCTICA PODRÍA SER LA SOLUCIÓN QUE
BUSCABA. ORÚNMILA LLAMÓ NUEVAMENTE A OLOKUN, SOLICITANDO QUE, CUANDO EL GUIRO SE LLENARA,
SU REPRESENTANTE EMERGIERA DEL MAR Y ALUMBRARA AL MUNDO, ALIVIANDO ASÍ LA CARGA DE TRABAJO
DEL SOL. TAMBIÉN PIDIÓ QUE APARECIERA ALGUIEN PARA CAMBIAR LOS GUIROS CUANDO SE VACIARAN.
ASÍ NACIÓ EL RELOJ DE ARENA Y, CON ÉL, LOS CICLOS DEL DÍA Y LA NOCHE. LA AURORA BOREAL,
COMO MENSAJERA DE LA MADRUGADA, SE ENCARGARÍA DE ANUNCIAR EL CAMBIO DE LOS GUIROS. ESTE
INGENIOSO SISTEMA PERMITIÓ UNA DISTRIBUCIÓN EQUITATIVA DE LA LUZ SOLAR Y LUNAR,
ESTABLECIENDO UN EQUILIBRIO EN EL TIEMPO Y MARCANDO EL SURGIMIENTO DEL DÍA Y LA NOCHE EN
EL MUNDO. ENSEÑANZAS: OBSERVACIÓN Y REFLEXIÓN: ORÚNMILA DEMOSTRÓ LA IMPORTANCIA DE
OBSERVAR Y REFLEXIONAR SOBRE LOS FENÓMENOS NATURALES Y LAS NECESIDADES DE LA HUMANIDAD.
ESTA HABILIDAD DE OBSERVACIÓN AGUDA LE PERMITIÓ IDENTIFICAR UN PROBLEMA POTENCIAL Y BUSCAR
UNA SOLUCIÓN. HUMILDAD Y COLABORACIÓN: A PESAR DE LA GRAN SABIDURÍA Y PODER ESPIRITUAL DE
ORÚNMILA, RECONOCIÓ LA NECESIDAD DE COLABORAR CON OLOKUN, UNA FUERZA DEL MAR. ESTA
HUMILDAD Y DISPOSICIÓN PARA TRABAJAR EN CONJUNTO RESALTAN LA IMPORTANCIA DE LA
COLABORACIÓN PARA ABORDAR DESAFÍOS COMPLEJOS. INNOVACIÓN Y CREATIVIDAD: LA CREACIÓN DEL
RELOJ DE ARENA REVELA LA INNOVACIÓN Y LA CREATIVIDAD DE ORUNMILA AL ENCONTRAR UNA SOLUCION
UNICA PARA EQUILIBRAR LA EXPOSICIÓN AL SOL Y LA NECESIDAD DE LUZ Y OSCURIDAD EN LA TIERRA.
SIMBOLISMO DEL TIEMPO: EL RELOJ DE ARENA SIMBOLIZA LA GESTIÓN DEL TIEMPO Y LA ALTERNANCIA
ENTRE EL DIA Y LA NOCHE. LA HISTORIA DESTACA LA IMPORTANCIA DE REGULAR EL TIEMPO PARA
MANTENER EL ORDEN Y LA ARMONIA EN LA VIDA COTIDIANA. EN RESUMEN, LA HISTORIA TRANSMITE
ENSEÑANZAS SOBRE OBSERVACIÓN, HUMILDAD, COLABORACION, INNOVACIÓN, RESPETO POR LA
NATURALEZA, EQUIDAD, APRECIO POR LO INVISIBLE Y CONCIENCIA DEL CAMBIO, PROPORCIONANDO
LECCIONES APLICABLES A LA VIDA COTIDIANA Y ESPIRITUAL. EBO: AKUKO, ADIE MEYI, EYELE MEYI
FUN-FUN, EYELE MEYI COLORCANELA, DOS BOTELLAS DE AGUA DE RIO Y OTRA DE MAR, ARENA, DOS
GUIROS REGULARES, EKU, EYA, AWADO, OPOLOPO OWO.''',
  '115. OLERGUERE EL TRAMPOSO.': '''PATAKI: HABÍA UNA VEZ UN HOMBRE LLAMADO OLERGUERE, ENTREGADO A LAS VENTAS Y A LAS RIFAS,
PERO SU CARÁCTER ESTABA MANCHADO POR LA TRAMPA Y EL ENGAÑO. DERROCHABA GRANDES SUMAS DE
DINERO EN GASTOS INNECESARIOS, SUMIENDO ASÍ SU FORTUNA EN LA DESDICHA Y RETRASANDO SU
EVOLUCIÓN PERSONAL. EN UNA SITUACIÓN DESESPERADA, OLERGUERE IDEÓ UNA RIFA DE OWO (DINERO)
SIN TENER NADA TANGIBLE QUE OFRECER COMO PREMIO. EL DIA DEL SORTEO, DOS PERSONAS
RESULTARON AGRACIADAS, PERO AL CARECER OLERGUERE DE BIENES QUE CUMPLIMENTARAN EL PREMIO,
SE VIO OBLIGADO A ESCONDERSE, YA QUE UNO DE LOS AGRAVIADOS SE ACERCABA CON UN PALO Y EL
OTRO PORTABA UN REVÓLVER, MIENTRAS QUE UN AMIGO SUYO, TAMBIÉN INVOLUCRADO EN LA RIFA,
DESENVAINÓ UN CUCHILLO. OLERGUERE NO PUDO SALIR HASTA QUE LOS PERJUDICADOS SE RETIRARON,
PLANEANDO REGRESAR AL DÍA SIGUIENTE PARA AJUSTAR CUENTAS. APROVECHANDO ESTA OPORTUNIDAD,
SE DIRIGIÓ A REGISTRARSE CON ORÚNMILA, QUIEN LE REVELÓ ESTE ODU Y LE INDICÓ LA NECESIDAD
DE REALIZAR UN EBBO CON AKUKO, TRES AGBORANES, UN REVÓLVER, UN OBE Y UN PALO. CONCLUIDO EL
EBO, SE LE PUSO A OGGÚN(SE PREGUNTA CUANTO TIEMPO Y SI ESTÁ COMPLETO CON ESO), Y UNA VEZ
COMPLETADO EL RITUAL, ORÚNMILA ENTREGÓ A OLERGUERE UN POCO DE IYE DE FLORES DE LA MATA DE
AROMA Y DE LAS FLORES DE MARAVILLA BLANCA. ESTE AFOSHE DEBIA SER SOPLADO DURANTE TRES DÍAS
CONSECUTIVOS, POR LA MAÑANA Y A LAS SIETE DE LA NOCHE, DESDE LA PUERTA DE SU CASA HACIA LA
DERECHA Y LA IZQUIERDA. ASÍ, OLERGUERE LOGRÓ EVADIR A LOS ENEMIGOS QUE INTENTABAN
ARREBATARLE LA VIDA. EBO: AKUKO, ADIE MEYI, EYELE MEYI FUN FUN, EYELE MEYI COLOR CANELA,
DOS BOTELLAS DE AGUA DE RIO Y OTRA DE MAR, ARENA, DOS GUIROS REGULARES, EKU, EYA, AWADO,
OPOLOPO OWO. ENSEÑANZAS: CONSECUENCIAS DE COMPORTAMIENTOS NEGATIVOS: OLERGUERE, DEBIDO A
SU COMPORTAMIENTO TRAMPOSO Y DERROCHADOR, SE ENCONTRÓ EN UNA SITUACIÓN DESFAVORABLE. LA
HISTORIA DESTACA COMO LAS ACCIONES NEGATIVAS PUEDEN TENER REPERCUSIONES EN LA FORTUNA Y LA
SEGURIDAD PERSONAL. PRUDENCIA EN LAS DECISIONES: LA RIFA IMPULSIVA SIN TENER NADA QUE
OFRECER COMO PREMIO ILUSTRA LA FALTA DE PRUDENCIA EN LAS DECISIONES FINANCIERAS Y DE VIDA.
LA HISTORIA SUGIERE LA IMPORTANCIA DE CONSIDERAR LAS CONSECUENCIAS ANTES DE TOMAR
DECISIONES IMPULSIVAS. BUSCAR ASESORAMIENTO Y ORIENTACIÓN: BUSCAR ASESORAMIENTO Y
ORIENTACIÓN ESPIRITUAL CUANDO SE ENFRENTAN DESAFÍOS SIGNIFICATIVOS. RESPETO POR LA
TRADICIÓN Y LAS PAUTAS ESPIRITUALES: LA HISTORIA ENFATIZA LA IMPORTANCIA DE RESPETAR LAS
TRADICIONES Y SEGUIR LAS PAUTAS ESPIRITUALES PARA ENFRENTAR DESAFÍOS. OLERGUERE BUSCÓ
REFUGIO EN LA SABIDURÍA DE ORÚNMILA Y SIGUIÓ LAS PRÁCTICAS RITUALES PRESCRITAS. EVITAR LA
CONFRONTACIÓN DIRECTA: LA DECISIÓN DE OLERGUERE DE ESCONDERSE Y BUSCAR LA INTERVENCIÓN DE
ORÚNMILA EN LUGAR DE ENFRENTARSE DIRECTAMENTE A SUS PERSEGUIDORES MUESTRA LA SABIDURIA DE
EVITAR CONFRONTACIONES INNECESARIAS. EN CONJUNTO, ESTAS LECCIONES RESALTAN LA IMPORTANCIA
DE LA PRUDENCIA, LA BÚSQUEDA DE ORIENTACIÓN ESPIRITUAL, EL RESPETO POR LAS TRADICIONES, Y
LA CAPACIDAD DE ADAPTARSE Y CAMBIAR PARA SUPERAR DESAFIOS Y MEJORAR LA PROPIA SUERTE''',
  '116. CUANDO ESHU ENSEÑO A ORÚNMILA A USAR EL ORACULO DE LA ADIVINACION.': '''ADIVINACION. PATAKI: ESHU PROPUSO A ORÚNMILA UN PACTO EN EL CUAL ESHU HARÍA A ORÚNMILA EL
REY DE LA RELIGIÓN, OTORGÁNDOLE EL PODER DE CONTROLAR LA VIDA Y LA MUERTE, ASÍ COMO LA
CAPACIDAD DE REVELAR EL PASADO, PRESENTE Y FUTURO A LOS SERES HUMANOS. EN ESTE ACUERDO,
ORÚNMILA ACTUARÍA COMO EL INTERMEDIARIO ENTRE LOS ORISHAS Y LOS HUMANOS. AL PREGUNTAR
ORÚNMILA QUÉ PEDÍA A CAMBIO DE ESTOS PODERES, ESHU RESPONDIÓ QUE QUERÍA SER ELJEFE
INMEDIATO DESPUÉS DE ORÚNMILA, EL PRIMER ORISHA A TENER EN CUENTA, Y QUE ORÚNMILA LE
PROPORCIONARA COMIDA ANTES QUE A LOS DEMÁS ORISHAS. ESTA PETICIÓN SE REFLEJA EN LOS
EBOSES, RITUALES QUE INCLUYEN ELEMENTOS COMO OWUNKO, AKUKO, EKU, EYA Y EPO. ORÚNMILA,
CONSIDERANDO LA IMPORTANCIA DEL PACTO, CONSULTÓ CON OLOFIN, QUIEN CONFIRMÓ QUE HABÍA
ORDENADO A ESHU CONCERTAR EL PACTO Y RESPALDÓ LA PROPUESTA. ORÚNMILA ACEPTÓ EL PACTO, Y
ESHU LE ENSEÑÓ TODO LO RELACIONADO CON EL ORÁCULO Y LA ADIVINACIÓN. ORÚNMILA COMENZÓ A
ORGANIZAR LOS 16 ODDUN MEJIS, ASIGNÁNDOLES NOMBRES DE ACUERDO CON SU APARICIÓN EN EL IBI
IDAJUN Y SU GRAVEDAD SIN EMBARGO, CUANDO INTENTÓ NOMBRAR EL PRIMER ODU, ESHU, PREOCUPADO
DE QUE ORÚNMILA NO CUMPLIERA EL PACTO Y APROVECHÁNDOSE DE SU POCA PRÁCTICA EN IFA, HIZO
QUE EL PRIMER ODU, LA CONFIANZA DE IFA, RESULTARA MALO, LLAMÁNDOLO BURU-BURU, QUE
SIGNIFICA MALO MALÍSIMO. ESHU TAMBIÉN QUERÍA PROBAR A ORÚNMILA PARA VER SI SE HACÍA PASAR
POR ADIVINADOR. ENTONCES, PROPUSO QUE EL PRIMER ODU, BURU-BURU, PASARA AL ÚLTIMO LUGAR Y
QUE OFUN OCUPARA EL PRIMER LUGAR. AUNQUE ORÚNMILA ACEPTÓ, OFUN RESULTÓ TAN INCONTROLABLE
COMO BURU-BURU. ANTE LAS DIFICULTADES, ESHU SUGIRIÓ TRAER DE NUEVO A BURU-BURU, PERO
ORÚNMILA NO QUERÍA. ESHU, PROMETIENDO CAMBIARLO Y HACERLO NUEVO CON VIRTUDES COMO NOBLEZA,
PUREZA, INTELIGENCIA, VALENTÍA Y CAPACIDAD, CONVENCIÓ A ORÚNMILA. ORÚNMILA ACEPTÓ, PERO
ESHU, A PESAR DE PROMETER COMPORTARSE BIEN, VOLVIÓ A ENGAÑAR A ORÚNMILA, CONSAGRANDO
NUEVAMENTE AL MISMO BURU-BURU CON TODAS SUS VIRTUDES Y DEFECTOS CON EL NOMBRE CAMBIADO A
EJÍOGBÉ. ESTE CAMBIO DE NOMBRES SIMBOLIZA EL PASO DE OFUN, DE SER EL PRIMERO, A OCUPAR EL
ÚLTIMO LUGAR, Y EJÍOGBÉ, SIENDO EL ÚLTIMO, A SER EL PRIMERO. COMO ESHU ES EL DUEÑO DE LA
LLUVIA, ACORDÓ CON OLORUN REPRESENTAR A EJÍOGBÉ POR EL CAMINO DEL BIEN, MIENTRAS ÉL LO
REPRESENTARÍA POR EL CAMINO DEL MAL. DURANTE LA CONSAGRACIÓN DE ESHU, ESTE PROVOCÓ UNA
FUERTE LLUVIA CON SU ARTE MALÉVOLO (EJI ES LLUVIA Y OGBE ES CESAR O CORTAR), JUSTIFICANDO
ASÍ EL NOMBRE DE ESTE ODU. EJÍOGBÉ REPRESENTA TANTO LO BUENO COMO LO MALO, Y SE ACONSEJA
TENER PRECAUCIÓN AL TRATAR CON ÉL. ENSEÑANZAS: PACTO Y RESPONSABILIDAD: LA HISTORIA
DESTACA LA IMPORTANCIA DE LOS PACTOS Y ACUERDOS EN LA RELIGIÓN Y LA VIDA EN GENERAL.
ORÚNMILA, AL ACEPTAR EL PACTO PROPUESTO POR ESHU, ASUME UNA GRAN RESPONSABILIDAD COMO
INTERMEDIARIO ENTRE LOS ORISHAS Y LOS HUMANOS, DEMOSTRANDO CÓMO LAS DECISIONES Y
COMPROMISOS PUEDEN TENER CONSECUENCIAS SIGNIFICATIVAS. LA DUALIDAD DE ESHU: ESHU, AL
REPRESENTAR TANTO EL BIEN COMO EL MAL EN LA HISTORIA, ILUSTRA LA DUALIDAD INHERENTE EN LA
NATURALEZA HUMANA Y EN LAS FUERZAS ESPIRITUALES. ESTE ASPECTO DUAL SE MANIFIESTA EN LA
CAPACIDAD DE ESHU PARA PROVOCAR TANTO LA LLUVIA BENEFICIOSA COMO PARA DESENCADENAR SU ARTE
MALÉVOLO. LA IMPORTANCIA DE LA CONSULTA: ORÚNMILA, AL CONSULTAR CON OLOFIN ANTES DE
ACEPTAR EL PACTO, MUESTRA LA IMPORTANCIA DE BUSCAR ORIENTACION Y SABIDURIA ANTES DE TOMAR
DECISIONES TRASCENDENTALES. LA CONSULTA CON FUENTES SABIAS Y CONFIABLES PUEDE SER CRUCIAL
PARA EVITAR CONSECUENCIAS NEGATIVAS. LA PRUEBA Y LA SUPERACIÓN: ESHU SOMETE A ORÚNMILA A
PRUEBAS PARA EVALUAR SU HABILIDAD COMO ADIVINO Y SU INTEGRIDAD PARA CUMPLIR EL PACTO.
ORÚNMILA ENFRENTA DIFICULTADES PERO DEMUESTRA SU CAPACIDAD PARA SUPERARLAS, LO QUE RESALTA
LA IMPORTANCIA DE LA PERSEVERANCIA Y LA ADAPTABILIDAD EN SITUACIONES DESAFIANTES. CUIDADO
CON LAS APARIENCIAS: EL CAMBIO DE NOMBRES Y LA TRANSFORMACIÓN DE SIGNIFICADOS SUBRAYAN LA
NECESIDAD DE MIRAR MÁS ALLÁ DE LAS APARIENCIAS, LAS COSAS NO SIEMPRE SON LO QUE PARECEN, Y
LA HISTORIA ADVIERTE SOBRE LA IMPORTANCIA DE LA CAUTELA Y LA COMPRENSIÓN PROFUNDA ANTES DE
JUZGAR O TOMAR DECISIONES. DUALIDAD EN LA NATURALEZA HUMANA: LA HISTORIA REFLEJA LA
DUALIDAD EN LA NATURALEZA HUMANA, REPRESENTADA POR LA CAPACIDAD DE ESHU PARA PROVOCAR
TANTO EVENTOS BENEFICIOSOS COMO MALÉVOLOS. ESTA DUALIDAD ES UN RECORDATORIO DE LA
COMPLEJIDAD DE LAS PERSONAS Y LA IMPORTANCIA DE EQUILIBRAR LAS FUERZAS OPUESTAS EN LA
VIDA. EN CONJUNTO, ESTAS LECCIONES PROPORCIONAN UNA VISIÓN MÁS PROFUNDA DE LA COMPLEJIDAD
DE LAS RELACIONES ENTRE LOS SERES DIVINOS Y HUMANOS, ASÍ COMO LAS DECISIONES QUE DAN FORMA
A LA VIDA ESPIRITUAL Y COTIDIANA.''',
  '117. NACIO QUE OSUN E IFA ANDEN JUNTOS.': '''PATAKI: EN LA TIERRA DE AGBANILODO RESIDÍA AWO OMO ORI OSHE, QUIEN ERA HIJO DE BABA EJÍ
OGBE Y SE ENCARGABA DE RESGUARDAR EL SECRETO DE AWO AMONSUN Y AWO AMORUN. ESTOS SECRETOS
HABÍAN SIDO OCULTADOS AL CONSAGRAR A AWO AKUEYERI MABOYA, EL CUAL ERA OLOFIN BABA ORUN
ODDUN. OMO EJÍ OGBE OMO ORI OSHE TENÍA LA RESPONSABILIDAD DE ABRIR LOS OJOS DE IFÁ EN AYE
PARA GBOGBO OSHA. LO HACÍA CUANDO OLOFIN DEJABA CAER LOS IKINES DESDE LO ALTO DE OPE NIFA
EN INLE IFE, LUGAR DONDE ÉL SE ESCONDÍA. AL LANZAR UNO, DECÍA: "OKANSHOSHON ORUN BAWA ENI
IFA IBOYO". ASÍ, OMO BABA EJÍ OGBE, AWO OMO ORI OSHE, TENÍA UN SOLO OJO EN LA TIERRA.
ANTES DE COMENZAR ESTA TAREA, AWO OMO ORI OSHE CONVOCABA A OLOFIN EN ELESE OPE NIFA CON EL
SIGUIENTE REZO: "OMO BABA EJÍ OGBE OMO ORI OSHE MOKUERE MAWANI IFAAWO PAKAN OMO KUNIFA IFA
OBOYO". SIN EMBARGO, LA FIRMEZA ESTABA AUSENTE DEBIDO A LA FALTA DE OSUN, EL CUAL ERA
CUSTODIADO POR AWO ORI MAYE, QUIEN SE RESISTÍA A QUE AWO OMO ORI OSHE ATENDIERA A OLOFIN.
POR ENDE, AWO ORI MAYE OMO OGBE ROSUN MANTUVO A OSUN ATADO, IMPIDIENDO SU LLEGADA JUNTO A
AWO OMO ORI OSHE, OBSERVANDO TODO LO QUE HACÍA AWO BABA EJÍ OGBE AL PIE DE OPE NIFA. LLENO
DE ENVIDIA. SHANGO, MOLESTO POR LA FALTA DE FIRMEZA EN LA TIERRA, CONFRONTÓ A AWO OMO ORI
MAYE OGBE ROSUN Y LIBERÓ A OSUN, QUIEN CORRIÓ HACIA OPE NIFA. SHANGO EMPEZÓ A CANTAR:
"OSUN MAWANI ODDUN ENI IFA SHANGO OMO ORI OSHE ODDUNOBANILORUN AGBA NI BOSHE AWO OMO
MAYIRE MAYIRE AWO." Y COMENZÓ A COMER EYELE JUNTO A OSUN, SENTENCIANDO: "DESDE AHORA, OSUN
E IFA ANDARAN JUNTOS". AWO BABA EJÍ OGBE, OMO ORI OSHE, INICIÓ LA ATEFA Y SALIÓ, SALUDÓ A
SHANGO Y DIJO: "ODDUN AYE BABA EJÍ OGBE OMORIBOSHE OYURE ODDUN BAWARI IFA ODDUN AGBAIRE".
TODOS SE ARRODILLARON Y RINDIERON HOMENAJE A AWO OMORIBOSHE Y A AWO ORI MAYE OGBE ROSUN.
ESTE ÚLTIMO, DISGUSTADO, SE RETIRÓ, SEGUIDO POR SHANGO, QUIEN LANZÓ JUJU DE GBOGBO Y AIYE
QUE HABÍA ALLÍ, REZANDO: "ABELE BELE ADIE ORUN BOWA LELE GBOGBO JUJU OSHE OGBE ROSUN ODDUN
OLOFIN IFA AWA". AWO OGBE ROSUN QUEDÓ HERMOSAMENTE ATAVIADO CON LAS JUJU DE TODOS LOS
PÁJAROS DE COLORES, Y TODOS COMENZARON A CELEBRARLO. SHANGO DIJO: "EJÍ OGBE, POR LA VIRTUD
DE AMONSUN Y AMORUN, SIEMPRE SERÁ EL PRIMERO EN ESTA TIERRA, PERO SIEMPRE DEBERÁ CUIDAR A
OSUN. OSUN SERÁ EL SEGUNDO Y ESTARÁ SIEMPRE OBSERVANDO SI EJÍ OGBE HACE BUEN O MAL USO DE
SUS PODERES". ENTONCES, TODOS COMENZARON A CANTAR: "AWO AMONSUN ATI AMORUN AGBA BI OSUN
LESE IGI LALA OPE IFA OLORUN BO OYO BATENI INSHE IFA". SHANGO TOMÓ A OSUN, A OMO BABA EJÍ
OGBE Y A OMO OGBE ROSUN PARA QUE SE ABRAZARAN JUNTOS Y EMPEZÓ A CANTAR: "BABA OSUN LADIDE,
BABA OSUN LADIDE, ITANI AWO KAYEWE ENI NIFA BABA OSUN LADIDE". Y AUNQUE EJI OGBE Y OGBE
ROSUN SE ACEPTARON, LA DESCONFIANZA SIEMPRE PERSISTIÓ ENTRE ELLOS. NOTA: POR ESO AWO BABA
EJIOGBE Y AWO OGBE ROSUN NUNCA ANDAN JUNTOS. REZO: BABA EJIOGBE AWO OMORI OSHE AGBA
OBARABANIREGUNIGBOSUN ATEFA ONI TOBELEREKUN OTO NIGBA YE IFA OYUMEDILOGUN IFA PEYE IBAYE
ADIFAFUN OLORA OYUBE IFAAGBANI OLORDUMARE OLOFIN ATEFA AGBANI LODENIFA BOKUNBOKUN ISHE
KUTE ISHE KUTE NISHE ADELE NIFA OLORUNBAWA NI ODDUN OLORDUMARE ABELE BELE NIFA AWAPE
NIFALOTUN AWRE NIFA OSI AMONSUN AGBANI BOSHE ASHANSHEREIFA AMORUN AGBANIBOSHE AGBADENIFA
KUEYERI MAGBOYAABOLERI IFA META AYE ADELE NILORUN AGBAN AGBANLODAFUN OLOFIN SHANGO ADELE
OKUN AGBANILODE AWOOMORIOSHE BABA EJIOGBE ADELE MAFUN AWO OLOYO OMA IREOYU OMO IFA
KAFEREFUN ORÚNMILA ATI SHANGO. EBO: AKUKO, ADELE, OTA, GBOGBO ILEKE OSHA, GBOGBO
ASHA,ATITAN DE ELESE OPE NIFA, MARIWO, EKU, EYA, EPO, AWADOOBI, OTI, ITANA, OPOLOPO OWO.
NOTA: EN ESTE CAMINO DE BABA EJIOGBE NACIO EL AWO CUANDO VA A RECOGER LOS IKINES EN ELESE
OPE NIFA PARA LAS CONSAGRACIONES, TIENE QUE REZAR Y CUANDO LOS ENTRA EN SU CASA LOS
PREPARA PARA DESPUES CONSAGRARLOS. LOS ADELESE SE PRUEBAN Y YA PROBADOS DELANTE DE SHANGO
SE LE REZA: ADELE BAWA ABALOLIFA OSHE ARIN ONA KOKE SHANGO IFAAGBORO OMA ADELE NIFA
ORÚNMILA OGBAIGAN SOKUN WEWE. ENSEÑANZAS: LA IMPORTANCIA DE LA COLABORACIÓN: DESTACA CÓMO
LA COLABORACIÓN ENTRE DIFERENTES ENTIDADES O FUERZAS PUEDE LLEVAR A UN EQUILIBRIO Y
ARMONÍA EN UN ENTORNO. ELVALOR DE LA VIRTUD Y LA RESPONSABILIDAD: SER EL PRIMERO CONLLEVA
RESPONSABILIDADES Y LA NECESIDAD DE ACTUAR CON VIRTUD Y CUIDADO PARA MANTENER EL
EQUILIBRIO Y LA ARMONÍA EN LA COMUNIDAD. LA SUPERACIÓN DE LA ENVIDIA: LA ENVIDIA Y LA
DESCONFIANZA PUEDEN GENERAR CONFLICTOS Y OBSTACULIZAR EL PROGRESO. SUPERAR ESTOS
SENTIMIENTOS ES CRUCIAL PARA MANTENER LA PAZ Y EL AVANCE COLECTIVO. EL RESPETO POR LOS
ROLES Y RESPONSABILIDADES: CADA INDIVIDUO TIENE SU PAPEL Y RESPONSABILIDAD EN LA SOCIEDAD.
RECONOCER Y RESPETAR ESOS ROLES ES ESENCIAL PARA MANTENER LA ESTABILIDAD Y EL ORDEN. LA
ACEPTACIÓN Y LA COLABORACIÓN A PESAR DE LAS DIFERENCIAS: AUNQUE PUEDA EXISTIR DESCONFIANZA
O DIFERENCIAS ENTRE INDIVIDUOS, LA COLABORACIÓN Y LA ACEPTACIÓN MUTUA SON FUNDAMENTALES
PARA EL BIENESTAR COLECTIVO. ESTAS LECCIONES RESALTAN VALORES UNIVERSALES DE COLABORACIÓN,
RESPONSABILIDAD, RESPETO Y CUIDADO MUTUO QUE PUEDEN APLICARSE EN DIFERENTES CONTEXTOS Y
COMUNIDADES.''',
  '118. BABA EJIOGBE NO COME BONIATO (KUKUNDUKU).': '''PATAKI: YEMAYÁ ERA UNA MUJER MAYOR, QUE SOSTENÍA SU VIDA CON LA COSECHA DE KUKUNDUKU
(BONIATO) QUE CULTIVABA. A PESAR DE SU GRAN SIEMBRA, SIEMPRE LLORABA POR NO TENER ESPOSO.
UN DÍA, MIENTRAS TRABAJABA EN EL CAMPO RECOLECTANDO KUKUNDUKU, ENCONTRÓ UNO
PARTICULARMENTE HERMOSO CON LA FORMA DE UNA PERSONA. OBSERVANDOLO DETENIDAMENTE, PENSÓ SI
ESTE KUKUNDUKU PODRÍA TRANSFORMARSE EN UN HOMBRE PARA SER SU MARIDO, PROMETIENDO SU
GRATITUD A INLE OGGUERE.EL KUKUNDUKU LE ADVIRTIÓ QUE SI SE TRANSFORMABA, ELLA NO PODRÍA
MENCIONARLE A NADIE QUE SE LLAMABA KUKUNDUKU. SORPRENDIDA, YEMAYÁ RESPONDIÓ QUE NO VIVÍA
CON NADIE EN SU CASA, SIN MARIDO NI HIJOS, POR LO QUE NO TENDRÍA A QUIÉN MENCIONARLE SU
NOMBRE. EL KUKUNDUKU LE PIDIÓ QUE SE DIERA LA VUELTA. AL HACERLO, EL KUKUNDUKU SE
TRANSFORMÓ EN UN HOMBRE JOVEN Y FUERTE, BESU AGUDEKETI, QUIEN SE FUE A VIVIR CON YEMAYÁ.
POSTERIORMENTE, VISITARON A ORÚNMILA, QUIEN LES ADVIRTIÓ QUE NINGUNO DE LOS HIJOS DE ESA
UNIÓN PODRÍA COMER KUKUNDUKU NI MENCIONARLO EN SU HOGAR, YA QUE BESU AGUDEKETI POSEIA UN
GRAN PODER DE AGBORIREGUN. REALIZARON EL EBO RECOMENDADO POR ORÚNMILA Y AL REGRESAR A
CASA, BESU AGUDEKETI PLANTÓ UNA CEIBA Y UNA ALMENDRA JUNTO A LA CASA, CADA UNA CON SU
RECIPIENTE DE AGUA DE RÍO, MAR Y ODO, CON MUCHAS OTA Y DILOGUN. ADEMÁS, COLOCÓ PAVOS
REALES PARA ALEGRAR A YEMAYÁ. TODOS EN LA COMARCA EMPEZARON A COMER KUKUNDUKU, LO QUE HIZO
QUE YEMAYÁ SE VOLVIERA RICA. UN DÍA, DURANTE UNAS FESTIVIDADES EN LA TIERRA EWADO
DEDICADAS A OLOKUN Y ODUDUWA, COMO YEMAYA NO ESTABA EN CASA, BESU AGUDEKETI FUE A RENDIR
HOMENAJE A OLOKUN Y ODUDUWA CON UN ASHO FUN-FUN. AL REGRESAR YEMAYA Y NOTAR LA AUSENCIA
DEL ASHO FUN-FUN, SE ENFADÓ ACUSANDO A BESU AGUDEKETI DE HABERSE LLEVADO SU TRAJE BLANCO Y
COMENZÓ A INSULTARLO LLAMANDOLE KUKUNDUKU. LOS AGBEYAMI (PAVOS REALES) QUE VIVÍAN BAJO LOS
ÁRBOLES COMENZARON A CANTAR, REVELANDO LA VERDAD. AUNQUE ESTABA LEJOS, BESU AGUDEKETI
PERCIBIÓ QUE YEMAYÁ HABIA ROTO SU PROMETA ASI QUE VOLVIÓ LLORANDO A CASA. AL LLEGAR,
ENCONTRÓ A LOS AGBEYAMI CANTANDO Y ASI CONFIRMÓ LO QUE HABÍA PRESENTIDO. ENTRÓ EN LA CASA,
MIRÓ A YEMAYÁ CON DESPRECIO, QUIEN LE PREGUNTÓ DE FORMA AGRESIVA DÓNDE HABÍA ESTADO CON SU
ROPA BLANCA. YEMAYA INTENTÓ QUITARLE LA ROPA, Y BESU AGUDEKETI SE TRANSFORMÓ EN MUCHOS
KUKUNDUKU. ELEGBA, QUIEN HABÍA ESCUCHADO EL CANTO DE LOS AGBEYAMI, INFORMÓ A ORÚNMILA. AL
ENTRAR EN LA CASA DE YEMAYÁ Y VER LA TRANSFORMACIÓN DE BESU AGUDEKETI, ORÚNMILA LE DIO A
YEMAYÁ QUE, DESDE ESE MOMENTO Y POR NO RESPETAR EL PACTO EN LA TIERRA DE OMO EÍ OGBE,
NADIE ALLÍ PODRÍA COMER KUKUNDUKU, PUES PERDERÍAN SU SUERTE Y SALUD Y ASÍ YEMAYÁ PERDIÓ SU
NEGOCIO Y CAYÓ DE NUEVO EN LA POBREZA. REZO: BABA EJIOGBE ENI ERI ISENI SHOGUN YEYE ADAFUN
KUKUNDU.KU TINISHE LEYA ISHU ABITI TORI SHEPE LODAFUN OMOABATIN TORIN SHOMO BENAIFIDAN
SHOMO YEMAYA OBIRINARUGBO OUN ITAKE BOSU AGUDOKOTIN AGBEYANI IGI MEYIARAGBA EGUSI LODAFUN
ORÚNMILA. EBO: AKUKO, ISHU KUKUNDUKU, JUJU AGBEYANI (PAVO REAL), IGIARAGBA, IGI EGUSI,
EKU, EYA, EPO, OPOLOPO OWO. ENSENANZAS: RESPETO A LOS ACUERDOS Y PROMESAS: EL RESPETO A
LOS PACTOS ES ESENCIAL EN CUALQUIER RELACIÓN. YEMAYÁ ROMPIÓ SU PROMESA SOBRE NO MENCIONAR
EL NOMBRE DEL KUKUNDUKU Y ESTO TRAJO CONSECUENCIAS NEGATIVAS. RESPONSABILIDAD SOBRE
NUESTRAS PALABRAS Y ACCIONES: NUESTRAS ACCIONES TIENEN REPERCUSIONES. YEMAYÁ ACTUÓ
IMPULSIVAMENTE, CULPANDO Y DESPOJANDO A BESU AGUDEKETI DE SU TRAJE BLANCO, LO QUE RESULTÓ
EN UN CAMBIO DRÁSTICO EN SU SITUACIÓN. VALORACIÓN DE LO QUE SE TIENE: LA HISTORIA RESALTA
EL VALOR DE LO QUE SE TIENE Y CÓMO, AL NO APRECIARLO ADECUADAMENTE, SE PUEDEN PERDER
OPORTUNIDADES Y BIENESTAR. ESTAS LECCIONES NOS RECUERDAN LA IMPORTANCIA DE LA INTEGRIDAD,
LA RESPONSABILIDAD Y EL RESPETO EN NUESTRAS ACCIONES Y RELACIONES, ASÍ COMO LA NECESIDAD
DE VALORAR Y APRECIAR LO QUE TENEMOS.''',
  '119. PORQUE OLOFIN SE RETIRA A LOS SEIS DIAS DE LA CEREMONIA DE IFA.': '''IFA. PATAKI: LA CORRUPCIÓN SE HABÍA APODERADO DE LA TIERRA DE TAL MANERA QUE OLOFIN
CONSIDERÓ LA OPCIÓN DE DESTRUIRLA POR COMPLETO. SIN EMBARGO, MOVIDO POR SU GRAN
MISERICORDIA, DECIDIÓ OTORGARLE OTRA OPORTUNIDAD A LA HUMANIDAD PARA SU REGENERACIÓN. FUE
ENTONCES CUANDO TOMÓ LA DECISIÓN DE ENCOMENDAR ESTA CRUCIAL TAREA A ORÚNMILA, EL SABIO
DIVINO. AL RECIBIR ESTA MISIÓN, ORÚNMILA SE SINTIÓ MOLESTO Y EXPRESÓ SU DESCONTENTO.
PREGUNTÓ A OLOFIN CÓMO PODRÍA CONFORMARSE CON VIVIR ENTRE UNA HUMANIDAD TAN CORROMPIDA Y,
AÚN MÁS, REPRESENTARLO DESPUÉS DE SU REDENCIÓN. ANTE ESTA RESPUESTA, OLOFIN, VIENDO QUE NO
TENÍA MUCHAS ALTERNATIVAS, LE DIJO A ORÚNMILA QUE IRÍA CON ÉL, PERO ÚNICAMENTE DURANTE LOS
PRIMEROS SEIS DÍAS. DESPUÉS DE ESE PLAZO, REGRESARÍA AL CIELO, YA QUE TENIA NUMEROSOS
ASUNTOS QUE RESOLVER EN ESE REINO CELESTIAL. NOTA: ESTA DECISIÓN DE OLOFIN EXPLICA POR
QUÉ, EN TODAS LAS CONSAGRACIONES DE IFÁ, AL SEXTO DÍA Y TRAS LA CEREMONIA DE LA COMIDA DE
OLOFIN, ESTE SE RETIRA DEL IGBO ODUN FÁ. OLOFIN ACOMPAÑA AL AWO (INICIADO EN IFÁ) DURANTE
EL PRIMER AÑO DE SU CONSAGRACIÓN. ORÚNMILA, POR SU PARTE, LO ACOMPAÑA DURANTE LOS PRIMEROS
SIETE AÑOS Y, POSTERIORMENTE, LO VISITA CADA CUARENTA Y UN DÍAS. ASÍ, LA INTERVENCIÓN
DIVINA EN LA TIERRA, LA PRUEBA DE ORÚNMILA Y LA PERIODICIDAD EN LA CONEXIÓN ENTRE OLOFIN Y
LOS AWOS NOS ENSEÑAN SOBRE LA IMPORTANCIA DE LA MISERICORDIA, LA PACIENCIA Y LA
RESPONSABILIDAD DIVINA EN EL PROCESO DE REGENERACIÓN Y GUÍA ESPIRITUAL. CADA DETALLE
REVELA UNA ESTRUCTURA SAGRADA DESTINADA A MANTENER EL EQUILIBRIO Y RESTAURAR LA ARMONÍA EN
LA CREACIÓN DE OLOFIN. ENSEÑANZAS: MISERICORDIA Y OPORTUNIDADES: A PESAR DE LA CORRUPCIÓN,
LA MISERICORDIA DE OLOFIN CONCEDIÓ OTRA OPORTUNIDAD A LA HUMANIDAD PARA REGENERARSE. NOS
ENSEÑA SOBRE LA IMPORTANCIA DE OFRECER SEGUNDAS OPORTUNIDADES Y CREER EN EL POTENCIAL DE
LA REDENCIÓN. RESPONSABILIDAD DIVINA Y COMPROMISO: LA RESPONSABILIDAD CONFIADA A ORÚNMILA
MUESTRA CÓMO LOS DESIGNIOS DIVINOS INVOLUCRAN COMPROMISO Y TRABAJO PARA INFLUIR EN EL
CURSO DE LA HUMANIDAD. DESTACA LA IMPORTANCIA DE LA ACCIÓN RESPONSABLE Y EL SERVICIO PARA
AYUDAR A RESTAURAR LA ARMONÍA EN LA TIERRA. RESPETO A LOS CICLOS Y TIEMPOS: LA
PERIODICIDAD EN LAS VISITAS DE ORÚNMILA Y OLOFIN A LOS AWOS RESALTA LA IMPORTANCIA DE
RESPETAR LOS CICLOS Y TIEMPOS ESTABLECIDOS EN LA VIDA ESPIRITUAL Y LA TOMA DE DECISIONES.
ESTAS LECCIONES RESALTAN VALORES COMO LA COMPASIÓN, LA RESPONSABILIDAD, EL RESPETO POR LOS
CICLOS Y LA IMPORTANCIA DE LA SABIDURIA EN LA TOMA DE DECISIONES, ENSENANZAS VALIOSAS
APLICABLES EN DIVERSAS SITUACIONES DE LA VIDA COTIDIANA.''',
  '120. EL AURA TIÑOSA ES SAGRADA Y LA CEIBA ES DIVINA.': '''PATAKI: OLORUN, EL PADRE DEL CIELO Y LA TIERRA, INSTRUYÓ A LA TIERRA CON ESTAS PALABRAS:
"TRABAJA Y HONRA AL CIELO. PROTEGE A TU HERMANO Y VIVIRÁN EN PAZ". PERO CON EL TIEMPO,
OLORUN Y AIYE (LA TIERRA) DISCUTIERON. AIYE INSISTÍA EN QUE ERA MÁS GRANDE Y PODEROSA QUE
SU HERMANO EL CIELO. ENVUELTA EN VANIDAD, QUERIA QUE SU HERMANO LE RINDIERA HOMENAJE. USÓ
UN LENGUAJE IRRESPONSABLE, EL PELIGROSO LENGUAJE DE LA IMPRUDENCIA. EN AQUELLA OCASIÓN, LA
TIERRA LE DIJO A OLORUN: "SOY LA BASE, EL FUNDAMENTO DEL CIELO. SIN MÍ, SE DERRUMBARÍA; NO
TENDRÍA MI HERMANO NADA EN QUÉ APOYARSE, NI EXISTIRIA COSA ALGUNA SI CAYERA. TODO SERIA
VAGUEDAD, INCONSISTENCIA, HUMO, NADA. SOY QUIEN SOSTIENE TODO, QUIEN SIEMPRE ACTÚA EN
APUROS, MIENTRAS ÉL SOLO CONTEMPLA. TRABAJO INCANSABLEMENTE, CREO TODAS LAS FORMAS DE
VIDA, LAS FUO Y LAS MANTENGO". "SOY LA FUENTE DE TODO; TODO SALE DE MI PODER ILIMITADO.
REPITO INSOLENTE: SOY SÓLIDA, ÉL, EN CAMBIO, ES VACÍO POR COMPLETO Y SUS RIQUEZAS NO SE
PUEDEN COMPARAR CON LAS MIAS. LOS BIENES DE MI HERMANO SON INTANGIBLES, NO PUEDE TOCAR NI
SOSTENER EN SUS MANOS AIRE, NUBES, LUCES, NADA. CONSIDERA CUÁNTO MÁS VALGO QUE ÉL. QUE
BAJE A RENDIRME HOMENAJE Y A HACERME FAVORES". OBA OLORUN, AL VERLA TAN OBSESIONADA Y
PRESUMIDA, NO LE RESPONDIÓ POR DESPRECIO. HIZO UNA SEÑA AL CIELO, QUE SE ALEJÓ AMENAZADOR,
SERENO Y TERRIBLE. "APRENDE", MURMURÓ EL CIELO AL ALEJARSE A UNA DISTANCIA
INCONMENSURABLE, APRENDE QUE EL CASTIGO NO TARDA EN LLEGAR POR NUESTRA SEPARACIÓN. LA
PALABRA DE LOS GRANDES NO LA DESHACEN LOS VIENTOS" IROKO RECOGIÓ ESAS PALABRAS Y MEDITÓ EN
EL SILENCIO DE UNA GRAN SOLEDAD QUE SURGIÓ TRAS LA SEPARACIÓN DEL CIELO Y LA TIERRA.
IROKO, LA CEIBA, HUNDIÓ SUS RAÍCES VIGOROSAS EN LO MÁS PROFUNDO DE LA TIERRA, SUS BRAZOS
SE ALZABAN ALTO EN EL CIELO. VIVÍA EN LA INTIMIDAD DEL CIELO Y LA TIERRA. EL GRAN CORAZÓN
DE IROKO TEMBLÓ DE ESPANTO AL COMPRENDER. HASTA ENTONCES, GRACIAS AL ACUERDO ENTRE ESTOS
HERMANOS, LA EXISTENCIA HABÍA SIDO UN ARTE VENTUROSO PARA TODAS LAS CRIATURAS TERRESTRES.
EL CIELO CUIDABA DE REGULAR LAS ESTACIONES CON TERNURA, HACIENDO QUE EL FRIO Y EL CALOR
FUERAN IGUALMENTE GRATOS Y BENEFICIOSOS. NI TORMENTAS NI LLUVIAS TORRENCIALES,
DESTRUCTORAS NI SEQUÍAS ASOLADORAS, HABÍAN SEMBRADO JAMÁS LA MISERIA Y LA DESOLACIÓN ENTRE
LOS HOMBRES. SE VIVÍA ALEGREMENTE, SE MORÍAN SIN DOLOR, MALES NI QUEBRANTOS. NI LOS
INDIVIDUOS MÁS VORACES PODÍAN PRESAGIAR LA DISCORDIA. LA DESGRACIA NO ERA COSA DE ESTE
MUNDO, ERA UN TIEMPO SIN CRUELDAD, UN TIEMPO ANHELADO POR TODOS, ANIMALES Y HOMBRES. LA
CRUELDAD NO EXISTÍA EN ESTE MUNDO. LOS ESPÍRITUS MALIGNOS QUE PROVOCAN PADECIMIENTOS
FÍSICOS, INVISIBLES Y ARTEROS, NO TENÍAN NOMBRE PORQUE NO EXISTÍAN; NADIE SE ENFERMABA. LA
MUERTE, DESEABLE, LIMPIA Y DULCE, SE ANUNCIABA CON SUEÑOS SUAVES. LOS HOMBRES DISFRUTABAN
DE UNA LARGA Y VENTUROSA VIDA. LA VEJEZ NO TRAÍA LA TRISTE APARIENCIA Y LOS ACHAQUES, SE
SENTÍA UN GRAN ANHELO DE INMOVILIDAD. UN SILENCIO AVANZABA LENTAMENTE POR SUS VENAS, UN
SILENCIO QUE BUSCABA DELICIOSAMENTE EL CORAZÓN. LOS OJOS SE CERRABAN LENTAMENTE, SE
OSCURECÍA SU VISIÓN, Y LA FELICIDAD INFINITA DE ENTREGARSE A MORIR SE DESVANECÍA COMO UN
HERMOSO ATARDECER. ENTONCES, LA BONDAD SÍ ERA DE ESTE MUNDO. UN MORIBUNDO PODÍA SONREÍR AL
PENSAR EN EL FESTÍN PLACENTERO QUE SU CUERPO, SANO Y HERMOSO, PROVEERÍA A INNUMERABLES Y
VORACES GUSANOS, AL IMAGINAR QUE LOS PÁJAROS PICOTEARÍAN SUS BRILLANTES OJOS CONVERTIDOS
EN SEMILLAS, QUE LAS BESTIAS FRATERNALES SE ALIMENTARÍAN DE SUS CABELLOS CONVERTIDOS EN
HIERBAS SECAS Y JUGOSAS, EN SUS HIJOS, EN SUS HERMANOS, QUE COMERÍAN SUS HUESOS
TRANSFORMADOS EN TUBERCULOS. NADIE PENSABA EN HACER DAÑO, NADIE HABIA DADO PIE A MALOS
EJEMPLOS. PERO ENTONCES, TODO CAMBIÓ. LA MEMORIA DEL BIEN PASADO SE PERDIÓ Y EL DOLOR
GOLPEÓ A LAS CRIATURAS HASTA BORRAR EL RECUERDO DE LA FELICIDAD EN LA QUE HABÍAN VIVIDO.
TODA DICHA SE HIZO REMOTA E INCREÍBLE. LA INFELICIDAD FUE MALDECIDA. FUE ENTONCES CUANDO
INCUBARON Y LLEGARON TODAS LAS DESGRACIAS, TODOS LOS HORRORES. LA PALABRA SE VOLVIÓ MALA;
EL DESCANSO DE LOS FALLECIDOS FUE PERTURBADO, Y LOS QUE MORÍAN YA NO DESCANSABAN EN LA
APACIBLE BELLEZA DE UNA NOCHE CUYA DULZURA NO TENÍA FIN. LA TIERRA PIDIÓ PERDÓN, PERO EL
CIELO, QUE TENÍA LAS AGUAS, SE MANTUVO IMPLACABLE. TODO SE CONVIRTIÓ EN POLVO ESTÉRIL,
CASI TODOS LOS ANIMALES HABÍAN MUERTO. LOS HOMBRES, ESQUELÉTICOS Y SIN ALIMENTO PARA
SOBREVIVIR NI FUERZAS PARA BUSCAR AGUA EN LA TIERRA RESECA, YACÍAN INERTES SOBRE LAS
PIEDRAS DESNUDAS, DONDE TODA VEGETACIÓN HABIA DESAPARECIDO. SOLO UN ÁRBOL EN EL MUNDO
MANTENÍA UNA COPA GIGANTESCA MILAGROSAMENTE, SE MANTENÍA FIRME Y LOZANO: ERA IROKO,
INMORTAL, QUE ADORABA AL CIELO, Y A ÉL ACUDIERON LOS MUERTOS DEL PASADO EN BUSCA DE
REFUGIO. EL ESPIRITU DE IROKO HABLABA CON EL CIELO Y TRABAJABA SIN DESCANSO POR SALVAR A
LA TIERRA Y SUS CRIATURAS. FUE ENTONCES CUANDO LOS HIJOS DE LA TIERRA, LOS ANIMALES DE
CUATRO PATAS, LOS PAJAROS, LOS POCOS HOMBRES QUE QUEDABAN Y QUE HABÍAN ADQUIRIDO VISIÓN
CLARA, REALIZARON EL PRIMER SACRIFICIO EN NOMBRE DE LA TIERRA. QUISIERON ENVIAR UNA
OFRENDA AL CIELO, PERO ESTE SE HABIA ALEJADO A UNA DISTANCIA INALCANZABLE, Y NINGUNO DE
ELLOS PODÍA LLEGAR ALLÍ SIN ALAS. ENTONCES, EL BUITRE EMPRENDIÓ EL SACRIFICIO Y SE DIRIGIÓ
AL CIELO PARA LLEVAR LA OFRENDA. AUNQUE ATRAVESÓ MIL TRABAJOS, AL FINAL LO CUMPLIÓ, SIENDO
CONSAGRADO POR OLORUN. ASÍ SE SALVÓ LA HUMANIDAD DE LA HORRENDA GUERRA ENTRE LA TIERRA Y
EL CIELO, QUE AUNQUE CONTINÚAN SEPARADOS, APLACARON SUS HOSTILIDADES. ENSENANZAS:
EQUILIBRIO Y ARMONIA: LA IMPORTANCIA DE MANTENER UN EQUILIBRIO Y ARMONÍA ENTRE LOS
DIFERENTES ELEMENTOS Y FUERZAS. LA DISCORDIA ENTRE EL CIELO Y LA TIERRA TRAJO DESASTRES Y
SUFRIMIENTO A TODAS LAS CRIATURAS. RESPETO Y COOPERACIÓN: LA NECESIDAD DE RESPETAR Y
COLABORAR ENTRE HERMANOS, INCLUSO SI TIENEN DIFERENCIAS. EL CONFLICTO ENTRE EL CIELO Y LA
TIERRA GENERÓ CONSECUENCIAS DEVASTADORAS PARA TODO LO EXISTENTE. CONSECUENCIAS DE LA
VANIDAD: LA VANIDAD Y LA PRESUNCIÓN DE LA TIERRA LLEVARON A LA ARROGANCIA Y LA FALTA DE
ENTENDIMIENTO CON EL CIELO. ESTO PROVOCÓ UN QUIEBRE EN LA RELACIÓN ENTRE AMBOS Y TRAJO
DESGRACIAS. EL VALOR DE LA PAZ Y LA COOPERACIÓN: LA EXISTENCIA ARMONIOSA ENTRE EL CIELO Y
LA TIERRA TRAJO FELICIDAD, AUSENCIA DE SUFRIMIENTO Y UNA VIDA VENTUROSA PARA TODAS LAS
CRIATURAS. LA PAZ Y LA COOPERACIÓN SON ESENCIALES PARA UNA EXISTENCIA PLENA Y FELIZ. ESTAS
LECCIONES NOS RECUERDAN LA IMPORTANCIA DE MANTENER EL EQUILIBRIO, EL RESPETO MUTUO Y LA
COOPERACIÓN PARA MANTENER LA ARMONÍA EN EL MUNDO QUE HABITAMOS.''',
  '121. EL TOQUE DE QUEDA. CUANDO ELEGBA Y OGGUN COMIERON CHIVO POR PRIMERA VEZ.': '''PRIMERA VEZ. PATAKI: DICE LA HISTORIA QUE EL REY NO SE FIABA DE SU PUEBLO, POR LO QUE
HABIA ESTABLECIDO UN TOQUE DE QUEDA EN EL QUE CUALQUIERA QUE ENTRARA O SALIERA DEL PUEBLO
SERÍA AJUSTICIADO. UNA VEZ, EL CHIVO, ENCONTRÁNDOSE EN DIFICULTADES, FUE A CASA DE
ORÚNMILA PARA QUE ESTE LO CONSULTARA, VIÉNDOLE ESTE ODÙ BABA EJIOGBE. ORÚNMILA LE HIZO EBÓ
Y LE DIJO QUE NO SALIERA DE SU CASA DURANTE SIETE DÍAS DESPUÉS DE LAS 6 DE LA TARDE, PUES
PODÍAN AJUSTICIARLO DEBIDO AL TOQUE DE QUEDA. EL CHIVO NO HIZO CASO Y SALIÓ A LA CALLE. EN
ESOS PRECISOS MOMENTOS, OBATALÁ HABÍA HECHO EBÓ Y SE ENCAMINABA FUERA DEL POBLADO PARA
BOTAR EL EBÓ, YA QUE OBATALÁ ERA LA ÚNICA PERSONA QUE PODÍA ENTRAR Y SALIR DEL PUEBLO. EL
CHIVO, AL VER A OBATALÁ CON EL EBÓ, SE LE OFRECIÓ PARA AYUDARLO. OBATALÁ LE DIJO QUE NO,
QUE ÉL PODÍA, PERO EL CHIVO INSISTIÓ TANTO QUE OBATALÁ ACCEDIÓ. EL CHIVO LE DIJO A OBATALÁ
QUE SE MONTASE SOBRE ÉL Y AMBOS EMPRENDIERON EL VIAJE. LOS GUARDIANES DE LA PUERTA DE ESE
PUEBLO ERAN ELEGUÁ Y OGÚN, Y COMO ARMA TENÍAN UN MACHETE CADA UNO. CUANDO EL CHIVO LLEGÓ A
LA PUERTA, ELEGUÁ Y OGÚN LE PREGUNTARON SI NO SABÍA QUE HABÍA TOQUE DE QUEDA. EL CHIVO
DUJO QUE SÍ, PERO QUE A ÉL NO LE IMPORTABA, MOMENTO EN QUE APROVECHARON ELEGGUÁ Y OGÚN
PARA EJECUTARLO Y COMÉRSELO. ENSENANZAS: RESPETO POR LAS NORMAS: DESTACA LA IMPORTANCIA DE
OBEDECER LAS REGLAS Y RESTRICCIONES ESTABLECIDAS POR AUTORIDADES O CONTEXTOS ESPECÍFICOS.
EL INCUMPLIMIENTO DE ESTAS NORMAS PUEDE LLEVAR A CONSECUENCIAS GRAVES. CONSECUENCIAS DE LA
ARROGANCIA Y LA TERQUEDAD: EL PERSONAJE DEL CHIVO MUESTRA QUE LA TERQUEDAD Y EL DESPRECIO
POR LAS ADVERTENCIAS PUEDEN DESENCADENAR DESASTRES. IGNORAR LAS INDICACIONES PUEDE TRAER
CONSECUENCIAS NEGATIVAS. DECISIONES INFORMADAS Y SABIAS: AUNQUE SE RECIBE CONSEJO, LA
DECISIÓN DE SEGUIR O NO ESE CONSEJO RECAE EN CADA INDIVIDUO. SIN EMBARGO, ES IMPORTANTE
TOMAR DECISIONES INFORMADAS Y REFLEXIONADAS, CONSIDERANDO LAS POSIBLES REPERCUSIONES. LA
IMPORTANCIA DEL DIÁLOGO Y EL RESPETO MUTUO: EL ENCUENTRO ENTRE EL CHIVO Y OBATALA TAMBIÉN
DESTACA LA IMPORTANCIA DE RESPETAR LAS DECISIONES DE LOS DEMÁS Y ENTENDER CUANDO ALGUIEN
RECHAZA NUESTRA AYUDA O CONSEJO. CONSECUENCIAS DE LA IMPRUDENCIA Y EL DESAFIO A LAS NORMAS
ESTABLECIDAS: MOSTRANDO CÓMO DESOBEDECER REGLAS, ESPECIALMENTE EN CONTEXTOS PELIGROSOS,
PUEDE LLEVAR A RESULTADOS TRÁGICOS. EN RESUMEN, LA HISTORIA RESALTA LA NECESIDAD DE
RESPETAR LAS REGLAS, TOMAR DECISIONES INFORMADAS Y REFLEXIONADAS, ASÍ COMO COMPRENDER LOS
LÍMITES Y ADVERTENCIAS ESTABLECIDOS PARA EVITAR SITUACIONES DESAFORTUNADAS.''',
  '122. EL PUERTO Y EL TELESCOPIO.': '''PATAKI: EN CIERTO LUGAR DE LA COSTA SE HALLABA UN PUERTO CON UNA PARTICULARIDAD:
ESTABAOCULTO DESDE EL MAR DEBIDO A UNA DENSA VEGETACION QUE CUBRIA TANTO LA FACHADA DEL
PUEBLO COMO LA DEL PUERTO. ESTA MALEZA IMPENETRABLE IMPEDÍA A LOS MARINEROS, INCLUSO CON
EL TELESCOPIO MÁS POTENTE, DIVISAR EL PUERTO O A SUS HABITANTES. DESCONFIADOS, CONTINUABAN
SU VIAJE, EVITANDO ACERCARSE A LA COSTA POR TEMOR A LO DESCONOCIDO. EN ESA SITUACIÓN LLEGÓ
ORÚNMILA A ESE PUEBLO Y REALIZÓ UN OSODE, CONSULTANDO CON IFÁ. ESTA LETRA DE IFÁ LE INDICÓ
QUE EL ÚNICO CAPAZ DE AYUDARLE ERA OGÚN, MARCÁNDOLE A IFÁ QUE LE OFRECIERA SIETE AKUKO A
OGÚN. ORÚNMILA REFLEXIONÓ QUE QUIZÁS OGÚN NO DEBERÍA HACER TODO EL TRABAJO, POR LO QUE
DECIDIÓ IDEAR UNA ESTRATEGIA. OGÚN ERA MUY GOLOSO, ASÍ QUE ORÚNMILA LE PRESENTÓ LOS SIETE
AKUKO Y LE ENTREGÓ UN COCO, DICIÉNDOLE QUE SEGÚN FUERA AVANZANDO EN SU LABOR, RECIBIRÍA
LOS AKUKO. OGÚN ESTUVO DE ACUERDO Y DIJO: "CORTARÉ LA MALEZA Y TÚ ME DARÁS UN AKUKO CADA
VEZ QUE TERMINE". ASÍ FUE COMO ORÚNMILA ENTREGABA UN AKUKO CADA VEZ QUE OGÚN COMPLETABA SU
TAREA, ABRIENDO EL CAMINO HACIA EL MAR. AHORA EL PUERTO ERA VISIBLE Y TODOS LOS BARCOS QUE
SURCABAN ESAS AGUAS RECALABAN EN SU PUERTO. GRACIAS A LA ASTUCIA DE ORÚNMILA Y LA LABOR DE
OGÚN, EL PROGRESO LLEGÓ A ESA TIERRA QUE ANTES PERMANECÍA OCULTA Y AISLADA. EBO: SIETE
AKUKO, SIETE MACHETES, UN TELESCOPIO, FANGO DE LA COSTA, UN BARCO, SAQUITO DE GRANOS
VARIADOS, AGUA DEMAR, ARENA DE LA PLAYA, DOS OBI, DOS ITANAS, DEMASINGREDIENTES, OPOLOPO
OWO. NOTA: SE LE DAN LOS AKUKO A OGGUN Y A LOS MACHETES, EL FANGO VA DENTRO DEL EBBO CON
LOS DEMAS INGREDIENTES, EL BARCO, LOS SAQUITOS Y EL TELESCOPIO SE LE PREGUNTA A OGGUN.
ENSENANZAS: LA IMPORTANCIA DE LA COLABORACIÓN: ORÚNMILA Y OGÚN TRABAJARON JUNTOS, CADA UNO
APORTANDO SUS HABILIDADES DE MANERA COMPLEMENTARIA, LO QUE LES PERMITIÓ SUPERAR UN
PROBLEMA APARENTEMENTE INSUPERABLE. LA COOPERACIÓN ENTRE DISTINTAS HABILIDADES Y TALENTOS
PUEDE LLEVAR AL ÉXITO. LA ESTRATEGIA Y LA ASTUCIA: ORÚNMILA UTILIZÓ SU INTELIGENCIA Y
ASTUCIA PARA RESOLVER EL PROBLEMA. EN LUGAR DE EXIGIR TODO EL TRABAJO A OGÚN, IDEÓ UNA
ESTRATEGIA INGENIOSA QUE PERMITIÓ QUE AMBOS COLABORARAN DE MANERA EFECTIVA. EL VALOR DE
SUPERAR OBSTÁCULOS: A PESAR DE LA DIFICULTAD Y LA APARENTE IMPOSIBILIDAD DE DIVISAR EL
PUERTO, ORÚNMILA Y OGÚN PERSISTIERON EN SU OBJETIVO DE HACERLO VISIBLE. ESTA PERSEVERANCIA
Y DETERMINACIÓN SON CRUCIALES PARA SUPERAR DESAFÍOS. LA IMPORTANCIA DE LA VISIBILIDAD: UNA
VEZ QUE EL PUERTO SE HIZO VISIBLE, LOS BARCOS PUDIERON ACCEDER A ÉL. ESTO RESALTA CÓMO LA
VISIBILIDAD Y LA ACCESIBILIDAD SON FUNDAMENTALES PARA EL DESARROLLO Y EL PROGRESO. LA
RECIPROCIDAD Y EL INTERCAMBIO: LA HISTORIA MUESTRA CÓMO UN INTERCAMBIO EQUITATIVO, EN ESTE
CASO, LA ENTREGA DE LOS AKUKO POR EL TRABAJO REALIZADO, FUE FUNDAMENTAL PARA LOGRAR EL
OBJETIVO COMÚN. EN RESUMEN, LA COLABORACION INTELIGENTE, LA ESTRATEGIA, LA PERCISTENCIA,
LA VISIBILIDAD Y EL INTERCAMBIO EQUITATIVO SON ELEMENTOS CRUCIALES PARA SUPERAR OBSTACULOS
Y LOGRAR EL PROGRESO.''',
  '123. EL COMIENZO DEL MUNDO. LOS SIETE PRINCIPES CORONADOS.': '''PATAKI: ORANIYAN, CONOCIDO POR SU TEMPERAMENTO GUERRERO, ESTABLECIÓ LA SUPREMACÍA DE LOS
REYES YORUBA SOBRE LAS TIERRAS QUE TENÍAN A ODUDUWA COMO ANCESTRO COMÚN. CUENTA LA
TRADICIÓN QUE TRAS LA MUERTE DE OKANBI, LOS SEIS HIJOS MAYORES SE REPARTIERON LOS BIENES Y
TESOROS. OLOWU RECIBIÓ LA CORONA, ALAKETI LOS VESTIDOS, OGISO, REY DE BENIN, LA PLATA,
ORAGUN, REY DE ILA, LAS MUJERES, ONICRADE, LOS REBANOS, Y OLUO POPO, LAS PERLAS. LO ÚNICO
QUE QUEDÓ PARA ORANIYAN FUE LA TIERRA, YA QUE SE ENCONTRABA EN UNA EXPEDICIÓN EN EL
MOMENTO DE LA REPARTICIÓN. SATISFECHO CON SU LOTE, AL SER DUEÑO DE LA TIERRA, RECIBÍA
RENTAS Y TRIBUTOS DE SUS HERMANOS. ESTA SUPREMACIA DE ORANIYAN SOBRE SUS HERMANOS SE
RELATA EN UNA LEYENDA POÉTICA. AL PRINCIPIO, NO EXISTÍA LA TIERRA; ARRIBA ESTABA EL CIELO
Y DEBAJO, EL AGUA. ENTONCES, EL TODOPODEROSO OLORDUMARE, DUEÑO DE TODAS LAS COSAS, CREÓ
PRIMERO SIETE PRÍNCIPES CORONADOS PARA SU ALIMENTO Y ENTRETENIMIENTO. LUEGO, CREÓ SIETE
CALABAZAS LLENAS DE AKALA (PAPILLA A BASE DE MAÍZ), Y SIETE SACOS CON CONCHAS, PERLAS,
TELAS, UNA GALLINA Y 21 BARRAS DE HIERRO. ADEMÁS, DENTRO DE UNA TELA NEGRA, CREÓ UN
PAQUETE VOLUMINOSO CUYA NATURALEZA NO SE VEÍA. DESPUÉS, DEJÓ CAER DESDE LO ALTO DEL CIELO,
AL FINAL DEL VACÍO LLENO DE AGUA, UNA NUEZ DE PALMA. EN EL MOMENTO, UNA GIGANTESCA PALMERA
SE ELEVÓ HASTA LOS PRÍNCIPES OFRECIÉNDOLES REFUGIO ENTRE SUS RAMAS. LOS PRÍNCIPES SE
INSTALARON ALLÍ CON SU EQUIPAJE, ABANDONANDO LA CADENA QUE SE REMONTABA HACIA OLORDUMARE.
TODOS QUERÍAN MANDAR Y RESOLVIERON SEPARARSE. LOS NOMBRES DE LOS SIETE PRÍNCIPES ERAN:
OLOWO, REY DE LOS OSBE; OSABE, REY DE IYA; ONI, REY DE IFE; ALEJERO, REY DE KETU; Y EL MÁS
JOVEN, ORANIYAN, REY DE OYO Y DE TODA LA TIERRA YORUBA, CON SUPREMACIA SOBRE LOS DEMAS
REYES. CUANDO ORANIYAN QUEDÓ SOLO, DESEO VER LO QUE ESTABA DENTRO DEL PAQUETE ENVUELTO EN
LA TELA NEGRA. AL ABRIRLO, VIO UNA MATERIA NEGRA QUE DESCONOCIA. AL SACUDIR LA TELA, LA
MATERIA CAYÓ AL AGUA Y, CON EL ESFUERZO DE UNA GALLINA QUE VOLÓ PARA POSARSE SOBRE ELLA Y
LA RASGUÑÓ CON LAS PATAS Y EL PICO, SE CONVIRTIÓ EN UN MONTÍCULO EMERGIENDO DEL AGUA. ESTA
FUE LA CREACIÓN DE LA TIERRA, SIGUIENDO LA VOLUNTAD DEL TODOPODEROSO. ORANIYAN,
SATISFECHO, GUARDÓ LAS 21 BARRAS DE HIERRO EN SU TROZO DE TELA NEGRA Y DESCENDIÓ SOBRE LA
TIERRA QUE HABÍA CREADO. LOS DEMÁS PRÍNCIPES QUERÍAN ARREBATARLE SU PARTE, PERO ORANIYAN
TENÍA ARMAS: SUS 21 BARRAS DE HIERRO, CONVERTIDAS POR LA VOLUNTAD DIVINA EN LANZAS,
VENABLOS, FLECHAS Y HACHAS. SOSTENIA UNA LARGA ESPADA, MÁS AFILADA QUE EL FILO DE LA MÁS
FINA CUCHILLA DE OTORIN. ENTONCES, LES DIJO QUE LA TIERRA ERA SOLO SUYA, QUE LE HABÍAN
ARREBATADO TODO Y SOLO LE HABÍAN DEJADO ESA TIERRA Y ESOS HIERROS. LOS SEIS PRÍNCIPES
PIDIERON CLEMENCIA, SE ARRODILLARON Y SUPLICARON A LOS PIES DE ORANIYAN. LE ROGARON QUE
LES CEDIERA PARTE DE LA TIERRA PARA PODER VIVIR COMO PRÍNCIPES. ORANIYAN ACEPTÓ Y LES
OTORGÓ TIERRA, CON LA CONDICIÓN DE QUE ELLOS Y SUS DESCENDIENTES SIEMPRE SERÍAN INFERIORES
A ÉL Y QUE CADA AÑO, DEBERÍAN RENDIR HOMENAJE Y TRIBUTO A LA CIUDAD COMO RECORDATORIO DE
LO QUE HABÍAN RECIBIDO COMO GRACIA. ORANIYAN SE CONVIRTIÓ EN REY DE OYO Y SOBERANO DE TODO
EL PAÍS YORUBA, INCLUYENDO TODA LA TIERRA. SU LEGADO Y PROYECTOS DE EXPEDICIÓN FUERON
TRUNCADOS EN IGANGAN DEBIDO A UNA DISPUTA ENTRE SUS HERMANOS POR UN JARRO DE CERVEZA.
LUEGO, TRAS OTRAS ADVERSIDADES, SU PRIMO AKIJONLE LO DEJÓ, FUNDANDO EJIGBO. ORANIYAN
ABANDONÓ SUS PLANES, FUNDÓ LA CIUDAD DE OYO, QUE SE CONVIRTIÓ EN LA CAPITAL DE LOS REYES
YORUBA EN ILE IFE. POSTERIORMENTE, DEJÓ A SU HIJO AJAKA COMO REY (ALAFIN) DE OYO Y
CONTINUÓ SU VIDA GUERRERA, CONVIRTIÉNDOSE EN EL SEGUNDO REY DE BENIN. RENUNCIÓ AL TRONO Y
DEJÓ A SU HIJO EWEKA, CUYOS DESCENDIENTES AÚN REINAN. REGRESÓ A ILE IFE, CAPTURÓ A UNO DE
SUS HERMANOS, OBALUFON, QUIEN HABÍA TOMADO EL TRONO, Y LO EXILIÓ A IDO. ASÍ, ORANIYAN SE
CONVIRTIÓ EN REY DE IFE. NOTA: ORANIYAN, FUE EL SEPTIMO HIJO DE OKANBI, HIJO DE ODUDUWA,
PRIMER REY LEGENDARIO DE LOS YORUBAS. EL FUEIGUALMENTE EL SEGUNDO REY Y EL PADRE DEL
TERCERO, AYARE, LLAMADO TAMBIEN DADA, Y EL CUARTO SHANGO. ENSEÑANZAS: SUPERVIVENCIA A
TRAVÉS DE LA ADVERSIDAD: LOS DESAFÍOS PUEDEN TRANSFORMARSE EN OPORTUNIDADES. AUNQUE
ORANIYAN RECIBIÓ SOLO LA TIERRA, APROVECHÓ SUS RECURSOS PARA ESTABLECER SU DOMINIO. EL
PODER DE LA VOLUNTAD DIVINA: LA HISTORIA REFLEJA CÓMO LA VOLUNTAD DIVINA GUIÓ LA CREACIÓN
DE LA TIERRA Y OTORGÓ PODER A ORANIYAN A TRAVÉS DE LAS BARRAS DE HIERRO CONVERTIDAS EN
ARMAS. CONSECUENCIAS DE LA AVARICIA Y LA AMBICIÓN: LA CODICIA DE LOS HERMANOS Y SU DESEO
DE ARREBATAR A ORANIYAN RESULTARON EN UNA CONFRONTACIÓN, EVIDENCIANDO LAS REPERCUSIONES DE
LA AMBICIÓN DESMEDIDA. JUSTICIA Y GENEROSIDAD: A PESAR DE LA DESIGUALDAD INICIAL, ORANIYAN
CONCEDIÓ TIERRA A SUS HERMANOS, AUNQUE CON LA CONDICIÓN DE MANTENER SU SUPREMACÍA. EL
VALOR DE LA HUMILDAD Y LA NEGOCIACIÓN: A PESAR DE SU PODER, ORANIYAN OPTÓ POR OTORGAR A
SUS HERMANOS UNA PORCIÓN DE TIERRA CUANDO SE POSTRARON ANTE ÉL, MOSTRANDO UN ACTO DE
COMPASIÓN Y HUMILDAD. LEGADO Y LIDERAZGO: ORANIYAN, COMO LÍDER, ESTABLECIÓ CIUDADES,
DEJANDO UN LEGADO PARA SUS DESCENDIENTES Y CONTRIBUYENDO AL DESARROLLO DE LAS TIERRAS
YORUBA. ESTAS LECCIONES HABLAN SOBRE EL EQUILIBRIO ENTRE LA AMBICIÓN, LA JUSTICIA, LA
GENEROSIDAD Y LA HUMILDAD EN LA FORMACIÓN DE UN LÍDER Y EL DESARROLLO DE UNA COMUNIDAD.''',
  '124. EJIOGBE, EL PODER DE SU NATURALEZA.': '''PATAKI: ORIBIBE ERA UN HIJO DE EJIOGBE, Y ÉL SE PUSO A VIVIR CON UNA MUJER QUE RESPONDÍA
AL NOMBRE DE BOYURINA (ADORADORES DE LOS OJOS DEL FUEGO). ESTA LE HIZO UN AMARRE EN SU
OKO, PARA QUE NO PUDIERA HACER EL AMOR CON MÁS NADIE QUE CON ELLA. UN DÍA SE SINTIÓ FLOJO
Y SE VIO SU IFÁ, SE HIZO EBÓ, Y TENÍA QUE PONERLO AL PIE DE UNA MATA, RESULTANDO QUE ERA
UNA MATA DE ÁRIDA, DONDE SE ENCONTRÓ CON ODUODE, EL CAZADOR NEGRO, EL CUAL LE DIJO QUE LA
FLOJEDAD SEXUAL LA CURABA OZAIN CON ESA MATA. LE MANDÓ A DARLE ADIÉ MEYI DUN DUN A SU IFÁ
Y DESPUÉS COGER 16 SEMILLAS DE ÁRIDA Y EN CONJUNTO CON UN INSHE DEL LARGO DE SU PENE.
TENÍA QUE HACER ISHEGUN PARA BEBER Y ADEMÁS DARLE AKUTAN AL ESPÍRITU QUE HABÍA EMPLEADO SU
OBINI EN EL AMARRE, Y CON ESO LOGRÓ DE NUEVO EL PODER DE SU NATURALEZA. ENSEÑANZAS: PODER
DE LA NATURALEZA: LA HISTORIA MUESTRA CÓMO EL PROTAGONISTA, A PESAR DE ESTAR LIMITADO POR
UN AMARRE, BUSCA RECUPERAR SU PODER Y CONTROL SOBRE SI MISMO. ESTO PUEDE INTERPRETARSE
COMO UNA LECCIÓN SOBRE LA DETERMINACIÓN PARA SUPERAR OBSTÁCULOS. CONOCIMIENTO Y AYUDA
ESPIRITUAL: EL PERSONAJE RECURRE A LA SABIDURÍA DE IFÁ Y A PRÁCTICAS ESPIRITUALES PARA
RESTAURAR SU PODER. ESTO SUBRAYA LA IMPORTANCIA DEL CONOCIMIENTO Y LA ORIENTACIÓN
ESPIRITUAL PARA SUPERAR DIFICULTADES. SUPERACIÓN PERSONAL: A TRAVÉS DE RITUALES Y ACCIONES
ESPECÍFICAS, EL PROTAGONISTA LOGRA LIBERARSE DEL AMARRE Y RECUPERAR SU CAPACIDAD. ESTO
PUEDE REFLEJAR EL CONCEPTO DE EMPODERAMIENTO PERSONAL Y LA IMPORTANCIA DE BUSCAR
SOLUCIONES ANTE LAS ADVERSIDADES. LA IMPORTANCIA DE APRENDER: LA HISTORIA IMPLICA APRENDER
DE LA EXPERIENCIA. EL PROTAGONISTA APRENDE DE LOS CONSEJOS DADOS POR ODUODE Y OZAIN, LO
QUE LE PERMITE RECUPERAR SU PODER. EN RESUMEN, LAS LECCIONES QUE SE PUEDEN EXTRAER
INCLUYEN LA DETERMINACIÓN ANTE LA ADVERSIDAD, LA BÚSQUEDA DE AYUDA Y CONOCIMIENTO, LA
IMPORTANCIA DE SUPERAR OBSTÁCULOS Y LA CAPACIDAD DE APRENDER Y APLICAR NUEVOS
CONOCIMIENTOS PARA EL CRECIMIENTO PERSONAL.''',
  '125. OYA, LA DUEÑA DEL CEMENTERIO.': '''PATAKI: EN TIEMPOS REMOTOS, EXISTÍA UNA TRIBU EN ÁFRICA CUYOS HABITANTES, AUNQUE MUY
POBRES, VIVIAN SUMAMENTE FELICES. EN ESTA TRIBU RESIDIAN TRES HERMANAS. LA MAYOR DE ELLAS,
YEMAYA, SOSTENÍA A SUS DOS HERMANAS MENORES CON LO QUE RECOLECTABA DEL MAR. LA SEGUNDA
HERMANA, OSHUN, INTENTABA AYUDAR A LA MAYOR Y, AL MISMO TIEMPO, CUIDAR A LA TERCERA, OYA,
QUE ERA MUY PEQUEÑA. OSHUN SOLÍA EXPLORAR LOS RÍOS Y CON LO QUE OBTENÍA DE ALLÍ, ASISTÍA A
SU HERMANA MAYOR. AMBAS SE QUERÍAN PROFUNDAMENTE. LA SEGUNDA HERMANA SOLÍA ATAR A LA MÁS
PEQUEÑA A LA ORILLA DEL RÍO PARA PROTEGERLA. UN DÍA INESPERADO, EL TERRITORIO FUE INVADIDO
Y SAQUEADO. COMO OYA ESTABA ATADA Y ALGO DISTANTE DE SU HERMANA, ESTA NO PUDO ESCUCHAR SUS
GRITOS MIENTRAS ERA LLEVADA POR LOS INVASORES. LA MAYOR, YEMAYA, SE SALVÓ PORQUE ESTABA
TRABAJANDO EN EL MAR. OSHUN TAMBIÉN SE SALVÓ, YA QUE ESTABA LEJOS DEL RÍO. PERO LA MÁS
PEQUEÑA, OYA, NO TUVO LA MISMA SUERTE. LA PÉRDIDA DE LA HERMANA MENOR AFECTÓ A LA MAYOR,
PERO LA SEGUNDA HERMANA, OSHUN, QUEDÓ PROFUNDAMENTE IMPACTADA Y ESTUVO EMOCIONALMENTE
ENFERMA DURANTE MUCHOS AÑOS. ANSIABA VER A SU HERMANITA PEQUEÑA A QUIEN LLAMABA "SU
PEQUEÑA HUA" POR ESO, OSHUN GUARDABA DIARIAMENTE ALGUNAS MONEDAS QUE LE SOBRABAN CON EL
PROPÓSITO DE RESCATAR A OYA ANTES DE QUE ALCANZARA LA EDAD ADULTA. CUANDO OSHUN SUPO EL
PRECIO QUE HABÍAN FUADO POR SU HERMANA, SE LO ENTREGÓ EN MONEDAS DE COBRE AL JEFE DE LA
TRIBU DE LOS INVASORES. SIN EMBARGO, ELJEFE, ENAMORADO LOCAMENTE DE OSHUN, DUPLICÓ EL
PRECIO DEL RESCATE SABIENDO QUE ELLA ERA DEMASIADO POBRE PARA PAGARLO. ANTE LA RESPUESTA
DECIDIDA DEL JEFE, OSHUN CAYO DE RODILLAS, LLORÓ Y SUPLICÓ QUE CAMBIARA SU DECISIÓN,
OFRECIENDO LA VIRGINIDAD A CAMBIO DE LA LIBERTAD DE OYA, PROMETIENDO NO ENGAÑARLO SI
ACCEDÍA. OSHUN VACILO, PENSANDO EN SU HERMANA YEMAYA A QUIEN AMABA MUCHO, PERO EL AMOR ERA
SU VIDA. FINALMENTE, BAJÓ LA CABEZA Y SE SACRIFICÓ. AL REGRESAR, OSHUN PIDIÓ PERDÓN A
YEMAYA, QUIEN LA BENDIJO Y PERDONÓ. CON LAS MONEDAS DE COBRE OBTENIDAS POR SU SACRIFICIO,
ADORNÓ LA CABEZA Y LOS BRAZOS DE OYA, EN MEMORIA DEL PASADO. OYA Y OSHUN CRECIERON JUNTAS,
PERO PARA CRIAR A OYA, OSHUN SIGUIÓ UNA VIDA DE SACRIFICIOS, CONTINUANDO LO QUE HABÍA
EMPEZADO POR ELLA. OYA LLEGÓ A LA MAYORÍA DE EDAD. OSHUN, UNA MUJER ALEGRE PERO SANTA Y
MÁRTIR DE UN CORAZÓN PURO, FUE BENDECIDA POR OLOFIN POR LO QUE HIZO POR OYA, Y A YEMAYA
POR AMBAS. EN ESA ÉPOCA, OLOFIN DIVIDIÓ LAS TIERRAS DEL MUNDO EN TRES PARTES Y AQUELLOS
MERECEDORES RECIBIERON LA AUTORIDAD PARA GOBERNAR (SANTO), DE ACUERDO CON SUS HABILIDADES.
A YEMAYA LE DIERON EL GOBIERNO DE LOS MARES, A OSHUN EL GOBIERNO DE LOS RÍOS, PERO OYA NO
ERA DE LA TRIBU DE SU HERMANA, YA QUE CUANDO PASARON LISTA, ERA CAUTIVA Y ESCLAVA, POR LO
QUE NO RECIBIÓ TIERRA PARA GOBERNAR. OSHUN SUPLICÓ A OLOFIN, QUIEN CONMOVIDO LE DIJO: "LAS
TIERRAS DEL MUNDO YA ESTÁN REPARTIDAS, PERO HAY UN LUGAR SIN DUEÑO. SI ELLA LO DESEA, SERÁ
SUYO". ERA EL CEMENTERIO. OYA ACEPTÓ GUSTOSA POR HACER FELIZ A OSHUN Y ASÍ, OSHUN SE
RETIRÓ. HASTA EL DÍA DE HOY, SABEMOS QUE OYA ES LA DUEÑA DE LOS CEMENTERIOS. NOTA: EN OYA,
LAS PIEZAS DE COBRE SIMBOLIZAN EL SACRIFICIO DE OSHUN. A MENUDO, SE LE DA DE COMER A OYA
EN LA ORILLA DEL RÍO, MIENTRAS QUE A OSHUN Y YEMAYA SE LES OFRECE COMIDA DENTRO DEL AGUA,
SIMBOLIZANDO LA INFANCIA DE OYA. ENSENANZAS: AMOR Y SACRIFICIO FAMILIAR: LA HISTORIA
DESTACA EL PODER DEL AMOR Y EL SACRIFICIO ENTRE HERMANAS. TANTO YEMAYA COMO OSHUN ESTÁN
DISPUESTAS A SACRIFICAR Y ARRIESGAR MUCHO PARA PROTEGER Y CUIDAR A SU HERMANA MENOR, OYA.
ESTE AMOR FAMILIAR PROFUNDO ILUSTRA LA IMPORTANCIA DE LOS LAZOS FAMILIARES Y LA
DISPOSICIÓN A HACER SACRIFICIOS POR EL BIENESTAR DE LOS SERES QUERIDOS. RESILIENCIA FRENTE
A LA ADVERSIDAD: LA TRIBU, A PESAR DE SER MUY POBRE, VIVE FELIZMENTE. SIN EMBARGO, CUANDO
ENFRENTAN LA ADVERSIDAD DE LA INVASIÓN Y EL SAQUEO, LOS PERSONAJES DEMUESTRAN DIFERENTES
NIVELES DE RESILIENCIA. YEMAYA SE SUMERGE EN SU TRABAJO PARA SUPERAR LA PERDIDA, MIENTRAS
QUE OSHUN QUEDA EMOCIONALMENTE AFECTADA DURANTE MUCHOS AÑOS. ESTA DUALIDAD RESALTA LA
IMPORTANCIA DE LA RESILIENCIA ANTE LAS DIFICULTADES. CONSECUENCIAS DE LAS DECISIONES Y
COMPROMISOS: LA HISTORIA ILUSTRA CÓMO LAS DECISIONES, INCLUSO LAS VALIENTES Y BIEN
INTENCIONADAS, PUEDEN TENER CONSECUENCIAS INESPERADAS. OSHUN SE COMPROMETE A DAR SU
VIRGINIDAD PARA SALVAR A SU HERMANA, PERO ESTE ACTO DE SACRIFICIO LLEVA A NUEVAS
COMPLICACIONES CUANDO EL PRECIO SE DUPLICA. ESTO SUBRAYA LA COMPLEJIDAD DE LAS ELECCIONES
Y CÓMO A VECES LOS RESULTADOS NO SON COMPLETAMENTE PREDECIBLES. RECOMPENSAS DE LA BONDAD Y
GENEROSIDAD: A PESAR DE LAS DIFICULTADES Y COMPLICACIONES, LA HISTORIA SUGIERE QUE LA
BONDAD Y LA GENEROSIDAD SON RECOMPENSADAS. OSHUN RECIBE LA AUTORIDAD PARA GOBERNAR SOBRE
LOS RÍOS COMO UNA RECOMPENSA POR SUS SACRIFICIOS. ESTO PROMUEVE LA IDEA DE QUE LOS ACTOS
ALTRUISTAS PUEDEN LLEVAR A BENEFICIOS Y RECONOCIMIENTOS A LARGO PLAZO. ACEPTACIÓN Y
ENCUENTRO DE PROPÓSITO: LA HISTORIA CONCLUYE CON EL TEMA DE ACEPTACIÓN Y ENCONTRAR UN
PROPÓSITO EN LAS CIRCUNSTANCIAS DADAS. AUNQUE OYA NO RECIBE INICIALMENTE TIERRAS PARA
GOBERNAR, ENCUENTRA UN PAPEL SIGNIFICATIVO COMO LA DUEÑA DE LOS CEMENTERIOS. ESTO DESTACA
LA IMPORTANCIA DE ACEPTAR LA REALIDAD Y ENCONTRAR SIGNIFICADO INCLUSO EN SITUACIONES
APARENTEMENTE DESFAVORABLES. EN RESUMEN, LA HISTORIA PROPORCIONA LECCIONES SOBRE EL AMOR
FAMILIAR, LA RESILIENCIA, LAS CONSECUENCIAS DE LAS DECISIONES, LAS RECOMPENSAS DE LA
BONDAD Y LA IMPORTANCIA DE ACEPTAR Y ENCONTRAR PROPÓSITO EN LA VIDA.''',
  '126. POR BABA LE QUITARON A OYA LA CANDELA.': '''PATAKI: EN TIEMPOS REMOTOS, EN LA TIERRA DE OMO YENI, UNA DEIDAD LLAMADA OYA SE JACTABA DE
SER LA DUENA ABSOLUTA DE LA CANDELA. CADA VEZ QUE SE ENFADABA, LLENABA LA TIERRA DE
CENTELLAS QUE RESULTABAN MORTALES PARA MÚLTIPLES PERSONAS. YEWA, OTRA DEIDAD,
CONSTANTEMENTE ACONSEJABA A OBATALA QUE ENVIARA A BUSCAR A OYA PARA VER SI PODÍA SER
CONTROLADA. CADA VEZ QUE OYA IBA A VER A BABA A LA LOMA, LLEVABA CONSIGO OFRENDAS COMO PAN
Y LECHE. COMPARTÍAN COMIDA Y LUEGO OYA RENDÍA HOMENAJE A BABA MOFORIBALE. DESPUÉS DE UNOS
DÍAS, REPETÍA EL PROCESO. SIN EMBARGO, UN DÍA, ELEGBA SE CRUZÓ CON OYA MIENTRAS TRANSITABA
POR UN CAMINO Y ELLA SOLTÓ UNA CENTELLA QUE CASI LO MATA. ASUSTADO, ELEGBA CORRIÓ Y SE
ENCONTRÓ CON EJIOGBE, HUO DE IFA, A QUIEN LE CONTÓ LO SUCEDIDO. EJIOGBE VERIFICÓ LAS
QUEJAS DE ELEGBA Y DECIDIÓ BUSCAR A SHANGO PARA PONER FIN A LOS ACTOS MALÉVOLOS DE OYA.
ORUNMILA Y ELEGBA SE ENCONTRARON CON SHANGO, QUIEN, HAMBRIENTO, PREGUNTÓ A EJIOGBE QUÉ LE
TRAÍA. EJIOGBE LE PREGUNTÓ QUÉ DESEABA COMER Y SHANGO RESPONDIÓ CON OTRA PREGUNTA SOBRE LO
QUE LE SUCEDÍA Y QUIÉN SE HABÍA METIDO CON ÉL. EJIOGBE EXPLICÓ QUE OYA LANZABA CENTELLAS
TODOS LOS DÍAS Y DESOBEDECÍA A BABA. SHANGO, ALIMENTADO POR ELEGBA, SE PRESENTÓ FRENTE A
OLOFIN, CANTÓ "SHEBORA, SHEBORA" Y CONTÓ LO SUCEDIDO. OLOFIN SE ASUSTÓ Y SHANGO, AL SACAR
LA LENGUA, PROVOCÓ LA CAÍDA DE RAYOS. OYA, SORPRENDIDA, SE ESCONDIÓ. SHANGO CONTINUÓ
SOBERBIO, Y OYA, INCAPAZ DE SOPORTARLO MÁS, BAJÓ A LA TIERRA. SHANGO LA PERSIGUIÓ, PERO
BABA LLEGÓ CON UNA TINAJA DE LECHE DE VACA Y SE LA ARROJÓ A SHANGO, APAGANDO LA CANDELA.
EJIOGBE SUGIRIÓ IR A BUSCAR A OYA PARA EVITAR QUE CAUSARA MÁS DAÑO. OYA INTENTÓ LANZAR
OTRA CENTELLA, PERO SHANGO Y EJIOGBE LA ANTICIPARON, LA SUJETARON FIRMEMENTE Y, MEDIANTE
UNA CEREMONIA PREPARADA POR BABA, LE QUITARON LA CANDELA. ESTA HISTORIA EXPLICA POR QUÉ
TODAS LAS CAZUELAS DE OOZAIN EN IFA LLEVAN CANDELA. EN EL SANTO, NO SE PUEDE USAR CANDELA
EN SUS CAZUELAS DE OMIERO, YA QUE OYA SE LA QUITO. REZO: SHUNEWE YEPE SHIWU ENIYO SHINU NI
SHINUVINI LA KOTONOMI BABALAWO ADIFAFUN ORÚNMILA UMBATILO ILE EYA TUTUWILAWO ORÚNMILA
ORUBO. EBO AKUKO FUN-FUN, EYELE MEYI FUN FUN, AIKORDIE MEYI, EYATUTU, GANGAN, ORI, OFUN,
EPO, EKO, EYA, AWADO, EKOMENI, GBOGBO TENUYEN KUPA ABEJI OWO. ENSEÑANZAS: PODER DE LA
COLABORACIÓN: LA HISTORIA DESTACA LA IMPORTANCIA DE TRABAJAR JUNTOS PARA SUPERAR DESAFIOS.
EN LUGAR DE ENFRENTAR A OYA POR SEPARADO, LAS DEIDADES, COMO SHANGO, ELEGBA, Y EJIOGBE,
UNEN FUERZAS PARA ABORDAR EL PROBLEMA. LA COLABORACIÓN DEMUESTRA SER MÁS EFECTIVA QUE
ENFRENTAR LAS DIFICULTADES INDIVIDUALMENTE. CONTROL DE LA IRA: OYA REPRESENTA LA IRA
DESCONTROLADA QUE PUEDE TENER CONSECUENCIAS DESTRUCTIVAS. SHANGO Y EJIOGBE, EN LUGAR DE
RESPONDER CON VIOLENCIA, OPTAN POR UTILIZAR ESTRATEGIAS Y RITUALES PARA CONTROLAR Y
NEUTRALIZAR LA FURIA DE OYA. ESTO ENSENA LA IMPORTANCIA DE MANEJAR LA IRA DE MANERA SABIA
Y CONSTRUCTIVA. LA IMPORTANCIA DE LA INTERVENCIÓN: YEWA Y OBATALA BUSCAN INTERVENIR Y
CONTROLAR A OYA ANTES DE QUE CAUSE MÁS DAÑO. ESTA ENSENANZA DESTACA LA IMPORTANCIA DE
ABORDAR LOS PROBLEMAS Y CONFLICTOS DE MANERA PROACTIVA EN LUGAR DE PERMITIR QUE SE
INTENSIFIQUEN. EL PRECIO DE LA SOBERBIA: LA HISTORIA MUESTRA QUE LA SOBERBIA DE OYA, AL
PROCLAMARSE DUEÑA ABSOLUTA DE LA CANDELA, LA LLEVA A UN CONFLICTO CON OTRAS DEIDADES. LA
SOBERBIA PUEDE SER PERJUDICIAL Y PROVOCAR ACCIONES QUE TIENEN CONSECUENCIAS NEGATIVAS. USO
SABIO DE LA AUTORIDAD: SHANGO, AL SER UNA DEIDAD CON PODER, UTILIZA SU AUTORIDAD DE MANERA
SABIA PARA CONTROLAR A OYA. ESTO DESTACA LA RESPONSABILIDAD ASOCIADA CON EL PODER Y CÓMO
DEBE SER USADO PARA EL BIEN COMÚN Y LA RESOLUCIÓN DE PROBLEMAS. RESOLUCIÓN PACÍFICA DE
CONFLICTOS: A PESAR DE LA SITUACIÓN POTENCIALMENTE PELIGROSA, LA HISTORIA NO CULMINA EN UN
CONFLICTO VIOLENTO. EN LUGAR DE ESO, SE RECURRE A CEREMONIAS Y RITUALES PARA RESOLVER EL
PROBLEMA, MOSTRANDO LA IMPORTANCIA DE ENCONTRAR SOLUCIONES PACÍFICAS INCLUSO EN
SITUACIONES TENSAS. RECONOCIMIENTO DE ERRORES Y CORRECCIÓN DE COMPORTAMIENTO: DESPUÉS DE
SER CONTROLADA, LA HISTORIA NO TERMINA EN CASTIGO ETERNO PARA OYA. EN CAMBIO, SE LE QUITA
LA CANDELA Y SE LE OFRECE LA OPORTUNIDAD DE CORREGIR SU COMPORTAMIENTO. ESTO DESTACA LA
IMPORTANCIA DE RECONOCER ERRORES, APRENDER DE ELLOS Y BUSCAR LA REDENCIÓN. EN RESUMEN, LA
HISTORIA TRANSMITE LECCIONES SOBRE LA COLABORACIÓN, EL CONTROL EMOCIONAL, LA INTERVENCIÓN
PROACTIVA, LA HUMILDAD FRENTE A LA SOBERBIA, EL USO SABIO DE LA AUTORIDAD, LA RESOLUCIÓN
PACÍFICA DE CONFLICTOS Y LA POSIBILIDAD DE CORRECCIÓN Y REDENCION.''',
  '127. EL LEON Y LOS HOMBRES.': '''PATAKI: HABÍA UNA VEZ UN LEÓN QUE VIVÍA PACÍFICAMENTE EN UN PUEBLO, CONVIVIENDO CON LAS
PERSONAS SIN CAUSAR NINGÚN PROBLEMA. SU NATURALEZA TRANQUILA Y SU IMPONENTE APARIENCIA
DESPERTABAN LA ENVIDIA DE ALGUNOS HABITANTES DEL LUGAR, QUIENES COMENZARON A REPUDIARLO
INJUSTAMENTE. LA BELLEZA Y FORTALEZA DEL LEON SUSCITABAN CELOS ENTRE LA GENTE, Y
DECIDIERON QUEJARSE ANTE OLOFIN, BUSCANDO SEPARAR AL LEÓN DE LA CONVIVENCIA CON LOS
HUMANOS. OLOFIN, PREOCUPADO POR LAS QUEJAS, CONSULTÓ A SU CONSEJERO ORÚNMILA PARA OBTENER
INFORMACIÓN SOBRE LA SITUACIÓN ENTRE EL LEÓN Y LA GENTE. DESPUÉS DE UNA CUIDADOSA
EVALUACIÓN, ORÚNMILA CONFIRMÓ QUE LAS QUEJAS ERAN INFUNDADAS Y QUE TODO SE DEBÍA A LA
ENVIDIA QUE SENTÍAN HACIA EL LEÓN POR SU HERMOSURA Y FUERZA. INFORMÓ A OLOFIN,
EXPRESÁNDOLE: "PADRE, LA GENTE SE QUEJA DE QUE EL LEÓN ARAÑA, PERO TODO ESO ES FALSO,
PRODUCTO DE LA ENVIDIA QUE LE TIENEN PORQUE ES HERMOSO Y FUERTE". ANTE ESTE INFORME
FAVORABLE, OLOFIN DECIDIO PERMITIR QUE EL LEÓN CONTINUARA VIVIENDO EN EL PUEBLO. AL
PRINCIPIO, LA GENTE LO DEJÓ TRANQUILO, PERO CON EL TIEMPO COMENZARON A MOLESTARLO. AL
TERCER DÍA, LO ATACARON CON UN PALO, Y EL LEÓN, EN DEFENSA PROPIA, RESPONDIÓ DE MANERA
CONTUNDENTE. ARRANCÓ UN BRAZO A UNO, UNA PIERNA A OTRO, Y A OTRO LO DEJÓ COMPLETAMENTE
DESTROZADO. ACTO SEGUIDO, EL LEÓN SE RETIRÓ HACIA LA SELVA. CUANDO LAS QUEJAS LLEGARON A
OÍDOS DE OLOFIN, EL LEÓN YA SE ENCONTRABA EN LA SELVA Y NUNCA MÁS REGRESÓ AL PUEBLO. LA
LECCIÓN DE ESTA HISTORIA RADICA EN LA INJUSTICIA DE JUZGAR POR ENVIDIA Y CÓMO LAS ACCIONES
IMPULSADAS POR LA MALICIA PUEDEN LLEVAR A CONSECUENCIAS INESPERADAS. ENSEÑANZAS:
INJUSTICIA DE LA ENVIDIA: LA HISTORIA DESTACA CÓMO LA ENVIDIA PUEDE LLEVAR A LA
INJUSTICIA. A PESAR DE QUE EL LEÓN VIVÍA PACÍFICAMENTE EN EL PUEBLO, LA GENTE COMENZÓ A
REPUDIARLO SIMPLEMENTE POR SU BELLEZA Y FUERZA, LO QUE REFLEJA CÓMO LA ENVIDIA PUEDE
GENERAR CONFLICTOS INNECESARIOS. EL PAPEL DE LA VERDAD Y LA JUSTICIA: LA CONSULTA DE
OLOFIN A ORÚNMILA MUESTRA LA IMPORTANCIA DE BUSCAR LA VERDAD Y LAJUSTICIA ANTES DE TOMAR
DECISIONES. ORÚNMILA, COMO CONSEJERO, REALIZA UNA EVALUACIÓN IMPARCIAL Y CONCLUYE QUE LAS
QUEJAS CONTRA EL LEÓN ERAN INFUNDADAS. CONSECUENCIAS DE LA INJUSTICIA: A PESAR DE LA
VERDAD PRESENTADA POR ORÚNMILA, LA GENTE CONTINÚA MOLESTANDO AL LEÓN. LAS ACCIONES
INJUSTAS LLEVAN A UNA REACCIÓN DEFENSIVA DEL LEÓN, RESULTANDO EN CONSECUENCIAS GRAVES PARA
QUIENES LO ATACARON. ESTO RESALTA CÓMO LA INJUSTICIA PUEDE TENER CONSECUENCIAS
PERJUDICIALES. LA SOLEDAD COMO CONSECUENCIA: AUNQUE OLOFIN DECIDE PERMITIR QUE EL LEÓN
CONTINÚE VIVIENDO EN EL PUEBLO, LAS ACCIONES INJUSTAS DE LA GENTE PROVOCAN QUE EL LEÓN SE
RETIRE HACIA LA SELVA. ESTO ILUSTRA CÓMO LA HOSTILIDAD Y LA ENVIDIA PUEDEN LLEVAR A LA
EXCLUSIÓN Y LA SOLEDAD. LA NECESIDAD DE LA CONVIVENCIA PACÍFICA: LA HISTORIA SUBRAYA LA
IMPORTANCIA DE LA CONVIVENCIA PACÍFICA. AUNQUE EL LEÓN VIVÍA EN ARMONÍA CON LA GENTE AL
PRINCIPIO, LAS ACCIONES INJUSTAS DE ALGUNOS LLEVARON A UN CONFLICTO INNECESARIO. LA PAZ Y
LA TOLERANCIA SON FUNDAMENTALES PARA MANTENER UNA SOCIEDAD ARMONIOSA. REACCIONES A LA
DEFENSIVA: EL LEÓN, AL SER ATACADO, REACCIONA EN DEFENSA PROPIA. ESTO ENSEÑA QUE, INCLUSO
LOS SERES MÁS PACÍFICOS, PUEDEN RESPONDER ANTE LA AGRESIÓN. LA HISTORIA SUGIERE QUE LA
AUTODEFENSA ES UNA RESPUESTA NATURAL ANTE LA INJUSTICIA. EN RESUMEN, LA HISTORIA OFRECE
LECCIONES SOBRE LA INJUSTICIA DE LA ENVIDIA, LA IMPORTANCIA DE BUSCAR LA VERDAD Y LA
JUSTICIA, LAS CONSECUENCIAS DE LA INJUSTICIA, LA SOLEDAD COMO RESULTADO DE ACCIONES
HOSTILES, LA NECESIDAD DE CONVIVENCIA PACÍFICA Y LA NATURALEZA DE LAS REACCIONES
DEFENSIVAS ANTE LA AGRESIÓN.''',
};

const _patakiesByOduName = <String, List<String>>{
  'BABA OGBE': _babaEjiogbePatakies,
  'OGBE OYECU': _ogbeOyecuPatakies,
  'OGBE OYEKU': _ogbeOyecuPatakies,
};

class _OduSection extends StatelessWidget {
  const _OduSection({
    required this.title,
    required this.body,
    this.subtitle,
    this.language,
    this.strings,
    this.translateBody = false,
    this.translateSubtitle = false,
  });

  final String title;
  final String body;
  final String? subtitle;
  final AppLanguage? language;
  final AppStrings? strings;
  final bool translateBody;
  final bool translateSubtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final canTranslate =
        language != null && strings != null && TranslationService.instance.isEnabled;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          if (translateBody && canTranslate)
            _TranslatedBody(
              text: body.isEmpty ? '-' : body,
              style: textTheme.bodyMedium,
              language: language!,
              strings: strings!,
              active: true,
              translate: true,
            )
          else
            Text(body.isEmpty ? '-' : body, style: textTheme.bodyMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            if (translateSubtitle && canTranslate)
              _TranslatedBody(
                text: subtitle!.isEmpty ? '-' : subtitle!,
                style: textTheme.bodySmall,
                language: language!,
                strings: strings!,
                active: true,
                translate: true,
              )
            else
              Text(
                subtitle!.isEmpty ? '-' : subtitle!,
                style: textTheme.bodySmall,
              ),
          ],
        ],
      ),
    );
  }
}

class _TranslatedBody extends StatefulWidget {
  const _TranslatedBody({
    required this.text,
    required this.style,
    required this.language,
    required this.strings,
    required this.active,
    required this.translate,
  });

  final String text;
  final TextStyle? style;
  final AppLanguage language;
  final AppStrings strings;
  final bool active;
  final bool translate;

  @override
  State<_TranslatedBody> createState() => _TranslatedBodyState();
}

class _TranslatedBodyState extends State<_TranslatedBody> {
  Future<String>? _future;
  bool _loadingCache = false;

  @override
  void didUpdateWidget(covariant _TranslatedBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.language == AppLanguage.es) {
      _future = null;
      return;
    }
    if (widget.active && widget.translate && _future == null) {
      _future = TranslationService.instance.translate(widget.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.trim().isEmpty || widget.text.trim() == '-') {
      return _buildFormattedBody('-', widget.style);
    }
    if (!widget.translate || widget.language == AppLanguage.es) {
      return _buildFormattedBody(widget.text, widget.style);
    }
    if (!TranslationService.instance.isEnabled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormattedBody(widget.text, widget.style),
          const SizedBox(height: 6),
          Text(
            widget.strings.traduccionNoConfig,
            style: widget.style?.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }
    if (!widget.active) {
      return _buildFormattedBody(widget.text, widget.style);
    }
    final cached = TranslationService.instance.cachedTranslate(widget.text);
    if (cached != null && cached.trim().isNotEmpty) {
      return _buildFormattedBody(cached, widget.style);
    }
    if (!_loadingCache) {
      _loadingCache = true;
      TranslationService.instance
          .cachedTranslateAsync(widget.text)
          .then((value) {
        if (!mounted) {
          return;
        }
        if (value != null && value.trim().isNotEmpty) {
          setState(() {});
        }
      });
    }
    _future ??= TranslationService.instance.translate(widget.text);
    return FutureBuilder<String>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildFormattedBody(widget.text, widget.style);
        }
        final value = snapshot.data?.trim().isNotEmpty == true
            ? snapshot.data!
            : widget.text;
        return _buildFormattedBody(value, widget.style);
      },
    );
  }
}

class _TranslatedText extends StatelessWidget {
  const _TranslatedText({
    required this.text,
    required this.style,
    required this.language,
    required this.strings,
    this.translate = true,
  });

  final String text;
  final TextStyle? style;
  final AppLanguage language;
  final AppStrings strings;
  final bool translate;

  @override
  Widget build(BuildContext context) {
    if (!translate || language == AppLanguage.es) {
      return Text(text, style: style);
    }
    return FutureBuilder<String?>(
      future: TranslationService.instance.cachedTranslateAsync(text),
      builder: (context, cacheSnap) {
        final cached = cacheSnap.data;
        if (cached != null && cached.trim().isNotEmpty) {
          return Text(cached, style: style);
        }
        if (!TranslationService.instance.isEnabled) {
          return Text(text, style: style);
        }
        return FutureBuilder<String>(
          future: TranslationService.instance.translate(text),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Text(text, style: style);
            }
            final value = snapshot.data?.trim().isNotEmpty == true
                ? snapshot.data!
                : text;
            return Text(value, style: style);
          },
        );
      },
    );
  }
}

List<String> _splitLineBySentences(String line) {
  if (line.isEmpty) {
    return const ['-'];
  }
  final parts = line.split(RegExp(r'(?<=[.!?])\\s+'));
  final cleaned = parts
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  return cleaned.isEmpty ? [line] : cleaned;
}

Widget _buildFormattedBody(String body, TextStyle? style) {
  final lines = body
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  if (lines.isEmpty) {
    return Text('-', style: style);
  }
  final hasImageToken = lines.any((line) => line == '[[ATENA]]');
  TextSpan buildSpan(String line) {
    final match = RegExp(r'^([A-ZÁÉÍÓÚÜÑ0-9 ,()\-]+):').firstMatch(line);
    if (match == null) {
      return TextSpan(text: line, style: style);
    }
    final header = match.group(1)!;
    final rest = line.substring(match.end).trim();
    return TextSpan(
      children: [
        TextSpan(
          text: '$header:',
          style: style?.copyWith(
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.underline,
          ),
        ),
        if (rest.isNotEmpty) TextSpan(text: ' $rest', style: style),
      ],
    );
  }

  if (lines.length == 1) {
    final line = lines.first;
    final segments = _splitLineBySentences(line);
    if (segments.length == 1) {
      return Text.rich(buildSpan(line));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < segments.length; i++) ...[
          Text.rich(buildSpan(segments[i])),
          if (i != segments.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  if (!hasImageToken) {
    final expanded = <String>[];
    for (final line in lines) {
      expanded.addAll(_splitLineBySentences(line));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < expanded.length; i++) ...[
          Text.rich(buildSpan(expanded[i])),
          if (i != expanded.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  final items = <Widget>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line == '[[ATENA]]') {
      items.add(Image.asset(
        'assets/odu_signs/ATENA.png',
        fit: BoxFit.contain,
      ));
    } else {
      items.add(Text.rich(buildSpan(line)));
    }
    if (i != lines.length - 1) {
      items.add(const SizedBox(height: 8));
    }
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: items,
  );
}

class _OduExpandableSection extends StatefulWidget {
  const _OduExpandableSection({
    required this.title,
    required this.body,
    required this.language,
    required this.strings,
    this.subtitle,
    this.translateBody = true,
  });

  final String title;
  final String body;
  final String? subtitle;
  final AppLanguage language;
  final AppStrings strings;
  final bool translateBody;

  @override
  State<_OduExpandableSection> createState() => _OduExpandableSectionState();
}

class _OduExpandableSectionState extends State<_OduExpandableSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const collapsedColor = Color(0xFFD9EFD2);
    const expandedColor = Color(0xFFC8E6C9);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: collapsedColor,
        child: ExpansionTile(
          collapsedBackgroundColor: collapsedColor,
          backgroundColor: expandedColor,
          onExpansionChanged: (value) {
            if (_expanded == value) {
              return;
            }
            setState(() => _expanded = value);
          },
          title: Text(
            widget.title,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TranslatedBody(
                    text: widget.body,
                    style: textTheme.bodyMedium,
                    language: widget.language,
                    strings: widget.strings,
                    active: _expanded,
                    translate: widget.translateBody,
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 6),
                    _TranslatedBody(
                      text: widget.subtitle!,
                      style: textTheme.bodySmall,
                      language: widget.language,
                      strings: widget.strings,
                      active: _expanded,
                      translate: widget.translateBody,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatakiesSection extends StatelessWidget {
  const _PatakiesSection({
    required this.strings,
    required this.oduName,
    required this.fallback,
  });

  final AppStrings strings;
  final String oduName;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final key = _normalizeOduName(oduName);
    final patakies = _patakiesByOduName[key];
    final textTheme = Theme.of(context).textTheme;
    const collapsedColor = Color(0xFFD9EFD2);
    const expandedColor = Color(0xFFC8E6C9);

    final hasList = patakies != null && patakies.isNotEmpty;
    final contentText =
        fallback.isNotEmpty ? fallback : strings.contenidoPendiente;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Theme(
        data: Theme.of(context).copyWith(
          expansionTileTheme: const ExpansionTileThemeData(
            collapsedBackgroundColor: collapsedColor,
            backgroundColor: expandedColor,
          ),
        ),
        child: Card(
          color: collapsedColor,
          child: ExpansionTile(
            collapsedBackgroundColor: collapsedColor,
            backgroundColor: expandedColor,
            title: Text(
              strings.historiasPatakies,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            children: hasList
                ? [
                    const SizedBox(height: 4),
                    ...patakies!.map((item) {
                      final content =
                          _babaEjiogbePatakiesContent[item] ?? '';
                      return Card(
                        color: expandedColor,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          title: _TranslatedText(
                            text: item,
                            style: textTheme.bodyMedium,
                            language: strings.language,
                            strings: strings,
                            translate: true,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PatakiDetailScreen(
                                  title: item,
                                  content: content,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                  ]
                : [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(contentText),
                    ),
                  ],
          ),
        ),
      ),
    );
  }
}

class PatakiDetailScreen extends StatelessWidget {
  const PatakiDetailScreen({
    super.key,
    required this.title,
    required this.content,
  });

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, language, _) {
        final strings = AppStrings(language);
        final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.4,
            );
        final resolvedContent =
            content.isEmpty ? strings.contenidoPendiente : content;
        final sections = _splitPatakiSections(resolvedContent);
        final patakiText = sections.pataki.join(' ').trim();
        final traduccionText = sections.traduccion.join(' ').trim();
        final ensenanzasText = sections.ensenanzas.join(' ').trim();
        final titleFuture = strings.language == AppLanguage.en
            ? TranslationService.instance.translate(title)
            : null;
        Widget buildTitle(TextStyle? style) {
          if (titleFuture == null) {
            return Text(title, style: style);
          }
          return FutureBuilder<String>(
            future: titleFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Text(title, style: style);
              }
              final value = snapshot.data?.trim().isNotEmpty == true
                  ? snapshot.data!
                  : title;
              return Text(value, style: style);
            },
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: buildTitle(null),
            actions: [
              IconButton(
                tooltip: 'Home',
                onPressed: () {
                  homeKey.currentState?.goOduExternal();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                icon: const Icon(Icons.home),
              ),
            ],
            bottom: const _LanguageTabBar(),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              buildTitle(
                Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              if (sections.pataki.isNotEmpty) ...[
                _PatakiSectionHeader(text: '${strings.patakiLabel}:'),
                const SizedBox(height: 8),
                _TranslatedPatakiBody(
                  text: patakiText,
                  textStyle: textStyle,
                  language: strings.language,
                  strings: strings,
                ),
                if (sections.traduccion.isNotEmpty) const SizedBox(height: 16),
              ],
              if (sections.traduccion.isNotEmpty) ...[
                _PatakiSectionHeader(text: '${strings.traduccionLabel}:'),
                const SizedBox(height: 8),
                _TranslatedPatakiBody(
                  text: traduccionText,
                  textStyle: textStyle,
                  language: strings.language,
                  strings: strings,
                ),
                if (sections.ensenanzas.isNotEmpty) const SizedBox(height: 16),
              ],
              if (sections.ensenanzas.isNotEmpty) ...[
                _PatakiSectionHeader(text: '${strings.ensenanzasLabel}:'),
                const SizedBox(height: 8),
                _TranslatedPatakiBody(
                  text: ensenanzasText,
                  textStyle: textStyle,
                  language: strings.language,
                  strings: strings,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PatakiSections {
  const _PatakiSections({
    required this.pataki,
    required this.traduccion,
    required this.ensenanzas,
  });

  final List<String> pataki;
  final List<String> traduccion;
  final List<String> ensenanzas;
}

_PatakiSections _splitPatakiSections(String content) {
  var normalized = content.replaceAll(RegExp(r'\\s+'), ' ').trim();
  if (normalized.isEmpty || normalized == '-') {
    return const _PatakiSections(pataki: ['-'], traduccion: [], ensenanzas: []);
  }
  normalized =
      normalized.replaceFirst(RegExp(r'^PATAKI:\\s*', caseSensitive: false), '');
  final parts =
      normalized.split(RegExp(r'ENSENANZAS:|ENSEÑANZAS:', caseSensitive: false));
  final beforeEnsenanzas = parts.isNotEmpty ? parts[0].trim() : '';
  final ensenanzas =
      parts.length > 1 ? _splitIntoParagraphs(parts[1].trim()) : <String>[];

  final tradParts = beforeEnsenanzas.split(
    RegExp(r'TRADUCCION:|TRADUCCIÓN:', caseSensitive: false),
  );
  final pataki =
      _splitIntoParagraphs(tradParts.isNotEmpty ? tradParts[0].trim() : '');
  final traduccion = tradParts.length > 1
      ? _splitIntoParagraphs(tradParts[1].trim())
      : <String>[];

  return _PatakiSections(
    pataki: pataki,
    traduccion: traduccion,
    ensenanzas: ensenanzas,
  );
}

List<String> _splitIntoParagraphs(String text) {
  if (text.isEmpty) {
    return ['-'];
  }
  final normalized = text.replaceAll(RegExp(r'\\s+'), ' ').trim();
  if (normalized.isEmpty) {
    return ['-'];
  }
  final numbered =
      RegExp(r'\\b\\d+\\.\\s').hasMatch(normalized) || normalized.startsWith('1.');
  if (numbered) {
    final parts =
        normalized.split(RegExp(r'(?<=\\.)\\s+(?=\\d+\\.)'));
    final numberedParts = parts
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (numberedParts.isNotEmpty) {
      return numberedParts;
    }
  }
  final sentences = normalized.split(RegExp(r'(?<=[.!?])\\s+'));
  final paragraphs = <String>[];
  for (final sentence in sentences) {
    final chunk = sentence.trim();
    if (chunk.isNotEmpty) {
      paragraphs.add(chunk);
    }
  }
  return paragraphs.isEmpty ? ['-'] : paragraphs;
}

List<Widget> _buildPatakiParagraphs(
  List<String> paragraphs,
  TextStyle? textStyle,
) {
  final widgets = <Widget>[];
  final justifyText = Platform.isMacOS;
  for (var i = 0; i < paragraphs.length; i++) {
    widgets.add(
      Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Text(
          paragraphs[i],
          textAlign: justifyText ? TextAlign.justify : TextAlign.start,
          style: textStyle,
        ),
      ),
    );
    if (i != paragraphs.length - 1) {
      widgets.add(const SizedBox(height: 12));
    }
  }
  return widgets;
}

List<Widget> _buildPatakiParagraphsFromText(
  String text,
  TextStyle? textStyle,
) {
  return _buildPatakiParagraphs(_splitIntoParagraphs(text), textStyle);
}

class _TranslatedPatakiBody extends StatefulWidget {
  const _TranslatedPatakiBody({
    required this.text,
    required this.textStyle,
    required this.language,
    required this.strings,
  });

  final String text;
  final TextStyle? textStyle;
  final AppLanguage language;
  final AppStrings strings;

  @override
  State<_TranslatedPatakiBody> createState() => _TranslatedPatakiBodyState();
}

class _TranslatedPatakiBodyState extends State<_TranslatedPatakiBody> {
  Future<String>? _future;
  bool _loadingCache = false;

  @override
  void didUpdateWidget(covariant _TranslatedPatakiBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.language == AppLanguage.es) {
      _future = null;
      return;
    }
    if (_future == null) {
      _future = TranslationService.instance.translate(widget.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.trim().isEmpty || widget.text.trim() == '-') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _buildPatakiParagraphsFromText('-', widget.textStyle),
      );
    }
    if (widget.language == AppLanguage.es) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _buildPatakiParagraphsFromText(widget.text, widget.textStyle),
      );
    }
    if (!TranslationService.instance.isEnabled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._buildPatakiParagraphsFromText(widget.text, widget.textStyle),
          const SizedBox(height: 6),
          Text(
            widget.strings.traduccionNoConfig,
            style: widget.textStyle?.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      );
    }
    final cached = TranslationService.instance.cachedTranslate(widget.text);
    if (cached != null && cached.trim().isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _buildPatakiParagraphsFromText(cached, widget.textStyle),
      );
    }
    if (!_loadingCache) {
      _loadingCache = true;
      TranslationService.instance
          .cachedTranslateAsync(widget.text)
          .then((value) {
        if (!mounted) {
          return;
        }
        if (value != null && value.trim().isNotEmpty) {
          setState(() {});
        }
      });
    }
    _future ??= TranslationService.instance.translate(widget.text);
    return FutureBuilder<String>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:
                _buildPatakiParagraphsFromText(widget.text, widget.textStyle),
          );
        }
        final value = snapshot.data?.trim().isNotEmpty == true
            ? snapshot.data!
            : widget.text;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _buildPatakiParagraphsFromText(value, widget.textStyle),
        );
      },
    );
  }
}

class _PatakiSectionHeader extends StatelessWidget {
  const _PatakiSectionHeader({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.underline,
          ),
    );
  }
}

String _normalizeOduName(String name) {
  final cleaned =
      name.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  final tokens = cleaned.split(' ');
  final mapped = tokens.map(_normalizeOduToken).toList();
  return mapped.join(' ');
}

String _normalizeOduToken(String token) {
  switch (token) {
    case 'OYECUN':
    case 'OYEKUN':
      return 'OYEKU';
    case 'IROSUN':
      return 'IROSO';
    case 'OTURUPON':
      return 'OTRUPON';
    case 'OSE':
      return 'OSHE';
    case 'OCANA':
    case 'OKANRA':
      return 'OKANA';
    case 'EJIOGBE':
      return 'OGBE';
    default:
      return token;
  }
}

String _mejiPrefixFromName(String name) {
  var normalized = _normalizeOduName(name);
  if (normalized.startsWith('BABA ')) {
    normalized = normalized.substring(5);
  }
  if (normalized.endsWith(' MEJI')) {
    normalized = normalized.substring(0, normalized.length - 5);
  }
  return normalized.trim();
}

class _OduSignAvatar extends StatelessWidget {
  const _OduSignAvatar({
    required this.pattern,
    required this.isMeji,
    this.size = 128,
  });

  final List<bool> pattern;
  final bool isMeji;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipOval(
            child: Image.asset(
              'assets/odu_signs/opon_ifa.png',
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(
            width: size * 0.52,
            height: size * 0.52,
            child: CustomPaint(
              painter: _OduSignPainter(pattern: pattern),
            ),
          ),
        ],
      ),
    );
  }
}

class _OduSignPainter extends CustomPainter {
  _OduSignPainter({required this.pattern});

  final List<bool> pattern;

  @override
  void paint(Canvas canvas, Size size) {
    if (pattern.length != 8) {
      return;
    }

    final blackPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final whitePaint = Paint()
      ..color = const Color(0xFFFFB300)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final yellowStroke = Paint()
      ..color = const Color(0xFF8A6D00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.03
      ..isAntiAlias = true;

    final padding = size.shortestSide * 0.10;
    final usableWidth = size.width - padding * 2;
    final usableHeight = size.height - padding * 2;

    final colGap = usableWidth * 0.10;
    final rowGap = usableHeight * 0.08;

    final colWidth = (usableWidth - colGap) / 2;
    final rowHeight = (usableHeight - rowGap * 3) / 4;
    final radius = (colWidth < rowHeight ? colWidth : rowHeight) * 0.40;

    final gridWidth = colWidth * 2 + colGap;
    final gridHeight = rowHeight * 4 + rowGap * 3;
    final offsetX = (size.width - gridWidth) / 2;
    final offsetY = (size.height - gridHeight) / 2;

    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 2; col++) {
        final isBlack = pattern[row * 2 + col];
        final centerX = offsetX + col * (colWidth + colGap) + colWidth / 2;
        final centerY = offsetY + row * (rowHeight + rowGap) + rowHeight / 2;
        final center = Offset(centerX, centerY);

        if (isBlack) {
          canvas.drawCircle(center, radius, blackPaint);
        } else {
          canvas.drawCircle(center, radius, whitePaint);
          canvas.drawCircle(center, radius, yellowStroke);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OduSignPainter oldDelegate) {
    return oldDelegate.pattern != pattern;
  }
}

String _formatDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _formatDatePdf(DateTime date, AppLanguage language) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  if (language == AppLanguage.en) {
    return '$month/$day/$year';
  }
  return '$day/$month/$year';
}
