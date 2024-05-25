#!/bin/bash

# Function to display usage message
usage() {
    echo "Please provide bastion IP address"
    exit 5
}

# Function to generate a new SSH key pair
generate_ssh_key() {
    ssh-keygen -t rsa -b 4096 -N "" -f "/home/ubuntu/keypair_to_rotate"
}

# Function to copy new key to remote authorized_keys and manage local key files
rotate_ssh_key() {
    local bastion_ip=$1
    cat keypair_to_rotate.pub | ssh -i keypair ubuntu@$bastion_ip 'cat > .ssh/authorized_keys'
    chmod +w keypair
    cat keypair_to_rotate > keypair
    chmod 400 keypair
    rm keypair_to_rotate keypair_to_rotate.pub
}

# Function to print completion message
complete_key_rotation() {
    local key_path="/home/ubuntu/keypair"
    local private_ip=$1
    echo "Key rotation complete. You can now connect with the new key using:"
    echo "ssh -i $key_path ubuntu@$private_ip"
}

# Main script execution
main() {
    if [ "$#" -eq 0 ]; then
        usage
    elif [ "$#" -eq 1 ]; then
        generate_ssh_key
        rotate_ssh_key "$1"
        complete_key_rotation "$1"
    else
        usage
    fi
}

# Execute main function
main "$@"
