# Prove coi Pocket Operator veri

Una cosa alla volta, nell'ordine. Ogni riga dice come va messo il PO e cosa guardare.
Adattatore di Hanz montato sul PO, Bobina sull'iPhone, sezione **Pocket Operator** («passa a…» in alto a destra).
Se una prova fallisce, prima di cambiare il codice si ricontrolla come è stata fatta (allineamento dei pin, canale, porta scelta).

## I tasti

| # | cosa | come | risultato |
|---|---|---|---|
| 1 | Bobina vede l'adattatore, e come si chiama | Collega → cerca l'adattatore; poi in alto «collegato a …» | ✅ 30/9/2026, via bluetooth: «PO MIDI Adapter (BLE) Bluetooth». Due adattatori si chiamano uguale |
| 2 | un tasto | PO fermo. Tasti → 1 | ✅ 30/9/2026 |
| 3 | tutti i 23 tasti rispondono | Tasti → uno per uno (sopra un tocco, sotto «tieni») | ✅ 30/9/2026: «funzionano tutti i tasti» |
| 4 | il tocco più corto | Suona → passi dal vivo, tasto 1 su un passo, premuto «tocco» (60 ms), ▶ | da fare |
| 5 | una combinazione | Tasti → in un tocco → pattern 2; il display dice il pattern | ✅ 30/9/2026: «tutte le combinazioni» |
| 6 | sul tonic un tasto suona il suo suono o quello scelto | PO-32, fermo: Tasti → 1, poi 5 | da fare |
| 7 | un effetto | PO che suona (play). Tasti → un effetto per un momento → 1 | da fare |
| 8 | l'eco | Collega → monitor: tornano indietro le frecce ← ? | da fare |

## A tempo

| # | cosa | come | risultato |
|---|---|---|---|
| 9 | Bobina lo suona | Ritmo → Bobina lo suona. Suona → passi dal vivo, qualche passo, ▶. Il PO va a tempo? | da fare |
| 10 | insieme al TX-6 | TX-6 in «Bobina dà il tempo», ▶ sul TX-6; poi ▶ sul PO: entra alla battuta dopo? Suona in ritardo? (Ritmo → anticipo) | da fare |
| 11 | cavo sync dal TX-6 | cavo aux → ingresso del PO, TX-6 aux su sync 8, PO su SY2. Ritmo → cavo sync dal TX-6, ▶: parte in battere col TX-6? | da fare |
| 12 | il TX-6 manda gli impulsi solo quando suona | come la 11, TX-6 fermo: il PO avanza o sta fermo? | da fare |
| 13 | pattern a tempo | come la 11; Suona → pattern a tempo, 1 · 2. Il cambio arriva sulla battuta o una battuta dopo? | da fare |
| 14 | effetti a tempo | come la 11; Suona → effetti a tempo, un effetto sui passi 13-16 | da fare |
| 15 | cancello | sul tonic: muto tenendo 1-4; sugli altri: col volume | da fare |
| 16 | senza cavo | Ritmo → senza cavo, 120 su Bobina e sul PO (bpm fino a 120), ▶: quanto si allontana in 5 minuti? | ✅ 1/10/2026, due PO con «▶ tutti i PO insieme»: partono nello stesso istante. Da misurare quanto si allontanano coi minuti |
| 17 | inclinazione | Suona → col corpo; inclinare a destra e a sinistra | da fare |

## Col configuratore web (Chrome sul Mac, cavo USB)

| # | cosa | come | risultato |
|---|---|---|---|
| 18 | le scorciatoie a CC | po_cc_control = 1; in Bobina Collega → scorciatoie a CC; Tasti → in un tocco → pattern 3 | da fare |
| 19 | sync out dell'adattatore | disable_transport = 0, cavo sync out → ingresso del PO, PO su SY2. Ritmo → sync out dell'adattatore, clock sempre acceso, ▶ | da fare |
| 20 | lo scivolamento | come la 19, a 128 bpm e a 120 bpm: dopo 2 minuti il PO è ancora a tempo? | da fare |

## Misure

(qui i numeri veri, man mano)

- 1/10/2026: in «Bobina lo suona» coi passi vuoti il PO restava fermo (giusto, ma non si capiva) e il play premuto da Bobina durava 40 ms. Ora 60 ms come i tasti che funzionano, e Ritmo avvisa. Con «senza cavo» i due PO partono insieme.
- 30/9/2026: con due adattatori via bluetooth Bobina ne comandava uno solo alla volta (una porta per tutta la sezione). Ora ogni PO ha il suo motore e la sua porta (PO 1, PO 2 in cima alle schede); Bobina li divide da sola fra le porte con lo stesso nome. Prova sul Mac: due PO partiti insieme, scarto 0,000 ms; fermato il PO 1, il PO 2 continua sulla griglia.

- 29/9/2026, sul Mac senza macchine (strumenti/prova-po), TX-6 e PO sulla stessa griglia, schermo bloccato 300 ms ogni 500: il PO entra sul passo 16 del TX-6 (inizio di battuta), i suoi passi cadono a 0,000 ms da quelli del TX-6, a 125,00 ms esatti. Lo stesso tasto ripremuto viene lasciato 20 ms prima. fx giù 20 ms prima del numero, e intanto i passi dal vivo tacciono. Col sync out: clock a 20,83 ms esatti, start nel pacchetto del primo impulso della battuta.
