import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../core/failures.dart';
import '../core/logx.dart';
import '../i18n/strings.dart';
import '../models/settings.dart';
import '../native/screen_capture.dart';
import '../ocr/image_prep.dart';
import '../ocr/ocr_engine.dart';
import '../translate/translator.dart';

enum PipelineState { stopped, running, paused, failing }

class PipelineStatus {
  const PipelineStatus({
    this.state = PipelineState.stopped,
    this.message = 'Detenido',
    this.hint,
    this.failedStage,
    this.frames = 0,
    this.ocrRuns = 0,
    this.translations = 0,
    this.cacheHits = 0,
    this.skippedUnchanged = 0,
    this.lastCaptureMs = 0,
    this.lastPrepMs = 0,
    this.lastOcrMs = 0,
    this.lastTranslateMs = 0,
    this.detectedLanguage,
  });

  final PipelineState state;
  final String message;
  final String? hint;
  final Stage? failedStage;

  final int frames;
  final int ocrRuns;
  final int translations;
  final int cacheHits;

  /// Fotogramas descartados porque la imagen no había cambiado. Un valor alto
  /// respecto a `frames` es buena señal: significa que el ahorro funciona.
  final int skippedUnchanged;

  final int lastCaptureMs;
  final int lastPrepMs;
  final int lastOcrMs;
  final int lastTranslateMs;
  final String? detectedLanguage;

  bool get isActive => state == PipelineState.running;

  int get lastTotalMs =>
      lastCaptureMs + lastPrepMs + lastOcrMs + lastTranslateMs;

  PipelineStatus copyWith({
    PipelineState? state,
    String? message,
    String? hint,
    bool clearHint = false,
    Stage? failedStage,
    bool clearStage = false,
    int? frames,
    int? ocrRuns,
    int? translations,
    int? cacheHits,
    int? skippedUnchanged,
    int? lastCaptureMs,
    int? lastPrepMs,
    int? lastOcrMs,
    int? lastTranslateMs,
    String? detectedLanguage,
  }) => PipelineStatus(
    state: state ?? this.state,
    message: message ?? this.message,
    hint: clearHint ? null : (hint ?? this.hint),
    failedStage: clearStage ? null : (failedStage ?? this.failedStage),
    frames: frames ?? this.frames,
    ocrRuns: ocrRuns ?? this.ocrRuns,
    translations: translations ?? this.translations,
    cacheHits: cacheHits ?? this.cacheHits,
    skippedUnchanged: skippedUnchanged ?? this.skippedUnchanged,
    lastCaptureMs: lastCaptureMs ?? this.lastCaptureMs,
    lastPrepMs: lastPrepMs ?? this.lastPrepMs,
    lastOcrMs: lastOcrMs ?? this.lastOcrMs,
    lastTranslateMs: lastTranslateMs ?? this.lastTranslateMs,
    detectedLanguage: detectedLanguage ?? this.detectedLanguage,
  );
}

class SubtitleContent {
  SubtitleContent({
    required this.translated,
    required this.original,
    this.fromCache = false,
  }) : shownAt = DateTime.now();

  final String translated;
  final String original;
  final bool fromCache;
  final DateTime shownAt;
}

/// Orquestador: captura → preprocesado → OCR → traducción → subtítulo.
///
/// Reglas de diseño que sostienen todo lo demás:
///  - Un único ciclo activo a la vez (contrapresión). Si un fotograma tarda más
///    que el intervalo, los siguientes se descartan en lugar de acumularse en
///    una cola que crecería sin control.
///  - Ninguna excepción escapa del ciclo. Cada etapa se captura y se traduce a
///    un estado visible para el usuario.
///  - Tras demasiados fallos seguidos se autopausa, en lugar de seguir
///    golpeando un motor roto o gastando cuota de API.
class TranslationPipeline {
  TranslationPipeline({
    required AppSettings settings,
    required OcrEngine ocrEngine,
    required ResilientTranslator translator,
    required this.resolveRegion,
    // Los tres campos son privados y mutables (se reemplazan en caliente), y
    // Dart no admite parámetros con nombre privados, así que la asignación
    // explícita es la única opción aquí.
    // ignore: prefer_initializing_formals
  }) : _settings = settings,
       // ignore: prefer_initializing_formals
       _ocrEngine = ocrEngine,
       // ignore: prefer_initializing_formals
       _translator = translator;

