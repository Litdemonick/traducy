import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/app_paths.dart';
import '../core/failures.dart';
import '../core/logx.dart';

/// Progreso de una descarga de datos de idioma.
class DownloadProgress {
  const DownloadProgress({
    required this.language,
    required this.receivedBytes,
    required this.totalBytes,
  });

  final String language;
  final int receivedBytes;

  /// `0` si el servidor no informa del tamaño.
  final int totalBytes;

  double get fraction =>
      totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;

  String get readable {
    final String received = _mb(receivedBytes);
    return totalBytes > 0 ? '$received / ${_mb(totalBytes)}' : received;
  }

  static String _mb(int bytes) => '${(bytes / 1048576).toStringAsFixed(1)} MB';
}

/// Descarga datos de idioma de Tesseract a una carpeta propia de la aplicación.
///
/// No se escribe en `C:\Program Files\Tesseract-OCR\tessdata` a propósito: esa
/// ruta exige permisos de administrador, y pedirlos para añadir un idioma sería
/// desproporcionado. En su lugar los ficheros van a `%APPDATA%\Traducy\tessdata`
/// y al invocar el OCR se le indica esa carpeta con `--tessdata-dir`.
class TessdataInstaller {
  TessdataInstaller({Directory? overrideDirectory, http.Client? client})
    : _directory = overrideDirectory ?? _defaultDirectory(),
      _client = client ?? http.Client();

  final Directory _directory;
  final http.Client _client;

  /// Modelos "fast": son los adecuados para traducir en tiempo real. Los
  /// "best" reconocen algo mejor pero pesan varias veces más y tardan bastante
  /// más por fotograma, lo que se nota enseguida a tres capturas por segundo.
  static const String _baseUrl =
      'https://github.com/tesseract-ocr/tessdata_fast/raw/main';

  static Directory _defaultDirectory() => AppPaths.instance.tessdataDirectory;

  String get directoryPath => _directory.path;

  File _fileFor(String language) =>
      File('${_directory.path}${Platform.pathSeparator}$language.traineddata');

  /// Idiomas ya descargados por la aplicación.
  Future<List<String>> installedLanguages() async {
    try {
      if (!await _directory.exists()) return <String>[];
      final List<String> found = <String>[];
      await for (final FileSystemEntity entity in _directory.list()) {
        if (entity is! File) continue;
        final String name = entity.uri.pathSegments.last;
        if (!name.endsWith('.traineddata')) continue;
        // Un fichero a medio descargar no cuenta como idioma disponible.
        if (await entity.length() < 1024) continue;
        found.add(name.substring(0, name.length - '.traineddata'.length));
      }
      found.sort();
      return found;
    } catch (e) {
      log.w('tessdata', 'No se pudo listar la carpeta de idiomas: $e');
      return <String>[];
    }
  }

  Future<bool> hasLanguage(String language) async {
    try {
      final File file = _fileFor(language);
      return await file.exists() && await file.length() > 1024;
    } catch (_) {
      return false;
    }
  }

  /// Descarga un idioma. Lanza `StageFailure` con un mensaje accionable si algo
  /// va mal, en lugar de dejar un fichero corrupto en la carpeta.
  Future<void> download(
    String language, {
    void Function(DownloadProgress progress)? onProgress,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final String clean = language.trim();
    // Los códigos vienen de una lista cerrada, pero esto viaja a una URL: más
    // vale rechazar cualquier cosa rara que construir una petición con ella.
    if (!RegExp(r'^[a-zA-Z_]{2,12}$').hasMatch(clean)) {
      throw StageFailure(Stage.ocr, 'Código de idioma no válido: "$language".');
    }

    final File target = _fileFor(clean);
    final File temporary = File('${target.path}.part');

    try {
      await _directory.create(recursive: true);
    } catch (e) {
      throw StageFailure(
        Stage.ocr,
        'No se pudo crear la carpeta de idiomas.',
        hint: 'Comprueba los permisos de ${_directory.path}',
        cause: e,
      );
    }

    http.StreamedResponse response;
    try {
      final http.Request request = http.Request(
        'GET',
        Uri.parse('$_baseUrl/$clean.traineddata'),
      );
      response = await _client.send(request).timeout(timeout);
    } catch (e) {
      throw StageFailure(
        Stage.ocr,
        'No se pudo conectar para descargar el idioma "$clean".',
        hint: 'Revisa tu conexión a internet y vuelve a intentarlo.',
        cause: e,
      );
    }

    if (response.statusCode == 404) {
      throw StageFailure(
        Stage.ocr,
        'No existe un paquete de idioma llamado "$clean".',
        hint: 'Comprueba el código en la pestaña Idiomas.',
      );
    }
    if (response.statusCode != 200) {
      throw StageFailure(
        Stage.ocr,
        'La descarga devolvió HTTP ${response.statusCode}.',
        hint: 'Inténtalo de nuevo en unos minutos.',
      );
    }

    IOSink? sink;
    int received = 0;
    final int total = response.contentLength ?? 0;
    try {
      sink = temporary.openWrite();
      await for (final List<int> chunk in response.stream.timeout(timeout)) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(
          DownloadProgress(
            language: clean,
            receivedBytes: received,
            totalBytes: total,
          ),
        );
      }
      await sink.flush();
      await sink.close();
      sink = null;
    } catch (e) {
      // Se cierra y se borra el parcial: dejar un .part suelto haría que el
      // siguiente intento arrancase sobre basura.
      try {
        await sink?.close();
      } catch (_) {
        // Ya estamos gestionando un fallo; el cierre no aporta nada más.
      }
      await _deleteQuietly(temporary);
      throw StageFailure(
        Stage.ocr,
        'La descarga de "$clean" se interrumpió.',
        hint: 'Comprueba la conexión y el espacio libre en disco.',
        cause: e,
      );
    }

    // Un fichero de idioma real pesa megas; si llega algo diminuto es una página
    // de error disfrazada de descarga.
    if (received < 100 * 1024) {
      await _deleteQuietly(temporary);
      throw StageFailure(
        Stage.ocr,
        'El fichero descargado para "$clean" no es válido.',
        hint:
            'Vuelve a intentarlo; puede haber fallado la red a media descarga.',
      );
    }

    try {
      if (await target.exists()) await target.delete();
      await temporary.rename(target.path);
    } catch (e) {
      await _deleteQuietly(temporary);
      throw StageFailure(
        Stage.ocr,
        'No se pudo guardar el idioma "$clean".',
        hint: 'Cierra otros programas que puedan estar usando el fichero.',
        cause: e,
      );
    }

    log.i(
      'tessdata',
      'Idioma "$clean" instalado (${DownloadProgress._mb(received)}) en '
          '${_directory.path}',
    );
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Un temporal huérfano es molesto, no grave; se sobrescribirá.
    }
  }

  void dispose() => _client.close();
}
