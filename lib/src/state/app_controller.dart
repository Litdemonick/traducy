import 'dart:io';
import 'dart:async';
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

import '../core/failures.dart';
import '../core/app_paths.dart';
import '../core/logx.dart';
import '../core/updater.dart';
import '../core/version.dart';
import '../models/languages.dart';
import '../i18n/strings.dart';
import '../models/settings.dart';
import '../models/settings_store.dart';
import '../native/overlay_native.dart';
import '../native/screen_capture.dart';
import '../ocr/ocr_engine.dart';
import '../ocr/tessdata_installer.dart';
import '../ocr/tesseract_ocr.dart';
import '../ocr/windows_ocr.dart';
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
  /// `true` si ahora mismo hay una ventana enganchada de verdad.
  ///
  /// La interfaz lo necesita: "anclada a X" sin saber si esa ventana existe es
  /// engañoso justo cuando hace falta saberlo, con el juego cerrado.
  bool _followConnected = false;
  bool get followConnected => _followConnected;

  /// Para no repetir el aviso de "no encuentro la ventana" cada 700 ms.
  bool _followLossReported = false;

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

  /// En segundo plano (modo juego): ventana oculta, solo icono en la bandeja.
  bool _background = false;
  bool get isInBackground => _background;

  /// `true` cuando no hay ventana a la vista, por minimizado o por segundo
  /// plano. Los temporizadores lo usan para no trabajar en balde.
  bool get isHidden => _minimized || _background;

  // --------------------------------------------------------------- arranque

  Future<void> initialize() async {
    try {
      final bool firstRun = !_store.settingsFileExists;
      _settings = await _store.load();
      if (firstRun) {
        // Primer arranque: si el instalador dejó escrito su idioma, se adopta.
        // Queda guardado como elección explícita, así que el panel lo muestra
        // seleccionado y se puede cambiar desde ahí.
        final UiLanguage? chosen = _languageFromInstaller();
        if (chosen != null) {
          _settings = _settings.copyWith(uiLanguage: chosen);
        }
      }
      // Antes que cualquier otra cosa: el resto del arranque ya genera mensajes
      // que el usuario va a leer en la consola del panel.
      L10n.apply(_settings.uiLanguage);
      _configMode = _settings.startInConfigMode;

      if (_settings.regionMode == RegionMode.followWindow) {
        // El identificador de la ventana no se puede guardar, asi que se busca
        // otra vez por el titulo que si se guardo.
        reacquireFollowWindow(quiet: true);
      }

      await _pickWorkingOcrEngine();

      await _positionWindowOverVirtualScreen();
      _overlay.applyOverlayStyles();
      _overlay.excludeFromCapture(true);
      await _applyInteractionMode();

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
      _fatalError = t.panel.msgStartFailed('$e');
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

  /// Minimiza la ventana dejando su botón en la barra de tareas.
  ///
  /// Es minimizar de verdad, no ocultar: el botón sigue ahí y al pulsarlo la
  /// ventana vuelve, que es lo que espera cualquiera de la flecha de minimizar.
  /// El modo "segundo plano" con icono junto al reloj es otra cosa y lo hace el
  /// botón del ojo.
  ///
  /// Antes de minimizar se devuelve el foco a la ventana. Mientras juega,
  /// Traducy lleva `WS_EX_NOACTIVATE` para no robar el foco, y una ventana con
  /// ese estilo no se restaura al pulsar su botón en la barra de tareas: Windows
  /// necesita poder activarla. Al restaurar se reaplica el modo que tocaba.
  Future<void> minimizeOverlay() async {
    try {
      _overlay.setFocusable(true);
      _appliedInteractive = null;
      _minimized = true;
      notifyListeners();
      await windowManager.setSkipTaskbar(false);
      await windowManager.minimize();
      log.i('controller', 'Minimizado. Su botón sigue en la barra de tareas.');
      toasts.info(t.minimizedTitle, detail: t.minimizedDetail);
    } catch (e) {
      log.w('controller', 'No se pudo minimizar: $e');
      toasts.error(t.minimizeFailed, detail: t.minimizeFailedDetail);
      _minimized = false;
      notifyListeners();
      await _applyInteractionMode();
    }
  }

  /// Manda Traducy a segundo plano: modo juego con la ventana fuera de la vista
  /// y solo el icono junto al reloj.
  ///
  /// Distinto de minimizar: aquí la ventana se oculta por completo y sale de la
  /// barra de tareas, para que no estorbe mientras se juega. La vuelta es el
  /// icono de la bandeja (clic izquierdo abre el panel, derecho da opciones) o
  /// Ctrl+Alt+T.
  Future<void> sendToBackground() async {
    try {
      _background = true;
      _minimized = false;
      notifyListeners();
      // Fuera de la barra de tareas mientras está oculta, para no aparecer
      // duplicado junto al icono de la bandeja.
      await windowManager.setSkipTaskbar(true);
      await windowManager.hide();
      log.i(
        'controller',
        'En segundo plano. Clic en el icono de la bandeja o Ctrl+Alt+T '
            'para recuperarlo.',
      );
      toasts.info(t.backgroundTitle, detail: t.backgroundDetail);
    } catch (e) {
      log.w('controller', 'No se pudo pasar a segundo plano: $e');
      toasts.error(t.backgroundFailed, detail: t.backgroundFailedDetail);
      _background = false;
      notifyListeners();
    }
  }

  /// Trae Traducy de vuelta, esté minimizado o en segundo plano.
  ///
  /// Con [openPanel] se abre además el panel de control. Es lo que hace el clic
  /// izquierdo en el icono de la bandeja: quien lo pulsa quiere ver la ventana,
  /// no recuperar un overlay invisible y quedarse sin nada delante.
  Future<void> restoreOverlay({bool openPanel = false}) async {
    try {
      await windowManager.setSkipTaskbar(false);
      if (await windowManager.isMinimized()) {
        await windowManager.restore();
      }
      await windowManager.show();
      // Al volver se reafirma la geometría y los estilos: mientras estaba
      // oculta pueden haber cambiado la resolución o el número de monitores.
      await _pickWorkingOcrEngine();

      await _positionWindowOverVirtualScreen();
      _overlay.applyOverlayStyles();
      _overlay.excludeFromCapture(true);
      if (openPanel) _configMode = true;
      _appliedInteractive = null; // fuerza reaplicar el modo de ratón
      await _applyInteractionMode();
      _overlay.bringToTop();
    } catch (e) {
      log.w('controller', 'No se pudo restaurar la ventana: $e');
    } finally {
      _minimized = false;
      _background = false;
      notifyListeners();
    }
  }

  /// Sincroniza el estado cuando Windows minimiza o restaura por su cuenta
  /// (botón de la barra de tareas, Win+D, Alt+Tab...).
  ///
  /// Sin esto, minimizar desde fuera dejaría los temporizadores trabajando
  /// contra una ventana que nadie ve, y restaurar desde fuera dejaría la
  /// captura parada con la ventana delante.
  void onSystemMinimize() {
    if (_minimized) return;
    _minimized = true;
    notifyListeners();
  }

  void onSystemRestore() {
    if (!_minimized && !_background) return;
    unawaited(restoreOverlay());
  }

  void _startKeepAliveTimers() {
    // Algunos juegos se ponen por encima al ganar el foco; reafirmar "siempre
    // visible" cada pocos segundos mantiene el subtítulo a la vista.
    _topmostTimer?.cancel();
    _topmostTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (isHidden) return;
      _overlay.bringToTop();
      final ({int left, int top, int right, int bottom})? rect = _overlay
          .windowRect();
      if (rect != null) _windowPhysicalRect = rect;
    });

    _followTimer?.cancel();
    _followTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (_settings.regionMode != RegionMode.followWindow) return;
      // La ventana pudo cerrarse y volver a abrirse con otro identificador: es lo
      // normal al reiniciar el juego, y sin reintentar aqui el anclaje quedaba
      // roto para siempre sin ninguna senal.
      if (_followHwnd == 0 || foreignWindowRect(_followHwnd) == null) {
        final bool reconnected = reacquireFollowWindow();
        if (reconnected) notifyListeners();
        if (!reconnected) return;
      }
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
    if (!_ready || isHidden) return;

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

  /// Rectángulo que se está arrastrando ahora mismo, en píxeles lógicos.
  ///
  /// Va en un `ValueNotifier` y no en el estado del controlador a propósito: las
  /// medidas del panel tienen que ir en vivo mientras se arrastra, pero
  /// reconstruir el panel entero a cada movimiento del ratón es justo lo que hacía
  /// el arrastre lento. Así solo se repinta el puñado de números que mira esto.
  final ValueNotifier<Rect?> regionPreview = ValueNotifier<Rect?>(null);
  final ValueNotifier<Rect?> subtitlePreview = ValueNotifier<Rect?>(null);

  // --------------------------------------------------------- región activa

  /// Región efectiva a capturar en este instante.
  CaptureRegion resolveCaptureRegion() {
    if (_settings.regionMode == RegionMode.followWindow && _followHwnd != 0) {
      final ({int left, int top, int width, int height})? rect =
          foreignWindowRect(_followHwnd);
      if (rect != null) {
        return CaptureRegion(
          left: rect.left + _settings.followOffsetX,
          top: rect.top + _settings.followOffsetY,
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
    if (isHidden) await restoreOverlay();
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
      value ? t.panel.msgPassthroughOn : t.panel.msgPassthroughOff,
      detail: value
          ? t.panel.msgPassthroughOnDetail
          : t.panel.msgPassthroughOffDetail,
    );
  }

  void setSubtitlesVisible(bool visible) {
    if (_subtitlesVisible == visible) return;
    _subtitlesVisible = visible;
    notifyListeners();
    toasts.info(
      visible ? t.panel.msgSubtitlesVisible : t.panel.msgSubtitlesHidden,
      detail: t.panel.msgToggleWithH,
    );
  }

  void toggleSubtitlesVisible() => setSubtitlesVisible(!_subtitlesVisible);

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
        t.panel.msgZoneLocked,
        detail: t.panel.msgZoneLockedDetail,
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
        t.panel.msgZoneLocked,
        detail: t.panel.msgZoneLockedDetail,
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
      editing ? t.panel.msgRegionOn : t.panel.msgRegionOff,
      detail: editing ? t.panel.msgRegionOnDetail : t.panel.msgRegionOffDetail,
    );
  }

  void setEditSubtitleBox(bool editing) {
    _commit(_settings.copyWith(editSubtitleBox: editing));
    toasts.info(
      editing ? t.panel.msgSubtitleBoxOn : t.panel.msgSubtitleBoxOff,
      detail: editing
          ? t.panel.msgSubtitleBoxOnDetail
          : t.panel.msgSubtitleBoxOffDetail,
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

  /// Redimensiona el panel arrastrando cualquiera de sus bordes.
  ///
  /// Tirando del borde izquierdo o del superior hay que mover **tambien** el
  /// origen: si solo cambiara el tamano, el panel creceria hacia el lado
  /// contrario al del arrastre, que es exactamente lo que nadie espera.
  ///
  /// El limite se aplica al tamano antes de calcular la posicion, y no despues:
  /// al reves, al llegar al minimo el borde seguia moviendose y el panel se
  /// deslizaba por la pantalla en lugar de quedarse quieto.
  void resizePanelFromEdge({
    required Offset delta,
    required bool left,
    required bool top,
    required bool right,
    required bool bottom,
  }) {
    final Size current = panelSize;
    final Size limits = _panelSizeLimits();

    double width = current.width;
    double height = current.height;
    if (left) width -= delta.dx;
    if (right) width += delta.dx;
    if (top) height -= delta.dy;
    if (bottom) height += delta.dy;

    width = width.clamp(AppSettings.panelMinWidth, limits.width);
    height = height.clamp(AppSettings.panelMinHeight, limits.height);

    double x = _settings.panelX;
    double y = _settings.panelY;
    if (left) x += current.width - width;
    if (top) y += current.height - height;

    _commit(
      _settings.copyWith(
        panelWidth: width,
        panelHeight: height,
        panelX: x < 0 ? 0 : x,
        panelY: y < 0 ? 0 : y,
      ),
    );
  }

  /// Tamano maximo del panel en la pantalla actual.
  Size _panelSizeLimits() {
    final Size bounds = _windowLogicalSize == Size.zero
        ? const Size(1920, 1080)
        : _windowLogicalSize;
    const double margin = 32;
    return Size(
      (bounds.width - margin).clamp(
        AppSettings.panelMinWidth,
        AppSettings.panelMaxWidth,
      ),
      (bounds.height - margin).clamp(
        AppSettings.panelMinHeight,
        AppSettings.panelMaxHeight,
      ),
    );
  }

  void setPanelSize(Size size) {
    _commit(
      _settings.copyWith(panelWidth: size.width, panelHeight: size.height),
    );
  }

  void resetPanelSize() {
    _commit(_settings.copyWith(panelWidth: 560, panelHeight: 720));
    toasts.info(t.panel.msgPanelSizeReset);
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
      locked ? t.panel.msgRegionLocked : t.panel.msgRegionUnlocked,
      detail: locked ? t.panel.msgLockedDetail : t.panel.msgUnlockedDetail,
    );
  }

  void toggleRegionLocked() => setRegionLocked(!_settings.regionLocked);

  void setSubtitleLocked(bool locked) {
    _commit(_settings.copyWith(subtitleLocked: locked));
    toasts.info(
      locked ? t.panel.msgSubtitleLocked : t.panel.msgSubtitleUnlocked,
      detail: locked ? t.panel.msgLockedDetail : t.panel.msgUnlockedDetail,
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
        previous.psm != engines.psm ||
        previous.ocrKind != engines.ocrKind;
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
      t.panel.msgGameLanguage(option.label),
      detail: t.panel.msgCheckingPack(option.ocrCode),
    );
  }

  void applyTargetLanguage(LanguageOption option) {
    setEngines(
      _settings.engines.copyWith(targetLanguage: option.translateCode),
    );
    toasts.success(t.panel.msgTargetLanguage(option.label));
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

  /// Lee el idioma que dejó escrito el instalador, o `null` si no hay nada.
  ///
  /// Cualquier fallo devuelve `null` y el arranque sigue con el idioma del
  /// sistema: un fichero ilegible no puede impedir que la aplicación abra.
  UiLanguage? _languageFromInstaller() {
    try {
      final File file = AppPaths.instance.installerLanguageFile;
      if (!file.existsSync()) return null;
      final String code = file.readAsStringSync().trim().toLowerCase();
      if (code.startsWith('es')) return UiLanguage.spanish;
      if (code.startsWith('en')) return UiLanguage.english;
      return null;
    } catch (e) {
      log.d('paths', 'No se pudo leer el idioma del instalador: $e');
      return null;
    }
  }

  /// Cambia el idioma de la interfaz.
  ///
  /// No reinicia nada: los textos se leen del idioma activo en cada repintado, y
  /// `notifyListeners` desde `_commit` provoca ese repintado. Los mensajes que ya
  /// estaban en la consola se quedan en el idioma en que se escribieron, que es
  /// lo honesto: son un historial de lo que pasó, no una traducción en vivo.
  void setUiLanguage(UiLanguage language) {
    final AppStrings applied = L10n.apply(language);
    _commit(_settings.copyWith(uiLanguage: language));
    final String name = switch (language) {
      UiLanguage.auto => '${t.uiLanguageAuto} (${applied.localeCode})',
      UiLanguage.spanish => t.uiLanguageSpanish,
      UiLanguage.english => t.uiLanguageEnglish,
    };
    toasts.info(t.uiLanguageChanged(name));
  }

  /// Vacía el historial de subtítulos de la caja.
  void clearSubtitleHistory() {
    _pipeline?.clearHistory();
    toasts.info(t.panel.msgHistoryCleared);
  }

  /// Activa o desactiva la actualización automática.
  void setAutoUpdate(bool value) {
    _commit(_settings.copyWith(autoUpdate: value));
    toasts.info(value ? t.panel.msgAutoUpdateOn : t.panel.msgAutoUpdateOff);
  }

  void setStartInConfigMode(bool value) =>
      _commit(_settings.copyWith(startInConfigMode: value));

  // ------------------------------------------------------ seguir una ventana

  Future<void> refreshWindowList() async {
    _availableWindows = listTopLevelWindows();
    notifyListeners();
  }

  /// Encuentra la ventana del juego y engancha la zona a ella.
  ///
  /// Es el camino directo: en lugar de dibujar un rectángulo a mano sobre la
  /// pantalla, se elige la ventana y la zona se coloca sola en su parte baja, que
  /// es donde ponen el diálogo casi todos los juegos. Y como queda anclada a la
  /// ventana, mover el juego no obliga a recolocar nada.
  ///
  /// Se prueban dos vías en orden. Primero la ventana en primer plano: si el
  /// usuario acaba de estar en el juego, es esa, y ninguna heurística lo va a
  /// hacer mejor. Si no sirve (el foco lo tiene el panel de Traducy, o el
  /// escritorio), se elige entre las visibles la de mayor superficie que no sea
  /// una ventana del sistema.
  Future<bool> detectGameWindow() async {
    _availableWindows = listTopLevelWindows();

    ForeignWindow? candidate = foregroundWindow();
    if (candidate != null && _looksLikeSystemWindow(candidate.title)) {
      candidate = null;
    }

    candidate ??= _largestUsableWindow(_availableWindows);

    if (candidate == null) {
      notifyListeners();
      toasts.warning(
        t.panel.msgNoGameWindow,
        detail: t.panel.msgNoGameWindowDetail,
      );
      return false;
    }

    followWindow(candidate);
    return true;
  }

  /// Descarta lo que nunca es el juego: el escritorio, la barra de tareas y los
  /// componentes de la interfaz de Windows, que aparecen en la enumeración como
  /// ventanas normales y a pantalla completa.
  static bool _looksLikeSystemWindow(String title) {
    const List<String> known = <String>[
      'program manager',
      'windows input experience',
      'windows shell experience host',
      '搜索',
      'search',
      'configuración',
      'settings',
      'traducy',
      'nvidia geforce overlay',
      'explorador de archivos',
      'file explorer',
    ];
    final String lower = title.toLowerCase().trim();
    if (lower.isEmpty) return true;
    return known.any((String name) => lower == name || lower.startsWith(name));
  }

  ForeignWindow? _largestUsableWindow(List<ForeignWindow> windows) {
    ForeignWindow? best;
    int bestArea = 0;
    for (final ForeignWindow window in windows) {
      if (_looksLikeSystemWindow(window.title)) continue;
      // Una ventana de juego ocupa una parte apreciable de la pantalla. El
      // umbral descarta paletas, notificaciones y ventanas de utilidades.
      if (window.width < 320 || window.height < 240) continue;
      final int area = window.width * window.height;
      if (area > bestArea) {
        bestArea = area;
        best = window;
      }
    }
    return best;
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
    _commit(
      _settings.copyWith(
        regionMode: RegionMode.followWindow,
        followWindowTitle: window.title,
        followOffsetX: region.left - window.left,
        followOffsetY: region.top - window.top,
        region: region,
      ),
    );
    _followConnected = true;
    toasts.success(
      t.panel.msgFollowing(window.title),
      detail: t.panel.msgFollowingDetail,
    );
  }

  void stopFollowingWindow() {
    toasts.info(t.panel.msgNotFollowing);
    _followHwnd = 0;
    _followConnected = false;
    _followLossReported = false;
    _commit(
      _settings.copyWith(
        regionMode: RegionMode.fixed,
        followWindowTitle: '',
        region: resolveCaptureRegion(),
      ),
    );
  }

  /// Vuelve a encontrar la ventana que se estaba siguiendo, por su título.
  ///
  /// Los identificadores de ventana de Windows no sobreviven a nada: cambian
  /// cada vez que el juego se abre, y no se pueden guardar en disco. Sin este
  /// reengancharse, "seguir ventana" solo funcionaba hasta cerrar Traducy o el
  /// juego, y después se comportaba como una zona fija sin decir nada, que es
  /// exactamente el sintoma de "no anda".
  ///
  /// El título tampoco es estable del todo (muchos juegos le añaden el capítulo o
  /// los FPS), así que se prueba primero la coincidencia exacta y luego una
  /// parcial, y si el título ha cambiado se guarda el nuevo.
  bool reacquireFollowWindow({bool quiet = false}) {
    final String wanted = _settings.followWindowTitle.trim();
    if (wanted.isEmpty) return false;

    ForeignWindow? exact;
    ForeignWindow? partial;
    for (final ForeignWindow window in listTopLevelWindows()) {
      final String title = window.title.trim();
      if (title == wanted) {
        exact = window;
        break;
      }
      if (partial == null &&
          (title.startsWith(wanted) ||
              wanted.startsWith(title) ||
              title.toLowerCase().contains(wanted.toLowerCase()))) {
        partial = window;
      }
    }

    final ForeignWindow? found = exact ?? partial;
    if (found == null) {
      _followConnected = false;
      if (!quiet && !_followLossReported) {
        _followLossReported = true;
        log.w('controller', 'No se encuentra la ventana "$wanted"');
        toasts.warning(
          t.panel.msgWindowLost(wanted),
          detail: t.panel.msgWindowLostDetail,
        );
      }
      return false;
    }

    _followHwnd = found.hwnd;
    _followConnected = true;
    _followLossReported = false;
    // El título pudo cambiar: se guarda el actual para que la próxima búsqueda
    // acierte a la primera.
    if (found.title.trim() != wanted) {
      _commit(_settings.copyWith(followWindowTitle: found.title.trim()));
    }
    if (!quiet) {
      log.i('controller', 'Reengachada a "${found.title}"');
    }
    return true;
  }

  void _recomputeFollowOffset() {
    if (_settings.regionMode != RegionMode.followWindow || _followHwnd == 0) {
      return;
    }
    final ({int left, int top, int width, int height})? rect =
        foreignWindowRect(_followHwnd);
    if (rect == null) return;
    _commit(
      _settings.copyWith(
        followOffsetX: _settings.region.left - rect.left,
        followOffsetY: _settings.region.top - rect.top,
      ),
    );
  }

  // -------------------------------------------------------------- motores

  OcrEngine _createOcrEngine() {
    if (_settings.engines.ocrKind == OcrKind.windows) {
      return WindowsOcr(languageTag: windowsOcrEffectiveTag);
    }
    return TesseractOcr(
      executablePath: _settings.engines.tesseractPath,
      languages: _settings.engines.ocrLanguages,
      psm: _settings.engines.psm,
      userTessdataDir: tessdataDirectory,
    );
  }

  /// Idiomas que el OCR de Windows puede reconocer en este equipo.
  ///
  /// Se consulta una vez y se guarda: la lista depende de los paquetes de idioma
  /// instalados, que no cambian mientras la aplicacion esta abierta.
  List<String> _windowsOcrLanguages = const <String>[];

  List<String> get windowsOcrLanguages => _windowsOcrLanguages;

  /// `true` si el motor de Windows esta disponible en este equipo.
  bool get windowsOcrAvailable => _windowsOcrLanguages.isNotEmpty;

  /// `true` si el motor de Windows tiene el idioma que se ha pedido.
  bool get windowsOcrCoversRequest =>
      WindowsOcr.covers(_windowsOcrLanguages, windowsOcrRequestedTag);

  /// Etiqueta BCP-47 que corresponde al idioma del juego (`jpn` -> `ja`).
  String get windowsOcrRequestedTag =>
      WindowsOcr.tagForTesseractCode(_settings.engines.ocrLanguages);

  /// Etiqueta concreta con la que se va a crear el motor.
  ///
  /// Se prefiere una de las que el sistema dice tener, incluida su variante
  /// regional: pedir `ja` cuando lo instalado es `ja-JP` funciona casi siempre,
  /// pero no en todas las versiones de Windows, y usar el nombre exacto que
  /// devuelve el sistema evita depender de eso.
  String get windowsOcrEffectiveTag {
    final String wanted = windowsOcrRequestedTag.toLowerCase();
    final String base = wanted.split('-').first;
    for (final String tag in _windowsOcrLanguages) {
      if (tag.toLowerCase() == wanted) return tag;
    }
    for (final String tag in _windowsOcrLanguages) {
      if (tag.toLowerCase().split('-').first == base) return tag;
    }
    return windowsOcrRequestedTag;
  }

  /// Cambia de motor de OCR y lo reinicia.
  Future<void> setOcrKind(OcrKind kind) async {
    if (_settings.engines.ocrKind == kind) return;
    _commit(
      _settings.copyWith(engines: _settings.engines.copyWith(ocrKind: kind)),
      rebuildEngines: true,
    );
    if (kind == OcrKind.windows) {
      _windowsOcrLanguages = await WindowsOcr.systemLanguages();
    } else {
      // Los idiomas del sistema no dicen nada sobre Tesseract, y dejarlos
      // puestos haria que la interfaz mezclara los dos motores.
      _installedOcrLanguages = const <String>[];
      _missingOcrLanguages = const <String>[];
    }
    await refreshEngineHealth();
    if (kind == OcrKind.windows) {
      await _autoDetectWindowsOcr();
    } else {
      // Se vuelve a mirar el equipo de verdad, no se da por hecho nada. Al
      // cambiar de motor las listas se vacian, y sin volver a detectar la guia
      // ofrecia descargar un idioma que el usuario ya tenia instalado.
      await autoDetectSetup();
    }
  }

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
      toasts.warning(t.panel.msgDownloadInProgress);
      return;
    }
    toasts.info(t.panel.msgDownloadingLanguage(language));
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
        t.panel.msgLanguageInstalled(language),
        detail: t.panel.msgSavedIn(tessdataDirectory),
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
      _downloadError = t.panel.msgDownloadUnexpected(language, '$e');
      log.e('controller', 'Fallo inesperado descargando "$language"', e);
      toasts.error(t.panel.msgDownloadFailed(language), detail: '$e');
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
    toasts.info(t.panel.msgLanguageFolderChanged, detail: tessdataDirectory);
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
        t.panel.msgTesseractInstallOpened,
        detail: t.panel.msgTesseractInstallOpenedDetail,
      );
    } catch (e) {
      log.e('controller', 'No se pudo lanzar winget', e);
      toasts.error(
        t.panel.msgInstallerFailed,
        detail: t.panel.msgInstallerFailedDetail,
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
      UpdateState(
        stage: UpdateStage.checking,
        message: t.panel.msgCheckingNewVersion,
      ),
    );
    if (!silent) toasts.info(t.panel.msgCheckingUpdates);

    try {
      final ReleaseInfo? release = await _updater.checkForUpdate();
      if (release == null) {
        _setUpdateState(
          UpdateState(message: t.panel.msgLatestVersion(appVersion)),
        );
        if (!silent) {
          toasts.success(t.panel.msgUpToDate, detail: appVersion);
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
          message: t.panel.msgVersionAvailable(release.version),
        ),
      );
      toasts.warning(
        t.panel.msgNewVersion(release.version),
        detail: _settings.autoUpdate
            ? t.panel.msgNewVersionAuto(release.readableSize)
            : t.panel.msgNewVersionManual(release.readableSize),
      );

      // Con la actualización automática no hay nada que pulsar: se descarga y se
      // instala sola. El bloqueo sigue estando, pero informa en lugar de esperar.
      if (_settings.autoUpdate) {
        await onRequestUpdateInstall();
      }
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
        UpdateState(
          stage: UpdateStage.failed,
          message: t.panel.msgUnexpectedError('$e'),
        ),
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
        message: t.panel.msgDownloadingVersion(release.version),
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
              message: t.panel.msgDownloadingVersion(release.version),
            ),
          );
        },
      );

      _setUpdateState(
        UpdateState(
          stage: UpdateStage.ready,
          release: release,
          message: t.panel.msgInstallingVersion(release.version),
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
      toasts.error(t.panel.msgUpdateFailed, detail: '$e');
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
    if (_settings.engines.ocrKind == OcrKind.windows) {
      await _autoDetectWindowsOcr();
      return;
    }
    // El cast es seguro tras la comprobacion de arriba, pero se hace con `is`
    // para que un motor nuevo en el futuro no acabe en una excepcion.
    final OcrEngine engine = _createOcrEngine();
    if (engine is! TesseractOcr) {
      engine.dispose();
      return;
    }
    final TesseractOcr probe = engine;
    try {
      final String? exe = await probe.resolveExecutable();
      if (exe == null) {
        toasts.error(
          t.panel.msgTesseractNotFound,
          detail: t.panel.msgTesseractNotFoundDetail,
        );
        return;
      }

      // Ruta encontrada por autodetección: se guarda para no repetir la búsqueda
      // en cada arranque, y para que el usuario vea de dónde sale.
      if (_settings.engines.tesseractPath.trim().isEmpty) {
        toasts.info(t.panel.msgTesseractFound, detail: exe);
      }

      final List<String> available = await probe.availableLanguages();
      final List<String> missing = await probe.missingLanguages();

      if (missing.isEmpty) {
        toasts.success(
          t.panel.msgOcrReady(_settings.engines.ocrLanguages),
          detail: t.panel.msgInstalledLanguages(available.join(', ')),
        );
        return;
      }

      // Falta el idioma configurado. Si hay otros, se nombran para que la
      // elección sea evidente en lugar de un simple "falta algo".
      final List<String> usable = available
          .where((String l) => l != 'osd')
          .toList();
      toasts.warning(
        t.panel.msgMissingOcrLanguage(missing.join(', ')),
        detail: usable.isEmpty
            ? t.panel.msgDownloadFromGuide
            : t.panel.msgOrUseInstalled(usable.join(', ')),
      );
    } catch (e) {
      log.w('controller', 'Autodetección incompleta: $e');
    } finally {
      probe.dispose();
    }
  }

  /// Elige el motor de OCR que de verdad funciona en este equipo.
  ///
  /// El de Windows viene por defecto porque es gratis y acierta mas, pero
  /// depende de un componente y de un paquete de idioma que no todos tienen. Si
  /// falta cualquiera de los dos, se pasa a Tesseract y se explica en la consola,
  /// en lugar de dejar la aplicacion sin traducir con un aviso que hay que ir a
  /// buscar. Solo ocurre en el arranque y solo hacia Tesseract: si el usuario
  /// elige un motor a mano, se respeta.
  Future<void> _pickWorkingOcrEngine() async {
    if (_settings.engines.ocrKind != OcrKind.windows) return;

    _windowsOcrLanguages = await WindowsOcr.systemLanguages();
    if (windowsOcrAvailable && windowsOcrCoversRequest) return;

    final String reason = windowsOcrAvailable
        ? t.panel.msgReasonNoLanguage
        : t.panel.msgReasonNoComponent;
    _commit(
      _settings.copyWith(
        engines: _settings.engines.copyWith(ocrKind: OcrKind.tesseract),
      ),
      rebuildEngines: true,
    );
    log.i('controller', 'Se usa Tesseract porque $reason');
    toasts.info(
      t.panel.msgFallbackToTesseract,
      detail: t.panel.msgFallbackToTesseractDetail(reason),
    );
  }

  /// Comprueba el motor del sistema y cuenta lo que encuentra.
  ///
  /// No toca nada de Windows. Si el idioma del juego no esta entre los que el
  /// sistema reconoce, la salida no es "instala un paquete de idioma": es pasar a
  /// Tesseract, que guarda sus idiomas dentro de la carpeta de Traducy y no
  /// cambia nada del equipo. Anadir el idioma a Windows queda como alternativa
  /// para quien la quiera, no como requisito.
  Future<void> _autoDetectWindowsOcr() async {
    _windowsOcrLanguages = await WindowsOcr.systemLanguages();
    notifyListeners();

    if (_windowsOcrLanguages.isEmpty) {
      toasts.warning(
        t.panel.msgNoOcrComponent,
        detail: t.panel.msgSwitchToTesseract,
      );
      return;
    }
    if (!windowsOcrCoversRequest) {
      toasts.warning(
        t.panel.msgWindowsCannotRead(_settings.engines.ocrLanguages),
        detail: t.panel.msgWindowsCannotReadDetail(
          _windowsOcrLanguages.join(', '),
        ),
      );
      return;
    }
    toasts.success(
      t.panel.msgWindowsOcrReady(windowsOcrEffectiveTag),
      detail: t.panel.msgWindowsOcrReadyDetail,
    );
  }

  Future<void> refreshEngineHealth() async {
    _ocrHealth = const EngineHealth(checking: true);
    _translatorHealth = const EngineHealth(checking: true);
    notifyListeners();

    final OcrEngine ocr = _createOcrEngine();
    try {
      final String? issue = await ocr.checkAvailability();
      _ocrHealth = EngineHealth(issue: issue, checkedAt: DateTime.now());
      if (ocr is WindowsOcr) {
        _windowsOcrLanguages = await WindowsOcr.systemLanguages();
        // Los paquetes de Tesseract no cuentan con este motor: si se dejaran, la
        // guia seguiria pidiendo descargar idiomas que no hacen falta.
        _installedOcrLanguages = const <String>[];
        _missingOcrLanguages = const <String>[];
      }
      if (ocr is TesseractOcr) {
        // Sistema + descargados: si solo se contase el sistema, un idioma
        // bajado por la app saldría como "no instalado" en el desplegable.
        _installedOcrLanguages = await ocr.availableLanguages();
        _missingOcrLanguages = await ocr.missingLanguages();
      }
    } catch (e) {
      _ocrHealth = EngineHealth(
        issue: t.panel.msgOcrCheckFailed('$e'),
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
        issue: t.panel.msgTranslatorCheckFailed('$e'),
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
      toasts.error(t.panel.msgCannotTranslateYet, detail: _ocrHealth.issue);
      return;
    }
    if (!resolveCaptureRegion().isValid) {
      setRegionToBottomBand();
      toasts.info(
        t.panel.msgBottomBandSet,
        detail: t.panel.msgBottomBandSetDetail,
      );
    }
    _pipeline?.start();
    notifyListeners();
    toasts.success(
      t.panel.msgTranslating,
      detail: t.panel.msgTranslatingDetail,
    );
  }

  void stopTranslating() {
    _pipeline?.stop();
    notifyListeners();
    toasts.info(t.panel.msgTranslationStopped);
  }

  void togglePause() {
    final TranslationPipeline? pipeline = _pipeline;
    if (pipeline == null) return;
    pipeline.toggle();
    notifyListeners();
    toasts.info(
      pipeline.isRunning
          ? t.panel.msgTranslationResumed
          : t.panel.msgTranslationPaused,
      detail: t.panel.msgToggleWithP,
    );
  }

  Future<void> testOnce() async {
    toasts.info(t.panel.msgTestingCapture);
    await _pipeline?.runOnce();
    notifyListeners();
    final PipelineStatus? status = _pipeline?.status.value;
    if (status == null) return;
    if (status.failedStage != null) {
      toasts.error(t.panel.msgTestFailed(status.message), detail: status.hint);
    } else {
      toasts.success(
        t.panel.msgTestDone(status.message),
        detail: t.panel.msgTestTimings(
          status.lastOcrMs,
          status.lastTranslateMs,
        ),
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
    regionPreview.dispose();
    subtitlePreview.dispose();
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
