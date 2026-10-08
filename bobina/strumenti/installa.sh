#!/bin/zsh
# Installa Bobina sull'iPhone di Giampiero senza cancellare il lavoro delle altre chat.
#
# Ogni sezione di Bobina (TP-7, TX-6, PO, OP-Z, M8, NTS-1, …) vive su un suo branch claude/…; installare da un
# branch solo toglie dal telefono le sezioni degli altri (è successo il 6/10/2026 con l'NTS-1).
# Questo script, dal tuo worktree:
#   1. unisce nel branch attuale tutti i branch locali claude/* con lavoro su bobina/ che qui manca (anche quelli nuovi);
#   2. compila in Release, con le righe di controllo accese (in Debug SwiftUI è troppo lento e Giampiero sente scatti);
#   3. installa sull'iPhone 18 Pro di Giampiero.
#
#   zsh bobina/strumenti/installa.sh
#
# Se un'unione ha conflitti si ferma: risolvili, fai il commit e rilancialo. Se la compilazione fallisce si ferma
# e non installa niente.
# Se pubblichi su main dal tuo branch (come il TP-7), non lanciarlo lì: unirebbe le altre sezioni nel tuo branch.
# Usa un worktree a parte, per esempio `git worktree add --detach ../bobina-build-tmp claude/tx6-midi`.
set -e
# senza pipefail un «xcodebuild … | grep» fallito non ferma lo script, e si installerebbe la Bobina vecchia
setopt pipefail
cd "$(dirname "$0")/../.."

IPHONE=00008160-000679C22E400036
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
# una cartella di build per worktree: due chat che installano insieme non si bloccano sul database di Xcode
# («database is locked», segnalato dalla chat del TP-7 l'8/10/2026)
DD="${BOBINA_DD:-$HOME/Library/Developer/Xcode/DerivedData/bobina-installa-$(basename "$PWD")}"

if [[ -n "$(git status --porcelain -- bobina)" ]]; then
  echo "Ci sono modifiche non salvate in bobina/: fai prima il commit." >&2
  exit 1
fi

# solo i branch che hanno lavoro su bobina/ che qui manca: un branch del sito o di altro non si tocca
for b in $(git branch --list 'claude/*' --format='%(refname:short)'); do
  if [[ -n "$(git log --oneline HEAD.."$b" -- bobina | head -1)" ]]; then
    echo "unisco $b"
    git merge --no-edit -m "Unisce $b prima di installare

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" "$b"
  fi
done

cd bobina
xcodebuild -project Bobina.xcodeproj -scheme Bobina -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath "$DD" \
  -allowProvisioningUpdates DEVELOPMENT_TEAM=C7K82R4TFA CODE_SIGN_STYLE=Automatic \
  'SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG' build | grep -E 'error:|BUILD (SUCCEEDED|FAILED)'

xcrun devicectl device install app --device "$IPHONE" "$DD/Build/Products/Release-iphoneos/Bobina.app" | grep -i -E 'installed|error'
echo "installato: $(git -C .. log --oneline -1)"
