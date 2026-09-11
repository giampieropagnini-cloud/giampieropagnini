"""Client per l'API locale della cornice Meural Canvas (porta 80, senza password).

Solo libreria standard di Python 3. Tutti gli endpoint sono GET tranne
`postcard`, che riceve un'immagine in multipart/form-data e la mostra subito.
"""
import json
import mimetypes
import urllib.error
import urllib.request
import uuid


class FrameError(Exception):
    pass


class Frame:
    def __init__(self, ip, timeout=10):
        self.ip = ip
        self.timeout = timeout

    # ---- primitive ---------------------------------------------------------

    def _get(self, path):
        url = f"http://{self.ip}/remote/{path}"
        try:
            with urllib.request.urlopen(url, timeout=self.timeout) as r:
                body = r.read().decode("utf-8", "replace")
        except (urllib.error.URLError, OSError) as e:
            raise FrameError(f"cornice {self.ip} non raggiungibile: {e}") from e
        try:
            return json.loads(body)
        except ValueError:
            return body

    def postcard(self, data, filename="image.jpg", content_type=None):
        """Mostra subito un'immagine (bytes) sulla cornice. Anteprima temporanea."""
        ctype = content_type or mimetypes.guess_type(filename)[0] or "image/jpeg"
        if ctype == "image/jpg":
            ctype = "image/jpeg"
        boundary = "----meural" + uuid.uuid4().hex
        body = b"".join([
            f"--{boundary}\r\n".encode(),
            f'Content-Disposition: form-data; name="photo"; filename="{filename}"\r\n'.encode(),
            f"Content-Type: {ctype}\r\n\r\n".encode(),
            data,
            f"\r\n--{boundary}--\r\n".encode(),
        ])
        req = urllib.request.Request(
            f"http://{self.ip}/remote/postcard",
            data=body,
            method="POST",
            headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
        )
        try:
            with urllib.request.urlopen(req, timeout=max(self.timeout, 30)) as r:
                return r.read().decode("utf-8", "replace")
        except (urllib.error.URLError, OSError) as e:
            raise FrameError(f"invio immagine fallito: {e}") from e

    # ---- comandi -----------------------------------------------------------

    def next(self):
        return self._get("control_command/set_key/right/")

    def prev(self):
        return self._get("control_command/set_key/left/")

    def key_up(self):
        return self._get("control_command/set_key/up/")

    def key_down(self):
        return self._get("control_command/set_key/down/")

    def sleep(self):
        return self._get("control_command/suspend")

    def wake(self):
        return self._get("control_command/resume")

    def set_backlight(self, value):
        value = max(0, min(100, int(value)))
        return self._get(f"control_command/set_backlight/{value}/")

    def als_off(self):
        return self._get("control_command/als_calibrate/off/")

    def set_orientation(self, orientation):
        if orientation not in ("portrait", "landscape"):
            raise ValueError("orientation deve essere portrait o landscape")
        return self._get(f"control_command/set_orientation/{orientation}")

    def change_gallery(self, gallery_id):
        return self._get(f"control_command/change_gallery/{gallery_id}")

    def change_item(self, item_id):
        return self._get(f"control_command/change_item/{item_id}")

    # ---- letture -----------------------------------------------------------

    def backlight(self):
        return self._get("get_backlight/")

    def is_sleeping(self):
        r = self._get("control_check/sleep/")
        if isinstance(r, dict):
            r = r.get("response", r.get("sleep", r))
        if isinstance(r, str):
            return r.strip().lower() in ("true", "1", "sleep", "sleeping")
        return bool(r)

    def system(self):
        return self._get("control_check/system/")

    def identify(self):
        return self._get("identify/")

    def wifi(self):
        return self._get("get_wifi_connections_json/")

    def galleries(self):
        return self._get("get_galleries_json/")

    def gallery_status(self):
        return self._get("get_gallery_status_json/")

    def gallery_items(self, gallery_id):
        return self._get(f"get_frame_items_by_gallery_json/{gallery_id}")

    def status(self):
        """Riassunto in una chiamata sola, tollerante agli errori parziali."""
        out = {}
        for key, fn in (
            ("system", self.system),
            ("sleeping", self.is_sleeping),
            ("backlight", self.backlight),
            ("now_playing", self.gallery_status),
        ):
            try:
                out[key] = fn()
            except FrameError as e:
                out[key] = {"error": str(e)}
        return out
