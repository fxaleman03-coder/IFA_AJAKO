import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:icloud_kv_storage/icloud_kv_storage.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'odu_data.dart';
import 'odu_content_repository.dart';
import 'odu_models.dart';
import 'odu_search_normalization.dart';
import 'odu_search_index.dart';
import 'theme/ifa_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(TranslationService.instance.preload());
  unawaited(OduContentRepository.instance.preload());
  runApp(const LibretaIfaApp());
}

final ValueNotifier<AppLanguage> appLanguage = ValueNotifier<AppLanguage>(
  AppLanguage.es,
);
final GlobalKey<_HomeScreenState> _homeKey = GlobalKey<_HomeScreenState>();
const String _disclaimerAcceptedStorageKey = 'disclaimerAccepted';
const String _membershipDebugActiveStorageKey = 'membershipDebugActive';

enum AppLanguage { es, en }

Future<bool> getDisclaimerAccepted() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_disclaimerAcceptedStorageKey) ?? false;
}

Future<void> setDisclaimerAccepted(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_disclaimerAcceptedStorageKey, value);
}

Future<bool> getMembershipDebugActive() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_membershipDebugActiveStorageKey) ?? false;
}

Future<void> setMembershipDebugActive(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_membershipDebugActiveStorageKey, value);
}

Future<bool> isMembershipActive() => getMembershipDebugActive();

const String _localNetworkTranslationUrl =
    'http://fxaleman03gmailcoms-MacBook-Pro.local:8787/translate';

List<String> _translationApiCandidates() {
  const configured = String.fromEnvironment(
    'TRANSLATION_API_URL',
    defaultValue: '',
  );
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

  String get appTitle => language == AppLanguage.es ? 'IFA AJAKO' : 'IFA AJAKO';
  String get consultas =>
      language == AppLanguage.es ? 'Consultas' : 'Consultations';
  String get suyeres => language == AppLanguage.es ? 'Suyeres' : 'Suyeres';
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
  String get hijoDe => language == AppLanguage.es ? 'Hijo de' : 'Child of';
  String get omoOlo => language == AppLanguage.es ? 'OMO/OLO' : 'OMO/OLO';
  String get seleccionaFecha =>
      language == AppLanguage.es ? 'Selecciona fecha' : 'Select date';
  String get filtrosConsultas => language == AppLanguage.es
      ? 'Filtros de consultas'
      : 'Consultation filters';
  String get filtrarPorFecha =>
      language == AppLanguage.es ? 'Filtrar por fecha' : 'Filter by date';
  String get filtrarPorNombre =>
      language == AppLanguage.es ? 'Filtrar por nombre' : 'Filter by name';
  String get limpiarFiltros =>
      language == AppLanguage.es ? 'Limpiar filtros' : 'Clear filters';
  String get buscarPorNombre =>
      language == AppLanguage.es ? 'Buscar por nombre' : 'Search by name';
  String get aplicar => language == AppLanguage.es ? 'Aplicar' : 'Apply';
  String get idioma => language == AppLanguage.es ? 'Idioma' : 'Language';
  String get volver => language == AppLanguage.es ? 'Volver' : 'Back';
  String get odusMeji => language == AppLanguage.es ? 'Odu Meji' : 'Meji Odus';
  String get oduSearchHint => language == AppLanguage.es
      ? 'Buscar por nombre, alias o palabra clave'
      : 'Search by name, alias, or keyword';
  String get oduSearchNoResults => language == AppLanguage.es
      ? 'No se encontraron odù para esa búsqueda.'
      : 'No odù found for that search.';
  String get oduSearchGroupName => language == AppLanguage.es ? 'Name' : 'Name';
  String get oduSearchGroupAlias =>
      language == AppLanguage.es ? 'Alias' : 'Alias';
  String get oduSearchGroupTopics =>
      language == AppLanguage.es ? 'Topics' : 'Topics';
  String get oduSearchGroupKeyword =>
      language == AppLanguage.es ? 'Keyword' : 'Keyword';
  String get oduSearchFilterAny =>
      language == AppLanguage.es ? 'Cualquier sección' : 'Any section';
  String get oduSearchFilterDescripcion =>
      language == AppLanguage.es ? 'Descripción' : 'Description';
  String get oduSearchFilterDiceIfa =>
      language == AppLanguage.es ? 'Dice Ifá' : 'Dice Ifá';
  String get oduSearchFilterEshu =>
      language == AppLanguage.es ? 'Eshu' : 'Eshu';
  String get oduSearchFilterObras =>
      language == AppLanguage.es ? 'Obras' : 'Obras';
  String get oduSearchFilterEwes =>
      language == AppLanguage.es ? 'Ewés' : 'Ewes';
  String get oduSearchFilterRezo =>
      language == AppLanguage.es ? 'Rezo' : 'Rezo';
  String get oduSearchFilterSuyere =>
      language == AppLanguage.es ? 'Suyere' : 'Suyere';
  String get oduSearchFilterHistorias =>
      language == AppLanguage.es ? 'Historias' : 'Stories';
  String get oduSearchTopicChipsLabel =>
      language == AppLanguage.es ? 'Temas detectados' : 'Detected topics';
  String get oduSearchDebugTitle =>
      language == AppLanguage.es ? 'Debug de búsqueda' : 'Search debug';
  String get oduSearchOpenError => language == AppLanguage.es
      ? 'No se pudo abrir el odù desde el índice de búsqueda.'
      : 'Could not open odù from search index.';
  String get encabezadoConsulta => language == AppLanguage.es
      ? 'Encabezado de la consulta'
      : 'Consultation header';
  String get odunToyale =>
      language == AppLanguage.es ? 'Odu Toyale' : 'Odu Toyale';
  String get oduOkuta => language == AppLanguage.es ? 'Odu Okuta' : 'Odu Okuta';
  String get oduTomala =>
      language == AppLanguage.es ? 'Odu Tomala' : 'Odu Tomala';
  String get detalleConsulta => language == AppLanguage.es
      ? 'Detalle de la consulta'
      : 'Consultation details';
  String get notas => language == AppLanguage.es ? 'Notas' : 'Notes';
  String get editar => language == AppLanguage.es ? 'Editar' : 'Edit';
  String get eliminar => language == AppLanguage.es ? 'Eliminar' : 'Delete';
  String get consultaEliminada => language == AppLanguage.es
      ? 'Consulta eliminada'
      : 'Consultation deleted';
  String get deshacer => language == AppLanguage.es ? 'Deshacer' : 'Undo';
  String get exportarPdf =>
      language == AppLanguage.es ? 'Exportar PDF' : 'Export PDF';
  String get sincronizarIcloud =>
      language == AppLanguage.es ? 'Sincronizar iCloud' : 'Sync iCloud';
  String get syncCompletada => language == AppLanguage.es
      ? 'Sincronización completada'
      : 'Sync completed';
  String get syncSinCambios =>
      language == AppLanguage.es ? 'Sin cambios' : 'No changes';
  String get syncAhora =>
      language == AppLanguage.es ? 'Actualizar biblioteca' : 'Sync now';
  String get contenidoPendiente => language == AppLanguage.es
      ? 'Contenido pendiente'
      : 'Content coming soon';
  String get guardarCambios =>
      language == AppLanguage.es ? 'Guardar cambios' : 'Save changes';
  String get rezo => language == AppLanguage.es ? 'Rezo' : 'Prayer';
  String get suyere => language == AppLanguage.es ? 'Suyere' : 'Suyere';
  String get enEsteSignoNace =>
      language == AppLanguage.es ? 'En este Odù nace' : 'In this Odù is born';
  String get descripcionSigno =>
      language == AppLanguage.es ? 'Descripción del Odù' : 'Odù description';
  String get prediccionesSigno => language == AppLanguage.es
      ? 'Predicciones del Odù'
      : 'Predictions of the Odù';
  String get prohibicionesSigno =>
      language == AppLanguage.es ? 'Este Odù prohíbe' : 'This Odù forbids';
  String get recomendacionesSigno => language == AppLanguage.es
      ? 'Este Odù recomienda'
      : 'This Odù recommends';
  String get ewesSigno =>
      language == AppLanguage.es ? 'Ewes del Odù' : 'Herbs of the Odù';
  String get eshuSigno =>
      language == AppLanguage.es ? 'Eshu del Odù' : 'Eshu of the Odù';
  String get rezosSuyeres =>
      language == AppLanguage.es ? 'Rezos y Suyeres' : 'Prayers and Suyeres';
  String get obrasSigno =>
      language == AppLanguage.es ? 'Obras del Odù' : 'Works of the Odù';
  String get diceIfa => language == AppLanguage.es ? 'Dice Ifá' : 'Ifá says';
  String get refranes => language == AppLanguage.es ? 'Refranes' : 'Proverbs';
  String get historiasPatakies => language == AppLanguage.es
      ? 'Historias y Patakies'
      : 'Stories and Patakies';
  String get patakiLabel => language == AppLanguage.es ? 'Pataki' : 'Pataki';
  String get traduccionLabel =>
      language == AppLanguage.es ? 'Traducción' : 'Translation';
  String get ensenanzasLabel =>
      language == AppLanguage.es ? 'Enseñanzas' : 'Teachings';
  String get traduciendo =>
      language == AppLanguage.es ? 'Traduciendo…' : 'Translating…';
  String get traduccionNoConfig => language == AppLanguage.es
      ? 'Traducción no configurada'
      : 'Translation not configured';
  String get terminosUso =>
      language == AppLanguage.es ? 'Términos de uso' : 'Terms of Use';
  String get politicaPrivacidad =>
      language == AppLanguage.es ? 'Política de privacidad' : 'Privacy Policy';
  String get membresia =>
      language == AppLanguage.es ? 'Membresía' : 'Membership';
  String get verAvisoImportante => language == AppLanguage.es
      ? 'Ver aviso importante'
      : 'View Important Notice';
  String get avisoMostradoProximoInicio => language == AppLanguage.es
      ? 'El aviso importante se mostrará en el próximo inicio.'
      : 'The important notice will be shown on next app start.';
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
          request.headers.set(
            HttpHeaders.contentTypeHeader,
            'application/json',
          );
          request.add(
            utf8.encode(
              jsonEncode({'text': text, 'source': source, 'target': target}),
            ),
          );
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

class LibretaIfaApp extends StatefulWidget {
  const LibretaIfaApp({super.key});

  @override
  State<LibretaIfaApp> createState() => _LibretaIfaAppState();
}

class _LibretaIfaAppState extends State<LibretaIfaApp> {
  bool? _disclaimerAccepted;

  @override
  void initState() {
    super.initState();
    _loadDisclaimerAccepted();
  }

  Future<void> _loadDisclaimerAccepted() async {
    final accepted = await getDisclaimerAccepted();
    if (!mounted) {
      return;
    }
    setState(() => _disclaimerAccepted = accepted);
  }

  void _handleDisclaimerAccepted() {
    setState(() => _disclaimerAccepted = true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Libreta de IFA',
      debugShowCheckedModeBanner: false,
      theme: IfaTheme.light(),
      home: _disclaimerAccepted == null
          ? const _DisclaimerLoadingScreen()
          : _disclaimerAccepted!
          ? HomeScreen(key: _homeKey)
          : DisclaimerGateScreen(onAccepted: _handleDisclaimerAccepted),
    );
  }
}

class _DisclaimerLoadingScreen extends StatelessWidget {
  const _DisclaimerLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class DisclaimerGateScreen extends StatefulWidget {
  const DisclaimerGateScreen({super.key, required this.onAccepted});

  final VoidCallback onAccepted;

  @override
  State<DisclaimerGateScreen> createState() => _DisclaimerGateScreenState();
}

class _DisclaimerGateScreenState extends State<DisclaimerGateScreen> {
  bool _hasAccepted = false;
  bool _saving = false;

  Future<void> _acceptAndContinue() async {
    if (!_hasAccepted || _saving) {
      return;
    }
    setState(() => _saving = true);
    await setDisclaimerAccepted(true);
    if (!mounted) {
      return;
    }
    widget.onAccepted();
  }

  Future<void> _exitApp() async {
    try {
      await SystemNavigator.pop();
    } catch (_) {
      // Ignore if the platform does not support closing here.
    }
    if (!mounted) {
      return;
    }
    await Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bodyStyle =
        Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55) ??
        const TextStyle(fontSize: 15, height: 1.55);
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, language, _) {
        final isEs = language == AppLanguage.es;
        final title = isEs ? 'Aviso importante' : 'Important Notice';
        final checkboxLabel = isEs
            ? 'He leído y acepto'
            : 'I have read and agree';
        final acceptLabel = isEs ? 'Acepto y continuar' : 'I Agree & Continue';
        final exitLabel = isEs ? 'Salir' : 'Exit';
        final paragraphs = isEs
            ? const [
                'IFA AJAKO es una plataforma de referencia y estudio estructurado de la tradición Ifá Afro-Cubana.',
                'El contenido de esta aplicación es únicamente para fines informativos, culturales y educativos. No sustituye una consulta religiosa formal, ni instrucción, ni guía directa de un practicante calificado.',
                'IFA AJAKO no ofrece asesoramiento médico, legal, psicológico o financiero.',
                'El usuario es el único responsable de cómo interpreta y aplica la información contenida en la aplicación.',
                'Al continuar, usted reconoce y acepta estos términos.',
              ]
            : const [
                'IFA AJAKO is a structured reference and educational platform dedicated to Afro-Cuban Ifá tradition.',
                'The content in this application is provided for informational, cultural, and educational purposes only. It does not replace formal religious consultation, mentorship, or instruction under a qualified practitioner.',
                'IFA AJAKO does not provide medical, legal, psychological, or financial advice.',
                'You are solely responsible for how you interpret and apply any information contained in this application.',
                'By continuing, you acknowledge and accept these terms.',
              ];

        return Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DisclaimerLanguageToggle(
                        language: language,
                        colorScheme: colorScheme,
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 16),
                              for (final paragraph in paragraphs)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: Text(paragraph, style: bodyStyle),
                                ),
                            ],
                          ),
                        ),
                      ),
                      CheckboxListTile(
                        value: _hasAccepted,
                        onChanged: _saving
                            ? null
                            : (value) {
                                setState(() => _hasAccepted = value ?? false);
                              },
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(checkboxLabel),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _hasAccepted && !_saving
                              ? _acceptAndContinue
                              : null,
                          child: Text(acceptLabel),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          onPressed: _saving ? null : _exitApp,
                          child: Text(exitLabel),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DisclaimerLanguageToggle extends StatelessWidget {
  const _DisclaimerLanguageToggle({
    required this.language,
    required this.colorScheme,
  });

  final AppLanguage language;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    Widget tab({required AppLanguage value, required String label}) {
      final selected = language == value;
      return Expanded(
        child: InkWell(
          onTap: selected ? null : () => appLanguage.value = value,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: selected
                      ? colorScheme.secondary
                      : colorScheme.outlineVariant,
                  width: selected ? 3 : 1.5,
                ),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab(value: AppLanguage.es, label: '🇪🇸'),
        tab(value: AppLanguage.en, label: '🇺🇸'),
      ],
    );
  }
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, language, _) {
        final strings = AppStrings(language);
        final sections = language == AppLanguage.es
            ? _termsSectionsEs
            : _termsSectionsEn;
        return _LegalDocumentScreen(
          title: strings.terminosUso,
          sections: sections,
        );
      },
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, language, _) {
        final strings = AppStrings(language);
        final sections = language == AppLanguage.es
            ? _privacySectionsEs
            : _privacySectionsEn;
        return _LegalDocumentScreen(
          title: strings.politicaPrivacidad,
          sections: sections,
        );
      },
    );
  }
}

class MembershipScreen extends StatefulWidget {
  const MembershipScreen({super.key});

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  bool _showFaq = false;
  bool _loading = false;
  bool _membershipDebugActive = false;

  @override
  void initState() {
    super.initState();
    _loadMembershipDebugState();
  }

  Future<void> _loadMembershipDebugState() async {
    final active = await getMembershipDebugActive();
    if (!mounted) {
      return;
    }
    setState(() => _membershipDebugActive = active);
  }

