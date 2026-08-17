import 'package:flutter/material.dart';

import '../core/updater.dart';
import '../i18n/strings.dart';
import '../state/app_controller.dart';
import 'widgets_common.dart';

/// Bloque de actualizaciones dentro de la pestaña Diagnóstico.
class UpdateSection extends StatelessWidget {
  const UpdateSection({
    super.key,
    required this.controller,
    required this.onInstall,
  });

  final AppController controller;

  /// Se llama al confirmar la instalación. El cierre ordenado de la aplicación
  /// vive en `main.dart`, no aquí.
  final Future<void> Function() onInstall;

  @override
  Widget build(BuildContext context) {
    final UpdateState state = controller.updateState;
    final ReleaseInfo? release = state.release;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionTitle(t.updates),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                t.installedVersion(controller.currentVersion),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            PressableScale(
              child: OutlinedButton.icon(
                onPressed: state.isBusy
                    ? null
                    : () => controller.checkForUpdate(),
                icon: const Icon(Icons.system_update_alt, size: 15),
                label: Text(t.checkNow),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kAccent,
                  side: const BorderSide(color: Color(0xFF3A3A44)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        HelpText(t.updateBlockExplanation),
        SwitchRow(
          label: t.autoUpdateLabel,
          subtitle: controller.settings.autoUpdate
              ? t.autoUpdateOn
              : t.autoUpdateOff,
          value: controller.settings.autoUpdate,
          onChanged: controller.setAutoUpdate,
        ),

        if (state.stage == UpdateStage.checking)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: LinearProgressIndicator(
              minHeight: 3,
              color: kAccent,
              backgroundColor: Color(0xFF2E2E38),
            ),
          ),

        if (state.stage == UpdateStage.available && release != null)
          NoticeCard(
            message: t.updateAvailable(release.version),
            hint: t.updateAvailableHint(release.readableSize),
            severity: NoticeSeverity.warning,
            action: PressableScale(
              child: FilledButton.icon(
                onPressed: onInstall,
                icon: const Icon(Icons.download, size: 15),
                label: Text(t.updateToVersion(release.version)),
                style: FilledButton.styleFrom(
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
                ),
              ),
            ),
          ),

        if (state.stage == UpdateStage.failed)
          NoticeCard(
            message: state.message,
            hint: t.updateManualFrom(controller.releasesPageUrl),
            severity: NoticeSeverity.error,
          ),

        if (state.stage == UpdateStage.idle && state.message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              state.message,
              style: const TextStyle(color: kRegionAccent, fontSize: 11.5),
            ),
          ),
      ],
    );
  }
}

/// Aviso que bloquea el trabajo mientras hay una actualización pendiente.
///
/// Vive **dentro del panel de control**, en su sitio y con su ancho. Antes cubría
/// la pantalla entera: además de tapar el escritorio, el botón de actualizar no
/// se podía pulsar, porque el overlay solo entrega el ratón en los rectángulos
/// que publica y ese cartel no era uno de ellos. Ocupando el hueco del panel, el
/// rectángulo ya está publicado y el botón responde.
///
/// Bloquea a propósito, y en las cuatro fases: mientras se espera la decisión,
/// durante la descarga, al lanzar el instalador y si algo falla. Una versión
/// vieja funcionando a medias parece un fallo de la aplicación, y durante la
/// instalación el ejecutable en marcha va a ser sustituido.
///
/// Siempre ofrece **Salir**: si la descarga falla por red, nadie debe quedarse
/// encerrado sin forma de cerrar el programa.
class UpdateBlockingScreen extends StatelessWidget {
  const UpdateBlockingScreen({
    super.key,
    required this.state,
    required this.onInstall,
    required this.onRetry,
    required this.onExit,
    required this.releasesPageUrl,
    required this.width,
    required this.automatic,
  });

  /// Ancho del panel, para ocupar exactamente su hueco.
  final double width;

  /// `true` si la actualización va sola. Cambia el texto: no hay nada que
  /// pulsar, así que prometer un botón sería mentir.
  final bool automatic;

