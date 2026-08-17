"""Genera los iconos de Traducy a partir del logo original en JPEG.

Produce:
  assets/logo_mark.png                     el símbolo suelto, fondo transparente
  assets/logo_traducy.png                  logo completo, transparente
  assets/tray_icon.ico                     icono de la bandeja del sistema
  windows/runner/resources/app_icon.ico    icono del ejecutable y barra de tareas

El JPEG de partida tiene fondo gris claro y no admite transparencia, así que el
canal alfa se reconstruye de dos formas distintas según la pieza:

  - El símbolo es un cuadrado redondeado de color saturado: se recorta y se le
    aplica una máscara de esquinas redondeadas generada a 4x y reducida, lo que
    da bordes suaves sin restos del fondo.

  - La palabra "traducy" es tinta oscura sobre gris claro. Ahí se invierte la
    mezcla alfa: si el píxel observado es C = A*F + (1-A)*B, conociendo el fondo
    B y la tinta F se despeja A. Eso devuelve un texto nítido y bien
    antialiasado, en lugar del halo gris que deja un simple umbral.

Todo con Pillow, sin numpy: las operaciones por canal de ImageChops ya corren en
C, así que no hace falta traer otra dependencia.
"""

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

ROOT = Path("t:/Traducy")
SOURCE = ROOT / "assets" / "logo_traducy.jpg"

# Tamaños que pide Windows: 16 y 32 para listas y barra de tareas, 48 para el
# explorador, 256 para vistas grandes.
ICO_SIZES = [16, 20, 24, 32, 40, 48, 64, 128, 256]

# Frontera entre símbolo y palabra, como fracción de la altura.
SPLIT = 0.62


def median(values):
    ordered = sorted(values)
    return ordered[len(ordered) // 2]


def background_color(image: Image.Image):
    """Color del fondo, medido en las cuatro esquinas."""
    w, h = image.size
    patch = 12
    samples = []
    for box in (
        (0, 0, patch, patch),
        (w - patch, 0, w, patch),
        (0, h - patch, patch, h),
        (w - patch, h - patch, w, h),
    ):
        samples.extend(image.crop(box).getdata())
    return tuple(median([s[c] for s in samples]) for c in range(3))


def content_mask(image: Image.Image, bg, tolerance: int = 26) -> Image.Image:
    """Máscara binaria de lo que no es fondo."""
    flat = Image.new("RGB", image.size, bg)
    diff = ImageChops.difference(image, flat).split()
    # Máximo por canal: un cambio fuerte en un solo canal ya es contenido.
    strongest = ImageChops.lighter(ImageChops.lighter(diff[0], diff[1]), diff[2])
    return strongest.point(lambda v: 255 if v > tolerance else 0, mode="1").convert("L")


def region_bbox(mask: Image.Image, top: float, bottom: float):
    """Caja del contenido dentro de una banda horizontal de la imagen."""
    w, h = mask.size
    y0, y1 = int(h * top), int(h * bottom)
    band = mask.crop((0, y0, w, y1))
    box = band.getbbox()
    if box is None:
        raise ValueError("banda sin contenido")
    return box[0], box[1] + y0, box[2], box[3] + y0


def measure_corner_radius(mask: Image.Image, box) -> int:
    """Radio real de las esquinas del arte, en píxeles.

    Se mide en lugar de estimarse: una máscara con el radio equivocado deja ver
    fondo en las esquinas o come el borde del icono, y a 16 px eso se nota. El
    truco es que la curva de la esquina termina exactamente a `r` píxeles del
    borde superior, así que basta buscar la primera fila cuyo contenido ya llega
    al borde izquierdo del recuadro.
    """
    x0, y0, x1, y1 = box
    height = y1 - y0
    for offset in range(1, height // 2):
        row = mask.crop((x0, y0 + offset, x1, y0 + offset + 1))
        bounds = row.getbbox()
        if bounds is not None and bounds[0] <= 1:
            return offset
    # Sin medida fiable se cae al valor típico de un icono de escritorio.
    return round((x1 - x0) * 0.225)


def rounded_alpha(size: int, radius: int) -> Image.Image:
    """Máscara de cuadrado redondeado, dibujada a 8x y reducida.

    El supermuestreo es lo que da el borde limpio: dibujar la curva al tamaño
    final produce un contorno escalonado que se ve en cuanto el icono aparece
    grande en el explorador.
    """
    scale = 8
    big = size * scale
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, big - 1, big - 1), radius=radius * scale, fill=255
    )
    return mask.resize((size, size), Image.LANCZOS)


