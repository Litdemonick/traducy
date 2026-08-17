import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../core/logx.dart';
import 'win32_ffi.dart' as w;

const String _flutterWindowClass = 'FLUTTER_RUNNER_WIN32_WINDOW';

/// Operaciones nativas sobre la propia ventana del overlay.
///
/// Todo aquí es "mejor esfuerzo": si una llamada de Windows falla, la app sigue
/// funcionando con menos prestaciones (por ejemplo sin excluirse de la captura)
/// en lugar de caerse.
class OverlayNative {
  int _hwnd = 0;
  bool _excludedFromCapture = false;

  /// Handle de nuestra ventana. Se localiza por clase + PID propio, no por
  /// título: así no importa que el usuario o el sistema cambien el título.
  int get hwnd {
    if (_hwnd != 0 && w.isWindow(_hwnd) != 0) return _hwnd;
    _hwnd = _findOwnWindow();
    return _hwnd;
  }

  int _findOwnWindow() {
    final int myPid = w.getCurrentProcessId();
    final Pointer<Utf16> className = _flutterWindowClass.toNativeUtf16();
    final Pointer<Uint32> pidOut = calloc<Uint32>();
    try {
      int found = 0;
      int cursor = 0;
      // Puede haber más de una ventana con esa clase si conviven varias apps
      // Flutter; nos quedamos con la que pertenece a este proceso.
      while (true) {
        cursor = w.findWindowEx(w.kNull, cursor, className, nullptr);
        if (cursor == 0) break;
        w.getWindowThreadProcessId(cursor, pidOut);
        if (pidOut.value == myPid) {
          found = cursor;
          break;
        }
      }
      if (found == 0) log.w('overlay', 'No se encontró la ventana propia');
      return found;
    } catch (e, st) {
      log.e('overlay', 'Fallo localizando la ventana propia', e, st);
      return 0;
    } finally {
      calloc.free(className);
      calloc.free(pidOut);
    }
  }

  /// Rectángulo de la ventana en píxeles físicos de pantalla. Es la pieza que
  /// permite convertir coordenadas lógicas de Flutter a coordenadas de captura.
  ({int left, int top, int right, int bottom})? windowRect() {
    final int h = hwnd;
    if (h == 0) return null;
    final Pointer<w.Rect> r = calloc<w.Rect>();
    try {
      if (w.getWindowRect(h, r) == 0) return null;
      return (
        left: r.ref.left,
        top: r.ref.top,
        right: r.ref.right,
        bottom: r.ref.bottom,
      );
    } finally {
      calloc.free(r);
    }
  }

  /// Excluye la ventana de cualquier captura de pantalla. Sin esto, el overlay
  /// se leería a sí mismo y el OCR entraría en un bucle traduciendo sus propios
  /// subtítulos.
  bool excludeFromCapture(bool exclude) {
    final int h = hwnd;
    if (h == 0) return false;
    final int result = w.setWindowDisplayAffinity(
      h,
      exclude ? w.wdaExcludeFromCapture : w.wdaNone,
    );
    _excludedFromCapture = result != 0 && exclude;
    if (result == 0 && exclude) {
      log.w(
        'overlay',
        'SetWindowDisplayAffinity no disponible (requiere Windows 10 2004+). '
            'Mantén la caja de subtítulos fuera de la zona de captura.',
      );
    }
    return _excludedFromCapture;
  }

  bool get isExcludedFromCapture => _excludedFromCapture;

  /// Estilo base: ventana por capas (necesario para transparencia y para el
  /// modo de color clave).
  ///
  /// A propósito **no** se pone `WS_EX_TOOLWINDOW`: quitaría la ventana de la
  /// barra de tareas y de Alt+Tab, y entonces no habría forma de minimizarla ni
  /// de recuperarla si los atajos globales fallan.
  void applyOverlayStyles() {
    final int h = hwnd;
    if (h == 0) return;
    final int current = w.getWindowLongPtr(h, w.gwlExStyle);
    // WS_EX_APPWINDOW es obligatorio: sin él, activar WS_EX_NOACTIVATE saca la
    // ventana de la barra de tareas, y el botón aparecía y desaparecía cada vez
    // que el cursor entraba o salía del panel.
    final int desired = current | w.wsExLayered | w.wsExAppWindow;
    if (desired != current) {
      w.setWindowLongPtr(h, w.gwlExStyle, desired);
    }
  }

