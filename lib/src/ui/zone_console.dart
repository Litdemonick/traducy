import 'package:flutter/material.dart';

import '../core/about.dart';
import '../i18n/strings.dart';
import '../models/settings.dart';
import '../pipeline/pipeline.dart';
import '../state/app_controller.dart';
import 'toasts.dart';
import 'widgets_common.dart';

/// Las áreas del panel, cada una con su propia guía.
enum PanelZone { region, languages, style, performance, diagnostics, about }

/// Consola de ayuda contextual.
///
/// Se actualiza según la pestaña abierta y el estado real de la aplicación: dice
/// qué se puede hacer aquí, qué falla ahora mismo y cuál es el siguiente paso.
///
/// Existe porque el panel tiene muchos ajustes y ninguno explica por sí solo
/// para qué sirve. Un texto fijo se quedaría corto; esto mira el estado (si hay
/// zona, si el OCR está listo, si está traduciendo) y responde a eso.
class ZoneConsole extends StatelessWidget {
  const ZoneConsole({super.key, required this.controller, required this.zone});

  final AppController controller;
  final PanelZone zone;

  @override
  Widget build(BuildContext context) {
    final TranslationPipeline? pipeline = controller.pipeline;

    // Dos fuentes que cambian solas: el estado del pipeline y el historial de
    // mensajes. Se escuchan aquí para reconstruir solo esta consola y no el
    // panel entero, que es mucho más caro de repintar.
    return ListenableBuilder(
      listenable: toasts,
      builder: (BuildContext context, _) {
        if (pipeline == null) return _build(context, null);
        return ValueListenableBuilder<PipelineStatus>(
          valueListenable: pipeline.status,
          builder: (BuildContext context, PipelineStatus status, _) =>
              _build(context, status),
        );
      },
    );
  }

