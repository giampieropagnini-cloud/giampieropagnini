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

/* ----------------------------------------------------------- telecomando */

function disegnaTelecomando() {
  const r = stato.dati.telecomando;
  const carta = $("#carta-telecomando");
  seCambiata("telecomando", r, carta, () => {
    const testi = { spento: "Spento", avvio: "In avvio…", attivo: "Attivo — in attesa della telecamera", errore: "Errore" };
    let statoTesto = testi[r.stato] || r.stato;
    if (r.stato === "attivo" && r.camera_collegata) statoTesto = "Attivo — una telecamera è abbinata!";
    let html =
      "<h2>Telecomando Bluetooth virtuale " +
      '<span class="distintivo" title="Basato sul protocollo del telecomando GPS ufficiale, decodificato dalla community.">sperimentale</span></h2>' +
      "<p>Il computer si finge il telecomando ufficiale «" + scappa(r.nome) + "»: le telecamere vere " +
      "(tutte e tre) possono abbinarsi e ricevere i quattro comandi del telecomando GPS.</p>";

    if (!r.disponibile) {
      html += '<div class="nota-installazione"><strong>Componente non installato.</strong> ' +
        "Per provarlo, apri il Terminale e scrivi:<br>" +
        "<code>python3 -m pip install bless</code><br>" +
        "poi chiudi e riavvia questo programma. Tutto il resto funziona anche senza.</div>";
    } else {
      const pallino = r.stato === "attivo" ? " acceso" : (r.stato === "errore" ? " rec" : "");
      html += '<div class="riga-telecomando">' +
        '<span class="pallino' + pallino + '"></span><strong>' + scappa(statoTesto) + "</strong>" +
        (r.stato === "errore" ? ' <span style="color:var(--testo-tenue)">' + scappa(r.errore) + "</span>" : "") +
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
        "<p style=\"font-size:13px\">Per abbinare: accendi il telecomando qui, poi sulla telecamera vai in " +
        "<strong>Impostazioni → Telecomando</strong> e scegli «" + scappa(r.nome) + "». " +
        "Su Mac, se la telecamera non lo trova, prova a rinominare il computer in «" + scappa(r.nome) + "» " +
        "(Impostazioni di Sistema → Generali → Info → Nome).</p>";
      if (r.registro && r.registro.length) {
        html += '<ul class="registro">' +
          r.registro.slice().reverse().map((v) =>
            '<li><span class="ora">' + scappa(v.ora) + "</span>" + scappa(v.testo) + "</li>").join("") + "</ul>";
      }
    }
    carta.innerHTML = html;
  });
}

/* ---------------------------------------------------------------- eventi */

document.addEventListener("click", (evento) => {
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
  disegnaTelecomando();
}

aggiorna();
setInterval(aggiorna, 1000);
