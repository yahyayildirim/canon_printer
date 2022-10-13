#!/bin/bash

[ $USER != 'root' ] && exec sudo "$0"

#Current user / Şu anki kullanıcı
USER_HOME=$(dirname $XAUTHORITY)
LOGIN_USER=$(echo $USER_HOME | sed 's|.*/||')

[ -z "$LOGIN_USER" ] && LOGIN_USER=$(who | head -1 | awk '{print $1}')

echo 'captstatusui sonlandırılıyor.'
killall captstatusui 2> /dev/null
echo 'CCPD durduruluyor.'
service ccpd stop
echo 'CUPS ve CCPD yeniden başlatılıyor.'
service cups restart
echo 'captstatusui başlatılıyor. '
while true
do
	sleep 1
	set -- $(pidof /usr/sbin/ccpd)
	if [ -n "$1" -a -n "$2" ]; then
		sudo -u $LOGIN_USER nohup captstatusui -P $(ccpdadmin | grep LBP | awk '{print $3}') > /dev/null 2>&1 &
		sleep 2
		break
	fi
done
echo
echo 'Yazıcınız halen çalışmıyorsa, bilgisayarı yeniden başlatın.'
echo 'Çıkmak için bir tuşa basın'
echo -ne "\e[12D saniye sonra otomatik çıkış yapılacaktır."
sec=30
while [ $sec -ne 0 ]
do
	len=$(( ${#sec} + 1 ))
	echo -ne "$sec \e[${len}D"
	sec=$(( $sec - 1 ))
	read -s -n1 -t1 && break
done
