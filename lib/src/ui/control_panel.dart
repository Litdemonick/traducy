import 'package:flutter/material.dart';

import '../core/app_paths.dart';
import 'toasts.dart';
import '../core/logx.dart';
import '../core/version.dart';
import '../models/languages.dart';
import '../models/settings.dart';
import '../pipeline/pipeline.dart';
import '../ocr/tessdata_installer.dart';
import '../state/app_controller.dart';
import 'about_section.dart';
import 'update_section.dart';
import 'widgets_common.dart';
import 'zone_console.dart';

/// Panel de configuración. Solo se muestra en modo configuración.
class ControlPanel extends StatefulWidget {
  const ControlPanel({
    super.key,
    required this.controller,
    required this.onClose,
    required this.onExit,
  });

  final AppController controller;
  final VoidCallback onClose;
  final VoidCallback onExit;

  @override
  State<ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends State<ControlPanel>
    with SingleTickerProviderStateMixin {
  static const int _tabCount = 6;

  late final TabController _tabs = TabController(
    length: _tabCount,
    vsync: this,
  );

  /// Un controlador por pestaña. `Scrollbar` exige un controlador dedicado por
  /// área desplazable: compartir uno entre las cinco pestañas hace que la barra
  /// se enganche a la equivocada y salte al cambiar de pestaña.
  late final List<ScrollController> _scrollControllers =
      List<ScrollController>.generate(_tabCount, (_) => ScrollController());

  @override
  void dispose() {
    _tabs.dispose();
    for (final ScrollController controller in _scrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  AppController get c => widget.controller;

  @override
  Widget build(BuildContext context) {
    final Size size = c.panelSize;

    return SizedBox(
      width: size.width,
      height: size.height,
      child: Stack(
        children: <Widget>[
          Positioned.fill(child: _panel(context)),
          // Asa de redimensión en la esquina inferior derecha, dentro de los
          // límites del panel: un widget pintado fuera de su padre no recibe
          // clics en Flutter.
          Positioned(
            right: 0,
            bottom: 0,
            child: _ResizeGrip(
              onDelta: (Offset delta) => c.setPanelSize(
                Size(size.width + delta.dx, size.height + delta.dy),
              ),
              onReset: c.resetPanelSize,
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kPanelBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3A3A44)),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x99000000), blurRadius: 24, spreadRadius: 2),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _Header(
            controller: c,
            onClose: widget.onClose,
            onExit: widget.onExit,
          ),
          _SetupGuide(controller: c),
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: kAccent,
            unselectedLabelColor: kMuted,
            indicatorColor: kAccent,
            labelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            dividerColor: const Color(0xFF3A3A44),
            tabs: const <Tab>[
              Tab(text: 'Zona'),
              Tab(text: 'Idiomas'),
              Tab(text: 'Estilo'),
              Tab(text: 'Rendimiento'),
              Tab(text: 'Diagnóstico'),
              Tab(text: 'Acerca de'),
            ],
          ),
          // Expanded en lugar de una altura fija: así el contenido crece y se
          // encoge con el panel al redimensionarlo.
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: <Widget>[
                _scroll(0, _RegionTab(controller: c)),
                _scroll(1, _LanguagesTab(controller: c)),
                _scroll(2, _StyleTab(controller: c)),
                _scroll(3, _PerformanceTab(controller: c)),
                _scroll(4, _DiagnosticsTab(controller: c)),
                _scroll(
                  5,
                  AboutSection(controller: c, onCopied: toasts.success),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Área desplazable con barra **siempre visible**.
  ///
  /// La barra que aparece y desaparece esconde que hay más contenido debajo, y
  /// en un panel con muchos ajustes eso lleva a pensar que no hay nada más. Con
  /// `thumbVisibility` fija, siempre se ve cuánto queda por recorrer.
  Widget _scroll(int index, Widget child) {
    final ScrollController controller = _scrollControllers[index];
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Scrollbar(
        controller: controller,
        thumbVisibility: true,
        trackVisibility: true,
        thickness: 7,
        radius: const Radius.circular(4),
        child: SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 4, 14, 16),
          child: child,
        ),
      ),
    );
  }
}

/// Asa para redimensionar el panel.
///
/// Doble clic devuelve el tamaño por defecto: es la salida cuando alguien lo
/// deja demasiado pequeño o demasiado grande y no encuentra cómo arreglarlo.
class _ResizeGrip extends StatelessWidget {
  const _ResizeGrip({required this.onDelta, required this.onReset});

  final ValueChanged<Offset> onDelta;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeDownRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (DragUpdateDetails details) => onDelta(details.delta),
        onDoubleTap: onReset,
        child: Tooltip(
          message:
              'Arrastra para redimensionar · doble clic para el tamaño '
              'por defecto',
          child: SizedBox(
            width: 22,
            height: 22,
            child: Center(
              child: Icon(
                Icons.drag_handle,
                size: 13,
                color: kMuted.withValues(alpha: 0.8),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ cabecera

class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.onClose,
    required this.onExit,
  });

  final AppController controller;
  final VoidCallback onClose;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final TranslationPipeline? pipeline = controller.pipeline;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
      child: Column(
        children: <Widget>[
          // La cabecera es el asa del panel: se arrastra desde aquí, como la
          // barra de título de cualquier ventana.
          MouseRegion(
            cursor: SystemMouseCursors.move,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (DragUpdateDetails details) {
                final AppSettings s = controller.settings;
                controller.setPanelPosition(
                  Offset(
                    s.panelX + details.delta.dx,
                    s.panelY + details.delta.dy,
                  ),
                );
              },
              child: Row(
                children: <Widget>[
                  const Icon(Icons.drag_indicator, color: kMuted, size: 18),
                  const SizedBox(width: 6),
                  // El símbolo del logo, no un icono genérico. `filterQuality`
                  // alta importa: se reduce de 361 px a 22 y sin ello el trazo
                  // blanco del interior se ve sucio.
                  Image.asset(
                    'assets/logo_mark.png',
                    width: 22,
                    height: 22,
                    filterQuality: FilterQuality.high,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Traducy',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Expanded(child: SizedBox.shrink()),
                  IconButton(
                    tooltip:
                        'Minimizar. Su botón sigue en la barra de tareas: '
                        'púlsalo para volver',
                    icon: const Icon(Icons.remove, size: 18),
                    color: kMuted,
                    onPressed: () => controller.minimizeOverlay(),
                  ),
                  IconButton(
                    tooltip:
                        'Modo juego: oculta Traducy y lo deja en segundo plano. '
                        'Vuelve con su icono junto al reloj o con Ctrl+Alt+T',
                    icon: const Icon(Icons.visibility_off, size: 18),
                    color: kMuted,
                    onPressed: () => controller.sendToBackground(),
                  ),
                  IconButton(
                    tooltip: 'Salir de Traducy',
                    icon: const Icon(Icons.power_settings_new, size: 18),
                    color: kDanger,
                    onPressed: onExit,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (pipeline != null)
            ValueListenableBuilder<PipelineStatus>(
              valueListenable: pipeline.status,
              builder: (BuildContext context, PipelineStatus status, _) {
                return Row(
                  children: <Widget>[
                    Expanded(child: _StatusPill(status: status)),
                    const SizedBox(width: 8),
                    _PrimaryButton(
                      icon: status.state == PipelineState.running
                          ? Icons.pause
                          : Icons.play_arrow,
                      label: status.state == PipelineState.running
                          ? 'Pausar'
                          : 'Traducir',
                      color: status.state == PipelineState.running
                          ? kSubtitleAccent
                          : kRegionAccent,
                      onPressed: () {
                        if (status.state == PipelineState.stopped) {
                          controller.startTranslating();
                        } else {
                          controller.togglePause();
                        }
                      },
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Guia de puesta en marcha.
///
/// Responde a la pregunta "por que no traduce?" sin obligar a rebuscar en las
/// pestanas: detecta el primer paso que falta, lo explica y ofrece el boton que
/// lo resuelve. El resto de pasos quedan a la vista como lista de comprobacion,
/// para que se entienda que hace falta y en que orden.
class _SetupGuide extends StatelessWidget {
  const _SetupGuide({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final List<_Step> steps = _buildSteps(controller);
    _Step? blocking;
    for (final _Step step in steps) {
      if (!step.done) {
        blocking = step;
        break;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (blocking != null)
            NoticeCard(
              message: blocking.problem,
              hint: blocking.hint,
              severity: NoticeSeverity.error,
              action: blocking.action,
            ),
          if (controller.downloadError != null)
            NoticeCard(
              message: controller.downloadError!,
              severity: NoticeSeverity.error,
              action: TextButton(
                onPressed: controller.clearDownloadError,
                child: const Text(
                  'Entendido',
                  style: TextStyle(fontSize: 11.5),
                ),
              ),
            ),
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF15151A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (int i = 0; i < steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          steps[i].done
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 14,
                          color: steps[i].done ? kRegionAccent : kMuted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${i + 1}. ${steps[i].title}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: steps[i].done
                                  ? Colors.white70
                                  : Colors.white,
                              fontWeight: steps[i].done
                                  ? FontWeight.w400
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_Step> _buildSteps(AppController c) {
    final bool tesseractMissing =
        c.ocrHealth.hasProblem && c.missingOcrLanguages.isEmpty;
    final bool languageMissing = c.missingOcrLanguages.isNotEmpty;
    final bool regionReady = c.resolveCaptureRegion().isValid;
    final bool running = c.pipeline?.isRunning ?? false;
    final String missingFirst = c.missingOcrLanguages.isEmpty
        ? ''
        : c.missingOcrLanguages.first;

    return <_Step>[
      _Step(
        title: 'Instalar Tesseract, el motor que lee el texto',
        done: !tesseractMissing,
        problem:
            'Falta Tesseract: sin el no se puede leer el texto de la pantalla.',
        hint:
            'Es el unico programa externo que necesita Traducy. Pulsa el boton '
            'y acepta la instalacion en la ventana que se abre.',
        action: _ActionButton(
          label: 'Instalar Tesseract',
          icon: Icons.download,
          onPressed: c.installTesseract,
          secondaryLabel: 'Ya esta, comprobar',
          onSecondary: c.refreshEngineHealth,
        ),
      ),
      _Step(
        title: 'Descargar el idioma del juego',
        done: !languageMissing,
        problem: 'Falta el idioma "$missingFirst" del OCR.',
        hint:
            'Tesseract necesita un paquete por cada escritura que lee. Se '
            'descarga en la carpeta de Traducy, sin pedir permisos de '
            'administrador.',
        action: c.download != null
            ? _DownloadProgressBar(progress: c.download!)
            : _ActionButton(
                label: 'Descargar $missingFirst',
                icon: Icons.language,
                onPressed: () {
                  if (missingFirst.isNotEmpty) {
                    c.installOcrLanguage(missingFirst);
                  }
                },
              ),
      ),
      _Step(
        title: 'Marcar la zona donde aparece el texto',
        done: regionReady,
        problem: 'No hay una zona de captura valida todavia.',
        hint:
            'Pulsa el boton para colocar una banda en la parte baja de la '
            'pantalla, y luego ajustala arrastrando el rectangulo verde sobre '
            'el texto del juego.',
        action: _ActionButton(
          label: 'Usar la banda inferior',
          icon: Icons.subtitles,
          onPressed: () {
            c.setRegionToBottomBand();
            c.setEditRegion(true);
          },
        ),
      ),
      _Step(
        title: 'Pulsar Traducir y pasar a modo juego con Ctrl+Alt+T',
        done: running,
        problem: 'Todo listo, pero la traduccion esta parada.',
        hint:
            'Pulsa Traducir. Recuerda tener el juego en modo ventana: la '
            'pantalla completa exclusiva no se puede capturar.',
        action: _ActionButton(
          label: 'Traducir ahora',
          icon: Icons.play_arrow,
          onPressed: c.startTranslating,
        ),
      ),
    ];
  }
}

class _Step {
  const _Step({
    required this.title,
    required this.done,
    required this.problem,
    required this.hint,
    required this.action,
  });

  final String title;
  final bool done;
  final String problem;
  final String hint;
  final Widget action;
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 15),
          label: Text(label),
          style: FilledButton.styleFrom(
            backgroundColor: kAccent,
            foregroundColor: const Color(0xFF11131A),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (secondaryLabel != null && onSecondary != null) ...<Widget>[
          const SizedBox(width: 8),
          TextButton(
            onPressed: onSecondary,
            child: Text(
              secondaryLabel!,
              style: const TextStyle(fontSize: 11.5),
            ),
          ),
        ],
      ],
    );
  }
}

class _DownloadProgressBar extends StatelessWidget {
  const _DownloadProgressBar({required this.progress});

  final DownloadProgress progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LinearProgressIndicator(
          // Sin tamano total conocido se muestra indeterminada, en lugar de una
          // barra congelada en cero.
          value: progress.totalBytes > 0 ? progress.fraction : null,
          minHeight: 4,
          color: kAccent,
          backgroundColor: const Color(0xFF2E2E38),
        ),
        const SizedBox(height: 6),
        Text(
          'Descargando ${progress.language}...  ${progress.readable}',
          style: const TextStyle(color: kMuted, fontSize: 11),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final PipelineStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon) = switch (status.state) {
      PipelineState.running => (kRegionAccent, Icons.sensors),
      PipelineState.paused => (kSubtitleAccent, Icons.pause_circle_outline),
      PipelineState.failing => (kDanger, Icons.error_outline),
      PipelineState.stopped => (kMuted, Icons.stop_circle_outlined),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              status.message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 11.5),
            ),
          ),
          if (status.lastTotalMs > 0)
            Text(
              '${status.lastTotalMs} ms',
              style: const TextStyle(color: kMuted, fontSize: 10.5),
            ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: const Color(0xFF11131A),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ------------------------------------------------------------- pestaña Zona

class _RegionTab extends StatelessWidget {
  const _RegionTab({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final AppSettings s = controller.settings;
    final CaptureRegion region = controller.resolveCaptureRegion();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ZoneConsole(controller: controller, zone: PanelZone.region),
        const SectionTitle('Activar sobre la pantalla'),
        const HelpText(
          'Los dos vienen desactivados a propósito: así nada aparece sobre el '
          'juego sin que lo pidas. Actívalos para colocarlos, y desactívalos al '
          'terminar. Se mueven por su barra de título y se redimensionan por los '
          'tiradores del borde; el interior deja pasar los clics al juego.',
        ),
        _EditToggle(
          label: 'Activar zona de captura',
          description: 'Muestra el rectángulo verde para situarlo sobre el texto del juego.',
          color: kRegionAccent,
          value: s.editRegion,
          onChanged: controller.setEditRegion,
        ),
        _EditToggle(
          label: 'Activar caja de subtítulos',
          description:
              'Muestra el marco naranja y un texto de ejemplo para colocarlo y '
              'darle estilo. Apagado, no aparece nada hasta que hay traducción.',
          color: kSubtitleAccent,
          value: s.editSubtitleBox,
          onChanged: controller.setEditSubtitleBox,
        ),

        const SectionTitle('Zona de captura'),
        const HelpText(
          'Lo más directo es detectar el juego: la zona se coloca sola en su '
          'parte baja y se mueve con la ventana. Si prefieres situarla a mano, '
          'usa los botones de abajo y ajusta el rectángulo verde.',
        ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => controller.detectGameWindow(),
            icon: const Icon(Icons.videogame_asset, size: 16),
            label: const Text('Detectar el juego'),
            style: FilledButton.styleFrom(
              backgroundColor: kRegionAccent,
              foregroundColor: const Color(0xFF11131A),
              padding: const EdgeInsets.symmetric(vertical: 10),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        if (s.regionMode == RegionMode.followWindow &&
            s.followWindowTitle.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: <Widget>[
                const Icon(Icons.link, size: 13, color: kRegionAccent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Anclada a "${s.followWindowTitle}"',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kRegionAccent, fontSize: 11),
                  ),
                ),
                TextButton(
                  onPressed: controller.stopFollowingWindow,
                  style: TextButton.styleFrom(
                    foregroundColor: kMuted,
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                  child: const Text('Desanclar'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: controller.setRegionToBottomBand,
                icon: const Icon(Icons.subtitles, size: 15),
                label: const Text('Banda inferior'),
                style: _outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: controller.setRegionToFullScreen,
                icon: const Icon(Icons.fullscreen, size: 15),
                label: const Text('Pantalla completa'),
                style: _outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchRow(
          label: 'Zona bloqueada',
          subtitle: s.regionLocked
              ? 'No se puede mover ni redimensionar.'
              : 'Se puede arrastrar y redimensionar.',
          value: s.regionLocked,
          onChanged: (bool v) => controller.setRegionLocked(v),
        ),
        SwitchRow(
          label: 'Caja de subtítulos bloqueada',
          subtitle: 'Candado independiente del de la zona.',
          value: s.subtitleLocked,
          onChanged: (bool v) => controller.setSubtitleLocked(v),
        ),
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF15151A),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: <Widget>[
              _MetricChip(label: 'X', value: '${region.left}'),
              _MetricChip(label: 'Y', value: '${region.top}'),
              _MetricChip(label: 'Ancho', value: '${region.width}'),
              _MetricChip(label: 'Alto', value: '${region.height}'),
            ],
          ),
        ),
        if (!region.isValid)
          const NoticeCard(
            message: 'La zona es demasiado pequeña para leer texto.',
            hint: 'Pulsa "Banda inferior" o agranda el rectángulo verde.',
            severity: NoticeSeverity.warning,
          ),

        const SectionTitle('Seguir una ventana'),
        const HelpText(
          'Ancla la zona a una ventana concreta: si mueves el juego, la zona lo '
          'acompaña.',
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                s.regionMode == RegionMode.followWindow
                    ? 'Siguiendo: ${s.followWindowTitle}'
                    : 'Zona fija en la pantalla',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            IconButton(
              tooltip: 'Actualizar la lista de ventanas',
              icon: const Icon(Icons.refresh, size: 18),
              color: kAccent,
              onPressed: controller.refreshWindowList,
            ),
          ],
        ),
        if (s.regionMode == RegionMode.followWindow)
          OutlinedButton.icon(
            onPressed: controller.stopFollowingWindow,
            icon: const Icon(Icons.link_off, size: 15),
            label: const Text('Dejar de seguir'),
            style: _outlined,
          ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 160),
          child: controller.availableWindows.isEmpty
              ? const HelpText(
                  'Pulsa actualizar para listar las ventanas abiertas.',
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: controller.availableWindows.length,
                  itemBuilder: (BuildContext context, int index) {
                    final window = controller.availableWindows[index];
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        window.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      subtitle: Text(
                        '${window.width}×${window.height}',
                        style: const TextStyle(color: kMuted, fontSize: 10.5),
                      ),
                      trailing: TextButton(
                        onPressed: () => controller.followWindow(window),
                        child: const Text(
                          'Seguir',
                          style: TextStyle(fontSize: 11.5),
                        ),
                      ),
                    );
                  },
                ),
        ),

        const SectionTitle('Ventana del overlay'),
        if (controller.isExcludedFromCapture)
          const NoticeCard(
            message: 'El overlay está excluido de la captura.',
            hint:
                'Los subtítulos no se releerán a sí mismos, así que puedes '
                'colocarlos donde quieras.',
            severity: NoticeSeverity.success,
          )
        else
          const NoticeCard(
            message:
                'Este Windows no permite excluir el overlay de la captura.',
            hint:
                'Mantén la caja de subtítulos FUERA del rectángulo verde para '
                'que el OCR no lea su propia traducción.',
            severity: NoticeSeverity.warning,
          ),
        if (controller.subtitleOverlapsRegion)
          const NoticeCard(
            message: 'La caja de subtítulos se solapa con la zona de captura.',
            hint: 'Muévela fuera del rectángulo verde para evitar un bucle.',
            severity: NoticeSeverity.error,
          ),
        SwitchRow(
          label: 'Abrir en modo configuración',
          subtitle: 'Si se desactiva, Traducy arranca directo en modo juego.',
          value: controller.settings.startInConfigMode,
          onChanged: controller.setStartInConfigMode,
        ),
        SwitchRow(
          label: 'Poder jugar con el panel abierto',
          subtitle:
              'Los clics pasan al juego salvo cuando el cursor está sobre el '
              'panel o las cajas. Desactívalo si algún clic no responde bien.',
          value: controller.settings.passthroughInConfig,
          onChanged: controller.setPassthroughInConfig,
        ),
        const SectionTitle('Transparencia'),
        const HelpText(
          'Compositor da transparencia real y es lo normal. El modo compatible '
          'recorta un color en vez de usar transparencia real: úsalo solo si con '
          'Compositor ves un fondo opaco tapando el escritorio. Los bordes '
          'suaves y los fondos translúcidos del subtítulo pierden calidad.',
        ),
        SegmentedButton<TransparencyMode>(
          segments: const <ButtonSegment<TransparencyMode>>[
            ButtonSegment<TransparencyMode>(
              value: TransparencyMode.compositor,
              label: Text('Compositor'),
            ),
            ButtonSegment<TransparencyMode>(
              value: TransparencyMode.colorKey,
              label: Text('Compatible'),
            ),
          ],
          selected: <TransparencyMode>{controller.settings.transparency},
          onSelectionChanged: (Set<TransparencyMode> value) =>
              controller.setTransparencyMode(value.first),
          style: ButtonStyle(
            textStyle: const WidgetStatePropertyAll<TextStyle>(
              TextStyle(fontSize: 11.5),
            ),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }
}

/// Interruptor grande y con color para activar cada marco de edición.
///
/// Va destacado porque es la puerta de entrada a colocar la zona: si pasa
/// desapercibido, el usuario no encuentra cómo mover nada.
class _EditToggle extends StatelessWidget {
  const _EditToggle({
    required this.label,
    required this.description,
    required this.color,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String description;
  final Color color;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: value
                ? color.withValues(alpha: 0.14)
                : const Color(0xFF15151A),
            border: Border.all(
              color: value ? color : const Color(0xFF3A3A44),
              width: value ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                value ? Icons.crop_free : Icons.crop_din,
                size: 17,
                color: value ? color : kMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: TextStyle(
                        color: value ? Colors.white : Colors.white70,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        description,
                        style: const TextStyle(color: kMuted, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                activeThumbColor: color,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(label, style: const TextStyle(color: kMuted, fontSize: 10)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------- pestaña Idiomas

class _LanguagesTab extends StatelessWidget {
  const _LanguagesTab({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final EngineSettings e = controller.settings.engines;
    final bool autoDetect = e.sourceLanguage == 'auto';
    final LanguageOption? ocrLanguage = languageByOcrCode(e.ocrLanguages);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ZoneConsole(controller: controller, zone: PanelZone.languages),

        const SectionTitle('Motor de OCR (lo que lee la pantalla)'),
        const HelpText(
          'El de Windows viene con el sistema: es gratis, no hay nada que '
          'instalar, no sale nada del equipo y acierta más sobre capturas de '
          'pantalla, sobre todo en japonés. Necesita que el idioma esté añadido '
          'en Windows. Tesseract funciona en cualquier equipo y trae sus propios '
          'paquetes, que Traducy descarga sin permisos de administrador.',
        ),
        SegmentedButton<OcrKind>(
          segments: const <ButtonSegment<OcrKind>>[
            ButtonSegment<OcrKind>(
              value: OcrKind.windows,
              label: Text('Windows'),
              icon: Icon(Icons.window, size: 14),
            ),
            ButtonSegment<OcrKind>(
              value: OcrKind.tesseract,
              label: Text('Tesseract'),
              icon: Icon(Icons.text_fields, size: 14),
            ),
          ],
          selected: <OcrKind>{e.ocrKind},
          onSelectionChanged: (Set<OcrKind> value) =>
              controller.setOcrKind(value.first),
          style: ButtonStyle(
            textStyle: const WidgetStatePropertyAll<TextStyle>(
              TextStyle(fontSize: 11.5),
            ),
            visualDensity: VisualDensity.compact,
          ),
        ),
        if (e.ocrKind == OcrKind.windows)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: controller.windowsOcrAvailable
                ? Text(
                    controller.windowsOcrCoversRequest
                        ? 'Windows reconoce: '
                              '${controller.windowsOcrLanguages.join(', ')}'
                        : 'Windows no tiene el idioma pedido. Añádelo en '
                              'Configuración → Hora e idioma → Idioma y región, '
                              'o cambia a Tesseract.',
                    style: TextStyle(
                      color: controller.windowsOcrCoversRequest
                          ? kMuted
                          : kSubtitleAccent,
                      fontSize: 10.5,
                      height: 1.35,
                    ),
                  )
                : const Text(
                    'Comprueba los motores en Diagnóstico para saber qué '
                    'idiomas reconoce este Windows.',
                    style: TextStyle(
                      color: kMuted,
                      fontSize: 10.5,
                      height: 1.35,
                    ),
                  ),
          ),

        const SectionTitle('Idioma del juego (lo que se lee)'),
        const HelpText(
          'El OCR necesita saber qué escritura leer. Elegir aquí "Japonés" '
          'configura a la vez el paquete de OCR y el idioma de origen.',
        ),
        DropdownButtonFormField<String>(
          initialValue: ocrLanguage?.ocrCode,
          isExpanded: true,
          dropdownColor: kPanelSurface,
          decoration: _dropdownDecoration('Escritura a reconocer'),
          style: const TextStyle(color: Colors.white, fontSize: 12.5),
          items: <DropdownMenuItem<String>>[
            for (final LanguageOption option in sourceLanguages)
              DropdownMenuItem<String>(
                value: option.ocrCode,
                child: Text(
                  '${option.label}  ·  ${option.ocrCode}'
                  // El aviso de "no instalado" es cosa de Tesseract: el motor de
                  // Windows no usa estos paquetes y marcarlos ahi confundiria.
                  '${e.ocrKind == OcrKind.tesseract && controller.installedOcrLanguages.isNotEmpty && !controller.installedOcrLanguages.contains(option.ocrCode) ? '  (no instalado)' : ''}',
                ),
              ),
          ],
          onChanged: (String? code) {
            if (code == null) return;
            final LanguageOption? option = languageByOcrCode(code);
            if (option != null) controller.applySourceLanguage(option);
          },
        ),
        if (ocrLanguage?.note != null) HelpText(ocrLanguage!.note!),
        SwitchRow(
          label: 'Detectar idioma automáticamente al traducir',
          subtitle: autoDetect
              ? 'El traductor decide el idioma de origen.'
              : 'Se envía "${e.sourceLanguage}" como idioma de origen.',
          value: autoDetect,
          onChanged: (bool v) {
            controller.setEngines(
              e.copyWith(
                sourceLanguage: v
                    ? 'auto'
                    : (ocrLanguage?.translateCode ?? 'en'),
              ),
            );
          },
        ),

        const SectionTitle('Traducir a'),
        DropdownButtonFormField<String>(
          initialValue:
              targetByTranslateCode(e.targetLanguage)?.translateCode ?? 'es',
          isExpanded: true,
          dropdownColor: kPanelSurface,
          decoration: _dropdownDecoration('Idioma de destino'),
          style: const TextStyle(color: Colors.white, fontSize: 12.5),
          items: <DropdownMenuItem<String>>[
            for (final LanguageOption option in targetLanguages)
              DropdownMenuItem<String>(
                value: option.translateCode,
                child: Text(option.label),
              ),
          ],
          onChanged: (String? code) {
            if (code == null) return;
            final LanguageOption? option = targetByTranslateCode(code);
            if (option != null) controller.applyTargetLanguage(option);
          },
        ),

        const SectionTitle('Motor de traducción'),
        DropdownButtonFormField<TranslatorKind>(
          initialValue: e.translator,
          isExpanded: true,
          dropdownColor: kPanelSurface,
          decoration: _dropdownDecoration('Motor'),
          style: const TextStyle(color: Colors.white, fontSize: 12.5),
          items: const <DropdownMenuItem<TranslatorKind>>[
            DropdownMenuItem<TranslatorKind>(
              value: TranslatorKind.googleFree,
              child: Text('Google Traductor — gratis, sin clave'),
            ),
            DropdownMenuItem<TranslatorKind>(
              value: TranslatorKind.claude,
              child: Text('Claude — máxima calidad (API key)'),
            ),
            DropdownMenuItem<TranslatorKind>(
              value: TranslatorKind.deepl,
              child: Text('DeepL — muy buena calidad (API key)'),
            ),
            DropdownMenuItem<TranslatorKind>(
              value: TranslatorKind.libre,
              child: Text('LibreTranslate — servidor propio'),
            ),
            DropdownMenuItem<TranslatorKind>(
              value: TranslatorKind.none,
              child: Text('Sin traducir — solo mostrar el original'),
            ),
          ],
          onChanged: (TranslatorKind? kind) {
            if (kind != null) {
              controller.setEngines(e.copyWith(translator: kind));
            }
          },
        ),

        if (e.translator == TranslatorKind.claude) ...<Widget>[
          DebouncedTextField(
            label: 'API key de Claude',
            hint: 'sk-ant-...',
            initialValue: e.claudeKey,
            obscure: true,
            onSubmitted: (String v) =>
                controller.setEngines(e.copyWith(claudeKey: v.trim())),
          ),
          DebouncedTextField(
            label: 'Modelo',
            initialValue: e.claudeModel,
            onSubmitted: (String v) => controller.setEngines(
              e.copyWith(
                claudeModel: v.trim().isEmpty ? 'claude-opus-5' : v.trim(),
              ),
            ),
          ),
          const HelpText(
            'Traduce entendiendo el contexto del juego: mantiene el tono y no '
            'destroza los nombres propios. Es de pago por uso.',
          ),
        ],
        if (e.translator == TranslatorKind.deepl)
          DebouncedTextField(
            label: 'API key de DeepL',
            hint: 'Las claves gratuitas terminan en :fx',
            initialValue: e.deeplKey,
            obscure: true,
            onSubmitted: (String v) =>
                controller.setEngines(e.copyWith(deeplKey: v.trim())),
          ),
        if (e.translator == TranslatorKind.libre)
          DebouncedTextField(
            label: 'URL de LibreTranslate',
            hint: 'http://localhost:5000',
            initialValue: e.libreTranslateUrl,
            onSubmitted: (String v) =>
                controller.setEngines(e.copyWith(libreTranslateUrl: v.trim())),
          ),

        const SectionTitle('Glosario'),
        const HelpText(
          'Términos que no deben traducirse o que tienen una traducción fija. '
          'Una línea por entrada. Solo lo aplica el motor Claude.',
        ),
        DebouncedTextField(
          label: 'Glosario',
          hint: 'Hollow Knight = Hollow Knight\nEstus Flask = Frasco de Estus',
          initialValue: e.glossary,
          maxLines: 4,
          onSubmitted: (String v) =>
              controller.setEngines(e.copyWith(glossary: v)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------- pestaña Estilo

class _StyleTab extends StatelessWidget {
  const _StyleTab({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final SubtitleStyle st = controller.settings.style;
    void update(SubtitleStyle updated) => controller.setStyle(updated);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ZoneConsole(controller: controller, zone: PanelZone.style),
        const SectionTitle('Texto'),
        SliderRow(
          label: 'Tamaño',
          value: st.fontSize,
          min: 12,
          max: 84,
          onChanged: (double v) => update(st.copyWith(fontSize: v)),
          suffix: ' px',
        ),
        SliderRow(
          label: 'Altura de línea',
          value: st.lineHeight,
          min: 0.9,
          max: 2.2,
          decimals: 2,
          onChanged: (double v) => update(st.copyWith(lineHeight: v)),
        ),
        SliderRow(
          label: 'Espaciado',
          value: st.letterSpacing,
          min: -1,
          max: 6,
          decimals: 1,
          onChanged: (double v) => update(st.copyWith(letterSpacing: v)),
        ),
        SliderRow(
          label: 'Líneas máximas',
          value: st.maxLines.toDouble(),
          min: 1,
          max: 10,
          divisions: 9,
          onChanged: (double v) => update(st.copyWith(maxLines: v.round())),
        ),
        SwitchRow(
          label: 'Historial en la caja',
          subtitle: st.showHistory
              ? 'Se ven también las líneas anteriores, con scroll. Activa la '
                    'caja para poder subir a leerlas con la rueda.'
              : 'Solo la última línea traducida.',
          value: st.showHistory,
          onChanged: (bool v) => update(st.copyWith(showHistory: v)),
        ),
        if (st.showHistory)
          SliderRow(
            label: 'Líneas recordadas',
            value: st.historyLength.toDouble(),
            min: 2,
            max: 40,
            divisions: 38,
            onChanged: (double v) =>
                update(st.copyWith(historyLength: v.round())),
          ),
        if (st.showHistory)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: OutlinedButton.icon(
              onPressed: controller.clearSubtitleHistory,
              icon: const Icon(Icons.delete_sweep, size: 15),
              label: const Text('Vaciar el historial'),
              style: _outlined,
            ),
          ),
        SwitchRow(
          label: 'Ajustar el texto a la caja',
          subtitle: st.autoFit
              ? 'La letra se encoge lo necesario para que entre el texto entero.'
              : 'Tamaño fijo: el texto largo se recorta.',
          value: st.autoFit,
          onChanged: (bool v) => update(st.copyWith(autoFit: v)),
        ),
        if (st.autoFit)
          SliderRow(
            label: 'Encogido máximo',
            value: st.minFontScale * 100,
            min: 30,
            max: 100,
            decimals: 0,
            suffix: ' %',
            onChanged: (double v) => update(st.copyWith(minFontScale: v / 100)),
          ),
        if (st.autoFit)
          const HelpText(
            'Hasta dónde puede encogerse la letra. Un texto que entra pero no se '
            'puede leer no sirve, así que por debajo de este límite se recorta '
            'en lugar de seguir reduciendo.',
          ),
        Row(
          children: <Widget>[
            Expanded(
              child: SwitchRow(
                label: 'Negrita',
                value: st.bold,
                onChanged: (bool v) => update(st.copyWith(bold: v)),
              ),
            ),
            Expanded(
              child: SwitchRow(
                label: 'Cursiva',
                value: st.italic,
                onChanged: (bool v) => update(st.copyWith(italic: v)),
              ),
            ),
          ],
        ),
        DebouncedTextField(
          label: 'Fuente',
          hint: 'Segoe UI, Arial, Consolas…',
          initialValue: st.fontFamily,
          onSubmitted: (String v) => update(
            st.copyWith(fontFamily: v.trim().isEmpty ? 'Segoe UI' : v.trim()),
          ),
        ),
        SegmentedButton<SubtitleAlign>(
          segments: const <ButtonSegment<SubtitleAlign>>[
            ButtonSegment<SubtitleAlign>(
              value: SubtitleAlign.left,
              icon: Icon(Icons.format_align_left, size: 16),
            ),
            ButtonSegment<SubtitleAlign>(
              value: SubtitleAlign.center,
              icon: Icon(Icons.format_align_center, size: 16),
            ),
            ButtonSegment<SubtitleAlign>(
              value: SubtitleAlign.right,
              icon: Icon(Icons.format_align_right, size: 16),
            ),
          ],
          selected: <SubtitleAlign>{st.align},
          onSelectionChanged: (Set<SubtitleAlign> v) =>
              update(st.copyWith(align: v.first)),
          style: ButtonStyle(visualDensity: VisualDensity.compact),
        ),

        const SectionTitle('Legibilidad'),
        const HelpText(
          'El contorno es lo que mantiene el texto legible sobre cualquier '
          'escena; el fondo semitransparente ayuda en fondos muy movidos.',
        ),
        SliderRow(
          label: 'Grosor contorno',
          value: st.outlineWidth,
          min: 0,
          max: 10,
          decimals: 1,
          onChanged: (double v) => update(st.copyWith(outlineWidth: v)),
        ),
        SliderRow(
          label: 'Opacidad fondo',
          value: st.backgroundOpacity,
          min: 0,
          max: 1,
          decimals: 2,
          onChanged: (double v) => update(st.copyWith(backgroundOpacity: v)),
        ),
        SliderRow(
          label: 'Redondeo',
          value: st.cornerRadius,
          min: 0,
          max: 32,
          onChanged: (double v) => update(st.copyWith(cornerRadius: v)),
        ),
        SliderRow(
          label: 'Margen interno',
          value: st.padding,
          min: 0,
          max: 40,
          onChanged: (double v) => update(st.copyWith(padding: v)),
        ),
        SwitchRow(
          label: 'Sombra',
          value: st.shadow,
          onChanged: (bool v) => update(st.copyWith(shadow: v)),
        ),
        SwitchRow(
          label: 'Mostrar también el texto original',
          subtitle: 'Útil para aprender el idioma o revisar el OCR.',
          value: st.showOriginal,
          onChanged: (bool v) => update(st.copyWith(showOriginal: v)),
        ),

        const SectionTitle('Colores'),
        ColorPickerRow(
          label: 'Color del texto',
          color: st.textColor,
          onChanged: (Color c) => update(st.copyWith(textColor: c)),
        ),
        ColorPickerRow(
          label: 'Color del contorno',
          color: st.outlineColor,
          onChanged: (Color c) => update(st.copyWith(outlineColor: c)),
        ),
        ColorPickerRow(
          label: 'Color del fondo',
          color: st.backgroundColor,
          onChanged: (Color c) => update(st.copyWith(backgroundColor: c)),
        ),
      ],
    );
  }
}

// ----------------------------------------------------- pestaña Rendimiento

class _PerformanceTab extends StatelessWidget {
  const _PerformanceTab({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final PipelineSettings p = controller.settings.pipeline;
    final PreprocessSettings pre = controller.settings.preprocess;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ZoneConsole(controller: controller, zone: PanelZone.performance),
        const SectionTitle('Frecuencia'),
        const HelpText(
          'Intervalo entre capturas. Más bajo responde antes pero consume más '
          'CPU y más cuota de traducción.',
        ),
        SliderRow(
          label: 'Intervalo',
          value: p.intervalMs.toDouble(),
          min: 150,
          max: 2000,
          divisions: 37,
          suffix: ' ms',
          onChanged: (double v) =>
              controller.setPipelineSettings(p.copyWith(intervalMs: v.round())),
        ),
        Text(
          '≈ ${(1000 / p.intervalMs).toStringAsFixed(1)} capturas por segundo',
          style: const TextStyle(color: kMuted, fontSize: 11),
        ),
        SliderRow(
          label: 'Cambio mínimo',
          value: p.minChangePercent,
          min: 0.1,
          max: 10,
          decimals: 1,
          suffix: ' %',
          onChanged: (double v) =>
              controller.setPipelineSettings(p.copyWith(minChangePercent: v)),
        ),
        const HelpText(
          'Cuánto tiene que cambiar la zona para volver a leerla. Bájalo si no '
          'detecta diálogos nuevos; súbelo si traduce de más en escenas con '
          'fondos animados.',
        ),
        SliderRow(
          label: 'Estabilidad',
          value: p.stabilityFrames.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          suffix: ' fot.',
          onChanged: (double v) => controller.setPipelineSettings(
            p.copyWith(stabilityFrames: v.round()),
          ),
        ),
        const HelpText(
          'Fotogramas con el mismo texto antes de traducir. Súbelo en juegos que '
          'escriben el diálogo letra a letra.',
        ),
        SliderRow(
          label: 'Permanencia',
          value: p.holdMs.toDouble(),
          min: 0,
          max: 10000,
          divisions: 40,
          suffix: ' ms',
          onChanged: (double v) =>
              controller.setPipelineSettings(p.copyWith(holdMs: v.round())),
        ),
        const HelpText(
          'Tiempo que el subtítulo sigue visible cuando el texto desaparece.',
        ),

        const SectionTitle('Preprocesado de imagen'),
        const HelpText(
          'Ajustar esto mejora la precisión del OCR más que cambiar de motor.',
        ),
        SliderRow(
          label: 'Escala',
          value: pre.scale,
          min: 1,
          max: 4,
          divisions: 12,
          decimals: 1,
          suffix: '×',
          onChanged: (double v) =>
              controller.setPreprocess(pre.copyWith(scale: v)),
        ),
        SliderRow(
          label: 'Contraste',
          value: pre.contrast,
          min: 0.5,
          max: 3,
          decimals: 2,
          onChanged: (double v) =>
              controller.setPreprocess(pre.copyWith(contrast: v)),
        ),
        SliderRow(
          label: 'Binarizar',
          value: pre.threshold.toDouble(),
          min: 0,
          max: 255,
          onChanged: (double v) =>
              controller.setPreprocess(pre.copyWith(threshold: v.round())),
        ),
        const HelpText(
          '0 = desactivado. Ayuda con texto plano sobre fondo plano; estorba en '
          'fondos complejos.',
        ),
        SwitchRow(
          label: 'Escala de grises',
          value: pre.grayscale,
          onChanged: (bool v) =>
              controller.setPreprocess(pre.copyWith(grayscale: v)),
        ),
        SwitchRow(
          label: 'Invertir',
          subtitle: 'Prueba a activarlo con texto claro sobre fondo oscuro.',
          value: pre.invert,
          onChanged: (bool v) =>
              controller.setPreprocess(pre.copyWith(invert: v)),
        ),
        SwitchRow(
          label: 'Reducir ruido',
          subtitle: 'Suaviza antes de leer. Útil con vídeo comprimido.',
          value: pre.denoise,
          onChanged: (bool v) =>
              controller.setPreprocess(pre.copyWith(denoise: v)),
        ),

        const SectionTitle('Tiempos de espera'),
        SliderRow(
          label: 'OCR',
          value: p.ocrTimeoutMs.toDouble(),
          min: 1000,
          max: 15000,
          divisions: 28,
          suffix: ' ms',
          onChanged: (double v) => controller.setPipelineSettings(
            p.copyWith(ocrTimeoutMs: v.round()),
          ),
        ),
        SliderRow(
          label: 'Traducción',
          value: p.translateTimeoutMs.toDouble(),
          min: 1000,
          max: 30000,
          divisions: 29,
          suffix: ' ms',
          onChanged: (double v) => controller.setPipelineSettings(
            p.copyWith(translateTimeoutMs: v.round()),
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------- pestaña Diagnóstico

class _DiagnosticsTab extends StatelessWidget {
  const _DiagnosticsTab({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final EngineHealth ocr = controller.ocrHealth;
    final EngineHealth translator = controller.translatorHealth;
    final TranslationPipeline? pipeline = controller.pipeline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ZoneConsole(controller: controller, zone: PanelZone.diagnostics),
        const SectionTitle('Estado de los motores'),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: controller.refreshEngineHealth,
                icon: const Icon(Icons.health_and_safety, size: 15),
                label: const Text('Comprobar'),
                style: _outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: controller.testOnce,
                icon: const Icon(Icons.play_circle_outline, size: 15),
                label: const Text('Probar ahora'),
                style: _outlined,
              ),
            ),
          ],
        ),
        _healthCard('OCR (Tesseract)', ocr),
        _healthCard('Traductor', translator),

        if (controller.installedOcrLanguages.isNotEmpty) ...<Widget>[
          const SectionTitle('Idiomas de OCR instalados'),
          Text(
            controller.installedOcrLanguages.join(', '),
            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
          ),
        ],

        const SectionTitle('Rutas'),
        const HelpText(
          'Traducy no necesita permisos de administrador: los paquetes de idioma '
          'se guardan en su propia carpeta, no en la de Tesseract.',
        ),
        DebouncedTextField(
          label: 'Ejecutable de Tesseract (vacío = autodetectar)',
          hint: r'C:\Program Files\Tesseract-OCR\tesseract.exe',
          initialValue: controller.settings.engines.tesseractPath,
          onSubmitted: (String v) => controller.setEngines(
            controller.settings.engines.copyWith(tesseractPath: v.trim()),
          ),
        ),
        DebouncedTextField(
          label: 'Carpeta de idiomas descargados (vacío = por defecto)',
          hint: controller.tessdataDirectory,
          initialValue: controller.settings.engines.tessdataDir,
          onSubmitted: controller.setTessdataDir,
        ),
        Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: const Color(0xFF15151A),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    AppPaths.instance.isBesideProgram
                        ? Icons.folder_special
                        : Icons.folder_shared,
                    size: 13,
                    color: kAccent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    AppPaths.instance.isBesideProgram
                        ? 'Todo junto al programa, donde lo instalaste'
                        : 'Todo en la carpeta del usuario',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _pathLine('Ajustes', AppPaths.instance.settingsFile.path),
              _pathLine('Idiomas', controller.tessdataDirectory),
              _pathLine('Versión', appVersion),
            ],
          ),
        ),
        if (controller.installedOcrLanguages.isNotEmpty ||
            controller.missingOcrLanguages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              controller.missingOcrLanguages.isEmpty
                  ? 'Todos los idiomas configurados están disponibles.'
                  : 'Pendientes de descargar: '
                        '${controller.missingOcrLanguages.join(', ')}',
              style: TextStyle(
                color: controller.missingOcrLanguages.isEmpty
                    ? kRegionAccent
                    : kSubtitleAccent,
                fontSize: 11,
              ),
            ),
          ),

        if (pipeline != null) ...<Widget>[
          const SectionTitle('Contadores'),
          ValueListenableBuilder<PipelineStatus>(
            valueListenable: pipeline.status,
            builder: (BuildContext context, PipelineStatus s, _) {
              return Column(
                children: <Widget>[
                  _statRow('Fotogramas', '${s.frames}'),
                  _statRow(
                    'Saltados sin cambios',
                    '${s.skippedUnchanged}'
                        '${s.frames > 0 ? '  (${(100 * s.skippedUnchanged / s.frames).round()}%)' : ''}',
                  ),
                  _statRow('Pasadas de OCR', '${s.ocrRuns}'),
                  _statRow('Traducciones', '${s.translations}'),
                  _statRow('Aciertos de caché', '${s.cacheHits}'),
                  const Divider(color: Color(0xFF3A3A44), height: 18),
                  _statRow('Captura', '${s.lastCaptureMs} ms'),
                  _statRow('Preprocesado', '${s.lastPrepMs} ms'),
                  _statRow('OCR', '${s.lastOcrMs} ms'),
                  _statRow('Traducción', '${s.lastTranslateMs} ms'),
                  if (s.detectedLanguage != null)
                    _statRow(
                      'Idioma detectado',
                      translateCodeLabel(s.detectedLanguage!),
                    ),
                ],
              );
            },
          ),
        ],

        const SectionTitle('Registro'),
        Container(
          height: 150,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF101014),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF2E2E38)),
          ),
          child: ValueListenableBuilder<int>(
            valueListenable: log.revision,
            builder: (BuildContext context, _, _) {
              final List<LogEntry> entries = log.entries.reversed
                  .take(120)
                  .toList();
              if (entries.isEmpty) {
                return const Center(
                  child: Text(
                    'Sin eventos',
                    style: TextStyle(color: kMuted, fontSize: 11),
                  ),
                );
              }
              return ListView.builder(
                itemCount: entries.length,
                itemBuilder: (BuildContext context, int index) {
                  final LogEntry entry = entries[index];
                  final Color color = switch (entry.level) {
                    LogLevel.error => kDanger,
                    LogLevel.warn => kSubtitleAccent,
                    LogLevel.info => Colors.white70,
                    LogLevel.debug => kMuted,
                  };
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Text(
                      '${entry.hhmmss} ${entry.tag}: ${entry.message}',
                      style: TextStyle(
                        color: color,
                        fontSize: 10.5,
                        fontFamily: 'Consolas',
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: log.clear,
          icon: const Icon(Icons.delete_outline, size: 15),
          label: const Text(
            'Limpiar registro',
            style: TextStyle(fontSize: 11.5),
          ),
        ),

        UpdateSection(
          controller: controller,
          onInstall: controller.onRequestUpdateInstall,
        ),

        const SectionTitle('Atajos de teclado'),
        _statRow('Ctrl + Alt + T', 'Mostrar / ocultar el panel'),
        _statRow('Ctrl + Alt + P', 'Pausar / reanudar la traducción'),
        _statRow('Ctrl + Alt + H', 'Ocultar / mostrar los subtítulos'),
      ],
    );
  }

  Widget _healthCard(String title, EngineHealth health) {
    if (health.checking) {
      return NoticeCard(
        message: '$title: comprobando…',
        severity: NoticeSeverity.info,
      );
    }
    if (health.issue != null) {
      return NoticeCard(
        message: '$title: ${health.issue}',
        severity: NoticeSeverity.error,
      );
    }
    if (health.isReady) {
      return NoticeCard(
        message: '$title: listo',
        severity: NoticeSeverity.success,
      );
    }
    return NoticeCard(
      message: '$title: sin comprobar',
      severity: NoticeSeverity.info,
    );
  }

  Widget _pathLine(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 54,
          child: Text(
            label,
            style: const TextStyle(color: kMuted, fontSize: 10.5),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(color: Colors.white70, fontSize: 10.5),
          ),
        ),
      ],
    ),
  );

  Widget _statRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: kMuted, fontSize: 11.5),
          ),
        ),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 11.5),
        ),
      ],
    ),
  );
}

// ------------------------------------------------------------------ estilos

final ButtonStyle _outlined = OutlinedButton.styleFrom(
  foregroundColor: kAccent,
  side: const BorderSide(color: Color(0xFF3A3A44)),
  padding: const EdgeInsets.symmetric(vertical: 10),
  textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
);

InputDecoration _dropdownDecoration(String label) => InputDecoration(
  labelText: label,
  labelStyle: const TextStyle(color: kMuted, fontSize: 12),
  isDense: true,
  filled: true,
  fillColor: const Color(0xFF1A1A20),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(6),
    borderSide: const BorderSide(color: Color(0xFF3A3A44)),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(6),
    borderSide: const BorderSide(color: Color(0xFF3A3A44)),
  ),
);
