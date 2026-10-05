# Dirtywave M8 via MIDI

Ricerca del 5/10/2026. Niente ancora misurato sulla macchina vera: le righe «da provare» vanno confermate.

## 1. Tasti (fatto: sezione Tasti)

- Note sul canale **CONTROL MAP CHAN** (Project > MIDI > Settings, di serie 10).
  Note On = giù, Note Off = su. 0 play · 1 shift · 2 edit · 3 option · 4 sinistra · 5 destra · 6 su · 7 giù.
- La mappa non è nel manuale: viene da handeyeco e dal sito m8tracker. Da provare.

## 2. Mute e solo delle 8 tracce

- Stesso canale: note **12-19 = mute** tracce 1-8, **20-27 = solo** tracce 1-8.
- Il sito m8tracker dice «toggle press»: Note On accende, Note Off spegne. Da provare.

## 3. Mettere in coda le righe della song

- Canale **SONG ROW CUE CHANNEL**: la nota = il numero della riga (riga 00 = nota 0, riga 1F = nota 31…).
- Sull'M8 la riga parte quando finisce la catena che suona (LIVE QUANTIZE nel Project).

## 4. Tempo

- SYNC IN: CLOCK, TRANSPORT, CLOCK+TRANSP., TRANSPORT+SPP, CLK+TRANSP+SPP.
- Con SYNC IN = CLOCK+TRANSP. l'M8 segue BobinaClock come TX-6, PO e OP-Z.
- Con SYNC OUT acceso è l'M8 a dare il tempo a Bobina.

## 5. L'M8 come modulo sonoro

- Track MIDI Input: ogni traccia ha CHAN, INST#, PG CHANGE (cambio strumento col program change), MODE (MONO, LEGATO, POLY).
- Le note da Bobina suonano gli strumenti dell'M8: i sequencer e i pad di Bobina possono suonarlo.

## 6. Manopole (CC)

- Fino a 128 mappature per song (Project > MIDI Mapping): sul parametro tieni OPTION e muovi il CC.
- Un CC può comandare più parametri insieme. Canale: CONTROL MAP CHAN.
- Idea: l'inclinazione del telefono (come per i PO) su un CC.

## 7. L'M8 che comanda gli altri

- Lo strumento MIDI OUT manda note, program change e fino a 10 CC su USB o TRS.
- Col telefono collegato via USB, Bobina può ricevere e girare tutto a TX-6, PO e OP-Z.

## 8. Lo schermo dell'M8 su Bobina (firmware 6.0 o più)

L'app gratuita **m8c** per iPhone e iPad già lo fa via MIDI USB (sorgente `src/backends/m8_rtmidi.c`).

- Porta: il nome comincia con «M8».
- SysEx con intestazione `F0 00 02 61 00`:
  - `… 00 'D' F7` stacca;
  - `… 00 'E' F7` accende lo schermo (aspetta risposta entro 1 s);
  - `… 00 'R' F7` ridisegna tutto.
- **Tasti:** `F0 00 02 61 00 msb 00 'C' stato F7`. Lo stato è un byte con un bit per tasto:
  - sinistra 128, su 64, giù 32, shift 16, play 8, destra 4, option 2, edit 1;
  - `msb` = bit 7 dello stato.

  Un messaggio solo per qualunque combinazione, senza canale da impostare.
- **Suonare (keyjazz):** `F0 00 02 61 00 msb 00 'K' nota velocity F7`. `nota FF` con velocity 0 spegne tutto.
- **Lo schermo arriva come SysEx a 7 bit.** Ogni 8° byte porta i bit alti dei 7 dopo.
- Dentro ci sono i comandi:
  - FE rettangolo (x, y, larghezza, altezza, colore);
  - FD carattere (carattere, x, y, colore testo, colore fondo);
  - FC oscilloscopio (colore + punti);
  - FB tasti premuti;
  - FF info: modello, firmware, font.
- Lo schermo è un flusso continuo: col cavo va bene, col bluetooth no.
- L'audio non passa: m8c consiglia AUM.

## Fonti

- Manuale M8 6.0.0: p. 10 Live Mode, p. 43 MIDI Mapping, p. 44 MIDI Settings, p. 62-65 External Instrument, MIDI Out, USB.
- handeyeco.github.io/tech-blog/m8-basic-midi
- sites.google.com/view/m8tracker/midi
- github.com/laamaa/m8c: m8_rtmidi.c, command.c, input.h
- m8c.laamaa.fi/ios-user-guide.html
