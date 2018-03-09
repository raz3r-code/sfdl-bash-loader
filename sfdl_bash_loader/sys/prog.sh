#!/bin/bash

dltime1=$(date +"%s" 2>/dev/null)

# pfad definieren und config laden
pwd=$3

files_arr=("${@}")
files_arr=("${files_arr[@]:1}")
files_arr=("${files_arr[@]:1}")
files_arr=("${files_arr[@]:1}")

# lade config
source $pwd/loader.cfg
	
dlname="${1##*/}"
resumedl=0
if [ -f "$sfdl_logs/$dlname.txt" ]; then
	resumedl=1
	resumetime=$(cat "$sfdl_logs/$dlname.txt")
fi

files_max="$(cat "$sfdl_logs/dl.txt" | cut -d '|' -f1)"
files_mt="$(cat "$sfdl_logs/dl.txt" | cut -d '|' -f2)"
loader_version="$(cat "$sfdl_logs/version.txt")"
	
# systemname ... Linux, Darwin, ...
sysnameX=$(uname)

downloaded="0"
progM=$(($2 / 1024))

function printText {
	if [ $sfdl_color_text == true ]; then
		echo -ne $'\e[40;38;5;82m' $1 $'\e[97m'$2 $'\e[0m\r'
	else
		echo -ne  $1 $' ' $2 $'\r'
	fi
}

function printDone {
	if [ $sfdl_color_text == true ]; then
		echo -ne $'\e[40;38;5;13m' $1 $'\e[97m'$2 $'\e[0m\n'
	else
		echo -ne  $1 $' ' $2 $'\n'
	fi
}

function joinMe { local d=$1; shift; echo -n "$1"; shift; printf "%s" "${@/#/$d}"; }

