#!/usr/bin/env bash

set -Eo pipefail

bn=$(basename $0)
usage="Usage: $bn DOMAIN DNSSERVER

Parameters:
  DOMAIN: Name of Active directory domain, for example: essos.local
  DNSSERVER: IP address of the internal DNS server.
             Noted down in CIDR notation, for example: 192.168.56.12

Example:
  Create a new DNS forwarder for a specific domain in dnsmasq.conf
  $bn essos.local 192.168.56.12
  
  Delete entry for specific domain
  $bn -d essos.local"


restart_services () {
    systemctl restart dnsmasq

    if grep -q "port=5353$" /etc/dnsmasq.conf 2>/dev/null && systemctl list-unit-files dns-over-tcp.service &>/dev/null; then
        systemctl restart dns-over-tcp
    fi
}


# Check if running as root or sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo" >&2
    exit 1
fi

if ! command -v dnsmasq &> /dev/null; then
    echo "dnsmasq not installed. Execute setup script first." >&2
    exit 1
fi

# Parse command-line options
delete_interface=false
while getopts ":d" opt; do
    case ${opt} in
        d)
            delete_interface=true
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            exit 1
            ;;
    esac
done

# Shift the parsed options
shift $((OPTIND -1))


if $delete_interface ; then
    if [[ -z $1 ]]; then
        echo -e "$usage" >&2
        exit 1
    else
        domain=$1
        ipaddress=$(grep "/${domain}/" /etc/dnsmasq.conf | cut -d '/' -f 3)
        echo "Deleting \"$domain\" from dnsmasq.conf if present"
        sed -i "/\/${domain}\//d" /etc/dnsmasq.conf
        number=$(grep -c "/${ipaddress}$" /etc/dnsmasq.conf)
        if [[ $number -eq 1 ]]; then
            echo "Deleting \"$ipaddress\" from dnsmasq.conf"
            sed -i "/\/${ipaddress}$/d" /etc/dnsmasq.conf
        fi
        restart_services
        exit
    fi
fi


# Check for mandatory positional parameter
if [[ -z $2 ]]; then
    echo -e "$usage" >&2
    exit 1
fi

# Collect parameters
domain=$1
dnsserver=$2


validdomain='^(([a-zA-Z](-?[a-zA-Z0-9])*)\.)+[a-zA-Z]{2,}$'
if ! echo $domain | grep -q -E "$validdomain" &>/dev/null ; then
    echo "\"$domain\" is an invalid domain name." >&2
    exit 1
fi

if grep "/$domain/" /etc/dnsmasq.conf &>/dev/null ; then
    echo "\"$domain\" already in dnsmasq.conf." >&2
    exit 1
fi

validip='^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$'
if ! echo $dnsserver | grep -q -E "$validip" &>/dev/null ; then
    echo "DNS server address \"$dnsserver\" is not a valid IP address." >&2
    exit 1
fi

dnspartial=$(echo $dnsserver | cut -d '.' -f 1-3)

echo "Adding to dnsmasq.conf and restarting dnsmasq (and dns-over-tcp):"
echo

tee -a /etc/dnsmasq.conf <<EOF
server=/${domain}/${dnsserver}
EOF

if ! grep -q ".in-addr.arpa/${dnsserver}" /etc/dnsmasq.conf &>/dev/null ; then
tee -a /etc/dnsmasq.conf <<EOF
server=/${dnspartial}.in-addr.arpa/${dnsserver}
EOF
fi

restart_services

