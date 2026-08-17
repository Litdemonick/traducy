import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'src/core/logx.dart';
import 'src/native/overlay_native.dart';
import 'src/native/screen_capture.dart';
import 'src/state/app_controller.dart';
import 'src/ui/hotkeys.dart';
import 'src/ui/overlay_root.dart';
import 'src/ui/tray.dart';

Future<void> main() async {
  // Cualquier excepción no capturada se registra en lugar de tumbar la app: un
  // overlay que desaparece a mitad de partida es el peor fallo posible aquí.
  FlutterError.onError = (FlutterErrorDetails details) {
    log.e(
      'flutter',
      details.exceptionAsString(),
      details.exception,
      details.stack,
    );
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    log.e('platform', 'Error asíncrono sin capturar', error, stack);
    return true; // tratado: no propagar
  };

  // Un widget que falla al construirse no puede dejar un rectangulo rojo
  // ocupando la pantalla por encima del juego. Se sustituye por algo diminuto y
  // discreto: el fallo queda en el registro, que es donde sirve de algo, y el
  // resto de la interfaz sigue funcionando.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    log.e(
      'widget',
      details.exceptionAsString(),
      details.exception,
      details.stack,
    );
    return const SizedBox.shrink();
  };

  WidgetsFlutterBinding.ensureInitialized();

  if (!Platform.isWindows) {
    // La captura de pantalla y el overlay usan la API de Windows directamente.
    runApp(const _UnsupportedPlatformApp());
    return;
  }

  await _initializeWindow();
  runApp(const TraducyApp());
}

Future<void> _initializeWindow() async {
  try {
    await windowManager.ensureInitialized();
  } catch (e, st) {
    log.e('boot', 'window_manager no se pudo inicializar', e, st);
  }

  // flutter_acrylic da transparencia real a través del compositor de Windows.
  // Si falla, la aplicación sigue arrancando y se anota en el registro: el fondo
  // se verá opaco, pero todo lo demás funciona y el diagnóstico dice por qué.
  try {
    await Window.initialize();
    await Window.setEffect(
      effect: WindowEffect.transparent,
      color: Colors.transparent,
    );
  } catch (e) {
    log.w('boot', 'Sin transparencia por compositor: $e');
  }

  const WindowOptions options = WindowOptions(
    size: Size(1280, 800),
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
    // El título identifica la ventana en el sistema; la app se coloca a sí
    // misma sobre todo el escritorio en cuanto arranca el controlador.
    title: 'Traducy',
  );

  try {
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setAsFrameless();
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setHasShadow(false);
      await windowManager.setResizable(false);

      // La ventana se lleva a su tamaño final **antes** de mostrarla.
      //
      // Redimensionarla después de arrancar provocaba que apareciese enorme y
      // pixelada: el motor gráfico ya había creado su superficie de dibujo al
      // tamaño inicial y Windows la estiraba hasta el nuevo. Dimensionar
      // primero y mostrar después evita esa carrera por completo.
      final ({int left, int top, int width, int height}) screen =
          ScreenCapture.virtualScreenBounds();
      if (screen.width > 0 && screen.height > 0) {
        OverlayNative().setBoundsPhysical(
          left: screen.left,
          top: screen.top,
          width: screen.width,
          height: screen.height,
        );
      }

      await windowManager.show();
    });
  } catch (e, st) {
    log.e('boot', 'Fallo al preparar la ventana', e, st);
  }

  // Recomendación del paquete: limpiar registros huérfanos de una ejecución
  // anterior que terminase de forma abrupta.
  try {
    await hotKeyManager.unregisterAll();
  } catch (e) {
    log.w('boot', 'No se pudieron limpiar los atajos previos: $e');
  }
}

class TraducyApp extends StatefulWidget {
  const TraducyApp({super.key});

  @override
  State<TraducyApp> createState() => _TraducyAppState();
}

