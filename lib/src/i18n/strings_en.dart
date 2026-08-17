import 'strings.dart';

/// Textos de la interfaz en ingles.
class StringsEn extends AppStrings {
  const StringsEn();

  @override
  String get localeCode => 'en';

  @override
  String get appTagline => 'Real-time screen translator';

  @override
  String get exit => 'Exit';

  @override
  String get retry => 'Retry';

  @override
  String get copy => 'Copy';

  @override
  String get free => 'Free';

  @override
  String get locked => 'Locked';

  @override
  String get opacity => 'Opacity';

  @override
  String get preparingOverlay => 'Getting the overlay ready...';

  @override
  String get startupFailed => 'Traducy could not start';

  @override
  String get captureZone => 'Capture zone';

  @override
  String get subtitles => 'Subtitles';

  @override
  String get subtitlePlaceholder => 'The translation shows up here';

  @override
  String get unlockToMove => 'Unlock to move and resize';

  @override
  String get lockInPlace => 'Lock in place';

  @override
  String get minimizeTooltip =>
      'Minimize. Its taskbar button stays there: click it to come back';

  @override
  String get gameModeTooltip =>
      'Game mode: hides Traducy and leaves it running in the background. Come '
      'back with its icon next to the clock, or with Ctrl+Alt+T';

  @override
  String get exitTooltip => 'Quit Traducy';

  @override
  String get minimizedTitle => 'Traducy minimized';

  @override
  String get minimizedDetail => 'Click its taskbar button to bring it back.';

  @override
  String get minimizeFailed => 'Could not minimize';

  @override
  String get minimizeFailedDetail =>
      'Use the eye button for game mode, or Ctrl+Alt+T.';

  @override
  String get backgroundTitle => 'Traducy is running in the background';

  @override
  String get backgroundDetail =>
      'Click its icon next to the clock, or press Ctrl+Alt+T, to come back.';

  @override
  String get backgroundFailed => 'Could not switch to background mode';

  @override
  String get backgroundFailedDetail =>
      'Use Ctrl+Alt+T to hide the panel while you play.';

  @override
  String get trayTooltip => 'Traducy - click to open, right-click for options';

  @override
  String get trayOpen => 'Open Traducy';

  @override
  String get trayTogglePause => 'Pause or resume translating';

  @override
  String get trayToggleSubtitles => 'Show or hide the subtitles';

  @override
  String get trayExit => 'Quit Traducy';

  @override
  String get tabRegion => 'Zone';

  @override
  String get tabLanguages => 'Languages';

  @override
  String get tabStyle => 'Style';

  @override
  String get tabPerformance => 'Performance';

  @override
  String get tabDiagnostics => 'Diagnostics';

  @override
  String get tabAbout => 'About';

  @override
  String get updates => 'Updates';

  @override
  String get checkNow => 'Check now';

  @override
  String get updateBlockExplanation =>
      'When a new version shows up, Traducy stops translating and blocks '
      'itself until you update: an old version half working looks like a bug '
      'in the app itself.';

  @override
  String get updateManualHint => 'Download it by hand from the releases page.';

  @override
  String get updateRequiredTitle => 'Update required';

  @override
  String get updateNow => 'Update now';

  @override
  String get doNotClose => 'Do not close the app.';

  @override
  String get installingUpdate => 'Installing the update';

  @override
  String get installingDetail =>
      'Traducy will close and the installer carries on by itself. The new '
      'version opens when it finishes.';

  @override
  String get updateFailedTitle => 'The update failed';

  @override
  String get checkingUpdates => 'Checking for updates';

  @override
  String get aboutTitle => 'About Traducy';

  @override
  String get aboutDescription =>
      'Mark an area over the game and Traducy reads the text that shows up '
      'there, displaying the translation as subtitles on top. It does not '
      'modify the game or its files.';

  @override
  String get sectionProject => 'Project';

  @override
  String get creator => 'Creator';

  @override
  String get repository => 'Repository';

  @override
  String get releases => 'Releases';

  @override
  String get releasesValue => 'Downloads and notes for every version';

  @override
  String get bugs => 'Bugs';

  @override
  String get bugsValue => 'Report a problem or ask for something';

  @override
  String get version => 'Version';

  @override
  String get sectionStorage => 'Where everything is stored';

  @override
  String get storageBeside =>
      'Next to the program, in the folder you picked when installing. '
      'Settings, OCR languages and downloaded updates.';

  @override
  String get storageUser => 'In your user folder.';

  @override
  String get folder => 'Folder';

  @override
  String get sectionBuiltWith => 'Built with';

  @override
  String get copyLinkTooltip => 'Copy the link';

  @override
  String get copyAuthorProfile => 'Creator profile';

  @override
  String get copyRepoLink => 'Repository link';

  @override
  String get copyReleasesLink => 'Releases link';

  @override
  String get copyIssuesLink => 'Issues link';

  @override
  String get copyVersionNumber => 'Version number';

  @override
  String get copyDataPath => 'Data folder path';

  @override
  String get uiLanguageAuto => 'Automatic';

  @override
  String get uiLanguageSpanish => 'Spanish';

  @override
  String get uiLanguageEnglish => 'English';

  @override
  String get uiLanguageSection => 'App language';

  @override
  String get uiLanguageHelp =>
      'Which language Traducy itself is shown in. Nothing to do with the '
      'language the game is translated into, which you pick below. Automatic '
      'follows Windows.';

  @override
  String installedVersion(String version) => 'Installed version: $version';

  @override
  String updateAvailable(String version) => 'Version $version is available';

  @override
  String updateAvailableHint(String size) =>
      'The installer ($size) will be downloaded and the new version installed '
      'over the current one, keeping your settings and downloaded languages.';

  @override
  String updateToVersion(String version) => 'Update to $version';

  @override
  String updateRequiredBody(String version) =>
      'There is a new version of Traducy ($version). Translating has stopped '
      'and the app stays blocked until it is installed.';

  @override
  String updateRequiredDetail(String size) =>
      'The installer ($size) will be downloaded, Traducy will close and the '
      'new version will be installed over the current one. Your settings and '
      'downloaded languages are kept.';

  @override
  String downloadingVersion(String version) => 'Downloading $version';

  @override
  String updateManualFrom(String url) =>
      'You can also download it by hand from $url';

  @override
  String versionValue(String version, String numeric) =>
      '$version  -  build $numeric';

  @override
  String copiedToClipboard(String what) => '$what copied to the clipboard';

  @override
  String copyLinkOf(String name) => 'Link for $name';

  @override
  String uiLanguageChanged(String language) => 'App language: $language';
}
