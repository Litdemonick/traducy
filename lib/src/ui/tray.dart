import 'package:tray_manager/tray_manager.dart';

import '../core/logx.dart';
import '../i18n/strings.dart';

/// Claves de los elementos del menú de la bandeja.
///
/// Se usan constantes en lugar de comparar etiquetas: las etiquetas cambian al
/// traducir o al retocar el texto, y una comparación por texto se rompería en
/// silencio.
class TrayAction {
  static const String show = 'show';
  static const String togglePause = 'toggle_pause';
  static const String toggleSubtitles = 'toggle_subtitles';
  static const String exit = 'exit';
}

/// Icono en la bandeja del sistema.
///
/// Es lo que permite que Traducy viva en segundo plano: al minimizar, la ventana
/// desaparece por completo y el único rastro es este icono, desde el que se
/// recupera con un clic o se maneja con el botón derecho.
class TrayService {
  static const String _iconAsset = 'assets/tray_icon.ico';

  bool _ready = false;
  bool get isReady => _ready;

  /// Crea el icono y su menú. Devuelve `false` si no se pudo: la app sigue
  /// siendo utilizable con los atajos globales y la barra de tareas, así que un
  /// fallo aquí no es motivo para abortar el arranque.
  Future<bool> setUp() async {
    try {
      await trayManager.setIcon(_iconAsset);
      await trayManager.setToolTip(t.trayTooltip);
      await trayManager.setContextMenu(
        Menu(
          items: <MenuItem>[
            MenuItem(key: TrayAction.show, label: t.trayOpen),
            MenuItem.separator(),
            MenuItem(key: TrayAction.togglePause, label: t.trayTogglePause),
            MenuItem(
              key: TrayAction.toggleSubtitles,
              label: t.trayToggleSubtitles,
            ),
            MenuItem.separator(),
            MenuItem(key: TrayAction.exit, label: t.trayExit),
          ],
        ),
      );
      _ready = true;
      log.i('tray', 'Icono de bandeja creado');
      return true;
    } catch (e, st) {
      log.e('tray', 'No se pudo crear el icono de bandeja', e, st);
      _ready = false;
      return false;
    }
  }

  /// Despliega el menú contextual. En Windows lo pide el clic derecho.
  Future<void> showContextMenu() async {
    if (!_ready) return;
    try {
      await trayManager.popUpContextMenu();
    } catch (e) {
      log.w('tray', 'No se pudo abrir el menú de bandeja: $e');
    }
  }

  Future<void> dispose() async {
    if (!_ready) return;
    try {
      await trayManager.destroy();
    } catch (e) {
      log.w('tray', 'No se pudo retirar el icono de bandeja: $e');
    }
    _ready = false;
  }
}