class _TraducyAppState extends State<TraducyApp>
    with WindowListener, TrayListener {
  final AppController _controller = AppController();
  final HotkeyService _hotkeys = HotkeyService();
  final TrayService _tray = TrayService();
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    trayManager.addListener(this);
    // No se puede cerrar sin pasar por nuestro código: hay ajustes pendientes
    // de volcar a disco, atajos globales que liberar y un icono de bandeja que
    // retirar (si no, quedaría un icono fantasma hasta pasar el ratón por él).
    windowManager.setPreventClose(true);
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    // El actualizador necesita cerrar la app para que el instalador pueda
    // sustituir el ejecutable; se le presta el cierre ordenado de aquí.
    _controller.shutdownHook = _exit;
    await _controller.initialize();
    await _hotkeys.register(
      onToggleConfig: () => unawaited(_controller.toggleConfigMode()),
      onTogglePause: _controller.togglePause,
      onToggleSubtitles: _controller.toggleSubtitlesVisible,
    );
    await _tray.setUp();
  }

  // ------------------------------------------------------------- bandeja

  /// Clic izquierdo: recuperar la ventana **y** abrir el panel de control. Es
  /// el gesto que espera cualquiera con un icono en la bandeja; restaurar solo
  /// un overlay transparente dejaría la sensación de que no ha pasado nada.
  @override
  void onTrayIconMouseDown() {
    unawaited(_controller.restoreOverlay(openPanel: true));
  }

  @override
  void onTrayIconRightMouseDown() {
    unawaited(_tray.showContextMenu());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case TrayAction.show:
        unawaited(_controller.restoreOverlay(openPanel: true));
      case TrayAction.togglePause:
        _controller.togglePause();
      case TrayAction.toggleSubtitles:
        _controller.toggleSubtitlesVisible();
      case TrayAction.exit:
        unawaited(_exit());
    }
  }

  @override
  void onWindowClose() {
    unawaited(_exit());
  }

  /// Minimizar y restaurar también ocurren desde fuera: el botón de la barra de
  /// tareas, Win+D o Alt+Tab. Se avisa al controlador para que pare o reanude la
  /// captura y reafirme la geometría al volver.
  @override
  void onWindowMinimize() {
    _controller.onSystemMinimize();
  }

  @override
  void onWindowRestore() {
    _controller.onSystemRestore();
  }

  /// Cierre en orden y a prueba de bloqueos.
  ///
  /// Termina con `exit(0)` a propósito. Desmontar el árbol de widgets mientras
  /// el pipeline libera sus `ValueNotifier` provocaba excepciones de "usado
  /// después de liberar", y `windowManager.destroy()` sobre una ventana
  /// transparente por capas se queda colgado en algunos equipos. Los ajustes ya
  /// están volcados a disco cuando llegamos aquí, así que no hay nada que
  /// perder y sí un cuelgue que evitar.
  Future<void> _exit() async {
    if (_closing) return;
    _closing = true;

    // Cada paso tiene su propio límite de tiempo: uno lento no debe impedir la
    // salida ni dejar la ventana a medio cerrar.
    Future<void> step(String name, Future<void> Function() action) async {
      try {
        await action().timeout(const Duration(seconds: 3));
      } catch (e) {
        log.w('exit', '$name no terminó limpiamente: $e');
      }
    }

    // Primero se para el trabajo en curso, para que ningún ciclo toque
    // recursos mientras se cierran.
    try {
      _controller.pipeline?.stop();
    } catch (_) {
      // Sin consecuencias: el proceso termina de todos modos.
    }

    await step('atajos', _hotkeys.unregisterAll);
    // El icono se retira antes de salir; si no, Windows deja un icono fantasma
    // en la bandeja hasta que el usuario pasa el ratón por encima.
    await step('bandeja', _tray.dispose);
    await step('ajustes', _controller.shutdown);
    await step('ventana', () async {
      await windowManager.setPreventClose(false);
      await windowManager.hide();
    });

    log.i('exit', 'Traducy cerrado');
    exit(0);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Traducy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4FC3F7),
          brightness: Brightness.dark,
        ),
        // Fondo transparente en toda la jerarquía: es lo que permite ver el
        // juego por debajo del overlay.
        scaffoldBackgroundColor: Colors.transparent,
        canvasColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        // Barra de desplazamiento discreta pero siempre presente: se ve cuánto
        // contenido queda sin que reste espacio ni cante sobre el panel oscuro.
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStateProperty.resolveWith<Color>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.dragged)) {
              return const Color(0xFF4FC3F7);
            }
            if (states.contains(WidgetState.hovered)) {
              return const Color(0xFF6E6E7A);
            }
            return const Color(0xFF4A4A55);
          }),
          trackColor: const WidgetStatePropertyAll<Color>(Color(0x1AFFFFFF)),
          trackBorderColor: const WidgetStatePropertyAll<Color>(
            Color(0x00000000),
          ),
          crossAxisMargin: 2,
          mainAxisMargin: 4,
          minThumbLength: 36,
        ),
      ),
      home: Material(
        type: MaterialType.transparency,
        child: OverlayRoot(
          controller: _controller,
          onExit: () => unawaited(_exit()),
        ),
      ),
    );
  }
}

class _UnsupportedPlatformApp extends StatelessWidget {
  const _UnsupportedPlatformApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Traducy solo funciona en Windows: la captura de pantalla y el '
              'overlay usan la API de Windows directamente.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
