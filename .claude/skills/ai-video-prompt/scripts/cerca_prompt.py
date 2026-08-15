#!/usr/bin/env python3
"""Cerca nel catalogo di prompt video allegato alla skill.

I due file JSON sono grandi (500 KB e 90 KB): usa questo script invece di
aprirli, altrimenti riempi il contesto per niente.

Esempi:
    python3 scripts/cerca_prompt.py --lista-categorie
    python3 scripts/cerca_prompt.py --categoria social-viral
    python3 scripts/cerca_prompt.py --modello kling-3.0 --limite 5
    python3 scripts/cerca_prompt.py --testo "perfume bottle"
    python3 scripts/cerca_prompt.py --matrice --lista-scenari
    python3 scripts/cerca_prompt.py --matrice --scenario perfume --modello veo-3.1
"""

import argparse
import json
import os
import sys
import textwrap

BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "kit", "data")
ALL_PROMPTS = os.path.join(BASE, "all-prompts.json")
MATRIX = os.path.join(BASE, "cross-model-matrix.json")


def carica(path):
    if not os.path.exists(path):
        sys.exit(f"File non trovato: {path}")
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def tronca(testo, larghezza=2000):
    testo = " ".join(str(testo).split())
    return testo if len(testo) <= larghezza else testo[:larghezza] + " […]"


def mostra_prompt(p, verboso):
    print(f"\n[{p.get('id')}] {p.get('title', '')}")
    print(f"  modello: {p.get('model')}   categoria: {p.get('category')}")
    params = p.get("params") or {}
    if params:
        print("  parametri: " + ", ".join(f"{k}={v}" for k, v in params.items()))
    print(textwrap.indent(textwrap.fill(tronca(p.get("prompt", "")), 96), "  "))
    if verboso:
        if p.get("notes"):
            print(f"  note: {tronca(p['notes'], 400)}")
        src = p.get("source") or {}
        if src:
            print(f"  fonte: {src.get('name', '')} {src.get('url', '')}")


def cerca_catalogo(args):
    dati = carica(ALL_PROMPTS)
    prompts = dati["prompts"]

    if args.lista_categorie:
        print(f"{dati['total']} prompt in catalogo.\n")
        print("CATEGORIE")
        conteggi = {}
        for p in prompts:
            conteggi[p.get("category")] = conteggi.get(p.get("category"), 0) + 1
        for c in dati.get("categories", []):
            n = conteggi.get(c["id"], 0)
            print(f"  {c['id']:<24} {n:>4}   {c.get('zh', '')}")
        print("\nMODELLI")
        for mid, m in dati.get("models", {}).items():
            print(f"  {mid:<20} {m.get('name', '')}")
        return

    risultati = prompts
    if args.categoria:
        risultati = [p for p in risultati if p.get("category") == args.categoria]
    if args.modello:
        risultati = [p for p in risultati if args.modello in str(p.get("model", ""))]
    if args.testo:
        ago = args.testo.lower()
        risultati = [
            p for p in risultati
            if ago in json.dumps(p, ensure_ascii=False).lower()
        ]

    if not risultati:
        print("Nessun risultato. Prova --lista-categorie per vedere i filtri validi.")
        return

    print(f"{len(risultati)} risultati (mostro {min(len(risultati), args.limite)}):")
    for p in risultati[: args.limite]:
        mostra_prompt(p, args.verboso)


def cerca_matrice(args):
    dati = carica(MATRIX)
    scenari = dati["scenarios"]

    if args.lista_scenari or not (args.scenario or args.modello or args.testo):
        print(
            f"{dati['total_prompts']} prompt = "
            f"{dati['total_scenarios']} scenari x {dati['total_models']} modelli.\n"
        )
        for s in scenari:
            print(f"  {s['id']:<26} {s.get('category', ''):<20} {s.get('title', '')}")
        print("\nModelli disponibili per ogni scenario:")
        print("  " + ", ".join(scenari[0]["by_model"].keys()))
        return

    trovati = scenari
    if args.scenario:
        ago = args.scenario.lower()
        trovati = [s for s in trovati if ago in s["id"].lower() or ago in s.get("category", "").lower()]
    if args.testo:
        ago = args.testo.lower()
        trovati = [s for s in trovati if ago in json.dumps(s, ensure_ascii=False).lower()]

    if not trovati:
        print("Nessuno scenario corrisponde. Usa --lista-scenari.")
        return

    for s in trovati[: args.limite]:
        print(f"\n=== {s['id']} — {s.get('title', '')}")
        print(f"    caso d'uso: {s.get('use_case', '')}")
        ancora = s.get("core_anchor") or {}
        if ancora and args.verboso:
            for k, v in ancora.items():
                print(f"    {k}: {tronca(v, 200)}")
        for mid, blocco in s["by_model"].items():
            if args.modello and args.modello not in mid:
                continue
            print(f"\n  --- {mid}")
            if blocco.get("method"):
                print(f"      metodo: {tronca(blocco['method'], 300)}")
            print(textwrap.indent(textwrap.fill(tronca(blocco.get("prompt", "")), 92), "      "))


def main():
    ap = argparse.ArgumentParser(
        description="Cerca nel catalogo prompt video della skill ai-video-prompt.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    ap.add_argument("--matrice", action="store_true",
                    help="cerca nella matrice cross-modello invece che nel catalogo")
    ap.add_argument("--categoria", help="filtra per categoria (es. social-viral)")
    ap.add_argument("--modello", help="filtra per modello (es. kling-3.0)")
    ap.add_argument("--scenario", help="solo con --matrice: id o categoria dello scenario")
    ap.add_argument("--testo", help="cerca una stringa libera")
    ap.add_argument("--limite", type=int, default=8, help="numero massimo di risultati (default 8)")
    ap.add_argument("--lista-categorie", action="store_true", help="elenca categorie e modelli")
    ap.add_argument("--lista-scenari", action="store_true", help="elenca gli scenari della matrice")
    ap.add_argument("--verboso", action="store_true", help="mostra note e fonti")
    args = ap.parse_args()

    if args.matrice or args.lista_scenari:
        cerca_matrice(args)
    else:
        cerca_catalogo(args)


if __name__ == "__main__":
    main()
