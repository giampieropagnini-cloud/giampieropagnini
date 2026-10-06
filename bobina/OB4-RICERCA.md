# OB-4 — appunti di ricerca (2/10/2026)

Per capire se l'OB-4 («magic radio», la cassa di teenage engineering) può entrare in Bobina. Solo ricerca, niente codice. Ogni riga dice da dove viene:

- 📄 **documentato**: guida ufficiale teenage engineering, pagina prodotto, note ufficiali di TE
- 🔎 **community**: ricavato da altri (codice su GitHub, forum, recensioni). Tra parentesi chi e quando
- ❓ **da misurare**: nessuno lo dice chiaro, le fonti litigano, oppure è una mia deduzione

Firmware: l'ultimo con un numero scritto da qualcuno è **1.4.11 (luglio 2022)** 🔎[F-21742]. Dopo, l'app orthoplay ha aggiunto il supporto per i colori nuovi (2/2024) e per l'edizione «mind games» (11/2024) 📄[APP]: è probabile che ci siano firmware più nuovi, ma nessuno ne scrive il numero ❓. TE **non pubblica le note dei firmware** dell'OB-4 (non c'è una pagina downloads/ob-4: risponde 404).

| sigla | fonte |
|---|---|
| G | [guida OB-4](https://teenage.engineering/guides/ob-4), letta tutta il 2/10/2026 |
| P | [pagina prodotto OB-4](https://teenage.engineering/products/ob-4) (specifiche) |
| OR | [guida ortho remote](https://teenage.engineering/guides/or-1) |
| APP | [orthoplay sull'App Store](https://apps.apple.com/us/app/orthoplay/id582616765), letta il 2/10/2026 |
| TEK | [ericlewis/TEKit](https://github.com/ericlewis/TEKit) (Swift, licenza MIT, **un solo commit del 30/3/2026**). File: `Devices/TEOB4.swift`, `Protocol/Serial/TESerialConstants.swift` |
| ORE | [Marcocanc/orthoplay-re](https://github.com/Marcocanc/orthoplay-re): protocollo websocket, **solo OD-11** |
| IFX | [smontaggio iFixit](https://www.ifixit.com/Teardown/Teenage+Engineering+OB-4+Teardown+and+Internals/161711) (LEGAL DELEUZE, 29/5/2023) |
| F-n | thread di op-forums.com numero n · EN = thread Elektronauts [184299](https://www.elektronauts.com/t/teenage-engineering-ob-4-update/184299) |

## In breve: le 6 cose che contano per Bobina

1. 📄 **L'OB-4 non ha MIDI.** La guida non lo nomina mai, niente MIDI USB, niente MIDI bluetooth, niente clock. 📄 Non ha nemmeno una porta USB: dietro c'è solo la spina di corrente (100-240 V) e davanti l'ingresso jack 3,5 mm. Quindi **niente tempo condiviso**: il loop dell'OB-4 non si aggancia al clock di Bobina.
2. 📄 È una cassa **bluetooth normale** (bluetooth classico AAC + bluetooth 5 LE). Se l'iPhone ci suona dentro, il **volume dell'iPhone muove la manopola motorizzata** dell'OB-4 e il tasto play dell'OB-4 manda play/pausa/avanti/indietro all'iPhone. Questo funziona già oggi, senza scrivere niente.
3. 🔎 Esiste un **canale nascosto in bluetooth LE** (quello che usa l'app orthoplay): TEKit l'ha estratto dal codice dell'app. Comandi: play, pausa, volume, **cambio sorgente** (linea / bluetooth / radio / disk), **frequenza FM**, nome, «knock knock», due parametri dell'**ambient**, batteria, stato. È codice di un solo commit, **mai dichiarato provato sull'OB-4**, e la parte di collegamento è incompleta ❓.
4. 🔎 In quel canale **non c'è** niente per le «magie»: registrare un loop, salvarlo, riavvolgere il nastro, cambiare velocità, metronomo, rumore, timer. Quelle si fanno **solo con le mani** sulla cassa (tasti input + play, manopole). Per Giampiero vuol dire: le fa Ele.
5. 📄 Il loop dell'OB-4 va **a orecchio, non a clock**: il «beat match» ascolta la musica e trova da solo i battiti (acceso di serie, sul display «auto» o «raw»). Se Bobina fa suonare TP-7 / OP-Z / TX-6 dentro l'OB-4, il loop si mette a tempo con quello che sente, non con un segnale.
6. 📄 Uso più realistico e utile subito: l'OB-4 come **cassa del banco** (ingresso jack, 5 ms di ritardo 🔎 F-21742) con il **nastro di 2 ore** che registra sempre tutto. In Bobina al massimo una pagina «OB-4» con 6-8 tasti grandi (sorgente, play/pausa, volume, radio preferite, ambient), costruita sul canale nascosto **dopo** averlo provato.

## 1. Cos'è, in numeri 📄 P

| cosa | valore |
|---|---|
| bluetooth | classico (AAC) + 5 LE |
| wi-fi | non nelle specifiche ❓ (vedi §9, la guida dell'app dice «stessa rete wi-fi») |
| ingressi | jack 3,5 mm stereo, livello linea (2,8 Vpp = 0 dBFS); cavo a **3 poli**, non 2 o 4 📄 G |
| uscite | nessuna |
| USB | **nessuna porta** 📄 P, G; 🔎 IFX non la trova nemmeno dentro |
| casse | 2 + 2, 2 × 38 W classe D, 52-25000 Hz |
| batteria | FM volume normale 72 ore; bluetooth volume alto 8 ore 📄. Carica 1-2 ore la prima volta 📄 G |
| nastro | registrazione continua di **2 ore** 📄 |
| peso | 1,7 kg, 232,5 × 284 × 57,5 mm |

## 2. I comandi sulla cassa 📄 G

| comando | cosa fa |
|---|---|
| **input** | cambia sorgente; tenuto = «shift» per le funzioni magiche |
| **play** | bluetooth: play/pausa, 2 tocchi = traccia dopo, 3 tocchi = traccia prima. Radio: cerca la stazione dopo |
| **volume** | volume e accensione; **motorizzata, si muove da sola** se il volume cambia in bluetooth |
| **tape** (rotella) | riavvolge / manda avanti il nastro; in disk regola tempo, timer, suono |
| tenere input all'accensione | **P1 mode**: meno bassi, voce più chiara (radio parlata) |
| inclinare la cassa | il display mostra la batteria |

## 3. Le quattro sorgenti 📄 G

| sorgente | cosa c'è da sapere |
|---|---|
| **line-in** | per OP-1, OP-Z, pocket operator. Abbassare il volume prima di collegare. Led rosso che lampeggia = il segnale satura, abbassa la sorgente |
| **bluetooth** | led blu lampeggiante = pronto ad accoppiarsi, fisso = collegato. Di serie **un telefono alla volta**; con orthoplay si mette «party mode»: due collegati, se uno suona l'altro va in pausa |
| **radio FM** | play = stazione dopo; input + play = stazione prima; tieni play, aspetta che la rotella si fermi e girala = sintonia fine. Mostra frequenza e nome (RDS). 🔎 F-20256: dal 2021 si ricorda la stazione |
| **disk** | modo «sperimentale» per rilassarsi; si tiene premuto play per passare da una funzione all'altra (§5) |

## 4. Il nastro e il loop (le «magie») 📄 G

Tutte funzionano su line-in, bluetooth e radio. Tutte si fanno **con le mani**.

| funzione | come | note |
|---|---|---|
| **scrub** | girare la rotella tape avanti/indietro | il nastro intanto continua a registrare; play = torna al tempo reale |
| **velocità** | input + manopola volume | sinistra tutto = riavvolge, destra tutto = avanti veloce; lasci input = la velocità resta; display «+1.0x» |
| **registra loop** | tieni input + play; il loop inizia quando li tieni e finisce quando li lasci | |
| **lunghezza** | in loop: input + volume | divide o moltiplica la lunghezza |
| **sposta** | in loop: play + volume | sposta il loop sul nastro, **a tempo** |
| **velocità del loop** | input + play tenuti + volume | |
| **esci** | play (ancora play = tempo reale) | |
| **salva** | tieni input + play finché compare «save» | si ritrovano in disk → loop. 🔎 F-20256 / EN: **al massimo 70**, il 71° cancella il primo |
| **beat match** | tocco veloce input + play con un loop attivo | analizza la musica e trova i battiti; resta come l'hai lasciato; display «auto» / «raw» |

❓ Quanto dura al massimo un loop, e se il beat match dà un numero di bpm leggibile da qualche parte: nessuno lo scrive.

## 5. Disk mode 📄 G

| # | funzione | cosa fa | comandi |
|---|---|---|---|
| 1 | **ambient** | trasforma qualsiasi sorgente in un paesaggio sonoro | rotella = timer di spegnimento, poi = suono; input + rotella = miscela; tieni input = cambia sorgente. **Scorciatoia: tieni play su line-in / bt / radio** = ambient subito; input + play = lo spegne |
| 2 | **karma** | «scatola dei mantra»; play = mantra dopo | nell'OB-4 Off-White al suo posto la musica gyil di SK Kakraba; nell'edizione «mind games» gli album di John Lennon |
| 3 | **metronomo** | rotella = tempo, il display mostra i bpm; play = set di suoni dopo | input + rotella = intonazione dell'808, input + play = decadimento. 🔎 F-20256: kick 808 aggiunto nel 2021 |
| 4 | **noise** | rumore bianco / rosa / marrone con «onde» | rotella = timer, poi forza delle onde; input + rotella = distanza fra le onde; play = tipo di rumore |
| 5 | **loop** | i loop salvati | play = scegli; input + volume = dividi la lunghezza |

❓ Il metronomo: da quanti a quanti bpm, se tiene i decimali, se esce qualcosa (no, non ha uscite: è solo suono dalla cassa).

## 6. MIDI: la risposta corta è no

- 📄 G e P: **nessuna parola su MIDI**, clock, sync, USB audio. L'unico «sync» è il beat match, che è ascolto.
- 📄 L'OB-4 non ha porte dati: niente USB, niente jack sync. Il jack è solo ingresso audio.
- 🔎 TEK mette l'OB-4 nella tabella «BLE, USB · Serial», insieme all'OP-Z. Ma il trasporto USB di TEKit è **CoreMIDI su Mac**, e l'OB-4 una porta USB non ce l'ha: quasi certamente è una riga copiata dall'OP-Z (stessa piattaforma software di TE) ❓. Anche le costanti di aggiornamento firmware (DFU) elencano modi «disk / cdc / midi / ble»: sono comuni a tutte le macchine TE, non vuol dire che l'OB-4 parli MIDI.
- 🔎 TEK cerca le macchine anche sul servizio bluetooth MIDI standard (03B80E5A…), ma **l'OB-4 lo riconosce da un altro segnale** (byte del costruttore, variante 0x01 «ricavato dall'osservazione»). Nessuna fonte dice che l'OB-4 si presenti come dispositivo MIDI bluetooth ❓ (si verifica in 1 minuto con un'app che elenca i servizi bluetooth, §12).
- 🔎 Forum (op-forums, Elektronauts, ricerca 2/10/2026): **nessuno** chiede o racconta un OB-4 a tempo via MIDI.
- 📄 OR: l'**ortho remote** (la manopola telecomando di TE) **sì** ha un modo MIDI bluetooth, ma per Mac (Audio MIDI Setup). Con l'OB-4 fa solo: tocco = play/pausa, 2 = avanti, 3 = indietro, giro = volume.

## 7. Bluetooth «normale» (funziona già oggi)

| cosa | come | fonte |
|---|---|---|
| suonare l'iPhone nell'OB-4 | accoppiamento normale da Impostazioni → Bluetooth | 📄 G |
| volume dall'iPhone | tasti volume / Centro di Controllo / Siri: la manopola dell'OB-4 **gira da sola** | 📄 G «reacts to adjustments made over bluetooth» |
| play / pausa / avanti / indietro | dal tasto play dell'OB-4 verso l'iPhone (AVRCP) | 📄 G descrive i tocchi; ❓ AVRCP non nominato ma è l'unico modo |
| passare da solo al bluetooth | «bluetooth auto-switch» in orthoplay: se il telefono suona, l'OB-4 passa al bluetooth | 📄 G |
| due telefoni | «party mode» in orthoplay | 📄 G |

Cosa vuol dire per Giampiero, senza toccare la cassa:
- ❓ (dedotto) **Siri**: «Ehi Siri, volume al 30 %», «pausa», «canzone successiva» agiscono sull'iPhone e quindi sull'OB-4 quando la sorgente è bluetooth.
- ❓ (dedotto) **Comandi rapidi**: le azioni «Riproduci/Pausa», «Imposta volume», «Salta» funzionano sull'audio dell'iPhone, quindi anche sull'OB-4. Si possono richiamare con Controllo Vocale o con Siri.
- ❓ (dedotto) **Bobina**: se Bobina diventa l'app che «sta suonando» (Now Playing), il tasto play dell'OB-4 o l'ortho remote in mano a Ele arrivano a Bobina come play/pausa/avanti/indietro. Può servire a Ele, non a Giampiero.
- 📄 Limite: in **line-in, radio e disk** il bluetooth audio non c'entra: volume sì (se resta collegato ❓), play/pausa no.

## 8. Il canale nascosto dell'app orthoplay (bluetooth LE) 🔎 TEK

Tutto da TEKit, che scrive «estratto da orthoplay.js SERIAL_DEFINES_ORTHOPLAY». Quindi i numeri vengono dall'app ufficiale, ma **nessuno dice di averli mandati a un OB-4 vero** ❓.

**Come ci si collega** 🔎: servizio bluetooth LE `10a6e10a-6e00-4de3-abba-dabbad000000`, caratteristica `c1832aeb-6409-4b97-9575-208525a8213b` (versione vecchia `…dabbadeeeeee`). Messaggio = 1 byte di instradamento + 1 byte di comando + dati. Le azioni dall'app usano comando `0x58` («user action»), le risposte della cassa `0x59` («user event»).

⚠️ In TEKit la funzione che collega la cassa al suo canale (`findTransport`) **restituisce sempre nulla** («in real usage, device manager would track this»): così com'è la libreria non si collega davvero. Va presa come mappa, non come codice pronto.

### Cosa si può mandare

| azione | byte | dati | per Bobina |
|---|---|---|---|
| play | `01` | — | sì |
| pausa | `02` | — | sì |
| play/pausa | `03` | — | sì |
| traccia prima / dopo | `04` / `05` | — | in radio forse = stazione ❓ |
| **volume** | `06` | volume (0-255? ❓), colore | sì |
| «sono collegato» / chiedi stato | `07` | — | sì, all'avvio |
| **cambia sorgente** | `08` | linea `F0`, bluetooth `F1`, FM `F2`, disk `F3` | sì |
| calibra motore | `09` | volume `F4`, scrub `F5` | no |
| **knock knock** (suono «dove sei?») | `0A` | — | sì, per provare il collegamento |
| nome | `0B` | fino a 16 caratteri | no |
| motore acceso/spento | `0C` | `03` acceso / `18` spento, quale motore | ❓ forse utile: manopola che non gira |
| bluetooth auto-switch | `0D` | acceso/spento | una volta |
| **parametro** | `0E` | `01` = ambient «wetness», `02` = ambient «primary», valore 0-255 ❓ | sì, per l'ambient |
| «clickmix» | `0F` | acceso/spento | ❓ nessuno sa cos'è |
| **frequenza FM** | `10` | 2 byte (unità ❓: il README scrive 91.1, la funzione vuole un intero, forse 9110) | sì, «radio preferite» |
| modo bluetooth | `11` | semplice `99`, party `19` | una volta |

Altri messaggi 🔎: batteria (`5E` → livello + in carica + spina), metadati (`09`), lista dei telefoni accoppiati e «dimentica» (`75`), aggiornamento firmware (`0D`, da **non** toccare).

### Cosa racconta la cassa (utile per lo schermo di Bobina)

Stato play/pausa, sorgente e funzione disk attiva (karma `F3`, ambient `F4`, metronomo `F5`, noise `F6`, loop `F7`), volume, titolo/artista/album e durata del brano bluetooth, posizione, **frequenza e nome della stazione FM**, nome, valori ambient, batteria.

### Cosa NON c'è

Registrare / salvare / scegliere un loop, scrub, velocità, beat match, scegliere la funzione disk (si sceglie solo «disk»), tempo del metronomo, tipo di rumore, timer, P1 mode. ❓ Forse esistono nel firmware ma l'app non li usa, quindi non sono nella lista.

## 9. L'app orthoplay e l'aggiornamento

- 📄 G: orthoplay serve a comandare l'OB-4 a distanza e ad **aggiornarne il sistema**. Fa: volume (con colore), play/pausa, cambio sorgente, avanti/indietro (anche ricerca FM), nome, knock knock, batteria, auto-switch, modo bluetooth, numero di serie, versione, **update**, registrazione.
- 📄 G: «bluetooth acceso e telefono **sulla stessa rete wi-fi** delle casse». Ma 📄 P non elenca il wi-fi tra le specifiche, e 🔎 TEK parla con l'OB-4 solo in bluetooth LE. Probabile frase rimasta dall'OD-11 (che è wi-fi) ❓.
- 📄 APP: versione **3.1.8 del 1/11/2025**, iOS 11 o successivo, 12 MB, **solo inglese**, «lo sviluppatore non ha ancora indicato quali funzioni di accessibilità supporta». Nessuna traccia di Siri o Comandi rapidi.
- 📄 G: l'unico modo di aggiornare il firmware è **dall'app** («tap here to update the speaker»). Niente programma da computer.
- 🔎 F-21742 (Jacob di TE, 29/3/2022): sintonia fine FM, ritardo line-in → cassa **5 ms**, audio migliore. 🔎 F-21742: 1.4.11 (10/7/2022) solo correzioni.
- ❓ App e Bobina sullo stesso iPhone: il bluetooth LE di solito accetta **un'app collegata alla volta**. Va provato se orthoplay aperta blocca Bobina e viceversa.

## 10. Cosa vorrebbe dire metterlo in Bobina

| idea | come | lavoro | quanto è sicuro |
|---|---|---|---|
| **OB-4 cassa del banco** | Ele collega una volta l'uscita di TP-7 / OP-Z / TX-6 al jack dell'OB-4 | zero codice | 📄 |
| **Volume da Bobina** | se l'OB-4 è in bluetooth: volume di sistema dell'iPhone. Altrimenti canale nascosto `06` | basso | 📄 / 🔎 |
| **Pagina OB-4**: sorgente, play/pausa, volume ±, knock knock, batteria | canale nascosto (§8) | medio, prima va provato | 🔎 + ❓ |
| **Radio preferite** (3-4 tasti con il nome della stazione) | `10` frequenza FM + lettura del nome RDS | basso dopo la pagina | 🔎 + ❓ unità |
| **Ambient a voce** | non si può accendere direttamente: `08 F3` porta in disk, ma la funzione la sceglie il tasto play ❓. I due parametri ambient (`0E`) si regolano | ❓ | 🔎 |
| **Loop a tempo con Bobina** | **non si può**: nessun clock. Al massimo Bobina suona a un tempo fisso e il beat match dell'OB-4 lo segue a orecchio | — | 📄 |
| **Riavvolgere il nastro / registrare un loop da Bobina** | **non si può** con quello che si sa | — | 🔎 |
| **Metronomo a tempo di Bobina** | **non si può**: il tempo si cambia solo con la rotella | — | 🔎 |

## 11. Idee per chi non usa le mani

1. **Il nastro come «ripeti quello che ho perso»**: l'OB-4 registra sempre 2 ore. Ele riavvolge con la rotella quando Giampiero dice «indietro»; è un gesto, nessun menu.
2. **Una sola sorgente fissa**: con «bluetooth auto-switch» acceso (una volta, da orthoplay) l'OB-4 passa da solo al bluetooth appena l'iPhone suona. Così Siri / Controllo Vocale bastano per volume e pausa.
3. **Comandi rapidi con nomi corti** («cassa piano», «cassa forte», «cassa pausa») che impostano il volume dell'iPhone: con Controllo Vocale si dicono per nome, senza griglia.
4. **Rumore e ambient per la sera**: il timer di spegnimento si mette con la rotella (Ele, una volta); da Bobina al massimo volume e sorgente.
5. **Knock knock come prova**: un tasto in Bobina che fa bussare la cassa dice subito se il collegamento bluetooth LE funziona, senza guardare schermi.

## 12. Dove le fonti non sono d'accordo

1. **Wi-fi**: la guida dell'app lo chiede, le specifiche non lo elencano, TEKit non lo usa.
2. **USB**: TEKit scrive «BLE, USB» per l'OB-4; guida, specifiche e smontaggio non mostrano nessuna porta USB.
3. **Batteria**: 📄 P 72 ore FM / 8 ore bluetooth forte; 🔎 negozi (Amazon UK) «40 ore» in media.
4. **Data di TEKit**: il commit dice 30/3/2026, OPZ-RICERCA scrive 31/3/2026 (fuso orario).
5. **Volume in TEKit**: il README mostra `setVolume(0.75)`, la funzione vuole un intero 0-255. Idem FM: `91.1` contro intero a 16 bit.

## 13. Da misurare noi

1. Con un'app che elenca i servizi bluetooth (es. LightBlue o nRF Connect, gratis): l'OB-4 mostra il servizio `10a6e10a…` e la caratteristica `c1832aeb…`? Mostra anche il servizio MIDI `03B80E5A…`? (risposta definitiva sul MIDI bluetooth)
2. Il canale nascosto risponde senza accoppiamento? Serve il led blu lampeggiante? Funziona mentre l'OB-4 è in line-in o radio?
3. Mandare `knock knock` (`0A`), poi play/pausa, poi `08 F2` (radio): la cassa obbedisce?
4. Volume `06`: da 0 a quanto? La manopola gira davvero?
5. Frequenza `10`: che unità (9110, 911 o 91100 per 91,1 MHz)?
6. Orthoplay aperta e Bobina insieme: si rubano il collegamento?
7. Volume dell'iPhone → manopola: succede anche quando la sorgente è line-in?
8. Metronomo: da quanti a quanti bpm; il beat match legge bene un TP-7 / OP-Z a 90 e 120 bpm?
9. Versione firmware attuale sull'OB-4 di Giampiero (orthoplay → more options → software version) e se c'è un aggiornamento.
10. Con «party mode»: iPhone di Giampiero + telefono di Ele insieme, chi vince?
