# Bobina

Un'app per iPhone che suona il **TP-7** e il **TX-6** di teenage engineering via MIDI, col cavo USB-C o col bluetooth.
Non è un semplice telecomando: fa quello che le macchine da sole non sanno fare.
Il tasto in alto a destra di ogni pagina passa dalla sezione TP-7 alla sezione TX-6 e ritorno.

### Sezione TP-7

- **Nastro**: una bobina virtuale da girare col dito (scrub e scratch), il trasporto vero (da capo, play, stop, registra), la velocità da ×0,5 a ×2, il tape stop, il «nastro stanco» (wow e flutter), e la velocità comandata inclinando il telefono.
- **Pad**: sedici cue come i pad di un campionatore. Segni i punti buoni di una registrazione mentre suona, poi li suoni. Più il balbettio (beat repeat), il collage a caso e il loop a tempo.
- **Ritmo**: un metronomo con tap (oppure il tempo del TP-7 stesso, in modalità sync), un sequencer di sedici passi che fa saltare il nastro fra i cue (una drum machine fatta di nastro), il cancello (muti a tempo, il trucco del transformer) e la pompa (il sidechain fatto col mixer del TP-7).
- **Mixer**: volumi e muti delle sei tracce, la deriva (volumi che vagano da soli), i guadagni dei tre ingressi, l'armamento della registrazione.
- **Collega**: cavo o bluetooth, lo specchio dei tasti del TP-7 in modalità ctrl, il monitor dei messaggi e tutte le tabelle MIDI.

### Sezione TX-6

