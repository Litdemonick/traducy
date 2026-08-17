import 'package:flutter/material.dart';

import '../models/settings.dart';
import '../pipeline/pipeline.dart';

/// Texto con contorno.
///
/// Se dibuja dos veces: primero el trazo y encima el relleno. Es la técnica
/// estándar de subtitulado y la razón de que el texto siga siendo legible tanto
/// sobre una escena nocturna como sobre un cielo blanco, algo que ni la sombra
/// ni un fondo semitransparente garantizan por sí solos.
class OutlinedText extends StatelessWidget {
  const OutlinedText({
    super.key,
    required this.text,
    required this.style,
    required this.outlineColor,
    required this.outlineWidth,
    required this.textAlign,
    required this.maxLines,
    this.shadow = false,
  });

  final String text;
  final TextStyle style;
  final Color outlineColor;
  final double outlineWidth;
  final TextAlign textAlign;
  final int maxLines;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final List<Shadow> shadows = shadow
        ? <Shadow>[
            const Shadow(
              color: Color(0xCC000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ]
        : const <Shadow>[];

    final Widget fill = Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: style.copyWith(shadows: shadows),
    );

    if (outlineWidth <= 0.05) return fill;

    return Stack(
      children: <Widget>[
        Text(
          text,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = outlineWidth
              ..strokeJoin = StrokeJoin.round
              ..color = outlineColor,
            shadows: shadows,
          ),
        ),
        fill,
      ],
    );
  }
}

/// Historial de subtítulos con scroll, dentro de la caja de texto.
///
/// La caja deja de ser una sola frase que se borra sola y pasa a ser el registro
/// de lo dicho: lo último abajo, lo anterior encima y atenuado. Si te distraes un
/// segundo, la frase sigue ahí.
///
/// Se baja sola a lo último **salvo que el usuario haya subido a leer**. Seguir
/// el texto nuevo a la fuerza haría imposible leer hacia atrás, que es justo
/// para lo que está.
///
/// El scroll con la rueda solo funciona con la caja activada desde el panel.
/// Fuera de ahí la caja deja pasar el ratón al juego, y capturar la rueda
/// significaría capturar también los clics.
class SubtitleHistoryView extends StatefulWidget {
  const SubtitleHistoryView({
    super.key,
    required this.entries,
    required this.style,
    required this.interactive,
  });

  final List<SubtitleContent> entries;
  final SubtitleStyle style;

  /// `true` cuando la caja está activada y puede recibir la rueda del ratón.
  final bool interactive;

  @override
  State<SubtitleHistoryView> createState() => _SubtitleHistoryViewState();
}

class _SubtitleHistoryViewState extends State<SubtitleHistoryView> {
  final ScrollController _scroll = ScrollController();

  /// Margen para considerar que el usuario sigue mirando lo último. Unos píxeles
  /// de inercia no cuentan como haber subido a leer.
  static const double _atBottomSlack = 28;

