(*
	AirPlay Automatico - per il Mac mini senza monitor

	Collega da solo il Mac all'Apple TV, come se cliccassi tu su
	Centro di Controllo > Duplica schermo > nome dell'Apple TV.

	Come funziona:
	  1. legge il nome dell'Apple TV dal file di configurazione
	     (~/Library/Application Support/AirPlay Automatico/apple-tv.txt)
	  2. se il Mac risulta gia' collegato a quell'Apple TV, non fa nulla
	  3. altrimenti apre il Centro di Controllo, entra in "Duplica schermo"
	     e clicca il nome dell'Apple TV
	  4. se l'Apple TV non compare ancora nell'elenco (all'accensione la rete
	     ci mette qualche secondo), riprova per un paio di minuti
	  5. tutto quello che fa viene scritto in ~/Library/Logs/AirPlayAutomatico.log

	Non dipende da posizioni fisse dei bottoni: cerca gli elementi per nome,
	cosi' regge meglio ai cambiamenti fra le versioni di macOS (Sonoma, Sequoia, Tahoe).
	Serve il permesso "Accessibilita'" (lo chiede da solo la prima volta).
*)

property nomeApp : "AirPlay Automatico"
property nomeAppleTV : ""
property tentativiMassimi : 10
property pausaTraTentativi : 8
property secondiAttesaElenco : 4
property haCliccato : false
property diagnosticaFatta : false
property barraDescritta : false

on run
	set nomeAppleTV to my leggiNomeAppleTV()
	if nomeAppleTV is "" then
		my scrivi("Nome dell'Apple TV mancante: mi fermo.")
		return
	end if
	my scrivi("---- Avvio. Apple TV da collegare: " & nomeAppleTV)
	set haCliccato to false
	set diagnosticaFatta to false
	set barraDescritta to false

	if my giaCollegato() then
		my scrivi("Il Mac risulta gia' collegato a " & nomeAppleTV & ". Non faccio nulla.")
		return
	end if

	set stato to my statoPermessi()
	if stato is not "ok" then
		my scrivi("Manca un permesso (" & stato & "): lo chiedo all'utente.")
		my chiediPermessi(stato)
		return
	end if

	repeat with tentativo from 1 to tentativiMassimi
		set esito to "errore"
		set dettaglio to ""
		try
			set esito to my tentaCollegamento()
		on error messaggio number numero
			set dettaglio to messaggio & " [" & numero & "]"
			set tipo to my tipoPermessoDaErrore(numero, messaggio)
			if tipo is not "ok" then
				my scrivi("Tentativo " & tentativo & ": manca un permesso (" & tipo & ") " & dettaglio)
				my chiudiPannello()
				my chiediPermessi(tipo)
				return
			end if
		end try
		my scrivi("Tentativo " & tentativo & " di " & tentativiMassimi & ": " & esito & "  " & dettaglio)
		my chiudiPannello()
		if esito is in {"collegato", "gia_collegato", "cliccato"} then exit repeat
		-- se ho gia' cliccato una volta, non riclicco mai nello stesso avvio (riclic = scollega!)
		if haCliccato then
			my scrivi("Ho gia' cliccato in questo avvio: mi fermo qui per non scollegare.")
			exit repeat
		end if
		if tentativo < tentativiMassimi then delay pausaTraTentativi
	end repeat
	my scrivi("Fine.")
end run

-- =====================================================================
--  Collegamento
-- =====================================================================

