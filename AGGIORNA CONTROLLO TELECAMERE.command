#!/bin/bash
# Doppio clic su questo file per scaricare l'ultima versione del
# Controllo Telecamere Insta360 (sostituisce i file di questa cartella).
#
# Tutto il lavoro sta dentro la funzione main, che viene letta per intera
# prima di essere eseguita: così lo script può aggiornare anche se stesso
# senza incidenti.

main() {
  DEST="$(cd "$(dirname "$0")" && pwd)"
  URL="https://github.com/giampieropagnini-cloud/giampieropagnini/archive/refs/heads/claude/insta360-camera-control-rm58p9.tar.gz"
  clear
  echo ""
  echo "  ╔══════════════════════════════════════════════════╗"
  echo "  ║   AGGIORNAMENTO CONTROLLO TELECAMERE             ║"
  echo "  ╚══════════════════════════════════════════════════╝"
  echo ""

  if [ -d "$DEST/.git" ]; then
    echo "  Questa è la copia collegata a GitHub: qui gli aggiornamenti"
    echo "  arrivano da Claude via git, questo file non serve."
    read -r -p "  Premi Invio per chiudere."
    exit 0
  fi

  TMP=$(mktemp -d) || exit 1
  echo "  ⟳ Scarico l'ultima versione…"
  if ! curl -sSL "$URL" -o "$TMP/programma.tgz"; then
    echo "  ✗ Scaricamento non riuscito: controlla la connessione e riprova."
    rm -rf "$TMP"
    read -r -p "  Premi Invio per chiudere."
    exit 1
  fi

  if ! tar xzf "$TMP/programma.tgz" -C "$TMP"; then
    echo "  ✗ Il file scaricato non si apre: riprova fra qualche minuto."
    rm -rf "$TMP"
    read -r -p "  Premi Invio per chiudere."
    exit 1
  fi

  SRC=$(find "$TMP" -maxdepth 1 -type d -name "giampieropagnini-*" | head -1)
  if [ -z "$SRC" ]; then
    echo "  ✗ Contenuto inatteso nel pacchetto scaricato."
    rm -rf "$TMP"
    read -r -p "  Premi Invio per chiudere."
    exit 1
  fi

  cp -R "$SRC/." "$DEST/"
  rm -rf "$TMP"

  echo "  ✓ Aggiornamento completato."
  echo ""
  echo "  Ora fai doppio clic su «CONTROLLA LE TELECAMERE.command»"
  echo "  per aprire la nuova versione."
  echo ""
  read -r -p "  Premi Invio per chiudere."
  exit 0
}

main "$@"
exit 0
