import 'panel_strings.dart';

/// Textos del panel en inglés.
class PanelStringsEn extends PanelStrings {
  const PanelStringsEn();

  @override
  String get resizeHint =>
      'Drag any edge to resize · double-click for the default size';
  @override
  String get pause => 'Pause';
  @override
  String get translate => 'Translate';
  @override
  String get understood => 'Got it';

  @override
  String stepNumber(int number, String title) => '$number. $title';
  @override
  String get stepWindowsOcrTitle => 'OCR engine: the one Windows ships with';
  @override
  String get stepWindowsOcrProblem =>
      'The Windows OCR engine cannot read this language.';
  @override
  String get stepWindowsOcrHint =>
      'Nothing to install and nothing to change in your Windows. If the game '
      'language is not one the system recognizes, switch to Tesseract: its '
      'language packs are stored inside the Traducy folder.';
  @override
  String get useTesseract => 'Use Tesseract';
  @override
  String get checkAgain => 'Check again';
  @override
  String get stepTesseractTitle =>
      'Install Tesseract, the engine that reads text';
  @override
  String get stepTesseractProblem =>
      'Tesseract is missing: without it there is no way to read text off the '
      'screen.';
  @override
  String get stepTesseractHint =>
      'Press the button and accept the install in the window that opens. Or '
      'switch to the Windows OCR engine, which ships with the system and needs '
      'no install.';
  @override
  String get installTesseract => 'Install Tesseract';
  @override
  String get useWindowsOcr => 'Use the Windows one';
  @override
  String get stepLanguageTitle => 'Download the game language';
  @override
  String stepLanguageProblem(String language) =>
      'The OCR language "$language" is missing.';
  @override
  String get stepLanguageHint =>
      'Tesseract needs one pack per script it reads. It downloads into the '
      'Traducy folder, without asking for administrator rights.';
  @override
  String downloadLanguage(String language) => 'Download $language';
  @override
  String get stepRegionTitle => 'Mark the area where the text shows up';
  @override
  String get stepRegionProblem => 'There is no valid capture zone yet.';
  @override
  String get stepRegionHint =>
      'Press "Detect the game" on the Zone tab, or place a band across the '
      'bottom of the screen and fit it over the game text.';
  @override
  String get useBottomBand => 'Use the bottom band';
  @override
  String get stepRunTitle =>
      'Press Translate and switch to game mode with Ctrl+Alt+T';
  @override
  String get stepRunProblem =>
      'Everything is ready, but translating is stopped.';
  @override
  String get stepRunHint =>
      'Press Translate. Remember to run the game windowed: exclusive fullscreen '
      'cannot be captured.';
  @override
  String get translateNow => 'Translate now';
  @override
  String downloadingLanguage(String language, String progress) =>
      'Downloading $language...  $progress';

