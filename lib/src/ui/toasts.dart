import 'dart:async';

import 'package:flutter/foundation.dart';

enum ToastKind { info, success, warning, error }

class ToastMessage {
  ToastMessage({required this.text, this.kind = ToastKind.info, this.detail})
    : id = _nextId++,
      createdAt = DateTime.now();

  static int _nextId = 0;

  final int id;
  final String text;
  final String? detail;
  final ToastKind kind;
  final DateTime createdAt;

  String get hhmmss =>
      '${createdAt.hour.toString().padLeft(2, '0')}:'
      '${createdAt.minute.toString().padLeft(2, '0')}:'
      '${createdAt.second.toString().padLeft(2, '0')}';
}

/// Canal de mensajes de la aplicación.
///
/// Cada acción del usuario deja aquí una línea diciendo qué ha pasado, y la
/// consola del panel de control las muestra. Sin esto, pulsar un botón que
/// trabaja en segundo plano (comprobar motores, cambiar de idioma, empezar a
/// traducir) no daría ninguna señal y parecería que la aplicación no ha hecho
/// nada.
///
/// **No dibuja nada por su cuenta**: todo se ve dentro del panel, nunca flotando
/// sobre el juego. Es distinto del registro técnico de `Logx`, que existe para
/// diagnosticar después; esto es para enterarse ahora.
class ToastCenter extends ChangeNotifier {
  ToastCenter._();
  static final ToastCenter instance = ToastCenter._();

  static const int _maxVisible = 3;
  static const Duration _lifetime = Duration(seconds: 4);
  static const Duration _lifetimeError = Duration(seconds: 8);

  final List<ToastMessage> _messages = <ToastMessage>[];
  final Map<int, Timer> _timers = <int, Timer>{};

  /// Historial que **no** caduca, para el registro en vivo de la consola de
  /// cada zona del panel. Los avisos flotantes desaparecen a los pocos
  /// segundos; aquí se puede volver a leer lo que pasó.
  final List<ToastMessage> _history = <ToastMessage>[];
  static const int _maxHistory = 40;

  List<ToastMessage> get messages => List<ToastMessage>.unmodifiable(_messages);

  /// Del más reciente al más antiguo.
  List<ToastMessage> get history =>
      List<ToastMessage>.unmodifiable(_history.reversed);

  void show(String text, {ToastKind kind = ToastKind.info, String? detail}) {
    final ToastMessage message = ToastMessage(
      text: text,
      kind: kind,
      detail: detail,
    );
    _messages.add(message);
    _history.add(message);
    if (_history.length > _maxHistory) {
      _history.removeRange(0, _history.length - _maxHistory);
    }

    // Se limita el número visible: una ráfaga de avisos tapando el juego sería
    // peor que no avisar.
    while (_messages.length > _maxVisible) {
      final ToastMessage removed = _messages.removeAt(0);
      _timers.remove(removed.id)?.cancel();
    }

    // Los errores duran más: hay que poder leerlos y actuar.
    final Duration lifetime = kind == ToastKind.error
        ? _lifetimeError
        : _lifetime;
    _timers[message.id] = Timer(lifetime, () => dismiss(message.id));
    notifyListeners();
  }

  void info(String text, {String? detail}) =>
      show(text, kind: ToastKind.info, detail: detail);
  void success(String text, {String? detail}) =>
      show(text, kind: ToastKind.success, detail: detail);
  void warning(String text, {String? detail}) =>
      show(text, kind: ToastKind.warning, detail: detail);
  void error(String text, {String? detail}) =>
      show(text, kind: ToastKind.error, detail: detail);

  void dismiss(int id) {
    _timers.remove(id)?.cancel();
    final int before = _messages.length;
    _messages.removeWhere((ToastMessage m) => m.id == id);
    if (_messages.length != before) notifyListeners();
  }

  void clear() {
    for (final Timer timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    if (_messages.isEmpty) return;
    _messages.clear();
    notifyListeners();
  }

  /// Vacía también el historial de la consola.
  void clearHistory() {
    _history.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final Timer timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    super.dispose();
  }
}

/// Atajo para no escribir `ToastCenter.instance` por todas partes.
ToastCenter get toasts => ToastCenter.instance;
