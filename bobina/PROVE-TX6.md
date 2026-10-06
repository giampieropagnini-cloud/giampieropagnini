# Prove col TX-6 vero

Una cosa alla volta, nell'ordine. Ogni riga dice come va messo il TX-6 e cosa guardare.
Le prime quattro si fanno col cavo al **Mac** e l'ascoltatore (`strumenti/ascolta`); le altre con l'**iPhone** e Bobina.

## Sul Mac (l'ascoltatore scrive cosa manda il TX-6)

| # | cosa | come | risultato |
|---|---|---|---|
| 1 | il nome con cui compare | cavo al Mac, TX-6 acceso | da fare |
| 2 | il fader in alto manda 127 o 0 | MIDI → CTRL OUT, fader 1 tutto su poi tutto giù | da fare |
| 3 | la manopola select in OUT | CTRL OUT, gira select a destra poi a sinistra | da fare |
| 4 | il clock che dà il TX-6 | CLOCK → SRC INT, OUT acceso; play sulla schermata del tempo | da fare |

## Con l'iPhone (Bobina, sezione TX-6)

| # | cosa | come | risultato |
|---|---|---|---|
| 5 | Bobina vede il TX-6 | cavo all'iPhone; in alto «collegato a TX-6» | da fare |
| 6 | volume della traccia 1 | MIDI → CTRL IN; Mixer, tr 1 − e + | ✅ 29/9/2026, via bluetooth: volumi delle tracce 1 e 2 (cc 7, canali 1-2) e main (cc 7, canale 7) |
| 7 | il muto fa muto o solo | Mixer, M sulla traccia 2; poi menu SOLO su solo e riprova | da fare |
| 8 | le scene a b c | salva scene diverse sul TX-6, poi Mixer → scene del TX-6 | da fare |
| 9 | la tastiera | NOTE on, SYNTH → play; Suona, traccia 1 | da fare |
| 10 | i sei pad: quale ottava | Suona, sei pad; cambia ottava finché suonano | ✅ 6/10/2026: le note sul canale 7 cambiano anche l'altezza. Con do4 le casse suonano alte come tom; do3 e do2 giuste. Di fabbrica ora do2 |
| 11 | suoni, effetti, pattern: l'ordine sui 128 valori | traccia → synth; Effetti → i nomi; guardare il display | da fare |
| 12 | start/stop e tempo ± | Ritmo → il trasporto del TX-6 | da fare |
| 13 | Bobina dà il tempo | CLOCK → SRC USB (col bluetooth: BLE); Ritmo → «Bobina dà il tempo al TX-6», ▶ | ✅ 29/9/2026, via bluetooth con SRC BLE: Bobina manda start e clock, il TX-6 prende il tempo e parte |
| 14 | Bobina segue il TX-6 | SRC INT, OUT acceso; Ritmo → «segui il TX-6»; play sul TX-6 | ✅ 29/9/2026, via bluetooth: arrivano start (FA) e clock, Bobina mostra lo stesso bpm del TX-6. Quindi il TX-6 manda il clock anche via bluetooth |
| 15 | pompa, onda, scena che sfuma | Ritmo e Mixer, con musica che entra nel TX-6 | da fare |
| 16 | il ponte verso il TP-7 | TX-6 su CTRL OUT col cavo, TP-7 col bluetooth; Collega → ponte | da fare |
| 17 | bluetooth | BLE → ACCEPT; Collega → cerca il TX-6 | ✅ 29/9/2026: compare «TX-6 Bluetooth», Bobina lo sceglie da sola per mandare e ascoltare. Il TP-7 resta collegato in bluetooth nello stesso momento |

## Misure

(qui i numeri veri, man mano)

- Sistemato: lo slider del main rimandava lo stesso valore molte volte.
- 29/9/2026, col bluetooth: la batteria a passi suonava a tempo da fermi, ma andava a scatti quando si scorreva lo schermo. Causa: l'orologio dei passi girava sul filo dello schermo. Ora il sequencer ha un filo suo (TX6Sequencer.swift). Prova sul Mac con lo schermo bloccato 300 ms ogni 500: passi a 125,00 ms esatti, clock a 20,83 ms (strumenti/prova-sequencer). Da riprovare sul telefono.

- Giampiero ricorda di aver già sincronizzato il TX-6 via bluetooth (il TP-7 invece il clock via bluetooth non lo manda: vedi PROVE.md). Da riprovare con la prova 17.
- 29/9/2026, TX-6 e TP-7 insieme via bluetooth: va a scatti. Nel registro oltre 3.300 messaggi di clock in arrivo (circa 50 al secondo) mentre Bobina mandava note e clock al TX-6: un solo bluetooth per due macchine si intasa. Fatto da Bobina: note spente nel pacchetto del passo dopo, clock dentro il pacchetto del passo, pompa a 4 punti, onde ogni 60 ms col bluetooth, avviso se il TX-6 manda un clock che non serve. Misura sul Mac con tre tracce e clock: da 64 a 48 pacchetti al secondo (tutti clock); senza clock 8. Da provare: TX-6 col cavo e TP-7 col bluetooth, oppure «tempo di Bobina» e CLOCK → OUT off sul TX-6.
- 1/10/2026, iPhone 18 Pro (iOS 27), versione ottimizzata (Release): Giampiero dice «molto più veloce, molto più fluido». La sonda conferma: il filo dello schermo non si blocca mai oltre 50 ms, anche con TP-7, TX-6 e due PO collegati insieme via bluetooth.
- 1/10/2026, iOS 27: «cerca il TX-6» faceva chiudere l'app (statusBarHeightForOrientation dà NaN dentro il pannello di Apple). Riparato con IOS27.swift.