  @override
  String get activateSection => 'Show on screen';
  @override
  String get activateHelp =>
      'Both start switched off on purpose, so nothing shows up over the game '
      'unless you ask for it. Switch them on to place them, and off when you '
      'are done. They move by their title bar and resize by the edge handles; '
      'the inside lets clicks through to the game.';
  @override
  String get activateRegionLabel => 'Show the capture zone';
  @override
  String get activateRegionDescription =>
      'Shows the green rectangle so you can place it over the game text.';
  @override
  String get activateSubtitleLabel => 'Show the subtitle box';
  @override
  String get activateSubtitleDescription =>
      'Shows the orange frame and a sample line so you can place and style it. '
      'Switched off, nothing appears until there is a translation.';
  @override
  String get captureZoneSection => 'Capture zone';
  @override
  String get captureZoneHelp =>
      'The quickest way is to detect the game: the zone places itself across its '
      'lower part and moves with the window. To place it by hand, use the '
      'buttons below and adjust the green rectangle.';
  @override
  String get detectGame => 'Detect the game';
  @override
  String anchoredTo(String title) => 'Anchored to "$title"';
  @override
  String waitingFor(String title) => 'Waiting for "$title" (not open)';
  @override
  String get unanchor => 'Unanchor';
  @override
  String get bottomBand => 'Bottom band';
  @override
  String get fullScreen => 'Full screen';
  @override
  String get regionLockedLabel => 'Zone locked';
  @override
  String get regionLockedOn => 'It cannot be moved or resized.';
  @override
  String get regionLockedOff => 'It can be dragged and resized.';
  @override
  String get subtitleLockedLabel => 'Subtitle box locked';
  @override
  String get subtitleLockedSubtitle =>
      'Its own lock, separate from the zone one.';
  @override
  String get metricsRegionTitle => 'Capture zone · real screen pixels';
  @override
  String get metricsSubtitleTitle => 'Subtitle box · window pixels';
  @override
  String get metricX => 'X';
  @override
  String get metricY => 'Y';
  @override
  String get metricWidth => 'Width';
  @override
  String get metricHeight => 'Height';
  @override
  String get zoneTooSmall => 'The zone is too small to read any text.';
  @override
  String get zoneTooSmallHint =>
      'Press "Bottom band" or make the green rectangle bigger.';
  @override
  String get followWindowSection => 'Follow a window';
  @override
  String get followWindowHelp =>
      'Anchors the zone to one window: move the game and the zone goes with it. '
      'It re-attaches by itself when the game is reopened.';
  @override
  String followingWindow(String title) => 'Following: $title';
  @override
  String get fixedZone => 'Zone fixed on the screen';
  @override
  String get refreshWindowList => 'Refresh the window list';
  @override
  String get stopFollowing => 'Stop following';
  @override
  String get pressRefreshToList => 'Press refresh to list the open windows.';
  @override
  String get follow => 'Follow';
  @override
  String get overlayWindowSection => 'Overlay window';
  @override
  String get overlayExcluded => 'The overlay is excluded from capture.';
  @override
  String get overlayExcludedHint =>
      'The subtitles will not read themselves back, so you can put them '
      'anywhere.';
  @override
  String get overlayNotExcluded =>
      'This Windows cannot exclude the overlay from capture.';
  @override
  String get overlayNotExcludedHint =>
      'Keep the subtitle box OUTSIDE the green rectangle so the OCR does not '
      'read its own translation.';
  @override
  String get subtitleOverlaps => 'The subtitle box overlaps the capture zone.';
  @override
  String get subtitleOverlapsHint =>
      'Move it outside the green rectangle to avoid a loop.';
  @override
  String get startInConfigLabel => 'Open in setup mode';
  @override
  String get startInConfigSubtitle =>
      'Switched off, Traducy starts straight into game mode.';
  @override
  String get playWithPanelLabel => 'Keep playing with the panel open';
  @override
  String get playWithPanelSubtitle =>
      'Clicks go to the game except while the cursor is over the panel or the '
      'boxes. Switch it off if some click does not respond properly.';

  @override
  String get ocrEngineSection => 'OCR engine (what reads the screen)';
  @override
  String get ocrEngineHelp =>
      'The Windows one ships with the system: free, nothing to install, nothing '
      'leaves your computer, and it is more accurate on screenshots, Japanese '
      'especially. It does need the language added in Windows. Tesseract works '
      'on any machine and brings its own packs, which Traducy downloads without '
      'administrator rights.';
  @override
  String windowsRecognizes(String languages) =>
      'Windows recognizes: $languages';
  @override
  String get windowsMissingLanguage =>
      'Windows does not have the requested language. Add it under Settings → '
      'Time & language → Language & region, or switch to Tesseract.';
  @override
  String get checkEnginesFirst =>
      'Check the engines under Diagnostics to see which languages this Windows '
      'recognizes.';
  @override
  String get gameLanguageSection => 'Game language (what gets read)';
  @override
  String get gameLanguageHelp =>
      'The OCR needs to know which script to read. Picking "Japanese" here sets '
      'both the OCR pack and the source language at once.';
  @override
  String get scriptToRecognize => 'Script to recognize';
  @override
  String get notInstalledSuffix => '  (not installed)';
  @override
  String get autoDetectLabel => 'Detect the language automatically';
  @override
  String get autoDetectOn => 'The translator decides the source language.';
  @override
  String autoDetectOff(String language) =>
      '"$language" is sent as the source language.';
  @override
  String get translateToSection => 'Translate into';
  @override
  String get targetLanguageLabel => 'Target language';
  @override
  String get translatorSection => 'Translation engine';
  @override
  String get translatorLabel => 'Engine';
  @override
  String get translatorGoogle => 'Google Translate — free, no key';
  @override
  String get translatorClaude => 'Claude — best quality (API key)';
  @override
  String get translatorDeepl => 'DeepL — very good quality (API key)';
  @override
  String get translatorLibre => 'LibreTranslate — your own server';
  @override
  String get translatorNone => 'No translation — show the original only';
  @override
  String get claudeKeyLabel => 'Claude API key';
  @override
  String get modelLabel => 'Model';
  @override
  String get claudeHelp =>
      'Translates with the context of the game in mind: it keeps the tone and '
      'does not mangle proper names. Pay per use.';
  @override
  String get deeplKeyLabel => 'DeepL API key';
  @override
  String get deeplKeyHint => 'Free keys end in :fx';
  @override
  String get libreUrlLabel => 'LibreTranslate URL';
  @override
  String get glossarySection => 'Glossary';
  @override
  String get glossaryHelp =>
      'Terms that must not be translated, or that have a fixed translation. One '
      'per line. Only the Claude engine applies it.';
  @override
  String get glossaryLabel => 'Glossary';

