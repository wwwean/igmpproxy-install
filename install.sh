#!/bin/sh

IGMPCONF_PATH=/etc/config/igmpproxy
INTERFACE_NAME=iptv

function isRoot() {
    if [ "$EUID" -ne 0 ]; then
        return 1
    fi
}

function initialCheck() {
    if ! isRoot; then
        echo "Недостаточно прав. Скрипт необходимо запустить от пользователя root"
        exit 1
    fi
}

function installIgmpproxy() {
    echo "Установка/обновление Igmpproxy"
    opkg update
    opkg install igmpproxy
}

function configuringIgmpproxy() {
    echo "Настройка Igmpproxy"

cat <<EOF > "$IGMPCONF_PATH"
config igmpproxy
        option quickleave 1
#       option verbose [0-3](none, minimal[default], more, maximum)

config phyint
        option network $INTERFACE_NAME
        option zone wan
        option direction upstream
        list altnet 192.168.0.0/16
        list altnet 172.16.0.0/12
        list altnet 10.0.0.0/8


config phyint
        option network lan
        option zone lan
        option direction downstream

config phyint
        option network loopback
        option direction disabled
EOF
}

function addInterface() {
    echo "Настройка/добавление интерфейса"
    echo
    echo "Сохранение резервной копиии настроек network и firewall"
    uci export network > /etc/config/network.backup
    uci export firewall > /etc/config/firewall.backup

    if ! uci -q show network."$INTERFACE_NAME" >/dev/null; then
        uci set network."$INTERFACE_NAME"=interface
        uci set network."$INTERFACE_NAME".proto='static'
        uci set network."$INTERFACE_NAME".device='eth1'
        uci set network."$INTERFACE_NAME".ipaddr='1.0.0.1'
        uci set network."$INTERFACE_NAME".netmask='255.255.255.0'
    else
        uci delete network."$INTERFACE_NAME"
        uci set network."$INTERFACE_NAME"=interface
        uci set network."$INTERFACE_NAME".proto='static'
        uci set network."$INTERFACE_NAME".device='eth1'
        uci set network."$INTERFACE_NAME".ipaddr='1.0.0.1'
        uci set network."$INTERFACE_NAME".netmask='255.255.255.0'
    fi
    uci commit network

    uci add_list firewall.wan.network="$INTERFACE_NAME"
    uci commit firewall
}

initialCheck
installIgmpproxy
configuringIgmpproxy
addInterface

echo "Перезапуск igmpproxy"
service igmpproxy restart
echo
echo "Настройка igmpproxy завершена"
