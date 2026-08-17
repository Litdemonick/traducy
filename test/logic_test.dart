import 'dart:ui' show Size;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:traducy/src/core/failures.dart';
import 'package:traducy/src/core/updater.dart';
import 'package:traducy/src/models/settings.dart';
import 'package:traducy/src/ocr/image_prep.dart';
import 'package:traducy/src/ocr/ocr_engine.dart';
import 'package:traducy/src/translate/translator.dart';

void main() {
  group('normalizeOcrText', () {
    test('une líneas partidas por el ancho de la caja', () {
      const String raw = 'El caballero avanzó hacia\nla puerta sellada.';
      expect(
        normalizeOcrText(raw),
        'El caballero avanzó hacia la puerta sellada.',
      );
    });

    test('respeta el salto cuando la línea anterior cierra frase', () {
      const String raw = '¿Quién eres?\nNo importa.';
      expect(normalizeOcrText(raw), '¿Quién eres?\nNo importa.');
    });

    test('descarta líneas que solo son ruido', () {
      expect(normalizeOcrText('|\n~\nHola'), 'Hola');
    });

    test('descarta letras sueltas pero conserva dígitos sueltos', () {
      expect(normalizeOcrText('a'), '');
      expect(normalizeOcrText('7'), '7');
    });

    test('colapsa espacios múltiples', () {
      expect(normalizeOcrText('Hola     mundo'), 'Hola mundo');
    });

    test('entrada vacía o en blanco devuelve cadena vacía', () {
      expect(normalizeOcrText(''), '');
      expect(normalizeOcrText('   \n  \n '), '');
    });
  });

  group('ocrComparisonKey', () {
    test('ignora puntuación y mayúsculas', () {
      expect(ocrComparisonKey('¡Hola, mundo!'), ocrComparisonKey('hola mundo'));
    });

    test('distingue textos realmente distintos', () {
      expect(
        ocrComparisonKey('abrir la puerta'),
        isNot(ocrComparisonKey('cerrar la puerta')),
      );
    });
  });

  group('huella de imagen', () {
    Uint8List solidFrame(int width, int height, int value) {
      final Uint8List bytes = Uint8List(width * height * 4);
      for (int i = 0; i < bytes.length; i += 4) {
        bytes[i] = value;
        bytes[i + 1] = value;
        bytes[i + 2] = value;
        bytes[i + 3] = 255;
      }
      return bytes;
    }

    test('dos fotogramas idénticos dan distancia cero', () {
      final Uint8List a = computeSignature(solidFrame(64, 32, 120), 64, 32);
      final Uint8List b = computeSignature(solidFrame(64, 32, 120), 64, 32);
      expect(signatureDistance(a, b), 0);
    });

    test('un cambio grande de brillo da distancia grande', () {
      final Uint8List dark = computeSignature(solidFrame(64, 32, 10), 64, 32);
      final Uint8List light = computeSignature(solidFrame(64, 32, 240), 64, 32);
      expect(signatureDistance(dark, light), greaterThan(200));
    });

    test('la huella tiene siempre el mismo tamaño', () {
      expect(
        computeSignature(solidFrame(11, 7, 50), 11, 7).length,
        signatureSide * signatureSide,
      );
      expect(
        computeSignature(solidFrame(1920, 40, 50), 1920, 40).length,
        signatureSide * signatureSide,
      );
    });

    test('huellas de tamaños distintos se consideran diferentes', () {
      expect(signatureDistance(Uint8List(4), Uint8List(8)), 255);
    });
  });

  group('CaptureRegion', () {
    test('recorta contra los límites de la pantalla', () {
      const CaptureRegion region = CaptureRegion(
        left: -50,
        top: -20,
        width: 400,
        height: 100,
      );
      final CaptureRegion clamped = region.clampTo(
        boundsLeft: 0,
        boundsTop: 0,
        boundsWidth: 1920,
        boundsHeight: 1080,
      );
      expect(clamped.left, 0);
      expect(clamped.top, 0);
      expect(clamped.width, 400);
    });

    test('no deja que la región se salga por la derecha', () {
      const CaptureRegion region = CaptureRegion(
        left: 1900,
        top: 100,
        width: 400,
        height: 100,
      );
      final CaptureRegion clamped = region.clampTo(
        boundsLeft: 0,
        boundsTop: 0,
        boundsWidth: 1920,
        boundsHeight: 1080,
      );
      expect(clamped.right, lessThanOrEqualTo(1920));
    });

    test('una región minúscula no se considera válida', () {
      expect(
        const CaptureRegion(left: 0, top: 0, width: 4, height: 4).isValid,
        isFalse,
      );
      expect(
        const CaptureRegion(left: 0, top: 0, width: 300, height: 80).isValid,
        isTrue,
      );
    });
  });

  group('serialización de ajustes', () {
    test('sobrevive a una ida y vuelta por JSON', () {
      const AppSettings original = AppSettings(
        region: CaptureRegion(left: 10, top: 20, width: 800, height: 200),
        regionLocked: true,
        subtitleLocked: true,
        engines: EngineSettings(
          ocrLanguages: 'jpn',
          sourceLanguage: 'ja',
          targetLanguage: 'es',
          translator: TranslatorKind.claude,
        ),
        style: SubtitleStyle(fontSize: 42, showOriginal: true),
      );

      final AppSettings restored = AppSettings.fromJson(original.toJson());

      expect(restored.region.width, 800);
      expect(restored.regionLocked, isTrue);
      expect(restored.subtitleLocked, isTrue);
      expect(restored.engines.ocrLanguages, 'jpn');
      expect(restored.engines.translator, TranslatorKind.claude);
      expect(restored.style.fontSize, 42);
      expect(restored.style.showOriginal, isTrue);
    });

    test('un JSON vacío produce los valores por defecto', () {
      final AppSettings settings = AppSettings.fromJson(<String, dynamic>{});
      expect(settings.engines.targetLanguage, 'es');
      expect(settings.pipeline.intervalMs, 350);
      expect(settings.regionLocked, isFalse);
    });

    test('valores corruptos caen a los valores por defecto sin lanzar', () {
      final AppSettings settings = AppSettings.fromJson(<String, dynamic>{
        'region': 'esto no es un objeto',
        'style': <String, dynamic>{'fontSize': 'grande'},
        'pipeline': <String, dynamic>{'intervalMs': null},
        'engines': <String, dynamic>{'translator': 'motor_inexistente'},
        'regionLocked': 'quizá',
      });
      expect(settings.region.width, 0);
      expect(settings.style.fontSize, 30);
      expect(settings.pipeline.intervalMs, 350);
      expect(settings.engines.translator, TranslatorKind.googleFree);
      expect(settings.regionLocked, isFalse);
    });

    test('los valores fuera de rango se recortan al cargar', () {
      final AppSettings settings = AppSettings.fromJson(<String, dynamic>{
        'style': <String, dynamic>{'fontSize': 9999, 'maxLines': 0},
        'pipeline': <String, dynamic>{'intervalMs': 5},
        'preprocess': <String, dynamic>{'scale': 100},
      });
      expect(settings.style.fontSize, 96);
      expect(settings.style.maxLines, 1);
      expect(settings.pipeline.intervalMs, 120);
      expect(settings.preprocess.scale, 4.0);
    });
  });

  group('TranslationCache', () {
    test('devuelve lo guardado con la misma clave', () {
      final TranslationCache cache = TranslationCache();
      cache.put('google', 'ja', 'es', 'こんにちは', 'hola');
      expect(cache.get('google', 'ja', 'es', 'こんにちは'), 'hola');
    });

    test('la clave incluye el motor y los idiomas', () {
      final TranslationCache cache = TranslationCache();
      cache.put('google', 'ja', 'es', 'hello', 'hola');
      expect(cache.get('deepl', 'ja', 'es', 'hello'), isNull);
      expect(cache.get('google', 'en', 'es', 'hello'), isNull);
      expect(cache.get('google', 'ja', 'fr', 'hello'), isNull);
    });

    test('desaloja la entrada menos usada al llegar al límite', () {
      final TranslationCache cache = TranslationCache(maxEntries: 2);
      cache.put('g', 'a', 'b', 'uno', '1');
      cache.put('g', 'a', 'b', 'dos', '2');
      // Consultar "uno" lo vuelve reciente, así que "dos" es el candidato.
      cache.get('g', 'a', 'b', 'uno');
      cache.put('g', 'a', 'b', 'tres', '3');

      expect(cache.get('g', 'a', 'b', 'uno'), '1');
      expect(cache.get('g', 'a', 'b', 'dos'), isNull);
      expect(cache.get('g', 'a', 'b', 'tres'), '3');
      expect(cache.length, 2);
    });
  });

  group('CircuitBreaker', () {
    test('se abre al alcanzar el umbral de fallos', () {
      final CircuitBreaker breaker = CircuitBreaker(failureThreshold: 3);
      expect(breaker.isOpen, isFalse);
      breaker.recordFailure();
      breaker.recordFailure();
      expect(breaker.isOpen, isFalse);
      breaker.recordFailure();
      expect(breaker.isOpen, isTrue);
    });

    test('un éxito reinicia la cuenta', () {
      final CircuitBreaker breaker = CircuitBreaker(failureThreshold: 2);
      breaker.recordFailure();
      breaker.recordSuccess();
      breaker.recordFailure();
      expect(breaker.isOpen, isFalse);
    });

    test('se vuelve a cerrar cuando pasa el tiempo de espera', () async {
      final CircuitBreaker breaker = CircuitBreaker(
        failureThreshold: 1,
        openDuration: const Duration(milliseconds: 30),
      );
      breaker.recordFailure();
      expect(breaker.isOpen, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 45));
      expect(breaker.isOpen, isFalse);
    });
  });

  group('ResilientTranslator', () {
    test('sirve de la caché sin volver a llamar al motor', () async {
      final _CountingTranslator inner = _CountingTranslator();
      final ResilientTranslator translator = ResilientTranslator(inner: inner);

      final TranslationResult first = await translator.translate(
        'hello',
        targetLanguage: 'es',
        timeout: const Duration(seconds: 1),
      );
      final TranslationResult second = await translator.translate(
        'hello',
        targetLanguage: 'es',
        timeout: const Duration(seconds: 1),
      );

      expect(first.fromCache, isFalse);
      expect(second.fromCache, isTrue);
      expect(second.text, first.text);
      expect(inner.calls, 1);
    });

    test('reintenta un fallo transitorio', () async {
      final _FlakyTranslator inner = _FlakyTranslator(failuresBeforeSuccess: 1);
      final ResilientTranslator translator = ResilientTranslator(
        inner: inner,
        maxAttempts: 2,
      );

      final TranslationResult result = await translator.translate(
        'hola',
        targetLanguage: 'en',
        timeout: const Duration(seconds: 1),
      );
      expect(result.text, 'ok');
      expect(inner.calls, 2);
    });

    test('no reintenta un fallo permanente de credenciales', () async {
      final _AlwaysFailingTranslator inner = _AlwaysFailingTranslator(
        StageFailure(Stage.translate, 'Falta la API key de DeepL.'),
      );
      final ResilientTranslator translator = ResilientTranslator(
        inner: inner,
        maxAttempts: 3,
      );

      await expectLater(
        translator.translate(
          'hola',
          targetLanguage: 'en',
          timeout: const Duration(seconds: 1),
        ),
        throwsA(isA<StageFailure>()),
      );
      expect(
        inner.calls,
        1,
        reason: 'una clave inválida no mejora reintentando',
      );
    });

    test('el texto vacío no llega al motor', () async {
      final _CountingTranslator inner = _CountingTranslator();
      final ResilientTranslator translator = ResilientTranslator(inner: inner);
      final TranslationResult result = await translator.translate(
        '   ',
        targetLanguage: 'es',
        timeout: const Duration(seconds: 1),
      );
      expect(result.text, '');
      expect(inner.calls, 0);
    });
  });

  group('PassthroughTranslator', () {
    test('devuelve el texto tal cual', () async {
      final PassthroughTranslator translator = PassthroughTranslator();
      final TranslationResult result = await translator.translate(
        'texto original',
        targetLanguage: 'es',
        timeout: const Duration(seconds: 1),
      );
      expect(result.text, 'texto original');
    });
  });

  group('compareVersions', () {
    test('ordena por los tres numeros', () {
      expect(compareVersions('1.0.0', '1.0.1'), lessThan(0));
      expect(compareVersions('1.1.0', '1.0.9'), greaterThan(0));
      expect(compareVersions('2.0.0', '1.9.9'), greaterThan(0));
      expect(compareVersions('1.2.3', '1.2.3'), 0);
    });

    test('una version sin letras es anterior a la primera con letras', () {
      expect(compareVersions('1.0.0', '1.0.0.a'), lessThan(0));
      expect(compareVersions('1.0.0.a', '1.0.0'), greaterThan(0));
    });

    test('las letras se ordenan como columnas de hoja de calculo', () {
      expect(compareVersions('1.0.0.a', '1.0.0.b'), lessThan(0));
      // 'z' es la revision 26 y 'aa' la 27: la longitud manda antes que el
      // alfabeto, o 'aa' quedaria antes de 'b'.
      expect(compareVersions('1.0.0.z', '1.0.0.aa'), lessThan(0));
      expect(compareVersions('1.0.0.aa', '1.0.0.ab'), lessThan(0));
      expect(compareVersions('1.0.0.bs', '1.0.0.bt'), lessThan(0));
    });

    test('el numero pesa mas que el sufijo', () {
      expect(compareVersions('1.0.0.zz', '1.0.1'), lessThan(0));
      expect(compareVersions('1.1.0', '1.0.99.zz'), greaterThan(0));
    });

    test('tolera etiquetas raras sin lanzar', () {
      expect(compareVersions('', ''), 0);
      expect(compareVersions('1', '1.0.0'), 0);
      expect(compareVersions('no-es-version', '1.0.0'), lessThan(0));
    });
  });

  group('SubtitleBox', () {
    test('se recorta para no salirse de la ventana', () {
      const SubtitleBox box = SubtitleBox(
        left: 5000,
        top: 5000,
        width: 900,
        height: 200,
      );
      final SubtitleBox clamped = box.clampTo(const Size(1920, 1080));
      expect(clamped.left + clamped.width, lessThanOrEqualTo(1920));
      expect(clamped.top + clamped.height, lessThanOrEqualTo(1080));
    });
  });
}

