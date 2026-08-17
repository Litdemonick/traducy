import 'dart:io';
import 'dart:async';
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

import '../core/failures.dart';
import '../core/logx.dart';
import '../core/updater.dart';
import '../core/version.dart';
import '../models/languages.dart';
import '../models/settings.dart';
import '../models/settings_store.dart';
import '../native/overlay_native.dart';
import '../native/screen_capture.dart';
import '../ocr/ocr_engine.dart';
import '../ocr/tessdata_installer.dart';
import '../ocr/tesseract_ocr.dart';
import '../pipeline/pipeline.dart';
import '../translate/http_translators.dart';
import '../translate/translator.dart';
import '../ui/toasts.dart';

/// Estado de un motor comprobado: `null` en `issue` significa listo.
class EngineHealth {
  const EngineHealth({this.checking = false, this.issue, this.checkedAt});

  final bool checking;
  final String? issue;
  final DateTime? checkedAt;

  bool get isReady => !checking && issue == null && checkedAt != null;
  bool get hasProblem => !checking && issue != null;
}

/// Estado central de la aplicación.
///
/// Concentra los ajustes, los motores, el pipeline y el estado de la ventana en
/// un único sitio; la interfaz solo lee de aquí y llama a estos métodos. Así no
/// hay dos partes de la app con ideas distintas sobre la región de captura.
class AppController extends ChangeNotifier {
  AppController({SettingsStore? store})
    : _store = store ?? SettingsStore(),
      _overlay = OverlayNative();

  final SettingsStore _store;
  final OverlayNative _overlay;

  AppSettings _settings = const AppSettings();
  AppSettings get settings => _settings;

  TranslationPipeline? _pipeline;
  TranslationPipeline? get pipeline => _pipeline;

  // ------------------------------------------------------ estado de interfaz

  bool _configMode = true;

  /// Modo configuración: se ven los controles y los rectángulos, y la ventana
  /// captura el ratón. En modo directo solo se ve el subtítulo y los clics
  /// atraviesan hacia el juego.
  bool get configMode => _configMode;

  bool _subtitlesVisible = true;
  bool get subtitlesVisible => _subtitlesVisible;

  bool _ready = false;
  bool get isReady => _ready;

  String? _fatalError;
  String? get fatalError => _fatalError;

  // --------------------------------------------------- geometría de ventana

  Size _windowLogicalSize = Size.zero;
  double _devicePixelRatio = 1.0;
  ({int left, int top, int right, int bottom})? _windowPhysicalRect;

  Size get windowLogicalSize => _windowLogicalSize;
  double get devicePixelRatio => _devicePixelRatio;

  // ------------------------------------------------------- salud de motores

  EngineHealth _ocrHealth = const EngineHealth();
  EngineHealth _translatorHealth = const EngineHealth();
  EngineHealth get ocrHealth => _ocrHealth;
  EngineHealth get translatorHealth => _translatorHealth;

  List<String> _installedOcrLanguages = <String>[];
  List<String> get installedOcrLanguages => _installedOcrLanguages;

  List<ForeignWindow> _availableWindows = <ForeignWindow>[];
  List<ForeignWindow> get availableWindows => _availableWindows;

  int _followHwnd = 0;

  /// Desplazamiento de la región respecto a la esquina de la ventana seguida.
  /// Guardar el desplazamiento (y no coordenadas absolutas) es lo que permite
  /// que la zona acompañe al juego cuando el usuario lo mueve.
  int _followOffsetX = 0;
  int _followOffsetY = 0;

  Timer? _topmostTimer;
  Timer? _followTimer;
  Timer? _hitTestTimer;

  /// Zonas de la interfaz que deben recibir el ratón en modo configuración.
  /// La interfaz las publica en cada construcción.
  List<Rect> _interactiveRects = const <Rect>[];

  /// Último estado aplicado a la ventana, para no llamar a Windows en balde.
  bool? _appliedInteractive;

  /// Ventana apartada a la barra de tareas. Mientras lo esté, el temporizador
  /// de "siempre visible" no debe tocarla: la haría reaparecer sola.
  bool _minimized = false;
  bool get isMinimized => _minimized;

  // --------------------------------------------------------------- arranque

  Future<void> initialize() async {
    try {
      _settings = await _store.load();
      _configMode = _settings.startInConfigMode;

      await _positionWindowOverVirtualScreen();
      _overlay.applyOverlayStyles();
      _overlay.excludeFromCapture(true);
      await _applyInteractionMode();
      _applyTransparencyMode();

      _buildPipeline();
      _startKeepAliveTimers();

      _ready = true;
      _logStartupDiagnostics();
      notifyListeners();

      // Las comprobaciones de motores tocan red y disco: se lanzan después de
      // que la interfaz ya esté en pantalla para que el arranque sea inmediato.
      unawaited(refreshEngineHealth().then((_) => autoDetectSetup()));
      unawaited(refreshWindowList());
    } catch (e, st) {
      log.e('controller', 'Fallo al inicializar', e, st);
      _fatalError = 'No se pudo iniciar Traducy: $e';
      _ready = true;
      notifyListeners();
    }
  }

  /// Extiende la ventana sobre todo el escritorio virtual, en píxeles físicos.
  Future<void> _positionWindowOverVirtualScreen() async {
    final ({int left, int top, int width, int height}) bounds =
        ScreenCapture.virtualScreenBounds();
    if (bounds.width <= 0 || bounds.height <= 0) {
      log.w('controller', 'Dimensiones de escritorio inválidas');
      return;
    }
    // Si la ventana ya está exactamente donde debe (la coloca el arranque antes
    // de mostrarla), no se toca. Un redimensionado de más con el motor gráfico
    // ya en marcha es lo que hacía que la interfaz saliese estirada.
    final ({int left, int top, int right, int bottom})? current = _overlay
        .windowRect();
    if (current != null &&
        current.left == bounds.left &&
        current.top == bounds.top &&
        current.right - current.left == bounds.width &&
        current.bottom - current.top == bounds.height) {
      _windowPhysicalRect = current;
      return;
    }

    final bool placed = _overlay.setBoundsPhysical(
      left: bounds.left,
      top: bounds.top,
      width: bounds.width,
      height: bounds.height,
    );
    if (!placed) {
      // Respaldo por el plugin, en unidades lógicas.
      try {
        await windowManager.setBounds(
          Rect.fromLTWH(
            bounds.left.toDouble(),
            bounds.top.toDouble(),
            bounds.width.toDouble(),
            bounds.height.toDouble(),
          ),
        );
      } catch (e) {
        log.w('controller', 'No se pudo colocar la ventana: $e');
      }
    }
    _windowPhysicalRect = _overlay.windowRect();
  }

