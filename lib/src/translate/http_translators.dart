import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/failures.dart';
import '../core/logx.dart';
import 'translator.dart';

/// Cliente HTTP compartido. Reutilizar una sola instancia mantiene vivas las
/// conexiones (keep-alive): en una traducción por segundo, ahorrarse el
/// handshake TLS en cada llamada se nota de verdad en la latencia.
class SharedHttpClient {
  SharedHttpClient._();
  static final http.Client instance = http.Client();
  static void close() => instance.close();
}

StageFailure _httpFailure(int statusCode, String body, String engine) {
  final String snippet = body.length > 200
      ? '${body.substring(0, 200)}…'
      : body;
  switch (statusCode) {
    case 401:
    case 403:
      return StageFailure(
        Stage.translate,
        '$engine rechazó la API key (no autorizado).',
        hint: 'Revisa la clave en la pestaña Motores.',
      );
    case 429:
      return StageFailure(
        Stage.translate,
        '$engine ha limitado la frecuencia de peticiones (429).',
        hint:
            'Aumenta el intervalo de captura o cambia a un motor sin límite '
            'de cuota.',
      );
    case 456:
      return StageFailure(
        Stage.translate,
        'Cuota de $engine agotada.',
        hint: 'Revisa tu plan o cambia de motor.',
      );
    default:
      return StageFailure(
        Stage.translate,
        '$engine devolvió HTTP $statusCode.',
        hint: snippet.isEmpty ? null : snippet,
      );
  }
}

// ---------------------------------------------------------------- Google web

/// Traductor por el endpoint web público de Google Translate.
///
/// No necesita clave, lo que lo hace el mejor valor por defecto para empezar a
/// usar la app sin configurar nada. Es un endpoint no oficial: puede limitar
/// peticiones si se abusa, y por eso el intervalo por defecto es de 350 ms y
/// hay caché delante.
class GoogleWebTranslator implements Translator {
  @override
  String get id => 'google_web';

  @override
  String get displayName => 'Google Traductor (gratis, sin clave)';

  @override
  bool get isMetered => false;

  @override
  Future<TranslationResult> translate(
    String text, {
    required String targetLanguage,
    String sourceLanguage = 'auto',
    required Duration timeout,
  }) async {
    final Stopwatch watch = Stopwatch()..start();
    final Uri uri = Uri.https(
      'translate.googleapis.com',
      '/translate_a/single',
      <String, String>{
        'client': 'gtx',
        'sl': sourceLanguage.isEmpty ? 'auto' : sourceLanguage,
        'tl': targetLanguage,
        'dt': 't',
        'q': text,
      },
    );

    final http.Response response = await SharedHttpClient.instance
        .get(uri, headers: const <String, String>{'User-Agent': 'Traducy/1.0'})
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw _httpFailure(response.statusCode, response.body, 'Google');
    }

    try {
      // La respuesta es un array anidado: [[[traducción, original, ...], ...], ...]
      final Object? decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List || decoded.isEmpty) {
        throw const FormatException('Estructura inesperada');
      }
      final Object? segments = decoded[0];
      if (segments is! List) {
        throw const FormatException('Sin segmentos de traducción');
      }

      final StringBuffer buffer = StringBuffer();
      for (final Object? segment in segments) {
        if (segment is List && segment.isNotEmpty && segment[0] is String) {
          buffer.write(segment[0] as String);
        }
      }

      final String? detected = decoded.length > 2 && decoded[2] is String
          ? decoded[2] as String
          : null;

      watch.stop();
      return TranslationResult(
        text: buffer.toString().trim(),
        fromCache: false,
        detectedLanguage: detected,
        durationMs: watch.elapsedMilliseconds,
      );
    } on StageFailure {
      rethrow;
    } catch (e) {
      throw StageFailure(
        Stage.translate,
        'No se pudo interpretar la respuesta de Google.',
        cause: e,
      );
    }
  }

  @override
  Future<String?> checkAvailability() async {
    try {
      await translate(
        'ok',
        targetLanguage: 'es',
        timeout: const Duration(seconds: 8),
      );
      return null;
    } on StageFailure catch (e) {
      return e.message;
    } catch (e) {
      return 'Sin conexión con Google Traductor: $e';
    }
  }

  @override
  void dispose() {}
}

