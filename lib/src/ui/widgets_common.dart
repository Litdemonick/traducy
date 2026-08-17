import 'dart:async';

import 'package:flutter/material.dart';

import '../i18n/strings.dart';

const Color kPanelBackground = Color(0xF21B1B20);
const Color kPanelSurface = Color(0xFF26262E);
const Color kAccent = Color(0xFF4FC3F7);
const Color kRegionAccent = Color(0xFF66BB6A);
const Color kSubtitleAccent = Color(0xFFFFB74D);
const Color kDanger = Color(0xFFEF5350);
const Color kMuted = Color(0xFF9E9E9E);

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: const TextStyle(
                color: kAccent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class HelpText extends StatelessWidget {
  const HelpText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(color: kMuted, fontSize: 11.5, height: 1.35),
      ),
    );
  }
}

class SliderRow extends StatelessWidget {
  const SliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.suffix = '',
    this.decimals = 0,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final int? divisions;
  final String suffix;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final double safeValue = value.clamp(min, max);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: safeValue,
                min: min,
                max: max,
                divisions: divisions,
                activeColor: kAccent,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 62,
            child: Text(
              '${safeValue.toStringAsFixed(decimals)}$suffix',
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white, fontSize: 12.5),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: const TextStyle(color: kMuted, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
            Switch(
              value: value,
              activeThumbColor: kAccent,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

/// Campo de texto que solo notifica tras una pausa en la escritura.
///
/// Sin el retardo, escribir una API key dispararía una reconstrucción de motores
/// y una comprobación de red por cada tecla pulsada.
class DebouncedTextField extends StatefulWidget {
  const DebouncedTextField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onSubmitted,
    this.hint,
    this.obscure = false,
    this.maxLines = 1,
    this.debounce = const Duration(milliseconds: 700),
  });

  final String label;
  final String initialValue;
  final ValueChanged<String> onSubmitted;
  final String? hint;
  final bool obscure;
  final int maxLines;
  final Duration debounce;

  @override
  State<DebouncedTextField> createState() => _DebouncedTextFieldState();
}

class _DebouncedTextFieldState extends State<DebouncedTextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  late final FocusNode _focusNode = FocusNode()..addListener(_onFocusChange);
  Timer? _timer;
  bool _revealed = false;

  @override
  void didUpdateWidget(DebouncedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Solo se sincroniza si el valor externo cambió y el usuario no está
    // escribiendo: sobrescribir el texto bajo el cursor sería exasperante.
    if (oldWidget.initialValue != widget.initialValue &&
        _controller.text != widget.initialValue &&
        _timer == null) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    // El temporizador pendiente se descarta sin entregar: notificar durante el
    // desmontaje del árbol provocaría un cambio de estado en pleno build.
    // El usuario conserva el valor porque también se entrega al perder el foco.
    _timer?.cancel();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && (_timer?.isActive ?? false)) {
      _timer?.cancel();
      _timer = null;
      widget.onSubmitted(_controller.text);
    }
  }

  void _onChanged(String value) {
    _timer?.cancel();
    _timer = Timer(widget.debounce, () {
      _timer = null;
      widget.onSubmitted(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        onChanged: _onChanged,
        onSubmitted: (String v) {
          _timer?.cancel();
          _timer = null;
          widget.onSubmitted(v);
        },
        obscureText: widget.obscure && !_revealed,
        maxLines: widget.obscure ? 1 : widget.maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 12.5),
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          labelStyle: const TextStyle(color: kMuted, fontSize: 12),
          hintStyle: const TextStyle(color: Color(0xFF6D6D75), fontSize: 12),
          isDense: true,
          filled: true,
          fillColor: const Color(0xFF1A1A20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFF3A3A44)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFF3A3A44)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: kAccent),
          ),
          suffixIcon: widget.obscure
              ? IconButton(
                  icon: Icon(
                    _revealed ? Icons.visibility_off : Icons.visibility,
                    size: 16,
                    color: kMuted,
                  ),
                  onPressed: () => setState(() => _revealed = !_revealed),
                )
              : null,
        ),
      ),
    );
  }
}

/// Selector de color: paleta rápida más ajuste fino por canales.
///
/// Se implementa a mano en lugar de añadir una dependencia: son treinta líneas
/// y evita arrastrar un paquete entero para elegir un color.
class ColorPickerRow extends StatelessWidget {
  const ColorPickerRow({
    super.key,
    required this.label,
    required this.color,
    required this.onChanged,
    this.showAlpha = false,
  });

  final String label;
  final Color color;
  final ValueChanged<Color> onChanged;
  final bool showAlpha;

  static const List<Color> _presets = <Color>[
    Color(0xFFFFFFFF),
    Color(0xFF000000),
    Color(0xFFFFEB3B),
    Color(0xFF4FC3F7),
    Color(0xFF66BB6A),
    Color(0xFFEF5350),
    Color(0xFFFFB74D),
    Color(0xFFCE93D8),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            for (final Color preset in _presets)
              InkWell(
                onTap: () => onChanged(preset.withValues(alpha: color.a)),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: preset,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _sameRgb(preset, color)
                          ? kAccent
                          : const Color(0xFF44444E),
                      width: _sameRgb(preset, color) ? 2.5 : 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
        _channelSlider(
          'R',
          color.r,
          (double v) => onChanged(color.withValues(red: v)),
        ),
        _channelSlider(
          'G',
          color.g,
          (double v) => onChanged(color.withValues(green: v)),
        ),
        _channelSlider(
          'B',
          color.b,
          (double v) => onChanged(color.withValues(blue: v)),
        ),
        if (showAlpha)
          _channelSlider(
            t.opacity,
            color.a,
            (double v) => onChanged(color.withValues(alpha: v)),
          ),
      ],
    );
  }

  static bool _sameRgb(Color a, Color b) =>
      (a.r - b.r).abs() < 0.01 &&
      (a.g - b.g).abs() < 0.01 &&
      (a.b - b.b).abs() < 0.01;

  Widget _channelSlider(
    String name,
    double value,
    ValueChanged<double> onChange,
  ) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 64,
          child: Text(
            name,
            style: const TextStyle(color: kMuted, fontSize: 11),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: value.clamp(0.0, 1.0),
              activeColor: kAccent,
              onChanged: onChange,
            ),
          ),
        ),
        SizedBox(
          width: 34,
          child: Text(
            (value * 255).round().toString(),
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

/// Aviso con nivel de severidad. Los mensajes de error siempre traen una acción
/// concreta, nunca solo "algo falló".
class NoticeCard extends StatelessWidget {
  const NoticeCard({
    super.key,
    required this.message,
    this.hint,
    this.severity = NoticeSeverity.info,
    this.action,
  });

  final String message;
  final String? hint;
  final NoticeSeverity severity;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon) = switch (severity) {
      NoticeSeverity.info => (kAccent, Icons.info_outline),
      NoticeSeverity.warning => (kSubtitleAccent, Icons.warning_amber_rounded),
      NoticeSeverity.error => (kDanger, Icons.error_outline),
      NoticeSeverity.success => (kRegionAccent, Icons.check_circle_outline),
    };

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                if (hint != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      hint!,
                      style: const TextStyle(
                        color: kMuted,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                if (action != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: action,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum NoticeSeverity { info, warning, error, success }
