#!/usr/bin/env bash

##################################################
#Version 3.3 updated on September 13, 2019
#http://help.ubuntu.ru/wiki/canon_capt
#http://forum.ubuntu.ru/index.php?topic=189049.0
#Translated into English and modified by @hieplpvip
#Translated into Turkish by @yahyayildirim 
##################################################

baslik="CANON LBP YAZICI MODELLERİ İÇİN SÜRÜCÜ YÜKLEME SCRİPTİ"

#Check if we are running as root / root olarak çalışıp çalışmadığımızı kontrol ediyoruz
[ $USER != 'root' ] && exec sudo "$0"

#Current user / Şu anki kullanıcı
USER_HOME=$(dirname $XAUTHORITY)
LOGIN_USER=$(echo $USER_HOME | sed 's|.*/||')

[ -z "$LOGIN_USER" ] && LOGIN_USER=$(who | head -1 | awk '{print $1}')

#Load the file containing the path to the desktop / Masaüstünde oluşturulacak kısayol değişkeni
XDG_DESKTOP_DIR="$USER_HOME/.local/share/applications/"

#Driver version / Sürücü versiyonu
DRIVER_VERSION='2.71-1'
DRIVER_VERSION_COMMON='3.21-1'

#Links to driver packages / Sürücü dosyası linkleri
declare -A URL_DRIVER=([amd64_common]='https://gitlab.com/yahyayildirim/canon_printer/-/raw/main/src/cndrvcups-common_3.21-1_amd64.deb' \
[amd64_capt]='https://gitlab.com/yahyayildirim/canon_printer/-/raw/main/src/cndrvcups-capt_2.71-1_amd64.deb' \
[i386_common]='https://gitlab.com/yahyayildirim/canon_printer/-/raw/main/src/cndrvcups-common_3.21-1_i386.deb' \
[i386_capt]='https://gitlab.com/yahyayildirim/canon_printer/-/raw/main/src/cndrvcups-capt_2.71-1_i386.deb')

#Links to autoshutdowntool 
declare -A URL_ASDT=([amd64]='https://gitlab.com/yahyayildirim/canon_printer/-/raw/main/src/autoshutdowntool_1.00-1_amd64_deb.tar.gz' \
[i386]='https://gitlab.com/yahyayildirim/canon_printer/-/raw/main/src/autoshutdowntool_1.00-1_i386_deb.tar.gz')


#ppd files and printer models mapping / ppd dosyaları ve yazıcı modelleri
declare -A LASERSHOT=([LBP-810]=1120 [LBP1120]=1120 [LBP1210]=1210 \
[LBP2900]=2900 [LBP3000]=3000 [LBP3010]=3050 [LBP3018]=3050 [LBP3050]=3050 \
[LBP3100]=3150 [LBP3108]=3150 [LBP3150]=3150 [LBP3200]=3200 [LBP3210]=3210 \
[LBP3250]=3250 [LBP3300]=3300 [LBP3310]=3310 [LBP3500]=3500 [LBP5000]=5000 \
[LBP5050]=5050 [LBP5100]=5100 [LBP5300]=5300 [LBP6000]=6018 [LBP6018]=6018 \
[LBP6020]=6020 [LBP6020B]=6020 [LBP6200]=6200 [LBP6300n]=6300n [LBP6300]=6300 \
[LBP6310]=6310 [LBP7010C]=7018C [LBP7018C]=7018C [LBP7200C]=7200C [LBP7210C]=7210C \
[LBP9100C]=9100C [LBP9200C]=9200C)

#Sort printer names / yazı adlarını sıraya koy
NAMESPRINTERS=$(echo "${!LASERSHOT[@]}" | tr ' ' '\n' | sort -n -k1.4)

#Models supported by autoshutdowntool - autoshutdowntool özelliğini destekleyen yazıcılar
declare -A ASDT_SUPPORTED_MODELS=([LBP6020]='MTNA002001 MTNA999999' \
[LBP6020B]='MTMA002001 MTMA999999' [LBP6200]='MTPA00001 MTPA99999' \
[LBP6310]='MTLA002001 MTLA999999' [LBP7010C]='MTQA00001 MTQA99999' \
[LBP7018C]='MTRA00001 MTRA99999' [LBP7210C]='MTKA002001 MTKA999999')

