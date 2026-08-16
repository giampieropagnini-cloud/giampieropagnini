# Portare Instagram sul sito

Tre comandi in tutto. Il primo scarica l'archivio dal tuo profilo, il secondo
sceglie i post migliori, il terzo costruisce la pagina.

Tutto gira **sul tuo computer**, dentro la cartella del sito:

```bash
cd ~/Desktop/giampieropagnini      # o dove tieni la cartella
```

---

## PARTE 1 — Il cookie (una volta sola, 2 minuti)

Instagram non fa scaricare niente a chi non ha fatto l'accesso. Gli diamo la
tua sessione, quella del browser dove sei già dentro.

### 1. Apri Instagram nel browser
Su **Chrome** (o Safari), vai su [instagram.com](https://www.instagram.com/) e
assicurati di essere entrato con il tuo profilo.

### 2. Apri gli strumenti per sviluppatori
Menu **Visualizza ▸ Sviluppo ▸ Mostra Console JavaScript**, oppure `⌥⌘I`.

> Su Safari prima serve: **Safari ▸ Impostazioni ▸ Avanzate ▸ Mostra menu Sviluppo**.

### 3. Copia il cookie
Nella riga della console scrivi esattamente questo e premi Invio:

```js
copy(document.cookie)
```

Non compare niente: è normale, il cookie è già negli appunti.

### 4. Incollalo nel file
Torna nella cartella del sito e crea il file `scrape/ig-cookies.txt`,
incollandoci dentro quello che hai copiato:

```bash
pbpaste > scrape/ig-cookies.txt
```

⚠️ Quel file **non finisce su GitHub** (è già escluso): vale come la tua
password, tienilo sul computer e basta. Se cambi la password di Instagram,
rifai questa parte.

---

## PARTE 2 — I tre comandi

### 1. Scarica l'archivio

```bash
python3 scrape/instagram.py giamps1982
```

Al posto di `giamps1982` metti il profilo che vuoi: `weedgadget`,
`gpthesynthroller`, quello che è.

Scarica i testi in `scrape/ig/giamps1982.json` e le foto in
`assets/ig/giamps1982/orig/`. Ci mette qualche minuto: fa una pausa fra una
pagina e l'altra apposta, per non farsi bloccare da Instagram.

Se hai fretta o vuoi solo provare: `--limit 60` si ferma ai primi 60 post.
Rilanciandolo più avanti riprende tutto da capo ma **non riscarica** le foto
che ci sono già, e i post vecchi restano.

### 2. Scegli i migliori

```bash
python3 scrape/ig_build.py giamps1982 --top 12
```

Scrive `instagram.json` nella cartella principale: è il contenuto della
pagina, ed è un file di testo che puoi correggere a mano quando vuoi.
In vetrina finiscono i post con più mi piace e commenti.

Per comandare tu la vetrina:

```bash
python3 scrape/ig_build.py giamps1982 --top 12 --pin CxAb12,CyZz34
python3 scrape/ig_build.py giamps1982 --exclude CxNo99
```

(il codice del post è quello dopo `/p/` nell'indirizzo di Instagram)

Dentro `instagram.json` puoi scrivere a mano `intro_it` e `intro_en`: sono le
due righe di presentazione della pagina, e non vengono sovrascritte quando
rilanci il comando.

### 3. Costruisci il sito

```bash
python3 gen.py --out docs --theme oscura --imgs
```

Poi guarda com'è venuto:

```bash
open docs/instagram.html
```

Quando ti piace, mandalo online:

```bash
git add -A && git commit -m "Archivio Instagram sul sito" && git push
```

---

## Se il cookie non funziona

Se compare **"la sessione non è valida"**, il cookie è scaduto: rifai la
PARTE 1. Succede quando esci da Instagram o cambi password.

Se compare **"Instagram frena"**, sta solo rallentando: aspetta da solo e
riprende. Se insiste, fermalo con `⌃C` e riprova fra mezz'ora, oppure metti
una pausa più lunga: `--pause 5`.

---

## La strada senza cookie

Se preferisci non toccare i cookie, Instagram può darti tutto lui:

1. App Instagram ▸ **Impostazioni ▸ Centro gestione account ▸ Le tue
   informazioni ▸ Scarica le tue informazioni**
2. Scegli **JSON** (non HTML) e qualità **alta**
3. Ti arriva un'email con un file `.zip` (da qualche ora a un giorno)
4. Poi:

```bash
python3 scrape/instagram.py giamps1982 --export ~/Downloads/il-file.zip
```

Vengono le foto e tutte le didascalie, ma **non i mi piace**: in quel caso la
vetrina si riempie con i post più recenti, e i migliori li scegli tu con
`--pin`.

---

## Cosa finisce su GitHub e cosa no

| Resta solo sul tuo computer | Va su GitHub |
|---|---|
| `scrape/ig-cookies.txt` (la tua sessione) | `instagram.json` (i testi della pagina) |
| `scrape/ig/` (l'archivio grezzo) | `docs/instagram.html` (la pagina) |
| `assets/ig/` (le foto originali) | `docs/img/ig/` (le foto rimpicciolite) |

Se un giorno cancelli `instagram.json`, la pagina Instagram sparisce dal sito
e dal menu, e il resto resta come prima.
