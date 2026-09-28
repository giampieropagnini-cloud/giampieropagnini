# TX-6 — appunti di ricerca (29/9/2026)

Etichette: [guida] = guida ufficiale v1.3.0 (è fatta di immagini, lette con OCR) · [fw] = note firmware
teenage.engineering/downloads/tx-6 · [support] = support.teenage.engineering · [misurato] = qualcuno l'ha misurato
sulla macchina · [forum] = detto da utenti, non verificato · [dedotto] = mia lettura.
La guida ufficiale è fatta di immagini: è stata letta con l OCR del Mac il 29/9/2026.

## Firmware
1.0.8 (21/4/2022) lancio · 1.1.4 (30/6/2022) CC esterni su tutto, note cromatiche, clock BLE in/out, BLE host,
PO sync su aux/cue, scene, registrazione su chiavetta, 44.1k · 1.2.5 (11/10/2022) beat tracking, CC gain e pattern,
tutti i CC 0-127, bpm con decimale · 1.2.10 (14/6/2023) USB 12 in/12 out (mac/iOS), integrazione TP-7 e CM-15,
USB host audio, ortho remote, clock compensato · 1.2.12 (11/4/2024) sampler, looper, detune, start/stop in sync16,
aux dual mono · 1.2.13 (12/8/2024) bug · 1.2.15 (28/3/2025) play+seq insieme, start/stop/tempo via CC, input mode
nel menu · 1.3.0 (10/6/2025) pattern utente con pitch per passo, catene, portamento, "midi synth generator" (note
in uscita), "midi cc knob function", scene su USB, link mode (due TX-6 = 24 canali), beat detect su ingressi USB ·
1.3.1 (23/12/2025) driver ASIO Windows · **1.3.3 (28/1/2026) ultimo**, stabilità USB audio.
Aggiornamento: Chrome su teenage.engineering/apps/update, oppure cue tenuto all'accensione → disco → copia .tfw.
Gli aggiornamenti hanno cancellato le impostazioni (1.2.12, 1.2.14 ritirato): salvare le scene prima.

## Hardware [guida]
- Per traccia ×6: 3 manopole (blu alta, arancio media, bianca bassa; di default EQ alti/medi/bassi ±18 dB),
  fader, VU a 5 led (tutti rossi = clip), tasto traccia.
