#!/bin/bash
# Doppio clic su questo file per aprire il Controllo Telecamere Insta360.
cd "$(dirname "$0")/insta360"
clear

echo ""
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║   CONTROLLO TELECAMERE INSTA360                  ║"
echo "  ║   GO 3S  ·  Ace Pro 2  ·  X6                     ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo ""

# --- controllo: serve Python 3 (di solito c'è già) ---
if ! command -v python3 >/dev/null 2>&1; then
  echo "  ✗ Manca Python 3. Su Mac si installa in un minuto:"
  echo "      apri il Terminale e scrivi   xcode-select --install"
  echo "    poi rilancia questo file."
  echo ""
  read -r -p "  Premi Invio per chiudere."
  exit 1
fi

# --- componente Bluetooth (facoltativo, serve per le telecamere vere) ---
if ! python3 -c "import bless, bleak" >/dev/null 2>&1; then
  echo "  Per comandare le telecamere VERE serve il componente Bluetooth"
  echo "  (per la modalità demo non serve)."
  echo ""
  read -r -p "  Lo installo adesso? Ci vuole un minuto. [S/n] " risposta
  case "$risposta" in
    [nN]*)
      echo "  Va bene: parto senza. Potrai installarlo a un prossimo avvio."
      ;;
    *)
      echo "  ⟳ Installo il componente Bluetooth…"
      if python3 -m pip install --user --quiet bless bleak 2>/dev/null \
         || python3 -m pip install --user --quiet --break-system-packages bless bleak 2>/dev/null; then
        echo "  ✓ Componente Bluetooth installato."
        echo "    (Alla prima accensione del telecomando, il Mac chiederà il"
        echo "     permesso di usare il Bluetooth: concedilo al Terminale.)"
      else
        echo "  ✗ Installazione non riuscita: parto lo stesso in modalità demo."
        echo "    Riprova al prossimo avvio, con il Mac collegato a internet."
      fi
      ;;
  esac
  echo ""
fi

echo "  ⟳ Avvio il programma… fra un attimo si apre il browser."
echo "    (Questa finestra deve restare aperta: è il motore del programma."
echo "     Per smettere: chiudi questa finestra, o premi Ctrl+C qui.)"
echo ""

python3 avvia.py

echo ""
read -r -p "  Programma chiuso. Premi Invio per chiudere la finestra."