  /// Vuelca al registro el estado real de la ventana al arrancar.
  ///
  /// Si algo va mal con el overlay (no se encuentra la ventana, no hay
  /// transparencia, la geometría no cuadra), estos datos lo dicen de inmediato
  /// en la consola. Sin ellos, diagnosticar un overlay que "bloquea todo" es
  /// adivinar.
  void _logStartupDiagnostics() {
    final ({int left, int top, int width, int height}) screen =
        ScreenCapture.virtualScreenBounds();
    final ({int left, int top, int right, int bottom})? window = _overlay
        .windowRect();

    log.i(
      'diag',
      'Escritorio virtual: ${screen.width}x${screen.height} '
          'en (${screen.left},${screen.top})',
    );
    log.i(
      'diag',
      window == null
          ? 'VENTANA NO LOCALIZADA: sin control nativo del overlay'
          : 'Ventana: (${window.left},${window.top}) a '
                '(${window.right},${window.bottom})',
    );
    log.i(
      'diag',
      'Excluida de la captura: ${_overlay.isExcludedFromCapture ? 'sí' : 'no'}',
    );
    log.i(
      'diag',
      'Modo: ${_configMode ? 'configuración' : 'directo'} · '
          'clics al juego: ${_settings.passthroughInConfig ? 'selectivos' : 'no'}',
    );
  }

  /// Manda Traducy a segundo plano: la ventana se oculta por completo y solo
  /// queda el icono de la bandeja del sistema.
  ///
  /// Se usa `hide()` y no `minimize()` a propósito. Minimizar deja un botón en
  /// la barra de tareas de una ventana que ocupa todo el escritorio, y eso
  /// estorba; ocultarla la saca de en medio de verdad, y el icono de la bandeja
  /// es la vía de vuelta (clic izquierdo abre, derecho da opciones).
  Future<void> minimizeOverlay() async {
    try {
      _minimized = true;
      notifyListeners();
      // Fuera de la barra de tareas mientras está en segundo plano, para que no
      // aparezca duplicado junto al icono de la bandeja.
      await windowManager.setSkipTaskbar(true);
      await windowManager.hide();
      log.i(
        'controller',
        'En segundo plano. Clic en el icono de la bandeja o Ctrl+Alt+T '
            'para recuperarlo.',
      );
      toasts.info(
        'Traducy sigue funcionando en segundo plano',
        detail: 'Clic en su icono junto al reloj, o Ctrl+Alt+T, para volver.',
      );
    } catch (e) {
      log.w('controller', 'No se pudo pasar a segundo plano: $e');
      toasts.error(
        'No se pudo pasar a segundo plano',
        detail: 'Usa Ctrl+Alt+T para ocultar el panel mientras juegas.',
      );
      _minimized = false;
      notifyListeners();
    }
  }

  /// Trae Traducy de vuelta desde segundo plano.
  Future<void> restoreOverlay() async {
    try {
      await windowManager.setSkipTaskbar(false);
      if (await windowManager.isMinimized()) {
        await windowManager.restore();
      }
      await windowManager.show();
      // Al volver se reafirma la geometría y los estilos: mientras estaba
      // oculta pueden haber cambiado la resolución o el número de monitores.
      await _positionWindowOverVirtualScreen();
      _overlay.applyOverlayStyles();
      _overlay.excludeFromCapture(true);
      _appliedInteractive = null; // fuerza reaplicar el modo de ratón
      await _applyInteractionMode();
      _overlay.bringToTop();
    } catch (e) {
      log.w('controller', 'No se pudo restaurar la ventana: $e');
    } finally {
      _minimized = false;
      notifyListeners();
    }
  }

