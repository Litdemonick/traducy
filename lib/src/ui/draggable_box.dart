import 'package:flutter/material.dart';

import '../i18n/strings.dart';

/// Qué borde o esquina se está arrastrando.
enum _DragMode {
  move,
  topLeft,
  top,
  topRight,
  right,
  bottomRight,
  bottom,
  bottomLeft,
  left,
}

/// Caja movible y redimensionable con candado propio.
///
/// La usan tanto la zona de captura como la caja de subtítulos: son el mismo
/// problema de interacción, y compartir el widget garantiza que las dos se
/// comporten igual (mismos tiradores, mismo mínimo, mismo bloqueo).
class DraggableBox extends StatefulWidget {
  const DraggableBox({
    super.key,
    required this.rect,
    required this.onChanged,
    this.onPreview,
    required this.bounds,
    this.locked = false,
    this.onToggleLock,
    this.minWidth = 80,
    this.minHeight = 40,
    this.accentColor = const Color(0xFF4FC3F7),
    this.label,
    this.badges = const <Widget>[],
    this.child,
    this.showFill = true,
    this.passThroughBody = true,
  });

  /// Si el interior de la caja deja pasar el ratón al programa de debajo.
  ///
  /// Es lo normal y la razón de que se pueda jugar con los marcos puestos. Se
  /// desactiva solo cuando el contenido necesita el ratón para algo, como el
  /// historial de subtítulos con su scroll: ahí la caja ya está activada a mano
  /// desde el panel, así que capturar el ratón dentro es lo que se espera.
  final bool passThroughBody;

  /// Rectángulo actual en píxeles lógicos, relativo al área disponible.
  final Rect rect;

  final ValueChanged<Rect> onChanged;

  /// Aviso continuo mientras se arrastra, para quien solo quiera mirar.
  ///
  /// Existe aparte de [onChanged] por una razon concreta: [onChanged] guarda los
  /// ajustes y reconstruye media interfaz, y hacerlo en cada movimiento del raton
  /// hacia el arrastre lento. Esto no guarda nada, solo cuenta por donde va la
  /// caja, y con eso las medidas del panel pueden ir en vivo sin coste.
  final ValueChanged<Rect>? onPreview;

  /// Límites en los que se puede mover (normalmente el tamaño de la ventana).
  final Size bounds;

  final bool locked;
  final VoidCallback? onToggleLock;
  final double minWidth;
  final double minHeight;
  final Color accentColor;
  final String? label;

  /// Controles extra en la barra de título de la caja.
  final List<Widget> badges;

  final Widget? child;
  final bool showFill;

  @override
  State<DraggableBox> createState() => _DraggableBoxState();
}

class _DraggableBoxState extends State<DraggableBox> {
  static const double _handleSize = 14;
  static const double _hitSlop = 22;

  /// Rectángulo mientras se arrastra.
  ///
  /// El gesto se resuelve **en local** y solo se avisa al exterior al soltar.
  /// Notificar en cada movimiento del ratón obligaba a reconstruir todo el
  /// overlay (incluido el panel completo) sesenta veces por segundo, y el
  /// arrastre se sentía pastoso. Con esto solo se repinta esta caja.
  Rect? _dragRect;

  /// El rectángulo que se pinta: el del arrastre en curso si hay uno.
  Rect get _effectiveRect => _dragRect ?? widget.rect;

  void _onPanStart(_DragMode mode, DragStartDetails details) {
    if (widget.locked) return;
    setState(() => _dragRect = widget.rect);
  }

  void _onPanEnd() {
    final Rect? finished = _dragRect;
    if (finished == null) return;
    setState(() => _dragRect = null);
    // Un único aviso al soltar: aquí sí se persiste y se avisa al pipeline.
    widget.onChanged(finished);
  }

