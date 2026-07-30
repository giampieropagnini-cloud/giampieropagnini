#!/bin/bash
# Doppio clic su questo file per mettere online il sito.
cd "$(dirname "$0")"
clear

echo ""
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║   PUBBLICAZIONE DI giampieropagnini.com          ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo ""

# --- controlli ---
if ! command -v gh >/dev/null 2>&1; then
  echo "  ✗ Manca lo strumento 'gh'. Installalo con:"
  echo "      brew install gh"
  echo ""
  read -r -p "  Premi Invio per chiudere."
  exit 1
fi

if [ ! -f docs/index.html ]; then
  echo "  ✗ Non trovo il sito nella cartella docs/."
  read -r -p "  Premi Invio per chiudere."
  exit 1
fi

DOMAIN=$(cat docs/CNAME 2>/dev/null || echo "giampieropagnini.com")

# --- 1. accesso a GitHub ---
if gh auth status >/dev/null 2>&1; then
  echo "  ✓ Sei già collegato a GitHub."
else
  echo "  PASSO 1 di 3 — Collegamento a GitHub"
  echo "  ─────────────────────────────────────"
  echo "  Fra un istante vedrai un codice tipo ABCD-1234."
  echo "  Copialo, poi si aprirà il browser: incollalo e clicca Authorize."
  echo ""
  read -r -p "  Premi Invio quando sei pronto... "
  echo ""
  gh auth login --hostname github.com --git-protocol https --web --scopes "repo,workflow" || {
    echo ""
    echo "  ✗ Accesso non riuscito. Riprova lanciando di nuovo questo file."
    read -r -p "  Premi Invio per chiudere."
    exit 1
  }
fi

USER=$(gh api user --jq '.login')
REPO="giampieropagnini"
echo ""
echo "  ✓ Collegato come: $USER"
echo ""

# --- 2. creazione repository e caricamento ---
echo "  PASSO 2 di 3 — Carico il sito su GitHub"
echo "  ─────────────────────────────────────"

if ! gh repo view "$USER/$REPO" >/dev/null 2>&1; then
  gh repo create "$REPO" --public \
    --description "Sito personale di Giampiero Pagnini — artista visivo, Pescara" \
    --homepage "https://$DOMAIN" >/dev/null
  echo "  ✓ Repository creato."
else
  echo "  ✓ Repository già esistente, aggiorno quello."
fi

git remote remove origin 2>/dev/null || true
git remote add origin "https://github.com/$USER/$REPO.git"
git branch -M main

echo "  ⟳ Carico 33 MB, può volerci qualche minuto..."
if git push -u origin main --force; then
  echo "  ✓ Sito caricato."
else
  echo "  ✗ Caricamento non riuscito. Controlla la connessione e riprova."
  read -r -p "  Premi Invio per chiudere."
  exit 1
fi

# --- 3. attivazione del sito pubblico ---
echo ""
echo "  PASSO 3 di 3 — Attivo la pubblicazione"
echo "  ─────────────────────────────────────"
gh api -X POST "repos/$USER/$REPO/pages" -f "source[branch]=main" -f "source[path]=/docs" >/dev/null 2>&1 \
  || gh api -X PUT "repos/$USER/$REPO/pages" -f "source[branch]=main" -f "source[path]=/docs" >/dev/null 2>&1
echo "  ✓ Pubblicazione attivata."

echo ""
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║   FATTO! Il sito è online.                       ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo ""
echo "  Indirizzo provvisorio (attivo fra 1-2 minuti):"
echo "     https://$USER.github.io/$REPO/"
echo ""
echo "  ─────────────────────────────────────────────────"
echo "  ULTIMO PASSO: collegare il tuo dominio"
echo "  ─────────────────────────────────────────────────"
echo "  Nel pannello dove gestisci giampieropagnini.com"
echo "  (Aruba, oppure Wix, oppure Cloudflare), inserisci"
echo "  questi record DNS:"
echo ""
echo "     Tipo    Nome    Valore"
echo "     A       @       185.199.108.153"
echo "     A       @       185.199.109.153"
echo "     A       @       185.199.110.153"
echo "     A       @       185.199.111.153"
echo "     CNAME   www     $USER.github.io."
echo ""
echo "  Poi dimmi che hai fatto e verifico io che sia tutto a posto."
echo ""
open "https://$USER.github.io/$REPO/" 2>/dev/null || true
read -r -p "  Premi Invio per chiudere questa finestra."