// ------------------------------------------------------------- LibreTranslate

/// LibreTranslate: servidor propio o instancia pública. Es la opción para
/// traducir sin depender de terceros ni de internet, si se aloja en local.
class LibreTranslateTranslator implements Translator {
  LibreTranslateTranslator({required this.baseUrl, this.apiKey = ''});

  final String baseUrl;
  final String apiKey;

  @override
  String get id => 'libre';

  @override
  String get displayName => 'LibreTranslate (autoalojado)';

  @override
  bool get isMetered => false;

  Uri? _endpoint() {
    final String raw = baseUrl.trim();
    if (raw.isEmpty) return null;
    final Uri? parsed = Uri.tryParse(
      raw.startsWith('http') ? raw : 'http://$raw',
    );
    if (parsed == null || parsed.host.isEmpty) return null;
    // Acepta tanto la raíz del servidor como la ruta completa /translate.
    final String path = parsed.path.endsWith('/translate')
        ? parsed.path
        : '${parsed.path.replaceAll(RegExp(r'/+$'), '')}/translate';
    return parsed.replace(path: path);
  }

  @override
  Future<TranslationResult> translate(
    String text, {
    required String targetLanguage,
    String sourceLanguage = 'auto',
    required Duration timeout,
  }) async {
    final Uri? uri = _endpoint();
    if (uri == null) {
      throw StageFailure(
        Stage.translate,
        'La URL de LibreTranslate no es válida.',
        hint: 'Ejemplo: http://localhost:5000',
      );
    }

    final Stopwatch watch = Stopwatch()..start();
    final http.Response response = await SharedHttpClient.instance
        .post(
          uri,
          headers: const <String, String>{'Content-Type': 'application/json'},
          body: jsonEncode(<String, dynamic>{
            'q': text,
            'source': sourceLanguage.isEmpty ? 'auto' : sourceLanguage,
            'target': targetLanguage,
            'format': 'text',
            if (apiKey.isNotEmpty) 'api_key': apiKey,
          }),
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw _httpFailure(response.statusCode, response.body, 'LibreTranslate');
    }

    try {
      final Object? decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map || decoded['translatedText'] is! String) {
        throw const FormatException('Falta translatedText');
      }
      watch.stop();
      return TranslationResult(
        text: (decoded['translatedText'] as String).trim(),
        fromCache: false,
        durationMs: watch.elapsedMilliseconds,
      );
    } on StageFailure {
      rethrow;
    } catch (e) {
      throw StageFailure(
        Stage.translate,
        'Respuesta inesperada de LibreTranslate.',
        cause: e,
      );
    }
  }

  @override
  Future<String?> checkAvailability() async {
    if (_endpoint() == null) {
      return 'Indica la URL del servidor LibreTranslate (p. ej. http://localhost:5000).';
    }
    try {
      await translate(
        'ok',
        targetLanguage: 'es',
        sourceLanguage: 'en',
        timeout: const Duration(seconds: 8),
      );
      return null;
    } on StageFailure catch (e) {
      return e.message;
    } catch (e) {
      return 'No se pudo contactar con LibreTranslate: $e';
    }
  }

  @override
  void dispose() {}
}

// --------------------------------------------------------------------- DeepL

/// DeepL. Requiere clave; la calidad en prosa es notablemente superior a la de
/// los traductores estadísticos gratuitos.
class DeeplTranslator implements Translator {
  DeeplTranslator({required this.apiKey});

  final String apiKey;

  @override
  String get id => 'deepl';

  @override
  String get displayName => 'DeepL (requiere API key)';

  @override
  bool get isMetered => true;

  /// Las claves gratuitas terminan en `:fx` y usan otro host. Detectarlo evita
  /// el error 403 más común al configurar DeepL.
  String get _host =>
      apiKey.trim().endsWith(':fx') ? 'api-free.deepl.com' : 'api.deepl.com';

