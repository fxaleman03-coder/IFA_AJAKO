class OduContent {
  const OduContent({
    required this.name,
    required this.mainName,
    required this.aliases,
    required this.rezoYoruba,
    required this.suyereYoruba,
    required this.suyereEspanol,
    required this.nace,
    required this.descripcion,
    required this.predicciones,
    required this.prohibiciones,
    required this.recomendaciones,
    required this.ewes,
    required this.eshu,
    required this.rezosYSuyeres,
    required this.obrasYEbbo,
    required this.diceIfa,
    required this.refranes,
    required this.historiasYPatakies,
  });

  final String name;
  final String mainName;
  final List<String> aliases;
  final String rezoYoruba;
  final String suyereYoruba;
  final String suyereEspanol;
  final String nace;
  final String descripcion;
  final String predicciones;
  final String prohibiciones;
  final String recomendaciones;
  final String ewes;
  final String eshu;
  final String rezosYSuyeres;
  final String obrasYEbbo;
  final String diceIfa;
  final String refranes;
  final String historiasYPatakies;

  static OduContent empty(String name) => OduContent(
    name: name,
    mainName: name,
    aliases: const [],
    rezoYoruba: '',
    suyereYoruba: '',
    suyereEspanol: '',
    nace: '',
    descripcion: '',
    predicciones: '',
    prohibiciones: '',
    recomendaciones: '',
    ewes: '',
    eshu: '',
    rezosYSuyeres: '',
    obrasYEbbo: '',
    diceIfa: '',
    refranes: '',
    historiasYPatakies: '',
  );

  factory OduContent.fromJson(
    Map<String, dynamic> json, {
    required String fallbackName,
  }) {
    String read(String key) {
      final value = json[key];
      if (value is String) {
        return value;
      }
      return '';
    }

    final name = (json['name'] is String)
        ? json['name'] as String
        : fallbackName;
    final mainNameRaw = (json['mainName'] is String)
        ? (json['mainName'] as String).trim()
        : '';
    final mainName = mainNameRaw.isNotEmpty ? mainNameRaw : name;
    final aliases = <String>[];
    final aliasesRaw = json['aliases'];
    if (aliasesRaw is List) {
      for (final alias in aliasesRaw) {
        if (alias is String && alias.trim().isNotEmpty) {
          aliases.add(alias.trim());
        }
      }
    }

    return OduContent(
      name: name,
      mainName: mainName,
      aliases: aliases,
      rezoYoruba: read('rezoYoruba'),
      suyereYoruba: read('suyereYoruba'),
      suyereEspanol: read('suyereEspanol'),
      nace: read('nace'),
      descripcion: read('descripcion'),
      predicciones: read('predicciones'),
      prohibiciones: read('prohibiciones'),
      recomendaciones: read('recomendaciones'),
      ewes: read('ewes'),
      eshu: read('eshu'),
      rezosYSuyeres: read('rezosYSuyeres'),
      obrasYEbbo: read('obrasYEbbo'),
      diceIfa: read('diceIfa'),
      refranes: read('refranes'),
      historiasYPatakies: read('historiasYPatakies'),
    );
  }
}

class OduData {
  const OduData({
    required this.content,
    required this.patakies,
    required this.patakiesContent,
  });

  final OduContent content;
  final List<String> patakies;
  final Map<String, String> patakiesContent;

  static OduData empty(String name) => OduData(
    content: OduContent.empty(name),
    patakies: const [],
    patakiesContent: const {},
  );

  factory OduData.fromJson(
    Map<String, dynamic> json, {
    required String fallbackName,
  }) {
    final contentJson = json['content'];
    final content = contentJson is Map<String, dynamic>
        ? OduContent.fromJson(contentJson, fallbackName: fallbackName)
        : OduContent.empty(fallbackName);

    final patakiesRaw = json['patakies'];
    final patakies = <String>[];
    if (patakiesRaw is List) {
      for (final item in patakiesRaw) {
        if (item is String) {
          patakies.add(item);
        }
      }
    }

    final patakiesContentRaw = json['patakiesContent'];
    final patakiesContent = <String, String>{};
    if (patakiesContentRaw is Map) {
      patakiesContentRaw.forEach((key, value) {
        if (key is String && value is String) {
          patakiesContent[key] = value;
        }
      });
    }

    return OduData(
      content: content,
      patakies: patakies,
      patakiesContent: patakiesContent,
    );
  }
}
