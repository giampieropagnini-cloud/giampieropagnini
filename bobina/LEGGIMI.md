# Bobina

Un'app per iPhone che suona il **TP-7**, il **TX-6** e i **Pocket Operator** (con l'adattatore MIDI di Hanz Tech) di teenage engineering via MIDI, col cavo USB-C o col bluetooth.
Non è un semplice telecomando: fa quello che le macchine da sole non sanno fare.
Il tasto «passa a…» in alto a destra di ogni pagina passa da una sezione all'altra. TX-6 e Pocket Operator stanno sullo stesso orologio: stessa battuta, e chi parte per secondo entra alla battuta dopo.

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

### Sezione Pocket Operator

- **PO 1, PO 2…** in cima a ogni scheda: un PO per adattatore (da due a quattro), ognuno col colore del suo modello; suonano insieme, sulla stessa battuta.
- **Tasti**: la faccia del PO scelto (sub, tonic, K.O!, speak) con la disposizione vera. Ogni tasto è diviso in due: sopra un tocco, sotto «tieni» (resta giù finché non lo ritocchi); i tasti funzione hanno ognuno il suo colore. Pattern, suono e volume in un tocco, «cancella il pattern», un effetto per un momento, il modo di sync.
- **Suona**: i **passi dal vivo** (Bobina preme i tasti del PO a tempo: sedici passi per ognuno dei sedici tasti), gli **effetti a tempo** (anche solo nell'ultima di ogni 2, 4, 8 battute), i **pattern a tempo** (una battuta per casella), il **cancello** (sul tonic un muto vero, sugli altri col volume) e **col corpo** (inclinando il telefono, quattro effetti).
- **Ritmo**: come sta a tempo (Bobina lo suona · cavo sync dal TX-6 · sync out dell'adattatore · senza cavo), il tempo comune col TX-6, l'anticipo per il ritardo del bluetooth.
- **Collega**: bluetooth o cavo, il canale, le scorciatoie a CC, il monitor e le tabelle MIDI dell'adattatore.

Quello che si sa dell'adattatore è in `PO-RICERCA.md`, le prove con le macchine vere in `PROVE-PO.md`.

### Sezione NTS-1 (Korg NTS-1 digital kit mkII)

- **Suono**: tutte le manopole dell'NTS-1 con un nome: oscillatore, filtro, inviluppo, mod, delay, reverb, volume, e i tasti dei tipi (saw, lp2, chorus, hall…). Quando giri una manopola sull'NTS-1, il valore si muove anche in Bobina.
- **Suona**: sedici pad (sopra suona, sotto «tieni»: con l'ARP acceso le note tenute si arpeggiano), l'arpeggio (forma, accordo, lunghezza), i **passi** a tempo con le altre macchine (la nota si sceglie anche dalla tastiera dell'NTS-1), l'NTS-1 **a tempo con Bobina** (start e clock: arpeggio, sequencer e delay bpm), l'**onda a tempo** su una manopola (onda, cancello, pompa) e l'**inclinazione**.
- **Banche**: «salva il suono di adesso» chiede all'NTS-1 il suono intero (anche gli 8 passi del suo sequencer) e lo tiene in Bobina; «carica» glielo rimanda.
- **Collega**: la porta, il firmware e il canale letti dall'NTS-1, e «sistema le impostazioni» se non ascolta le manopole o non segue il tempo.

Quello che si sa dell'NTS-1 è in `NTS1-RICERCA.md`.

> Compilata con Xcode 26.6 e 27.0 e provata col TP-7 vero, col cavo e col bluetooth, fra il 28/9 e il 1/10/2026: quello che funziona e quello che no è in `PROVE.md`.

---

## Per le chat che ci lavorano: installare senza cancellare gli altri

Ogni sezione vive su un suo branch `claude/…`. Si installa **sempre** con `zsh bobina/strumenti/installa.sh`: unisce tutti i branch `claude/*` locali, compila in Release e installa sull'iPhone 18 Pro di Giampiero. Installare da un branch solo toglie dal telefono le sezioni degli altri.

**Dopo ogni cambiamento** (commit o installazione) si avvisano tutte le altre chat di Bobina con SendMessage (ListAgents, nomi con «Bobina»): branch e commit, file comuni toccati, cosa cambia per gli altri, se va unito. Una chat nuova si presenta alle altre appena nasce. È una regola di Giampiero (8/10/2026), scritta anche nel suo CLAUDE.md globale.

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

## Preparare il TX-6

Tieni **shift** e premi **select** per il menu, poi:

- **MIDI** → CTRL **IN**: è l'unico modo in cui il TX-6 ascolta Bobina. NOTE **on** fa suonare il synth dalle note.
  - CTRL **OUT** lo trasforma in controller: in Collega vedi fader e manopole, e col ponte comandano il TP-7. Ma in OUT non ascolta niente.
- **SYNTH** → **play** per la tastiera, i pad e la batteria a passi.
- **CLOCK** → SRC **USB** se è Bobina a dare il tempo; SRC **INT** e OUT acceso se è Bobina a seguirlo.
- **Col cavo**: collega il TX-6 acceso all'iPhone. Bobina lo sceglie da sola. Il TX-6 fa anche da scheda audio; per non farlo caricare dall'iPhone, menu → **GND** acceso.
- **Col bluetooth**: sul TX-6 **BLE → ACCEPT**, in Bobina *Collega → cerca il TX-6*.
- Il TX-6 non racconta com'è messo: Bobina ricorda solo quello che gli ha mandato. E ogni comando che arriva fa saltare il display del TX-6 su quel parametro.

## Preparare il PO

- L'adattatore va montato come dice la sua guida: mascherina a filo, nessuno spazio fra mascherina e piedini delle manopole. Se un tasto non risponde, è quasi sempre l'allineamento.
- **Col bluetooth** (solo l'adattatore V3): in Bobina *Collega → cerca l'adattatore*. Il bluetooth va acceso nel configuratore web dell'adattatore (`ble_midi_enabled = 1`).
- **Col cavo**: micro USB dell'adattatore → iPhone. Compare come «Teensy MIDI».
- **A tempo col TX-6, col cavo**: aux del TX-6 → ingresso del PO. Sul TX-6: aux, shift + gira select → sync 8. Sul PO: tasto in alto + bpm fino a **SY2**. In Bobina: *Ritmo → cavo sync dal TX-6*.
- Via MIDI **le manopole A e B non si muovono**, e il PO non dice mai com'è messo.

## Preparare l'NTS-1

- **Col cavo**: USB-C dell'NTS-1 → iPhone. L'iPhone lo accende anche (provato il 6/10/2026). Bobina lo sceglie da sola.
- Bobina al collegamento legge firmware, canale e impostazioni. Servono due impostazioni globali dell'NTS-1: **MIDI short message = on** (se no ignora le manopole di Bobina) e **Clock = Auto** (se no non segue il tempo). Se mancano, *Collega → sistema le impostazioni* le accende da Bobina.
- **Niente bluetooth**: l'NTS-1 non ce l'ha.
- L'arpeggio dell'NTS-1 si accende solo dal suo tasto ARP (via MIDI non c'è un comando). Per questo c'è l'**arpeggio di Bobina** (Suona): suona lui le note tenute, a tempo, senza toccare la macchina.
- Un suono caricato da Bobina va nel suono in modifica: per tenerlo sull'NTS-1, salvalo lì in un programma.

## Cose da sapere (TP-7)

- **Le cose di velocità funzionano solo mentre il TP-7 suona davvero** (▶ in sync, o il play della macchina). Riguarda velocità, nastro stanco, tape stop e inclinazione; il nastro mosso dalla leva (trasporto in cue) non le sente. La velocità resta anche dopo uno stop: il display non la mostra.
- **La leva a nastro fermo** vale come una velocità: 64 fermo, 68 avanti a ×1, 60 indietro a ×1. «dito» tiene fermo il nastro solo mentre suona o corre con la leva.
- **In cue un pad sposta il nastro al suo segno, ma suona solo se il nastro corre.** Per questo, se il nastro è fermo, il pad lo fa partire con la leva.
- **Cambiare registrazione**: un comando MIDI non c'è, ma con menu → **PLAY → resume** sul TP-7 i tasti ⏪ ⏩ attraversano tutti i file. Oppure un **album** (`strumenti/banche/album.py`): più registrazioni in un file, e ⏮ ⏭ canzone.
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
| `Bobina/TX6.swift` | i byte del TX-6 |
| `Bobina/TX6Engine.swift` | il motore della sezione TX-6 |
| `Bobina/TX6Views.swift` | le cinque schermate del TX-6 e le sue tabelle |
| `TX6-RICERCA.md` · `PROVE-TX6.md` | cosa si sa del TX-6, e le prove con la macchina vera |
| `Bobina/BobinaClock.swift` | l'orologio unico: la griglia di battiti che TX-6 e PO leggono |
| `Bobina/PO.swift` | i byte dell'adattatore dei PO e i nomi dei quattro modelli |
| `Bobina/POEngine.swift` · `POSequencer.swift` | il motore dei PO e il loro ritmo, su un filo suo |
| `Bobina/POViews.swift` | le quattro schermate dei PO |
| `PO-RICERCA.md` · `PROVE-PO.md` | cosa si sa dell'adattatore, e le prove con le macchine vere |
| `Bobina/NTS1.swift` | i byte dell'NTS-1: CC, SysEx Korg, il suono salvato |
| `Bobina/NTS1Engine.swift` · `NTS1Play.swift` | il motore dell'NTS-1, i pad, i passi e l'onda a tempo |
| `Bobina/NTS1Views.swift` | le quattro schermate dell'NTS-1 |
| `NTS1-RICERCA.md` | cosa si sa dell'NTS-1 |
