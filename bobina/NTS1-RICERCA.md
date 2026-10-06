# Korg NTS-1 digital kit mkII: cosa si sa

Ricerca del 6/10/2026. Fonte principale: il documento ufficiale Korg «NTS-1 mkII digital kit MIDI Implementation» v1.00 (18/3/2024),
https://files.kraftmusic.com/media/ownersmanual/Korg_NTS-1_MkII_MIDI_Implementation.pdf, e il manuale
https://cdn.korg.com/us/support/download/files/6686ccc6489984771d001397de392e88.pdf

## Collegamento

- USB-C: MIDI e corrente. **Provato il 6/10/2026: l'iPhone lo accende da solo.**
- MIDI IN e OUT su jack 3,5 mm tipo A. Niente bluetooth.
- Parametro globale «MIDI Route»: USB+MIDI oppure solo USB.

## Cosa riceve

- Note su un canale (il canale globale, di serie 1), pitch bend, All Notes Off (CC 123).
- Un CC per ogni manopola (tabella in `Bobina/NTS1.swift`), con la metà bassa a 14 bit su un altro CC. Bobina manda solo la metà alta (0-127).
- **Solo se il globale «MIDI short message» è acceso** (tabella 2-1, nota *4).
- Clock, start, continue, stop: **solo se il globale «Clock» è su Auto** (nota *6).
- NRPN: 8 parametri «edit» per oscillatore, mod, delay, reverb (anche delle unit user). Di serie spenti. Bobina non li usa ancora.
- Program change: **non c'è**. Per cambiare suono da Bobina si manda il suono intero (SysEx 40).

## Cosa manda

- Le note della sua tastiera, dell'arpeggio e del sequencer.
- I CC quando giri una manopola: Bobina li legge e muove i suoi valori.
- Clock, start, stop.
- SysEx 7E «current program changed» quando il suono cambia: Bobina rilegge il suono (al massimo ogni secondo).

## SysEx (intestazione `F0 42 3g 00 01 73`, g = canale globale 0-15)

| funzione | cosa |
|---|---|
| `10` → `40` | chiede il suono in modifica → il suono (576 byte a 7 bit, 505 a 8 bit) |
| `40` | manda un suono nel suono in modifica, risponde `23` (ok) o `24` (errore) |
| `0E` → `51` | chiede le impostazioni globali → le impostazioni (`GLOB…`) |
| `51` | scrive le impostazioni globali nella memoria dell'NTS-1 |
| `F0 42 50 00 dd F7` | «Search Device»: risponde da qualunque canale con canale globale e firmware |
| `17`-`1E`, `47`-`4A` | unit user (logue SDK 2.0): versione, slot, caricamento con CRC32 |

I dati a 7 bit: ogni gruppo di 8 byte comincia con i bit alti dei 7 che seguono (`NTS1.unpack`).
Nel suono i valori a 10 bit stanno su due byte; il documento dice «alto, basso». Bobina lo legge così, e se il numero non torna prova al contrario: **da verificare sulla macchina**.

## Da provare sulla macchina vera

1. Il nome della porta MIDI (Bobina cerca «NTS-1»): se ce ne sono due, quale è quella giusta.
2. Le manopole di Bobina muovono l'NTS-1 (serve «short message» acceso).
3. «salva il suono di adesso» arriva intero (584 byte in più pacchetti, Bobina li ricompone) e il nome è giusto.
4. «carica» lo rimette uguale; l'NTS-1 risponde «ha ricevuto».
5. A tempo: l'arpeggio segue il bpm di Bobina.
6. L'ordine dei byte a 10 bit (punto sopra).

## Bug noti (community)

- logue-sdk issue #116: se la metà bassa (es. CC 102) arriva prima di quella alta (CC 54) può essere ignorata. Bobina manda solo la metà alta.
- Firmware più recente trovato: 1.3 (10/9/2024).
