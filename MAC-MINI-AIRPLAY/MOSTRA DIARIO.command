#!/bin/bash
# Doppio clic: mostra le ultime righe del diario di AirPlay Automatico
# e le copia negli appunti, così puoi incollarle (cmd + V) nel messaggio a Claude.
clear
LOG="$HOME/Library/Logs/AirPlayAutomatico.log"
echo ""
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║   AIRPLAY AUTOMATICO — diario                    ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo ""
if [ ! -f "$LOG" ]; then
  echo "  Il diario è ancora vuoto: l'app non è mai partita."
  read -r -p "  Premi Invio per chiudere."
  exit 0
fi
echo "  macOS $(sw_vers -productVersion) — $(scutil --get ComputerName 2>/dev/null)"
echo "  Ultime 40 righe di $LOG:"
echo ""
tail -n 40 "$LOG" | sed 's/^/     /'
{
  echo "macOS $(sw_vers -productVersion)"
  tail -n 40 "$LOG"
} | pbcopy
echo ""
echo "  ✓ Le ho copiate negli appunti: incollale (cmd + V) nel messaggio a Claude."
echo "    (con lo stesso account iCloud sui due Mac, puoi incollarle anche dall'altro Mac)"
echo ""
read -r -p "  Premi Invio per chiudere."
