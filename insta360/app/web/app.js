/* Controllo Telecamere Insta360 — logica dell'interfaccia.
   Vanilla JavaScript: chiede lo stato al programma una volta al secondo
   e ridisegna solo le parti cambiate. */

"use strict";

const stato = {
  dati: null,        // ultimo stato ricevuto dal server
  scelta: null,      // id della telecamera aperta nel pannello
  firme: {},         // impronte per ridisegnare solo ciò che cambia
  erroreRete: false,
};

const $ = (sel) => document.querySelector(sel);

/* ------------------------------------------------------------ utilità */

function fmtDurata(secondi) {
  const s = Math.max(0, Math.round(secondi || 0));
  const m = Math.floor(s / 60);
  return String(m).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0");
}

function fmtPeso(mb) {
  if (mb >= 1024) return (mb / 1024).toFixed(2).replace(".", ",") + " GB";
  return Math.round(mb) + " MB";
}

function fmtGB(gb) {
  return (Math.round(gb * 10) / 10).toString().replace(".", ",") + " GB";
}

function scappa(testo) {
  const div = document.createElement("div");
  div.textContent = String(testo == null ? "" : testo);
  return div.innerHTML.replace(/"/g, "&quot;");
}

function avviso(testo, ok) {
  const el = document.createElement("div");
  el.className = "avviso" + (ok ? " ok" : "");
  el.textContent = testo;
  $("#avvisi").appendChild(el);
  setTimeout(() => el.remove(), 4200);
}

/* Ridisegna una sezione solo se la sua "impronta" è cambiata.
   Se dentro c'è un menù a tendina in uso, aspetta: niente scherzi. */
function seCambiata(chiave, valore, contenitore, disegna) {
  const impronta = JSON.stringify(valore);
  if (stato.firme[chiave] === impronta) return;
  const attivo = document.activeElement;
  if (attivo && contenitore.contains(attivo) &&
      (attivo.tagName === "SELECT" || attivo.tagName === "INPUT")) return;
  stato.firme[chiave] = impronta;
  disegna();
}

/* ---------------------------------------------------------------- rete */

async function aggiorna() {
  try {
    const risposta = await fetch("/api/stato");
    stato.dati = await risposta.json();
    if (stato.erroreRete) { stato.erroreRete = false; avviso("Collegamento ristabilito.", true); }
    disegnaTutto();
  } catch (e) {
    if (!stato.erroreRete) {
      stato.erroreRete = true;
      avviso("Non riesco a parlare col programma: la finestra del terminale è ancora aperta?");
    }
  }
}

async function comanda(percorso, corpo) {
  try {
    const risposta = await fetch(percorso, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(corpo || {}),
    });
    const dati = await risposta.json().catch(() => ({}));
    if (!risposta.ok) avviso(dati.errore || "Comando non riuscito.");
    await aggiorna();
  } catch (e) {
    avviso("Comando non inviato: programma non raggiungibile.");
  }
}

const comandaTelecamera = (id, corpo) => comanda("/api/telecamere/" + id, corpo);

/* ---------------------------------------------------------------- icone */

function iconaTelecamera(tipo) {
  if (tipo === "360") {
    return '<svg width="34" height="34" viewBox="0 0 34 34" fill="none">' +
      '<rect x="12" y="2" width="10" height="30" rx="4" stroke="var(--accento)" stroke-width="2"/>' +
      '<circle cx="17" cy="10" r="4.2" stroke="var(--accento)" stroke-width="2"/>' +
      '<circle cx="17" cy="10" r="1.4" fill="var(--accento)"/></svg>';
  }
  if (tipo === "mini") {
    return '<svg width="34" height="34" viewBox="0 0 34 34" fill="none">' +
      '<rect x="4" y="10" width="14" height="20" rx="7" stroke="var(--accento)" stroke-width="2"/>' +
      '<circle cx="11" cy="17" r="3.2" stroke="var(--accento)" stroke-width="2"/>' +
      '<rect x="21" y="12" width="9" height="16" rx="3" stroke="var(--accento)" stroke-width="2" opacity=".55"/></svg>';
  }
  return '<svg width="34" height="34" viewBox="0 0 34 34" fill="none">' +
    '<rect x="3" y="8" width="28" height="19" rx="5" stroke="var(--accento)" stroke-width="2"/>' +
    '<circle cx="12" cy="17.5" r="5" stroke="var(--accento)" stroke-width="2"/>' +
    '<circle cx="12" cy="17.5" r="1.6" fill="var(--accento)"/>' +
    '<rect x="21" y="12" width="7" height="4" rx="1.5" fill="var(--accento)" opacity=".7"/></svg>';
}

