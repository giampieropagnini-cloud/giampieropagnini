#!/bin/bash
# Doppio clic su questo file per installare "AirPlay Automatico" sul Mac mini.
# Da quel momento:
#   - ogni volta che accendi il Mac, lui si collega da solo all'Apple TV (Duplica schermo)
#   - se la TV si stacca, basta toccare la tastiera (o ctrl+cmd+Q, password, Invio)
#     e la TV torna sul Mac da sola, grazie alla "guardia"
cd "$(dirname "$0")"
clear

NOME_APP="AirPlay Automatico"
SORGENTE="airplay-automatico.applescript"
SORGENTE_APP="avvio-app.applescript"
CONFIG_DIR="$HOME/Library/Application Support/$NOME_APP"
CONFIG="$CONFIG_DIR/apple-tv.txt"
SCRIPT_COMPILATO="$CONFIG_DIR/airplay-automatico.scpt"
GUARDIA="$CONFIG_DIR/guardia.sh"
GUARDIA_PLIST="$HOME/Library/LaunchAgents/com.giampieropagnini.airplay-automatico.guardia.plist"
LOG="$HOME/Library/Logs/AirPlayAutomatico.log"
BUNDLE_ID="com.giampieropagnini.airplay-automatico"

chiudi() {
  echo ""
  read -r -p "  Premi Invio per chiudere questa finestra."
  exit "${1:-0}"
}

# chiedi_si_no "domanda" default -> 0 = si', 1 = no
chiedi_si_no() {
  local risposta
  read -r -p "  $1 " risposta
  risposta=${risposta:-$2}
  case "$risposta" in
    s|S|si|Si|SI|sì|Sì|y|Y|yes) return 0 ;;
    *) return 1 ;;
  esac
}

echo ""
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║   AIRPLAY AUTOMATICO — installazione             ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo ""
echo "  Alla fine, quando accendi il Mac mini, lui si collega da solo"
echo "  all'Apple TV come monitor. E se la TV si stacca, basta toccare"
echo "  la tastiera: torna da sola. L'iPad con Duet non servirà più."
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
mkdir -p "$CONFIG_DIR" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"

# --- 1. quale Apple TV ---
echo "  PASSO 1 di 4 — Quale Apple TV?"
echo "  ─────────────────────────────────────"
NOME_TV=""
ATTUALE=$(head -n 1 "$CONFIG" 2>/dev/null)
if [ -n "$ATTUALE" ]; then
  echo "  Apple TV già impostata: $ATTUALE"
  if chiedi_si_no "La tengo? (Invio = sì, n = ne scelgo un'altra)" s; then
    NOME_TV="$ATTUALE"
  fi
fi
if [ -z "$NOME_TV" ]; then
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
fi
printf '%s\n' "$NOME_TV" > "$CONFIG"
echo ""
echo "  ✓ Apple TV: $NOME_TV"
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

# L'app va rifatta se manca, se non è la nostra, o se la firma non è più valida
# (una firma rotta fa sì che la spunta in Accessibilità non valga nulla).
RIFARE=0
ID_VECCHIO=""
if [ -z "$APP" ]; then
  RIFARE=1
  APP_DIR="/Applications"
  if [ ! -w "$APP_DIR" ]; then
    APP_DIR="$HOME/Applications"
    mkdir -p "$APP_DIR"
  fi
  APP="$APP_DIR/$NOME_APP.app"
else
  ID_VECCHIO=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP/Contents/Info.plist" 2>/dev/null)
  if [ "$ID_VECCHIO" != "$BUNDLE_ID" ] || ! codesign --verify --deep --strict "$APP" >/dev/null 2>&1; then
    RIFARE=1
  fi
fi

APP_RIFATTA=0
if [ "$RIFARE" = "1" ]; then
  pkill -f "$NOME_APP.app/Contents/MacOS/" >/dev/null 2>&1
  # dimentica i vecchi permessi: con l'app rifatta vanno ridati (macOS li richiede da solo)
  for id in "$ID_VECCHIO" "$BUNDLE_ID"; do
    [ -n "$id" ] || continue
    tccutil reset Accessibility "$id" >/dev/null 2>&1
    tccutil reset AppleEvents "$id" >/dev/null 2>&1
  done
  rm -rf "$APP"
  if ! osacompile -o "$APP" "$SORGENTE_APP" 2>"$ERR"; then
    echo "  ✗ Non riesco a creare l'app:"
    sed 's/^/     /' "$ERR"
    rm -f "$ERR"
    chiudi 1
  fi
  PLIST="$APP/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$PLIST" >/dev/null 2>&1 \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $BUNDLE_ID" "$PLIST" >/dev/null 2>&1
  # niente icona nel Dock: lavora in silenzio
  /usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$PLIST" >/dev/null 2>&1 \
    || /usr/libexec/PlistBuddy -c "Set :LSUIElement true" "$PLIST" >/dev/null 2>&1
  # firma l'app (firma locale): così la spunta in Accessibilità resta valida
  if codesign --force --deep --sign - "$APP" >/dev/null 2>&1 && codesign --verify --deep --strict "$APP" >/dev/null 2>&1; then
    echo "  ✓ App creata e firmata: $APP"
  else
    echo "  ⚠ App creata ma non sono riuscito a firmarla: $APP"
    echo "    (può funzionare lo stesso; se i permessi non vengono accettati, dimmelo)"
  fi
  APP_RIFATTA=1
