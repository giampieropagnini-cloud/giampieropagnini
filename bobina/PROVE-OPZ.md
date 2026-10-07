# Prove OP-Z

Prove con l'OP-Z vero, una alla volta. Risultato: ✅ va · ❌ non va · ❓ da rifare.
Le fonti dei dubbi sono in OPZ-RICERCA.md §14.

| # | prova | come | risultato |
|---|---|---|---|
| 1 | collegamento bluetooth | Collega → cerca l'OP-Z (tasto pairing sotto l'OP-Z). Che nome compare? | |
| 2 | ▶ ■ | Suona → suona / ferma | |
| 3 | pattern 1-16 | Suona → tasti pattern, da fermo e mentre suona (alla battuta) | |
| 4 | pattern prima / dopo | CC 103 valori 16 e 17 | |
| 5 | muti | Muti → kick, snare… (CC 53, 127 = muto) | |
| 6 | muto solo audio | CC 54 | |
| 7 | gruppi di muti | CC 55, 0 = gruppo 1? | |
| 8 | tempo da solo | Ritmo → l'OP-Z va da solo, − + (CC 56 = bpm, 40-127) | |
| 9 | clock di Bobina col bluetooth | Ritmo → Bobina dà il clock (tasto 4 acceso sull'OP-Z): sta a tempo? scatti? | |
| 10 | insieme a TX-6 / PO | stessa battuta? anticipo da regolare? | |
| 11 | swing | CC 57: 64 = niente swing? | |
| 12 | punch-in | Effetti: quale ottava (53-64 o 65-76) fa partire gli effetti? | ✅ 4/10: SHIFT + tasto manda note 9 e 11 sul canale 13 → fa = 5. Con 5-16 e 17-28 vanno («vanno forti») |
| 13 | − + del suono | CC relativi 32-49 | |
| 14 | poliritmi | CC 60 | |
| 15 | canzone a pattern | ogni 4 battute, il cambio cade sul battere? | |

## 4/10/2026

- Collegato col bluetooth: «funziona quasi tutto» (Giampiero), tranne gli effetti.
- Tastiera: i primi tre tasti della fila di sotto mandano 53, 55, 57 sul canale della traccia attiva (kick).
- SHIFT + tasto (punch-in) manda note bassissime sul canale 13 (visti 9 e 11). Gli effetti ora partono da 5.
- Crea (Bobina suona le tracce 1-8 a passi): note, batteria e sequenza vanno. Se non suona niente: Live → «tutto suona» (l'OP-Z ricorda i muti, Bobina dopo una reinstallazione no).
- Pattern di Bobina (16, copia/incolla): vanno.
- Effetti di Bobina dal vivo e nei passi: vanno. Duck rinforzato (20 passi relativi giù); durata degli effetti nei passi 1-16: va.
- Pattern da 4 a 32 passi e catena di pattern: va.
- Passi per traccia (1-32, poliritmi kick 4, snare 7, perc 5): va.

Da provare ancora: «scrivi una battuta sull'OP-Z» col record lock, clock di Bobina insieme a TX-6 e PO, CC 102/103 canali, swing.
- Durata delle note per traccia (tenuta per arp e chord), «ricomincia da zero», «svuota» sotto i passi: vanno.
- Arpeggio: quello dell'OP-Z non va a tempo con Bobina e col CC 9 = 8 restava acceso lentissimo; tenuto solo quello di Bobina (CC 9 = 0 spegne quello dell'OP-Z). Va a tempo.
- Tasti nota tocca/tieni, note tenute accavallate, arpeggio sulle note tenute: «suona tutto perfetto».
- Mixer di Crea (suona/muta, solo, volume): va.
- 7/10: «scrivi sull'OP-Z» con 2 battute (32 passi, pattern 1 e 2): «sembra funzionare» → il record lock regge il cambio di pattern via CC 103.
- 7/10: lo stop MIDI (anche due volte) NON spegne il record lock: va tolto a mano (REC). In Bobina, alla fine della scrittura, un avviso rosso lo ricorda.
