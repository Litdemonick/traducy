import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traducy/src/models/settings.dart';
import 'package:traducy/src/pipeline/pipeline.dart';
import 'package:traducy/src/ui/subtitle_view.dart';

Widget _host({
  SubtitleContent? content,
  String? placeholder,
  SubtitleStyle style = const SubtitleStyle(),
  Size? box,
}) {
  final Widget view = SubtitleView(
    content: content,
    style: style,
    placeholder: placeholder,
  );
  return MaterialApp(
    home: Material(
      // Con `box` se reproduce la caja de subtitulos del overlay: un rectangulo
      // de tamano fijo dentro del cual el texto tiene que caber.
      child: box == null
          ? view
          : Center(
              child: SizedBox(
                width: box.width,
                height: box.height,
                child: Center(child: view),
              ),
            ),
    ),
  );
}

/// Tamano con el que se pinto realmente el texto.
double _renderedFontSize(WidgetTester tester, String text) {
  final Text widget = tester.widget<Text>(find.text(text).first);
  return widget.style!.fontSize!;
}

void main() {
  testWidgets('sin contenido y sin texto de muestra no dibuja nada', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host());

    // La caja de texto solo existe cuando se activa en el panel o cuando hay
    // una traducción real. Fuera de eso no debe aparecer nada sobre el juego.
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('el texto de muestra solo aparece si se pasa', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(placeholder: 'Aquí aparecerá la traducción'));

    expect(find.text('Aquí aparecerá la traducción'), findsWidgets);
  });

  testWidgets('una traducción real se muestra aunque no haya muestra', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        content: SubtitleContent(
          translated: 'Este juego contiene escenas violentas.',
          original: 'このゲームには暴力的表現が含まれています。',
        ),
      ),
    );

    expect(find.text('Este juego contiene escenas violentas.'), findsWidgets);
  });

  testWidgets('el original solo se muestra si el estilo lo pide', (
    WidgetTester tester,
  ) async {
    final SubtitleContent content = SubtitleContent(
      translated: 'Traducción',
      original: 'Original',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: SubtitleView(
            content: content,
            style: const SubtitleStyle(showOriginal: false),
          ),
        ),
      ),
    );
    expect(find.text('Original'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: SubtitleView(
            content: content,
            style: const SubtitleStyle(showOriginal: true),
          ),
        ),
      ),
    );
    expect(find.text('Original'), findsWidgets);
  });

  testWidgets('un texto largo encoge la letra para entrar en la caja', (
    WidgetTester tester,
  ) async {
    // El sintoma que arregla: el parrafo se salia de la caja por abajo en lugar
    // de adaptarse a ella.
    const String largo =
        'Los guardias del castillo llevan semanas sin dormir, y el capitan '
        'insiste en que la puerta sellada no se abrira por si sola aunque le '
        'recemos todas las noches.';
    const SubtitleStyle style = SubtitleStyle(fontSize: 28);

    await tester.pumpWidget(
      _host(
        content: SubtitleContent(translated: largo, original: ''),
        style: style,
        box: const Size(360, 90),
      ),
    );

    expect(_renderedFontSize(tester, largo), lessThan(style.fontSize));
    expect(
      _renderedFontSize(tester, largo),
      greaterThanOrEqualTo(style.fontSize * style.minFontScale - 0.01),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('un texto corto se queda al tamano elegido', (
    WidgetTester tester,
  ) async {
    const String corto = 'Vamos.';
    const SubtitleStyle style = SubtitleStyle(fontSize: 28);

    await tester.pumpWidget(
      _host(
        content: SubtitleContent(translated: corto, original: ''),
        style: style,
        box: const Size(360, 120),
      ),
    );

    expect(_renderedFontSize(tester, corto), style.fontSize);
  });

  testWidgets('sin ajuste automatico se respeta el tamano elegido', (
    WidgetTester tester,
  ) async {
    const String largo =
        'Los guardias del castillo llevan semanas sin dormir y nadie sabe por '
        'que la puerta sigue cerrada.';
    const SubtitleStyle style = SubtitleStyle(fontSize: 28, autoFit: false);

    await tester.pumpWidget(
      _host(
        content: SubtitleContent(translated: largo, original: ''),
        style: style,
        box: const Size(360, 90),
      ),
    );

    expect(_renderedFontSize(tester, largo), style.fontSize);
    // Recortado por el borde de la caja, no desbordado sobre el juego.
    expect(tester.takeException(), isNull);
  });
}
