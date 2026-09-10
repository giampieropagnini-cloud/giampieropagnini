# Mac mini M2 senza monitor: si collega da solo all'Apple TV

Oggi fai così: accendi il Mac mini M2, scrivi la password alla cieca, accendi l'iPad con Duet
per vedere qualcosa, e da lì mandi lo schermo all'Apple TV.

Con questa cosa installata, fai così: accendi il Mac mini M2, scrivi la password alla cieca,
aspetti un minuto, **e la TV si accende da sola con lo schermo del Mac**. L'iPad non serve più.

Funziona con un piccolo programma, **AirPlay Automatico**, che a ogni accensione fa al posto tuo
i clic su Centro di Controllo → Duplica schermo → nome dell'Apple TV.

> Va installato **sul Mac mini M2**, quello senza monitor. Non sul Mac mini M4 su cui lavori
> di solito: lì c'è solo la cartella con i file.

---

## Cosa ti serve (una volta sola)

- il Mac mini M2 acceso **con l'iPad e Duet collegati**, così vedi lo schermo durante l'installazione
- l'Apple TV accesa e sulla stessa rete Wi‑Fi del Mac
- 5 minuti

---

## Installazione (una volta sola, sul Mac mini M2)

### 1. Porta i file sul Mac mini M2 e avvia l'installazione

**Modo A, il più semplice: una riga nel Terminale.**
Sul Mac mini M2 apri il Terminale (**cmd + spazio**, scrivi `Terminale`, Invio), poi scrivi questa
riga e premi Invio:

```
curl -fsSL https://giampieropagnini.com/airplay/installa.sh | bash
```

Scarica da solo i file sulla Scrivania, in una cartella `MAC-MINI-AIRPLAY`, e fa partire
subito l'installazione guidata. Poi vai al punto 2.

> Se sui due Mac usi lo stesso account iCloud, puoi copiare la riga qui sull'M4 (cmd + C)
> e incollarla sul Mac mini M2 (cmd + V): gli appunti passano da un Mac all'altro da soli.
>
> La riga corta funziona da quando questo aggiornamento è online sul sito. Finché non lo è,
> usa questa riga più lunga, che prende i file direttamente da GitHub (stesso risultato):
>
> ```
> curl -fsSL https://raw.githubusercontent.com/giampieropagnini-cloud/giampieropagnini/claude/mac-mini-airplay-monitor-zk2qhc/MAC-MINI-AIRPLAY/installa.sh | bash
> ```

**Modo B: AirDrop.**
Sul Mac mini M4, nella cartella del sito, clic destro sulla cartella `MAC-MINI-AIRPLAY` →
**Condividi** → **AirDrop** → scegli il Mac mini M2. Sull'M2 la cartella arriva in *Download*.
Aprila e fai doppio clic su `INSTALLA AIRPLAY AUTOMATICO.command`.

> Se macOS dice che "non può essere aperto perché proviene da uno sviluppatore non identificato":
> clic destro sul file → **Apri** → **Apri**.

Nella cartella trovi:

| File | A cosa serve |
|---|---|
| `INSTALLA AIRPLAY AUTOMATICO.command` | **l'installatore** (è quello da aprire nel modo B) |
| `RIMUOVI AIRPLAY AUTOMATICO.command` | per togliere tutto, se un giorno non lo vuoi più |
| `installa.sh` | quello che scarica e avvia tutto nel modo A |
| `airplay-automatico.applescript` | lo script vero e proprio (non serve toccarlo) |
| `avvio-app.applescript` | l'involucro dell'app (non serve toccarlo) |

### 2. Rispondi alle domande dell'installatore
- **Quale Apple TV?** Ti mostra le Apple TV che trova in casa: scrivi il numero e premi Invio.
  Se non la trova (per esempio è spenta), scrivi il nome a mano, uguale a come lo vedi in *Duplica schermo*.
- Se macOS chiede **«Il Terminale vuole controllare System Events»** → clicca **OK**.
- Se macOS chiede se il Terminale può **cercare dispositivi sulla rete locale** → **Consenti**.

### 3. Dai i permessi ad AirPlay Automatico (solo la prima volta)
Alla fine l'installatore apre l'app. Possono comparire due avvisi:

| Avviso | Cosa fare |
|---|---|
| «AirPlay Automatico vuole controllare **System Events**» | clicca **OK** |
| «AirPlay Automatico vuole controllare il computer con le funzioni di **Accessibilità**» | clicca **Apri Impostazioni di Sistema**, poi **attiva l'interruttore** accanto a *AirPlay Automatico* (se non c'è nell'elenco: premi **+** e scegli l'app nella cartella *Applicazioni*) |

Poi torna nella finestra nera e premi Invio: l'app fa subito una prova e la TV dovrebbe accendersi
con lo schermo del Mac.

### 4. Fatto
Chiudi la finestra. Da adesso parte da sola a ogni accensione del Mac mini M2.

---

## Poi, ogni giorno

1. Accendi il Mac mini M2.
2. Scrivi la password alla cieca e premi Invio (come fai già oggi).
3. Aspetta circa un minuto: la TV si accende con lo schermo del Mac.

