---
name: ai-video-prompt
description: Scrive prompt professionali per i modelli di generazione video AI (Seedance, Kling, Sora, Veo, HappyHorse, Runway, Pika, Hailuo, Wan, Hunyuan, Gemini Omni) e per contenuti video social. Usare quando l'utente chiede di creare un video, un Reel, un video per Instagram/TikTok/YouTube Shorts, una pubblicità o video prodotto, uno spot, un video con AI, uno storyboard o una sceneggiatura a inquadrature; quando chiede quale modello video usare o come scrivere/correggere un prompt video; quando un video generato è venuto male (volto che cambia, sottotitoli indesiderati, doppioni del personaggio, stile che deriva). Copre scelta del modello, formula del prompt, storyboard multi-inquadratura, vincoli negativi, formati verticali social e diagnosi degli errori.
---

# ai-video-prompt

Trasforma una richiesta in linguaggio naturale ("voglio un Reel per il mio studio") in un prompt che il modello video capisce davvero.

**Cosa fa questa skill:** scrive e corregge i *prompt*. Non genera il video da sola.
**Chi genera:** il modello che scegli — via il suo sito, la sua API, oppure il connettore Higgsfield se è attivo in questa conversazione (vedi § Generare davvero).

## Routing — parti da qui

| La richiesta è… | Vai a |
|---|---|
| "quale modello uso?", "Sora o Kling?", "ce n'è uno gratis?" | `references/modelli.md` |
| "scrivimi un prompt per…", singola inquadratura | `references/formula.md` |
| storia, più scene, "prima… poi…", spot narrativo | `references/storyboard.md` |
| Reel / TikTok / Short / post Instagram / formato verticale | `references/social.md` |
| "è venuto male", "il volto cambia", "escono i sottotitoli" | `references/debug.md` |
| regole specifiche di un modello (Kling, Wan, Pika, Runway…) | `references/per-modello.md` |
| "fammi un esempio simile a…", cerchi ispirazione | `scripts/cerca_prompt.py` (433 prompt reali) |

Non caricare tutti i reference insieme. Apri solo quello che serve.

## Le 3 domande da fare prima di scrivere

Se l'utente non le ha già chiarite, chiedile — ma **massimo tre**, e poi scrivi il prompt. Non intervistare l'utente.

1. **Durata e formato** — 5s / 10s / 15s+? Verticale 9:16 o orizzontale 16:9?
2. **Audio** — serve audio nativo (dialogo, ambiente) o ci metti tu musica in montaggio?
3. **Punto di partenza** — testo puro, oppure hai già una foto/video di riferimento?

Se l'utente dà già una richiesta ricca, salta le domande e scrivi.

## La formula, in breve

Ogni prompt video ben scritto è un'**istruzione tecnica**, non una descrizione poetica. Otto elementi:

```
soggetto preciso + dettaglio dell'azione + ambiente + luce e colore
+ movimento di macchina + stile visivo + qualità + vincoli negativi
```

Tre regole che valgono su tutti i modelli:

- **Un solo movimento di macchina per inquadratura.** Chiedere insieme dolly, pan e zoom destabilizza l'immagine.
- **Emozione mostrata, non nominata.** Non "molto triste": "le spalle si abbassano, lo sguardo scivola a terra".
- **I vincoli negativi non sono opzionali.** Almeno: niente watermark, niente logo, niente sottotitoli.

Dettaglio completo, dizionario dei movimenti di macchina, luci, stili e gradazioni colore in `references/formula.md`; lista vincoli e combinazioni che si annullano a vicenda in `references/vincoli.md`.

## Formato dell'output

Consegna sempre così — l'utente deve poter copiare e incollare senza pulire:

```markdown
## Prompt — [modello scelto]

<il prompt, in un blocco di codice, pronto da incollare>

## Perché così
- [scelta 1 e motivo, una riga]
- [scelta 2 e motivo, una riga]

## Da regolare se non funziona
- [leva 1] → [cosa cambia]
```

Se il modello di destinazione lavora meglio in inglese (Sora, Veo, Runway, Pika, Hailuo), **scrivi il prompt in inglese** e la spiegazione in italiano. Dillo esplicitamente all'utente.

## Generare davvero

Questa skill produce il testo. Per ottenere il file video:

- **Se il connettore Higgsfield è attivo** nella conversazione, puoi passare direttamente il prompt ai suoi strumenti di generazione video e restituire il risultato. È il percorso più corto: prompt → video, senza uscire dalla chat.
- **Altrimenti** consegna il prompt e indica dove incollarlo (il sito del modello scelto — vedi la colonna "dove" in `references/modelli.md`).

Non promettere un video se non hai uno strumento di generazione disponibile: consegna il prompt e dillo.

## Materiale di approfondimento

`kit/` contiene la documentazione originale del progetto **lanshu-awesome-ai-video-kit** (in cinese, licenza MIT — vedi `kit/LICENSE-lanshu`): 21 documenti di metodologia, incluse le masterclass estese su Seedance, Kling e HappyHorse, la coerenza dei personaggi e i percorsi FPV/drone. Consultala quando i reference in italiano non bastano — per esempio su una funzione specifica di un singolo modello.

- `kit/methodology/` — metodologia completa
- `kit/data/all-prompts.json` — 433 prompt catalogati (usa lo script, non aprire il file: è grande)
- `kit/data/cross-model-matrix.json` — 110 prompt equivalenti su 10 scenari × 11 modelli, per convertire un prompt da un modello all'altro
