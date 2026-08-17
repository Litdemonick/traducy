import 'panel_strings.dart';

/// Textos del panel en español.
class PanelStringsEs extends PanelStrings {
  const PanelStringsEs();

  @override
  String get resizeHint =>
      'Arrastra cualquier borde para redimensionar · doble clic para el tamaño '
      'por defecto';
  @override
  String get pause => 'Pausar';
  @override
  String get translate => 'Traducir';
  @override
  String get understood => 'Entendido';

  @override
  String stepNumber(int number, String title) => '$number. $title';
  @override
  String get stepWindowsOcrTitle => 'Motor de OCR: el que trae Windows';
  @override
  String get stepWindowsOcrProblem =>
      'El OCR de Windows no puede leer este idioma.';
  @override
  String get stepWindowsOcrHint =>
      'No hay nada que instalar ni nada que cambiar en tu Windows. Si el idioma '
      'del juego no está entre los que reconoce el sistema, pasa a Tesseract: '
      'sus paquetes se guardan dentro de la carpeta de Traducy.';
  @override
  String get useTesseract => 'Usar Tesseract';
  @override
  String get checkAgain => 'Volver a comprobar';
  @override
  String get stepTesseractTitle =>
      'Instalar Tesseract, el motor que lee el texto';
  @override
  String get stepTesseractProblem =>
      'Falta Tesseract: sin él no se puede leer el texto de la pantalla.';
  @override
  String get stepTesseractHint =>
      'Pulsa el botón y acepta la instalación en la ventana que se abre. O '
      'cambia al OCR de Windows, que ya viene con el sistema y no hay que '
      'instalar.';
  @override
  String get installTesseract => 'Instalar Tesseract';
  @override
  String get useWindowsOcr => 'Usar el de Windows';
  @override
  String get stepLanguageTitle => 'Descargar el idioma del juego';
  @override
  String stepLanguageProblem(String language) =>
      'Falta el idioma "$language" del OCR.';
  @override
  String get stepLanguageHint =>
      'Tesseract necesita un paquete por cada escritura que lee. Se descarga en '
      'la carpeta de Traducy, sin pedir permisos de administrador.';
  @override
  String downloadLanguage(String language) => 'Descargar $language';
  @override
  String get stepRegionTitle => 'Marcar la zona donde aparece el texto';
  @override
  String get stepRegionProblem => 'No hay una zona de captura válida todavía.';
  @override
  String get stepRegionHint =>
      'Pulsa "Detectar el juego" en la pestaña Zona, o coloca una banda en la '
      'parte baja de la pantalla y ajústala sobre el texto del juego.';
  @override
  String get useBottomBand => 'Usar la banda inferior';
  @override
  String get stepRunTitle =>
      'Pulsar Traducir y pasar a modo juego con Ctrl+Alt+T';
  @override
  String get stepRunProblem => 'Todo listo, pero la traducción está parada.';
  @override
  String get stepRunHint =>
      'Pulsa Traducir. Recuerda tener el juego en modo ventana: la pantalla '
      'completa exclusiva no se puede capturar.';
  @override
  String get translateNow => 'Traducir ahora';
  @override
  String downloadingLanguage(String language, String progress) =>
      'Descargando $language...  $progress';

