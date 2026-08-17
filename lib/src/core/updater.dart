import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'about.dart';
import 'app_paths.dart';
import 'failures.dart';
import 'logx.dart';
import 'version.dart';

/// Una versión publicada en GitHub.
class ReleaseInfo {
  const ReleaseInfo({
    required this.version,
    required this.installerUrl,
    required this.sizeBytes,
    this.notes = '',
    this.publishedAt,
  });

  /// Versión visible, tal cual la etiqueta de la release (`1.0.0.bs`).
  final String version;

  /// URL del instalador adjunto.
  final String installerUrl;

  final int sizeBytes;
  final String notes;
  final DateTime? publishedAt;

  String get readableSize => '${(sizeBytes / 1048576).toStringAsFixed(1)} MB';
}

enum UpdateStage { idle, checking, available, downloading, ready, failed }

class UpdateState {
  const UpdateState({
    this.stage = UpdateStage.idle,
    this.release,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.message = '',
  });

  final UpdateStage stage;
  final ReleaseInfo? release;
  final int receivedBytes;
  final int totalBytes;
  final String message;

  double get fraction =>
      totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;

  String get readableProgress {
    String mb(int b) => '${(b / 1048576).toStringAsFixed(1)} MB';
    return totalBytes > 0
        ? '${mb(receivedBytes)} / ${mb(totalBytes)}'
        : mb(receivedBytes);
  }

  bool get isBusy =>
      stage == UpdateStage.checking || stage == UpdateStage.downloading;
}

/// Comprueba si hay una versión nueva y descarga su instalador.
///
/// Solo lee la API pública de GitHub, sin credenciales: el repositorio es
/// público a propósito para que la actualización funcione sin incrustar ningún
/// token en el ejecutable. Un token dentro de un `.exe` que se reparte es una
/// credencial regalada a cualquiera que lo tenga.
class Updater {
  Updater({http.Client? client, this.owner = _owner, this.repo = _repo})
    : _client = client ?? http.Client();

  static const String _owner = About.githubOwner;
  static const String _repo = About.githubRepo;

  final http.Client _client;
  final String owner;
  final String repo;

  Uri get _latestUri =>
      Uri.https('api.github.com', '/repos/$owner/$repo/releases/latest');

  /// Página de releases, para copiarla si algo falla.
  String get releasesPageUrl => About.releasesUrl;

  /// Consulta la última versión publicada.
  ///
  /// Devuelve `null` si la instalada ya está al día. Lanza `StageFailure` con un
  /// mensaje accionable si no se pudo comprobar.
  Future<ReleaseInfo?> checkForUpdate({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    http.Response response;
    try {
      response = await _client
          .get(
            _latestUri,
            headers: const <String, String>{
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
              'User-Agent': 'Traducy',
            },
          )
          .timeout(timeout);
    } catch (e) {
      throw StageFailure(
        Stage.render,
        'No se pudo comprobar si hay actualizaciones.',
        hint: 'Revisa tu conexión a internet.',
        cause: e,
      );
    }

    if (response.statusCode == 404) {
      throw StageFailure(
        Stage.render,
        'Todavía no hay ninguna versión publicada.',
        hint: 'Vuelve a intentarlo cuando exista la primera release.',
      );
    }
    if (response.statusCode == 403) {
      // La API pública limita a 60 peticiones por hora y por IP.
      throw StageFailure(
        Stage.render,
        'GitHub ha limitado las peticiones temporalmente.',
        hint: 'Espera unos minutos y vuelve a comprobar.',
      );
    }
    if (response.statusCode != 200) {
      throw StageFailure(
        Stage.render,
        'GitHub respondió con HTTP ${response.statusCode}.',
      );
    }

    try {
      final Object? decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) throw const FormatException('Raíz inesperada');

      final String tag = (decoded['tag_name'] as String? ?? '').trim();
      final String version = tag.startsWith('v') ? tag.substring(1) : tag;
      if (version.isEmpty) {
        throw const FormatException('Release sin etiqueta');
      }

      if (compareVersions(version, appVersion) <= 0) {
        log.i('updater', 'Ya está al día (instalada $appVersion, última $tag)');
        return null;
      }

      // Se busca el instalador entre los adjuntos. Una release sin .exe no sirve
      // para actualizar, aunque exista.
      final Object? assets = decoded['assets'];
      String? url;
      int size = 0;
      if (assets is List) {
        for (final Object? asset in assets) {
          if (asset is! Map) continue;
          final String name = (asset['name'] as String? ?? '').toLowerCase();
          if (name.endsWith('.exe') && name.contains('setup')) {
            url = asset['browser_download_url'] as String?;
            size = (asset['size'] as num?)?.toInt() ?? 0;
            break;
          }
        }
      }
      if (url == null) {
        throw StageFailure(
          Stage.render,
          'La versión $version no trae instalador adjunto.',
          hint: 'Descárgala a mano desde la página de releases.',
        );
      }

      return ReleaseInfo(
        version: version,
        installerUrl: url,
        sizeBytes: size,
        notes: (decoded['body'] as String? ?? '').trim(),
        publishedAt: DateTime.tryParse(
          decoded['published_at'] as String? ?? '',
        ),
      );
    } on StageFailure {
      rethrow;
    } catch (e) {
      throw StageFailure(
        Stage.render,
        'No se pudo interpretar la respuesta de GitHub.',
        cause: e,
      );
    }
  }

