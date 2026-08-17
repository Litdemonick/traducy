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
Uint8List computeSignature(Uint8List bgra, int width, int height) {
  final Uint8List out = Uint8List(_signatureLength);
  if (width <= 0 || height <= 0) return out;

  for (int gy = 0; gy < signatureSide; gy++) {
    // Se muestrea el centro de cada celda de la rejilla, no la esquina: así la
    // huella es estable ante desplazamientos de un píxel.
    final int sy = (((gy * 2 + 1) * height) ~/ (signatureSide * 2)).clamp(
      0,
      height - 1,
    );
    final int rowBase = sy * width * 4;
    final int outBase = gy * signatureSide;
    for (int gx = 0; gx < signatureSide; gx++) {
      final int sx = (((gx * 2 + 1) * width) ~/ (signatureSide * 2)).clamp(
        0,
        width - 1,
      );
      final int i = rowBase + sx * 4;
      final int b = bgra[i];
      final int g = bgra[i + 1];
      final int r = bgra[i + 2];
      // Luminancia entera aproximada (coeficientes BT.601 escalados x1000).
      out[outBase + gx] = ((r * 299 + g * 587 + b * 114) ~/ 1000).clamp(0, 255);
    }
  }
  return out;
}

/// Diferencia media absoluta entre dos huellas, en la escala 0-255.
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