  /// Conmuta entre los dos modos de la ventana.
  ///
  /// `interactive` (configuración): la ventana recibe clics y **foco de
  /// teclado**, imprescindible para escribir en los campos de API key.
  /// No interactivo (directo): los clics atraviesan hacia el juego y la ventana
  /// nunca roba el foco, que es lo que evita minimizados fantasma al jugar.
  ///
  /// `window_manager` ofrece `setIgnoreMouseEvents`; esto es el respaldo nativo
  /// y se aplica en paralelo para que el estado quede consistente aunque el
  /// plugin falle.
  /// Deja pasar los clics hacia lo que hay debajo, o los captura.
  ///
  /// Este es el conmutador rápido: se llama muchas veces por segundo según dónde
  /// esté el cursor. Toca **solo** `WS_EX_TRANSPARENT`, que no afecta ni al foco
  /// ni a la barra de tareas, y por eso puede cambiar tan a menudo sin efectos
  /// visibles.
  ///
  /// Devuelve `false` si no hay ventana localizada, para que quien llame pueda
  /// recurrir al plugin como respaldo.
  bool setClickThrough(bool enabled) {
    final int h = hwnd;
    if (h == 0) return false;
    final int current = w.getWindowLongPtr(h, w.gwlExStyle);
    final int updated = enabled
        ? current | w.wsExTransparent
        : current & ~w.wsExTransparent;
    if (updated != current) {
      w.setWindowLongPtr(h, w.gwlExStyle, updated);
    }
    return true;
  }

  /// Permite o impide que la ventana tome el foco del teclado.
  ///
  /// Va aparte del anterior y **solo se llama al cambiar de modo**, nunca desde
  /// el temporizador. `WS_EX_NOACTIVATE` hace que el shell reevalúe la ventana,
  /// y cambiarlo continuamente es lo que hacía parpadear el botón de la barra de
  /// tareas. En modo juego interesa activo (el overlay no debe robar el foco);
  /// en configuración, desactivado, o no se podría escribir una API key.
  void setFocusable(bool focusable) {
    final int h = hwnd;
    if (h == 0) return;
    final int current = w.getWindowLongPtr(h, w.gwlExStyle);
    int updated = current | w.wsExLayered | w.wsExAppWindow;
    if (focusable) {
      updated &= ~w.wsExNoActivate;
    } else {
      updated |= w.wsExNoActivate;
    }
    if (updated != current) {
      w.setWindowLongPtr(h, w.gwlExStyle, updated);
      log.d('overlay', 'Foco de teclado: ${focusable ? 'sí' : 'no'}');
    }
  }

  /// Coloca la ventana usando píxeles físicos.
  ///
  /// Se hace por FFI y no con `window_manager` porque este último trabaja en
  /// píxeles lógicos: con varios monitores a escalados distintos, la conversión
  /// deja la ventana descuadrada respecto al escritorio virtual.
  bool setBoundsPhysical({
    required int left,
    required int top,
    required int width,
    required int height,
  }) {
    final int h = hwnd;
    if (h == 0) return false;
    final int ok = w.setWindowPos(
      h,
      w.hwndTopmost,
      left,
      top,
      width,
      height,
      w.swpNoActivate | w.swpShowWindow,
    );
    if (ok == 0) log.w('overlay', 'SetWindowPos falló');
    return ok != 0;
  }

  /// Reafirma "siempre visible". Algunos juegos se ponen por encima al ganar
  /// foco, así que esto se vuelve a llamar periódicamente.
  void bringToTop() {
    final int h = hwnd;
    if (h == 0) return;
    w.setWindowPos(
      h,
      w.hwndTopmost,
      0,
      0,
      0,
      0,
      w.swpNoMove | w.swpNoSize | w.swpNoActivate,
    );
  }

  /// Transparencia por color clave: todo píxel del color indicado se vuelve
  /// invisible. Es el modo compatible para equipos donde la composición DWM no
  /// da transparencia real.
  bool applyColorKey(int rgbColorKey) {
    final int h = hwnd;
    if (h == 0) return false;
    applyOverlayStyles();
    // Windows espera COLORREF = 0x00BBGGRR, al contrario que el 0xRRGGBB de Dart.
    final int r = (rgbColorKey >> 16) & 0xFF;
    final int g = (rgbColorKey >> 8) & 0xFF;
    final int b = rgbColorKey & 0xFF;
    final int colorRef = (b << 16) | (g << 8) | r;
    final int ok = w.setLayeredWindowAttributes(
      h,
      colorRef,
      255,
      w.lwaColorKey,
    );
    if (ok == 0) log.w('overlay', 'SetLayeredWindowAttributes falló');
    return ok != 0;
  }

  /// Quita el color clave y vuelve a alfa completo (modo compositor).
  void clearColorKey() {
    final int h = hwnd;
    if (h == 0) return;
    w.setLayeredWindowAttributes(h, 0, 255, w.lwaAlpha);
  }
}

/// Posición del cursor en píxeles físicos de pantalla, o `null` si Windows no
/// la devuelve (ocurre durante el bloqueo de sesión).
({int x, int y})? cursorPosition() {
  final Pointer<w.Point> point = calloc<w.Point>();
  try {
    if (w.getCursorPos(point) == 0) return null;
    return (x: point.ref.x, y: point.ref.y);
  } catch (_) {
    return null;
  } finally {
    calloc.free(point);
  }
}

