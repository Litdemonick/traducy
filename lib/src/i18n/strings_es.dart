import 'strings.dart';

/// Textos de la interfaz en espanol.
class StringsEs extends AppStrings {
  const StringsEs();

  @override
  String get localeCode => 'es';

  @override
  String get appTagline => 'Traductor de pantalla en tiempo real';

  @override
  String get exit => 'Salir';

  @override
  String get retry => 'Reintentar';

  @override
  String get copy => 'Copiar';

  @override
  String get free => 'Libre';

  @override
  String get locked => 'Bloqueada';

  @override
  String get opacity => 'Opacidad';

  @override
  String get preparingOverlay => 'Preparando el overlay...';

  @override
  String get startupFailed => 'Traducy no pudo arrancar';

  @override
  String get captureZone => 'Zona de captura';

  @override
  String get subtitles => 'Subtitulos';

  @override
  String get subtitlePlaceholder => 'Aqui aparecera la traduccion';

  @override
  String get unlockToMove => 'Desbloquear para mover y redimensionar';

  @override
  String get lockInPlace => 'Bloquear en su sitio';

  @override
  String get minimizeTooltip =>
      'Minimizar. Su boton sigue en la barra de tareas: pulsalo para volver';

  @override
  String get gameModeTooltip =>
      'Modo juego: oculta Traducy y lo deja en segundo plano. Vuelve con su '
      'icono junto al reloj o con Ctrl+Alt+T';

  @override
  String get exitTooltip => 'Salir de Traducy';

  @override
  String get minimizedTitle => 'Traducy minimizado';

  @override
  String get minimizedDetail =>
      'Pulsa su boton en la barra de tareas para volver.';

  @override
  String get minimizeFailed => 'No se pudo minimizar';

  @override
  String get minimizeFailedDetail =>
      'Usa el ojo para pasar a modo juego, o Ctrl+Alt+T.';

  @override
  String get backgroundTitle => 'Traducy en segundo plano';

  @override
  String get backgroundDetail =>
      'Clic en su icono junto al reloj, o Ctrl+Alt+T, para volver.';

  @override
  String get backgroundFailed => 'No se pudo pasar a segundo plano';

  @override
  String get backgroundFailedDetail =>
      'Usa Ctrl+Alt+T para ocultar el panel mientras juegas.';

  @override
  String get trayTooltip =>
      'Traducy - clic para abrir, clic derecho para opciones';

  @override
  String get trayOpen => 'Abrir Traducy';

  @override
  String get trayTogglePause => 'Pausar o reanudar la traduccion';

  @override
  String get trayToggleSubtitles => 'Mostrar u ocultar los subtitulos';

  @override
  String get trayExit => 'Salir de Traducy';

  @override
  String get tabRegion => 'Zona';

  @override
  String get tabLanguages => 'Idiomas';

  @override
  String get tabStyle => 'Estilo';

  @override
  String get tabPerformance => 'Rendimiento';

  @override
  String get tabDiagnostics => 'Diagnostico';

  @override
  String get tabAbout => 'Acerca de';

  @override
  String get updates => 'Actualizaciones';

  @override
  String get checkNow => 'Comprobar';

  @override
  String get updateBlockExplanation =>
      'Al detectarse una version nueva, Traducy detiene la traduccion y queda '
      'bloqueado hasta actualizar: una version vieja funcionando a medias '
      'parece un fallo de la propia aplicacion.';

  @override
  String get updateManualHint =>
      'Descargala a mano desde la pagina de versiones.';

  @override
  String get updateRequiredTitle => 'Actualizacion necesaria';

  @override
  String get updateNow => 'Actualizar ahora';

  @override
  String get doNotClose => 'No cierres la aplicacion.';

  @override
  String get installingUpdate => 'Instalando la actualizacion';

  @override
  String get installingDetail =>
      'Traducy se va a cerrar y el instalador seguira solo. Al terminar se '
      'abrira la version nueva.';

  @override
  String get updateFailedTitle => 'No se pudo actualizar';