/* -------------------------------------------------------------- griglia */

function testoStato(t) {
  const s = t.stato;
  if (!s.collegata) return "Non collegata";
  if (s.in_registrazione) return "REC " + fmtDurata(s.durata_registrazione);
  return "Pronta — batteria " + s.batteria + "%";
}

function disegnaGriglia() {
  const griglia = $("#griglia");
  for (const t of stato.dati.telecamere) {
    let scheda = griglia.querySelector('[data-scheda="' + t.id + '"]');
    if (!scheda) {
      scheda = document.createElement("article");
      scheda.className = "scheda";
      scheda.dataset.scheda = t.id;
      scheda.style.setProperty("--accento", t.colore);
      griglia.appendChild(scheda);
    }
    const s = t.stato;
    seCambiata("scheda:" + t.id,
      [s.collegata, s.in_registrazione, s.batteria, t.id === stato.scelta, Math.round(s.durata_registrazione || 0)],
      scheda,
      () => {
        scheda.classList.toggle("scelta", t.id === stato.scelta);
        const pallino = !s.collegata ? "" : (s.in_registrazione ? " rec" : " acceso");
        scheda.innerHTML =
          '<span class="icona">' + iconaTelecamera(t.tipo) + "</span>" +
          "<h3>" + scappa(t.nome) + "</h3>" +
          '<p class="sotto">' + scappa(t.sottotitolo) + "</p>" +
          '<div class="chips">' + t.chips.map((c) => '<span class="chip">' + scappa(c) + "</span>").join("") + "</div>" +
          '<div class="stato-riga"><span class="pallino' + pallino + '"></span>' +
          "<span>" + scappa(testoStato(t)) + "</span></div>" +
          '<div style="display:flex;justify-content:space-between;align-items:center;margin-top:12px">' +
          '<span class="apri">Apri i controlli →</span>' +
          '<button class="btn btn-piccolo" data-azione="' + (s.collegata ? "scollega" : "collega") + '" data-tele="' + t.id + '">' +
          (s.collegata ? "Scollega" : "Collega") + "</button></div>";
      });
  }
}

/* ------------------------------------------------------------- pannello */

function telecameraScelta() {
  if (!stato.dati || !stato.scelta) return null;
  return stato.dati.telecamere.find((t) => t.id === stato.scelta) || null;
}

function disegnaPannello() {
  const pannello = $("#pannello");
  const t = telecameraScelta();
  if (!t) {
    pannello.classList.add("nascosto");
    pannello.innerHTML = "";
    pannello.dataset.per = "";
    stato.firme = ripulisciFirme("pan:");
    return;
  }
  pannello.classList.remove("nascosto");
  pannello.style.setProperty("--accento", t.colore);

  if (!pannello.dataset.per || pannello.dataset.per !== t.id) {
    pannello.dataset.per = t.id;
    stato.firme = ripulisciFirme("pan:");
    pannello.innerHTML =
      '<div class="pannello-testa">' +
      "  <h2>" + scappa(t.nome) + "</h2>" +
      '  <div class="gruppo" id="pan-bottoni"></div>' +
      "</div>" +
      '<div class="colonne">' +
      '  <div><div id="pan-mirino"></div><div id="pan-scatto"></div></div>' +
      '  <div><div id="pan-modalita"></div><div id="pan-impostazioni"></div></div>' +
      "</div>" +
      '<div class="colonne" style="margin-top:20px">' +
      '  <div id="pan-file"></div><div id="pan-registro"></div>' +
      "</div>";
  }

  const s = t.stato;
  const modalita = t.modalita_disponibili.find((m) => m.id === s.modalita) || t.modalita_disponibili[0];

  seCambiata("pan:bottoni", [s.collegata], $("#pan-bottoni"), () => {
    $("#pan-bottoni").innerHTML =
      (s.collegata
        ? '<button class="btn" data-azione="scollega" data-tele="' + t.id + '">Scollega</button>' +
          '<button class="btn btn-pericolo" data-azione="spegni" data-tele="' + t.id + '">Spegni</button>'
        : '<button class="btn btn-primario" data-azione="collega" data-tele="' + t.id + '">Collega</button>') +
      '<button class="btn" data-azione="chiudi">← Tutte le telecamere</button>';
  });

  disegnaMirino(t, modalita);
  disegnaScatto(t, modalita);
  disegnaModalita(t, modalita);
  disegnaImpostazioni(t, modalita);
  disegnaFile(t);
  disegnaRegistro(t);
}