  bool _stickToBottom = true;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SubtitleHistoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entries.length != oldWidget.entries.length) _followNewest();
  }

  void _followNewest() {
    if (!_stickToBottom) return;
    // Después del repintado: durante `didUpdateWidget` la lista todavía mide lo
    // que medía antes y el desplazamiento se quedaría corto.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final ScrollPosition position = _scroll.position;
    _stickToBottom =
        position.pixels >= position.maxScrollExtent - _atBottomSlack;
  }

  @override
  Widget build(BuildContext context) {
    final List<SubtitleContent> entries = widget.entries;
    if (entries.isEmpty) return const SizedBox.shrink();

    final SubtitleStyle style = widget.style;
    final Widget list = NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        if (notification is ScrollUpdateNotification) _onScroll();
        return false;
      },
      child: ListView.builder(
        controller: _scroll,
        padding: EdgeInsets.zero,
        // Sin rebote: en un overlay sobre un juego, el efecto elástico se
        // confunde con un fallo de dibujado.
        physics: widget.interactive
            ? const ClampingScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        itemCount: entries.length,
        itemBuilder: (BuildContext context, int index) {
          final bool isNewest = index == entries.length - 1;
          return Padding(
            padding: EdgeInsets.only(
              bottom: isNewest ? 0 : style.fontSize * 0.3,
            ),
            child: Opacity(
              // Lo anterior se atenúa: se lee si hace falta, y no compite con la
              // línea que se está diciendo ahora.
              opacity: isNewest ? 1.0 : 0.55,
              child: SubtitleView(
                content: entries[index],
                style: style,
                // Dentro de la lista el alto es libre: aquí no se encoge la
                // letra, se desplaza. Encogerla dejaría cada línea de un tamaño
                // distinto según lo larga que fuese.
                fitToBox: false,
                showBackground: false,
              ),
            ),
          );
        },
      ),
    );

    return Container(
      padding: EdgeInsets.all(style.padding),
      decoration: BoxDecoration(
        color: style.backgroundColor.withValues(alpha: style.backgroundOpacity),
        borderRadius: BorderRadius.circular(style.cornerRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Scrollbar(
        controller: _scroll,
        // Visible solo cuando se puede usar: una barra que no responde al ratón
        // es peor que no tenerla.
        thumbVisibility: widget.interactive,
        thickness: 5,
        radius: const Radius.circular(3),
        child: list,
      ),
    );
  }
}

/// El subtítulo en pantalla.
class SubtitleView extends StatelessWidget {
  const SubtitleView({
    super.key,
    required this.content,
    required this.style,
    this.placeholder,
    this.fitToBox = true,
    this.showBackground = true,
  });

  final SubtitleContent? content;
  final SubtitleStyle style;

  /// Si el texto debe encogerse para entrar en la caja.
  ///
  /// Se desactiva dentro del historial: ahí el alto es libre y el texto se
  /// desplaza en lugar de encogerse.
  final bool fitToBox;

  /// Si dibuja su propio fondo. En el historial lo pinta la lista, una sola vez,
  /// en lugar de una caja por línea.
  final bool showBackground;

  /// Texto de ejemplo para ver el estilo mientras se configura, aunque no haya
  /// nada traducido todavía.
  final String? placeholder;

  TextAlign get _textAlign => switch (style.align) {
    SubtitleAlign.left => TextAlign.left,
    SubtitleAlign.center => TextAlign.center,
    SubtitleAlign.right => TextAlign.right,
  };

  Alignment get _boxAlign => switch (style.align) {
    SubtitleAlign.left => Alignment.centerLeft,
    SubtitleAlign.center => Alignment.center,
    SubtitleAlign.right => Alignment.centerRight,
  };

