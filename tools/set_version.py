"""Fija la version de Traducy en todos los sitios a la vez.

Uso:
    python tools/set_version.py 1.0.0.bs
    python tools/set_version.py 1.2.0

El esquema es MAYOR.MENOR.PARCHE con un sufijo opcional de letras para las
revisiones pequenas y frecuentes: 1.0.0.a, 1.0.0.b, ... 1.0.0.z, 1.0.0.aa, y asi.

Por que hace falta un script y no basta con editar a mano: Windows almacena la
version del ejecutable como cuatro numeros, y "bs" no es un numero. Asi que la
misma version vive en dos formas y hay que mantenerlas en sincronia:

    visible   1.0.0.bs     lo que ve la gente, en el instalador y en la app
    numerica  1.0.0.71     lo que guardan los metadatos del .exe

El sufijo se traduce a numero como las columnas de una hoja de calculo
(a=1 ... z=26, aa=27 ...), asi que el orden de versiones se conserva: cualquier
comparacion que haga Windows o el instalador da el mismo resultado que la
lectura humana.

Ficheros que actualiza:
    pubspec.yaml                 version: 1.0.0+71
    lib/src/core/version.dart    la cadena visible, para mostrarla en la app
    installer/traducy.iss        ambas formas, para el instalador
"""

from __future__ import annotations

import io
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

VERSION_PATTERN = re.compile(r"^(\d+)\.(\d+)\.(\d+)(?:\.([a-z]+))?$")


def suffix_to_number(suffix: str) -> int:
    """Convierte un sufijo de letras en un entero, como las columnas de Excel.

    Sin sufijo devuelve 0, que queda por debajo de 'a'. Asi una version sin
    letras es siempre anterior a la primera revision con letras.
    """
    total = 0
    for character in suffix:
        total = total * 26 + (ord(character) - ord("a") + 1)
    return total


def number_to_suffix(number: int) -> str:
    """Inversa de suffix_to_number, util para saber cual es la siguiente."""
    if number <= 0:
        return ""
    letters = ""
    while number > 0:
        number, remainder = divmod(number - 1, 26)
        letters = chr(ord("a") + remainder) + letters
    return letters


def parse(version: str) -> tuple[str, str, int]:
    match = VERSION_PATTERN.match(version.strip())
    if not match:
        raise SystemExit(
            f'Version no valida: "{version}".\n'
            "Formato esperado: 1.0.0 o 1.0.0.bs (letras minusculas al final)."
        )
    major, minor, patch, suffix = match.groups()
    build = suffix_to_number(suffix or "")
    visible = f"{major}.{minor}.{patch}" + (f".{suffix}" if suffix else "")
    numeric = f"{major}.{minor}.{patch}.{build}"
    return visible, numeric, build


def replace_once(path: Path, pattern: str, replacement: str) -> None:
    """Sustituye una sola coincidencia y falla si no la encuentra.

    Falla a proposito: un reemplazo silencioso que no ocurre deja el proyecto con
    versiones distintas en cada fichero, y eso se descubre tarde y mal.
    """
    text = io.open(path, encoding="utf-8").read()
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.MULTILINE)
    if count != 1:
        raise SystemExit(f"No se encontro el patron en {path}: {pattern}")
    io.open(path, "w", encoding="utf-8", newline="").write(updated)


def write_dart_version(visible: str, numeric: str, build: int) -> None:
    path = ROOT / "lib" / "src" / "core" / "version.dart"
    content = f'''// GENERADO POR tools/set_version.py — no editar a mano.
//
// La version se toca con:
//   python tools/set_version.py {visible}
//
// Existen dos formas de lo mismo porque Windows guarda la version del
// ejecutable como cuatro numeros y un sufijo de letras no lo es.

/// Version visible, la que se ensena a las personas.
const String appVersion = '{visible}';

/// Version numerica, la que llevan los metadatos del ejecutable.
const String appVersionNumeric = '{numeric}';

/// Numero de revision derivado del sufijo de letras ({build}).
const int appVersionBuild = {build};
'''
    io.open(path, "w", encoding="utf-8", newline="").write(content)


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(
            "Uso: python tools/set_version.py <version>\n"
            "Ejemplos: 1.0.0    1.0.0.a    1.0.0.bs    1.1.0.c"
        )

    visible, numeric, build = parse(sys.argv[1])

    # pubspec: Flutter exige version: X.Y.Z+entero, y de ahi salen los metadatos
    # del ejecutable que compila.
    base = visible.split(".")[0:3]
    replace_once(
        ROOT / "pubspec.yaml",
        r"^version:\s*.+$",
        f"version: {'.'.join(base)}+{build}",
    )

    write_dart_version(visible, numeric, build)

    iss = ROOT / "installer" / "traducy.iss"
    replace_once(
        iss,
        r'^#define MyAppVersion ".*"$',
        f'#define MyAppVersion "{visible}"',
    )
    replace_once(
        iss,
        r'^#define MyAppVersionNumeric ".*"$',
        f'#define MyAppVersionNumeric "{numeric}"',
    )

    following = number_to_suffix(build + 1)
    print(f"version visible    {visible}")
    print(f"version numerica   {numeric}")
    print(f"pubspec            {'.'.join(base)}+{build}")
    print(f"siguiente revision {'.'.join(base)}.{following}")


if __name__ == "__main__":
    main()
