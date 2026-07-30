# Come mettere online giampieropagnini.com

Guida pratica. Il dominio è già tuo (registrato il 9 febbraio 2005, pagato fino al 9 febbraio 2027).

---

## Situazione di partenza

| Cosa | Stato attuale |
|---|---|
| Dominio | `giampieropagnini.com` — tuo, scade 09/02/2027 |
| Nameserver (DNS) | `NS10.WIXDNS.NET` e `NS11.WIXDNS.NET` → **puntano ancora a Wix** |
| Dove punta ora | Server Wix (185.230.63.x) che mostra una pagina d'errore |
| Registrar tecnico | Tucows (il partner che Wix usa per i domini collegati) |
| Pannello dove lo vedi | Aruba |

**Traduzione:** il dominio è tuo, ma il "centralino" che decide dove mandare i visitatori è ancora quello di Wix. Dobbiamo spostare quel centralino.

---

## Passo 1 — Capire dove puoi modificare i DNS

Apri il pannello Aruba → **Domini** → clicca su `giampieropagnini.com`.

Cerca una voce tipo **"Gestione DNS"** / **"DNS e Nameserver"** e guarda cosa dice:

### Caso A — Aruba ti fa modificare i nameserver ✅
Vedi i nameserver attuali (quelli `WIXDNS`) e un pulsante per cambiarli.
→ **Vai al Passo 2A.** È il caso migliore: 5 minuti e sei online.

### Caso B — Aruba dice "dominio non gestito" o i campi sono bloccati
Significa che la gestione è passata davvero a Wix.
→ **Vai al Passo 2B.**

---

## Passo 2A — Modifica i DNS su Aruba

Nel pannello Aruba, sezione DNS del dominio, **sostituisci i record**:

### Se Aruba ti fa inserire i "record" (A e CNAME)

Cancella i record A esistenti e inserisci questi quattro:

| Tipo | Nome / Host | Valore |
|---|---|---|
| A | `@` (oppure vuoto) | `185.199.108.153` |
| A | `@` | `185.199.109.153` |
| A | `@` | `185.199.110.153` |
| A | `@` | `185.199.111.153` |
| CNAME | `www` | `USERNAME.github.io.` |

⚠️ `USERNAME` va sostituito col nome utente GitHub — te lo dico io appena il repository è creato.

### Se Aruba ti fa cambiare solo i "nameserver"
Usa quelli di Cloudflare (hai già un account, lo usi per yokozuna.it): aggiungi il dominio
su Cloudflare, lui ti dà due nameserver tipo `xxx.ns.cloudflare.com`, e li incolli su Aruba.
Poi i record A qui sopra li mettiamo dentro Cloudflare.

---

## Passo 2B — Se la gestione è ancora su Wix

Entra su **wix.com** con le tue credenziali → **Domini** (o Impostazioni → Domini).
Trovi `giampieropagnini.com`. Da lì hai due possibilità:

1. **Cambia i nameserver / i record DNS** dentro Wix, mettendo quelli del Passo 2A.
   Funziona subito e non costa nulla.
2. **Sposta il dominio via da Wix** (più pulito a lungo termine):
   Wix → dominio → *Trasferisci via da Wix* → sblocca il dominio e fatti mandare il
   **codice di autorizzazione** (codice EPP / auth code).
   Poi su Aruba: *Trasferisci un dominio* → inserisci il codice.
   Costa circa 12-15 € e include un anno di rinnovo. Richiede 5-7 giorni.

---

## Passo 3 — Attivare HTTPS

Una volta che i DNS puntano al posto giusto, il certificato di sicurezza (il lucchetto)
si attiva da solo e gratis. Su GitHub Pages: Settings → Pages → spunta **Enforce HTTPS**
(compare dopo qualche ora, quando il DNS si è propagato).

---

## Tempi

| Fase | Quanto ci vuole |
|---|---|
| Modifica DNS | 5 minuti |
| Propagazione in tutto il mondo | da 15 minuti a 24 ore (di solito ~1 ora) |
| Certificato HTTPS | fino a 24 ore dopo la propagazione |
| Trasferimento dominio (opzionale) | 5-7 giorni |

---

## Come verificare che ha funzionato

Dal Terminale:

```bash
dig +short giampieropagnini.com
```

Se risponde con `185.199.108.153` (e simili) invece di `185.230.63.x`, il cambio è avvenuto.

---

## Nota sul vecchio sito Wix

Finché non cambi i DNS, il vecchio indirizzo `giamps1982.wixsite.com/giampiero-pagnini`
continua a funzionare. Non cancellare l'account Wix finché il nuovo sito non è online
e verificato — poi potrai disdire l'abbonamento senza perdere nulla:
tutte le immagini originali sono già salvate in `assets/img/` sul tuo Mac.
