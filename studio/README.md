# Studio: materiale di partenza

Qui va tutto quello che serve per progettare il nuovo studio.
Claude legge SOLO questo repository: i link a Drive, iCloud o Polycam
non sono raggiungibili dal suo ambiente.

## Dove mettere i file

| Cartella            | Cosa                                                        |
|---------------------|-------------------------------------------------------------|
| `studio/scansione/` | export Polycam: modello 3D (GLB), planimetria (PDF/DXF/PNG)  |
| `studio/foto360/`   | foto 360 della Insta360 X6 in formato equirettangolare (JPG)|
| `studio/foto/`      | foto normali del telefono: pareti, finestra, porta, prese   |

## Come caricare dal telefono (Safari o Chrome)

1. Apri github.com e accedi.
2. Repository `giampieropagnini` → in alto scegli il ramo `claude/home-studio-design-ydiboc`.
3. Entra nella cartella giusta (es. `studio/scansione`).
4. Menu "Add file" → "Upload files". Se il menu non compare, attiva
   "Richiedi sito desktop" dal menu del browser (icona AA in Safari).
5. Seleziona il file da Files / Foto e premi "Commit changes".

Limite del caricamento da browser: 25 MB per file. Per file più grandi
usa l'app Working Copy (iPhone) oppure un computer con git: il limite sale a 100 MB.

## Export Polycam (iPhone)

Polycam → Library → apri la scansione della stanza → icona Export/Condividi:

- Modello: formato **GLB**, qualità *Medium* (resta sotto i 25 MB). Nome: `stanza.glb`
- Planimetria (Floor plan): **PDF** e **DXF** se disponibili, altrimenti **PNG**
  con le misure visibili. Nome: `planimetria.pdf` / `planimetria.dxf` / `planimetria.png`
- Se compare anche "Room plan" (USDZ o JSON), aggiungilo: `roomplan.usdz`

## Export Insta360 X6

App Insta360 → Album → apri la foto 360 → Export:

- Scegli **foto 360** (equirettangolare, immagine larga il doppio dell'altezza),
  NON un "reframe" piatto. Nome: `stanza-360.jpg`
- Se il JPG supera i 25 MB, esporta a risoluzione più bassa
  oppure caricalo con Working Copy.
