# Prove col TP-7 vero

iPhone 16 Pro Max (iOS 26.7, USB-C), TP-7 firmware 1.1.11, Bobina compilata con Xcode 26.6.

| # | cosa | come | risultato |
|---|---|---|---|
| 1 | l'iPhone vede il TP-7 come porta MIDI | cavo USB-C, TP-7 su MIDI → cue | ✅ 28/9/2026: «collegato a TP-7», Bobina sceglie da sola ingresso e uscita |
| 2 | trasporto (▶ ■ ⏮ ●) | scheda Nastro, TP-7 su MIDI → cue | ❌ 28/9/2026: ▶ ■ ● ecc. non fanno niente. Funzionano invece la bobina da girare (cc 18) e gli altri controlli della pagina Nastro (pitch bend). Con MIDI → **sync** invece ▶ ■ ● funzionano tutti ✅. Quindi in «cue» il TP-7 ignora start/continue/stop (FA/FB/FC); «off» non ancora provato |
| 3 | segnare e richiamare i cue da MIDI | scheda Pad, TP-7 su cue, schermata CUE | da provare |
| 4 | loop via MIDI | schermata LOOP aperta sul TP-7 | da provare |
| 5 | tape stop e avvio | scheda Nastro, mentre suona, MIDI → sync | ✅ 28/9/2026: rallenta e si ferma; «avvio» riparte lento e sale |
| 6 | «segui il TP-7» | TP-7 su MIDI → sync, scheda Ritmo | ✅ 28/9/2026: il primo tentativo era sbagliato. Rifatto: arrivano start, clock e stop; col cancello acceso il suono si spezza a tempo, e i passi del cancello si cambiano mentre suona |
| 7 | specchio dei tasti (TP-7 → Bobina) | TP-7 su MIDI → ctrl, scheda Collega | ✅ 28/9/2026: arrivano ▶ (cc 23), ■ (cc 24), ● (cc 22), mode (cc 28), premuto 127 e lasciato 0 |

## Misure sul Mac (TP-7 col cavo, ascoltatore CoreMIDI)

- In ctrl: cc 22/23/24/28 premuto e lasciato, cc 30 della bobina relativo (1-3 avanti, 125-127 indietro).
- In sync: fa allo ▶, clock regolare per tutta la riproduzione (110 BPM col file di prova), fc allo ■.

## Da sistemare

- Collega → «a chi parla Bobina»: i due menu mostrano entrambi «TP-7» senza dire quale è l'uscita e quale l'ingresso.
