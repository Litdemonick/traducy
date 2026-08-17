/// Etapa del pipeline donde ocurrió un fallo. Sirve para mostrar al usuario
/// exactamente qué parte hay que arreglar en lugar de un error genérico.
enum Stage { capture, preprocess, ocr, translate, render }

class StageFailure implements Exception {
  StageFailure(this.stage, this.message, {this.hint, this.cause});

  final Stage stage;
  final String message;

  /// Texto accionable para el usuario ("instala Tesseract", "revisa la API key").
  final String? hint;
  final Object? cause;

  @override
  String toString() => 'StageFailure(${stage.name}): $message';
}
