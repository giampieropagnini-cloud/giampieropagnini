# Crediti e provenienza

## Materiale originale

La cartella `methodology/` e i due file in `data/` provengono da:

**lanshu-awesome-ai-video-kit**
https://github.com/cclank/lanshu-awesome-ai-video-kit
Copyright (c) 2026 lanshu — licenza MIT (testo completo in `LICENSE-lanshu`)

Contenuto ripreso senza modifiche:
- 21 documenti di metodologia (`methodology/`), in cinese
- `data/all-prompts.json` — 433 prompt catalogati su 15+ modelli
- `data/cross-model-matrix.json` — 110 prompt su 10 scenari × 11 modelli

## Cosa è stato aggiunto

I file in `references/`, `scripts/` e `SKILL.md` sono riscritti per questa skill.
Rispetto al repo originale:

- le 7 skill separate del progetto (`seedance-prompter`, `kling-prompter`,
  `happyhorse-prompter`, `seedance-storyboard`, `seedance-debugger`,
  `model-selector`, `prompt-translator`) sono state unificate in un solo
  pacchetto autoconsistente, perché nell'originale si linkavano a vicenda e a
  file esterni alla propria cartella;
- i contenuti operativi sono stati condensati e tradotti in italiano, così che
  la skill si attivi su richieste in italiano;
- `references/social.md` è nuovo: non c'è materiale equivalente nell'originale;
- `scripts/cerca_prompt.py` è nuovo: serve a interrogare i JSON senza aprirli.

La documentazione cinese in `methodology/` resta la fonte più dettagliata:
consultala per le masterclass estese sui singoli modelli.
