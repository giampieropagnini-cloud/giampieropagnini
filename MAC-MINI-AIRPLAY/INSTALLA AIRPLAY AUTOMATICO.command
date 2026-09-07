#!/bin/bash
# Doppio clic su questo file per installare "AirPlay Automatico" sul Mac mini.
# Da quel momento, ogni volta che accendi il Mac, lui si collega da solo
# all'Apple TV (Duplica schermo), senza bisogno dell'iPad.
cd "$(dirname "$0")"
clear

NOME_APP="AirPlay Automatico"
SORGENTE="airplay-automatico.applescript"
SORGENTE_APP="avvio-app.applescript"
CONFIG_DIR="$HOME/Library/Application Support/$NOME_APP"
CONFIG="$CONFIG_DIR/apple-tv.txt"
SCRIPT_COMPILATO="$CONFIG_DIR/airplay-automatico.scpt"
LOG="$HOME/Library/Logs/AirPlayAutomatico.log"

chiudi() {
  echo ""
  read -r -p "  Premi Invio per chiudere questa finestra."
  exit "${1:-0}"
}

echo ""
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║   AIRPLAY AUTOMATICO — installazione             ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo ""
echo "  Alla fine, quando accendi il Mac mini, lui si collega da solo"
echo "  all'Apple TV come monitor. L'iPad con Duet non servirà più."
echo ""

# --- controlli ---
if [ "$(uname)" != "Darwin" ]; then
  echo "  ✗ Questo file va aperto sul Mac mini, non su altri computer."
  chiudi 1
fi
if [ ! -f "$SORGENTE" ] || [ ! -f "$SORGENTE_APP" ]; then
  echo "  ✗ Non trovo i file dello script nella stessa cartella di questo installatore."
  echo "    Servono: $SORGENTE e $SORGENTE_APP"
  chiudi 1
fi
echo "  Questo Mac: $(scutil --get ComputerName 2>/dev/null) — macOS $(sw_vers -productVersion)"
echo ""

# --- 1. quale Apple TV ---
echo "  PASSO 1 di 4 — Quale Apple TV?"
echo "  ─────────────────────────────────────"
echo "  Cerco le Apple TV in casa (5 secondi)..."
echo "  (se macOS chiede se il Terminale può cercare dispositivi sulla rete locale, clicca Consenti)"
TMP=$(mktemp)
dns-sd -B _airplay._tcp local. > "$TMP" 2>/dev/null &
DNSPID=$!
sleep 5
kill "$DNSPID" 2>/dev/null
wait "$DNSPID" 2>/dev/null
IO=$(scutil --get ComputerName 2>/dev/null)
TROVATI=()
while IFS= read -r riga; do
  [ -n "$riga" ] || continue
  [ "$riga" = "$IO" ] && continue
  TROVATI+=("$riga")
done < <(grep -E '^[0-9:.]+ +Add ' "$TMP" \
          | sed -E 's/^.*_airplay\._tcp\.[[:space:]]+//' \
          | LC_ALL=C awk '{ while (match($0, /\\[0-9][0-9][0-9]/)) { $0 = substr($0, 1, RSTART-1) sprintf("%c", substr($0, RSTART+1, 3)+0) substr($0, RSTART+4) }; print }' \
          | sort -u)
rm -f "$TMP"

