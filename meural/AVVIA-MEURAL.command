#!/bin/bash
# Doppio clic su Mac: avvia Meural Locale e apre l'interfaccia nel browser.
cd "$(dirname "$0")/app" || exit 1
if [ ! -f config.json ]; then
  cp config.example.json config.json
  echo "Creato config.json: inserisci l'IP della cornice dall'interfaccia web."
fi
IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo 127.0.0.1)
PORT=$(python3 -c 'import json;print(json.load(open("config.json")).get("port",8080))')
echo "Dal telefono apri:  http://$IP:$PORT"
( sleep 1; open "http://127.0.0.1:$PORT" ) &
python3 server.py config.json
