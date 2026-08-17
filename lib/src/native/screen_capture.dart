import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../core/failures.dart';
import '../core/logx.dart';
import 'win32_ffi.dart' as w;

/// Un fotograma capturado, en BGRA de 8 bits por canal y orden top-down.
class CapturedFrame {
  const CapturedFrame({
    required this.bgra,
    required this.width,
    required this.height,
  });

  final Uint8List bgra;
  final int width;
  final int height;
}

/// Captura una región de la pantalla con GDI (BitBlt).
///
/// Los recursos GDI (DC de memoria, bitmap y buffer nativo) se reutilizan
/// mientras el tamaño no cambie: crear y destruir un bitmap en cada fotograma
/// es la vía rápida a una fuga de handles GDI, y a 3 capturas por segundo eso
/// se nota en horas de juego.
class ScreenCapture {
  int _memDC = 0;
  int _bitmap = 0;
  int _oldObject = 0;
  Pointer<Uint8> _pixels = nullptr;
  Pointer<Uint8> _headerBuffer = nullptr;
  int _width = 0;
  int _height = 0;
  bool _disposed = false;

  static const int _maxSide = 8192;

  /// Límites del escritorio virtual completo, en píxeles físicos.
  static ({int left, int top, int width, int height}) virtualScreenBounds() {
    final int left = w.getSystemMetrics(w.smXVirtualScreen);
    final int top = w.getSystemMetrics(w.smYVirtualScreen);
    int width = w.getSystemMetrics(w.smCxVirtualScreen);
    int height = w.getSystemMetrics(w.smCyVirtualScreen);
    // Si el sistema devuelve 0 (caso raro con drivers en transición) caemos a
    // la pantalla principal para no dejar la app sin área válida.
    if (width <= 0) width = w.getSystemMetrics(w.smCxScreen);
    if (height <= 0) height = w.getSystemMetrics(w.smCyScreen);
    return (left: left, top: top, width: width, height: height);
  }

  /// Captura el rectángulo indicado en píxeles físicos de pantalla.
  ///
  /// Devuelve `null` si la región es inválida o si GDI falla, en lugar de
  /// lanzar: el pipeline trata un fotograma perdido como algo normal.
  CapturedFrame? capture({
    required int x,
    required int y,
    required int width,
    required int height,
  }) {
    if (_disposed) return null;
    if (width <= 0 || height <= 0) return null;
    if (width > _maxSide || height > _maxSide) {
      log.w('capture', 'Región demasiado grande: ${width}x$height');
      return null;
    }

    final int screenDC = w.getDC(w.kNull);
    if (screenDC == 0) {
      log.w('capture', 'GetDC(NULL) devolvió 0');
      return null;
    }

    try {
      if (!_ensureResources(screenDC, width, height)) return null;

      // CAPTUREBLT incluye ventanas por capas superpuestas, necesario para
      // juegos en ventana sin bordes con overlays encima.
      final int ok = w.bitBlt(
        _memDC,
        0,
        0,
        width,
        height,
        screenDC,
        x,
        y,
        w.srccopy | w.captureblt,
      );
      if (ok == 0) {
        log.w('capture', 'BitBlt falló en ${x}x$y ${width}x$height');
        return null;
      }

      _writeHeader(width, height);
      final int lines = w.getDIBits(
        _memDC,
        _bitmap,
        0,
        height,
        _pixels,
        _headerBuffer,
        w.dibRgbColors,
      );
      if (lines == 0) {
        log.w('capture', 'GetDIBits no copió líneas');
        return null;
      }

      // Copia a memoria Dart: el buffer nativo se reutiliza en el siguiente
      // fotograma, así que no puede escapar de aquí por referencia.
      final Uint8List bytes = Uint8List.fromList(
        _pixels.asTypedList(width * height * 4),
      );
      return CapturedFrame(bgra: bytes, width: width, height: height);
    } catch (e, st) {
      log.e('capture', 'Excepción durante la captura', e, st);
      return null;
    } finally {
      w.releaseDC(w.kNull, screenDC);
    }
  }

  bool _ensureResources(int screenDC, int width, int height) {
    if (_memDC != 0 && _width == width && _height == height) return true;

    _releaseGdi();

    _memDC = w.createCompatibleDC(screenDC);
    if (_memDC == 0) {
      log.e('capture', 'CreateCompatibleDC falló');
      return false;
    }
    _bitmap = w.createCompatibleBitmap(screenDC, width, height);
    if (_bitmap == 0) {
      log.e('capture', 'CreateCompatibleBitmap falló para ${width}x$height');
      _releaseGdi();
      return false;
    }
    _oldObject = w.selectObject(_memDC, _bitmap);

    try {
      _pixels = calloc<Uint8>(width * height * 4);
      // 40 bytes de BITMAPINFOHEADER + espacio de sobra para la tabla de
      // colores que Windows puede escribir aunque en 32 bits no se use.
      _headerBuffer = calloc<Uint8>(sizeOf<w.BitmapInfoHeader>() + 256);
    } catch (e) {
      log.e('capture', 'Sin memoria para el buffer de captura', e);
      _releaseGdi();
      return false;
    }

    _width = width;
    _height = height;
    return true;
  }

  void _writeHeader(int width, int height) {
    final Pointer<w.BitmapInfoHeader> header = _headerBuffer
        .cast<w.BitmapInfoHeader>();
    header.ref
      ..biSize = sizeOf<w.BitmapInfoHeader>()
      ..biWidth = width
      // Altura negativa = filas de arriba a abajo, que es el orden que espera
      // package:image; con altura positiva la imagen sale del revés.
      ..biHeight = -height
      ..biPlanes = 1
      ..biBitCount = 32
      ..biCompression = w.biRgb
      ..biSizeImage = 0
      ..biXPelsPerMeter = 0
      ..biYPelsPerMeter = 0
      ..biClrUsed = 0
      ..biClrImportant = 0;
  }

  void _releaseGdi() {
    if (_memDC != 0 && _oldObject != 0) {
      w.selectObject(_memDC, _oldObject);
      _oldObject = 0;
    }
    if (_bitmap != 0) {
      w.deleteObject(_bitmap);
      _bitmap = 0;
    }
    if (_memDC != 0) {
      w.deleteDC(_memDC);
      _memDC = 0;
    }
    if (_pixels != nullptr) {
      calloc.free(_pixels);
      _pixels = nullptr;
    }
    if (_headerBuffer != nullptr) {
      calloc.free(_headerBuffer);
      _headerBuffer = nullptr;
    }
    _width = 0;
    _height = 0;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _releaseGdi();
  }
}

/// Comprueba si la captura funciona sobre la región dada. Un fotograma
/// completamente negro suele significar juego en pantalla completa exclusiva,
/// que GDI no puede leer.
StageFailure? diagnoseBlackFrame(CapturedFrame frame) {
  final Uint8List b = frame.bgra;
  int nonBlack = 0;
  // Muestreo cada 97 píxeles (número primo, evita alinearse con patrones).
  for (int i = 0; i < b.length; i += 4 * 97) {
    if (b[i] > 8 || b[i + 1] > 8 || b[i + 2] > 8) {
      nonBlack++;
      if (nonBlack > 3) return null;
    }
  }
  return StageFailure(
    Stage.capture,
    'La región capturada está en negro.',
    hint:
        'Los juegos en pantalla completa exclusiva no se pueden capturar. '
        'Cambia el juego a "ventana" o "pantalla completa en ventana".',
  );
}
