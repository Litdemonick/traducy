import 'dart:async';
import 'dart:collection';

import '../core/failures.dart';
import '../core/logx.dart';

class TranslationResult {
  const TranslationResult({
    required this.text,
    required this.fromCache,
    this.detectedLanguage,
    this.durationMs = 0,
  });

  final String text;
  final bool fromCache;
  final String? detectedLanguage;
  final int durationMs;
}

abstract class Translator {
  String get id;
  String get displayName;

  /// `true` si el motor consume una API de pago o con cuota. La interfaz lo usa
  /// para avisar antes de subir la frecuencia de captura.
  bool get isMetered => false;

  Future<TranslationResult> translate(
    String text, {
    required String targetLanguage,
    String sourceLanguage = 'auto',
    required Duration timeout,
  });

  /// `null` si el motor está listo; si no, un mensaje accionable.
  Future<String?> checkAvailability();

  void dispose() {}
}

/// Traductor nulo: deja pasar el texto original. Sirve para usar la app solo
/// como lupa de OCR, o para depurar el reconocimiento sin gastar traducciones.
class PassthroughTranslator implements Translator {
  @override
  String get id => 'none';

  @override
  String get displayName => 'Sin traducir (mostrar original)';

  @override
  bool get isMetered => false;

  @override
  Future<TranslationResult> translate(
    String text, {
    required String targetLanguage,
    String sourceLanguage = 'auto',
    required Duration timeout,
  }) async => TranslationResult(text: text, fromCache: false);

  @override
  Future<String?> checkAvailability() async => null;

  @override
  void dispose() {}
}

/// Caché LRU de traducciones.
///
/// Los juegos repiten texto constantemente: menús, nombres de objetos, la misma
/// línea de diálogo mientras el jugador la lee. Sin caché, cada repetición
/// serían una llamada de red y una espera; con ella, respuesta instantánea.
class TranslationCache {
  TranslationCache({this.maxEntries = 600});

  final int maxEntries;
  final LinkedHashMap<String, String> _entries =
      LinkedHashMap<String, String>();

  int get length => _entries.length;

  String _key(String engineId, String source, String target, String text) =>
      '$engineId|$source|$target|$text';

  String? get(String engineId, String source, String target, String text) {
    final String key = _key(engineId, source, target, text);
    final String? value = _entries.remove(key);
    // Reinsertar mueve la entrada al final: así lo más usado sobrevive.
    if (value != null) _entries[key] = value;
    return value;
  }

  void put(
    String engineId,
    String source,
    String target,
    String text,
    String translation,
  ) {
    final String key = _key(engineId, source, target, text);
    _entries.remove(key);
    _entries[key] = translation;
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  void clear() => _entries.clear();
}

/// Cortacircuitos. Tras varios fallos seguidos deja de intentarlo un rato en
/// lugar de castigar una API caída (o agotar la cuota) fotograma tras fotograma.
class CircuitBreaker {
  CircuitBreaker({
    this.failureThreshold = 4,
    this.openDuration = const Duration(seconds: 20),
  });

  final int failureThreshold;
  final Duration openDuration;

  int _consecutiveFailures = 0;
  DateTime? _openedAt;

  bool get isOpen {
    final DateTime? openedAt = _openedAt;
    if (openedAt == null) return false;
    if (DateTime.now().difference(openedAt) >= openDuration) {
      // Se cierra a modo de prueba: el siguiente intento decide si sigue roto.
      _openedAt = null;
      _consecutiveFailures = failureThreshold - 1;
      return false;
    }
    return true;
  }

  Duration get remainingCooldown {
    final DateTime? openedAt = _openedAt;
    if (openedAt == null) return Duration.zero;
    final Duration elapsed = DateTime.now().difference(openedAt);
    final Duration left = openDuration - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  void recordSuccess() {
    _consecutiveFailures = 0;
    _openedAt = null;
  }

  void recordFailure() {
    _consecutiveFailures++;
    if (_consecutiveFailures >= failureThreshold && _openedAt == null) {
      _openedAt = DateTime.now();
      log.w(
        'translate',
        'Cortacircuitos abierto tras $_consecutiveFailures fallos; '
            'pausa de ${openDuration.inSeconds} s',
      );
    }
  }

  void reset() {
    _consecutiveFailures = 0;
    _openedAt = null;
  }
}

/// Decorador que añade caché, reintentos y cortacircuitos a cualquier
/// traductor. El pipeline solo habla con esta clase, así que las políticas de
/// resiliencia viven en un único sitio en lugar de repetirse en cada motor.
class ResilientTranslator {
  ResilientTranslator({
    required this.inner,
    TranslationCache? cache,
    CircuitBreaker? breaker,
    this.maxAttempts = 2,
  }) : cache = cache ?? TranslationCache(),
       _breaker = breaker ?? CircuitBreaker();

  final Translator inner;
  final TranslationCache cache;
  final CircuitBreaker _breaker;
  final int maxAttempts;

  bool get isCircuitOpen => _breaker.isOpen;
  Duration get cooldown => _breaker.remainingCooldown;

  Future<TranslationResult> translate(
    String text, {
    required String targetLanguage,
    String sourceLanguage = 'auto',
    required Duration timeout,
  }) async {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const TranslationResult(text: '', fromCache: false);
    }

    final String? cached = cache.get(
      inner.id,
      sourceLanguage,
      targetLanguage,
      trimmed,
    );
    if (cached != null) {
      return TranslationResult(text: cached, fromCache: true);
    }

    if (_breaker.isOpen) {
      throw StageFailure(
        Stage.translate,
        'Traducción en pausa ${_breaker.remainingCooldown.inSeconds} s tras '
        'varios fallos seguidos.',
        hint: 'Revisa la conexión, la API key o cambia de motor.',
      );
    }

    Object? lastError;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final TranslationResult result = await inner
            .translate(
              trimmed,
              targetLanguage: targetLanguage,
              sourceLanguage: sourceLanguage,
              timeout: timeout,
            )
            .timeout(timeout);
        _breaker.recordSuccess();
        if (result.text.trim().isNotEmpty) {
          cache.put(
            inner.id,
            sourceLanguage,
            targetLanguage,
            trimmed,
            result.text,
          );
        }
        return result;
      } catch (e) {
        lastError = e;
        // Un fallo permanente (clave inválida, idioma no soportado) no mejora
        // reintentando: se corta ya y se informa.
        if (e is StageFailure &&
            e.stage == Stage.translate &&
            _isPermanent(e)) {
          _breaker.recordFailure();
          rethrow;
        }
        if (attempt < maxAttempts) {
          await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
        }
      }
    }

    _breaker.recordFailure();
    if (lastError is StageFailure) throw lastError;
    throw StageFailure(
      Stage.translate,
      'No se pudo traducir tras $maxAttempts intentos.',
      cause: lastError,
    );
  }

  bool _isPermanent(StageFailure failure) {
    final String message = failure.message.toLowerCase();
    return message.contains('api key') ||
        message.contains('no autorizado') ||
        message.contains('inválid') ||
        message.contains('no soportado');
  }

  Future<String?> checkAvailability() => inner.checkAvailability();

  void resetBreaker() => _breaker.reset();

  void dispose() {
    inner.dispose();
    cache.clear();
  }
}