#OS architecture / İşletim Sistemi Tespit Etme
if [ "$(uname -m)" == 'x86_64' ]; then
	ARCH='amd64'
else
	ARCH='i386'
fi

#Determine the init system / Servis öneticisini tespit etme
if [[ $(ps -p1 | grep systemd) ]]; then
	INIT_SYSTEM='systemd'
else
	INIT_SYSTEM='upstart'
fi

#Move to the current directory / Mevcut dizine geç
cd "$(dirname "$0")"

function valid_ip() {
	local ip=$1
	local stat=1

	if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
		ip=($(echo "$ip" | tr '.' ' '))
		[[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
		stat=$?
	fi
	return $stat
}

function check_error() {
	if [ $2 -ne 0 ]; then
		case $1 in
			'WGET') echo "$3 dosyası indirilirken hata oluştu."
				[ -n "$3" ] && [ -f "$3" ] && rm "$3";;
			'PACKAGE') echo "$3 paket indirilirken hata oluştu.";;
			*) echo 'Error';;
		esac
		echo 'Çıkmak için herhangi bir tuşa basın...'
		read -s -n1
		exit 1
	fi
}

function canon_uninstall() {
	if [ -f /usr/sbin/ccpdadmin ]; then
		installed_model=$(ccpdadmin | grep LBP | awk '{print $3}')
		if [ -n "$installed_model" ]; then
			echo "$installed_model yazıcı bulundu."
			echo "captstatusui kapatılıyor."
			killall captstatusui 2> /dev/null
			echo 'CCPD durduruluyor.'
			service ccpd stop
			echo 'CCPD ile yapılandırılan yazıcı ayarları siliniyor.'
			ccpdadmin -x $installed_model
			echo 'Yazıcı CUPS üzerinden kaldırılıyor.'
			lpadmin -x $installed_model
		fi
	fi
	echo 'Driver paketleri kaldırılıyor.'
	dpkg --purge cndrvcups-capt
	dpkg --purge cndrvcups-common
	echo 'Kullanılmayan kütüphane ve paketler kaldırılıyor.'
	apt-get -y autoremove
	echo 'Ayarlar siliniyor.'
	[ -f /etc/init/ccpd-start.conf ] && rm /etc/init/ccpd-start.conf
	[ -f /etc/udev/rules.d/85-canon-capt.rules ] && rm /etc/udev/rules.d/85-canon-capt.rules
	[ -f "${XDG_DESKTOP_DIR}/captstatusui.desktop" ] && rm "${XDG_DESKTOP_DIR}/captstatusui.desktop"
	[ -f "${XDG_DESKTOP_DIR}/$NAMEPRINTER.desktop" ] && rm "${XDG_DESKTOP_DIR}/$NAMEPRINTER.desktop"
	[ -f /usr/bin/autoshutdowntool ] && rm /usr/bin/autoshutdowntool
	[ $INIT_SYSTEM == 'systemd' ] && update-rc.d -f ccpd remove
	echo 'Kaldırma tamamlandı.'
	echo 'Çıkmak için herhangi bir tuşa basın...'
	read -s -n1
	return 0
}


