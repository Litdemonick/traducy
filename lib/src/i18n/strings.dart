import 'package:flutter/foundation.dart';

import 'strings_en.dart';
import 'strings_es.dart';

/// Idioma de la **interfaz**, no de la traducción.
///
/// Son cosas distintas y conviene no confundirlas: esto decide en qué idioma
/// están los botones y las explicaciones de Traducy; el idioma al que se traduce
/// el juego se elige en la pestaña Idiomas.
enum UiLanguage {
  /// El del sistema: español si Windows está en español, inglés en cualquier
  /// otro caso.
  auto,
  spanish,
  english,
}

/// Todos los textos que lee el usuario.
///
/// Es una clase con miembros en lugar de un mapa de claves a propósito: si falta
/// una traducción, no compila. Con un mapa, el fallo aparecería en tiempo de
/// ejecución y justo en la pantalla de alguien que no puede arreglarlo.
///
/// Los mensajes de `log.*` no están aquí: son el registro técnico para
/// diagnosticar, no interfaz.
abstract class AppStrings {
  const AppStrings();

  /// Código ISO del idioma, para mostrarlo y para depurar.
  String get localeCode;

  // ------------------------------------------------------------- general
  String get appTagline;
  String get exit;
  String get retry;
  String get copy;
  String get free;
  String get locked;
  String get opacity;

  // ------------------------------------------------------- arranque y overlay
  String get preparingOverlay;
  String get startupFailed;
  String get captureZone;
  String get subtitles;
  String get subtitlePlaceholder;
  String get unlockToMove;
  String get lockInPlace;

  // ------------------------------------------------------- cabecera del panel
  String get minimizeTooltip;
  String get gameModeTooltip;
  String get exitTooltip;
  String get minimizedTitle;
  String get minimizedDetail;
  String get minimizeFailed;
  String get minimizeFailedDetail;
  String get backgroundTitle;
  String get backgroundDetail;
  String get backgroundFailed;
  String get backgroundFailedDetail;

  // ---------------------------------------------------------------- bandeja
  String get trayTooltip;
  String get trayOpen;
  String get trayTogglePause;
  String get trayToggleSubtitles;
  String get trayExit;

  // ------------------------------------------------------------- pestañas
  String get tabRegion;
  String get tabLanguages;
  String get tabStyle;
  String get tabPerformance;
  String get tabDiagnostics;
  String get tabAbout;

  // -------------------------------------------------------- actualizaciones
  String get updates;
  String installedVersion(String version);
  String get checkNow;
  String get updateBlockExplanation;
  String updateAvailable(String version);
  String updateAvailableHint(String size);
  String updateToVersion(String version);
  String get updateManualHint;
  String get updateRequiredTitle;
  String updateRequiredBody(String version);
  String updateRequiredDetail(String size);
  String get updateNow;
  String downloadingVersion(String version);
  String get doNotClose;
  String get installingUpdate;
  String get installingDetail;
  String get updateFailedTitle;
  String updateManualFrom(String url);
  String get checkingUpdates;

  // -------------------------------------------------------------- acerca de
  String get aboutTitle;
  String get aboutDescription;
  String get sectionProject;
  String get creator;
  String get repository;
  String get releases;
  String get releasesValue;
  String get bugs;
  String get bugsValue;
  String get version;
  String versionValue(String version, String numeric);
  String get sectionStorage;
  String get storageBeside;
  String get storageUser;
  String get folder;
  String get sectionBuiltWith;
  String get copyLinkTooltip;
  String copiedToClipboard(String what);
  String get copyAuthorProfile;
  String get copyRepoLink;
  String get copyReleasesLink;
  String get copyIssuesLink;
  String get copyVersionNumber;
  String get copyDataPath;
  String copyLinkOf(String name);

  /// Nombre del idioma tal como se ofrece en el selector.
  String get uiLanguageAuto;
  String get uiLanguageSpanish;
  String get uiLanguageEnglish;
  String get uiLanguageSection;
  String get uiLanguageHelp;
  String uiLanguageChanged(String language);
}

/// Idioma activo de la interfaz.
///
/// Es global porque los textos no salen solo de los widgets: el pipeline, el
/// controlador y el canal de mensajes también escriben cosas que el usuario lee,
/// y ninguno de ellos tiene un `BuildContext` a mano.
class L10n {
  L10n._();

  static final ValueNotifier<AppStrings> current = ValueNotifier<AppStrings>(
    _resolve(UiLanguage.auto),
  );

  /// Aplica la elección del usuario. Devuelve el idioma que ha quedado activo.
  static AppStrings apply(UiLanguage choice) {
    final AppStrings strings = _resolve(choice);
    if (strings.localeCode != current.value.localeCode) {
      current.value = strings;
    }
    return strings;
  }

  /// Idioma del sistema, para el modo automático.
  ///
  /// Inglés es el que se usa por defecto y no el español: quien tenga Windows en
  /// alemán o en portugués entenderá antes la versión inglesa que una española,
  /// y quien lo tenga en español la recibe igual sin tocar nada.
  static UiLanguage systemLanguage() {
    try {
      final String code = PlatformDispatcher.instance.locale.languageCode
          .toLowerCase();
      return code == 'es' ? UiLanguage.spanish : UiLanguage.english;
    } catch (_) {
      return UiLanguage.english;
    }
  }

  static AppStrings _resolve(UiLanguage choice) {
    final UiLanguage effective = choice == UiLanguage.auto
        ? systemLanguage()
        : choice;
    return effective == UiLanguage.spanish
        ? const StringsEs()
        : const StringsEn();
  }
}

/// Atajo de lectura: `t.exit` en lugar de `L10n.current.value.exit`.
AppStrings get t => L10n.current.value;