  Future<void> _onContinue(AppLanguage language) async {
    if (_loading) {
      return;
    }
    final isEs = language == AppLanguage.es;
    setState(() => _loading = true);
    try {
      final enableDebug = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            isEs ? 'Pagos aún no activados' : 'Payments not enabled yet',
          ),
          content: Text(
            isEs
                ? 'La integración de pagos estará disponible en una próxima fase.\n\n¿Deseas activar modo membresía (prueba)?'
                : 'Payments will be available in a future phase.\n\nDo you want to enable membership mode (test)?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(isEs ? 'Ahora no' : 'Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(isEs ? 'Activar modo prueba' : 'Enable test mode'),
            ),
          ],
        ),
      );
      if (enableDebug == true) {
        await setMembershipDebugActive(true);
        if (!mounted) {
          return;
        }
        setState(() => _membershipDebugActive = true);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _onRestore(AppLanguage language) async {
    final isEs = language == AppLanguage.es;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isEs
              ? 'Disponible cuando integremos pagos'
              : 'Available when payments are integrated',
        ),
        content: Text(
          isEs
              ? 'La restauración de compras estará disponible cuando activemos pagos en la aplicación.'
              : 'Purchase restoration will be available once payments are enabled in the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(isEs ? 'Entendido' : 'Understood'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700);
    final subtitleStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      height: 1.5,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
    );
    final bodyStyle =
        Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55) ??
        const TextStyle(fontSize: 15, height: 1.55);

    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, language, _) {
        final isEs = language == AppLanguage.es;
        final title = isEs ? 'Membresía' : 'Membership';
        final subtitle = isEs
            ? 'Contribución anual para sostener la biblioteca institucional'
            : 'Annual contribution to sustain the institutional library';
        final institutionalContribution = isEs
            ? 'La membresía anual contribuye al sostenimiento y ampliación estructurada de esta plataforma digital de referencia.\n\nLa biblioteca puede ampliarse cuando existan fundamentos documentales sólidos y verificables dentro de la tradición Afro-Cubana.'
            : 'The annual membership contributes to the structured preservation and responsible expansion of this digital reference platform.\n\nThe library may expand when well-documented and verifiable foundations are identified within Afro-Cuban tradition.';
        final primaryPrice = isEs ? r'$99 / año' : r'$99 / year';
        final secondaryPrice = isEs ? r'$99 / year' : r'$99 / año';
        final priceDescriptor = isEs
            ? 'Contribución anual institucional'
            : 'Annual institutional contribution';
        final continueLabel = isEs
            ? 'Contribuir y activar acceso'
            : 'Contribute & Activate Access';
        final restoreLabel = isEs ? 'Restaurar compra' : 'Restore purchase';
        final includesLabel = isEs ? '¿Qué incluye?' : 'What’s included?';
        final statusLabel = isEs
            ? 'Estado: Activa (prueba)'
            : 'Status: Active (test)';
        final finePrint = isEs
            ? 'El pago y la renovación se gestionan por App Store/Google Play. Puedes cancelar en cualquier momento antes de la fecha de renovación. El acceso se mantiene activo hasta el final del periodo pagado.'
            : 'Billing and renewal are managed by the App Store/Google Play. You can cancel anytime before the renewal date. Access remains active until the end of the paid period.';
        final bullets = isEs
            ? const [
                'Acceso completo a la biblioteca de Odù (contenido premium).',
                'Ampliación estructurada cuando existan fundamentos documentales sólidos.',
                'Funciones avanzadas para estudio y referencia.',
                'Acceso multiplataforma (según tu cuenta de tienda).',
                'Soporte y mejoras continuas.',
              ]
            : const [
                'Full access to the Odù library (premium content).',
                'Structured expansion when well-documented foundations are identified.',
                'Advanced study and reference features.',
                'Cross-device access (store account dependent).',
                'Continued support and improvements.',
              ];
        final faqItems = isEs ? _membershipFaqEs : _membershipFaqEn;

        return Scaffold(
          appBar: AppBar(title: Text(title), bottom: const _LanguageTabBar()),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: titleStyle),
                      const SizedBox(height: 8),
                      Text(subtitle, style: subtitleStyle),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            institutionalContribution,
                            style: bodyStyle.copyWith(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Center(
                            child: Column(
                              children: [
                                Text(
                                  primaryPrice,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  secondaryPrice,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  priceDescriptor,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        fontSize: 12.5,
                                        letterSpacing: 0.3,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.65),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      for (final bullet in bullets)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('• ', style: bodyStyle),
                              Expanded(child: Text(bullet, style: bodyStyle)),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            finePrint,
                            style: bodyStyle.copyWith(
                              fontSize: 13.5,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      if (_membershipDebugActive) ...[
                        const SizedBox(height: 10),
                        Text(
                          statusLabel,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.secondary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _loading
                              ? null
                              : () => _onContinue(language),
                          child: Text(continueLabel),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _loading
                              ? null
                              : () => _onRestore(language),
                          child: Text(restoreLabel),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          onPressed: () {
                            setState(() => _showFaq = !_showFaq);
                          },
                          child: Text(includesLabel),
                        ),
                      ),
                      if (_showFaq) ...[
                        const SizedBox(height: 8),
                        for (final item in faqItems)
                          Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ExpansionTile(
                              title: Text(item.question),
                              childrenPadding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                16,
                              ),
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(item.answer, style: bodyStyle),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MembershipFaqItem {
  const _MembershipFaqItem({required this.question, required this.answer});

  final String question;
  final String answer;
}

const List<_MembershipFaqItem> _membershipFaqEs = [
  _MembershipFaqItem(
    question: '¿Qué obtengo con la membresía?',
    answer:
        'Obtienes acceso premium a la biblioteca completa de Odù, funciones avanzadas orientadas al estudio y la referencia, y ampliaciones estructuradas cuando existan fundamentos documentales sólidos.',
  ),
  _MembershipFaqItem(
    question: '¿Qué significa contribución institucional?',
    answer:
        'La membresía no representa la compra de contenido individual.\n\nConstituye una contribución para el sostenimiento, organización y ampliación estructurada de la biblioteca digital de referencia.',
  ),
  _MembershipFaqItem(
    question: '¿Puedo cancelar cuando quiera?',
    answer:
        'Sí. Puedes cancelar en cualquier momento antes de la fecha de renovación desde tu cuenta de App Store o Google Play.',
  ),
  _MembershipFaqItem(
    question: '¿Mi contenido se guarda?',
    answer:
        'Sí. Se conservan preferencias y contenido local del estudio. No almacenamos datos sensibles del cliente como parte de esta membresía.',
  ),
];

const List<_MembershipFaqItem> _membershipFaqEn = [
  _MembershipFaqItem(
    question: 'What do I get with membership?',
    answer:
        'You get premium access to the full Odù library, advanced study and reference features, and structured expansions when well-documented foundations are identified.',
  ),
  _MembershipFaqItem(
    question: 'What does institutional contribution mean?',
    answer:
        'The membership does not represent the purchase of individual content.\n\nIt constitutes a contribution toward the structured preservation, organization, and responsible expansion of the digital reference library.',
  ),
  _MembershipFaqItem(
    question: 'Can I cancel anytime?',
    answer:
        'Yes. You can cancel anytime before your renewal date from your App Store or Google Play account.',
  ),
  _MembershipFaqItem(
    question: 'Is my content saved?',
    answer:
        'Yes. Preferences and local study content remain stored locally. No sensitive client data is stored as part of this membership flow.',
  ),
];

class _LegalDocumentScreen extends StatelessWidget {
  const _LegalDocumentScreen({required this.title, required this.sections});

  final String title;
  final List<_LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700);
    final bodyStyle = Theme.of(
      context,
    ).textTheme.bodyLarge?.copyWith(height: 1.55);

    return Scaffold(
      appBar: AppBar(title: Text(title), bottom: const _LanguageTabBar()),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < sections.length; i++) ...[
                    Text(sections[i].title, style: titleStyle),
                    const SizedBox(height: 10),
                    for (final paragraph in sections[i].paragraphs)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(paragraph, style: bodyStyle),
                      ),
                    if (i != sections.length - 1) const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegalSection {
  const _LegalSection({required this.title, required this.paragraphs});

  final String title;
  final List<String> paragraphs;
}

const List<_LegalSection> _termsSectionsEs = [
  _LegalSection(
    title: 'Propósito de la aplicación',
    paragraphs: [
      'IFA AJAKO es una plataforma de referencia y estudio estructurado de la tradición Ifá Afro-Cubana. Su finalidad es educativa y de consulta.',
    ],
  ),
  _LegalSection(
    title: 'No constituye asesoramiento profesional',
    paragraphs: [
      'El contenido no reemplaza consulta religiosa formal ni asesoramiento médico, legal, psicológico o financiero.',
    ],
  ),
  _LegalSection(
    title: 'Responsabilidad del usuario',
    paragraphs: [
      'Cada usuario es responsable de cómo interpreta y aplica la información mostrada en la aplicación.',
    ],
  ),
  _LegalSection(
    title: 'Uso prohibido',
    paragraphs: [
      'Se prohíbe usar la aplicación para fraude, suplantación, tergiversación o cualquier actividad ilícita.',
    ],
  ),
  _LegalSection(
    title: 'Propiedad de contenido y licencia',
    paragraphs: [
      'El contenido y la presentación de IFA AJAKO están protegidos por derechos aplicables. El usuario puede consultar el material dentro de la app, pero no puede revenderlo ni relicenciarlo sin autorización.',
    ],
  ),
  _LegalSection(
    title: 'Suscripción y pagos',
    paragraphs: [
      'Actualmente esta sección funciona como marcador legal. Si se habilitan suscripciones o pagos, se informarán aquí los términos comerciales y de renovación.',
    ],
  ),
  _LegalSection(
    title: 'Terminación',
    paragraphs: [
      'Se puede limitar o suspender el acceso ante uso indebido o incumplimiento de estos términos.',
    ],
  ),
  _LegalSection(
    title: 'Contacto',
    paragraphs: ['Contacto legal: legal@ifa-ajako.example (placeholder).'],
  ),
];

const List<_LegalSection> _termsSectionsEn = [
  _LegalSection(
    title: 'App purpose',
    paragraphs: [
      'IFA AJAKO is a structured reference and study platform for Afro-Cuban Ifa tradition. Its purpose is educational and informational.',
    ],
  ),
  _LegalSection(
    title: 'No professional advice',
    paragraphs: [
      'This content does not replace formal religious consultation or medical, legal, psychological, or financial advice.',
    ],
  ),
  _LegalSection(
    title: 'User responsibility',
    paragraphs: [
      'You are solely responsible for how you interpret and apply the information displayed in the app.',
    ],
  ),
  _LegalSection(
    title: 'Prohibited use',
    paragraphs: [
      'Fraud, misrepresentation, impersonation, and unlawful uses are strictly prohibited.',
    ],
  ),
  _LegalSection(
    title: 'Content ownership and license',
    paragraphs: [
      'IFA AJAKO content and presentation are protected by applicable rights. Users may view content in-app but may not resell or sublicense it without permission.',
    ],
  ),
  _LegalSection(
    title: 'Subscription and payment terms',
    paragraphs: [
      'This section is currently a legal placeholder. If subscriptions or paid features are introduced, billing and renewal terms will be stated here.',
    ],
  ),
  _LegalSection(
    title: 'Termination',
    paragraphs: [
      'Access may be limited or suspended for misuse or violation of these terms.',
    ],
  ),
  _LegalSection(
    title: 'Contact',
    paragraphs: ['Legal contact: legal@ifa-ajako.example (placeholder).'],
  ),
];

const List<_LegalSection> _privacySectionsEs = [
  _LegalSection(
    title: 'Datos almacenados localmente',
    paragraphs: [
      'La app almacena en el dispositivo preferencias básicas y la aceptación del aviso importante (clave: disclaimerAccepted).',
      'También puede almacenar consultas creadas por el usuario y caché de traducciones para rendimiento y disponibilidad local.',
    ],
  ),
  _LegalSection(
    title: 'Analítica',
    paragraphs: ['Actualmente IFA AJAKO no utiliza analítica de uso.'],
  ),
  _LegalSection(
    title: 'Sincronización en la nube',
    paragraphs: [
      'En plataformas Apple, la app puede sincronizar consultas mediante iCloud Key-Value Storage cuando esa función está disponible.',
    ],
  ),
  _LegalSection(
    title: 'Servicios de terceros',
    paragraphs: [
      'La app puede interactuar con servicios y componentes del sistema de Apple/Google para funciones de plataforma (por ejemplo, almacenamiento, compartir o impresión), según el dispositivo.',
    ],
  ),
  _LegalSection(
    title: 'Solicitud de eliminación',
    paragraphs: [
      'Para solicitar eliminación de datos o aclaraciones, use el contacto de privacidad: privacy@ifa-ajako.example (placeholder).',
    ],
  ),
  _LegalSection(
    title: 'Actualizaciones de esta política',
    paragraphs: [
      'Esta política puede actualizarse con el tiempo. La versión vigente será la publicada dentro de la aplicación.',
    ],
  ),
];

const List<_LegalSection> _privacySectionsEn = [
  _LegalSection(
    title: 'Data stored locally',
    paragraphs: [
      'The app stores basic preferences and disclaimer acceptance on-device (key: disclaimerAccepted).',
      'It may also store user-created consultations and translation cache for performance and local availability.',
    ],
  ),
  _LegalSection(
    title: 'Analytics',
    paragraphs: ['IFA AJAKO currently does not use usage analytics.'],
  ),
  _LegalSection(
    title: 'Cloud sync',
    paragraphs: [
      'On Apple platforms, the app may sync consultations through iCloud Key-Value Storage when that feature is available.',
    ],
  ),
  _LegalSection(
    title: 'Third-party services',
    paragraphs: [
      'The app may rely on Apple/Google system services and platform components for features such as storage, sharing, or printing, depending on device capabilities.',
    ],
  ),
  _LegalSection(
    title: 'Deletion requests',
    paragraphs: [
      'To request data deletion or clarification, contact privacy: privacy@ifa-ajako.example (placeholder).',
    ],
  ),
  _LegalSection(
    title: 'Policy updates',
    paragraphs: [
      'This policy may be updated over time. The current version is the one published inside the app.',
    ],
  ),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _ConsultaFilterAction { byDate, byName, clear }

class _HomeScreenState extends State<HomeScreen> {
  static const _sections = 3;
  static const _icloudDataKey = 'consultas_json';
  static const _icloudUpdatedKey = 'consultas_updated_at';
  static const _icloudDeletedKey = 'consultas_deleted_ids';

  final _icloud = CKKVStorage();
  int _sectionIndex = 0;
  final List<Consulta> _consultas = [];
  final Set<int> _deletedConsultaIds = {};
  bool _loadingConsultas = true;
  bool _showConsultas = false;
  bool _openingConsultasFilter = false;
  DateTime? _consultaFilterDate;
  String? _consultaFilterName;
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
            leading: _sectionIndex != 0
                ? IconButton(
                    tooltip: strings.volver,
                    onPressed: _goHome,
                    icon: const Icon(Icons.arrow_back),
                  )
                : null,
            actions: _sectionIndex == 0
                ? [
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'sync') {
                          _showSyncNow(strings);
                        } else if (value == 'export_json') {
                          _exportConsultasJson(strings);
                        } else if (value == 'import_json') {
                          _importConsultasJson(strings);
                        } else if (value == 'membership') {
                          _openMembershipScreen();
                        } else if (value == 'terms') {
                          _openTermsScreen();
                        } else if (value == 'privacy') {
                          _openPrivacyScreen();
                        } else if (value == 'view_notice') {
                          _resetDisclaimerForNextStart(strings);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'sync',
                          child: Text(strings.syncAhora),
                        ),
                        const PopupMenuItem(
                          value: 'export_json',
                          child: Text('Exportar JSON'),
                        ),
                        const PopupMenuItem(
                          value: 'import_json',
                          child: Text('Importar JSON'),
                        ),
                        PopupMenuItem(
                          value: 'membership',
                          child: Text(strings.membresia),
                        ),
                        PopupMenuItem(
                          value: 'terms',
                          child: Text(strings.terminosUso),
                        ),
                        PopupMenuItem(
                          value: 'privacy',
                          child: Text(strings.politicaPrivacidad),
                        ),
                        PopupMenuItem(
                          value: 'view_notice',
                          child: Text(strings.verAvisoImportante),
                        ),
                      ],
                    ),
                  ]
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
                  filterName: _consultaFilterName,
                  canClearFilters:
                      _consultaFilterDate != null ||
                      ((_consultaFilterName ?? '').trim().isNotEmpty),
                  onClearFilters: _clearConsultasFilters,
                  selectedId: _selectedConsultaId,
                  onSyncNow: () => _showSyncNow(strings),
                  onSelectForPdf: (consulta) {
                    setState(() => _selectedConsultaId = consulta.id);
                    _exportConsultasPdf(strings);
                  },
                  onEdit: (consulta) =>
                      _openConsultaEditor(strings, existing: consulta),
                  onSwipeDelete: (consulta) =>
                      _removeConsultaWithUndo(strings, consulta),
                  onConfirmSwipeDelete: (consulta) =>
                      _confirmDeleteDialog(strings, consulta),
                  onDelete: (consulta) => _confirmDelete(strings, consulta),
                ),
                SuyeresScreen(strings: strings),
                OduScreen(onBackToHome: _goHome),
              ],
            ),
          ),
          floatingActionButton: _sectionIndex == 0
              ? TextButton.icon(
                  onPressed: () => _openConsultaEditor(strings),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.tertiary,
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(strings.nuevaConsulta),
                )
              : null,
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _sectionIndex,
            onDestinationSelected: (index) {
              if (index < _sections) {
                setState(() => _sectionIndex = index);
                if (index == 0) {
                  _openConsultasFilter(strings);
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
                label: strings.suyeres,
              ),
              NavigationDestination(
                icon: _buildOduNavIcon(selected: false),
                selectedIcon: _buildOduNavIcon(selected: true),
                label: strings.odu,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOduNavIcon({required bool selected}) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = selected
        ? colorScheme.secondaryContainer
        : colorScheme.surfaceContainerHighest;
    final border = selected ? colorScheme.secondary : colorScheme.outline;
    final shadow = selected
        ? [
            const BoxShadow(
              color: Color(0x33000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ]
        : null;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 1.2),
        boxShadow: shadow,
      ),
      child: Center(
        child: ImageIcon(
          AssetImage('assets/odu_signs/opele_chango.png'),
          size: 18,
          color: selected
              ? colorScheme.onSecondaryContainer
              : colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Future<void> _openConsultaEditor(
    AppStrings strings, {
    Consulta? existing,
  }) async {
    final consulta = await Navigator.of(context).push<Consulta>(
      MaterialPageRoute(
        builder: (_) => ConsultaEditorScreen(existing: existing),
      ),
    );

    if (consulta == null) {
      _goHome();
      return;
    }

    setState(() {
      final index = _consultas.indexWhere((item) => item.id == consulta.id);
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

  Future<void> _openConsultasFilter(AppStrings strings) async {
    if (_openingConsultasFilter) {
      return;
    }
    _openingConsultasFilter = true;
    var typedName = _consultaFilterName ?? '';
    try {
      final action = await showModalBottomSheet<_ConsultaFilterAction>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) {
          final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
          return SafeArea(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: bottomInset),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today),
                      title: Text(strings.filtrarPorFecha),
                      onTap: () => Navigator.of(
                        sheetContext,
                      ).pop(_ConsultaFilterAction.byDate),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: typedName,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: strings.filtrarPorNombre,
                        hintText: strings.buscarPorNombre,
                        prefixIcon: const Icon(Icons.search),
                      ),
                      onChanged: (value) => typedName = value,
                      onFieldSubmitted: (_) => Navigator.of(
                        sheetContext,
                      ).pop(_ConsultaFilterAction.byName),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.of(
                              sheetContext,
                            ).pop(_ConsultaFilterAction.clear),
                            icon: const Icon(Icons.filter_alt_off),
                            label: Text(strings.limpiarFiltros),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.of(
                              sheetContext,
                            ).pop(_ConsultaFilterAction.byName),
                            child: Text(strings.aplicar),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
      if (!mounted || action == null) {
        return;
      }
      if (action == _ConsultaFilterAction.byName) {
        final normalized = typedName.trim();
        setState(() {
          _consultaFilterName = normalized.isEmpty ? null : normalized;
          if (_consultaFilterName != null) {
            _consultaFilterDate = null;
          }
          _showConsultas = true;
        });
        return;
      }
      if (action == _ConsultaFilterAction.clear) {
        _clearConsultasFilters();
        return;
      }

      final picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(1900),
        lastDate: DateTime(2100),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (picked == null) {
        return;
      }
      setState(() {
        _consultaFilterDate = picked;
        _consultaFilterName = null;
        _showConsultas = true;
      });
    } finally {
      _openingConsultasFilter = false;
    }
  }

  void _goHome() {
    setState(() {
      _sectionIndex = 0;
      _showConsultas = false;
      _consultaFilterDate = null;
      _consultaFilterName = null;
      _selectedConsultaId = null;
    });
  }

  void goHomeExternal() => _goHome();

  void _clearConsultasFilters() {
    _goHome();
  }

  Future<void> _openMembershipScreen() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MembershipScreen()));
  }

  Future<void> _openTermsScreen() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TermsScreen()));
  }

  Future<void> _openPrivacyScreen() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PrivacyScreen()));
  }

  Future<void> _resetDisclaimerForNextStart(AppStrings strings) async {
    await setDisclaimerAccepted(false);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(strings.avisoMostradoProximoInicio)));
  }

  void goOduExternal() {
    setState(() {
      _sectionIndex = 2;
      _showConsultas = false;
      _consultaFilterDate = null;
      _consultaFilterName = null;
      _selectedConsultaId = null;
    });
  }

  Future<bool> _confirmDeleteDialog(
    AppStrings strings,
    Consulta consulta,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.eliminar),
        content: Text(
          consulta.nombreCompleto.isEmpty
              ? strings.eliminar
              : consulta.nombreCompleto,
        ),
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

    return shouldDelete == true;
  }

  Future<void> _confirmDelete(AppStrings strings, Consulta consulta) async {
    final shouldDelete = await _confirmDeleteDialog(strings, consulta);
    if (!shouldDelete) {
      return;
    }

    setState(() {
      _consultas.remove(consulta);
      _deletedConsultaIds.add(consulta.id);
      if (_selectedConsultaId == consulta.id) {
        _selectedConsultaId = null;
      }
    });
    await _saveConsultas();
  }

  Future<void> _removeConsultaWithUndo(
    AppStrings strings,
    Consulta consulta,
  ) async {
    final index = _consultas.indexOf(consulta);
    if (index == -1) {
      return;
    }
    setState(() {
      _consultas.removeAt(index);
      _deletedConsultaIds.add(consulta.id);
      if (_selectedConsultaId == consulta.id) {
        _selectedConsultaId = null;
      }
    });
    await _saveConsultas();
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(strings.consultaEliminada),
        action: SnackBarAction(
          label: strings.deshacer,
          onPressed: () {
            unawaited(_undoConsultaDelete(consulta, index));
          },
        ),
      ),
    );
  }

  Future<void> _undoConsultaDelete(Consulta consulta, int index) async {
    if (!mounted) {
      return;
    }
    setState(() {
      final insertionIndex = index <= _consultas.length
          ? index
          : _consultas.length;
      _consultas.insert(insertionIndex, consulta);
      _deletedConsultaIds.remove(consulta.id);
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
                return Consulta.fromJson(Map<String, dynamic>.from(entry));
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
                  return Consulta.fromJson(Map<String, dynamic>.from(entry));
                }
                return null;
              }).whereType<Consulta>(),
            );
          _consultas.removeWhere(
            (item) => _deletedConsultaIds.contains(item.id),
          );
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(strings.sinConsultas)));
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('JSON: $path')));
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
          if (!mounted) {
            return;
          }
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('JSON: $path')));
      }
      if (!Platform.isIOS) {
        await OpenFilex.open(path);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error al exportar JSON')));
      }
    }
  }

  Future<void> _importConsultasJson(AppStrings strings) async {
    const typeGroup = XTypeGroup(label: 'JSON', extensions: ['json']);
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('JSON inválido')));
        }
        return;
      }
      final parsed = data
          .map((entry) {
            if (entry is Map) {
              return Consulta.fromJson(Map<String, dynamic>.from(entry));
            }
            return null;
          })
          .whereType<Consulta>()
          .toList();
      setState(() {
        final merged = <int, Consulta>{
          for (final existing in _consultas) existing.id: existing,
          for (final incoming in parsed) incoming.id: incoming,
        };
        _consultas
          ..clear()
          ..addAll(merged.values);
        _consultaFilterDate = null;
        _consultaFilterName = null;
        _showConsultas = true;
        _selectedConsultaId = null;
      });
      await _saveConsultas();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Importación completada')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error al importar JSON')));
      }
    }
  }

  Future<void> _showSyncNow(AppStrings strings) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(strings.syncAhora),
        children: [
          SimpleDialogOption(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final changed = await _syncFromIcloud(forceMerge: true);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    changed ? strings.syncCompletada : strings.syncSinCambios,
                  ),
                ),
              );
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
        remoteList = data
            .map((entry) {
              if (entry is Map) {
                return Consulta.fromJson(Map<String, dynamic>.from(entry));
              }
              return null;
            })
            .whereType<Consulta>()
            .toList();
      } else if (data is Map) {
        final consultasRaw = data['consultas'];
        final deletedRaw = data['deletedIds'];
        if (consultasRaw is List) {
          remoteList = consultasRaw
              .map((entry) {
                if (entry is Map) {
                  return Consulta.fromJson(Map<String, dynamic>.from(entry));
                }
                return null;
              })
              .whereType<Consulta>()
              .toList();
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
      _deletedConsultaIds.addAll(remoteDeleted);

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
      final changed =
          mergedList.length != _consultas.length ||
          _consultas.any((item) => !merged.containsKey(item.id)) ||
          deletedChanged;

      if (changed || forceMerge) {
        if (mounted) {
          setState(() {
            _consultas
              ..clear()
              ..addAll(mergedList);
            _consultaFilterDate = null;
            _consultaFilterName = null;
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
    final pdfCourierBold = pw.Font.courierBold();
    pw.ImageProvider? logoImage;
    try {
      final data = await DefaultAssetBundle.of(context).load('assets/logo.png');
      logoImage = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      logoImage = null;
    }

    final selected = _consultas
        .where((consulta) => consulta.id == _selectedConsultaId)
        .toList();

    if (selected.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(strings.sinConsultas)));
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
                          consulta.oduTomala.isEmpty ? '-' : consulta.oduTomala,
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
                          consulta.oduOkuta.isEmpty ? '-' : consulta.oduOkuta,
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
        Widget tab({required AppLanguage value, required String label}) {
          final selected = language == value;
          return Expanded(
            child: InkWell(
              onTap: selected ? null : () => appLanguage.value = value,
              child: Container(
                height: kToolbarHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected
                          ? Theme.of(context).colorScheme.secondary
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(
                            context,
                          ).colorScheme.onPrimary.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }

        return Row(
          children: [
            tab(value: AppLanguage.es, label: '🇪🇸'),
            tab(value: AppLanguage.en, label: '🇺🇸'),
          ],
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
    required this.onSwipeDelete,
    required this.onConfirmSwipeDelete,
    required this.filterDate,
    required this.filterName,
    required this.canClearFilters,
    required this.onClearFilters,
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
  final ValueChanged<Consulta> onSwipeDelete;
  final Future<bool> Function(Consulta) onConfirmSwipeDelete;
  final DateTime? filterDate;
  final String? filterName;
  final bool canClearFilters;
  final VoidCallback onClearFilters;
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
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.center,
              widthFactor: 0.85,
              child: Image.asset(
                'assets/logos/image.png',
                width: 260,
                height: 260,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Structured Afro-Cuban Ifá Reference',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                letterSpacing: 0.5,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }
    final nameFilter = filterName?.trim().toLowerCase();
    final filtered = consultas.where((consulta) {
      final matchesDate =
          filterDate == null || _isSameDate(consulta.fecha, filterDate!);
      final matchesName =
          nameFilter == null ||
          nameFilter.isEmpty ||
          _matchesNameFilter(consulta.nombreCompleto, nameFilter);
      return matchesDate && matchesName;
    }).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: canClearFilters ? onClearFilters : null,
                icon: const Icon(Icons.filter_alt_off),
                label: Text(strings.limpiarFiltros),
              ),
            ],
          ),
        ),
        if (filtered.isEmpty)
          Expanded(child: Center(child: Text(strings.sinConsultas))),
        if (filtered.isNotEmpty)
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              separatorBuilder: (_, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final consulta = filtered[index];
                return Dismissible(
                  key: ObjectKey(consulta),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Icon(
                      Icons.delete,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  secondaryBackground: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Icon(
                      Icons.delete,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  confirmDismiss: (_) => onConfirmSwipeDelete(consulta),
                  onDismissed: (_) => onSwipeDelete(consulta),
                  child: _ConsultaCard(
                    consulta: consulta,
                    strings: strings,
                    isSelected: selectedId == consulta.id,
                    onSelectForPdf: () => onSelectForPdf(consulta),
                    onEdit: () => onEdit(consulta),
                    onDelete: () => onDelete(consulta),
                  ),
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
            Text('${strings.fecha}: ${_formatDate(consulta.fecha)}'),
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
                  PopupMenuItem(value: 'edit', child: Text(strings.editar)),
                  PopupMenuItem(value: 'delete', child: Text(strings.eliminar)),
                  const PopupMenuDivider(),
                  PopupMenuItem(value: 'pdf', child: Text(strings.exportarPdf)),
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
      fecha:
          DateTime.tryParse(json['fecha'] as String? ?? '') ?? DateTime.now(),
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
  const ConsultaEditorScreen({super.key, this.existing});

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
    _nombreController = TextEditingController(
      text: existing?.nombreCompleto ?? '',
    );
    _hijoController = TextEditingController(text: existing?.hijoDe ?? '');
    _omoOloController = TextEditingController(text: existing?.omoOlo ?? '');
    _toyaleController = TextEditingController(text: existing?.odunToyale ?? '');
    _okutaController = TextEditingController(text: existing?.oduOkuta ?? '');
    _tomalaController = TextEditingController(text: existing?.oduTomala ?? '');
    _detalleController = TextEditingController(
      text: existing?.detalleConsulta ?? '',
    );
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
                        decoration: InputDecoration(
                          labelText: strings.nombreCompleto,
                        ),
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
                            child: Text(
                              '${strings.fecha}: ${_formatDate(_fecha)}',
                            ),
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
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _save,
                child: Text(
                  widget.existing == null
                      ? strings.guardar
                      : strings.guardarCambios,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OduNoteField extends StatelessWidget {
  const _OduNoteField({required this.label, required this.controller});

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
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
      ],
    );
  }
}

class SuyeresScreen extends StatelessWidget {
  const SuyeresScreen({super.key, required this.strings});

  final AppStrings strings;

  static const List<SuyereCardData> _suyeres = [
    SuyereCardData(
      title: 'SUYERE A ECHU MODUNBELA:',
      lines: [
        'MOYUMBAO ORISHA, MOYUMBAO ORISHA ASHE',
        'MOYUMBAO ORISHA, MOYUMBAO ORISHA ASHE',
        'MOYUMBAO ILE, MOYUMBAO ORISHA ASHE',
        'Elewua elewa a',
      ],
    ),
    SuyereCardData(
      title: 'SUYERE OGUN:',
      lines: [
        'OGUN A LA WELDE, O INLE MOKUO',
        'BABA A LA WELDE, O INLE MOKUO',
        'OGUNDERE ARERE, INLE BOMBO LOKUA',
        'OGUN GUANILE, OKE GUALONA',
        'INLE BOMBO LOKUA ALDE',
        'AWANILEO, OGUN MARIBO',
        'AWANILEO, ARERE MARIBO OGUN AFOMBOLE',
        'O INLE ODE OBERE MARIWO',
        'OGUNDE BAMBA',
        'MARIWO YE, YE, YE, MARIWO',
        'OGUN LA MIGUO',
        'IBORERE, IBORAIRA, OBATALAILA IQUIYOSO',
        'IBORERE, IBORAIRA, OBATALAILA IQUIYOSO',
        'OBATALAILA----------- IQUIYOSO',
        'OBATALAILA----------- IQUIYOSO',
        'OGUN MEYI, MEYI MORESE A LA GERE OGUN',
        'OGUN MEYI, MEYI MORESE A LA GERE OGUN',
      ],
    ),
    SuyereCardData(
      title: 'SUYERE OCHOZI:',
      lines: [
        'OCHOZI BABA, AYILODA A LA MALAODE (BIS)',
        'SIRE, SIRE ODEMATA ODE, ODE',
        'YANBELEKE ILORUN',
        'ODE MATA KOLONA',
        'ODE MATA KOLONA',
        'ODE MATA KOLONA EH',
        'ERO SIBAMBA KARERE',
        'BABA KARERE BABA KARERE',
        'ADIFAFUN OCHOZI',
        'ADIFAFUN ODE',
        'EEE EMI ODEDE (BIS)',
        'AWA LORO KONNFORA ODE',
        'GUAYE, GUAYE COMO DE MORO',
        'GUAYE, GUAYE COMO DE MORO',
        'GUAYE, GUAYE',
        'GUAYE KEKE',
        'GUAYE, GUAYE COMO DE MORO',
        'IWARA ODEFA, ODE MATA',
        'IWARA ODEFA, IFA DE MATA',
      ],
    ),
    SuyereCardData(
      title: 'SUYERE A OSHUN:',
      lines: [
        'IYA MI ILE ORO, IYA MI ILE ORO',
        'BOGBO ASHE, IYA MI SARAMAWO EH',
        'IYA MI ILE (BIS)',
        'IDE WERE, WERE ITA OSHUN',
        'IDE WERE, WERE',
        'IDE WERE, WERE ITA OSHUN',
        'IDEWERE WERE ITA IYA',
        'OSHA KI NIWA ITA OSHUN, SHEKE',
        'SHEKE ITA IYA, IDE WERE, WERE (BIS)',
        'SHEKE, SHEKE, SHEKE, SHEKE, SHEKE KOMAITA',
        'KOMA ITA OSHUN',
        'SHEKE, SHEKE, SHEKE, SHEKE, SHEKE KOMAITA',
        'KOMAITA IYA (BIS)',
        'OSHUN BALEO, YEYE BALEO',
        'OSHUN BALEO, YEYE BALEO',
        'OSHUN IBORU, IBOYA, IBOCHECHE',
        'YEYE BALEO (BIS)',
      ],
    ),
    SuyereCardData(
      title: 'SUYERE ALGAYU:',
      lines: [
        'OYA, OYA OTOWA',
        'OYA, OYA ALGAYU COMASE IRAWO',
        'OKE, OKE ALGAYU OMO LORISHA (BIS)',
        'ALGAYU OMO LASERE',
        'ALGAYU SHO LA NIO',
        'ALGAYU SHO LA NIO, BABA, SÉLA',
        'INDIA SE LAYO',
        'SORO ELEWE MI SORO ALGAYU',
        'MAIN, MAIN, MAIN SOROSO AHE',
        'ALGAYU SOROSO AHE',
      ],
    ),
    SuyereCardData(
      title: 'SUYERE SHANGO:',
      lines: [
        'CABOE EH, EH CABOE',
        'CABOE EH CABIO SILE OH (BIS)',
        'URE URE, URE IROKO, IROKO LO KEKE',
        'ANAPAINA KONIAPAÑA APAÑA MISISI',
        'OLUWO OZAIN ALA MALADE',
        'OBA LUBE OBA LUBE, OBA LUBE OBA EH',
        'OBA LUBE OBA LUBE, OBA LUBE OBA EH',
        'OBA EH OBA YANA YANA',
        'MEREBOTIMBO LODE, MEREBOTIMBO',
        'MEREBOTIMBO LODE, MEREBOTIMBO',
        'JEVIOSO MEREBOTIMBO LODE',
        'MEREBOTIMBO KUELE A',
        'SHANGO ARAGBA RIBODE',
        'SHANGO ARAGBA RIBODE',
        'ODEMATA RIBODE',
        'SHANGO ARAGBA RIBODE',
        'ARABAO SORIBODE',
      ],
    ),
    SuyereCardData(
      title: 'SUYERE A ORICHAOKO:',
      lines: [
        'IRAWO ILE OFERE, ODUDUWA LA SHUPUA',
        'IRAWO ILE OFERE, INLE LA SHUPUA',
        'IRAWO ILE OFERE, INA LA SHUPUA',
        'IRAWO ILE OFERE, ORICHAOKO LA SHUPUA (BIS)',
        'YOMBALE MISIRE EREO',
        'YOMBALE MISIRE EREO ORICHAOKO',
        'YOMBALE MISIRE EREO GOGOYARO (BIS)',
        'OMO ODARA DEI',
        'OMO ODARA DIE',
        'OMO ODARA DEI',
        'OMO ODARA DIE',
        'OLODUMARE DEI',
        'OMO ODARA ORICHAOKO (BIS)',
        'LAYE LAWA, LAYE, LAYE LAFISI',
        'LAYE, LAYE LAFISI, LAYE LAWA (BIS)',
        'IEH, ORICHAOKO DIDE',
        'IEH, ORICHAOKO DIDE',
        'BABA KARERE, KARE LAWAO',
      ],
    ),
    SuyereCardData(
      title: 'SUYERE OLOKUN:',
      lines: [
        'OLOKUN BAWAO, ORISHA BAWAO',
        'BAWA ORISHA, BAWA ORISHA BAWAO',
        'OLOKUN FERELILELE, OLOKUN FERELILELE',
        'AKANA LERY FERELILELE',
      ],
    ),
    SuyereCardData(
      title: 'SUYERE AZOGUANO:',
      lines: [
        'UÑEÑE, UÑEÑE MITO MANU KUKU',
        'UÑEÑE, UÑEÑE ASOWANO NANU',
        'UÑEÑE, UÑEÑE AFIMAYE NANU',
        'UÑEÑE, UÑEÑE ASOYI N NANU',
        'UÑEÑE, UÑEÑE KUTUMASE NANU',
        'UÑEÑE, UÑEÑE SUSUJUME NANU',
        'AKARA ASUYAGUEA',
        'ASUYAGUEA AZOGUANO, ASUYAGUEA',
        'CORO: AKARA ASUYAGUEA',
        'ASUSUJONA, ASUSUJONA, ASUYAGUEA',
        'CORO: AKARA ASUYAGUEA',
        'ASUSUJONA, ASUSUJONA, ASUYAGUEA',
        'CORO: AKARA ASUYAGUEA',
      ],
    ),
    SuyereCardData(
      title: 'SUYERE ABITA:',
      lines: [
        'ABITA MOKONU',
        'ABITA MOKOAYE',
        'KUKUNU, KUKUNU ABITA MOKONU',
        'ABITA MOKOAYE',
      ],
    ),
    SuyereCardData(
      title: 'SUYERE DE ODDUA:',
      lines: [
        'ODDUA NIYE, ODDUA NIYE EYE',
        'ODDUA NIYE, ODDUA NIYE EYE',
        'IRAWO ILE OFERE ODUDUWA LA SHUPUA',
        'CORO: IRAWO ILE OFERE ODUDUWA LA SHUPUA',
      ],
    ),
    SuyereCardData(
      title: 'SUYERE DE AYAKUA ORUN:',
      lines: ['EYE EYENI', 'AYAKUA AUN EGUN OLORUN', 'AWA IKU'],
    ),
    SuyereCardData(
      title: 'SUYERE EGUN:',
      lines: [
        'YOLO, YOLO LAWAO',
        'SHANGO EGGUN AWALODE',
        'BOGBO EGGUN ARA ONU AWALODE',
        'SHANGO EGUN AWALODE',
        'IKUYERE, IKUYERE',
        'EYE IKU, IKUYERE',
        'ERUN SEYE, ERUN SEYE',
        'EYE ERUN SEYE',
        'EYE EYELE, EYELE NI LEO',
        'AKOKORO LOYE, EYELE NILEO',
        'EYE EYELE, EYELE DUN, DUN',
        'DUN, DUN BAWA IKU EGUN',
        'BOGBO EGUN KE NI ARA ONU KE TIMBELESE OLODUMARE',
        'IBAILEKUN CON SU WALELE LAILORUN EGUN BOGBO EGUN KE NI ARA ONU (nombre del EGUN) KE TIMBELESE CON SU WALELE',
        'LAILORUN EGUN',
        'AUMBÁ WA ORI, AUMBÁ WA ORI, AWA OZUN, AWA OMA, LERY OMA, LEYABBÓ, BOGBO EGU KE NI ARA ONU KAWÉ',
        'ECHU KUELE, KUELE ONIYA, ECHU KUELE, KUELE ONIYA BOGBO EGUN KE NI ARA ONU (nombre del EGUN al cual se le oficia) SE FUE IYA',
      ],
    ),
    SuyereCardData(
      title: 'SUYERE DE YEMAYA.',
      lines: [
        'YEMAYA ABOYO INLE LADE, ABOYO YEMAYA INLE LADE.ABOYOO.',
        'YEMAYA OROMINI LAYEO YEMAYA. YEMAYA OROMINI LAYEO YEMAYA.',
        'EWE LOYA, ACOTA, ALEKETE, OZUNYEMAYA OROMINI LAYEEE YERMAYA.',
        'KAE KAE KAEEE YEMAYA OLORDO. KAE KAE KAE ASESU OLORDO.',
        'YEMAYA ASESUUU, ASESU YEMAYA. YEMAYA ASESUUU, ASESU YAMAYA.',
        'YEMAYA OLORDO, OLORDO YEMAYA.',
      ],
    ),
    SuyereCardData(
      title: 'SUYERE DE OBATALA.',
      lines: [
        'BABA ARAYEOOO. BABA ARAYEOOO.',
        'BABA KUEURO,OSHAKINIOOO LAYEYEO OKUNIO NI BABA.',
        'OBATALA KINI LOKUO, OBATALA KINI LOKUO.',
        'TELE TELE SINEYAWO, LATE LATE KOMOSONASHE, OBATALA OMO LORISHA YOBATALA EEE, OBATALA DIDE DIDE. OBATALA EEE, OBATALA DIDE DIDE.OBATALA FEYE SIMORO, OBATALA DIDE DIDE.',
      ],
    ),
    SuyereCardData(
      title: 'SUYERE PARA DESPUES DEL YEN DE LA ALDIE DE ORULA.',
      lines: [
        'ESPALDA. OSA LOBEYO LAMINAGARA TIRI YAMPO VI SHANGO KABIOSILE LAMINAGARA ADIFAFUN ASHIKUELU.ALA DERECHA. TUTUTO TUTONENE INANKIO AKUAERY, ORO MANKIO ALDIE ODDUN, ORO MANKIO ASHE ORISA.ALA IZQUIERDA. TUTUTO TUTONENEO, TUTUTO TUTONENEO, INANKIO COMAWAMA, TUTUTO TUTONENEOO.PLUMA. OGBE ROSO UNTELE, ATIEDI IKU, ATIEDI ARON.',
        'JUJU TOLO MANIKUY , TOLO MANIKUY.',
        'JUJU TOLO MANIKUY .',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: strings.suyeres,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _suyeres.length,
        separatorBuilder: (_, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final suyeres = _suyeres[index];
          return Card(
            elevation: 2,
            child: ListTile(
              title: Text(
                suyeres.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SuyereDetailScreen(data: suyeres),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class SuyereCardData {
  const SuyereCardData({required this.title, required this.lines});

  final String title;
  final List<String> lines;
}

class SuyereDetailScreen extends StatelessWidget {
  const SuyereDetailScreen({super.key, required this.data});

  final SuyereCardData data;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, language, _) {
        final strings = AppStrings(language);
        final body = data.lines.join('\n').trim();
        final resolvedBody = body.isEmpty ? strings.contenidoPendiente : body;
        return Scaffold(
          appBar: AppBar(
            title: Text(data.title),
            bottom: const _LanguageTabBar(),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                data.title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _FormattedBody(
                text: resolvedBody,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        );
      },
    );
  }
}

class OduScreen extends StatefulWidget {
  const OduScreen({super.key, required this.onBackToHome});

  final VoidCallback onBackToHome;

  @override
  State<OduScreen> createState() => _OduScreenState();
}

class _OduScreenState extends State<OduScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final Future<OduSearchIndex> _searchIndexFuture = OduSearchIndex.load();
  String _query = '';
  String? _searchSectionBoost;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onQueryChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final next = _searchController.text;
    if (_query == next) {
      return;
    }
    setState(() => _query = next);
  }

  List<(int, int)> _findHighlightRanges(
    String rawText,
    List<String> normalizedTokens,
  ) {
    final folded = foldSearchTextKeepingLength(rawText);
    final ranges = <(int, int)>[];
    for (final token in normalizedTokens) {
      final q = token.trim();
      if (q.length < 2) {
        continue;
      }
      var start = 0;
      while (start < folded.length) {
        final hit = folded.indexOf(q, start);
        if (hit < 0) {
          break;
        }
        ranges.add((hit, hit + q.length));
        start = hit + q.length;
      }
    }
    if (ranges.isEmpty) {
      return const [];
    }
    ranges.sort((a, b) => a.$1.compareTo(b.$1));
    final merged = <(int, int)>[ranges.first];
    for (var i = 1; i < ranges.length; i++) {
      final prev = merged.last;
      final current = ranges[i];
      if (current.$1 <= prev.$2) {
        merged[merged.length - 1] = (
          prev.$1,
          current.$2 > prev.$2 ? current.$2 : prev.$2,
        );
      } else {
        merged.add(current);
      }
    }
    return merged;
  }

  TextSpan _buildHighlightedSpan(
    String text,
    List<String> normalizedTokens, {
    required TextStyle baseStyle,
  }) {
    final ranges = _findHighlightRanges(text, normalizedTokens);
    if (ranges.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }
    final children = <InlineSpan>[];
    var cursor = 0;
    for (final range in ranges) {
      final start = range.$1.clamp(0, text.length);
      final end = range.$2.clamp(0, text.length);
      if (start > cursor) {
        children.add(
          TextSpan(text: text.substring(cursor, start), style: baseStyle),
        );
      }
      if (end > start) {
        children.add(
          TextSpan(
            text: text.substring(start, end),
            style: baseStyle.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      }
      cursor = end;
    }
    if (cursor < text.length) {
      children.add(TextSpan(text: text.substring(cursor), style: baseStyle));
    }
    return TextSpan(children: children, style: baseStyle);
  }

  OduEntry? _resolveOduEntryFromSearch(OduSearchEntry result) {
    final normalizedCandidates = <String>{
      _normalizeOduName(result.key),
      _normalizeOduName(result.name),
      ...result.aliases.map(_normalizeOduName),
    };
    for (final entry in oduEntries) {
      if (normalizedCandidates.contains(_normalizeOduName(entry.name))) {
        return entry;
      }
    }
    return null;
  }

  void _openEntryFromSearch(
    BuildContext context,
    OduScoredResult result,
    AppStrings strings,
  ) {
    final resolved = _resolveOduEntryFromSearch(result.entry);
    if (resolved == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.oduSearchOpenError)));
      return;
    }
    final target = resolved.isMeji
        ? MejiDetailScreen(entry: resolved)
        : OduDetailScreen(entry: resolved);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => target));
  }

  Widget _buildMejiGrid(List<OduEntry> mejiEntries) {
    return LayoutBuilder(
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
                  final avatarSize = (constraints.maxHeight * 0.62).clamp(
                    64.0,
                    110.0,
                  );
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
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(fontSize: 9),
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
    );
  }

  Widget _buildGroupHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  List<(String?, String)> _sectionFilterOptions(AppStrings strings) {
    return <(String?, String)>[
      (null, strings.oduSearchFilterAny),
      ('descripcion', strings.oduSearchFilterDescripcion),
      ('diceIfa', strings.oduSearchFilterDiceIfa),
      ('eshu', strings.oduSearchFilterEshu),
      ('obras', strings.oduSearchFilterObras),
      ('ewes', strings.oduSearchFilterEwes),
      ('rezoYoruba', strings.oduSearchFilterRezo),
      ('suyereYoruba', strings.oduSearchFilterSuyere),
      ('historiasYPatakies', strings.oduSearchFilterHistorias),
    ];
  }

  Widget _buildResolvedTopicChips(
    OduSearchResults results,
    AppStrings strings,
  ) {
    if (results.resolvedTopics.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.oduSearchTopicChipsLabel,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: results.resolvedTopics
                .map((topic) {
                  return ActionChip(
                    label: Text(topic.label),
                    onPressed: () {
                      _searchController.text = topic.label;
                      _searchController.selection = TextSelection.collapsed(
                        offset: topic.label.length,
                      );
                    },
                  );
                })
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(AppStrings strings, OduSearchResults results) {
    final queryTokens = results.highlightTokens;
    if (results.isEmpty) {
      return Center(child: Text(strings.oduSearchNoResults));
    }
    final widgets = <Widget>[];

    void addGroup(String title, List<OduScoredResult> entries) {
      if (entries.isEmpty) return;
      widgets.add(_buildGroupHeader(title));
      for (final scored in entries) {
        final entry = scored.entry;
        final titleText = entry.name.isEmpty ? entry.key : entry.name;
        final subtitleText = entry.preview.isEmpty
            ? entry.aliases.take(2).join(', ')
            : entry.preview;
        widgets.add(
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              title: RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: _buildHighlightedSpan(
                  titleText,
                  queryTokens,
                  baseStyle:
                      Theme.of(context).textTheme.titleMedium ??
                      const TextStyle(),
                ),
              ),
              subtitle: RichText(
                maxLines: scored.why == null ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                text: _buildHighlightedSpan(
                  scored.why == null
                      ? subtitleText
                      : '$subtitleText\n${scored.why}',
                  queryTokens,
                  baseStyle:
                      Theme.of(context).textTheme.bodySmall ??
                      const TextStyle(),
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${scored.score}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () => _openEntryFromSearch(context, scored, strings),
            ),
          ),
        );
      }
    }

    addGroup(strings.oduSearchGroupName, results.nameMatches);
    addGroup(strings.oduSearchGroupAlias, results.aliasMatches);
    addGroup(strings.oduSearchGroupTopics, results.topicMatches);
    addGroup(strings.oduSearchGroupKeyword, results.keywordMatches);

    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      children: widgets,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mejiEntries = oduEntries.where((entry) => entry.isMeji).toList();
    final searching = _query.trim().isNotEmpty;

    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, language, child) {
        final strings = AppStrings(language);
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: strings.oduSearchHint,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _query.trim().isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => _searchController.clear(),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String?>(
                    tooltip: strings.filtrosConsultas,
                    icon: const Icon(Icons.tune),
                    initialValue: _searchSectionBoost,
                    onSelected: (value) {
                      setState(() => _searchSectionBoost = value);
                    },
                    itemBuilder: (_) => _sectionFilterOptions(strings)
                        .map(
                          (option) => PopupMenuItem<String?>(
                            value: option.$1,
                            child: Row(
                              children: [
                                if (_searchSectionBoost == option.$1)
                                  const Icon(Icons.check, size: 16)
                                else
                                  const SizedBox(width: 16),
                                const SizedBox(width: 8),
                                Text(option.$2),
                              ],
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(width: 8),
                    FutureBuilder<OduSearchIndex>(
                      future: _searchIndexFuture,
                      builder: (context, snapshot) {
                        return IconButton(
                          tooltip: strings.oduSearchDebugTitle,
                          onPressed: snapshot.hasData
                              ? () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => OduSearchDebugScreen(
                                        index: snapshot.data!,
                                        title: strings.oduSearchDebugTitle,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                          icon: const Icon(Icons.bug_report_outlined),
                        );
                      },
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: searching
                    ? FutureBuilder<OduSearchIndex>(
                        future: _searchIndexFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (!snapshot.hasData) {
                            return Center(
                              child: Text(strings.oduSearchNoResults),
                            );
                          }
                          final results = snapshot.data!.search(
                            _query,
                            sectionBoostOverride: _searchSectionBoost,
                          );
                          return Column(
                            children: [
                              _buildResolvedTopicChips(results, strings),
                              Expanded(
                                child: _buildSearchResults(strings, results),
                              ),
                            ],
                          );
                        },
                      )
                    : _buildMejiGrid(mejiEntries),
              ),
            ],
          ),
        );
      },
    );
  }
}

class OduSearchDebugScreen extends StatelessWidget {
  const OduSearchDebugScreen({
    super.key,
    required this.index,
    required this.title,
  });

  final OduSearchIndex index;
  final String title;

  static const _queries = <String>[
    'eshu aroni',
    'odu que hablan de dinero',
    'odu sobre enfermedad',
    'odu donde habla eshu aroni',
    'rezo de orunmila',
    'suyere de iku',
    'odu de justicia y acusacion',
    'odu con osanyin proteccion',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _queries.length,
        itemBuilder: (context, indexQuery) {
          final query = _queries[indexQuery];
          final result = index.search(query);
          final ranked =
              [
                ...result.nameMatches.map((e) => ('Name', e)),
                ...result.aliasMatches.map((e) => ('Alias', e)),
                ...result.topicMatches.map((e) => ('Topics', e)),
                ...result.keywordMatches.map((e) => ('Keyword', e)),
              ]..sort((a, b) {
                if (a.$2.score != b.$2.score) {
                  return b.$2.score.compareTo(a.$2.score);
                }
                return a.$2.entry.name.compareTo(b.$2.entry.name);
              });
          final top5 = ranked
              .take(5)
              .map((row) {
                final label = row.$1;
                final item = row.$2;
                final tokenInfo = item.matchedTokens.isEmpty
                    ? '-'
                    : item.matchedTokens.join('|');
                final sectionInfo = item.matchedSections.isEmpty
                    ? '-'
                    : item.matchedSections.join('|');
                final phraseInfo = item.matchedPhraseTypes.isEmpty
                    ? '-'
                    : item.matchedPhraseTypes.join('|');
                return '$label:${item.entry.name}(${item.score}) '
                    '[tokens:$tokenInfo] [section:$sectionInfo] '
                    '[phrase:$phraseInfo]';
              })
              .join(' | ');
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              title: Text(query),
              subtitle: Text(
                'Name=${result.nameMatches.length}, '
                'Alias=${result.aliasMatches.length}, '
                'Topics=${result.topicMatches.length}, '
                'Keyword=${result.keywordMatches.length}'
                '${top5.isEmpty ? '' : '\n$top5'}',
              ),
            ),
          );
        },
      ),
    );
  }
}

class MejiIconsScreen extends StatelessWidget {
  const MejiIconsScreen({super.key, required this.entry});

  final OduEntry entry;

  @override
  Widget build(BuildContext context) {
    final prefix = _mejiPrefixFromName(entry.name);
    final subSigns = oduEntries
        .where(
          (entry) =>
              !entry.isMeji && _normalizeOduName(entry.name).startsWith(prefix),
        )
        .toList();
    final iconEntries = [entry, ...subSigns];

    return Scaffold(
      appBar: AppBar(title: Text(entry.name), bottom: const _LanguageTabBar()),
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
                        ? MejiDetailScreen(entry: item)
                        : OduDetailScreen(entry: item);
                    Navigator.of(
                      context,
                    ).push(MaterialPageRoute(builder: (_) => target));
                  },
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final avatarSize = (constraints.maxHeight * 0.62).clamp(
                        64.0,
                        110.0,
                      );
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
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(fontSize: 9),
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

class MejiDetailScreen extends StatefulWidget {
  const MejiDetailScreen({super.key, required this.entry});

  final OduEntry entry;

  @override
  State<MejiDetailScreen> createState() => _MejiDetailScreenState();
}

class _MejiDetailScreenState extends State<MejiDetailScreen> {
  late final Future<OduData> _dataFuture;
  late final Future<bool> _membershipFuture;
  String? _currentExpandedSectionTitle;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
    _membershipFuture = isMembershipActive();
  }

  Future<OduData> _loadData() {
    final key = _normalizeOduName(widget.entry.name);
    return OduContentRepository.instance.getByKey(
      key,
      fallbackName: widget.entry.name,
    );
  }

  void _setCurrentSection(String? title) {
    if (_currentExpandedSectionTitle == title) {
      return;
    }
    setState(() => _currentExpandedSectionTitle = title);
    assert(() {
      debugPrint('Expanded section (${widget.entry.name}): ${title ?? 'none'}');
      return true;
    }());
  }

  void _handleSectionExpansion(String sectionTitle, bool isExpanded) {
    if (isExpanded) {
      _setCurrentSection(sectionTitle);
      return;
    }
    if (_currentExpandedSectionTitle == sectionTitle) {
      _setCurrentSection(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, language, _) {
        final strings = AppStrings(language);
        return FutureBuilder<OduData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            final data = snapshot.data ?? OduData.empty(widget.entry.name);
            final currentIndex = oduEntries.indexWhere(
              (element) => element.name == widget.entry.name,
            );
            final hasPrev = currentIndex > 0;
            final hasNext =
                currentIndex >= 0 && currentIndex < oduEntries.length - 1;
            final prevEntry = hasPrev ? oduEntries[currentIndex - 1] : null;
            final nextEntry = hasNext ? oduEntries[currentIndex + 1] : null;
            return FutureBuilder<bool>(
              future: _membershipFuture,
              builder: (context, membershipSnapshot) {
                final membershipActive = membershipSnapshot.data ?? false;
                final loadingMembership =
                    membershipSnapshot.connectionState ==
                    ConnectionState.waiting;
                final visibleMainTitle = _resolveVisibleOduMainTitle(
                  content: data.content,
                  fallbackEntryName: widget.entry.name,
                );
                final visibleAliases = _resolveVisibleOduAliases(
                  content: data.content,
                  mainTitle: visibleMainTitle,
                );
                return Scaffold(
                  appBar: AppBar(
                    title: Text(visibleMainTitle),
                    automaticallyImplyLeading: false,
                    leading: IconButton(
                      tooltip: prevEntry == null
                          ? 'Anterior'
                          : 'Anterior: ${prevEntry.name}',
                      onPressed: prevEntry == null
                          ? null
                          : () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      OduDetailScreen(entry: prevEntry),
                                ),
                              );
                            },
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                    ),
                    actions: [
                      IconButton(
                        tooltip: nextEntry == null
                            ? 'Siguiente'
                            : 'Siguiente: ${nextEntry.name}',
                        onPressed: nextEntry == null
                            ? null
                            : () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        OduDetailScreen(entry: nextEntry),
                                  ),
                                );
                              },
                        icon: const Icon(
                          Icons.chevron_right,
                          color: Colors.white,
                        ),
                      ),
                    ],
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(84),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              children: [
                                const Spacer(),
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: IconButton(
                                    tooltip: 'Home',
                                    onPressed: () {
                                      _homeKey.currentState?.goOduExternal();
                                      Navigator.of(
                                        context,
                                      ).popUntil((route) => route.isFirst);
                                    },
                                    icon: const Icon(
                                      Icons.home,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const _LanguageTabBar(),
                        ],
                      ),
                    ),
                  ),
                  body: loadingMembership
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          children: [
                            buildCurrentSectionIndicator(
                              context,
                              _currentExpandedSectionTitle,
                              isSpanish: strings.language == AppLanguage.es,
                            ),
                            Expanded(
                              child: ListView(
                                padding: const EdgeInsets.all(16),
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: _OduHeaderTitleBlock(
                                          mainTitle: visibleMainTitle,
                                          aliases: visibleAliases,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      _OduSignAvatar(
                                        pattern: widget.entry.marks,
                                        isMeji: true,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  ..._buildOduContentSections(
                                    strings: strings,
                                    data: data,
                                    membershipActive: membershipActive,
                                    onSectionExpansionChanged:
                                        _handleSectionExpansion,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class OduDetailScreen extends StatefulWidget {
  const OduDetailScreen({super.key, required this.entry});

  final OduEntry entry;

  @override
  State<OduDetailScreen> createState() => _OduDetailScreenState();
}

class _OduDetailScreenState extends State<OduDetailScreen> {
  late final Future<OduData> _dataFuture;
  late final Future<bool> _membershipFuture;
  String? _currentExpandedSectionTitle;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
    _membershipFuture = isMembershipActive();
  }

  Future<OduData> _loadData() {
    final key = _normalizeOduName(widget.entry.name);
    return OduContentRepository.instance.getByKey(
      key,
      fallbackName: widget.entry.name,
    );
  }

  void _setCurrentSection(String? title) {
    if (_currentExpandedSectionTitle == title) {
      return;
    }
    setState(() => _currentExpandedSectionTitle = title);
    assert(() {
      debugPrint('Expanded section (${widget.entry.name}): ${title ?? 'none'}');
      return true;
    }());
  }

  void _handleSectionExpansion(String sectionTitle, bool isExpanded) {
    if (isExpanded) {
      _setCurrentSection(sectionTitle);
      return;
    }
    if (_currentExpandedSectionTitle == sectionTitle) {
      _setCurrentSection(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, language, _) {
        final strings = AppStrings(language);
        return FutureBuilder<OduData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            final data = snapshot.data ?? OduData.empty(widget.entry.name);
            final currentIndex = oduEntries.indexWhere(
              (element) => element.name == widget.entry.name,
            );
            final hasPrev = currentIndex > 0;
            final hasNext =
                currentIndex >= 0 && currentIndex < oduEntries.length - 1;
            final prevEntry = hasPrev ? oduEntries[currentIndex - 1] : null;
            final nextEntry = hasNext ? oduEntries[currentIndex + 1] : null;
            return FutureBuilder<bool>(
              future: _membershipFuture,
              builder: (context, membershipSnapshot) {
                final membershipActive = membershipSnapshot.data ?? false;
                final loadingMembership =
                    membershipSnapshot.connectionState ==
                    ConnectionState.waiting;
                final visibleMainTitle = _resolveVisibleOduMainTitle(
                  content: data.content,
                  fallbackEntryName: widget.entry.name,
                );
                final visibleAliases = _resolveVisibleOduAliases(
                  content: data.content,
                  mainTitle: visibleMainTitle,
                );
                return Scaffold(
                  appBar: AppBar(
                    title: Text(visibleMainTitle),
                    automaticallyImplyLeading: false,
                    leading: IconButton(
                      tooltip: prevEntry == null
                          ? 'Anterior'
                          : 'Anterior: ${prevEntry.name}',
                      onPressed: prevEntry == null
                          ? null
                          : () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      OduDetailScreen(entry: prevEntry),
                                ),
                              );
                            },
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                    ),
                    actions: [
                      IconButton(
                        tooltip: nextEntry == null
                            ? 'Siguiente'
                            : 'Siguiente: ${nextEntry.name}',
                        onPressed: nextEntry == null
                            ? null
                            : () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        OduDetailScreen(entry: nextEntry),
                                  ),
                                );
                              },
                        icon: const Icon(
                          Icons.chevron_right,
                          color: Colors.white,
                        ),
                      ),
                    ],
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(84),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              children: [
                                const Spacer(),
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: IconButton(
                                    tooltip: 'Home',
                                    onPressed: () {
                                      _homeKey.currentState?.goOduExternal();
                                      Navigator.of(
                                        context,
                                      ).popUntil((route) => route.isFirst);
                                    },
                                    icon: const Icon(
                                      Icons.home,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const _LanguageTabBar(),
                        ],
                      ),
                    ),
                  ),
                  body: loadingMembership
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          children: [
                            buildCurrentSectionIndicator(
                              context,
                              _currentExpandedSectionTitle,
                              isSpanish: strings.language == AppLanguage.es,
                            ),
                            Expanded(
                              child: ListView(
                                padding: const EdgeInsets.all(16),
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: _OduHeaderTitleBlock(
                                          mainTitle: visibleMainTitle,
                                          aliases: visibleAliases,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      _OduSignAvatar(
                                        pattern: widget.entry.marks,
                                        isMeji: widget.entry.isMeji,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  ..._buildOduContentSections(
                                    strings: strings,
                                    data: data,
                                    membershipActive: membershipActive,
                                    onSectionExpansionChanged:
                                        _handleSectionExpansion,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                );
              },
            );
          },
        );
      },
    );
  }
}

String _resolveVisibleOduMainTitle({
  required OduContent content,
  required String fallbackEntryName,
}) {
  final mainName = content.mainName.trim();
  if (mainName.isNotEmpty) {
    return mainName;
  }
  final contentName = content.name.trim();
  if (contentName.isNotEmpty) {
    return contentName;
  }
  return _toDisplayTitleCase(fallbackEntryName);
}

List<String> _resolveVisibleOduAliases({
  required OduContent content,
  required String mainTitle,
}) {
  final visible = <String>[];
  final seen = <String>{_normalizeOduName(mainTitle)};

  for (final rawAlias in content.aliases) {
    final alias = rawAlias.trim();
    if (alias.isEmpty) {
      continue;
    }
    final normalizedAlias = _normalizeOduName(alias);
    if (normalizedAlias.isEmpty || !seen.add(normalizedAlias)) {
      continue;
    }
    visible.add(alias);
  }

  return visible;
}

class _OduHeaderTitleBlock extends StatelessWidget {
  const _OduHeaderTitleBlock({required this.mainTitle, required this.aliases});

  final String mainTitle;
  final List<String> aliases;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final aliasStyle = textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      height: 1.3,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(mainTitle, style: textTheme.headlineSmall),
        if (aliases.isNotEmpty) ...[
          const SizedBox(height: 6),
          ...aliases.map((alias) => Text(alias, style: aliasStyle)),
        ],
      ],
    );
  }
}

List<Widget> _buildOduContentSections({
  required AppStrings strings,
  required OduData data,
  required bool membershipActive,
  void Function(String sectionTitle, bool isExpanded)?
  onSectionExpansionChanged,
}) {
  final content = data.content;
  final sections = <Widget>[];

  final rezo = _normalizeOduText(content.rezoYoruba, preserveLineBreaks: true);
  if (_hasOduText(rezo)) {
    sections.add(
      _OduSection(
        title: strings.rezo,
        body: rezo,
        language: strings.language,
        strings: strings,
      ),
    );
  }

  final suyereY = _normalizeOduText(
    content.suyereYoruba,
    preserveLineBreaks: true,
  );
  final suyereEs = _normalizeOduText(
    content.suyereEspanol,
    preserveLineBreaks: true,
  );
  final suyereEsDisplay = prepareDisplayText(suyereEs);
  if (_hasOduText(suyereY) || _hasOduText(suyereEsDisplay)) {
    sections.add(
      _OduSection(
        title: strings.suyere,
        body: suyereY,
        subtitle: _hasOduText(suyereEsDisplay) ? suyereEsDisplay : null,
        language: strings.language,
        strings: strings,
      ),
    );
  }

  final eshu = _normalizeOduText(content.eshu);
  final nace = _normalizeOduText(content.nace);
  final eshuHeaderLine = _extractFirstNonEmptyOduLine(eshu);
  if (_hasOduText(nace)) {
    sections.add(
      _OduExpandableSection(
        title: strings.enEsteSignoNace,
        body: nace,
        language: strings.language,
        strings: strings,
        allowReindex: false,
        shiftLeadingOrderedSequenceFromTwo: true,
        sectionKey: 'nace',
        duplicateLineToRemoveAfterPrepare: eshuHeaderLine,
        onExpansionChanged: (isExpanded) => onSectionExpansionChanged?.call(
          strings.enEsteSignoNace,
          isExpanded,
        ),
      ),
    );
  }

  final descripcion = normalizeDescripcionOduHeaderNumberForDisplay(
    _normalizeOduText(content.descripcion),
    oduName: content.name,
  );
  final hasDescripcionSection =
      descripcion.trim().isNotEmpty && descripcion.trim() != '-';
  if (hasDescripcionSection) {
    sections.add(
      _OduExpandableSection(
        title: strings.descripcionSigno,
        body: descripcion,
        language: strings.language,
        strings: strings,
        sectionKey: 'descripcion',
        onExpansionChanged: (isExpanded) => onSectionExpansionChanged?.call(
          strings.descripcionSigno,
          isExpanded,
        ),
      ),
    );
  }

  final predicciones = _normalizeOduText(content.predicciones);
  if (_hasOduText(predicciones)) {
    sections.add(
      _OduExpandableSection(
        title: strings.prediccionesSigno,
        body: predicciones,
        language: strings.language,
        strings: strings,
        sectionKey: 'predicciones',
        onExpansionChanged: (isExpanded) => onSectionExpansionChanged?.call(
          strings.prediccionesSigno,
          isExpanded,
        ),
      ),
    );
  }

  final prohibiciones = _normalizeOduText(content.prohibiciones);
  if (_hasOduText(prohibiciones)) {
    sections.add(
      _OduExpandableSection(
        title: strings.prohibicionesSigno,
        body: prohibiciones,
        language: strings.language,
        strings: strings,
        sectionKey: 'prohibiciones',
        onExpansionChanged: (isExpanded) => onSectionExpansionChanged?.call(
          strings.prohibicionesSigno,
          isExpanded,
        ),
      ),
    );
  }

  final recomendaciones = _normalizeOduText(content.recomendaciones);
  if (_hasOduText(recomendaciones)) {
    sections.add(
      _OduExpandableSection(
        title: strings.recomendacionesSigno,
        body: recomendaciones,
        language: strings.language,
        strings: strings,
        sectionKey: 'recomendaciones',
        onExpansionChanged: (isExpanded) => onSectionExpansionChanged?.call(
          strings.recomendacionesSigno,
          isExpanded,
        ),
      ),
    );
  }

  final ewes = _normalizeOduText(content.ewes);
  if (_hasOduText(ewes)) {
    sections.add(
      _OduExpandableSection(
        title: strings.ewesSigno,
        body: ewes,
        language: strings.language,
        strings: strings,
        sectionKey: 'ewes',
        requiresMembership: true,
        membershipActive: membershipActive,
        onExpansionChanged: (isExpanded) =>
            onSectionExpansionChanged?.call(strings.ewesSigno, isExpanded),
      ),
    );
  }

  if (_hasOduText(eshu)) {
    sections.add(
      _OduExpandableSection(
        title: strings.eshuSigno,
        body: eshu,
        language: strings.language,
        strings: strings,
        sectionKey: 'eshu',
        requiresMembership: true,
        membershipActive: membershipActive,
        onExpansionChanged: (isExpanded) =>
            onSectionExpansionChanged?.call(strings.eshuSigno, isExpanded),
      ),
    );
  }

  final rezos = _normalizeOduText(content.rezosYSuyeres);
  final hasStandaloneRezo = _hasOduText(rezo);
  final hasStandaloneSuyere =
      _hasOduText(suyereY) || _hasOduText(suyereEsDisplay);
  final showGroupedRezosOnly =
      _hasOduText(rezos) && !hasStandaloneRezo && !hasStandaloneSuyere;
  if (showGroupedRezosOnly) {
    sections.add(
      _OduExpandableSection(
        title: strings.rezosSuyeres,
        body: rezos,
        language: strings.language,
        strings: strings,
        sectionKey: 'otros',
        onExpansionChanged: (isExpanded) =>
            onSectionExpansionChanged?.call(strings.rezosSuyeres, isExpanded),
      ),
    );
  }

  final obras = _normalizeOduText(content.obrasYEbbo);
  if (_hasOduText(obras)) {
    sections.add(
      _OduExpandableSection(
        title: strings.obrasSigno,
        body: obras,
        language: strings.language,
        strings: strings,
        sectionKey: 'obras',
        requiresMembership: true,
        membershipActive: membershipActive,
        onExpansionChanged: (isExpanded) =>
            onSectionExpansionChanged?.call(strings.obrasSigno, isExpanded),
      ),
    );
  }

  final dice = _normalizeOduText(content.diceIfa);
  if (_hasOduText(dice)) {
    sections.add(
      _OduExpandableSection(
        title: strings.diceIfa,
        body: dice,
        language: strings.language,
        strings: strings,
        sectionKey: 'dice_ifa',
        requiresMembership: true,
        membershipActive: membershipActive,
        onExpansionChanged: (isExpanded) =>
            onSectionExpansionChanged?.call(strings.diceIfa, isExpanded),
      ),
    );
  }

  final refranes = _normalizeOduText(content.refranes);
  if (_hasOduText(refranes)) {
    sections.add(
      _OduExpandableSection(
        title: strings.refranes,
        body: refranes,
        language: strings.language,
        strings: strings,
        sectionKey: 'otros',
        onExpansionChanged: (isExpanded) =>
            onSectionExpansionChanged?.call(strings.refranes, isExpanded),
      ),
    );
  }

  final historiasFallback = _normalizeOduText(content.historiasYPatakies);
  if (data.patakies.isNotEmpty || _hasOduText(historiasFallback)) {
    sections.add(
      _PatakiesSection(
        strings: strings,
        fallback: historiasFallback,
        patakies: data.patakies,
        patakiesContent: data.patakiesContent,
        membershipActive: membershipActive,
        onExpansionChanged: (isExpanded) => onSectionExpansionChanged?.call(
          strings.historiasPatakies,
          isExpanded,
        ),
      ),
    );
  }

  return sections;
}

bool _hasOduText(String? text) {
  if (text == null) {
    return false;
  }
  final trimmed = text.trim();
  return trimmed.isNotEmpty && trimmed != '-';
}

String _normalizeOduText(String text, {bool preserveLineBreaks = false}) {
  if (text.trim().isEmpty) {
    return '';
  }

  final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final lines = normalized.split('\n');

  if (preserveLineBreaks) {
    final out = <String>[];
    var previousBlank = false;
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) {
        if (!previousBlank && out.isNotEmpty) {
          out.add('');
        }
        previousBlank = true;
        continue;
      }
      out.add(line);
      previousBlank = false;
    }
    while (out.isNotEmpty && out.last.isEmpty) {
      out.removeLast();
    }
    return out.join('\n');
  }

  final out = <String>[];
  var previousEndedParagraph = true;

  bool isStandalone(String line) {
    final l = line.trim();
    if (l.isEmpty) {
      return true;
    }
    if (RegExp(r'^[\u2022\-*]\s+').hasMatch(l)) {
      return true;
    }
    if (RegExp(r'^\d+\s*[-.)]\s+').hasMatch(l)) {
      return true;
    }
    if (RegExp(r'^[A-ZÁÉÍÓÚÜÑ0-9 ,()\-]{2,80}:$').hasMatch(l)) {
      return true;
    }
    return false;
  }

  bool startsNewParagraph(String line) {
    final l = line.trim();
    if (l.isEmpty) {
      return true;
    }
    if (isStandalone(l)) {
      return true;
    }
    if (RegExp(
      r'^(REZO|SUYERE|IFA DE|DICE IFA|NACE|DESCRIPCI(?:Ó|O)N(?:\s+DEL\s+OD(?:Ù|U|O))?|HIERBAS|ESHU|REFRANES)\b',
    ).hasMatch(l.toUpperCase())) {
      return true;
    }
    return false;
  }

  for (final raw in lines) {
    final line = raw.trim();
    if (line.isEmpty) {
      if (out.isNotEmpty && out.last.isNotEmpty) {
        out.add('');
      }
      previousEndedParagraph = true;
      continue;
    }

    if (out.isEmpty || previousEndedParagraph || startsNewParagraph(line)) {
      out.add(line);
      previousEndedParagraph = isStandalone(line);
      continue;
    }

    final prev = out.removeLast();
    final merged = '$prev $line'.replaceAll(RegExp(r'\s+'), ' ').trim();
    out.add(merged);
    previousEndedParagraph = false;
  }

  while (out.isNotEmpty && out.last.isEmpty) {
    out.removeLast();
  }

  return out.join('\n');
}

String? _extractFirstNonEmptyOduLine(String text) {
  for (final raw
      in text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n')) {
    final line = raw.trim();
    if (line.isNotEmpty && line != '-') {
      return line;
    }
  }
  return null;
}

String _normalizeComparableLine(String line) {
  final markerStripped = line.trim().replaceFirst(
    RegExp(r'^(?:[•\-]\s+|\d{1,3}\s*[-.)]\s+)'),
    '',
  );
  return markerStripped
      .replaceAll(RegExp(r'[.!?;:,\-–—"]+$'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .toLowerCase();
}

String _removeDuplicatedEshuHeaderLineFromNace({
  required String preparedNaceText,
  required String eshuHeaderLine,
}) {
  if (preparedNaceText.trim().isEmpty || eshuHeaderLine.trim().isEmpty) {
    return preparedNaceText;
  }

  final eshuHeaderKey = _normalizeComparableLine(eshuHeaderLine);
  if (eshuHeaderKey.isEmpty) {
    return preparedNaceText;
  }

  final filteredLines = <String>[];
  for (final raw
      in preparedNaceText
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n')
          .split('\n')) {
    final line = raw.trim();
    if (line.isNotEmpty && _normalizeComparableLine(line) == eshuHeaderKey) {
      continue;
    }
    filteredLines.add(raw);
  }

  return filteredLines.join('\n');
}

String _shiftLeadingOrderedSequenceFromTwoToOne(String text) {
  if (text.trim().isEmpty) {
    return text;
  }

  final lines = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');
  final orderedLinePattern = RegExp(r'^(\s*)(\d{1,3})(\.\s+)(.+)$');

  var startIndex = -1;
  var endExclusive = -1;
  final numbers = <int>[];

  for (var i = 0; i < lines.length; i++) {
    final firstMatch = orderedLinePattern.firstMatch(lines[i]);
    if (firstMatch == null) {
      continue;
    }

    startIndex = i;
    numbers.add(int.parse(firstMatch.group(2)!));

    var j = i + 1;
    while (j < lines.length) {
      final nextMatch = orderedLinePattern.firstMatch(lines[j]);
      if (nextMatch == null) {
        break;
      }
      numbers.add(int.parse(nextMatch.group(2)!));
      j++;
    }
    endExclusive = j;
    break;
  }

  if (startIndex < 0 || numbers.length < 3) {
    return text;
  }

  final firstNumber = numbers.first;
  if (firstNumber != 2) {
    return text;
  }

  for (var i = 1; i < numbers.length; i++) {
    if (numbers[i] != numbers[i - 1] + 1) {
      return text;
    }
  }

  for (var i = startIndex; i < endExclusive; i++) {
    final match = orderedLinePattern.firstMatch(lines[i]);
    if (match == null) {
      continue;
    }
    final number = int.parse(match.group(2)!);
    lines[i] =
        '${match.group(1)}${number - 1}${match.group(3)}${match.group(4)}';
  }

  return lines.join('\n');
}

String normalizeOduRawTextForDisplay(String input, {bool allowReindex = true}) {
  if (input.isEmpty) {
    return input;
  }

  var text = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  text = text
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'[ \t]+$'), ''))
      .join('\n');

  // Merge standalone "Ud." lines with the next non-empty line.
  // Example:
  //   Ud.
  //
  //   TIENE...
  // becomes:
  //   Ud TIENE...
  text = text.replaceAllMapped(
    RegExp(r'^\s*Ud\.\s*\n(?:\s*\n)*(\S.*)$', multiLine: true),
    (m) => 'Ud ${m.group(1)!}',
  );
  text = text.replaceAll(RegExp(r'Ud {2,}'), 'Ud ');

  // Repair hyphenated line wraps from scanned/exported text: "ESTOR-\nBA" -> "ESTORBA".
  text = text.replaceAllMapped(
    RegExp(r'([A-Za-zÁÉÍÓÚÑáéíóúñ])-\n([A-Za-zÁÉÍÓÚÑáéíóúñ])'),
    (m) => '${m.group(1)}${m.group(2)}',
  );

  // Normalize ".-" / ". -" list-like separators into paragraph boundaries.
  text = text.replaceAllMapped(RegExp(r'\.\s*-\s*'), (_) => '.\n');

  // Turn broken quote-colon separators into bullet boundaries.
  text = text.replaceAllMapped(
    RegExp(r'''(?:["“”']\s*\.?\s*:\s*)+'''),
    (_) => '\n• ',
  );
  text = text.replaceAll(RegExp(r'''(^|\n)\s*["“”']+\s*(?=•\s)'''), r'$1');

  // Remove embedded reference numbers between punctuation and next ordered item.
  // Example: "DINERO.156 14- " -> "DINERO.\n14- "
  text = text.replaceAllMapped(
    RegExp(r'\.(\s*)(\d{1,4})(\s+)(\d{1,3})\s*-\s+'),
    (m) => '.\n${m.group(4)}- ',
  );
  text = text.replaceAllMapped(
    RegExp(r'([:;])(\s*)(\d{1,4})(\s+)(\d{1,3})\s*-\s+'),
    (m) => '${m.group(1)}\n${m.group(5)}- ',
  );

  // Split inline list markers glued after punctuation: ".12-" -> ".\n12- ".
  text = text.replaceAllMapped(
    RegExp(r'([.!?])(\s*)(\d{1,3})\s*-\s+'),
    (m) => '${m.group(1)}\n${m.group(3)}- ',
  );
  text = text.replaceAllMapped(
    RegExp(r'([.!?])(\d{1,3})\s*-\s+'),
    (m) => '${m.group(1)}\n${m.group(2)}- ',
  );
  text = text.replaceAllMapped(
    RegExp(r'([):;])(\s*)(\d{1,3})\s*-\s+'),
    (m) => '${m.group(1)}\n${m.group(3)}- ',
  );
  text = text.replaceAllMapped(
    RegExp(r'([):;])(\d{1,3})\s*-\s+'),
    (m) => '${m.group(1)}\n${m.group(2)}- ',
  );

  // Remove glued reference digits after letters.
  // Examples:
  // "de162 la" -> "de la"
  // "DE162" -> "DE"
  text = text.replaceAllMapped(
    RegExp(r'([a-záéíóúüñ])(\d{2,4})(?=\s|[.,;:!?)]|$)', caseSensitive: false),
    (m) => m.group(1)!,
  );

  // Optional conservative cleanup when digits are glued before a letter.
  // Example: " 162la" -> " la"
  text = text.replaceAllMapped(
    RegExp(r'(^|\s)(\d{2,4})([a-záéíóúüñ])', caseSensitive: false),
    (m) => '${m.group(1)}${m.group(3)}',
  );

  // Normalize common enumeration tokens and force them onto new lines.
  text = text.replaceAllMapped(
    RegExp(r'(?<!^)(?<!\n)\s*(\d{1,2})\s*\.\s*-\s+'),
    (m) => '\n${m.group(1)}. ',
  );
  text = text.replaceAllMapped(
    RegExp(r'(?<!^)(?<!\n)\s*(\d{1,2})\s*\)\s+'),
    (m) => '\n${m.group(1)}. ',
  );
  text = text.replaceAllMapped(
    RegExp(r'(^|\n)\s*(\d{1,2})\s*\.\s*-\s*'),
    (m) => '${m.group(1)}${m.group(2)}. ',
  );
  text = text.replaceAllMapped(
    RegExp(r'(^|\n)\s*(\d{1,2})\s*\)\s*'),
    (m) => '${m.group(1)}${m.group(2)}. ',
  );

  // Normalize dangling "2-" markers and merge following bullet lines.
  final orderedListLines = text.split('\n');
  for (var i = 0; i < orderedListLines.length; i++) {
    final currentLine = orderedListLines[i];
    final sameLineMatch = RegExp(
      r'^\s*(\d{1,2})-\s*(.+)$',
    ).firstMatch(currentLine);
    if (sameLineMatch != null) {
      final number = sameLineMatch.group(1)!;
      var body = sameLineMatch.group(2)!.trim();
      body = body.replaceFirst(RegExp(r'^•\s*'), '');
      body = body.replaceAll(RegExp(r'\s+'), ' ').trim();
      orderedListLines[i] = body.isEmpty ? '$number.' : '$number. $body';
      continue;
    }

    final markerOnlyMatch = RegExp(
      r'^\s*(\d{1,2})-\s*$',
    ).firstMatch(currentLine);
    if (markerOnlyMatch == null) {
      continue;
    }

    var nextIndex = i + 1;
    while (nextIndex < orderedListLines.length &&
        orderedListLines[nextIndex].trim().isEmpty) {
      nextIndex++;
    }
    if (nextIndex >= orderedListLines.length) {
      continue;
    }

    final bulletMatch = RegExp(
      r'^\s*•\s*(.+)\s*$',
    ).firstMatch(orderedListLines[nextIndex]);
    if (bulletMatch == null) {
      continue;
    }

    final number = markerOnlyMatch.group(1)!;
    final mergedText = bulletMatch
        .group(1)!
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (mergedText.isEmpty) {
      continue;
    }

    orderedListLines[i] = '$number. $mergedText';
    orderedListLines[nextIndex] = '';
  }

  if (allowReindex) {
    // Reindex self-contained ordered lists that start above 1.
    // Conservative rules:
    // - at least 3 consecutive numeric lines
    // - first number > 1
    // - strictly sequential increments by 1
    final orderedDotLinePattern = RegExp(r'^(\s*)(\d{1,3})(\.\s+)(.+)$');
    var runStart = -1;
    var runNumbers = <int>[];

    void flushOrderedRun(int endExclusive) {
      if (runStart < 0) {
        runNumbers = <int>[];
        return;
      }
      final firstNumber = runNumbers.isEmpty ? 0 : runNumbers.first;
      final hasMinimumLength = runNumbers.length >= 3;
      var sequential = true;
      for (var i = 1; i < runNumbers.length; i++) {
        if (runNumbers[i] != runNumbers[i - 1] + 1) {
          sequential = false;
          break;
        }
      }
      if (hasMinimumLength && firstNumber > 1 && sequential) {
        final shift = firstNumber - 1;
        for (var lineIndex = runStart; lineIndex < endExclusive; lineIndex++) {
          final line = orderedListLines[lineIndex];
          final match = orderedDotLinePattern.firstMatch(line);
          if (match == null) {
            continue;
          }
          final number = int.tryParse(match.group(2) ?? '');
          if (number == null) {
            continue;
          }
          final reindexed = number - shift;
          orderedListLines[lineIndex] =
              '${match.group(1)}$reindexed${match.group(3)}${match.group(4)}';
        }
      }
      runStart = -1;
      runNumbers = <int>[];
    }

    for (var i = 0; i < orderedListLines.length; i++) {
      final line = orderedListLines[i];
      final match = orderedDotLinePattern.firstMatch(line);
      if (match == null) {
        flushOrderedRun(i);
        continue;
      }
      final number = int.tryParse(match.group(2) ?? '');
      if (number == null) {
        flushOrderedRun(i);
        continue;
      }
      if (runStart < 0) {
        runStart = i;
        runNumbers = <int>[number];
        continue;
      }
      runNumbers.add(number);
    }
    flushOrderedRun(orderedListLines.length);
  }

  text = orderedListLines.join('\n');

  // Split glued number markers from text when punctuation artifacts collapse.
  text = text.replaceAllMapped(
    RegExp(r'([a-záéíóúñàèìòùâêîôûãõçẹọṣńṅ])\.(\d{1,3})([A-ZÁÉÍÓÚÑ])'),
    (m) => '${m.group(1)}.\n${m.group(2)}\n${m.group(3)}',
  );
  text = text.replaceAllMapped(
    RegExp(r'([.!?:;])\s*(\d{1,3})([A-ZÁÉÍÓÚÑ])'),
    (m) => '${m.group(1)}\n${m.group(2)}\n${m.group(3)}',
  );

  bool isOrderedListLine(String line) {
    final trimmed = line.trim();
    return RegExp(r'^\d{1,2}(?:\.|\.\-|-\.)\s+').hasMatch(trimmed) ||
        RegExp(r'^\d{1,2}\)\s+').hasMatch(trimmed);
  }

  // Remove trailing reference-number artifacts (display only).
  final referenceNormalizedLines = text.split('\n');
  for (var i = 0; i < referenceNormalizedLines.length; i++) {
    final rawLine = referenceNormalizedLines[i];
    if (isOrderedListLine(rawLine)) {
      continue;
    }
    var normalizedLine = rawLine.replaceAllMapped(
      RegExp(r'''([.!?;:,\)\]\}"”'])\s*(\d{1,3})\s*$'''),
      (m) => m.group(1)!,
    );
    normalizedLine = normalizedLine.replaceAllMapped(
      RegExp(r'([.!?;:])\s*[-–—]\s*(\d{1,3})\s*$'),
      (m) => m.group(1)!,
    );
    referenceNormalizedLines[i] = normalizedLine;
  }

  final referenceStrippedLines = <String>[];
  for (var i = 0; i < referenceNormalizedLines.length; i++) {
    final current = referenceNormalizedLines[i];
    final trimmedCurrent = current.trim();
    final isNumericReferenceLine = RegExp(
      r'^\d{1,3}$',
    ).hasMatch(trimmedCurrent);
    if (!isNumericReferenceLine) {
      referenceStrippedLines.add(current);
      continue;
    }

    String? previousNonEmpty;
    for (var j = i - 1; j >= 0; j--) {
      final candidate = referenceNormalizedLines[j].trim();
      if (candidate.isNotEmpty) {
        previousNonEmpty = candidate;
        break;
      }
    }

    String? nextNonEmpty;
    for (var j = i + 1; j < referenceNormalizedLines.length; j++) {
      final candidate = referenceNormalizedLines[j].trim();
      if (candidate.isNotEmpty) {
        nextNonEmpty = candidate;
        break;
      }
    }

    final previousEndsSentence =
        previousNonEmpty != null &&
        RegExp(r'[.?!;:]$').hasMatch(previousNonEmpty);
    final nextLooksLikeOrderedList =
        nextNonEmpty != null &&
        (RegExp(r'^\d{1,2}(?:\.|\.\-|-\.)\s+').hasMatch(nextNonEmpty) ||
            RegExp(r'^\d{1,2}\)\s+').hasMatch(nextNonEmpty));

    if (previousEndsSentence && !nextLooksLikeOrderedList) {
      continue;
    }
    referenceStrippedLines.add(current);
  }

  text = referenceStrippedLines.join('\n');

  final output = <String>[];

  bool isPunctuationArtifact(String line) {
    final trimmed = line.trim();
    return RegExp(r'''^\s*["“”']\s*:\s*$''').hasMatch(trimmed) ||
        RegExp(r'''^\s*["“”']\s*$''').hasMatch(trimmed) ||
        RegExp(r'^\s*:\s*$').hasMatch(trimmed) ||
        RegExp(r'^\s*[-–—]\s*$').hasMatch(trimmed);
  }

  bool shouldJoinLines(String previous, String current) {
    final prev = previous.trimRight();
    final next = current.trimLeft();
    if (prev.isEmpty || next.isEmpty) {
      return false;
    }
    if (RegExp(r'[.!?:]$').hasMatch(prev)) {
      return false;
    }
    if (RegExp(r'^(•|\d+\.)\s').hasMatch(next)) {
      return false;
    }
    if (RegExp(r'^[A-ZÁÉÍÓÚÑ]{3,}').hasMatch(next)) {
      return false;
    }
    final lowerStart = RegExp(
      r'^[a-záéíóúüñàèìòùâêîôûãõçẹọṣńṅ]',
    ).hasMatch(next);
    final quotedLowerStart = RegExp(
      r'''^["“”']\s*[a-záéíóúüñàèìòùâêîôûãõçẹọṣńṅ]''',
    ).hasMatch(next);
    final continuationStart = RegExp(r'^[,;:)\]-]').hasMatch(next);
    return lowerStart || quotedLowerStart || continuationStart;
  }

  for (final rawLine in text.split('\n')) {
    var line = rawLine.trim();
    if (line.isEmpty) {
      if (output.isNotEmpty && output.last.isNotEmpty) {
        output.add('');
      }
      continue;
    }
    if (isPunctuationArtifact(line)) {
      continue;
    }

    line = line.replaceAll(RegExp(r'''^["“”']+\s*(?=•\s*)'''), '');
    line = line.replaceFirst(RegExp(r'''^•\s*["“”']+\s*'''), '• ');

    if (output.isNotEmpty &&
        output.last.isNotEmpty &&
        shouldJoinLines(output.last, line)) {
      final merged = '${output.last} $line'
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      output[output.length - 1] = merged;
      continue;
    }

    output.add(line);
  }

  while (output.isNotEmpty && output.last.isEmpty) {
    output.removeLast();
  }

  return output.join('\n');
}

// Debug-only manual check:
// if (kDebugMode) {
//   const sample = 'estructuración de162 la personalidad. DINERO.156 14- ...';
//   final normalized = normalizeOduRawTextForDisplay(sample);
//   debugPrint('[ODU][normalize sample] $normalized');
//   // Expected display: "estructuración de la personalidad. DINERO. 14- ..."
// }

bool _printedOkanaPrepareDisplayTrace = false;
const String _oduWordRegexFragment = r'od(?:ù|u|o)';
const String _descripcionWordRegexFragment = r'descripci(?:ó|o)n';

String removeStandaloneHeaderLine(String text) {
  if (text.trim().isEmpty) {
    return text;
  }
  final linePattern = RegExp(
    r'^en\s+este\s+'
    '$_oduWordRegexFragment'
    r'(\s+nace)?\s*[:\-–—]?\s*$',
    caseSensitive: false,
  );
  final lines = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');
  final filtered = lines.where((line) => !linePattern.hasMatch(line.trim()));
  return filtered.join('\n');
}

String removeDescripcionHeaderPrefixForDisplay(
  String text, {
  required String sectionKey,
}) {
  final normalizedSectionKey = sectionKey.trim().toLowerCase();
  if (text.trim().isEmpty ||
      (normalizedSectionKey != 'descripcion' &&
          normalizedSectionKey != 'description')) {
    return text;
  }

  final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final descriptionHeaderPattern = RegExp(
    r'''^\s*(?:\d{1,3}\s*[-.)]\s*)?["“”']?\s*'''
    '$_descripcionWordRegexFragment'
    r'''\s+del\s+'''
    '$_oduWordRegexFragment'
    r'''\b\s*:?\s*["“”']?\s*''',
    caseSensitive: false,
  );

  final lines = normalized.split('\n');
  final cleanedLines = <String>[];
  for (final line in lines) {
    final cleaned = line.replaceFirst(descriptionHeaderPattern, '');
    if (cleaned.trim().isEmpty) {
      continue;
    }
    cleanedLines.add(cleaned);
  }

  return cleanedLines.join('\n');
}

String mergeStandaloneNumberWithNextLine(String text) {
  if (text.trim().isEmpty) {
    return text;
  }

  final lines = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');
  final mergedLines = <String>[];
  final standaloneDotOrParen = RegExp(r'^\s*(\d{1,3})[.)]\s*$');
  final standaloneDash = RegExp(r'^\s*(\d{1,3})-\s*$');
  final anyStandaloneMarker = RegExp(r'^\s*\d{1,3}(?:[.)]|-)\s*$');

  var index = 0;
  while (index < lines.length) {
    final current = lines[index];
    final markerMatch =
        standaloneDotOrParen.firstMatch(current) ??
        standaloneDash.firstMatch(current);
    if (markerMatch == null) {
      mergedLines.add(current);
      index++;
      continue;
    }

    final markerNumber = markerMatch.group(1)!;
    var nextIndex = index + 1;
    var skippedBlanks = 0;
    while (nextIndex < lines.length &&
        lines[nextIndex].trim().isEmpty &&
        skippedBlanks < 2) {
      nextIndex++;
      skippedBlanks++;
    }

    if (nextIndex >= lines.length || lines[nextIndex].trim().isEmpty) {
      mergedLines.add(current);
      index++;
      continue;
    }

    final nextLine = lines[nextIndex];
    if (anyStandaloneMarker.hasMatch(nextLine) ||
        _isKnownSectionHeaderLine(nextLine)) {
      mergedLines.add(current);
      index++;
      continue;
    }

    final normalizedContent = nextLine
        .replaceFirst(RegExp(r'^\s*[•\-]\s+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalizedContent.isEmpty) {
      mergedLines.add(current);
      index++;
      continue;
    }

    mergedLines.add('$markerNumber. $normalizedContent');
    index = nextIndex + 1;
  }

  return mergedLines.join('\n');
}

String stripHighNumberedPointPrefixesInAquiBlocks(String text) {
  if (text.trim().isEmpty) {
    return text;
  }

  final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final lines = normalized.split('\n');
  final highPrefixLine = RegExp(r'^\s*(\d{2,3})\s*[-.)]\s+(.+)$');
  final standaloneHighPrefix = RegExp(r'^\s*\d{2,3}\s*[-.)]\s*$');
  final hasAqui = RegExp(r'AQU[ÍI]', caseSensitive: false).hasMatch(normalized);
  final highNumberedCount = lines.where(highPrefixLine.hasMatch).length;

  if (!hasAqui && highNumberedCount < 2) {
    return text;
  }

  final adjustedLines = <String>[];
  for (final line in lines) {
    final withTextMatch = highPrefixLine.firstMatch(line);
    if (withTextMatch != null) {
      final body = withTextMatch.group(2)!.trim();
      if (body.isNotEmpty) {
        adjustedLines.add('• $body');
      }
      continue;
    }
    if (standaloneHighPrefix.hasMatch(line)) {
      continue;
    }
    adjustedLines.add(line);
  }
  return adjustedLines.join('\n');
}

String removeStandaloneNoHayEspecificacionesSentence(String text) {
  if (text.trim().isEmpty) {
    return text;
  }

  final sentencePattern = RegExp(
    r'^\s*no\s+hay\s+especifica\w*\s*\.?\s*$',
    caseSensitive: false,
  );
  final lines = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');
  final cleanedLines = <String>[];

  for (final rawLine in lines) {
    if (rawLine.trim().isEmpty) {
      cleanedLines.add(rawLine);
      continue;
    }

    // Ensure sentence boundaries are splittable when source has glued text.
    final sentenceReady = rawLine.replaceAllMapped(
      RegExp(r'([.!?])(?=\S)'),
      (m) => '${m.group(1)} ',
    );
    final parts = sentenceReady.split(RegExp(r'(?<=[.!?])\s+'));
    final kept = parts
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty && !sentencePattern.hasMatch(part))
        .toList();

    if (kept.isEmpty) {
      continue;
    }
    cleanedLines.add(kept.join(' '));
  }

  return cleanedLines.join('\n');
}

bool _isKnownSectionHeaderLine(String line) {
  final folded = _foldDiacritics(line)
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[:\-–—]+$'), '')
      .replaceAll(RegExp(r'\s+'), ' ');
  if (folded.isEmpty) {
    return false;
  }

  final tolerantHeaderPattern = RegExp(
    r'^(?:en\s+este\s+'
    '$_oduWordRegexFragment'
    r'(?:\s+nace)?|'
    '$_descripcionWordRegexFragment'
    r'\s+del\s+'
    '$_oduWordRegexFragment'
    r')$',
    caseSensitive: false,
  );
  if (tolerantHeaderPattern.hasMatch(folded)) {
    return true;
  }

  const knownHeaders = <String>{
    'en este odu',
    'en este odo',
    'en este odu nace',
    'en este odo nace',
    'descripcion del odu',
    'descripcion del odo',
    'ewes del odu',
    'ewes del odo',
    'eshu del odu',
    'eshu del odo',
    'obras del odu',
    'obras del odo',
    'obras y ebbo',
    'dice ifa',
    'historias',
    'patakies',
    'historias/patakies',
    'rezo',
    'suyere',
    'traduccion',
    'traduccion de suyere',
    'rezos y suyeres',
    'refranes',
  };

  return knownHeaders.contains(folded);
}

String _foldDiacritics(String value) {
  return value
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('Á', 'A')
      .replaceAll('É', 'E')
      .replaceAll('Í', 'I')
      .replaceAll('Ó', 'O')
      .replaceAll('Ú', 'U')
      .replaceAll('ü', 'u')
      .replaceAll('Ü', 'U')
      .replaceAll('ñ', 'n')
      .replaceAll('Ñ', 'N')
      .replaceAll('ù', 'u')
      .replaceAll('Ù', 'U');
}

bool _looksLikeOkanaYabileTrace(String text) {
  final folded = _foldDiacritics(text).toUpperCase();
  return folded.contains('OKANA OJUANI') ||
      folded.contains('AQUI : EL AWO ES DESOBEDIENTE');
}

String formatListStyleForSection(String text, {required String sectionKey}) {
  if (text.trim().isEmpty) {
    return text;
  }
  const sectionsToBullet = <String>{'nace', 'eshu', 'dice_ifa', 'patakies'};
  final normalizedSection = sectionKey.trim().toLowerCase();
  if (!sectionsToBullet.contains(normalizedSection)) {
    return text;
  }

  final markerPattern = RegExp(r'^\s*\d{1,3}\s*(?:[-.)]\s+|\.\s+)');
  final lines = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');
  final adjusted = lines
      .map((line) => line.replaceFirst(markerPattern, '• '))
      .toList();
  return adjusted.join('\n');
}

String cleanupDescripcionNumericArtifactsForDisplay(
  String text, {
  required String sectionKey,
}) {
  final normalizedSectionKey = sectionKey.trim().toLowerCase();
  if ((normalizedSectionKey != 'descripcion' &&
          normalizedSectionKey != 'description') ||
      text.trim().isEmpty) {
    return text;
  }

  final normalized = text
      .replaceAll('\u00A0', ' ')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
  final cleanedLines = <String>[];
  final startNumberDotPattern = RegExp(r'^\s*\d{1,3}\.\s+');
  final startNumberParenPattern = RegExp(r'^\s*\d{1,3}\)\s+');
  final startNumberDashPattern = RegExp(r'^\s*\d{1,3}\-\s+');
  final looseNumberBeforeTextPattern = RegExp(
    r'(?<=\s)\d{1,3}\s+(?=[A-ZÁÉÍÓÚÜÑa-záéíóúüñ])',
  );
  final dotGluedNumberPattern = RegExp(r'\.(\d{1,3})\s+');
  final trailingNumberWithDotPattern = RegExp(r'\s+\d{1,3}\s*\.$');
  final trailingNumberPattern = RegExp(r'\s+\d{1,3}$');
  final joReferencePattern = RegExp(
    r'\(?\s*esta\s+informaci[óo]n\s+es\s+de\s+j\.?\s*o\.?\s*\)?\.?',
    caseSensitive: false,
  );
  final orderHeaderWithNumberPattern = RegExp(
    r'^\s*ESTE\s+(?:ES\s+)?(?:EL\s+)?OD(?:U|O|Ù)\s*#\s*(\d{1,3})\s+DEL\s+ORDEN\s+SEÑORIAL\s+DE\s+IF[ÁA]\.?\s*$',
    caseSensitive: false,
  );

  for (final rawLine in normalized.split('\n')) {
    var line = rawLine;
    final orderMatch = orderHeaderWithNumberPattern.firstMatch(line.trim());
    if (orderMatch != null) {
      final number = orderMatch.group(1)!;
      cleanedLines.add('ESTE ES EL ODU # $number DEL ORDEN SEÑORIAL DE IFÁ.');
      continue;
    }
    line = line.replaceFirst(startNumberDotPattern, '');
    line = line.replaceFirst(startNumberParenPattern, '');
    line = line.replaceFirst(startNumberDashPattern, '');
    line = line.replaceAll(looseNumberBeforeTextPattern, '');
    line = line.replaceAll(dotGluedNumberPattern, '. ');
    line = line.replaceAll(trailingNumberWithDotPattern, '');
    line = line.replaceAll(trailingNumberPattern, '');
    line = line.replaceAll(joReferencePattern, '');
    cleanedLines.add(line);
  }

  return cleanedLines.join('\n');
}

const Map<String, String> _descripcionOduNumberAliases = <String, String>{
  // Runtime content key variants vs canonical odu_data.dart names.
  'BABA OGBE': 'BABA EJIOGBE',
  'OGBE IKA': 'OGBE KA',
};

final Map<String, int> _oduNumberByNormalizedName = (() {
  final map = <String, int>{};
  for (var i = 0; i < oduEntries.length; i++) {
    final number = i + 1;
    final name = oduEntries[i].name;
    map[_normalizeOduNumberLookup(name)] = number;
  }
  for (final entry in _descripcionOduNumberAliases.entries) {
    final aliasKey = _normalizeOduNumberLookup(entry.key);
    final canonicalKey = _normalizeOduNumberLookup(entry.value);
    final number = map[canonicalKey];
    if (number != null) {
      map[aliasKey] = number;
    }
  }
  return map;
})();

String _normalizeOduNumberLookup(String value) => _foldDiacritics(value)
    .toUpperCase()
    .replaceAll('_', ' ')
    .replaceAll(RegExp(r'[^A-Z0-9 ]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String normalizeDescripcionOduHeaderNumberForDisplay(
  String text, {
  required String oduName,
}) {
  if (text.trim().isEmpty || oduName.trim().isEmpty) {
    return text;
  }
  final normalizedName = _normalizeOduNumberLookup(oduName);
  final number = _oduNumberByNormalizedName[normalizedName];
  if (number == null) {
    return text;
  }

  final headerPattern = RegExp(
    r'^\s*ESTE\s+(?:ES\s+)?(?:EL\s+)?ODU\s*#\s*\d*',
    multiLine: true,
    caseSensitive: false,
  );
  if (!headerPattern.hasMatch(text)) {
    return text;
  }
  return text.replaceFirst(headerPattern, 'ESTE ES EL ODU # $number');
}

bool _isDescripcionItemLikeLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) {
    return false;
  }
  return RegExp(
    r'^(?:[•\-\*]\s+|\d{1,3}\s*(?:\.\-|[.\)\-])\s+)',
  ).hasMatch(trimmed);
}

bool isDescripcionListLike(String text) {
  final lines = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  if (lines.length < 6) {
    return false;
  }
  final itemLikeCount = lines.where(_isDescripcionItemLikeLine).length;
  return (itemLikeCount / lines.length) >= 0.7;
}

String formatDescripcionAsBulletsIfListLike(String text) {
  if (!isDescripcionListLike(text)) {
    return text;
  }

  final markerPattern = RegExp(
    r'^\s*(?:[•\-\*]\s+|\d{1,3}\s*(?:\.\-|[.\)\-])\s+)',
  );
  final bulletNumberOnlyPattern = RegExp(r'^\s*•\s*\d{1,3}\.?\s*$');
  final numberOnlyPattern = RegExp(r'^\s*\d{1,3}\.?\s*$');
  final lines = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');
  final out = <String>[];

  for (final rawLine in lines) {
    final trimmed = rawLine.trim();
    if (trimmed.isEmpty) {
      if (out.isNotEmpty && out.last.isNotEmpty) {
        out.add('');
      }
      continue;
    }

    if (_isDescripcionItemLikeLine(trimmed)) {
      final item = trimmed.replaceFirst(markerPattern, '').trim();
      if (item.isEmpty ||
          numberOnlyPattern.hasMatch(item) ||
          bulletNumberOnlyPattern.hasMatch('• $item')) {
        continue;
      }
      if (item.length > 180) {
        out.add(item);
      } else {
        out.add('• $item');
      }
      continue;
    }

    out.add(trimmed);
  }

  while (out.isNotEmpty && out.last.isEmpty) {
    out.removeLast();
  }
  return out.join('\n');
}

String formatEwesAsBulletsForDisplay(String text) {
  // Debug-only example (display layer):
  // Input:  "hierbas: sargazo, espanta muerto, jobo, algarrobo"
  // Output:
  // "• sargazo
  //  • espanta muerto
  //  • jobo
  //  • algarrobo"
  // Input:  "Mangle rojo palo bobo mano pilón ... piñón de rosa ..."
  // Output includes grouped compounds such as:
  // "• Mangle rojo", "• palo bobo", "• mano pilón", "• piñón de rosa"
  if (text.trim().isEmpty) {
    return text;
  }

  String capitalizeFirst(String s) {
    final t = s.trim();
    if (t.isEmpty) return t;
    return t[0].toUpperCase() + t.substring(1);
  }

  String toBulletedItem(String item) {
    final trimmed = item.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final withoutBullet = trimmed.startsWith('•')
        ? trimmed.substring(1).trimLeft()
        : trimmed;
    return '• ${capitalizeFirst(withoutBullet)}';
  }

  final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final precleanedLines = normalized.split('\n').map((line) {
    var cleanedLine = line.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
    cleanedLine = cleanedLine.replaceAll(RegExp(r'\s*,\s*'), ', ');
    return cleanedLine;
  }).toList();
  final precleanedText = precleanedLines.join('\n').trim();

  final commaCount = RegExp(r',').allMatches(precleanedText).length;
  final startsWithHierbaLabel = RegExp(
    r'^\s*hierbas?\s*:',
    caseSensitive: false,
  ).hasMatch(precleanedText);
  final commaBasedCandidate = startsWithHierbaLabel || commaCount >= 6;
  if (commaBasedCandidate) {
    final splitSource = precleanedText.replaceAll('\n', ' ');
    final tokens = splitSource.split(RegExp(r'\s*,\s*'));
    final items = <String>[];
    for (var i = 0; i < tokens.length; i++) {
      var token = tokens[i].trim();
      if (i == 0) {
        token = token.replaceFirst(
          RegExp(r'^hierbas?\s*:\s*', caseSensitive: false),
          '',
        );
      }
      token = token.replaceFirst(RegExp(r'\.+$'), '').trim();
      if (token.length < 2) {
        continue;
      }
      items.add(token);
    }

    if (items.length >= 4) {
      return items
          .map(toBulletedItem)
          .where((item) => item.isNotEmpty)
          .join('\n');
    }
  }

  // Space-dense herb-list detection for entries without commas.
  if (commaCount == 0) {
    final spaceSource = precleanedText
        .replaceFirst(RegExp(r'^\s*hierbas?\s*:\s*', caseSensitive: false), '')
        .trim();
    final words = spaceSource
        .split(RegExp(r'\s+'))
        .map(
          (word) => word
              .replaceFirst(RegExp(r'^[;:!?.(),]+'), '')
              .replaceFirst(RegExp(r'[;:!?.(),]+$'), '')
              .trim(),
        )
        .where((word) => word.isNotEmpty)
        .toList();
    final wordCount = words.length;
    if (wordCount == 0) {
      return text;
    }

    final hasSentencePunctuation = RegExp(r'[.!?:]').hasMatch(spaceSource);
    final totalWordLength = words.fold<int>(
      0,
      (sum, word) => sum + word.length,
    );
    final averageWordLength = totalWordLength / wordCount;
    final spaceDenseCandidate =
        !hasSentencePunctuation && wordCount >= 12 && averageWordLength <= 10;

    if (!spaceDenseCandidate) {
      return text;
    }

    String normalizeForPhraseMatch(String value) {
      return _foldDiacritics(
        value,
      ).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
    }

    const trigramPhrases = <String>{'pinon de rosa'};
    const bigramPhrases = <String>{
      'mangle rojo',
      'palo bobo',
      'mano pilon',
      'orquidea ayua',
      'bejuco bi',
      'rosa cimarrona',
      'bledo blanco',
    };

    final normalizedWords = words.map(normalizeForPhraseMatch).toList();
    final items = <String>[];

    var i = 0;
    while (i < words.length) {
      var consumed = 1;

      if (i + 2 < words.length) {
        final tri =
            '${normalizedWords[i]} ${normalizedWords[i + 1]} ${normalizedWords[i + 2]}';
        if (trigramPhrases.contains(tri)) {
          consumed = 3;
        }
      }

      if (consumed == 1 && i + 1 < words.length) {
        final bi = '${normalizedWords[i]} ${normalizedWords[i + 1]}';
        if (bigramPhrases.contains(bi)) {
          consumed = 2;
        }
      }

      final item = words.sublist(i, i + consumed).join(' ').trim();
      if (item.isNotEmpty) {
        items.add(item);
      }
      i += consumed;
    }

    if (items.length >= 4) {
      return items
          .map(toBulletedItem)
          .where((item) => item.isNotEmpty)
          .join('\n');
    }
  }

  return text;
}

String prepareDisplayText(
  String raw, {
  bool allowReindex = true,
  String sectionKey = 'otros',
}) {
  var cleaned = normalizeOduRawTextForDisplay(raw, allowReindex: allowReindex);
  cleaned = cleaned.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  // Merge standalone "Aquí:" lines with the next non-empty line globally.
  // Applies to standalone AQUI/AQUÍ lines (optionally prefixed by marker/bullet).
  final standaloneAquiPattern = RegExp(
    r'''^(\s*(?:[•\-]\s*|\d{1,3}\s*[.)-]\s*)?)["“”']?\s*AQU[IÍ]\s*:\s*["“”']?\s*\n(?:\s*\n)*(\S.*)$''',
    multiLine: true,
    caseSensitive: false,
  );
  while (true) {
    final mergedAqui = cleaned.replaceAllMapped(standaloneAquiPattern, (m) {
      final prefix = (m.group(1) ?? '').trimRight();
      final content = m.group(2)!;
      final prefixOut = prefix.isEmpty ? '' : '$prefix ';
      return '${prefixOut}Aquí: $content';
    });
    if (mergedAqui == cleaned) {
      break;
    }
    cleaned = mergedAqui;
  }

  final noHeader = removeStandaloneHeaderLine(cleaned);
  final noDescripcionHeader = removeDescripcionHeaderPrefixForDisplay(
    noHeader,
    sectionKey: sectionKey,
  );
  final cased = normalizeCaseForDisplay(noDescripcionHeader);
  final normalizedSectionKey = sectionKey.trim().toLowerCase().replaceAll(
    RegExp(r'[^a-z]'),
    '',
  );
  final cleanedDescripcionNumbers =
      cleanupDescripcionNumericArtifactsForDisplay(
        cased,
        sectionKey: sectionKey,
      );
  final isDescripcionSection =
      normalizedSectionKey == 'descripcion' ||
      normalizedSectionKey == 'description';
  var finalText = cleanedDescripcionNumbers;
  if (isDescripcionSection) {
    // Descripción: default render is paragraph mode; bullets only when clearly list-like.
    finalText = formatDescripcionAsBulletsIfListLike(cleanedDescripcionNumbers);
  } else {
    final merged = mergeStandaloneNumberWithNextLine(cleanedDescripcionNumbers);
    final strippedAqui = stripHighNumberedPointPrefixesInAquiBlocks(merged);
    final noSpecLine = removeStandaloneNoHayEspecificacionesSentence(
      strippedAqui,
    );
    finalText = formatListStyleForSection(noSpecLine, sectionKey: sectionKey);
    if (normalizedSectionKey == 'ewes' ||
        normalizedSectionKey == 'ewesyoruba') {
      finalText = formatEwesAsBulletsForDisplay(finalText);
    }
  }
  if (kDebugMode &&
      !_printedOkanaPrepareDisplayTrace &&
      _looksLikeOkanaYabileTrace(finalText)) {
    final previewLines = finalText.split('\n').take(25).join('\n');
    debugPrint(
      '[ODU][prepareDisplayText][OKANA YABILE] first 25 lines:\n$previewLines',
    );
    _printedOkanaPrepareDisplayTrace = true;
  }
  return finalText;
}

Widget buildCurrentSectionIndicator(
  BuildContext context,
  String? title, {
  required bool isSpanish,
}) {
  if (title == null || title.trim().isEmpty) {
    return const SizedBox.shrink();
  }
  final prefix = isSpanish ? 'Sección: ' : 'Section: ';
  final cs = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.bookmark_outline,
            size: 16,
            color: cs.onSurface.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$prefix$title',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                color: cs.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _OduSection extends StatelessWidget {
  const _OduSection({
    required this.title,
    required this.body,
    this.subtitle,
    this.language,
    this.strings,
  });

  final String title;
  final String body;
  final String? subtitle;
  final AppLanguage? language;
  final AppStrings? strings;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bodyStyle =
        textTheme.bodyLarge?.copyWith(height: 1.55) ??
        textTheme.bodyMedium?.copyWith(height: 1.55);
    final displayBody = body.isEmpty ? '-' : body;
    final displaySubtitle = subtitle == null
        ? null
        : prepareDisplayText(subtitle!.isEmpty ? '-' : subtitle!);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          _buildFormattedBody(displayBody, bodyStyle),
          if (displaySubtitle != null && _hasOduText(displaySubtitle)) ...[
            const SizedBox(height: 16),
            Text(
              'Traducción',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            _buildFormattedBody(displaySubtitle, bodyStyle),
          ],
        ],
      ),
    );
  }
}

class _FormattedBody extends StatelessWidget {
  const _FormattedBody({required this.text, required this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed == '-') {
      return Text('-', style: style);
    }
    final spans = _buildFormattedSpans(text, style);
    return Text.rich(TextSpan(children: spans), style: style);
  }
}

List<InlineSpan> _buildFormattedSpans(String text, TextStyle? style) {
  final lines = text.split('\n');
  final spans = <InlineSpan>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.isNotEmpty) {
      spans.add(_buildFormattedHeaderSpan(line, style));
    }
    if (i != lines.length - 1) {
      spans.add(const TextSpan(text: '\n'));
    }
  }
  return spans;
}

