# Bobina

Un'app per iPhone che suona il **TP-7** di teenage engineering via MIDI, col cavo USB-C o col bluetooth.
Non è un semplice telecomando: fa quello che la macchina da sola non sa fare.

- **Nastro**: una bobina virtuale da girare col dito (scrub e scratch), il trasporto vero (da capo, play, stop, registra), la velocità da ×0,5 a ×2, il tape stop, il «nastro stanco» (wow e flutter), e la velocità comandata inclinando il telefono.
- **Pad**: sedici cue come i pad di un campionatore. Segni i punti buoni di una registrazione mentre suona, poi li suoni. Più il balbettio (beat repeat), il collage a caso e il loop a tempo.
- **Ritmo**: un metronomo con tap (oppure il tempo del TP-7 stesso, in modalità sync), un sequencer di sedici passi che fa saltare il nastro fra i cue (una drum machine fatta di nastro), il cancello (muti a tempo, il trucco del transformer) e la pompa (il sidechain fatto col mixer del TP-7).
- **Mixer**: volumi e muti delle sei tracce, la deriva (volumi che vagano da soli), i guadagni dei tre ingressi, l'armamento della registrazione.
- **Collega**: cavo o bluetooth, lo specchio dei tasti del TP-7 in modalità ctrl, il monitor dei messaggi e tutte le tabelle MIDI.

> Compilata con Xcode 26.6 e 27.0 e provata col TP-7 vero, col cavo e col bluetooth, fra il 28/9 e il 1/10/2026: quello che funziona e quello che no è in `PROVE.md`.

---

## Installarla sull'iPhone (una volta sola, circa 20 minuti)

Serve: un Mac con **Xcode** (gratis dal Mac App Store, versione 16 o successiva), l'iPhone con iOS 17 o successivo, il cavo per collegarlo al Mac.

1. **Scarica il progetto.** Dalla pagina GitHub del sito: pulsante verde *Code* → *Download ZIP*, poi apri lo ZIP. Oppure, dal Terminale, `git clone` del repository.
2. **Apri** la cartella `bobina` e fai doppio clic su **`Bobina.xcodeproj`**. Si apre Xcode.
3. **Aggiungi il tuo Apple ID a Xcode**: menu *Xcode → Settings → Accounts*, il `+` in basso, *Apple ID*. Basta quello che usi già.
4. **Firma l'app**: nella colonna a sinistra clicca sul progetto **Bobina** (l'icona blu in cima), poi sul target **Bobina**, poi la scheda **Signing & Capabilities**. In *Team* scegli il tuo nome con *(Personal Team)*.
   Se Xcode dice che il *Bundle Identifier* è già preso, cambia `com.giampieropagnini.bobina` in qualcosa di tuo, per esempio `com.giampieropagnini.bobina2`.
5. **Collega l'iPhone al Mac**, sbloccalo e rispondi *Autorizza* alla domanda sul computer.
6. **Attiva la Modalità sviluppatore sull'iPhone**: *Impostazioni → Privacy e sicurezza → Modalità sviluppatore*. L'iPhone si riavvia; conferma.
7. In Xcode, nella barra in alto, scegli **il tuo iPhone** come destinazione e premi **▶** (o ⌘R).
8. La prima volta l'iPhone non si fida: *Impostazioni → Generali → VPN e gestione dispositivi*, tocca il tuo Apple ID, **Autorizza**. Poi riapri Bobina.

