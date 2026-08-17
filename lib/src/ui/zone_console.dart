import 'package:flutter/material.dart';

import '../models/settings.dart';
import '../pipeline/pipeline.dart';
import '../state/app_controller.dart';
import 'toasts.dart';
import 'widgets_common.dart';

/// Las áreas del panel, cada una con su propia guía.
enum PanelZone { region, languages, style, performance, diagnostics }

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
            headline: 'Sin zona de captura',
            body:
                'Traducy no sabe todavía de qué parte de la pantalla leer. '
                'Pulsa "Banda inferior" para empezar por donde casi todos los '
                'juegos ponen los diálogos.',
            tips: const <String>[
              'Activa "Activar zona de captura" para ver el rectángulo verde.',
              'Se mueve por su barra de título; el interior deja pasar los clics.',
            ],
          );
        }
        if (c.subtitleOverlapsRegion) {
          return _ZoneInfo(
            color: kDanger,
            icon: Icons.warning_amber_rounded,
            headline: 'Los subtítulos se solapan con la zona',
            body:
                'El OCR leería su propia traducción y entraría en bucle. Mueve '
                'la caja de subtítulos fuera del rectángulo verde.',
            tips: const <String>[],
          );
        }
        return _ZoneInfo(
          color: kRegionAccent,
          icon: Icons.check_circle_outline,
          headline: 'Zona lista: ${region.width}×${region.height} px',
          body: s.regionMode == RegionMode.followWindow
              ? 'La zona sigue a la ventana "${s.followWindowTitle}": si mueves '
                    'el juego, la zona lo acompaña.'
              : 'Zona fija en la pantalla. Cuanto más ceñida al texto, mejor '
                    'lee el OCR y menos CPU gasta.',
          tips: <String>[
            if (!s.regionLocked)
              'Cuando la tengas puesta, ciérrala con el candado de su barra.',
            if (s.regionLocked)
              'Está bloqueada: quita el candado si quieres moverla.',
          ],
        );

      case PanelZone.languages:
        if (c.missingOcrLanguages.isNotEmpty) {
          return _ZoneInfo(
            color: kDanger,
            icon: Icons.language,
            headline: 'Falta el idioma "${c.missingOcrLanguages.join(', ')}"',
            body:
                'El OCR necesita un paquete por cada escritura que lee. Púlsalo '
                'en el aviso de arriba y se descarga solo, sin permisos de '
                'administrador.',
            tips: const <String>[],
          );
        }
        return _ZoneInfo(
          color: kAccent,
          icon: Icons.translate,
          headline:
              'Leyendo "${s.engines.ocrLanguages}" → '
              '${s.engines.targetLanguage}',
          body: s.engines.translator == TranslatorKind.claude
              ? 'Claude entiende el contexto del juego: mantiene el tono y no '
                    'destroza los nombres propios. Es de pago por uso.'
              : s.engines.translator == TranslatorKind.googleFree
              ? 'Google Traductor no necesita clave. Si limita las peticiones, '
                    'sube el intervalo en Rendimiento o cambia de motor.'
              : 'Motor: ${s.engines.translator.name}.',
          tips: <String>[
            if (s.engines.sourceLanguage == 'auto')
              'El idioma de origen se detecta solo al traducir.',
            if (s.engines.translator == TranslatorKind.claude &&
                s.engines.glossary.trim().isEmpty)
              'Añade un glosario para fijar nombres propios del juego.',
          ],
        );

      case PanelZone.style:
        return _ZoneInfo(
          color: kSubtitleAccent,
          icon: Icons.text_fields,
          headline: 'Aspecto de los subtítulos',
          body:
              'Los cambios se ven al momento en la caja de texto. Activa '
              '"Editar caja de subtítulos" en Zona si quieres verla mientras '
              'ajustas.',
          tips: const <String>[
            'El contorno es lo que mantiene el texto legible sobre cualquier '
                'escena; súbelo antes que el fondo.',
            'Mostrar el original ayuda a comprobar si el OCR lee bien.',
          ],
        );

      case PanelZone.performance:
        final int skipped = status?.skippedUnchanged ?? 0;
        final int frames = status?.frames ?? 0;
        final int percent = frames > 0 ? (100 * skipped / frames).round() : 0;
        return _ZoneInfo(
          color: kAccent,
          icon: Icons.speed,
          headline: frames > 0
              ? 'Ahorrando el $percent % de las capturas'
              : 'Ajustes de velocidad y precisión',
          body: frames > 0
              ? 'Cuando la imagen no cambia, Traducy se salta el OCR y la '
                    'traducción. Un porcentaje alto es buena señal.'
              : 'Bajar el intervalo responde antes pero consume más CPU y más '
                    'cuota de traducción.',
          tips: const <String>[
            'Si el OCR falla, sube la escala a 2× o 3×: es el ajuste con más '
                'efecto.',
            'Si traduce de más en escenas animadas, sube el umbral de cambio.',
            'Si salen frases a medias, sube la estabilidad a 3 o 4 fotogramas.',
          ],
        );

      case PanelZone.diagnostics:
        final bool ocrReady = c.ocrHealth.isReady;
        final bool translatorReady = c.translatorHealth.isReady;
        if (!ocrReady || !translatorReady) {
          return _ZoneInfo(
            color: kSubtitleAccent,
            icon: Icons.health_and_safety,
            headline: 'Comprobación de motores pendiente',
            body:
                'Pulsa "Comprobar" para ver si el OCR y el traductor responden. '
                '"Probar ahora" hace una captura completa y dice cuánto tardó '
                'cada etapa.',
            tips: const <String>[],
          );
        }
        return _ZoneInfo(
          color: kRegionAccent,
          icon: Icons.verified,
          headline: 'OCR y traductor operativos',
          body:
              'Aquí ves las rutas donde se guarda todo, los contadores del '
              'pipeline y el registro de eventos. Es lo primero que hay que '
              'mirar si algo deja de funcionar.',
          tips: const <String>[
            'El registro guarda los últimos 400 eventos con su hora.',
          ],
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

  /// Alto fijo: unas cinco líneas. Dejarlo crecer libre movería todo el panel
  /// cada vez que entra un mensaje.
  static const double _height = 86;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_LiveFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Lo nuevo va arriba, así que se vuelve al principio al llegar un mensaje;
    // si no, el último quedaría fuera de la vista.
    if (_scroll.hasClients && _scroll.offset > 0) {
      _scroll.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<ToastMessage> history = toasts.history;
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