  @override
  String get activateSection => 'Activar sobre la pantalla';
  @override
  String get activateHelp =>
      'Los dos vienen desactivados a propósito: así nada aparece sobre el juego '
      'sin que lo pidas. Actívalos para colocarlos, y desactívalos al terminar. '
      'Se mueven por su barra de título y se redimensionan por los tiradores '
      'del borde; el interior deja pasar los clics al juego.';
  @override
  String get activateRegionLabel => 'Activar zona de captura';
  @override
  String get activateRegionDescription =>
      'Muestra el rectángulo verde para situarlo sobre el texto del juego.';
  @override
  String get activateSubtitleLabel => 'Activar caja de subtítulos';
  @override
  String get activateSubtitleDescription =>
      'Muestra el marco naranja y un texto de ejemplo para colocarlo y darle '
      'estilo. Apagado, no aparece nada hasta que hay traducción.';
  @override
  String get captureZoneSection => 'Zona de captura';
  @override
  String get captureZoneHelp =>
      'Lo más directo es detectar el juego: la zona se coloca sola en su parte '
      'baja y se mueve con la ventana. Si prefieres situarla a mano, usa los '
      'botones de abajo y ajusta el rectángulo verde.';
  @override
  String get detectGame => 'Detectar el juego';
  @override
  String anchoredTo(String title) => 'Anclada a "$title"';
  @override
  String waitingFor(String title) => 'Esperando "$title" (no está abierta)';
  @override
  String get unanchor => 'Desanclar';
  @override
  String get bottomBand => 'Banda inferior';
  @override
  String get fullScreen => 'Pantalla completa';
  @override
  String get regionLockedLabel => 'Zona bloqueada';
  @override
  String get regionLockedOn => 'No se puede mover ni redimensionar.';
  @override
  String get regionLockedOff => 'Se puede arrastrar y redimensionar.';
  @override
  String get subtitleLockedLabel => 'Caja de subtítulos bloqueada';
  @override
  String get subtitleLockedSubtitle => 'Candado independiente del de la zona.';
  @override
  String get metricsRegionTitle =>
      'Zona de captura · píxeles reales de pantalla';
  @override
  String get metricsSubtitleTitle =>
      'Caja de subtítulos · píxeles de la ventana';
  @override
  String get metricX => 'X';
  @override
  String get metricY => 'Y';
  @override
  String get metricWidth => 'Ancho';
  @override
  String get metricHeight => 'Alto';
  @override
  String get zoneTooSmall => 'La zona es demasiado pequeña para leer texto.';
  @override
  String get zoneTooSmallHint =>
      'Pulsa "Banda inferior" o agranda el rectángulo verde.';
  @override
  String get followWindowSection => 'Seguir una ventana';
  @override
  String get followWindowHelp =>
      'Ancla la zona a una ventana concreta: si mueves el juego, la zona lo '
      'acompaña. Se vuelve a enganchar sola cuando el juego se reabre.';
  @override
  String followingWindow(String title) => 'Siguiendo: $title';
  @override
  String get fixedZone => 'Zona fija en la pantalla';
  @override
  String get refreshWindowList => 'Actualizar la lista de ventanas';
  @override
  String get stopFollowing => 'Dejar de seguir';
  @override
  String get pressRefreshToList =>
      'Pulsa actualizar para listar las ventanas abiertas.';
  @override
  String get follow => 'Seguir';
  @override
  String get overlayWindowSection => 'Ventana del overlay';
  @override
  String get overlayExcluded => 'El overlay está excluido de la captura.';
  @override
  String get overlayExcludedHint =>
      'Los subtítulos no se releerán a sí mismos, así que puedes colocarlos '
      'donde quieras.';
  @override
  String get overlayNotExcluded =>
      'Este Windows no permite excluir el overlay de la captura.';
  @override
  String get overlayNotExcludedHint =>
      'Mantén la caja de subtítulos FUERA del rectángulo verde para que el OCR '
      'no lea su propia traducción.';
  @override
  String get subtitleOverlaps =>
      'La caja de subtítulos se solapa con la zona de captura.';
  @override
  String get subtitleOverlapsHint =>
      'Muévela fuera del rectángulo verde para evitar un bucle.';
  @override
  String get startInConfigLabel => 'Abrir en modo configuración';
  @override
  String get startInConfigSubtitle =>
      'Si se desactiva, Traducy arranca directo en modo juego.';
  @override
  String get playWithPanelLabel => 'Poder jugar con el panel abierto';
  @override
  String get playWithPanelSubtitle =>
      'Los clics pasan al juego salvo cuando el cursor está sobre el panel o '
      'las cajas. Desactívalo si algún clic no responde bien.';

