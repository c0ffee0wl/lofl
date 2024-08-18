#!/usr/bin/env bash

set -Euo pipefail

# Check if running as root or sudo
if [ "$EUID" -ne 0 ]
then
    echo "Please run as root or with sudo" >&2
    exit 1
fi


echo "Installing dnsmasq and configuring it to listen on port 5353 ..."
echo

if ! command -v dnsmasq &> /dev/null; then
    apt update
    apt install -y dnsmasq python3-dnslib
fi

cp /etc/dnsmasq.conf /etc/dnsmasq.conf.bak

tee /etc/dnsmasq.conf <<EOF
# Configuration file for dnsmasq.
#
# Format is one option per line, legal options are the same
# as the long options legal on the command line. See
# "/usr/sbin/dnsmasq --help" or "man 8 dnsmasq" for details.

port=5353

# Default DNS server
server=1.0.0.1

EOF

systemctl enable dnsmasq --now


echo
echo
echo "Installing a systemd service for the dns-over-tcp Python script ..."
echo

systemctl stop dns-over-tcp 2>/dev/null

tee /etc/systemd/system/dns-over-tcp.service <<EOF
[Unit]
Description=DNS over TCP service
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=3
ExecStart=/usr/bin/env python "$PWD/dns_over_tcp.py"

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable dns-over-tcp --now