function ripulisciFirme(prefisso) {
  const nuove = {};
  for (const k of Object.keys(stato.firme)) if (!k.startsWith(prefisso)) nuove[k] = stato.firme[k];
  return nuove;
}

function disegnaMirino(t, modalita) {
  const s = t.stato;
  const griglia = (s.valori || {}).griglia === "3×3";
  const pianeta = (s.valori || {}).prospettiva === "Piccolo pianeta";
  seCambiata("pan:mirino",
    [s.collegata, s.in_registrazione, Math.round(s.durata_registrazione || 0), griglia, pianeta,
     modalita.id, s.risoluzione, s.batteria, s.autoscatto_fra != null && Math.ceil(s.autoscatto_fra)],
    $("#pan-mirino"),
    () => {
      let dentro = "";
      if (!s.collegata) {
        dentro = '<div class="spenta">Telecamera non collegata.<br>Premi «Collega» qui sopra per accenderla (in demo).</div>';
      } else {
        if (t.tipo === "360") dentro += '<div class="maschera-sfera"' + (pianeta ? ' style="transform:scale(1.6)"' : "") + "></div>";
        if (griglia) dentro += '<div class="griglia-terzi"></div>';
        if (s.in_registrazione) {
          dentro += '<div class="etichetta-rec"><span class="pallino rec"></span>REC ' + fmtDurata(s.durata_registrazione) + "</div>";
        } else if (s.autoscatto_fra != null) {
          dentro += '<div class="etichetta-rec">Autoscatto: ' + Math.ceil(s.autoscatto_fra) + "…</div>";
        }
        dentro += '<div class="etichetta-info"><span>' + scappa(modalita.nome + " · " + s.risoluzione) + "</span>" +
                  "<span>" + s.batteria + "% 🔋</span></div>";
      }
      $("#pan-mirino").innerHTML = '<div class="mirino tipo-' + t.tipo + '">' + dentro + "</div>";
    });
}

function disegnaScatto(t, modalita) {
  const s = t.stato;
  seCambiata("pan:scatto",
    [s.collegata, modalita.tipo, s.in_registrazione, s.autoscatto_fra != null && Math.ceil(s.autoscatto_fra),
     s.batteria, s.memoria_libera_gb],
    $("#pan-scatto"),
    () => {
      let classe = "bottone-scatto", azione = "scatta", testo = "SCATTA";
      if (modalita.tipo === "video") {
        classe += s.in_registrazione ? " registrando" : " video";
        testo = s.in_registrazione ? "■ STOP" : "● REC";
      } else if (s.autoscatto_fra != null) {
        testo = "ANNULLA " + Math.ceil(s.autoscatto_fra);
        azione = "annulla_autoscatto";
      }
      const percBatt = Math.max(0, Math.min(100, s.batteria || 0));
      const percMem = s.memoria_totale_gb ? Math.round(100 * s.memoria_libera_gb / s.memoria_totale_gb) : 0;
      $("#pan-scatto").innerHTML =
        '<div class="riga-scatto">' +
        '<button class="' + classe + '" data-azione="' + azione + '" data-tele="' + t.id + '"' +
        (s.collegata ? "" : " disabled") + ">" + testo + "</button>" +
        '<div class="indicatori">' +
        "<div>Batteria " + (s.collegata ? percBatt + "%" : "—") +
        '<div class="barra"><span class="' + (percBatt < 20 ? "scarsa" : "") + '" style="width:' + (s.collegata ? percBatt : 0) + '%"></span></div></div>' +
        "<div>Memoria libera " + (s.collegata ? fmtGB(s.memoria_libera_gb) + " di " + fmtGB(s.memoria_totale_gb) : "—") +
        '<div class="barra"><span class="memoria" style="width:' + (s.collegata ? percMem : 0) + '%"></span></div></div>' +
        "</div></div>";
    });
}

