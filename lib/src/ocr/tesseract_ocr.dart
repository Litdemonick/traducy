import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../core/failures.dart';
import '../core/logx.dart';
import 'ocr_engine.dart';

/// OCR local con Tesseract, invocado como proceso externo.
///
/// Se usa un proceso en lugar de enlazar la librería por FFI a propósito: si
/// Tesseract se cuelga o revienta con una imagen rara, se lleva por delante su
/// propio proceso y no el de la app. Es la diferencia entre "un fotograma
/// fallido" y "la aplicación se cerró".
/// `true` si todos los idiomas pedidos son de escritura CJK.
///
/// Se comprueba que lo sean *todos*: con `jpn+eng` hay texto latino de por
/// medio y sus espacios entre palabras si son informacion que hay que conservar.
bool _isCjkOnly(String languages) {
  const Set<String> cjk = <String>{
    'jpn',
    'jpn_vert',
    'chi_sim',
    'chi_sim_vert',
    'chi_tra',
    'chi_tra_vert',
    'kor',
    'kor_vert',
  };
  final List<String> parts = languages
      .split('+')
      .map((String part) => part.trim())
      .where((String part) => part.isNotEmpty)
      .toList();
  return parts.isNotEmpty && parts.every(cjk.contains);
}

class TesseractOcr implements OcrEngine {
  TesseractOcr({
    required String executablePath,
    required this.languages,
    required this.psm,
    this.userTessdataDir = '',
  }) : _configuredPath = executablePath.trim();

  @override
  String get id => 'tesseract';

  @override
  String get displayName => 'Tesseract (local)';

  final String languages;
  final int psm;

  /// Carpeta propia con los idiomas que ha descargado la aplicación.
  ///
  /// Existe porque la carpeta `tessdata` de la instalación está bajo
  /// `C:\Program Files` y escribir ahí exige permisos de administrador. Cuando
  /// todos los idiomas pedidos están aquí, se le pasa a Tesseract con
  /// `--tessdata-dir` y no hace falta tocar la instalación del sistema.
  final String userTessdataDir;

  final String _configuredPath;

  /// Idiomas solicitados, ya separados.
  List<String> get requestedLanguages => languages
      .split('+')
      .map((String s) => s.trim())
      .where((String s) => s.isNotEmpty)
      .toList();

  String? _resolvedPath;

  // No hay recursos que liberar: cada reconocimiento vive y muere en su propio
  // proceso. Se declara porque `implements` no hereda cuerpos.
  @override
  void dispose() {}

  static const List<String> _commonInstallPaths = <String>[
    r'C:\Program Files\Tesseract-OCR\tesseract.exe',
    r'C:\Program Files (x86)\Tesseract-OCR\tesseract.exe',
  ];

  /// Localiza el ejecutable: ruta configurada, luego PATH, luego las rutas de
  /// instalación habituales del instalador de UB-Mannheim.
  Future<String?> resolveExecutable() async {
    if (_resolvedPath != null) return _resolvedPath;

    if (_configuredPath.isNotEmpty) {
      if (await File(_configuredPath).exists()) {
        _resolvedPath = _configuredPath;
        return _resolvedPath;
      }
      log.w(
        'ocr',
        'La ruta configurada de Tesseract no existe: $_configuredPath',
      );
    }

    // PATH
    try {
      final ProcessResult where = await Process.run('where', <String>[
        'tesseract',
      ]).timeout(const Duration(seconds: 5));
      if (where.exitCode == 0) {
        final String first = where.stdout
            .toString()
            .split(RegExp(r'\r?\n'))
            .map((String s) => s.trim())
            .firstWhere((String s) => s.isNotEmpty, orElse: () => '');
        if (first.isNotEmpty && await File(first).exists()) {
          _resolvedPath = first;
          return _resolvedPath;
        }
      }
    } catch (e) {
      log.d('ocr', 'No se pudo consultar el PATH: $e');
    }

    for (final String candidate in _commonInstallPaths) {
      if (await File(candidate).exists()) {
        _resolvedPath = candidate;
        return _resolvedPath;
      }
    }

    // Instalación portable junto al ejecutable de la app.
    try {
      final String appDir = File(Platform.resolvedExecutable).parent.path;
      final String portable =
          '$appDir${Platform.pathSeparator}tesseract${Platform.pathSeparator}tesseract.exe';
      if (await File(portable).exists()) {
        _resolvedPath = portable;
        return _resolvedPath;
      }
    } catch (_) {
      // Sin acceso al directorio de la app; se ignora.
    }

    return null;
  }

