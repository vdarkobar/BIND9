#!/bin/bash

# Define the directory where zone files are located
ZONE_DIR="/etc/bind/zones"
# Default Time To Live for DNS records
DEFAULT_TTL="3600"

# List available zone files
echo "Available zones in $ZONE_DIR:"
ls $ZONE_DIR

# Prompt the user to enter the name of the zone to modify
echo "Enter the name of the zone to modify (without path):"
read ZONE_NAME
ZONE_FILE="$ZONE_DIR/$ZONE_NAME"

# Check if the selected zone file exists
if [ ! -f "$ZONE_FILE" ]; then
    echo "Error: Zone file does not exist."
    exit 1
fi

# List A records in the selected zone file
echo "Clients in the zone '$ZONE_NAME':"
grep -P 'IN\tA' "$ZONE_FILE" | awk '{print $1 " -> " $4}'

# Ask the user for the desired action (add or delete a DNS record)
echo "Do you want to 'add' or 'delete' a DNS record? Enter 'add' or 'delete':"
read ACTION

# Validate the user's action
if [[ "$ACTION" != "add" && "$ACTION" != "delete" ]]; then
    echo "Error: Invalid action. Please enter 'add' or 'delete'."
    exit 1
fi

# Backup the zone file before making changes
cp "$ZONE_FILE" "${ZONE_FILE}.backup"

if [ "$ACTION" == "add" ]; then
    echo "Adding a DNS record..."
    # Prompt for subnet, record name, record IP, and TTL
    echo "Enter the subnet (e.g., 192.168.1.0/24):"
    read SUBNET
    echo "Enter the record name:"
    read RECORD_NAME
    echo "Enter the record IP:"
    read RECORD_IP
    echo "Enter TTL (default $DEFAULT_TTL):"
    read TTL
    TTL="${TTL:-$DEFAULT_TTL}"  # Use default TTL if none specified

    # Validate the IP address format
    if ! [[ $RECORD_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: Invalid IP address format."
        exit 1
    fi

    # Determine where to add the new record based on the subnet
    if ! grep -q "; $SUBNET - A Records" "$ZONE_FILE"; then
        # If the subnet section does not exist, add it at the end of the file
        echo -e "\n; $SUBNET - A Records\n$RECORD_NAME\tIN\tA\t$RECORD_IP ;" >> "$ZONE_FILE"
    else
        # If the subnet section exists, add the record to this section
        sed -i "/; $SUBNET - A Records/a\\$RECORD_NAME\tIN\tA\t$RECORD_IP ;" "$ZONE_FILE"
    fi
elif [ "$ACTION" == "delete" ]; then
    echo "Deleting a DNS record..."
    # Prompt for the record name to delete
    echo "Enter the record name to delete:"
    read RECORD_NAME

    # Delete the record using sed
    sed -i "/$RECORD_NAME\tIN\tA/d" "$ZONE_FILE"
fi

# Update serial number
SERIAL=$(date +%Y%m%d%H)
sed -i "/Serial/,+1 s/[0-9]\{10\}/$SERIAL/" "$ZONE_FILE"

# Reload BIND9 to apply changes
if ! sudo rndc reload; then
    echo "Error: Failed to reload BIND9. Restoring from backup."
    cp "${ZONE_FILE}.backup" "$ZONE_FILE"
    exit 1
fi

echo "DNS record $ACTION successfully. BIND9 reloaded."

# Clean up the backup file after successful changes
rm -f "${ZONE_FILE}.backup"
