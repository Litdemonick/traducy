# Traducy

Traductor de pantalla en tiempo real para Windows. Marca una zona sobre el
juego, y Traducy lee el texto que aparece ahí y muestra la traducción como
subtítulos por encima, sin tocar el juego ni sus ficheros.

Pensado para jugar a juegos en japonés, chino, coreano, inglés o cualquier otro
idioma sin traducción oficial.

## Cómo funciona

```
Zona de captura ──▶ Captura GDI ──▶ Preprocesado ──▶ OCR ──▶ Traducción ──▶ Subtítulo
   (tú la marcas)     ~2 ms          otro isolate    Tesseract   caché+red      overlay
```

Tres decisiones sostienen el rendimiento:

- **Detección de cambios.** Antes de gastar un OCR se compara una huella de
  32×32 con la del fotograma anterior. Si el diálogo no ha cambiado, no se
  vuelve a leer ni a traducir. En una partida normal se salta el 80–95 % de los
  fotogramas.
- **Caché de traducciones.** Los juegos repiten muchísimo texto (menús, nombres
  de objetos, la misma línea mientras la lees). Lo repetido se resuelve al
  instante y sin gastar cuota.
- **Contrapresión.** Solo hay un ciclo activo a la vez. Si un fotograma tarda
  más que el intervalo, el siguiente se descarta en lugar de acumularse en una
  cola que acabaría mostrando subtítulos con segundos de retraso.

## Requisitos

- Windows 10 versión 2004 o posterior (para que el overlay pueda excluirse de su
  propia captura; en versiones anteriores funciona, pero hay que mantener los
  subtítulos fuera de la zona de captura).
- **Tesseract OCR** instalado. Es el único requisito externo:

```powershell
winget install UB-Mannheim.TesseractOCR
```

