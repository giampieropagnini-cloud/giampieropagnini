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
| 7 | il muto fa muto o solo | Mixer, M sulla traccia 2; poi menu SOLO su solo e riprova | ✅ 6/10/2026: M (cc 120 + volume a zero, e ritorno al volume di prima) funziona. Il solo lo fa Bobina col volume |
| 8 | le scene a b c | salva scene diverse sul TX-6, poi Mixer → scene del TX-6 | da fare |
| 9 | la tastiera | NOTE on, SYNTH → play; Suona, traccia 1 | da fare |
| 10 | i sei pad: quale ottava | Suona, sei pad; cambia ottava finché suonano | ✅ 6/10/2026: le note do-la sul canale 7 suonano la traccia sempre alla stessa altezza (casse come tom, anche a do2); la tastiera sul canale della traccia a do1-do2 dà casse giuste. Ora pad e batteria a passi suonano sul canale della traccia, di fabbrica a do2 |
| 11 | suoni, effetti, pattern: l'ordine sui 128 valori | traccia → synth; Effetti → i nomi; guardare il display | da fare |
| 12 | start/stop e tempo ± | Ritmo → il trasporto del TX-6 | da fare |
| 13 | Bobina dà il tempo | CLOCK → SRC USB (col bluetooth: BLE); Ritmo → «Bobina dà il tempo al TX-6», ▶ | ✅ 29/9/2026, via bluetooth con SRC BLE: Bobina manda start e clock, il TX-6 prende il tempo e parte |
| 14 | Bobina segue il TX-6 | SRC INT, OUT acceso; Ritmo → «segui il TX-6»; play sul TX-6 | ✅ 29/9/2026, via bluetooth: arrivano start (FA) e clock, Bobina mostra lo stesso bpm del TX-6. Quindi il TX-6 manda il clock anche via bluetooth |
| 15 | pompa, onda, scena che sfuma | Ritmo e Mixer, con musica che entra nel TX-6 | da fare |
| 16 | il ponte verso il TP-7 | TX-6 su CTRL OUT col cavo, TP-7 col bluetooth; Collega → ponte | da fare |
| 18 | effetti: acceso e spento | Mixer → FX I: mandate alzate, riverbero; «spento», poi «acceso» | da fare: con «spento» deve tacere (cc 82 a 0 e ritorno a 0), con «acceso» tornare |
| 19 | effetti: cosa fanno i parametri 1, 2, 3 | un effetto alla volta: parametro 1, 2, 3 a 0 e a max, ascoltando | in parte: 8/10/2026 il display del TX-6 non cambia pagina coi parametri (le mandate sì). Dalla guida: un valore per effetto (CHO subtle-strong, REV drone-large, DLY 1/8-mash, TRM 0-99, FRZ −/+, TPE stop1-pong, DST push-dstroy, CRU shape-bit), il filtro due (CUT e RES): il parametro 2 è solo la risonanza del filtro, il 3 nessuno. Da confermare a orecchio |
| 20 | i nomi degli effetti e dei preset | sul TX-6 shift + FX I (poi FX II): la pagina dell'effetto; in Bobina Mixer → FX I/II, tocca un effetto alla volta, poi i suoi preset | in parte: 8/10/2026 FX I col cc 15 = 0 riverbero, 64 chorus, 127 delay (l'ordine della guida li scambiava: rimesso quello della tabella MIDI). Riverbero: drone è l'ultimo (light, small, medium, large, drone), misurato. FX II e gli altri preset da confermare. Ogni preset manda il centro della sua fetta di 0-127 |
| 21 | freeze e tape stop a colpi | Mixer → FX II: «freeze · 1 battuta», «tape stop · 1 battuta», poi «tieni» e «lascia» | da fare: il colpo accende FX II con quell'effetto e dopo una battuta lo spegne |
| 22 | FX II su quale traccia | Mixer → FX II: «tr 1»… «tr 6», «tutto», con un effetto che si sente (tremolo) | 8/10/2026: cc 9 = tracce 1-6 poi tutto il mix per ultimo (con «tutto» primo ogni tasto cadeva sul posto dopo: tr 6 = tutto, tutto = traccia 1). Corretto, da riprovare |
| 23 | tremolo e freeze: quale parametro muove il valore | sul TX-6 shift + FX II (pagina del tremolo, barra 0-99); Mixer → FX II → tremolo → «max» su 1, 2, 3 | 8/10/2026: il parametro 1 (cc 12) lascia la barra a 0. Da fare: quale dei tre la muove |
| 24 | tape e freeze: tieni FX II e rotellina | FX II → tape o freeze: «tieni FX II», poi la rotellina con «parametro 1», 2, 3; poi «tieni per» e «scratch» | da fare: quale parametro fa lo scratch. 8/10/2026, misurato da Giampiero sul TX-6: suonano solo tenendo premuto FX II, e girando select intanto si fa lo scratch |
| 17 | bluetooth | BLE → ACCEPT; Collega → cerca il TX-6 | ✅ 29/9/2026: compare «TX-6 Bluetooth», Bobina lo sceglie da sola per mandare e ascoltare. Il TP-7 resta collegato in bluetooth nello stesso momento |

