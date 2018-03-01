#!/bin/bash
# ==========================================================================================================
# SFDL BASH-Loader - Updater - raz3r
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
version_repo=0
version_local=0
first_install=false
url_repoversion="https://raw.githubusercontent.com/raz3r-code/sfdl-bash-loader/master/sfdl_bash_loader/sys/logs/version.txt"
url_repodownload="https://github.com/raz3r-code/sfdl-bash-loader/trunk/sfdl_bash_loader/"


status=`ps aux | grep [-i] 'bashloader.sh' 2> /dev/null | wc -l | tr -d '[[:space:]]'`
if [ "$status" -gt 0 ]; then
    echo "[`date`] : BASH-Loader wird bereits ausgefuehrt! [pid: $status]"
    exit 1
fi

if ! [ -z $1 ]; then
	first_install=true
	mkdir sfdl_bash_loader/
	cd sfdl_bash_loader
fi 
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

# macht das bild sauber

clear
echo "# =========================================================================================================="
echo "# SFDL BASH-Loader - Installer/Updater - raz3r"
echo "# =========================================================================================================="
echo "| system: $osxcheck"

chkTools()
{
	installTools=()
	# brew (Darwin)
	if [ $osxcheck == "Darwin" ]; then
		brew=0
		if hash brew 2>/dev/null; then
			brew=1
		else
			installTools+=($(echo "brew "))
		fi
	fi
    
	# svn
	subv=0
	if hash svn 2>/dev/null; then
		subv=1
	else
		installTools+=($(echo "subversion "))
	fi
	
	# wget
	wget=0
	if hash wget 2>/dev/null; then
		wget=1
	else
		installTools+=($(echo "wget "))
	fi
	
	if [ ! -z "$1" ]; then
		if [ "$1" == "true" ]; then
			echo "| -- TOOLS ----------------------------- "
			echo "| subversion: $subv"
			echo "| wget:    	$wget"
			if [ $osxcheck == "Darwin" ]; then
				echo "| brew:    	$brew"
			fi
			echo "| -------------------------------------- "
			echo "| tools fehlen: ${#installTools[@]}"
			echo "| Tools: ${installTools[@]}"
			echo "| ----------------------------- TOOLS -- "
		fi
	fi
}

loaderupdate()
{
echo "| -------------------------------------- "

#hole versionsnummern
version_repo=$(wget -q -O - "$@" $url_repoversion | cut -d"." -f2)

if [ -f "$pwd/sys/logs/version.txt" ]; then
	version_local=$(cat "./sys/logs/version.txt" | cut -d"." -f2)
fi

if [ $first_install = false ]; then
	echo "| Installiert Version: 3.$version_local"
fi

echo "| Aktuelle Version:    3.$version_repo"
echo "| -------------------------------------- "
if [ $(($version_local)) -lt $(($version_repo)) ]; then
	echo "| ! Neue Version wird installiert !"
	echo "| -------------------------------------- "
	
	if [ -d "$pwd/sys" ]; then
		echo "| Konfiguration speichern..."
		mkdir "$pwd/backup/"
		cp -rf "$pwd/sys/userscript" "$pwd/backup/userscript/"
		cp -rf "$pwd/sys/loader.cfg" "$pwd/backup/loader.cfg"
	fi
	rm -rf "$pwd/sys/"
	rm -rf "$pwd/start.sh"
	
	echo "| Download wird gestartet."
	echo "| Bitte warten ..."
	
	svn export "$url_repodownload"sys/ 1> /dev/null
	svn export "$url_repodownload"start.sh 1> /dev/null
	
	if [ $first_install = true ]; then
		svn export "$url_repodownload"update.sh 1> /dev/null
	fi 
	
	chmod +x start.sh
	
	if [ -d "$pwd/backup" ]; then
		echo "| Konfiguration wiederherstellen..."
		cp -rf "$pwd/backup/userscript" "$pwd/sys/userscript/"
		cp -rf "$pwd/backup/loader.cfg" "$pwd/sys/loader.cfg"
		rm -rf "$pwd/backup/"
	fi
	
	if ! [ -d "$pwd/sfdl" ]; then
		mkdir sfdl
	fi
	
	if ! [ -d "$pwd/downloads" ]; then
		mkdir downloads
	fi
	if [ $first_install = true ]; then
		echo "| Installation abgeschlossen "
	else
		echo "| Update abgeschlossen "
	fi
	echo "| -------------------------------------- "
else
	echo "| -------------------------------------- "
	echo "| Version ist aktuell!"	
	echo "| -------------------------------------- "	
fi
}

chkTools

if [ "${#installTools[@]}" != 0 ]; then
	echo "| Es sind nicht alle Tools installiert!"
	echo "| Installiere ${#installTools[@]} fehlende Tools ... bitte warten ..."
	
	if [ $osxcheck == "Darwin" ]; then
		if hash brew 2>/dev/null; then
			brew install ${installTools[@]} > /dev/null
		else
			/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" > /dev/null
			brew install ${installTools[@]} > /dev/null
		fi
	else
		if hash apt-get 2>/dev/null; then
			# sudo pass eingabe
			usesudo=0
			if hash sudo 2>/dev/null; then
				usesudo=1
				while [[ -z "$sudopass" ]]
				do
					read -p "| Bitte SUDO Passwort eingeben: " sudopass
				done
			fi
			if [ $usesudo == 1 ]; then
				echo $sudopass | sudo -S apt-get --yes --force-yes install ${installTools[@]} > /dev/null
			else
				apt-get --yes --force-yes install ${installTools[@]} > /dev/null
			fi
		else
			echo "| Konnte Paketmanager APT nicht finden!"
		fi
	fi
	
	chkTools "true"

	if [ "${#installTools[@]}" != 0 ]; then
		echo "| BASH-Loader Installer konnte ${#installTools[@]} Tools"
		echo "| nicht installieren: ${installTools[@]}"
		if [ $osxcheck == "Darwin" ]; then
			echo "| Installiere Homebrew: http://brew.sh"
			echo "| und installiere z.B. mit: brew install ${installTools[@]}"
		else
			echo "| Versuche Tools mit dem Paketmanager zu"
			echo "| installieren. Beispiel: sudo apt-get --yes install ${installTools[@]}"
		fi
	else
		echo "| -------------------------------------- "
		echo "| Alle Pakete installiert!"
		echo "| Starte Installation in 5 Sekunden ..."
		sleep 5
		loaderupdate
	fi
else
	echo "| -------------------------------------- "
	echo "| Alle Pakete installiert!"
	echo "| Starte Installation in 5 Sekunden ..."
	sleep 5
    loaderupdate
fi









