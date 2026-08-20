# Controllo Telecamere Insta360

Un programma per il tuo computer che raccoglie in un unico posto le tue tre
telecamere — **Insta360 GO 3S**, **Insta360 Ace Pro 2** e **Insta360 X6** —
con tutte le loro modalità, impostazioni e comandi, in italiano.

Non c'è niente da installare: usa il Python 3 già presente sul Mac e si apre
nel browser. Nessun dato esce dal computer (il programma ascolta solo su
`127.0.0.1`, cioè "questo computer e basta").

## Avvio in dieci secondi

1. Fai **doppio clic** su `CONTROLLA LE TELECAMERE.command` (nella cartella
   principale, accanto a `PUBBLICA IL SITO.command`).
2. Si apre il browser con la griglia delle tre telecamere.
3. Scegline una, premi **Collega**, e prova tutto: scatto, registrazione,
   modalità, risoluzioni, autoscatto, griglia in anteprima, gestione dei file.

Da terminale, in alternativa: `cd insta360 && python3 avvia.py`.

## Cosa fa la modalità demo

Le tre telecamere nel programma partono **simulate**: rispondono a ogni
comando come quelle vere (la batteria si scarica, la memoria si riempie, i
file compaiono dopo ogni scatto), così puoi imparare l'interfaccia e provare
ogni funzione senza telecamere accese. Ogni modello ha le sue modalità reali:

- **GO 3S** — Video 4K, FreeFrame, slow motion, timelapse, TimeShift,
  pre-registrazione, loop, foto a intervalli.
- **Ace Pro 2** — Video fino a 8K, PureVideo notturno, foto 50 MP, raffica,
  Starlapse, profili colore Leica.
- **X6** — Video 360 fino a 8K/50, obiettivo singolo, InstaFrame, foto 360,
  Bullet Time, timelapse e TimeShift 360, Active HDR / Dolby Vision.

## La verità sul controllo delle telecamere vere

Questa parte è importante, quindi te la dico senza giri di parole.

Insta360 **non pubblica** un modo ufficiale e aperto per comandare tutto dal
computer: il controllo completo (anteprima dal vivo compresa) ce l'ha solo la
loro app per telefono. Però le strade percorribili esistono, e questo
programma è costruito per usarle:

### 1. Il telecomando Bluetooth virtuale (già incluso, sperimentale)

Le tue tre telecamere supportano tutte il telecomando ufficiale "GPS Action
Remote". La community ne ha decodificato il linguaggio, e questo programma sa
parlarlo: il computer **si finge il telecomando**, la telecamera si abbina e
riceve i comandi veri:

- **Scatto** (foto, oppure avvia/ferma la registrazione)
- **Cambio modalità**
- **Schermo acceso/spento**
- **Spegnimento**

Come si prova:

1. Installa il componente (una volta sola): apri il Terminale e scrivi
   `python3 -m pip install bless`
2. Riavvia il programma e premi **«Accendi il telecomando»** nel pannello
   apposito. Il Mac chiederà il permesso di usare il Bluetooth: concedilo.
3. Sulla telecamera: **Impostazioni → Telecomando** e scegli
   «Insta360 GPS Remote».
4. Usa i quattro pulsanti dal programma.

È sperimentale: se la telecamera non trova il telecomando, il trucco che
spesso risolve è rinominare il Mac in «Insta360 GPS Remote» (Impostazioni di
Sistema → Generali → Info → Nome) perché macOS a volte annuncia il nome del
computer invece di quello scelto dal programma. Il telecomando è "cieco" come
quello vero: manda i comandi ma non vede lo schermo della telecamera.

### 2. L'SDK ufficiale per la X6 (controllo totale, su richiesta)

Per le telecamere 360 (quindi la X6, non la GO 3S né la Ace Pro 2) Insta360
offre gratis agli sviluppatori un **Camera SDK** per Windows/Linux/macOS con
controllo completo via USB o Wi-Fi: anteprima, ogni impostazione, scaricamento
dei file. Va richiesto compilando un modulo:

