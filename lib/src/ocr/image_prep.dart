import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Petición de preprocesado. Solo contiene datos planos para poder viajar a
/// otro isolate sin sorpresas.
class PrepRequest {
  const PrepRequest({
    required this.bgra,
    required this.width,
    required this.height,
    required this.scale,
    required this.grayscale,
    required this.contrast,
    required this.threshold,
    required this.invert,
    required this.denoise,
  });

  final Uint8List bgra;
  final int width;
  final int height;
  final double scale;
  final bool grayscale;
  final double contrast;
  final int threshold;
  final bool invert;
  final bool denoise;
}

class PrepResult {
  const PrepResult({required this.png, required this.signature});

  /// PNG listo para entrar en el OCR.
  final Uint8List png;

  /// Huella de 32x32 en escala de grises. Comparando dos huellas consecutivas
  /// se detecta si la imagen cambió, y así se evita repetir OCR y traducción
  /// sobre un diálogo que sigue siendo el mismo.
  final Uint8List signature;
}

const int signatureSide = 32;
const int _signatureLength = signatureSide * signatureSide;

/// Calcula la huella muestreando directamente el BGRA original.
///
/// Se hace sobre los bytes crudos (sin pasar por package:image) porque es la
/// operación que corre en *todos* los fotogramas, incluidos los que luego se
/// descartan: cuanto más barata, mejor.
///
/// Cada celda de la rejilla es el **promedio** de una submuestra de 4x4 puntos
/// repartidos por su interior, no un único píxel del centro. La diferencia
/// importa: los trazos de la letra son finos, y con un solo punto por celda una
/// línea de diálogo nueva puede caer entera entre los puntos muestreados y
/// pasar por "sin cambios". Promediando, cualquier texto que entre en la celda
/// altera su valor.
Uint8List computeSignature(Uint8List bgra, int width, int height) {
  final Uint8List out = Uint8List(_signatureLength);
  if (width <= 0 || height <= 0) return out;

  // 4x4 = 16 muestras por celda, 16384 lecturas en total. Barato incluso para
  // una zona de pantalla completa, y corre dentro del isolate de preparación.
  const int subSamples = 4;

  for (int gy = 0; gy < signatureSide; gy++) {
    final int outBase = gy * signatureSide;
    for (int gx = 0; gx < signatureSide; gx++) {
      int sum = 0;
      for (int sy = 0; sy < subSamples; sy++) {
        // Puntos repartidos dentro de la celda, sin tocar sus bordes: así la
        // huella es estable ante desplazamientos de un píxel.
        final int py =
            (((gy * subSamples + sy) * 2 + 1) * height) ~/
            (signatureSide * subSamples * 2);
        final int rowBase = py.clamp(0, height - 1) * width * 4;
        for (int sx = 0; sx < subSamples; sx++) {
          final int px =
              (((gx * subSamples + sx) * 2 + 1) * width) ~/
              (signatureSide * subSamples * 2);
          final int i = rowBase + px.clamp(0, width - 1) * 4;
          final int b = bgra[i];
          final int g = bgra[i + 1];
          final int r = bgra[i + 2];
          // Luminancia entera aproximada (coeficientes BT.601 escalados x1000).
          sum += (r * 299 + g * 587 + b * 114) ~/ 1000;
        }
      }
      out[outBase + gx] = (sum ~/ (subSamples * subSamples)).clamp(0, 255);
    }
  }
  return out;
}