function canon_install() {
	clear
	echo -e "$baslik\n"
	PS3='
Lütfen yazıcı modelinizi seçin: '
	select NAMEPRINTER in $NAMESPRINTERS
	do
		[ -n "$NAMEPRINTER" ] && break
	done
	clear
	echo -e "$baslik\n"
	echo "Seçtiğiniz Yazıcı: $NAMEPRINTER"
	echo
	PS3='
Yazıcınız bilgisayara nasıl bağlanmış durumda: '
	select CONNECTION in 'USB üzerinden' 'Ağ Üzerinden (LAN, NET)' 'Geri Dön'
	do
		if [ "$REPLY" == "1" ]; then
			CONNECTION="usb"
			while true
			do
				#Looking for a device connected to the USB port / USB'ye bağlı cihaz-yazıcı arama
				NODE_DEVICE=$(ls -1t /dev/usb/lp* 2> /dev/null | head -1)
				if [ -n "$NODE_DEVICE" ]; then
					#Find the serial number of that device / USB'ye bağlı olan cihazın seri numarasını bul
					PRINTER_SERIAL=$(udevadm info --attribute-walk --name=$NODE_DEVICE | sed '/./{H;$!d;};x;/ATTRS{product}=="Canon CAPT USB \(Device\|Printer\)"/!d;' | awk -F'==' '/ATTRS{serial}/{print $2}')
					#If the serial number is found, that device is a Canon printer / Eğer seri numarası bulunursa, bu cihaz bir Canon yazıcısıdır
					[ -n "$PRINTER_SERIAL" ] && break
				fi
				echo -ne "\nYazıyı açın ve kabloyu bilgisayara bağlayın."
				sleep 2
			done
			PATH_DEVICE="/dev/canon$NAMEPRINTER"
			break
		elif [ "$REPLY" == "2" ]; then
			CONNECTION="lan"
			read -p 'Yazıcının IP adresini giriniz: ' IP_ADDRES
			until valid_ip "$IP_ADDRES"
			do
				echo 'Hatalı IP adresi girdiniz.  Örn: 192.168.1.23 veya 10.23.23.23 vs. girin.'
				read IP_ADDRES
			done
			PATH_DEVICE="net:$IP_ADDRES"
			echo 'Yazıcıyı açın ve herhangi bir tuşa basın'
			read -s -n1
			sleep 5
			break
		elif [ "$REPLY" == "3" ]; then
			canon_install
			break
		fi
	done
	clear
	echo -e "$baslik\n"
	echo '************Sürücü Kurulumu************'
	COMMON_FILE=cndrvcups-common_${DRIVER_VERSION_COMMON}_${ARCH}.deb
	CAPT_FILE=cndrvcups-capt_${DRIVER_VERSION}_${ARCH}.deb
	if [ ! -f $COMMON_FILE ]; then
		sudo -u $LOGIN_USER wget -c -O $COMMON_FILE ${URL_DRIVER[${ARCH}_common]} --show-progress --no-check-certificate
		check_error WGET $? $COMMON_FILE
	fi
	if [ ! -f $CAPT_FILE ]; then
		sudo -u $LOGIN_USER wget -c -O $CAPT_FILE ${URL_DRIVER[${ARCH}_capt]} --show-progress --no-check-certificate
		check_error WGET $? $CAPT_FILE
	fi
	dpkg --add-architecture i386
	apt update -y
	apt install -y libglade2-0 libcanberra-gtk-module
	check_error PACKAGE $?
	echo 'CUPS sürücüleri yükleniyor'
	apt install -f ./$COMMON_FILE
	check_error PACKAGE $? $COMMON_FILE
	echo 'CAPT Printer Driver Modülü yükleniyor.'
	apt install -f ./$CAPT_FILE
	check_error PACKAGE $? $CAPT_FILE
	#Replace /etc/init.d/ccpd
	echo '#!/bin/bash
# CUPS için Canon Yazıcı Arkaplan Uygulaması Scripti (ccpd)
### BEGIN INIT INFO
# Provides:          ccpd
# Required-Start:    $local_fs $remote_fs $syslog $network $named
# Should-Start:      $ALL
# Required-Stop:     $syslog $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Description:       Start Canon Printer Daemon for CUPS
### END INIT INFO

# If the CUPS print server is not running, wait until it starts
# CUPS yazdırma sunucusu çalışmıyorsa, başlayana kadar bekleyin
if [ `ps awx | grep cupsd | grep -v grep | wc -l` -eq 0 ]; then
	while [ `ps awx | grep cupsd | grep -v grep | wc -l` -eq 0 ]
	do
		sleep 3
	done
	sleep 5
fi

ccpd_start ()
{
	echo -n "${DAEMON} başlatılıyor: "
	start-stop-daemon --start --quiet --oknodo --exec ${DAEMON}
}

ccpd_stop ()
{
	echo -n "${DAEMON} kapatılıyor: "
	start-stop-daemon --stop --quiet --oknodo --retry TERM/30/KILL/5 --exec ${DAEMON}
}

DAEMON=/usr/sbin/ccpd
case $1 in
	start)
		ccpd_start
		;;
	stop)
		ccpd_stop
		;;
	status)
		echo "${DAEMON}:" $(pidof ${DAEMON})
		;;
	restart)
		while true
		do
			ccpd_stop
			ccpd_start
			# if the ccpd process does not appear after 5 seconds, we restart it again
			# ccpd işlemi 5 saniye sonra görünmezse, yeniden başlatılacak
			for (( i = 1 ; i <= 5 ; i++ ))
			do
				sleep 1
				set -- $(pidof ${DAEMON})
				[ -n "$1" -a -n "$2" ] && exit 0
			done
		done
		;;
	*)
		echo "Açıklama: ccpd {start|stop|status|restart}"
		exit 1
		;;
