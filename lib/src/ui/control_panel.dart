import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/app_paths.dart';
import 'toasts.dart';
import '../core/logx.dart';
import '../core/version.dart';
import '../models/languages.dart';
import '../i18n/strings.dart';
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

          // Tiradores de los cuatro lados y las cuatro esquinas, todos dentro de
          // los límites del panel: un widget pintado fuera de su padre no recibe
          // clics en Flutter, así que un tirador "por fuera" del borde no
          // funcionaría.
          //
          // Van después del panel en el Stack para quedar por encima de su
          // contenido; si no, los controles del borde se comerían el arrastre.
          _edge(top: true),
          _edge(bottom: true),
          _edge(left: true),
          _edge(right: true),
          _edge(top: true, left: true),
          _edge(top: true, right: true),
          _edge(bottom: true, left: true),
          _edge(bottom: true, right: true),

          // La esquina inferior derecha lleva además su marca visible, que es lo
          // que hace evidente que el panel se puede redimensionar.
          Positioned(
            right: 0,
            bottom: 0,
            child: _ResizeGrip(
              onDelta: (Offset delta) => c.resizePanelFromEdge(
                delta: delta,
                left: false,
                top: false,
                right: true,
                bottom: true,
              ),
              onReset: c.resetPanelSize,
            ),
          ),
        ],
      ),
    );
  }

  /// Grosor de la banda sensible de cada borde.
  ///
  /// 7 px es suficiente para acertar con el ratón sin pensar y poco para robarle
  /// clics al contenido que hay justo dentro.
  static const double _edgeBand = 7;

  /// Zona de arrastre de un borde o de una esquina.
  ///
  /// Se indica con banderas en lugar de con un enum de nueve valores porque es lo
  /// que consume `resizePanelFromEdge`: qué bordes se mueven. Una esquina es
  /// simplemente dos bordes a la vez.
  Widget _edge({
    bool left = false,
    bool top = false,
    bool right = false,
    bool bottom = false,
  }) {
    final bool horizontal = left || right;
    final bool vertical = top || bottom;
    final bool corner = horizontal && vertical;

    final MouseCursor cursor = corner
        ? ((left && top) || (right && bottom)
              ? SystemMouseCursors.resizeUpLeftDownRight
              : SystemMouseCursors.resizeUpRightDownLeft)
        : (horizontal
              ? SystemMouseCursors.resizeLeftRight
              : SystemMouseCursors.resizeUpDown);

    // En las esquinas la zona sensible es un cuadrado algo mayor: acertar en la
    // intersección de dos bandas de 7 px sería un ejercicio de puntería.
    final double thickness = corner ? _edgeBand * 2.4 : _edgeBand;

    return Positioned(
      left: left || !horizontal ? 0 : null,
      right: right || !horizontal ? 0 : null,
      top: top || !vertical ? 0 : null,
      bottom: bottom || !vertical ? 0 : null,
      width: horizontal ? thickness : null,
      height: vertical ? thickness : null,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanUpdate: (DragUpdateDetails details) => c.resizePanelFromEdge(
            delta: details.delta,
            left: left,
            top: top,
            right: right,
            bottom: bottom,
          ),
          // Doble clic en cualquier borde devuelve el tamaño de fábrica: es la
          // salida cuando el panel queda demasiado pequeño o demasiado grande.
          onDoubleTap: c.resetPanelSize,
        ),
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
            tabs: <Tab>[
              Tab(text: t.tabRegion),
              Tab(text: t.tabLanguages),
              Tab(text: t.tabStyle),
              Tab(text: t.tabPerformance),
              Tab(text: t.tabDiagnostics),
              Tab(text: t.tabAbout),
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
          message: t.panel.resizeHint,
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
                    tooltip: t.minimizeTooltip,
                    icon: const Icon(Icons.remove, size: 18),
                    color: kMuted,
                    onPressed: () => controller.minimizeOverlay(),
                  ),
                  IconButton(
                    tooltip: t.gameModeTooltip,
                    icon: const Icon(Icons.visibility_off, size: 18),
                    color: kMuted,
                    onPressed: () => controller.sendToBackground(),
                  ),
                  IconButton(
                    tooltip: t.exitTooltip,
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
                          ? t.panel.pause
                          : t.panel.translate,
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
                child: Text(
                  t.panel.understood,
                  style: const TextStyle(fontSize: 11.5),
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
                            t.panel.stepNumber(i + 1, steps[i].title),
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
    final bool usingWindows = c.settings.engines.ocrKind == OcrKind.windows;
    final bool engineMissing =
        c.ocrHealth.hasProblem && c.missingOcrLanguages.isEmpty;
    // Descargar paquetes es cosa de Tesseract. Con el motor de Windows este paso
    // no existe, y dejarlo decia "falta el idioma" sobre algo que no se usa.
    final bool languageMissing =
        !usingWindows && c.missingOcrLanguages.isNotEmpty;
    final bool regionReady = c.resolveCaptureRegion().isValid;
    final bool running = c.pipeline?.isRunning ?? false;
    final String missingFirst = c.missingOcrLanguages.isEmpty
        ? ''
        : c.missingOcrLanguages.first;

    return <_Step>[
      if (usingWindows)
        _Step(
          title: t.panel.stepWindowsOcrTitle,
          done: !engineMissing,
          problem: c.ocrHealth.issue ?? t.panel.stepWindowsOcrProblem,
          hint: t.panel.stepWindowsOcrHint,
          action: _ActionButton(
            label: t.panel.useTesseract,
            icon: Icons.swap_horiz,
            onPressed: () => c.setOcrKind(OcrKind.tesseract),
            secondaryLabel: t.panel.checkAgain,
            onSecondary: c.refreshEngineHealth,
          ),
        )
      else
        _Step(
          title: t.panel.stepTesseractTitle,
          done: !engineMissing,
          problem: t.panel.stepTesseractProblem,
          hint: t.panel.stepTesseractHint,
          action: _ActionButton(
            label: t.panel.installTesseract,
            icon: Icons.download,
            onPressed: c.installTesseract,
            secondaryLabel: t.panel.useWindowsOcr,
            onSecondary: () => c.setOcrKind(OcrKind.windows),
          ),
        ),
      if (!usingWindows)
        _Step(
          title: t.panel.stepLanguageTitle,
          done: !languageMissing,
          problem: t.panel.stepLanguageProblem(missingFirst),
          hint: t.panel.stepLanguageHint,
          action: c.download != null
              ? _DownloadProgressBar(progress: c.download!)
              : _ActionButton(
                  label: t.panel.downloadLanguage(missingFirst),
                  icon: Icons.language,
                  onPressed: () {
                    if (missingFirst.isNotEmpty) {
                      c.installOcrLanguage(missingFirst);
                    }
                  },
                ),
        ),
      _Step(
        title: t.panel.stepRegionTitle,
        done: regionReady,
        problem: t.panel.stepRegionProblem,
        hint: t.panel.stepRegionHint,
        action: _ActionButton(
          label: t.panel.useBottomBand,
          icon: Icons.subtitles,
          onPressed: () {
            c.setRegionToBottomBand();
            c.setEditRegion(true);
          },
        ),
      ),
      _Step(
        title: t.panel.stepRunTitle,
        done: running,
        problem: t.panel.stepRunProblem,
        hint: t.panel.stepRunHint,
        action: _ActionButton(
          label: t.panel.translateNow,
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
        PressableScale(
          child: FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 15),
            label: Text(label),
            style:
                FilledButton.styleFrom(
                  backgroundColor: kAccent,
                  foregroundColor: const Color(0xFF11131A),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ).copyWith(
                  // Al pasar el ratón se aclara un poco: deja claro cuál es el botón
                  // principal de cada paso sin necesidad de leerlo.
                  overlayColor: const WidgetStatePropertyAll<Color>(
                    Color(0x1A11131A),
                  ),
                ),
          ),
        ),
        if (secondaryLabel != null && onSecondary != null) ...<Widget>[
          const SizedBox(width: 8),
          PressableScale(
            child: TextButton(
              onPressed: onSecondary,
              child: Text(
                secondaryLabel!,
                style: const TextStyle(fontSize: 11.5),
              ),
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
          t.panel.downloadingLanguage(progress.language, progress.readable),
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
        SectionTitle(t.panel.activateSection),
        HelpText(t.panel.activateHelp),
        _EditToggle(
          label: t.panel.activateRegionLabel,
          description: t.panel.activateRegionDescription,
          color: kRegionAccent,
          value: s.editRegion,
          onChanged: controller.setEditRegion,
        ),
        _EditToggle(
          label: t.panel.activateSubtitleLabel,
          description: t.panel.activateSubtitleDescription,
          color: kSubtitleAccent,
          value: s.editSubtitleBox,
          onChanged: controller.setEditSubtitleBox,
        ),

        SectionTitle(t.panel.captureZoneSection),
        HelpText(t.panel.captureZoneHelp),
        SizedBox(
          width: double.infinity,
          child: PressableScale(
            child: FilledButton.icon(
              onPressed: () => controller.detectGameWindow(),
              icon: const Icon(Icons.videogame_asset, size: 16),
              label: Text(t.panel.detectGame),
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
        ),
        if (s.regionMode == RegionMode.followWindow &&
            s.followWindowTitle.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: <Widget>[
                Icon(
                  controller.followConnected ? Icons.link : Icons.link_off,
                  size: 13,
                  color: controller.followConnected
                      ? kRegionAccent
                      : kSubtitleAccent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    controller.followConnected
                        ? t.panel.anchoredTo(s.followWindowTitle)
                        : t.panel.waitingFor(s.followWindowTitle),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: controller.followConnected
                          ? kRegionAccent
                          : kSubtitleAccent,
                      fontSize: 11,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: controller.stopFollowingWindow,
                  style: TextButton.styleFrom(
                    foregroundColor: kMuted,
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                  child: Text(t.panel.unanchor),
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
                label: Text(t.panel.bottomBand),
                style: _outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: controller.setRegionToFullScreen,
                icon: const Icon(Icons.fullscreen, size: 15),
                label: Text(t.panel.fullScreen),
                style: _outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchRow(
          label: t.panel.regionLockedLabel,
          subtitle: s.regionLocked
              ? t.panel.regionLockedOn
              : t.panel.regionLockedOff,
          value: s.regionLocked,
          onChanged: (bool v) => controller.setRegionLocked(v),
        ),
        SwitchRow(
          label: t.panel.subtitleLockedLabel,
          subtitle: t.panel.subtitleLockedSubtitle,
          value: s.subtitleLocked,
          onChanged: (bool v) => controller.setSubtitleLocked(v),
        ),
        _LiveMetrics(
          title: t.panel.metricsRegionTitle,
          accent: kRegionAccent,
          preview: controller.regionPreview,
          fallback: region,
          toRegion: controller.logicalRectToRegion,
        ),
        _LiveMetrics(
          title: t.panel.metricsSubtitleTitle,
          accent: kSubtitleAccent,
          preview: controller.subtitlePreview,
          fallback: CaptureRegion(
            left: s.subtitleBox.left.round(),
            top: s.subtitleBox.top.round(),
            width: s.subtitleBox.width.round(),
            height: s.subtitleBox.height.round(),
          ),
          toRegion: (Rect rect) => CaptureRegion(
            left: rect.left.round(),
            top: rect.top.round(),
            width: rect.width.round(),
            height: rect.height.round(),
          ),
        ),
        if (!region.isValid)
          NoticeCard(
            message: t.panel.zoneTooSmall,
            hint: t.panel.zoneTooSmallHint,
            severity: NoticeSeverity.warning,
          ),

        SectionTitle(t.panel.followWindowSection),
        HelpText(t.panel.followWindowHelp),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                s.regionMode == RegionMode.followWindow
                    ? t.panel.followingWindow(s.followWindowTitle)
                    : t.panel.fixedZone,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            IconButton(
              tooltip: t.panel.refreshWindowList,
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
            label: Text(t.panel.stopFollowing),
            style: _outlined,
          ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 160),
          child: controller.availableWindows.isEmpty
              ? HelpText(t.panel.pressRefreshToList)
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
                        child: Text(
                          t.panel.follow,
                          style: const TextStyle(fontSize: 11.5),
                        ),
                      ),
                    );
                  },
                ),
        ),

        SectionTitle(t.panel.overlayWindowSection),
        if (controller.isExcludedFromCapture)
          NoticeCard(
            message: t.panel.overlayExcluded,
            hint: t.panel.overlayExcludedHint,
            severity: NoticeSeverity.success,
          )
        else
          NoticeCard(
            message: t.panel.overlayNotExcluded,
            hint: t.panel.overlayNotExcludedHint,
            severity: NoticeSeverity.warning,
          ),
        if (controller.subtitleOverlapsRegion)
          NoticeCard(
            message: t.panel.subtitleOverlaps,
            hint: t.panel.subtitleOverlapsHint,
            severity: NoticeSeverity.error,
          ),
        SwitchRow(
          label: t.panel.startInConfigLabel,
          subtitle: t.panel.startInConfigSubtitle,
          value: controller.settings.startInConfigMode,
          onChanged: controller.setStartInConfigMode,
        ),
        SwitchRow(
          label: t.panel.playWithPanelLabel,
          subtitle: t.panel.playWithPanelSubtitle,
          value: controller.settings.passthroughInConfig,
          onChanged: controller.setPassthroughInConfig,
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

/// Medidas que se actualizan **mientras** se arrastra.
///
/// Escucha el rectangulo de arrastre en lugar de esperar a que se suelte. Antes
/// mostraba el valor guardado, que durante el arrastre es el de antes de empezar:
/// numeros que no corresponden con lo que se esta viendo en pantalla. Un dato que
/// miente es peor que no tenerlo.
///
/// Escuchando solo aqui, el resto del panel no se reconstruye a cada movimiento
/// del raton, que es lo que hacia el arrastre lento.
class _LiveMetrics extends StatelessWidget {
  const _LiveMetrics({
    required this.title,
    required this.accent,
    required this.preview,
    required this.fallback,
    required this.toRegion,
  });

  final String title;
  final Color accent;

  /// Rectangulo en curso, en pixeles logicos, o `null` si no se esta arrastrando.
  final ValueListenable<Rect?> preview;

  /// Lo que se muestra cuando no hay arrastre: el valor guardado.
  final CaptureRegion fallback;

  /// Conversion del rectangulo logico a las unidades que se muestran.
  final CaptureRegion Function(Rect rect) toRegion;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: kControlSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              color: accent,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<Rect?>(
            valueListenable: preview,
            builder: (BuildContext context, Rect? live, _) {
              final CaptureRegion shown = live == null
                  ? fallback
                  : toRegion(live);
              return Row(
                children: <Widget>[
                  _MetricChip(label: t.panel.metricX, value: '${shown.left}'),
                  _MetricChip(label: t.panel.metricY, value: '${shown.top}'),
                  _MetricChip(
                    label: t.panel.metricWidth,
                    value: '${shown.width}',
                  ),
                  _MetricChip(
                    label: t.panel.metricHeight,
                    value: '${shown.height}',
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

        SectionTitle(t.uiLanguageSection),
        HelpText(t.uiLanguageHelp),
        SegmentedButton<UiLanguage>(
          segments: <ButtonSegment<UiLanguage>>[
            ButtonSegment<UiLanguage>(
              value: UiLanguage.auto,
              label: Text(t.uiLanguageAuto),
            ),
            ButtonSegment<UiLanguage>(
              value: UiLanguage.spanish,
              label: Text(t.uiLanguageSpanish),
            ),
            ButtonSegment<UiLanguage>(
              value: UiLanguage.english,
              label: Text(t.uiLanguageEnglish),
            ),
          ],
          selected: <UiLanguage>{controller.settings.uiLanguage},
          onSelectionChanged: (Set<UiLanguage> value) =>
              controller.setUiLanguage(value.first),
          style: ButtonStyle(
            textStyle: const WidgetStatePropertyAll<TextStyle>(
              TextStyle(fontSize: 11.5),
            ),
            visualDensity: VisualDensity.compact,
          ),
        ),

        SectionTitle(t.panel.ocrEngineSection),
        HelpText(t.panel.ocrEngineHelp),
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
                        ? t.panel.windowsRecognizes(
                            controller.windowsOcrLanguages.join(', '),
                          )
                        : t.panel.windowsMissingLanguage,
                    style: TextStyle(
                      color: controller.windowsOcrCoversRequest
                          ? kMuted
                          : kSubtitleAccent,
                      fontSize: 10.5,
                      height: 1.35,
                    ),
                  )
                : Text(
                    t.panel.checkEnginesFirst,
                    style: const TextStyle(
                      color: kMuted,
                      fontSize: 10.5,
                      height: 1.35,
                    ),
                  ),
          ),

        SectionTitle(t.panel.gameLanguageSection),
        HelpText(t.panel.gameLanguageHelp),
        DropdownButtonFormField<String>(
          initialValue: ocrLanguage?.ocrCode,
          isExpanded: true,
          dropdownColor: kPanelSurface,
          decoration: _dropdownDecoration(t.panel.scriptToRecognize),
          style: const TextStyle(color: Colors.white, fontSize: 12.5),
          items: <DropdownMenuItem<String>>[
            for (final LanguageOption option in sourceLanguages)
              DropdownMenuItem<String>(
                value: option.ocrCode,
                child: Text(
                  '${option.label}  ·  ${option.ocrCode}'
                  // El aviso de "no instalado" es cosa de Tesseract: el motor de
                  // Windows no usa estos paquetes y marcarlos ahi confundiria.
                  '${e.ocrKind == OcrKind.tesseract && controller.installedOcrLanguages.isNotEmpty && !controller.installedOcrLanguages.contains(option.ocrCode) ? t.panel.notInstalledSuffix : ''}',
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
          label: t.panel.autoDetectLabel,
          subtitle: autoDetect
              ? t.panel.autoDetectOn
              : t.panel.autoDetectOff(e.sourceLanguage),
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

        SectionTitle(t.panel.translateToSection),
        DropdownButtonFormField<String>(
          initialValue:
              targetByTranslateCode(e.targetLanguage)?.translateCode ?? 'es',
          isExpanded: true,
          dropdownColor: kPanelSurface,
          decoration: _dropdownDecoration(t.panel.targetLanguageLabel),
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

        SectionTitle(t.panel.translatorSection),
        DropdownButtonFormField<TranslatorKind>(
          initialValue: e.translator,
          isExpanded: true,
          dropdownColor: kPanelSurface,
          decoration: _dropdownDecoration(t.panel.translatorLabel),
          style: const TextStyle(color: Colors.white, fontSize: 12.5),
          items: <DropdownMenuItem<TranslatorKind>>[
            DropdownMenuItem<TranslatorKind>(
              value: TranslatorKind.googleFree,
              child: Text(t.panel.translatorGoogle),
            ),
            DropdownMenuItem<TranslatorKind>(
              value: TranslatorKind.claude,
              child: Text(t.panel.translatorClaude),
            ),
            DropdownMenuItem<TranslatorKind>(
              value: TranslatorKind.deepl,
              child: Text(t.panel.translatorDeepl),
            ),
            DropdownMenuItem<TranslatorKind>(
              value: TranslatorKind.libre,
              child: Text(t.panel.translatorLibre),
            ),
            DropdownMenuItem<TranslatorKind>(
              value: TranslatorKind.none,
              child: Text(t.panel.translatorNone),
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
            label: t.panel.claudeKeyLabel,
            hint: 'sk-ant-...',
            initialValue: e.claudeKey,
            obscure: true,
            onSubmitted: (String v) =>
                controller.setEngines(e.copyWith(claudeKey: v.trim())),
          ),
          DebouncedTextField(
            label: t.panel.modelLabel,
            initialValue: e.claudeModel,
            onSubmitted: (String v) => controller.setEngines(
              e.copyWith(
                claudeModel: v.trim().isEmpty ? 'claude-opus-5' : v.trim(),
              ),
            ),
          ),
          HelpText(t.panel.claudeHelp),
        ],
        if (e.translator == TranslatorKind.deepl)
          DebouncedTextField(
            label: t.panel.deeplKeyLabel,
            hint: t.panel.deeplKeyHint,
            initialValue: e.deeplKey,
            obscure: true,
            onSubmitted: (String v) =>
                controller.setEngines(e.copyWith(deeplKey: v.trim())),
          ),
        if (e.translator == TranslatorKind.libre)
          DebouncedTextField(
            label: t.panel.libreUrlLabel,
            hint: 'http://localhost:5000',
            initialValue: e.libreTranslateUrl,
            onSubmitted: (String v) =>
                controller.setEngines(e.copyWith(libreTranslateUrl: v.trim())),
          ),

        SectionTitle(t.panel.glossarySection),
        HelpText(t.panel.glossaryHelp),
        DebouncedTextField(
          label: t.panel.glossaryLabel,
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
        SectionTitle(t.panel.textSection),
        SliderRow(
          label: t.panel.fontSizeLabel,
          value: st.fontSize,
          min: 12,
          max: 84,
          onChanged: (double v) => update(st.copyWith(fontSize: v)),
          suffix: ' px',
        ),
        SliderRow(
          label: t.panel.lineHeightLabel,
          value: st.lineHeight,
          min: 0.9,
          max: 2.2,
          decimals: 2,
          onChanged: (double v) => update(st.copyWith(lineHeight: v)),
        ),
        SliderRow(
          label: t.panel.letterSpacingLabel,
          value: st.letterSpacing,
          min: -1,
          max: 6,
          decimals: 1,
          onChanged: (double v) => update(st.copyWith(letterSpacing: v)),
        ),
        SliderRow(
          label: t.panel.maxLinesLabel,
          value: st.maxLines.toDouble(),
          min: 1,
          max: 10,
          divisions: 9,
          onChanged: (double v) => update(st.copyWith(maxLines: v.round())),
        ),
        SwitchRow(
          label: t.panel.historyLabel,
          subtitle: st.showHistory ? t.panel.historyOn : t.panel.historyOff,
          value: st.showHistory,
          onChanged: (bool v) => update(st.copyWith(showHistory: v)),
        ),
        if (st.showHistory)
          SliderRow(
            label: t.panel.rememberedLinesLabel,
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
              label: Text(t.panel.clearHistory),
              style: _outlined,
            ),
          ),
        SwitchRow(
          label: t.panel.autoFitLabel,
          subtitle: st.autoFit ? t.panel.autoFitOn : t.panel.autoFitOff,
          value: st.autoFit,
          onChanged: (bool v) => update(st.copyWith(autoFit: v)),
        ),
        if (st.autoFit)
          SliderRow(
            label: t.panel.minShrinkLabel,
            value: st.minFontScale * 100,
            min: 30,
            max: 100,
            decimals: 0,
            suffix: ' %',
            onChanged: (double v) => update(st.copyWith(minFontScale: v / 100)),
          ),
        if (st.autoFit) HelpText(t.panel.minShrinkHelp),
        Row(
          children: <Widget>[
            Expanded(
              child: SwitchRow(
                label: t.panel.boldLabel,
                value: st.bold,
                onChanged: (bool v) => update(st.copyWith(bold: v)),
              ),
            ),
            Expanded(
              child: SwitchRow(
                label: t.panel.italicLabel,
                value: st.italic,
                onChanged: (bool v) => update(st.copyWith(italic: v)),
              ),
            ),
          ],
        ),
        DebouncedTextField(
          label: t.panel.fontLabel,
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

        SectionTitle(t.panel.readabilitySection),
        HelpText(t.panel.readabilityHelp),
        SliderRow(
          label: t.panel.outlineWidthLabel,
          value: st.outlineWidth,
          min: 0,
          max: 10,
          decimals: 1,
          onChanged: (double v) => update(st.copyWith(outlineWidth: v)),
        ),
        SliderRow(
          label: t.panel.backgroundOpacityLabel,
          value: st.backgroundOpacity,
          min: 0,
          max: 1,
          decimals: 2,
          onChanged: (double v) => update(st.copyWith(backgroundOpacity: v)),
        ),
        SliderRow(
          label: t.panel.cornerRadiusLabel,
          value: st.cornerRadius,
          min: 0,
          max: 32,
          onChanged: (double v) => update(st.copyWith(cornerRadius: v)),
        ),
        SliderRow(
          label: t.panel.paddingLabel,
          value: st.padding,
          min: 0,
          max: 40,
          onChanged: (double v) => update(st.copyWith(padding: v)),
        ),
        SwitchRow(
          label: t.panel.shadowLabel,
          value: st.shadow,
          onChanged: (bool v) => update(st.copyWith(shadow: v)),
        ),
        SwitchRow(
          label: t.panel.showOriginalLabel,
          subtitle: t.panel.showOriginalSubtitle,
          value: st.showOriginal,
          onChanged: (bool v) => update(st.copyWith(showOriginal: v)),
        ),

        SectionTitle(t.panel.colorsSection),
        ColorPickerRow(
          label: t.panel.textColorLabel,
          color: st.textColor,
          onChanged: (Color c) => update(st.copyWith(textColor: c)),
        ),
        ColorPickerRow(
          label: t.panel.outlineColorLabel,
          color: st.outlineColor,
          onChanged: (Color c) => update(st.copyWith(outlineColor: c)),
        ),
        ColorPickerRow(
          label: t.panel.backgroundColorLabel,
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
        SectionTitle(t.panel.frequencySection),
        HelpText(t.panel.frequencyHelp),
        SliderRow(
          label: t.panel.intervalLabel,
          value: p.intervalMs.toDouble(),
          min: 150,
          max: 2000,
          divisions: 37,
          suffix: ' ms',
          onChanged: (double v) =>
              controller.setPipelineSettings(p.copyWith(intervalMs: v.round())),
        ),
        Text(
          t.panel.capturesPerSecond((1000 / p.intervalMs).toStringAsFixed(1)),
          style: const TextStyle(color: kMuted, fontSize: 11),
        ),
        SliderRow(
          label: t.panel.minChangeLabel,
          value: p.minChangePercent,
          min: 0.1,
          max: 10,
          decimals: 1,
          suffix: ' %',
          onChanged: (double v) =>
              controller.setPipelineSettings(p.copyWith(minChangePercent: v)),
        ),
        HelpText(t.panel.minChangeHelp),
        SliderRow(
          label: t.panel.stabilityLabel,
          value: p.stabilityFrames.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          suffix: t.panel.stabilityFramesSuffix,
          onChanged: (double v) => controller.setPipelineSettings(
            p.copyWith(stabilityFrames: v.round()),
          ),
        ),
        const HelpText(
          'Fotogramas con el mismo texto antes de traducir. Súbelo en juegos que '
          'escriben el diálogo letra a letra.',
        ),
        SliderRow(
          label: t.panel.holdLabel,
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
          label: t.panel.scaleLabel,
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
          label: t.panel.contrastLabel,
          value: pre.contrast,
          min: 0.5,
          max: 3,
          decimals: 2,
          onChanged: (double v) =>
              controller.setPreprocess(pre.copyWith(contrast: v)),
        ),
        SliderRow(
          label: t.panel.binarizeLabel,
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
          label: t.panel.grayscaleLabel,
          value: pre.grayscale,
          onChanged: (bool v) =>
              controller.setPreprocess(pre.copyWith(grayscale: v)),
        ),
        SwitchRow(
          label: t.panel.invertLabel,
          subtitle: 'Prueba a activarlo con texto claro sobre fondo oscuro.',
          value: pre.invert,
          onChanged: (bool v) =>
              controller.setPreprocess(pre.copyWith(invert: v)),
        ),
        SwitchRow(
          label: t.panel.denoiseLabel,
          subtitle: 'Suaviza antes de leer. Útil con vídeo comprimido.',
          value: pre.denoise,
          onChanged: (bool v) =>
              controller.setPreprocess(pre.copyWith(denoise: v)),
        ),

        SectionTitle(t.panel.timeoutsSection),
        SliderRow(
          label: t.panel.ocrLabel,
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
          label: t.panel.translationLabel,
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
        SectionTitle(t.panel.enginesSection),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: controller.refreshEngineHealth,
                icon: const Icon(Icons.health_and_safety, size: 15),
                label: Text(t.panel.check),
                style: _outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: controller.testOnce,
                icon: const Icon(Icons.play_circle_outline, size: 15),
                label: Text(t.panel.testNow),
                style: _outlined,
              ),
            ),
          ],
        ),
        _healthCard(
          controller.settings.engines.ocrKind == OcrKind.windows
              ? t.panel.ocrEngineWindowsName
              : t.panel.ocrEngineTesseractName,
          ocr,
        ),
        _healthCard('Traductor', translator),

        if (controller.installedOcrLanguages.isNotEmpty) ...<Widget>[
          const SectionTitle('Idiomas de OCR instalados'),
          Text(
            controller.installedOcrLanguages.join(', '),
            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
          ),
        ],

        SectionTitle(t.panel.pathsSection),
        const HelpText(
          'Traducy no necesita permisos de administrador: los paquetes de idioma '
          'se guardan en su propia carpeta, no en la de Tesseract.',
        ),
        DebouncedTextField(
          label: t.panel.tesseractExeLabel,
          hint: t.panel.tesseractExeHint,
          initialValue: controller.settings.engines.tesseractPath,
          onSubmitted: (String v) => controller.setEngines(
            controller.settings.engines.copyWith(tesseractPath: v.trim()),
          ),
        ),
        DebouncedTextField(
          label: t.panel.tessdataFolderLabel,
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

        SectionTitle(t.panel.logSection),
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
          label: Text(t.panel.clearLog, style: const TextStyle(fontSize: 11.5)),
        ),

        UpdateSection(
          controller: controller,
          onInstall: controller.onRequestUpdateInstall,
        ),

        SectionTitle(t.panel.shortcutsSection),
        _statRow('Ctrl + Alt + T', 'Mostrar / ocultar el panel'),
        _statRow('Ctrl + Alt + P', 'Pausar / reanudar la traducción'),
        _statRow('Ctrl + Alt + H', 'Ocultar / mostrar los subtítulos'),
      ],
    );
  }

  Widget _healthCard(String title, EngineHealth health) {
    if (health.checking) {
      return NoticeCard(
        message: t.panel.healthChecking(title),
        severity: NoticeSeverity.info,
      );
    }
    final String? issue = health.issue;
    if (issue != null) {
      return NoticeCard(
        message: t.panel.healthIssue(title, issue),
        severity: NoticeSeverity.error,
      );
    }
    if (health.isReady) {
      return NoticeCard(
        message: t.panel.healthReady(title),
        severity: NoticeSeverity.success,
      );
    }
    return NoticeCard(
      message: t.panel.healthUnchecked(title),
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
