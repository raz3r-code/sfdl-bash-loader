#!/bin/bash

# pfad definieren und config laden
pwd=$1

# loader basispfad
ppwd="$(dirname "$pwd")"

source $pwd/loader.cfg
loaderVersion=$(cat "$sfdl_logs/version.txt" 2>/dev/null)

# php test
USEPHP=0
if hash php-cgi 2>/dev/null; then
	USEPHP=1
fi

# mac os x check
osxcheck=$(uname)
if [ $osxcheck == "Darwin" ]; then
	netcatcmd="nc"
else
	#netcatcmd="$sfdl_sys/netcat"
	netcatcmd="nc.openbsd"
fi

urldecode() {
    local url_encoded="${1//+/ }"
    printf '%b' "${url_encoded//%/\\x}"
}

HTMLTMP=/tmp/webresp
PAGETEMP=/tmp/webtmp
[ -p $HTMLTMP ] || mkfifo $HTMLTMP

while true; do
	( cat $HTMLTMP ) | $netcatcmd -lkv $sfld_status_webserver_port 2> "$sfdl_logs/status.log" | (
		
		REQ=()
		IFS=$'\r\n'
		REQ=`while read LINE && [ "$LINE" ] ; do echo "$LINE" ; done`
		IFS=$'\n' read -rd '' -a REQ <<<"$REQ"
		
		chk="$(echo ${REQ[0]} | grep -Eo '^[^ ]+')"
		get="${REQ[0]#GET }"
		post="${REQ[0]#POST }"
		
		# post oder get
		if [ "$chk" == "GET" ]; then
			url="${get% HTTP/*}"
		else
			url="${post% HTTP/*}"
		fi
		
		# server logs
		cip=$(tail -1 "$sfdl_logs/status.log" | cut -d'[' -f 2 | cut -d']' -f 1)
		echo "$cip [`date '+%d-%m-%Y %H:%M:%S'`] ${REQ[0]}" >> "$sfdl_logs/verbindungen.log" 2>&1
		
		# default page
		if [ "$url" == "/" ]
		then
			if [ -f "$sfdl_status/index.html" ]; then
				echo -e 'HTTP/1.1 200 OK' > $PAGETEMP
				echo -e 'Content-Type: text/html; charset=utf-8\r\n' >> $PAGETEMP
				cat "$sfdl_status/index.html" >> $PAGETEMP
				cat $PAGETEMP > $HTMLTMP
			else
				echo -e 'HTTP/1.1 200 OK' > $PAGETEMP
				echo -e 'Content-Type: application/json\r\n' >> $PAGETEMP
				echo -e "{ \"BASHLoader\" : [ { \"version\":\"$loaderVersion\", \"url\":\"error\", \"msg\":\"$sfdl_status/index.html nicht gefunden!\" } ] }" >> $PAGETEMP
				cat $PAGETEMP > $HTMLTMP
			fi
		# upload sfdl file
		elif [ "$url" == "/file" ]
		then
			uppcnt=0
			linecnt=0
			filename=""
			filename2=""
			extension=""
			timout=$sfdl_status_timout
			timeSTART=$(date +"%s" 2>/dev/null)
			isTIMEOUT=0
			while read i
			do
				findFilename="$(echo $i | grep -oE 'Content-Disposition: form-data; name=\"sfdl\"; filename=\"(.*)\"')"
				if [ ! -z "$findFilename" ]; then
					regEx="Content-Disposition: form-data; name=\"sfdl\"; filename=\"((.*))\""
					if [[ "$i" =~ $regEx ]]; then
						filename=${BASH_REMATCH[1]};
						
						# ist es wirklich eine sfdl datei?
						filename2=$(basename "$filename")
						extension="${filename2##*.}"
						if [ "$extension" != "sfdl" ] && [ "$extension" != "SFDL" ]; then
							echo -e 'HTTP/1.1 200 OK' > $PAGETEMP
							echo -e 'Content-Type: application/json\r\n' >> $PAGETEMP
							echo -e "{ \"BASHLoader\" : [ { \"version\":\"$loaderVersion\", \"upload\":\"fail\", \"sfdl\":\"$filename\" } ] }" >> $PAGETEMP
							cat $PAGETEMP > $HTMLTMP
							break
						fi
					fi
				fi
				
				# anfang der sfdl datei
				findStart="$(echo $i | grep -oE '(.*)xml version=(.*)')"
				if [ ! -z "$findStart" ]; then
					if [ "$findStart" == "$i" ]; then
						uppcnt=$((uppcnt + 1))
					fi
				fi
				
				# sfdl datei erstellen
				if [ $uppcnt == 1 ]; then
					if [ ! -z "$i" ]; then
						if [ $linecnt == 0 ]; then
							echo "$i" > "$sfdl_files/$filename"
						else
							echo "$i" >> "$sfdl_files/$filename"
						fi
						linecnt=$((linecnt + 1))
					fi
				fi
				
				# ende des sfld files
				if [ "</SFDLFile>" == "$i" ]; then
					uppcnt=$((uppcnt + 1))
				fi
				
				# ende des uploads
				if [ $uppcnt -gt 1 ]; then
					break
				fi
				
				# timeout
				timeNOW=$(date +"%s" 2>/dev/null)
				timeOUT=$(expr $timeNOW - $timeSTART 2>/dev/null)
				if [ $timeOUT -gt $timout ]; then
					isTIMEOUT=1
					break
				fi
				
			done
			
			#echo -e 'HTTP/1.1 200 OK\r\n' > $HTMLTMP
			
			if [ $uppcnt == 2 ] && [ $linecnt != 0 ]; then
				echo -e 'HTTP/1.1 200 OK' > $PAGETEMP
				echo -e 'Content-Type: application/json\r\n' >> $PAGETEMP
				echo -e "{ \"BASHLoader\" : [ { \"version\":\"$loaderVersion\", \"upload\":\"ok\", \"sfdl\":\"$filename\" } ] }" >> $PAGETEMP
				cat $PAGETEMP > $HTMLTMP
			else
				echo -e 'HTTP/1.1 200 OK' > $PAGETEMP
				echo -e 'Content-Type: application/json\r\n' >> $PAGETEMP
				echo -e "{ \"BASHLoader\" : [ { \"version\":\"$loaderVersion\", \"upload\":\"fail\", \"sfdl\":\"$filename\" } ] }" >> $PAGETEMP
				cat $PAGETEMP > $HTMLTMP
			fi

		# status json
		elif [ "$url" == "/status.json" ]
		then
			if [ -f "$sfdl_status/status.json" ]; then
				echo -e 'HTTP/1.1 200 OK' > $PAGETEMP
				echo -e 'Content-Type: application/json\r\n' >> $PAGETEMP
				cat "$sfdl_status/status.json" >> $PAGETEMP
				cat $PAGETEMP > $HTMLTMP
			else
				echo -e 'HTTP/1.1 200 OK' > $PAGETEMP
				echo -e 'Content-Type: application/json\r\n' >> $PAGETEMP
				echo -e "{ \"BASHLoader\" : [ { \"version\":\"$loaderVersion\", \"json\":\"error\", \"msg\":\"status.json nicht gefunden: $sfdl_status/status.json\" } ] }" >> $PAGETEMP
				cat $PAGETEMP > $HTMLTMP
			fi
			
		# start sfdl loader
		elif [[ "$url" == /start* ]]
		then
			command="$(echo -n "$url" | sed 's/\/start\///' | tr -d '[[:space:]]')"
			
			if [ "$sfdl_status_start_passwort" == "$command" ]; then
				exec "$sfdl_bdir/start.sh" &
				
				echo -e 'HTTP/1.1 200 OK' > $PAGETEMP
				echo -e 'Content-Type: application/json\r\n' >> $PAGETEMP
				echo -e "{ \"BASHLoader\" : [ { \"version\":\"$loaderVersion\", \"start\":\"ok\" } ] }" >> $PAGETEMP
				cat $PAGETEMP > $HTMLTMP
			else
				echo -e 'HTTP/1.1 200 OK' > $PAGETEMP
				echo -e 'Content-Type: application/json\r\n' >> $PAGETEMP
				echo -e "{ \"BASHLoader\" : [ { \"version\":\"$loaderVersion\", \"start\":\"Falsches Passwort!\" } ] }" >> $PAGETEMP
				cat $PAGETEMP > $HTMLTMP
			fi
			
		# stop sfdl loader
		elif [[ "$url" == /stop* ]]
		then
			command="$(echo -n "$url" | sed 's/\/stop\///' | tr -d '[[:space:]]')"
			
			if [ "$sfdl_status_stop_passwort" == "$command" ]; then
				pkill -f bashloader.sh
				pkill -f prog.sh
				pkill -f wget
				
				echo -e 'HTTP/1.1 200 OK' > $PAGETEMP
				echo -e 'Content-Type: application/json\r\n' >> $PAGETEMP
				echo -e "{ \"BASHLoader\" : [ { \"version\":\"$loaderVersion\", \"stop\":\"ok\" } ] }" >> $PAGETEMP
				cat $PAGETEMP > $HTMLTMP
			else
				echo -e 'HTTP/1.1 200 OK' > $PAGETEMP
				echo -e 'Content-Type: application/json\r\n' >> $PAGETEMP
				echo -e "{ \"BASHLoader\" : [ { \"version\":\"$loaderVersion\", \"stop\":\"Falsches Passwort!\" } ] }" >> $PAGETEMP
				cat $PAGETEMP > $HTMLTMP
			fi
		
		# kill webserver
		elif [[ "$url" == /kill* ]]
		then
			command="$(echo -n "$url" | sed 's/\/kill\///' | tr -d '[[:space:]]')"
			
			if [ "$sfdl_status_kill_passwort" == "$command" ]; then
				echo -e 'HTTP/1.1 200 OK' > $PAGETEMP
				echo -e 'Content-Type: application/json\r\n' >> $PAGETEMP
				echo -e "{ \"BASHLoader\" : [ { \"version\":\"$loaderVersion\", \"kill\":\"ok\" } ] }" >> $PAGETEMP
				cat $PAGETEMP > $HTMLTMP
				sleep 1
				pkill -f status.sh
			else
				echo -e 'HTTP/1.1 200 OK' > $PAGETEMP
				echo -e 'Content-Type: application/json\r\n' >> $PAGETEMP
				echo -e "{ \"BASHLoader\" : [ { \"version\":\"$loaderVersion\", \"kill\":\"Falsches Passwort!\" } ] }" >> $PAGETEMP
				cat $PAGETEMP > $HTMLTMP
			fi
		
		# sfdl datei mit ftp link
		elif [[ "$url" == /addftp* ]]
		then
			command="$(echo -n "$url" | sed 's/\/addftp\///' | tr -d '[[:space:]]')"
			
			upFTPlink=""
			
			chkFTPlink1="$(echo $command | grep -oE 'ftp://(.*):(.*)@[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}:[0-9]{1,5}/(.*)')"
			if [ ! -z "$chkFTPlink1" ]; then
				upFTPlink="$chkFTPlink1"
			fi
			
			chkFTPlink2="$(echo $command | grep -oE 'ftp://[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}:[0-9]{1,5}/(.*)')"
			if [ ! -z "$chkFTPlink2" ]; then
				upFTPlink="$chkFTPlink2"
			fi
			
			chkFTPlink3="$(echo $command | grep -oE 'ftp://[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}/(.*)')"
			if [ ! -z "$chkFTPlink3" ]; then
				upFTPlink="$chkFTPlink3"
			fi
			
			upFTPlink="$(urldecode "$upFTPlink")"
			
			if [ ! -z "$upFTPlink" ]; then
				cleanurl="${upFTPlink%/}" # entfernt das letzte slash
				cleanname="${cleanurl##*/}" # spuckt alles nach dem letzten slash kommt aus
				base64sting="$(echo -n "$upFTPlink" | base64)" # ftp url 2 base64
				
				exec wget -q -t $sfdl_wget_max_retry --retry-connrefused --content-disposition -N -P "$sfdl_files" "http://download.sfdl.net/$base64sting" &
				
				echo -e 'HTTP/1.1 200 OK' > $PAGETEMP
				echo -e 'Content-Type: application/json\r\n' >> $PAGETEMP
				echo -e "{ \"BASHLoader\" : [ { \"version\":\"$loaderVersion\", \"status\":\"ok\", \"msg\":\"$cleanname.sfdl\" } ] }" >> $PAGETEMP
				cat $PAGETEMP > $HTMLTMP
			else
				echo -e 'HTTP/1.1 200 OK' > $PAGETEMP
				echo -e 'Content-Type: application/json\r\n' >> $PAGETEMP
				echo -e "{ \"BASHLoader\" : [ { \"version\":\"$loaderVersion\", \"status\":\"error\", \"msg\":\"Kein FTP Link erkannt!\" } ] }" >> $PAGETEMP
				cat $PAGETEMP > $HTMLTMP
			fi
		
		# sfdl upload von url
		elif [[ "$url" == /upload* ]]
		then
			download="$(echo -n "$url" | sed 's/\/upload\///' | tr -d '[[:space:]]')"
			exec wget -q -t $sfdl_wget_max_retry --retry-connrefused --content-disposition -N -P "$sfdl_files" "$download" &
			
			# download von sfdl.net?
			chkSFDLnet="$(echo $download | grep -oE 'download.sfdl.net')"
			if [ ! -z "$chkSFDLnet" ]; then
				base64sting="$(echo -n "$download" | sed 's/http:\/\/download.sfdl.net\///' | tr -d '[[:space:]]' | base64 --decode)"
				cleanurl="${base64sting%/}" # entfernt das letzte slash
				cleanname="${cleanurl##*/}" # spuckt alles nach dem letzten slash kommt aus
				
				echo -e 'HTTP/1.1 200 OK' > $PAGETEMP
				echo -e 'Content-Type: application/json\r\n' >> $PAGETEMP
				echo -e "{ \"BASHLoader\" : [ { \"version\":\"$loaderVersion\", \"upload\":\"ok\", \"sfdl\":\"$cleanname.sfdl\" } ] }" >> $PAGETEMP
				cat $PAGETEMP > $HTMLTMP
			else
				echo -e 'HTTP/1.1 200 OK' > $PAGETEMP
				echo -e 'Content-Type: application/json\r\n' >> $PAGETEMP
				echo -e "{ \"BASHLoader\" : [ { \"version\":\"$loaderVersion\", \"upload\":\"ok\", \"sfdl\":\"$download\" } ] }" >> $PAGETEMP
				cat $PAGETEMP > $HTMLTMP
			fi
		
		# sonstiges
		else
			filename=$(basename "$url") # dateiname
			extension="${filename##*.}" # dateiendung
			
			#echo "filename: $filename"
			#echo "extension: $extension"
			#echo "url: $url"
			
			chkURL="$(echo $url | grep -oE 'php?')"
			if [ ! -z "$chkURL" ]; then
				basefile="$(echo $url | cut -d '?' -f1)"
				echo "basefile: $basefile"
				
				#baseextension="$(echo $extension | cut -d '?' -f1)"
				baseextension="${basefile##*.}"
				echo "baseextension: $baseextension"
				
				thisfile="$sfdl_status$basefile"
				thisextension="$baseextension"
			else
				thisfile="$sfdl_status$url"
				thisextension="$extension"
			fi
			
			if [ -f "$thisfile" ]; then
				if [ "$thisextension" == "php" ] && [ $USEPHP == 1 ]; then
					HEADER="HTTP/1.1 200 OK\r\n"
					PHPOUT=`php-cgi -c "$sfdl_status_php_ini_path" "$sfdl_status_doc_root$url" 2>/dev/null`
					OUTPUT="$HEADER$PHPOUT"
					echo "$OUTPUT" > $HTMLTMP
				else
					cat "$sfdl_status$url" > $HTMLTMP
				fi
			else
				echo -e 'HTTP/1.1 404 Not Found' > $PAGETEMP
				echo -e 'Content-Type: text/html; charset=utf-8\r\n' >> $PAGETEMP
				echo -e '<html><head><title>404 - BASH-Loader</title></head><body><h1>404 - Seite nicht gefunden!</h1></body></html>' >> $PAGETEMP
				cat $PAGETEMP > $HTMLTMP
			fi
		fi
		
		<<EOF

EOF
		
	)
done