  void _onPanUpdate(_DragMode mode, DragUpdateDetails details) {
    if (widget.locked) return;
    final Rect current = _effectiveRect;
    final Offset delta = details.delta;

    double left = current.left;
    double top = current.top;
    double right = current.right;
    double bottom = current.bottom;

    switch (mode) {
      case _DragMode.move:
        left += delta.dx;
        top += delta.dy;
        right += delta.dx;
        bottom += delta.dy;
      case _DragMode.topLeft:
        left += delta.dx;
        top += delta.dy;
      case _DragMode.top:
        top += delta.dy;
      case _DragMode.topRight:
        right += delta.dx;
        top += delta.dy;
      case _DragMode.right:
        right += delta.dx;
      case _DragMode.bottomRight:
        right += delta.dx;
        bottom += delta.dy;
      case _DragMode.bottom:
        bottom += delta.dy;
      case _DragMode.bottomLeft:
        left += delta.dx;
        bottom += delta.dy;
      case _DragMode.left:
        left += delta.dx;
    }

    // Respetar el mínimo empujando el borde contrario, no recortando el que se
    // arrastra: así la caja no "salta" al llegar al límite.
    if (right - left < widget.minWidth) {
      if (mode == _DragMode.left ||
          mode == _DragMode.topLeft ||
          mode == _DragMode.bottomLeft) {
        left = right - widget.minWidth;
      } else {
        right = left + widget.minWidth;
      }
    }
    if (bottom - top < widget.minHeight) {
      if (mode == _DragMode.top ||
          mode == _DragMode.topLeft ||
          mode == _DragMode.topRight) {
        top = bottom - widget.minHeight;
      } else {
        bottom = top + widget.minHeight;
      }
    }

    Rect updated = Rect.fromLTRB(left, top, right, bottom);

    // Al mover se desplaza la caja completa para que no se deforme al topar con
    // un borde; al redimensionar sí se recorta contra el límite.
    if (mode == _DragMode.move) {
      final double maxLeft = (widget.bounds.width - updated.width).clamp(
        0.0,
        double.infinity,
      );
      final double maxTop = (widget.bounds.height - updated.height).clamp(
        0.0,
        double.infinity,
      );
      updated = Rect.fromLTWH(
        updated.left.clamp(0.0, maxLeft),
        updated.top.clamp(0.0, maxTop),
        updated.width,
        updated.height,
      );
    } else {
      updated = Rect.fromLTRB(
        updated.left.clamp(0.0, widget.bounds.width),
        updated.top.clamp(0.0, widget.bounds.height),
        updated.right.clamp(0.0, widget.bounds.width),
        updated.bottom.clamp(0.0, widget.bounds.height),
      );
    }

    if (updated.width < widget.minWidth || updated.height < widget.minHeight) {
      return; // Movimiento descartado: dejaría la caja por debajo del mínimo.
    }
    if (updated == _dragRect) return; // Nada que repintar.
    setState(() => _dragRect = updated);
    widget.onPreview?.call(updated);
  }

