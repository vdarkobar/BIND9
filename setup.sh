#!/bin/bash

clear

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

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
    echo -e "${GREEN}Backup of /etc/hosts created.${NC}"
else
    echo -e "${GREEN}Backup of /etc/hosts already exists. Skipping backup.${NC}"
fi

# Backup original /etc/cloud/cloud.cfg file before modifications
CLOUD_CFG="/etc/cloud/cloud.cfg"
if [ ! -f "$CLOUD_CFG.bak" ]; then
    sudo cp "$CLOUD_CFG" "$CLOUD_CFG.bak"
    echo -e "${GREEN}Backup of $CLOUD_CFG created.${NC}"
else
    echo -e "${GREEN}Backup of $CLOUD_CFG already exists. Skipping backup.${NC}"
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
        echo -e "${GREEN}Backup of $file created.${NC}"
    else
        echo -e "${GREEN}Backup of $file already exists. Skipping backup.${NC}"
    fi
done

########################################################################

# Extract the domain name from /etc/resolv.conf
DOMAIN_NAME=$(grep '^domain' /etc/resolv.conf | awk '{print $2}')

# Check if DOMAIN_NAME has a value
if [ -z "$DOMAIN_NAME" ]; then
    echo "${RED}Could not determine the domain name from /etc/resolv.conf. Skipping operations that require the domain name.${NC}"
else
    # Continue with operations that require DOMAIN_NAME
    # Identify the host's primary IP address and hostname
    HOST_IP=$(hostname -I | awk '{print $1}')
    HOST_NAME=$(hostname)

    # Skip /etc/hosts update if HOST_IP or HOST_NAME are not determined
    if [ -z "$HOST_IP" ] || [ -z "$HOST_NAME" ]; then
        echo -e "${RED}Could not determine the host IP address or hostname. Skipping /etc/hosts update!!!${NC}"
    else
        # Display the extracted domain name, host IP, and hostname
        echo -e "${GREEN}Domain name: $DOMAIN_NAME${NC}"
        echo -e "${GREEN}Host IP: $HOST_IP${NC}"
        echo -e "${GREEN}Hostname: $HOST_NAME${NC}"

        # Remove any existing lines with the current hostname in /etc/hosts
        sudo sed -i "/$HOST_NAME/d" /etc/hosts

        # Append the new line in the specified format to /etc/hosts
        NEW_LINE="$HOST_IP\t$HOST_NAME $HOST_NAME.$DOMAIN_NAME"
        echo -e "$NEW_LINE" | sudo tee -a /etc/hosts > /dev/null

        echo -e "${GREEN}File /etc/hosts has been updated.${NC}"
    fi

    # Continue with any other operations that require DOMAIN_NAME
fi

########################################################################

# Define the file path
FILE_PATH="/etc/cloud/cloud.cfg"

# Comment out the specified modules
sudo sed -i '/^\s*- set_hostname/ s/^/#/' "$FILE_PATH"
sudo sed -i '/^\s*- update_hostname/ s/^/#/' "$FILE_PATH"
sudo sed -i '/^\s*- update_etc_hosts/ s/^/#/' "$FILE_PATH"

echo -e "${GREEN}Modifications to $FILE_PATH applied successfully.${NC}"

########################################################################

# Identify the host's primary IP address associated with the default route
#HOST_IP=$(ip route get 1.1.1.1 | grep -oP 'src \K\S+')
HOST_IP=$(hostname -I | awk '{print $1}')

# Display the identified IP address
echo -e "${GREEN}Host's primary IP address:${NC} $HOST_IP"

# Replace or append the nameserver line
if grep -q "^nameserver" /etc/resolv.conf; then
    # Replace existing nameserver line(s)
    sudo sed -i "/^nameserver/c\nameserver $HOST_IP" /etc/resolv.conf
    echo -e "${GREEN}Replaced existing nameserver line in /etc/resolv.conf.${NC}"
else
    # Append new nameserver line if not present
    echo "nameserver $HOST_IP" | sudo tee -a /etc/resolv.conf > /dev/null
    echo -e "${GREEN}Added nameserver line to /etc/resolv.conf.${NC}"
fi

echo -e "${GREEN}File /etc/resolv.conf has been updated.${NC}"

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

# Prompt user for reboot

while true; do
    read -p "Do you want to reboot the server? (yes/no): " response
    case "${response,,}" in
        yes|y) echo -e "Rebooting the server...${NC}"; sudo reboot; break ;;
        no|n) echo -e "${RED}Reboot cancelled.${NC}"; exit 0 ;;
        *) echo -e "${YELLOW}Invalid response. Please answer${NC} yes or no." ;;
    esac
done
