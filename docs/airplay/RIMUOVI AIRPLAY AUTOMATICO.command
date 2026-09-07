#!/bin/bash
# Doppio clic su questo file per togliere "AirPlay Automatico" dal Mac mini.
clear
NOME_APP="AirPlay Automatico"

echo ""
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║   AIRPLAY AUTOMATICO — rimozione                 ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo ""
read -r -p "  Vuoi davvero togliere «$NOME_APP»? (s/n) " RISPOSTA
case "$RISPOSTA" in
  s|S|si|Si|SI|sì|Sì) ;;
  *) echo "  Non ho toccato nulla."; read -r -p "  Premi Invio per chiudere."; exit 0 ;;
esac

echo "  (se macOS chiede se il Terminale può controllare «System Events», clicca OK)"
osascript -e "tell application \"System Events\" to delete (every login item whose name is \"$NOME_APP\")" >/dev/null 2>&1
rm -rf "/Applications/$NOME_APP.app" "$HOME/Applications/$NOME_APP.app"
rm -rf "$HOME/Library/Application Support/$NOME_APP"

echo ""
echo "  ✓ Rimosso. Il Mac non si collegherà più da solo all'Apple TV."
echo "    (Il diario resta in ~/Library/Logs/AirPlayAutomatico.log: puoi cancellarlo.)"
echo "    Se vuoi, togli anche la voce «$NOME_APP» da"
echo "    Impostazioni di Sistema → Privacy e sicurezza → Accessibilità."
echo ""
read -r -p "  Premi Invio per chiudere questa finestra."