- Richiesta: https://www.insta360.com/sdk/apply
- Guida: https://onlinemanual.insta360.com/developer/en-us/resource/sdk
- Esempi: https://github.com/Insta360Develop/Desktop-CameraSDK-Cpp

Quando (se) vorrai, la richiesta si fa in cinque minuti; una volta ottenuto
l'SDK, questo programma ha già la struttura pronta per aggiungerlo come
"driver" accanto a quello demo e a quello Bluetooth.

### 3. Il Wi-Fi decodificato dalla community (per smanettoni)

Le Insta360 creano una loro rete Wi-Fi (password predefinita `88888888`, la
telecamera è `192.168.42.1`) e parlano un linguaggio proprietario sulla porta
6666. Il progetto open source
[insta360-wifi-api](https://github.com/RigacciOrg/insta360-wifi-api) l'ha
decodificato per i modelli meno recenti (scatto, registrazione, impostazioni
video, elenco dei file). Sui modelli nuovi non è garantito: lo cito come
strada futura, non l'ho incluso nel programma.

### In sintesi

| Cosa vuoi fare                    | Strada giusta oggi                        |
| --------------------------------- | ----------------------------------------- |
| Scattare/registrare a distanza    | Telecomando Bluetooth virtuale (tutte e tre) |
| Anteprima dal vivo e ogni impostazione | App ufficiale Insta360 sul telefono  |
| Controllo totale della X6 dal computer | SDK ufficiale (da richiedere)        |
| Scaricare i file sul Mac          | App Insta360 per desktop, o la scheda/cavo USB |

## Domande veloci

**Il programma vede le foto/video veri?** In demo no: i file elencati sono
simulati. Coi collegamenti reali (SDK) sì; nel frattempo il modo più comodo
per scaricare resta il cavo USB o l'app ufficiale.

**Posso aggiungere un'altra telecamera?** Sì: si aggiunge una voce in
`app/registry.py` con modalità e impostazioni, e compare da sola
nell'interfaccia.

**Su che porta gira?** `http://127.0.0.1:8360` (se occupata, prova le
successive: 8361, 8362…).

## Per chi mette le mani nel codice

```
insta360/
├── avvia.py                  ← punto di partenza (python3 avvia.py)
├── app/
│   ├── registry.py           ← catalogo delle telecamere e delle funzioni
│   ├── controller.py         ← smista i comandi
│   ├── server.py             ← server web locale (solo librerie standard)
│   ├── drivers/
│   │   ├── base.py           ← interfaccia comune dei driver
│   │   ├── demo.py           ← simulatore completo
│   │   └── telecomando_ble.py← telecomando Bluetooth virtuale (bless)
│   └── web/                  ← interfaccia (HTML, CSS, JS, in italiano)
├── tests/                    ← prove automatiche: python3 -m unittest
└── requirements-bluetooth.txt← unico componente facoltativo (bless)
```

Le prove automatiche si lanciano con:

```
cd insta360 && python3 -m unittest discover -s tests -v
```

## Fonti e ringraziamenti

- Protocollo del telecomando Bluetooth: progetto MIT
  [pchwalek/insta360_ble_esp32](https://github.com/pchwalek/insta360_ble_esp32)
  e l'esempio ESPHome di
  [btittelbach](https://github.com/btittelbach/esphome_config_examples).
- Protocollo Wi-Fi: [RigacciOrg/insta360-wifi-api](https://github.com/RigacciOrg/insta360-wifi-api).
- SDK e documentazione ufficiale: [insta360.com/sdk/apply](https://www.insta360.com/sdk/apply),
  [manuale sviluppatori](https://onlinemanual.insta360.com/developer/en-us/resource/sdk),
  [Insta360Develop su GitHub](https://github.com/Insta360Develop/Desktop-CameraSDK-Cpp).
- Compatibilità del telecomando GPS con GO 3S / Ace Pro 2 / serie X:
  [store Insta360](https://store.insta360.com/product/gps-action-remote).
