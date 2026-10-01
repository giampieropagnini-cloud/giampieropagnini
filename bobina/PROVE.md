# Prove col TP-7 vero

iPhone 16 Pro Max (iOS 26.7, USB-C), TP-7 firmware 1.1.11, Bobina compilata con Xcode 26.6.

| # | cosa | come | risultato |
|---|---|---|---|
| 1 | l'iPhone vede il TP-7 come porta MIDI | cavo USB-C, TP-7 su MIDI → cue | ✅ 28/9/2026: «collegato a TP-7», Bobina sceglie da sola ingresso e uscita |
| 2 | trasporto (▶ ■ ⏮ ●) | scheda Nastro, TP-7 su MIDI → cue | ❌ 28/9/2026: ▶ ■ ● ecc. non fanno niente. Funzionano invece la bobina da girare (cc 18) e gli altri controlli della pagina Nastro (pitch bend). Con MIDI → **sync** invece ▶ ■ ● funzionano tutti ✅. Quindi in «cue» il TP-7 ignora start/continue/stop (FA/FB/FC); «off» non ancora provato |
| 3 | segnare e richiamare i cue da MIDI, sequencer di nastro | scheda Pad e Ritmo, TP-7 su cue, schermata CUE, ▶ dalla macchina | ✅ 29/9/2026: i pad segnano e richiamano, il sequencer fa saltare il nastro fra i cue |
| 4 | loop via MIDI | schermata LOOP aperta sul TP-7 | ✅ 29/9/2026 |
| 5 | tape stop e avvio | scheda Nastro, mentre suona, MIDI → sync | ✅ 28/9/2026: rallenta e si ferma; «avvio» riparte lento e sale |
| 6 | «segui il TP-7» | TP-7 su MIDI → sync, scheda Ritmo | ✅ 28/9/2026: il primo tentativo era sbagliato. Rifatto: arrivano start, clock e stop; col cancello acceso il suono si spezza a tempo, e i passi del cancello si cambiano mentre suona |
| 7 | specchio dei tasti (TP-7 → Bobina) | TP-7 su MIDI → ctrl, scheda Collega | ✅ 28/9/2026: arrivano ▶ (cc 23), ■ (cc 24), ● (cc 22), mode (cc 28), premuto 127 e lasciato 0 |

| 9 | ⏪ ⏩ avvolgimento veloce (cc 18 a 0 e 127) | scheda Nastro | ✅ 29/9/2026: avanti e indietro velocissimi. Ma arrivato in fondo **non passa alla canzone dopo**: via MIDI non c'è modo di cambiare canzone |
| 10 | ▶ in cue con la leva | scheda Nastro, TP-7 su cue e fermo, leva tenuta su un valore | ⚠️ 30/9/2026: a **60** il nastro suona a velocità normale, ma (1/10) si ferma da solo sempre prima: secondo lucidyan/tp7-midi a nastro fermo 60 = indietro ×1, 64 = fermo, 68 = avanti ×1. Quindi riavvolgeva fino all'inizio. Il ▶ in cue ora usa 68. Attenzione: la leva lasciata a 60 mentre il nastro suona da solo (dopo un pad) lo tiene fermo, e la sequenza sembra non andare |
| 11 | trasporto in cue (▶ ■ con la leva) | scheda Nastro, TP-7 su cue | ✅ 1/10/2026: ▶ suona a velocità normale, ■ ferma. ❌ i pad in «richiama» a nastro fermo spostano il nastro ma non lo fanno partire, e Bobina toglieva la leva a ogni colpo: sequenza muta. Corretto: il pad fa partire la leva se il nastro è fermo. ❌ ● (cc 14 + continue) in cue arma ma non parte: aggiunto un ● in cue. Provato: arma, ma la ripresa parte solo col ▶ della macchina; il ■ in cue (disarmo, cc 14 a 0) la chiude. Ora ● in cue arma soltanto. ❓ col nastro che corre con la leva, passando a Ritmo il TP-7 si ferma e resta bloccato finché non premi ▶ e ■ sulla macchina: da capire |
| 12 | ▶ in cue con la leva a 68 | scheda Nastro, TP-7 su cue, bluetooth | ✅ 1/10/2026: suona in avanti e non si ferma. ❌ pad in «richiama» e sequenza muti; suonavano solo tenendo «dito». Motivo: il pad sposta il nastro ma suona solo se corre già, e Bobina al colpo rimetteva la leva al centro (fermo); il dito (60) lo faceva correre all'indietro. Corretto: il pad lascia la leva a 68, e se il nastro è fermo lo fa partire |
| 13 | tutto in cue col bluetooth: ▶ ■ a leva, pad, sequenza, dito | TP-7 su cue, vecchio iPhone | ✅ 1/10/2026: «funziona perfetto». Registrare senza toccare la macchina in cue **non si può**: provato ● = arma + leva 68, arma ma non parte; serve il ▶ della macchina. Il ■ di Bobina (disarmo) chiude la ripresa. In sync invece il ● di Bobina registra |
| 14 | banche con i segni già scritti | 10 WAV fatti da `strumenti/banche/genera.py`, copiati con field kit | ✅ 1/10/2026: primo tentativo coi soli segni (chunk cue): il TP-7 li tiene ma i pad non li suonano. Da un file segnato a mano si è visto il formato vero: cue con id da 0 in ordine di posizione, più un LIST/adtl con una voce «note» per segno (C2 = nota 36). Con quello, i pad suonano i segni appena il file è sul TP-7 |
| 8 | mixer: volume, deriva, ingressi, registrazione da Bobina | scheda Mixer, MIDI → sync | ✅ 29/9/2026: tutto funziona |

## Col bluetooth (29/9/2026)

- Collegamento: dopo «cerca il TP-7» Bobina sceglie da sola «TP-7 Bluetooth» in uscita e in ingresso ✅. Il collegamento è caduto una volta ed è tornato da solo.
- In sync arrivano start, continue e stop (fa, fb, fc), ma **nessun impulso di clock**: col bluetooth «segui il TP-7» non può funzionare, e il cancello resta fermo. Col cavo il clock arriva.
- Il muto (M nel Mixer) arriva ✅. Il cancello col tempo di Bobina (tap, «segui il TP-7» spento) spezza il suono a tempo ✅: i messaggi a tempo viaggiano bene anche col bluetooth.
- In ctrl arrivano i giri della bobina del TP-7 (cc 30) ✅.
- Provato anche al contrario (TP-7 su scan, Bobina «fatti trovare»): il collegamento non si è formato, quindi niente di misurato. La sincronizzazione bluetooth che Giampiero ricordava era col TX-6, non col TP-7.
- Con TP-7 e TX-6 insieme in bluetooth sono arrivati circa 50 impulsi di clock al secondo, quasi certamente dal TX-6 (aveva CLOCK → OUT acceso); dal TP-7 solo continue e stop. La misura col solo TP-7 (accept) resta: zero impulsi.

## Misure sul Mac (TP-7 col cavo, ascoltatore CoreMIDI)

- In ctrl: cc 22/23/24/28 premuto e lasciato, cc 30 della bobina relativo (1-3 avanti, 125-127 indietro).
- In sync: fa allo ▶, clock regolare per tutta la riproduzione (110 BPM col file di prova), fc allo ■.

## Sistemato

- Ritmo: con «segui il TP-7» acceso e il TP-7 in bluetooth, una riga avvisa che il tempo arriva solo col cavo (1/10/2026).
- Collega → «a chi parla Bobina»: accanto ai due menu c'è scritto «manda a» e «ascolta» (1/10/2026).
