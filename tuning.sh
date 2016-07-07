#!/bin/bash

# Run as root

# increase TCP max buffer size setable using setsockopt()
# allow testing with 256MB buffers
sysctl -w net.core.rmem_max=268435456
sysctl -w net.core.wmem_max=268435456

# increase Linux autotuning TCP buffer limits
# min, default, and max number of bytes to use
# allow auto-tuning up to 128MB buffers
sysctl -w net.ipv4.tcp_rmem='4096 87380 134217728'
sysctl -w net.ipv4.tcp_wmem='4096 65536 134217728'

# recommended to increase this for 10G NICS or higher
sysctl -w net.core.netdev_max_backlog=250000

# don't cache ssthresh from previous connection
sysctl -w net.ipv4.tcp_no_metrics_save=1

# Explicitly set htcp as the congestion control: cubic buggy in older 2.6 kernels
sysctl -w net.ipv4.tcp_congestion_control=htcp

# If you are using Jumbo Frames, also set this
sysctl -w net.ipv4.tcp_mtu_probing=1

# increase txqueuelen for 10G NICS
/sbin/ifconfig eth5 txqueuelen 10000

tc qdisc add dev eth5 root fq