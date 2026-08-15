# Storyboard: raccontare una storia su più inquadrature

Il modello tiene separati **spazio** (cosa c'è nell'immagine) e **tempo** (come cambia). Per un video narrativo la forma migliore del prompt non è un paragrafo descrittivo: è una **timeline di inquadrature**.

## Regola base

Etichetta le inquadrature — `Inquadratura 1`, `Inquadratura 2`, `Inquadratura 3` — **nell'ordine in cui gli eventi accadono**, dal principale al secondario.

**Non imporre durate al secondo.** I modelli gestiscono male "da 0 a 3 secondi"; forzarlo produce risultati anomali. Lascia che il ritmo emerga dalla scrittura.

## Negativo vs positivo

❌ "Un uomo corre per strada tutto nervoso, molto cinematografico."
Il modello non sa dove inizia l'azione, dove finisce, quando stacca.

✅
```
Inquadratura 1: ripresa laterale del vicolo, l'uomo parte lentamente, respiro affannoso.
Inquadratura 2: rovescia un banco di frutta, la macchina fa un pan rapido e chiude
                sul suo primo piano atterrito.
Inquadratura 3: scavalca un muretto e sparisce, la macchina arretra lentamente
                e si ferma sulla strada vuota.
```

## Le 4 dimensioni di ogni inquadratura

Ogni inquadratura dice queste quattro cose, in quest'ordine:

1. **Macchina** — movimento o tipo di stacco ("campo lungo che avanza lentamente", "macchina fissa", "stacco su…")
2. **Azione ed espressione** — cosa fa il soggetto e come cambia in volto
3. **Posizione nello spazio** — dove si trova, in che rapporto con l'ambiente
4. **Audio** — effetti, voce, musica di quel momento

## Simboli per i tipi di informazione

Aiutano il modello a distinguere i registri. Convenzione del kit:

| Tipo | Simbolo | Esempio |
|---|---|---|
| musica | `( )` | `(sottofondo di piano jazz rilassato)` |
| effetto sonoro | `< >` | `<il vetro tintinna sul tavolo>` |
| battuta | `{ }` | `{Quanto tempo}` |
| sottotitolo voluto | `【 】` | `【Capitolo 2: il ritorno】` |

Per le battute in un'altra lingua, dichiara la lingua invece di mischiare: `dice in inglese {Hello world}`, non `He said "Hello world"`.

## Esempio completo

```
L'immagine 1 è la protagonista, l'immagine 2 l'ambiente di riferimento,
i movimenti di macchina seguono il video 1.

Inquadratura 1: sera, mezza figura laterale della ragazza (immagine 1), la macchina
    avanza lentamente. È in piedi sul bordo della terrazza, il vento le muove il
    cappotto. La macchina la orbita per mezzo giro, dal viso alla schiena.
    (musica di archi molto tenue) <traffico attutito in lontananza>

Inquadratura 2: dissolvenza in campo lunghissimo, vista dall'alto sull'isolato,
    le luci della città si accendono a ondate.

Inquadratura 3: stacco su primo piano a terra, si volta verso la macchina,
    l'espressione passa da distratta a decisa, dice {Ci sto}. La macchina resta
    ferma e chiude sul dettaglio degli occhi.

Resa cinematografica, tonalità fredda desaturata, grana da pellicola.
Volto e proporzioni stabili, movimenti continui, nessuno sfarfallio.
Niente watermark, logo o sottotitoli.
```

## Video lungo: prolungare o montare?

| Situazione | Metodo |
|---|---|
| scena unica, dialogo, emozione che sale, un solo percorso | **prolungamento** — piano sequenza immersivo |
| svolta narrativa, inseguimento, montaggio rapido | **segmenti separati poi montati** — ritmo e impatto |

Nella pratica si combinano: prolungamento per la parte parlata, segmenti staccati per gli stacchi.

⚠️ Ai punti di giunzione può comparire uno scatto. Rimedio in montaggio: togli **6 fotogrammi** dalla fine del primo segmento e **1 fotogramma** dall'inizio del secondo. Meglio ancora: fai finire ogni segmento su uno stacco, così il salto è mascherato dal taglio.

## Materiali di riferimento: quanti e quali

Quattro ruoli funzionali:

| Ruolo | Serve a |
|---|---|
| ancoraggio personaggio | fissare l'aspetto |
| definizione scena | fissare ambiente e stile |
| riferimento macchina | fissare linguaggio e ritmo delle riprese |
| riferimento audio | fissare emozione e timbro |

Configurazione consigliata, **4-5 materiali in tutto**: 1-2 immagini del personaggio (un primo piano del volto + una figura intera) + 1 immagine di scena + 1 video di riferimento + 1 traccia audio.

⚠️ Non riempire il limite di materiali. Troppi riferimenti e il modello non capisce quale caratteristica ha priorità: conflitti di stile, soggetti confusi, risultato alla deriva.