  /// `true` si la carpeta propia contiene todos los idiomas solicitados.
  Future<bool> _userDirCoversRequest() async {
    if (userTessdataDir.isEmpty) return false;
    final List<String> requested = requestedLanguages;
    if (requested.isEmpty) return false;
    try {
      for (final String language in requested) {
        final File file = File(
          '$userTessdataDir${Platform.pathSeparator}$language.traineddata',
        );
        if (!await file.exists()) return false;
      }
      return true;
    } catch (e) {
      log.w('ocr', 'No se pudo comprobar la carpeta de idiomas propia: $e');
      return false;
    }
  }

  /// Todos los idiomas usables: los de la instalación de Tesseract más los que
  /// ha descargado la aplicación.
  ///
  /// La interfaz debe consultar esto y no solo los del sistema. Mirando solo el
  /// sistema, un idioma descargado por la app aparecía marcado como "no
  /// instalado" aunque el OCR lo estuviera usando sin problema.
  Future<List<String>> availableLanguages() async {
    final Set<String> all = <String>{
      ...await listLanguages(),
      ...await _ownLanguages(),
    };
    final List<String> sorted = all.toList()..sort();
    return sorted;
  }

  /// Idiomas solicitados que no están disponibles ni en el sistema ni en la
  /// carpeta propia. Es lo que la interfaz ofrece descargar.
  Future<List<String>> missingLanguages() async {
    final List<String> system = await listLanguages();
    final List<String> own = await _ownLanguages();
    if (system.isEmpty && own.isEmpty) return <String>[];
    return requestedLanguages
        .where((String l) => !system.contains(l) && !own.contains(l))
        .toList();
  }

  Future<List<String>> _ownLanguages() async {
    if (userTessdataDir.isEmpty) return <String>[];
    try {
      final Directory dir = Directory(userTessdataDir);
      if (!await dir.exists()) return <String>[];
      final List<String> found = <String>[];
      await for (final FileSystemEntity entity in dir.list()) {
        if (entity is! File) continue;
        final String name = entity.uri.pathSegments.last;
        if (name.endsWith('.traineddata')) {
          found.add(name.substring(0, name.length - '.traineddata'.length));
        }
      }
      return found;
    } catch (_) {
      return <String>[];
    }
  }

  @override
  Future<String?> checkAvailability() async {
    final String? exe = await resolveExecutable();
    if (exe == null) {
      return 'No se encontró Tesseract OCR. Instálalo (winget install '
          'UB-Mannheim.TesseractOCR) o indica la ruta del ejecutable en Motores.';
    }
    try {
      final ProcessResult result = await Process.run(exe, <String>[
        '--version',
      ]).timeout(const Duration(seconds: 8));
      if (result.exitCode != 0) {
        return 'Tesseract respondió con código ${result.exitCode}.';
      }
    } catch (e) {
      return 'No se pudo ejecutar Tesseract: $e';
    }

    final List<String> missing = await missingLanguages();
    if (missing.isNotEmpty) {
      return 'Falta el paquete de idioma "${missing.join(', ')}" del OCR. '
          'Púlsalo para descargarlo: sin él no se puede reconocer ese idioma.';
    }
    return null;
  }

