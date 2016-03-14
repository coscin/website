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

      ```
      you@coscin-ctrl-timbuktu ~$ sudo apt-get update
      you@coscin-ctrl-timbuktu ~$ sudo apt-get install python-pip python-dev git
      ```

4.  If this will be a zookeeper node, install zookeeper as a daemon (generally only one controller host per switch needs
to run Zookeeper).

    ```
    you@coscin-ctrl-timbuktu ~$ sudo apt-get install zookeeper zookeeperd
    ```

5.  Install Python packages.  You can ignore warnings when installing the `six` package.  

    ```
    you@coscin-ctrl-timbuktu$ sudo pip install ryu kazoo
    you@coscin-ctrl-timbuktu$ sudo pip install six --upgrade
    ```

6.  Add a `frenetic` user to run the controller software:

    ```
    you@coscin-ctrl-timbuktu ~$ sudo adduser frenetic
    ```

7.  Install the Coscin Controller software under the `frenetic` user

    ```
    you@coscin-ctrl-timbuktu ~$ sudo -i -u frenetic
    frenetic@coscin-ctrl-timbuktu ~$ mkdir src
    frenetic@coscin-ctrl-timbuktu ~$ cd src
    frenetic@coscin-ctrl-timbuktu ~/src$ git clone https://github.com/coscin/coscin-app-ryu
    frenetic@coscin-ctrl-timbuktu ~/src$ exit
    ```

8.  Install the Upstart script for coscin-app-ryu

    ```
    you@coscin-ctrl-timbuktu ~$ sudo install ~frenetic/src/coscin-app-ryu/coscin-app-ryu.conf /etc/init
    ```

    The coscin-app-ryu.conf file is configured to use `~frenetic/src/coscin-app-ryu/coscin_gates_testbed.conf` as its
    configuration file.  If you want to use another configuration file, like `coscin_production.conf`, you can change
    it in this file (e.g. `sudo nano /etc/init/coscin-app-ryu.conf`)

9.  Make sure the Coscin configuration file is correct.  See the next section for details.  

9.  Start up the controller.  

    ```
    you@coscin-ctrl-timbuktu ~$ sudo service coscin-app-ryu start
    ```

10.  Check the log file `/var/log/upstart/coscin-app-ryu.log` for problems.  Common ones are:

     * You're not getting a backup controller message.  That means your switch is not communcating to this controller.
     On an HP 5406l switch, you want to make sure the running configuration has the proper controller IP address
     recorded.  

     * The controller software is waiting as a backup controller.  That means there's another controller online and
     it's the master.  That's fine.  If you want to test this for backup status, you can shut down the controller.
     This one should immediately be promoted to master.  

     * If you get a "Index NONE Not found" that usually means the switch is communicating a DPID (datapath ID, usuaully
     the Mac address prepended with an OpenFlow slice identifier).  In this case, you should see the DPID line
     a few log messages above.  Check your configuration file to make sure the proper DPID is listed.

## The CoSciN Configuration File

The CoSciN controller reads its configuration from a JSON-formatted file. Here's the one used for the Gates hall Testbed:

```
{
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
```

There are two "sides" to the CoSciN network labelled `ithaca` and `nyc` (although in the Gates testbed, both of these
sides are in Gates 440).  The parameters are:

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
