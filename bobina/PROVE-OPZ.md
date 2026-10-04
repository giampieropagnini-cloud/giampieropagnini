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
| 12 | punch-in | Effetti: quale ottava (53-64 o 65-76) fa partire gli effetti? | ❌ 4/10 con 53-64. Misurato: SHIFT + tasto manda note 9 e 11 sul canale 13 → fa = 5. Corretto, da riprovare |
| 13 | − + del suono | CC relativi 32-49 | |
| 14 | poliritmi | CC 60 | |
| 15 | canzone a pattern | ogni 4 battute, il cambio cade sul battere? | |

## 4/10/2026

- Collegato col bluetooth: «funziona quasi tutto» (Giampiero), tranne gli effetti.
- Tastiera: i primi tre tasti della fila di sotto mandano 53, 55, 57 sul canale della traccia attiva (kick).
- SHIFT + tasto (punch-in) manda note bassissime sul canale 13 (visti 9 e 11). Gli effetti ora partono da 5.