  /// Idiomas con datos instalados (códigos de tessdata).
  Future<List<String>> listLanguages() async {
    final String? exe = await resolveExecutable();
    if (exe == null) return <String>[];
    try {
      final ProcessResult result = await Process.run(exe, <String>[
        '--list-langs',
      ]).timeout(const Duration(seconds: 8));
      // --list-langs escribe la cabecera en stderr y la lista en stdout según
      // la versión, así que se leen ambos.
      final String combined = '${result.stdout}\n${result.stderr}';
      return combined
          .split(RegExp(r'\r?\n'))
          .map((String s) => s.trim())
          .where(
            (String s) =>
                s.isNotEmpty &&
                !s.contains(':') &&
                !s.contains(' ') &&
                RegExp(r'^[a-zA-Z_]{3,}$').hasMatch(s),
          )
          .toList();
    } catch (e) {
      log.d('ocr', 'No se pudieron listar los idiomas: $e');
      return <String>[];
    }
  }

  @override
  Future<OcrResult> recognize(
    Uint8List png, {
    required Duration timeout,
  }) async {
    final Stopwatch watch = Stopwatch()..start();
    final String? exe = await resolveExecutable();
    if (exe == null) {
      throw StageFailure(
        Stage.ocr,
        'Tesseract no está disponible.',
        hint:
            'Instálalo con: winget install UB-Mannheim.TesseractOCR — '
            'o indica la ruta manualmente en la pestaña Motores.',
      );
    }

    // Si nuestra carpeta cubre todos los idiomas pedidos se usa esa; si no, se
    // deja que Tesseract busque en la del sistema. Mezclar ambas no es posible:
    // --tessdata-dir sustituye la ruta de búsqueda, no la amplía.
    final bool useUserDir = await _userDirCoversRequest();

    final List<String> args = <String>[
      'stdin', // leer la imagen por la entrada estándar
      'stdout', // escribir el texto por la salida estándar
      '-l',
      languages.isEmpty ? 'eng' : languages,
      if (useUserDir) ...<String>['--tessdata-dir', userTessdataDir],
      '--psm',
      psm.toString(),
      // Evita el aviso "Estimating resolution" en imágenes sin metadatos DPI.
      '--dpi',
      '96',
      // Solo para escrituras que separan palabras con espacios. En japones,
      // chino y coreano Tesseract mete un espacio entre casi cada caracter, y
      // conservarlos deja un texto que el traductor no entiende como palabras.
      if (!_isCjkOnly(languages)) ...<String>[
        '-c',
        'preserve_interword_spaces=1',
      ],
    ];

    Process? process;
    try {
      process = await Process.start(exe, args);

      // stdout y stderr se drenan en paralelo mientras se escribe la entrada.
      // Si no se drenan, un stderr lleno bloquea el proceso hijo y el timeout
      // sería el único freno: un cuelgue silencioso en cada fotograma.
      final Future<String> stdoutFuture = process.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .join();
      final Future<String> stderrFuture = process.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .join();

      process.stdin.add(png);
      await process.stdin.flush();
      await process.stdin.close();

      final List<Object> results = await Future.wait(<Future<Object>>[
        stdoutFuture,
        stderrFuture,
        process.exitCode,
      ]).timeout(timeout);

      final String out = results[0] as String;
      final String err = results[1] as String;
      final int exitCode = results[2] as int;

      if (exitCode != 0) {
        throw StageFailure(
          Stage.ocr,
          'Tesseract terminó con código $exitCode.',
          hint: err.trim().isEmpty ? null : err.trim().split('\n').first,
        );
      }

      final String text = normalizeOcrText(out);
      watch.stop();
      return OcrResult(text: text, durationMs: watch.elapsedMilliseconds);
    } on TimeoutException {
      process?.kill(ProcessSignal.sigkill);
      throw StageFailure(
        Stage.ocr,
        'El OCR tardó más de ${timeout.inMilliseconds} ms.',
        hint:
            'Reduce el tamaño de la región de captura o baja la escala de '
            'preprocesado.',
      );
    } on StageFailure {
      rethrow;
    } catch (e) {
      process?.kill(ProcessSignal.sigkill);
      throw StageFailure(Stage.ocr, 'Fallo al ejecutar el OCR.', cause: e);
    }
  }
}
