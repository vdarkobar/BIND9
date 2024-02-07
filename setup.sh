#!/bin/bash

# Install BIND9

if ! sudo apt -y install bind9 bind9-utils bind9-dnsutils bind9-doc; then
    echo "Failed to install BIND9 packages. Exiting."
    exit 1
fi

########################################################################

# Create backup files

# Backup the existing /etc/hosts file
if [ ! -f /etc/hosts.backup ]; then
    sudo cp /etc/hosts /etc/hosts.backup
    echo "Backup of /etc/hosts created."
else
    echo "Backup of /etc/hosts already exists. Skipping backup."
fi

# Backup original /etc/cloud/cloud.cfg file before modifications
CLOUD_CFG="/etc/cloud/cloud.cfg"
if [ ! -f "$CLOUD_CFG.bak" ]; then
    sudo cp "$CLOUD_CFG" "$CLOUD_CFG.bak"
    echo "Backup of $CLOUD_CFG created."
else
    echo "Backup of $CLOUD_CFG already exists. Skipping backup."
fi

# Before modifying BIND9 configuration files, create backups if they don't already exist

BIND9_FILES=(
    "/etc/default/named"
    "/etc/bind/named.conf"
    "/etc/bind/named.conf.local"
    "/etc/bind/named.conf.options"
)

for file in "${BIND9_FILES[@]}"; do
    if [ ! -f "$file.backup" ]; then
        sudo cp "$file" "$file.backup"
        echo "Backup of $file created."
    else
        echo "Backup of $file already exists. Skipping backup."
    fi
done

########################################################################

# Extract the domain name from /etc/resolv.conf
DOMAIN_NAME=$(grep '^domain' /etc/resolv.conf | awk '{print $2}')

# Check if DOMAIN_NAME has a value
if [ -z "$DOMAIN_NAME" ]; then
    echo "Could not determine the domain name from /etc/resolv.conf."
    exit 1
fi

# Identify the host's primary IP address and hostname
HOST_IP=$(hostname -I | awk '{print $1}')
HOST_NAME=$(hostname)

# Check for necessary values
if [ -z "$HOST_IP" ] || [ -z "$HOST_NAME" ]; then
    echo "Could not determine the host IP address or hostname."
    exit 1
fi

# Display the extracted domain name, host IP, and hostname
echo "Domain name: $DOMAIN_NAME"
echo "Host IP: $HOST_IP"
echo "Hostname: $HOST_NAME"

# Remove any existing lines with the current hostname in /etc/hosts
sudo sed -i "/$HOST_NAME/d" /etc/hosts

# Append the new line in the specified format to /etc/hosts
NEW_LINE="$HOST_IP\t$HOST_NAME $HOST_NAME.$DOMAIN_NAME"
echo -e "$NEW_LINE" | sudo tee -a /etc/hosts > /dev/null

echo "/etc/hosts has been updated."

########################################################################

# Define the file path
FILE_PATH="/etc/cloud/cloud.cfg"

# Comment out the specified modules
sudo sed -i '/^\s*- set_hostname/ s/^/#/' "$FILE_PATH"
sudo sed -i '/^\s*- update_hostname/ s/^/#/' "$FILE_PATH"
sudo sed -i '/^\s*- update_etc_hosts/ s/^/#/' "$FILE_PATH"

echo "Modifications applied successfully."

########################################################################

# Identify the host's primary IP address associated with the default route
#HOST_IP=$(ip route get 1.1.1.1 | grep -oP 'src \K\S+')
HOST_IP=$(hostname -I | awk '{print $1}')

# Display the identified IP address
echo "Host's primary IP address: $HOST_IP"

# Replace or append the nameserver line
if grep -q "^nameserver" /etc/resolv.conf; then
    # Replace existing nameserver line(s)
    sudo sed -i "/^nameserver/c\nameserver $HOST_IP" /etc/resolv.conf
    echo "Replaced existing nameserver line in /etc/resolv.conf."
else
    # Append new nameserver line if not present
    echo "nameserver $HOST_IP" | sudo tee -a /etc/resolv.conf > /dev/null
    echo "Added nameserver line to /etc/resolv.conf."
fi

echo "/etc/resolv.conf has been updated."

########################################################################

# Make the DNS configuration file immutable

sudo chattr +i /etc/resolv.conf

########################################################################

# Prepare firewall:

sudo ufw allow 53/tcp comment 'DNS port 53/tcp'
sudo ufw allow 53/udp comment 'DNS port 53/udp'

########################################################################

# Create necessary folders

sudo mkdir /etc/bind/zones
sudo mkdir /var/log/named
sudo chown bind:bind /var/log/named

########################################################################

# Prompt user for reboot confirmation

while true; do
    read -p "Do you want to reboot the server? (yes/no): " response
    case "${response,,}" in
        yes|y) echo "Rebooting the server..."; sudo reboot; break ;;
        no|n) echo "Reboot cancelled."; exit 0 ;;
        *) echo "Invalid response. Please answer yes or no." ;;
    esac
done
