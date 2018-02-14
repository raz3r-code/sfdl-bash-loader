#!/bin/bash
# ==========================================================================================================
# SFDL BASH-Loader - liebevoll gescripted von GrafSauger und raz3r
# ==========================================================================================================
# 888888b.         d8888  .d8888b.  888    888        888                            888
# 888  "88b       d88888 d88P  Y88b 888    888        888                            888
# 888  .88P      d88P888 Y88b.      888    888        888                            888
# 8888888K.     d88P 888  "Y888b.   8888888888        888      .d88b.   8888b.   .d88888  .d88b.  888d888
# 888  "Y88b   d88P  888     "Y88b. 888    888        888     d88""88b     "88b d88" 888 d8P  Y8b 888P"
# 888    888  d88P   888       "888 888    888 888888 888     888  888 .d888888 888  888 88888888 888
# 888   d88P d8888888888 Y88b  d88P 888    888        888     Y88..88P 888  888 Y88b 888 Y8b.     888
# 8888888P" d88P     888  "Y8888P"  888    888        88888888 "Y88P"  "Y888888  "Y88888  "Y8888  888
# ==========================================================================================================
# sfdl bash loader version
sfdl_version="3.11"

IFSDEFAULT=$IFS

# pfad definieren
# osx: kann nun auch unter mac osx mit doppelklick vom desktop aus gestartet werden
osxcheck=$(uname)
if [ $osxcheck == "Darwin" ]; then
	realpath() {
		[[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
	}
	osxpath="$(realpath "$0")"
	pwd=$(dirname "${osxpath}")
else
	pwd="`dirname \"$0\"`"
fi

# loader basispfad
ppwd="$(dirname "$pwd")"

# lade config
source "$pwd/loader.cfg"

# macht das bild sauber
if [ $debug == false ]; then
	clear
fi

# loader version exportieren
echo -n "$sfdl_version" > "$sfdl_logs/version.txt"

# bringt hoffentlich licht ins dunkle ($1 = passwort, $2 = aes-128-cbc)
function aes128cbc {
	aes_pass_md5="$(echo -n "$1" | md5sum | cut -d '-' -f1 | tr -d '[[:space:]]')"
	aes_iv="$(echo $2 | xxd -l 16 -ps)"
	echo $2 | openssl enc -d -a -A -aes-128-cbc -iv $aes_iv -K $aes_pass_md5 2> /dev/null| tail -c +17
}
function BruteForce {
	while IFS='' read -r line || [[ -n "$line" ]]; do
		serverip="$(aes128cbc "$line" "$1" | grep -E -o '([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})')"
		if [ -n "$serverip" ]; then
			echo $line
			break
		fi
	done < "$2"
}
function printText {
	if [ $sfdl_color_text == true ]; then
		echo $'\e[40;38;5;82m' $1 $'\e[97m'$2 $'\e[0m'
	else
		echo  $1 $2
	fi
}
function printErr {
	if [ $sfdl_color_text == true ]; then
		echo $'\e[40;38;5;13m' $1 $'\e[0m'
	else
		echo  $1
	fi
}
function printLinie {
	if [ $sfdl_logo == true ]; then
		if [ $sfdl_color_text == true ]; then
			echo $'\e[1;33;40m'=========================================================================================================$'\e[49m'
		else
			echo -e "========================================================================================================="
		fi
	else
		if [ $sfdl_color_text == true ]; then
			echo $'\e[1;33;40m'==================================================$'\e[49m'
		else
			echo -e "=================================================="
		fi
	fi
}

# erstellt die json status page
# $1 = status (running/done), $2 = name der sfld datei, die gerade in arbeit ist
function printJSON {
	DATETIME=`date +'%d.%m.%Y - %H:%M:%S'`
	JSDATE=`date -u +"%FT%T.000Z"`

	if [ -z "$3" ]; then
		ACTION="NULL"
	else
		ACTION="$3"
	fi

	if [ -z "$4" ]; then
		LOADING="NULL"
	else
		LOADING="$4"
	fi

	if [ -z "$5" ]; then
		LOADING_MT_FILES="NULL"
	else
		LOADING_MT_FILES="$5"
	fi

	if [ -z "$6" ]; then
		LOADING_TOTAL_FILES="NULL"
	else
		LOADING_TOTAL_FILES="$6"
	fi

	if [ -z "$7" ]; then
		LOADING_FILE_ARRAY="NULL"
	else
		LOADING_FILE_ARRAY="$7"
	fi

	echo -e "{ \"BASHLoader\" : [ { \"version\":\"$sfdl_version\", \"date\":\"$JSDATE\", \"datetime\":\"$DATETIME\", \"status\":\"$1\", \"sfdl\":\"$2\", \"action\":\"$ACTION\", \"loading_mt_files\":\"$LOADING_MT_FILES\", \"loading_total_files\":\"$LOADING_TOTAL_FILES\", \"loading\":\"$LOADING\", \"loading_file_array\":\"$LOADING_FILE_ARRAY\" } ] }" > "$sfdl_status_json_file"
}

# erstelle gleich mal einen status
printJSON "running" "NULL"

# teste auf vorhandene system tools
if hash wget 2>/dev/null; then
	if [ $debug == true ]; then
		printText "Tooltest:" "wget gefunden!"
	fi
else
	printErr "ERROR 901: wget nicht gefunden!"
	printJSON "exit" "NULL" "901"
	exit 901
fi

# teste auf vorhandene system tools
if hash lftp 2>/dev/null; then
	if [ $debug == true ]; then
		printText "Tooltest:" "lftp gefunden!"
	fi
else
	printErr "ERROR 901: lftp nicht gefunden!"
	printJSON "exit" "NULL" "901"
	exit 901
fi

# auf welchem system laufe ich?
sysname=$(uname)
if [ $sysname == "Linux" ]
then
	syscore="linux"
elif [ $sysname == "FreeBSD" ]
then
	syscore="freebsd"
	sfdl_xrel_tmdb_mod=false
elif [ $sysname == "Darwin" ]
then
	syscore="darwin"
	sfdl_xrel_tmdb_mod=false
else
	syscore="unbekannt"
fi

# starte webserver
# jetzt wird es kompliziert, da die status.sh durchaus mehrfach gestartet wird
# meistens dreimal und das auch so sein soll. also kompliziert, um falsch positive
# ergebnisse zu vermeiden.
if [ $sysname == "Darwin" ]; then
    MYIP=`ifconfig | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p'`
else
    MYIP=`hostname -I | cut -d' ' -f1`
fi

WWW=()
IFS=$'\r\n'
WWW=`ps aux | grep 'status.py' | grep -v 'grep'`
IFS=$'\n' read -rd '' -a WWW <<<"$WWW"
WWWCNT=${#WWW[@]}

if [ "$WWWCNT" == 0 ]; then
	if [ $sfdl_status_webserver == true ]; then
		python "$sfdl_sys/status.py" "port=$sfld_status_webserver_port" > /dev/null 2>&1 &
		WEBSERVER="ONLINE"
		if [ $debug == true ]; then
			echo "Webserver (status.py) wird gestartet!"
		fi
	fi
else
	if [ $sfdl_status_webserver == false ]; then
		pkill -f status.py
		WEBSERVER="OFFLINE"
		if [ $debug == true ]; then
			echo "Webserver (status.py) wurde beendet!"
		fi
	else
		WEBSERVER="ONLINE"
		if [ $debug == true ]; then
			echo "Webserver (status.py) ist online!"
		fi
	fi
fi

# welche wget version?
wget_version="0.0.0"
wgetcmd=`wget --version`
regEx='GNU Wget ([0-9]*.[0-9]*|[0-9]*.[0-9]*.[0-9]*)'
if [[ "$wgetcmd" =~ $regEx ]]; then
	wget_version=${BASH_REMATCH[1]};
	if [ $debug == true ]; then
		echo "wget Version: $wget_version"
	fi
fi

# logo oder nicht logo
if [ $sfdl_logo == true ]; then
	echo $'\e[8;35;105t'
	if [ $osxcheck == "Darwin" ]; then
		echo $'\e[40m'
	fi
	if [ $debug == false ]; then
			clear
		fi
	if [ $sfdl_color_text == true ]; then
		echo $'\e[1;33;40m''===[SFDL BASH-Loader '$sfdl_version' (GrafSauger,raz3r)]==========================================================='
		rand=$(((RANDOM % 5) + 1))
		if [ $rand = 1 ]
		then
			txColor=183
		elif [ $rand = 2 ]
		then
			txColor=234
		elif [ $rand = 3 ]
		then
			txColor=28
		elif [ $rand = 4 ]
		then
			txColor=196
		else
			txColor=40
		fi
		while IFS='' read -r line || [[ -n "$line" ]]; do
			echo $'\e[38;5;'$txColor'm'"$line"
			txColor=$((txColor+1))
		done < "$sfdl_sys/logo.txt"
		echo -e "                                                                                                         "
		echo $'\e[1;33;40m'=========================================================================================================$'\e[1;39;49m'
	else
		echo -e "===[SFDL BASH-Loader $sfdl_version (GrafSauger,raz3r)]============================================================="
		cat "$sfdl_sys/logo.txt"
		echo -e "                                                                                                         "
		echo -e "========================================================================================================="
	fi
else
	if [ $sfdl_color_text == true ]; then
		echo $'\e[44m''==[SFDL BASH-Loader v$sfdl_version (GrafSauger,raz3r)]=='$'\e[49m'
	else
		echo -e "==[SFDL BASH-Loader v$sfdl_version (GrafSauger,raz3r)]=="
	fi
fi

# haben wir sfdl files?
for sfdl in "$sfdl_files"/*.sfdl
do
	if [ $uscript_befor == true ]; then
		echo "Userscript wird ausgeführt. Bitte warten...."
		"$uscript_folder"/before.sh
		echo "Userscript wurde ausgeführt"
	fi
	
	if [ -f "$sfdl" ]; then
		# dieses sfdl files wird gerade verarbeitet
		ladesfdl="${sfdl##*/}"
		bsize=0
		printText "SFDL Datei:" "$ladesfdl"
		printJSON "running" "$ladesfdl" "Lese SFDL Datei"
		# lese daten aus dem xml
		name="$(cat $sfdl | grep -m1 '<Description' | cut -d '>' -f 2 | cut -d '<' -f 1)"
		name="$(echo -n "$name" | sed 's/​//g')"
		if [ -z "$name" ]; then
			name="${ladesfdl%.sfdl}"
		fi
		upper="$(cat $sfdl | grep -m1 '<Uploader' | cut -d '>' -f 2 | cut -d '<' -f 1)"
		fversion="$(cat $sfdl | grep -m1 '<SFDLFileVersion' | cut -d '>' -f 2 | cut -d '<' -f 1)"
		crypt="$(cat $sfdl | grep -m1 '<Encrypted' | cut -d '>' -f 2 | cut -d '<' -f 1)"
		host="$(cat $sfdl | grep -m1 '<Host' | cut -d '>' -f 2 | cut -d '<' -f 1)"
		port="$(cat $sfdl | grep -m1 '<Port' | cut -d '>' -f 2 | cut -d '<' -f 1)"
		maxdl="$(cat $sfdl | grep -m1 '<MaxDownloadThreads' | cut -d '>' -f 2 | cut -d '<' -f 1)"
		auth="$(cat $sfdl | grep -m1 '<AuthRequired' | cut -d '>' -f 2 | cut -d '<' -f 1)"
		username="$(cat $sfdl | grep -m1 '<Username' | cut -d '>' -f 2 | cut -d '<' -f 1)"
		password="$(cat $sfdl | grep -m1 '<Password' | cut -d '>' -f 2 | cut -d '<' -f 1)"

		# anonymous ftp
		if [ $auth == false ]; then
			username="anonymous"
			password="anonymous@anonymous.nix"
		fi
		if [ -z $username ]; then
			username="anonymous"

			if [ -z $password ]; then
				password="anonymous@anonymous.nix"
			fi
		fi

		bmode="$(cat $sfdl | grep -m1 '<BulkFolderMode' | cut -d '>' -f 2 | cut -d '<' -f 1)"
		if [ $bmode == true ]; then
            IFS=$'\n'
			bpath="$(cat $sfdl | grep -m1 '<BulkFolderPath' | cut -d '>' -f 2 | cut -d '<' -f 1)"
			if [ $crypt == false ]; then
				IFS=$'\n'
				bpath=($(cat $sfdl | grep '<BulkFolderPath' | cut -d '>' -f 2 | cut -d '<' -f 1 | sed 's/ /\&#32;/g' | sort -u))
				bsizex=()
				brootx=()
				filearray=()

				bpathArrCnt=${#bpath[@]}

				# entferne alten wget index (falls vorhanden)
				if [ -f "$sfdl_downloads/$name/index.html" ]; then
					rm -f "$sfdl_downloads/$name/index.html"
				fi

				# entferne alten lftp index (falls vorhanden)
				if [ -f "$sfdl_logs/$ladepfad"_lftp_index.log ]; then
					rm -f "$sfdl_logs/$ladepfad"_lftp_index.log
				fi
				if [ -f "$sfdl_logs/$ladepfad"_lftp_error.log ]; then
                                        rm -f "$sfdl_logs/$ladepfad"_lftp_error.log
                                fi
				# index mit lftp laden (rekursiv)
				if [ $bpathArrCnt == 1 ]; then
					sfdl_wget_download=false
					sfdl_lftp_download=true
					
					i=${bpath[0]}
                    i="$(echo $i | sed 's/&#32;/ /g')"
					i="$(echo $i | sed 's@/*$@@g')" # danke tenti

					ladepfad="${i##*/}"
					printText "Lade Index (lftp):" "$ladepfad"

					lftp -p $port -u "$username","$password" -e "set net:timeout 5; set net:reconnect-interval-base 5; set net:max-retries 2; set ftp:ssl-allow no; open && find -l '$i' && exit" $host 2> $sfdl_logs/$ladepfad'_lftp_error.log' 1> $sfdl_logs/$ladepfad'_lftp_index.log'
					if [ -s "$sfdl_logs/$ladepfad"_lftp_error.log ]; then
						printErr "FEHLER: Es konnte kein Index der FTP-Daten erstellt werden!"
                                                printErr "$ladesfdl wird uebersprungen!"
                                                printLinie
						mkdir -p "$sfdl_files"/error
						mv "$sfdl" "$sfdl_files"/error/$name.sfdl
                                                continue
					fi
					if [ -f "$sfdl_logs/$ladepfad"_lftp_index.log ]; then
						IFS=$IFSDEFAULT
						while IFS='' read -r line || [[ -n "$line" ]]; do
							if [[ "$line" != d* ]]
							then
								#fixxed by raz3r
								byte=0
								if [ $sysname == "Darwin" ]; then
									may_byte="$(echo $line | cut -d ' ' -f 3)"

									if [[ $may_byte =~ ^-?[0-9]+$ ]]; then
 								  	byte=$may_byte
									else
   									byte="$(echo $line | cut -d ' ' -f 2)"
									fi

								else
										byte="$(echo $line | grep -oP "\s+\K\d*\d" | sed q)"
								fi

								if [ $byte -ne 0 ]; then
									file=${line##*/}
									bsize=$((bsize+byte))
									filearray+=($(echo "$file|$byte"))
								fi
							fi
						done < "$sfdl_logs/$ladepfad"_lftp_index.log

						if [ $debug == false ]; then
							rm -f "$sfdl_logs/$ladepfad"_lftp_index.log
						fi
					else
						printErr "FEHLER: Es konnte kein Index der FTP-Daten erstellt werden!"
						printErr "$ladesfdl wird uebersprungen!"
						printLinie
						continue
					fi
				else
					# index mit wget laden
					sfdl_wget_download=true
					sfdl_lftp_download=false
					for i in "${bpath[@]}"; do
						i="$(echo $i | sed 's/&#32;/ /g')"
						i="$(echo $i | sed 's@/*$@@g')" # danke tenti
						ladepfad="${i##*/}"
						printText "Lade Index (wget):" "$ladepfad"

						wget -t $sfdl_wget_max_retry_index --retry-connrefused --no-remove-listing -P "$sfdl_downloads/$name" --ftp-user="$username" --ftp-password="$password" "ftp://$host:$port$i/" 2> $sfdl_logs/$ladepfad'_wget_index.log'
						if [ -f "$sfdl_downloads/$name/index.html" ]; then
							while IFS='' read -r line || [[ -n "$line" ]]; do
								regEx='.*(File|Datei).*<a href="(.*)">(.*)<\/a>.*\(([0-9]*) [Bb]ytes\)'
								if [[ "$line" =~ $regEx ]]; then
									f_1=${BASH_REMATCH[2]};
									f_2=${BASH_REMATCH[3]};
									f_3=${BASH_REMATCH[4]};
									f_1="$(echo $f_1 | sed 's/&#32;/ /g')" # wandelt &#32; in leerzeichen um
									broot+=($(echo \"$f_1\"))
									bsize=$((bsize+f_3))
									filearray+=($(echo "$f_2|$f_3"))
								fi
							done < "$sfdl_downloads/$name/index.html"

							if [ $debug == false ]; then
								rm -f "$sfdl_downloads/$name/"index.html*
								rm -f "$sfdl_downloads/$name/".listing
								rm -f "$sfdl_logs/$ladepfad"_wget_index.log
							fi
						else
							printErr "FEHLER: Es konnte kein Index der FTP-Daten erstellt werden!"
							printErr "$ladesfdl wird uebersprungen!"
							printLinie
							continue
						fi
					done
				fi
			fi
		else
			IFS=$'\n'
			# total download size
			bsizex=($(cat $sfdl | grep '<FileSize' | cut -d '>' -f 2 | cut -d '<' -f 1))
			bsize=0
			for i in "${bsizex[@]}"
			do
				bsize=$((bsize+i))
			done

			if [ $crypt == true ]; then
				droot=($(cat $sfdl | grep '<FileFullPath' | cut -d '>' -f 2 | cut -d '<' -f 1))
			else
				droot=($(cat $sfdl | grep '<FileFullPath' | cut -d '>' -f 2 | cut -d '<' -f 1 | sort -u))
				drootMTH=()
				for i in "${droot[@]}"; do
					drootMTH+=($(echo \"ftp://$host:$port${i}\"))
				done
			fi
		fi

		# vorhandenen speicherplatz anzeigen
		if hash awk 2>/dev/null; then
			hddspace="$(df -hl $sfdl_downloads | awk 'NR==2 {print $4}')"
			printText "Verfuegbarer Speicherplatz:" "$hddspace in $sfdl_downloads"
		fi

		# debug
		if [ $debug == true ]; then
			echo ===[DEBUG]=====================================
			echo sfdl_wget_multithread: $sfdl_wget_multithread
			echo sfdl_wget_multithreads: $sfdl_wget_multithreads
			echo wget: $wget_version
			echo SFDL Datei: $sfdl
			echo Description: $name
			echo Uploader: $upper
			echo SFDLFileVersion: $fversion
			echo MaxDownloadThreads: $maxdl
			echo Encrypted: $crypt
			echo Host: $host
			echo Port: $port
			echo AuthRequired: $auth
			echo Username: $username
			echo Password: $password
			echo BulkFolderMode: $bmode
			echo Download Size: $bsize
			echo *NIX System: $syscore
			echo filearray: Array mit ${#filearray[@]} Elementen ...
			for i in "${filearray[@]}"
			do
				echo "filearray: $i"
			done

            echo BulkFolderPath: $bpath
            if [ $sfdl_wget_multithread == true ]; then
                if [ $crypt == false ]; then
                    echo sfdl_wget_multithread: Array mit ${#broot[@]} Elementen ...
                    for i in "${broot[@]}"
                    do
                        echo broot: $i
                    done
                fi
            fi

            echo DirectoryRoot: Array mit ${#drootMTH[@]} Elementen ...
            if [ $sfdl_wget_multithread == true ]; then
                for i in "${drootMTH[@]}"
                do
                    echo drootMTH: $i
                done
            else
                for i in "${droot[@]}"
                do
                    echo droot: $i
                done
            fi
			echo =====================================[DEBUG]===
		fi

		# verschluesselt?
		if [ $crypt == true ]; then
			printErr "$ladesfdl ist verschluesselt!"
			byte=0
			
			# ist openssl, xxd und md5sum vorhanden?
			if { hash openssl 2>/dev/null; } && { hash xxd 2>/dev/null; } && { hash md5sum 2>/dev/null; } && { hash tail 2>/dev/null; } then
				addNewPass="false"
				if [ -f "$sfdl_sys/passwords.txt" ]; then
					printText "AES:" "Versuche alle Passwoerter aus der Liste"
					aes_pass="$(BruteForce "$host" "$sfdl_sys/passwords.txt")"
					if [ -n "$aes_pass" ]; then
						printText "AES:" "Passwort gefunden, entschluessle SFDL mit: $aes_pass"
					else
						addNewPass="true"
						printText "AES:" "Keines der Passwoerter war beim Entschluesseln hilfreich"
					fi
				else
					addNewPass="true"
				fi

				while [[ -z "$aes_pass" ]]
				do
					printJSON "running" "$ladesfdl" "Warte auf Passworteingabe"
					read -p "Bitte Passwort eingeben: " aes_pass
				done

				# entschluesseln
				host="$(aes128cbc "$aes_pass" "$host" | grep -E -o '([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})')"
				# konnte host entschluesselt werden?
				if [ -z "$host" ]; then
					printErr "$ladesfdl kann mit Passwort $aes_pass nicht entschluesselt werden!"
					printErr "$ladesfdl wird uebersprungen!"
					continue
				else
					if [ $addNewPass == "true" ]; then
						echo -e "$aes_pass" >> "$sfdl_sys/passwords.txt"
					fi
				fi

				name="$(aes128cbc "$aes_pass" "$name")"
				name="$(echo -n "$name" | sed 's/​//g')"
				if [ -z "$name" ]; then
					name="${ladesfdl%.sfdl}"
				fi
				upper="$(aes128cbc "$aes_pass" "$upper")"
				username="$(aes128cbc "$aes_pass" "$username")"
				password="$(aes128cbc "$aes_pass" "$password")"

				# anonymous ftp
				if [ -z $username ]; then
					username="anonymous"

					if [ -z $password ]; then
						password="anonymous@anonymous.nix"
					fi
				fi

				if [ $bmode == true ]; then
					bpath="$(aes128cbc "$aes_pass" "$bpath")"
					if [ $sfdl_wget_multithread == true ]; then
						IFS=$'\n'
						bpath_crypt=($(cat $sfdl | grep '<BulkFolderPath' | cut -d '>' -f 2 | cut -d '<' -f 1))
						bpath=()
						for i in "${bpath_crypt[@]}"; do
							bpath+="$(aes128cbc "$aes_pass" "$i")"
						done
						bsizex=()
						brootx=()
						filearray=()

						bpathArrCnt=${#bpath[@]}

						# entferne alten wget index (falls vorhanden)
						if [ -f "$sfdl_downloads/$name/index.html" ]; then
							rm -f "$sfdl_downloads/$name/index.html"
						fi

						# entferne alten lftp index (falls vorhanden)
						if [ -f "$sfdl_logs/$ladepfad"_lftp_index.log ]; then
							rm -f "$sfdl_logs/$ladepfad"_lftp_index.log
						fi
						if [ -f "$sfdl_logs/$ladepfad"_lftp_error.log ]; then
                                                        rm -f "$sfdl_logs/$ladepfad"_lftp_error.log
                                                fi

						# index mit lftp laden (rekursiv)
						if [ $bpathArrCnt == 1 ]; then
							sfdl_wget_download=false
							sfdl_lftp_download=true
							
							i=${bpath[0]}
                            				i="$(echo $i | sed 's/&#32;/ /g')"
							i="$(echo $i | sed 's@/*$@@g')" # danke tenti
							
							ladepfad="${i##*/}"
							printText "Lade Index (lftp):" "$ladepfad"

							lftp -p $port -u "$username","$password" -e "set net:timeout 5; set net:reconnect-interval-base 5; set net:max-retries 2; set ftp:ssl-allow no; open && find -l '$i' && exit" $host 2> $sfdl_logs/$ladepfad'_lftp_error.log' 1> $sfdl_logs/$ladepfad'_lftp_index.log'
							if [ -s "$sfdl_logs/$ladepfad"_lftp_error.log ]; then
                                                		printErr "FEHLER: Es konnte kein Index der FTP-Daten erstellt werden!"
                                                		printErr "$ladesfdl wird uebersprungen!"
                                                		printLinie
								mkdir -p "$sfdl_files"/error
                                                		mv "$sfdl" "$sfdl_files"/error/$name.sfdl
								continue
                                        		fi
							if [ -f "$sfdl_logs/$ladepfad"_lftp_index.log ]; then
								IFS=$IFSDEFAULT
								while IFS='' read -r line || [[ -n "$line" ]]; do
									if [[ "$line" != d* ]]
									then
										#fixxed by raz3r
										byte=0
										if [ $sysname == "Darwin" ]; then
											may_byte="$(echo $line | cut -d ' ' -f 3)"

											if [[ $may_byte =~ ^-?[0-9]+$ ]]; then
												byte=$may_byte
											else
												byte="$(echo $line | cut -d ' ' -f 2)"
											fi

										else
											byte="$(echo $line | grep -oP "\s+\K\d*\d" | sed q)"
										fi
									
										if [ $byte -ne 0 ]; then
                                            						file=${line##*/}
                                            						bsize=$((bsize+byte))
                                            						filearray+=("$(echo "$file|$byte")")
										fi
									fi
								done < "$sfdl_logs/$ladepfad"_lftp_index.log

								if [ $debug == false ]; then
									rm -f "$sfdl_logs/$ladepfad"_lftp_index.log
								fi
							else
								printErr "FEHLER: Es konnte kein Index der FTP-Daten erstellt werden!"
								printErr "$ladesfdl wird uebersprungen!"
								printLinie
								continue
							fi
						else
							# index mit wget laden
							sfdl_wget_download=true
							sfdl_lftp_download=false
							for i in "${bpath[@]}"; do
								i="$(echo $i | sed 's/&#32;/ /g')"
								i="$(echo $i | sed 's@/*$@@g')" # danke tenti
								ladepfad="${i##*/}"
								printText "Lade Index (wget):" "$ladepfad"
								wget -t $sfdl_wget_max_retry_index --retry-connrefused --no-remove-listing -q -P "$sfdl_downloads/$name" --ftp-user="$username" --ftp-password="$password" "ftp://$host:$port$i/" 2> $sfdl_logs/$ladepfad'_wget_index.log'
								if [ -f "$sfdl_downloads/$name/index.html" ]; then
									while IFS='' read -r line || [[ -n "$line" ]]; do
										regEx='.*(File|Datei).*<a href="(.*)">(.*)<\/a>.*\(([0-9]*) [Bb]ytes\)'
										if [[ "$line" =~ $regEx ]]; then
											f_1=${BASH_REMATCH[2]};
											f_2=${BASH_REMATCH[3]};
											f_3=${BASH_REMATCH[4]};
											f_1="$(echo $f_1 | sed 's/&#32;/ /g')" # wandelt &#32; in leerzeichen um
											broot+=($(echo \"$f_1\"))
											bsize=$((bsize+f_3))
											filearray+=($(echo "$f_2|$f_3"))
										fi
									done < "$sfdl_downloads/$name/index.html"

									if [ $debug == false ]; then
										rm -f "$sfdl_downloads/$name/"index.html*
										rm -f "$sfdl_downloads/$name/".listing
										rm -f "$sfdl_logs/$ladepfad"_wget_index.log
									fi
								else
									printErr "FEHLER: Es konnte kein Index der FTP-Daten erstellt werden!"
									printErr "$ladesfdl wird uebersprungen!"
									printLinie
									continue
								fi
							done
						fi
					fi
				else
					carr=0
					for i in "${droot[@]}"
					do
						droot[$carr]="$(aes128cbc "$aes_pass" "$i")"
						carr=$((carr+1))
					done
					drootMTH=()
					for i in "${droot[@]}"; do
						drootMTH+=($(echo \"ftp://$host:$port${i}\"))
					done
				fi

				# anonymous ftp
				if [ $auth == false ]; then
					username="anonymous"
					password="anonymous@anonymous.com"
				fi
				if [ -z $username ]; then
					username="anonymous"

					if [ -z $password ]; then
						password="anonymous@anonymous.com"
					fi
				fi

				# mehr debug nach der verschluesselung
				if [ $debug == true ]; then
					echo ===[DEBUG-CRYPT]===============================
					echo AES-Passwort: $aes_pass
					echo Description: $name
					echo Uploader: $upper
					echo Host: $host
					echo Username: $username
					echo Password: $password
					echo filearray: Array mit ${#filearray[@]} Elementen ...
					for i in "${filearray[@]}"
					do
						echo "filearray: $i"
					done
					if [ $bmode == true ]; then
						echo BulkFolderPath: $bpath
						echo sfdl_wget_multithread: Array mit ${#broot[@]} Elementen ...
						for i in "${broot[@]}"
						do
							echo broot: $i
						done
					else
						echo DirectoryRoot: Array mit ${#droot[@]} Elementen ...
						for i in "${drootMTH[@]}"
						do
							echo drootMTH: $i
						done
					fi
					echo ===============================[DEBUG-CRYPT]===
				fi
			else
				printErr "Es fehlt mindestens ein Programm zum entschluesseln: openssl, xxd, md5sum;"
				printErr "$sfdl wird uebersprungen!"
				printLinie
				continue
			fi
		fi

		# ping server
		if ping -q -c 1 $host &> /dev/null
		then
			printText "PING:" "Server hat auf einen PING geantwortet!"
		else
			printErr "ERROR: Server $host hat auf PING nicht geantwortet! Neuer Versuch..."
			if ping -q -c 5 $host &> /dev/null
			then
				printText "PING:" "Server $host hat nun erfogreich auf 5 PINGS geantwortet!"
			else
				printErr "ERROR: Server $host antwortet weiterhin auf keine PINGS! FTP online?"
			fi
		fi

		# speedreport erstellen?
		do_speedreport=true
		if [ $sfdl_wget_download == true ]; then
			dltimeX1=$(date +"%s" 2>/dev/null)
			if [ -z "dltime1" ]; then
				printErr "Es wird kein Speedreport erstellt, da - date - keine Antwort gab!"
				do_speedreport=false
			fi
		fi

		# lftp download
		# lftp vorhanden?
		if [ $sfdl_lftp_download == true ]; then
			sfdl_wget_download=false
			if hash lftp 2>/dev/null; then

                # wenn keine files vorhanden sind, skip download
                if [ ${#filearray[@]} -eq 0 ]; then
                    printErr "Leeres (filearray) Array: Keine Dateien gefunden!"
                    printErr "Kein Download moeglich, wird uebersprungen..."
                    continue
                fi

				# erstellt downloadverzeichnis manuell, um fehlermeldungen des prog.sh scriptes zu vermeiden
				# lftp erstellt den pfad erst, wenn die ersten daten eintreffen
				mkdir "$sfdl_downloads/$name" > /dev/null 2>&1

                IFS=$'\n'
				DLPATH=${bpath[0]}
                DLPATH="$(echo $DLPATH | sed 's/&#32;/ /g')"
				printText "Dateien die insgesamt geladen werden:" "${#filearray[@]}"
				printText "Dateien die gleichzeitig geladen werden:" "$maxdl"
				if [ $sfdl_wget_multithreads == sfdl ]; then
					maxdl=$maxdl
				else
					maxdl=$sfdl_wget_multithreads
				fi
				echo -n "${#filearray[@]}|$maxdl" > $sfdl_logs/dl.txt
				lftp -p $port -u "$username","$password" -e 'set ftp:ssl-allow no; mirror --continue --parallel="'$maxdl'" -vvv --log="'$sfdl_logs/$name'_lftp.log" "'$DLPATH'" "'$sfdl_downloads/$name'"; exit' $host > "$sfdl_logs/$name"_download.log | "$sfdl_sys/prog.sh" "$sfdl_downloads/$name" "$bsize" "$pwd" "${filearray[@]}"
			else
				printErr "Es wurde kein lftp gefunden! Bitte lftp installieren!"
				printLinie
				exit
			fi
		fi

		# wget download
		# wget vorhanden?
		if [ $sfdl_wget_download == true ]; then
			sfdl_lftp_download=false
			if hash wget 2>/dev/null; then
				# download pfad .... bulkmode true/false
				if [ $bmode == true ]; then
					printLinie
					printText "Download:" "$name"
					if [ ${#broot[@]} -eq 0 ]; then
						printErr "Leeres (broot) Array: Keine Dateien gefunden!"
						printErr "Kein Download moeglich, wird uebersprungen..."
						continue
					else
						printText "Dateien die insgesamt geladen werden:" "${#broot[@]}"
						if [ $sfdl_wget_multithreads == sfdl ]; then
							printText "Dateien die gleichzeitig geladen werden:" "$maxdl"
							echo -n "${#broot[@]}|$maxdl" > $sfdl_logs/dl.txt
							echo ${broot[*]} | xargs -n 1 -P $maxdl wget -q -t $sfdl_wget_max_retry --retry-connrefused -c -P "$sfdl_downloads/$name" --ftp-user="$username" --ftp-password="$password" | "$sfdl_sys/prog.sh" "$sfdl_downloads/$name" "$bsize" "$pwd" "${filearray[@]}"
						else
							printText "Dateien die gleichzeitig geladen werden:" "$sfdl_wget_multithreads"
							echo -n "${#broot[@]}|$sfdl_wget_multithreads" > $sfdl_logs/dl.txt
							echo ${broot[*]} | xargs -n 1 -P $sfdl_wget_multithreads wget -q -t $sfdl_wget_max_retry --retry-connrefused -c -P "$sfdl_downloads/$name" --ftp-user="$username" --ftp-password="$password" | "$sfdl_sys/prog.sh" "$sfdl_downloads/$name" "$bsize" "$pwd" "${filearray[@]}"
						fi
					fi
				else
					printLinie
					printText "Download:" "$name"
					printText "Dateien die insgesamt geladen werden:" "${#droot[@]}"
					if [ $sfdl_wget_multithreads == sfdl ]; then
						printText "Dateien die gleichzeitig geladen werden:" "$maxdl"
						echo -n "${#droot[@]}|$maxdl" > $sfdl_logs/dl.txt
						echo ${drootMTH[*]} | xargs -n 1 -P $maxdl wget -q -t $sfdl_wget_max_retry --retry-connrefused -c -P "$sfdl_downloads/$name" --ftp-user="$username" --ftp-password="$password" | "$sfdl_sys/prog.sh" "$sfdl_downloads/$name" "$bsize" "$pwd" "${filearray[@]}"
					else
						printText "Dateien die gleichzeitig geladen werden:" "$sfdl_wget_multithreads"
						echo -n "${#droot[@]}|$sfdl_wget_multithreads" > $sfdl_logs/dl.txt
						echo ${drootMTH[*]} | xargs -n 1 -P $sfdl_wget_multithreads wget -q -t $sfdl_wget_max_retry --retry-connrefused -c -P "$sfdl_downloads/$name" --ftp-user="$username" --ftp-password="$password" | "$sfdl_sys/prog.sh" "$sfdl_downloads/$name" "$bsize" "$pwd" "${filearray[@]}"
					fi
				fi
			else
				printErr "Es wurde kein wget gefunden! Bitte wget installieren!"
				printLinie
				exit
			fi
		fi

		# entferne wget & lftp temp files
		if [ $debug == false ]; then
			if [ $sfdl_lftp_download == true ]; then
				printText "Logs:" "Entferne Logfiles (lftp)"
				rm -f "$sfdl_logs/$ladepfad"_lftp_error.log
				rm -f "$sfdl_logs/$name"_lftp.log
				rm -f "$sfdl_logs/$name"_download.log
				rm -f "$sfdl_logs/dl.txt"
				rm -f "$sfdl_logs/version.txt"
			fi
			if [ $sfdl_wget_download == true ]; then
				printText "Logs:" "Entferne Logfiles (wget)"
				rm -f "$sfdl_downloads/$name/"index.html*
				rm -f "$sfdl_downloads/$name/".listing
				rm -f "$sfdl_logs/dl.txt"
				rm -f "$sfdl_logs/version.txt"
			fi
		fi

		# erstelle speedreport
		if [ $do_speedreport == true ]; then
			printJSON "running" "$ladesfdl" "Erstelle Speedreport"
			#zeit fuer speedreport
			dltimeX2=$(date +"%s")
			#berechne vergangene sekunden
			dltime=$(expr $dltimeX2 - $dltimeX1 2>/dev/null)
			resumedl=0
			if [ -f "$sfdl_logs/$name.txt" ]; then
				resumedl=1
				resumetime=$(cat "$sfdl_logs/$name.txt")
				rm -f "$sfdl_logs/$name.txt"
			fi
			if [ "$resumedl" == "1" ]; then
				dltimeX=$((dltimeX+resumetime))
			fi
			if [ $syscore == "darwin" ]; then
				speedtime=$(date -u -r $dltimeX +%T 2>/dev/null)
			else
				speedtime=$(date -u -d @${dltimeX} +"%T" 2>/dev/null)
			fi
			#wie viel wurde geladen?
			downloadSize=$(du "$sfdl_downloads/$name" 2>/dev/null | cut -f1 2>/dev/null | tail -n 1 2>/dev/null)
			downloadSizeH=$(du -h "$sfdl_downloads/$name" 2>/dev/null | cut -f1 2>/dev/null | tail -n 1 2>/dev/null)
			#rechne speed
			mbsecf=$(bc -l <<< "$downloadSize/$dltimeX/1024" 2>/dev/null)
			mbsec=${mbsecf:0:4}
			mbitsf=$(bc -l <<< "$downloadSize*8/$dltimeX/1024" 2>/dev/null)
			mbits=${mbitsf:0:4}
			#dateien im download
			dlfiles=$(find "$sfdl_downloads/$name" -type f 2>/dev/null | wc -l 2>/dev/null)
			#stelle speedreport zusammen
			speedy="Downloaded: $dlfiles Dateien ($downloadSizeH), in $speedtime ($mbsec MB/s | $mbits Mbit/s)"
			printText "Speedreport:" "$speedy"
			printText "Erstelle:" "speedreport.txt"

			if [ $debug == true ]; then
				echo ===[DEBUG-SPEEDREPORT]=========================
				echo dltimeX2: $dltimeX2
				echo dltime: $dltime
				echo resumedl: $resumedl
				echo resumetime: $resumetime
				echo dltimeX: $dltimeX
				echo speedtime: $speedtime
				echo downloadSize: $downloadSize
				echo downloadSizeH: $downloadSizeH
				echo mbsecf: $mbsecf
				echo mbsec: $mbsec
				echo mbitsf: $mbitsf
				echo mbits: $mbits
				echo dlfiles: $dlfiles
				echo =========================[DEBUG-SPEEDREPORT]===
			fi

			if [ -d "$sfdl_downloads/$name" ]; then
				echo Releasename: $name > "$sfdl_downloads/$name/speedreport.txt"
				echo Upload von: $upper >> "$sfdl_downloads/$name/speedreport.txt"
				echo  >> "$sfdl_downloads/$name/speedreport.txt"
				echo $speedy >> "$sfdl_downloads/$name/speedreport.txt"
				echo  >> "$sfdl_downloads/$name/speedreport.txt"
				echo Kommentar: Danke! >> "$sfdl_downloads/$name/speedreport.txt"
				if [ $sfdl_eigenwerbung == true ]; then
					echo -e "[SIZE=1]Powered by [url=https://github.com/raz3r-code/sfdl-bash-loader/releases]SFDL BASH-Loader[/url] $sfdl_version[/SIZE]" >> "$sfdl_downloads/$name/speedreport.txt"
				fi
			fi
		else
			printErr "Fehler: Erstelle keinen Speedreport (do_speedreport=false)!"
		fi

		# rar files auspacken und entfernen
		rar_error="false"
		filePath="$sfdl_downloads/$name/"

		# anzahl der vorhandenen dateien im downloadverzeichnis
		totalFiles=$(find $filePath -type f 2>/dev/null | wc -l 2>/dev/null)

		if [ $debug == true ]; then
			echo UNRAR totalFiles: $totalFiles
		fi

		# array aller dateien im downloadverzeichnis
		allFiles=()
		IFS=$'\r\n'
		allFiles=`find "$filePath" -type f`
		IFS=$'\n' read -rd '' -a allFiles <<<"$allFiles"

		rarFiles=()
		rarPart=()
		rarRar=()

		for i in "${allFiles[@]}"; do
			
			regEx='(.rar|.[a-z]{1}[0-9]{2})$'
			if [[ "$i" =~ $regEx ]]; then
				rarFiles+=($(echo $i))

				f_1=${BASH_REMATCH[1]};
				if [ "$f_1" == ".rar" ]; then
					rarRar+=($(echo $i))
				fi

				regEx2='(part1.rar|part01.rar|part001.rar|part0001.rar|part00001.rar)$'
				if [[ "$i" =~ $regEx2 ]]; then
					rarPart+=($(echo $i))
				fi
			fi
		done

		c_rarFiles=${#rarFiles[@]}
		c_rarRar=${#rarRar[@]}
		c_rarPart=${#rarPart[@]}

		if [ $debug == true ]; then
			echo c_rarFiles: $c_rarFiles
			echo c_rarRar: $c_rarRar
			echo c_rarPart: $c_rarPart
		fi

		
		if [ "$c_rarFiles" == 0 ]; then
			printText "RAR:" "Keine RAR Archive gefunden!"
			printJSON "running" "$ladesfdl" "Keine RAR Archive gefunden"
		else
			if [ $sfdl_rar_auspacken == true ]; then

				printText "RAR:" "$c_rarFiles RAR Archive gefunden und werden jetzt ausgepackt!"
				printJSON "running" "$ladesfdl" "$c_rarFiles RAR Archive werden verarbeitet"

				cd "$filePath"
				
				if [ "$c_rarPart" == 0 ]; then
                    for i in "${rarRar[@]}"; do
                        if [ $debug == true ]; then
                        echo entpacke: "$i"
                    fi
                    unrar e -y -r -o- "$i" 2>> "$filePath/rarerr.txt" 1>> "$filePath/rarlog.txt"
                    chmod -R $sfdl_chmod $filePath
		    done
                else
					for i in "${rarPart[@]}"; do
						if [ $debug == true ]; then
							echo entpacke: "$i"
						fi
						unrar e -y -r -o- "$i" 2>> "$filePath/rarerr.txt" 1>> "$filePath/rarlog.txt"
						chmod -R $sfdl_chmod $filePath
					done
				fi

				cd "$ppwd"
			fi
			
			
			# ist die rarlog.txt leer, gab es fehler?
			if [ -f "$filePath/rarlog.txt" ]; then
				rarlogok=`cat $filePath/rarlog.txt | grep "No files to extract"`
				if [ -z "$rarlogok" ] ; then
					printErr "RAR: rarlog.txt O.K.!"
				else
					printErr "RAR: rarlog.txt meldet Fehler beim Auspacken!"
					rar_error="true"
				fi
			fi
			# ist die rarerr.txt leer, gab es fehler?
			if [ -f "$filePath/rarerr.txt" ]; then
				if [ -s "$filePath/rarerr.txt" ]; then
					printErr "RAR: rarerr.txt meldet Fehler beim Auspacken!"
					rar_error="true"
				fi
			fi
		fi
		
		# entferne rar files
		if [ $rar_error == false ]; then
			if [ $sfdl_rar_auspacken == true ]; then
				if [ $sfdl_rar_entfernen == true ]; then
					printText "RAR:" "Entferne RAR Archive!"
					for i in "${rarFiles[@]}"; do
						if [ $debug == true ]; then
							echo RAR entferne: "$i"
						fi
						rm -f "$i"
					done
					rm -f "$filePath/rarerr.txt"
				fi
			fi
		fi

		# sfdl verschieben
		if [ -d "$sfdl_downloads/$name" ]; then
			if [ -f "$sfdl" ]; then
				printText "SFDL:" "verschiebe ${sfdl##*/}"
				mv "$sfdl" "$sfdl_downloads/$name/$name.sfdl"
			fi
		fi

		if [ $uscript_after == true ]; then
			echo "Userscript wird ausgeführt. Bitte warten...."
			"$uscript_folder"/after.sh
			echo "Userscript wurde ausgeführt"
		fi
		
		# xrel.to - tmdb.org mod
		if [ $rar_error == false ]; then
			if [ $sfdl_xrel_tmdb_mod == true ]; then
				# jq vorhanden und funktioniert?
				if hash jq 2>/dev/null; then
					useJQ="jq"
				else
					if hash "$sfdl_sys/jq" 2>/dev/null; then
						useJQ="$sfdl_sys/jq"
					else
						printErr "ERROR: Kein funktionierendes jq gefunden! Xrel/TMDb Mod deaktiviert!"
						continue
					fi
				fi

				printText "XREL.to:" "Greife auf API Daten zu..."
				xrel_type_movie="$(wget -qO- "http://api.xrel.to/api/release/info.xml?dirname=$name" | grep -o -m1 -P '<type>(.*)</type>' | cut -d '>' -f 2 | cut -d '<' -f 1)"
				if [ "$xrel_type_movie" == "movie" ]; then
					xrel_imdb_id="$(wget -qO- "http://api.xrel.to/api/release/info.xml?dirname=$name" | grep -o -m1 -P '<uri>imdb:(.*)</uri>' | cut -d '>' -f 2 | cut -d '<' -f 1 | cut -d ':' -f2)"
					if [ -z "$xrel_imdb_id" ]; then
						printErr "XREL.to: FEHLER keine IMDB ID gefunden!"
						continue
					else
						printJSON "running" "$ladesfdl" "TMDB.org hole Filminformationen"
						printText "TMDB.org:" "Speichere API Daten in ... tmdb.json"
						wget -qO "$sfdl_downloads/$name/tmdb.json" "http://api.tmdb.org/3/movie/$xrel_imdb_id?api_key=$tmdb_api_key&language=$tmdb_language"
						if [ -f "$sfdl_downloads/$name/tmdb.json" ]; then
							printText "TMDB.org:" "Lade Filminformationen..."
							tmdb_m_id="$(cat "$sfdl_downloads/$name/tmdb.json" | $useJQ -c -r ".id")"
							tmdb_m_title="$(cat "$sfdl_downloads/$name/tmdb.json" | $useJQ -c -r ".title")"
							tmdb_m_otitle="$(cat "$sfdl_downloads/$name/tmdb.json" | $useJQ -c -r ".original_title")"
							tmdb_m_jahr="$(cat "$sfdl_downloads/$name/tmdb.json" | $useJQ -c -r ".release_date" | cut -d '-' -f1)"
							tmdb_m_runtime="$(cat "$sfdl_downloads/$name/tmdb.json" | $useJQ -c -r ".runtime")"
							tmdb_m_tagline="$(cat "$sfdl_downloads/$name/tmdb.json" | $useJQ -c -r ".tagline")"
							tmdb_m_overview="$(cat "$sfdl_downloads/$name/tmdb.json" | $useJQ -c -r ".overview")"
							tmdb_m_olanguage="$(cat "$sfdl_downloads/$name/tmdb.json" | $useJQ -c -r ".original_language")"
							tmdb_m_land="$(cat "$sfdl_downloads/$name/tmdb.json" | $useJQ -c -r ".production_countries[0].name")"
							tmdb_m_firma="$(cat "$sfdl_downloads/$name/tmdb.json" | $useJQ -c -r ".production_companies[0].name")"
							tmdb_m_collection="$(cat "$sfdl_downloads/$name/tmdb.json" | $useJQ -c -r ".belongs_to_collection.name")"
							# die filmdatei bekomm einen neuen namen
							tmdb_filmdatei="$(du -a -S "$sfdl_downloads/$name/"* | sort -nr | head -n 1)" # die groesste datei wird wohl der film sein
							film_ganzefilm="${tmdb_filmdatei##*/}" # filmdatei
							film_extension="${tmdb_filmdatei##*.}" # dateiendung: mkv, mp4, avi, ...
							# entferne problematische sonerzeichen aus dem titel
							tmdb_m_title_c="$(echo $tmdb_m_title| sed -f "$sfdl_sys/pattern-sed.txt")"
							# konvertiere utf-8 nach ascii
							if hash iconv 2>/dev/null; then
								printText "UTF-8:" "Konvertiere UTF-8 Zeichen nach ASCII"
								tmdb_m_title_c="$(echo $tmdb_m_title_c| iconv -f utf-8 -t us-ascii//TRANSLIT)"
							else
								printText "UTF-8:" "iconv wurde auf dem System nicht gefunden! Konvertieren von UTF-8 nach ASCII nicht moeglich!"
							fi
							if [ ! -f "$sfdl_downloads/$name/$tmdb_m_title_c ($tmdb_m_jahr).$film_extension" ]; then
								printText "TMDB.org:" "Aus $film_ganzefilm wird $tmdb_m_title_c ($tmdb_m_jahr).$film_extension"
								mv "$sfdl_downloads/$name/$film_ganzefilm" "$sfdl_downloads/$name/$tmdb_m_title_c ($tmdb_m_jahr).$film_extension"
							fi
							# lade poster und fanart
							if [ ! -d "$sfdl_downloads/$name/kodi" ]; then
								mkdir "$sfdl_downloads/$name/kodi"
							fi
							# anfang der kodi.nfo
							echo "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\" ?>" > "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
							echo "<movie>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
							echo "	<title>$tmdb_m_title</title>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
							echo "	<originaltitle>$tmdb_m_otitle</originaltitle>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
							echo "	<sorttitle>$tmdb_m_title 1</sorttitle^>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
							echo "	<year>$tmdb_m_jahr</year>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
							echo "	<runtime>$tmdb_m_runtime</runtime>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
							echo "	<outline>$tmdb_m_tagline</outline>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
							echo "	<plot>$tmdb_m_overview</plot>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
							echo "	<country>$tmdb_m_land</country>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
							echo "	<studio>$tmdb_m_firma</studio>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
							echo "	<filenameandpath>$kodi_pfad_zum_film/$tmdb_m_title_c ($tmdb_m_jahr).$film_extension</filenameandpath>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
							echo "	<playcount>0</playcount>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
							echo "	<lastplayed></lastplayed>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
							echo "	<id>$xrel_imdb_id</id>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
							echo "	<tmdbid>$tmdb_m_id</tmdbid>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
							echo "	<rlsname>$name</rlsname>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
							if [ "$tmdb_m_collection" == "null" ]; then
								echo "	<set></set>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
							else
								echo "	<set>$tmdb_m_collection</set>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
							fi
							printText "TMDB.org:" "Lade Cover- und Hintergrundbild..."
							tmdb_m_poster="$(cat "$sfdl_downloads/$name/tmdb.json" | $useJQ -c -r ".poster_path")"
							if [ ! -f "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr)-poster.jpg" ]; then
								wget -qO "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr)-poster.jpg" "http://image.tmdb.org/t/p/original$tmdb_m_poster"
							fi
							tmdb_m_fanart="$(cat "$sfdl_downloads/$name/tmdb.json" | $useJQ -c -r ".backdrop_path")"
							if [ ! -f "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr)-fanart.jpg" ]; then
								wget -qO "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr)-fanart.jpg" "http://image.tmdb.org/t/p/original$tmdb_m_fanart"
							fi
							echo "	<thumb aspect=\"poster\" preview=\"$kodi_pfad_zum_cover/$tmdb_m_title_c ($tmdb_m_jahr)-poster.jpg\">$kodi_pfad_zum_cover/$tmdb_m_title_c ($tmdb_m_jahr)-poster.jpg</thumb>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
							echo "	<fanart>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
							echo "		<thumb preview=\"$kodi_pfad_zum_hintergrund/$tmdb_m_title_c ($tmdb_m_jahr)-fanart.jpg\">$kodi_pfad_zum_hintergrund/$tmdb_m_title_c ($tmdb_m_jahr)-fanart.jpg</thumb>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
							echo "	</fanart>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
							# movie genres
							IFS=$'\r\n'
							GLOBIGNORE='*'
							tmdb_m_genres=($(cat "$sfdl_downloads/$name/tmdb.json" | $useJQ -c -r ".genres[] .name"))
							for i in "${tmdb_m_genres[@]}"
							do
								echo "	<genre>$i</genre>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
							done
							# lade regisseur
							tmdb_m_crew=($(wget -qO- "http://api.tmdb.org/3/movie/$tmdb_m_id/credits?api_key=$tmdb_api_key&language=$tmdb_language" | $useJQ -c -r ".crew[] | [.job, .name]"))
							for i in "${tmdb_m_crew[@]}"
							do
								job="$(echo $i | $useJQ -c -r ".[0]")"
								if [ $job == "Director" ]; then
									tmdb_m_director="$(echo $i | $useJQ -c -r ".[1]")"
								fi
							done
							echo "	<director>$tmdb_m_director</director>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
							# lade trailer
							tmdb_m_vids=($(wget -qO- "http://api.tmdb.org/3/movie/$tmdb_m_id/videos?api_key=$tmdb_api_key&language=$tmdb_language" | $useJQ -c -r ".results[] | [.key, .name, .site, .type]"))
							for i in "${tmdb_m_vids[@]}"
							do
								trailer="$(echo $i | $useJQ -c -r ".[1]")"
								youtube="$(echo $i | $useJQ -c -r ".[2]")"
								if { [ "$trailer" == "German Trailer" ]; } && { [ "$youtube" == "YouTube" ]; } then
									tmdb_m_trailer="$(echo $i | $useJQ -c -r ".[0]")"
								fi
							done
							echo "	<trailer>plugin://plugin.video.youtube/?action=play_video&amp;videoid=$tmdb_m_trailer</trailer>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
							# lade cast
							printText "TMDB.org:" "Lade Profilbilder der Schauspieler..."
							tmdb_m_cast=($(wget -qO- "http://api.tmdb.org/3/movie/$tmdb_m_id/credits?api_key=$tmdb_api_key&language=$tmdb_language" | $useJQ -c -r ".cast[] | [.character, .name, .profile_path, .order]"))
							# erstelle pfad fuer schauspieler profilbilder
							if [ ! -d "$sfdl_downloads/$name/kodi/schauspieler" ]; then
								mkdir "$sfdl_downloads/$name/kodi/schauspieler"
							fi
							for i in "${tmdb_m_cast[@]}"
							do
								cntarr=($(echo $i | $useJQ -c -r ".[]"))
								if [ ${#cntarr[@]} == 4 ]; then
									echo "	<actor>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
									echo "		<order>${cntarr[3]}</order>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
									echo "		<name>${cntarr[1]}</name>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
									echo "		<role>${cntarr[0]}</role>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
									echo "		<thumb>$kodi_pfad_zum_actor${cntarr[2]}</thumb>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
									echo "	</actor>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
									# lade profilbild des schauspielers
									if [ ! -f "$sfdl_downloads/$name/kodi/schauspieler${cntarr[2]}" ]; then
										if ! [ "${cntarr[2]}" == "null" ]; then
											wget -qO "$sfdl_downloads/$name/kodi/schauspieler${cntarr[2]}" "http://image.tmdb.org/t/p/original${cntarr[2]}"
										fi
									fi
								else
									echo "	<actor>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
									echo "		<order>${cntarr[2]}</order>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
									echo "		<name>${cntarr[1]}</name>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
									echo "		<role>${cntarr[0]}</role>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
									echo "		<thumb></thumb>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
									echo "	</actor>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
								fi
							done
							# ende der kodi.nfo
							date_added="$(date +"%Y-%m-%d %T")"
							echo "	<dateadded>$date_added</dateadded>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
							echo "</movie>" >> "$sfdl_downloads/$name/kodi/$tmdb_m_title_c ($tmdb_m_jahr).nfo"
							if [ -f "$sfdl_downloads/$name/tmdb.json" ]; then
								rm -f "$sfdl_downloads/$name/tmdb.json"
							fi
						else
							printErr "TMDB.org: FEHLER kann tmdb.json nicht finden!"
							continue
						fi
					fi
				else
					printErr "XREL.to: Download ist kein Film oder wurde nicht gefunden!"
				fi
			fi
		fi

		# ende
		printLinie

		printJSON "done" "NULL"

	else
		if [ "$WEBSERVER" == "ONLINE" ]; then
			printText "Webinterface ONLINE:" "http://$MYIP:$sfld_status_webserver_port"
		fi
		printErr "Keine SFDL Datei gefunden! Ist $sfdl_files leer?"
		printJSON "done" "NULL" "Keine SFDL Datei gefunden! Ist $sfdl_files leer?"
		printLinie
	fi
done

# sind in der zwischenzeit neue sfdl files hinzugekommen?

if [ `ls -a "$sfdl_files"/*.sfdl 2>/dev/null | wc -l` != 0 ] ; then
	if [ $debug == true ]; then
        	printText "Folgendes ist im sfdl Ordner:" "$(ls -A $sfdl_files/*.sfdl)"
	fi
	printText "INFO:" "Weitere SFDL Dateien gefunden! Starte in 5 Sekunden ..."
	sleep 5
	exec "$pwd/bashloader.sh"
	exit 0
else
	printText "Alle Download abgeschlossen"
	if [ $uscript_end == true ]; then
			echo "Userscript wird ausgeführt. Bitte warten...."
			"$uscript_folder"/end.sh
			echo "Userscript wurde ausgeführt"
	exit 0
fi