  /// Descarga el instalador y devuelve su ruta.
  ///
  /// Se escribe en un temporal y se renombra al final: así una descarga cortada
  /// nunca deja un `.exe` a medias que alguien pueda ejecutar.
  Future<File> downloadInstaller(
    ReleaseInfo release, {
    void Function(int received, int total)? onProgress,
    Duration timeout = const Duration(minutes: 10),
  }) async {
    final Directory folder = AppPaths.instance.updatesDirectory;
    try {
      await folder.create(recursive: true);
    } catch (e) {
      throw StageFailure(
        Stage.render,
        'No se pudo crear la carpeta de descargas.',
        hint: 'Comprueba los permisos de ${folder.path}',
        cause: e,
      );
    }

    final File target = File(
      '${folder.path}${Platform.pathSeparator}'
      'TraducySetup-${release.version}.exe',
    );
    final File temporary = File('${target.path}.part');

    http.StreamedResponse response;
    try {
      final http.Request request = http.Request(
        'GET',
        Uri.parse(release.installerUrl),
      );
      request.headers['User-Agent'] = 'Traducy';
      response = await _client.send(request).timeout(timeout);
    } catch (e) {
      throw StageFailure(
        Stage.render,
        'No se pudo descargar la actualización.',
        hint: 'Revisa tu conexión y vuelve a intentarlo.',
        cause: e,
      );
    }

    if (response.statusCode != 200) {
      throw StageFailure(
        Stage.render,
        'La descarga devolvió HTTP ${response.statusCode}.',
      );
    }

    IOSink? sink;
    int received = 0;
    final int total = response.contentLength ?? release.sizeBytes;
    try {
      sink = temporary.openWrite();
      await for (final List<int> chunk in response.stream.timeout(timeout)) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.flush();
      await sink.close();
      sink = null;
    } catch (e) {
      try {
        await sink?.close();
      } catch (_) {
        // Ya se está gestionando un fallo; cerrar no aporta nada más.
      }
      await _deleteQuietly(temporary);
      throw StageFailure(
        Stage.render,
        'La descarga se interrumpió.',
        hint: 'Comprueba la conexión y el espacio libre en disco.',
        cause: e,
      );
    }

    // Un instalador real pesa megas. Algo diminuto es una página de error.
    if (received < 1024 * 1024) {
      await _deleteQuietly(temporary);
      throw StageFailure(
        Stage.render,
        'El instalador descargado no es válido.',
        hint: 'Vuelve a intentarlo.',
      );
    }

    try {
      if (await target.exists()) await target.delete();
      await temporary.rename(target.path);
    } catch (e) {
      await _deleteQuietly(temporary);
      throw StageFailure(
        Stage.render,
        'No se pudo guardar el instalador.',
        cause: e,
      );
    }

    log.i('updater', 'Instalador descargado en ${target.path}');
    return target;
  }

  /// Lanza el instalador y devuelve el control.
  ///
  /// Se arranca desprendido del proceso para que pueda sustituir el ejecutable
  /// **después** de que Traducy se cierre. El instalador cierra la aplicación
  /// por su cuenta (`CloseApplications=yes`), pero salir de inmediato evita
  /// depender de eso.
  Future<void> launchInstaller(File installer) async {
    try {
      await Process.start(
        installer.path,
        // Sin ventana de bienvenida: viniendo de "actualizar" dentro de la app,
        // repetir el asistente completo sobra. Aun así muestra el progreso y
        // pide confirmación si hace falta elevar permisos.
        const <String>['/SILENT', '/NOCANCEL', '/RESTARTAPPLICATIONS'],
        mode: ProcessStartMode.detached,
      );
      log.i('updater', 'Instalador lanzado: ${installer.path}');
    } catch (e) {
      throw StageFailure(
        Stage.render,
        'No se pudo abrir el instalador.',
        hint: 'Ábrelo a mano: ${installer.path}',
        cause: e,
      );
    }
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Un temporal huérfano es molesto, no grave.
    }
  }

  void dispose() => _client.close();
}

/// Compara dos versiones con sufijo de letras (`1.0.0.bs`).
///
/// Devuelve <0 si `a` es anterior, 0 si iguales, >0 si `a` es posterior. Las
/// letras se ordenan primero por longitud y luego alfabéticamente, igual que la
/// numeración tipo hoja de cálculo que usa `tools/set_version.py`: 'z' va antes
/// de 'aa' porque 'aa' es la revisión 27.
int compareVersions(String a, String b) {
  final (List<int> numbersA, String suffixA) = _splitVersion(a);
  final (List<int> numbersB, String suffixB) = _splitVersion(b);

  for (int i = 0; i < 3; i++) {
    final int left = i < numbersA.length ? numbersA[i] : 0;
    final int right = i < numbersB.length ? numbersB[i] : 0;
    if (left != right) return left - right;
  }

  if (suffixA.length != suffixB.length) {
    return suffixA.length - suffixB.length;
  }
  return suffixA.compareTo(suffixB);
}

(List<int>, String) _splitVersion(String version) {
  String cleaned = version.trim();
  final RegExp suffixPattern = RegExp(r'\.?([a-z]+)$');
  final RegExpMatch? match = suffixPattern.firstMatch(cleaned);
  String suffix = '';
  if (match != null) {
    suffix = match.group(1)!;
    cleaned = cleaned.substring(0, match.start);
  }
  final List<int> numbers = cleaned
      .split('.')
      .map((String part) => int.tryParse(part) ?? 0)
      .toList();
  return (numbers, suffix);
}
