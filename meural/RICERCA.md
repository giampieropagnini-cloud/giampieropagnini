# Meural Canvas: ricerca per un'app nostra

Ricerca fatta l'11 settembre 2026. Obiettivo: capire se possiamo sostituire
l'app ufficiale Meural (Netgear) con un programma nostro, e cosa serve.

## Risposta breve

Sì, si può fare, e non partiamo da zero. La cornice ha un **server web locale
sulla porta 80** senza password che la comunità ha già mappato per intero.
Con quello si controlla tutto ciò che è già sulla cornice e si manda a schermo
qualsiasi immagine dalla rete di casa, senza passare dai server Netgear.

Il limite vero è uno: **caricare nuove playlist permanenti** oggi passa solo
dal cloud Netgear (o dalla scheda SD). Il cloud è ancora vivo ma Netgear ha
chiuso il prodotto e non lo sviluppa più, quindi va trattato come qualcosa che
può sparire.

## Stato di Meural / Netgear

- Netgear ha **dismesso il prodotto** in silenzio (restructuring charges nei
  bilanci, "mercato piccolo, non in linea col portfolio"). Dichiarazione:
  vendere le scorte e "mantenere il servizio per gli abbonati".
- L'app non riceve sviluppo. I forum Netgear del 2026 sono pieni di
  segnalazioni: Canvas II che non sincronizzano più ("last sync 22 luglio
  2025", server status offline), interfaccia web che va e viene.
- L'autenticazione cloud è passata su **AWS Cognito + accounts2.netgear.com**
  con WAF che blocca IP e login interattivi. Le integrazioni open source hanno
  dovuto riscrivere il login due volte (ultimi fix ad agosto 2026).
- Il supporto NFT (MetaMask, Coinbase Wallet, Phantom/Solana) è una funzione
  **del cloud Netgear**: importa gli NFT dal wallet come "item" nella libreria.
  Se il cloud muore, muore anche quello. Con un'app nostra lo rifacciamo in
  modo indipendente (vedi sotto).

## Cosa espone la cornice in locale (porta 80, nessuna autenticazione)

Tutto `GET http://<ip-cornice>/remote/...` salvo `postcard` che è `POST`.

| Endpoint | Cosa fa |
|---|---|
| `control_command/set_key/right/` `left/` `up/` `down/` | Come i gesti sulla cornice: avanti/indietro, menu su/giù |
| `control_command/suspend` / `resume` | Spegne / accende lo schermo |
| `control_command/set_backlight/{0-100}/` | Luminosità |
| `control_command/als_calibrate/off/` | Disattiva il sensore di luce ambientale |
| `control_command/set_orientation/portrait` / `landscape` | Orientamento |
| `control_command/change_gallery/{id}` | Cambia playlist (tra quelle già sulla cornice) |
| `control_command/change_item/{id}` | Salta a un'opera precisa |
| `get_backlight/` | Luminosità attuale |
| `control_check/sleep/` | Sta dormendo? |
| `control_check/system/` | Info di sistema (firmware, storage, wifi, sensore luce) |
| `identify/` | Identifica la cornice |
| `get_wifi_connections_json/` | Wifi |
| `get_galleries_json/` | Elenco playlist presenti sulla cornice |
| `get_gallery_status_json/` | Playlist e opera in riproduzione adesso |
| `get_frame_items_by_gallery_json/{id}` | Opere dentro una playlist |
| `postcard` | `POST multipart/form-data`, campo `photo` = file JPEG/PNG/GIF. Mostra subito l'immagine |

Note dai progetti che lo usano:

- `postcard` mostra l'immagine **temporaneamente**: dopo un certo tempo la
  cornice torna alla playlist. La durata si regola col parametro cloud
  `previewDuration`. Per uno slideshow locale i progetti esistenti rimandano
  semplicemente una nuova postcard a intervalli (funziona, è quello che fa il
  "watchdog" di EdgeIQ per tenere vive le cornici con il cloud giù).
- Le playlist sulla cornice possono arrivare anche da **scheda SD**: cartelle
  `meural1` … `meural4` nella radice della scheda vengono lette come playlist
  locali (senza titoli/metadati). Questa è la via 100% offline per contenuti
  permanenti.
- Il firmware più recente (2.3.x) sembra meno affidabile con la postcard su
  alcune Canvas II ("non sempre tiene sui dispositivi nuovi", bigboxer23).
  Da verificare sulla tua.

## API cloud Netgear (finché esiste)

Base `https://api.meural.com/v0/` (le integrazioni recenti usano anche `v1`),
header `Authorization: Token <token>`, `x-meural-api-version: 4`.

- `GET user/devices`, `user/galleries`, `user/items`
- `POST items` (multipart, campo `image`) per caricare un'immagine
- `POST galleries` (`name`, `orientation`) per creare una playlist
- `POST galleries/{g}/items/{i}` per aggiungere un'opera a una playlist
- `POST devices/{d}/galleries/{g}` per mandare la playlist alla cornice
- `POST devices/{d}/sync`, `PUT devices/{d}` per impostazioni (durata
  opera, fit, colore bordi, `previewDuration`)

Login: Cognito `eu-west-1`, client `487bd4kvb1fnop6mbgk8gu5ibf`, flusso
`CUSTOM_AUTH` con eventuale codice 2FA via email, poi scambio token su
`accounts2.netgear.com/api/oauth/...`. Il codice pronto è in
`GuySie/ha-meural` (`netgear_auth.py`). Scorciatoia pratica: copiare il token
dal browser su my.meural.netgear.com (Network tab), come fa il CLI di
anthonynelzinsantos.

## Progetti esistenti da cui attingere

| Progetto | Cosa fa | Locale/Cloud | Note |
|---|---|---|---|
| [GuySie/local-meural](https://github.com/GuySie/local-meural) | Integrazione Home Assistant solo locale | Locale | La mappa completa dell'API locale, Python, luglio 2026 |
| [GuySie/ha-meural](https://github.com/GuySie/ha-meural) | Integrazione HA completa | Entrambi | 68 stelle, login Cognito funzionante ad agosto 2026 |
| [davemorin/meural-manager](https://github.com/davemorin/meural-manager) | Web app self-hosted: libreria, upload drag&drop, EXIF, playlist, cancellazioni in blocco | Cloud | Node/Express, MIT, gennaio 2026 |
| [geeForceOne/MeuralManager](https://github.com/geeForceOne/MeuralManager) | Web app self-hosted (.NET/Blazor, Docker): playlist, crop 16:9, pulizia upload orfani, telecomando | Entrambi | MIT, settembre 2026 |
| [anthonynelzinsantos/MeuralManager](https://github.com/anthonynelzinsantos/MeuralManager) | CLI Python: export libreria, upload con resize, spostare tra playlist, push diretto | Cloud | CC0, login con token da browser |
| [bigboxer23/meural-control](https://github.com/bigboxer23/meural-control) | Manda contenuti da fonti esterne (Google Photos, JWST, immagini AI, URL) | Entrambi | Java/Spring, Apache 2.0, 460+ commit |
| [hughmadden/MeuralMCP](https://github.com/hughmadden/MeuralMCP) | Daemon + REST + server MCP per tenere immagini a schermo via LAN | Entrambi | Python, giugno 2026 |
| [EdgeIQ-Labs/meural-manager](https://github.com/EdgeIQ-Labs/meural-manager) | Watchdog: sveglia la cornice e rimanda postcard quando resta nera | Locale | Node, agosto 2026 |
| [dsackr/ha-digital-frames](https://github.com/dsackr/ha-digital-frames) | Galleria multi-cornice per HA, Meural via postcard | Locale | MIT |
| [tobyscales/meural-sync](https://github.com/tobyscales/meural-sync) | Google Photos → playlist Meural via GitHub Actions | Cloud | Python |
| [MikeFez/Immich-MeuralCanvas-Cropper](https://github.com/MikeFez/Immich-MeuralCanvas-Cropper) | Ritaglio immagini da Immich per Meural | Cloud | |
| [mikeknoop/homebridge-meural](https://github.com/mikeknoop/homebridge-meural) | HomeKit | Cloud | Fermo dal 2024 |
| [emadow/meural-newspapers](https://github.com/emadow/meural-newspapers) | Prime pagine dei giornali ogni mattina | Cloud | TypeScript |

Nessun progetto ha trovato un modo per **caricare playlist permanenti via
LAN** senza cloud o SD. Nessuno ha fatto root o firmware custom della cornice
(non ci sono teardown pubblici utili).

## Cosa possiamo costruire noi

### Fase 1: "Meural Locale" (zero dipendenza da Netgear)

Un piccolo server Python che gira su un Raspberry Pi, un Mac sempre acceso o un
NAS, con interfaccia web da telefono:

- telecomando: avanti/indietro, luminosità, accendi/spegni, orientamento,
  scelta playlist tra quelle già sulla cornice;
- slideshow locale: una cartella di immagini (o una libreria) che il server
  spinge via `postcard` a intervalli scelti da te, con ordine, casuale,
  fasce orarie, spegnimento notturno;
- watchdog: se la cornice resta nera o si addormenta, la sveglia;
- adattamento immagini automatico (1920×1080 o 1080×1920, fit/crop, bordi).

Sostituisce il 90% di quello che usi dell'app, senza account Netgear.

### Fase 2: NFT indipendenti dal cloud Netgear

Il server legge i tuoi wallet (Ethereum, Polygon, Solana…) tramite un'API
gratuita tipo Alchemy `getNFTsForOwner` o Moralis, scarica le immagini (con
cache locale, risolvendo IPFS), le prepara nel formato della cornice e le mette
nello slideshow. Opzionale: cartellino stile museo con nome, collezione, QR
code al contratto, come faceva Netgear ma senza il loro cloud.

### Fase 3 (finché il cloud vive): ponte verso le playlist permanenti

Uso dell'API cloud per caricare in blocco e creare playlist che poi restano
sulla cornice anche se il cloud sparisce. Riusiamo il login Cognito di
`ha-meural` o il token copiato dal browser. In alternativa, generazione
automatica della scheda SD (cartelle `meural1..4`) per contenuti permanenti
senza cloud.

### Tecnologia proposta

Python 3 + FastAPI + Pillow, un solo file di configurazione, Docker opzionale.
Interfaccia web leggera (HTML/JS) da usare dal telefono. Se in casa c'è Home
Assistant, `local-meural` copre già la parte telecomando e conviene integrare
piuttosto che duplicare.

## Prossimo passo concreto

Nello stesso folder c'è `meural_local.py`, uno script di prova senza
dipendenze. Da un computer sulla stessa rete wifi della cornice:

```
python3 meural/meural_local.py 192.168.1.50 status
python3 meural/meural_local.py 192.168.1.50 galleries
python3 meural/meural_local.py 192.168.1.50 next
python3 meural/meural_local.py 192.168.1.50 backlight 60
python3 meural/meural_local.py 192.168.1.50 show foto.jpg
```

L'indirizzo IP si trova nell'app Meural (impostazioni cornice) o nel router.
Il risultato di `status` e `show` ci dice modello, firmware e se la postcard
funziona sulla tua unità: da lì decidiamo l'architettura definitiva.

## Fonti

- https://github.com/GuySie/local-meural
- https://github.com/GuySie/ha-meural (README, `pymeural.py`, `netgear_auth.py`, issues #74 #77)
- https://github.com/bigboxer23/meural-control
- https://github.com/davemorin/meural-manager
- https://github.com/geeForceOne/MeuralManager
- https://github.com/anthonynelzinsantos/MeuralManager
- https://github.com/hughmadden/MeuralMCP
- https://github.com/EdgeIQ-Labs/meural-manager
- https://github.com/dsackr/ha-digital-frames
- https://www.channelnews.com.au/exclusivenetgear-kills-off-meural-canvas/
- https://community.netgear.com/discussions/en-home-networking-meural-canvas/meural-canvas-ii-server-status-offline/2473603
- https://community.netgear.com/discussions/en-home-networking-meural-canvas/looks-to-me-that-netgear-has-terminated-the-meural-devices%E2%80%A6-are-they-still-going/2470380
- https://www.netgear.com/hub/pressroom/nft-crypto-wallets-on-meural/
- https://www.businesswire.com/news/home/20220728005060/en/NETGEAR-to-Support-Solana-Blockchain-With-the-Integration-of-Phantom-Wallet-Into-the-Meural-Platform
- https://www.alchemy.com/docs/reference/nft-api-endpoints/nft-api-endpoints/nft-ownership-endpoints/get-nf-ts-for-owner-v-3
- https://docs.moralis.com/get-started/tutorials/data-api/nfts/get-all-nfts-owned-by-a-wallet-address
