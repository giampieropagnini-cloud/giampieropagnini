# WeedGadget — come riempire la griglia dell'archivio

La pagina `weedgadget.html` ha ora tre parti: il racconto, **le sezioni dei dieci
anni** (già scritte, si correggono in `content.json`) e **la griglia**, cioè il
muro di pezzi presi dall'archivio Instagram.

La griglia è vuota finché non le si danno le immagini. Il motivo è che la sessione
di lavoro in cloud ha Instagram bloccato dalla rete, quindi lo scarico va fatto dal
tuo computer. Sono cinque minuti.

---

## 1 · Scarica l'archivio da Instagram

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

## 2 · Riempi la griglia

Nella cartella del sito:

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

## 3 · Ricostruisci il sito e pubblica

```bash
python3 gen.py --theme oscura --out docs
git add -A && git commit -m "WeedGadget: la griglia dell'archivio" && git push
```

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
