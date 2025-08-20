#!/bin/bash
# servers_info.sh - Collect detailed server information daily
# Author: Shenhav_Hezi
# Version: 1.0
# Description:
#   Gathers system, hardware, network, storage, and security information
#   for auditing and troubleshooting across distributed Linux systems.
#   Saves output to LOGDIR with hostname and date.

# Configuration
LOGDIR="/var/log/server_info"
DATE=$(date +%Y-%m-%d)
HOST=$(hostname -s)
LOGFILE="$LOGDIR/${HOST}_info_${DATE}.log"

mkdir -p "$LOGDIR"

exec > >(tee -a "$LOGFILE") 2>&1

echo "===== Server Info Report - $HOST - $DATE ====="
echo

### 1. General System Info
echo ">>> GENERAL SYSTEM INFO"
hostnamectl
uptime
echo

### 2. CPU & Memory
echo ">>> CPU & MEMORY"
lscpu | egrep 'Model name|Socket|CPU\(s\)'
free -h
echo "Load Average: $(cat /proc/loadavg)"
echo

### 3. Disk & Filesystems
echo ">>> DISK & FILESYSTEMS"
df -hT
lsblk
mount | grep "^/"
echo

### 4. Volume Groups & LVM
echo ">>> LVM CONFIGURATION"
vgs 2>/dev/null || echo "No volume groups"
lvs 2>/dev/null || echo "No logical volumes"
pvs 2>/dev/null || echo "No physical volumes"
echo

### 5. RAID / Multipath
echo ">>> RAID / MULTIPATH"
cat /proc/mdstat 2>/dev/null || echo "No RAID configured"
multipath -ll 2>/dev/null || echo "No multipath devices"
echo

### 6. Network Info
echo ">>> NETWORK CONFIGURATION"
ip a
ip route
ss -tulnp
echo

### 7. Users & Access
echo ">>> USERS & ACCESS"
who
last -n 10
getent group sudo || getent group wheel
echo

### 8. Services & Processes
echo ">>> RUNNING SERVICES & PROCESSES"
systemctl list-units --type=service --state=running
echo
echo "Top 10 processes by memory:"
ps aux --sort=-%mem | head -n 11
echo
echo "Top 10 processes by CPU:"
ps aux --sort=-%cpu | head -n 11
echo

### 9. Security & Configurations
echo ">>> SECURITY CONFIGURATION"
(iptables -L -n 2>/dev/null || firewall-cmd --list-all 2>/dev/null) || echo "No firewall detected"
sestatus 2>/dev/null || echo "SELinux not installed/enabled"
echo

### 10. Packages & Updates
echo ">>> PACKAGE STATUS"
if command -v apt &>/dev/null; then
    apt list --upgradable 2>/dev/null | grep -v Listing
elif command -v yum &>/dev/null; then
    yum check-update || true
fi
echo

echo "===== End of Report for $HOST ====="