esac
exit 0' > /etc/init.d/ccpd
	#Installation utilities for managing AppArmor / AppArmor'u yönetmek için yardımcı program kuruluyor
	apt -y install apparmor-utils
	#Set AppArmor security profile for cupsd to complain mode / Cupsd Hata Modu için AppArmor güvenlik profilini ayarlanıyor
	aa-complain /usr/sbin/cupsd
	echo 'CUPS yeniden başlatılıyor.'
	service cups restart
	if [ $ARCH == 'amd64' ]; then
		echo '64-bit sürücülerinin çalışabilmesi için gerekli olan 32-bit kütüphaneleri yükleniyor.'
		apt -y install libatk1.0-0:i386 libcairo2:i386 libgtk2.0-0:i386 libpango1.0-0:i386 libstdc++6:i386 libpopt0:i386 libxml2:i386 libc6:i386
		check_error PACKAGE $?
	fi
	echo "Yazıcı CUPS'a yükleniyor"
	/usr/sbin/lpadmin -p $NAMEPRINTER -P /usr/share/cups/model/CNCUPSLBP${LASERSHOT[$NAMEPRINTER]}CAPTK.ppd -v ccp://localhost:59687 -E
	echo "$NAMEPRINTER varsayılan yazıcı olarak ayarlanıyor."
	/usr/sbin/lpadmin -d $NAMEPRINTER
	echo 'Yazıcı ccpd arkaplan programı yapılandırma dosyasına kaydediliyor.'
	/usr/sbin/ccpdadmin -p $NAMEPRINTER -o $PATH_DEVICE
	#Verify printer installation / Yazıcı kurulumunu doğrulanıyor
	installed_printer=$(ccpdadmin | grep $NAMEPRINTER | awk '{print $3}')
	if [ -n "$installed_printer" ]; then
		if [ "$CONNECTION" == "usb" ]; then
			echo 'Yazıcı için kural oluşturuluyor.'
			#A rule is created to provides an alternative name (a symbolic link) to our printer so as not to depend on the changing values of lp0, lp1,...
			#lp0, lp1, ... değişken değerlerine bağlı kalmamak için yazıcımıza alternatif bir ad (sembolik bir bağlantı) sağlamak için bir kural oluşturuluyor.			
			echo 'KERNEL=="lp[0-9]*", SUBSYSTEMS=="usb", ATTRS{serial}=='$PRINTER_SERIAL', SYMLINK+="canon'$NAMEPRINTER'"' > /etc/udev/rules.d/85-canon-capt.rules
			#Update the rules / Kurallar güncelleniyor
			udevadm control --reload-rules
			#Check the created rule / Oluşturulan kural kontrol ediliyor
			until [ -e $PATH_DEVICE ]
			do
				echo -ne "Yazıcıyı kapatın, 2 saniye bekleyin ve yazıcıyı tekrar açın.\r"
				sleep 2
			done
		fi
		echo -e "\e[2Kccpd çalıştırılıyor."
		service ccpd restart
		
		#Autoload ccpd - ccpd aktifleştiriliyor
		if [ $INIT_SYSTEM == 'systemd' ]; then
			update-rc.d ccpd defaults
		else
			echo 'description "Canon Printer Daemon for CUPS (ccpd)"
author "LinuxMania <customer@linuxmania.jp>"
start on (started cups and runlevel [2345])
stop on runlevel [016]
expect fork
respawn
exec /usr/sbin/ccpd start' > /etc/init/ccpd-start.conf
		fi
		#Create captstatusui shortcut on desktop / Masaüstünde captstatusui kısayolu oluşturuluyor
		echo "#!/usr/bin/env xdg-open
