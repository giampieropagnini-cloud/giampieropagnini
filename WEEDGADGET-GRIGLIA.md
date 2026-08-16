# WeedGadget — come riempire la griglia dell'archivio

La pagina `weedgadget.html` ha ora tre parti: il racconto, **le sezioni dei dieci
anni** (già scritte, si correggono in `content.json`) e **la griglia**, cioè il
muro di pezzi presi dall'archivio Instagram.

La griglia è vuota finché non le si danno le immagini. Il motivo è che la sessione
di lavoro in cloud non ha internet aperto — non solo Instagram: qualsiasi indirizzo
fuori da GitHub è chiuso dalla rete dell'ambiente. Quindi lo scarico va fatto dal
tuo computer. Sono cinque minuti, e ci sono due strade.

---

## Strada A · Scaricare direttamente da Instagram, da loggato

Questa non passa da nessun servizio esterno: parla con Instagram usando i cookie del
browser dove sei già entrato con **@weedgadget**.

1. Apri `instagram.com` nel browser, con l'account WeedGadget.
2. Copia il cookie **sessionid**:
   - Chrome: `F12` ▸ **Application** ▸ Cookies ▸ `https://www.instagram.com` ▸ `sessionid`
   - Safari: **Sviluppo** ▸ Mostra Inspector Web ▸ **Archiviazione** ▸ Cookie
3. Poi, nella cartella del sito:

```bash
export IG_SESSIONID='il-valore-copiato'
python3 scrape/ig_scrape.py --user weedgadget --top 98
python3 scrape/wg_ingest.py --from-json scrape/ig_weedgadget-grid.json
python3 gen.py --theme oscura --out docs
```

Scarica i 98 post più recenti con le loro didascalie, le immagini finiscono in
`assets/wg/ig/`, i dati grezzi restano in `scrape/ig_weedgadget.json` — così, se
serve rifare la griglia, non c'è bisogno di riscaricare niente.

Due avvertenze oneste: il cookie è la tua sessione, quindi non va messo dentro il
repository (l'`export` sta solo nel terminale, e scade da solo); e Instagram cambia
i suoi indirizzi interni ogni tanto, quindi se un giorno lo script si ferma con un
errore, la Strada B funziona sempre.

---

## Strada B · L'esportazione dei dati Instagram

Dall'app o dal sito, con l'account **@weedgadget**:

**Impostazioni ▸ Centro gestione account ▸ Le tue informazioni e autorizzazioni ▸
Scarica le tue informazioni**

Scegli:

- solo **@weedgadget** (non tutti gli account)
- **Formato: JSON** — non HTML, è importante
- **Qualità dei contenuti multimediali: alta**
- periodo: **tutto**

Instagram manda una mail con lo zip, di solito entro qualche ora. Scaricalo e
scompattalo, per esempio sulla Scrivania.

---

## In tutti i casi · Riempi la griglia

Qualunque sia la fonte, il pezzo finale è sempre `wg_ingest.py`. Con l'esportazione:

```bash
python3 scrape/wg_ingest.py --from-export ~/Desktop/instagram-weedgadget
```

Prende i **98 pezzi più recenti** — l'ordine in cui stanno sul profilo — li
ridimensiona e scrive:

- `assets/wg/grid/wg-001.jpg` (+ `.webp`) — la mattonella, lato 640
- `assets/wg/grid/large/wg-001.jpg` — quella che si apre col clic, lato 1600

e aggiorna `content.json`. Le didascalie arrivano dai post, ripulite da hashtag e
menzioni.

Se vuoi vedere cosa farebbe senza che scriva niente:

```bash
python3 scrape/wg_ingest.py --from-export ~/Desktop/instagram-weedgadget --dry-run
```

**Altre due strade**, se l'esportazione non serve:

```bash
# una cartella di foto già tue, in ordine alfabetico
python3 scrape/wg_ingest.py --from-dir ~/Desktop/vetro --sort name

# quanti pezzi vuoi, invece di 98
python3 scrape/wg_ingest.py --from-dir ~/Desktop/vetro --top 60
```

Serve **Pillow** per il ridimensionamento (`pip3 install Pillow`). Senza Pillow lo
script si arrangia con `sips`, che sul Mac c'è già, ma non fa i `.webp`.

---

## E poi · Ricostruisci il sito e pubblica

```bash
python3 gen.py --theme oscura --out docs
git add -A && git commit -m "WeedGadget: la griglia dell'archivio" && git push
```

---

## La cartella del progetto

Oltre alla griglia, il progetto ha la sua cartella con una sottocartella per
ognuna delle dodici sezioni:

    assets/wg/sezioni/01-vetro-americano/
    assets/wg/sezioni/02-spazio-barcellona/
    assets/wg/sezioni/03-marchio-insegne/
    …

Ci si mettono dentro le immagini di quella sezione — insegne, schermate del
negozio, capi, espositori, stand — numerate `01-`, `02-`, … perché l'ordine è
quello alfabetico. In ogni cartella c'è un `LEGGIMI.md` che dice cosa ci va.

Poi:

```bash
python3 scrape/wg_ingest.py --sections     # rimpicciolisce e fa i .webp
python3 gen.py --theme oscura --out docs
```

Ogni sezione che ha immagini si prende una fascia sua nella pagina: il testo da un
lato, il mosaico dall'altro — la prima immagine grande, le altre piccole intorno —
e le fasce si alternano da destra a sinistra. Se ne vedono nove, le altre si
aprono a tutto schermo toccandone una. Nell'indice in cima, la scheda della
sezione dice quante immagini ha e ci porta.

Le sezioni senza immagini restano schede di solo testo, come sono adesso.

---

## Le didascalie e i testi

Tutto quello che si legge nella pagina sta in `content.json`, dentro
`"weedgadget"`. Si può correggere a mano e ricostruire:

- `sections` — le dodici sezioni dei dieci anni, con testo italiano e inglese.
  Sono una prima stesura scritta a partire dal tuo racconto: rileggile e cambiale
  dove serve, soprattutto dove servono nomi, date e luoghi precisi.
- `grid_note_it` / `grid_note_en` — la riga sotto il titolo della griglia.
- `grid` — l'elenco dei pezzi. Ogni voce ha `cap_it` e `cap_en`: se le riempi,
  la didascalia compare quando si apre l'immagine grande.
- `grid_max` — quanti pezzi mostrare al massimo (98).