else
  echo "  ✓ App già presente e a posto ($APP): ho aggiornato solo lo script."
fi
rm -f "$ERR"
printf '%s\n' "$APP" > "$CONFIG_DIR/app.txt"
echo ""

# --- 3. avvio automatico, guardia, schermo ---
echo "  PASSO 3 di 4 — Avvio automatico e ricollegamento"
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
echo "  La «guardia»: se la TV si stacca (o sei andato sull'Apple TV) e poi tocchi la"
echo "  tastiera o il mouse del Mac, entro mezzo minuto la TV torna sul Mac da sola."
echo "  Finché non tocchi il Mac non fa nulla: puoi guardare l'Apple TV in pace."
echo "  Sequenza sicura, alla cieca: ctrl + cmd + Q, poi password e Invio."
if chiedi_si_no "La attivo? (Invio = sì, n = no)" s; then
  cat > "$GUARDIA" <<'EOF'
#!/bin/bash
# La "guardia" di AirPlay Automatico. launchd la esegue ogni 20 secondi.
# Se la TV non e' collegata e tu stai usando il Mac (tastiera o mouse toccati da poco,
# oppure hai appena sbloccato lo schermo con la password), avvia AirPlay Automatico
# che la ricollega. Se non tocchi il Mac (per esempio stai guardando l'Apple TV) non fa nulla.

NOME_APP="AirPlay Automatico"
CONFIG_DIR="$HOME/Library/Application Support/$NOME_APP"
LOG="$HOME/Library/Logs/AirPlayAutomatico.log"
SECONDI_ATTIVITA=90      # "stai usando il Mac" = tastiera o mouse toccati negli ultimi 90 secondi
PAUSA_TRA_AVVII=150      # non riavviare l'app piu' spesso di cosi' (secondi)
FLAG_BLOCCATO="$CONFIG_DIR/guardia-bloccato"