def extract_mark(source: Image.Image, mask: Image.Image):
    """Recorta el símbolo y le pone fondo transparente.

    Se conserva la resolución nativa del recorte: ampliar a un tamaño redondo
    solo interpola y ablanda el resultado, y todos los usos posteriores
    (bandeja, ejecutable, cabecera del panel) son reducciones.
    """
    x0, y0, x1, y1 = region_bbox(mask, 0.0, SPLIT)

    # Se fuerza a cuadrado desde el centro: el arte es un cuadrado redondeado y
    # una diferencia de un par de píxeles deformaría las esquinas.
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2

    # Y se recorta un poco hacia dentro. El original lleva una sombra suave y un
    # borde antialiasado contra el gris del fondo; sin este margen, esos píxeles
    # claros quedan dentro de la máscara y dibujan un halo alrededor del icono.
    inset = 0.055
    side = max(x1 - x0, y1 - y0)
    # Lado entero y esquina calculada a partir de él: así el recorte es
    # exactamente cuadrado y la máscara circular encaja sin deformarse.
    out_size = int(side * (1 - inset))
    left = round(cx - out_size / 2)
    top = round(cy - out_size / 2)
    crop = source.crop((left, top, left + out_size, top + out_size))
    # El radio se mide sobre el arte original y se ajusta al recorte, que es algo
    # más pequeño por el margen anterior.
    radius = round(measure_corner_radius(mask, (x0, y0, x1, y1)) * out_size / side)

    mark = crop.convert("RGBA")
    mark.putalpha(rounded_alpha(out_size, radius))
    return mark, (x0, y0, x1, y1), radius