  @override
  String get textSection => 'Text';
  @override
  String get fontSizeLabel => 'Size';
  @override
  String get lineHeightLabel => 'Line height';
  @override
  String get letterSpacingLabel => 'Letter spacing';
  @override
  String get maxLinesLabel => 'Maximum lines';
  @override
  String get historyLabel => 'History in the box';
  @override
  String get historyOn =>
      'Earlier lines stay visible, with scrolling. Switch the box on to scroll '
      'up and read them with the wheel.';
  @override
  String get historyOff => 'Only the latest translated line.';
  @override
  String get rememberedLinesLabel => 'Lines remembered';
  @override
  String get clearHistory => 'Clear the history';
  @override
  String get autoFitLabel => 'Fit the text to the box';
  @override
  String get autoFitOn =>
      'The type shrinks as much as needed for the whole text to fit.';
  @override
  String get autoFitOff => 'Fixed size: long text gets cut off.';
  @override
  String get minShrinkLabel => 'Smallest allowed';
  @override
  String get minShrinkHelp =>
      'How far the type may shrink. Text that fits but cannot be read is no '
      'use, so below this limit it gets cut off instead of shrinking further.';
  @override
  String get boldLabel => 'Bold';
  @override
  String get italicLabel => 'Italic';
  @override
  String get fontLabel => 'Font';
  @override
  String get readabilitySection => 'Readability';
  @override
  String get readabilityHelp =>
      'The outline is what keeps the text readable over any scene; the '
      'semi-transparent background helps on very busy ones.';
  @override
  String get outlineWidthLabel => 'Outline width';
  @override
  String get backgroundOpacityLabel => 'Background opacity';
  @override
  String get cornerRadiusLabel => 'Corner radius';
  @override
  String get paddingLabel => 'Inner padding';
  @override
  String get shadowLabel => 'Shadow';
  @override
  String get showOriginalLabel => 'Show the original text too';
  @override
  String get showOriginalSubtitle =>
      'Handy for learning the language or checking the OCR.';
  @override
  String get colorsSection => 'Colors';
  @override
  String get textColorLabel => 'Text color';
  @override
  String get outlineColorLabel => 'Outline color';
  @override
  String get backgroundColorLabel => 'Background color';

  @override
  String get frequencySection => 'Frequency';
  @override
  String get frequencyHelp =>
      'Time between captures. Lower responds sooner but costs more CPU and more '
      'translation quota.';
  @override
  String get intervalLabel => 'Interval';
  @override
  String capturesPerSecond(String value) => '≈ $value captures per second';
  @override
  String get minChangeLabel => 'Minimum change';
  @override
  String get minChangeHelp =>
      'How much the zone must change before it is read again. Lower it if new '
      'dialogue goes undetected; raise it if it translates too often on scenes '
      'with animated backgrounds.';
  @override
  String get stabilityLabel => 'Stability';
  @override
  String get stabilityFramesSuffix => ' fr.';
  @override
  String get stabilityHelp =>
      'Frames with the same text before translating. Raise it if the game types '
      'the dialogue out letter by letter.';
  @override
  String get holdLabel => 'Hold time';
  @override
  String get holdHelp =>
      'How long the subtitle stays on screen once no text is detected any more.';
  @override
  String get preprocessSection => 'Image preparation';
  @override
  String get preprocessHelp =>
      'Good preprocessing raises OCR accuracy more than changing engine. Scale '
      'is the setting with the biggest impact.';
  @override
  String get scaleLabel => 'Scale';
  @override
  String get contrastLabel => 'Contrast';
  @override
  String get binarizeLabel => 'Threshold';
  @override
  String get grayscaleLabel => 'Grayscale';
  @override
  String get invertLabel => 'Invert';
  @override
  String get denoiseLabel => 'Reduce noise';
  @override
  String get timeoutsSection => 'Timeouts';
  @override
  String get timeoutsHelp =>
      'Past this, the stage is abandoned instead of leaving the cycle hanging.';
  @override
  String get ocrLabel => 'OCR';
  @override
  String get translationLabel => 'Translation';