TextSpan _buildFormattedHeaderSpan(String line, TextStyle? style) {
  final match = RegExp(r'^([^:]{2,80}):\s*(.*)$').firstMatch(line);
  if (match == null) {
    return TextSpan(text: line, style: style);
  }
  final header = match.group(1)!.trim();
  if (!_looksLikeHeader(header)) {
    return TextSpan(text: line, style: style);
  }
  final rest = (match.group(2) ?? '').trim();
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

bool _looksLikeHeader(String header) {
  final trimmed = header.trim();
  if (trimmed.isEmpty) {
    return false;
  }
  if (trimmed.length > 80) {
    return false;
  }
  if (trimmed.contains('.') || trimmed.contains('?') || trimmed.contains('!')) {
    return false;
  }
  final hasLetter = RegExp(r'[A-Za-zÁÉÍÓÚÑáéíóúñ]').hasMatch(trimmed);
  if (!hasLetter) {
    return false;
  }
  final wordCount = trimmed.split(RegExp(r'\s+')).length;
  return wordCount <= 16;
}

class _TranslatedBody extends StatefulWidget {
  const _TranslatedBody({
    required this.text,
    required this.style,
    required this.language,
    required this.strings,
    required this.active,
    required this.translate,
    this.useReadableParagraphs = false,
    this.normalizeSpanishCase = false,
    this.allowReindex = true,
    this.shiftLeadingOrderedSequenceFromTwo = false,
    this.sectionKey = 'otros',
    this.duplicateLineToRemoveAfterPrepare,
  });

  final String text;
  final TextStyle? style;
  final AppLanguage language;
  final AppStrings strings;
  final bool active;
  final bool translate;
  final bool useReadableParagraphs;
  final bool normalizeSpanishCase;
  final bool allowReindex;
  final bool shiftLeadingOrderedSequenceFromTwo;
  final String sectionKey;
  final String? duplicateLineToRemoveAfterPrepare;

  @override
  State<_TranslatedBody> createState() => _TranslatedBodyState();
}

class _TranslatedBodyState extends State<_TranslatedBody> {
  Future<String>? _future;
  bool _loadingCache = false;

  Widget _renderBody(String text) {
    var displayText = prepareDisplayText(
      text,
      allowReindex: widget.allowReindex,
      sectionKey: widget.sectionKey,
    );
    final duplicateLine = widget.duplicateLineToRemoveAfterPrepare;
    if (duplicateLine != null && duplicateLine.trim().isNotEmpty) {
      displayText = _removeDuplicatedEshuHeaderLineFromNace(
        preparedNaceText: displayText,
        eshuHeaderLine: duplicateLine,
      );
    }
    if (widget.shiftLeadingOrderedSequenceFromTwo) {
      displayText = _shiftLeadingOrderedSequenceFromTwoToOne(displayText);
    }
    if (widget.useReadableParagraphs) {
      final baseStyle = widget.style ?? Theme.of(context).textTheme.bodyLarge;
      final paragraphStyle = (baseStyle ?? const TextStyle()).copyWith(
        height: 1.55,
      );
      return ReadableParagraphs(
        text: displayText,
        style: paragraphStyle,
        textIsPrepared: true,
        sectionKey: widget.sectionKey,
      );
    }
    return _buildFormattedBody(displayText, widget.style, textIsPrepared: true);
  }

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
      return _renderBody('-');
    }
    if (!widget.translate || widget.language == AppLanguage.es) {
      return _renderBody(widget.text);
    }
    if (!TranslationService.instance.isEnabled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _renderBody(widget.text),
          const SizedBox(height: 6),
          Text(
            widget.strings.traduccionNoConfig,
            style: widget.style?.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      );
    }
    if (!widget.active) {
      return _renderBody(widget.text);
    }
    final cached = TranslationService.instance.cachedTranslate(widget.text);
    if (cached != null && cached.trim().isNotEmpty) {
      return _renderBody(cached);
    }
    if (!_loadingCache) {
      _loadingCache = true;
      TranslationService.instance.cachedTranslateAsync(widget.text).then((
        value,
      ) {
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
          return _renderBody(widget.text);
        }
        final value = snapshot.data?.trim().isNotEmpty == true
            ? snapshot.data!
            : widget.text;
        return _renderBody(value);
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

Widget _buildFormattedBody(
  String body,
  TextStyle? style, {
  bool textIsPrepared = false,
  bool allowReindex = true,
}) {
  final cleaned = textIsPrepared
      ? body
      : prepareDisplayText(body, allowReindex: allowReindex);
  final normalized = cleaned.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (normalized.trim().isEmpty) {
    return Text('-', style: style);
  }

  const imageTokenMap = <String, String>{
    '[[ATENA]]': 'assets/odu_signs/ATENA.png',
    '[[ATENA_BABA_EJIOGBE]]': 'assets/odu_signs/ATENA_BABA_EJIOGBE.png',
    '[[ATENA_ODI_MEYI]]': 'assets/odu_signs/ATENA_ODI_MEYI.png',
  };

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

  final items = <Widget>[];
  var lastWasSpacer = false;
  final lines = normalized.split('\n');

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      if (items.isNotEmpty && !lastWasSpacer) {
        items.add(const SizedBox(height: 12));
        lastWasSpacer = true;
      }
      continue;
    }

    if (items.isNotEmpty && !lastWasSpacer) {
      items.add(const SizedBox(height: 12));
    }

    final imagePath = imageTokenMap[line];
    if (imagePath != null) {
      items.add(Image.asset(imagePath, fit: BoxFit.contain));
    } else {
      items.add(Text.rich(buildSpan(line), style: style));
    }
    lastWasSpacer = false;
  }

  while (items.isNotEmpty && items.last is SizedBox) {
    items.removeLast();
  }

  if (items.isEmpty) {
    return Text('-', style: style);
  }

  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: items);
}

