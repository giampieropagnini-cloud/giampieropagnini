#!/usr/bin/env python3
"""Trova la cornice Meural sulla rete di casa, senza entrare nel router.

Prova tutti gli indirizzi della tua rete wifi (es. 192.168.1.1 … 254) e
chiede a ciascuno se risponde come una cornice Meural sulla porta 80.

Uso:
  python3 trova_cornice.py            # usa la rete del computer
  python3 trova_cornice.py 192.168.0  # oppure indica la rete a mano
"""
import json
import socket
import subprocess
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor


def rete_locale():
    """Prefisso della rete (es. '192.168.1') letto dall'IP del computer."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("192.0.2.1", 80))  # non invia nulla, serve solo a scegliere l'interfaccia
        ip = s.getsockname()[0]
        s.close()
    except OSError:
        return None
    return ip.rsplit(".", 1)[0]


def prova(ip):
    try:
        with urllib.request.urlopen(f"http://{ip}/remote/identify/", timeout=1.5) as r:
            body = r.read(2000).decode("utf-8", "replace")
    except Exception:  # noqa: BLE001
        return None
    try:
        data = json.loads(body)
    except ValueError:
        data = body
    return ip, data


def main():
    prefix = sys.argv[1].rstrip(".") if len(sys.argv) > 1 else rete_locale()
    if not prefix:
        sys.exit("Non riesco a capire la rete: passala a mano, es. python3 trova_cornice.py 192.168.1")
    print(f"Cerco la cornice su {prefix}.1 … {prefix}.254 (qualche secondo)…")
    ips = [f"{prefix}.{i}" for i in range(1, 255)]
    trovate = []
    with ThreadPoolExecutor(max_workers=64) as ex:
        for res in ex.map(prova, ips):
            if res:
                trovate.append(res)
    if not trovate:
        print("Nessuna cornice trovata. Controlla che sia accesa e sulla stessa wifi del computer.")
        print("Se la rete non è quella giusta, indicala: python3 trova_cornice.py 192.168.0")
        return 1
    for ip, data in trovate:
        print(f"\nCornice trovata: {ip}")
        print(json.dumps(data, indent=2, ensure_ascii=False) if isinstance(data, (dict, list)) else data)
        print(f"\nProva subito:  python3 meural_local.py {ip} status")
    return 0


if __name__ == "__main__":
    sys.exit(main())
