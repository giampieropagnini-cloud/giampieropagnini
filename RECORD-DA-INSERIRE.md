# Record da inserire su Cloudflare — giampieropagnini.com

Pagina: Cloudflare → giampieropagnini.com → **DNS** → **Records**

---

## 1. PRIMA: cancella questi

| Cosa | Perché |
|---|---|
| Record **A** con valore `185.230.63.107` | vecchio server Wix |
| Record **A** con valore `185.230.63.171` | vecchio server Wix |
| Record **A** con valore `185.230.63.186` | vecchio server Wix |
| Record **MX** `_dc-mx.4fe515caff58...` | segnaposto inutile creato da Cloudflare |

Su ognuno: **Edit** → **Delete**.

---

## 2. POI: aggiungi questi (bottone *Add record*)

### 📧 LA POSTA — inseriscili per primi, sono urgenti

Serve per far tornare a funzionare **info@giampieropagnini.com**

| Type | Name   | Valore / Target             | Priority | Proxy         |
|------|--------|-----------------------------|----------|---------------|
| MX   | `@`    | `mail.giampieropagnini.com` | `10`     | (non c'è)     |
| A    | `mail` | `62.149.128.154`            | —        | **DNS only** ⚠️ |
| TXT  | `@`    | `v=spf1 include:_spf.aruba.it ~all` | — | (non c'è) |

⚠️ Il record **A `mail`** DEVE avere la nuvoletta **grigia**. Se resta arancione la
posta non arriva: Cloudflare non sa gestire il traffico email.

### 🌐 IL SITO

| Type  | Name  | Valore / Target                    | Proxy         |
|-------|-------|------------------------------------|---------------|
| A     | `@`   | `185.199.108.153`                  | **DNS only** ⚠️ |
| A     | `@`   | `185.199.109.153`                  | **DNS only** ⚠️ |
| A     | `@`   | `185.199.110.153`                  | **DNS only** ⚠️ |
| A     | `@`   | `185.199.111.153`                  | **DNS only** ⚠️ |
| CNAME | `www` | `giampieropagnini-cloud.github.io` | **DNS only** ⚠️ |

---

## 3. Controllo finale

Alla fine la lista deve avere **9 record** e **tutte le nuvolette grigie**
(scritta *DNS only* accanto a ciascuna).

Se una nuvoletta è arancione, cliccaci sopra: diventa grigia.

---

## Poi scrivimi

Io da qui verifico:
- che il sito risponda su giampieropagnini.com
- che la posta di info@giampieropagnini.com sia di nuovo raggiungibile
- attivo il certificato HTTPS

---

### Da dove vengono questi valori

Non sono inventati: li ho letti dalla configurazione reale del tuo dominio
prima che venisse azzerata.

- `62.149.128.154` è il server di posta Aruba a cui puntava
  `mail.giampieropagnini.com` (verificato: rete ARUBA-NET, *Shared Hosting and
  Mail services*)
- `185.199.108-111.153` sono i quattro server di GitHub Pages, dove ora vive il sito
- `giampieropagnini-cloud.github.io` è il tuo spazio su GitHub