L'iPad con Duet lo puoi sempre usare come prima, se ti serve.

Per fare una prova senza riavviare: **cmd + spazio**, scrivi `AirPlay Automatico`, Invio.

---

## Facoltativo: niente più password all'accensione

Se vuoi che il Mac mini M2 si accenda e vada direttamente alla scrivania, senza scrivere la password:

**Impostazioni di Sistema → Utenti e gruppi → Accedi automaticamente** → scegli il tuo nome →
scrivi la password una volta. Da lì in poi basta premere il tasto di accensione.

⚠️ Se la voce **Accedi automaticamente** è grigia o dice "non disponibile", è perché
**FileVault** (la cifratura del disco) è acceso: con FileVault acceso l'accesso automatico non
esiste. L'installatore te lo dice alla fine. Per spegnerlo:
**Impostazioni di Sistema → Privacy e sicurezza → FileVault → Disattiva**, poi aspetta che finisca
(può volerci un po') e torna a *Utenti e gruppi*.
Spegnere FileVault vuol dire che chi ha in mano il Mac può leggere quello che c'è dentro: per un
Mac che sta in casa e serve per la musica va bene, ma decidi tu.

---

## Se non funziona

Controlla nell'ordine:

1. **L'Apple TV è accesa e sulla stessa rete del Mac?** Con l'iPad, prova a collegarla a mano
   come facevi prima: se non funziona a mano, non funziona nemmeno da solo.
2. **Il nome è giusto?** Deve essere uguale a quello che vedi in *Duplica schermo*. Per cambiarlo,
   riapri `INSTALLA AIRPLAY AUTOMATICO.command` (è sulla Scrivania, nella cartella `MAC-MINI-AIRPLAY`).
3. **Ti chiede sempre il permesso di Accessibilità anche se l'interruttore è acceso?**
   Succede se manca l'altro permesso (Automazione) o se l'app è stata rifatta. Rilancia la riga del
   Terminale (o `INSTALLA AIRPLAY AUTOMATICO.command`): l'installatore rifà l'app, la firma e
   fa richiedere i permessi da capo. Quando compare «vuole avere accesso per controllare System
   Events» clicca **OK**, non «Non consentire».
4. **I due interruttori sono accesi?** Impostazioni di Sistema → Privacy e sicurezza:
   - **Accessibilità** → *AirPlay Automatico* attivo. Se era già acceso ma non funziona: selezionalo,
     premi **−** per toglierlo, poi **+** per rimetterlo.
   - **Automazione** → *AirPlay Automatico* → *System Events* attivo.
5. **Sull'Apple TV**: Impostazioni → AirPlay e HomeKit → *Richiedi codice* deve essere
   **Solo la prima volta** (o mai), altrimenti la TV chiede un codice che tu non puoi vedere sul Mac.
6. Se ancora niente, **mandami il diario**: è il file `AirPlayAutomatico.log`
   (cmd + spazio, scrivi `AirPlayAutomatico.log`, Invio). Lì c'è scritto passo per passo cosa ha
   provato a fare. Dimmi anche la versione di macOS (menu  → Informazioni su questo Mac).

Nel frattempo puoi sempre fare come prima con l'iPad.

---

## Per togliere tutto

Sul Mac mini M2, doppio clic su `RIMUOVI AIRPLAY AUTOMATICO.command`. Fine.

---

## Come funziona (se ti interessa)

- macOS non ha un'opzione "collega sempre questa Apple TV all'avvio". Però permette a un programma
  con il permesso *Accessibilità* di fare i clic al posto tuo. AirPlay Automatico fa esattamente
  questo: apre il Centro di Controllo, entra in *Duplica schermo* e clicca il nome dell'Apple TV.
- Cerca le voci **per nome**, non per posizione: così regge meglio ai cambiamenti di macOS
  (Sonoma, Sequoia, Tahoe). Se il Mac è già collegato, non tocca nulla.
- All'accensione la rete ci mette qualche secondo: se l'Apple TV non compare ancora nell'elenco,
  riprova ogni pochi secondi per circa 4 minuti, poi si arrende.
- Un Mac mini M2 senza monitor si inventa da solo uno "schermo virtuale" (1920×1080), quindi non
  serve nessun adattatore finto HDMI: l'Apple TV duplica quello schermo.
- Il programma non ha bisogno di internet, non manda niente da nessuna parte e scrive un diario in
  `~/Library/Logs/AirPlayAutomatico.log`.
- La cartella `MAC-MINI-AIRPLAY` viene pubblicata anche sul sito, all'indirizzo
  `giampieropagnini.com/airplay/`: è da lì che la riga del Terminale scarica i file.
- Non ho un Mac sotto mano per provarlo davvero: la prima prova la facciamo insieme. Se il diario
  mostra un errore, mandamelo e lo sistemo.

Riferimenti Apple: [usare AirPlay dal Mac](https://support.apple.com/guide/mac-help/mchld7e543a0/mac),
[accesso automatico e FileVault](https://support.apple.com/en-us/102316).