while [ : ]
do
	name_chmod="$1"; echo ${var// /\ }
	chmod -R $sfdl_chmod "$name_chmod"
	if [ $sysnameX == "Darwin" ]
	then
		progB="$(du -k $1 2>/dev/null | cut -f1 2>/dev/null | tail -n 1 2>/dev/null)"
	elif [ $sysnameX == "FreeBSD" ]
	then
		progB="$(du -k $1 2>/dev/null | cut -f1 2>/dev/null | tail -n 1 2>/dev/null)"
	else
		progB="$(du $1 2>/dev/null | cut -f1 2>/dev/null | tail -n 1 2>/dev/null)"
	fi
	progH="$(du -h $1 2>/dev/null | cut -f1 2>/dev/null | tail -n 1)"
	downloaded=$(bc -l <<< "$progB/$progM*100" 2>/dev/null | cut -d "." -f 1 2>/dev/null)
	dltime2=$(date +"%s" 2>/dev/null)
	dltime=$(expr $dltime2 - $dltime1 2>/dev/null)
	
	if [ "$resumedl" == "1" ]; then
		dltime=$((dltime+resumetime))
	fi

	dltime_eta=$(bc -l <<< "($progM-$progB)/($progB/$dltime)" 2>/dev/null)
	
	if [ $sysnameX == "Darwin" ]
	then
		speedtimeX=$(date -u -r $dltime +%T 2>/dev/null)
		speedtime_eta=$(date -u -r $dltime_eta +%T 2>/dev/null)

	elif [ $sysnameX == "FreeBSD" ]
	then
		speedtimeX=$(date -u -r $dltime +%T 2>/dev/null)
		speedtime_eta=$(date -u -r $dltime_eta +%T 2>/dev/null)
	else
		speedtimeX=$(date -u -d @${dltime} +"%T" 2>/dev/null)
		speedtime_eta=$(date -u -d @${dltime_eta} +"%T" 2>/dev/null)
	fi

	mbsecf=$(bc -l <<< "$progB/$dltime/1024" 2>/dev/null)
	mbsec=${mbsecf:0:4}
	
	# speichere aktuelle dltime in temp logs, sollte der dl abgebrochen und fortgesetzt werden
	echo $dltime > "$sfdl_logs/$dlname.txt"
	
	DATETIME=`date +'%d.%m.%Y - %H:%M:%S'`
	JSDATE=`date -u +"%FT%T.000Z"`
	
	# datei updates
	FILES=()
	IFS=$'\r\n'
	if [ $sysnameX == "Darwin" ]; then
		FILES=`find $1 -type f -exec du -k -a {} + | sort -n`
	else
		FILES=`find $1 -type f -exec du -B1 -a {} + | sort -n`
	fi
	IFS=$'\n' read -rd '' -a FILES <<<"$FILES"

	FILESARR=()	
	for i in "${FILES[@]}";
	do
		regEx="([0-9]*)(.*)"
		if [[ "$i" =~ $regEx ]]; then
			f_size=${BASH_REMATCH[1]};
			if [ $sysnameX == "Darwin" ]; then
				f_size=$(bc -l <<< "$f_size*1024" 2>/dev/null)
			fi
			f_name="${BASH_REMATCH[2]##*/}"
			FILESARR+=($(echo "$f_name|$f_size"))
		fi
	done
	
	FLISTARR=()
	for i in "${files_arr[@]}";
	do
		added=0
		c_name="$(echo $i | cut -d '|' -f 1)"
		c_size="$(echo $i | cut -d '|' -f 2)"
		for m in "${FILESARR[@]}";
		do
			m_name="$(echo $m | cut -d '|' -f 1)"
			m_size="$(echo $m | cut -d '|' -f 2)"
			
			if [ "$c_name" == "$m_name" ]; then
				FLISTARR+=($(echo "$c_name|$c_size|$m_size"))
				added=1
			fi
		done
		if [ $added == 0 ]; then
			FLISTARR+=($(echo "$c_name|$c_size|NULL"))
			added=0
		fi
	done
	

#Prüfe Downloadabbruch vom server
if [ -f ""$sfdl_logs/$dlname"_download.log" ]; then
				downlogok=`cat "$sfdl_logs/$dlname"_download.log | grep "Fehler"`
				if [ -z "$downlogok" ] ; then

	files_json="$(joinMe ";" "${FLISTARR[@]}")"
	
	echo -ne "{ \"BASHLoader\" : [ { \"version\":\"$loader_version\", \"date\":\"$JSDATE\", \"datetime\":\"$DATETIME\", \"status\":\"running\", \"sfdl\":\"$dlname.sfdl\", \"action\":\"loading\", \"loading_mt_files\":\"$files_mt\", \"loading_total_files\":\"$files_max\", \"loading\":\"$progH|$progB|$progM|$downloaded|$mbsec|$speedtimeX|$speedtime_eta\", \"loading_file_array\":\"$files_json\" } ] }" > "$sfdl_status_json_file"

	if [[ "$downloaded" -le "9" ]]; then
		printText "Wird geladen:" "$progH ($progB KB / $progM KB) [----------] $downloaded% ($mbsec MB/s) [$speedtimeX]/[$speedtime_eta]"
	fi
	
	if [[ "$downloaded" -ge "10" && "$downloaded" -lt "20" ]]; then
		printText "Wird geladen:" "$progH ($progB KB / $progM KB) [#---------] $downloaded% ($mbsec MB/s) [$speedtimeX]/[$speedtime_eta]"
	fi
	
	if [[ "$downloaded" -ge "20" && "$downloaded" -lt "30" ]]; then
		printText "Wird geladen:" "$progH ($progB KB / $progM KB) [##--------] $downloaded% ($mbsec MB/s) [$speedtimeX]/[$speedtime_eta]"
	fi
	
	if [[ "$downloaded" -ge "30" && "$downloaded" -lt "40" ]]; then
		printText "Wird geladen:" "$progH ($progB KB / $progM KB) [###-------] $downloaded% ($mbsec MB/s) [$speedtimeX]/[$speedtime_eta]"
	fi
	
	if [[ "$downloaded" -ge "40" && "$downloaded" -lt "50" ]]; then
		printText "Wird geladen:" "$progH ($progB KB / $progM KB) [####------] $downloaded% ($mbsec MB/s) [$speedtimeX]/[$speedtime_eta]"
	fi
	
	if [[ "$downloaded" -ge "50" && "$downloaded" -lt "60" ]]; then
		printText "Wird geladen:" "$progH ($progB KB / $progM KB) [#####-----] $downloaded% ($mbsec MB/s) [$speedtimeX]/[$speedtime_eta]"
	fi
	
	if [[ "$downloaded" -ge "60" && "$downloaded" -lt "70" ]]; then
		printText "Wird geladen:" "$progH ($progB KB / $progM KB) [######----] $downloaded% ($mbsec MB/s) [$speedtimeX]/[$speedtime_eta]"
	fi
	
	if [[ "$downloaded" -ge "70" && "$downloaded" -lt "80" ]]; then
		printText "Wird geladen:" "$progH ($progB KB / $progM KB) [#######---] $downloaded% ($mbsec MB/s) [$speedtimeX]/[$speedtime_eta]"
	fi
	
	if [[ "$downloaded" -ge "80" && "$downloaded" -lt "90" ]]; then
		printText "Wird geladen:" "$progH ($progB KB / $progM KB) [########--] $downloaded% ($mbsec MB/s) [$speedtimeX]/[$speedtime_eta]"
	fi
	
	if [[ "$downloaded" -ge "90" && "$downloaded" -lt "99" ]]; then
		printText "Wird geladen:" "$progH ($progB KB / $progM KB) [#########-] $downloaded% ($mbsec MB/s) [$speedtimeX]/[$speedtime_eta]"
	fi
	
	if [[ "$downloaded" -ge "99" && "$downloaded" -lt "100" ]]; then
		printText "Wird geladen:" "$progH ($progB KB / $progM KB) [##########] $downloaded% ($mbsec MB/s) [$speedtimeX]/[$speedtime_eta]"
	fi
	
	# wenn der download komplett ist: beenden
	if [[ "$downloaded" == "100" ]]; then
		printDone "Wird geladen:" "$progH ($progB KB / $progM KB) [##########] $downloaded% ($mbsec MB/s) [$speedtimeX]/[00:00:00]"
		sleep 1
		break
	fi
				else
					echo "Download Fehler!"
					exit 1
				fi
fi
	# schlafen
	sleep 5
done
