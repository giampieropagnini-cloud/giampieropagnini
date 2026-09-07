#!/bin/bash
# Scarica "AirPlay Automatico" e avvia l'installazione.
#
# Da usare sul Mac mini SENZA monitor (con l'iPad collegato per vedere).
# Apri il Terminale e scrivi questa riga, poi premi Invio:
#
#     curl -fsSL https://giampieropagnini.com/airplay/installa.sh | bash
#
# I file finiscono sulla Scrivania, nella cartella MAC-MINI-AIRPLAY,
# e parte subito l'installatore guidato.

BASE="${AIRPLAY_BASE:-https://giampieropagnini.com/airplay}"
DEST="$HOME/Desktop/MAC-MINI-AIRPLAY"

echo ""
echo "  AirPlay Automatico — scarico i file nella cartella:"
echo "  $DEST"
echo ""
mkdir -p "$DEST" || { echo "  ✗ Non riesco a creare la cartella."; exit 1; }
cd "$DEST" || exit 1

# nome nel sito (con %20 al posto degli spazi) -> nome del file sul Mac
scarica() {
  if curl -fsSL "$BASE/$1" -o "$2"; then
    echo "  ✓ $2"
  else
    echo ""
    echo "  ✗ Non riesco a scaricare: $BASE/$1"
    echo "    Forse l'aggiornamento del sito non è ancora online, o manca la connessione."
    echo "    Riprova fra qualche minuto, oppure copia la cartella MAC-MINI-AIRPLAY"
    echo "    dall'altro Mac con AirDrop e apri INSTALLA AIRPLAY AUTOMATICO.command da lì."
    exit 1
  fi
}
scarica "INSTALLA%20AIRPLAY%20AUTOMATICO.command" "INSTALLA AIRPLAY AUTOMATICO.command"
scarica "RIMUOVI%20AIRPLAY%20AUTOMATICO.command"  "RIMUOVI AIRPLAY AUTOMATICO.command"
scarica "airplay-automatico.applescript"           "airplay-automatico.applescript"
scarica "avvio-app.applescript"                    "avvio-app.applescript"
scarica "GUIDA-AIRPLAY-AUTOMATICO.md"              "GUIDA-AIRPLAY-AUTOMATICO.md"
chmod +x "INSTALLA AIRPLAY AUTOMATICO.command" "RIMUOVI AIRPLAY AUTOMATICO.command"
xattr -d com.apple.quarantine ./* >/dev/null 2>&1

echo ""
echo "  ✓ Tutto scaricato. Ora parte l'installazione guidata..."
sleep 2
[ -n "$AIRPLAY_SOLO_SCARICA" ] && exit 0
if [ -t 0 ]; then
  exec bash "./INSTALLA AIRPLAY AUTOMATICO.command"
else
  exec bash "./INSTALLA AIRPLAY AUTOMATICO.command" < /dev/tty
fi