NOME_TV=""
if [ ${#TROVATI[@]} -gt 0 ]; then
  echo ""
  echo "  Ho trovato questi dispositivi AirPlay:"
  i=1
  for n in "${TROVATI[@]}"; do
    echo "     $i) $n"
    i=$((i+1))
  done
  echo "     0) Nessuno di questi: lo scrivo io"
  echo ""
  while true; do
    read -r -p "  Scrivi il numero dell'Apple TV e premi Invio: " SCELTA
    if [ "$SCELTA" = "0" ]; then break; fi
    if [[ "$SCELTA" =~ ^[0-9]+$ ]] && [ "$SCELTA" -ge 1 ] && [ "$SCELTA" -le ${#TROVATI[@]} ]; then
      NOME_TV="${TROVATI[$((SCELTA-1))]}"
      break
    fi
    echo "  Non ho capito, riprova."
  done
else
  echo ""
  echo "  Non ho trovato nessuna Apple TV in rete (forse è spenta, o non è sulla stessa rete Wi-Fi)."
  echo "  Non fa niente: scrivi tu il nome."
fi
while [ -z "$NOME_TV" ]; do
  read -r -p "  Scrivi il nome esatto dell'Apple TV (come appare in Duplica schermo): " NOME_TV
done
mkdir -p "$CONFIG_DIR"
printf '%s\n' "$NOME_TV" > "$CONFIG"
echo ""
echo "  ✓ Apple TV scelta: $NOME_TV"
echo ""

# --- 2. creazione dell'app ---
echo "  PASSO 2 di 4 — Preparo l'app «$NOME_APP»"
echo "  ─────────────────────────────────────"
ERR=$(mktemp)
if ! osacompile -o "$SCRIPT_COMPILATO" "$SORGENTE" 2>"$ERR"; then
  echo "  ✗ Non riesco a compilare lo script:"
  sed 's/^/     /' "$ERR"
  rm -f "$ERR"
  chiudi 1
fi

APP=""
for candidato in "/Applications/$NOME_APP.app" "$HOME/Applications/$NOME_APP.app"; do
  [ -d "$candidato" ] && APP="$candidato" && break
done
if [ -z "$APP" ]; then
  APP_DIR="/Applications"
  if [ ! -w "$APP_DIR" ]; then
    APP_DIR="$HOME/Applications"
    mkdir -p "$APP_DIR"
  fi
  APP="$APP_DIR/$NOME_APP.app"
  if ! osacompile -o "$APP" "$SORGENTE_APP" 2>"$ERR"; then
    echo "  ✗ Non riesco a creare l'app:"
    sed 's/^/     /' "$ERR"
    rm -f "$ERR"
    chiudi 1
  fi
  # niente icona nel Dock: lavora in silenzio
  /usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$APP/Contents/Info.plist" >/dev/null 2>&1 \
    || /usr/libexec/PlistBuddy -c "Set :LSUIElement true" "$APP/Contents/Info.plist" >/dev/null 2>&1
  echo "  ✓ App creata in: $APP"
else
  echo "  ✓ App già presente ($APP): ho aggiornato solo lo script."
fi
rm -f "$ERR"
echo ""

# --- 3. avvio automatico all'accensione ---
echo "  PASSO 3 di 4 — Avvio automatico all'accensione"
echo "  ─────────────────────────────────────"
echo "  (se macOS chiede se il Terminale può controllare «System Events», clicca OK)"
if osascript >/dev/null 2>&1 <<EOF
tell application "System Events"
	try
		delete (every login item whose name is "$NOME_APP")
	end try
	make login item at end with properties {path:"$APP", hidden:false}
end tell
EOF
then
  echo "  ✓ «$NOME_APP» partirà da solo a ogni accensione."
else
  echo "  ⚠ Non sono riuscito ad aggiungerlo automaticamente. Fallo a mano:"
  echo "    Impostazioni di Sistema → Generali → Elementi login → premi + → scegli"
  echo "    $APP"
fi
echo ""

FILEVAULT=0
if fdesetup status 2>/dev/null | grep -qi "FileVault is On"; then FILEVAULT=1; fi

# --- 4. permessi e prova ---
echo "  PASSO 4 di 4 — Permessi e prova (solo la prima volta)"
echo "  ─────────────────────────────────────"
echo "  Ora apro «$NOME_APP». macOS può mostrare uno o due avvisi:"
echo ""
echo "   • «$NOME_APP vuole controllare System Events»"
echo "       → clicca OK (o Consenti)"
echo ""
echo "   • «$NOME_APP vuole controllare il computer con le funzioni di Accessibilità»"
echo "       → clicca «Apri Impostazioni di Sistema»"
echo "       → nella finestra che si apre ATTIVA l'interruttore accanto a «$NOME_APP»"
echo "         (se non c'è, premi + e scegli l'app nella cartella Applicazioni)"
echo ""
read -r -p "  Premi Invio per aprirla adesso... "
open "$APP"
echo ""
echo "  Quando hai attivato l'interruttore (o se non è comparso nessun avviso),"
read -r -p "  torna qui e premi Invio: faccio una prova di collegamento all'Apple TV... "
open "$APP"
echo ""
echo "  ⟳ Aspetto 40 secondi. Guarda la TV: dovrebbe accendersi con lo schermo del Mac."
sleep 40
echo ""
echo "  Ultime righe del diario ($LOG):"
if [ -f "$LOG" ]; then
  tail -n 8 "$LOG" | sed 's/^/     /'
else
  echo "     (ancora vuoto: probabilmente l'app aspetta un permesso; controlla gli avvisi sullo schermo)"
fi

echo ""
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║   FATTO!                                         ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo ""
echo "  Da adesso, quando accendi il Mac mini:"
echo "     1. scrivi la password come fai sempre (alla cieca) e premi Invio"
echo "     2. aspetta circa un minuto"
echo "     3. la TV si accende con lo schermo del Mac. L'iPad non serve più."
echo ""
echo "  Per provare senza riavviare: cerca «$NOME_APP» con Spotlight (cmd + spazio) e aprilo."
echo "  Se qualcosa non va, mandami il diario: $LOG"
echo ""
echo "  ─────────────────────────────────────────────────"
echo "  FACOLTATIVO: togliere anche la password all'accensione"
echo "  ─────────────────────────────────────────────────"
if [ "$FILEVAULT" = "1" ]; then
  echo "  Su questo Mac FileVault è acceso: il login automatico non è possibile"
  echo "  finché resta acceso. Se vuoi toglierlo, vedi la guida (GUIDA-AIRPLAY-AUTOMATICO.md)."
else
  echo "  Impostazioni di Sistema → Utenti e gruppi → «Accedi automaticamente»"
  echo "  → scegli il tuo nome → scrivi la password. Da quel momento basta accendere."
fi
chiudi 0