  @override
  Future<TranslationResult> translate(
    String text, {
    required String targetLanguage,
    String sourceLanguage = 'auto',
    required Duration timeout,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw StageFailure(
        Stage.translate,
        'Falta la API key de DeepL.',
        hint: 'Pégala en la pestaña Motores.',
      );
    }

    final Stopwatch watch = Stopwatch()..start();
    final http.Response response = await SharedHttpClient.instance
        .post(
          Uri.https(_host, '/v2/translate'),
          headers: <String, String>{
            'Authorization': 'DeepL-Auth-Key ${apiKey.trim()}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, dynamic>{
            'text': <String>[text],
            'target_lang': targetLanguage.toUpperCase(),
            if (sourceLanguage.isNotEmpty && sourceLanguage != 'auto')
              'source_lang': sourceLanguage.toUpperCase(),
          }),
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw _httpFailure(response.statusCode, response.body, 'DeepL');
    }

    try {
      final Object? decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) throw const FormatException('Raíz no es objeto');
      final Object? translations = decoded['translations'];
      if (translations is! List || translations.isEmpty) {
        throw const FormatException('Sin traducciones');
      }
      final Object? first = translations.first;
      if (first is! Map || first['text'] is! String) {
        throw const FormatException('Falta el campo text');
      }
      watch.stop();
      return TranslationResult(
        text: (first['text'] as String).trim(),
        fromCache: false,
        detectedLanguage: first['detected_source_language'] is String
            ? (first['detected_source_language'] as String).toLowerCase()
            : null,
        durationMs: watch.elapsedMilliseconds,
      );
    } on StageFailure {
      rethrow;
    } catch (e) {
      throw StageFailure(
        Stage.translate,
        'Respuesta inesperada de DeepL.',
        cause: e,
      );
    }
  }

  @override
  Future<String?> checkAvailability() async {
    if (apiKey.trim().isEmpty) return 'Falta la API key de DeepL.';
    try {
      await translate(
        'ok',
        targetLanguage: 'es',
        sourceLanguage: 'en',
        timeout: const Duration(seconds: 10),
      );
      return null;
    } on StageFailure catch (e) {
      return e.message;
    } catch (e) {
      return 'No se pudo contactar con DeepL: $e';
    }
  }

  @override
  void dispose() {}
}

// -------------------------------------------------------------------- Claude

/// Traducción con la API de Claude (Anthropic).
///
/// Es el motor de mayor calidad para videojuegos porque entiende el contexto:
/// mantiene el tono, respeta nombres propios y no traduce literalmente
/// expresiones idiomáticas. A cambio es de pago y añade algo de latencia, así
/// que el pensamiento extendido se desactiva y el esfuerzo se fija en bajo:
/// para una línea de diálogo no aporta calidad y sí retardo.
class ClaudeTranslator implements Translator {
  ClaudeTranslator({
    required this.apiKey,
    this.model = 'claude-opus-5',
    this.glossary = '',
  });

  final String apiKey;
  final String model;

  /// Términos que deben respetarse tal cual o traducirse de una forma concreta.
  final String glossary;

  static const String _apiVersion = '2023-06-01';

  @override
  String get id => 'claude';

  @override
  String get displayName => 'Claude (máxima calidad, requiere API key)';

  @override
  bool get isMetered => true;

  String _buildSystemPrompt(String targetLanguage) {
    final StringBuffer prompt = StringBuffer()
      ..writeln(
        'Traduces texto extraído por OCR de la pantalla de un videojuego.',
      )
      ..writeln(
        'Devuelve únicamente la traducción a $targetLanguage, sin comillas, '
        'sin comentarios y sin explicaciones.',
      )
      ..writeln(
        'Conserva el tono y el registro del original (formal, coloquial, '
        'arcaico) y mantén los saltos de línea.',
      )
      ..writeln(
        'No traduzcas nombres propios, de personajes, lugares, objetos, '
        'habilidades ni elementos de interfaz reconocibles.',
      )
      ..writeln(
        'El OCR puede introducir errores de reconocimiento: interpreta la '
        'intención más probable en lugar de traducir letra por letra.',
      )
      ..writeln(
        'Si el texto ya está en $targetLanguage, devuélvelo sin cambios.',
      );

    final String cleanGlossary = glossary.trim();
    if (cleanGlossary.isNotEmpty) {
      prompt
        ..writeln()
        ..writeln('Glosario de términos de obligado cumplimiento:')
        ..writeln(cleanGlossary);
    }
    return prompt.toString();
  }