function disegnaModalita(t, modalita) {
  const s = t.stato;
  seCambiata("pan:modalita", [modalita.id, s.collegata, s.in_registrazione], $("#pan-modalita"), () => {
    $("#pan-modalita").innerHTML =
      "<h4>Modalità</h4>" +
      '<div class="modalita-chips">' +
      t.modalita_disponibili.map((m) =>
        '<button data-azione="modalita" data-tele="' + t.id + '" data-valore="' + m.id + '"' +
        (m.id === modalita.id ? ' class="attiva"' : "") +
        (!s.collegata || s.in_registrazione ? " disabled" : "") + ">" + scappa(m.nome) + "</button>"
      ).join("") + "</div>";
  });
}

function disegnaImpostazioni(t, modalita) {
  const s = t.stato;
  seCambiata("pan:impostazioni",
    [modalita.id, s.risoluzione, s.valori, s.collegata],
    $("#pan-impostazioni"),
    () => {
      const etichettaRis = modalita.tipo === "foto" ? "Formato foto" : "Risoluzione";
      let html = "<h4>" + etichettaRis + "</h4>" +
        '<label class="campo"><select data-scelta="risoluzione" data-tele="' + t.id + '"' + (s.collegata ? "" : " disabled") + ">" +
        modalita.risoluzioni.map((r) =>
          '<option value="' + scappa(r) + '"' + (r === s.risoluzione ? " selected" : "") + ">" + scappa(r) + "</option>"
        ).join("") + "</select></label>";
      html += "<h4>Impostazioni</h4>" + '<div class="griglia-impostazioni">' +
        t.impostazioni_disponibili.map((imp) => {
          const valore = (s.valori || {})[imp.id];
          return '<label class="campo">' + scappa(imp.nome) +
            '<select data-scelta="impostazione" data-tele="' + t.id + '" data-chiave="' + imp.id + '"' +
            (s.collegata ? "" : " disabled") + ">" +
            imp.opzioni.map((o) =>
              '<option value="' + scappa(o) + '"' + (o === valore ? " selected" : "") + ">" + scappa(o) + "</option>"
            ).join("") + "</select></label>";
        }).join("") + "</div>";
      $("#pan-impostazioni").innerHTML = html;
    });
}

function disegnaFile(t) {
  const s = t.stato;
  seCambiata("pan:file", [s.file, s.collegata], $("#pan-file"), () => {
    const righe = (s.file || []).map((f) =>
      "<tr><td>" + scappa(f.nome) + "</td>" +
      "<td>" + (f.tipo === "foto" ? "foto" : "video " + fmtDurata(f.durata_s)) + "</td>" +
      "<td>" + fmtPeso(f.dimensione_mb) + "</td>" +
      "<td>" + scappa(f.quando) + "</td>" +
      '<td><button class="btn btn-piccolo btn-pericolo" data-azione="elimina_file" data-tele="' + t.id +
      '" data-valore="' + scappa(f.nome) + '"' + (s.collegata ? "" : " disabled") + ">Elimina</button></td></tr>"
    ).join("");
    $("#pan-file").innerHTML =
      "<h4>File sulla telecamera</h4>" +
      (righe
        ? '<div class="contenitore-file"><table class="tabella-file">' +
          "<tr><th>Nome</th><th>Tipo</th><th>Peso</th><th>Quando</th><th></th></tr>" + righe + "</table></div>"
        : '<p style="color:var(--testo-tenue);font-size:13.5px">Nessun file. Scatta qualcosa!</p>');
  });
}

function disegnaRegistro(t) {
  seCambiata("pan:registro", t.registro, $("#pan-registro"), () => {
    $("#pan-registro").innerHTML =
      "<h4>Registro</h4><ul class=\"registro\">" +
      t.registro.slice().reverse().map((v) =>
        '<li><span class="ora">' + scappa(v.ora) + "</span>" + scappa(v.testo) + "</li>").join("") +
      "</ul>";
  });
}

