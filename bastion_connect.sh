#!/bin/bash

# Check if the KEY_PATH environment variable is set
if [ -z "$KEY_PATH" ]; then
    echo "KEY_PATH env var is expected"
    exit 5
fi

# Check if at least one argument (the public instance IP) is provided
if [ $# -lt 1 ]; then
    echo "Please provide bastion IP address"
    exit 5
fi

# Extract the arguments
BASTION_IP=$1
PRIVATE_IP=$2
shift 2
COMMAND="$@"

# Define the path to the new key file on the bastion host
NEW_KEY_PATH_FILE="/home/ubuntu/keypair"

# Check if the new key file exists on the bastion host
ssh -i "$KEY_PATH" ubuntu@$BASTION_IP "test -f $NEW_KEY_PATH_FILE"
if [ $? -ne 0 ]; then
    echo "Failed to find the new key path file on the bastion host"
    exit 5
fi

# Determine which operation to perform
if [ -n "$PRIVATE_IP" ] && [ -n "$COMMAND" ]; then
    # Run a command on the private instance via the public instance and display the output
    ssh -t -i "$KEY_PATH" ubuntu@"$BASTION_IP" "ssh -i $NEW_KEY_PATH_FILE ubuntu@$PRIVATE_IP '$COMMAND'"
elif [ -n "$PRIVATE_IP" ]; then
    # Connect to the private instance via the public instance
    ssh -t -i "$KEY_PATH" ubuntu@"$BASTION_IP" "ssh -t -i $NEW_KEY_PATH_FILE ubuntu@$PRIVATE_IP"
else
    # Connect to the public instance
    ssh -t -i "$KEY_PATH" ubuntu@"$BASTION_IP"
fi
