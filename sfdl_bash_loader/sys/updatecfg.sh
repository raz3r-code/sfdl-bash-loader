#!/bin/bash
pwd='$pwd'
ppwd='$pwd/..'
source "$1"     #./loader.cfg.new
source "$2"	#./loader.cfg.bak
source "$3"	#./force.cfg

echo -e "debug=$debug						# debug true/false 
sfdl_logo=$sfdl_logo						# ascii logo true/false
sfdl_color_text=$sfdl_color_text					# text mit farbe true/false
sfdl_entferne_logs=$sfdl_entferne_logs					# wget download-logs entfernen true/false
sfdl_fortsetzen=$sfdl_fortsetzen					# ask = fragen, true = immer fortsetzen, false = immer neu laden
sfdl_wget_download=$sfdl_wget_download					# true = wird mit wget laden, false = wird wget download ignorieren
sfdl_wget_max_retry=$sfdl_wget_max_retry					# maximale anzahl an versuchen eine datei zu laden 0 = unbegrenzt
sfdl_wget_max_retry_index=$sfdl_wget_max_retry_index				# versuche fuer index laden
sfdl_rar_auspacken=$sfdl_rar_auspacken					# rar archive auspacken true/false
sfdl_rar_entfernen=$sfdl_rar_entfernen					# rar archive nach dem auspacken entfernen true/false
sfdl_xrel_tmdb_mod=$sfdl_xrel_tmdb_mod					# lade daten von xrel.to und tmdb.org true/false
sfdl_wget_multithread=$sfdl_wget_multithread				# true = es werden gleichzeitig mehrere dateien geladen
sfdl_wget_multithreads=$sfdl_wget_multithreads				# sfdl = MaxDownloadThreads, sfdl_wget_multithreads=10 z.B. ueberschreibt die vorgabe durch MaxDownloadThreads und oeffnet 10 gleichzeitige verbindungen
sfdl_eigenwerbung=$sfdl_eigenwerbung					# schreibt werbung in den speedreport
sfdl_chmod=$sfdl_chmod						# Rechte verteilung der Daten nach und während dem download/ nach dem Entpacken
sfdl_update=$sfdl_update						# ask = fragen, true = immer updaten, false = nicht updaten
#==========================================================================================================
uscript_folder=\"$uscript_folder\"   			#absoluter Pfad zu script Ordner
uscript_befor=$uscript_befor               			#Userscript vor dem Download ausführen. true zum aktivieren
uscript_after=$uscript_after               			#Userscript nach dem Download ausführen. true zum aktivieren
uscript_end=$uscript_end               				#Userscript nach dem kompletten Download ausführen. true zum aktivieren
#==========================================================================================================
#Features
history=$history						# true = es wird in /logs/History.txt der Download verlauf mit Datum angelegt.
sample_remove=$sample_remove        #entfernt alle daten im Download ordner die das wort "sample" enthalten. (achtung bei filmen oder sereien die eventuell einen namen mit sample haben.
#==========================================================================================================
#Proxy Einstellungen
proxy=$proxy                     			#true zum proxy aktivieren 
proxyauth=$proxyauth                   			#true wenn proxy Username oder password erforderlich. ansonsten werden die user und pass ignoriert
proxytyp=$proxytyp                     			#http ACHTUNG: lftp unterstützt nur HTTP!!
proxyuser=$proxyuser                        			#wenn erforderlich
proxypass=$proxypass                        			#wenn erforderlich
proxyip=$proxyip                         	 		#ip angabe wenn aktiviert
proxyport=$proxyport                        			#proxy Port
#==========================================================================================================
sfdl_files=\"$sfdl_files\"				# pfad wo sfdl files gesucht werden
sfdl_logs=\"$sfdl_logs\"					# wget download logs
sfdl_downloads=\"$sfdl_downloads\"			# pfad wo downloads gespeichert werden
sfdl_sys=\"$sfdl_sys\"						# pfad fuer wichtige tools
sfdl_status=\"$sfdl_status\"				# pfad zur status dir
#==========================================================================================================
# unrar: alternative versionen falls systemweit kein unrar installiert ist (nur fuer den notfall gedacht!), besser: apt-get install unrar
# sfdl_unrar="'"$sfdl_sys/unrar-3.4-openbsd/unrar"'"
# sfdl_unrar="'"$sfdl_sys/unrar-3.7.7-centos/unrar"'"
# sfdl_unrar="'"$sfdl_sys/unrar-4.1.3-armv4l/unrar"'"
# sfdl_unrar="'"$sfdl_sys/unrar-5.3.7-arm/unrar"'"
sfdl_unrar=\"$sfdl_unrar\"
# ========================================================================================================
tmdb_api_key=\"$tmdb_api_key\" 	# kodi api key: $tmdb_api_key
tmdb_language=\"$tmdb_language\"					# de = informationen zum film sind immer deutsch
# wird in die kodi.nfo eingetragen und kodi wird hier nach dem film suchen
# alternativen z.b. \"smb://user:pass@127.0.0.1/filme\" oder ein lokaler pfad wie \"/home/kodi/filme\"
kodi_pfad_zum_film=\"$kodi_pfad_zum_film\" 		# kein / am ende
kodi_pfad_zum_cover=\"$kodi_pfad_zum_cover\"		# oder z.b. \"http://127.0.0.1/cover\" kein / am ende
kodi_pfad_zum_hintergrund=\"$kodi_pfad_zum_hintergrund\"	# kein / am ende
kodi_pfad_zum_actor=\"$kodi_pfad_zum_actor\"		# kein / am ende
# ========================================================================================================
sfdl_status_webserver=$sfdl_status_webserver				# schaltet webserver an oder aus; true = ein | false = aus
sfld_status_webserver_port=$sfld_status_webserver_port				# legt den port fest, unter dem der webserver errreichbar ist
sfdl_status_json_file=\"$sfdl_status_json_file\"		# json status datei
sfdl_status_start_passwort=\"$sfdl_status_start_passwort\"			# legt das passwort fuer den bash loader remote start fest (UNBEDINGT AENDERN!!!)
sfdl_status_stop_passwort=\"$sfdl_status_stop_passwort\"				# legt das passwort zum beenden des laufnden bash loaders fest (UNBEDINGT AENDERN!!!)
sfdl_status_kill_passwort=\"$sfdl_status_kill_passwort\"			# legt das passwort zum remote beenden des webservers fest (UNBEDINGT AENDERN!!!)
sfdl_status_timout=$sfdl_status_timout					# webserver timout
sfdl_status_php_ini_path=\"$sfdl_status_php_ini_path\"				# pfad in der die php.ini abgelegt ist
sfdl_status_doc_root=\"$sfdl_status_doc_root\"			# doc root - pfad zu den html/php usw files" >"$4"
