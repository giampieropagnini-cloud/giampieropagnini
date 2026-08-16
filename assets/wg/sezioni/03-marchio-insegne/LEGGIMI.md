# 03 · Marchio e insegne

Il nome, il marchio e tutte le sue applicazioni, dalle insegne dello spazio alle stampe.

Qui dentro vanno le immagini di questa sezione: `.jpg` (oppure `.png`, `.webp`).
Vengono mostrate sulla pagina WeedGadget in ordine alfabetico, quindi conviene
numerarle: `01-....jpg`, `02-....jpg` e così via.

La prima immagine fa da copertina della sezione; le altre si aprono a tutto
schermo toccando la copertina.

Dopo averle messe qui:

```bash
python3 scrape/wg_ingest.py --sections     # le rimpicciolisce e ne fa il .webp
python3 gen.py --theme oscura --out docs   # ricostruisce il sito
```
