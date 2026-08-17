/// Un idioma con sus dos códigos: el que necesita Tesseract para leer la
/// escritura y el que necesitan los traductores.
///
/// Son códigos distintos a propósito: Tesseract usa ISO 639-3 (`jpn`, `spa`) y
/// las APIs de traducción usan ISO 639-1 (`ja`, `es`). Confundirlos es el error
/// clásico al configurar OCR + traducción, así que aquí van emparejados.
class LanguageOption {
  const LanguageOption({
    required this.label,
    required this.ocrCode,
    required this.translateCode,
    this.recommendedPsm = 6,
    this.note,
  });

  final String label;

  /// Código de tessdata. Vacío si el idioma no es reconocible por OCR.
  final String ocrCode;

  /// Código para las APIs de traducción.
  final String translateCode;

  /// Los idiomas verticales o de trazo denso rinden mejor con otro modo de
  /// segmentación de página.
  final int recommendedPsm;

  final String? note;
}

/// Idiomas de origen habituales en videojuegos, ordenados por lo frecuentes que
/// son en juegos sin traducir al español.
const List<LanguageOption> sourceLanguages = <LanguageOption>[
  LanguageOption(
    label: 'Japonés',
    ocrCode: 'jpn',
    translateCode: 'ja',
    note:
        'Requiere el paquete jpn de Tesseract. Para texto vertical instala '
        'también jpn_vert.',
  ),
  LanguageOption(label: 'Inglés', ocrCode: 'eng', translateCode: 'en'),
  LanguageOption(
    label: 'Chino simplificado',
    ocrCode: 'chi_sim',
    translateCode: 'zh-CN',
  ),
  LanguageOption(
    label: 'Chino tradicional',
    ocrCode: 'chi_tra',
    translateCode: 'zh-TW',
  ),
  LanguageOption(label: 'Coreano', ocrCode: 'kor', translateCode: 'ko'),
  LanguageOption(label: 'Ruso', ocrCode: 'rus', translateCode: 'ru'),
  LanguageOption(label: 'Alemán', ocrCode: 'deu', translateCode: 'de'),
  LanguageOption(label: 'Francés', ocrCode: 'fra', translateCode: 'fr'),
  LanguageOption(label: 'Italiano', ocrCode: 'ita', translateCode: 'it'),
  LanguageOption(label: 'Portugués', ocrCode: 'por', translateCode: 'pt'),
  LanguageOption(label: 'Polaco', ocrCode: 'pol', translateCode: 'pl'),
  LanguageOption(label: 'Turco', ocrCode: 'tur', translateCode: 'tr'),
  LanguageOption(label: 'Árabe', ocrCode: 'ara', translateCode: 'ar'),
  LanguageOption(label: 'Tailandés', ocrCode: 'tha', translateCode: 'th'),
  LanguageOption(label: 'Vietnamita', ocrCode: 'vie', translateCode: 'vi'),
  LanguageOption(label: 'Español', ocrCode: 'spa', translateCode: 'es'),
];

/// Idiomas de destino. Español es el primero porque es el caso de uso principal.
const List<LanguageOption> targetLanguages = <LanguageOption>[
  LanguageOption(label: 'Español', ocrCode: 'spa', translateCode: 'es'),
  LanguageOption(label: 'Inglés', ocrCode: 'eng', translateCode: 'en'),
  LanguageOption(
    label: 'Español (Latinoamérica)',
    ocrCode: 'spa',
    translateCode: 'es',
  ),
  LanguageOption(label: 'Portugués', ocrCode: 'por', translateCode: 'pt'),
  LanguageOption(label: 'Francés', ocrCode: 'fra', translateCode: 'fr'),
  LanguageOption(label: 'Alemán', ocrCode: 'deu', translateCode: 'de'),
  LanguageOption(label: 'Italiano', ocrCode: 'ita', translateCode: 'it'),
  LanguageOption(label: 'Japonés', ocrCode: 'jpn', translateCode: 'ja'),
  LanguageOption(label: 'Coreano', ocrCode: 'kor', translateCode: 'ko'),
  LanguageOption(label: 'Ruso', ocrCode: 'rus', translateCode: 'ru'),
  LanguageOption(
    label: 'Chino simplificado',
    ocrCode: 'chi_sim',
    translateCode: 'zh-CN',
  ),
];

/// Busca un idioma por su código de OCR. Devuelve `null` si no está en la lista
/// (el usuario puede escribir combinaciones propias como `jpn+eng`).
LanguageOption? languageByOcrCode(String ocrCode) {
  for (final LanguageOption option in sourceLanguages) {
    if (option.ocrCode == ocrCode) return option;
  }
  return null;
}

LanguageOption? targetByTranslateCode(String code) {
  for (final LanguageOption option in targetLanguages) {
    if (option.translateCode == code) return option;
  }
  return null;
}

/// Etiqueta legible para un código de traducción, para mostrar el idioma
/// detectado en la barra de estado.
String translateCodeLabel(String code) {
  final String normalized = code.toLowerCase();
  for (final LanguageOption option in sourceLanguages) {
    if (option.translateCode.toLowerCase() == normalized) return option.label;
  }
  return code;
}
