import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traducy/src/models/settings.dart';
import 'package:traducy/src/pipeline/pipeline.dart';
import 'package:traducy/src/ui/subtitle_view.dart';

Widget _host({SubtitleContent? content, String? placeholder}) {
  return MaterialApp(
    home: Material(
      child: SubtitleView(
        content: content,
        style: const SubtitleStyle(),
        placeholder: placeholder,
      ),
    ),
  );
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
}