- **Mixer**: volume e muto delle sei tracce; ogni traccia si apre con tutto il resto (pan, guadagno, filtro, EQ, compressore, mandate, synth). Il generale (main, aux, cue, manopole del TX-6 spente), le scene a b c della macchina, e le **scene che sfumano**: quante ne vuoi, e il passaggio dall'una all'altra in 1-16 battute.
- **Effetti**: FX I (riverbero, chorus, delay) con le mandate delle tracce e il ritorno, FX II (filtro, crush, distorsione, tremolo, freeze, tape) su una traccia o su tutto, le mandate aux.
- **Suona**: **pattern e stili** (sette stili pronti, house, techno, hip hop, reggaeton, drum'n'bass, electro, ambient, e i tuoi pattern salvati: il cambio entra all'inizio della battuta), **i sei strumenti** (suono e barre di ogni traccia), una tastiera (una traccia, o accordi sulle sei tracce), sei pad (do-la sul canale 7), la **batteria a passi**, la **melodia a passi** e i **passi con manopola**. Il ritmo gira su un filo suo: scorrere lo schermo non lo rallenta.
- **Ritmo**: il tempo in tre modi (di Bobina, Bobina lo dà al TX-6, Bobina segue il TX-6), start/stop e tempo del TX-6, la **pompa** (il sidechain che il TX-6 non ha), il **cancello**, due **onde** (gli LFO che mancano), la **deriva** di volumi e pan, e il filtro **col corpo** inclinando il telefono.
- **Collega**: cavo o bluetooth, lo specchio di fader e manopole in CTRL OUT, il **ponte** (il TX-6 in CTRL OUT comanda la sezione TP-7), il monitor e tutte le tabelle MIDI del TX-6.

> **Attenzione:** il codice è stato scritto e controllato riga per riga, ma non ancora compilato su un Mac. Se Xcode segnala un errore, vedi in fondo.

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
  - `off`, `cue` o `sync`: in tutte e tre il TP-7 ascolta Bobina.
  - `cue` serve per i pad: le note diventano cue.
  - `sync` fa mandare al TP-7 il suo tempo: in Ritmo, «segui il TP-7» fa dettare i passi al nastro. In sync però i pad non vanno.
  - `ctrl` trasforma il TP-7 in controller: in Collega vedi i suoi tasti. Ma in `ctrl` non ascolta più niente, e l'impostazione resta anche scollegato: rimettila come prima quando hai finito.
- **Col cavo**: collega il TP-7 acceso all'iPhone. In Collega compare «TP-7» e Bobina lo sceglie da sola.
  - Finché è collegato, il TP-7 fa anche da scheda audio dell'iPhone.
  - L'iPhone potrebbe provare a caricarlo con la sua batteria.
- **Col bluetooth**: sul TP-7 **BLE → accept**, in Bobina *Collega → cerca il TP-7* e sceglilo dalla lista.
  - Oppure al contrario: TP-7 su **scan** e in Bobina *fatti trovare*.
  - iOS stacca il bluetooth MIDI se resta zitto per qualche minuto: se succede, ricollega.

## Preparare il TX-6

Tieni **shift** e premi **select** per il menu, poi:

- **MIDI** → CTRL **IN**: è l'unico modo in cui il TX-6 ascolta Bobina. NOTE **on** fa suonare il synth dalle note.
  - CTRL **OUT** lo trasforma in controller: in Collega vedi fader e manopole, e col ponte comandano il TP-7. Ma in OUT non ascolta niente.
- **SYNTH** → **play** per la tastiera, i pad e la batteria a passi.
- **CLOCK** → SRC **USB** se è Bobina a dare il tempo; SRC **INT** e OUT acceso se è Bobina a seguirlo.
- **Col cavo**: collega il TX-6 acceso all'iPhone. Bobina lo sceglie da sola. Il TX-6 fa anche da scheda audio; per non farlo caricare dall'iPhone, menu → **GND** acceso.
- **Col bluetooth**: sul TX-6 **BLE → ACCEPT**, in Bobina *Collega → cerca il TX-6*.
- Il TX-6 non racconta com'è messo: Bobina ricorda solo quello che gli ha mandato. E ogni comando che arriva fa saltare il display del TX-6 su quel parametro.

## Cose da sapere (TP-7)

- **Le cose di velocità funzionano solo mentre il TP-7 suona.** Riguarda velocità, nastro stanco, tape stop e inclinazione. Premi ▶ in Bobina o sulla macchina, oppure fai partire un cue da un pad. La velocità resta anche dopo uno stop: il display non la mostra.
- **Il loop via MIDI** funziona solo con la schermata LOOP aperta sulla macchina (▲, poi loop). **I pad** vogliono la schermata CUE.
- **Registrare da Bobina** crea sempre un file nuovo; ■ chiude la ripresa.
- **Il TP-7 non racconta mai com'è messo.** Bobina non può sapere se sta suonando o se il loop è acceso: si ricorda solo quello che gli ha mandato.
- **I pad in modalità «segna»** legano la loro nota al punto dove passa il nastro in quel momento. Se non segnano, tieni premuto ● sulla macchina mentre tocchi il pad: è il modo ufficiale. La ricetta:
  1. apri una registrazione lunga e premi play;
  2. tocca i pad a tempo nei punti buoni;
  3. passa a «richiama» e suonali;
  4. mettili nel sequencer di Ritmo.
- **Il mixer del TP-7 si azzera** ogni volta che un cue o un loop cambia traccia. Vale anche per i muti del cancello e per la pompa.
- **Via MIDI non c'è modo di cancellare i cue**: si fa sulla macchina.
- **Niente tasto «panico»** in altre app collegate al TP-7: il messaggio che usano (CC 120) sul TP-7 mette in muto le tracce.

## Se Xcode segnala un errore

Bobina è stata scritta senza un Mac a disposizione, quindi è possibile che Xcode trovi qualche errore di battitura al primo tentativo. Si può fare così:

- da Xcode 26.3 c'è Claude dentro Xcode: *Settings → Intelligence*, accedi, e chiedigli di sistemare gli errori di compilazione;
- oppure copia il messaggio d'errore (riga e file) e incollalo a Claude nella stessa conversazione in cui è nata l'app.

## Dove sono le cose

| file | cosa c'è |
|---|---|
| `Bobina/MIDI.swift` | il filo con CoreMIDI: porte, invio con marca temporale, ricezione |
| `Bobina/TP7.swift` | i byte del TP-7: cosa capisce, cosa manda, come si leggono |
| `Bobina/Engine.swift` | il motore: orologio, effetti, sequencer, sensori |
| `Bobina/*View.swift` | le cinque schermate e le tabelle |
| `Bobina/TX6.swift` | i byte del TX-6 |
| `Bobina/TX6Engine.swift` | il motore della sezione TX-6 |
| `Bobina/TX6Views.swift` | le cinque schermate del TX-6 e le sue tabelle |
| `TX6-RICERCA.md` · `PROVE-TX6.md` | cosa si sa del TX-6, e le prove con la macchina vera |