  @override
  Future<TranslationResult> translate(
    String text, {
    required String targetLanguage,
    String sourceLanguage = 'auto',
    required Duration timeout,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw StageFailure(
        Stage.translate,
        'Falta la API key de Claude.',
        hint: 'Pégala en la pestaña Motores.',
      );
    }

    final Stopwatch watch = Stopwatch()..start();
    final http.Response response = await SharedHttpClient.instance
        .post(
          Uri.https('api.anthropic.com', '/v1/messages'),
          headers: <String, String>{
            'x-api-key': apiKey.trim(),
            'anthropic-version': _apiVersion,
            'content-type': 'application/json',
          },
          body: jsonEncode(<String, dynamic>{
            'model': model,
            'max_tokens': 1024,
            // Sin pensamiento extendido: en subtítulos en tiempo real la
            // latencia importa más que el razonamiento profundo.
            'thinking': <String, dynamic>{'type': 'disabled'},
            'output_config': <String, dynamic>{'effort': 'low'},
            'system': <Map<String, dynamic>>[
              <String, dynamic>{
                'type': 'text',
                'text': _buildSystemPrompt(targetLanguage),
                // El prompt de sistema es idéntico en cada llamada: cachearlo
                // recorta coste y latencia de forma notable.
                'cache_control': <String, dynamic>{'type': 'ephemeral'},
              },
            ],
            'messages': <Map<String, dynamic>>[
              <String, dynamic>{'role': 'user', 'content': text},
            ],
          }),
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw _httpFailure(response.statusCode, response.body, 'Claude');
    }

    try {
      final Object? decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) throw const FormatException('Raíz no es objeto');

      // Comprobar stop_reason antes de leer content: en un rechazo el array
      // de contenido puede venir vacío y un acceso directo por índice fallaría.
      if (decoded['stop_reason'] == 'refusal') {
        throw StageFailure(
          Stage.translate,
          'Claude declinó traducir este texto.',
          hint: 'Suele ocurrir con contenido sensible; prueba con otro motor.',
        );
      }

      final Object? content = decoded['content'];
      if (content is! List) throw const FormatException('Sin contenido');

      final StringBuffer buffer = StringBuffer();
      for (final Object? block in content) {
        if (block is Map &&
            block['type'] == 'text' &&
            block['text'] is String) {
          buffer.write(block['text'] as String);
        }
      }

      final String result = buffer.toString().trim();
      if (result.isEmpty && decoded['stop_reason'] == 'max_tokens') {
        throw StageFailure(
          Stage.translate,
          'La respuesta de Claude se truncó.',
          hint: 'Reduce el tamaño de la región de captura.',
        );
      }

      watch.stop();
      return TranslationResult(
        text: result,
        fromCache: false,
        durationMs: watch.elapsedMilliseconds,
      );
    } on StageFailure {
      rethrow;
    } catch (e) {
      throw StageFailure(
        Stage.translate,
        'Respuesta inesperada de Claude.',
        cause: e,
      );
    }
  }

  @override
  Future<String?> checkAvailability() async {
    if (apiKey.trim().isEmpty) return 'Falta la API key de Claude.';
    try {
      final TranslationResult result = await translate(
        'ok',
        targetLanguage: 'es',
        timeout: const Duration(seconds: 20),
      );
      log.d('translate', 'Claude respondió: ${result.text}');
      return null;
    } on StageFailure catch (e) {
      return e.message;
    } catch (e) {
      return 'No se pudo contactar con la API de Claude: $e';
    }
  }

  @override
  void dispose() {}
}
