(*
	Involucro minimo dell'app "AirPlay Automatico".

	Non fa altro che avviare lo script vero (airplay-automatico.scpt) che l'installatore
	mette nella cartella di configurazione. Questo file non cambia mai nel tempo, cosi'
	il permesso "Accessibilita'" concesso all'app resta valido anche quando lo script
	viene aggiornato.
*)

on run
	set percorso to (POSIX path of (path to application support from user domain)) & "AirPlay Automatico/airplay-automatico.scpt"
	try
		run script (POSIX file percorso)
	on error messaggio number numero
		if numero is not -128 then
			activate
			display dialog "AirPlay Automatico non " & (character id 232) & " riuscito a partire:" & return & messaggio & return & return & "Prova a rilanciare \"INSTALLA AIRPLAY AUTOMATICO.command\"." buttons {"OK"} default button 1 with icon stop
		end if
	end try
end run