/* ------------------------------------------------- Bluetooth (vero) */

function etichettaSegnale(rssi) {
  if (rssi == null) return "";
  if (rssi >= -60) return "segnale forte";
  if (rssi >= -75) return "segnale medio";
  return "segnale debole";
}

function notaInstallazione() {
  return '<div class="nota-installazione"><strong>Componente Bluetooth non installato.</strong> ' +
    "Chiudi il programma e riaprilo: alla partenza ti chiederà se installarlo (basta premere Invio). " +
    "In alternativa, in una finestra nuova del Terminale: " +
    "<code>python3 -m pip install --user bless bleak</code></div>";
}

function registroHtml(voci) {
  if (!voci || !voci.length) return "";
  return '<ul class="registro">' +
    voci.slice().reverse().map((v) =>
      '<li><span class="ora">' + scappa(v.ora) + "</span>" + scappa(v.testo) + "</li>").join("") + "</ul>";
}

function disegnaBluetooth() {
  const r = stato.dati.telecomando;
  const b = stato.dati.bluetooth;
  const s = stato.dati.sonda || {};
  const carta = $("#carta-telecomando");
  seCambiata("bluetooth", [r, b, s], carta, () => {
    let html =
      "<h2>Telecamere vere via Bluetooth " +
      '<span class="distintivo" title="Basato sul protocollo del telecomando GPS ufficiale Insta360, decodificato dalla community.">sperimentale</span></h2>';

    /* -- passo 1: ricerca ------------------------------------------- */
    html += "<h4>Passo 1 · Cerca la telecamera</h4>" +
      "<p><strong>Prima, sulla telecamera:</strong> scorri in basso → Impostazioni (ingranaggio) → " +
      "<strong>Telecomando Bluetooth</strong> (in inglese <em>Bluetooth Remote</em>) e lascia quella " +
      "schermata aperta. Poi premi qui il pulsante: compare l'elenco degli apparecchi intorno a te.</p>";
    if (!b.disponibile) {
      html += notaInstallazione();
    } else {
      html += '<div class="riga-telecomando">' +
        '<button class="btn btn-primario" data-bluetooth="cerca"' + (b.in_corso ? " disabled" : "") + ">" +
        (b.in_corso ? "Sto cercando… (6 s)" : "Cerca le telecamere vicine") + "</button>" +
        (b.quando ? '<span style="color:var(--testo-tenue);font-size:13px">Ultima ricerca: ' + scappa(b.quando) + "</span>" : "") +
        "</div>";
      if (b.errore) {
        html += '<p class="errore-ble">' + scappa(b.errore) + "</p>";
      }
      if (b.risultati && b.risultati.length) {
        html += '<ul class="lista-ble">' +
          b.risultati.slice(0, 12).map((d) =>
            '<li class="' + (d.insta ? "insta" : "") + '">' +
            '<button class="btn btn-piccolo" data-bluetooth="sonda" data-indirizzo="' +
            scappa(d.indirizzo) + '" data-nome="' + scappa(d.nome) + '">Collega</button> ' +
            "<strong>" + scappa(d.nome) + "</strong>" +
            (d.insta ? ' <span class="badge-insta">sembra una Insta360!</span>' : "") +
            ' <span class="segnale">' + etichettaSegnale(d.segnale) + "</span></li>").join("") +
          "</ul>";
      } else if (b.quando && !b.in_corso && !b.errore) {
        html += '<p style="color:var(--testo-tenue);font-size:13px">Nessun apparecchio trovato: ' +
          "controlla che le telecamere siano accese e vicine, poi riprova.</p>";
      }
      html += registroHtml(b.registro);
    }

    /* -- passo 2: collegamento diretto (sonda) ----------------------- */
    html += "<h4>Passo 2 · Collegati alla telecamera</h4>" +
      "<p>Come fa il telecomando vero: è il programma che si collega <strong>lui</strong> alla " +
      "telecamera. Premi «Collega» accanto alla tua telecamera nell'elenco qui sopra.</p>";
    if (s && s.stato && s.stato !== "inattiva") {
      const testiSonda = { connessione: "Mi sto collegando a «" + scappa(s.nome) + "»…",
                           collegata: "Collegata a «" + scappa(s.nome) + "»",
                           errore: "Collegamento non riuscito" };
      const pallinoSonda = s.stato === "collegata" ? " acceso" : (s.stato === "errore" ? " rec" : "");
      html += '<div class="riga-telecomando">' +
        '<span class="pallino' + pallinoSonda + '"></span><strong>' +
        (testiSonda[s.stato] || scappa(s.stato)) + "</strong>" +
        (s.stato === "errore" ? ' <span class="errore-ble">' + scappa(s.errore) + "</span>" : "") +
        "</div>";
      if (s.stato === "collegata") {
        const puoi = s.scrivibili && s.scrivibili.length;
        html += '<div class="riga-telecomando"><span class="pulsanti">' +
          '<button class="btn btn-primario" data-bluetooth="sonda_comando" data-comando="scatto"' +
          (puoi ? "" : " disabled") + ">Prova scatto</button>" +
          '<button class="btn" data-bluetooth="sonda_comando" data-comando="modalita"' +
          (puoi ? "" : " disabled") + ">Prova cambio modalità</button>" +
          '<button class="btn" data-bluetooth="sonda_comando" data-comando="schermo"' +
          (puoi ? "" : " disabled") + ">Prova schermo</button>" +
          "</span></div>" +
          '<div class="riga-telecomando">' +
          '<button class="btn" data-bluetooth="sonda_scollega">Scollega</button>' +
          '<button class="btn" data-copia="diagnostica">📋 Copia per Claude</button>' +
          "</div>";
      }
      if (s.dettagli && s.dettagli.length) {
        html += '<div class="dettagli-sonda" id="dettagli-sonda">' +
          s.dettagli.map((riga) => scappa(riga)).join("<br>") + "</div>" +
          "<p style=\"font-size:12.5px;color:var(--testo-tenue)\">Questa è la diagnostica: le tue " +
          "telecamere raccontano qui come sono fatte. Premi <strong>«Copia per Claude»</strong> e " +
          "incolla il risultato in chat: da lì taro i comandi sul tuo modello esatto.</p>";
      }
      html += registroHtml(s.registro);
    }

    /* -- passo 3: telecomando virtuale (alternativa) ------------------ */
    html += "<h4>Passo 3 · In alternativa: il telecomando virtuale</h4>" +
      "<p>Il computer si finge il telecomando ufficiale «" + scappa(r.nome) + "». " +
      "Metodo alternativo, da provare se il Passo 2 non dovesse funzionare.</p>";
    if (!r.disponibile) {
      html += notaInstallazione();
    } else {
      const testi = { spento: "Spento", avvio: "In avvio…", attivo: "Attivo — in attesa della telecamera", errore: "Errore" };
      let statoTesto = testi[r.stato] || r.stato;
      if (r.stato === "attivo" && r.camera_collegata) statoTesto = "Attivo — una telecamera è abbinata!";
      const pallino = r.stato === "attivo" ? " acceso" : (r.stato === "errore" ? " rec" : "");
      html += '<div class="riga-telecomando">' +
        '<span class="pallino' + pallino + '"></span><strong>' + scappa(statoTesto) + "</strong>" +
        (r.stato === "errore" ? ' <span class="errore-ble">' + scappa(r.errore) + "</span>" : "") +
        "</div>" +
        '<div class="riga-telecomando">' +
        (r.stato === "attivo" || r.stato === "avvio"
          ? '<button class="btn" data-telecomando="ferma">Ferma il telecomando</button>'
          : '<button class="btn btn-primario" data-telecomando="accendi">Accendi il telecomando</button>') +
        '<span class="pulsanti">' +
        r.comandi.map((c) =>
          '<button class="btn" data-telecomando="comando" data-comando="' + c.id + '"' +
          (r.stato === "attivo" ? "" : " disabled") + ">" + scappa(c.nome) + "</button>").join("") +
        "</span></div>" +
        "<details><summary>Come si abbina la telecamera (aprimi)</summary>" +
        "<ol style=\"font-size:13.5px\">" +
        "<li>Premi «Accendi il telecomando» qui sopra. La prima volta il Mac chiederà il permesso " +
        "di usare il Bluetooth: concedilo al Terminale.</li>" +
        "<li>Sulla telecamera (sulla GO 3S: dal quadrante dell'Action Pod) scorri in basso, apri le " +
        "<strong>Impostazioni</strong> (icona ingranaggio) e cerca la voce " +
        "<strong>Telecomando Bluetooth</strong> (in inglese <em>Bluetooth Remote</em>).</li>" +
        "<li>Scegli «" + scappa(r.nome) + "» quando compare, e usa i pulsanti qui sopra.</li>" +
        "<li>Se non compare: rinomina il Mac in «" + scappa(r.nome) + "» " +
        "(Impostazioni di Sistema → Generali → Info → Nome) e riprova — a volte macOS annuncia " +
        "il nome del computer invece di quello del telecomando.</li>" +
        "</ol></details>";
      html += registroHtml(r.registro);
    }
    carta.innerHTML = html;
  });
}

