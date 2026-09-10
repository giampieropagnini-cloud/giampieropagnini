#!/bin/bash
# Doppio clic: mostra le ultime righe del diario di AirPlay Automatico,
# le manda per email alla tua Gmail (così Claude le legge da solo)
# e le copia anche negli appunti.
clear
LOG="$HOME/Library/Logs/AirPlayAutomatico.log"
DEST="giampiero.pagnini@gmail.com"
OGGETTO="Diario AirPlay Automatico"

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

INFO="macOS $(sw_vers -productVersion) — $(scutil --get ComputerName 2>/dev/null)"
APPLETV=$(head -n 1 "$HOME/Library/Application Support/AirPlay Automatico/apple-tv.txt" 2>/dev/null)
TESTO=$(
  echo "$INFO"
  echo "Apple TV configurata: $APPLETV"
  echo ""
  tail -n 200 "$LOG"
)

echo "  $INFO"
echo "  Ultime righe di $LOG:"
echo ""
tail -n 200 "$LOG" | sed 's/^/     /'
echo ""

printf '%s\n' "$TESTO" | pbcopy 2>/dev/null

echo "  ⟳ Provo a mandarlo per email a $DEST con Mail..."
echo "    (se macOS chiede se il Terminale può controllare «Mail», clicca OK)"
if osascript - "$DEST" "$OGGETTO" "$TESTO" <<'EOF' >/dev/null 2>&1
on run argv
	set dest to item 1 of argv
	set oggetto to item 2 of argv
	set testo to item 3 of argv
	with timeout of 40 seconds
		tell application "Mail"
			set msg to make new outgoing message with properties {subject:oggetto, content:testo & return, visible:false}
			tell msg to make new to recipient at end of to recipients with properties {address:dest}
			send msg
		end tell
	end timeout
end run
EOF
then
  echo ""
  echo "  ✓ Inviato. Ora scrivi a Claude soltanto: «inviato». Lo legge lui dalla tua Gmail."
else
  echo ""
  echo "  ⚠ Non sono riuscito a mandarlo con Mail (forse Mail non è configurato su questo Mac)."
  echo "    Il diario è comunque negli appunti: incollalo (cmd + V) nel messaggio a Claude,"
  echo "    anche dall'altro Mac se i due Mac hanno lo stesso account iCloud."
fi
echo ""
read -r -p "  Premi Invio per chiudere."
