import 'dart:typed_data';

class OcrResult {
  const OcrResult({required this.text, this.durationMs = 0});

  final String text;
  final int durationMs;

  bool get isEmpty => text.trim().isEmpty;
}

abstract class OcrEngine {
  String get id;
  String get displayName;

  /// Reconoce el texto de un PNG ya preprocesado.
  Future<OcrResult> recognize(Uint8List png, {required Duration timeout});

  /// Comprueba que el motor está instalado y configurado. Devuelve `null` si
  /// todo está bien, o un mensaje accionable para el usuario si no.
  Future<String?> checkAvailability();

  void dispose() {}
}

final RegExp _horizontalSpace = RegExp(r'[ \t]+');
final RegExp _nonAlphanumeric = RegExp(r'[^\p{L}\p{N}]', unicode: true);
final RegExp _digit = RegExp(r'\p{N}', unicode: true);

/// Cierres de frase, incluidos los de puntuación asiática de ancho completo.
const String _sentenceEndChars = '.!?:;…”」。！？';

/// Quita caracteres de control y marcas invisibles (BOM, marcas de dirección)
/// que el OCR cuela a veces y que rompen las comparaciones de texto.
///
/// Se filtra por punto de código en lugar de con una expresión regular: meter
/// bytes de control literales en el código fuente es una fuente de errores
/// silenciosos al editarlo.
String _stripInvisible(String input) {
  final StringBuffer out = StringBuffer();
  for (final int codeUnit in input.codeUnits) {
    final bool isControl =
        codeUnit < 0x20 && codeUnit != 0x09; // se conserva el tabulador
    final bool isDelete = codeUnit == 0x7F;
    final bool isZeroWidth = codeUnit >= 0x200B && codeUnit <= 0x200F;
    final bool isBom = codeUnit == 0xFEFF;
    if (isControl || isDelete || isZeroWidth || isBom) continue;
    out.writeCharCode(codeUnit);
  }
  return out.toString();
}

/// Rango de escrituras que no separan palabras con espacios: kana, kanji,
/// hangul, puntuacion de ancho completo y sus formas de anchura media.
bool _isCjk(int codeUnit) =>
    (codeUnit >= 0x3000 && codeUnit <= 0x30FF) || // puntuacion CJK y kana
    (codeUnit >= 0x3400 && codeUnit <= 0x4DBF) || // ideogramas, extension A
    (codeUnit >= 0x4E00 && codeUnit <= 0x9FFF) || // ideogramas comunes
    (codeUnit >= 0xAC00 && codeUnit <= 0xD7AF) || // hangul
    (codeUnit >= 0xF900 &&
        codeUnit <= 0xFAFF) || // ideogramas de compatibilidad
    (codeUnit >= 0xFF00 && codeUnit <= 0xFF9F); // formas anchas y kana medio

/// Junta lo que Tesseract separo sin motivo.
///
/// Con `-l jpn`, Tesseract mete un espacio entre casi todos los caracteres, y
/// `preserve_interword_spaces` los conserva porque para el alfabeto latino esos
/// espacios si son informacion. El resultado es un texto tipo "こ ん に ち は"
/// que el traductor no reconoce como palabras: traduce caracter por caracter y
/// devuelve un galimatias. Aqui se quita el espacio solo cuando lo que hay a
/// cada lado es CJK, asi que un texto mezclado ("HP 100 の 回復") conserva los
/// espacios que si hacen falta.
String _joinCjkSpacing(String line) {
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < line.length; i++) {
    final int unit = line.codeUnitAt(i);
    final bool isSpace = unit == 0x20 || unit == 0x09;
    if (isSpace && i > 0 && i + 1 < line.length) {
      if (_isCjk(line.codeUnitAt(i - 1)) && _isCjk(line.codeUnitAt(i + 1))) {
        continue;
      }
    }
    out.writeCharCode(unit);
  }
  return out.toString();
}

/// Simbolos que el OCR inventa en los bordes del recorte y en las texturas del
/// fondo. Sueltos no significan nada, pero llegan en cantidad.
const String _noiseChars = r"|_~^`'\/<>*+=[]{}():;,.-·—–…";

/// `true` si la linea es sobre todo ruido.
///
/// Es la defensa contra el sintoma de "muchos signos y cosas raras": una franja
/// con texto japones y un fondo con textura produce lineas enteras de barras y
/// puntos junto al texto de verdad. Traducirlas gasta cuota y ensucia el
/// subtitulo, asi que se descartan antes.
bool _isMostlyNoise(String line) {
  int noise = 0;
  int meaningful = 0;
  for (int i = 0; i < line.length; i++) {
    final String character = line[i];
    if (character == ' ' || character == '\t') continue;
    if (_noiseChars.contains(character)) {
      noise++;
    } else {
      meaningful++;
    }
  }
  if (meaningful == 0) return true;
  // Un signo por cada caracter con sentido ya es demasiado: el texto normal
  // lleva puntuacion, pero no en esa proporcion.
  return noise > meaningful;
}

bool _endsSentence(String line) =>
    line.isNotEmpty && _sentenceEndChars.contains(line[line.length - 1]);

/// Limpia la salida cruda del OCR.
///
/// Los motores de OCR sobre capturas de juego producen basura previsible:
/// líneas de un solo símbolo por artefactos del borde, espacios raros y saltos
/// de línea de más. Filtrar aquí evita gastar traducciones en ruido.
String normalizeOcrText(String raw) {
  if (raw.trim().isEmpty) return '';

  final List<String> keptLines = <String>[];
  for (final String rawLine in raw.split('\n')) {
    final String line = _joinCjkSpacing(
      _stripInvisible(rawLine).replaceAll(_horizontalSpace, ' ').trim(),
    ).trim();
    if (line.isEmpty) continue;

    // Descarta líneas sin contenido real: solo signos de puntuación o ruido.
    final String meaningful = line.replaceAll(_nonAlphanumeric, '');
    if (meaningful.isEmpty) continue;
    if (_isMostlyNoise(line)) continue;
    // Una letra suelta casi siempre es un artefacto del borde del recorte;
    // un dígito suelto sí puede ser información válida (un contador, un daño).
    if (meaningful.length == 1 && !_digit.hasMatch(meaningful)) continue;

    keptLines.add(line);
  }

  if (keptLines.isEmpty) return '';

  // Une las líneas en un párrafo: los diálogos vienen partidos por el ancho de
  // la caja del juego, no por gramática, y traducir línea a línea da resultados
  // bastante peores que traducir la frase completa.
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < keptLines.length; i++) {
    if (i > 0) {
      // Si la línea anterior no cierra frase, era un corte por ancho: se une
      // con espacio. Si la cierra, se respeta el salto de línea.
      buffer.write(_endsSentence(keptLines[i - 1]) ? '\n' : ' ');
    }
    buffer.write(keptLines[i]);
  }

  return buffer.toString().trim();
}

/// Clave de comparación entre fotogramas: ignora diferencias que no cambian el
/// significado, para no retraducir lo mismo cuando el OCR titubea con un signo.
String ocrComparisonKey(String text) =>
    text.toLowerCase().replaceAll(_nonAlphanumeric, '');