/// `true` si algún botón principal del ratón está pulsado ahora mismo.
///
/// Se consulta para no cambiar el modo de la ventana en mitad de un arrastre:
/// hacerlo cortaría el gesto a medias y la caja se quedaría a medio mover.
bool isMouseButtonDown() {
  try {
    // El bit alto indica "pulsado en este momento".
    const int pressedMask = 0x8000;
    return (w.getAsyncKeyState(w.vkLButton) & pressedMask) != 0 ||
        (w.getAsyncKeyState(w.vkRButton) & pressedMask) != 0;
  } catch (_) {
    // Ante la duda se asume pulsado: es el lado seguro, porque solo retrasa el
    // cambio de modo en lugar de romper un arrastre.
    return true;
  }
}

/// Una ventana de otro programa, candidata a ser el objetivo de la captura.
class ForeignWindow {
  const ForeignWindow({
    required this.hwnd,
    required this.title,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final int hwnd;
  final String title;
  final int left;
  final int top;
  final int width;
  final int height;

  @override
  String toString() => '$title (${width}x$height)';
}

// EnumWindows necesita un puntero a función estático, de modo que el
// acumulador tiene que vivir a nivel de librería. Solo se usa desde el isolate
// de UI y de forma síncrona dentro de listTopLevelWindows(), así que no hay
// riesgo de acceso concurrente.
final List<ForeignWindow> _enumAccumulator = <ForeignWindow>[];
int _ownPid = 0;

int _enumCallback(int hwnd, int lParam) {
  try {
    if (w.isWindowVisible(hwnd) == 0) return 1;
    if (w.isIconic(hwnd) != 0) return 1;

    final Pointer<Uint32> pid = calloc<Uint32>();
    try {
      w.getWindowThreadProcessId(hwnd, pid);
      // Nunca ofrecer nuestra propia ventana como objetivo de captura.
      if (pid.value == _ownPid) {
        return 1;
      }
    } finally {
      calloc.free(pid);
    }

    final Pointer<Utf16> buffer = calloc<Uint16>(512).cast<Utf16>();
    final Pointer<w.Rect> rect = calloc<w.Rect>();
    try {
      final int len = w.getWindowText(hwnd, buffer, 512);
      if (len <= 0) return 1;
      final String title = buffer.toDartString(length: len).trim();
      if (title.isEmpty) return 1;

      if (w.getWindowRect(hwnd, rect) == 0) return 1;
      final int width = rect.ref.right - rect.ref.left;
      final int height = rect.ref.bottom - rect.ref.top;
      // Descarta ventanas herramienta invisibles de 1x1 y similares.
      if (width < 120 || height < 80) return 1;

      _enumAccumulator.add(
        ForeignWindow(
          hwnd: hwnd,
          title: title,
          left: rect.ref.left,
          top: rect.ref.top,
          width: width,
          height: height,
        ),
      );
    } finally {
      calloc.free(buffer);
      calloc.free(rect);
    }
  } catch (_) {
    // Una ventana problemática no debe interrumpir la enumeración.
  }
  return 1; // continuar
}

/// Lista las ventanas visibles de otros programas, ordenadas por título.
List<ForeignWindow> listTopLevelWindows() {
  _enumAccumulator.clear();
  try {
    _ownPid = w.getCurrentProcessId();
    final Pointer<NativeFunction<w.EnumWindowsProcNative>> proc =
        Pointer.fromFunction<w.EnumWindowsProcNative>(_enumCallback, 1);
    w.enumWindows(proc, 0);
  } catch (e, st) {
    log.e('overlay', 'EnumWindows falló', e, st);
  }
  final List<ForeignWindow> result = List<ForeignWindow>.of(_enumAccumulator);
  _enumAccumulator.clear();
  result.sort(
    (ForeignWindow a, ForeignWindow b) =>
        a.title.toLowerCase().compareTo(b.title.toLowerCase()),
  );
  return result;
}

/// Rectángulo actual de una ventana ajena, o `null` si ya no existe.
/// Se usa para que la región de captura siga a la ventana si el usuario la mueve.
({int left, int top, int width, int height})? foreignWindowRect(int hwnd) {
  if (hwnd == 0 || w.isWindow(hwnd) == 0) return null;
  if (w.isIconic(hwnd) != 0) return null;
  final Pointer<w.Rect> r = calloc<w.Rect>();
  try {
    if (w.getWindowRect(hwnd, r) == 0) return null;
    return (
      left: r.ref.left,
      top: r.ref.top,
      width: r.ref.right - r.ref.left,
      height: r.ref.bottom - r.ref.top,
    );
  } finally {
    calloc.free(r);
  }
}