/* ---------------------------------------------------------------- eventi */

document.addEventListener("click", (evento) => {
  const bottoneCopia = evento.target.closest("[data-copia]");
  if (bottoneCopia) {
    const testo = (stato.dati.sonda && stato.dati.sonda.diagnostica) || "";
    const finito = () => { bottoneCopia.textContent = "✓ Copiato! Ora incollalo in chat"; };
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(testo).then(finito, () => avviso("Non riesco a copiare: selezionalo a mano."));
    } else {
      const ta = document.createElement("textarea");
      ta.value = testo; document.body.appendChild(ta); ta.select();
      try { document.execCommand("copy"); finito(); } catch (e) { avviso("Selezionalo a mano dalla diagnostica."); }
      ta.remove();
    }
    return;
  }

  const bottoneBluetooth = evento.target.closest("[data-bluetooth]");
  if (bottoneBluetooth) {
    const richiesta = { azione: bottoneBluetooth.dataset.bluetooth };
    if (bottoneBluetooth.dataset.indirizzo) richiesta.indirizzo = bottoneBluetooth.dataset.indirizzo;
    if (bottoneBluetooth.dataset.nome) richiesta.nome = bottoneBluetooth.dataset.nome;
    if (bottoneBluetooth.dataset.comando) richiesta.comando = bottoneBluetooth.dataset.comando;
    comanda("/api/bluetooth", richiesta);
    return;
  }

  const bottoneTelecomando = evento.target.closest("[data-telecomando]");
  if (bottoneTelecomando) {
    const azione = bottoneTelecomando.dataset.telecomando;
    comanda("/api/telecomando",
      azione === "comando" ? { azione: "comando", comando: bottoneTelecomando.dataset.comando } : { azione });
    return;
  }

  const bottone = evento.target.closest("[data-azione]");
  if (bottone) {
    const azione = bottone.dataset.azione;
    if (azione === "chiudi") {
      stato.scelta = null;
      disegnaTutto();
      return;
    }
    const id = bottone.dataset.tele;
    if (azione === "modalita") comandaTelecamera(id, { azione: "modalita", valore: bottone.dataset.valore });
    else if (azione === "elimina_file") comandaTelecamera(id, { azione: "elimina_file", nome: bottone.dataset.valore });
    else comandaTelecamera(id, { azione });
    return;
  }

  const scheda = evento.target.closest("[data-scheda]");
  if (scheda) {
    stato.scelta = scheda.dataset.scheda;
    disegnaTutto();
    $("#pannello").scrollIntoView({ behavior: "smooth", block: "start" });
  }
});

document.addEventListener("change", (evento) => {
  const scelta = evento.target.closest("[data-scelta]");
  if (!scelta) return;
  const id = scelta.dataset.tele;
  if (scelta.dataset.scelta === "risoluzione") {
    comandaTelecamera(id, { azione: "risoluzione", valore: scelta.value });
  } else {
    comandaTelecamera(id, { azione: "impostazione", chiave: scelta.dataset.chiave, valore: scelta.value });
  }
  scelta.blur();
});

/* ----------------------------------------------------------------- avvio */

function disegnaTutto() {
  if (!stato.dati) return;
  $("#versione").textContent = "Controllo Telecamere Insta360 — versione " + stato.dati.versione;
  disegnaGriglia();
  disegnaPannello();
  disegnaBluetooth();
}

aggiorna();
setInterval(aggiorna, 1000);