- Colonna destra: display OLED 48×64, manopola select (gira e si preme), FX I (blu), FX II (arancio), shift.
- Sopra: USB-C + 6 minijack stereo (numerati 6..1 partendo dall'USB). Ogni ingresso: mono / mono bilanciato /
  stereo / split L+R.
- Sotto: tasti aux e cue; uscita aux 3.5; cue 3.5 cuffia con microfono (headset); main 6.35 con adattatore.
- Lato: interruttore, led (verde = carico). Batteria 8 h [guida]; utenti 4-6 h misurate.
- Niente jack MIDI: MIDI solo USB e BLE. Sync analogico dagli jack aux/cue.
- Specifiche: ingressi 10 kΩ, guadagno 0-42 dB, max 13 dBu; main/aux 8 dBu 2 Vrms; cue 2 dBu 1 Vrms; 24 bit / 48 kHz;
  160 g; 90×62×23 mm. MFi (Made for iPhone).

## Combinazioni [guida]
home: gira select = volume main · premi select = quick access (tempo/recorder/loop/sample) · shift+gira = cambia
quick access · shift+select = menu di sistema · shift = esci · tasto traccia = solo/muto (tipo nel menu SOLO) ·
shift+traccia ripetuto = menu traccia (filtro, eq, comp, gain, pan + pagine synth) · select nel menu traccia = parametro
successivo · tieni select 1 s = valore di default · aux / cue = pagine aux/cue · shift+cue = microfono · FX I/FX II =
accende/spegne · shift+FX = menu effetto (FX ancora = effetto successivo) · tieni cue = ascolta l'effetto in cuffia senza
accenderlo · pagina FX I: tieni traccia+gira = mandata, shift+gira = ritorno · pagina FX II: traccia = dove sta (stessa
traccia di nuovo = main), shift+FX II = cambia effetto · freeze: tocca select = reset.
tempo: gira = 40-400 bpm · FX I = tap · FX II = nuovo punto d'inizio · select = play/stop · tieni FX II+gira = decimali
(solo clock interno) · beat tracking: FX I aiuta, FX II azzera.
disco: FX I play · FX II rec · shift+FX II = auto (parte col suono, si ferma dopo 5 s di silenzio) · select = file ·
tieni select = cancella · gira = scrub.
aux: gira = volume · tieni traccia+gira = mandata · select = PRE/POST · shift+gira = sync 8/16 o split "A" · aux = A/B.
cue: tracce = chi va in cuffia · gira = volume · select = CUE/MAIN · shift+gira = sync 8/16.
mic: cue+gira; VOL on/off e volume, GAIN 0-31 dB, GATE, DUCK, FX (none/reverb/delay).
seq: shift+traccia = pagina SEQ · gira = pattern · shift+gira = catena 1-4 · select+gira = slot della catena.
menu SEQ: tracce = pattern utente U1-U6 · gira = passo 1-16 · select = passo on/off · shift+gira = pitch ±24.
synth: select sulla pagina frequenza = DET · select su forma d'onda = SLIDE · select su MIDI = canale MIDI.
sampler: FX II = registra (tieni traccia = registra in quello slot, gira = da quale traccia) · FX I = suona (tracce =
suonano, gira = pitch, select = pitch/inizio/fine). max 5,5 s, 6 slot.
looper: gira = traccia · tieni FX II = registra (lascia = stop) · FX II mentre suona = stop · FX I = play/retrigger.
max 22 s. Sample e loop si perdono allo spegnimento: shift+FX II salva su USB, shift+FX I carica.
Solo 2022 (vecchio fw): MEMO preset con shift+tieni FX.

## Menu di sistema [guida]
SOLO (solo / mute / solo momentaneo / mute momentaneo) · USB (2 CH, 12 IN, 12 OUT, 12 CH; + main out source EXT/MIX,
volume uscita USB) · TEMPO · CLOCK (SRC INT/USB/BLE/TR1-6; OUT on/off; in+out = clock instradato fra usb e ble) · DISK ·
POTS (EQ / CUST / TR / SYNTH; parametri assegnabili: flt comp pan eq h/m/l aux auxb FX I freq det len cc) · SYNTH
(off / play / seq / tone; + play+seq da 1.2.15) · SEQ · SAMPLE · LOOP · MIDI (CTRL off/IN/OUT, NOTE off/ON) · BLE (off /
ACCEPT / SCAN, NAME) · SCENE (save/load a b c; 9 slot su chiavetta) · TUNER · INPUT · DJ (off / slow fade / fast cut:
fader 1 = crossfader fra 5 e 6) · LIMITER on/off · VU pre/post · OUT (NORMAL / SWITCH: scambia aux e cue) · RATE
(DEFAULT 48k / MULTI 48+44.1) · LEDS (3 livelli) · DISP · THEME chiaro/scuro · CC (canale e cc di ogni manopola) · GND
(isolamento: spegne il caricatore) · OS · batteria · RESET (gira in senso orario).
FX I (mandata): CHO subtle/medium/strong · REV drone/light/small/medium/large · DLY 1/8 1/4 1/2 2/3 3/4 1 3/2 warp mash.
FX II (insert su una traccia o sul main): TRM · FRZ · TPE stop1/stop2/pong · FLT cut+res · DST push/drive/blow/dstroy ·
CRU shape/bend/chip/bit.
Synth, suono per traccia: SIN TRI SQR SAW · KICK SNARE CLAP HIHAT · SAMPLE · MIDI (manda note). Parametri FRQ DET LEN
SLIDE SEQ. 22 pattern fissi + 1 random + 6 utente.
Flusso: ingresso→gain→adc→mono/stereo→vu pre→pan→filtro→eq→comp→ fader/solo→vu post→ FX II, FX I, master, aux post;
cue; aux pre. Master: fx1, fx2, master → volume → limiter → main.

## USB
2 CH = 2 in/2 out, il più compatibile · 12 IN = 12 dal computer al mixer · 12 OUT = 12 dal mixer al computer (post fader,
SENZA effetti) · 12 CH = entrambi ("usa questa col TP-7"). Stereo mix con FX solo in 2 CH [forum, misurato].
iPhone: "collegalo direttamente, nessun cavo speciale" [guida]. Carica dall'iPhone se GND è spento.
Una sola porta USB: con l'iPhone collegato per l'audio, il MIDI passa comunque dallo stesso cavo (è un dispositivo
composito) [dedotto, da verificare]; chiavetta + iPhone insieme no.
Host USB: se il TX-6 sta a monte di un hub diventa host ("H") e il Mac non lo vede più.

## MIDI [guida]
Menu MIDI: CTRL off / IN / OUT (mai insieme) · NOTE on/off. "ctrl off e note off disattivano tutto il midi".
Uscita (CTRL OUT), tutto canale 1: fader cc 1-6 · manopole alte 7-12 · medie 13-18 · basse 19-24 · tasti traccia 25-30
(0/127) · encoder 31 (relativo) · click encoder 32 · FX I 33 · FX II 34 · shift 35 · aux 36 · cue 37.
Entrata (CTRL IN), canali 1-6 = tracce: volume 7 · pan 8 · gain 9 · pattern 14 · muto/solo 120 · filtro 74 · EQ alti 85
medi 86 bassi 87 · comp 93 · forma d'onda 3 · frequenza 89 · lunghezza 90 · detune 95 · mandata FX I 91 · aux 92 · aux II 94.
Canale 7 = master: volume main 7 · aux 14 · cue 15 · local control 122 · start/stop 46 (toggle) · tempo relativo 47.
Canali 8/9 = FX I / FX II: acceso 82 · motore 15 · param 1/2/3 = 12/13/14 · ritorno FX I (ch 8) 7 · traccia FX II (ch 9) 9.
on/off: 0-63 off, 64-127 on.
Note: canali 1-6 do0-si8 cromatiche sulla traccia · canale 7: do re mi fa sol la = tracce 1-6 alla loro frequenza.
Program change canale 7: 1 → scena a, 2 → b, 3 → "b" (refuso per c). 0 o 1-based? da misurare.
CC knob (1.3.0): POTS su CUST o TR, manopola su "cc", canale/cc nel menu CC; funziona con MIDI CTRL spento; i fader no
[forum, non provato].
Note in uscita (1.3.0): traccia con suono MIDI manda note sul suo canale (sequencer → synth esterno) [non documentato].
Clock: sorgenti INT/USB/BLE/TR; OUT on/off. Conflitto: un articolo support 2024 dice niente clock via bluetooth.
Sync analogico: sinistro = impulsi, destro = audio (sync8) o start/stop (sync16). Aux più forte. 8 = PO, 16 = modulare.

## Misurato da altri (op1-lfo-hero, branch feature/support-field-devices, notes/RESEARCH.md)
- midi control in/out/X esclusivo: in = riceve e non manda nulla; out = manda e ignora.
- default: ignora tutti i CC finché non metti CTRL IN. Per seguire il clock esterno serve SRC = USB.
- cc 120 assoluto: 127 muto, 0 acceso. Attenzione: è anche "All Sound Off" per altri strumenti.
- cc 82 (FX on) è globale; la mandata per traccia è cc 91.
- relativi (cc 47, cc 31) in complemento a due: 1..63 su, 127..65 giù. 64±1 sbaglia di brutto.
- cc 46 = toggle senza stato.
- manda clock 24 ppqn solo con SRC interno e OUT acceso.
- BLE: le marche temporali devono essere vere, altrimenti bpm assurdi.
- CoreMIDI: nome "TX-6", produttore "teenage engineering"; compare due volte (USB e BLE).
Forum [misurato]: il display salta alla pagina del parametro ricevuto via MIDI (ogni LFO ruba lo schermo); i tasti
mandano sempre premuto e lasciato (mai toggle); tempo via CC solo relativo → per imporre un bpm si manda il clock;
batteria o stato non leggibili via MIDI; BLE CC verso iPhone a volte non arriva (ACCEPT vs SCAN).

## Da misurare noi
1. direzione dei fader (127 = su? darnfish dice il contrario, jakeisnt no)
2. cc 47 e cc 31 in complemento a due
3. program change: 0 → a oppure 1 → a? il terzo è c?
4. note canale 7: quale ottava?
5. valori di cc 3 (forma d'onda), cc 15 (motore FX), cc 14 (pattern), cc 12-14 (parametri FX): come si dividono 0-127
6. cc 120 fa muto o solo secondo il menu SOLO?
7. clock via BLE sì o no
8. note in uscita col suono MIDI (1.3.0)
9. il display che salta: si può evitare?
10. MIDI e audio insieme sull'iPhone con un cavo solo

## Programmi della community
- psimyn/tx6 (web, tx6.psimyn.com, GPL-3): telecomando con LFO, tastiera, sequencer. Su iOS serve Bluefy. Voleva farne un'app iOS.
- jakeisnt/tx-6 (tx-6.jake.kitchen, MIT, 26/9/2026): driver TX-6/TP-7/OP-1f, Web MIDI + Web Bluetooth.
- darnfish/use-tx-6 + tx-6-midi-events (2023): hook React via BLE, legge i tasti (CTRL OUT).
- jwamin/field-remote (Swift, 2026): telecomando BLE TP-7/TX-6 con Comandi rapidi di Siri. cc 47 sbagliato (64±n).
- andrewralon/op1-lfo-hero: LFO per i field, profilo TX-6 misurato, mapper nel browser.
- Electra One preset TX-6 (J. Pilarski); t-switcher (Mac, 49 $) usa TX-6/TP-7/EP-133 come superfici per app.
- Nessun SysEx noto. Firmware cifrato.

## Usi creativi visti in giro (fonte forum)
ducking del microfono come sidechain povero (cassa nel mic, volume mic 1) · beat tracking come sync box da vinile/CDJ ·
convertitore clock MIDI → impulsi analogici · anello di effetti esterno con aux pre + canale 6 · feedback voluto in 12 IN ·
chitarra diretta con drive + reverb · drone con 6 sinusoidi (tone) · FX II filtro come risonatore (res 92-99) · drum TX-6
come modulo suonato da OP-XY/DAW con CC per passo · mixdown del TP-7 (12 CH) · loop di tutto il mix (cue in un ingresso
libero) · surround tascabile da AUM · accordatore · video jam col telefono (clic risolti con iOS 26.0.1).

## Desideri non soddisfatti (= occasioni per l'app)
sidechain fra canali (il più chiesto) · LFO / modulazioni · morph fra scene, più di 3 scene · toggle invece di
momentaneo · tempo assoluto · velocity sulle drum · stato globale visibile (il "suono ovattato" era FX II filtro acceso) ·
backup delle scene prima degli aggiornamenti · telecomando nativo iOS (Safari non ha Web MIDI) · superficie più grande
delle manopoline.