/// Porcentaje de la huella que ha cambiado de forma apreciable (0-100).
///
/// Es la medida que decide si merece la pena repetir el OCR, y no la media
/// absoluta, porque la media diluye justo lo que interesa: un renglón de
/// diálogo nuevo en una franja ancha altera mucho unas pocas celdas y nada el
/// resto, así que su media sale en torno a 2 sobre 255 y cualquier umbral
/// razonable la descartaría. Contando *cuántas* celdas cambiaron, ese mismo
/// renglón sale como un 5% de la zona y se detecta sin confundirlo con el ruido
/// de fondo, que mueve muchas celdas pero muy poco.
///
/// [levelDelta] es lo que debe moverse una celda para contar. Por debajo de ~10
/// niveles está el ruido de la compresión de vídeo, el suavizado de bordes y los
/// degradados animados.
double signatureChangePercent(Uint8List a, Uint8List b, {int levelDelta = 10}) {
  if (a.length != b.length || a.isEmpty) return 100;
  int changed = 0;
  for (int i = 0; i < a.length; i++) {
    final int d = a[i] - b[i];
    if ((d < 0 ? -d : d) > levelDelta) changed++;
  }
  return changed * 100 / a.length;
}

/// `true` si la huella es prácticamente plana: la zona no ve nada aprovechable.
///
/// Pasa con los juegos en pantalla completa exclusiva (la captura sale negra),
/// con contenido protegido, o con una zona colocada sobre un fondo liso. Sin
/// esta comprobación el síntoma es desconcertante: la aplicación repite "sin
/// cambios" indefinidamente, que es literalmente cierto y no explica nada.
bool isSignatureFlat(Uint8List signature, {int spread = 6}) {
  if (signature.isEmpty) return true;
  int min = 255;
  int max = 0;
  for (final int value in signature) {
    if (value < min) min = value;
    if (value > max) max = value;
  }
  return (max - min) <= spread;
}

/// Diferencia media absoluta entre dos huellas, en la escala 0-255.
///
/// Se conserva para el panel de diagnóstico: como número que mirar es más
/// intuitivo que un porcentaje de celdas.
double signatureDistance(Uint8List a, Uint8List b) {
  if (a.length != b.length || a.isEmpty) return 255;
  int sum = 0;
  for (int i = 0; i < a.length; i++) {
    final int d = a[i] - b[i];
    sum += d < 0 ? -d : d;
  }
  return sum / a.length;
}

/// Punto de entrada del isolate: convierte un fotograma crudo en un PNG
/// optimizado para OCR. Es función de nivel superior porque `Isolate.run`
/// necesita poder enviarla.
PrepResult preprocessFrame(PrepRequest request) {
  final Uint8List signature = computeSignature(
    request.bgra,
    request.width,
    request.height,
  );

  img.Image image = img.Image.fromBytes(
    width: request.width,
    height: request.height,
    bytes: request.bgra.buffer,
    numChannels: 4,
    order: img.ChannelOrder.bgra,
  );

  // El orden importa: suavizar antes de binarizar evita que el ruido se
  // convierta en manchas negras que el OCR interpreta como caracteres.
  if (request.denoise) {
    image = img.gaussianBlur(image, radius: 1);
  }
  if (request.grayscale) {
    image = img.grayscale(image);
  }
  if ((request.contrast - 1.0).abs() > 0.01) {
    image = img.adjustColor(image, contrast: request.contrast);
  }
  if (request.threshold > 0) {
    image = img.luminanceThreshold(
      image,
      threshold: request.threshold / 255.0,
      outputColor: false,
    );
  }
  if (request.invert) {
    image = img.invert(image);
  }
  if (request.scale > 1.01) {
    final int targetWidth = (request.width * request.scale).round();
    final int targetHeight = (request.height * request.scale).round();
    // Techo de seguridad: una región enorme escalada x4 puede agotar la
    // memoria y colgar el isolate.
    if (targetWidth <= 6000 && targetHeight <= 6000) {
      image = img.copyResize(
        image,
        width: targetWidth,
        height: targetHeight,
        interpolation: img.Interpolation.cubic,
      );
    }
  }

  // level 1: comprimir rápido. El PNG solo viaja por una tubería a Tesseract,
  // no se guarda, así que el tamaño importa mucho menos que la latencia.
  final Uint8List png = img.encodePng(image, level: 1, singleFrame: true);
  return PrepResult(png: png, signature: signature);
}