[Desktop Entry]
Version=1.0
Name=$NAMEPRINTER
GenericName=Status monitor for Canon CAPT Printer
GenericName[tr]=Canon CAPT Yazıcılar İçin Durum Kontrol Programı
Exec=captstatusui -P $NAMEPRINTER
Terminal=false
Type=Application
Icon=/usr/share/icons/pardus/48x48/devices/printer.svg" > "${XDG_DESKTOP_DIR}/$NAMEPRINTER.desktop"
		chmod 775 "${XDG_DESKTOP_DIR}/$NAMEPRINTER.desktop"
		chown $LOGIN_USER:$LOGIN_USER "${XDG_DESKTOP_DIR}/$NAMEPRINTER.desktop"

		#Install autoshutdowntool for supported models
		if [[ "${!ASDT_SUPPORTED_MODELS[@]}" =~ "$NAMEPRINTER" ]]; then
			SERIALRANGE=(${ASDT_SUPPORTED_MODELS[$NAMEPRINTER]})
			SERIALMIN=${SERIALRANGE[0]}
			SERIALMAX=${SERIALRANGE[1]}
			if [[ ${#PRINTER_SERIAL} -eq ${#SERIALMIN} && $PRINTER_SERIAL > $SERIALMIN && $PRINTER_SERIAL < $SERIALMAX || $PRINTER_SERIAL == $SERIALMIN || $PRINTER_SERIAL == $SERIALMAX ]]; then
				echo "autoshutdowntool yardımcı programı yükleniyor."
				ASDT_FILE=autoshutdowntool_1.00-1_${ARCH}_deb.tar.gz
				if [ ! -f $ASDT_FILE ]; then
					wget -c -O $ASDT_FILE ${URL_ASDT[$ARCH]} --show-progress
					check_error WGET $? $ASDT_FILE
				fi
				tar --gzip --extract --file=$ASDT_FILE --totals --directory=/usr/bin
			fi
		fi

		#Start captstatusui / captstatusui başlatılıyor
		if [[ -n "$DISPLAY" ]] ; then
			sudo -u $LOGIN_USER nohup captstatusui -P $NAMEPRINTER > /dev/null 2>&1 &
			sleep 5
		fi
		echo 'Kurulum tamamlandı. Çıkmak için bir tuşa basın.'
		read -s -n1
		exit 0
	else
		echo '$NAMEPRINTER için driver yüklenemedi!'
		echo 'Çıkmak için bir tuşa basın.'
		read -s -n1
		exit 1
	fi
}

function canon_help {
	clear
	echo 'YÜKLEME NOTLARI:
1- Bu yazıcı serisi için zaten sürücü yüklediyseniz, bu komut dosyasını kullanmadan önce onu kaldırın.
2- Sürücü paketleri bulunmazsa, otomatik olarak İnternetten indirilir ve komut dosyası klasörüne kaydedilir.
3- Sürücüyü güncellemek için önce bu komut dosyasını kullanarak eski sürümü kaldırın, daha sonra yenisini kurun.

YAZDIRMA SORUNLARI İLE İLGİLİ NOTLAR:
1- Yazıcı yazdırmayı durdurursa, terminalden bu kodu çalıştırın: captstatusui -P <printer_name>
2- captstatusui penceresi yazıcının mevcut durumunu gösterir. Bir hata oluşursa, açıklaması bu ekranda görüntülenir.
3- Yazdırmaya devam etmek için "Resume Job/İşi Devam Ettir" düğmesine basmayı deneyebilirsiniz veya işi iptal etmek için "Cancel Job/İşi İptal Et" düğmesine basabilirsiniz.
Bu yardımcı olmazsa "canon_restart.sh"yi çalıştırmayı deneyin.


Yazıcı yapılandırma komutu: cngplp
Ek ayarlar komutu: captstatusui -P <yazıcı_adı>
Otomatik kapatmak için (tüm modeller için geçerli değildir): autoshutdowntool
'
}

clear
echo -e "$baslik\n"
echo "DESTEKLENEN YAZICILAR:"
echo "$NAMESPRINTERS" | sed ':a; /$/N; s/\n/\ \t/; ta' | fold -s
echo
PS3='
Lütfen seçim yapın: '
select opt in 'Kur' 'Kaldır' 'Yardım' 'Çıkış'
do
	if [ "$opt" == 'Kur' ]; then
		canon_install
		break
	elif [ "$opt" == 'Kaldır' ]; then
		canon_uninstall
		break
	elif [ "$opt" == 'Yardım' ]; then
		canon_help
	elif [ "$opt" == 'Çıkış' ]; then
		break
	fi
done
