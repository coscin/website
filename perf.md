---
layout: main
title: Performance Testing
---

For testing performance, we leave the host coscin-host-ithaca1 fixed while moving the 
host coscintest-host-nyc1 (called the Test Box, since the IP address varies and we 
therefore we can't give it a permanent host name) at various points on the NYC side.  

The Test Box runs Ubuntu Server 14.04 LTS.  There are 4 Gigabit Ethernet copper interfaces on the Test box, generally assigned 
`eth0-eth3`.  Two Ten-Gigabit interfaces are named `eth4` and `eth5`.  Traditionally, we
plug the management network into `eth0` or `eth4`, and use `eth5` for the actual 
performance testing.

Changing the IP address is done in `/etc/network/interfaces`.  Currently the setup
for the Test Box at Cornell Tech is:

```
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
#auto eth0
#iface eth0 inet dhcp
auto eth0
iface eth0 inet static
  address 128.253.80.134/26
  gateway 128.253.80.129

# Don't enable IP on eth1.  It will be sending utilization packets
auto eth1
iface eth1 inet manual
  pre-up ifconfig $IFACE up
  pre-down ifconfig $IFACE down

auto eth5
iface eth5 inet static
# address 192.168.57.100/24
  address 128.253.80.133/26
  gateway 128.253.80.129
```

Change the management interfaces on `eth0` (or move it to `eth4` if you wish) by changing the
address and gateway lines for `eth0`.  Then do the same for the production data network on
`eth5`.

By default, Internet traffic will go over the default route using the lowest numbered 
Ethernet interface, which will be the management NIC.  That's fine, except you want CoSciN
traffic to go over `eth5`.  To do so, add a route for the Ithaca side of the CoSciN net:

```
sudo ip route add 132.236.137.96/27 via GATEWAY dev eth5 src NEWIP
```

Where `GATEWAY` and `NEWIP` are the values you used in the `gateway` and `address` lines for 
`eth5` in the `interfaces` file.  

You also need to set up the correct route on coscin-host-ithaca so it goes over the 10GB interface
as well.  

```
sudo ip route add NEWNET via 132.236.137.97 dev eth5 src 132.236.137.98
```

Where `NEWNET` is the network that the `NEWIP` is on (the network of the test box).  

To make sure you have connectivity, ping both sides of the network - in the above case, ping 
`NEWIP` from the Ithaca host and 132.236.137.98 from the Test box.  It generally takes a minute
or two for the pings to actually work, and it tends to work best when you send it from both sides
at about the same time.  (This is really coincidence, but it generally seeds the ARP caches 
at the right time.)

Finally, to perform the actual test, do this on coscin-host-ithaca1:

```
iperf3 -s
```

And this on the test box:

```
iperf3 -c 132.236.137.98
```

If you get bandwidth over 1 Gbit/sec, you pretty much know everything is configured correctly.  If
it's less then 1 Gbit/sec, make sure the traffic is going over the right interfaces.  On 
both sides of the network, use `ifconfig` to verify the TX and RX packets of `eth5` are 
increasing after an iperf3 test.  If they are, the numbers you are seeing are correct.

### Turning SDN On and Off

These notes are for internal use.  For performance testing, we've been leaving SDN off by 
running the HP switches in traditional mode.  (Actually we leave OpenFlow on, we just
move all the ports to a VLAN which doesn't use OpenFlow.)

To turn SDN back on: 

* Login to coscin-sw-ithaca
  * config 
  * vlan 1
  * untagged a1-a8,b1-b8
  * vlan 10
  * no untagged a1-a8,b1-b8
  * write memory

Do the same on coscin-sw-nyc

Turn on controller software

* Login to coscin-ctrl-ithaca1
  * sudo service coscin-app-ryu start
  * Review /var/log/upstart/coscin-app-ryu and make sure there are some "Learned" messages - it may take a few minutes. 

Do the same for coscin-ctrl-nyc1

To turn it off,just reverse the steps above (move ports back to vlan 10, then stop the coscin-app-ryu service on the controllers)


