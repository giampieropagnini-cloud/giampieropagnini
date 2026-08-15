# Scegliere il modello

Fonte: matrice del progetto lanshu-awesome-ai-video-kit. Il panorama si muove in fretta — se una capacità è decisiva per il lavoro, verificala sul sito del modello prima di promettere qualcosa all'utente.

## Matrice rapida

| Modello | Fornitore | Audio nativo | Fisica | Edita video esistenti | Durata max | Terreno di casa |
|---|---|---|---|---|---|---|
| **Seedance 2.0** | ByteDance | no | ★★★ | no | 15s | narrazione cinematografica, multi-soggetto |
| **Kling 3.0** | Kuaishou | ★★★★ | ★★★★ | sì | 15s per segmento, ~2 min con storyboard | dialoghi, image-to-video |
| **HappyHorse 1.0** | Alibaba | ★★ | ★★ | no | 15s (default 5s) | clip compatte, ASMR |
| **Sora 2** | OpenAI | ★★★★ | ★★★★★ | no | 25s (Pro) | qualità cinematografica, film d'autore |
| **Veo 3.1** | Google | ★★★★★ | ★★★ | no | fino a ~148s concatenando | dialoghi fra più persone, audio sincronizzato |
| **Gemini Omni** | Google | ★★★ | ★★★ | ★★★★★ | — | editing iterativo, testo renderizzato nel video |
| **Runway Gen-4 / Aleph** | Runway | no | ★★★ | ★★★★★ | 30s | **editing di video esistenti** (capacità esclusiva) |
| **Pika 2.5** | Pika Labs | ★ | ★★ | no | 25s | effetti creativi (Pikaffects) |
| **Hailuo 02** | MiniMax | no | ★★★★★ | no | 10s | acqua, fuoco, tessuti, gravità |
| **Wan 2.7** | Alibaba | ★★★★★ | ★★★ | sì | 15s | avatar parlanti, lip-sync |
| **Hunyuan Video 1.5** | Tencent | no | ★★★ | sì | 10s | open source, LoRA, self-hosting |
| **Jimeng 3.0** | ByteDance | ★★ | ★★★ | no | 15s | integrazione con CapCut |

Open source oltre a Hunyuan: LTX-Video, Mochi 1, CogVideoX 5B.

## Albero decisionale

```
Devi modificare un video che hai già?
├── sì → Runway Aleph (nessun altro lo fa nativamente)
└── no
    ├── Persona che parla in camera / lip-sync?      → Wan 2.7
    ├── Dialogo fra più personaggi + audio preciso?  → Veo 3.1
    ├── Fisica estrema (acqua, fuoco, salti)?        → Hailuo 02
    ├── Effetti virali (si scioglie, esplode)?       → Pika 2.5
    ├── Deve girare in locale / budget zero?         → Hunyuan 1.5
    ├── Massima resa cinematografica?                → Sora 2
    ├── Clip 5-15s con audio ambientale?             → HappyHorse 1.0
    └── Storia su più inquadrature?                  → Seedance 2.0 o Kling 3.0
```

## Scorciatoie per estremi

| Serve… | Ordine di preferenza |
|---|---|
| video più lungo | Veo 3.1 concatenato > Kling storyboard > Sora 2 Pro > Seedance/Wan > Hailuo |
| fisica più credibile | Hailuo 02 > Sora 2 > Kling 3.0 |
| audio migliore | Veo 3.1 > Wan 2.7 > Kling 3.0 > HappyHorse |
| editing | Runway Aleph (esclusiva) |
| open source | Hunyuan 1.5 |
| effetti speciali | Pika 2.5 |
| resa da cinema | Sora 2 > Runway > Hailuo > Veo |

## Come rispondere

Consiglia **una** scelta principale e **una** alternativa, con una riga di motivo ciascuna. Non elencare tutti e dodici i modelli: è la domanda dell'utente al contrario.