Con l'Apple ID gratuito l'app resta valida **7 giorni**: quando smette di aprirsi, ricollega l'iPhone al Mac e ripremi ▶ in Xcode. Con l'iscrizione al programma sviluppatori Apple (99 $ l'anno) resta un anno.

---

## Preparare il TP-7

Tieni **mode** per aprire il menu, poi:

- **MIDI**
  - `cue` serve per i pad: le note diventano cue. Qui il TP-7 ignora ▶ ■ ● normali: usa **Nastro → trasporto in cue**, dove play e stop si fanno con la leva. Per registrare, ● in cue arma e il ▶ lo premi sulla macchina; ■ in cue chiude la ripresa.
  - `sync`: funziona il trasporto normale (▶ ■ ⏮ ●) e il TP-7 manda il suo tempo: in Ritmo, «segui il TP-7» fa dettare i passi al nastro, **ma solo col cavo** (col bluetooth il tempo non arriva). In sync però i pad non vanno.
  - `off`: secondo le misure si comporta come sync, senza mandare il tempo. Non l'abbiamo provato.
  - `ctrl` trasforma il TP-7 in controller: in Collega vedi i suoi tasti. Ma in `ctrl` non ascolta più niente, e l'impostazione resta anche scollegato: rimettila come prima quando hai finito.
- **Col cavo**: collega il TP-7 acceso all'iPhone. In Collega compare «TP-7» e Bobina lo sceglie da sola.
  - Finché è collegato, il TP-7 fa anche da scheda audio dell'iPhone.
  - L'iPhone potrebbe provare a caricarlo con la sua batteria.
- **Col bluetooth**: sul TP-7 **BLE → accept**, in Bobina *Collega → cerca il TP-7* e sceglilo dalla lista.
  - Oppure al contrario: TP-7 su **scan** e in Bobina *fatti trovare*.
  - iOS stacca il bluetooth MIDI se resta zitto per qualche minuto: se succede, ricollega.

## Cose da sapere

- **Le cose di velocità funzionano solo mentre il TP-7 suona davvero** (▶ in sync, o il play della macchina). Riguarda velocità, nastro stanco, tape stop e inclinazione; il nastro mosso dalla leva (trasporto in cue) non le sente. La velocità resta anche dopo uno stop: il display non la mostra.
- **La leva a nastro fermo** vale come una velocità: 64 fermo, 68 avanti a ×1, 60 indietro a ×1. «dito» tiene fermo il nastro solo mentre suona o corre con la leva.
- **In cue un pad sposta il nastro al suo segno, ma suona solo se il nastro corre.** Per questo, se il nastro è fermo, il pad lo fa partire con la leva.
- **Cambiare registrazione via MIDI non si può**: ⏩ arriva in fondo al file e si ferma lì. Si cambia sulla macchina.
- **Il loop via MIDI** funziona solo con la schermata LOOP aperta sulla macchina (▲, poi loop). **I pad** vogliono la schermata CUE.
- **Registrare da Bobina** (in sync) crea sempre un file nuovo; ■ chiude la ripresa. In cue serve il ▶ della macchina.
- **Il TP-7 non racconta mai com'è messo.** Bobina non può sapere se sta suonando o se il loop è acceso: si ricorda solo quello che gli ha mandato.
- **I pad in modalità «segna»** legano la loro nota al punto dove passa il nastro in quel momento. Se non segnano, tieni premuto ● sulla macchina mentre tocchi il pad: è il modo ufficiale. La ricetta:
  1. apri una registrazione lunga e falla correre (▶ di «trasporto in cue»);
  2. tocca i pad a tempo nei punti buoni;
  3. passa a «richiama» e suonali;
  4. mettili nel sequencer di Ritmo.
- **Il mixer del TP-7 si azzera** ogni volta che un cue o un loop cambia traccia. Vale anche per i muti del cancello e per la pompa.
- **Via MIDI non c'è modo di cancellare i cue**: si fa sulla macchina.
- **Niente tasto «panico»** in altre app collegate al TP-7: il messaggio che usano (CC 120) sul TP-7 mette in muto le tracce.

## Se Xcode segnala un errore

Con Xcode 26.6 e 27.0 compila senza errori. Se una versione futura di Xcode ne segnalasse, si può fare così:

- da Xcode 26.3 c'è Claude dentro Xcode: *Settings → Intelligence*, accedi, e chiedigli di sistemare gli errori di compilazione;
- oppure copia il messaggio d'errore (riga e file) e incollalo a Claude nella stessa conversazione in cui è nata l'app.

Se l'iPhone ha una versione di iOS più nuova di Xcode, l'installazione si ferma con «developer disk image could not be mounted»: va aggiornato Xcode dal Mac App Store. Se sull'iPhone «Verify App» resta bloccato, cancella Bobina, reinstallala e riprova.

## Dove sono le cose

| file | cosa c'è |
|---|---|
| `Bobina/MIDI.swift` | il filo con CoreMIDI: porte, invio con marca temporale, ricezione |
| `Bobina/TP7.swift` | i byte del TP-7: cosa capisce, cosa manda, come si leggono |
| `Bobina/Engine.swift` | il motore: orologio, effetti, sequencer, sensori |
| `Bobina/*View.swift` | le cinque schermate e le tabelle |
