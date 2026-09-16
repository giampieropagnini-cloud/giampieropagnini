# Meural Locale

Un'app nostra per la cornice Meural Canvas, che parla direttamente con la
cornice sulla rete di casa. Niente account Netgear, niente cloud.

Cosa fa:

- telecomando dal telefono: avanti/indietro, accendi/spegni, luminosità,
  cambio playlist tra quelle già sulla cornice;
- slideshow da una cartella di immagini sul computer, con intervallo, ordine
  casuale, adattamento automatico (intera con bordi o riempi con ritaglio);
- "mostra subito una foto" dal telefono;
- spegnimento notturno a orari scelti;
- watchdog: se la cornice si addormenta da sola, la risveglia;
- NFT: uno script scarica le immagini del tuo wallet nella cartella dello
  slideshow (serve una chiave gratuita Alchemy).

Il perché e la ricerca completa sono in `RICERCA.md`.

## Serve

- un computer sempre acceso sulla stessa wifi della cornice (Mac, Raspberry
  Pi, NAS, va bene tutto) con Python 3;
- facoltativo ma consigliato: `pip3 install pillow` per l'adattamento delle
  immagini;
- l'indirizzo IP della cornice: nell'app Meural sotto le impostazioni della
  cornice, oppure nel router. Conviene fissarlo nel router (prenotazione DHCP)
  così non cambia.

## Avvio

Su Mac: doppio clic su `AVVIA-MEURAL.command`. Su qualsiasi sistema:

```
cd meural/app
cp config.example.json config.json
python3 server.py config.json
```

Poi dal telefono apri `http://<ip-del-computer>:8080`, inserisci l'IP della
cornice, salva, e la sezione "Cornice" deve dire "collegata".

Le immagini vanno nella cartella `meural/app/immagini` (si crea da sola) o si
caricano dal telefono col pulsante "Aggiungi immagini".

## Prova senza la cornice

In un terminale: `python3 app/mock_frame.py` (cornice finta su porta 8081).
In `config.json` metti `"frame_ip": "127.0.0.1:8081"`. Tutto funziona uguale,
la cornice finta stampa a video quello che riceve.

## NFT

Nell'interfaccia web c'è la sezione "NFT dal wallet": inserisci l'indirizzo
del wallet, la rete e una chiave gratuita di Alchemy (alchemy.com, piano
free), poi "Scarica NFT". Le immagini finiscono in `immagini/nft` ed entrano
subito nello slideshow. Reti: Ethereum, Polygon, Base, Arbitrum, Optimism.

Da terminale, la stessa cosa:

```
ALCHEMY_KEY=la_tua_chiave python3 app/nft.py 0xIL_TUO_WALLET --chain eth-mainnet --out app/immagini/nft
```

## Scheda SD: playlist permanenti senza cloud

La cornice legge fino a 4 cartelle `meural1`…`meural4` nella radice di una
scheda SD e le mostra come playlist. Per prepararne una dalle tue immagini,
già adattate alla risoluzione della cornice:

```
python3 app/scheda_sd.py app/immagini/nft /Volumes/NOME_SCHEDA --slot 1
```

Poi espelli la scheda e inseriscila nella cornice.

## Limiti noti

- La postcard è un'anteprima: la cornice dopo un po' torna alla sua
  playlist. Lo slideshow rimanda un'immagine nuova prima che succeda, quindi
  nella pratica non si nota. Se noti che torna indietro, abbassa l'intervallo.
- Le playlist permanenti sulla cornice si caricano ancora solo con l'app
  Meural (cloud) o con la scheda SD (cartelle `meural1`…`meural4`).
- Sui firmware 2.3.x qualcuno segnala la postcard meno affidabile: da provare
  sulla tua unità con `python3 meural_local.py <ip> show foto.jpg`.

## Strumento da terminale

`meural_local.py` fa le stesse cose senza interfaccia:

```
python3 meural/meural_local.py 192.168.1.50 status
python3 meural/meural_local.py 192.168.1.50 next
python3 meural/meural_local.py 192.168.1.50 show foto.jpg
```
