# Diagnosi: il video è venuto male

Dodici guasti ricorrenti, dalla documentazione ufficiale Volcano Ark raccolta nel kit. Struttura: **sintomo → causa → rimedio**.

Chiedi sempre all'utente il prompt usato **e** la descrizione del difetto (o uno screenshot) prima di diagnosticare. Poi restituisci: causa, prompt corretto, e perché la correzione funziona.

## Indice per sintomo

| Quello che vedi | Vai a |
|---|---|
| il volto cambia a metà, non somiglia al riferimento | 1 |
| compaiono sottotitoli non richiesti | 2 |
| compare un logo o un watermark | 3 |
| lo stile scivola dall'anime al realistico | 4 |
| scatto nel punto di giunzione fra due segmenti | 5 |
| due personaggi identici nella stessa scena | 6 |
| dopo il prolungamento l'immagine è sfocata | 7 |
| l'effetto speciale non è quello che volevo | 8 |
| il numero di persone non torna | 9 |
| clic o rumore alla fine dell'audio | 10 |
| la voce pronuncia male | 11 |
| il timbro di voce non somiglia al riferimento | 12 |

---

## 1 · Il volto cambia (ID drift)

**Causa** — l'immagine di riferimento del volto non ha peso sufficiente: è mescolata a immagini di posa, abiti, dettagli, e il viso occupa una porzione troppo piccola del fotogramma.

**Rimedio**
1. Fornisci **una foto separata del solo volto** (primo piano, espressione neutra, niente spalle né sfondo) oltre alla figura intera.
2. Nel prompt separa i ruoli: `i tratti del viso del soggetto 1 seguono l'immagine 1 (primo piano), il look e l'abbigliamento seguono l'immagine 2 (figura intera)`.
3. Metti i materiali più importanti **all'inizio** del prompt.

⚠️ Usa primo piano + figura intera. **Niente viste multiple / model sheet a tre viste**: il modello le legge come persone diverse e peggiora il problema.

## 2 · Sottotitoli non richiesti

**Causa** — c'è del testo nelle immagini o nei video di riferimento.

**Rimedio** — non è eliminabile al 100%, si abbassa la probabilità:
1. Vincolo esplicito: `nessun testo o sottotitolo`.
2. Rimuovi il testo dai materiali di riferimento prima di usarli.
3. Se il progetto lo consente, **genera in orizzontale e ritaglia dopo**: in verticale la probabilità di sottotitoli spuri è nettamente più alta. (Rilevante per i Reel — vedi `social.md`.)

## 3 · Logo o watermark

**Rimedio** — vincolo esplicito: `niente watermark`, `niente logo`. Quasi sempre basta.

## 4 · Deriva di stile

**Causa** — vuoi un risultato 2D/3D ma il riferimento è fotografico e il prompt non insiste sullo stile.

**Rimedio** — vincolo di stile esplicito e ripetuto (`stile anime 2D per tutta la durata`); se serve precisione, **converti prima l'immagine di riferimento nello stile target**, poi genera il video.

## 5 · Scatto alla giunzione

**Rimedio** — in montaggio: taglia **6 fotogrammi** dalla coda del primo segmento e **1 fotogramma** dalla testa del secondo, per ogni giunzione. Meglio ancora: fai finire il segmento su uno stacco di scena, così il salto è invisibile.

## 6 · Gemelli / personaggio clonato

**Causa** — definizione ambigua dei soggetti, o riferimenti a viste multiple.

**Rimedio**
1. Lega ogni personaggio alla sua immagine, con formato costante: `Marco (immagine 1) passa la busta a Luca (immagine 2)`.
2. Vincolo globale in coda al prompt:
   ```
   vietato mostrare persone identiche per aspetto, abbigliamento e accessori
   nessun effetto gemello o sdoppiamento
   un solo esemplare per personaggio nella stessa inquadratura
   ```
3. Riferimenti a **persona singola**, mai viste multiple.
4. Non incollare la sceneggiatura intera come prompt: la ridondanza confonde il modello.

## 7 · Qualità che degrada dopo il prolungamento

**Causa** — rigenerare a partire da un video già generato accumula degrado, soprattutto sui volti (macchie di colore).

**Rimedio**
1. Converti il video sorgente in un "white model" prima di prolungarlo: `trasforma il video in modello 3D bianco, personaggi in bianco puro, senza colore, texture o ombre, fondo bianco, struttura stabile`.
2. Parti sempre da immagini di riferimento ad alta risoluzione.
3. Limita il numero di prolungamenti a catena.

## 8 · Effetto speciale sbagliato

**Causa** — descrivere un effetto a parole è ambiguo (es. "il numero 2999 entra con animazione a conto alla rovescia" produce numeri che saltano a caso).

**Rimedio** — definisci l'effetto con un **video di riferimento** invece che a parole: `l'ingresso del numero segue il video 1`.

## 9 · Numero di persone sbagliato

**Causa** — oltre 4 persone di riferimento la stabilità crolla.

**Rimedio** — genera in due passaggi: raggruppa le persone a **massimo 4 per immagine**, genera le immagini di gruppo, poi usa quelle come riferimento per il video.

## 10 · Clic alla fine dell'audio

**Rimedio** — rigenera, oppure applica una dissolvenza audio in coda con l'inviluppo del volume nel tuo editor: porta a zero il volume nell'ultimo mezzo secondo.

## 11 · Pronuncia sbagliata

**Rimedio** — sostituisci la parola problematica con un **omofono più comune** nel testo del prompt. Il modello legge la grafia; se la grafia è insolita, sbaglia. Attenuazione, non soluzione completa.

## 12 · Timbro di voce diverso dal riferimento

**Rimedio**
1. Descrivi il timbro a parole oltre a fornire l'audio: `voce maschile matura, calda e profonda, con una leggera grana`.
2. Tieni le battute stilisticamente vicine al tono dell'audio di riferimento.
