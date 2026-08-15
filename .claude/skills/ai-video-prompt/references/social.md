# Video per Instagram e social

Questo file è un'aggiunta al kit originale, che è pensato per la produzione video generica. Qui c'è quello che cambia quando il video finisce in un Reel.

## Formato

| Piattaforma | Rapporto | Risoluzione di riferimento |
|---|---|---|
| Instagram Reels, TikTok, YouTube Shorts | 9:16 | 1080 × 1920 |
| Post nel feed Instagram | 4:5 o 1:1 | 1080 × 1350 / 1080 × 1080 |
| YouTube, LinkedIn | 16:9 | 1920 × 1080 |

I limiti di durata delle piattaforme cambiano spesso: se la durata è vincolante per il progetto, falla verificare all'utente sulla piattaforma invece di dare un numero a memoria.

## Genera in orizzontale, ritaglia in verticale

Contro-intuitivo ma è la raccomandazione della documentazione dei modelli: **in verticale la probabilità che compaiano sottotitoli spuri è nettamente più alta** che in orizzontale.

Quindi, quando l'inquadratura lo permette:
1. genera in 16:9 componendo il soggetto al centro,
2. ritaglia a 9:16 in montaggio.

Quando *non* farlo: se la composizione verticale è il punto (una figura intera in piedi, un grattacielo, un tracking dall'alto in basso). In quel caso genera direttamente in 9:16 e rafforza il vincolo `nessun testo o sottotitolo`.

## Zone di sicurezza

Nel verticale l'interfaccia della piattaforma copre parte dell'immagine: in basso didascalia e pulsanti, a destra la colonna delle icone, in alto la barra di stato. Le proporzioni esatte variano per app e per dispositivo, ma la regola pratica regge ovunque:

**Tieni il soggetto e qualsiasi elemento leggibile nel terzo centrale.** Nel prompt questo si traduce in una richiesta di composizione:
```
composizione centrata, soggetto nel terzo centrale del fotogramma,
spazio libero nei margini superiore e inferiore
```

## L'aggancio nei primi secondi

Chi scorre decide subito. Il primo secondo deve contenere **movimento e un soggetto già leggibile** — non una dissolvenza dal nero, non un campo lungo che poi avvicina.

| ❌ Apertura debole | ✅ Apertura forte |
|---|---|
| dissolvenza dal nero, poi lento push-in | il soggetto è già in primo piano e si muove al fotogramma 1 |
| campo lunghissimo che stabilisce l'ambiente | dettaglio stretto che si apre rivelando il contesto |
| soggetto immobile che poi inizia a muoversi | gesto già in corso, colto a metà |

Nel prompt, prima inquadratura:
```
Inquadratura 1: si apre già sul gesto in corso, primo piano stretto, la macchina
    è già in movimento al primo fotogramma
```

## Loop

Un video che si ricongiunge da solo raddoppia il tempo di visione senza costare niente. Se il contenuto lo permette, chiedilo esplicitamente:
```
loop-ready motion with seamless start and end frames
```
Funziona con soggetti ciclici: onde, fumo, macchinari, mani che lavorano, camminate.

## Sottotitoli: generali no, aggiungili dopo

I social si guardano senza audio, quindi i sottotitoli servono — ma **non farli generare al modello**. Escono deformati, con lettere inventate, e non li puoi correggere. Genera pulito (`nessun testo o sottotitolo`) e metti le didascalie in montaggio, dove controlli font, tempi e correzioni.

Stessa logica per il logo del cliente: mai nel prompt, sempre in sovrimpressione dopo.

## Audio

Se il video finisce su Reels con una traccia della piattaforma, l'audio nativo del modello è sprecato: scegli un modello forte sul visivo e lascia perdere l'audio.
Se invece serve una voce che parla in camera, l'audio nativo diventa il criterio principale di scelta del modello (vedi `modelli.md`: Veo 3.1, Wan 2.7).

## Serie e coerenza di marca

Per una serie di post che devono sembrare la stessa cosa, blocca tre cose e tienile identiche su tutti i prompt:

1. **una gradazione colore** — es. `warm grading, slightly desaturated`
2. **una grammatica di macchina** — es. sempre `slow push-in`, sempre `handheld`
3. **una condizione di luce** — es. sempre `soft window light`

Salva questo blocco e riusalo verbatim. La riconoscibilità di una serie viene molto più dalla costanza di questi tre parametri che dal soggetto.

Se nella serie ricorre la stessa persona, leggi la sezione sull'ID drift in `debug.md` prima di partire: è il problema che rovina più spesso le serie.

## Esempi pronti nel dataset

Il catalogo allegato ha una categoria dedicata. Per vederli:

```bash
python3 scripts/cerca_prompt.py --categoria social-viral
```