-- Un tentativo completo. Restituisce:
--   "collegato"      ho cliccato e il Mac risulta collegato
--   "cliccato"       ho cliccato ma non riesco a verificare (di solito e' andata bene)
--   "gia_collegato"  era gia' collegato
--   "non_trovato"    l'Apple TV non e' comparsa nell'elenco
on tentaCollegamento()
	my apriElencoDispositivi()

	-- aspetta che l'Apple TV compaia nell'elenco (arriva via rete, puo' volerci qualche secondo)
	set elemento to missing value
	repeat (secondiAttesaElenco * 2) times
		set elemento to my cercaDispositivo()
		if elemento is not missing value then exit repeat
		delay 0.5
	end repeat

	if elemento is missing value then
		if my pannelloMostraCollegamentoAttivo() then return "gia_collegato"
		if not diagnosticaFatta then
			set diagnosticaFatta to true
			my descriviPannello()
		end if
		return "non_trovato"
	end if

	set ruolo to my ruoloDi(elemento)
	set valore to my valoreDi(elemento)
	my scrivi("Trovato '" & nomeAppleTV & "' nel pannello (ruolo " & ruolo & ", valore " & valore & ", testo " & my testoDi(elemento) & ").")

	-- gia' collegato? allora NON clicco, altrimenti lo scollegherei
	if valore is 1 and ruolo is in {"AXCheckBox", "AXDisclosureTriangle", "AXRadioButton"} then return "gia_collegato"
	if my pannelloMostraCollegamentoAttivo() then return "gia_collegato"

	-- un solo clic; se subito dopo il pannello cambia e System Events protesta, non importa
	set haCliccato to true
	try
		tell application "System Events" to click elemento
	on error messaggio number numero
		my scrivi("(subito dopo il clic: " & messaggio & " [" & numero & "])")
	end try
	my scrivi("Ho cliccato su '" & nomeAppleTV & "'. Aspetto il collegamento...")
	delay 3
	my chiudiPannello()

	-- verifica (fino a circa 40 secondi)
	repeat 12 times
		if my giaCollegato() then return "collegato"
		delay 2
	end repeat
	return "cliccato"
end tentaCollegamento

-- Cerca la riga dell'Apple TV nel pannello. Preferisce l'interruttore (checkbox) della riga,
-- e un elemento che si chiama ESATTAMENTE come l'Apple TV rispetto a uno che la contiene soltanto.
on cercaDispositivo()
	set elementi to my elementiDelPannello()
	set nomeNorm to my normalizza(nomeAppleTV)
	set nomeBase to my senzaSuffisso(nomeAppleTV)
	set nomeBaseNorm to my normalizza(nomeBase)
	set migliore to missing value
	set punteggioMigliore to 0
	repeat with e in elementi
		set el to contents of e
		set testo to my testoDi(el)
		set testoNorm to my normalizza(testo)
		set punteggio to 0
		if testo contains ("|" & nomeAppleTV & "|") then
			set punteggio to 30
		else if testo contains nomeAppleTV then
			set punteggio to 20
		else if testoNorm contains nomeNorm then
			set punteggio to 15
		else if nomeBase is not nomeAppleTV and (testo contains ("|" & nomeBase & "|") or testoNorm contains nomeBaseNorm) then
			set punteggio to 5
		end if
		if punteggio > 0 then
			set ruolo to my ruoloDi(el)
			if ruolo is "AXStaticText" then set punteggio to punteggio + 1
			if ruolo is in {"AXButton", "AXRadioButton", "AXMenuItem", "AXMenuButton", "AXPopUpButton"} then set punteggio to punteggio + 2
			if ruolo is "AXDisclosureTriangle" then set punteggio to punteggio + 3
			if ruolo is "AXCheckBox" then set punteggio to punteggio + 4
			if ruolo is in {"AXCheckBox", "AXDisclosureTriangle"} and my valoreDi(el) is 1 then set punteggio to punteggio + 3
			if punteggio > punteggioMigliore then
				set migliore to el
				set punteggioMigliore to punteggio
			end if
		end if
	end repeat
	if migliore is not missing value and punteggioMigliore < 15 then
		my scrivi("Attenzione: non trovo '" & nomeAppleTV & "', uso la riga simile '" & nomeBase & "'.")
	end if
	return migliore
end cercaDispositivo

-- Solo lettere e numeri, minuscole: "Camera (2)" -> "camera2"
on normalizza(t)
	set t to t as text
	set buoni to "abcdefghijklmnopqrstuvwxyz0123456789"
	set risultato to ""
	repeat with c in (characters of t)
		set ch to c as text
		set tieni to (buoni contains ch)
		if not tieni then
			try
				if (id of ch) > 127 then set tieni to true
			end try
		end if
		if tieni then set risultato to risultato & ch
	end repeat
	return risultato
end normalizza

-- "Camera (2)" -> "Camera"
on senzaSuffisso(t)
	set t to t as text
	if t ends with ")" then
		set p to (offset of " (" in t)
		if p > 1 then return text 1 thru (p - 1) of t
	end if
	return t
end senzaSuffisso

-- Scrive nel diario tutto quello che c'e' nel pannello (per capire come e' fatto)
on descriviPannello()
	set finestre to {}
	try
		tell application "System Events" to tell process "ControlCenter" to set finestre to every window
	end try
	my scrivi("  [diagnostica] finestre del Centro di Controllo: " & (count of finestre))
	set idx to 0
	repeat with f in finestre
		set idx to idx + 1
		set fin to contents of f
		set nomeFin to ""
		try
			tell application "System Events" to set nomeFin to (name of fin) as text
		end try
		set elementi to {}
		set metodo to "entire contents"
		try
			tell application "System Events" to set elementi to entire contents of fin
		on error errMsg
			set metodo to "a mano (entire contents fallito: " & errMsg & ")"
			try
				set elementi to my raccogliElementi(fin, 0, {})
			end try
		end try
		my scrivi("  [diagnostica] finestra " & idx & " '" & nomeFin & "': " & (count of elementi) & " elementi, letti con " & metodo)
		set n to 0
		repeat with e in elementi
			set n to n + 1
			if n > 150 then
				my scrivi("    ... (altri elementi omessi)")
				exit repeat
			end if
			set el to contents of e
			set sub to ""
			try
				tell application "System Events" to set sub to (value of attribute "AXSubrole" of el) as text
			end try
			my scrivi("    " & my ruoloDi(el) & " " & sub & " " & my testoDi(el))
		end repeat
	end repeat
end descriviPannello

-- Scrive nel diario le icone della barra dei menu del Centro di Controllo
on descriviBarraMenu()
	try
		tell application "System Events"
			tell process "ControlCenter"
				set voci to menu bar items of menu bar 1
			end tell
		end tell
		set riga to ""
		repeat with v in voci
			set el to contents of v
			set ident to ""
			try
				tell application "System Events" to set ident to (value of attribute "AXIdentifier" of el) as text
			end try
			set descr to ""
			try
				tell application "System Events" to set descr to (description of el) as text
			end try
			set riga to riga & "[" & ident & " / " & descr & "] "
		end repeat
		my scrivi("  [diagnostica] icone nella barra dei menu: " & riga)
	end try
end descriviBarraMenu

-- Apre l'elenco dei dispositivi di "Duplica schermo".
-- Prima prova l'icona dedicata nella barra dei menu (se e' impostata "mostra sempre"),
-- altrimenti passa dal Centro di Controllo.
on apriElencoDispositivi()
	set voceDuplica to missing value
	set voceCentro to missing value
	tell application "System Events"
		if not (exists process "ControlCenter") then error "Il Centro di Controllo non e' ancora attivo"
		tell process "ControlCenter"
			repeat with voce in (menu bar items of menu bar 1)
				set ident to ""
				try
					set ident to (value of attribute "AXIdentifier" of voce) as text
				end try
				set descr to ""
				try
					set descr to (description of voce) as text
				end try
				if ident contains "screenmirroring" or ident contains "screen-mirroring" or descr is "Screen Mirroring" or descr is "Duplica schermo" then
					set voceDuplica to contents of voce
				else if ident is "com.apple.menuextra.controlcenter" or descr is "Control Center" or descr is "Centro di Controllo" then
					set voceCentro to contents of voce
				end if
			end repeat
		end tell
	end tell
	if not barraDescritta then
		set barraDescritta to true
		my descriviBarraMenu()
	end if

	-- 1) Centro di Controllo > Duplica schermo (strada che funziona anche su macOS 26)
	if voceCentro is not missing value then
		tell application "System Events" to click voceCentro
		my aspettaPannello()
		set modulo to missing value
		repeat 10 times
			set modulo to my cercaElemento({"controlcenter-screen-mirroring", "Screen Mirroring", "Duplica schermo"})
			if modulo is not missing value then exit repeat
			delay 0.3
		end repeat
		if modulo is not missing value then
			my apriDettagli(modulo)
			delay 1.2
			my scrivi("Aperto Centro di Controllo > Duplica schermo.")
			return
		end if
		my scrivi("Nel Centro di Controllo non trovo la voce 'Duplica schermo': provo l'icona dedicata.")
		my chiudiPannello()
	end if

	-- 2) icona dedicata "Duplica schermo" nella barra dei menu
	if voceDuplica is not missing value then
		tell application "System Events" to click voceDuplica
		my aspettaPannello()
		my scrivi("Aperto 'Duplica schermo' dall'icona nella barra dei menu.")
		return
	end if

	error "Non trovo ne' il Centro di Controllo ne' l'icona 'Duplica schermo' nella barra dei menu"
