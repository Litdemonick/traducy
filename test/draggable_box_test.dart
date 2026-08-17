import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traducy/src/i18n/strings.dart';
import 'package:traducy/src/ui/draggable_box.dart';

/// Alto de la franja reservada a la barra de título dentro del marco. El marco
/// se dibuja desplazado hacia arriba esa cantidad para que la barra (y su
/// candado) queden dentro de los límites y puedan recibir clics.
const double _titleStrip = 34;

/// Envuelve la caja en un Stack del tamaño indicado, como en el overlay real.
///
/// `onBehindTap` simula lo que hay detrás del overlay: si recibe el toque, es
/// que la caja dejó pasar el clic, que es justo lo que se quiere del interior.
Widget _host({
  required Rect rect,
  required ValueChanged<Rect> onChanged,
  bool locked = false,
  Size bounds = const Size(700, 520),
  VoidCallback? onBehindTap,
}) {
  return MaterialApp(
    home: Material(
      child: SizedBox(
        width: bounds.width,
        height: bounds.height,
        child: Stack(
          children: <Widget>[
            if (onBehindTap != null)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onBehindTap,
                ),
              ),
            DraggableBox(
              rect: rect,
              bounds: bounds,
              locked: locked,
              onChanged: onChanged,
              label: 'Caja',
            ),
          ],
        ),
      ),
    ),
  );
}

/// Punto dentro de la barra de título, que es el asa para mover la caja.
Offset _titleBarPoint(Rect rect) =>
    Offset(rect.left + 60, rect.top - _titleStrip / 2);

/// Posición lógica de la caja tal y como está pintada ahora mismo, descontando
/// la franja del título. Sirve para distinguir "se ve moverse" de "avisó al
/// exterior", que es justo la diferencia que arregló la lentitud del arrastre.
Offset _paintedTopLeft(WidgetTester tester) {
  final RenderBox box = tester.renderObject<RenderBox>(
    find.byType(DraggableBox),
  );
  final Offset origin = box.localToGlobal(Offset.zero);
  return Offset(origin.dx, origin.dy + _titleStrip);
}

