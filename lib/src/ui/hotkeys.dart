import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import '../core/logx.dart';

/// Atajos globales. Son la única forma de manejar la app mientras el juego
/// tiene el foco, así que si el registro falla se avisa pero la app sigue
/// usable desde el panel.
class HotkeyService {
  bool _registered = false;

  /// Registra los tres atajos. Devuelve la lista de los que no se pudieron
  /// registrar (normalmente porque otro programa ya los tiene tomados).
  Future<List<String>> register({
    required VoidCallback onToggleConfig,
    required VoidCallback onTogglePause,
    required VoidCallback onToggleSubtitles,
  }) async {
    final List<String> failed = <String>[];
    try {
      await hotKeyManager.unregisterAll();
    } catch (e) {
      log.w('hotkeys', 'unregisterAll falló: $e');
    }

    Future<void> tryRegister(
      String label,
      PhysicalKeyboardKey key,
      VoidCallback handler,
    ) async {
      try {
        await hotKeyManager.register(
          HotKey(
            identifier: 'traducy_$label',
            key: key,
            modifiers: const <HotKeyModifier>[
              HotKeyModifier.control,
              HotKeyModifier.alt,
            ],
            scope: HotKeyScope.system,
          ),
          keyDownHandler: (_) => handler(),
        );
      } catch (e) {
        log.w('hotkeys', 'No se pudo registrar $label: $e');
        failed.add(label);
      }
    }

    await tryRegister('Ctrl+Alt+T', PhysicalKeyboardKey.keyT, onToggleConfig);
    await tryRegister('Ctrl+Alt+P', PhysicalKeyboardKey.keyP, onTogglePause);
    await tryRegister(
      'Ctrl+Alt+H',
      PhysicalKeyboardKey.keyH,
      onToggleSubtitles,
    );

    _registered = true;
    if (failed.isEmpty) {
      log.i('hotkeys', 'Atajos globales registrados');
    } else {
      log.w('hotkeys', 'Atajos no disponibles: ${failed.join(', ')}');
    }
    return failed;
  }

  Future<void> unregisterAll() async {
    if (!_registered) return;
    try {
      await hotKeyManager.unregisterAll();
    } catch (e) {
      log.w('hotkeys', 'Fallo al liberar los atajos: $e');
    }
    _registered = false;
  }
}
