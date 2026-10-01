#!/usr/bin/env python3
"""Legge e cambia le impostazioni dell'adattatore MIDI di Hanz Tech dal Mac, senza Chrome.

L'adattatore va attaccato al Mac col cavo micro USB. Parla sulla porta seriale del Teensy
con gli stessi comandi del configuratore web (JSON, READALL e SAVEALL; firmware 3.4.x).

    python3 configura-adattatore.py                       # mostra le impostazioni
    python3 configura-adattatore.py disable_transport=0   # le cambia, poi le rilegge

Per il sync out col clock di Bobina servono disable_transport=0 e sync_out_enabled=1.
"""
import glob
import json
import os
import sys
import termios
import time

KEYS = ["po_midi_channel", "disable_transport", "sync_out_enabled", "po_cc_control", "midi_ppqn",
        "ble_midi_enabled", "version"]


def porta():
    trovate = sorted(glob.glob("/dev/cu.usbmodem*"))
    if not trovate:
        sys.exit("Nessun adattatore sul cavo USB: attaccalo al Mac con la micro USB e riprova.")
    if len(trovate) > 1:
        print("Più porte USB, uso la prima:", ", ".join(trovate))
    return trovate[0]


def apri(nome):
    fd = os.open(nome, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    attr = termios.tcgetattr(fd)
    attr[0] = 0                                   # iflag
    attr[1] = 0                                   # oflag
    attr[2] = termios.CS8 | termios.CREAD | termios.CLOCAL
    attr[3] = 0                                   # lflag: niente eco, niente righe
    attr[4] = attr[5] = termios.B115200
    termios.tcsetattr(fd, termios.TCSANOW, attr)
    termios.tcflush(fd, termios.TCIOFLUSH)
    return fd


def manda(fd, comando, secondi=2.0):
    os.write(fd, json.dumps(comando).encode())
    fine = time.time() + secondi
    dati = b""
    while time.time() < fine:
        try:
            pezzo = os.read(fd, 4096)
        except BlockingIOError:
            pezzo = b""
        if pezzo:
            dati += pezzo
            fine = max(fine, time.time() + 0.3)
        else:
            time.sleep(0.02)
    testo = dati.decode(errors="replace")
    # la risposta è un oggetto JSON; prima possono esserci righe di avvio
    inizio = testo.find("{")
    if inizio < 0:
        return testo, None
    try:
        return testo, json.loads(testo[inizio:testo.rfind("}") + 1])
    except json.JSONDecodeError:
        return testo, None


def mostra(cfg):
    for k in KEYS:
        if k in cfg:
            print(f"  {k} = {cfg[k]}")


def main():
    nome = porta()
    fd = apri(nome)
    print("Adattatore su", nome)
    _, cfg = manda(fd, {"command": "READALL"})
    if cfg is None:
        sys.exit("L'adattatore non ha risposto. Se c'è la microSD, le impostazioni vengono da lì: toglila.")
    print("Adesso:")
    mostra(cfg)
    nuove = {}
    for arg in sys.argv[1:]:
        k, _, v = arg.partition("=")
        if k not in cfg:
            sys.exit(f"Non conosco «{k}».")
        nuove[k] = int(v)
    if not nuove:
        return
    _, esito = manda(fd, {"command": "SAVEALL", "data": nuove})
    print("Salvato:" if esito and esito.get("status") == "Success" else "Risposta:", esito)
    _, cfg = manda(fd, {"command": "READALL"})
    print("Dopo:")
    mostra(cfg or {})
    sbagliate = [k for k, v in nuove.items() if not cfg or cfg.get(k) != v]
    if sbagliate:
        sys.exit("Non hanno preso: " + ", ".join(sbagliate))
    print("Fatto.")


if __name__ == "__main__":
    main()
