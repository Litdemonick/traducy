import 'package:flutter/material.dart';

import '../i18n/strings.dart';
import '../models/settings.dart';
import '../pipeline/pipeline.dart';
import '../state/app_controller.dart';
import 'control_panel.dart';
import 'draggable_box.dart';
import 'subtitle_view.dart';
import 'update_section.dart';
import 'widgets_common.dart';

/// Lienzo del overlay: cubre todo el escritorio y dibuja encima del juego.
///
/// La regla que ordena todo este fichero: **la ventana solo intercepta el ratón
/// donde hay algo con lo que interactuar**. Eso son el panel, las barras de
/// título de las cajas y sus tiradores de borde. El resto de la pantalla —
/// incluido el interior de la zona marcada y de los subtítulos — deja pasar los
/// clics al programa de debajo.
class OverlayRoot extends StatefulWidget {
  const OverlayRoot({
    super.key,
    required this.controller,
    required this.onExit,
  });

  final AppController controller;
  final VoidCallback onExit;

  @override
  State<OverlayRoot> createState() => _OverlayRootState();
}

class _OverlayRootState extends State<OverlayRoot> {
  final GlobalKey _panelKey = GlobalKey();

  /// Deben coincidir con las constantes de `DraggableBox`: son las medidas de la
  /// barra de título y de la banda sensible del borde.
  static const double _titleStripHeight = 34;
  static const double _minFrameWidth = 260;
  static const double _edgeBand = 26;

  AppController get controller => widget.controller;

  /// Zonas sensibles de una caja: su barra de título y una banda estrecha
  /// alrededor del borde para los tiradores. El interior queda deliberadamente
  /// fuera, y es lo que permite pinchar lo que hay detrás del rectángulo.
  List<Rect> _boxHitAreas(Rect r, {required bool locked}) {
    final double frameWidth = r.width < _minFrameWidth
        ? _minFrameWidth
        : r.width;
    final bool titleAbove = r.top >= _titleStripHeight;
    final Rect titleBar = Rect.fromLTWH(
      r.left,
      titleAbove ? r.top - _titleStripHeight : r.bottom + 4,
      frameWidth,
      _titleStripHeight,
    );

    // Bloqueada: no hay tiradores, así que solo la barra (para el candado).
    if (locked) return <Rect>[titleBar];

    final double half = _edgeBand / 2;
    return <Rect>[
      titleBar,
      Rect.fromLTRB(r.left - half, r.top - half, r.right + half, r.top + half),
      Rect.fromLTRB(
        r.left - half,
        r.bottom - half,
        r.right + half,
        r.bottom + half,
      ),
      Rect.fromLTRB(
        r.left - half,
        r.top - half,
        r.left + half,
        r.bottom + half,
      ),
      Rect.fromLTRB(
        r.right - half,
        r.top - half,
        r.right + half,
        r.bottom + half,
      ),
    ];
  }

  /// Publica las zonas que deben recibir el ratón. Se recalcula tras cada
  /// fotograma porque el panel cambia de altura al cambiar de pestaña y de sitio
  /// al arrastrarlo.
  void _publishInteractiveRects() {
    final List<Rect> rects = <Rect>[];

    // El panel solo cuenta si está a la vista; los marcos, siempre que estén
    // activados, aunque el panel esté oculto.
    final BuildContext? panelContext = controller.configMode
        ? _panelKey.currentContext
        : null;
    if (panelContext != null) {
      final RenderObject? renderObject = panelContext.findRenderObject();
      if (renderObject is RenderBox && renderObject.hasSize) {
        final Offset origin = renderObject.localToGlobal(Offset.zero);
        rects.add(
          Rect.fromLTWH(
            origin.dx,
            origin.dy,
            renderObject.size.width,
            renderObject.size.height,
          ),
        );
      }
    }

    final AppSettings s = controller.settings;
    if (s.editRegion) {
      final CaptureRegion region = controller.resolveCaptureRegion();
      if (region.isValid) {
        rects.addAll(
          _boxHitAreas(
            controller.regionToLogicalRect(region),
            locked: s.regionLocked,
          ),
        );
      }
    }
    if (s.editSubtitleBox && s.style.showHistory) {
      // Con el historial dentro, el interior de la caja tambien recibe el raton:
      // sin registrar su rectangulo, la rueda no llegaria a la lista.
      rects.add(s.subtitleBox.rect);
    }
    if (s.editSubtitleBox) {
      rects.addAll(_boxHitAreas(s.subtitleBox.rect, locked: s.subtitleLocked));
    }

    controller.setInteractiveRects(rects);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        if (!controller.isReady) {
          return const _BootScreen();
        }

        final String? fatal = controller.fatalError;
        if (fatal != null) {
          return _FatalScreen(message: fatal, onExit: widget.onExit);
        }

        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _publishInteractiveRects(),
        );

