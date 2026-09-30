# Pocket Operator e l'adattatore MIDI di Hanz Tech — cosa si sa

Ricerca del 29/9/2026. Ogni riga dice da dove viene:

- 📄 **documentato**: wiki, pagina del prodotto, guida teenage engineering
- 🔎 **letto nel codice**: firmware 3.4.3 su GitHub (Teensy) e 3.4.0 (ESP32, bluetooth)
- 📏 **misurato**: provato con la macchina vera (vedi `PROVE-PO.md`)
- ❓ **da misurare**

Fonti: [hanztechnology.com](https://hanztechnology.com/products/pocket-operator-midi-adapter-v3) ·
[firmware V3](https://github.com/Hanz-Tech/midi-adapter-v3-software) e la sua [wiki](https://github.com/Hanz-Tech/midi-adapter-v3-software/wiki) ·
[firmware V2](https://github.com/Hanz-Tech/midi-adapter-software) ·
[schemi V3](https://github.com/Hanz-Tech/midi-adapter-v3-hardware) ·
[configuratore web](https://github.com/Hanz-Tech/poma-web-configurator) ·
[Tindie](https://www.tindie.com/products/hanztech/pocket-operator-midi-adapter-v3/).

## L'adattatore

- 📄 Due schede impilate e una mascherina stampata in 3D. La scheda di sopra ha dei **pogo pin** che toccano i contatti dei tasti del PO: niente saldature. Copre tutti i 23 tasti; il display e le due manopole restano liberi.
- 📄 **Le manopole A e B non si comandano via MIDI.** Il resto sì: tutti i 23 tasti.
- 📄 Va bene per **tutte e tre le serie** di PO (1x, 2x, 3x). Per le vecchie 1x e 2x esiste una scheda di sopra diversa con due fermi laterali. L'allineamento dei pin è la causa di quasi tutti i problemi: se un tasto non risponde, si sposta la mascherina.
- 🔎 Versioni:
  - **V2**: Teensy 4.1, firmware 2.4.x. **Niente bluetooth.**
  - **V3**: Teensy 4.1 + un ESP32-C3 che fa solo da ponte bluetooth. Firmware 3.4.3 (Teensy), 3.4.0 (ESP32). 105 $. Su Tindie esaurito dal 16/3/2025.
  - Nel GitHub c'è anche un «v5» su RP2040, senza manuale: un prototipo.
- 📄 Prese della V3:
  - **micro USB**: alimentazione, e verso un computer (o un telefono) compare come **«Teensy MIDI»**;
  - **USB host**: ci si attaccano controller MIDI, massimo 100-150 mA (per di più serve un hub alimentato);
  - **MIDI DIN** in e out, **TRS 3,5 mm tipo A** in e out (nella scatola due convertitori A/B);
  - **bluetooth MIDI**: acceso con `ble_midi_enabled = 1`. La wiki dice «PO_MIDI_ADAPTER(BLE)»; 📏 sull'iPhone compare come **«PO MIDI Adapter (BLE) Bluetooth»**, e due adattatori si chiamano uguale (30/9/2026);
  - **sync out** 3,5 mm: il clock MIDI diventa impulsi per il PO.
- 📄 Consumo col bluetooth acceso 150-200 mA: non si può alimentare da un OP-Z.
- 📄 Le impostazioni si cambiano col **configuratore web** (Chrome, [pomawebconfig.hanztechnology.com](https://pomawebconfig.hanztechnology.com/)) oppure col file `config.cfg` sulla microSD. Se c'è la microSD vince lei. 🔎 Il configuratore parla col Teensy sulla porta seriale USB (115200, comandi JSON `READALL` e `SAVEALL`): **dal bluetooth e dal MIDI non si configura niente.**

## La mappa MIDI

🔎 Canale **1** (`po_midi_channel`). Contano solo **Note On e Note Off**: Note On = tasto giù, Note Off = tasto su. La velocity non conta. Finché la nota resta accesa, il tasto resta premuto.

**Le combinazioni si fanno sovrapponendo le note**: per `pattern + 5` si accende la nota di pattern, poi quella del 5, poi si spengono. È così che fa anche il firmware per le sue combinazioni: 20 ms fra un passo e l'altro.

| tasto | nota | | tasto | nota | | tasto | nota | | tasto | nota |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 68 | | 2 | 69 | | 3 | 70 | | 4 | 71 |
| 5 | 72 | | 6 | 73 | | 7 | 74 | | 8 | 75 |
| 9 | 60 | | 10 | 61 | | 11 | 62 | | 12 | 63 |
| 13 | 64 | | 14 | 65 | | 15 | 66 | | 16 | 67 |

| tasto | nota |
|---|---|
| sound | 76 |
| pattern | 77 |
| play | 78 |
| il tasto in alto a destra (record · acc · style) | 79 |
| fx | 80 |
| bpm | 81 |
| write | 82 |

- 📄 Le due file basse (9-16) sono 60-67 e le due alte (1-8) 68-75: così sui 16 pad di una Beatstep Pro la fila di sotto suona la metà di sotto del PO.
- 📄 Il modello «OP-Z» del file (`config_opz.cfg`) usa altre note e il canale 14: non ci riguarda.
- 🔎 Note Off vero (0x80). ❓ Se un Note On con velocity 0 viene preso come rilascio: Bobina manda sempre 0x80.
- ❓ **Quanto dev'essere lungo un tocco** perché il PO lo senta. Il firmware tiene i suoi a 20 ms: Bobina parte da 30 ms.

### Registrazione a un tasto e looper (solo PO-33, in prova)

- 📄🔎 `midi_note_record_1` … `_16` (di serie 48, poi 10-24): un Note On preme record + il tasto, il successivo rilascia. 🔎 Mentre registra, **qualunque** Note On sul canale del PO ferma la registrazione.
- 📄🔎 Looper (tracce 1-8): finita la registrazione rilancia il campione a ogni giro premendo il tasto **5**. Nota 49 = avvia/ferma, 50 = cancella (preme sound, il tasto, record…: cancella il campione vero).

### Modalità a CC (spenta di serie)

🔎 Con `po_cc_control = 1` (dal configuratore) arrivano tre scorciatoie: **un solo messaggio al posto di quattro**, perché la combinazione la fa il Teensy, 20 ms per passo.

| CC | valore | fa |
|---|---|---|
| 10 | 0-15 | sound + tasto 1-16 |
| 11 | 0-15 | pattern + tasto 1-16 |
| 12 | 0-15 | bpm + tasto 1-16 (volume) |
| quello di `midi_cc_knob_9` | 0-4 | cambia cosa fanno le note (0 = normale, 1 = i 16 pad diventano i tasti funzione, 2 = fx tenuto, 3 = tasto in alto tenuto, 4 = write acceso) |

- 🔎 Con valori sopra 15 il firmware legge fuori dalla sua tabella: non mandarli mai.
- 🔎 In modalità 0 (quella di partenza) le note funzionano come sempre: accendere il CC non rompe niente.
- Col bluetooth conta: un cambio di pattern a tempo diventa un pacchetto invece di quattro.

## Trasporto, clock e sync out

- 🔎 Clock (0xF8), start, continue e stop arrivano da qualunque ingresso e passano a tutte le uscite.
- 🔎 `disable_transport = 1` (di serie): start e stop passano ma **non toccano il PO**.
  Con `disable_transport = 0`: start o continue premono play se l'adattatore crede che il PO sia fermo; stop lo ripreme se crede che suoni. Lo stato lo tiene l'adattatore (cambia anche quando play arriva come nota): ❓ se si sfasa.
- 🔎 **Sync out**: con `sync_out_enabled = 1` **e** `disable_transport = 0`. L'adattatore misura il bpm dal clock ogni battito (media degli ultimi quattro) e manda **2 impulsi per quarto** da 6 ms, finché non arriva lo stop.
- 🔎 **Gli impulsi non sono agganciati al clock**: l'adattatore ne ricava il bpm e poi va da solo, con un intervallo arrotondato al millisecondo. Ai tempi dove 30 000 / bpm non è intero il PO scivola piano piano. Esempio: 128 bpm → 234,375 ms diventa 235 → lo 0,27 % più lento, circa 0,16 s al minuto. ❓ Da misurare.
  Tempi senza scivolamento: **60, 75, 80, 100, 120, 125, 150, 200, 240, 250, 300**.
- 🔎 Il bpm si aggiorna una volta a battito: i cambi di tempo arrivano con un battito di ritardo.

## Cosa manda indietro

- 🔎 **Niente di suo.** I pin che toccano il PO sono solo uscite: l'adattatore non sa cosa c'è sul display, non sa se il PO suona, non sa quale pattern è acceso.
- 🔎 È anche un **smistatore**: quello che arriva dal bluetooth esce da DIN, TRS, USB e USB host. Note, CC, start e stop tornano **anche indietro sul bluetooth** (un'eco); il clock no.
  Per Bobina non è un problema: ogni sezione ascolta solo la sua porta.
- 🔎 Una nota che arriva su un canale diverso da quello del PO non preme niente ma passa lo stesso alle uscite: dal TRS out si può suonare un'altra macchina (una Volca) sullo stesso bluetooth.

## Per ogni PO

I tasti e le combinazioni sono nel prontuario (`static/pocket-operator/`): PO-14 sub, PO-32 tonic, PO-33 K.O!, PO-35 speak. Via MIDI si fa tutto quello che usa **solo tasti**:

- scegliere suoni e pattern, catene di pattern, scrivere e cancellare step, effetti (fx + tasto), accenti (tonic), stili (sub), muti (tonic: tieni il tasto; speak: sound + tasto), campionare (K.O! e speak: record + tasto, dal microfono o dal line in), copiare, cancellare;
- volume: bpm + 1-16;
- i tre tempi preset: bpm da solo (80 · 120 · 140);
- il modo di sync: tasto in alto + bpm, da SY0 a SY5.

Non si fa: tutto quello che vuole A o B. Quindi **niente tempo fine** (bpm + B), niente swing, niente parameter lock, niente nota o lunghezza di uno step, niente pagine delle manopole. Niente reset (vuole le pile).

**Quindi il tempo del PO via MIDI è solo 80, 120 o 140**, oppure quello che gli arriva dal sync.

❓ Sul PO-32 tonic il prontuario dice che fuori dalla scrittura i tasti suonano il suono selezionato; su altri PO della serie ogni tasto suona il suo suono. Da guardare: cambia come Bobina lo suona dal vivo.

## Il sync fra macchine (documentato)

- 📄 PO: 2 impulsi per quarto sul canale **sinistro** dell'ingresso. Tasto in alto + bpm cicla SY0-SY5. Per ricevere il sync: **SY2** (entra solo sync, esce stereo).
  **Non SY4 o SY5 col TX-6**: lì il PO mescola all'uscita anche il canale destro dell'ingresso, cioè l'audio che il TX-6 manda con il sync8. Se il PO entra nel TX-6 si fa un giro chiuso.
- 📄 TX-6: aux o cue, **shift + gira select** → sync 8 (sinistro = impulsi, destro = audio) o sync 16. Sync 8 è quello dei PO. Aux esce più forte di cue (8 dBu contro 2).
  ❓ Se il TX-6 manda gli impulsi solo quando va il suo clock, e se il PO parte in battere.

## Tre modi per stare a tempo con TX-6 e TP-7

1. **Bobina suona il PO dal vivo.** Il PO resta fermo, il sequencer di Bobina preme i tasti al momento giusto. Il tempo è quello di Bobina, lo stesso del TX-6. Serve solo il bluetooth. Errore: quello del bluetooth, qualche millisecondo (❓).
2. **Il PO va col suo pattern, a tempo col TX-6.** Cavo dall'aux del TX-6 (sync 8) all'ingresso del PO (SY2). Bobina dà il tempo al TX-6 e al PO manda solo i tasti: pattern, effetti, muti. È la strada più precisa. Si può fare anche col sync out dell'adattatore, ma serve il clock sul bluetooth (48 messaggi al secondo in più) e c'è lo scivolamento visto sopra.
3. **Bobina dà il clock all'adattatore**, e l'adattatore fa gli impulsi. Per quando il TX-6 non c'è.

## Programmi della community

- Hanz: il [controller a nastro](https://github.com/Hanz-Tech/po-midi-ribbon-controller) (terzo al concorso #po10diy di teenage engineering, con un PO-28), un [looper in Python](https://github.com/Hanz-Tech/midi-adapter-software/tree/v2/looper) per Beatstep Pro, il profilo Beatstep Pro.
- Nessuna app per iPhone fatta apposta per l'adattatore: qualunque app che manda note sul canale 1 lo suona.
- Per il sync esistono app che fanno gli impulsi dall'uscita audio del telefono (PO LoopSync e simili): una quarta strada, non serve l'adattatore.