  @override
  String get ocrEngineSection => 'Motor de OCR (lo que lee la pantalla)';
  @override
  String get ocrEngineHelp =>
      'El de Windows viene con el sistema: es gratis, no hay nada que instalar, '
      'no sale nada del equipo y acierta más sobre capturas de pantalla, sobre '
      'todo en japonés. Necesita que el idioma esté añadido en Windows. '
      'Tesseract funciona en cualquier equipo y trae sus propios paquetes, que '
      'Traducy descarga sin permisos de administrador.';
  @override
  String windowsRecognizes(String languages) => 'Windows reconoce: $languages';
  @override
  String get windowsMissingLanguage =>
      'Windows no tiene el idioma pedido. Añádelo en Configuración → Hora e '
      'idioma → Idioma y región, o cambia a Tesseract.';
  @override
  String get checkEnginesFirst =>
      'Comprueba los motores en Diagnóstico para saber qué idiomas reconoce '
      'este Windows.';
  @override
  String get gameLanguageSection => 'Idioma del juego (lo que se lee)';
  @override
  String get gameLanguageHelp =>
      'El OCR necesita saber qué escritura leer. Elegir aquí "Japonés" '
      'configura a la vez el paquete de OCR y el idioma de origen.';
  @override
  String get scriptToRecognize => 'Escritura a reconocer';
  @override
  String get notInstalledSuffix => '  (no instalado)';
  @override
  String get autoDetectLabel => 'Detectar idioma automáticamente al traducir';
  @override
  String get autoDetectOn => 'El traductor decide el idioma de origen.';
  @override
  String autoDetectOff(String language) =>
      'Se envía "$language" como idioma de origen.';
  @override
  String get translateToSection => 'Traducir a';
  @override
  String get targetLanguageLabel => 'Idioma de destino';
  @override
  String get translatorSection => 'Motor de traducción';
  @override
  String get translatorLabel => 'Motor';
  @override
  String get translatorGoogle => 'Google Traductor — gratis, sin clave';
  @override
  String get translatorClaude => 'Claude — máxima calidad (API key)';
  @override
  String get translatorDeepl => 'DeepL — muy buena calidad (API key)';
  @override
  String get translatorLibre => 'LibreTranslate — servidor propio';
  @override
  String get translatorNone => 'Sin traducir — solo mostrar el original';
  @override
  String get claudeKeyLabel => 'API key de Claude';
  @override
  String get modelLabel => 'Modelo';
  @override
  String get claudeHelp =>
      'Traduce entendiendo el contexto del juego: mantiene el tono y no '
      'destroza los nombres propios. Es de pago por uso.';
  @override
  String get deeplKeyLabel => 'API key de DeepL';
  @override
  String get deeplKeyHint => 'Las claves gratuitas terminan en :fx';
  @override
  String get libreUrlLabel => 'URL de LibreTranslate';
  @override
  String get glossarySection => 'Glosario';
  @override
  String get glossaryHelp =>
      'Términos que no deben traducirse o que tienen una traducción fija. Una '
      'línea por entrada. Solo lo aplica el motor Claude.';
  @override
  String get glossaryLabel => 'Glosario';

  @override
  String get textSection => 'Texto';
  @override
  String get fontSizeLabel => 'Tamaño';
  @override
  String get lineHeightLabel => 'Altura de línea';
  @override
  String get letterSpacingLabel => 'Espaciado';
  @override
  String get maxLinesLabel => 'Líneas máximas';
  @override
  String get historyLabel => 'Historial en la caja';
  @override
  String get historyOn =>
      'Se ven también las líneas anteriores, con scroll. Activa la caja para '
      'poder subir a leerlas con la rueda.';
  @override
  String get historyOff => 'Solo la última línea traducida.';
  @override
  String get rememberedLinesLabel => 'Líneas recordadas';
  @override
  String get clearHistory => 'Vaciar el historial';
  @override
  String get autoFitLabel => 'Ajustar el texto a la caja';
  @override
  String get autoFitOn =>
      'La letra se encoge lo necesario para que entre el texto entero.';
  @override
  String get autoFitOff => 'Tamaño fijo: el texto largo se recorta.';
  @override
  String get minShrinkLabel => 'Encogido máximo';
  @override
  String get minShrinkHelp =>
      'Hasta dónde puede encogerse la letra. Un texto que entra pero no se '
      'puede leer no sirve, así que por debajo de este límite se recorta en '
      'lugar de seguir reduciendo.';
  @override
  String get boldLabel => 'Negrita';
  @override
  String get italicLabel => 'Cursiva';
  @override
  String get fontLabel => 'Fuente';
  @override
  String get readabilitySection => 'Legibilidad';
  @override
  String get readabilityHelp =>
      'El contorno es lo que mantiene el texto legible sobre cualquier escena; '
      'el fondo semitransparente ayuda en fondos muy movidos.';
  @override
  String get outlineWidthLabel => 'Grosor contorno';
  @override
  String get backgroundOpacityLabel => 'Opacidad fondo';
  @override
  String get cornerRadiusLabel => 'Redondeo';
  @override
  String get paddingLabel => 'Margen interno';
  @override
  String get shadowLabel => 'Sombra';
  @override
  String get showOriginalLabel => 'Mostrar también el texto original';
  @override
  String get showOriginalSubtitle =>
      'Útil para aprender el idioma o revisar el OCR.';
  @override
  String get colorsSection => 'Colores';
  @override
  String get textColorLabel => 'Color del texto';
  @override
  String get outlineColorLabel => 'Color del contorno';
  @override
  String get backgroundColorLabel => 'Color del fondo';

