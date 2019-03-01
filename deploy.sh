TUNIFACE="tun0"
IFACENAME="eth1"
IP_DNS="89.234.141.66" # recursif.arn-fai.net. You should change this according to the DNS resolver used in /etc/resolv.dnsmasq.conf
# This script also currently assumes that /etc/network/intefaces includes /etc/network/interfaces.d/*

apt update
apt install isc-dhcp-server -y

# Enable (non)predictive interface name
ln -s /dev/null /etc/systemd/network/99-default.link

# Configure interface
echo "allow-hotplug $IFACENAME"     >  /etc/network/interfaces.d/$IFACENAME.conf
echo "iface $IFACENAME inet static" >> /etc/network/interfaces.d/$IFACENAME.conf
echo "address 10.0.0.1/24"          >> /etc/network/interfaces.d/$IFACENAME.conf

# Configure dhcpd

cat << EOF > /etc/dhcp/dhcpd.conf
default-lease-time 600;
max-lease-time 7200;
ddns-update-style none;
subnet 10.0.0.0 netmask 255.255.255.0 {
	range 10.0.0.10 10.0.0.100;
	option routers 10.0.0.1;
	option domain-name-servers $IP_DNS;
}
EOF

# Configure isc-dhcp-server

sed -i 's/INTERFACESv/#INTERFACESv/g' /etc/default/isc-dhcp-server 
sed -i 's/INTERFACESv/#INTERFACESv/g' /etc/default/isc-dhcp-server 
echo "INTERFACESv4='$IFACENAME'" >> /etc/default/isc-dhcp-server

# Blackmagic for iptables / masquerade

cat << EOF > /usr/local/bin/ynh-extraeth
#!/bin/bash

iptables -t nat -A POSTROUTING -s 10.0.0.1/24 -o $TUNIFACE -j MASQUERADE
echo 1 > /proc/sys/net/ipv4/ip_forward

case "\$1" in
	start)
		systemctl stop isc-dhcp-server
		systemctl start isc-dhcp-server
	;;
	stop)
		systemctl stop isc-dhcp-server
	;;
esac

exit 0
EOF

chmod +x /usr/local/bin/ynh-extraeth

# Add a service to run the iptable blackmagic everytime the interface goes up

cat << EOF > /etc/systemd/system/ynh-extraeth.service
[Unit]
Description=Extra ethernet port going through VPN
Requires=network.target ifup@$IFACENAME.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/ynh-extraeth start
RemainAfterExit=no

[Install]
WantedBy=ifup@$IFACENAME.service
EOF

systemctl daemon-reload
systemctl enable ynh-extraeth

# And also everytime we reload yunohost firewall

mkdir /etc/yunohost/hooks.d
mkdir /etc/yunohost/hooks.d/post_iptable_rules
cat << EOF > /etc/yunohost/hooks.d/post_iptable_rules/99-extraeth
#!/bin/bash

if ip a | grep -q "$IFACENAME:"
then
    systemctl start ynh-extraeth
fi
EOF
