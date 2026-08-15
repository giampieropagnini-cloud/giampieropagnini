# La formula a 8 elementi

Un buon prompt video è un'**istruzione da regista**, non un tema descrittivo: chi, fa cosa, dove, con che luce, ripreso come, in che ordine temporale.

```
soggetto preciso + dettaglio dell'azione + ambiente + luce e colore
+ movimento di macchina + stile visivo + qualità + vincoli negativi
```

## 1 · Soggetto preciso

Il modello deve poter identificare il soggetto senza ambiguità. Usa **2-3 caratteristiche statiche e stabili** (abbigliamento, capelli, categoria) — non caratteristiche mutevoli.

- Debole: "una donna"
- Forte: "la donna con il vestito rosso e il cappello di paglia"

Con immagini di riferimento, definisci esplicitamente il legame:
`definisci come soggetto 1 la donna con il vestito rosso nell'immagine 1`

Con più soggetti, dai a ciascuno un'etichetta univoca e **riusa sempre quella stessa etichetta** nel resto del prompt ("il poliziotto", "il ladro"). Mai lasciare un pronome ambiguo.

## 2 · Dettaglio dell'azione

- **Parti del corpo + quantificazione**: non "si muove", ma "alza lentamente la mano destra", "gira la testa di scatto".
- **Preferisci movimenti piccoli e continui.** Corse, salti, capriole violente degradano la resa in quasi tutti i modelli.
- **Collega le azioni fra loro**: "sfruttando l'inerzia della rotazione, alza il braccio". Le transizioni fanno la naturalezza.
- **Esternalizza l'emozione** in dettagli fisici:

| Invece di | Scrivi |
|---|---|
| è triste | le spalle si abbassano, lo sguardo scivola a terra, il respiro si fa corto |
| è arrabbiato | la mascella si contrae, le nocche sbiancano sul bordo del tavolo |
| è nervoso | le dita tamburellano, deglutisce, sposta il peso da un piede all'altro |
| è felice | gli angoli degli occhi si increspano, le spalle si sciolgono |

## 3 · Ambiente

Dove si trova il soggetto e in che rapporto spaziale con quello che lo circonda. Poche parole, ma concrete.

## 4 · Luce e colore

**Momento**: golden hour · blue hour · mezzogiorno · cielo coperto
**Sorgente**: luce dura · luce morbida · luce da finestra · neon · luce volumetrica · controluce

| Termine (inglese, usalo così) | Effetto emotivo |
|---|---|
| golden hour | caldo, nostalgico, da viaggio |
| blue hour | freddo, fantascientifico, solitario |
| overcast | documentaristico, uniforme, reale |
| hard key light | drammatico, noir |
| soft window light | intimo, calmo, autentico |
| neon spill | cyberpunk, vita notturna |
| volumetric lighting | epico, sacro |
| backlight / rim light | silhouette, contorno marcato |
| practical light | naturale, ambientale |
| butterfly lighting | beauty, ritratto premium |
| tungsten | interni, vintage, giallo caldo |
| fluorescent | ufficio, metropolitana, ospedale |

**Gradazione colore**: `teal and orange grading` (lo standard hollywoodiano) · `warm grading` · `cool grading` · `high saturation` · `desaturated, muted palette` · `black and white`

## 5 · Movimento di macchina

**Dimensione dell'inquadratura**

| Termine | Sigla | Quando |
|---|---|---|
| Extreme Wide Shot | EWS | geografia, isolamento, grandiosità |
| Wide Shot | WS | contesto ambientale |
| Medium Shot | MS | relazioni, gesti |
| Medium Close-Up | MCU | intenzione, mani, oggetti |
| Close-Up | CU | emozione, dettaglio |
| Extreme Close-Up | ECU | texture, occhi, micro-espressioni |

**Movimento**

| Termine | Effetto |
|---|---|
| dolly in / push in | enfasi, avvicinamento |
| dolly out / pull back | rivelazione, distacco |
| pan left / right | segue, mostra lo spazio |
| tilt up / down | rivela l'altezza |
| crane up / down | sguardo dall'alto |
| tracking shot | segue il soggetto |
| orbit / arc | presentazione prodotto o personaggio |
| handheld | documentaristico, teso |
| gimbal / steadicam | fluido, piano sequenza |
| rack focus | sposta l'attenzione |
| slow push-in | costruisce suspense |
| aerial / drone | vista d'insieme |

**Angolo**: low angle · high angle · eye level · bird's eye

> ⚠️ **Un solo movimento per inquadratura.** Chiedere insieme dolly + pan + zoom è la causa numero uno di immagini instabili.

## 6 · Stile visivo

| Stile | Parole chiave |
|---|---|
| cinematografico | cinematic, film grain, anamorphic, 35mm |
| documentario | documentary, handheld, naturalistic, vérité |
| pubblicitario | commercial quality, clean aesthetic, product hero |
| cyberpunk | cyberpunk, neon-lit, holographic, dystopian |
| pellicola vintage | vintage, 8mm, VHS, retro grain, color shift |
| anime | anime aesthetic, cel-shaded, Ghibli-inspired |
| surreale | surreal, dreamlike, impossible geometry |
| noir | film noir, high contrast B&W, deep shadows |
| Wes Anderson | symmetrical composition, pastel palette |

Massimo **due** ancoraggi stilistici. Con tre o più il modello ne sceglie uno a caso.

## 7 · Qualità

Nitidezza, texture, resa luminosa: "alta definizione, ricco di dettagli, resa cinematografica, colori naturali, luce morbida".

## 8 · Vincoli negativi

Vedi `vincoli.md`. Non saltarli: sono la differenza fra una generazione usabile e una da buttare.

## Modello di prompt completo

```
[soggetto + azione + ambiente + luce + macchina + stile + qualità]
…descrizione positiva…

Vincoli:
- volto stabile, senza deformazioni
- movimenti continui e naturali, non rigidi
- stile [X] costante per tutta la durata, senza derive
- niente watermark, niente logo, niente sottotitoli
```
