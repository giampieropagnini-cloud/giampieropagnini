# Collegare giampieropagnini.com — via Cloudflare

Segui nell'ordine. Fermati quando arrivi a "SCRIVIMI" e mandami un messaggio.

---

## PARTE 1 — Su Cloudflare (5 minuti)

### 1. Aggiungi il dominio
Nella pagina che ti ho aperto, scrivi:

```
giampieropagnini.com
```

e clicca **Continue** / **Add domain**.

### 2. Scegli il piano
Seleziona **Free** (gratis, in fondo alla lista) → **Continue**.

### 3. Cloudflare copia i record esistenti
Ti mostrerà i record trovati, che puntano ancora a Wix (`185.230.63.x`).
Vai avanti: li sistemiamo al passo 4.

### 4. Sistema i record ⚠️ passaggio importante

**Cancella** tutti i record di tipo **A** che puntano a `185.230.63.qualcosa`
(sono di Wix — clicca Edit → Delete su ognuno).

**Aggiungi** questi record nuovi (bottone *Add record*):

### Il sito
| Type  | Name  | IPv4 address / Target             | Proxy status        |
|-------|-------|-----------------------------------|---------------------|
| A     | `@`   | `185.199.108.153`                 | **DNS only** (grigio) |
| A     | `@`   | `185.199.109.153`                 | **DNS only** (grigio) |
| A     | `@`   | `185.199.110.153`                 | **DNS only** (grigio) |
| A     | `@`   | `185.199.111.153`                 | **DNS only** (grigio) |
| CNAME | `www` | `giampieropagnini-cloud.github.io` | **DNS only** (grigio) |

### La posta ⚠️ non dimenticarli
Il dominio aveva una casella email su Aruba. Per non perderla servono:

| Type | Name   | Valore                       | Priorità | Proxy      |
|------|--------|------------------------------|----------|------------|
| MX   | `@`    | `mail.giampieropagnini.com`  | `10`     | —          |
| A    | `mail` | `62.149.128.154`             | —        | **DNS only** |
| TXT  | `@`    | `v=spf1 include:_spf.aruba.it ~all` | — | —      |

> ⚠️ La nuvoletta accanto a ogni record deve essere **GRIGIA** ("DNS only"),
> non arancione. Se resta arancione, il certificato di sicurezza non si attiva.
> Si cambia cliccandoci sopra.

### 5. Prendi i due nameserver
Cloudflare ti mostrerà due indirizzi tipo:

```
adam.ns.cloudflare.com
kate.ns.cloudflare.com
```

**Copiali** (sono diversi per ogni account — usa quelli che vedi tu).

---

## PARTE 2 — Su Aruba (3 minuti)

### 6. Entra nel pannello
`admin.aruba.it` → **Domini** → **giampieropagnini.com**

### 7. Cambia i nameserver
Cerca **"Gestione DNS"** / **"Modifica nameserver"** / **"DNS e Nameserver"**.

Scegli l'opzione **DNS esterni** / **Nameserver personalizzati** e **sostituisci**:

| Prima (Wix)         | Dopo (Cloudflare)        |
|---------------------|--------------------------|
| `ns10.wixdns.net`   | il primo che ti ha dato Cloudflare  |
| `ns11.wixdns.net`   | il secondo che ti ha dato Cloudflare |

Salva.

---

## SCRIVIMI 📩

Appena salvato su Aruba, mandami un messaggio.

Io da qui:
- controllo che il cambio si stia propagando
- riattivo il dominio sul sito
- accendo il certificato HTTPS (il lucchetto)
- verifico che tutto risponda

---

## Cosa aspettarsi

| Quando | Cosa succede |
|---|---|
| Subito | Aruba salva; Cloudflare dice ancora "Pending" |
| 15 min – 2 ore | Cloudflare diventa **Active**; il dominio inizia a puntare al sito nuovo |
| Entro 24 ore | Il lucchetto HTTPS si attiva |

Nel frattempo il sito resta raggiungibile a
`https://giampieropagnini-cloud.github.io/giampieropagnini/`

---

## Se qualcosa non torna

- **Aruba non ti fa cambiare i nameserver** → mandami uno screenshot della pagina.
- **Cloudflare resta "Pending" dopo qualche ora** → ricontrolla di aver scritto
  bene i due nameserver su Aruba (senza spazi, senza punto finale).
- **Il vecchio sito Wix si vede ancora** → è la memoria del browser: prova in
  finestra anonima. Non cancellare l'account Wix finché tutto non è verificato.
