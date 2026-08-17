import 'dart:io';

import 'logx.dart';

/// Decide dónde guarda Traducy sus cosas.
///
/// Regla única: **todo vive junto al programa**, en la carpeta que el usuario
/// eligió al instalar. Si instaló en `D:\Juegos\Traducy`, sus ajustes, los
/// idiomas del OCR y las descargas de actualizaciones están en
/// `D:\Juegos\Traducy\datos`. Nada se reparte entre dos sitios.
///
/// El instalador concede permiso de escritura a esa subcarpeta (`users-modify`),
/// así que funciona igual en `C:\Program Files` que en un USB, sin pedir
/// permisos de administrador al abrir la aplicación.
///
/// Queda un respaldo a `%APPDATA%` para el caso en que la carpeta no admita
/// escritura de verdad: compilar y ejecutar desde una ruta protegida sin pasar
/// por el instalador, o una unidad de solo lectura. Sin ese respaldo, los
/// ajustes no se guardarían y nada lo explicaría.
class AppPaths {
  AppPaths._({
    required this.dataDirectory,
    required this.isBesideProgram,
    this.fallbackReason,
  });

  /// Carpeta raíz de todos los datos de la aplicación.
  final Directory dataDirectory;

  /// `true` si los datos están junto al programa, como debe ser.
  final bool isBesideProgram;

  /// Explicación de por qué se tuvo que recurrir a `%APPDATA%`, o `null` si no
  /// hizo falta. La interfaz lo muestra para que no haya misterio sobre dónde
  /// acabaron los ficheros.
  final String? fallbackReason;

  static AppPaths? _instance;

  /// Nombre de la subcarpeta de datos. Coincide con la que crea el instalador.
  static const String dataFolderName = 'datos';

  static AppPaths get instance => _instance ??= _resolve();

  /// Comprueba escribiendo de verdad, no consultando permisos.
  ///
  /// Los permisos de Windows tienen suficientes capas (ACL, herencia,
  /// virtualización de carpetas protegidas) para que consultarlos dé respuestas
  /// engañosas. Crear y borrar un fichero es la única prueba que no miente.
  static bool _canWriteInto(Directory directory) {
    File? probe;
    try {
      directory.createSync(recursive: true);
      probe = File(
        '${directory.path}${Platform.pathSeparator}'
        '.escritura-${DateTime.now().microsecondsSinceEpoch}',
      );
      probe.writeAsStringSync('ok', flush: true);
      return true;
    } catch (_) {
      return false;
    } finally {
      try {
        if (probe != null && probe.existsSync()) probe.deleteSync();
      } catch (_) {
        // Si no se puede borrar la prueba, tampoco se podía escribir: da igual.
      }
    }
  }

  static AppPaths _resolve() {
    String? reason;

    try {
      final Directory exeDir = File(Platform.resolvedExecutable).parent;
      final Directory beside = Directory(
        '${exeDir.path}${Platform.pathSeparator}$dataFolderName',
      );
      if (_canWriteInto(beside)) {
        log.i('paths', 'Datos junto al programa: ${beside.path}');
        return AppPaths._(dataDirectory: beside, isBesideProgram: true);
      }
      reason =
          'La carpeta ${beside.path} no admite escritura, así que los datos '
          'van a la carpeta del usuario. Reinstala en una ubicación con '
          'permisos si quieres tenerlo todo junto al programa.';
      log.w('paths', reason);
    } catch (e) {
      reason = 'No se pudo usar la carpeta del programa: $e';
      log.w('paths', reason);
    }

    final String? appData = Platform.environment['APPDATA'];
    final String base = appData != null && appData.trim().isNotEmpty
        ? appData
        // Último recurso para sesiones muy restringidas sin APPDATA definido.
        : Directory.systemTemp.path;
    return AppPaths._(
      dataDirectory: Directory('$base${Platform.pathSeparator}Traducy'),
      isBesideProgram: false,
      fallbackReason: reason,
    );
  }

  /// Fichero de ajustes.
  File get settingsFile =>
      File('${dataDirectory.path}${Platform.pathSeparator}settings.json');

  /// Carpeta de paquetes de idioma descargados por la aplicación.
  Directory get tessdataDirectory =>
      Directory('${dataDirectory.path}${Platform.pathSeparator}tessdata');

  /// Idioma que eligió el usuario en el instalador, si lo dejó escrito.
  ///
  /// Lo escribe el instalador de Inno con el idioma de su asistente. Se lee una
  /// sola vez, en el primer arranque: quien instala en inglés abre Traducy en
  /// inglés sin tener que buscar el ajuste. Después manda lo que elija en el
  /// panel.
  File get installerLanguageFile =>
      File('${dataDirectory.path}${Platform.pathSeparator}idioma.txt');

  /// Carpeta donde el actualizador guarda los instaladores que descarga.
  Directory get updatesDirectory =>
      Directory('${dataDirectory.path}${Platform.pathSeparator}updates');

  /// Solo para pruebas: permite forzar una raíz distinta.
  static void overrideForTesting(Directory directory) {
    _instance = AppPaths._(dataDirectory: directory, isBesideProgram: true);
  }
}