  AppSettings _settings;
  OcrEngine _ocrEngine;
  ResilientTranslator _translator;

  /// Resuelve la región a capturar en cada ciclo. Es una función y no un valor
  /// fijo porque en modo "seguir ventana" el rectángulo cambia si el usuario
  /// mueve el juego.
  final CaptureRegion Function() resolveRegion;

  final ScreenCapture _capture = ScreenCapture();

  final ValueNotifier<PipelineStatus> status = ValueNotifier<PipelineStatus>(
    const PipelineStatus(),
  );
  final ValueNotifier<SubtitleContent?> subtitle =
      ValueNotifier<SubtitleContent?>(null);

  /// Las últimas líneas traducidas, de la más antigua a la más reciente.
  ///
  /// Es una lista aparte y no una simple pila de `subtitle` porque el subtítulo
  /// actual se retira cuando el texto deja de verse en pantalla, y el historial
  /// tiene que sobrevivir a eso: lo que ya se dijo sigue siendo lo que se dijo.
  final ValueNotifier<List<SubtitleContent>> history =
      ValueNotifier<List<SubtitleContent>>(const <SubtitleContent>[]);

  Timer? _timer;
  bool _busy = false;
  bool _disposed = false;

  Uint8List? _lastSignature;
  String? _lastTranslatedKey;
  String? _pendingKey;

  /// Texto del OCR que está esperando confirmación de estabilidad.
  ///
  /// Se guarda entero, no solo su clave, porque un fotograma idéntico confirma
  /// la estabilidad sin necesidad de repetir el OCR: se traduce este texto.
  String? _pendingText;
  int _pendingCount = 0;
  int _consecutiveErrors = 0;
  DateTime? _lastTextSeenAt;

  /// Cuándo se avisó por última vez de una captura en negro o de una zona plana.
  ///
  /// Son fallos persistentes: mientras el juego siga en pantalla completa
  /// exclusiva, van a repetirse en cada fotograma. Se avisa cada
  /// [_diagnosisInterval] para que el mensaje siga a la vista sin inundar el
  /// registro con tres líneas por segundo.
  DateTime? _blackFrameWarnedAt;
  DateTime? _flatFrameWarnedAt;
  static const Duration _diagnosisInterval = Duration(seconds: 12);

  bool get isRunning => status.value.state == PipelineState.running;

  // ------------------------------------------------------------ ciclo de vida

  void start() {
    if (_disposed) return;
    _consecutiveErrors = 0;
    _blackFrameWarnedAt = null;
    _flatFrameWarnedAt = null;
    _restartTimer();
    _setStatus(
      state: PipelineState.running,
      message: t.panel.pipelineRunning,
      clearHint: true,
      clearStage: true,
    );
    log.i(
      'pipeline',
      'Iniciado (intervalo ${_settings.pipeline.intervalMs} ms)',
    );
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _lastSignature = null;
    _lastTranslatedKey = null;
    _pendingKey = null;
    _pendingText = null;
    _pendingCount = 0;
    _setStatus(state: PipelineState.stopped, message: t.panel.pipelineStopped);
    log.i('pipeline', 'Detenido');
  }

  void pause() {
    if (!isRunning) return;
    _timer?.cancel();
    _timer = null;
    _setStatus(state: PipelineState.paused, message: t.panel.pipelinePaused);
  }

  void resume() {
    if (_disposed) return;
    if (status.value.state == PipelineState.running) return;
    _consecutiveErrors = 0;
    _restartTimer();
    _setStatus(
      state: PipelineState.running,
      message: t.panel.pipelineRunning,
      clearHint: true,
      clearStage: true,
    );
  }