class ReadableParagraphs extends StatelessWidget {
  const ReadableParagraphs({
    super.key,
    required this.text,
    required this.style,
    this.textIsPrepared = false,
    this.allowReindex = true,
    this.sectionKey = 'otros',
  });

  final String text;
  final TextStyle style;
  final bool textIsPrepared;
  final bool allowReindex;
  final String sectionKey;

  @override
  Widget build(BuildContext context) {
    final display = textIsPrepared
        ? text
        : prepareDisplayText(
            text,
            allowReindex: allowReindex,
            sectionKey: sectionKey,
          );
    final chunks = _splitReadableChunks(display);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < chunks.length; i++) ...[
          Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
            child: Text(
              chunks[i],
              textAlign: TextAlign.start,
              style: style.copyWith(height: 1.55),
            ),
          ),
          if (i != chunks.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

List<String> _splitReadableChunks(String text) {
  final normalized = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .trim();
  if (normalized.isEmpty || normalized == '-') {
    return const ['-'];
  }

  final boundaryPrepared = normalized.replaceAllMapped(
    RegExp(r'(\."\s*:|"\.\s*:|"\s*:|";\s*|\s:\s)'),
    (match) => '${match.group(0)!}\n',
  );

  // Re-merge standalone "Aquí:" headers that can be split by the generic " : " boundary rule.
  var aquiMerged = boundaryPrepared;
  final chunkAquiPattern = RegExp(
    r'''^(\s*(?:[•\-]\s*|\d{1,3}\s*[.)-]\s*)?)["“”']?\s*AQU[IÍ]\s*:\s*["“”']?\s*\n(?:\s*\n)*(\S.*)$''',
    multiLine: true,
    caseSensitive: false,
  );
  while (true) {
    final next = aquiMerged.replaceAllMapped(chunkAquiPattern, (m) {
      final prefix = (m.group(1) ?? '').trimRight();
      final content = m.group(2)!;
      final prefixOut = prefix.isEmpty ? '' : '$prefix ';
      return '${prefixOut}Aquí: $content';
    });
    if (next == aquiMerged) {
      break;
    }
    aquiMerged = next;
  }

  // Protect "Ud." so sentence splitting does not isolate it as a standalone chunk.
  final protectedAbbreviations = aquiMerged.replaceAllMapped(
    RegExp(r'\bUd\.(?=\s+[A-Za-zÁÉÍÓÚÑáéíóúñ])'),
    (_) => 'Ud§',
  );

  final parts = protectedAbbreviations.split(
    RegExp(r'\n\n+|\n|(?<=\.\")\s+|(?<=\.)\s+|(?<=;)\s+'),
  );

  final chunks = parts
      .map((part) => part.replaceAll('Ud§', 'Ud.').trim())
      .where((part) => part.isNotEmpty)
      .toList();

  final merged = <String>[];
  final standaloneMarkerPattern = RegExp(r'^\s*\d{1,3}(?:\.|\))\s*$');

  var i = 0;
  while (i < chunks.length) {
    final current = chunks[i];
    if (standaloneMarkerPattern.hasMatch(current) && i + 1 < chunks.length) {
      final marker = current.trim();
      final next = chunks[i + 1]
          .replaceFirst(RegExp(r'^\s*[•\-]\s+'), '')
          .trim();
      if (next.isNotEmpty) {
        merged.add('$marker $next');
        i += 2;
        continue;
      }
    }
    merged.add(current);
    i++;
  }

  return merged;
}

String normalizeCaseForDisplay(String s) {
  final trimmed = s.trim();
  if (isMostlyUppercase(trimmed)) {
    return _toSentenceCase(trimmed);
  }
  return s;
}

bool isMostlyUppercase(String text) {
  final letters = RegExp(r'[A-Za-zÁÉÍÓÚÜÑÀÈÌÒÙÂÊÎÔÛÃÕÇẸỌṢŃṄ]');
  final matches = letters.allMatches(text);
  if (matches.isEmpty) return false;

  var uppercaseCount = 0;
  for (final m in matches) {
    final char = m.group(0)!;
    if (char == char.toUpperCase()) {
      uppercaseCount++;
    }
  }

  return uppercaseCount / matches.length > 0.8;
}

String _toSentenceCase(String text) {
  final normalized = text.toLowerCase();
  final buffer = StringBuffer();
  var capitalizeNext = true;
  final letterPattern = RegExp(r'[a-záéíóúüñàèìòùâêîôûãõçẹọṣńṅ]');
  for (var i = 0; i < normalized.length; i++) {
    final char = normalized[i];
    if (capitalizeNext && letterPattern.hasMatch(char)) {
      buffer.write(char.toUpperCase());
      capitalizeNext = false;
      continue;
    }
    buffer.write(char);
    if (char == '.' || char == '!' || char == '?') {
      capitalizeNext = true;
    }
  }
  return buffer.toString();
}

String _toDisplayTitleCase(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return text;
  }
  return trimmed
      .split(RegExp(r'\s+'))
      .map((word) {
        return word
            .split('-')
            .map((part) {
              if (part.isEmpty) {
                return part;
              }
              final lower = part.toLowerCase();
              return '${lower[0].toUpperCase()}${lower.substring(1)}';
            })
            .join('-');
      })
      .join(' ');
}

class _OduExpandableSection extends StatefulWidget {
  const _OduExpandableSection({
    required this.title,
    required this.body,
    required this.language,
    required this.strings,
    this.requiresMembership = false,
    this.membershipActive = false,
    this.allowReindex = true,
    this.shiftLeadingOrderedSequenceFromTwo = false,
    this.sectionKey = 'otros',
    this.duplicateLineToRemoveAfterPrepare,
    this.onExpansionChanged,
  });

