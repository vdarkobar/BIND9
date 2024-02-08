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

# Prepare File 1
FILENAME1="named.conf.logging"

# Destination folder (use absolute or relative path)
DESTINATION="/etc/bind/"

# Check if the file exists in the current directory
if [ -f "$FILENAME1" ]; then
    # Check if the destination folder exists
    if [ -d "$DESTINATION" ]; then
        # Copy the file to the destination folder
        sudo cp "$FILENAME1" "$DESTINATION"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}File '$FILENAME1' has been successfully copied to '$DESTINATION'.${NC}"
        else
            echo -e "${RED}Failed to copy the file to '$DESTINATION'.${NC}"
        fi
    else
        echo -e "${RED}Destination folder '$DESTINATION' does not exist.${NC}"
    fi
else
    echo -e "${RED}File '$FILENAME1' does not exist in the current directory.${NC}"
fi

# Define the file and the line to append
FILE="/etc/bind/named.conf"
LINE='include "/etc/bind/named.conf.logging";'

# Check if the line already exists in the file
if grep -Fq "$LINE" "$FILE"; then
    echo -e "${GREEN}The specified line already exists in $FILE${NC}"
else
    # Append the line to the file
    echo "$LINE" | sudo tee -a "$FILE" > /dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Line successfully appended to $FILE${NC}"
    else
        echo -e "${RED}Failed to append the line to $FILE${NC}"
    fi
fi

########################################################################

# Prepare File 2
FILENAME2="named.conf.options"

# Destination folder (use absolute or relative path)
DESTINATION="/etc/bind/"

# Check if the file exists in the current directory
if [ -f "$FILENAME2" ]; then
    # Check if the destination folder exists
    if [ -d "$DESTINATION" ]; then
        # Copy the file to the destination folder
        sudo cp "$FILENAME2" "$DESTINATION"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}File '$FILENAME2' has been successfully copied to '$DESTINATION'.${NC}"
        else
            echo -e "${RED}Failed to copy the file to '$DESTINATION'.${NC}"
        fi
    else
        echo -e "${RED}Destination folder '$DESTINATION' does not exist.${NC}"
    fi
else
    echo -e "${RED}File '$FILENAME2' does not exist in the current directory.${NC}"
fi

# Define the file path
FILE="/etc/bind/named.conf.options"

# Identify the host's primary IP address
HOST_IP=$(hostname -I | awk '{print $1}')

# Prompt user for input

# Initialize input flag
VALID_INPUT=0

