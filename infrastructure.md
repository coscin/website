---
layout: main
title: Infrastructure
---

## Creating a Controller

> Note: Yahoo-supplied 1U servers work fine as controllers.  If you use one, make sure you disable the IPMI 
Watchdog timer in BIOS.  Otherwise your server will spontaneously reboot in the middle of installation or running (and
it's really confusing to debug!)

1. Install Ubuntu Server 14.04 from a USB stick.  There is an Ubuntu 14.04 USB stick expressly for this purpose. 
Accept the defaults, except be sure to install OpenSSH Server when prompted.  (If you forget, you can 
always install the APT package "openssh-server" in step 2 below.)

2.  Make sure the IP address is properly set statically (/etc/network/interfaces) or by DHCP.  CIT and Weill
Medical Network staffs control the production IP addresses.  For the test network in Gates, Emin Gun-Sirer 
(egs@systems.cs.cornell.edu) is the administrator of DHCP-supplied IP addresses in the SysLab, and this is the 
preferred method of configuration for "permanent" hosted machines.  Either way, you want to make sure the
IP is more-or-less permanently leased, since the switches depend on communicating with controllers at a 
particular address.

3.  Install supporting software

        you@coscin-ctrl-timbuktu ~$ sudo apt-get update
        you@coscin-ctrl-timbuktu ~$ sudo apt-get install python-pip python-dev git

4.  If this will be a zookeeper node, install zookeeper as a daemon (generally only one controller host per switch needs
to run Zookeeper).

        you@coscin-ctrl-timbuktu ~$ sudo apt-get install zookeeperd

5.  Install Python packages.  You can ignore warnings when installing the `six` package.  

        you@coscin-ctrl-timbuktu$ sudo pip install ryu kazoo
        you@coscin-ctrl-timbuktu$ sudo pip install six --upgrade

6.  Add a `frenetic` user to run the controller software:

        you@coscin-ctrl-timbuktu ~$ sudo adduser frenetic

7.  Install the Coscin Controller software under the `frenetic` user

        you@coscin-ctrl-timbuktu ~$ sudo -i -u frenetic
        frenetic@coscin-ctrl-timbuktu ~$ mkdir src
        frenetic@coscin-ctrl-timbuktu ~$ cd src
        frenetic@coscin-ctrl-timbuktu ~/src$ git clone https://github.com/coscin/coscin-app-ryu
        frenetic@coscin-ctrl-timbuktu ~/src$ exit

8.  Install the Upstart script for coscin-app-ryu

        you@coscin-ctrl-timbuktu ~$ sudo install ~frenetic/src/coscin-app-ryu/coscin-app-ryu.conf /etc/init

    The coscin-app-ryu.conf file is configured to use `~frenetic/src/coscin-app-ryu/coscin_gates_testbed.json` as its
    configuration file.  If you want to use another configuration file, like `coscin_production.json`, you can change
    it in this file (e.g. `sudo nano /etc/init/coscin-app-ryu.conf`)

9.  Make sure the Coscin configuration file is correct.  See the next section for details.  

9.  Start up the controller.  

        you@coscin-ctrl-timbuktu ~$ sudo service coscin-app-ryu start

10.  Check the log file `/var/log/upstart/coscin-app-ryu.log` for problems.  Common ones are:

     * The controller host name is not present in the configuration file.  In that case, you'll get the following:

        `2016-03-16 10:34:17.106 ERROR CoscinApp The hostname coscintest-ctrl-nyc1 is not present in a controller_hosts attribute for the switch in coscin_gates_testbed.json`

     * You're not getting a backup controller message.  

        `2016-03-16 10:38:11.488 INFO CoscinApp Switch 378372418241536 says hello.`

     That means your switch is not communcating to this controller.
     On an HP 5406l switch, you want to make sure the running configuration has the proper controller IP address
     recorded.  

     * The controller software is waiting as a backup controller.  

       `2016-03-16 10:38:11.489 INFO CoscinApp Beginning in backup controller state.  If there's a working primary controller, we'll wait here`

     That means there's another controller online and
     it's the master.  That's fine.  If you want to test this for backup status, you can shut down the coscin-app-ryu
     service on the master controller.
     The coscin-app-ryu controller on this machine should be promoted to master shortly afterward (courtesy of
     Zookeeper).  

     * If you get:

       `2016-03-16 10:41:26.506 INFO CoscinApp Connected to Switch: UKNOWN`

      that usually means the switch is communicating a DPID (datapath ID, usuaully
     the Mac address prepended with an OpenFlow slice identifier).  In this case, you should see the DPID line:

       `2016-03-16 10:38:11.488 INFO CoscinApp Switch 378372418241536 says hello.`

     a few log messages above.  Check your configuration file to make sure the proper DPID is listed.

### The CoSciN Configuration File

The CoSciN controller reads its configuration from a JSON-formatted file. Here's the one used for the Gates hall Testbed,
`coscin_gates_testbed.json`:

    {
      "ip_rewrites": true,
      "ithaca": {
        "dpid": 378372418415616,
        "network": "192.168.56.0/24",
        "vlan": 1,
        "controller_hosts": ["coscintest-ctrl-ithaca1", "coscintest-ctrl-ithaca2"],
        "zookeeper": "coscintest-ctrl-ithaca1:2181"
      },
      "nyc": {
        "dpid": 378372418241536,
        "network": "192.168.57.0/24",
        "vlan": 1,
        "controller_hosts": ["coscintest-ctrl-nyc1", "coscintest-ctrl-nyc2"],
        "zookeeper": "coscintest-ctrl-nyc1:2181"
      },
      "alternate_paths": [
        { "ithaca": "192.168.156.0/24", "nyc": "192.168.157.0/24" },
        { "ithaca": "192.168.158.0/24", "nyc": "192.168.159.0/24" },
        { "ithaca": "192.168.160.0/24", "nyc": "192.168.161.0/24" }
      ]
    }

There are two "sides" to the CoSciN network labelled `ithaca` and `nyc` (although in the Gates testbed, both of these
sides are in Gates 440).  The parameters are:

* `ip_rewrites` turns IP rewriting on or off.  The default is on.  If IP rewriting is turned off, the `alternate_paths` below
will be ignored, and packets will go over the default route from ithaca to nyc and back.  This makes the switch operation
slightly faster, but turns off all the nice path rerouting stuff that CoSciN makes available.   

* `dpid` gives the datapath ID for the switch.  Every switch has a different one, usually composed of the switches MAC 
address prepended with an OpenFlow slice ID.  Since the number here needs to be decimal, it's usually easiest to bring
up the controller, which will report the DPID in the log as an integer.  The controller itself will error out if the
dpid in the configu file doesn't match.  But you can then copy-and-paste the DPID from the log to the config file and restart it.

* `network` is the real network continaing the measurement server and hosts in CIDR format. 

* `vlan` is the VLAN id of the OpenFlow slice on the switch.  Usually we use 1 because it's the default.

* `controller_hosts` is an array of all the controller names for this side of the network.  One of these should match the
hostname recorded in /etc/hostname on Ubuntu.  (DNS names may be different, but these aren't consulted here).

* `zookeeper` is the DNS host name and port for the Zookeeper server.  There is only one per side.  Default port here is 2181,
and the host name should be pingable from all controllers (so it should be in DNS, or in every hosts' /etc/hosts file).

* The `alternate_paths` structure defines imaginary networks that will define the route.  There may be one or more here.

> Note: The subnet sizes for each network and alternate paths _for the same side of the network_ must match.  However, the subnet
sizes can differ _between_ the sides - you can have 1024 hosts on the Ithaca side and 2 on the NYC side and things will be
just fine.  But all the Ithaca subnet sizes should be 1024 in this case.  

## Creating an SDM (Software Defined Measurement) Host

There's one host on each side of the CoSciN network responsible for measurements.  They wake up once per period, measure
response times across all three networks, then report their results via a specially-formatted packet to the switch.
These hosts are not critical to network operations - if they're not running, CoSciN just routes packets along
the default path.   But they both need to be running to make the measurements work.

1. Install Ubuntu Server 14.04 from a USB stick.  There is an Ubuntu 14.04 USB stick expressly for this purpose. 
Accept the defaults, except be sure to install OpenSSH Server when prompted.  (If you forget, you can 
always install the APT package "openssh-server" in step 3 below.)

1. The host requires two NICs, one for doing the actual measurements, and one (eth1) for reporting the results.  The first
NIC should have an IP address assigned to it (through DHCP or statically).  The second should not.  That's because if
the second NIC sends any IP packets, the switch will consider that a host, learn its IP, and handle all the traffic in
the switch.  Measurement reporting packets have a special non-IP Ethernet type, and must all got the controller.  To
configure a non-IP NIC in Ubuntu, include the following in `/etc/network/interfaces`:

        # Don't enable IP on eth1.  It will be sending utilization packets
        auto eth1
        iface eth1 inet manual
          pre-up ifconfig $IFACE up
          pre-down ifconfig $IFACE down

3.  Install supporting software

        you@coscin-host-timbuktu ~$ sudo apt-get update
        you@coscin-host-timbuktu ~$ sudo apt-get install python-pip python-dev git

5.  Install Python packages. 

        you@coscin-host-timbuktu$ sudo pip install scapy

6.  Add a `coscin` user to run the controller software:

        you@coscin-host-timbuktu ~$ sudo adduser coscin

7.  Install the Coscin Measurement software under the `coscin` user

        you@coscin-host-timbuktu ~$ sudo -i -u coscin
        coscin@coscin-host-timbuktu ~$ mkdir src
        coscin@coscin-host-timbuktu ~$ cd src
        coscin@coscin-host-timbuktu ~/src$ git clone https://github.com/coscin/sdm
        coscin@coscin-host-timbuktu ~/src$ exit

8.  Install the Upstart script for coscin-sdm

        you@coscin-host-timbuktu ~$ sudo install ~coscin/src/sdm/coscin-sdm.conf /etc/init

    The coscin-sdm.conf file is configured to use `~coscin/src/sdm/coscin_gates_testbed.json` as its
    configuration file, and assumes the host is on the Ithaca side.  
    If you want to use another configuration file, like `coscin_production.json`, or want to configure it
    for the NYC side of the network, you can change
    either of these in the file file (e.g. `sudo nano /etc/init/coscin-app-ryu.conf`)

9.  Make sure the SDM configuration file is correct.  See the next section for details.  

9.  Start up the controller.  

        you@coscin-host-timbuktu ~$ sudo service coscin-sdm start

10.  Check the log file `/var/log/upstart/coscin-sdm.log` for problems. 

### The SDM configuration file

There are a few configuration parameters in a JSON file:

    {
      "probe_interval": 60,
      "alternate_hosts": { 
        "ithaca": [ "192.168.157.100", "192.168.159.100", "192.168.161.100" ],
        "nyc": [ "192.168.156.100", "192.168.158.100", "192.168.160.100" ]
      }
    }

* `probe_interval` is the time between probes in seconds.  

* `alternate_hosts` is a lot like the `alternate_paths` attribute in the CoSciN controller configuration.  The three hosts
represent the three imaginary IPs for a host on the other side.  So in the above example, 192.168.157.100, 192.168.159.100
and 192.168.161.100 are actually the same host (192.168.57.100), but each takes a different alternate path.  The SDM 
program pings each in turn to measure response times.  

## Source Code

* The CoSciN Controller is in the [coscin/coscin-app-ryu](https://github.com/coscin/coscin-app-ryu) repositiory on GitHub.

* The SDM server is in the [coscin/sdm](https://github.com/coscin/sdm) repositiory on GitHub.
