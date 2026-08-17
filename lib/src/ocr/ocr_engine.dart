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
    final String line = _stripInvisible(rawLine)
        .replaceAll(_horizontalSpace, ' ')
        .trim();
    if (line.isEmpty) continue;

    // Descarta líneas sin contenido real: solo signos de puntuación o ruido.
    final String meaningful = line.replaceAll(_nonAlphanumeric, '');
    if (meaningful.isEmpty) continue;
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