  @override
  String get enginesSection => 'Engine status';
  @override
  String get check => 'Check';
  @override
  String get testNow => 'Test now';
  @override
  String get pathsSection => 'Paths';
  @override
  String get pathsHelp =>
      'Languages downloaded by Traducy are kept in its own folder, not in the '
      'Tesseract one.';
  @override
  String get tesseractExeLabel => 'Tesseract executable (empty = auto-detect)';
  @override
  String get tesseractExeHint =>
      r'C:\Program Files\Tesseract-OCR\tesseract.exe';
  @override
  String get tessdataFolderLabel =>
      'Downloaded languages folder (empty = default)';
  @override
  String get settingsFileLabel => 'Settings';
  @override
  String get languagesFolderLabel => 'Languages';
  @override
  String get statsSection => 'Counters';
  @override
  String get statFrames => 'Frames';
  @override
  String get statOcrRuns => 'OCR runs';
  @override
  String get statTranslations => 'Translations';
  @override
  String get statCacheHits => 'Cache hits';
  @override
  String get statSkipped => 'Skipped, unchanged';
  @override
  String get statCapture => 'Capture';
  @override
  String get statPreprocess => 'Preprocessing';
  @override
  String get statOcr => 'OCR';
  @override
  String get statTranslation => 'Translation';
  @override
  String get statDetectedLanguage => 'Detected language';
  @override
  String get logSection => 'Log';
  @override
  String get clearLog => 'Clear the log';
  @override
  String get shortcutsSection => 'Keyboard shortcuts';
  @override
  String get shortcutPanel => 'Show or hide the panel';
  @override
  String get shortcutPause => 'Pause or resume';
  @override
  String get shortcutSubtitles => 'Show or hide the subtitles';
  @override
  String healthReady(String engine) => '$engine: ready';
  @override
  String healthIssue(String engine, String issue) => '$engine: $issue';
  @override
  String healthChecking(String engine) => '$engine: checking…';
  @override
  String healthUnchecked(String engine) => '$engine: not checked';
  @override
  String get ocrEngineWindowsName => 'OCR (Windows)';
  @override
  String get ocrEngineTesseractName => 'OCR (Tesseract)';