def ink_color(region: Image.Image, region_mask: Image.Image):
    """Color de la tinta: mediana del 5 % de píxeles más oscuros del texto."""
    pixels = [
        p
        for p, m in zip(region.getdata(), region_mask.getdata())
        if m > 127
    ]
    if not pixels:
        return (30, 40, 70)
    pixels.sort(key=lambda p: p[0] + p[1] + p[2])
    darkest = pixels[: max(1, len(pixels) // 20)]
    return tuple(median([p[c] for p in darkest]) for c in range(3))


def extract_wordmark(source: Image.Image, mask: Image.Image, bg):
    """Palabra con alfa reconstruido y su caja en el original."""
    x0, y0, x1, y1 = region_bbox(mask, SPLIT, 1.0)
    region = source.crop((x0, y0, x1, y1))
    region_mask = mask.crop((x0, y0, x1, y1))
    ink = ink_color(region, region_mask)

    # A = (B - C) / (B - F) por canal; se toma el máximo porque el canal con más
    # contraste entre tinta y fondo es el más fiable.
    channels = []
    for c, channel in enumerate(region.split()):
        span = bg[c] - ink[c]
        if abs(span) < 1:
            continue
        # (bg - canal) escalado a 0-255 según el margen disponible.
        lifted = ImageChops.subtract(Image.new("L", region.size, bg[c]), channel)
        channels.append(lifted.point(lambda v, s=span: min(255, int(v * 255 / s))))

    if not channels:
        alpha = region_mask
    else:
        alpha = channels[0]
        for extra in channels[1:]:
            alpha = ImageChops.lighter(alpha, extra)

    # El JPEG deja motas de compresión en el fondo que se traducen en alfa muy
    # bajo. Recortarlas evita una suciedad gris alrededor del texto.
    alpha = alpha.point(lambda v: 0 if v < 10 else v)

    word = Image.new("RGBA", region.size, (*ink, 0))
    word.putalpha(alpha)
    return word, (x0, y0, x1, y1)


def build_full_logo(mark: Image.Image, mark_box, word: Image.Image, word_box):
    """Compone símbolo y palabra sobre lienzo transparente, conservando la
    proporción y la separación del original."""
    mark_side = max(mark_box[2] - mark_box[0], mark_box[3] - mark_box[1])
    target = mark.size[0]
    scale = target / mark_side

    word_w = round((word_box[2] - word_box[0]) * scale)
    word_h = round((word_box[3] - word_box[1]) * scale)
    word = word.resize((word_w, word_h), Image.LANCZOS)

    gap = max(0, round((word_box[1] - mark_box[3]) * scale))
    pad = round(target * 0.06)
    width = max(target, word_w) + pad * 2
    height = pad + target + gap + word_h + pad

    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    canvas.alpha_composite(mark, ((width - target) // 2, pad))
    canvas.alpha_composite(word, ((width - word_w) // 2, pad + target + gap))
    return canvas


def save_ico(mark: Image.Image, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    mark.save(destination, format="ICO", sizes=[(s, s) for s in ICO_SIZES])


def on_canvas(art: Image.Image, size, margin: float, bg=(255, 255, 255)):
    """Coloca el arte centrado y completo sobre un lienzo opaco del tamano dado.

    `thumbnail` respeta la proporcion y nunca amplia, asi que el arte entra
    entero: es lo que evita que el logo salga recortado.
    """
    canvas = Image.new("RGB", size, bg)
    limit = (
        max(1, int(size[0] * (1 - margin * 2))),
        max(1, int(size[1] * (1 - margin * 2))),
    )
    piece = art.copy()
    piece.thumbnail(limit, Image.LANCZOS)
    # Se compone sobre el fondo antes de pegar: el BMP no lleva canal alfa y sin
    # esto los bordes suaves saldrian negros.
    flat = Image.new("RGB", piece.size, bg)
    flat.paste(piece, (0, 0), piece)
    canvas.paste(
        flat,
        ((size[0] - piece.size[0]) // 2, (size[1] - piece.size[1]) // 2),
    )
    return canvas


def save_wizard_images(mark: Image.Image, full: Image.Image, folder: Path) -> None:
    """Imagenes del asistente de Inno Setup, en BMP y a los tamanos que espera.

    Los tamanos no son arbitrarios: el panel lateral de las paginas de bienvenida
    y de fin mide 164x314, y el icono de cabecera 55x55. Una imagen mas grande no
    se reduce, se recorta, y el logo aparece cortado. Se generan tambien las
    variantes al doble para pantallas a 200 %, que Inno elige segun el DPI.
    """
    folder.mkdir(parents=True, exist_ok=True)

    # Panel vertical: el logo completo, con aire suficiente para que respire.
    on_canvas(full, (164, 314), margin=0.10).save(folder / "wizard_large.bmp")
    on_canvas(full, (328, 628), margin=0.10).save(folder / "wizard_large@2x.bmp")

    # Cabecera: solo el simbolo, casi a sangre porque es diminuto.
    on_canvas(mark, (55, 55), margin=0.04).save(folder / "wizard_small.bmp")
    on_canvas(mark, (110, 110), margin=0.04).save(folder / "wizard_small@2x.bmp")


def main() -> None:
    source = Image.open(SOURCE).convert("RGB")
    bg = background_color(source)
    mask = content_mask(source, bg)

    mark, mark_box, radius = extract_mark(source, mask)
    word, word_box = extract_wordmark(source, mask, bg)
    full = build_full_logo(mark, mark_box, word, word_box)

    (ROOT / "assets").mkdir(exist_ok=True)
    mark.save(ROOT / "assets" / "logo_mark.png")
    full.save(ROOT / "assets" / "logo_traducy.png")
    save_ico(mark, ROOT / "assets" / "tray_icon.ico")
    save_ico(mark, ROOT / "windows" / "runner" / "resources" / "app_icon.ico")
    save_wizard_images(mark, full, ROOT / "installer")

    print(f"fondo detectado      {bg}")
    print(f"símbolo              {mark_box} -> {mark.size}, radio {radius} px")
    print(f"palabra              {word_box} -> {word.size}")
    print(f"logo_mark.png        {mark.size}")
    print(f"logo_traducy.png     {full.size}")
    print(f"iconos .ico          {ICO_SIZES}")
    print("asistente Inno       164x314 y 55x55 (mas variantes @2x)")


if __name__ == "__main__":
    main()
