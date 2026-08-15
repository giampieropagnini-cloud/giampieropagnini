# Vincoli negativi

I vincoli delimitano lo spazio di generazione. Senza, il modello riempie i buchi come gli pare — e di solito li riempie con watermark, sottotitoli e mani a sei dita.

## I tre di base — mettili sempre

```
niente watermark
niente logo
nessun testo o sottotitolo
```

(In inglese: `no watermarks`, `no logos`, `no text overlays, no subtitles`.)

## Per problema

**Stabilità dell'immagine**
```
volto stabile, senza deformazioni
proporzioni del corpo stabili
movimenti continui e naturali, non rigidi
nessuna compenetrazione, nessuno scatto, nessuno sfarfallio
```

**Coerenza di stile**
```
stile [X] costante per tutta la durata
nessuna deriva stilistica
gradazione colore uniforme
```

**Anti-doppione** (il modello che clona il personaggio)
```
vietato mostrare persone identiche per aspetto, abbigliamento e accessori
nessun effetto gemello o sdoppiamento
un solo esemplare per ciascun personaggio nella stessa inquadratura
```

**Stabilità della macchina**
```
inquadratura stabile, senza scossoni
macchina fissa
nessuno zoom improvviso
```

**Pulizia audio**
```
audio naturale, senza troncamenti
dissolvenza audio in chiusura
```

**In inglese**, per i modelli che lavorano meglio così:
```
avoid camera shake, no text overlays, no watermarks,
avoid blurry faces, no extra limbs, no distorted hands
```

## Combinazioni che si annullano

Scriverle insieme equivale a non scrivere niente: il modello ne sceglie una a caso, o le media in qualcosa di brutto.

| ❌ Coppia contraddittoria | Perché |
|---|---|
| `8mm film` + `4K ultra sharp` | la pellicola *è* grana e morbidezza |
| `film grain` + `ultra sharp` | stesso conflitto |
| `cinematic` + `handheld documentary` (entrambi enfatizzati) | due grammatiche visive opposte |
| più di due stili d'autore insieme | il modello ne prende uno solo |
| `slow motion` + `high speed action` | contraddizione temporale |

## Quanti metterne

Da tre a sei righe di vincoli. Oltre, cominci a soffocare la parte creativa del prompt e la resa peggiora.