  @override
  String get frequencySection => 'Frecuencia';
  @override
  String get frequencyHelp =>
      'Intervalo entre capturas. Más bajo responde antes pero consume más CPU y '
      'más cuota de traducción.';
  @override
  String get intervalLabel => 'Intervalo';
  @override
  String capturesPerSecond(String value) => '≈ $value capturas por segundo';
  @override
  String get minChangeLabel => 'Cambio mínimo';
  @override
  String get minChangeHelp =>
      'Cuánto tiene que cambiar la zona para volver a leerla. Bájalo si no '
      'detecta diálogos nuevos; súbelo si traduce de más en escenas con fondos '
      'animados.';
  @override
  String get stabilityLabel => 'Estabilidad';
  @override
  String get stabilityFramesSuffix => ' fot.';
  @override
  String get stabilityHelp =>
      'Fotogramas con el mismo texto antes de traducir. Súbelo si el juego '
      'escribe el diálogo letra a letra.';
  @override
  String get holdLabel => 'Permanencia';
  @override
  String get holdHelp =>
      'Tiempo que el subtítulo sigue en pantalla cuando ya no se detecta texto.';
  @override
  String get preprocessSection => 'Preparación de la imagen';
  @override
  String get preprocessHelp =>
      'Un buen preprocesado sube la precisión del OCR más que cambiar de motor. '
      'La escala es el ajuste con más impacto.';
  @override
  String get scaleLabel => 'Escala';
  @override
  String get contrastLabel => 'Contraste';
  @override
  String get binarizeLabel => 'Binarizar';
  @override
  String get grayscaleLabel => 'Escala de grises';
  @override
  String get invertLabel => 'Invertir';
  @override
  String get denoiseLabel => 'Reducir ruido';
  @override
  String get timeoutsSection => 'Tiempos de espera';
  @override
  String get timeoutsHelp =>
      'Pasado este tiempo se abandona la etapa en lugar de dejar el ciclo '
      'colgado.';
  @override
  String get ocrLabel => 'OCR';
  @override
  String get translationLabel => 'Traducción';

  @override
  String get enginesSection => 'Estado de los motores';
  @override
  String get check => 'Comprobar';
  @override
  String get testNow => 'Probar ahora';
  @override
  String get pathsSection => 'Rutas';
  @override
  String get pathsHelp =>
      'Los idiomas que descarga Traducy se guardan en su propia carpeta, no en '
      'la de Tesseract.';
  @override
  String get tesseractExeLabel =>
      'Ejecutable de Tesseract (vacío = autodetectar)';
  @override
  String get tesseractExeHint =>
      r'C:\Program Files\Tesseract-OCR\tesseract.exe';
  @override
  String get tessdataFolderLabel =>
      'Carpeta de idiomas descargados (vacío = por defecto)';
  @override
  String get settingsFileLabel => 'Ajustes';
  @override
  String get languagesFolderLabel => 'Idiomas';
  @override
  String get statsSection => 'Contadores';
  @override
  String get statFrames => 'Fotogramas';
  @override
  String get statOcrRuns => 'Pasadas de OCR';
  @override
  String get statTranslations => 'Traducciones';
  @override
  String get statCacheHits => 'Aciertos de caché';
  @override
  String get statSkipped => 'Saltados sin cambios';
  @override
  String get statCapture => 'Captura';
  @override
  String get statPreprocess => 'Preprocesado';
  @override
  String get statOcr => 'OCR';
  @override
  String get statTranslation => 'Traducción';
  @override
  String get statDetectedLanguage => 'Idioma detectado';
  @override
  String get logSection => 'Registro';
  @override
  String get clearLog => 'Limpiar registro';
  @override
  String get shortcutsSection => 'Atajos de teclado';
  @override
  String get shortcutPanel => 'Mostrar u ocultar el panel';
  @override
  String get shortcutPause => 'Pausar o reanudar';
  @override
  String get shortcutSubtitles => 'Mostrar u ocultar los subtítulos';
  @override
  String healthReady(String engine) => '$engine: listo';
  @override
  String healthIssue(String engine, String issue) => '$engine: $issue';
  @override
  String healthChecking(String engine) => '$engine: comprobando…';
  @override
  String healthUnchecked(String engine) => '$engine: sin comprobar';
  @override
  String get ocrEngineWindowsName => 'OCR (Windows)';
  @override
  String get ocrEngineTesseractName => 'OCR (Tesseract)';