end apriElencoDispositivi

-- Apre il dettaglio di un modulo del Centro di Controllo
-- (usa l'azione "show details" se c'e', altrimenti un clic normale)
on apriDettagli(el)
	set fatto to false
	tell application "System Events"
		try
			repeat with az in (actions of el)
				set nomeAz to ""
				try
					set nomeAz to (name of az) as text
				end try
				set descAz to ""
				try
					set descAz to (description of az) as text
				end try
				if nomeAz contains "show details" or descAz contains "show details" or nomeAz contains "mostra dettagli" or descAz contains "mostra dettagli" then
					perform (contents of az)
					set fatto to true
					exit repeat
				end if
			end repeat
		end try
		if not fatto then click el
	end tell
end apriDettagli

-- Aspetta che il pannello del Centro di Controllo sia visibile
on aspettaPannello()
	tell application "System Events"
		tell process "ControlCenter"
			repeat 25 times
				if (count of windows) > 0 then exit repeat
				delay 0.2
			end repeat
			if (count of windows) is 0 then error "Il pannello del Centro di Controllo non si e' aperto"
		end tell
	end tell
	delay 0.6
end aspettaPannello

-- Chiude il pannello del Centro di Controllo, se e' aperto
on chiudiPannello()
	try
		tell application "System Events"
			tell process "ControlCenter"
				repeat 2 times
					if (count of windows) > 0 then
						key code 53 -- tasto Esc
						delay 0.5
					end if
				end repeat
				if (count of windows) > 0 then
					repeat with voce in (menu bar items of menu bar 1)
						set ident to ""
						try
							set ident to (value of attribute "AXIdentifier" of voce) as text
						end try
						if ident is "com.apple.menuextra.controlcenter" then
							click voce
							delay 0.4
							exit repeat
						end if
					end repeat
				end if
			end tell
		end tell
	end try
end chiudiPannello

-- Vero se il pannello mostra le opzioni di un collegamento gia' attivo
-- ("Usa come display esteso" / "Use As Extended Display")
on pannelloMostraCollegamentoAttivo()
	set el to my cercaElemento({"Extended Display", "Separate Display", "Built-in Display", "display esteso", "schermo esteso", "display separato", "schermo separato", "display integrato", "schermo integrato"})
	return (el is not missing value)
end pannelloMostraCollegamentoAttivo

-- =====================================================================
--  Ricerca degli elementi nel pannello (per nome, non per posizione)
-- =====================================================================

-- Cerca nel pannello del Centro di Controllo un elemento il cui testo
-- (descrizione, nome, titolo, identificatore o valore) contiene uno dei testi dati.
-- Preferisce gli elementi cliccabili (checkbox, triangoli, bottoni) alle etichette.
on cercaElemento(testi)
	set elementi to my elementiDelPannello()
	set migliore to missing value
	set punteggioMigliore to 0
	repeat with e in elementi
		set el to contents of e
		set testo to my testoDi(el)
		set trovato to false
		repeat with t in testi
			if testo contains (t as text) then
				set trovato to true
				exit repeat
			end if
		end repeat
		if trovato then
			set ruolo to my ruoloDi(el)
			set punteggio to 1
			if ruolo is "AXStaticText" then set punteggio to 2
			if ruolo is in {"AXButton", "AXRadioButton", "AXMenuItem", "AXMenuButton", "AXPopUpButton"} then set punteggio to 3
			if ruolo is "AXCheckBox" then set punteggio to 4
			if ruolo is "AXDisclosureTriangle" then set punteggio to 5
			-- l'identificatore interno (es. "controlcenter-screen-mirroring") vince su tutto
			set ident to my identificatoreDi(el)
			if ident is not "" then
				repeat with t in testi
					if ident contains (t as text) then
						set punteggio to punteggio + 10
						exit repeat
					end if
				end repeat
			end if
			if punteggio > punteggioMigliore then
				set migliore to el
				set punteggioMigliore to punteggio
			end if
		end if
	end repeat
	return migliore
end cercaElemento

-- Tutti gli elementi della finestra del Centro di Controllo
on elementiDelPannello()
	set elementi to {}
	set finestre to {}
	try
		tell application "System Events" to tell process "ControlCenter" to set finestre to every window
	end try
	repeat with f in finestre
		set fin to contents of f
		set parte to {}
		try
			tell application "System Events" to set parte to entire contents of fin
		on error
			-- se "entire contents" fallisce, li raccolgo a mano
			try
				set parte to my raccogliElementi(fin, 0, {})
			end try
		end try
		set elementi to elementi & parte
	end repeat
	return elementi
end elementiDelPannello

on raccogliElementi(contenitore, profondita, accumulo)
	if profondita > 12 then return accumulo
	set figli to {}
	try
		tell application "System Events" to set figli to UI elements of contenitore
	end try
	repeat with f in figli
		set fig to contents of f
		set end of accumulo to fig
		set accumulo to my raccogliElementi(fig, profondita + 1, accumulo)
	end repeat
	return accumulo
end raccogliElementi

-- Tutti i testi di un elemento, uniti da "|"
on testoDi(el)
	set testo to ""
	tell application "System Events"
		try
			set testo to testo & "|" & ((description of el) as text)
		end try
		try
			set testo to testo & "|" & ((name of el) as text)
		end try
		try
			set testo to testo & "|" & ((title of el) as text)
		end try
		try
			set testo to testo & "|" & ((value of attribute "AXIdentifier" of el) as text)
		end try
		try
			set v to value of el
			if class of v is text then set testo to testo & "|" & v
		end try
	end tell
	return testo & "|"
end testoDi

on identificatoreDi(el)
	try
		tell application "System Events" to return (value of attribute "AXIdentifier" of el) as text
	end try
	return ""
end identificatoreDi

on ruoloDi(el)
	try
		tell application "System Events" to return (role of el) as text
	end try
	return ""
end ruoloDi

on valoreDi(el)
	try
		tell application "System Events" to return (value of el) as integer
	end try
	return -1
end valoreDi

-- =====================================================================
--  Stato, permessi, configurazione, log
-- =====================================================================

-- Vero se fra gli schermi collegati ce n'e' uno con il nome dell'Apple TV
on giaCollegato()
	-- 1) fra gli schermi visti dal sistema (con "schermo esteso")
	try
		tell application "System Events" to set nomi to display name of every desktop
		repeat with n in nomi
			try
				if (n as text) contains nomeAppleTV then return true
			end try
		end repeat
	end try
	-- 2) fra i display elencati dal sistema (anche con "duplica")
	try
		set comando to "/usr/sbin/system_profiler SPDisplaysDataType -json 2>/dev/null | /usr/bin/grep -c -E " & quoted form of ("\"_name\" ?: ?\"" & nomeAppleTV & "\"") & " || true"
		set conteggio to do shell script comando
		if (conteggio as integer) > 0 then return true
	end try
	return false