  @override
  String get pipelineRunning => 'Running';
  @override
  String get pipelinePaused => 'Paused';
  @override
  String get pipelineStopped => 'Stopped';
  @override
  String get pipelineDefineZone => 'Set the capture zone';
  @override
  String get pipelineDefineZoneHint => 'Drag the rectangle over the game text.';
  @override
  String get pipelineCaptureFailed => 'The screen could not be captured.';
  @override
  String get pipelineCaptureFailedHint =>
      'Check that the zone is inside an active monitor.';
  @override
  String get pipelineBlackFrame => 'The zone captures as black';
  @override
  String get pipelineBlackFrameHint => 'Run the game windowed or borderless.';
  @override
  String get pipelineFlatFrame => 'The zone sees no text (flat image)';
  @override
  String get pipelineFlatFrameHint =>
      'Check that the rectangle sits over the game text and that the game is windowed or borderless.';
  @override
  String get pipelinePrepFailed => 'Preparing the image failed.';
  @override
  String get pipelinePrepFailedHint => 'Try lowering the preprocessing scale.';
  @override
  String get pipelineNoText => 'No text in the zone';
  @override
  String get pipelineAlreadyTranslated => 'Text already translated';
  @override
  String get pipelineWaitingStable => 'Waiting for the text to settle';
  @override
  String get pipelineTranslated => 'Translated';
  @override
  String get pipelineTranslatedCached => 'Translated (cached)';
  @override
  String pipelineUnchanged(String percent) => 'No change ($percent %)';
  @override
  String pipelineAutoPaused(int errors, String message) =>
      'Paused after $errors errors: $message';
  @override
  String get pipelineAutoPausedHint => 'Fix the problem and press Resume.';
  @override
  String pipelineUnexpected(String error) => 'Unexpected error: $error';
  @override
  String get msgPassthroughOn => 'You can keep playing with the panel open';
  @override
  String get msgPassthroughOnDetail =>
      'Clicks go to the game except over the panel and the boxes.';
  @override
  String get msgPassthroughOff => 'The panel takes the clicks';
  @override
  String get msgPassthroughOffDetail =>
      'While the panel is visible, the window receives every click.';
  @override
  String get msgSubtitlesVisible => 'Subtitles visible';
  @override
  String get msgSubtitlesHidden => 'Subtitles hidden';
  @override
  String get msgToggleWithH => 'Ctrl+Alt+H toggles them.';
  @override
  String get msgZoneLocked => 'The zone is locked';
  @override
  String get msgZoneLockedDetail => 'Take the lock off its bar to change it.';
  @override
  String get msgRegionOn => 'Capture zone shown';
  @override
  String get msgRegionOff => 'Capture zone hidden';
  @override
  String get msgRegionOnDetail =>
      'Drag its title bar to move it and the edge handles to resize it.';
  @override
  String get msgRegionOffDetail =>
      'The zone is still being captured; only the frame is hidden.';
  @override
  String get msgSubtitleBoxOn => 'Subtitle box shown';
  @override
  String get msgSubtitleBoxOff => 'Subtitle box hidden';
  @override
  String get msgSubtitleBoxOnDetail =>
      'Move the box by its bar; the inside lets clicks through.';
  @override
  String get msgSubtitleBoxOffDetail => 'The translated text still shows.';
  @override
  String get msgPanelSizeReset => 'Panel size reset';
  @override
  String get msgRegionLocked => 'Capture zone locked';
  @override
  String get msgRegionUnlocked => 'Capture zone unlocked';
  @override
  String get msgSubtitleLocked => 'Subtitle box locked';
  @override
  String get msgSubtitleUnlocked => 'Subtitle box unlocked';
  @override
  String get msgLockedDetail => 'It can no longer be moved or resized.';
  @override
  String get msgUnlockedDetail => 'Drag its title bar to move it.';
  @override
  String msgGameLanguage(String label) => 'Game language: $label';
  @override
  String msgCheckingPack(String code) =>
      'Checking whether the OCR has the "$code" pack...';
  @override
  String msgTargetLanguage(String label) => 'It will be translated into $label';
  @override
  String get msgHistoryCleared => 'Subtitle history cleared';
  @override
  String get msgAutoUpdateOn => 'New versions will install by themselves';
  @override
  String get msgAutoUpdateOff =>
      'New versions will wait until you press Update';
  @override
  String get msgNoGameWindow => 'No game window found';
  @override
  String get msgNoGameWindowDetail =>
      'Open the game windowed or borderless and press Detect the game again.';
  @override
  String msgFollowing(String title) => 'Following "$title"';
  @override
  String get msgFollowingDetail =>
      'The zone sits across the lower part of that window and moves with it. Switch it on under Zone to adjust it.';
  @override
  String get msgNotFollowing => 'The zone no longer follows any window';
  @override
  String msgWindowLost(String title) => 'I cannot find the "$title" window';
  @override
  String get msgWindowLostDetail =>
      'The zone stays where it was. Open the game, or press Detect the game to attach it to another window.';
  @override
  String get msgDownloadInProgress => 'There is already a download running';
  @override
  String msgDownloadingLanguage(String language) =>
      'Downloading the "$language" language...';
  @override
  String msgLanguageInstalled(String language) =>
      'The "$language" language is installed';
  @override
  String msgSavedIn(String path) => 'Saved in $path';
  @override
  String msgDownloadFailed(String language) => 'Could not download "$language"';
  @override
  String get msgLanguageFolderChanged => 'Languages folder changed';
  @override
  String get msgTesseractInstallOpened =>
      'The Tesseract install opened in PowerShell';
  @override
  String get msgTesseractInstallOpenedDetail =>
      'When it finishes, press "Check again" in the panel.';
  @override
  String get msgInstallerFailed => 'The installer could not be opened';
  @override
  String get msgInstallerFailedDetail =>
      'Run it by hand: winget install UB-Mannheim.TesseractOCR';
  @override
  String get msgCheckingUpdates => 'Checking for updates...';
  @override
  String get msgUpToDate => 'You already have the latest version';
  @override
  String msgNewVersion(String version) => 'There is a new version: $version';
  @override
  String msgNewVersionAuto(String size) =>
      'Traducy has stopped and is updating itself ($size).';
  @override
  String msgNewVersionManual(String size) =>
      'Traducy has stopped and stays blocked until you update ($size).';
  @override
  String get msgUpdateFailed => 'The update failed';
  @override
  String get msgTesseractNotFound => 'Tesseract is not on this computer';
  @override
  String get msgTesseractNotFoundDetail =>
      'Press "Install Tesseract" in the guide above.';
  @override
  String get msgTesseractFound => 'Tesseract detected';
  @override
  String msgOcrReady(String languages) => 'All set: OCR "$languages" available';
  @override
  String msgInstalledLanguages(String languages) =>
      'Installed languages: $languages';
  @override
  String msgMissingOcrLanguage(String languages) =>
      'The OCR language "$languages" is missing';
  @override
  String get msgDownloadFromGuide => 'Download it from the guide above.';
  @override
  String msgOrUseInstalled(String languages) =>
      'You can download it from the guide, or use one you already have: $languages.';
  @override
  String get msgFallbackToTesseract =>
      'Tesseract will be used to read the screen';
  @override
  String msgFallbackToTesseractDetail(String reason) =>
      'The Windows OCR engine is no use here: $reason. You can try again from the Languages tab once you add it.';
  @override
  String get msgReasonNoLanguage =>
      'Windows does not have the language installed';
  @override
  String get msgReasonNoComponent =>
      'this Windows does not ship the OCR component';
  @override
  String get msgNoOcrComponent =>
      'This Windows does not ship the OCR component';
  @override
  String get msgSwitchToTesseract =>
      'Switch to Tesseract on the Languages tab.';
  @override
  String msgWindowsCannotRead(String language) =>
      'Windows does not recognize "$language"';
  @override
  String msgWindowsCannotReadDetail(String languages) =>
      'It recognizes: $languages. Use Tesseract for this one: it downloads inside Traducy and changes nothing in your Windows.';
  @override
  String msgWindowsOcrReady(String tag) => 'Windows OCR ready ($tag)';
  @override
  String get msgWindowsOcrReadyDetail =>
      'Nothing installed and nothing leaves your computer.';
  @override
  String get msgCannotTranslateYet => 'Cannot translate yet';
  @override
  String get msgBottomBandSet => 'A zone was placed across the bottom band';
  @override
  String get msgBottomBandSetDetail =>
      'Adjust it if the game text shows up somewhere else.';
  @override
  String get msgTranslating => 'Translating';
  @override
  String get msgTranslatingDetail =>
      'Ctrl+Alt+T hides the panel · Ctrl+Alt+P pauses';
  @override
  String get msgTranslationStopped => 'Translating stopped';
  @override
  String get msgTranslationResumed => 'Translating resumed';
  @override
  String get msgTranslationPaused => 'Translating paused';
  @override
  String get msgToggleWithP => 'Ctrl+Alt+P toggles it.';
  @override
  String get msgTestingCapture => 'Running a test capture...';
  @override
  String msgTestFailed(String message) => 'The test failed: $message';
  @override
  String msgTestDone(String message) => 'Test finished: $message';
  @override
  String msgTestTimings(int ocrMs, int translateMs) =>
      'OCR $ocrMs ms · translation $translateMs ms';
  @override
  String msgUnexpectedError(String error) => 'Unexpected failure: $error';
  @override
  String msgStartFailed(String error) => 'Traducy could not start: $error';
  @override
  String get msgCheckingNewVersion => 'Checking for a new version...';
  @override
  String msgLatestVersion(String version) =>
      'You are on the latest version ($version).';
  @override
  String msgVersionAvailable(String version) =>
      'Version $version is available.';
  @override
  String msgDownloadingVersion(String version) =>
      'Downloading version $version...';
  @override
  String msgInstallingVersion(String version) =>
      'Installing version $version. Traducy will close and open again.';
  @override
  String msgDownloadUnexpected(String language, String error) =>
      'Unexpected failure downloading "$language": $error';
  @override
  String msgOcrCheckFailed(String error) => 'Checking the OCR failed: $error';
  @override
  String msgTranslatorCheckFailed(String error) =>
      'Checking the translator failed: $error';
  @override
  String get consoleNoZoneHeadline => 'No capture zone';
  @override
  String get consoleNoZoneBody =>
      'Traducy does not know which part of the screen to read yet. Press '
      '"Detect the game" and the zone places itself where dialogue usually is.';
  @override
  String get consoleNoZoneTip1 =>
      'Switch on "Show the capture zone" to see the green rectangle.';
  @override
  String get consoleNoZoneTip2 =>
      'It moves by its title bar; the inside lets clicks through.';
  @override
  String get consoleOverlapHeadline => 'The subtitles overlap the zone';
  @override
  String get consoleOverlapBody =>
      'The OCR would read its own translation and loop. Move the subtitle box '
      'outside the green rectangle.';
  @override
  String consoleZoneReadyHeadline(int width, int height) =>
      'Zone ready: $width×$height px';
  @override
  String consoleZoneFollowBody(String title) =>
      'The zone follows the "$title" window: move the game and the zone goes '
      'with it.';
  @override
  String get consoleZoneFixedBody =>
      'Zone fixed on the screen. The tighter it is around the text, the better '
      'the OCR reads and the less CPU it costs.';
  @override
  String get consoleZoneTipLock =>
      'Once it is in place, close it with the lock on its bar.';
  @override
  String get consoleZoneTipLocked =>
      'It is locked: take the lock off to move it.';
  @override
  String consoleMissingLanguageHeadline(String languages) =>
      'The "$languages" language is missing';
  @override
  String get consoleMissingLanguageBody =>
      'The OCR needs one pack per script it reads. Press it in the notice above '
      'and it downloads by itself, without administrator rights.';
  @override
  String consoleLanguagesReadyHeadline(String source, String target) =>
      'Translating $source → $target';
  @override
  String get consoleLanguagesAutoBody =>
      'The translator decides the source language. That works best when the '
      'game mixes languages.';
  @override
  String consoleLanguagesFixedBody(String source) =>
      '"$source" is sent as the source language, rather than letting the '
      'translator guess.';
  @override
  String get consoleLanguagesTipEngine =>
      'The translation engine is chosen further down; Claude is the one that '
      'understands the context of a game best.';
  @override
  String get consoleStyleHeadline => 'How the subtitles look';
  @override
  String get consoleStyleBody =>
      'Changes show up in the box straight away. Switch the subtitle box on from '
      'the Zone tab to see them without waiting for a translation.';
  @override
  String get consoleStyleTip1 =>
      'The outline is what keeps the text readable over any scene.';
  @override
  String get consoleStyleTip2 =>
      'With the history on, the box keeps the earlier lines.';
  @override
  String get consolePerformanceHeadline => 'Cycle performance';
  @override
  String consolePerformanceBody(int frames, int skipped) =>
      '$frames frames processed, $skipped skipped because nothing changed. The '
      'more get skipped, the less CPU and quota it costs.';
  @override
  String get consolePerformanceIdleBody =>
      'No data yet: press Translate and come back here to see how long each '
      'stage takes.';
  @override
  String get consolePerformanceTip1 =>
      'If new dialogue goes undetected, lower "Minimum change".';
  @override
  String get consolePerformanceTip2 =>
      'Preprocessing scale is what raises OCR accuracy the most.';
  @override
  String get consoleEnginesPendingHeadline => 'Engine check pending';
  @override
  String get consoleEnginesPendingBody =>
      'Press "Check" to see whether the OCR and the translator respond. "Test '
      'now" runs a full capture and reports how long each stage took.';
  @override
  String get consoleEnginesReadyHeadline => 'OCR and translator working';
  @override
  String get consoleEnginesReadyBody =>
      'Here you can see where everything is stored, the cycle counters and the '
      'event log. It is the first place to look when something stops working.';
  @override
  String get consoleEnginesTip =>
      'The log keeps the last 400 events with their time.';
  @override
  String consoleAboutHeadline(String version, String author) =>
      'Version $version · $author';
  @override
  String get consoleAboutBody =>
      'Project details and the folder where Traducy stores everything. Links '
      'are copied to the clipboard instead of opened: pulling a browser over '
      'the game gets in the way more than it helps.';
  @override
  String get consoleAboutTip1 =>
      'Paste the repository link in your browser to see the code.';
  @override
  String get consoleAboutTip2 =>
      'If something is broken, the issues link is the place to say so.';
  @override
  String get consoleWaitingTitle => 'What you can do here';
  @override
  String get consoleFeedEmpty => 'Nothing has happened here yet.';
}