  void toggle() => isRunning ? pause() : resume();

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(milliseconds: _settings.pipeline.intervalMs),
      (_) => _tick(),
    );
  }

  /// Reconfigura en caliente. El temporizador solo se recrea si cambió el
  /// intervalo, para no perder el ritmo con cada ajuste de la interfaz.
  void updateSettings(AppSettings settings) {
    final int previousInterval = _settings.pipeline.intervalMs;
    final PreprocessSettings previousPrep = _settings.preprocess;
    _settings = settings;

    if (previousInterval != settings.pipeline.intervalMs && isRunning) {
      _restartTimer();
    }
    // Si cambió el preprocesado, la huella anterior ya no es comparable.
    if (previousPrep.scale != settings.preprocess.scale ||
        previousPrep.threshold != settings.preprocess.threshold ||
        previousPrep.invert != settings.preprocess.invert ||
        previousPrep.grayscale != settings.preprocess.grayscale) {
      _lastSignature = null;
    }
  }

  /// Sustituye los motores (al cambiar de traductor o de idioma de OCR) y
  /// olvida las claves de deduplicación: el mismo texto debe reprocesarse
  /// porque el resultado esperado es distinto.
  void updateEngines({OcrEngine? ocrEngine, ResilientTranslator? translator}) {
    if (ocrEngine != null && ocrEngine != _ocrEngine) {
      _ocrEngine.dispose();
      _ocrEngine = ocrEngine;
      _lastSignature = null;
    }
    if (translator != null && translator != _translator) {
      _translator.dispose();
      _translator = translator;
    }
    _lastTranslatedKey = null;
    _pendingKey = null;
    _pendingText = null;
    _pendingCount = 0;
    _consecutiveErrors = 0;
  }

  /// Fuerza un ciclo completo ignorando la detección de cambios. Lo usa el botón
  /// "Probar ahora" de la interfaz.
  Future<void> runOnce() async {
    _lastSignature = null;
    _lastTranslatedKey = null;
    await _tick(force: true);
  }

  void clearSubtitle() {
    subtitle.value = null;
    _lastTranslatedKey = null;
    _lastTextSeenAt = null;
  }

  // ------------------------------------------------------------------- ciclo

  Future<void> _tick({bool force = false}) async {
    if (_disposed) return;
    if (_busy) {
      // Contrapresión: el ciclo anterior sigue en marcha. Descartar es correcto
      // aquí; encolar acabaría mostrando subtítulos con segundos de retraso.
      _setStatus(skippedUnchanged: status.value.skippedUnchanged);
      return;
    }
    _busy = true;
    try {
      await _runCycle(force: force);
      _consecutiveErrors = 0;
    } on StageFailure catch (failure) {
      _handleFailure(failure);
    } catch (e, st) {
      log.e('pipeline', 'Error inesperado en el ciclo', e, st);
      _handleFailure(
        StageFailure(Stage.render, t.panel.pipelineUnexpected('$e'), cause: e),
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> _runCycle({required bool force}) async {
    final CaptureRegion region = resolveRegion();
    if (!region.isValid) {
      _setStatus(
        message: t.panel.pipelineDefineZone,
        hint: t.panel.pipelineDefineZoneHint,
      );
      return;
    }

    // ---- 1. Captura
    final Stopwatch watch = Stopwatch()..start();
    final CapturedFrame? frame = _capture.capture(
      x: region.left,
      y: region.top,
      width: region.width,
      height: region.height,
    );
    final int captureMs = watch.elapsedMilliseconds;
    if (frame == null) {
      throw StageFailure(
        Stage.capture,
        t.panel.pipelineCaptureFailed,
        hint: t.panel.pipelineCaptureFailedHint,
      );
    }

    // El aviso se repite, pero espaciado. Antes se daba una sola vez, y con una
    // captura permanentemente en negro el resultado era desconcertante: el
    // primer aviso pasaba desapercibido y a partir de ahí la aplicación decía
    // "sin cambios" para siempre, que es cierto y no explica nada.
    final StageFailure? black = diagnoseBlackFrame(frame);
    if (black != null) {
      final DateTime now = DateTime.now();
      final DateTime? last = _blackFrameWarnedAt;
      if (last == null || now.difference(last) > _diagnosisInterval) {
        _blackFrameWarnedAt = now;
        throw black;
      }
      _setStatus(
        state: PipelineState.failing,
        message: t.panel.pipelineBlackFrame,
        hint: t.panel.pipelineBlackFrameHint,
        frames: status.value.frames + 1,
        lastCaptureMs: captureMs,
      );
      return;
    }

    // ---- 2. Preprocesado en otro isolate
    watch.reset();
    final PreprocessSettings prep = _settings.preprocess;
    final PrepRequest request = PrepRequest(
      bgra: frame.bgra,
      width: frame.width,
      height: frame.height,
      scale: prep.scale,
      grayscale: prep.grayscale,
      contrast: prep.contrast,
      threshold: prep.threshold,
      invert: prep.invert,
      denoise: prep.denoise,
    );

    late final PrepResult prepared;
    try {
      // Fuera del isolate de interfaz: escalar y binarizar una imagen es
      // trabajo de CPU suficiente para provocar tirones en la animación del
      // subtítulo si se hiciera aquí.
      prepared = await Isolate.run(() => preprocessFrame(request));
    } catch (e) {
      throw StageFailure(
        Stage.preprocess,
        t.panel.pipelinePrepFailed,
        hint: t.panel.pipelinePrepFailedHint,
        cause: e,
      );
    }
    final int prepMs = watch.elapsedMilliseconds;

    // ---- 3. ¿Ha cambiado algo?
    //
    // Una zona plana no es que no haya cambiado: es que no se está viendo nada.
    // Merece su propio mensaje, porque la solución no tiene nada que ver.
    if (isSignatureFlat(prepared.signature)) {
      final DateTime now = DateTime.now();
      final DateTime? last = _flatFrameWarnedAt;
      if (last == null || now.difference(last) > _diagnosisInterval) {
        _flatFrameWarnedAt = now;
        log.w('pipeline', 'La zona de captura no ve nada aprovechable');
      }
      _expireSubtitleIfStale();
      _setStatus(
        state: PipelineState.running,
        message: t.panel.pipelineFlatFrame,
        hint: t.panel.pipelineFlatFrameHint,
        frames: status.value.frames + 1,
        skippedUnchanged: status.value.skippedUnchanged + 1,
        lastCaptureMs: captureMs,
        lastPrepMs: prepMs,
        clearStage: true,
      );
      return;
    }

    final Uint8List? previous = _lastSignature;
    if (!force && previous != null) {
      final double changed = signatureChangePercent(
        prepared.signature,
        previous,
      );
      if (changed < _settings.pipeline.minChangePercent) {
        // Un fotograma idéntico con texto pendiente **confirma** que ese texto
        // ya está quieto: es exactamente lo que la estabilización estaba
        // esperando. Sin esto quedaba un bloqueo mutuo que impedía traducir
        // nada: el primer fotograma dejaba el texto pendiente, y todos los
        // siguientes lo saltaban por "sin cambios", así que el contador de
        // estabilidad nunca llegaba a su objetivo. Ahorra además un OCR, porque
        // sobre la misma imagen daría el mismo resultado.
        final String? pending = _pendingText;
        if (pending != null && _pendingKey != null) {
          _pendingCount++;
          if (_pendingCount >= _settings.pipeline.stabilityFrames) {
            await _translateAndShow(
              text: pending,
              key: _pendingKey!,
              captureMs: captureMs,
              prepMs: prepMs,
              ocrMs: 0,
              countOcrRun: false,
            );
            return;
          }
          _setStatus(
            state: PipelineState.running,
            message: t.panel.pipelineWaitingStable,
            frames: status.value.frames + 1,
            lastCaptureMs: captureMs,
            lastPrepMs: prepMs,
            clearHint: true,
            clearStage: true,
          );
          _hurryNextCycle();
          return;
        }

        _expireSubtitleIfStale();
        _setStatus(
          state: PipelineState.running,
          // Con el número delante se puede ajustar el umbral con criterio en
          // lugar de a ciegas.
          message: t.panel.pipelineUnchanged(changed.toStringAsFixed(1)),
          frames: status.value.frames + 1,
          skippedUnchanged: status.value.skippedUnchanged + 1,
          lastCaptureMs: captureMs,
          lastPrepMs: prepMs,
          clearHint: true,
          clearStage: true,
        );
        return;
      }
    }
    _lastSignature = prepared.signature;

    // ---- 4. OCR
    watch.reset();
    final OcrResult ocr = await _ocrEngine.recognize(
      prepared.png,
      timeout: Duration(milliseconds: _settings.pipeline.ocrTimeoutMs),
    );
    final int ocrMs = watch.elapsedMilliseconds;

    final String text = ocr.text;
    if (text.length < _settings.pipeline.minTextLength) {
      _expireSubtitleIfStale();
      _pendingKey = null;
      _pendingText = null;
      _pendingCount = 0;
      _setStatus(
        state: PipelineState.running,
        message: t.panel.pipelineNoText,
        frames: status.value.frames + 1,
        ocrRuns: status.value.ocrRuns + 1,
        lastCaptureMs: captureMs,
        lastPrepMs: prepMs,
        lastOcrMs: ocrMs,
        clearHint: true,
        clearStage: true,
      );
      return;
    }

    _lastTextSeenAt = DateTime.now();
    final String key = ocrComparisonKey(text);

    // Ya traducido y en pantalla: no hay nada que hacer.
    if (!force && key == _lastTranslatedKey) {
      _setStatus(
        state: PipelineState.running,
        message: t.panel.pipelineAlreadyTranslated,
        frames: status.value.frames + 1,
        ocrRuns: status.value.ocrRuns + 1,
        lastCaptureMs: captureMs,
        lastPrepMs: prepMs,
        lastOcrMs: ocrMs,
        clearHint: true,
        clearStage: true,
      );
      return;
    }

    // ---- 5. Estabilización
    // Muchos juegos escriben el diálogo letra a letra. Traducir cada estado
    // intermedio gastaría cuota y mostraría frases a medias, así que se espera
    // a que el OCR devuelva el mismo texto varias veces seguidas.
    if (!force && _settings.pipeline.stabilityFrames > 1) {
      if (key != _pendingKey) {
        _pendingKey = key;
        _pendingText = text;
        _pendingCount = 1;
      } else {
        _pendingText = text;
        _pendingCount++;
      }
      if (_pendingCount < _settings.pipeline.stabilityFrames) {
        // Confirmar cuanto antes: mientras se espera, el subtitulo todavia no
        // esta en pantalla y esa espera es la que se nota.
        _hurryNextCycle();
        _setStatus(
          state: PipelineState.running,
          message: t.panel.pipelineWaitingStable,
          frames: status.value.frames + 1,
          ocrRuns: status.value.ocrRuns + 1,
          lastCaptureMs: captureMs,
          lastPrepMs: prepMs,
          lastOcrMs: ocrMs,
          clearHint: true,
          clearStage: true,
        );
        return;
      }
    }
    // ---- 6. Traducción
    await _translateAndShow(
      text: text,
      key: key,
      captureMs: captureMs,
      prepMs: prepMs,
      ocrMs: ocrMs,
    );
  }

  /// Traduce, pinta el subtítulo y actualiza el estado.
  ///
  /// Es un método aparte porque hay dos caminos que llegan aquí: el normal, tras
  /// leer texto nuevo, y el de un fotograma repetido que confirma la estabilidad
  /// del texto ya leído. [countOcrRun] distingue el segundo, donde no se ha
  /// ejecutado ningún OCR y sumarlo falsearía las estadísticas.
  Future<void> _translateAndShow({
    required String text,
    required String key,
    required int captureMs,
    required int prepMs,
    required int ocrMs,
    bool countOcrRun = true,
  }) async {
    _pendingKey = null;
    _pendingText = null;
    _pendingCount = 0;

    final Stopwatch watch = Stopwatch()..start();
    final TranslationResult translation = await _translator.translate(
      text,
      targetLanguage: _settings.engines.targetLanguage,
      sourceLanguage: _settings.engines.sourceLanguage,
      timeout: Duration(milliseconds: _settings.pipeline.translateTimeoutMs),
    );
    final int translateMs = watch.elapsedMilliseconds;

    _lastTranslatedKey = key;
    _lastTextSeenAt = DateTime.now();
    final SubtitleContent content = SubtitleContent(
      translated: translation.text.isEmpty ? text : translation.text,
      original: text,
      fromCache: translation.fromCache,
    );
    subtitle.value = content;
    _remember(content);

    _setStatus(
      state: PipelineState.running,
      message: translation.fromCache
          ? t.panel.pipelineTranslatedCached
          : t.panel.pipelineTranslated,
      frames: status.value.frames + 1,
      ocrRuns: status.value.ocrRuns + (countOcrRun ? 1 : 0),
      translations: status.value.translations + 1,
      cacheHits: status.value.cacheHits + (translation.fromCache ? 1 : 0),
      lastCaptureMs: captureMs,
      lastPrepMs: prepMs,
      lastOcrMs: ocrMs,
      lastTranslateMs: translateMs,
      detectedLanguage: translation.detectedLanguage,
      clearHint: true,
      clearStage: true,
    );
  }

  /// Guarda la línea en el historial, recortándolo por el final.
  ///
  /// Se crea una lista nueva en lugar de modificar la existente: `ValueNotifier`
  /// compara por identidad, y mutar la lista en su sitio no avisaría a nadie.
  void _remember(SubtitleContent content) {
    final int limit = _settings.style.historyLength;
    final List<SubtitleContent> updated = <SubtitleContent>[
      ...history.value,
      content,
    ];
    history.value = updated.length > limit
        ? updated.sublist(updated.length - limit)
        : updated;
  }

  /// Vacía el historial. Lo usa el botón de la interfaz y el arranque.
  void clearHistory() {
    if (history.value.isEmpty) return;
    history.value = const <SubtitleContent>[];
  }

  /// Adelanta el siguiente ciclo cuando hay un texto esperando confirmacion.
  ///
  /// La espera de estabilidad existe para no traducir dialogos a medio escribir,
  /// pero cumplirla al ritmo normal de captura anade un intervalo completo al
  /// tiempo que tarda en aparecer el subtitulo. Confirmando antes se conserva la
  /// proteccion contra el efecto maquina de escribir y se recorta la espera a la
  /// mitad, sin gastar CPU en los fotogramas en los que no hay nada pendiente.
  void _hurryNextCycle() {
    if (_disposed || _timer == null) return;
    const int hurryMs = 110;
    if (_settings.pipeline.intervalMs <= hurryMs) return;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: hurryMs), () {
      // Se vuelve al ritmo normal en cuanto se ha atendido el ciclo urgente.
      _restartTimer();
      unawaited(_tick());
    });
  }

  /// Retira el subtítulo cuando lleva demasiado tiempo sin volver a detectarse
  /// el texto, para que no se quede congelado sobre una escena distinta.
  void _expireSubtitleIfStale() {
    final int holdMs = _settings.pipeline.holdMs;
    if (holdMs <= 0) {
      if (subtitle.value != null) {
        subtitle.value = null;
        _lastTranslatedKey = null;
      }
      return;
    }
    final DateTime? seenAt = _lastTextSeenAt;
    if (seenAt == null) return;
    if (DateTime.now().difference(seenAt).inMilliseconds > holdMs) {
      if (subtitle.value != null) {
        subtitle.value = null;
        _lastTranslatedKey = null;
      }
      _lastTextSeenAt = null;
    }
  }

  void _handleFailure(StageFailure failure) {
    _consecutiveErrors++;
    log.w(
      'pipeline',
      '[${failure.stage.name}] ${failure.message}'
          '${failure.cause == null ? '' : ' | ${failure.cause}'}',
    );

    final bool shouldPause =
        _consecutiveErrors >= _settings.pipeline.maxConsecutiveErrors;
    if (shouldPause) {
      _timer?.cancel();
      _timer = null;
      _setStatus(
        state: PipelineState.paused,
        message: t.panel.pipelineAutoPaused(
          _consecutiveErrors,
          failure.message,
        ),
        hint: failure.hint ?? t.panel.pipelineAutoPausedHint,
        failedStage: failure.stage,
      );
      log.e(
        'pipeline',
        'Autopausa tras $_consecutiveErrors errores consecutivos',
      );
      return;
    }

    _setStatus(
      state: PipelineState.failing,
      message: failure.message,
      hint: failure.hint,
      failedStage: failure.stage,
      frames: status.value.frames + 1,
    );
  }

  void _setStatus({
    PipelineState? state,
    String? message,
    String? hint,
    bool clearHint = false,
    Stage? failedStage,
    bool clearStage = false,
    int? frames,
    int? ocrRuns,
    int? translations,
    int? cacheHits,
    int? skippedUnchanged,
    int? lastCaptureMs,
    int? lastPrepMs,
    int? lastOcrMs,
    int? lastTranslateMs,
    String? detectedLanguage,
  }) {
    if (_disposed) return;
    status.value = status.value.copyWith(
      state: state,
      message: message,
      hint: hint,
      clearHint: clearHint,
      failedStage: failedStage,
      clearStage: clearStage,
      frames: frames,
      ocrRuns: ocrRuns,
      translations: translations,
      cacheHits: cacheHits,
      skippedUnchanged: skippedUnchanged,
      lastCaptureMs: lastCaptureMs,
      lastPrepMs: lastPrepMs,
      lastOcrMs: lastOcrMs,
      lastTranslateMs: lastTranslateMs,
      detectedLanguage: detectedLanguage,
    );
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _capture.dispose();
    _ocrEngine.dispose();
    _translator.dispose();
    status.dispose();
    subtitle.dispose();
    history.dispose();
  }
}