end giaCollegato

-- Prova davvero a leggere la barra dei menu: se fallisce, dice quale permesso manca.
-- Restituisce "ok", "accessibilita" oppure "automazione".
on statoPermessi()
	try
		tell application "System Events" to tell process "ControlCenter" to get count of menu bars
		return "ok"
	on error messaggio number numero
		my scrivi("Prova dei permessi: " & messaggio & " [" & numero & "]")
		return my tipoPermessoDaErrore(numero, messaggio)
	end try
end statoPermessi

on tipoPermessoDaErrore(numero, messaggio)
	if numero is -1743 then return "automazione"
	if numero is -25211 or numero is -1719 then return "accessibilita"
	set m to messaggio as text
	if m contains "assistive" or m contains "accessibilit" then return "accessibilita"
	if m contains "not authorized" or m contains "non autorizzat" or m contains "autorizzazione" then return "automazione"
	return "ok"
end tipoPermessoDaErrore

on chiediPermessi(tipo)
	set aGrave to character id 224
	set eGrave to character id 232
	activate
	if tipo is "automazione" then
		try
			display dialog nomeApp & " non ha il permesso di controllare \"System Events\" (gli serve per fare i clic al posto tuo). Probabilmente e' stato premuto \"Non consentire\"." & return & return & "Nella finestra che si apre: Automazione > " & nomeApp & " > attiva l'interruttore di \"System Events\"." & return & "Poi apri di nuovo " & nomeApp & "." buttons {"Apri Impostazioni"} default button 1 with title nomeApp with icon caution
		end try
		do shell script "open 'x-apple.systempreferences:com.apple.preference.security?Privacy_Automation'"
	else
		try
			display dialog "Per collegare l'Apple TV da solo, " & nomeApp & " ha bisogno del permesso \"Accessibilit" & aGrave & "\"." & return & return & "1. Nella finestra che si apre, attiva l'interruttore accanto a \"" & nomeApp & "\" (se non c'" & eGrave & ", premi + e scegli l'app nella cartella Applicazioni)." & return & "2. Poi apri di nuovo " & nomeApp & "." & return & return & "Se l'interruttore era GI" & (character id 192) & " acceso e non funziona: selezionalo, premi il tasto - per toglierlo, poi + per rimetterlo. Oppure apri di nuovo INSTALLA AIRPLAY AUTOMATICO.command, che rif" & aGrave & " l'app da capo." buttons {"Apri Impostazioni"} default button 1 with title nomeApp with icon caution
		end try
		do shell script "open 'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility'"
	end if
