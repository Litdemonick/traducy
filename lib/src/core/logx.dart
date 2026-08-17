import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warn, error }

class LogEntry {
  LogEntry(this.level, this.tag, this.message) : time = DateTime.now();
  final DateTime time;
  final LogLevel level;
  final String tag;
  final String message;

  String get hhmmss =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}:'
      '${time.second.toString().padLeft(2, '0')}';

  @override
  String toString() => '[$hhmmss] ${level.name.toUpperCase()} $tag: $message';
}

/// Registro en memoria (buffer circular). Nunca lanza excepciones: es el
/// último recurso cuando algo falla, así que debe ser infalible.
class Logx {
  Logx._();
  static final Logx instance = Logx._();

  static const int _max = 400;
  final List<LogEntry> _entries = <LogEntry>[];
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  List<LogEntry> get entries => List<LogEntry>.unmodifiable(_entries);

  void _add(LogLevel level, String tag, String message) {
    try {
      _entries.add(LogEntry(level, tag, message));
      if (_entries.length > _max) {
        _entries.removeRange(0, _entries.length - _max);
      }
      revision.value++;
      // Visible en debug y profile: es la vía para diagnosticar
      // problemas de ventana sin poder abrir el panel.
      if (!kReleaseMode) debugPrint(_entries.last.toString());
    } catch (_) {
      // Ignorado a propósito: el logger jamás debe tumbar la app.
    }
  }

  void d(String tag, String message) => _add(LogLevel.debug, tag, message);
  void i(String tag, String message) => _add(LogLevel.info, tag, message);
  void w(String tag, String message) => _add(LogLevel.warn, tag, message);
  void e(String tag, String message, [Object? error, StackTrace? st]) {
    final detail = error == null ? '' : ' | $error';
    _add(LogLevel.error, tag, '$message$detail');
    if (!kReleaseMode && st != null) debugPrint(st.toString());
  }

  void clear() {
    _entries.clear();
    revision.value++;
  }

  String dump() => _entries.map((LogEntry e) => e.toString()).join('\n');
}

final Logx log = Logx.instance;