while [[ $VALID_INPUT -eq 0 ]]; do
    # Prompt user for input
    echo "Enter one or more subnets as trusted clients, format 192.168.1.0/24, comma-separated:"
    read -r INPUT_SUBNETS

    # Check for empty input
    if [[ -z "$INPUT_SUBNETS" ]]; then
        echo "No input provided. Please enter one or more subnets."
        continue # Prompt again
    fi

    # Assume input is valid initially
    VALID_INPUT=1

    # Validate each subnet format
    IFS=',' read -r -a SUBNET_ARRAY <<< "$INPUT_SUBNETS"
    for SUBNET in "${SUBNET_ARRAY[@]}"; do
        TRIMMED_SUBNET=$(echo "$SUBNET" | xargs) # Trim whitespace
        if ! [[ $TRIMMED_SUBNET =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
            echo "Error: '$TRIMMED_SUBNET' is not a valid subnet format."
            VALID_INPUT=0
            break # Exit the for loop, invalid input found
        fi
    done
done

FORMATTED_SUBNETS=""
for SUBNET in "${SUBNET_ARRAY[@]}"; do
    TRIMMED_SUBNET=$(echo "$SUBNET" | xargs) # Trim whitespace
    FORMATTED_SUBNETS+="\t$TRIMMED_SUBNET;\n"
done

# Replace HOST_IP with the actual host IP address
sudo sed -i "s/HOST_IP/$HOST_IP/" "$FILE"
echo "Host IP address in $FILE updated"

# Check if acl trustedclients exists
if grep -q "acl trustedclients" "$FILE"; then
    # Use awk to replace the block
    awk -v subnet_list="$FORMATTED_SUBNETS" '
    /acl trustedclients {/,/};/ {
        if (!done) {
            print "acl trustedclients {";
            print subnet_list;
            print "};";
            done=1;
        }
        next;
    } 1' "$FILE" > tmpfile && sudo mv tmpfile "$FILE"
    echo "Trusted clients in $FILE updated"
else
    echo "acl trustedclients block not found. Please check $FILE."
fi

########################################################################

# Prepare File 23
FILENAME3="named.conf.local"

# Destination folder (use absolute or relative path)
DESTINATION="/etc/bind/"

# Check if the file exists in the current directory
if [ -f "$FILENAME3" ]; then
    # Check if the destination folder exists
    if [ -d "$DESTINATION" ]; then
        # Copy the file to the destination folder
        sudo cp "$FILENAME3" "$DESTINATION"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}File '$FILENAME3' has been successfully copied to '$DESTINATION'.${NC}"
        else
            echo -e "${RED}Failed to copy the file to '$DESTINATION'.${NC}"
        fi
    else
        echo -e "${RED}Destination folder '$DESTINATION' does not exist.${NC}"
    fi
else
    echo -e "${RED}File '$FILENAME3' does not exist in the current directory.${NC}"
fi

# Define the file path
FILE="/etc/bind/named.conf.local"

# Extract the domain name from /etc/resolv.conf
DOMAIN_NAME=$(grep '^domain' /etc/resolv.conf | awk '{print $2}')

# Use sed to replace DOMAIN_NAME with the actual domain name in the configuration file
sudo sed -i "s/DOMAIN_NAME/$DOMAIN_NAME/g" $FILE

# Prompt the user for the Slave DNS Server IP address and validate input
while true; do
    read -p "Enter Slave DNS Server IP Address: " SLAVE_IP
    if [[ -z "$SLAVE_IP" ]]; then
        echo "Input cannot be blank. Please enter a valid IP address."
    elif ! [[ $SLAVE_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Invalid IP address format. Please enter a valid IP address."
    else
        break
    fi
done

# Use sed to replace placeholders in the file
sudo sed -i "s/SLAVE_IP/$SLAVE_IP/g" $FILE

# Path to the input and output files
options_file="/etc/bind/named.conf.options"
local_file="/etc/bind/named.conf.local"

# Placeholder for the actual slave DNS server IP
slave_ip=$SLAVE_IP

# Ensure the script is run as root
#if [[ $EUID -ne 0 ]]; then
#   echo "This script must be run as root" 
#   exit 1
#fi

# Extract subnets from the acl trustedclients block
subnets=$(awk '/acl trustedclients {/,/};/' $options_file | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/[0-9]\{1,2\}')

# Check if we have the # Declaring reverse zones comment, if not, append it
if ! grep -q "# Declaring reverse zones" $local_file; then
    echo -e "\n# Declaring reverse zones" | sudo tee -a $local_file > /dev/null
fi

# Write each subnet as a reverse zone declaration
while read -r subnet; do
    # Reverse the IP and remove the subnet mask
    rev_ip=$(echo $subnet | cut -d'/' -f1 | awk -F. '{print $3"."$2"."$1}')
    
    # Create the reverse zone declaration
    zone_declaration="zone \"${rev_ip}.in-addr.arpa\" {\n\ttype master;\n\tfile \"/etc/bind/zones/db.${rev_ip}\";\n\tallow-transfer { $slave_ip; };\n};\n"

    # Append the declaration to the local file using tee with append mode
    echo -e "$zone_declaration" | sudo tee -a $local_file > /dev/null
done <<< "$subnets"

echo "Reverse DNS zones have been added to $local_file."

########################################################################

# Prompt user for reboot confirmation
while true; do
    read -p "Do you want to reboot the server? (yes/no): " response
    case "${response,,}" in
        yes|y) echo -e "Rebooting the server...${NC}"; sudo reboot; break ;;
        no|n) echo -e "${RED}Reboot cancelled.${NC}"; exit 0 ;;
        *) echo -e "${YELLOW}Invalid response. Please answer${NC} yes or no." ;;
    esac
done
