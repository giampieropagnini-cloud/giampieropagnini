# EP-133 K.O. II — appunti di ricerca (2/10/2026)

Per una futura sezione K.O. II di Bobina. Ogni riga dice da dove viene:

- 📄 **documentato**: guida ufficiale teenage engineering, note dei firmware, pagina dei download
- 🔎 **community**: ricavato da altri (reverse engineering, codice su GitHub, forum, siti terzi). Tra parentesi chi e quando
- ❓ **da misurare**: nessuno lo dice chiaro, le fonti litigano, oppure è una mia deduzione

Firmware: l'ultimo è **OS 2.5.1 del 3/7/2026** 📄[DL] (il grosso è arrivato con la 2.5 del 24/6/2026). La guida in linea è scritta per la «ver 2.5» 📄[G]. Prima di tutto: **aggiornare la macchina alla 2.5.1**, perché metà delle cose MIDI utili (CC 12/13, CC 64, audio USB, clock bluetooth più stabile) esistono solo da lì.

| sigla | fonte |
|---|---|
| G | [guida EP-133](https://teenage.engineering/guides/ep-133). Capitoli col nome: G-system (cap. 14: impostazioni, 14.1 tabella MIDI, 14.2 note, 14.5 CC), G-howto (cap. 12), G-modes (cap. 8), G-hw (cap. 1), G-spec (cap. 16), G-fx (cap. 11), G-play (cap. 9), G-workflow (cap. 6), G-power (cap. 2) |
| NEW | [what's new](https://teenage.engineering/guides/ep-133/whats-new): note di OS 2.5, 2.0.5, 2.0.2, 2.0.1, 2.0 |
| DL | [pagina dei download](https://teenage.engineering/downloads/ep-133): elenco dei firmware con le date, dalla 1.1.0 (22/11/2023) alla 2.5.1 |
| MG | [midi.guide](https://midi.guide/d/teenage-engineering/ep-133-ko-ii/) (aggiornato 10/7/2026, contributore slaaven) |
| TM | [teenagemanual.com/ep-133/midi](https://www.teenagemanual.com/ep-133/midi) (sito terzo, senza data né autore) |
| GR | [manuale di Gabriel Roth](https://gabrielroth.com/ko2/) (sito terzo, scritto su OS 2.0.5, inizio 2026) |
| EL | [Elektronauts, post #5870 di Elijah](https://www.elektronauts.com/t/teenage-engineering-ep-133-k-o-ii/203660/5870) (13/4/2025) |
| KM | [kmorrill/ep-series-sysex](https://github.com/kmorrill/ep-series-sysex) (MIT, provato su EP-133 ed EP-40 con OS 2.5.1) e il suo [thread su op-forums](https://op-forums.com/t/opening-up-the-ep-series-for-third-party-development/31759) (11/7/2026). È lo stesso autore di `op-z-sysex` citato in OPZ-RICERCA |
| ZB | [ZacharySBrown/ep133-ppak, PROTOCOL.md](https://github.com/ZacharySBrown/ep133-ppak/blob/main/PROTOCOL.md) (25/4/2026, provato su OS 2.0.5) |
| UNI | [seajaysec/ep-unity](https://github.com/seajaysec/ep-unity) (riscrive il firmware, settembre 2026) |
| D2D | [phones24/ep133-export-to-daw](https://github.com/phones24/ep133-export-to-daw) (AGPL, aggiornato 18/5/2026) |
| OST | [garrettjwilke/ep_133_sample_tool](https://github.com/garrettjwilke/ep_133_sample_tool) (copia offline del Sample Tool, archiviato 1/8/2026; fork vivo: pbarilla) |
| WIDI | [CME WIDI K.O.II](https://www.cme-pro.com/widi-koii/) e la sua [guida d'avvio](https://www.cme-pro.com/widi-koii-start-guide/) (uscito a ottobre 2025, [Synth Anatomy](https://synthanatomy.com/2025/10/cme-widi-k-o-ii.html)) |
| RA | [reelaudio.app, «record EP-133 into your iPhone»](https://www.reelaudio.app/blog/record-ep-133-ko-ii-iphone) (Tug, 10/7/2026) |
| APL | [Apple, «Charge and connect with the USB-C connector»](https://support.apple.com/en-us/105099) |
| SOS | [recensione Sound On Sound](https://www.soundonsound.com/reviews/teenage-engineering-ep-133-ko-ii) (letta solo nel riassunto di una ricerca: «power automatically switches to USB when plugged in») |
| PK / BF | app [PunchKit](https://punchkit.dev/) ([op-forums 21/8/2026](https://op-forums.com/t/i-made-punchkit-an-ios-macos-companion-for-the-ko-ii-happy-to-hear-your-thoughts/31858)) · [Best Friend for K.O. II](https://epbf.app/) (luglio 2026) |

## In breve: le 8 cose che contano per Bobina

1. 📄 **Niente bluetooth dentro la macchina.** Le strade sono due: **cavo USB-C** (MIDI class compliant, con clock e trasporto 📄 G-hw) oppure l'adattatore **CME WIDI K.O.II** (🔎 WIDI, si infila nelle prese MIDI TRS e prende corrente da lì). TE stessa nelle note della 2.5 parla di «BLE MIDI clock» con meno jitter 📄 NEW.
2. 📄 **Non c'è un canale per gruppo.** Tutta la macchina ascolta e manda su **un canale di sistema** (di serie «all»: riceve tutti i canali, manda sull'1). I quattro gruppi si distinguono per **nota**: A = 36-47, B = 48-59, C = 60-71, D = 72-83 📄 G-system 14.2. Si può anche dare un canale tutto suo a un singolo pad (📄 G-modes 8.2.5).
3. 📄 I **CC sono pochissimi**: 1 vibrato, 12 e 13 = le due manopole degli effetti (X e Y), 64 sustain. **Il fader non si comanda via MIDI** (non c'è nella tabella) ❓.
4. 📄 **Scene, pattern, progetti e muti: via MIDI non si cambiano.** Il program change è stato **tolto** con la 2.0.2 (30/9/2025) 📄 NEW. L'unica porta socchiusa è lo **Song Position Pointer** in modalità song ❓.
5. 📄 **Clock in o out** (non tutti e due insieme): impostazione 101 = segue, 102 = comanda. Riceve start, stop, continue e song position 📄 G-system 14.1. Tempo da 40 a 399 bpm 📄 G-modes.
6. 📄 La presa **sync out** fa da **sync per i Pocket Operator** (8 = due impulsi per quarto, sul PO **SY2**) 📄 G-howto 12.5. Col K.O. II che segue il clock di Bobina via USB, il PO resta agganciato senza l'adattatore Hanz ❓.
7. ❓ L'iPhone **probabilmente non basta ad alimentarlo**: la macchina chiede 5 V e almeno 1 A 📄 G-power, l'iPhone dà al massimo 4,5 W agli accessori 📄 APL. RA consiglia le pile AAA. Da provare.
8. 🔎 Il **SysEx** della community è tutto **file**: campioni, pad, progetti, backup. Niente comandi dal vivo, niente lettura di tempo o scena attiva (🔎 ZB). Scritture sbagliate hanno **bloccato e fatto formattare** delle macchine vere (🔎 ZB, KM). In Bobina v1: solo MIDI standard.

## 1. I pad e le note

📄 G-system 14.2: la tabella è sempre la stessa per i quattro gruppi, cambia solo l'ottava. Il pad «.» è in alto a sinistra sulla macchina, come sul tastierino numerico.

| posto sul tastierino | nota gruppo A | B | C | D |
|---|---|---|---|---|
| `.` | 36 (C2) | 48 (C3) | 60 (C4) | 72 (C5) |
| `0` | 37 | 49 | 61 | 73 |
| `enter` | 38 | 50 | 62 | 74 |
| `1` | 39 | 51 | 63 | 75 |
| `2` | 40 | 52 | 64 | 76 |
| `3` | 41 | 53 | 65 | 77 |
| `4` | 42 | 54 | 66 | 78 |
| `5` | 43 | 55 | 67 | 79 |
| `6` | 44 | 56 | 68 | 80 |
| `7` | 45 | 57 | 69 | 81 |
| `8` | 46 | 58 | 70 | 82 |
| `9` | 47 | 59 | 71 | 83 |

- 📄 Le note suonano il pad **del progetto aperto**, qualunque gruppo sia selezionato sulla macchina: Bobina può suonare tutti e 48 i pad senza toccare niente.
- 📄 «Keys mode: 0-127»: se sulla macchina è acceso KEYS, le note diventano una tastiera cromatica del pad selezionato (G-system 14.1, 14.2). ❓ Cosa succede ai numeri 36-83 in quel momento: suonano il pad selezionato intonato, non più gli altri pad. Il modo KEYS lo accende solo la mano (o Ele).
- 🔎 MG: la velocity da 1 a 127 fa il **volume** del colpo. ❓ Anche quando la sensibilità dei pad (impostazione 300) è spenta.
- 📄 La nota spenta arriva come note on con velocity 0 (fw 1.1.1 📄 DL). Nella tabella 14.1 il «note off» è segnato con la x: ❓ per sicurezza Bobina manda note on a 0.
- 📄 Polifonia: fino a 16 voci mono o 12 stereo (OS 2.0 📄 NEW); campioni stirati, stereo o molto alti ne consumano di più.
- 📄 Le note mandate **vengono registrate** se la macchina è in registrazione (G-howto 12.8: «any notes you play on the keyboard will trigger the pads»; ❓ e se registra, finiscono nel pattern come le dita).
- 📄 G-modes 8.2.6: i **mute group** (gruppi di esclusione, come charleston aperto/chiuso) valgono anche per le note che arrivano.

### Un pad col suo canale

📄 G-modes 8.2.5 e G-howto 12.9: in SOUND EDIT (SHIFT + SOUND, poi − / + fino alla pagina midi) la manopola X sceglie il canale del pad, la Y la «root note». Dalla 2.0 quel canale vale **in uscita e in entrata** 📄 NEW. Un pad con suono «000» non suona niente e serve solo a mandare MIDI ad altre macchine (📄 G-howto 12.9).

❓ Con un canale suo, il pad suona anche le altre note intonate (come una tastiera)? La guida non lo dice. Se sì, è il modo per avere melodie da Bobina senza il modo KEYS.

## 2. Le impostazioni MIDI

📄 G-system: **SHIFT + ERASE** apre le impostazioni; − / + per muoversi, ENTER per scegliere, SHIFT + ENTER per tornare indietro. Oppure si **batte il numero** e ENTER (es. `101` ENTER). Per Giampiero: lo fa Ele una volta, battendo i numeri.

| codice | cosa fa | note |
|---|---|---|
| 100 | clock MIDI spento | **di serie** |
| 101 | clock MIDI **in entrata** (solo riceve) | per seguire Bobina |
| 102 | clock MIDI **in uscita** (solo manda) | per comandare gli altri |
| 110 | riceve **tutti** i canali, manda sul canale 1 | ❓ di serie (TM e MG dicono così) |
| 111-126 | riceve e manda sul canale 1 … 16 | |
| 127 | manda e riceve solo dai pad che hanno un canale in SOUND EDIT | dalla 2.0.1 📄 NEW |
| 130 / 131 | MIDI thru spento / acceso | il thru passa quello che entra a MIDI out **e** USB 📄 NEW (OS 2.0) |
| 140 / 141 | allo stop **non** azzera / azzera i controller | 📄 G-system dice 140 = off (di serie). ❗ la nota della 2.0.2 dice il contrario (140 = on). Vedi 13 |
| 200 / 201 / 202 | sync in: 1/8 · **1/16 (di serie)** · 24 ppqn | presa sync |
| 210 / 211 / 212 | sync out: 1/8 · **1/16 (di serie)** · 24 ppqn | 1/8 = Pocket Operator |
| 300 / 301 / 302 | velocity dei pad: spenta (di serie) · alta · bassa | |
| 330 / 331 | manopole e fader: scala (di serie) · aggancio | |
| 400 / 401 / 402 | metronomo: sempre · solo in registrazione (di serie) · solo conteggio | |
| 410 / 411 / 412 | cambio scena: subito (di serie) · **a fine battuta** · a fine pattern | utile se Ele cambia scena a mano |
| 420 / 421 | loop della canzone spento / acceso | |
| 430 / 431 | play: dalla battuta dove sei · dall'inizio del pattern | |
| 510 / 511 | ingresso audio USB: solo campionatore (di serie) · campionatore + ascolto | |

📄 G-system 14.3, **lock mode**: tenendo MAIN all'accensione compare `lok`; da lì ogni cambiamento fatto sulla macchina sparisce al riavvio. Per una macchina che Giampiero usa solo da Bobina è una rete di sicurezza: nessun tocco sbagliato rovina il progetto. ❓ Il MIDI in entrata funziona normalmente in lock mode?

## 3. Tabella dei CC in entrata (completa)

📄 G-system 14.5, confermata da 🔎 MG (10/7/2026):

| CC | valori | cosa fa | da quando |
|---|---|---|---|
| 0 + 32 | 0-16383 | bank select (insieme al program change sceglieva i suoni 1-999) | ❗ vedi 5 |
| 1 | 1-127 | vibrato (rotella di modulazione) | OS 2.0 📄 NEW |
| 12 | 1-127 | parametro effetto, **manopola X** | OS 2.5 📄 NEW |
| 13 | 1-127 | parametro effetto, **manopola Y** | OS 2.5 📄 NEW |
| 64 | 1-127 (🔎 MG: 0-63 giù, 64-127 su) | pedale sustain per i suoni KEY e LEGATO | OS 2.5 📄 NEW |

Più il **pitch bend** (📄 OS 2.0: «incoming pitch bend and mod wheel now affect sample playback»).

- ❓ CC 12 e 13: la guida dice «fx parameter (knobX / knobY)», le note della 2.5 «FX X/Y parameters», MG «X/Y dell'effetto **punch-in** attivo». Due letture: (a) le manopole dell'effetto in mandata (delay, reverb, chorus, distorsione, filtro, compressore, 📄 G-fx: in FX le manopole regolano l'effetto scelto), (b) l'X/Y di un punch-in tenuto. Da provare.
- ❓ Su che canale vanno i CC: con 110 (tutti) qualunque canale; con 111-126 quello scelto.
- 📄 **Non ci sono** CC per: fader, livello dei gruppi, muti, tempo, swing, quantità di effetto, scelta della scena o del pattern.

## 4. Gli altri messaggi (tabella di implementazione)

📄 G-system 14.1. La tabella sul sito è disegnata con cerchietti e croci; l'ho letta dal codice della pagina, quindi ❓ una riga potrebbe essere spostata.

| messaggio | manda | riceve | note |
|---|---|---|---|
| canale | 1 (cambia 1-16) | 1 (cambia 1-16) | modo 1 = omni on, poly |
| note 36-83 (keys: 0-127) | sì | sì | |
| aftertouch (tasti / canale) | no | no | ❗ TM dice che lo riceve; vedi 13 |
| pitch bend | no | **sì** | |
| CC 0 e 32 (bank select) | sì | sì | «use bank select to reach all sounds 1-999» |
| CC 1 | no | **sì** | rotella |
| program change (0-127) | sì | sì | ❗ ma dalla 2.0.2 «non più mappato», vedi 5 |
| SysEx | sì | sì | «identity request+reply, proprietary messages». L'identity va anche sulla presa TRS dalla 2.5 📄 NEW |
| song position | **sì** | **sì** | dalla 2.5 è relativa all'**inizio della canzone**, non della scena 📄 NEW |
| song select, tune request | no | no | |
| clock | sì | sì | uno dei due, secondo 101 / 102 |
| start / stop / continue | sì | sì | TM e GR: «clock, start, stop, continue, song position» in tutte e due le direzioni |
| all sound off | sì | no | |
| reset all controllers | no ❓ | no | ❗ ma con 141 lo manda allo stop (📄 NEW 2.0.2) |
| all notes off, local, system reset | no | no | |
| active sensing | sì ❓ | no | |

### Cosa manda il K.O. II

- 📄 Le note dei pad (suonati o del sequencer) sul canale di sistema o su quello del pad (📄 NEW OS 2.0: «Pads now by default send midi notes to the system midi channel»).
- ❓ Muovendo il fader o le manopole **esce qualcosa**? Nessuna fonte lo dice. Da guardare con un monitor MIDI.
- 🔎 PK: l'app PunchKit fa arpeggi «locked to EP MIDI clock», quindi il clock in uscita via USB arriva all'iPhone.

## 5. Program change: la storia

- 📄 OS 2.0 (9/4/2025): «sending and receiving program change messages».
- 🔎 EL (13/4/2025): l'impostazione «P.Ch» decideva solo se il K.O. II **cambia il campione del pad** quando riceve un program change; non serviva a mandarlo. Il program change si può registrare su un pad con un canale e ripetere. Bug: sulla presa TRS usciva un valore sbagliato, via USB no.
- 📄 OS 2.0.1 (22/5/2025): corretti program change e channel pressure sulla TRS.
- 📄 **OS 2.0.2 (30/9/2025): «removed: midi program change support. program change can still be recorded and relayed but is no longer mapped on the device.»** 🔎 GR conferma su 2.0.5.
- 📄 Ma la tabella 14.1 e la 14.5 (scritte per la 2.5) dicono ancora «use bank select to reach all sounds 1-999», e 🔎 MG lo ripete. ❓ Probabilmente è testo vecchio.

Per Bobina: il program change **non cambia scene, pattern né progetti**, e oggi probabilmente nemmeno i suoni. Serve solo se il K.O. II deve **mandare** program change ad altre macchine (registrati su un pad).

## 6. Clock, start/stop, tempo

- 📄 G-howto 12.9: clock MIDI da impostazioni → MIDI → clock: off, in, out. Uno per volta.
- 📄 G-hw: «the usb-c port allows K.O. II to work as a midi device with clock and transport». ❓ Con 101, il clock lo prende **sia** da USB **sia** dalla TRS? Se arriva da tutte e due insieme?
- 📄 G-spec: il sequencer interno lavora a **96 tick per quarto**; il clock MIDI ne ha 24.
- 📄 G-modes 8.4: tempo da **40 a 399 bpm**, anche coi decimali (120.51). La manopola va solo da 60 a 180, il resto si batte coi numeri. **Via MIDI il tempo si cambia solo col clock**: nessun CC di tempo.
- 📄 NEW OS 2.5: «BLE MIDI clock: reduced jitter by measuring BPM per beat rather than per tick. Improves timestretch and sidechain sync over BLE.» Vuol dire: il K.O. II misura il tempo battito per battito. ❓ Un piccolo ritardo nel cambio di tempo quando Bobina fa una rampa.
- 📄 NEW 2.0.1: corretti «crash when playing song with external clock», «timestretch did not work with external clock», «weird behaviours when recording with external clock». Altro motivo per stare sulla 2.5.1.
- 📄 G-system 430 / 431: con start il K.O. II parte dalla battuta corrente o dall'inizio del pattern. ❓ Con un **start** MIDI (FA) riparte da capo? (lo standard dice sì), e col **continue** (FB) da dove era.
- 📄 Song position: ricevuta. Dalla 2.5 «MIDI Song Position Pointer is now relative to song start, not scene start. DAW playhead navigation works correctly». ❓ Quindi in modalità song Bobina potrebbe **saltare a una battuta della canzone** (e dunque a una scena) con un SPP. È la sola strada nota per «cambiare scena» da fuori. Tutta da provare: se va solo da fermo, se va a tempo, se va fuori dalla modalità song.

## 7. La presa sync (anche Pocket Operator)

📄 G-hw 1.2 e G-spec 16: due prese da 3,5 mm, **sync in** e **sync out**, 3,3 V (l'ingresso regge fino a 10 V).

| modo | punta (sinistra) | anello (destra) | a cosa serve |
|---|---|---|---|
| 8 («dual 8th») | clock a ottavi | clock a ottavi | **due Pocket Operator** con uno sdoppiatore |
| 16 (di serie) | clock a sedicesimi | start / reset | stile eurorack, un altro K.O. II |
| 24 | sync24 | start / stop | drum machine d'epoca (serve cavo DIN sync, non MIDI) |

- 📄 G-howto 12.5, **K.O. II comanda il PO**: sync out del K.O. II → ingresso (lato sinistro) del PO. Sul PO: tasto funzione + BPM fino a **SY2**. Sul K.O. II: impostazione **210** (sync out 8). Poi play sul PO e play sul K.O. II.
- 📄 G-howto 12.6, **il PO comanda il K.O. II**: cavo stereo → due mono. Punta (sync) nel sync in del K.O. II, anello (audio) nel suo ingresso audio. PO in **SY1**, K.O. II a **200**. Bonus: gli effetti del K.O. II sull'audio del PO.
- 📄 G-howto 12.4: due K.O. II, tutti e due a 1/16 in e out.
- 📄 NEW 2.0.5 (3/12/2025): «restored SYNC OUT continuous clock output» (il sync out batte anche da fermo). NEW 2.5: «PO sync (SYNC 8) auto-start fixed», «PO sync auto-start now restarts from the beginning».
- ❓ Il sync out segue anche il clock MIDI che arriva da Bobina (cioè: Bobina → USB → K.O. II → sync out → PO)? Logico, non scritto.

## 8. Col cavo USB-C sull'iPhone

- 📄 G-hw: USB-C = MIDI, file e firmware. 🔎 TM e altri: **class compliant**, niente driver. 📄 DL 1.2.2: sistemato il MIDI USB su Android.
- 📄 NEW OS 2.5: anche **audio USB class compliant**, in entrata e in uscita (il K.O. II registra dall'iPhone e l'iPhone registra il K.O. II). 🔎 RA: su iPhone USB-C basta un cavo USB-C ↔ USB-C. Su iPhone Lightning serve l'adattatore Apple per fotocamere (🔎 RA, PK, BF).
- 🔎 BF: serve un cavo **dati**; quelli da sola ricarica non vanno.
- **Corrente**: 📄 G-power «5V / min 1A». 📄 APL: l'iPhone 15 e successivi alimentano accessori fino a **4,5 W** (≈ 0,9 A a 5 V). 🔎 RA (10/7/2026): «an iPhone is a weak power host», tieni le **4 pile AAA** dentro. 🔎 PK: su Lightning l'adattatore deve essere alimentato. ❓ Con le pile dentro e l'iPhone attaccato, da dove prende corrente il K.O. II? (Sound On Sound: «passa all'USB quando è collegato») Se la prende dall'iPhone, scarica il telefono. Da misurare.
- ❓ Il nome con cui compare in CoreMIDI (porta USB).
- ❓ Hub USB-C con K.O. II **e** OP-Z (o TX-6) sull'unica presa dell'iPhone: meglio un hub alimentato.

## 9. Bluetooth: solo con l'adattatore

- 📄 G-hw, G-spec: nessuna parola sul bluetooth. La macchina non ce l'ha.
- 🔎 WIDI (CME, ottobre 2025): **WIDI K.O.II**, due spine TRS MIDI tipo A, un tasto e un led. Prende corrente **dalla presa MIDI out** del K.O. II: niente pile, niente cavi. Passa note, CC, clock, SysEx. Ritardo dichiarato «fino a 3 ms». Portata 20 m.
- 🔎 WIDI, guida: su iOS si collega dentro l'app che ha la pagina bluetooth MIDI, oppure con **midimittr**. Da iOS 16 l'iPhone si ricollega da solo dopo il primo abbinamento. Per Bobina: lo stesso `CABTMIDICentralViewController` usato per gli altri ❓.
- 📄 NEW 2.5 «BLE MIDI clock: reduced jitter … over BLE»: TE ha pensato proprio a questo caso.
- ❓ Il SysEx (campioni) via WIDI: possibile in teoria, ma la TRS è lenta. Non ci serve.
- ❓ Il ritardo vero col WIDI, nota mandata e rimandata col thru acceso (131).

## 10. Il SysEx della community

### Com'è fatto (🔎 ZB, KM)

- Intestazione `F0 00 20 76 33 40 …`: `00 20 76` = teenage engineering, `33` = EP-133, `40` costante TE (🔎 ZB).
- È un **sistema di file**: campioni nei posti 1-999, progetti, pad. Lo usa l'**EP Sample Tool** ufficiale (📄 G 10.2: [teenage.engineering/apps/ep-sample-tool](https://teenage.engineering/apps/ep-sample-tool), dal browser col cavo USB-C).
- 🔎 ZB: **non si leggono** il progetto attivo, il tempo, la batteria né i pattern dal vivo. Solo file.
- 🔎 KM: nessun comando dal vivo (cambio scena, muti, tempo) documentato.

### Da leggere: abbastanza sicuro

| comando 🔎 ZB | cosa fa |
|---|---|
| `01` | saluto, apre la sessione |
| `0B` | stato di un file (nome, dati) |
| `04 00` | elenco dei 12 pad di un gruppo |
| `07 02` | metadati di un file (JSON) |
| `03 00` / `03 01` | legge un file a pezzi da 327 byte |

Regola di ZB: **mai** `03 00` su un file senza prima chiedere `0B` e vedere che esiste.

### Scrive: non in Bobina v1

| comando | cosa fa | rischio |
|---|---|---|
| `02 00` / `02 01` | crea un file e lo riempie (caricare un campione) | 🔎 ZB «sicuro»; 📄 NEW 2.5 ha corretto «uploading samples while in SAMPLE could corrupt samples» e un crash con USB instabile |
| `07 01` | cambia i metadati (nome, impostazioni del pad) | 🔎 ZB |
| `05 01` | **fa suonare un pad o un campione** | 🔎 ZB lo mette fra le scritture «sicure». ❓ Interessante come anteprima, ma per suonare bastano le note |
| `06 02` | **cancella un file** | 🔎 ZB: «può bloccare la macchina» |
| `01` con flag = 1 | modo scrittura, fase dati sconosciuta | 🔎 ZB: pericoloso |

### Mai

- 🔎 ZB: due blocchi «ERROR 8200» durante le prove (serve spegnere e riaccendere, non basta staccare l'USB) e un «ERROR CLOCK 43» dopo un `.ppak` costruito da zero, **risolto solo formattando** (SHIFT + ERASE all'accensione, 📄 G-system 14.4: cancella tutti i suoni).
- 🔎 KM (11/7/2026): «these devices can be crashed and require formatting by malformed writes». Regole: backup prima, un'operazione per volta, mai due programmi insieme sulla macchina.
- 🔎 UNI: riscrive il firmware via WebMIDI (DFU) per trasformare un EP-133 in EP-40. Lo dice da solo: «can brick your device». Mai.

## 11. Programmi che esistono già (idee da rubare)

| programma | cosa fa | idea per Bobina |
|---|---|---|
| EP Sample Tool (TE, browser) | campioni su e giù, backup e ripristino dei progetti (📄 DL 1.2.0) | lo usa Ele dal Mac, non Bobina |
| [Best Friend](https://epbf.app/) (iOS 26+, 9,99 $, luglio 2026) | col cavo: legge pad, note di scene e canzoni, esporta tracce, backup; tastiera con accordi e arpeggiatore che suona il K.O. II | accordi e arpeggi a tasti grandi |
| [PunchKit](https://punchkit.dev/) (iOS, 2026) | kit da 12 pad offline, «MIDI playground» (accordi, melodia, basso, arpeggi sul clock del K.O. II), effetti «punch it», registrazione USB, backup | seguire il clock del K.O. II quando è lui a comandare |
| Cornerman for K.O. II (iOS) | backup sul telefono | — |
| [ep133-export-to-daw](https://ep133-to-daw.cc/) (D2D) | legge il progetto (via WebMIDI o da backup), **non scrive**; esporta in Ableton, REAPER, MIDI | lo «specchio»: mostrare le scene in grande |
| [ep_133_sample_tool](https://github.com/pbarilla/ep_133_sample_tool) (OST, fork) | Sample Tool offline, Mac/Win/Linux | — |
| Ko-tool (Zatumanen), ep133-krate, EP133-skill | lettori di progetti, gestori di campioni, generatori di `.ppak` | — |

❓ Nessuna di queste app dice di supportare l'accessibilità. Tutte vogliono il cavo.

## 12. Idee per chi non usa le mani

Carico sul bluetooth (WIDI): **basso** = un messaggio ogni tanto · **medio** = qualche messaggio a ogni battito · **alto** = flusso continuo.

| idea | come | cavo / WIDI | stato |
|---|---|---|---|
| **48 pad in grande** | una pagina per gruppo (A-D), 12 tasti col posto vero del tastierino; ogni tasto diviso in due (sopra tocco, sotto tieni) come per gli altri | tutti e due, carico basso | 📄 note 36-83 |
| **Colpi a tempo** | Bobina mette il colpo sul prossimo sedicesimo dell'orologio unico: anche un comando vocale lento cade a tempo | tutti e due | ❓ anticipo per il ritardo del bluetooth |
| **Rullo / note repeat** | il tasto «tieni» ripete la nota a 1/8, 1/16, 1/32 col clock di Bobina | cavo meglio; WIDI medio | sulla macchina c'è TIMING + pad, via MIDI no: lo fa Bobina |
| **Registra le dita di Bobina** | Ele arma REC, Bobina suona: le note finiscono nel pattern | tutti e due | ❓ da provare |
| **Volume e accento** | velocity: tasto «piano / forte» | tutti e due | 🔎 MG |
| **Manopole effetti** | due cursori grandi = CC 12 e 13, a gradini (8-16 passi) invece che continui | WIDI basso-medio | ❓ cosa muovono davvero (vedi 3) |
| **Sweep a tempo** | CC 12 o 13 che sale lungo una battuta, un passo per sedicesimo | medio | a 120 bpm = 8 messaggi al secondo |
| **Tieni la nota** | sustain CC 64 per i suoni KEY e LEGATO: un tasto «pedale» | basso | 📄 OS 2.5 |
| **Vibrato e pitch** | CC 1 a un tocco; pitch bend a gradini per un «tape stop» finto | basso / medio | 📄 |
| **Clock da Bobina** | 101 sul K.O. II, Bobina manda clock + start/stop: tempo esatto anche fuori da 60-180 | **cavo**; WIDI ok dalla 2.5 | 📄 |
| **Il K.O. II comanda** | 102 sul K.O. II: Bobina segue il suo clock e lo gira agli altri | cavo | 📄 |
| **Salto di scena (SPP)** | in modalità song, Ele mette le scene in fila; Bobina manda un Song Position Pointer per saltare a una sezione | cavo | ❓ tutto da provare (vedi 6) |
| **Scene con Ele** | non si cambiano via MIDI. Se le cambia Ele a mano, impostazione **411** = il cambio cade a fine battuta | — | 📄 |
| **Muti e fader** | **non si fanno via MIDI** | — | 📄 (assenti) |
| **Effetti punch-in** | via MIDI no (sono FX + pad sulla macchina). ❓ Se il CC 12/13 muove l'X/Y del punch-in, serve comunque che qualcuno tenga FX | — | ❓ |
| **K.O. II suona le altre** | pad con suono «000» e canale assegnato: il sequencer del K.O. II manda note al TX-6/OP-Z/PO via Bobina | cavo | 📄 G-howto 12.9 |
| **Ponte** | le note dei pad del K.O. II (in uscita) comandano le sezioni di Bobina, come il ponte del TX-6 | tutti e due | 📄 |
| **Lock mode** | Ele accende tenendo MAIN: nessun errore resta salvato | — | 📄 14.3 |

### Stare a tempo con OP-Z, TX-6 e PO

1. **Bobina comanda, K.O. II col cavo**: Bobina manda il clock (K.O. II su 101) insieme a OP-Z e TX-6, come già fa. Serve un hub USB-C ❓.
2. **Il PO attaccato al K.O. II**: sync out del K.O. II (210) → PO in **SY2**. Il PO prende il clock diretto, agganciato, invece del sync calcolato dell'adattatore Hanz (che 🔎 PO-RICERCA dice scivola un poco ai tempi «storti»). ❓ Che il sync out segua il clock MIDI in entrata.
3. **K.O. II via WIDI**: clock da Bobina sul bluetooth. TE dalla 2.5 lo ha reso più stabile. ❓ Quanto scivola rispetto al cavo.
4. **K.O. II comanda**: 102, Bobina segue e gira il tempo agli altri. Solo col cavo, o col WIDI ❓.
5. Due K.O. II o una drum machine d'epoca: presa sync, 16 o 24.

## 13. Dove le fonti non sono d'accordo

1. **Impostazione 140/141**: la tabella della guida dice 140 = non azzera allo stop (di serie), 141 = azzera. Le note della 2.0.2 dicono «140 (on) and 141 (off)». ❓
2. **Program change**: le note della 2.0.2 dicono «tolto», la tabella 14.1 e MG (10/7/2026) dicono ancora «bank select per i suoni 1-999». EL (aprile 2025) parlava di un'impostazione «P.Ch» che oggi nella lista delle impostazioni non c'è più.
3. **CC 12 e 13**: «manopole X/Y dell'effetto» (guida, note 2.5) o «X/Y del punch-in attivo» (MG).
4. **Aftertouch**: TM dice che lo riceve (tasti e canale); nella tabella 14.1 (letta dal codice della pagina) è una croce. Le note della 2.0.2 parlano però di «recording fast external MIDI aftertouch»: forse lo registra e lo ripassa senza usarlo.
5. **Cosa manda**: TM dice che manda anche i CC; la tabella segna solo il bank select. Nessuno dice se il fader esce.
6. **Corrente dall'iPhone**: Sound On Sound «passa all'USB quando è collegato»; RA consiglia le pile perché l'iPhone è debole. Le due cose insieme dicono: probabilmente prova a prendere corrente dall'iPhone.
7. **Canali «per gruppo»**: prima della 2.0 il MIDI era diverso (la 2.0 ha portato «a new midi note map» e il canale di sistema). Le guide vecchie e i video del 2024 non valgono più.

## 14. Da misurare noi

1. Nome in CoreMIDI, col cavo e col WIDI. Il WIDI si collega dal `CABTMIDICentralViewController` senza midimittr?
2. Corrente: col solo iPhone si accende? Con le pile dentro, scarica il telefono? Quanto dura una sessione.
3. Valore di serie del canale (110?) e del clock (100) su una macchina con la 2.5.1.
4. Note 36-83 con KEYS acceso e spento; velocity con la sensibilità dei pad spenta.
5. Un pad con canale suo: suona le altre note intonate?
6. CC 12 e 13: cosa muovono, con FX aperto e chiuso, a macchina ferma e in play.
7. Il K.O. II manda qualcosa muovendo fader e manopole? (monitor MIDI)
8. Clock 101: da USB, da TRS, da tutti e due. Start (FA) e continue (FB): da dove riparte.
9. Song Position Pointer in modalità song: salta? A tempo o solo da fermo?
10. Sync out che segue il clock di Bobina, col PO in SY2.
11. Ritardo: col cavo e col WIDI, nota mandata e rimandata col thru (131).
12. Lock mode: il MIDI in entrata funziona? Le note registrate si perdono al riavvio?
13. Hub USB-C con K.O. II + OP-Z (o TX-6) sull'iPhone.
14. Program change in entrata con la 2.5.1: fa ancora qualcosa?
