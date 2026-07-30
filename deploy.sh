#!/bin/bash
# Pubblica il sito su GitHub Pages. Richiede: gh autenticato (gh auth status).
set -e
cd "$(dirname "$0")"

REPO_NAME="${1:-giampieropagnini}"
USER=$(gh api user --jq '.login')
DOMAIN=$(cat docs/CNAME)

echo "▸ Utente GitHub: $USER"
echo "▸ Repository:    $USER/$REPO_NAME"
echo "▸ Dominio:       $DOMAIN"
echo

if gh repo view "$USER/$REPO_NAME" >/dev/null 2>&1; then
  echo "▸ Il repository esiste già, riuso quello."
else
  echo "▸ Creo il repository..."
  gh repo create "$REPO_NAME" --public \
    --description "Sito personale di Giampiero Pagnini — artista visivo, Pescara" \
    --homepage "https://$DOMAIN"
fi

git remote remove origin 2>/dev/null || true
git remote add origin "https://github.com/$USER/$REPO_NAME.git"
git branch -M main

echo "▸ Carico i file (85 MB, può volerci qualche minuto)..."
git push -u origin main --force

echo "▸ Attivo GitHub Pages sulla cartella /docs..."
gh api -X POST "repos/$USER/$REPO_NAME/pages" \
  -f "source[branch]=main" -f "source[path]=/docs" 2>/dev/null \
  || gh api -X PUT "repos/$USER/$REPO_NAME/pages" \
       -f "source[branch]=main" -f "source[path]=/docs"

echo
echo "✅ Fatto."
echo "   Indirizzo provvisorio: https://$USER.github.io/$REPO_NAME/"
echo "   Dominio finale:        https://$DOMAIN (dopo il cambio DNS)"
echo
echo "   Record DNS da inserire:"
echo "     A     @     185.199.108.153"
echo "     A     @     185.199.109.153"
echo "     A     @     185.199.110.153"
echo "     A     @     185.199.111.153"
echo "     CNAME www   $USER.github.io."