  Widget _handle(_DragMode mode, Alignment alignment, MouseCursor cursor) {
    // El área sensible es mayor que el cuadrado visible: agarrar una esquina de
    // 14 px con el ratón es incómodo, 22 px se acierta a la primera.
    return Align(
      alignment: alignment,
      child: MouseRegion(
        cursor: widget.locked ? SystemMouseCursors.basic : cursor,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (DragStartDetails d) => _onPanStart(mode, d),
          onPanUpdate: (DragUpdateDetails d) => _onPanUpdate(mode, d),
          onPanEnd: (DragEndDetails _) => _onPanEnd(),
          onPanCancel: _onPanEnd,
          child: SizedBox(
            width: _hitSlop,
            height: _hitSlop,
            child: Center(
              child: Container(
                width: _handleSize,
                height: _handleSize,
                decoration: BoxDecoration(
                  color: widget.locked
                      ? const Color(0xFF9E9E9E)
                      : widget.accentColor,
                  border: Border.all(color: Colors.white, width: 1.5),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Alto reservado para la barra de título, incluida su separación.
  static const double _titleStripHeight = 34;

  /// Ancho mínimo del marco para que la barra de título quepa entera.
  ///
  /// Importa porque un widget pintado fuera de los límites de su padre **no
  /// recibe clics** en Flutter: si la barra sobresaliera, el candado sería
  /// puramente decorativo.
  static const double _minFrameWidth = 260;

  @override
  Widget build(BuildContext context) {
    final Rect r = _effectiveRect;
    final Color accent = widget.locked
        ? const Color(0xFF9E9E9E)
        : widget.accentColor;

    // La barra va encima de la caja salvo que no quepa (caja pegada al borde
    // superior de la pantalla), en cuyo caso pasa debajo.
    final bool titleAbove = r.top >= _titleStripHeight;
    final double frameWidth = r.width < _minFrameWidth
        ? _minFrameWidth
        : r.width;

    return Positioned(
      left: r.left,
      top: titleAbove ? r.top - _titleStripHeight : r.top,
      width: frameWidth,
      height: r.height + _titleStripHeight,
      child: Stack(
        children: <Widget>[
          // La caja se arrastra por su barra de título, como una ventana.
          //
          // Es lo que permite que el interior del rectángulo deje pasar los
          // clics al juego: si el cuerpo capturase el ratón para moverse, la
          // caja se convertiría en un parche que bloquea todo lo que tapa.
          Positioned(
            left: 0,
            top: titleAbove ? 0 : r.height + 4,
            child: MouseRegion(
              cursor: widget.locked
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.move,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (DragStartDetails d) =>
                    _onPanStart(_DragMode.move, d),
                onPanUpdate: (DragUpdateDetails d) =>
                    _onPanUpdate(_DragMode.move, d),
                onPanEnd: (DragEndDetails _) => _onPanEnd(),
                onPanCancel: _onPanEnd,
                child: _TitleBar(
                  label: widget.label,
                  accent: accent,
                  locked: widget.locked,
                  onToggleLock: widget.onToggleLock,
                  badges: widget.badges,
                  size: r.size,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: titleAbove ? _titleStripHeight : 0,
            width: r.width,
            height: r.height,
            child: _buildBody(accent),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(Color accent) {
    return Stack(
      children: <Widget>[
        // Cuerpo: solo visual. `IgnorePointer` es la pieza clave de todo esto:
        // el interior del rectángulo no intercepta nada, así que se puede
        // pinchar lo que hay detrás a través de la zona marcada y de los
        // subtítulos. La caja se mueve por su barra de título y se redimensiona
        // por los tiradores del borde, igual que una ventana.
        Positioned.fill(
          child: IgnorePointer(
            ignoring: widget.passThroughBody,
            child: Container(
              decoration: BoxDecoration(
                color: widget.showFill
                    ? accent.withValues(alpha: 0.08)
                    : Colors.transparent,
                border: Border.all(
                  color: accent,
                  width: 2,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
              child: widget.child,
            ),
          ),
        ),

        if (!widget.locked) ...<Widget>[
          _handle(
            _DragMode.topLeft,
            Alignment.topLeft,
            SystemMouseCursors.resizeUpLeft,
          ),
          _handle(
            _DragMode.top,
            Alignment.topCenter,
            SystemMouseCursors.resizeUp,
          ),
          _handle(
            _DragMode.topRight,
            Alignment.topRight,
            SystemMouseCursors.resizeUpRight,
          ),
          _handle(
            _DragMode.right,
            Alignment.centerRight,
            SystemMouseCursors.resizeRight,
          ),
          _handle(
            _DragMode.bottomRight,
            Alignment.bottomRight,
            SystemMouseCursors.resizeDownRight,
          ),
          _handle(
            _DragMode.bottom,
            Alignment.bottomCenter,
            SystemMouseCursors.resizeDown,
          ),
          _handle(
            _DragMode.bottomLeft,
            Alignment.bottomLeft,
            SystemMouseCursors.resizeDownLeft,
          ),
          _handle(
            _DragMode.left,
            Alignment.centerLeft,
            SystemMouseCursors.resizeLeft,
          ),
        ],
      ],
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({
    required this.label,
    required this.accent,
    required this.locked,
    required this.onToggleLock,
    required this.badges,
    required this.size,
  });

  final String? label;
  final Color accent;
  final bool locked;
  final VoidCallback? onToggleLock;
  final List<Widget> badges;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xEE1E1E22),
        border: Border.all(color: accent, width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (label != null)
            Text(
              label!,
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(width: 8),
          Text(
            '${size.width.round()}×${size.height.round()}',
            style: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 11),
          ),
          ...badges,
          if (onToggleLock != null) ...<Widget>[
            const SizedBox(width: 6),
            _LockButton(locked: locked, accent: accent, onTap: onToggleLock!),
          ],
        ],
      ),
    );
  }
}

/// Botón de bloqueo. Cada caja tiene el suyo, independiente de la otra.
class _LockButton extends StatelessWidget {
  const _LockButton({
    required this.locked,
    required this.accent,
    required this.onTap,
  });

  final bool locked;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: locked
          ? 'Desbloquear para mover y redimensionar'
          : 'Bloquear en su sitio',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: locked
                ? const Color(0xFF9E9E9E).withValues(alpha: 0.25)
                : accent.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                locked ? Icons.lock : Icons.lock_open,
                size: 14,
                color: locked ? const Color(0xFFE0E0E0) : accent,
              ),
              const SizedBox(width: 4),
              Text(
                locked ? t.locked : t.free,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: locked ? const Color(0xFFE0E0E0) : accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
