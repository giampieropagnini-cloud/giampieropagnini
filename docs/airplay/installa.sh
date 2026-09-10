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

DEST="$HOME/Desktop/MAC-MINI-AIRPLAY"

# Da dove scaricare, in ordine: il sito; poi GitHub (ramo principale);
# poi GitHub (ramo di lavoro, utile finche' l'aggiornamento non e' ancora sul sito).
RAW="https://raw.githubusercontent.com/giampieropagnini-cloud/giampieropagnini"
CANDIDATI="${AIRPLAY_BASE:-https://giampieropagnini.com/airplay $RAW/main/MAC-MINI-AIRPLAY $RAW/claude/mac-mini-airplay-monitor-zk2qhc/MAC-MINI-AIRPLAY}"
BASE=""
for c in $CANDIDATI; do
  if curl -fsSL -m 20 "$c/avvio-app.applescript" -o /dev/null 2>/dev/null; then
    BASE="$c"
    break
  fi
done
if [ -z "$BASE" ]; then
  echo ""
  echo "  ✗ Non riesco a raggiungere i file da scaricare. Controlla la connessione e riprova."
  echo "    In alternativa copia la cartella MAC-MINI-AIRPLAY dall'altro Mac con AirDrop"
  echo "    e apri INSTALLA AIRPLAY AUTOMATICO.command da lì."
  exit 1
fi

echo ""
echo "  AirPlay Automatico — scarico i file da $BASE"
echo "  nella cartella: $DEST"
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
    echo "    Controlla la connessione e riprova, oppure copia la cartella MAC-MINI-AIRPLAY"
    echo "    dall'altro Mac con AirDrop e apri INSTALLA AIRPLAY AUTOMATICO.command da lì."
    exit 1
  fi
}
scarica "INSTALLA%20AIRPLAY%20AUTOMATICO.command" "INSTALLA AIRPLAY AUTOMATICO.command"
scarica "RIMUOVI%20AIRPLAY%20AUTOMATICO.command"  "RIMUOVI AIRPLAY AUTOMATICO.command"
scarica "airplay-automatico.applescript"           "airplay-automatico.applescript"
scarica "avvio-app.applescript"                    "avvio-app.applescript"
scarica "GUIDA-AIRPLAY-AUTOMATICO.md"              "GUIDA-AIRPLAY-AUTOMATICO.md"
scarica "MOSTRA%20DIARIO.command"                  "MOSTRA DIARIO.command"
chmod +x "INSTALLA AIRPLAY AUTOMATICO.command" "RIMUOVI AIRPLAY AUTOMATICO.command" "MOSTRA DIARIO.command"
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