// ------------------------------------------------------------------- dobles

class _CountingTranslator implements Translator {
  int calls = 0;

  @override
  String get id => 'counting';

  @override
  String get displayName => 'Contador';

  @override
  bool get isMetered => false;

  @override
  Future<TranslationResult> translate(
    String text, {
    required String targetLanguage,
    String sourceLanguage = 'auto',
    required Duration timeout,
  }) async {
    calls++;
    return TranslationResult(text: '[$text]', fromCache: false);
  }

  @override
  Future<String?> checkAvailability() async => null;

  @override
  void dispose() {}
}

class _FlakyTranslator implements Translator {
  _FlakyTranslator({required this.failuresBeforeSuccess});

  final int failuresBeforeSuccess;
  int calls = 0;

  @override
  String get id => 'flaky';

  @override
  String get displayName => 'Inestable';

  @override
  bool get isMetered => false;

  @override
  Future<TranslationResult> translate(
    String text, {
    required String targetLanguage,
    String sourceLanguage = 'auto',
    required Duration timeout,
  }) async {
    calls++;
    if (calls <= failuresBeforeSuccess) {
      throw StageFailure(Stage.translate, 'Fallo temporal de red');
    }
    return const TranslationResult(text: 'ok', fromCache: false);
  }

  @override
  Future<String?> checkAvailability() async => null;

  @override
  void dispose() {}
}

class _AlwaysFailingTranslator implements Translator {
  _AlwaysFailingTranslator(this.failure);

  final StageFailure failure;
  int calls = 0;

  @override
  String get id => 'failing';

  @override
  String get displayName => 'Siempre falla';

  @override
  bool get isMetered => false;

  @override
  Future<TranslationResult> translate(
    String text, {
    required String targetLanguage,
    String sourceLanguage = 'auto',
    required Duration timeout,
  }) async {
    calls++;
    throw failure;
  }

  @override
  Future<String?> checkAvailability() async => failure.message;

  @override
  void dispose() {}
}
