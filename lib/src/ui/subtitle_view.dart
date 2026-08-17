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

/// El subtítulo en pantalla.
class SubtitleView extends StatelessWidget {
  const SubtitleView({
    super.key,
    required this.content,
    required this.style,
    this.placeholder,
  });

  final SubtitleContent? content;
  final SubtitleStyle style;

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

    return AnimatedOpacity(
      opacity: 1,
      duration: Duration(milliseconds: style.fadeMs),
      child: Container(
        alignment: _boxAlign,
        padding: EdgeInsets.all(style.padding),
        decoration: BoxDecoration(
          color: style.backgroundColor.withValues(
            alpha: style.backgroundOpacity,
          ),
          borderRadius: BorderRadius.circular(style.cornerRadius),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: switch (style.align) {
            SubtitleAlign.left => CrossAxisAlignment.start,
            SubtitleAlign.center => CrossAxisAlignment.center,
            SubtitleAlign.right => CrossAxisAlignment.end,
          },
          children: <Widget>[
            OutlinedText(
              text: translated,
              style: baseStyle,
              outlineColor: style.outlineColor,
              outlineWidth: style.outlineWidth,
              textAlign: _textAlign,
              maxLines: style.maxLines,
              shadow: style.shadow,
            ),
            if (style.showOriginal &&
                current != null &&
                current.original.isNotEmpty) ...<Widget>[
              SizedBox(height: style.fontSize * 0.28),
              OutlinedText(
                text: current.original,
                style: baseStyle.copyWith(
                  fontSize: style.fontSize * 0.72,
                  fontWeight: FontWeight.w400,
                  color: style.textColor.withValues(
                    alpha: style.originalOpacity,
                  ),
                ),
                outlineColor: style.outlineColor,
                outlineWidth: style.outlineWidth * 0.7,
                textAlign: _textAlign,
                maxLines: style.maxLines,
                shadow: style.shadow,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