  @override
  String get updateAutomaticNotice =>
      'Se esta instalando sola. Puedes desactivar la actualizacion automatica en Diagnostico.';

  @override
  String get autoUpdateLabel => 'Actualizar automaticamente';

  @override
  String get autoUpdateOn =>
      'Las versiones nuevas se descargan e instalan solas.';

  @override
  String get autoUpdateOff =>
      'Las versiones nuevas esperan a que pulses Actualizar.';

  @override
  String get checkingUpdates => 'Comprobando actualizaciones';

  @override
  String get aboutTitle => 'Acerca de Traducy';

  @override
  String get aboutDescription =>
      'Marca una zona sobre el juego y Traducy lee el texto que aparece ahi, '
      'mostrando la traduccion como subtitulos por encima. No modifica el '
      'juego ni sus ficheros.';

  @override
  String get sectionProject => 'Proyecto';

  @override
  String get creator => 'Creador';

  @override
  String get repository => 'Repositorio';

  @override
  String get releases => 'Versiones';

  @override
  String get releasesValue => 'Descargas y notas de cada version';

  @override
  String get bugs => 'Fallos';

  @override
  String get bugsValue => 'Reportar un problema o pedir algo';

  @override
  String get version => 'Version';

  @override
  String get sectionStorage => 'Donde se guarda todo';

  @override
  String get storageBeside =>
      'Junto al programa, en la carpeta que elegiste al instalar. Ajustes, '
      'idiomas del OCR y actualizaciones descargadas.';

  @override
  String get storageUser => 'En la carpeta del usuario.';

  @override
  String get folder => 'Carpeta';

  @override
  String get sectionBuiltWith => 'Hecho con';

  @override
  String get copyLinkTooltip => 'Copiar el enlace';

  @override
  String get copyAuthorProfile => 'Perfil del creador';

  @override
  String get copyRepoLink => 'Enlace del repositorio';

  @override
  String get copyReleasesLink => 'Enlace de las versiones';

  @override
  String get copyIssuesLink => 'Enlace de incidencias';

  @override
  String get copyVersionNumber => 'Numero de version';

  @override
  String get copyDataPath => 'Ruta de los datos';

  @override
  String get uiLanguageAuto => 'Automatico';

  @override
  String get uiLanguageSpanish => 'Espanol';

  @override
  String get uiLanguageEnglish => 'Ingles';

  @override
  String get uiLanguageSection => 'Idioma de la aplicacion';

  @override
  String get uiLanguageHelp =>
      'En que idioma se ve Traducy. No tiene nada que ver con el idioma al que '
      'se traduce el juego, que se elige mas abajo. En automatico sigue al de '
      'Windows.';

  @override
  String installedVersion(String version) => 'Version instalada: $version';

  @override
  String updateAvailable(String version) => 'Version $version disponible';

  @override
  String updateAvailableHint(String size) =>
      'Se descargara el instalador ($size) y la version nueva se instalara '
      'encima de la actual conservando tus ajustes y los idiomas descargados.';

  @override
  String updateToVersion(String version) => 'Actualizar a $version';

  @override
  String updateRequiredBody(String version) =>
      'Hay una version nueva de Traducy ($version). La traduccion se ha '
      'detenido y la aplicacion queda bloqueada hasta que se instale.';

  @override
  String updateRequiredDetail(String size) =>
      'Se descargara el instalador ($size), Traducy se cerrara y la version '
      'nueva se instalara encima de la actual. Tus ajustes y los idiomas '
      'descargados se conservan.';

  @override
  String downloadingVersion(String version) => 'Descargando $version';

  @override
  String updateManualFrom(String url) =>
      'Tambien puedes descargarla a mano desde $url';

  @override
  String versionValue(String version, String numeric) =>
      '$version  -  compilacion $numeric';

  @override
  String copiedToClipboard(String what) => '$what copiado al portapapeles';

  @override
  String copyLinkOf(String name) => 'Enlace de $name';

  @override
  String uiLanguageChanged(String language) =>
      'Idioma de la aplicacion: $language';
}