end chiediPermessi

on cartellaConfig()
	return (POSIX path of (path to application support from user domain)) & nomeApp & "/"
end cartellaConfig

-- Legge il nome dell'Apple TV; se manca lo chiede e lo salva
on leggiNomeAppleTV()
	set f to (my cartellaConfig()) & "apple-tv.txt"
	set nome to ""
	try
		set nome to do shell script "head -n 1 " & quoted form of f & " 2>/dev/null"
	end try
	set nome to my pulisci(nome)
	if nome is "" then
		try
			activate
			set risposta to display dialog "Come si chiama l'Apple TV a cui collegarti?" & return & "(il nome che vedi in Centro di Controllo > Duplica schermo)" default answer "Apple TV" buttons {"Annulla", "OK"} default button "OK" cancel button "Annulla" with title nomeApp
			set nome to my pulisci(text returned of risposta)
			if nome is not "" then
				do shell script "mkdir -p " & quoted form of (my cartellaConfig()) & " && printf '%s\\n' " & quoted form of nome & " > " & quoted form of f
			end if
		on error
			set nome to ""
		end try
	end if
	return nome
end leggiNomeAppleTV

-- Toglie spazi e a capo all'inizio e alla fine
on pulisci(s)
	set s to s as text
	set spazi to {space, tab, return, linefeed}
	repeat while (length of s) > 0 and (character 1 of s) is in spazi
		if (length of s) is 1 then
			set s to ""
		else
			set s to text 2 thru -1 of s
		end if
	end repeat
	repeat while (length of s) > 0 and (character -1 of s) is in spazi
		if (length of s) is 1 then
			set s to ""
		else
			set s to text 1 thru -2 of s
		end if
	end repeat
	return s
end pulisci

-- Scrive una riga nel file di log (~/Library/Logs/AirPlayAutomatico.log)
on scrivi(messaggio)
	try
		set riga to (do shell script "date '+%Y-%m-%d %H:%M:%S'") & "  " & messaggio
		do shell script "mkdir -p \"$HOME/Library/Logs\"; printf '%s\\n' " & quoted form of riga & " >> \"$HOME/Library/Logs/AirPlayAutomatico.log\""
	end try
end scrivi