  final String title;
  final String body;
  final AppLanguage language;
  final AppStrings strings;
  final bool requiresMembership;
  final bool membershipActive;
  final bool allowReindex;
  final bool shiftLeadingOrderedSequenceFromTwo;
  final String sectionKey;
  final String? duplicateLineToRemoveAfterPrepare;
  final ValueChanged<bool>? onExpansionChanged;

  @override
  State<_OduExpandableSection> createState() => _OduExpandableSectionState();
}

class _OduExpandableSectionState extends State<_OduExpandableSection> {
  bool _expanded = false;

  Widget _buildExpandedBody(TextStyle? bodyStyle) {
    return _TranslatedBody(
      text: widget.body,
      style: bodyStyle,
      language: widget.language,
      strings: widget.strings,
      active: _expanded,
      translate: true,
      useReadableParagraphs: true,
      normalizeSpanishCase: true,
      allowReindex: widget.allowReindex,
      shiftLeadingOrderedSequenceFromTwo:
          widget.shiftLeadingOrderedSequenceFromTwo,
      sectionKey: widget.sectionKey,
      duplicateLineToRemoveAfterPrepare:
          widget.duplicateLineToRemoveAfterPrepare,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bodyStyle =
        textTheme.bodyLarge?.copyWith(height: 1.55) ??
        textTheme.bodyMedium?.copyWith(height: 1.55);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: ExpansionTile(
          onExpansionChanged: (value) {
            if (_expanded == value) {
              return;
            }
            setState(() => _expanded = value);
            widget.onExpansionChanged?.call(value);
          },
          title: Text(
            widget.title,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SelectionArea(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!widget.requiresMembership)
                          _buildExpandedBody(bodyStyle)
                        else
                          (widget.membershipActive
                              ? _buildExpandedBody(bodyStyle)
                              : _PremiumMembershipCallout(
                                  strings: widget.strings,
                                )),
                      ],
                    ),
                  ),
                ),
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
    required this.fallback,
    required this.patakies,
    required this.patakiesContent,
    required this.membershipActive,
    this.onExpansionChanged,
  });

  final AppStrings strings;
  final String fallback;
  final List<String> patakies;
  final Map<String, String> patakiesContent;
  final bool membershipActive;
  final ValueChanged<bool>? onExpansionChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bodyStyle =
        textTheme.bodyLarge?.copyWith(height: 1.55) ??
        textTheme.bodyMedium?.copyWith(height: 1.55);

    final hasList = patakies.isNotEmpty;
    final contentText = fallback.isNotEmpty
        ? fallback
        : strings.contenidoPendiente;
    final displayTitle = prepareDisplayText(strings.historiasPatakies);
    final displayFallback = prepareDisplayText(
      contentText,
      sectionKey: 'patakies',
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: ExpansionTile(
          onExpansionChanged: onExpansionChanged,
          title: Text(
            displayTitle,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          children: !membershipActive
              ? [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _PremiumMembershipCallout(strings: strings),
                  ),
                ]
              : hasList
              ? [
                  ...patakies.map((item) {
                    final content = patakiesContent[item] ?? '';
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: SelectionArea(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: ListTile(
                              title: _TranslatedText(
                                text: prepareDisplayText(item),
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
                                      membershipActive: membershipActive,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                ]
              : [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SelectionArea(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: ReadableParagraphs(
                            text: displayFallback,
                            style: bodyStyle ?? const TextStyle(),
                            textIsPrepared: true,
                            sectionKey: 'patakies',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
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
    required this.membershipActive,
  });

  final String title;
  final String content;
  final bool membershipActive;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, language, _) {
        final strings = AppStrings(language);
        final textStyle = Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(height: 1.4);
        final resolvedContent = content.trim().isEmpty
            ? ''
            : prepareDisplayText(content, sectionKey: 'patakies');
        final sections = _splitPatakiSections(resolvedContent);
        final patakiText = sections.pataki.join(' ').trim();
        final traduccionText = sections.traduccion.join(' ').trim();
        final ensenanzasText = sections.ensenanzas.join(' ').trim();
        final patakiDisplay = prepareDisplayText(
          patakiText,
          sectionKey: 'patakies',
        );
        final traduccionDisplay = prepareDisplayText(
          traduccionText,
          sectionKey: 'patakies',
        );
        final ensenanzasDisplay = prepareDisplayText(
          ensenanzasText,
          sectionKey: 'patakies',
        );
        final titleFuture = strings.language == AppLanguage.en
            ? TranslationService.instance.translate(title)
            : null;
        Widget buildTitle(TextStyle? style) {
          final titleDisplay = prepareDisplayText(title);
          if (titleFuture == null) {
            return Text(titleDisplay, style: style);
          }
          return FutureBuilder<String>(
            future: titleFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Text(titleDisplay, style: style);
              }
              final value = snapshot.data?.trim().isNotEmpty == true
                  ? snapshot.data!
                  : titleDisplay;
              return Text(prepareDisplayText(value), style: style);
            },
          );
        }

        Widget buildReadableBody(String text) {
          return SelectionArea(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: _TranslatedPatakiBody(
                  text: text,
                  textStyle: textStyle,
                  language: strings.language,
                  strings: strings,
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: buildTitle(null),
            actions: [
              IconButton(
                tooltip: 'Home',
                onPressed: () {
                  _homeKey.currentState?.goOduExternal();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                icon: const Icon(Icons.home),
              ),
            ],
            bottom: const _LanguageTabBar(),
          ),
          body: !membershipActive
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    buildTitle(
                      Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PremiumMembershipCallout(strings: strings),
                  ],
                )
              : ListView(
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
                      buildReadableBody(patakiDisplay),
                      if (sections.traduccion.isNotEmpty)
                        const SizedBox(height: 16),
                    ],
                    if (sections.traduccion.isNotEmpty) ...[
                      _PatakiSectionHeader(text: '${strings.traduccionLabel}:'),
                      const SizedBox(height: 8),
                      buildReadableBody(traduccionDisplay),
                      if (sections.ensenanzas.isNotEmpty)
                        const SizedBox(height: 16),
                    ],
                    if (sections.ensenanzas.isNotEmpty) ...[
                      _PatakiSectionHeader(text: '${strings.ensenanzasLabel}:'),
                      const SizedBox(height: 8),
                      buildReadableBody(ensenanzasDisplay),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class _PremiumMembershipCallout extends StatelessWidget {
  const _PremiumMembershipCallout({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final isEs = strings.language == AppLanguage.es;
    final title = isEs ? '🔒 Contenido premium' : '🔒 Premium content';
    final body = isEs
        ? 'Este contenido forma parte de la membresía anual.'
        : 'This content is part of the annual membership.';
    final action = isEs ? 'Ver membresía' : 'View membership';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(height: 1.55),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MembershipScreen(),
                      ),
                    );
                  },
                  child: Text(action),
                ),
              ],
            ),
          ),
        ),
      ),
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
  normalized = normalized.replaceFirst(
    RegExp(r'^PATAKI:\\s*', caseSensitive: false),
    '',
  );
  final parts = normalized.split(
    RegExp(r'ENSENANZAS:|ENSEÑANZAS:', caseSensitive: false),
  );
  final beforeEnsenanzas = parts.isNotEmpty ? parts[0].trim() : '';
  final ensenanzas = parts.length > 1
      ? _splitIntoParagraphs(parts[1].trim())
      : <String>[];

  final tradParts = beforeEnsenanzas.split(
    RegExp(r'TRADUCCION:|TRADUCCIÓN:', caseSensitive: false),
  );
  final pataki = _splitIntoParagraphs(
    tradParts.isNotEmpty ? tradParts[0].trim() : '',
  );
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
      RegExp(r'\\b\\d+\\.\\s').hasMatch(normalized) ||
      normalized.startsWith('1.');
  if (numbered) {
    final parts = normalized.split(RegExp(r'(?<=\\.)\\s+(?=\\d+\\.)'));
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

  Widget _renderBody(String text) {
    final raw = text.trim().isEmpty ? '-' : text;
    final display = prepareDisplayText(raw, sectionKey: 'patakies');
    final style = (widget.textStyle ?? const TextStyle()).copyWith(
      height: 1.55,
    );
    return ReadableParagraphs(
      text: display,
      style: style,
      textIsPrepared: true,
      sectionKey: 'patakies',
    );
  }

  @override
  void didUpdateWidget(covariant _TranslatedPatakiBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.language == AppLanguage.es) {
      _future = null;
      return;
    }
    _future ??= TranslationService.instance.translate(widget.text);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.trim().isEmpty || widget.text.trim() == '-') {
      return _renderBody('-');
    }
    if (widget.language == AppLanguage.es) {
      return _renderBody(widget.text);
    }
    if (!TranslationService.instance.isEnabled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _renderBody(widget.text),
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
      return _renderBody(cached);
    }
    if (!_loadingCache) {
      _loadingCache = true;
      TranslationService.instance.cachedTranslateAsync(widget.text).then((
        value,
      ) {
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
          return _renderBody(widget.text);
        }
        final value = snapshot.data?.trim().isNotEmpty == true
            ? snapshot.data!
            : widget.text;
        return _renderBody(value);
      },
    );
  }
}

class _PatakiSectionHeader extends StatelessWidget {
  const _PatakiSectionHeader({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final displayText = prepareDisplayText(text);
    return Text(
      displayText,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.bold,
        decoration: TextDecoration.underline,
      ),
    );
  }
}

String _normalizeOduName(String name) {
  final cleaned = name.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  final normalizedInput = cleaned;
  final tokens = normalizedInput.split(' ');
  final ogbeNormalized = _normalizeOgbeSubOdu(tokens);
  if (ogbeNormalized != null) {
    return ogbeNormalized;
  }
  final mapped = tokens.map(_normalizeOduToken).toList();
  return mapped.join(' ');
}

String? _normalizeOgbeSubOdu(List<String> tokens) {
  if (tokens.isEmpty) {
    return null;
  }
  var hasBaba = false;
  var index = 0;
  if (tokens.first == 'BABA') {
    hasBaba = true;
    index = 1;
  }
  if (tokens.length <= index || tokens[index] != 'OGBE') {
    return null;
  }
  const ogbeMap = {
    'YEKU': 'YEKU',
    'OYEKU': 'YEKU',
    'OYECU': 'YEKU',
    'OYECUN': 'YEKU',
    'OYEKUN': 'YEKU',
    'WEÑE': 'WEÑE',
    'WEÑ': 'WEÑE',
    'WENE': 'WEÑE',
    'IWORI': 'WEÑE',
    'DI': 'DI',
    'ODI': 'DI',
    'ROSO': 'ROSO',
    'IROSO': 'ROSO',
    'WANLE': 'WANLE',
    'OJUANI': 'WANLE',
    'BARA': 'BARA',
    'OBARA': 'BARA',
    'KANA': 'KANA',
    'OKANA': 'KANA',
    'YONO': 'YONO',
    'OGUNDA': 'YONO',
    'SA': 'SA',
    'OSA': 'SA',
    'KA': 'KA',
    'IKA': 'KA',
    'TUMAKO': 'TUMAKO',
    'OTRUPON': 'TUMAKO',
    'TUA': 'TUA',
    'OTURA': 'TUA',
    'ATE': 'ATE',
    'IRETE': 'ATE',
    'SHE': 'SHE',
    'OSHE': 'SHE',
    'FUN': 'FUN',
    'OFUN': 'FUN',
  };
  final normalized = <String>[];
  if (hasBaba) {
    normalized.add('BABA');
  }
  normalized.add('OGBE');
  if (tokens.length > index + 1) {
    final first = tokens[index + 1];
    normalized.add(ogbeMap[first] ?? first);
    if (tokens.length > index + 2) {
      normalized.addAll(tokens.sublist(index + 2).map(_normalizeOduToken));
    }
  }
  return normalized.join(' ');
}

String _normalizeOduToken(String token) {
  switch (token) {
    case 'OYECUN':
    case 'OYEKUN':
    case 'MATELEKUN':
      return 'OYEKUN';
    case 'YEKU':
      return 'OYEKUN';
    case 'NILOGBE':
      return 'OGBE';
    case 'PITI':
    case 'WIRO':
      return 'IWORI';
    case 'BERE':
      return 'OGBE';
    case 'BOGDE':
    case 'UMBO':
      return 'OGBE';
    case 'KOSO':
      return 'IROSO';
    case 'IROSUN':
      return 'IROSO';
    case 'ROSO':
    case 'ODI':
      return 'ODI';
    case 'BIROSO':
      return 'IROSO';
    case 'OTURUPON':
      return 'OTRUPON';
    case 'TUMAKO':
      return 'OTRUPON';
    case 'BATRUPON':
    case 'BATUTO':
      return 'OTRUPON';
    case 'TURALE':
      return 'OTURA';
    case 'ROTE':
      return 'IRETE';
    case 'BOSHE':
      return 'OSHE';
    case 'BOFUN':
      return 'OFUN';
    case 'TUA':
      return 'OTURA';
    case 'TESIA':
      return 'OTURA';
    case 'TAURO':
    case 'TUANILARA':
      return 'OTURA';
    case 'ATE':
      return 'IRETE';
    case 'BIRETE':
      return 'IRETE';
    case 'LEKE':
    case 'UNKUEMI':
      return 'IRETE';
    case 'SHE':
      return 'OSHE';
    case 'PAKIOSHE':
      return 'OSHE';
    case 'FUN':
      return 'OFUN';
    case 'BEDURA':
      return 'OFUN';
    case 'FUMBO':
      return 'OFUN';
    case 'OSE':
      return 'OSHE';
    case 'OCANA':
    case 'OKANRA':
      return 'OKANA';
    case 'KANA':
      return 'OKANA';
    case 'PELEKA':
    case 'KALU':
      return 'OKANA';
    case 'WEÑE':
      return 'IWORI';
    case 'DI':
      return 'ODI';
    case 'ORO':
    case 'WALE':
      return 'OJUANI';
    case 'WANLE':
      return 'OJUANI';
    case 'JUANI':
      return 'OJUANI';
    case 'OMONI':
    case 'GAN':
      return 'OBARA';
    case 'BODE':
      return 'ODI';
    case 'BOKA':
      return 'IKA';
    case 'BOSASO':
      return 'OSA';
    case 'BARA':
      return 'OBARA';
    case 'YONO':
      return 'OGUNDA';
    case 'TEKUNDA':
      return 'OGUNDA';
    case 'TOLA':
    case 'TOLDA':
      return 'OGUNDA';
    case 'SA':
      return 'OSA';
    case 'BIRIKUSA':
      return 'OSA';
    case 'KA':
      return 'IKA';
    case 'BIKA':
      return 'IKA';
    case 'EJIOGBE':
      return 'OGBE';
    case 'SHOGBE':
      return 'OGBE';
    case 'TANSHELA':
      return 'IWORI';
    case 'SHIDI':
      return 'ODI';
    case 'HERMOSO':
      return 'IROSO';
    case 'LOSURE':
      return 'OJUANI';
    case 'POKON':
      return 'OBARA';
    case 'DAWAN':
      return 'OKANA';
    case 'ALAKENTU':
      return 'OTURA';
    case 'BOGBE':
      return 'OGBE';
    case 'YEKUN':
      return 'OYEKUN';
    case 'WEREKO':
      return 'IWORI';
    case 'DILA':
      return 'ODI';
    case 'KUÑA':
      return 'OGUNDA';
    case 'KASIKA':
      return 'IKA';
    case 'TUMBUN':
      return 'OTRUPON';
    case 'KUSHIYA':
      return 'OTURA';
    case 'KETE':
      return 'IRETE';
    case 'SODE':
      return 'OGBE';
    case 'JIO':
      return 'IWORI';
    case 'YABILE':
      return 'OJUANI';
    case 'KAKUIN':
      return 'OGUNDA';
    case 'TRUPON':
      return 'OTRUPON';
    case 'WETE':
      return 'IRETE';
    case 'BIODE':
      return 'OGBE';
    case 'KUANEYE':
      return 'IWORI';
    case 'DIO':
      return 'ODI';
    case 'KOROSO':
      return 'IROSO';
    case 'LENI':
      return 'OJUANI';
    case 'BAMBO':
      return 'OBARA';
    case 'KO':
      return 'OKANA';
    case 'MASA':
      return 'OSA';
    case 'TETURA':
      return 'OTURA';
    case 'LOFOBEYO':
      return 'OGBE';
    case 'WORIWO':
      return 'IWORI';
    case 'LONI':
      return 'OJUANI';
    case 'SHEPE':
      return 'OBARA';
    case 'KULEYA':
      return 'OGUNDA';
    case 'URE':
      return 'OTURA';
    case 'RETE':
      return 'IRETE';
    case 'BEMI':
      return 'OGBE';
    case 'FEFE':
      return 'IWORI';
    case 'JUNKO':
      return 'OJUANI';
    case 'OGUNDA':
      return 'OGUNDA';
    case 'FOGUERO':
      return 'OTURA';
    case 'FA':
      return 'OSHE';
    case 'BEKONWAO':
      return 'OGBE';
    case 'ADAKINO':
      return 'IWORI';
    case 'ÑAO':
      return 'OJUANI';
    case 'ANGUEDE':
      return 'OGUNDA';
    case 'BALOFUN':
      return 'OFUN';
    case 'NIKO':
      return 'OGBE';
    case 'POMPEYO':
      return 'IWORI';
    case 'LAKENTU':
      return 'OJUANI';
    case 'KITU':
      return 'OKANA';
    case 'AIRA':
      return 'OGUNDA';
    case 'TIYU':
      return 'IRETE';
    case 'ADAKOY':
      return 'OFUN';
    case 'UNTELU':
      return 'OGBE';
    case 'YERO':
      return 'OYEKUN';
    case 'UNTENDI':
      return 'ODI';
    case 'LAZO':
      return 'IROSO';
    case 'WAN':
      return 'OJUANI';
    case 'OBA':
      return 'OBARA';
    case 'KUTAN':
      return 'OGUNDA';
    case 'ANSA':
      return 'OSA';
    case 'SUKA':
      return 'OTURA';
    case 'UNFA':
      return 'OSHE';
    case 'FILE':
      return 'OFUN';
    case 'PAURE':
      return 'IWORI';
    case 'LEZO':
      return 'IROSO';
    case 'NIWO':
      return 'OJUANI';
    case 'OMOLU':
      return 'OGUNDA';
    case 'TURA':
      return 'OTURA';
    case 'BILE':
      return 'IRETE';
    case 'ORANGUN':
      return 'OGBE';
    case 'NALBE':
      return 'OGBE';
    case 'YEMILO':
      return 'OYEKUN';
    case 'GANDO':
      return 'IWORI';
    case 'FUNI':
      return 'OJUANI';
    case 'SUSU':
      return 'OBARA';
    case 'FUNDA':
      return 'OGUNDA';
    case 'KAMALA':
      return 'IKA';
    case 'TEMPOLA':
      return 'OTURA';
    case 'OJUANO':
      return 'OJUANI';
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
            child: CustomPaint(painter: _OduSignPainter(pattern: pattern)),
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

bool _isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

bool _matchesNameFilter(String fullName, String rawFilter) {
  final normalizedName = _normalizeFilterText(fullName);
  final normalizedFilter = _normalizeFilterText(rawFilter);
  if (normalizedFilter.isEmpty) {
    return true;
  }
  final terms = normalizedFilter.split(' ').where((term) => term.isNotEmpty);
  return terms.every((term) => normalizedName.contains(term));
}

String _normalizeFilterText(String value) {
  const replacements = <String, String>{
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'ã': 'a',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'õ': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'ñ': 'n',
  };
  final lower = value.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(replacements[char] ?? char);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
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