## Misure

(qui i numeri veri, man mano)

- Sistemato: lo slider del main rimandava lo stesso valore molte volte.
- 29/9/2026, col bluetooth: la batteria a passi suonava a tempo da fermi, ma andava a scatti quando si scorreva lo schermo. Causa: l'orologio dei passi girava sul filo dello schermo. Ora il sequencer ha un filo suo (TX6Sequencer.swift). Prova sul Mac con lo schermo bloccato 300 ms ogni 500: passi a 125,00 ms esatti, clock a 20,83 ms (strumenti/prova-sequencer). Da riprovare sul telefono.

- Giampiero ricorda di aver già sincronizzato il TX-6 via bluetooth (il TP-7 invece il clock via bluetooth non lo manda: vedi PROVE.md). Da riprovare con la prova 17.
- 29/9/2026, TX-6 e TP-7 insieme via bluetooth: va a scatti. Nel registro oltre 3.300 messaggi di clock in arrivo (circa 50 al secondo) mentre Bobina mandava note e clock al TX-6: un solo bluetooth per due macchine si intasa. Fatto da Bobina: note spente nel pacchetto del passo dopo, clock dentro il pacchetto del passo, pompa a 4 punti, onde ogni 60 ms col bluetooth, avviso se il TX-6 manda un clock che non serve. Misura sul Mac con tre tracce e clock: da 64 a 48 pacchetti al secondo (tutti clock); senza clock 8. Da provare: TX-6 col cavo e TP-7 col bluetooth, oppure «tempo di Bobina» e CLOCK → OUT off sul TX-6.
- 1/10/2026, iPhone 18 Pro (iOS 27), versione ottimizzata (Release): Giampiero dice «molto più veloce, molto più fluido». La sonda conferma: il filo dello schermo non si blocca mai oltre 50 ms, anche con TP-7, TX-6 e due PO collegati insieme via bluetooth.
- 7/10/2026: mixer «alcuni comandi funzionano, altri no, alcuni una volta e poi si bloccano». Nel registro il TX-6 mandava il suo clock (32 pacchetti al secondo in arrivo, CLOCK → OUT acceso): il bluetooth era intasato e i comandi si perdevano. Con CLOCK OUT off: «funziona tutto». L'avviso in cima alle pagine del TX-6 ora lo dice chiaro.
- 6/10/2026, sera: «non funziona nulla», né il mixer né le pagine delle tracce, con Bobina collegata e i messaggi giusti. Era il TX-6 che non ascoltava: rimesso su MIDI → CTRL IN, tutto a posto. Quando non risponde niente, prima di toccare il codice si controlla CTRL IN.
- 6/10/2026, prova dei comandi sulla traccia 1 (il display del TX-6 salta sulla pagina del parametro): volume cc 7, guadagno cc 9, pan cc 8, EQ alti/medi/bassi cc 85/86/87, compressore cc 93, FX I cc 91, aux cc 92, aux II cc 94, muto cc 120: tutti come la guida («funziona tutto»). Il filtro (cc 74) non è stato provato.
- 6/10/2026: mixer con guadagno, EQ, compressore e il resto di ogni canale («le sei tracce» a strati, «un canale»): provato da Giampiero, «tutto perfetto».
- 6/10/2026: la cassa che suonava anche alta come un tom e le onde che non si spegnevano erano note rimaste accese sul TX-6 (Bobina chiusa o reinstallata a nota giù). Dopo lo spegnimento automatico al collegamento e il tasto «silenzio»: «adesso funziona».
- 1/10/2026, iOS 27: «cerca il TX-6» faceva chiudere l'app (statusBarHeightForOrientation dà NaN dentro il pannello di Apple). Riparato con IOS27.swift.
- 8/10/2026: spegnendo gli effetti da Bobina Giampiero li sentiva ancora, finché non metteva a zero le mandate delle tracce; il parametro 2 «non si capisce cosa fa». Dalla guida: i tasti FX accendono e spengono, cc 82 0-63 spento e 64-127 acceso; quasi ogni effetto ha un valore solo (select cambia preset o quantità, premuto passa al valore dopo se c'è). Bobina partiva credendo gli effetti spenti senza saperlo: ora «acceso» e «spento» sono due tasti che mandano sempre, e FX I spento mette anche il ritorno a zero. Da provare (prova 18).
- 8/10/2026: «silenzio» toccato per sbaglio col bluetooth, poi il TX-6 non suonava più. Mandava 768 spegnimenti in un secondo. Ora prima i pad e le note delle melodie in un pacchetto, poi le altre due ogni 15 ms (circa 5 secondi).
- 8/10/2026, regola di Giampiero: il guadagno solo ±1 dB, mai salti né «max» (casse in pericolo se il Controllo Vocale sente male). Tolto anche dai passi con manopola, dalle onde, dall'inclinazione; la prova dei comandi lo manda col valore che ha già.