  void _startKeepAliveTimers() {
    // Algunos juegos se ponen por encima al ganar el foco; reafirmar "siempre
    // visible" cada pocos segundos mantiene el subtítulo a la vista.
    _topmostTimer?.cancel();
    _topmostTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_minimized) return;
      _overlay.bringToTop();
      final ({int left, int top, int right, int bottom})? rect = _overlay
          .windowRect();
      if (rect != null) _windowPhysicalRect = rect;
    });

    _followTimer?.cancel();
    _followTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (_settings.regionMode != RegionMode.followWindow) return;
      // Solo notifica si el rectángulo cambió, para no repintar sin motivo.
      final CaptureRegion resolved = resolveCaptureRegion();
      if (resolved.left != _settings.region.left ||
          resolved.top != _settings.region.top) {
        notifyListeners();
      }
    });

    _hitTestTimer?.cancel();
    _hitTestTimer = Timer.periodic(
      const Duration(milliseconds: 60),
      (_) => _updateSelectivePassthrough(),
    );
  }

  /// Decide, según dónde esté el cursor, si la ventana debe capturar el ratón.
  ///
  /// Es lo que permite tener el panel abierto y a la vez seguir jugando: la
  /// ventana solo se vuelve opaca al ratón cuando el cursor está encima de algo
  /// con lo que se puede interactuar.
  void _updateSelectivePassthrough() {
    // En segundo plano no hay nada que decidir: la ventana está oculta y tocar
    // sus estilos solo provocaría trabajo (y parpadeos) sin motivo.
    if (!_ready || _minimized) return;

    // Sin nada interactivo en pantalla (panel oculto y marcos desactivados) la
    // ventana debe dejar pasar todos los clics.
    if (_interactiveRects.isEmpty) {
      _setWindowInteractive(false);
      return;
    }

    // Modo simple: en configuración la ventana captura todo. Es el
    // comportamiento de reserva si el selectivo diera problemas.
    if (!_settings.passthroughInConfig) {
      _setWindowInteractive(true);
      return;
    }

    // Nunca se cambia de modo con un botón pulsado: cortaría el arrastre en
    // curso y la caja quedaría a medio mover.
    if (isMouseButtonDown()) return;

    final ({int x, int y})? cursor = cursorPosition();
    if (cursor == null) return;

    final Offset logical = physicalToLogical(
      Offset(cursor.x.toDouble(), cursor.y.toDouble()),
    );
    bool overUi = false;
    for (final Rect rect in _interactiveRects) {
      if (rect.contains(logical)) {
        overUi = true;
        break;
      }
    }
    _setWindowInteractive(overUi);
  }

  /// Conmutador rápido de captura del ratón, llamado desde el temporizador.
  ///
  /// Solo toca `WS_EX_TRANSPARENT`. Antes también cambiaba el estilo de foco, y
  /// eso hacía que Windows reevaluase la ventana y el botón de la barra de
  /// tareas fuese y viniese al mover el ratón. El estilo de foco ahora solo
  /// cambia al cambiar de modo.
  void _setWindowInteractive(bool interactive) {
    if (_appliedInteractive == interactive) return;
    _appliedInteractive = interactive;
    if (!_overlay.setClickThrough(!interactive)) {
      // Sin ventana localizada se recurre al plugin, que hace lo mismo por su
      // cuenta. Es el respaldo, no la vía principal: llamar a los dos a la vez
      // multiplica el trabajo sin ganar nada.
      unawaited(_setIgnoreMouseEventsFallback(!interactive));
    }
  }

  Future<void> _setIgnoreMouseEventsFallback(bool ignore) async {
    try {
      await windowManager.setIgnoreMouseEvents(ignore);
    } catch (e) {
      log.w('controller', 'setIgnoreMouseEvents falló: $e');
    }
  }

  /// La interfaz declara aquí sus zonas sensibles al ratón. Los rectángulos se
  /// amplían un margen para cubrir los tiradores de redimensión, que sobresalen
  /// del borde de la caja.
  void setInteractiveRects(List<Rect> rects) {
    _interactiveRects = rects;
  }

  // ------------------------------------------------------- conversión de ejes

  /// Convierte un punto lógico de Flutter a píxeles físicos de pantalla.
  ///
  /// Todo el desalineamiento entre "lo que marco" y "lo que se captura" nace
  /// aquí, así que la conversión vive en un único punto y usa el rectángulo real
  /// de la ventana leído de Windows en lugar de suposiciones.
  Offset logicalToPhysical(Offset logical) {
    final ({int left, int top, int right, int bottom})? rect =
        _windowPhysicalRect;
    final double originX = (rect?.left ?? 0).toDouble();
    final double originY = (rect?.top ?? 0).toDouble();
    return Offset(
      originX + logical.dx * _devicePixelRatio,
      originY + logical.dy * _devicePixelRatio,
    );
  }

  Offset physicalToLogical(Offset physical) {
    final ({int left, int top, int right, int bottom})? rect =
        _windowPhysicalRect;
    final double originX = (rect?.left ?? 0).toDouble();
    final double originY = (rect?.top ?? 0).toDouble();
    if (_devicePixelRatio <= 0) return Offset.zero;
    return Offset(
      (physical.dx - originX) / _devicePixelRatio,
      (physical.dy - originY) / _devicePixelRatio,
    );
  }

  CaptureRegion logicalRectToRegion(Rect logical) {
    final Offset topLeft = logicalToPhysical(logical.topLeft);
    return CaptureRegion(
      left: topLeft.dx.round(),
      top: topLeft.dy.round(),
      width: (logical.width * _devicePixelRatio).round(),
      height: (logical.height * _devicePixelRatio).round(),
    );
  }

  Rect regionToLogicalRect(CaptureRegion region) {
    final Offset topLeft = physicalToLogical(
      Offset(region.left.toDouble(), region.top.toDouble()),
    );
    if (_devicePixelRatio <= 0) return Rect.zero;
    return Rect.fromLTWH(
      topLeft.dx,
      topLeft.dy,
      region.width / _devicePixelRatio,
      region.height / _devicePixelRatio,
    );
  }

  /// La interfaz informa de su tamaño lógico y del factor de escala en cada
  /// construcción; ambos pueden cambiar si el usuario mueve la ventana a un
  /// monitor con otro escalado.
  void reportViewportMetrics({
    required Size logicalSize,
    required double devicePixelRatio,
  }) {
    final bool changed =
        _windowLogicalSize != logicalSize ||
        _devicePixelRatio != devicePixelRatio;
    _windowLogicalSize = logicalSize;
    _devicePixelRatio = devicePixelRatio;
    if (changed) {
      _windowPhysicalRect = _overlay.windowRect() ?? _windowPhysicalRect;
    }
  }

  // --------------------------------------------------------- región activa

  /// Región efectiva a capturar en este instante.
  CaptureRegion resolveCaptureRegion() {
    if (_settings.regionMode == RegionMode.followWindow && _followHwnd != 0) {
      final ({int left, int top, int width, int height})? rect =
          foreignWindowRect(_followHwnd);
      if (rect != null) {
        return CaptureRegion(
          left: rect.left + _followOffsetX,
          top: rect.top + _followOffsetY,
          width: _settings.region.width,
          height: _settings.region.height,
        );
      }
      // La ventana se cerró o se minimizó: se usa la última posición conocida
      // en lugar de dejar de traducir de golpe.
    }
    return _settings.region;
  }

  // ------------------------------------------------------ modos de la ventana

  Future<void> setConfigMode(bool enabled) async {
    // Si la ventana estaba minimizada, el atajo debe recuperarla aunque el modo
    // ya fuese el pedido: es la única vía de vuelta cuando está apartada.
    if (_minimized) await restoreOverlay();
    if (_configMode == enabled) return;
    _configMode = enabled;
    await _applyInteractionMode();
    notifyListeners();
  }

  Future<void> toggleConfigMode() => setConfigMode(!_configMode);

  Future<void> _applyInteractionMode() async {
    // El foco de teclado se decide aquí y solo aquí, una vez por cambio de
    // modo: en configuración la ventana debe poder recibir el teclado (campos
    // de API key); en modo juego no, para no robarle el foco al juego.
    _overlay.setFocusable(_configMode);

    // En modo directo los clics siempre atraviesan. En configuración el estado
    // de partida es "no capturar" cuando el paso selectivo está activo: el
    // temporizador lo activará en cuanto el cursor entre en el panel.
    final bool interactive = _configMode && !_settings.passthroughInConfig;
    _appliedInteractive = interactive;
    if (!_overlay.setClickThrough(!interactive)) {
      await _setIgnoreMouseEventsFallback(!interactive);
    }
    _overlay.bringToTop();
  }

  void setPassthroughInConfig(bool value) {
    _commit(_settings.copyWith(passthroughInConfig: value));
    unawaited(_applyInteractionMode());
    toasts.info(
      value
          ? 'Puedes jugar con el panel abierto'
          : 'El panel captura los clics',
      detail: value
          ? 'Los clics pasan al juego salvo sobre el panel y las cajas.'
          : 'Mientras el panel esté visible, la ventana recibe todos los clics.',
    );
  }

  void setSubtitlesVisible(bool visible) {
    if (_subtitlesVisible == visible) return;
    _subtitlesVisible = visible;
    notifyListeners();
    toasts.info(
      visible ? 'Subtítulos visibles' : 'Subtítulos ocultos',
      detail: 'Ctrl+Alt+H para alternar.',
    );
  }

  void toggleSubtitlesVisible() => setSubtitlesVisible(!_subtitlesVisible);

  void _applyTransparencyMode() {
    if (_settings.transparency == TransparencyMode.colorKey) {
      _overlay.applyColorKey(_settings.colorKey);
    } else {
      _overlay.clearColorKey();
    }
  }

  bool get isExcludedFromCapture => _overlay.isExcludedFromCapture;

  /// `true` si la caja de subtítulos se solapa con la zona de captura y el
  /// sistema no puede excluir la ventana. En ese caso el OCR leería nuestro
  /// propio subtítulo, así que hay que avisar.
  bool get subtitleOverlapsRegion {
    if (_overlay.isExcludedFromCapture) return false;
    final Rect regionRect = regionToLogicalRect(resolveCaptureRegion());
    return regionRect.overlaps(_settings.subtitleBox.rect);
  }

  // ------------------------------------------------------- mutar los ajustes

  void _commit(AppSettings updated, {bool rebuildEngines = false}) {
    _settings = updated;
    _pipeline?.updateSettings(updated);
    if (rebuildEngines) _rebuildEngines();
    _store.saveDebounced(updated);
    notifyListeners();
  }

  void setRegion(CaptureRegion region) {
    if (_settings.regionLocked) return;
    final ({int left, int top, int width, int height}) bounds =
        ScreenCapture.virtualScreenBounds();
    final CaptureRegion clamped = region.clampTo(
      boundsLeft: bounds.left,
      boundsTop: bounds.top,
      boundsWidth: bounds.width,
      boundsHeight: bounds.height,
    );
    _commit(_settings.copyWith(region: clamped));
    _recomputeFollowOffset();
  }

  /// La zona pasa a cubrir la pantalla completa del PC (el escritorio virtual).
  void setRegionToFullScreen() {
    if (_settings.regionLocked) {
      toasts.warning(
        'La zona está bloqueada',
        detail: 'Quita el candado de su barra para poder cambiarla.',
      );
      return;
    }
    final ({int left, int top, int width, int height}) bounds =
        ScreenCapture.virtualScreenBounds();
    _commit(
      _settings.copyWith(
        regionMode: RegionMode.fixed,
        region: CaptureRegion(
          left: bounds.left,
          top: bounds.top,
          width: bounds.width,
          height: bounds.height,
        ),
      ),
    );
  }

  /// Zona por defecto: banda inferior centrada, donde casi todos los juegos
  /// ponen los diálogos.
  void setRegionToBottomBand() {
    if (_settings.regionLocked) {
      toasts.warning(
        'La zona está bloqueada',
        detail: 'Quita el candado de su barra para poder cambiarla.',
      );
      return;
    }
    final ({int left, int top, int width, int height}) bounds =
        ScreenCapture.virtualScreenBounds();
    final int width = (bounds.width * 0.6).round();
    final int height = (bounds.height * 0.22).round();
    _commit(
      _settings.copyWith(
        regionMode: RegionMode.fixed,
        region: CaptureRegion(
          left: bounds.left + (bounds.width - width) ~/ 2,
          top:
              bounds.top +
              bounds.height -
              height -
              (bounds.height * 0.06).round(),
          width: width,
          height: height,
        ),
      ),
    );
  }

  /// Muestra u oculta el marco de edición de la zona.
  ///
  /// Al activarlo se garantiza que haya una zona válida que editar: si no la
  /// hay, se propone la banda inferior en lugar de mostrar un marco vacío.
  void setEditRegion(bool editing) {
    if (editing && !resolveCaptureRegion().isValid) {
      setRegionToBottomBand();
    }
    _commit(_settings.copyWith(editRegion: editing));
    toasts.info(
      editing ? 'Zona de captura activada' : 'Zona de captura desactivada',
      detail: editing
          ? 'Arrastra su barra de título para moverla y los tiradores del borde '
                'para redimensionarla.'
          : 'La zona sigue capturándose; solo se ha ocultado el marco.',
    );
  }

  void setEditSubtitleBox(bool editing) {
    _commit(_settings.copyWith(editSubtitleBox: editing));
    toasts.info(
      editing
          ? 'Caja de subtítulos activada'
          : 'Caja de subtítulos desactivada',
      detail: editing
          ? 'Mueve la caja por su barra; el interior deja pasar los clics.'
          : 'El texto traducido se sigue mostrando.',
    );
  }

  /// Tamaño efectivo del panel: el guardado, recortado a los límites y a lo que
  /// cabe en la ventana.
  ///
  /// Se recorta aquí y no al guardar porque el espacio disponible cambia al
  /// mover la ventana a otro monitor: un tamaño válido ayer puede no caber hoy.
  Size get panelSize {
    final Size bounds = _windowLogicalSize == Size.zero
        ? const Size(1920, 1080)
        : _windowLogicalSize;
    const double margin = 32;
    final double maxWidth = (bounds.width - margin).clamp(
      AppSettings.panelMinWidth,
      AppSettings.panelMaxWidth,
    );
    final double maxHeight = (bounds.height - margin).clamp(
      AppSettings.panelMinHeight,
      AppSettings.panelMaxHeight,
    );
    return Size(
      _settings.panelWidth.clamp(AppSettings.panelMinWidth, maxWidth),
      _settings.panelHeight.clamp(AppSettings.panelMinHeight, maxHeight),
    );
  }

  void setPanelSize(Size size) {
    _commit(
      _settings.copyWith(panelWidth: size.width, panelHeight: size.height),
    );
  }

  void resetPanelSize() {
    _commit(_settings.copyWith(panelWidth: 560, panelHeight: 720));
    toasts.info('Tamaño del panel restablecido');
  }

  void setPanelPosition(Offset position) {
    final Size bounds = _windowLogicalSize == Size.zero
        ? const Size(1920, 1080)
        : _windowLogicalSize;
    // Se deja siempre un trozo visible: un panel arrastrado fuera de la
    // pantalla sería irrecuperable sin editar el fichero de ajustes.
    const double minVisible = 120;
    _commit(
      _settings.copyWith(
        panelX: position.dx.clamp(
          -0.0,
          (bounds.width - minVisible).clamp(0.0, bounds.width),
        ),
        panelY: position.dy.clamp(
          0.0,
          (bounds.height - minVisible).clamp(0.0, bounds.height),
        ),
      ),
    );
  }

  void setRegionLocked(bool locked) {
    _commit(_settings.copyWith(regionLocked: locked));
    toasts.info(
      locked ? 'Zona de captura bloqueada' : 'Zona de captura desbloqueada',
      detail: locked
          ? 'Ya no se puede mover ni redimensionar.'
          : 'Arrastra su barra de título para moverla.',
    );
  }

  void toggleRegionLocked() => setRegionLocked(!_settings.regionLocked);

  void setSubtitleLocked(bool locked) {
    _commit(_settings.copyWith(subtitleLocked: locked));
    toasts.info(
      locked ? 'Caja de subtítulos bloqueada' : 'Caja de subtítulos libre',
      detail: locked
          ? 'Ya no se puede mover ni redimensionar.'
          : 'Arrastra su barra de título para moverla.',
    );
  }

  void toggleSubtitleLocked() => setSubtitleLocked(!_settings.subtitleLocked);

  void setSubtitleBox(SubtitleBox box) {
    if (_settings.subtitleLocked) return;
    final Size bounds = _windowLogicalSize == Size.zero
        ? const Size(1920, 1080)
        : _windowLogicalSize;
    _commit(_settings.copyWith(subtitleBox: box.clampTo(bounds)));
  }

  void setStyle(SubtitleStyle style) =>
      _commit(_settings.copyWith(style: style));

  void setPreprocess(PreprocessSettings preprocess) =>
      _commit(_settings.copyWith(preprocess: preprocess));

  void setPipelineSettings(PipelineSettings pipelineSettings) =>
      _commit(_settings.copyWith(pipeline: pipelineSettings));

  void setEngines(EngineSettings engines) {
    final EngineSettings previous = _settings.engines;
    final bool needsRebuild =
        previous.translator != engines.translator ||
        previous.deeplKey != engines.deeplKey ||
        previous.claudeKey != engines.claudeKey ||
        previous.claudeModel != engines.claudeModel ||
        previous.libreTranslateUrl != engines.libreTranslateUrl ||
        previous.glossary != engines.glossary ||
        previous.tesseractPath != engines.tesseractPath ||
        previous.ocrLanguages != engines.ocrLanguages ||
        previous.psm != engines.psm;
    _commit(_settings.copyWith(engines: engines), rebuildEngines: needsRebuild);
    if (needsRebuild) unawaited(refreshEngineHealth());
  }

  /// Aplica un idioma de origen completo: ajusta a la vez el código de OCR y el
  /// de traducción, que son distintos y desincronizarlos es el error típico.
  void applySourceLanguage(LanguageOption option) {
    setEngines(
      _settings.engines.copyWith(
        ocrLanguages: option.ocrCode,
        sourceLanguage: option.translateCode,
        psm: option.recommendedPsm,
      ),
    );
    toasts.info(
      'Idioma del juego: ${option.label}',
      detail: 'Comprobando si el OCR tiene el paquete "${option.ocrCode}"...',
    );
  }

  void applyTargetLanguage(LanguageOption option) {
    setEngines(
      _settings.engines.copyWith(targetLanguage: option.translateCode),
    );
    toasts.success('Se traducirá a ${option.label}');
  }

  /// Deja que el traductor detecte el idioma de origen. El OCR sigue
  /// necesitando saber qué escritura leer, así que ese código no se toca.
  void setAutoDetectSource(bool auto) {
    setEngines(
      _settings.engines.copyWith(
        sourceLanguage: auto ? 'auto' : _settings.engines.sourceLanguage,
      ),
    );
  }

  void setTransparencyMode(TransparencyMode mode) {
    _commit(_settings.copyWith(transparency: mode));
    _applyTransparencyMode();
    toasts.info(
      mode == TransparencyMode.compositor
          ? 'Transparencia por compositor'
          : 'Transparencia compatible por color',
      detail: mode == TransparencyMode.compositor
          ? 'Es la de mejor aspecto. Si ves fondo opaco, prueba la compatible.'
          : 'Funciona en cualquier equipo, aunque el borde puede notarse.',
    );
  }

  void setColorKey(int argb) {
    _commit(_settings.copyWith(colorKey: argb & 0xFFFFFF));
    _applyTransparencyMode();
  }

  void setStartInConfigMode(bool value) =>
      _commit(_settings.copyWith(startInConfigMode: value));

  // ------------------------------------------------------ seguir una ventana

  Future<void> refreshWindowList() async {
    _availableWindows = listTopLevelWindows();
    notifyListeners();
  }

  /// Ancla la región a una ventana concreta y ajusta la zona a su parte
  /// inferior, que es donde suele estar el texto.
  void followWindow(ForeignWindow window) {
    _followHwnd = window.hwnd;
    final int height = (window.height * 0.25).round().clamp(60, window.height);
    final int width = (window.width * 0.9).round();
    final CaptureRegion region = CaptureRegion(
      left: window.left + (window.width - width) ~/ 2,
      top: window.top + window.height - height - (window.height * 0.04).round(),
      width: width,
      height: height,
    );
    _followOffsetX = region.left - window.left;
    _followOffsetY = region.top - window.top;
    _commit(
      _settings.copyWith(
        regionMode: RegionMode.followWindow,
        followWindowTitle: window.title,
        region: region,
      ),
    );
    toasts.success(
      'Siguiendo a "${window.title}"',
      detail: 'La zona se moverá con esa ventana. Ajústala si hace falta.',
    );
  }

  void stopFollowingWindow() {
    toasts.info('La zona ya no sigue a ninguna ventana');
    _followHwnd = 0;
    _commit(
      _settings.copyWith(
        regionMode: RegionMode.fixed,
        followWindowTitle: '',
        region: resolveCaptureRegion(),
      ),
    );
  }

  void _recomputeFollowOffset() {
    if (_settings.regionMode != RegionMode.followWindow || _followHwnd == 0) {
      return;
    }
    final ({int left, int top, int width, int height})? rect =
        foreignWindowRect(_followHwnd);
    if (rect == null) return;
    _followOffsetX = _settings.region.left - rect.left;
    _followOffsetY = _settings.region.top - rect.top;
  }

  // -------------------------------------------------------------- motores

  OcrEngine _createOcrEngine() => TesseractOcr(
    executablePath: _settings.engines.tesseractPath,
    languages: _settings.engines.ocrLanguages,
    psm: _settings.engines.psm,
    userTessdataDir: tessdataDirectory,
  );

  Translator _createTranslator() {
    final EngineSettings e = _settings.engines;
    switch (e.translator) {
      case TranslatorKind.none:
        return PassthroughTranslator();
      case TranslatorKind.googleFree:
        return GoogleWebTranslator();
      case TranslatorKind.libre:
        return LibreTranslateTranslator(baseUrl: e.libreTranslateUrl);
      case TranslatorKind.deepl:
        return DeeplTranslator(apiKey: e.deeplKey);
      case TranslatorKind.claude:
        return ClaudeTranslator(
          apiKey: e.claudeKey,
          model: e.claudeModel,
          glossary: e.glossary,
        );
    }
  }

  void _buildPipeline() {
    _pipeline = TranslationPipeline(
      settings: _settings,
      ocrEngine: _createOcrEngine(),
      translator: ResilientTranslator(inner: _createTranslator()),
      resolveRegion: resolveCaptureRegion,
    );
  }

  void _rebuildEngines() {
    _pipeline?.updateEngines(
      ocrEngine: _createOcrEngine(),
      translator: ResilientTranslator(inner: _createTranslator()),
    );
  }

  /// `true` si el OCR no está operativo. Sin OCR no hay nada que traducir, así
  /// que la interfaz lo muestra como un aviso destacado en todas las pestañas.
  bool get ocrBlocked => _ocrHealth.hasProblem;

  /// Idiomas de OCR que faltan por descargar para lo que está configurado.
  List<String> _missingOcrLanguages = <String>[];
  List<String> get missingOcrLanguages => _missingOcrLanguages;

  /// Descarga en curso, o `null` si no hay ninguna.
  DownloadProgress? _download;
  DownloadProgress? get download => _download;

  String? _downloadError;
  String? get downloadError => _downloadError;

  late final TessdataInstaller _installer = _createInstaller();

  TessdataInstaller _createInstaller() {
    final String custom = _settings.engines.tessdataDir.trim();
    return TessdataInstaller(
      overrideDirectory: custom.isEmpty ? null : Directory(custom),
    );
  }

  /// Carpeta efectiva donde se guardan los paquetes de idioma.
  String get tessdataDirectory {
    final String custom = _settings.engines.tessdataDir.trim();
    return custom.isEmpty ? _installer.directoryPath : custom;
  }

  /// Descarga un paquete de idioma del OCR.
  ///
  /// Va a la carpeta de la aplicación, no a la de Tesseract: esa está bajo
  /// `Program Files` y escribir ahí pediría permisos de administrador para algo
  /// que no los necesita.
  Future<void> installOcrLanguage(String language) async {
    if (_download != null) {
      toasts.warning('Ya hay una descarga en curso');
      return;
    }
    toasts.info('Descargando el idioma "$language"...');
    _downloadError = null;
    _download = DownloadProgress(
      language: language,
      receivedBytes: 0,
      totalBytes: 0,
    );
    notifyListeners();

    final TessdataInstaller installer = _createInstaller();
    try {
      await installer.download(
        language,
        onProgress: (DownloadProgress progress) {
          _download = progress;
          notifyListeners();
        },
      );
      _download = null;
      notifyListeners();
      toasts.success(
        'Idioma "$language" instalado',
        detail: 'Guardado en $tessdataDirectory',
      );
      // Los motores se reconstruyen para que el OCR vea el idioma nuevo, y se
      // vuelve a comprobar la salud para que desaparezca el aviso.
      _rebuildEngines();
      await refreshEngineHealth();
    } on StageFailure catch (failure) {
      _download = null;
      _downloadError = failure.hint == null
          ? failure.message
          : '${failure.message} ${failure.hint}';
      log.e('controller', 'Fallo descargando "$language": ${failure.message}');
      toasts.error(failure.message, detail: failure.hint);
      notifyListeners();
    } catch (e) {
      _download = null;
      _downloadError = 'Fallo inesperado al descargar "$language": $e';
      log.e('controller', 'Fallo inesperado descargando "$language"', e);
      toasts.error('No se pudo descargar "$language"', detail: '$e');
      notifyListeners();
    } finally {
      installer.dispose();
    }
  }

  /// Reintenta la actualización tras un fallo, sin volver a consultar GitHub.
  Future<void> retryUpdate() async {
    final ReleaseInfo? release = _updateState.release;
    if (release == null) {
      await checkForUpdate();
      return;
    }
    _setUpdateState(
      UpdateState(
        stage: UpdateStage.available,
        release: release,
        message: 'Versión ${release.version} disponible.',
      ),
    );
    await onRequestUpdateInstall();
  }

  void clearDownloadError() {
    if (_downloadError == null) return;
    _downloadError = null;
    notifyListeners();
  }

  void setTessdataDir(String path) {
    setEngines(_settings.engines.copyWith(tessdataDir: path.trim()));
    unawaited(refreshEngineHealth());
    toasts.info('Carpeta de idiomas cambiada', detail: tessdataDirectory);
  }

  /// Lanza la instalación de Tesseract en una consola visible.
  ///
  /// Se abre una ventana de PowerShell en lugar de instalar en silencio: es el
  /// usuario quien ve qué se instala y puede cancelarlo, y si winget falla el
  /// mensaje de error queda a la vista en lugar de perderse.
  Future<void> installTesseract() async {
    const String command =
        'winget install --id UB-Mannheim.TesseractOCR --exact '
        '--accept-package-agreements --accept-source-agreements';
    try {
      await Process.start(
        'powershell',
        <String>['-NoExit', '-Command', command],
        mode: ProcessStartMode.detached,
        runInShell: true,
      );
      log.i('controller', 'Instalación de Tesseract lanzada en PowerShell');
      toasts.info(
        'Instalación de Tesseract abierta en PowerShell',
        detail: 'Cuando termine, pulsa "Ya está, comprobar" en el panel.',
      );
    } catch (e) {
      log.e('controller', 'No se pudo lanzar winget', e);
      toasts.error(
        'No se pudo abrir el instalador',
        detail: 'Ejecuta a mano: winget install UB-Mannheim.TesseractOCR',
      );
    }
  }

  // ------------------------------------------------------------- actualizar

  final Updater _updater = Updater();

  /// Cierre ordenado, inyectado desde `main.dart`.
  ///
  /// El controlador sabe cuándo hay que cerrar (el instalador va a sustituir el
  /// ejecutable) pero no cómo: liberar atajos, retirar el icono de la bandeja y
  /// terminar el proceso son cosas de la capa de aplicación.
  Future<void> Function()? shutdownHook;

  /// Lo llama el botón de actualizar del panel.
  Future<void> onRequestUpdateInstall() async {
    await downloadAndInstallUpdate(onReadyToClose: shutdownHook ?? () async {});
  }

  UpdateState _updateState = const UpdateState();
  UpdateState get updateState => _updateState;

  String get currentVersion => appVersion;
  String get releasesPageUrl => _updater.releasesPageUrl;

  /// `true` cuando hay una versión nueva pendiente y la aplicación debe quedar
  /// bloqueada hasta que se instale.
  ///
  /// Es deliberadamente estricto: una versión vieja traduciendo con un motor o
  /// una API que ya cambió da resultados raros que parecen fallos de la
  /// aplicación. Se detiene el trabajo y se pide actualizar. La pantalla de
  /// bloqueo siempre ofrece salir, para que un fallo de descarga no deje a nadie
  /// encerrado.
  bool get updateRequired =>
      _updateState.release != null && _updateState.stage != UpdateStage.idle;

  void _setUpdateState(UpdateState state) {
    _updateState = state;
    notifyListeners();
  }

  /// Busca una versión más reciente en las releases de GitHub.
  Future<void> checkForUpdate({bool silent = false}) async {
    if (_updateState.isBusy) return;
    _setUpdateState(
      const UpdateState(
        stage: UpdateStage.checking,
        message: 'Comprobando si hay una versión nueva...',
      ),
    );
    if (!silent) toasts.info('Comprobando actualizaciones...');

    try {
      final ReleaseInfo? release = await _updater.checkForUpdate();
      if (release == null) {
        _setUpdateState(
          UpdateState(message: 'Estás en la última versión ($appVersion).'),
        );
        if (!silent) {
          toasts.success('Ya tienes la última versión', detail: appVersion);
        }
        return;
      }
      // Se detiene el trabajo en curso antes de bloquear: dejar el pipeline
      // capturando y gastando cuota detrás de una pantalla que el usuario no
      // puede tocar no tendría ningún sentido.
      try {
        _pipeline?.stop();
      } catch (e) {
        log.w('updater', 'No se pudo detener el pipeline: $e');
      }
      _setUpdateState(
        UpdateState(
          stage: UpdateStage.available,
          release: release,
          message: 'Versión ${release.version} disponible.',
        ),
      );
      toasts.warning(
        'Hay una versión nueva: ${release.version}',
        detail:
            'Traducy se ha detenido y quedará bloqueado hasta actualizar '
            '(${release.readableSize}).',
      );
    } on StageFailure catch (failure) {
      _setUpdateState(
        UpdateState(stage: UpdateStage.failed, message: failure.message),
      );
      if (!silent) {
        toasts.error(failure.message, detail: failure.hint);
      } else {
        log.w('updater', failure.message);
      }
    } catch (e) {
      _setUpdateState(
        UpdateState(stage: UpdateStage.failed, message: 'Fallo inesperado: $e'),
      );
      log.e('updater', 'Fallo inesperado comprobando actualizaciones', e);
    }
  }

  /// Descarga la actualización y lanza el instalador.
  ///
  /// El instalador sustituye el ejecutable en marcha, así que hay que cerrar
  /// Traducy. Se avisa por [onReadyToClose] en lugar de cerrar aquí: el cierre
  /// ordenado (volcar ajustes, liberar atajos, retirar el icono de la bandeja)
  /// vive en `main.dart`.
  Future<void> downloadAndInstallUpdate({
    required Future<void> Function() onReadyToClose,
  }) async {
    final ReleaseInfo? release = _updateState.release;
    if (release == null || _updateState.isBusy) return;

    _setUpdateState(
      UpdateState(
        stage: UpdateStage.downloading,
        release: release,
        totalBytes: release.sizeBytes,
        message: 'Descargando la versión ${release.version}...',
      ),
    );

    try {
      final File installer = await _updater.downloadInstaller(
        release,
        onProgress: (int received, int total) {
          _setUpdateState(
            UpdateState(
              stage: UpdateStage.downloading,
              release: release,
              receivedBytes: received,
              totalBytes: total,
              message: 'Descargando la versión ${release.version}...',
            ),
          );
        },
      );

      _setUpdateState(
        UpdateState(
          stage: UpdateStage.ready,
          release: release,
          message:
              'Instalando la versión ${release.version}. '
              'Traducy se cerrará y volverá a abrirse.',
        ),
      );

      // Los ajustes se vuelcan antes de lanzar el instalador: si se hiciera
      // después, el proceso ya estaría muriendo y se perderían.
      await _store.flush();
      await _updater.launchInstaller(installer);

      // Un instante para que el instalador arranque de verdad antes de que
      // desaparezca el proceso que lo lanzó.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await onReadyToClose();
    } on StageFailure catch (failure) {
      _setUpdateState(
        UpdateState(
          stage: UpdateStage.failed,
          release: release,
          message: failure.message,
        ),
      );
      toasts.error(failure.message, detail: failure.hint);
    } catch (e) {
      _setUpdateState(
        UpdateState(
          stage: UpdateStage.failed,
          release: release,
          message: 'Fallo inesperado: $e',
        ),
      );
      toasts.error('No se pudo actualizar', detail: '$e');
    }
  }

  /// Revisa qué tiene instalado el usuario y ajusta la configuración a ello.
  ///
  /// Se llama al arrancar. La idea es que la aplicación se entere sola en lugar
  /// de esperar a que alguien vaya a buscar el ajuste correcto: si el idioma
  /// configurado no está pero hay otro disponible, lo dice; si Tesseract está en
  /// una ruta no estándar, la fija; y si todo está en orden, también lo dice,
  /// para que no haya dudas.
  Future<void> autoDetectSetup() async {
    final TesseractOcr probe = _createOcrEngine() as TesseractOcr;
    try {
      final String? exe = await probe.resolveExecutable();
      if (exe == null) {
        toasts.error(
          'No se encuentra Tesseract en este equipo',
          detail: 'Pulsa "Instalar Tesseract" en la guía de arriba.',
        );
        return;
      }

      // Ruta encontrada por autodetección: se guarda para no repetir la búsqueda
      // en cada arranque, y para que el usuario vea de dónde sale.
      if (_settings.engines.tesseractPath.trim().isEmpty) {
        toasts.info('Tesseract detectado', detail: exe);
      }

      final List<String> available = await probe.availableLanguages();
      final List<String> missing = await probe.missingLanguages();

      if (missing.isEmpty) {
        toasts.success(
          'Todo listo: OCR "${_settings.engines.ocrLanguages}" disponible',
          detail: 'Idiomas instalados: ${available.join(', ')}',
        );
        return;
      }

      // Falta el idioma configurado. Si hay otros, se nombran para que la
      // elección sea evidente en lugar de un simple "falta algo".
      final List<String> usable = available
          .where((String l) => l != 'osd')
          .toList();
      toasts.warning(
        'Falta el idioma "${missing.join(', ')}" del OCR',
        detail: usable.isEmpty
            ? 'Descárgalo desde la guía de arriba.'
            : 'Puedes descargarlo desde la guía, o usar uno de los que ya '
                  'tienes: ${usable.join(', ')}.',
      );
    } catch (e) {
      log.w('controller', 'Autodetección incompleta: $e');
    } finally {
      probe.dispose();
    }
  }

  Future<void> refreshEngineHealth() async {
    _ocrHealth = const EngineHealth(checking: true);
    _translatorHealth = const EngineHealth(checking: true);
    notifyListeners();

    final OcrEngine ocr = _createOcrEngine();
    try {
      final String? issue = await ocr.checkAvailability();
      _ocrHealth = EngineHealth(issue: issue, checkedAt: DateTime.now());
      if (ocr is TesseractOcr) {
        // Sistema + descargados: si solo se contase el sistema, un idioma
        // bajado por la app saldría como "no instalado" en el desplegable.
        _installedOcrLanguages = await ocr.availableLanguages();
        _missingOcrLanguages = await ocr.missingLanguages();
      }
    } catch (e) {
      _ocrHealth = EngineHealth(
        issue: 'Fallo al comprobar el OCR: $e',
        checkedAt: DateTime.now(),
      );
    } finally {
      ocr.dispose();
    }
    // Al registro: es la respuesta a "por qué no traduce" y debe poder verse
    // sin abrir el panel.
    final String? ocrIssue = _ocrHealth.issue;
    if (ocrIssue == null) {
      log.i('diag', 'OCR listo (${_settings.engines.ocrLanguages})');
    } else {
      log.e('diag', 'OCR NO DISPONIBLE: $ocrIssue');
    }
    notifyListeners();

    final Translator translator = _createTranslator();
    try {
      final String? issue = await translator.checkAvailability();
      _translatorHealth = EngineHealth(issue: issue, checkedAt: DateTime.now());
    } catch (e) {
      _translatorHealth = EngineHealth(
        issue: 'Fallo al comprobar el traductor: $e',
        checkedAt: DateTime.now(),
      );
    } finally {
      translator.dispose();
    }
    final String? translatorIssue = _translatorHealth.issue;
    if (translatorIssue == null) {
      log.i(
        'diag',
        'Traductor listo (${_settings.engines.translator.name} → '
            '${_settings.engines.targetLanguage})',
      );
    } else {
      log.e('diag', 'TRADUCTOR NO DISPONIBLE: $translatorIssue');
    }
    notifyListeners();
  }

  // ------------------------------------------------------------- pipeline

  void startTranslating() {
    if (_ocrHealth.hasProblem) {
      toasts.error('No se puede traducir todavía', detail: _ocrHealth.issue);
      return;
    }
    if (!resolveCaptureRegion().isValid) {
      setRegionToBottomBand();
      toasts.info(
        'Se ha puesto una zona en la banda inferior',
        detail: 'Ajústala si el texto del juego aparece en otro sitio.',
      );
    }
    _pipeline?.start();
    notifyListeners();
    toasts.success(
      'Traduciendo',
      detail: 'Ctrl+Alt+T oculta el panel · Ctrl+Alt+P pausa',
    );
  }

  void stopTranslating() {
    _pipeline?.stop();
    notifyListeners();
    toasts.info('Traducción detenida');
  }

  void togglePause() {
    final TranslationPipeline? pipeline = _pipeline;
    if (pipeline == null) return;
    pipeline.toggle();
    notifyListeners();
    toasts.info(
      pipeline.isRunning ? 'Traducción reanudada' : 'Traducción en pausa',
      detail: 'Ctrl+Alt+P para alternar.',
    );
  }

  Future<void> testOnce() async {
    toasts.info('Probando una captura...');
    await _pipeline?.runOnce();
    notifyListeners();
    final PipelineStatus? status = _pipeline?.status.value;
    if (status == null) return;
    if (status.failedStage != null) {
      toasts.error('La prueba falló: ${status.message}', detail: status.hint);
    } else {
      toasts.success(
        'Prueba completada: ${status.message}',
        detail:
            'OCR ${status.lastOcrMs} ms · traducción '
            '${status.lastTranslateMs} ms',
      );
    }
  }

  // ---------------------------------------------------------------- cierre

  Future<void> shutdown() async {
    _topmostTimer?.cancel();
    _followTimer?.cancel();
    _hitTestTimer?.cancel();
    await _store.flush();
  }

  @override
  void dispose() {
    _topmostTimer?.cancel();
    _followTimer?.cancel();
    _hitTestTimer?.cancel();
    _pipeline?.dispose();
    _updater.dispose();
    _store.dispose();
    SharedHttpClient.close();
    super.dispose();
  }
}