  final UpdateState state;
  final Future<void> Function() onInstall;
  final Future<void> Function() onRetry;
  final VoidCallback onExit;
  final String releasesPageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
      decoration: BoxDecoration(
        color: kPanelBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF3A3A44)),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x99000000), blurRadius: 26),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Image.asset(
            'assets/logo_mark.png',
            width: 46,
            height: 46,
            filterQuality: FilterQuality.high,
          ),
          const SizedBox(height: 14),
          ..._body(),
        ],
      ),
    );
  }

  List<Widget> _body() {
    final ReleaseInfo? release = state.release;

    switch (state.stage) {
      case UpdateStage.available:
        if (automatic) {
          return <Widget>[
            _title(t.updateRequiredTitle),
            const SizedBox(height: 10),
            _text(t.updateRequiredBody(release?.version ?? '')),
            const SizedBox(height: 16),
            const LinearProgressIndicator(
              minHeight: 3,
              color: kAccent,
              backgroundColor: Color(0xFF2E2E38),
            ),
            const SizedBox(height: 12),
            _text(t.updateAutomaticNotice, muted: true),
            const SizedBox(height: 14),
            _actions(<Widget>[_secondary(t.exit, onExit)]),
          ];
        }
        return <Widget>[
          _title(t.updateRequiredTitle),
          const SizedBox(height: 10),
          _text(t.updateRequiredBody(release?.version ?? '')),
          const SizedBox(height: 8),
          _text(
            t.updateRequiredDetail(release?.readableSize ?? ''),
            muted: true,
          ),
          const SizedBox(height: 18),
          _actions(<Widget>[
            _primary(t.updateNow, Icons.download, onInstall),
            _secondary(t.exit, onExit),
          ]),
        ];

      case UpdateStage.downloading:
        return <Widget>[
          _title(t.downloadingVersion(release?.version ?? '')),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            // Sin tamaño conocido, indeterminada: una barra clavada en cero
            // parece que se ha colgado.
            value: state.totalBytes > 0 ? state.fraction : null,
            minHeight: 4,
            color: kAccent,
            backgroundColor: const Color(0xFF2E2E38),
          ),
          const SizedBox(height: 12),
          _text(state.readableProgress, muted: true),
          const SizedBox(height: 6),
          _warn(t.doNotClose),
        ];

      case UpdateStage.ready:
        return <Widget>[
          _title(t.installingUpdate),
          const SizedBox(height: 16),
          const LinearProgressIndicator(
            minHeight: 4,
            color: kAccent,
            backgroundColor: Color(0xFF2E2E38),
          ),
          const SizedBox(height: 12),
          _text(t.installingDetail, muted: true),
        ];

      case UpdateStage.failed:
        return <Widget>[
          _title(t.updateFailedTitle),
          const SizedBox(height: 10),
          _text(state.message),
          const SizedBox(height: 8),
          _text(t.updateManualFrom(releasesPageUrl), muted: true),
          const SizedBox(height: 18),
          _actions(<Widget>[
            _primary(t.retry, Icons.refresh, onRetry),
            _secondary(t.exit, onExit),
          ]),
        ];

      case UpdateStage.checking:
      case UpdateStage.idle:
        return <Widget>[
          _title(t.checkingUpdates),
          const SizedBox(height: 16),
          const LinearProgressIndicator(
            minHeight: 3,
            color: kAccent,
            backgroundColor: Color(0xFF2E2E38),
          ),
        ];
    }
  }

  Widget _title(String text) => Text(
    text,
    textAlign: TextAlign.center,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.none,
    ),
  );

  Widget _text(String text, {bool muted = false}) => Text(
    text,
    textAlign: TextAlign.center,
    style: TextStyle(
      color: muted ? kMuted : Colors.white70,
      fontSize: muted ? 11.5 : 12.5,
      height: 1.45,
      decoration: TextDecoration.none,
    ),
  );

  Widget _warn(String text) => Text(
    text,
    style: const TextStyle(
      color: kSubtitleAccent,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.none,
    ),
  );

  Widget _actions(List<Widget> children) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: <Widget>[
      for (int i = 0; i < children.length; i++) ...<Widget>[
        if (i > 0) const SizedBox(width: 10),
        children[i],
      ],
    ],
  );

  Widget _primary(
    String label,
    IconData icon,
    Future<void> Function() action,
  ) => PressableScale(
    child: FilledButton.icon(
      onPressed: action,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: kAccent,
        foregroundColor: const Color(0xFF11131A),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
      ),
    ),
  );

  Widget _secondary(String label, VoidCallback action) => PressableScale(
    child: OutlinedButton(
      onPressed: action,
      style: OutlinedButton.styleFrom(
        foregroundColor: kMuted,
        side: const BorderSide(color: Color(0xFF3A3A44)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        textStyle: const TextStyle(fontSize: 12.5),
      ),
      child: Text(label),
    ),
  );
}