scrivi() { printf '%s  [guardia] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG"; }

NOME_TV=$(head -n 1 "$CONFIG_DIR/apple-tv.txt" 2>/dev/null)
[ -n "$NOME_TV" ] || exit 0

# il diario non deve crescere all'infinito
if [ -f "$LOG" ] && [ "$(stat -f %z "$LOG" 2>/dev/null || echo 0)" -gt 2000000 ]; then
  tail -n 2000 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi

# nei primi 3 minuti dopo l'accensione ci pensa l'avvio automatico
avvio=$(sysctl -n kern.boottime 2>/dev/null | awk '{ v=$4; gsub(/[^0-9]/, "", v); print v }')
ora=$(date +%s)
if [ -n "$avvio" ] && [ $((ora - avvio)) -lt 180 ]; then exit 0; fi

# l'app sta gia' lavorando?
pgrep -f "$NOME_APP.app/Contents/MacOS/" >/dev/null 2>&1 && exit 0

# schermo bloccato? (serve la password) allora non si puo' fare nulla: me lo segno
if ioreg -n Root -d1 2>/dev/null | grep -Eq 'CGSSessionScreenIsLocked"? *= *(Yes|1|true)'; then
  touch "$FLAG_BLOCCATO"
  exit 0
fi

# appena sbloccato con la password? allora la TV va ricollegata subito
sbloccato=0
if [ -f "$FLAG_BLOCCATO" ]; then
  rm -f "$FLAG_BLOCCATO"
  sbloccato=1
fi

# tastiera o mouse toccati da poco?
idle=$(ioreg -c IOHIDSystem 2>/dev/null | awk '/HIDIdleTime/ { v=$NF; gsub(/[^0-9]/, "", v); print int(v/1000000000); exit }')
if [ "$sbloccato" = "0" ]; then
  if [ -z "$idle" ]; then
    if [ ! -f "$CONFIG_DIR/guardia-avviso" ]; then
      scrivi "non riesco a leggere da quanto non tocchi il Mac: la guardia lavora solo dopo lo sblocco con la password"
      touch "$CONFIG_DIR/guardia-avviso"
    fi
    exit 0
  fi
  [ "$idle" -le "$SECONDI_ATTIVITA" ] || exit 0
fi

# la TV e' gia' collegata?
/usr/sbin/system_profiler SPDisplaysDataType 2>/dev/null | grep -F -q "$NOME_TV" && exit 0

# non insistere troppo (dopo uno sblocco invece si parte subito)
ultimo=$(cat "$CONFIG_DIR/guardia-ultimo" 2>/dev/null || echo 0)
if [ "$sbloccato" = "0" ] && [ $((ora - ultimo)) -lt "$PAUSA_TRA_AVVII" ]; then exit 0; fi
echo "$ora" > "$CONFIG_DIR/guardia-ultimo"

touch "$CONFIG_DIR/avvio-guardia"
if [ "$sbloccato" = "1" ]; then
  scrivi "schermo appena sbloccato e TV non collegata: avvio $NOME_APP"
else
  scrivi "stai usando il Mac (ultimo tocco ${idle}s fa) e la TV non e' collegata: avvio $NOME_APP"
fi
APP=$(head -n 1 "$CONFIG_DIR/app.txt" 2>/dev/null)
if [ -n "$APP" ] && [ -d "$APP" ]; then
  open "$APP"
else
  open -a "$NOME_APP"
fi
EOF
  chmod +x "$GUARDIA"
  cat > "$GUARDIA_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>com.giampieropagnini.airplay-automatico.guardia</string>
	<key>ProgramArguments</key>
	<array>
		<string>/bin/bash</string>
		<string>$GUARDIA</string>
	</array>
	<key>StartInterval</key>
	<integer>20</integer>
	<key>RunAtLoad</key>
	<true/>
	<key>StandardErrorPath</key>
	<string>$HOME/Library/Logs/AirPlayAutomatico-guardia.log</string>
</dict>
</plist>
EOF
  launchctl bootout "gui/$(id -u)" "$GUARDIA_PLIST" >/dev/null 2>&1
  if launchctl bootstrap "gui/$(id -u)" "$GUARDIA_PLIST" >/dev/null 2>&1 || launchctl load -w "$GUARDIA_PLIST" >/dev/null 2>&1; then
    echo "  ✓ Guardia attiva."
  else
    echo "  ⚠ Non sono riuscito ad attivare la guardia: dimmelo."
  fi
else
  launchctl bootout "gui/$(id -u)" "$GUARDIA_PLIST" >/dev/null 2>&1
  rm -f "$GUARDIA_PLIST" "$GUARDIA"
  echo "  ✓ Guardia non attiva."
fi

echo ""
echo "  Lo schermo: di solito macOS «spegne lo schermo» dopo qualche minuto che non tocchi"
echo "  il Mac, e questo stacca la TV. Posso dirgli di non spegnerlo mai da solo."
echo "  (ti chiederà la password del Mac: scrivila e premi Invio; non si vede mentre la scrivi)"
if chiedi_si_no "Lo faccio? (Invio = sì, n = no)" s; then
  if sudo -p "  Password del Mac: " pmset -a displaysleep 0; then
    echo "  ✓ Lo schermo non si spegne più da solo (la TV la spegni tu col suo telecomando)."
  else
    echo "  ⚠ Non ci sono riuscito (password sbagliata?). Puoi farlo a mano:"
    echo "    Impostazioni di Sistema → Schermata di blocco → «Spegni lo schermo quando inattivo» → Mai"
  fi
  sudo -k 2>/dev/null
fi
echo ""

FILEVAULT=0
if fdesetup status 2>/dev/null | grep -qi "FileVault is On"; then FILEVAULT=1; fi

# --- 4. permessi e prova ---
echo "  PASSO 4 di 4 — Permessi e prova (solo la prima volta)"
echo "  ─────────────────────────────────────"
if [ "$APP_RIFATTA" = "1" ]; then
  echo "  L'app è stata (ri)creata, quindi macOS chiederà i permessi da capo."
fi
echo "  Ora apro «$NOME_APP». macOS può mostrare uno o due avvisi:"
echo ""
echo "   • «$NOME_APP vuole avere accesso per controllare System Events»"
echo "       → clicca OK   (NON «Non consentire»: senza questo non può fare i clic)"
echo ""
echo "   • «$NOME_APP vuole controllare il computer con le funzioni di Accessibilità»"
echo "       → clicca «Apri Impostazioni di Sistema»"
echo "       → nella finestra che si apre ATTIVA l'interruttore accanto a «$NOME_APP»"
echo "         (se non c'è, premi + e scegli l'app nella cartella Applicazioni)"
echo ""
echo "  Se sbagli un clic, niente paura: l'app ti dice quale permesso manca e apre la"
echo "  finestra giusta (Privacy e sicurezza → Automazione, oppure → Accessibilità)."
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
  tail -n 12 "$LOG" | sed 's/^/     /'
  { echo "macOS $(sw_vers -productVersion)"; tail -n 40 "$LOG"; } | pbcopy 2>/dev/null
  echo ""
  echo "  (le ho copiate negli appunti: se qualcosa non va, incollale con cmd + V nel messaggio a Claude)"
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
echo "  Se la TV si stacca (o sei stato sull'Apple TV) e vuoi tornare al Mac, alla cieca:"
echo "     1. premi Maiuscole e aspetta 5 secondi"
echo "     2. premi ctrl + cmd + Q, aspetta 3 secondi, scrivi la password, premi Invio"
echo "     3. aspetta mezzo minuto: la TV torna sul Mac"
echo ""
echo "  Se qualcosa non va: doppio clic su «MOSTRA DIARIO.command» e manda il diario a Claude."
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
