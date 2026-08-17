import 'dart:io';

import 'logx.dart';

/// Decide dónde guarda Traducy sus cosas.
///
/// Hay un único sitio que resuelve esto para que no haya dos partes de la
/// aplicación escribiendo en carpetas distintas. Dos modos:
///
///  - **Instalado** (por defecto): todo en `%APPDATA%\Traducy`. Es lo correcto
///    en Windows porque la carpeta del programa suele estar bajo
///    `C:\Program Files`, donde un programa sin privilegios no puede escribir.
///
///  - **Portátil**: si junto al ejecutable hay un fichero `portable.txt`, todo
///    va a `datos\` dentro de la propia carpeta del programa. Lo crea el
///    instalador cuando se marca esa opción, y sirve para llevar Traducy en un
///    USB o para tenerlo todo en la unidad que el usuario elija.
class AppPaths {
  AppPaths._({required this.dataDirectory, required this.isPortable});

  /// Carpeta raíz de todos los datos de la aplicación.
  final Directory dataDirectory;

  /// `true` si se está usando la carpeta del programa en lugar de `%APPDATA%`.
  final bool isPortable;

  static AppPaths? _instance;

  /// Marca que activa el modo portátil, creada por el instalador.
  static const String portableMarker = 'portable.txt';

  static AppPaths get instance => _instance ??= _resolve();

  static AppPaths _resolve() {
    try {
      final Directory exeDir = File(Platform.resolvedExecutable).parent;
      final File marker = File(
        '${exeDir.path}${Platform.pathSeparator}$portableMarker',
      );
      if (marker.existsSync()) {
        final Directory data = Directory(
          '${exeDir.path}${Platform.pathSeparator}datos',
        );
        log.i('paths', 'Modo portátil: datos en ${data.path}');
        return AppPaths._(dataDirectory: data, isPortable: true);
      }
    } catch (e) {
      // Sin acceso al directorio del ejecutable se sigue con %APPDATA%, que es
      // el comportamiento normal.
      log.w('paths', 'No se pudo comprobar el modo portátil: $e');
    }

    final String? appData = Platform.environment['APPDATA'];
    final String base = appData != null && appData.trim().isNotEmpty
        ? appData
        // Último recurso para sesiones muy restringidas sin APPDATA definido.
        : Directory.systemTemp.path;
    final Directory data = Directory('$base${Platform.pathSeparator}Traducy');
    return AppPaths._(dataDirectory: data, isPortable: false);
  }

  /// Fichero de ajustes.
  File get settingsFile =>
      File('${dataDirectory.path}${Platform.pathSeparator}settings.json');

  /// Carpeta de paquetes de idioma descargados por la aplicación.
  Directory get tessdataDirectory =>
      Directory('${dataDirectory.path}${Platform.pathSeparator}tessdata');

  /// Solo para pruebas: permite forzar una raíz distinta.
  static void overrideForTesting(Directory directory) {
    _instance = AppPaths._(dataDirectory: directory, isPortable: false);
  }
}
