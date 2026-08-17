/// Datos del proyecto, en un único sitio.
///
/// Existe para que el nombre del autor, la dirección del repositorio y los
/// enlaces no aparezcan copiados en cinco ficheros distintos: cuando cambie el
/// usuario de GitHub o se mueva el repositorio, se toca aquí y el actualizador,
/// el panel de información y la documentación siguen coincidiendo.
class About {
  const About._();

  static const String appName = 'Traducy';
  static const String tagline = 'Traductor de pantalla en tiempo real';

  static const String description =
      'Marca una zona sobre el juego y Traducy lee el texto que aparece ahí, '
      'mostrando la traducción como subtítulos por encima. No modifica el juego '
      'ni sus ficheros.';

  /// Cuenta de GitHub que publica el proyecto. El actualizador consulta las
  /// releases de aquí.
  static const String githubOwner = 'Litdemonick';
  static const String githubRepo = 'traducy';

  static const String author = 'Litdemonick';

  static const String repoUrl = 'https://github.com/$githubOwner/$githubRepo';
  static const String releasesUrl = '$repoUrl/releases';
  static const String latestReleaseUrl = '$releasesUrl/latest';
  static const String issuesUrl = '$repoUrl/issues';
  static const String authorUrl = 'https://github.com/$githubOwner';

  /// Componentes de terceros que conviene reconocer, con su licencia.
  static const List<(String, String, String)> credits =
      <(String, String, String)>[
        (
          'Tesseract OCR',
          'Apache 2.0',
          'https://github.com/tesseract-ocr/tesseract',
        ),
        ('Flutter', 'BSD 3-Clause', 'https://flutter.dev'),
        ('Inno Setup', 'Licencia propia', 'https://jrsoftware.org/isinfo.php'),
      ];
}