Durante la instalación, en la pantalla de componentes, marca los **idiomas
adicionales** que vayas a leer (Japanese, Chinese, Korean…). Si ya lo tienes
instalado sin esos idiomas, puedes añadirlos después: descarga el fichero
`.traineddata` del idioma desde
[tessdata](https://github.com/tesseract-ocr/tessdata) y cópialo a
`C:\Program Files\Tesseract-OCR\tessdata\`.

Traducy detecta Tesseract automáticamente (PATH, rutas de instalación
habituales, o una carpeta `tesseract\` junto al ejecutable para uso portable).
Si no lo encuentra, puedes indicar la ruta a mano en **Diagnóstico**.

## Compilar y ejecutar

```powershell
flutter pub get
flutter run -d windows          # desarrollo
flutter build windows --release # ejecutable final
```

El ejecutable queda en `build\windows\x64\runner\Release\traducy.exe`.

## Primeros pasos

1. Abre el juego **en modo ventana** o **pantalla completa en ventana**. La
   pantalla completa exclusiva no se puede capturar con GDI; Traducy lo detecta
   y te avisa con un fotograma en negro.
2. Arranca Traducy. Se abre en modo configuración con el panel, que puedes
   arrastrar desde su cabecera a donde te estorbe menos.
3. En **Zona**, activa *Editar zona de captura*. Aparece el rectángulo verde:
   pulsa *Banda inferior* (donde casi todos los juegos ponen los diálogos) o
   *Pantalla completa*, ajústalo, y pulsa el candado de su barra para fijarlo.
   Desactiva la edición cuando termines.
4. En **Idiomas**, elige el idioma del juego (p. ej. Japonés) y el de destino
   (Español por defecto).
5. Pulsa **Traducir**.
6. Con `Ctrl+Alt+T` ocultas el panel y pasas a modo juego.

## El overlay no te bloquea el ratón

Traducy cubre toda la pantalla, pero **solo intercepta el ratón donde hay algo
con lo que interactuar**: el panel, las barras de título de las cajas y sus
tiradores de borde. Todo lo demás — incluido el interior del rectángulo verde y
el de los subtítulos — deja pasar los clics al programa de debajo, así que
puedes seguir jugando con los marcos puestos.

Además:

- Los marcos de edición **solo aparecen si los activas** desde la pestaña Zona.
  No salen solos encima del juego.
- Las cajas se mueven arrastrando su **barra de título** y se redimensionan por
  los **tiradores del borde**, igual que una ventana normal.
- El botón **–** de la cabecera minimiza Traducy a la barra de tareas.
  `Ctrl+Alt+T` lo recupera.
- Si algo no responde como esperas, desactiva *Poder jugar con el panel abierto*
  en Zona: la ventana pasa a capturar todos los clics mientras el panel esté
  visible, que es el comportamiento simple y predecible.

## En segundo plano (bandeja del sistema)

El botón **⌄** de la cabecera manda Traducy a segundo plano: la ventana se oculta
por completo y solo queda el icono en la bandeja del sistema (área de iconos
ocultos, junto al reloj).

- **Clic izquierdo** en el icono: vuelve a abrirlo.
- **Clic derecho**: menú con abrir, pausar o reanudar la traducción, mostrar u
  ocultar los subtítulos, y salir.
- `Ctrl+Alt+T` también lo recupera desde cualquier sitio.

Se usa ocultar y no minimizar a propósito: minimizar dejaría en la barra de
tareas el botón de una ventana que ocupa todo el escritorio, y eso estorba más
de lo que ayuda.

## Atajos globales

| Atajo | Acción |
|---|---|
| `Ctrl+Alt+T` | Mostrar / ocultar el panel de configuración |
| `Ctrl+Alt+P` | Pausar / reanudar la traducción |
| `Ctrl+Alt+H` | Ocultar / mostrar los subtítulos |

Funcionan aunque el juego tenga el foco. Si otro programa ya los tiene tomados,
Traducy lo registra en el diagnóstico y sigue funcionando desde el panel.

## Los dos candados

La zona de captura y la caja de subtítulos son independientes y **cada una tiene
su propio candado** en su barra de título:

- **Zona de captura** (verde): dónde se lee el texto.
- **Subtítulos** (naranja): dónde se muestra la traducción.

Bloquear una no bloquea la otra, así que puedes fijar la zona de lectura al
milímetro y seguir moviendo los subtítulos, o al contrario.

## Motores de traducción

| Motor | Clave | Notas |
|---|---|---|
| Google Traductor | No | Por defecto. Endpoint web público, sin configuración. Puede limitar la frecuencia si se abusa. |
| Claude | Sí | La mejor calidad para videojuegos: entiende el contexto, mantiene el tono y respeta los nombres propios. Admite glosario. De pago por uso. |
| DeepL | Sí | Muy buena calidad en prosa. Las claves gratuitas terminan en `:fx` y Traducy lo detecta solo. |
| LibreTranslate | Opcional | Servidor propio. La opción para traducir sin depender de terceros ni de internet. |
| Sin traducir | No | Muestra solo el texto reconocido. Útil para afinar el OCR. |

## Ajustar la precisión del OCR

Si el reconocimiento falla, la pestaña **Rendimiento** da más resultado que
cambiar de motor:

- **Escala** ×2 o ×3: Tesseract acierta mucho más con texto grande. Es el ajuste
  con más impacto.
- **Contraste**: súbelo con texto de bajo contraste sobre fondos con textura.
- **Binarizar**: pon un valor sobre 128 si el texto es de color plano sobre
  fondo plano. Estórbalo en fondos complejos, así que déjalo en 0 por defecto.
- **Invertir**: pruébalo con texto claro sobre fondo oscuro.
- **Reducir ruido**: útil con vídeo comprimido o escalado.

Ajusta la zona lo más ceñida posible al texto: cuanto menos fondo entre, mejor
lee el OCR y menos CPU consume.

## Problemas frecuentes

**Dice que el OCR no está disponible y no traduce.** Falta Tesseract. El panel
muestra un aviso rojo con un botón *Instalar con winget*; o hazlo a mano con el
comando de la sección Requisitos. El traductor y el OCR son piezas separadas:
que el traductor esté listo no sirve de nada si no hay nada reconocido que
traducir.

**Diagnosticar sin abrir el panel.** Ejecuta `flutter run -d windows --profile`
y mira la consola: al arrancar se vuelca el estado real (medidas del escritorio,
rectángulo de la ventana, si se pudo excluir de la captura, y si el OCR y el
traductor están listos). Es la vía rápida para saber qué falla.

**La zona sale en negro.** El juego está en pantalla completa exclusiva. Cambia
a "ventana" o "pantalla completa en ventana" en sus opciones de vídeo.

**Traduce sus propios subtítulos.** Ocurre solo en Windows anteriores a la
versión 2004, donde el overlay no puede excluirse de la captura. Mueve la caja
de subtítulos fuera del rectángulo verde; el panel te avisa cuando se solapan.

**El fondo del overlay es opaco.** Cambia **Zona → Transparencia** al modo
*Compatible*, que usa transparencia por color clave y funciona en cualquier
equipo.

**Traduce de más en escenas con animación de fondo.** Sube el *umbral de cambio*
en Rendimiento.

**Los subtítulos aparecen a medias.** Sube *estabilidad* a 3 o 4 fotogramas: el
juego escribe el diálogo letra a letra y Traducy espera a que el texto se
estabilice antes de traducir.

**Algún clic no responde con el panel abierto.** Desactiva *Poder jugar con el
panel abierto* en Zona: la ventana pasa a capturar todos los clics mientras el
panel está visible.

## Configuración

Se guarda en `%APPDATA%\Traducy\settings.json`, con escritura atómica. Si el
fichero se corrompe, Traducy lo aparta como `.corrupt-<fecha>` y arranca con los
valores de fábrica en lugar de quedarse inservible.

## Iconos y logo

El logo de partida es `assets/logo_traducy.jpg`. De él se derivan, con
`tools/make_icons.py`:

| Salida | Uso |
|---|---|
| `assets/logo_mark.png` | Símbolo suelto, transparente. Cabecera del panel. |
| `assets/logo_traducy.png` | Logo completo, transparente. Pantalla de arranque. |
| `assets/tray_icon.ico` | Icono de la bandeja del sistema. |
| `windows/runner/resources/app_icon.ico` | Ejecutable, barra de tareas, Alt+Tab y explorador. |

Los `.ico` llevan nueve tamaños (16 a 256 px) para que Windows tenga la versión
adecuada en cada sitio en lugar de reescalar una sola.

El JPEG original no tiene transparencia, así que el alfa se reconstruye de dos
formas distintas: el símbolo con una máscara de esquinas redondeadas cuyo radio
se **mide** sobre el propio arte (estimarlo dejaba fondo asomando en las
esquinas), y la palabra invirtiendo la mezcla alfa a partir del color de fondo y
del de la tinta, que da un texto nítido en lugar del halo gris que deja un
umbral simple.

Para regenerarlos tras cambiar el logo:

```powershell
python tools\make_icons.py
```

Solo necesita Pillow. Tras regenerar el `.ico` del runner hay que recompilar
para que Windows tome el icono nuevo.

## Crear el instalador para compartir

Con [Inno Setup 6](https://jrsoftware.org/isdl.php) instalado:

```powershell
flutter build windows --release
iscc installer	raducy.iss
```

Sale `installer\salida\TraducySetup-<version>.exe`, un único fichero que se
puede pasar a cualquiera. Lo que hace ese instalador:

- **Deja elegir la carpeta de instalación**, para poder ponerlo en otra unidad si
  el disco C: va justo.
- **Detecta una instalación previa** y actualiza en el mismo sitio en lugar de
  dejar dos copias. Si la versión instalada es más nueva, avisa antes de
  sobrescribirla.
- **Cierra Traducy si está abierto** antes de sustituir los ficheros: sin eso, la
  actualización falla con "fichero en uso".
- **Modo portátil** opcional: marca esa casilla y los ajustes y los idiomas se
  guardan en `datos\` dentro de la carpeta del programa, en lugar de en
  `%APPDATA%`. Útil para llevarlo en un USB o para tenerlo todo en una unidad
  concreta. La aplicación lo detecta por el fichero `portable.txt` que crea el
  instalador, y lo indica en Diagnóstico.
- **Español e inglés** en el asistente, con el logo de Traducy.
- **Avisa sobre Tesseract** antes de instalar, para que nadie se lleve la
  sorpresa de que la aplicación no traduce hasta instalarlo.

Al desinstalar se conservan los ajustes de `%APPDATA%\Traducy`: si se reinstala,
todo vuelve como estaba.

## Versiones

Para revisiones pequeñas y frecuentes el esquema es `MAYOR.MENOR.PARCHE` con un
sufijo de letras: `1.0.0.a`, `1.0.0.b`, … `1.0.0.z`, `1.0.0.aa`, y así.

```powershell
python tools\set_version.py 1.0.0.bs
```

Ese comando la deja sincronizada en `pubspec.yaml`, en la aplicación
(`lib/src/core/version.dart`) y en el instalador. **No editar la versión a mano
en cada sitio**: Windows guarda la versión del ejecutable como cuatro números y
un sufijo de letras no lo es, así que conviven dos formas de lo mismo —
`1.0.0.bs` para leer y `1.0.0.71` para los metadatos. El script calcula la
segunda a partir de la primera (letras a número, como las columnas de una hoja de
cálculo), de modo que el orden de versiones se conserva y el instalador puede
comparar cuál es más reciente.

## Estructura del código

```
lib/
  main.dart                     arranque, ventana, atajos, bandeja, cierre limpio
  src/
    core/        registro en memoria y tipos de fallo por etapa
    native/      FFI de Win32: captura GDI, estilos del overlay, ventanas, cursor
    models/      ajustes, idiomas, persistencia
    ocr/         preprocesado en isolate, motor Tesseract, limpieza de texto
    translate/   motores de traducción, caché LRU, cortacircuitos
    pipeline/    orquestador con contrapresión y autopausa
    state/       controlador central
    ui/          overlay, cajas arrastrables, panel, subtítulos, bandeja
tools/
  make_icons.py                 genera los iconos a partir del logo
test/
  logic_test.dart               lógica pura: OCR, ajustes, caché, resiliencia
  draggable_box_test.dart       arrastre, bloqueo y paso de clics de las cajas
  subtitle_view_test.dart       cuándo aparece y cuándo no la caja de texto
```

## Pruebas

```powershell
flutter test
dart analyze
```
