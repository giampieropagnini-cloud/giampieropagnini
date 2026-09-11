"""Slideshow locale e watchdog per la cornice.

Un thread in background:
- se lo slideshow è attivo, manda un'immagine della cartella alla cornice
  (postcard) ogni `interval` secondi, in ordine o casuale;
- rispetta la fascia notturna (spegne lo schermo all'ora `night_from`,
  lo riaccende all'ora `night_to`);
- se la cornice si addormenta da sola in orario attivo, la risveglia.
"""
import datetime as dt
import logging
import os
import random
import threading
import time

from frame import FrameError
import images

log = logging.getLogger("slideshow")


def _parse_hm(s):
    if not s:
        return None
    h, m = s.split(":")
    return dt.time(int(h), int(m))


def in_night(now, night_from, night_to):
    """True se `now` cade nella fascia notturna (che può scavalcare mezzanotte)."""
    a, b = _parse_hm(night_from), _parse_hm(night_to)
    if not a or not b or a == b:
        return False
    t = now.time()
    if a < b:
        return a <= t < b
    return t >= a or t < b


class Slideshow(threading.Thread):
    def __init__(self, frame, config, folder_fn):
        super().__init__(daemon=True)
        self.frame = frame
        self.config = config
        self.folder_fn = folder_fn  # ritorna la cartella immagini assoluta
        self.lock = threading.Lock()
        self.running = False
        self.wake_event = threading.Event()
        self.queue = []
        self.index = 0
        self.current = None
        self.last_sent = None
        self.last_error = None
        self.night_applied = None  # None / "sleep" / "wake"
        self.stop_flag = False

    # ---- controllo ---------------------------------------------------------

    def start_show(self):
        with self.lock:
            self.running = True
            self._rebuild_queue()
        self.wake_event.set()

    def stop_show(self):
        with self.lock:
            self.running = False

    def skip(self):
        """Passa subito alla prossima immagine dello slideshow."""
        self.wake_event.set()

    def show_file(self, path):
        """Mostra subito un file, fuori dallo slideshow."""
        self._send(path)

    def state(self):
        with self.lock:
            return {
                "running": self.running,
                "current": self.current,
                "last_sent": self.last_sent,
                "last_error": self.last_error,
                "queued": len(self.queue),
                "night": in_night(dt.datetime.now(), self.config.get("night_from"),
                                  self.config.get("night_to")),
            }

    # ---- interno -----------------------------------------------------------

    def _rebuild_queue(self):
        files = images.list_images(self.folder_fn())
        if self.config.get("shuffle"):
            random.shuffle(files)
        self.queue = files
        self.index = 0

    def _next_file(self):
        with self.lock:
            if not self.queue or self.index >= len(self.queue):
                self._rebuild_queue()
            if not self.queue:
                return None
            f = self.queue[self.index]
            self.index += 1
            return os.path.join(self.folder_fn(), f)

    def _send(self, path):
        cfg = self.config
        data, name, ctype = images.prepare(
            path,
            orientation=cfg.get("orientation", "auto"),
            mode=cfg.get("fit", "fit"),
            background=cfg.get("background", "#000000"),
        )
        try:
            self.frame.postcard(data, name, ctype)
            with self.lock:
                self.current = os.path.basename(path)
                self.last_sent = time.time()
                self.last_error = None
            log.info("inviata %s (%d KB)", name, len(data) // 1024)
        except FrameError as e:
            with self.lock:
                self.last_error = str(e)
            log.warning("%s", e)

    def _apply_night(self, night):
        """Spegne all'inizio della notte e riaccende alla fine. Fuori dalla
        notte non tocca la cornice finché non è stata lei a spegnerla."""
        want = "sleep" if night else "wake"
        if self.night_applied == want:
            return
        if want == "wake" and self.night_applied is None:
            self.night_applied = "wake"
            return
        try:
            if night:
                self.frame.sleep()
                log.info("fascia notturna: schermo spento")
            else:
                self.frame.wake()
                log.info("fine fascia notturna: schermo acceso")
            self.night_applied = want
        except FrameError as e:
            log.warning("%s", e)

    def _watchdog(self):
        """Risveglia la cornice se dorme in orario attivo con lo slideshow acceso."""
        try:
            if self.frame.is_sleeping():
                self.frame.wake()
                log.info("watchdog: cornice risvegliata")
        except FrameError as e:
            log.warning("watchdog: %s", e)

    def run(self):
        last_watchdog = 0
        while not self.stop_flag:
            cfg = self.config
            night = in_night(dt.datetime.now(), cfg.get("night_from"), cfg.get("night_to"))
            if cfg.get("night_enabled"):
                self._apply_night(night)
            else:
                self.night_applied = None

            if self.running and not night:
                if cfg.get("watchdog", True) and time.time() - last_watchdog > 60:
                    self._watchdog()
                    last_watchdog = time.time()
                path = self._next_file()
                if path:
                    self._send(path)
                interval = max(5, int(cfg.get("interval", 300)))
            else:
                interval = 30

            self.wake_event.wait(interval)
            self.wake_event.clear()
