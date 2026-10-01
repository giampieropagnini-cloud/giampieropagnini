# OP-Z — appunti di ricerca (1/10/2026)

Per la sezione OP-Z di Bobina. Ogni riga dice da dove viene:

- 📄 **documentato**: guida ufficiale teenage engineering, note dei firmware, file di testo che TE mette nel disco dell'OP-Z
- 🔎 **community**: ricavato da altri (reverse engineering, codice su GitHub, forum). Tra parentesi chi e quando
- ❓ **da misurare**: nessuno lo dice chiaro, le fonti litigano, oppure è una mia deduzione

Firmware: l'ultimo è **1.2.45 del 31/3/2022** 📄[FW]. Da allora niente: le misure della community del 2026 valgono per la macchina di oggi.

| sigla | fonte |
|---|---|
| G | [guida OP-Z](https://teenage.engineering/guides/op-z/midi), cap. 21 «midi». Altri capitoli col nome: G-tempo, G-tracks, G-track, G-mixer, G-project, G-app… |
| FW | [note dei firmware](https://teenage.engineering/downloads/op-z) |
| DISK | `how_to_import.txt` del disco OP-Z e due `midi.json` veri ([chrisrauh/opz-collab](https://github.com/chrisrauh/opz-collab), [schollz/error-garden](https://github.com/schollz/error-garden)) |
| KM | [kmorrill/op-z-sysex](https://github.com/kmorrill/op-z-sysex) (29/8/2026): SysEx provato sulla macchina, fw 1.2.45 |
| OD | [opzdoc wiki](https://github.com/hyphz/opzdoc/wiki/MIDI-Protocol) (hyphz / MarkRdgOx): la prima mappa SysEx |
| LIB | [patriciogonzalezvivo/libopz](https://github.com/patriciogonzalezvivo/libopz) (C++, licenza non commerciale: solo come documentazione) |
| ZPO | [lrk/z-po-project](https://github.com/lrk/z-po-project/wiki): formato dei progetti |
| STU | [agolg/opz-studio](https://github.com/agolg/opz-studio) (editor web, 18/9/2026) |
| NBW | [nbw/opz](https://github.com/nbw/opz) (OPZ.js, 2020-21): cosa esce dall'OP-Z |
| TEK | [ericlewis/TEKit](https://github.com/ericlewis/TEKit) (Swift, 31/3/2026, un solo commit) |
| F-n | thread di op-forums.com numero n · LP = forum Loopy Pro |
| APP | scheda App Store dell'app OP-Z, letta il 1/10/2026 |

## In breve: le 8 cose che contano per Bobina

1. 📄 Tutte e 16 le tracce ricevono e mandano MIDI, **ognuna sul suo canale**: di serie traccia N = canale N (🔎 DISK, OD, NBW).
2. 📄 Le impostazioni MIDI si cambiano tenendo **TEMPO + SCREEN** e premendo i tasti 1-8: per Giampiero lo fa Ele una volta. La cosa più importante: **tasto 1 spento** (altrimenti il canale 1 va alla traccia attiva e non al kick).
3. 📄 Cambio pattern con **CC 103** (0-15, 16 = dopo, 17 = prima) o program change. 📄 Il cambio è **immediato** e tiene la posizione del passo: la battuta giusta la deve scegliere Bobina.
4. 🔎 **Tempo via CC 56 solo fino a 127 bpm** (valore = bpm, sotto 40 resta 40). Per un tempo esatto e oltre 127 serve il clock.
5. 📄🔎 **Niente clock in uscita sul bluetooth** (TE al supporto). Clock in entrata sul bluetooth: segnalati scatti e blocchi (2019) ❓. Col cavo il clock va.
6. 🔎 Sull'iPhone l'OP-Z è un normale dispositivo **bluetooth MIDI**: dopo il collegamento lo vedono anche altre app (AUM, midimittr). Un solo collegamento bluetooth per volta; cavo e bluetooth insieme sì.
7. 🔎 Col SysEx della community si **legge** molto: batteria in %, pattern e progetto attivi, muti, tempo esatto, i suoni. Ma un messaggio di scrittura ($07) ha **fatto piantare un OP-Z vero** il 18/9/2026 (STU). In Bobina v1: solo MIDI standard, SysEx al massimo in lettura e col cavo.
8. ❓ L'app ufficiale (Unity, solo inglese) non dichiara nessuna accessibilità: con Controllo Vocale quasi certamente solo la griglia.

## 1. Le 16 tracce

📄 G-tracks: 8 tracce audio (1-4 batteria, 5-8 synth) e 8 tracce di controllo (9-16). Canali di serie: 🔎 `track_channels [0..15]` nei `midi.json` veri (DISK), decodifica del $10 (OD), «MIDI IN always matches the position of the track» (defn, F-13646, 4/4/2019), OPZ.js (NBW).

| # | traccia | canale di serie | cosa fa una nota in entrata | note per passo |
|---|---|---|---|---|
| 1 | kick | 1 | uno dei 24 suoni del kit 📄 | 2 📄 |
| 2 | snare | 2 | idem | 2 |
| 3 | perc | 3 | idem | 2 |
| 4 | sample | 4 | idem | 2 |
| 5 | bass | 5 | nota, monofonico 📄 | 1 |
| 6 | lead | 6 | nota, polifonia 3 📄 | 3 (🔎 KM: 4 posti in memoria) |
| 7 | arp | 7 | le note tenute diventano arpeggio 📄 | 🔎 8 posti (KM, STU) |
| 8 | chord | 8 | accordi, polifonia 4 (6 con `generous_chords`) 📄 | 4 |
| 9 | fx1 | 9 | «parameters can be set using the musical keyboard» 📄; riverbero: i tasti danno il predelay 📄 | 1 |
| 10 | fx2 | 10 | idem | 1 |
| 11 | tape | 11 | bianchi = da dove riparte il nastro, neri = lunghezza del loop (1 corto … 0 lungo) 📄 | 1 |
| 12 | master | 12 | trasporta la tonalità / il modo delle tracce scelte; progressioni d'accordi 📄 | 4 |
| 13 | perform | 13 | effetti punch-in su tutte le tracce 📄 | 6 |
| 14 | module | 14 | senza modulo è «una traccia MIDI con 16 CC indipendenti» 📄; con oplab esce in CV | 6 |
| 15 | lights | 15 | neri = 10 pattern di luci, bianchi = effetti e animazioni 📄 (14 🔎 KM); serve un'interfaccia DMX USB | 4 |
| 16 | motion | 16 | immagini (photomatic) o grafica (motion) **nell'app OP-Z** 📄 | 4 |

Note per passo: 📄 per le tracce 1-8; per le 9-16 sono i posti in memoria (🔎 KM).

❓ Che le note via MIDI facciano davvero tutto questo sulle tracce 9-16 non l'ha scritto nessuno: va provato traccia per traccia. 🔎 Un banco di prova di KM si aspetta note in uscita da 9, 10, 11, 13, 14, 15, 16 e **non** da master (12).

## 2. Le impostazioni MIDI

### Sulla macchina

📄 G 21.3: tieni **TEMPO + SCREEN** (dal fw 1.2.38 📄 FW; prima era SHIFT + tasti neri sulla traccia module 🔎 OD, F-7733) e premi:

| tasto | impostazione | nel `midi.json` | bit del $10 🔎 KM | a cosa serve |
|---|---|---|---|---|
| 1 | channel one to active | `channel_one_to_active` | 0 | quello che arriva sul canale 1 va alla traccia attiva |
| 2 | incoming midi | `incoming_midi` | 1 | ascolta il MIDI |
| 3 | outgoing midi | `outgoing_midi` | 2 | manda il MIDI |
| 4 | midi clock in | `timing_clock_in` | 3 | segue il clock esterno |
| 5 | midi clock out | `timing_clock_out` | 4 | manda il clock |
| 6 | alt program change | `alt_program_change` | 5 | altro modo di leggere i program change (vedi 3f) |
| 7 | midi echo | `midi_echo` | 6 | rimanda indietro sulla stessa porta quello che riceve, e lo passa alle altre porte |
| 8 | enable program change | `enable_program_change` | 7 | program change in entrata e in uscita |
| tracce 1-16 | mute track | `track_enable` | byte 0-15 | spegne tutto il MIDI di quella traccia |
| tieni una traccia 1 s + manopola verde | canale 1-16 | `track_channels` | byte 16-31 | canale di quella traccia (scorciatoia dal fw 1.2.31 📄 FW) |

❓ Come si vede se un'impostazione è accesa (led acceso = on?). 📄 FW 1.1.23: `enable_program_change` resta dopo lo spegnimento; ❓ le altre di sicuro.

### Il file `midi.json`

📄 G 21.4 e DISK: si accende tenendo **TRACK**, compare il disco «OP-Z», file `config/midi.json`; il MIDI si può solo **modificare** (non aggiungere né togliere). Com'è fatto davvero (🔎 DISK, chrisrauh/opz-collab):

```json
{
  "alt_program_change" : false,
  "channel_one_to_active" : true,
  "enable_program_change" : true,
  "incoming_midi" : true,
  "midi_echo" : false,
  "outgoing_midi" : true,
  "parameter_cc_out" : [ [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 ], … 16 righe … ],
  "timing_clock_in" : false,
  "timing_clock_out" : true,
  "track_channels" : [ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 ],
  "track_enable" : [ true, true, … 16 volte ]
}
```

- 🔎 `track_channels` nel file parte da **0** (la guida dice 1-16).
- `parameter_cc_out`: 📄 la guida dice 0-255; 🔎 nei file 1-16, per KM 0-127.
- `parameter_cc_out` cambia solo i CC **in uscita**: quelli in entrata restano fissi (🔎 KM).

### Via app o SysEx

📄 G 21.5: l'app ha una pagina «midi setup» (CC in uscita, canale per traccia, gli 8 interruttori). 🔎 KM: l'app non simula tasti, manda il SysEx `$10` con tutta la configurazione (292 byte: 16 tracce accese, 16 canali da 0, 256 CC in uscita, 1 byte con gli 8 bit sopra, 3 byte da lasciare uguali).

### Come esce di fabbrica

❓ Non è scritto. Indizi:
- 📄 G-tempo: «by default, incoming midi clock is disabled».
- 🔎 Due file veri: uno con tasto 1 acceso e clock out acceso, l'altro con entrambi spenti.
- 🔎 OD ha decodificato un `$10` con byte 0x97 (1, 2, 3, 5, 8 accesi); 🔎 la macchina di KM rispondeva 0x95 (2 **spento**: però i loro CC funzionavano, vedi §13).
- Quindi Bobina deve **leggere** com'è messa la macchina ($0F, §9) o farla controllare a Ele.

### Come la vuole Bobina (proposta, da fare con Ele una volta)

tasto 1 **spento** · 2 acceso · 3 acceso · 4 acceso solo se Bobina dà il tempo col cavo · 5 acceso solo col cavo · 6 spento · 7 **spento** (con l'eco Bobina si sente da sola) · 8 acceso.

## 3. Tabella dei CC in entrata (completa)

📄 G 21.6, la tabella «incoming midi». «any» = qualunque canale.

### 3a. Parametri del suono (canale = traccia)

| CC | CC relativo | nome TE | valori | batteria | synth (bass, lead, chord) | arp |
|---|---|---|---|---|---|---|
| 1 | 32 | parameter 1 | 0-127 · rel 1/127 | pitch | parametro 1 del motore | parametro 1 |
| 2 | 33 | parameter 2 | | reverse | parametro 2 del motore | parametro 2 |
| 3 | 34 | filter cutoff | | filtro | filtro | filtro |
| 4 | 35 | filter resonance | | risonanza | risonanza | risonanza |
| 5 | 36 | envelope attack | | attacco | attacco | attacco |
| 6 | 37 | envelope decay | | decay | decay | decay |
| 7 | 38 | envelope sustain | | sustain | sustain | sustain |
| 8 | 39 | envelope release | | release | release | release |
| 9 | 40 | lfo depth | | lfo | lfo | **velocità arp** |
| 10 | 41 | lfo speed | | | | **pattern arp** |
| 11 | 42 | lfo target | | | | **stile arp** |
| 12 | 43 | lfo shape | | | | **estensione arp** |
| 13 | 44 | fx 1 send | | mandata FX 1 | | |
| 14 | 45 | fx 2 send | | mandata FX 2 | | |
| 15 | 46 | pan | | pan | | |
| 16 | 47 | volume | | volume | | |
| 17 | 48 | portamento | | — | portamento | |
| 18 | 49 | note style | | retrig/mono/gate/loop | poly/mono/legato | |

Fonti: nomi e valori 📄 G 21.6; cosa c'è sulle manopole 📄 G-parameter-pages; arp al posto dell'lfo 🔎 OD ($0E «LFO Depth / Arp Speed»).

Sulle tracce di controllo il nome TE dice poco. 📄 Le manopole sono queste (G-parameter-pages); quale CC le muove è 🔎 dedotto dal nome del parametro nella tabella TE (filtro = CC 3, lfo = CC 9-12, pan = CC 15…):

| traccia | CC 1 | CC 2 | CC 3 | CC 4 | CC 9-12 | CC 13-16 |
|---|---|---|---|---|---|---|
| fx1, fx2 | param 1 | param 2 | filtro | risonanza | lfo (pagina 2) | — |
| tape | velocità grossa | velocità fine | filtro | risonanza | — | fx1, fx2, pan, livello |
| master | chorus | drive | filtro (HP/LP, neutro a metà) | risonanza | — | — |
| lights 🔎 KM | colore | colore alternativo | velocità del pattern | intensità | — | knob 5-8 per il DMX |
| motion ❓ | controllo 1 | 2 | 3 | 4 | 9-12 | 13-16 |

📄 G-tape: «sending midi cc simultaneously to parameters 1 and 2 can result in some cool scratching effects» → CC 1 e 2 sul canale 11.

Cosa si sa dei valori:
- 📄 Relativi (32-49 e 51): solo **1 = un passo su, 127 = un passo giù**.
- 🔎 KM: dentro l'OP-Z i parametri sono a 8 bit (0-255); STU manda il valore diviso 2. ❓ Quindi il CC li moltiplica per 2.
- 🔎 STU, KM: un CC cambia il suono **del pattern attivo** (in 2 ms, KM). ❓ Se resta salvato nel pattern con l'autosave.
- 📄 LFO (G 4.4): profondità a metà = spento, a destra aggiunge, a sinistra toglie; velocità a sinistra del centro va a tempo (1/64, 1/32, 1/16, 1/8, 1/4, 1/2, 1/1, 2/1), a destra è libera; 8 destinazioni (param 1, param 2, filtro, risonanza, attacco, pitch, pan, volume); 12 forme (6 libere: sine, triangle, square, saw, random, gyro; 6 che ripartono a ogni nota). ❓ Dove cadono le soglie fra 0 e 127.
- 📄 Arp: velocità in 8 scatti, tutta a sinistra = arpeggio spento (fw 1.2.12); pattern MANUAL UP DOWN UP/DOWN DOWN/UP RANDOM; 6 stili. ❓ soglie.
- 📄 Stili di nota: batteria 4, synth 3, master 2 (latch / free). ❓ soglie del CC 18.

### 3b. Sistema

| CC | nome | canale | valori | cosa si sa |
|---|---|---|---|---|
| 50 | track gain | 1-16 | 0-127 | 🔎 funziona su tutte le 16 tracce, anche fx, tape, i/o (jtswearingen, F-24575, 3/8/2023). ❓ quale valore è «normale» |
| 51 | track gain relativo | 1-16 | 1 / 127 | |
| 52 | reset track gains | any | any | rimette tutti i guadagni |
| 53 | mute | 1-16 | 0-1 | 📄 FW 1.2.20: anche **127 = muto**. Muta le note e il MIDI in uscita |
| 54 | audio mute | 1-16 | 0-1 | 📄 G-mixer: muta solo l'audio, la traccia continua a mandare MIDI e a suonare dentro fx e tape |
| 55 | mute group | any | 0-9 | 📄 10 gruppi di muti per progetto, quello attivo è salvato **per pattern**. ❓ 0 = gruppo 1? |
| 56 | tempo | any | 0-127 | 📄 la macchina va da 40 a 200 bpm. 🔎 il valore **è** il bpm: sotto 40 resta 40, sopra 127 non si va (Gruffalo 28/4/2021, FunkyJunky 17/5/2021, F-19884). Nessun firmware dopo l'ha corretto 📄 FW |
| 57 | swing | any | 0-127 | 📄 50 % = niente swing; zona morta al centro (fw 1.2.31). ❓ come si dividono i valori |
| 103 | select pattern | **1-10** | 0-15 | 📄. 🔎 canale = **progetto** (STU; FunkyJunky 2021: «outgoing channel matches project number (1-10)») ❓ se cambia anche progetto |
| 103 | next pattern | any | 16 | 📄 dal fw 1.2.8 |
| 103 | previous pattern | any | 17 | 📄 |

📄 G-project 7.3: «if the sequencer is playing, the pattern switches instantly, maintaining the current step position for all tracks». 📄 FW 1.2.14: anche il program change cambia subito (prima aspettava il passo dopo).

### 3c. Traccia

| CC | nome | canale | valori | cosa si sa |
|---|---|---|---|---|
| 60 | step count | 1-16 | 1-16 | 📄 quanti passi usa la traccia (ogni traccia il suo: poliritmi). 🔎 jtswearingen ci ha messo un LFO sul canale 1 = fill di cassa |
| 61 | step length | 1-16 | 1-16 | 📄 moltiplicatore: sulla macchina tasti 1-8, **9 = 16 volte più lunga**, **0 = avanza solo con un trig** (oplab o step component jump). 🔎 jtswearingen: **valore 10 = traccia ferma** (in pausa). ❓ cosa fanno 1-9 e 11-16 |
| 62 | quantize | 1-16 | 0-127 | 📄 (sulla macchina 0-100 %). midi.guide scrive 1-16 |
| 63 | note length | 1-16 | 0-127 | 📄 da 1/64 a una battuta, tutto a destra = drone (G-track). midi.guide scrive 1-16 |

### 3d. Interfaccia

| CC | nome | colonna «track/channel» | valori |
|---|---|---|---|
| 102 | active track | **0** | 0-15 |
| 102 | parameter page | **1** | 0-3 |

📄 G 21.6, così com'è. Il canale 0 nel MIDI non esiste: la lettura più probabile è **canale 1 = scegli la traccia attiva, canale 2 = scegli la pagina**. A favore:
- 📄 FW 1.2.12: «disregard 'channel_one_to_active' setting when processing incoming UI group CC messages» (cioè il CC 102 sul canale 1 non viene dirottato);
- 🔎 jtswearingen (F-24575, 3/8/2023): CC 102 valore 0 **canale 2** con l'arp attivo ha aperto la pagina LFO, che l'arp non ha, e le manopole sono impazzite.
❓ Tutto da misurare. Non mandare il CC 102 pagina sull'arp.

### 3e. Gli altri messaggi

| messaggio | canale | valori | cosa si sa |
|---|---|---|---|
| start · stop · continue | — | — | 📄 ricevuti. 🔎 KM: Start col cavo fa partire il pattern subito (fw 1.2.45). 📄 FW 1.1.23: passano alle altre porte; continue migliorato per l'OP-1 |
| program change | 1, 2 | 0-127 | 📄 modo normale (vedi 3f) |
| program change | 1-10 | 0-15 | 📄 modo alt |
| clock | — | — | 📄 se `timing_clock_in` è acceso, l'OP-Z passa da solo in sync esterno |
| pitch bend | 1-16 | | 📄 sulla traccia; sul tape fa il tape stop (G-interface) |
| note | 1-16 | | vedi §1 e §4 |
| song position pointer | — | | 📄 «not used»: non si può far partire a metà |
| active sensing | — | | 📄 «not used» |
| tutti gli altri CC (0, 19-31, 58-59, 64-101, 104-127) | | | ❓ non in tabella: probabilmente ignorati |

### 3f. Program change, nel dettaglio

📄 G 21.3 e 21.4 (cambia pattern solo con il tasto 8 acceso):
- **Normale**: «pattern 1–160 is activated with bank 1 / program 1–128 and bank 2 / program 1–32». 160 = 10 progetti × 16 pattern. La tabella mette questi program change sui canali **1 e 2**.
- **Alt**: «bank 1–16 / program 1–16». La tabella dice canali **1-10**, valori 0-15.

Due letture possibili di «bank», tutte e due ❓:
1. bank = **canale MIDI**: numero = (progetto−1)×16 + (pattern−1); fino a 127 sul canale 1, oltre sul canale 2 meno 128. In alt: canale = progetto, programma = pattern.
2. bank = **Bank Select (CC 0)** prima del program change. 🔎 STU non lo sa: prova 5 combinazioni e chiede all'utente quale ha funzionato.

🔎 STU evita il canale 1 per il program change per via del tasto 1. 📄 Storia: fw 1.1.12 sistemato l'alt invertito in **uscita**; 1.2.8 sistemato il program change in entrata «rotto»; 1.2.14 cambio immediato.

## 4. Suonare l'OP-Z da Bobina: le note

- 📄 Batteria: ogni kit ha **24 suoni sulla tastiera**. ❓ Quali note MIDI: 🔎 KM (luci) e STU indicano che l'ottava di serie della tastiera va da **53 a 76** (fa-mi); 📄 FW 1.1.23 «full octave range to drum tracks». Da misurare.
- 📄 Synth: nota = altezza, con velocity (anche sull'arp dal fw 1.1.23). Polifonia nella tabella del §1.
- 📄 Perform (canale 13), i tasti degli effetti punch-in (G-punch-in): fa duck · fa# filter sweep · sol loop 1 · sol# stereo · la loop 2 · si♭ pitch · si follow/echo · do ramp up/fill 1 · do# short · re ramp down/fill 2 · re# long (la guida scrive «C#» due volte: il secondo è quasi certamente re#) · mi random. L'ottava bassa agisce sulla traccia, quella alta sul gruppo. ❓ Via MIDI: quale ottava, e se agiscono «su tutte le tracce» come da tastiera.
- 🔎 Lights (canale 15), KM dalle tabelle dell'app: pattern 1-10 = note **54 56 58 61 63 66 68 70 73 75**; animazioni 1-14 = note **53 55 57 59 60 62 64 65 67 69 71 72 74 76** (la 14 accende anche la macchina del fumo). Senza interfaccia DMX non si vede niente.
- 📄 Motion (canale 16) nell'app: photomatic = i tasti mostrano le immagini 1-24 del rullino; motion = neri cambiano inquadratura, bianchi fanno effetti finché tenuti.
- 📄 Registrare nel sequencer dell'OP-Z vuole **REC tenuto** sulla macchina (o REC+PLAY = record lock). Non c'è un messaggio MIDI per il rec. ❓ Ele mette il record lock e Bobina suona: le note vengono scritte? E uno Stop MIDI toglie il lock come il tasto stop?

## 5. Cosa manda l'OP-Z

| cosa | quando | fonte |
|---|---|---|
| note (on/off con velocity) | sequencer e tastiera, sul canale della traccia | 📄 G 21.1, 🔎 NBW |
| CC delle manopole | giri una manopola: CC del parametro sul canale della traccia. Di serie pagina 1 = CC 1-4, pagina 2 = 5-8, pagina 3 = 9-12, pagina 4 = 13-16 | 📄 G 21.1; 🔎 DISK, OD, NBW |
| CC anche da traccia mutata | sì, dal fw 1.2.38 | 📄 FW |
| pitch bend | sul canale della traccia (giusto anche se rimappato dal fw 1.2.38) | 📄 FW, 🔎 NBW |
| clock 24 per quarto | se `timing_clock_out`, anche con `outgoing_midi` spento (fw 1.2.5). **Non sul bluetooth** | 📄 G, FW; 🔎 TE via F-15179 |
| start / stop | 🔎 NBW li decodifica. ❓ se partono premendo ▶ ■ o solo col clock out | 🔎 NBW |
| program change | quando cambia pattern, se il tasto 8 è acceso. 🔎 KM li ha visti (1, 2, 3, 4) a ogni cambio della catena | 📄 G «in/out», 🔎 KM. ❓ su che canale |
| CC 123 valore 0 su tutti i 16 canali | premendo stop mentre suona | 🔎 NBW, issue #1 |
| niente | tasti traccia, play, stop, ottava, project/mixer/tempo/screen non mandano note né CC | 🔎 NBW |
| tutto quello che riceve | solo con `midi_echo` acceso | 📄 G |
| traccia mutata dal mixer | niente MIDI. Con «audio mute» (SHIFT nel mixer) il MIDI esce lo stesso | 📄 G-mixer |

🔎 F-7733 (flom, 6/2020): i CC partono da 0 invece che dal valore vero prima dei punch-in. Vago, da verificare.

## 6. Clock, start/stop, tempo

- 📄 Clock in entrata = sync esterno automatico (se il tasto 4 è acceso); si vede tenendo TEMPO (G 21.2 dice «four green leds», G-tempo dice «track leds 1-16 blinking green, in groups of four»).
- 📄 FW 1.2.5: non perde il sync cambiando progetto con un cambio pattern.
- 📄 Tempo sulla macchina: 40-200 bpm, con le cifre (TEMPO + 1 2 0 = 120), tap, nudge con −/+, lock con SHIFT.
- 🔎 KM: il tempo vero sta nel blocco globale come numero intero 40-200, scrivibile via SysEx $0C (§9): è l'unico modo per un tempo esatto **senza** clock. Rischio di scrittura.
- 🔎 TE al supporto (mail citata in F-15179, thread 2019-2023): «the reason for us currently not sending midi clock over BLE is that we found it to lower the maximum distance … before the connection started to become unstable».
- 🔎 Clock **in entrata** sul bluetooth: LP e F-15179 (2019) parlano di OP-Z che «balbetta» o si blocca da slave via bluetooth; col cavo tutto liscio. 📄 FW 1.2.45 (2022): «reduced ble midi jitter». ❓ Da rimisurare oggi.
- Per Bobina: col bluetooth il modo sicuro è **start + CC 56** (stesso bpm, ma i due orologi poi scivolano) oppure clock leggero da provare. Col cavo, clock vero.

## 7. Bluetooth sull'iPhone

- 📄 G-app: «push the pair button on the backside of your OP-Z»; nell'app «tap the scan button». 🔎 soundtech.co.uk: tasto sotto la macchina, tenerlo finché la luce lampeggia blu. ❓ Se l'OP-Z si fa trovare senza premere il tasto (problema per Giampiero: serve Ele ogni volta?).
- 🔎 Sul Mac si collega da Configurazione MIDI Audio → bluetooth, e poi l'app OP-Z si aggancia da sola (soundtech). Quindi l'app usa il collegamento MIDI del sistema, non uno suo.
- 🔎 Sull'iPhone, una volta collegato, l'OP-Z si vede in AUM e midimittr insieme all'app OP-Z (dhunterrr, F-23305, 11/11/2022). Ma alcune app smettono di leggere il MIDI quando vanno in secondo piano (RoutineDiscount, stesso thread).
- 🔎 «The OP-Z can connect only to one device via BT at a time. But you can send/receive MIDI via BT and USB in parallel» (RoutineDiscount, F-23305, 11/11/2022).
- 🔎 L'OP-Z non si collega da solo a tastiere bluetooth: serve un telefono in mezzo (F-7863, 2018).
- 🔎 TEK cerca l'OP-Z per il servizio bluetooth MIDI standard (`03B80E5A…`) e per un servizio TE (`10a6e10a…`); nei dati del costruttore il tipo 0x02 = OP-Z. Un solo commit, non verificato.
- ❓ **CABTMIDICentralViewController** (quello che Bobina usa per TP-7 e TX-6) dovrebbe funzionare: l'OP-Z è un normale dispositivo bluetooth MIDI. Da provare, insieme al nome che compare in CoreMIDI.
- ❓ Ritardo e jitter sul bluetooth: nessun numero pubblico. 🔎 KM col cavo: nota rimandata indietro in 1-2 ms.
- Per non intasare il bluetooth: ogni `MIDISend` è un pacchetto. Messaggi che partono insieme (accordo, scena di muti, 18 CC di un suono) vanno **in un solo `MIDISend`** con più messaggi nella lista. ❓ Quanti ne entrano in un pacchetto dell'OP-Z.

## 8. Col cavo USB-C

- 📄 G-usb: MIDI USB; con cavo C-C «use a high quality cable». 📄 FW 1.2.45: «improved usb-c to usb-c connection logic»; 1.2.26: sistemato iOS che rifiutava l'OP-Z dopo un computer.
- 📄 FW 1.2.5: l'OP-Z è anche una scheda audio a 2 canali. ❓ Se l'iPhone la prende come uscita audio (come TP-7 e TX-6).
- 📄 G-hardware: **SCREEN + il tasto bianco più a destra** spegne la ricarica via USB (led gialli): così l'OP-Z non svuota l'iPhone e sparisce il ronzio.
- 📄 L'OP-Z può essere host USB (100 mA massimo), ma con l'iPhone è l'iPhone a fare da host.
- ❓ L'iPhone ha una sola presa: OP-Z e TX-6 entrambi col cavo vogliono un hub USB-C alimentato. Da provare.
- Col cavo vanno: clock in e out, SysEx veloce, latenza minima. È la strada consigliata per l'OP-Z.

## 9. Il SysEx della community

### Com'è fatto (🔎 OD, KM)

`F0 00 20 76 01 <id> <dati> F7`: `00 20 76` = teenage engineering, `01` = versione del protocollo. I dati a 8 bit sono impacchettati a 7 bit (un byte coi bit alti ogni 7), i blocchi grossi sono compressi zlib. Viaggia sia col cavo sia col bluetooth (KM). L'app ufficiale lo chiama StateSync.

Per ricevere gli aggiornamenti bisogna mandare un **battito** circa una volta al secondo: `F0 00 20 76 01 00 01 4E 2E 06 F7` (🔎 LIB, KM, fw 1.2.5+). Al primo battito l'OP-Z manda un'ondata di stato: `$11`, `$04`, `$07`, `$1A`, `$03`, `$14`, 16 × `$0E`, `$1B`, `$06`, `$12`, `$13`, `$09` (pattern), `$0C` (globale). Sul bluetooth è pesante.

### Da leggere: abbastanza sicuro

| richiesta | risposta | cosa ci si legge | fonte |
|---|---|---|---|
| `F0 7E 7F 06 01 F7` (identità, standard) | numero di serie, firmware | che macchina è, che firmware | 🔎 OD, KM. ⚠️ 📄 FW 1.1.12 sistemava un crash con questa richiesta all'accensione |
| battito `$00` | `$01` + l'ondata sopra | vedi le righe sotto | 🔎 KM |
| (ondata) `$04` | 4 byte | **batteria 0-100 %**, volume generale, microfono, ingresso | 🔎 KM, provato |
| (ondata) `$03` | 2 byte | traccia selezionata e ottava | 🔎 OD, KM |
| (ondata) `$06` | 4 byte | tasti tenuti, pagina, **sta suonando sì/no** | 🔎 OD |
| (ondata) `$07` | 20 byte | **progetto, pattern attivo**, catena attiva e a che punto è | 🔎 KM, provato |
| (ondata) `$12` | 18 byte | livello delle 16 tracce + **quali sono mute** | 🔎 KM |
| (ondata) `$0E` | 19 byte per traccia | i 18 parametri del suono (0-255) | 🔎 OD, KM |
| (ondata) `$0C` | 568 byte zlib | **tempo esatto**, swing, livelli di gruppo, le 15 catene salvate | 🔎 KM |
| `$0F` | `$10` | la configurazione MIDI intera (§2) | 🔎 KM, provato |
| `$08` | `$09` | tutti i 16 pattern del progetto (342 272 byte) | 🔎 KM. ⚠️ OD: sembra far ripartire le note tenute |

❓ Se il battito di Bobina litiga con l'app OP-Z aperta nello stesso momento (l'OP-Z registra un solo «interlocutore»).
⚠️ La batteria qui **si legge** (sul TX-6 no): utile per Giampiero.

### Scrive: non in Bobina v1

| messaggio | cosa scrive | stato |
|---|---|---|
| `$09` + `$0A` | i pattern (note, accordi, velocity, micro timing, lock, step component, suoni) | 🔎 KM e LED: provato, con conferma pacchetto per pacchetto (`$0B`) e rifiuto (`$08 FF FF FF FF`). Scrive sempre dal pattern 1 fino a N |
| `$0C` | tempo esatto, catene, livelli di gruppo, swing, metronomo | 🔎 KM: provato. 46 byte sconosciuti da ricopiare tali e quali |
| `$0E` | i 18 parametri di una traccia, subito, a 8 bit | 🔎 KM: provato |
| `$10` | la configurazione MIDI | 🔎 KM: provato e rimesso a posto. STU lo vieta |
| `$07` | richiama una catena o un pattern | 🔎 KM: «provato». 🔎 **STU: il 18/9/2026 ha fatto piantare un OP-Z vero** (montato come disco, audio muto). Vietato |
| `$03`, `$06`, `$13` | traccia/ottava, tasti tenuti (restano «premuti»), autosave | 🔎 KM: rischioso. STU lo vieta |
| `$51`-`$55`, `$35`, `$53` | trasferimento file, campioni, plug | 🔎 KM: provato, solo con backup |

### Mai

`$04`, `$14` (scrive memoria grezza), `$19`, `$61`, `$62` (comandi di testo: `debug-crash` manda l'OP-Z in modalità aggiornamento 🔎 OD), `$66` (tunnel seriale: spegnimento, modalità fabbrica, DFU 🔎 KM). 🔎 TEK ha una funzione `setPowerMode(.powerOff)` per l'OP-Z: non usarla.

Le regole di KM per chi scrive: backup prima, un'operazione per volta, riletta vera dopo, rimettere a posto se non torna.

## 10. Programmi che esistono già (idee da rubare)

| programma | cosa fa | idea per Bobina |
|---|---|---|
| [OP-Z Studio](https://agolg.github.io/opz-studio/) (STU, web, 9/2026) | legge il progetto, sequencer nel browser, scrive i pattern via SysEx con backup e riletta | lista dei messaggi vietati; il cambio pattern «da confermare guardando l'OP-Z la prima volta» |
| [opz-controller](https://github.com/FrankSlav15/opz-controller) (web, 29/9/2026) | pannello CC; un «patch code» JSON (`{"track":"lead","params":{"filter":90}}`) applicato con una **rampa in ms** | suoni salvati come testo, richiamati con una rampa |
| [OPZ.js](https://github.com/nbw/opz) (NBW) | decodifica quello che esce dall'OP-Z; demo: Tetris, forme, sketch suonati dall'OP-Z | lo specchio: l'OP-Z che comanda Bobina (come il ponte del TX-6) |
| [finger](https://github.com/sampi/finger) (web, 2019) | il sequencer «finger» dell'OP-1 rifatto per l'OP-Z: metà tastiera pattern di batteria, metà synth | pattern pronti a un tocco |
| [M-Vave SMK-25](https://github.com/tsoop-com/op-z-m-vave-smk-25) | mappe per una tastierina bluetooth: 8 preset = 8 tracce, manopole = 16 parametri, pad = effetti di perform e tape | i pad degli effetti |
| OP-Z CTRL (Max for Live, pauk) | pannello per traccia, 44 preset, **casuale per sezioni** (suono, ADSR, LFO, note, master) | il casuale a sezioni |
| MIDI Designer layout (coolquentin), cheat codes 2 (norns), connect-opz (norns) | superfici di controllo | — |
| [TEKit](https://github.com/ericlewis/TEKit) (Swift) | bluetooth verso OP-Z/TP-7/OB-4 col protocollo seriale TE | solo come riferimento, non verificato |
| [field-remote](https://github.com/jwamin/field-remote) (SwiftUI) | telecomando bluetooth TX-6/TP-7 con Comandi rapidi | già noto (TX6-RICERCA) |

## 11. Idee per chi non usa le mani

Carico sul bluetooth: **basso** = un messaggio ogni tanto · **medio** = qualche messaggio a ogni battito · **alto** = flusso continuo (da evitare, o solo col cavo).

| idea | come | carico | stato |
|---|---|---|---|
| **La canzone a pattern** | Bobina tiene una scaletta (pattern × battute) e manda CC 103 all'inizio di ogni blocco; 16/17 = avanti/indietro. Anche fra progetti (canale = progetto) e senza il limite di 32 della catena | basso | ❓ anticipo per il ritardo bluetooth: il cambio è immediato e tiene il passo, un ritardo di pochi ms non si sente |
| **Scene di muti** | un solo CC 55 (gruppo 0-9) invece di 16 CC 53 | basso | ❓ chi prepara i gruppi: Ele dal mixer, o Bobina con CC 53 mentre il gruppo è attivo? |
| **Il cancello** | CC 54 (muto solo audio) on/off a tempo su una traccia | medio | 📄 il MIDI della traccia continua |
| **Macro con l'LFO dell'OP-Z** | invece di mandare un flusso di CC, Bobina regola una volta CC 9-12 (profondità, velocità a tempo, destinazione, forma) e l'OP-Z modula da solo | basso | ❓ soglie dei valori |
| **Sweep a gradini** | un CC ogni sedicesimo o ogni ottavo, non continuo | medio | a 120 bpm un sedicesimo = 8 messaggi al secondo |
| **Tasti + e −** | CC relativi 32-49 (1 = su, 127 = giù): un tocco = un passo | basso | 📄 |
| **Poliritmi** | CC 60 per traccia (kick 16, perc 12, arp 7…), CC 61 per allungare (basso ×2) | basso | 📄 |
| **Fill di cassa** | CC 60 sul canale 1 cambiato ogni battuta (come l'LFO di jtswearingen, ma a gradini) | basso | 🔎 |
| **Pausa traccia** | CC 61 = 10 ferma la traccia, il valore di prima la fa ripartire | basso | 🔎 jtswearingen, ❓ |
| **Rampa di tempo** | CC 56 un passo per battito (40-127 bpm). Col cavo: clock di Bobina, qualunque tempo | basso / alto (clock: 48 messaggi al secondo a 120) | 🔎 |
| **Swing** | CC 57 | basso | ❓ valori |
| **Casuale e umanizza** | a inizio battuta valori a caso sui CC 1-18 scelti, sparsi lungo il battito, tutto in pochi `MIDISend` | basso-medio | il «randomize preset» (TRACK+REC) via MIDI non c'è |
| **Accordi e melodie a tasti grandi** | note sul canale 8 (accordi), 6 (lead), 5 (basso); un accordo in un solo `MIDISend` | basso | 📄 |
| **Effetti punch-in a un tocco** | note sul canale 13, tenute finché il tasto è «tieni» | basso | ❓ quale ottava |
| **Cambi di tonalità** | note sul canale 12 (master) | basso | ❓ |
| **Trucchi col nastro** | canale 11: note = punto di partenza e lunghezza del loop (beat repeat); pitch bend = tape stop; CC 1 + 2 = scratch | basso (note) / alto (scratch, tape stop) | 📄; per il tape stop 8-10 gradini bastano |
| **Pompa** | CC 50 (guadagno) giù e su a ogni battito sulle tracce scelte, come la pompa del TX-6 | medio | ❓ valore «normale» del CC 50 |
| **Luci e immagini** | canale 15 = pattern e animazioni di luce (serve DMX); canale 16 = photomatic/motion nell'app OP-Z su un **altro** dispositivo (iPad + HDMI) | basso | 📄 |
| **Traccia attiva per Ele** | CC 102 canale 1 = sceglie su che traccia lavorano tastiera e manopole dell'OP-Z | basso | ❓; mai la pagina sull'arp |
| **Specchio dell'OP-Z** | col cavo: batteria, pattern, muti, tempo letti col SysEx e mostrati in grande | alto all'inizio | 🔎 KM; solo lettura |
| **Ponte** | le manopole dell'OP-Z (CC 1-16 in uscita) comandano le sezioni TP-7 / TX-6 / PO, come il ponte del TX-6 | basso | 📄 |

### Stare a tempo con TX-6, PO e TP-7

1. **OP-Z col cavo, gli altri in bluetooth**: Bobina manda il clock all'OP-Z (tasto 4 acceso). Il TX-6 ha la sorgente clock BLE (TX6-RICERCA, con un dubbio del supporto TE). Il TP-7 in bluetooth non manda clock (PROVE.md). È la strada più solida.
2. **Tutto in bluetooth**: all'OP-Z niente clock (o clock da provare), solo start + CC 56 con lo stesso bpm; ogni tanto Bobina riallinea con stop + start a inizio frase. Si sentirà scivolare? ❓
3. **OP-Z che comanda, col cavo**: l'OP-Z manda il clock (tasto 5) e Bobina lo segue e lo gira agli altri.
4. Con il modulo oplab (fuori produzione) l'OP-Z ha un'uscita sync «pocket operator» 📄 G-oplab: non ci riguarda.

## 12. L'app ufficiale OP-Z

- 📄 G-app: schermo senza fili dell'OP-Z (parametri, touch pad per regolarli), mixer, configurator (quali plug in quali slot), **midi setup**, photomatic (24 immagini per rullino, 10 rullini, suonate dalla traccia 16), motion (grafica 2D/3D fatta con videolab/Unity), guida, uscita video HDMI, trasferimento file.
- 📄 APP: versione **1.3.1 del 2/10/2023** (ultima), iOS 12 o successivo, **solo inglese**, 3,6 stelle su 8 voti in Italia, «lo sviluppatore non ha ancora indicato quali funzioni di accessibilità supporta».
- 🔎 OD: è un programma **Unity**. ❓ Dedotto: i tasti sono disegnati, non sono tasti veri di iOS → Controllo Vocale non vede i nomi, si può usare solo con la griglia. Da provare.
- 🔎 F-23305: con alcune app solo quella in primo piano elabora il MIDI; photomatic e motion devono stare in primo piano. Quindi Bobina e l'app OP-Z sullo stesso iPhone si pestano i piedi: l'app va su un altro dispositivo.
- Uso utile: Ele può usarla **una volta** dalla pagina midi setup per sistemare gli interruttori senza ricordare i tasti.

## 13. Dove le fonti non sono d'accordo

1. **Pattern in modo normale**: la tabella sulla macchina dice «pattern 1–16», il `midi.json` «pattern 1–160». Giusto 160 (10 × 16).
2. **Alt program change**: il testo dice «bank 1–16», la tabella «canale 1–10».
3. **«Bank»** = canale MIDI (la tabella mette i program change sui canali 1 e 2) oppure Bank Select CC 0 (STU prova tutte e due). ❓
4. **CC 62 e 63**: guida 0-127, midi.guide 1-16.
5. **`parameter_cc_out`**: guida 0-255, file veri 1-16, KM 0-127.
6. **`track_channels`**: guida 1-16, file veri 0-15.
7. **Il canale scelto vale anche in entrata?** Il `midi.json` dice «outgoing channel per track»; defn (2019) dice che l'ingresso resta sempre traccia N = canale N. Dopo, il fw 1.2.31 ha aggiunto la scorciatoia «set midi channel». ❓
8. **CC 102**: colonna canale «0» e «1», che nel MIDI non esistono.
9. **`$07`**: «provato sulla macchina» per KM, «ha fatto piantare l'OP-Z» per STU (18/9/2026).
10. **Il byte delle impostazioni di KM** (0x95) dice MIDI in entrata spento, ma i loro CC funzionavano: o la mappa dei bit va ricontrollata, o la macchina era cambiata fra le due prove.
11. **Clock sul bluetooth**: TE dice che non lo manda; LP (2019) racconta di un OP-Z «master clock» via app di sync sul bluetooth. Probabilmente parlava di Link, non di clock.
12. **CC 56**: guida 0-127 per un tempo 40-200; la community misura valore = bpm, tetto 127.
13. **Sync esterno**: G 21.2 «four green leds», G-tempo «leds 1-16 blinking green in groups of four».
14. FunkyJunky (F-20117, 2021) scrive «FC (play), FA (stop)»: è al contrario, nel MIDI FA = start e FC = stop (come in NBW).

## 14. Da misurare noi

1. Come si collega: CABTMIDICentralViewController senza l'app OP-Z? Serve premere il tasto di pairing ogni volta? Che nome compare in CoreMIDI, col cavo e col bluetooth?
2. Come escono di fabbrica gli 8 interruttori (leggere col `$0F`, o guardare i led con TEMPO + SCREEN).
3. CC 102: canale 1 = traccia e canale 2 = pagina?
4. CC 103: il canale cambia anche il progetto? Che succede su un canale da 11 a 16?
5. Program change: quale delle due letture (canale o Bank Select), in modo normale e alt. E su che canale l'OP-Z manda i suoi.
6. CC 56 (valore = bpm, sotto 40?) e CC 57 (dove cade il 50 %).
7. CC 61: che moltiplicatore danno 1-16; il 10 ferma davvero la traccia?
8. CC 53 / 54: assoluti o a commutazione? 127 vale anche per il 54? CC 55: 0 = gruppo 1?
9. Le soglie: CC 18 (stile nota), CC 11 e 12 (destinazione e forma LFO), CC 9-12 sull'arp.
10. Le note della batteria (quale nota = quale dei 24 suoni) e l'ottava dei synth.
11. Le note sulle tracce di controllo: tape (11), master (12), perform (13), lights (15).
12. Clock in entrata sul bluetooth: stabile con il firmware 1.2.45? E start/stop senza il tasto 4?
13. Cosa manda l'OP-Z premendo ▶ e ■ (start/stop? CC 123?).
14. Ritardo bluetooth: nota mandata e rimandata indietro con l'eco acceso.
15. Record lock messo da Ele + note di Bobina: vengono scritte nel pattern?
16. Battito SysEx di Bobina con l'app OP-Z aperta: chi vince? E la batteria `$04` arriva anche sul bluetooth?
17. Hub USB-C con OP-Z e TX-6 sull'iPhone.
18. Un CC resta salvato nel pattern dopo lo spegnimento?