  Widget _build(BuildContext context, PipelineStatus? status) {
    final _ZoneInfo info = _infoFor(zone, controller, status);

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF101014),
        border: Border(left: BorderSide(color: info.color, width: 3)),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(info.icon, size: 14, color: info.color),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  info.headline,
                  style: TextStyle(
                    color: info.color,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            info.body,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          _LiveFeed(status: status),
          if (info.tips.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            for (final String tip in info.tips)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      '·  ',
                      style: TextStyle(color: kMuted, fontSize: 11),
                    ),
                    Expanded(
                      child: Text(
                        tip,
                        style: const TextStyle(
                          color: kMuted,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  _ZoneInfo _infoFor(PanelZone zone, AppController c, PipelineStatus? status) {
    final AppSettings s = c.settings;

    switch (zone) {
      case PanelZone.region:
        final CaptureRegion region = c.resolveCaptureRegion();
        if (!region.isValid) {
          return _ZoneInfo(
            color: kDanger,
            icon: Icons.crop_free,
            headline: t.panel.consoleNoZoneHeadline,
            body: t.panel.consoleNoZoneBody,
            tips: <String>[
              t.panel.consoleNoZoneTip1,
              t.panel.consoleNoZoneTip2,
            ],
          );
        }
        if (c.subtitleOverlapsRegion) {
          return _ZoneInfo(
            color: kDanger,
            icon: Icons.warning_amber_rounded,
            headline: t.panel.consoleOverlapHeadline,
            body: t.panel.consoleOverlapBody,
            tips: const <String>[],
          );
        }
        return _ZoneInfo(
          color: kRegionAccent,
          icon: Icons.check_circle_outline,
          headline: t.panel.consoleZoneReadyHeadline(
            region.width,
            region.height,
          ),
          body: s.regionMode == RegionMode.followWindow
              ? t.panel.consoleZoneFollowBody(s.followWindowTitle)
              : t.panel.consoleZoneFixedBody,
          tips: <String>[
            if (!s.regionLocked) t.panel.consoleZoneTipLock,
            if (s.regionLocked) t.panel.consoleZoneTipLocked,
          ],
        );

      case PanelZone.languages:
        if (c.missingOcrLanguages.isNotEmpty) {
          return _ZoneInfo(
            color: kDanger,
            icon: Icons.language,
            headline: t.panel.consoleMissingLanguageHeadline(
              c.missingOcrLanguages.join(', '),
            ),
            body: t.panel.consoleMissingLanguageBody,
            tips: const <String>[],
          );
        }
        return _ZoneInfo(
          color: kAccent,
          icon: Icons.translate,
          headline: t.panel.consoleLanguagesReadyHeadline(
            s.engines.ocrLanguages,
            s.engines.targetLanguage,
          ),
          body: s.engines.sourceLanguage == 'auto'
              ? t.panel.consoleLanguagesAutoBody
              : t.panel.consoleLanguagesFixedBody(s.engines.sourceLanguage),
          tips: <String>[t.panel.consoleLanguagesTipEngine],
        );

      case PanelZone.style:
        return _ZoneInfo(
          color: kSubtitleAccent,
          icon: Icons.text_fields,
          headline: t.panel.consoleStyleHeadline,
          body: t.panel.consoleStyleBody,
          tips: <String>[t.panel.consoleStyleTip1, t.panel.consoleStyleTip2],
        );

      case PanelZone.performance:
        final int skipped = status?.skippedUnchanged ?? 0;
        final int frames = status?.frames ?? 0;
        return _ZoneInfo(
          color: kAccent,
          icon: Icons.speed,
          headline: t.panel.consolePerformanceHeadline,
          body: frames > 0
              ? t.panel.consolePerformanceBody(frames, skipped)
              : t.panel.consolePerformanceIdleBody,
          tips: <String>[
            t.panel.consolePerformanceTip1,
            t.panel.consolePerformanceTip2,
          ],
        );

      case PanelZone.diagnostics:
        final bool ocrReady = c.ocrHealth.isReady;
        final bool translatorReady = c.translatorHealth.isReady;
        if (!ocrReady || !translatorReady) {
          return _ZoneInfo(
            color: kSubtitleAccent,
            icon: Icons.health_and_safety,
            headline: t.panel.consoleEnginesPendingHeadline,
            body: t.panel.consoleEnginesPendingBody,
            tips: const <String>[],
          );
        }
        return _ZoneInfo(
          color: kRegionAccent,
          icon: Icons.verified,
          headline: t.panel.consoleEnginesReadyHeadline,
          body: t.panel.consoleEnginesReadyBody,
          tips: <String>[t.panel.consoleEnginesTip],
        );

      case PanelZone.about:
        return _ZoneInfo(
          color: kAccent,
          icon: Icons.info_outline,
          headline: t.panel.consoleAboutHeadline(
            c.currentVersion,
            About.author,
          ),
          body: t.panel.consoleAboutBody,
          tips: <String>[t.panel.consoleAboutTip1, t.panel.consoleAboutTip2],
        );
    }
  }
}

/// Registro en vivo dentro de la consola.
///
/// Muestra los mensajes recientes y, si el pipeline está en marcha, la etapa en
/// la que va. Es la parte que "se va actualizando": sin ella la consola solo
/// explicaría qué se puede hacer, no qué está pasando.
///
/// Lleva su propia barra de desplazamiento **siempre visible**, porque el
/// historial crece y desde el panel no hay otra forma de saber que hay más
/// líneas por encima.
class _LiveFeed extends StatefulWidget {
  const _LiveFeed({required this.status});

  final PipelineStatus? status;

  @override
  State<_LiveFeed> createState() => _LiveFeedState();
}

class _LiveFeedState extends State<_LiveFeed> {
  final ScrollController _scroll = ScrollController();

  /// Alto fijo. Dejarlo crecer libre movería todo el panel cada vez que entra un
  /// mensaje.
  static const double _height = 130;

  /// Identificador del mensaje que estaba arriba en el último repintado.
  ///
  /// Sirve para distinguir "ha llegado un mensaje nuevo" de "el widget se ha
  /// repintado". Se repinta muchas veces por segundo, porque el estado del
  /// pipeline cambia con cada ciclo, y sin esta distinción cualquier repintado
  /// devolvía la lista al principio: el usuario bajaba a leer y algo lo subía de
  /// vuelta a los milisegundos.
  int? _topMessageId;

  /// Margen para considerar que el usuario está mirando el principio de la
  /// lista. Un par de píxeles de inercia no cuentan como haber bajado.
  static const double _atTopSlack = 24;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_LiveFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    _followNewMessages();
  }

  /// Lo nuevo va arriba, así que el seguimiento consiste en volver al principio;
  /// pero solo si hay un mensaje nuevo **y** el usuario ya estaba mirando ahí.
  /// Si ha bajado a leer algo, se le deja en paz: es su desplazamiento, no el
  /// nuestro.
  void _followNewMessages() {
    final List<ToastMessage> history = toasts.history;
    final int? newest = history.isEmpty ? null : history.first.id;
    if (newest == _topMessageId) return;

    final bool isFirstBuild = _topMessageId == null;
    _topMessageId = newest;
    if (!_scroll.hasClients) return;
    if (isFirstBuild || _scroll.offset <= _atTopSlack) {
      // Después del repintado: durante `didUpdateWidget` la lista todavía tiene
      // el número de elementos anterior.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<ToastMessage> history = toasts.history;
    _topMessageId ??= history.isEmpty ? null : history.first.id;
    final PipelineStatus? s = widget.status;
    final bool showPipeline = s != null && s.state != PipelineState.stopped;

    if (history.isEmpty && !showPipeline) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.only(top: 7),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF2A2A33))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (showPipeline) _PipelineLine(status: s),
          if (history.isNotEmpty)
            SizedBox(
              height: _height,
              child: Scrollbar(
                controller: _scroll,
                thumbVisibility: true,
                trackVisibility: true,
                thickness: 6,
                radius: const Radius.circular(3),
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.only(right: 10),
                  itemCount: history.length,
                  itemBuilder: (BuildContext context, int index) =>
                      _FeedLine(message: history[index]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Estado del pipeline, fijo arriba del registro para que no se pierda al
/// desplazar los mensajes.
class _PipelineLine extends StatelessWidget {
  const _PipelineLine({required this.status});

  final PipelineStatus status;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (status.state) {
      PipelineState.running => kRegionAccent,
      PipelineState.failing => kDanger,
      PipelineState.paused => kSubtitleAccent,
      PipelineState.stopped => kMuted,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              status.message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontFamily: 'Consolas',
              ),
            ),
          ),
          if (status.lastTotalMs > 0)
            Text(
              '${status.lastTotalMs} ms',
              style: const TextStyle(
                color: kMuted,
                fontSize: 10,
                fontFamily: 'Consolas',
              ),
            ),
        ],
      ),
    );
  }
}

class _FeedLine extends StatelessWidget {
  const _FeedLine({required this.message});

  final ToastMessage message;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (message.kind) {
      ToastKind.error => kDanger,
      ToastKind.warning => kSubtitleAccent,
      ToastKind.success => kRegionAccent,
      ToastKind.info => Colors.white70,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            message.hhmmss,
            style: const TextStyle(
              color: Color(0xFF6D6D78),
              fontSize: 10,
              fontFamily: 'Consolas',
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  message.text,
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontFamily: 'Consolas',
                    height: 1.3,
                  ),
                ),
                if (message.detail != null)
                  Text(
                    message.detail!,
                    style: const TextStyle(
                      color: Color(0xFF7A7A86),
                      fontSize: 10,
                      fontFamily: 'Consolas',
                      height: 1.3,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoneInfo {
  const _ZoneInfo({
    required this.color,
    required this.icon,
    required this.headline,
    required this.body,
    required this.tips,
  });

  final Color color;
  final IconData icon;
  final String headline;
  final String body;
  final List<String> tips;
}
