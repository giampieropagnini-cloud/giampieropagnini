#!/bin/bash
# Installazione e avvio in un colpo solo del Controllo Telecamere Insta360.
# Si usa incollando nel Terminale la riga che Claude ti ha dato in chat:
# scarica l'ultima versione sulla Scrivania, prepara il Bluetooth e avvia.
# Nessuna domanda, nessun doppio clic, nessun blocco di sicurezza del Mac.

set -u

URL="https://github.com/giampieropagnini-cloud/giampieropagnini/archive/refs/heads/claude/insta360-camera-control-rm58p9.tar.gz"
DEST="$HOME/Desktop/Controllo Telecamere Insta360"

echo ""
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║   CONTROLLO TELECAMERE INSTA360 — installazione  ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo ""

if ! command -v python3 >/dev/null 2>&1; then
  echo "  ✗ Manca Python 3. Scrivi nel Terminale:  xcode-select --install"
  echo "    accetta l'installazione (pochi minuti), poi rilancia la riga di Claude."
  exit 1
fi

TMP=$(mktemp -d) || exit 1

echo "  Passo 1 di 3 — Scarico l'ultima versione…"
if ! curl -fsSL "$URL" -o "$TMP/programma.tgz"; then
  echo "  ✗ Scaricamento non riuscito: controlla la connessione internet e riprova."
  rm -rf "$TMP"
  exit 1
fi
mkdir -p "$DEST"
if ! tar xzf "$TMP/programma.tgz" --strip-components=1 -C "$DEST"; then
  echo "  ✗ Non riesco ad aprire il pacchetto scaricato: riprova fra qualche minuto."
  rm -rf "$TMP"
  exit 1
fi
rm -rf "$TMP"
echo "  ✓ Programma pronto sulla Scrivania, cartella «Controllo Telecamere Insta360»."
echo ""

echo "  Passo 2 di 3 — Componente Bluetooth (serve per le telecamere vere)…"
if python3 -c "import bless, bleak" >/dev/null 2>&1; then
  echo "  ✓ Già installato."
else
  echo "    (ci può volere un minuto, è normale che resti fermo un po')"
  if python3 -m pip install --user --quiet bless bleak 2>/dev/null \
     || python3 -m pip install --user --quiet --break-system-packages bless bleak 2>/dev/null; then
    echo "  ✓ Componente Bluetooth installato."
  else
    echo "  ✗ Non ci sono riuscito: il programma parte lo stesso (in demo)."
    echo "    Al prossimo avvio riproverà da solo."
  fi
fi
echo ""

echo "  Passo 3 di 3 — Avvio il programma!"
echo "  ────────────────────────────────────────────────────"
echo "  LASCIA APERTA questa finestra: è il motore del programma."
echo "  La prossima volta ti basta il doppio clic su"
echo "  «CONTROLLA LE TELECAMERE.command» nella cartella sulla Scrivania."
echo ""

cd "$DEST/insta360" || exit 1
exec python3 avvia.py
