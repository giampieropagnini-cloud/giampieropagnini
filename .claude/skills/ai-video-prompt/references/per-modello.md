# Regole specifiche per modello

La formula a 8 elementi (`formula.md`) vale ovunque. Qui le deviazioni che contano modello per modello.

## Seedance 2.0

Formula piena a 8 elementi, 50-200 parole. È il modello che regge meglio narrazione complessa e più soggetti. Per storie su più inquadrature vedi `storyboard.md`.
Approfondimento: `kit/methodology/15-seedance-masterclass.md` e `19-seedance-masterclass-round3.md`.

## Kling 3.0

Tre modalità, scegli in base alla richiesta:

| Situazione | Modalità |
|---|---|
| clip 5s, scena singola | formula base in 4 parti |
| narrazione + audio | formula avanzata a 5 livelli |
| parti da un'immagine | formula image-to-video |

**Regola ferrea dell'image-to-video**: descrivi **solo il movimento**, mai ciò che è già visibile nell'immagine.

- ❌ "Una donna con un vestito rosso davanti a una finestra…" (ridescrive)
- ✅ "Il vento si alza; i capelli le si sollevano intorno al viso, si gira lentamente verso la macchina."

Stessa regola su Hunyuan. Approfondimento: `kit/methodology/09-kling-公式.md`, `18-kling-masterclass.md`.

## HappyHorse 1.0

Prompt **compatti: 30-55 parole**, rispettati alla lettera. Soggetto per primo, poi tecnica di ripresa, poi il percorso di attivazione audio (`with X audible`, `speaking English at natural pace`). Superare la lunghezza peggiora il risultato.
Approfondimento: `kit/methodology/17-happyhorse-masterclass.md`.

## Sora 2 / Veo 3.1

Scrivi in **inglese**. Sora premia la qualità cinematografica e la fisica; Veo è la scelta quando servono più voci che dialogano con audio sincronizzato.
Approfondimento: `kit/methodology/11-sora-公式.md`, `12-veo-公式.md`.

## Runway Gen-4 / Aleph

Gen-4, testo → video:
```
[Subject — specific details] [Action — clear verbs] [Setting]
[Camera — framing + movement] [Motion — how it evolves over time]
[Style — film stock / mood / era] [Constraints]
```

Aleph, editing di un video esistente — l'unica capacità di questo tipo sul mercato. Verbi operativi:

| Verbo | Uso |
|---|---|
| `add` | "Add streetlights to make this look like night" |
| `remove` | "Remove all background pedestrians" |
| `change` | "Change the camera to a wider angle" |
| `replace` | "Replace the car with a vintage motorcycle" |
| `re-light` | "Re-light with colder blue tones" |
| `re-style` | "Re-style as hand-painted watercolor animation" |

Ogni prompt Aleph dice tre cose: **cosa cambiare**, **cosa preservare intatto**, **quanto spingere la trasformazione**.

## Pika 2.5

```
A [subject] [action] in [setting], [style/lighting], [camera], [quality], no morphing.
```

Effetti Pikaffects: Melt, Inflate, Deflate, Squish, Crumble, Tear, Explode, Crush, Eye-pop, Levitate, Poke, Dissolve, Peel, Cake-ify, Ta-da.
Pikaframes: definisci primo e ultimo fotogramma, il modello genera la transizione.

Cinque regole: un solo soggetto · cambia una variabile alla volta · un solo ancoraggio stilistico · aggiungi sempre `no morphing` · aggiungi sempre `1080p` o `high quality` (il default è basso).

## Hailuo 02

Si comporta da "Director's AI": vuole un copione, non un elenco di aggettivi. Prompt **sobri**, focalizzati su fisica e sequenza temporale.

- ❌ "A beautiful epic ocean scene with dramatic waves and many cool effects."
- ✅ "Massive ocean waves crash against rugged cliff rocks at high speed, water spray erupts upward and disperses in mist, foam pools form and drain in cycles."

Vocabolario fisico: `water spray`, `fluid dynamics`, `surface tension`, `flame flickers`, `smoke trails`, `fabric folds`, `silk ripples`, `angular momentum`, `accurate gravity`, `knee absorption`, `Maillard reaction`.

## Wan 2.7

Quattro blocchi espliciti:
```
Entity: [chi/cosa — aspetto dettagliato]
Scene:  [dove — ambiente + luce]
Motion: [cosa succede — azioni in sequenza]
Sound:  [cosa si sente — voce / effetti / musica]
```

Il blocco `Sound` è il motivo per cui si sceglie Wan: accetta i tre elementi insieme.
```
Sound: Voice: "Bentornati all'aggiornamento settimanale."
       Voce femminile professionale, brusio ambientale, senza musica.
```

Per un avatar parlante servono tre cose insieme: Entity dichiarato come talking-head (`facing the camera directly`), Motion con `lips synced to dialogue`, Sound con le battute effettive.

## Hunyuan Video 1.5

Open source. Due modalità di riscrittura del prompt: **Normal** (scene semplici) e **Master** (arricchisce composizione, luce e macchina — per output cinematografici).
Vale la regola image-to-video di Kling: solo il movimento.
Self-hosting, parametri consigliati: `Q5_K_M GGUF + 30 steps + dpmpp_2m_sde + sgm_uniform + cfg 6.0`, lato corto almeno 1024px.

## Convertire un prompt da un modello all'altro

`kit/data/cross-model-matrix.json` contiene 110 prompt equivalenti — gli stessi 10 scenari scritti per 11 modelli diversi. Quando devi portare un prompt da un modello a un altro, **guarda come lo stesso scenario è scritto nel modello di destinazione** invece di riscriverlo a intuito:

```bash
python3 scripts/cerca_prompt.py --matrice --scenario product
```
