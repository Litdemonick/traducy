import 'dart:ui' show Color, Offset, Rect, Size;

/// Modo de transparencia de la ventana overlay.
enum TransparencyMode {
  /// Alfa real vía composición DWM. Es lo que se ve mejor.
  compositor,

  /// Un color concreto se vuelve invisible. Funciona en cualquier Windows,
  /// como red de seguridad si el compositor no da transparencia.
  colorKey,
}

enum TranslatorKind { none, googleFree, libre, deepl, claude }

/// Cómo se decide la región que se captura.
enum RegionMode {
  /// Rectángulo fijo en coordenadas de pantalla.
  fixed,

  /// Rectángulo relativo a una ventana concreta; si el usuario mueve la
  /// ventana, la región la sigue.
  followWindow,
}

class CaptureRegion {
  const CaptureRegion({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  /// Coordenadas en píxeles **físicos** de pantalla. Se guardan en físicos a
  /// propósito: mezclar unidades lógicas y físicas es la fuente número uno de
  /// desalineaciones al cambiar el escalado de Windows o de monitor.
  final int left;
  final int top;
  final int width;
  final int height;

  static const CaptureRegion zero = CaptureRegion(
    left: 0,
    top: 0,
    width: 0,
    height: 0,
  );

  bool get isValid => width >= 24 && height >= 12;

  int get right => left + width;
  int get bottom => top + height;

  CaptureRegion copyWith({int? left, int? top, int? width, int? height}) =>
      CaptureRegion(
        left: left ?? this.left,
        top: top ?? this.top,
        width: width ?? this.width,
        height: height ?? this.height,
      );

  CaptureRegion clampTo({
    required int boundsLeft,
    required int boundsTop,
    required int boundsWidth,
    required int boundsHeight,
  }) {
    final int w = width.clamp(24, boundsWidth);
    final int h = height.clamp(12, boundsHeight);
    final int l = left.clamp(boundsLeft, boundsLeft + boundsWidth - w);
    final int t = top.clamp(boundsTop, boundsTop + boundsHeight - h);
    return CaptureRegion(left: l, top: t, width: w, height: h);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'left': left,
    'top': top,
    'width': width,
    'height': height,
  };

  static CaptureRegion fromJson(Map<String, dynamic> json) => CaptureRegion(
    left: _asInt(json['left'], 0),
    top: _asInt(json['top'], 0),
    width: _asInt(json['width'], 0),
    height: _asInt(json['height'], 0),
  );
}

/// Posición y tamaño de la caja de subtítulos, en píxeles **lógicos** de la
/// ventana (coordenadas de Flutter), porque es un elemento de interfaz.
class SubtitleBox {
  const SubtitleBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  Rect get rect => Rect.fromLTWH(left, top, width, height);
  Offset get offset => Offset(left, top);
  Size get size => Size(width, height);

  SubtitleBox copyWith({
    double? left,
    double? top,
    double? width,
    double? height,
  }) => SubtitleBox(
    left: left ?? this.left,
    top: top ?? this.top,
    width: width ?? this.width,
    height: height ?? this.height,
  );

  SubtitleBox clampTo(Size bounds) {
    final double w = width.clamp(180.0, bounds.width);
    final double h = height.clamp(56.0, bounds.height);
    return SubtitleBox(
      left: left.clamp(0.0, (bounds.width - w).clamp(0.0, bounds.width)),
      top: top.clamp(0.0, (bounds.height - h).clamp(0.0, bounds.height)),
      width: w,
      height: h,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'left': left,
    'top': top,
    'width': width,
    'height': height,
  };

  static SubtitleBox fromJson(Map<String, dynamic> json) => SubtitleBox(
    left: _asDouble(json['left'], 120),
    top: _asDouble(json['top'], 520),
    width: _asDouble(json['width'], 900),
    height: _asDouble(json['height'], 160),
  );
}

enum SubtitleAlign { left, center, right }

class SubtitleStyle {
  const SubtitleStyle({
    this.fontFamily = 'Segoe UI',
    this.fontSize = 30,
    this.bold = true,
    this.italic = false,
    this.textColor = const Color(0xFFFFFFFF),
    this.outlineColor = const Color(0xFF000000),
    this.outlineWidth = 3.5,
    this.shadow = true,
    this.backgroundColor = const Color(0xFF000000),
    this.backgroundOpacity = 0.55,
    this.cornerRadius = 12,
    this.padding = 14,
    this.lineHeight = 1.25,
    this.letterSpacing = 0,
    this.align = SubtitleAlign.center,
    this.showOriginal = false,
    this.originalOpacity = 0.65,
    this.maxLines = 4,
    this.fadeMs = 140,
  });

  final String fontFamily;
  final double fontSize;
  final bool bold;
  final bool italic;
  final Color textColor;
  final Color outlineColor;
  final double outlineWidth;
  final bool shadow;
  final Color backgroundColor;
  final double backgroundOpacity;
  final double cornerRadius;
  final double padding;
  final double lineHeight;
  final double letterSpacing;
  final SubtitleAlign align;
  final bool showOriginal;
  final double originalOpacity;
  final int maxLines;
  final int fadeMs;

  SubtitleStyle copyWith({
    String? fontFamily,
    double? fontSize,
    bool? bold,
    bool? italic,
    Color? textColor,
    Color? outlineColor,
    double? outlineWidth,
    bool? shadow,
    Color? backgroundColor,
    double? backgroundOpacity,
    double? cornerRadius,
    double? padding,
    double? lineHeight,
    double? letterSpacing,
    SubtitleAlign? align,
    bool? showOriginal,
    double? originalOpacity,
    int? maxLines,
    int? fadeMs,
  }) => SubtitleStyle(
    fontFamily: fontFamily ?? this.fontFamily,
    fontSize: fontSize ?? this.fontSize,
    bold: bold ?? this.bold,
    italic: italic ?? this.italic,
    textColor: textColor ?? this.textColor,
    outlineColor: outlineColor ?? this.outlineColor,
    outlineWidth: outlineWidth ?? this.outlineWidth,
    shadow: shadow ?? this.shadow,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
    cornerRadius: cornerRadius ?? this.cornerRadius,
    padding: padding ?? this.padding,
    lineHeight: lineHeight ?? this.lineHeight,
    letterSpacing: letterSpacing ?? this.letterSpacing,
    align: align ?? this.align,
    showOriginal: showOriginal ?? this.showOriginal,
    originalOpacity: originalOpacity ?? this.originalOpacity,
    maxLines: maxLines ?? this.maxLines,
    fadeMs: fadeMs ?? this.fadeMs,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'fontFamily': fontFamily,
    'fontSize': fontSize,
    'bold': bold,
    'italic': italic,
    'textColor': _colorToInt(textColor),
    'outlineColor': _colorToInt(outlineColor),
    'outlineWidth': outlineWidth,
    'shadow': shadow,
    'backgroundColor': _colorToInt(backgroundColor),
    'backgroundOpacity': backgroundOpacity,
    'cornerRadius': cornerRadius,
    'padding': padding,
    'lineHeight': lineHeight,
    'letterSpacing': letterSpacing,
    'align': align.name,
    'showOriginal': showOriginal,
    'originalOpacity': originalOpacity,
    'maxLines': maxLines,
    'fadeMs': fadeMs,
  };

  static SubtitleStyle fromJson(Map<String, dynamic> json) => SubtitleStyle(
    fontFamily: _asString(json['fontFamily'], 'Segoe UI'),
    fontSize: _asDouble(json['fontSize'], 30).clamp(10, 96),
    bold: _asBool(json['bold'], true),
    italic: _asBool(json['italic'], false),
    textColor: _intToColor(json['textColor'], 0xFFFFFFFF),
    outlineColor: _intToColor(json['outlineColor'], 0xFF000000),
    outlineWidth: _asDouble(json['outlineWidth'], 3.5).clamp(0, 12),
    shadow: _asBool(json['shadow'], true),
    backgroundColor: _intToColor(json['backgroundColor'], 0xFF000000),
    backgroundOpacity: _asDouble(json['backgroundOpacity'], 0.55).clamp(0, 1),
    cornerRadius: _asDouble(json['cornerRadius'], 12).clamp(0, 40),
    padding: _asDouble(json['padding'], 14).clamp(0, 48),
    lineHeight: _asDouble(json['lineHeight'], 1.25).clamp(0.9, 2.2),
    letterSpacing: _asDouble(json['letterSpacing'], 0).clamp(-2, 8),
    align: _asEnum(json['align'], SubtitleAlign.values, SubtitleAlign.center),
    showOriginal: _asBool(json['showOriginal'], false),
    originalOpacity: _asDouble(json['originalOpacity'], 0.65).clamp(0.1, 1),
    maxLines: _asInt(json['maxLines'], 4).clamp(1, 12),
    fadeMs: _asInt(json['fadeMs'], 140).clamp(0, 1200),
  );
}

/// Ajustes de preprocesado de imagen antes del OCR. Un buen preprocesado sube
/// la precisión del OCR mucho más que cambiar de motor.
class PreprocessSettings {
  const PreprocessSettings({
    this.scale = 2.0,
    this.grayscale = true,
    this.contrast = 1.35,
    this.threshold = 0,
    this.invert = false,
    this.denoise = false,
  });

  /// Multiplicador de tamaño. Tesseract funciona mucho mejor con texto grande.
  final double scale;
  final bool grayscale;
  final double contrast;

  /// 0 = desactivado. Si es > 0, binariza en ese umbral (0-255). Útil con texto
  /// de color plano sobre fondo plano; contraproducente con fondos complejos.
  final int threshold;

  /// Para texto claro sobre fondo oscuro algunos motores aciertan más invertido.
  final bool invert;
  final bool denoise;

  PreprocessSettings copyWith({
    double? scale,
    bool? grayscale,
    double? contrast,
    int? threshold,
    bool? invert,
    bool? denoise,
  }) => PreprocessSettings(
    scale: scale ?? this.scale,
    grayscale: grayscale ?? this.grayscale,
    contrast: contrast ?? this.contrast,
    threshold: threshold ?? this.threshold,
    invert: invert ?? this.invert,
    denoise: denoise ?? this.denoise,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'scale': scale,
    'grayscale': grayscale,
    'contrast': contrast,
    'threshold': threshold,
    'invert': invert,
    'denoise': denoise,
  };

  static PreprocessSettings fromJson(Map<String, dynamic> json) =>
      PreprocessSettings(
        scale: _asDouble(json['scale'], 2.0).clamp(1.0, 4.0),
        grayscale: _asBool(json['grayscale'], true),
        contrast: _asDouble(json['contrast'], 1.35).clamp(0.5, 3.0),
        threshold: _asInt(json['threshold'], 0).clamp(0, 255),
        invert: _asBool(json['invert'], false),
        denoise: _asBool(json['denoise'], false),
      );
}

class PipelineSettings {
  const PipelineSettings({
    this.intervalMs = 350,
    this.minChangePercent = 0.8,
    this.stabilityFrames = 2,
    this.minTextLength = 2,
    this.holdMs = 2500,
    this.ocrTimeoutMs = 4000,
    this.translateTimeoutMs = 6000,
    this.maxConsecutiveErrors = 8,
  });

  /// Periodo entre capturas. 350 ms (≈3/s) da sensación de tiempo real sin
  /// castigar los FPS del juego.
  final int intervalMs;

  /// Porcentaje de la zona que debe cambiar para repetir el OCR. Es el ahorro
  /// grande de CPU y de llamadas a la API de traducción.
  ///
  /// Sustituye al antiguo "umbral de cambio", que comparaba la diferencia media
  /// de píxeles: esa media diluía los cambios pequeños y localizados, y un
  /// renglón de diálogo nuevo dentro de una franja ancha se quedaba por debajo
  /// de cualquier umbral útil. El síntoma era el peor posible: la aplicación
  /// repetía "sin cambios" sin traducir nunca.
  ///
  /// 0.8 % de una rejilla de 32x32 son 8 celdas: por debajo de lo que ocupa un
  /// renglón corto de diálogo dentro de una franja ancha, y muy por encima del
  /// ruido de un fondo animado, que mueve muchas celdas pero pocos niveles y no
  /// llega a contar.
  final double minChangePercent;

  /// Fotogramas consecutivos con el mismo texto antes de traducir. Evita
  /// traducir diálogos a medio escribir en juegos con efecto máquina de escribir.
  final int stabilityFrames;

  final int minTextLength;

  /// Tiempo que el subtítulo permanece en pantalla cuando ya no se detecta texto.
  final int holdMs;

  final int ocrTimeoutMs;
  final int translateTimeoutMs;

  /// Tras este número de errores seguidos el pipeline se autopausa en lugar de
  /// seguir golpeando un motor que claramente no funciona.
  final int maxConsecutiveErrors;

  PipelineSettings copyWith({
    int? intervalMs,
    double? minChangePercent,
    int? stabilityFrames,
    int? minTextLength,
    int? holdMs,
    int? ocrTimeoutMs,
    int? translateTimeoutMs,
    int? maxConsecutiveErrors,
  }) => PipelineSettings(
    intervalMs: intervalMs ?? this.intervalMs,
    minChangePercent: minChangePercent ?? this.minChangePercent,
    stabilityFrames: stabilityFrames ?? this.stabilityFrames,
    minTextLength: minTextLength ?? this.minTextLength,
    holdMs: holdMs ?? this.holdMs,
    ocrTimeoutMs: ocrTimeoutMs ?? this.ocrTimeoutMs,
    translateTimeoutMs: translateTimeoutMs ?? this.translateTimeoutMs,
    maxConsecutiveErrors: maxConsecutiveErrors ?? this.maxConsecutiveErrors,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'intervalMs': intervalMs,
    'minChangePercent': minChangePercent,
    'stabilityFrames': stabilityFrames,
    'minTextLength': minTextLength,
    'holdMs': holdMs,
    'ocrTimeoutMs': ocrTimeoutMs,
    'translateTimeoutMs': translateTimeoutMs,
    'maxConsecutiveErrors': maxConsecutiveErrors,
  };

  static PipelineSettings fromJson(
    Map<String, dynamic> json,
  ) => PipelineSettings(
    intervalMs: _asInt(json['intervalMs'], 350).clamp(120, 5000),
    // Se lee solo la clave nueva a propósito. Un `changeThreshold` guardado
    // valía 6 en una escala de 0-255 y significaría 6 % aquí: cinco veces
    // más exigente de lo debido, justo el fallo que se está corrigiendo.
    minChangePercent: _asDouble(json['minChangePercent'], 1.2).clamp(0.1, 25),
    stabilityFrames: _asInt(json['stabilityFrames'], 2).clamp(1, 6),
    minTextLength: _asInt(json['minTextLength'], 2).clamp(1, 40),
    holdMs: _asInt(json['holdMs'], 2500).clamp(0, 30000),
    ocrTimeoutMs: _asInt(json['ocrTimeoutMs'], 4000).clamp(500, 30000),
    translateTimeoutMs: _asInt(
      json['translateTimeoutMs'],
      6000,
    ).clamp(500, 60000),
    maxConsecutiveErrors: _asInt(json['maxConsecutiveErrors'], 8).clamp(2, 100),
  );
}

class EngineSettings {
  const EngineSettings({
    this.tesseractPath = '',
    this.ocrLanguages = 'eng',
    this.psm = 6,
    this.translator = TranslatorKind.googleFree,
    this.targetLanguage = 'es',
    this.sourceLanguage = 'auto',
    this.deeplKey = '',
    this.claudeKey = '',
    this.claudeModel = 'claude-opus-5',
    this.libreTranslateUrl = '',
    this.glossary = '',
    this.tessdataDir = '',
  });

  /// Ruta al ejecutable de Tesseract. Vacío = autodetectar.
  final String tesseractPath;

  /// Códigos de idioma de tessdata separados por `+` (p. ej. `jpn+eng`).
  final String ocrLanguages;

  /// Page Segmentation Mode de Tesseract. 6 = bloque uniforme de texto, que es
  /// lo correcto para una caja de diálogo. 7 = una sola línea.
  final int psm;

  final TranslatorKind translator;
  final String targetLanguage;
  final String sourceLanguage;
  final String deeplKey;
  final String claudeKey;
  final String claudeModel;
  final String libreTranslateUrl;

  /// Términos que no deben traducirse o deben traducirse de una forma concreta
  /// (nombres propios, objetos del juego). Una línea por entrada.
  final String glossary;

  /// Carpeta donde la aplicación guarda los paquetes de idioma que descarga.
  ///
  /// Vacío = `%APPDATA%\Traducy	essdata`. Se puede cambiar para dejarlos en
  /// otra unidad, o junto al ejecutable si se quiere una instalación portátil
  /// que se pueda llevar en un USB.
  final String tessdataDir;

  EngineSettings copyWith({
    String? tesseractPath,
    String? ocrLanguages,
    int? psm,
    TranslatorKind? translator,
    String? targetLanguage,
    String? sourceLanguage,
    String? deeplKey,
    String? claudeKey,
    String? claudeModel,
    String? libreTranslateUrl,
    String? glossary,
    String? tessdataDir,
  }) => EngineSettings(
    tesseractPath: tesseractPath ?? this.tesseractPath,
    ocrLanguages: ocrLanguages ?? this.ocrLanguages,
    psm: psm ?? this.psm,
    translator: translator ?? this.translator,
    targetLanguage: targetLanguage ?? this.targetLanguage,
    sourceLanguage: sourceLanguage ?? this.sourceLanguage,
    deeplKey: deeplKey ?? this.deeplKey,
    claudeKey: claudeKey ?? this.claudeKey,
    claudeModel: claudeModel ?? this.claudeModel,
    libreTranslateUrl: libreTranslateUrl ?? this.libreTranslateUrl,
    glossary: glossary ?? this.glossary,
    tessdataDir: tessdataDir ?? this.tessdataDir,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'tesseractPath': tesseractPath,
    'ocrLanguages': ocrLanguages,
    'psm': psm,
    'translator': translator.name,
    'targetLanguage': targetLanguage,
    'sourceLanguage': sourceLanguage,
    'deeplKey': deeplKey,
    'claudeKey': claudeKey,
    'claudeModel': claudeModel,
    'libreTranslateUrl': libreTranslateUrl,
    'glossary': glossary,
    'tessdataDir': tessdataDir,
  };

  static EngineSettings fromJson(Map<String, dynamic> json) => EngineSettings(
    tesseractPath: _asString(json['tesseractPath'], ''),
    ocrLanguages: _asString(json['ocrLanguages'], 'eng'),
    psm: _asInt(json['psm'], 6).clamp(0, 13),
    translator: _asEnum(
      json['translator'],
      TranslatorKind.values,
      TranslatorKind.googleFree,
    ),
    targetLanguage: _asString(json['targetLanguage'], 'es'),
    sourceLanguage: _asString(json['sourceLanguage'], 'auto'),
    deeplKey: _asString(json['deeplKey'], ''),
    claudeKey: _asString(json['claudeKey'], ''),
    claudeModel: _asString(json['claudeModel'], 'claude-opus-5'),
    libreTranslateUrl: _asString(json['libreTranslateUrl'], ''),
    glossary: _asString(json['glossary'], ''),
    tessdataDir: _asString(json['tessdataDir'], ''),
  );
}

class AppSettings {
  const AppSettings({
    this.region = CaptureRegion.zero,
    this.regionMode = RegionMode.fixed,
    this.regionLocked = false,
    this.subtitleLocked = false,
    this.editRegion = false,
    this.editSubtitleBox = false,
    this.panelX = 24,
    this.panelY = 24,
    this.panelWidth = 560,
    this.panelHeight = 720,
    this.followWindowTitle = '',
    this.subtitleBox = const SubtitleBox(
      left: 120,
      top: 520,
      width: 900,
      height: 170,
    ),
    this.style = const SubtitleStyle(),
    this.preprocess = const PreprocessSettings(),
    this.pipeline = const PipelineSettings(),
    this.engines = const EngineSettings(),
    this.transparency = TransparencyMode.compositor,
    this.colorKey = 0xFF00FF,
    this.startInConfigMode = true,
    this.passthroughInConfig = true,
    this.hotkeyToggleConfig = 'ctrl+alt+T',
    this.hotkeyPause = 'ctrl+alt+P',
    this.hotkeyHide = 'ctrl+alt+H',
  });

  static const int schemaVersion = 1;

  final CaptureRegion region;
  final RegionMode regionMode;

  /// Zona de captura bloqueada: sigue visible en modo configuración pero no se
  /// puede mover ni redimensionar. Evita descolocarla sin querer después de
  /// haberla ajustado al milímetro.
  final bool regionLocked;

  /// Caja de subtítulos bloqueada, con el mismo propósito.
  final bool subtitleLocked;

  /// Marco de edición de la zona de captura visible.
  ///
  /// Se activa desde el panel a propósito: un rectángulo que aparece solo sobre
  /// el juego resulta desconcertante, y además su barra y sus tiradores
  /// interceptan el ratón. Mientras está desactivado, la zona sigue
  /// capturándose; simplemente no se ve ni molesta.
  final bool editRegion;

  /// Marco de edición de la caja de subtítulos, con la misma lógica. El texto se
  /// sigue mostrando cuando está desactivado; solo desaparece el marco.
  final bool editSubtitleBox;

  /// Posición del panel de control, en píxeles lógicos.
  final double panelX;
  final double panelY;

  /// Tamaño del panel, en píxeles lógicos. Se recorta contra los límites de la
  /// pantalla al aplicarse, así que un valor guardado en un monitor grande no
  /// deja el panel inmanejable en uno pequeño.
  final double panelWidth;
  final double panelHeight;

  /// Límites del panel. El mínimo es el punto donde los controles siguen
  /// siendo usables; por debajo, los deslizadores y las pestañas se aplastan.
  static const double panelMinWidth = 420;
  static const double panelMinHeight = 380;
  static const double panelMaxWidth = 1000;
  static const double panelMaxHeight = 1200;

  /// Título de la ventana a seguir. El HWND no se persiste porque cambia en
  /// cada arranque del juego; el título sí permite reencontrarla.
  final String followWindowTitle;

  final SubtitleBox subtitleBox;
  final SubtitleStyle style;
  final PreprocessSettings preprocess;
  final PipelineSettings pipeline;
  final EngineSettings engines;
  final TransparencyMode transparency;
  final int colorKey;
  final bool startInConfigMode;

  /// En modo configuración, dejar pasar los clics al juego mientras el cursor no
  /// esté sobre el panel ni sobre las cajas. Permite avanzar el diálogo del
  /// juego para ver texto real mientras se ajusta la zona.
  ///
  /// Si diera problemas en algún equipo, desactivarlo devuelve el
  /// comportamiento simple: la ventana captura todos los clics.
  final bool passthroughInConfig;

  final String hotkeyToggleConfig;
  final String hotkeyPause;
  final String hotkeyHide;

  AppSettings copyWith({
    CaptureRegion? region,
    bool? regionLocked,
    bool? subtitleLocked,
    bool? editRegion,
    bool? editSubtitleBox,
    double? panelX,
    double? panelY,
    double? panelWidth,
    double? panelHeight,
    RegionMode? regionMode,
    String? followWindowTitle,
    SubtitleBox? subtitleBox,
    SubtitleStyle? style,
    PreprocessSettings? preprocess,
    PipelineSettings? pipeline,
    EngineSettings? engines,
    TransparencyMode? transparency,
    int? colorKey,
    bool? startInConfigMode,
    bool? passthroughInConfig,
    String? hotkeyToggleConfig,
    String? hotkeyPause,
    String? hotkeyHide,
  }) => AppSettings(
    region: region ?? this.region,
    regionMode: regionMode ?? this.regionMode,
    regionLocked: regionLocked ?? this.regionLocked,
    subtitleLocked: subtitleLocked ?? this.subtitleLocked,
    editRegion: editRegion ?? this.editRegion,
    editSubtitleBox: editSubtitleBox ?? this.editSubtitleBox,
    panelX: panelX ?? this.panelX,
    panelY: panelY ?? this.panelY,
    panelWidth: panelWidth ?? this.panelWidth,
    panelHeight: panelHeight ?? this.panelHeight,
    followWindowTitle: followWindowTitle ?? this.followWindowTitle,
    subtitleBox: subtitleBox ?? this.subtitleBox,
    style: style ?? this.style,
    preprocess: preprocess ?? this.preprocess,
    pipeline: pipeline ?? this.pipeline,
    engines: engines ?? this.engines,
    transparency: transparency ?? this.transparency,
    colorKey: colorKey ?? this.colorKey,
    startInConfigMode: startInConfigMode ?? this.startInConfigMode,
    passthroughInConfig: passthroughInConfig ?? this.passthroughInConfig,
    hotkeyToggleConfig: hotkeyToggleConfig ?? this.hotkeyToggleConfig,
    hotkeyPause: hotkeyPause ?? this.hotkeyPause,
    hotkeyHide: hotkeyHide ?? this.hotkeyHide,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'region': region.toJson(),
    'regionMode': regionMode.name,
    'regionLocked': regionLocked,
    'subtitleLocked': subtitleLocked,
    'editRegion': editRegion,
    'editSubtitleBox': editSubtitleBox,
    'panelX': panelX,
    'panelY': panelY,
    'panelWidth': panelWidth,
    'panelHeight': panelHeight,
    'followWindowTitle': followWindowTitle,
    'subtitleBox': subtitleBox.toJson(),
    'style': style.toJson(),
    'preprocess': preprocess.toJson(),
    'pipeline': pipeline.toJson(),
    'engines': engines.toJson(),
    'transparency': transparency.name,
    'colorKey': colorKey,
    'startInConfigMode': startInConfigMode,
    'passthroughInConfig': passthroughInConfig,
    'hotkeyToggleConfig': hotkeyToggleConfig,
    'hotkeyPause': hotkeyPause,
    'hotkeyHide': hotkeyHide,
  };

  /// Reconstruye los ajustes tolerando campos ausentes, nulos o del tipo
  /// equivocado. Un JSON corrupto a medias produce valores por defecto en los
  /// campos afectados, no una excepción.
  static AppSettings fromJson(Map<String, dynamic> json) => AppSettings(
    region: CaptureRegion.fromJson(_asMap(json['region'])),
    regionMode: _asEnum(
      json['regionMode'],
      RegionMode.values,
      RegionMode.fixed,
    ),
    regionLocked: _asBool(json['regionLocked'], false),
    subtitleLocked: _asBool(json['subtitleLocked'], false),
    editRegion: _asBool(json['editRegion'], false),
    editSubtitleBox: _asBool(json['editSubtitleBox'], false),
    panelX: _asDouble(json['panelX'], 24),
    panelY: _asDouble(json['panelY'], 24),
    panelWidth: _asDouble(
      json['panelWidth'],
      560,
    ).clamp(panelMinWidth, panelMaxWidth),
    panelHeight: _asDouble(
      json['panelHeight'],
      720,
    ).clamp(panelMinHeight, panelMaxHeight),
    followWindowTitle: _asString(json['followWindowTitle'], ''),
    subtitleBox: SubtitleBox.fromJson(_asMap(json['subtitleBox'])),
    style: SubtitleStyle.fromJson(_asMap(json['style'])),
    preprocess: PreprocessSettings.fromJson(_asMap(json['preprocess'])),
    pipeline: PipelineSettings.fromJson(_asMap(json['pipeline'])),
    engines: EngineSettings.fromJson(_asMap(json['engines'])),
    transparency: _asEnum(
      json['transparency'],
      TransparencyMode.values,
      TransparencyMode.compositor,
    ),
    colorKey: _asInt(json['colorKey'], 0xFF00FF),
    startInConfigMode: _asBool(json['startInConfigMode'], true),
    passthroughInConfig: _asBool(json['passthroughInConfig'], true),
    hotkeyToggleConfig: _asString(json['hotkeyToggleConfig'], 'ctrl+alt+T'),
    hotkeyPause: _asString(json['hotkeyPause'], 'ctrl+alt+P'),
    hotkeyHide: _asString(json['hotkeyHide'], 'ctrl+alt+H'),
  );
}

// ------------------------------------------------- lectores JSON defensivos

Map<String, dynamic> _asMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

int _asInt(Object? value, int fallback) {
  if (value is int) return value;
  if (value is double && value.isFinite) return value.round();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double _asDouble(Object? value, double fallback) {
  if (value is double) return value.isFinite ? value : fallback;
  if (value is int) return value.toDouble();
  if (value is String) {
    final double? parsed = double.tryParse(value);
    if (parsed != null && parsed.isFinite) return parsed;
  }
  return fallback;
}

bool _asBool(Object? value, bool fallback) {
  if (value is bool) return value;
  if (value is String) {
    if (value.toLowerCase() == 'true') return true;
    if (value.toLowerCase() == 'false') return false;
  }
  return fallback;
}

String _asString(Object? value, String fallback) =>
    value is String ? value : fallback;

T _asEnum<T extends Enum>(Object? value, List<T> values, T fallback) {
  if (value is String) {
    for (final T candidate in values) {
      if (candidate.name == value) return candidate;
    }
  }
  return fallback;
}

int _colorToInt(Color color) {
  int channel(double v) => (v * 255.0).round().clamp(0, 255);
  return (channel(color.a) << 24) |
      (channel(color.r) << 16) |
      (channel(color.g) << 8) |
      channel(color.b);
}

Color _intToColor(Object? value, int fallback) =>
    Color(_asInt(value, fallback));

/// Expuesto para la interfaz, que necesita serializar colores del selector.
int colorToArgbInt(Color color) => _colorToInt(color);
