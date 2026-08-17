import 'package:flutter/services.dart';

import '../core/failures.dart';
import '../core/logx.dart';
import 'ocr_engine.dart';

/// El OCR que ya viene con Windows (`Windows.Media.Ocr`).
///
/// Es la alternativa gratuita de verdad a Tesseract: no hay clave que pedir, no
/// sale nada del equipo y no hay nada que instalar aparte del paquete de idioma
/// de Windows. Sobre capturas de pantalla acierta bastante más que Tesseract, y
/// en japonés, chino y coreano la diferencia es grande, porque es el mismo motor
/// que usa el sistema para leer texto de imágenes.
///
/// Lo que pide a cambio: el idioma tiene que estar instalado en Windows. La
/// lista real la da el propio sistema en [systemLanguages], y de ahí sale el
/// mensaje que explica qué falta en lugar de fallar sin más.
class WindowsOcr implements OcrEngine {
  WindowsOcr({required this.languageTag});

  static const MethodChannel _channel = MethodChannel('traducy/windows_ocr');

  /// Etiqueta BCP-47 del idioma a reconocer (`ja`, `es`, `zh-Hans`...).
  ///
  /// Vacío significa "los idiomas del perfil del usuario", que es lo que más
  /// acierta cuando no hay preferencia.
  final String languageTag;

  @override
  String get id => 'windows';

  @override
  String get displayName => 'OCR de Windows';

  /// Idiomas que el sistema puede reconocer ahora mismo.
  ///
  /// Devuelve una lista vacía si el motor no está disponible, que en la práctica
  /// significa una edición de Windows sin el componente de OCR.
  static Future<List<String>> systemLanguages() async {
    try {
      final List<Object?>? tags = await _channel.invokeListMethod<Object?>(
        'languages',
      );
      return (tags ?? const <Object?>[])
          .whereType<String>()
          .map((String tag) => tag.trim())
          .where((String tag) => tag.isNotEmpty)
          .toList();
    } catch (e) {
      log.w('ocr', 'El OCR de Windows no respondió: $e');
      return const <String>[];
    }
  }

  /// Traduce un código de Tesseract al BCP-47 que espera Windows.
  ///
  /// Son dos nomenclaturas distintas para lo mismo (`jpn` frente a `ja`), y sin
  /// esta tabla elegir japonés en el panel dejaría al motor de Windows sin
  /// idioma que buscar.
  static String tagForTesseractCode(String code) {
    const Map<String, String> table = <String, String>{
      'jpn': 'ja',
      'jpn_vert': 'ja',
      'chi_sim': 'zh-Hans',
      'chi_sim_vert': 'zh-Hans',
      'chi_tra': 'zh-Hant',
      'chi_tra_vert': 'zh-Hant',
      'kor': 'ko',
      'kor_vert': 'ko',
      'eng': 'en',
      'spa': 'es',
      'fra': 'fr',
      'deu': 'de',
      'ita': 'it',
      'por': 'pt',
      'rus': 'ru',
      'ara': 'ar',
      'hin': 'hi',
      'tha': 'th',
      'vie': 'vi',
      'tur': 'tr',
      'pol': 'pl',
      'nld': 'nl',
      'swe': 'sv',
      'ces': 'cs',
      'ell': 'el',
      'heb': 'he',
      'ind': 'id',
      'ukr': 'uk',
    };
    // Solo el primero: Windows reconoce con un idioma a la vez, al contrario que
    // Tesseract, que acepta `jpn+eng`.
    final String first = code.split('+').first.trim().toLowerCase();
    return table[first] ?? first;
  }

  /// `true` si Windows puede reconocer [tag], comparando también solo el idioma.
  ///
  /// La comparación es por prefijo porque el sistema devuelve variantes
  /// regionales (`en-US`, `es-ES`) y lo que se pide es el idioma (`en`, `es`).
  static bool covers(List<String> available, String tag) {
    final String wanted = tag.toLowerCase();
    final String base = wanted.split('-').first;
    for (final String candidate in available) {
      final String lower = candidate.toLowerCase();
      if (lower == wanted) return true;
      if (lower.split('-').first == base) return true;
    }
    return false;
  }

  @override
  Future<OcrResult> recognize(
    Uint8List png, {
    required Duration timeout,
  }) async {
    final Stopwatch watch = Stopwatch()..start();
    try {
      final Map<Object?, Object?>? reply = await _channel
          .invokeMapMethod<Object?, Object?>('recognize', <String, Object?>{
            'png': png,
            'language': languageTag,
          })
          .timeout(timeout);

      final String raw = (reply?['text'] as String? ?? '');
      return OcrResult(
        text: normalizeOcrText(raw),
        durationMs: watch.elapsedMilliseconds,
      );
    } on PlatformException catch (e) {
      throw StageFailure(
        Stage.ocr,
        e.message ?? 'El OCR de Windows falló.',
        hint: e.code == 'sin_idioma'
            ? 'Añade el idioma en Configuración de Windows → Hora e idioma → '
                  'Idioma y región, o cambia a Tesseract.'
            : 'Prueba a cambiar de motor en la pestaña Idiomas.',
        cause: e,
      );
    } catch (e) {
      throw StageFailure(
        Stage.ocr,
        'El OCR de Windows no respondió a tiempo.',
        hint: 'Sube el tiempo máximo de OCR o reduce el tamaño de la zona.',
        cause: e,
      );
    }
  }

  @override
  Future<String?> checkAvailability() async {
    final List<String> available = await systemLanguages();
    if (available.isEmpty) {
      return 'Este Windows no trae el componente de OCR. Usa Tesseract.';
    }
    if (languageTag.isEmpty) return null;
    if (!covers(available, languageTag)) {
      return 'Windows no tiene instalado el idioma "$languageTag". '
          'Añádelo en Configuración → Hora e idioma → Idioma y región, '
          'o cambia a Tesseract.';
    }
    return null;
  }

  @override
  void dispose() {
    // Libera el motor que el lado nativo mantiene en caché. Si falla, no hay
    // nada que hacer: el proceso se está cerrando.
    _channel.invokeMethod<void>('dispose').catchError((Object _) {});
  }
}
