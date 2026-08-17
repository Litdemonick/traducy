import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/about.dart';
import '../core/app_paths.dart';
import '../core/version.dart';
import '../i18n/strings.dart';
import '../state/app_controller.dart';
import 'widgets_common.dart';
import 'zone_console.dart';

/// Zona de información: qué es la aplicación, quién la hace, qué versión es y
/// dónde vive el código.
///
/// Los enlaces no se abren en el navegador desde aquí. El overlay es una ventana
/// siempre visible sobre el juego, y lanzar un navegador por encima mientras
/// alguien está jugando es más molesto que útil: se copian al portapapeles y se
/// abren cuando convenga.
class AboutSection extends StatelessWidget {
  const AboutSection({
    super.key,
    required this.controller,
    required this.onCopied,
  });

  final AppController controller;

  /// Aviso de que algo se copió, para que la consola lo cuente.
  final void Function(String message) onCopied;

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    onCopied(t.copiedToClipboard(label));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionTitle(t.aboutTitle),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF15151A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF2A2A33)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Image.asset(
                    'assets/logo_mark.png',
                    width: 40,
                    height: 40,
                    filterQuality: FilterQuality.high,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Text(
                              About.appName,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: kAccent.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'v$appVersion',
                                style: const TextStyle(
                                  color: kAccent,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t.appTagline,
                          style: const TextStyle(color: kMuted, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                t.aboutDescription,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),

        SectionTitle(t.sectionProject),
        _InfoRow(
          icon: Icons.person_outline,
          label: t.creator,
          value: About.author,
          onCopy: () => _copy(About.authorUrl, t.copyAuthorProfile),
        ),
        _InfoRow(
          icon: Icons.code,
          label: t.repository,
          value: '${About.githubOwner}/${About.githubRepo}',
          onCopy: () => _copy(About.repoUrl, t.copyRepoLink),
        ),
        _InfoRow(
          icon: Icons.new_releases_outlined,
          label: t.releases,
          value: t.releasesValue,
          onCopy: () => _copy(About.releasesUrl, t.copyReleasesLink),
        ),
        _InfoRow(
          icon: Icons.bug_report_outlined,
          label: t.bugs,
          value: t.bugsValue,
          onCopy: () => _copy(About.issuesUrl, t.copyIssuesLink),
        ),
        _InfoRow(
          icon: Icons.numbers,
          label: t.version,
          value: t.versionValue(appVersion, appVersionNumeric),
          onCopy: () => _copy(appVersion, t.copyVersionNumber),
        ),

        SectionTitle(t.sectionStorage),
        HelpText(
          AppPaths.instance.isBesideProgram ? t.storageBeside : t.storageUser,
        ),
        _InfoRow(
          icon: Icons.folder_outlined,
          label: t.folder,
          value: AppPaths.instance.dataDirectory.path,
          onCopy: () =>
              _copy(AppPaths.instance.dataDirectory.path, t.copyDataPath),
        ),
        if (AppPaths.instance.fallbackReason != null)
          NoticeCard(
            message: AppPaths.instance.fallbackReason!,
            severity: NoticeSeverity.warning,
          ),

        SectionTitle(t.sectionBuiltWith),
        for (final (String name, String license, String url) in About.credits)
          _InfoRow(
            icon: Icons.extension_outlined,
            label: name,
            value: license,
            onCopy: () => _copy(url, t.copyLinkOf(name)),
          ),

        ZoneConsole(controller: controller, zone: PanelZone.about),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final IconData icon;
  final String label;
  final String value;
  final Future<void> Function() onCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 14, color: kMuted),
          const SizedBox(width: 8),
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(color: kMuted, fontSize: 11),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ),
          CopyIconButton(tooltip: t.copyLinkTooltip, onPressed: onCopy),
        ],
      ),
    );
  }
}
