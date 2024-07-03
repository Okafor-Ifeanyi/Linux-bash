#!/bin/bash

# Define directories and files
SECURE_DIR="/var/secure"
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="$SECURE_DIR/user_passwords.txt"

# Ensure secure directory for storing passwords
sudo mkdir -p $SECURE_DIR
sudo chmod 700 $SECURE_DIR
sudo touch $PASSWORD_FILE
sudo chmod 600 $PASSWORD_FILE

# Ensure log file exists
sudo touch $LOG_FILE
sudo chmod 644 $LOG_FILE

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a $LOG_FILE
}

# Function to generate random password
generate_password() {
    echo $(openssl rand -base64 12)
}

# Read the input file
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <user_list_file>"
    exit 1
fi

USER_LIST_FILE=$1

while IFS=';' read -r username groups; do
    username=$(echo $username | xargs)
    groups=$(echo $groups | xargs)

    # Create user if it doesn't exist
    if id "$username" &>/dev/null; then
        log "User $username already exists"
    else
        password=$(generate_password)
        sudo useradd -m -s /bin/bash "$username"
        echo "$username:$password" | sudo chpasswd
        log "Created user $username"

        # Store password securely
        echo "$username,$password" | sudo tee -a $PASSWORD_FILE

        # Create a personal group for the user
        if ! getent group "$username" &>/dev/null; then
            sudo groupadd "$username"
        fi
        sudo usermod -aG "$username" "$username"
        log "Created personal group $username and added user to it"

        # Add user to specified groups
        IFS=',' read -ra ADDR <<< "$groups"
        for group in "${ADDR[@]}"; do
            if ! getent group "$group" &>/dev/null; then
                sudo groupadd "$group"
                log "Created group $group"
            fi
            sudo usermod -aG "$group" "$username"
            log "Added user $username to group $group"
        done
    fi
done < "$USER_LIST_FILE"