  @override
  Widget build(BuildContext context) {
    final SubtitleContent? current = content;
    final String translated = current?.translated ?? placeholder ?? '';
    if (translated.isEmpty) return const SizedBox.shrink();

    final TextStyle baseStyle = TextStyle(
      fontFamily: style.fontFamily,
      fontSize: style.fontSize,
      fontWeight: style.bold ? FontWeight.w700 : FontWeight.w400,
      fontStyle: style.italic ? FontStyle.italic : FontStyle.normal,
      color: style.textColor,
      height: style.lineHeight,
      letterSpacing: style.letterSpacing,
      // Sin decoración heredada: dentro de un Stack sin Material el texto puede
      // salir subrayado en amarillo.
      decoration: TextDecoration.none,
    );

    final String? original =
        style.showOriginal && current != null && current.original.isNotEmpty
        ? current.original
        : null;

    return AnimatedOpacity(
      opacity: 1,
      duration: Duration(milliseconds: style.fadeMs),
      child: Container(
        alignment: _boxAlign,
        padding: showBackground
            ? EdgeInsets.all(style.padding)
            : EdgeInsets.zero,
        decoration: showBackground
            ? BoxDecoration(
                color: style.backgroundColor.withValues(
                  alpha: style.backgroundOpacity,
                ),
                borderRadius: BorderRadius.circular(style.cornerRadius),
              )
            : null,
        // Nada se pinta fuera de la caja. El ajuste automático evita llegar a
        // este extremo, pero si el texto no cabe ni al tamaño mínimo, es mejor
        // que se corte en el borde que verlo desbordado sobre el juego: la caja
        // que se coloca es la que se ve, sin sorpresas.
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // El tamaño de letra se decide aquí, con la caja ya medida: es lo
            // que permite que un diálogo largo entre entero en lugar de
            // cortarse, y que uno corto se vea al tamaño elegido.
            final double scale = style.autoFit && fitToBox
                ? _fitScale(
                    translated: translated,
                    original: original,
                    base: baseStyle,
                    constraints: constraints,
                  )
                : 1.0;
            return _body(
              translated: translated,
              original: original,
              textStyle: scale == 1.0
                  ? baseStyle
                  : baseStyle.copyWith(fontSize: style.fontSize * scale),
              constraints: constraints,
            );
          },
        ),
      ),
    );
  }

  /// Busca el mayor tamaño de letra que cabe en la caja.
  ///
  /// Se mide con `TextPainter`, el mismo motor que dibujará el texto, en lugar
  /// de estimar por número de caracteres: con letra proporcional, kanji y saltos
  /// de línea automáticos, cualquier estimación se equivoca justo en los casos
  /// difíciles, que son los que importan.
  ///
  /// Es una busqueda binaria de siete pasos: siete medidas por cada traducción
  /// nueva, no por fotograma, porque el subtítulo solo se reconstruye cuando
  /// cambia el texto.
  double _fitScale({
    required String translated,
    required String? original,
    required TextStyle base,
    required BoxConstraints constraints,
  }) {
    final double maxWidth = constraints.maxWidth;
    final double maxHeight = constraints.maxHeight;
    // Sin límites reales no hay nada que ajustar: es el caso de una caja que
    // crece con su contenido.
    if (!maxWidth.isFinite || !maxHeight.isFinite) return 1.0;
    if (maxWidth <= 0 || maxHeight <= 0) return 1.0;

    if (_fits(
      scale: 1.0,
      translated: translated,
      original: original,
      base: base,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    )) {
      return 1.0;
    }

    double low = style.minFontScale;
    double high = 1.0;
    // Si ni el mínimo entra, se devuelve el mínimo: el texto se recortará con
    // puntos suspensivos, que al menos deja ver que falta algo.
    if (!_fits(
      scale: low,
      translated: translated,
      original: original,
      base: base,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    )) {
      return low;
    }

    for (int i = 0; i < 7; i++) {
      final double middle = (low + high) / 2;
      if (_fits(
        scale: middle,
        translated: translated,
        original: original,
        base: base,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      )) {
        low = middle;
      } else {
        high = middle;
      }
    }
    return low;
  }

  bool _fits({
    required double scale,
    required String translated,
    required String? original,
    required TextStyle base,
    required double maxWidth,
    required double maxHeight,
  }) {
    // Cabe si entra en el alto **y** dentro del límite de líneas. Comprobar solo
    // el alto no bastaria: con un límite de líneas puesto, `TextPainter` recorta
    // y devuelve una altura que cabe de sobra, así que el texto pasaría el
    // control justo cuando se está perdiendo la mitad.
    final (double height, bool exceeded) = _measure(
      text: translated,
      style: base.copyWith(fontSize: style.fontSize * scale),
      maxWidth: maxWidth,
    );
    if (exceeded) return false;
    double used = height;
    if (original != null) {
      // El original va debajo y a menor tamaño; su hueco cuenta igual.
      final (double originalHeight, bool originalExceeded) = _measure(
        text: original,
        style: base.copyWith(fontSize: style.fontSize * scale * 0.72),
        maxWidth: maxWidth,
      );
      if (originalExceeded) return false;
      used += style.fontSize * scale * 0.28 + originalHeight;
    }
    return used <= maxHeight;
  }

  (double, bool) _measure({
    required String text,
    required TextStyle style,
    required double maxWidth,
    int? maxLines,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: _textAlign,
      textDirection: TextDirection.ltr,
      maxLines: maxLines ?? this.style.maxLines,
    )..layout(maxWidth: maxWidth);
    final double height = painter.height;
    final bool exceeded = painter.didExceedMaxLines;
    painter.dispose();
    return (height, exceeded);
  }

  Widget _body({
    required String translated,
    required String? original,
    required TextStyle textStyle,
    required BoxConstraints constraints,
  }) {
    final double fontSize = textStyle.fontSize ?? style.fontSize;
    final double outlineScale = fontSize / style.fontSize;
    final double gap = fontSize * 0.28;
    final TextStyle originalStyle = textStyle.copyWith(
      fontSize: fontSize * 0.72,
      fontWeight: FontWeight.w400,
      color: style.textColor.withValues(alpha: style.originalOpacity),
    );

    // Cuántas líneas caben de verdad en la caja.
    //
    // Es la garantía de que lo que se ve es exactamente lo que hay: el ajuste
    // automático encoge la letra, pero si el texto sigue sin caber (o el ajuste
    // está apagado) hay que recortar por líneas. Sin esto, la columna crecía por
    // debajo del borde y el párrafo se salía de la caja encima del juego.
    int linesThatFit(String text, TextStyle candidate, double budget) {
      if (!budget.isFinite) return style.maxLines;
      if (budget <= 0) return 1;
      final (double oneLine, _) = _measure(
        text: text,
        style: candidate,
        maxWidth: constraints.maxWidth,
        maxLines: 1,
      );
      if (oneLine <= 0) return 1;
      return (budget / oneLine).floor().clamp(1, style.maxLines);
    }

    final double available = constraints.maxHeight;
    int translatedLines;
    int originalLines = style.maxLines;

    if (original == null) {
      translatedLines = linesThatFit(translated, textStyle, available);
    } else {
      // Se reserva sitio para al menos un renglón del original antes de repartir
      // el resto: si se le da todo a la traducción, el original desaparece sin
      // que nada lo explique.
      final (double originalOneLine, _) = _measure(
        text: original,
        style: originalStyle,
        maxWidth: constraints.maxWidth,
        maxLines: 1,
      );
      translatedLines = linesThatFit(
        translated,
        textStyle,
        available - gap - originalOneLine,
      );
      final (double translatedHeight, _) = _measure(
        text: translated,
        style: textStyle,
        maxWidth: constraints.maxWidth,
        maxLines: translatedLines,
      );
      originalLines = linesThatFit(
        original,
        originalStyle,
        available - gap - translatedHeight,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: switch (style.align) {
        SubtitleAlign.left => CrossAxisAlignment.start,
        SubtitleAlign.center => CrossAxisAlignment.center,
        SubtitleAlign.right => CrossAxisAlignment.end,
      },
      children: <Widget>[
        OutlinedText(
          text: translated,
          style: textStyle,
          outlineColor: style.outlineColor,
          // El contorno acompaña al tamaño de la letra: fijo, sobre letra
          // encogida se comería el trazo y el texto saldría embarrado.
          outlineWidth: style.outlineWidth * outlineScale,
          textAlign: _textAlign,
          maxLines: translatedLines,
          shadow: style.shadow,
        ),
        if (original != null) ...<Widget>[
          SizedBox(height: gap),
          OutlinedText(
            text: original,
            style: originalStyle,
            outlineColor: style.outlineColor,
            outlineWidth: style.outlineWidth * 0.7 * outlineScale,
            textAlign: _textAlign,
            maxLines: originalLines,
            shadow: style.shadow,
          ),
        ],
      ],
    );
  }
}
