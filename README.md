
This will configure a DHCP client + iptable MASQUERADE to pipe network into an other interface

So typically you want the USB ethernet adapter to be bridged to the tun0 / VPN interface

This should probably turned into an app (and fixed by people who actually understand network), **this is mainly a POC !**

You need to tune the parameters at the top of the file before running it.


