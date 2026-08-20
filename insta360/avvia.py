#!/usr/bin/env python3
# Punto di partenza del programma: avvia il server locale e apre il browser.
# Da terminale:  python3 avvia.py            (porta 8360, browser automatico)
#                python3 avvia.py --porta 9000 --senza-browser

import argparse
import sys
import threading
import webbrowser

if sys.version_info < (3, 8):
    print("Serve Python 3.8 o più recente. Su Mac: installa gli strumenti con")
    print("  xcode-select --install")
    sys.exit(1)

from app import VERSIONE                    # noqa: E402
from app.server import crea_server          # noqa: E402
from app.drivers import telecomando_ble     # noqa: E402


def principale() -> None:
    parser = argparse.ArgumentParser(description="Controllo Telecamere Insta360")
    parser.add_argument("--porta", type=int, default=8360)
    parser.add_argument("--senza-browser", action="store_true")
    argomenti = parser.parse_args()

    server, porta = crea_server(argomenti.porta)
    indirizzo = "http://127.0.0.1:%d" % porta

    print()
    print("  ╔══════════════════════════════════════════════════╗")
    print("  ║   CONTROLLO TELECAMERE INSTA360  —  v%-8s    ║" % VERSIONE)
    print("  ╚══════════════════════════════════════════════════╝")
    print()
    print("  Il programma è acceso. Aprilo nel browser qui:")
    print("     " + indirizzo)
    print()
    if telecomando_ble.DISPONIBILE:
        print("  Telecomando Bluetooth: componente installato ✓")
    else:
        print("  Telecomando Bluetooth: non installato (facoltativo).")
        print("  Per provarlo:  python3 -m pip install bless")
    print()
    print("  Per chiudere: torna qui e premi Ctrl+C (o chiudi la finestra).")
    print()

    if not argomenti.senza_browser:
        threading.Timer(0.6, lambda: webbrowser.open(indirizzo)).start()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n  A presto!")
    finally:
        server.server_close()


if __name__ == "__main__":
    principale()
