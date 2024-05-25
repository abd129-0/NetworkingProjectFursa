#!/bin/bash

# Function to display error messages and exit
exit_with_error() {
    echo "$1"
    exit "$2"
}

# Function to perform client hello step
client_hello() {
    local server_ip="$1"

    echo "Step 1: Sending Client Hello Message"

    # Send client hello message
    curl -s -X POST -H "Content-Type: application/json" \
        -d '{"version": "1.3", "ciphersSuites": ["TLS_AES_128_GCM_SHA256", "TLS_CHACHA20_POLY1305_SHA256"], "message": "Client Hello"}' \
        "http://$server_ip:8080/clienthello" >res

    # Check if server certificate is valid
    if [ $? -ne 0 ]; then
        exit_with_error "Server Certificate is invalid." 5
    fi

    # Extract server certificate and session ID
    jq -r '.serverCert' res >cert.pem
    session_id=$(jq -r '.sessionID' res)
    rm res

    echo "Step 2: Client Hello Message Sent and Server Response Received"
}

# Function to perform server certificate verification
server_cert_verification() {
    echo "Step 3: Verifying Server Certificate"

    # Download server CA certificate
    wget "https://alonitac.github.io/DevOpsTheHardWay/networking_project/cert-ca-aws.pem"

    # Check if certificate download was successful
    if [ $? -ne 0 ]; then
        exit_with_error "Server Certificate is invalid." 5
    fi

    # Verify server certificate
    openssl verify -CAfile cert-ca-aws.pem cert.pem

    # Check if certificate verification was successful
    if [ $? -ne 0 ]; then
        exit_with_error "Server Certificate is invalid." 5
    fi

    # Clean up downloaded CA certificate
    rm cert-ca-aws.pem

    echo "Step 3: Server Certificate Verified"
}

# Function to perform client-server master-key exchange
client_server_key_exchange() {
    echo "Step 4: Generating Master Key"

    # Generate master key
    openssl rand -base64 32 >master-key
    master_key=$(cat master-key)

    # Encrypt master key with server certificate
    master_key_enc=$(openssl smime -encrypt -aes-256-cbc -in master-key -outform DER cert.pem | base64 -w 0)
    rm cert.pem
    rm master-key

    # Prepare request body for master key exchange
    sample_message_sent="Hi server, please encrypt me and send to client!"
    body="{\"sessionID\": \"$session_id\",\"masterKey\": \"$master_key_enc\",\"sampleMessage\": \"$sample_message_sent\"}"

    echo "Step 5: Sending Master Key to Server and Receiving Response"

    # Send master key to server and receive response
    sample_message_rec=$(curl -s -X POST -H "Content-Type: application/json" -d "$body" "$1:8080/keyexchange" | jq -r '.encryptedSampleMessage')

    # Decrypt received message using master key
    decrypt_message=$(echo "$sample_message_rec" | base64 -d | openssl enc -d -aes-256-cbc -pbkdf2 -k "$master_key")

    echo "Step 6: Master Key Exchange Completed"
}

# Function to perform client verification message
client_verification_message() {
    echo "Step 7: Verifying Client Message"

    # Verify if decrypted message matches the sample message sent
    if [[ "$decrypt_message" == "$sample_message_sent" ]]; then
        echo "Client-Server TLS handshake has been completed successfully"
    else
        exit_with_error "Server symmetric encryption using the exchanged master-key has failed." 6
    fi
}

# Main script
if [ $# -ne 1 ]; then
    exit_with_error "Please add the server ip as argument" 1
fi

client_hello "$1"
server_cert_verification
client_server_key_exchange "$1"
client_verification_message