  @override
  String get pipelineRunning => 'En marcha';
  @override
  String get pipelinePaused => 'En pausa';
  @override
  String get pipelineStopped => 'Detenido';
  @override
  String get pipelineDefineZone => 'Define la zona de captura';
  @override
  String get pipelineDefineZoneHint =>
      'Arrastra el rectángulo sobre el texto del juego.';
  @override
  String get pipelineCaptureFailed => 'No se pudo capturar la pantalla.';
  @override
  String get pipelineCaptureFailedHint =>
      'Comprueba que la zona esté dentro de un monitor activo.';
  @override
  String get pipelineBlackFrame => 'La zona se captura en negro';
  @override
  String get pipelineBlackFrameHint =>
      'Pon el juego en modo ventana o sin bordes.';
  @override
  String get pipelineFlatFrame => 'La zona no ve texto (imagen plana)';
  @override
  String get pipelineFlatFrameHint =>
      'Comprueba que el rectángulo esté encima del texto del juego y que el juego esté en modo ventana o sin bordes.';
  @override
  String get pipelinePrepFailed => 'Fallo al preparar la imagen.';
  @override
  String get pipelinePrepFailedHint =>
      'Prueba a bajar la escala de preprocesado.';
  @override
  String get pipelineNoText => 'Sin texto en la zona';
  @override
  String get pipelineAlreadyTranslated => 'Texto ya traducido';
  @override
  String get pipelineWaitingStable => 'Esperando texto estable';
  @override
  String get pipelineTranslated => 'Traducido';
  @override
  String get pipelineTranslatedCached => 'Traducido (caché)';
  @override
  String pipelineUnchanged(String percent) => 'Sin cambios ($percent %)';
  @override
  String pipelineAutoPaused(int errors, String message) =>
      'Pausado tras $errors errores: $message';
  @override
  String get pipelineAutoPausedHint => 'Corrige el problema y pulsa Reanudar.';
  @override
  String pipelineUnexpected(String error) => 'Error inesperado: $error';
  @override
  String get msgPassthroughOn => 'Puedes jugar con el panel abierto';
  @override
  String get msgPassthroughOnDetail =>
      'Los clics pasan al juego salvo sobre el panel y las cajas.';
  @override
  String get msgPassthroughOff => 'El panel captura los clics';
  @override
  String get msgPassthroughOffDetail =>
      'Mientras el panel esté visible, la ventana recibe todos los clics.';
  @override
  String get msgSubtitlesVisible => 'Subtítulos visibles';
  @override
  String get msgSubtitlesHidden => 'Subtítulos ocultos';
  @override
  String get msgToggleWithH => 'Ctrl+Alt+H para alternar.';
  @override
  String get msgZoneLocked => 'La zona está bloqueada';
  @override
  String get msgZoneLockedDetail =>
      'Quita el candado de su barra para poder cambiarla.';
  @override
  String get msgRegionOn => 'Zona de captura activada';
  @override
  String get msgRegionOff => 'Zona de captura desactivada';
  @override
  String get msgRegionOnDetail =>
      'Arrastra su barra de título para moverla y los tiradores del borde para redimensionarla.';
  @override
  String get msgRegionOffDetail =>
      'La zona sigue capturándose; solo se ha ocultado el marco.';
  @override
  String get msgSubtitleBoxOn => 'Caja de subtítulos activada';
  @override
  String get msgSubtitleBoxOff => 'Caja de subtítulos desactivada';
  @override
  String get msgSubtitleBoxOnDetail =>
      'Mueve la caja por su barra; el interior deja pasar los clics.';
  @override
  String get msgSubtitleBoxOffDetail =>
      'El texto traducido se sigue mostrando.';
  @override
  String get msgPanelSizeReset => 'Tamaño del panel restablecido';
  @override
  String get msgRegionLocked => 'Zona de captura bloqueada';
  @override
  String get msgRegionUnlocked => 'Zona de captura desbloqueada';
  @override
  String get msgSubtitleLocked => 'Caja de subtítulos bloqueada';
  @override
  String get msgSubtitleUnlocked => 'Caja de subtítulos libre';
  @override
  String get msgLockedDetail => 'Ya no se puede mover ni redimensionar.';
  @override
  String get msgUnlockedDetail => 'Arrastra su barra de título para moverla.';
  @override
  String msgGameLanguage(String label) => 'Idioma del juego: $label';
  @override
  String msgCheckingPack(String code) =>
      'Comprobando si el OCR tiene el paquete "$code"...';
  @override
  String msgTargetLanguage(String label) => 'Se traducirá a $label';
  @override
  String get msgHistoryCleared => 'Historial de subtítulos vaciado';
  @override
  String get msgAutoUpdateOn => 'Las versiones nuevas se instalarán solas';
  @override
  String get msgAutoUpdateOff =>
      'Las versiones nuevas esperarán a que pulses Actualizar';
  @override
  String get msgNoGameWindow => 'No se encontró ninguna ventana de juego';
  @override
  String get msgNoGameWindowDetail =>
      'Abre el juego en modo ventana o sin bordes y vuelve a pulsar Detectar el juego.';
  @override
  String msgFollowing(String title) => 'Siguiendo a "$title"';
  @override
  String get msgFollowingDetail =>
      'La zona está en la parte baja de esa ventana y se mueve con ella. Actívala en Zona si quieres ajustarla.';
  @override
  String get msgNotFollowing => 'La zona ya no sigue a ninguna ventana';
  @override
  String msgWindowLost(String title) => 'No encuentro la ventana "$title"';
  @override
  String get msgWindowLostDetail =>
      'La zona se queda donde estaba. Abre el juego, o pulsa Detectar el juego para engancharla a otra ventana.';
  @override
  String get msgDownloadInProgress => 'Ya hay una descarga en curso';
  @override
  String msgDownloadingLanguage(String language) =>
      'Descargando el idioma "$language"...';
  @override
  String msgLanguageInstalled(String language) =>
      'Idioma "$language" instalado';
  @override
  String msgSavedIn(String path) => 'Guardado en $path';
  @override
  String msgDownloadFailed(String language) =>
      'No se pudo descargar "$language"';
  @override
  String get msgLanguageFolderChanged => 'Carpeta de idiomas cambiada';
  @override
  String get msgTesseractInstallOpened =>
      'Instalación de Tesseract abierta en PowerShell';
  @override
  String get msgTesseractInstallOpenedDetail =>
      'Cuando termine, pulsa "Volver a comprobar" en el panel.';
  @override
  String get msgInstallerFailed => 'No se pudo abrir el instalador';
  @override
  String get msgInstallerFailedDetail =>
      'Ejecuta a mano: winget install UB-Mannheim.TesseractOCR';
  @override
  String get msgCheckingUpdates => 'Comprobando actualizaciones...';
  @override
  String get msgUpToDate => 'Ya tienes la última versión';
  @override
  String msgNewVersion(String version) => 'Hay una versión nueva: $version';
  @override
  String msgNewVersionAuto(String size) =>
      'Traducy se ha detenido y se está actualizando solo ($size).';
  @override
  String msgNewVersionManual(String size) =>
      'Traducy se ha detenido y quedará bloqueado hasta actualizar ($size).';
  @override
  String get msgUpdateFailed => 'No se pudo actualizar';
  @override
  String get msgTesseractNotFound => 'No se encuentra Tesseract en este equipo';
  @override
  String get msgTesseractNotFoundDetail =>
      'Pulsa "Instalar Tesseract" en la guía de arriba.';
  @override
  String get msgTesseractFound => 'Tesseract detectado';
  @override
  String msgOcrReady(String languages) =>
      'Todo listo: OCR "$languages" disponible';
  @override
  String msgInstalledLanguages(String languages) =>
      'Idiomas instalados: $languages';
  @override
  String msgMissingOcrLanguage(String languages) =>
      'Falta el idioma "$languages" del OCR';
  @override
  String get msgDownloadFromGuide => 'Descárgalo desde la guía de arriba.';
  @override
  String msgOrUseInstalled(String languages) =>
      'Puedes descargarlo desde la guía, o usar uno de los que ya tienes: $languages.';
  @override
  String get msgFallbackToTesseract =>
      'Se usará Tesseract para leer la pantalla';
  @override
  String msgFallbackToTesseractDetail(String reason) =>
      'El OCR de Windows no sirve aquí: $reason. Puedes volver a intentarlo desde la pestaña Idiomas cuando lo añadas.';
  @override
  String get msgReasonNoLanguage =>
      'Windows no tiene instalado el idioma que hace falta';
  @override
  String get msgReasonNoComponent =>
      'este Windows no trae el componente de OCR';
  @override
  String get msgNoOcrComponent => 'Este Windows no trae el componente de OCR';
  @override
  String get msgSwitchToTesseract =>
      'Cambia a Tesseract en la pestaña Idiomas.';
  @override
  String msgWindowsCannotRead(String language) =>
      'Windows no reconoce "$language"';
  @override
  String msgWindowsCannotReadDetail(String languages) =>
      'Reconoce: $languages. Usa Tesseract para este idioma: se descarga dentro de Traducy y no cambia nada de tu Windows.';
  @override
  String msgWindowsOcrReady(String tag) => 'OCR de Windows listo ($tag)';
  @override
  String get msgWindowsOcrReadyDetail =>
      'Sin instalar nada y sin salir del equipo.';
  @override
  String get msgCannotTranslateYet => 'No se puede traducir todavía';
  @override
  String get msgBottomBandSet => 'Se ha puesto una zona en la banda inferior';
  @override
  String get msgBottomBandSetDetail =>
      'Ajústala si el texto del juego aparece en otro sitio.';
  @override
  String get msgTranslating => 'Traduciendo';
  @override
  String get msgTranslatingDetail =>
      'Ctrl+Alt+T oculta el panel · Ctrl+Alt+P pausa';
  @override
  String get msgTranslationStopped => 'Traducción detenida';
  @override
  String get msgTranslationResumed => 'Traducción reanudada';
  @override
  String get msgTranslationPaused => 'Traducción en pausa';
  @override
  String get msgToggleWithP => 'Ctrl+Alt+P para alternar.';
  @override
  String get msgTestingCapture => 'Probando una captura...';
  @override
  String msgTestFailed(String message) => 'La prueba falló: $message';
  @override
  String msgTestDone(String message) => 'Prueba completada: $message';
  @override
  String msgTestTimings(int ocrMs, int translateMs) =>
      'OCR $ocrMs ms · traducción $translateMs ms';
  @override
  String msgUnexpectedError(String error) => 'Fallo inesperado: $error';
  @override
  String msgStartFailed(String error) => 'No se pudo iniciar Traducy: $error';
  @override
  String get msgCheckingNewVersion => 'Comprobando si hay una versión nueva...';
  @override
  String msgLatestVersion(String version) =>
      'Estás en la última versión ($version).';
  @override
  String msgVersionAvailable(String version) => 'Versión $version disponible.';
  @override
  String msgDownloadingVersion(String version) =>
      'Descargando la versión $version...';
  @override
  String msgInstallingVersion(String version) =>
      'Instalando la versión $version. Traducy se cerrará y volverá a abrirse.';
  @override
  String msgDownloadUnexpected(String language, String error) =>
      'Fallo inesperado al descargar "$language": $error';
  @override
  String msgOcrCheckFailed(String error) => 'Fallo al comprobar el OCR: $error';
  @override
  String msgTranslatorCheckFailed(String error) =>
      'Fallo al comprobar el traductor: $error';
  @override
  String get consoleNoZoneHeadline => 'Sin zona de captura';
  @override
  String get consoleNoZoneBody =>
      'Traducy no sabe todavía de qué parte de la pantalla leer. Pulsa '
      '"Detectar el juego" y la zona se coloca sola donde suelen estar los '
      'diálogos.';
  @override
  String get consoleNoZoneTip1 =>
      'Activa "Activar zona de captura" para ver el rectángulo verde.';
  @override
  String get consoleNoZoneTip2 =>
      'Se mueve por su barra de título; el interior deja pasar los clics.';
  @override
  String get consoleOverlapHeadline => 'Los subtítulos se solapan con la zona';
  @override
  String get consoleOverlapBody =>
      'El OCR leería su propia traducción y entraría en bucle. Mueve la caja de '
      'subtítulos fuera del rectángulo verde.';
  @override
  String consoleZoneReadyHeadline(int width, int height) =>
      'Zona lista: $width×$height px';
  @override
  String consoleZoneFollowBody(String title) =>
      'La zona sigue a la ventana "$title": si mueves el juego, la zona lo '
      'acompaña.';
  @override
  String get consoleZoneFixedBody =>
      'Zona fija en la pantalla. Cuanto más ceñida al texto, mejor lee el OCR y '
      'menos CPU gasta.';
  @override
  String get consoleZoneTipLock =>
      'Cuando la tengas puesta, ciérrala con el candado de su barra.';
  @override
  String get consoleZoneTipLocked =>
      'Está bloqueada: quita el candado si quieres moverla.';
  @override
  String consoleMissingLanguageHeadline(String languages) =>
      'Falta el idioma "$languages"';
  @override
  String get consoleMissingLanguageBody =>
      'El OCR necesita un paquete por cada escritura que lee. Púlsalo en el '
      'aviso de arriba y se descarga solo, sin permisos de administrador.';
  @override
  String consoleLanguagesReadyHeadline(String source, String target) =>
      'Traduciendo $source → $target';
  @override
  String get consoleLanguagesAutoBody =>
      'El idioma de origen lo decide el traductor. Es lo que mejor funciona '
      'cuando el juego mezcla idiomas.';
  @override
  String consoleLanguagesFixedBody(String source) =>
      'Se envía "$source" como idioma de origen, sin dejar que el traductor lo '
      'adivine.';
  @override
  String get consoleLanguagesTipEngine =>
      'El motor de traducción se elige más abajo; Claude es el que mejor '
      'entiende el contexto de un juego.';
  @override
  String get consoleStyleHeadline => 'Aspecto de los subtítulos';
  @override
  String get consoleStyleBody =>
      'Los cambios se ven al momento en la caja. Activa la caja de subtítulos '
      'en la pestaña Zona para verlos sin esperar a que haya traducción.';
  @override
  String get consoleStyleTip1 =>
      'El contorno mantiene el texto legible sobre cualquier escena.';
  @override
  String get consoleStyleTip2 =>
      'Con el historial activado, la caja guarda las líneas anteriores.';
  @override
  String get consolePerformanceHeadline => 'Rendimiento del ciclo';
  @override
  String consolePerformanceBody(int frames, int skipped) =>
      '$frames fotogramas procesados, $skipped saltados por no haber cambios. '
      'Cuantos más se salten, menos CPU y menos cuota se gasta.';
  @override
  String get consolePerformanceIdleBody =>
      'Sin datos todavía: pulsa Traducir y vuelve aquí para ver cuánto tarda '
      'cada etapa.';
  @override
  String get consolePerformanceTip1 =>
      'Si no detecta diálogos nuevos, baja "Cambio mínimo".';
  @override
  String get consolePerformanceTip2 =>
      'La escala del preprocesado es lo que más sube la precisión del OCR.';
  @override
  String get consoleEnginesPendingHeadline =>
      'Comprobación de motores pendiente';
  @override
  String get consoleEnginesPendingBody =>
      'Pulsa "Comprobar" para ver si el OCR y el traductor responden. "Probar '
      'ahora" hace una captura completa y dice cuánto tardó cada etapa.';
  @override
  String get consoleEnginesReadyHeadline => 'OCR y traductor operativos';
  @override
  String get consoleEnginesReadyBody =>
      'Aquí ves las rutas donde se guarda todo, los contadores del ciclo y el '
      'registro de eventos. Es lo primero que hay que mirar si algo deja de '
      'funcionar.';
  @override
  String get consoleEnginesTip =>
      'El registro guarda los últimos 400 eventos con su hora.';
  @override
  String consoleAboutHeadline(String version, String author) =>
      'Versión $version · $author';
  @override
  String get consoleAboutBody =>
      'Datos del proyecto y la carpeta donde Traducy guarda todo. Los enlaces '
      'se copian al portapapeles en vez de abrirse: sacar un navegador por '
      'encima del juego estorba más de lo que ayuda.';
  @override
  String get consoleAboutTip1 =>
      'Pega el enlace del repositorio en el navegador para ver el código.';
  @override
  String get consoleAboutTip2 =>
      'Si algo no funciona, el enlace de incidencias es el sitio donde '
      'contarlo.';
  @override
  String get consoleWaitingTitle => 'Qué se puede hacer aquí';
  @override
  String get consoleFeedEmpty => 'Todavía no ha pasado nada por aquí.';
}