        final AppSettings settings = controller.settings;

        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Size logicalSize = Size(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            // La conversión entre coordenadas de Flutter y de pantalla depende
            // de estos dos valores, y ambos cambian si la ventana se mueve a un
            // monitor con otro escalado.
            controller.reportViewportMetrics(
              logicalSize: logicalSize,
              devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
            );

            return Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                // Fondo del modo compatible.
                //
                // `LWA_COLORKEY` desactiva el alfa por píxel de la ventana: los
                // píxeles que Flutter pinta transparentes dejan de serlo y salen
                // opacos con el color que hubiera en el búfer, que es lo que se
                // veía como una pantalla gris tapando el escritorio. En este
                // modo hay que pintar de verdad el color clave para que Windows
                // sepa qué recortar; en modo compositor el fondo se queda
                // transparente y lo compone el DWM.
                if (settings.transparency == TransparencyMode.colorKey)
                  Positioned.fill(
                    child: ColoredBox(
                      color: Color(0xFF000000 | settings.colorKey),
                    ),
                  ),
                if (settings.editRegion)
                  _RegionOverlay(controller: controller, bounds: logicalSize),
                _SubtitleLayer(controller: controller, bounds: logicalSize),
                if (controller.configMode)
                  Positioned(
                    left: settings.panelX,
                    top: settings.panelY,
                    // Aísla el repintado: mover una caja no debe obligar a
                    // redibujar el panel entero, que es lo más caro de la
                    // pantalla.
                    child: RepaintBoundary(
                      child: ControlPanel(
                        key: _panelKey,
                        controller: controller,
                        onClose: () => controller.setConfigMode(false),
                        onExit: widget.onExit,
                      ),
                    ),
                  ),
                if (!controller.configMode)
                  _LiveIndicator(controller: controller, bounds: logicalSize),
                // Con una actualizacion pendiente se bloquea todo: una version
                // vieja a medias parece un fallo de la aplicacion, y durante la
                // instalacion este mismo ejecutable va a ser sustituido.
                if (controller.updateRequired)
                  UpdateBlockingScreen(
                    state: controller.updateState,
                    onInstall: controller.onRequestUpdateInstall,
                    onRetry: controller.retryUpdate,
                    onExit: widget.onExit,
                    releasesPageUrl: controller.releasesPageUrl,
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// El rectángulo verde de la zona de captura, con su propio candado.
class _RegionOverlay extends StatelessWidget {
  const _RegionOverlay({required this.controller, required this.bounds});

  final AppController controller;
  final Size bounds;

  @override
  Widget build(BuildContext context) {
    final CaptureRegion region = controller.resolveCaptureRegion();
    final Rect logical = controller.regionToLogicalRect(region);

    // Si la región guardada no es válida todavía, no se dibuja nada: pintar un
    // rectángulo de 0x0 con tiradores confundiría más que ayudar.
    if (!region.isValid || logical.width <= 0 || logical.height <= 0) {
      return const SizedBox.shrink();
    }

    final bool following =
        controller.settings.regionMode == RegionMode.followWindow;

    return DraggableBox(
      rect: logical,
      bounds: bounds,
      locked: controller.settings.regionLocked,
      onToggleLock: controller.toggleRegionLocked,
      accentColor: kRegionAccent,
      label: t.captureZone,
      minWidth: 60,
      minHeight: 30,
      badges: <Widget>[
        if (following) ...<Widget>[
          const SizedBox(width: 6),
          const Icon(Icons.link, size: 13, color: kRegionAccent),
        ],
      ],
      onChanged: (Rect updated) =>
          controller.setRegion(controller.logicalRectToRegion(updated)),
    );
  }
}

/// La caja de subtítulos.
///
/// El marco con barra y tiradores solo aparece si se activa la edición desde el
/// panel. El texto se muestra siempre, y nunca intercepta el ratón.
class _SubtitleLayer extends StatelessWidget {
  const _SubtitleLayer({required this.controller, required this.bounds});

  final AppController controller;
  final Size bounds;

  @override
  Widget build(BuildContext context) {
    if (!controller.subtitlesVisible) return const SizedBox.shrink();

    final TranslationPipeline? pipeline = controller.pipeline;
    final SubtitleBox box = controller.settings.subtitleBox;
    // El marco no depende de que el panel esté visible: ocultar el panel con el
    // ojo no debe llevarse por delante la caja de texto ni la zona.
    final bool editing = controller.settings.editSubtitleBox;

    // El texto de muestra solo con la edición activada. Fuera de ahí la caja no
    // existe: no hay marco ni texto de relleno, y en pantalla no aparece nada
    // hasta que hay una traducción de verdad.
    final String? placeholder = editing ? t.subtitlePlaceholder : null;

    final SubtitleStyle style = controller.settings.style;

    // Con el historial activado la caja muestra tambien las lineas anteriores y
    // se puede subir a leerlas; la rueda solo responde con la caja activada,
    // porque fuera de ahi el interior deja pasar el raton al juego.
    final bool useHistory = style.showHistory && pipeline != null;

    // El repintado del texto se aísla del marco: al arrastrar la caja solo se
    // recoloca, sin volver a maquetar el párrafo con su contorno.
    final Widget subtitle = RepaintBoundary(
      child: pipeline == null
          ? SubtitleView(content: null, style: style, placeholder: placeholder)
          : useHistory
          ? ValueListenableBuilder<List<SubtitleContent>>(
              valueListenable: pipeline.history,
              builder:
                  (BuildContext context, List<SubtitleContent> entries, _) {
                    if (entries.isEmpty) {
                      // Todavia no hay nada traducido: se mantiene la vista
                      // simple para que el texto de muestra de la edicion siga
                      // apareciendo.
                      return SubtitleView(
                        content: null,
                        style: style,
                        placeholder: placeholder,
                      );
                    }
                    return SubtitleHistoryView(
                      entries: entries,
                      style: style,
                      interactive: editing,
                    );
                  },
            )
          : ValueListenableBuilder<SubtitleContent?>(
              valueListenable: pipeline.subtitle,
              builder: (BuildContext context, SubtitleContent? content, _) {
                return SubtitleView(
                  content: content,
                  style: style,
                  placeholder: placeholder,
                );
              },
            ),
    );

    if (!editing) {
      return Positioned(
        left: box.left,
        top: box.top,
        width: box.width,
        height: box.height,
        // Recortado al rectángulo de la caja: fuera de la edición no hay marco
        // a la vista, así que un texto desbordado no tendría ninguna referencia
        // y parecería que el subtítulo aparece donde quiere.
        child: IgnorePointer(
          child: ClipRect(child: Center(child: subtitle)),
        ),
      );
    }

    return DraggableBox(
      rect: box.rect,
      bounds: bounds,
      locked: controller.settings.subtitleLocked,
      onToggleLock: controller.toggleSubtitleLocked,
      accentColor: kSubtitleAccent,
      label: t.subtitles,
      minWidth: 200,
      minHeight: 60,
      showFill: false,
      // Con el historial a la vista, el interior necesita la rueda del raton
      // para desplazarse. La caja ya esta activada a mano desde el panel, asi
      // que capturar el raton dentro de ella es lo que espera quien la activo.
      passThroughBody: !useHistory,
      onChanged: (Rect updated) => controller.setSubtitleBox(
        SubtitleBox(
          left: updated.left,
          top: updated.top,
          width: updated.width,
          height: updated.height,
        ),
      ),
      child: ClipRect(child: Center(child: subtitle)),
    );
  }
}

/// Aviso discreto en modo directo. Solo aparece cuando algo va mal: en modo
/// juego no se puede pulsar nada, así que un error silencioso dejaría al
/// usuario esperando subtítulos que no van a llegar.
class _LiveIndicator extends StatelessWidget {
  const _LiveIndicator({required this.controller, required this.bounds});

  final AppController controller;
  final Size bounds;

  @override
  Widget build(BuildContext context) {
    final TranslationPipeline? pipeline = controller.pipeline;
    if (pipeline == null) return const SizedBox.shrink();

    return ValueListenableBuilder<PipelineStatus>(
      valueListenable: pipeline.status,
      builder: (BuildContext context, PipelineStatus status, _) {
        final bool problem =
            status.state == PipelineState.failing ||
            status.state == PipelineState.paused ||
            status.state == PipelineState.stopped;
        if (!problem) return const SizedBox.shrink();

        final Color color = status.state == PipelineState.failing
            ? kDanger
            : kSubtitleAccent;

        return Positioned(
          top: 12,
          left: 0,
          width: bounds.width,
          child: IgnorePointer(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xE61B1B20),
                  border: Border.all(color: color.withValues(alpha: 0.6)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.warning_amber_rounded, size: 15, color: color),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Text(
                        '${status.message}  ·  Ctrl+Alt+T para abrir el panel',
                        maxLines: 2,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.fromLTRB(36, 32, 36, 28),
        decoration: BoxDecoration(
          color: kPanelBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF3A3A44)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x99000000),
              blurRadius: 32,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Image.asset(
              'assets/logo_traducy.png',
              width: 168,
              filterQuality: FilterQuality.high,
            ),
            const SizedBox(height: 22),
            const SizedBox(
              width: 168,
              child: LinearProgressIndicator(
                minHeight: 3,
                color: kAccent,
                backgroundColor: Color(0xFF2E2E38),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              t.preparingOverlay,
              style: const TextStyle(
                color: kMuted,
                fontSize: 12,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FatalScreen extends StatelessWidget {
  const _FatalScreen({required this.message, required this.onExit});

  final String message;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kPanelBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kDanger),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.error_outline, color: kDanger, size: 20),
                const SizedBox(width: 8),
                Text(
                  t.startupFailed,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12.5,
                height: 1.4,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(onPressed: onExit, child: Text(t.exit)),
            ),
          ],
        ),
      ),
    );
  }
}
