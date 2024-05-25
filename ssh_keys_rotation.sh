#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 <private-instance-ip>"
    exit 1
}

# Function to check if the key file exists
check_key_file() {
    if [ ! -f "$KEY_PATH" ]; then
        echo "The key file at $KEY_PATH does not exist. Please check the path and try again."
        exit 2
    fi
}

# Function to test the key file connection to the private instance
test_key_connection() {
    echo "Testing if the key at $KEY_PATH can connect to the private instance..."
    if ! ssh -i "$KEY_PATH" -o "StrictHostKeyChecking=no" -o "BatchMode=yes" ubuntu@$PRIVATE_IP "exit"; then
        echo "The key at $KEY_PATH cannot connect to the private instance. Check the key and its permissions."
        exit 3
    fi
}

# Function to generate a new key pair
generate_new_key_pair() {
    ssh-keygen -t rsa -b 4096 -f $NEW_KEY_PATH -N "" -C "key_rotation"
}

# Function to append the new public key to the authorized_keys on the private instance
append_new_key_to_authorized_keys() {
    cat $NEW_KEY_PATH.pub | ssh -i "$KEY_PATH" ubuntu@$PRIVATE_IP "cat > ~/.ssh/authorized_keys"
}

# Function to replace the old key with the new key
replace_old_key() {
    sudo mv $NEW_KEY_PATH $KEY_PATH
    sudo rm $NEW_KEY_PATH.pub
}


# Function to set correct permissions for the new key
set_key_permissions() {
    sudo chmod 400 $KEY_PATH
}

# Function to complete key rotation and display the final message
complete_key_rotation() {
    echo "Key rotation complete. You can now connect with the new key using:"
    echo "ssh -i $KEY_PATH ubuntu@$PRIVATE_IP"
}

# Main script execution

# Ensure the script is executed with a private instance IP
if [ $# -ne 1 ]; then
    usage
fi

PRIVATE_IP=$1
KEY_PATH="/home/ubuntu/keypair"
NEW_KEY_PATH="/home/ubuntu/new_key"

# Check if the key file exists
check_key_file

# Test if the key at KEY_PATH can connect to the private instance
test_key_connection

# Generate a new key pair
generate_new_key_pair

# Replace the old key with the new key in the KEY_PATH
replace_old_key

# Set correct permissions for the new key at KEY_PATH
set_key_permissions

# Complete key rotation and display the final message
complete_key_rotation