void main() {
  // La interfaz habla el idioma del sistema, y el de la máquina de pruebas no
  // tiene por qué ser el mismo. Se fija para que las aserciones comparen contra
  // un texto conocido en lugar de depender de la configuración del equipo.
  setUpAll(() => L10n.apply(UiLanguage.spanish));

  testWidgets(
    'el interior de la caja deja pasar los clics a lo que hay detrás',
    (WidgetTester tester) async {
      int behindTaps = 0;
      const Rect start = Rect.fromLTWH(100, 100, 300, 120);

      await tester.pumpWidget(
        _host(rect: start, onChanged: (_) {}, onBehindTap: () => behindTaps++),
      );

      // Un clic en el centro del rectángulo debe llegar al fondo, no quedarse
      // en la caja: es lo que permite seguir jugando con la zona marcada
      // encima del juego.
      await tester.tapAt(start.center);
      await tester.pump();

      expect(behindTaps, 1, reason: 'el interior no debe interceptar el ratón');
    },
  );

  testWidgets('la barra de título sí captura el ratón', (
    WidgetTester tester,
  ) async {
    int behindTaps = 0;
    const Rect start = Rect.fromLTWH(100, 100, 300, 120);

    await tester.pumpWidget(
      _host(rect: start, onChanged: (_) {}, onBehindTap: () => behindTaps++),
    );

    await tester.tapAt(_titleBarPoint(start));
    await tester.pump();

    expect(behindTaps, 0, reason: 'la barra es zona de interfaz, no del juego');
  });

  testWidgets('el arrastre por la barra solo avisa una vez, al soltar', (
    WidgetTester tester,
  ) async {
    final List<Rect> notifications = <Rect>[];
    const Rect start = Rect.fromLTWH(100, 100, 300, 120);

    await tester.pumpWidget(_host(rect: start, onChanged: notifications.add));

    // Se arrastra en varios pasos, como haría un ratón real.
    final TestGesture gesture = await tester.startGesture(
      _titleBarPoint(start),
    );
    for (int i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(8, 4));
      await tester.pump();
    }

    expect(
      notifications,
      isEmpty,
      reason:
          'durante el gesto no debe notificar: eso reconstruía todo el overlay '
          'y hacía el arrastre lento',
    );

    // Pero sí debe verse moviéndose mientras se arrastra.
    final Offset midDrag = _paintedTopLeft(tester);
    expect(midDrag.dx, closeTo(180, 1));
    expect(midDrag.dy, closeTo(140, 1));

    await gesture.up();
    await tester.pump();

    expect(notifications, hasLength(1));
    expect(notifications.single.left, closeTo(180, 1));
    expect(notifications.single.top, closeTo(140, 1));
    expect(notifications.single.width, closeTo(300, 1));
    expect(notifications.single.height, closeTo(120, 1));
  });

  testWidgets('una caja bloqueada no se mueve ni notifica', (
    WidgetTester tester,
  ) async {
    final List<Rect> notifications = <Rect>[];
    const Rect start = Rect.fromLTWH(100, 100, 300, 120);

    await tester.pumpWidget(
      _host(rect: start, onChanged: notifications.add, locked: true),
    );

    final TestGesture gesture = await tester.startGesture(
      _titleBarPoint(start),
    );
    for (int i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(20, 12));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();

    expect(notifications, isEmpty);
    expect(_paintedTopLeft(tester).dx, closeTo(100, 1));
  });

  testWidgets('la caja no se sale de los límites al moverla', (
    WidgetTester tester,
  ) async {
    final List<Rect> notifications = <Rect>[];
    const Size bounds = Size(700, 520);
    const Rect start = Rect.fromLTWH(480, 380, 180, 90);

    await tester.pumpWidget(
      _host(rect: start, onChanged: notifications.add, bounds: bounds),
    );

    // Empujón grande hacia la esquina inferior derecha.
    final TestGesture gesture = await tester.startGesture(
      _titleBarPoint(start),
    );
    for (int i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(18, 14));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();

    final Rect result = notifications.single;
    expect(result.right, lessThanOrEqualTo(bounds.width + 0.01));
    expect(result.bottom, lessThanOrEqualTo(bounds.height + 0.01));
    // Al topar con el borde se desplaza, no se deforma.
    expect(result.width, closeTo(start.width, 0.01));
    expect(result.height, closeTo(start.height, 0.01));
  });

  testWidgets('el candado de la barra alterna el bloqueo', (
    WidgetTester tester,
  ) async {
    int toggles = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: SizedBox(
            width: 700,
            height: 520,
            child: Stack(
              children: <Widget>[
                DraggableBox(
                  rect: const Rect.fromLTWH(100, 100, 300, 120),
                  bounds: const Size(700, 520),
                  onChanged: (_) {},
                  onToggleLock: () => toggles++,
                  label: 'Caja',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Libre'));
    await tester.pump();
    expect(toggles, 1);
  });

  testWidgets('redimensionar por una esquina cambia el tamaño', (
    WidgetTester tester,
  ) async {
    final List<Rect> notifications = <Rect>[];
    const Rect start = Rect.fromLTWH(200, 200, 300, 120);

    await tester.pumpWidget(_host(rect: start, onChanged: notifications.add));

    // El tirador inferior derecho vive dentro de la esquina de la caja.
    final TestGesture gesture = await tester.startGesture(
      start.bottomRight - const Offset(6, 6),
    );
    for (int i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(10, 6));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();

    final Rect result = notifications.single;
    expect(result.left, closeTo(start.left, 1));
    expect(result.top, closeTo(start.top, 1));
    expect(result.width, greaterThan(start.width));
    expect(result.height, greaterThan(start.height));
  });
}
