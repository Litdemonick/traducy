import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/app_paths.dart';
import '../core/logx.dart';
import 'settings.dart';

/// Persistencia de ajustes en `%APPDATA%\Traducy\settings.json`.
///
/// La escritura es atómica (fichero temporal + renombrado) y la lectura tolera
/// un fichero corrupto: lo aparta como `.corrupt` y arranca con valores por
/// defecto en vez de dejar la app inservible.
class SettingsStore {
  SettingsStore({Directory? overrideDirectory})
    : _directory = overrideDirectory ?? AppPaths.instance.dataDirectory;

  final Directory _directory;
  Timer? _debounce;
  AppSettings? _pending;
  bool _writing = false;

  static const Duration _debounceDelay = Duration(milliseconds: 600);

  File get _file =>
      File('${_directory.path}${Platform.pathSeparator}settings.json');
  File get _tempFile =>
      File('${_directory.path}${Platform.pathSeparator}settings.json.tmp');

  String get filePath => _file.path;

  Future<AppSettings> load() async {
    try {
      if (!await _file.exists()) {
        log.i('settings', 'Sin ajustes previos, usando valores por defecto');
        return const AppSettings();
      }
      final String raw = await _file.readAsString();
      if (raw.trim().isEmpty) return const AppSettings();

      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('La raíz del JSON no es un objeto');
      }
      final AppSettings settings = AppSettings.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      log.i('settings', 'Ajustes cargados de ${_file.path}');
      return settings;
    } catch (e, st) {
      log.e(
        'settings',
        'Ajustes corruptos, se restauran los de fábrica',
        e,
        st,
      );
      await _quarantineCorruptFile();
      return const AppSettings();
    }
  }

  Future<void> _quarantineCorruptFile() async {
    try {
      if (await _file.exists()) {
        final String stamp = DateTime.now().millisecondsSinceEpoch.toString();
        await _file.rename('${_file.path}.corrupt-$stamp');
      }
    } catch (e) {
      log.w('settings', 'No se pudo apartar el fichero corrupto: $e');
    }
  }

  /// Guarda con retardo: la interfaz cambia ajustes en cada movimiento de un
  /// deslizador, y no tiene sentido escribir a disco en cada píxel.
  void saveDebounced(AppSettings settings) {
    _pending = settings;
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      final AppSettings? toSave = _pending;
      _pending = null;
      if (toSave != null) unawaited(save(toSave));
    });
  }

  Future<bool> save(AppSettings settings) async {
    if (_writing) {
      // Una escritura ya está en curso; deja el valor pendiente y sal. Así dos
      // guardados simultáneos nunca compiten por el mismo fichero temporal.
      _pending = settings;
      return false;
    }
    _writing = true;
    try {
      if (!await _directory.exists()) {
        await _directory.create(recursive: true);
      }
      final String json = const JsonEncoder.withIndent('  ')
          .convert(settings.toJson());

      await _tempFile.writeAsString(json, flush: true);
      // En Windows rename() falla si el destino existe, así que se borra primero.
      if (await _file.exists()) await _file.delete();
      await _tempFile.rename(_file.path);
      return true;
    } catch (e, st) {
      log.e('settings', 'No se pudieron guardar los ajustes', e, st);
      return false;
    } finally {
      _writing = false;
      final AppSettings? queued = _pending;
      if (queued != null) {
        _pending = null;
        unawaited(save(queued));
      }
    }
  }

  /// Vuelca lo pendiente inmediatamente. Se llama al cerrar la app para que no
  /// se pierda el último ajuste por culpa del retardo.
  Future<void> flush() async {
    _debounce?.cancel();
    _debounce = null;
    final AppSettings? toSave = _pending;
    _pending = null;
    if (toSave != null) await save(toSave);
  }

  void dispose() {
    _debounce?.cancel();
    _debounce = null;
  }
}
