"""Preparazione immagini per la cornice.

Se Pillow è installato (`pip3 install pillow`) le immagini vengono ruotate
secondo l'EXIF e adattate alla risoluzione della cornice (1920x1080 o
1080x1920) con letterbox o ritaglio. Senza Pillow il file viene inviato così
com'è: funziona lo stesso, la cornice adatta da sola.
"""
import io
import os

try:
    from PIL import Image, ImageOps
    HAVE_PIL = True
except ImportError:  # pragma: no cover
    HAVE_PIL = False

EXTENSIONS = (".jpg", ".jpeg", ".png", ".gif")
SIZES = {"landscape": (1920, 1080), "portrait": (1080, 1920)}


def is_image(name):
    return name.lower().endswith(EXTENSIONS) and not name.startswith(".")


def list_images(folder):
    """Immagini nella cartella e nelle sue sottocartelle dirette (es. `nft/`),
    come percorsi relativi alla cartella."""
    if not folder or not os.path.isdir(folder):
        return []
    out = []
    for f in sorted(os.listdir(folder)):
        p = os.path.join(folder, f)
        if is_image(f):
            out.append(f)
        elif os.path.isdir(p) and not f.startswith("."):
            out.extend(os.path.join(f, g) for g in sorted(os.listdir(p)) if is_image(g))
    return out


def prepare(path, orientation="auto", mode="fit", background="#000000", quality=90):
    """Ritorna (bytes, filename, content_type) pronti per la postcard."""
    name = os.path.basename(path)
    if not HAVE_PIL or name.lower().endswith(".gif"):
        with open(path, "rb") as f:
            return f.read(), name, None

    img = Image.open(path)
    img = ImageOps.exif_transpose(img)
    if img.mode not in ("RGB",):
        img = img.convert("RGB")

    if orientation == "auto":
        orientation = "landscape" if img.width >= img.height else "portrait"
    target = SIZES.get(orientation, SIZES["landscape"])

    if mode == "crop":
        out = ImageOps.fit(img, target, method=Image.LANCZOS, centering=(0.5, 0.5))
    else:
        out = ImageOps.pad(img, target, method=Image.LANCZOS, color=background)

    buf = io.BytesIO()
    out.save(buf, "JPEG", quality=quality, optimize=True)
    base = os.path.splitext(name)[0]
    return buf.getvalue(), base + ".jpg", "image/jpeg"
