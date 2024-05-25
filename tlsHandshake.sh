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
  curl -s -X POST -H "Content-Type: application/json" \
    -d '{"version": "1.3", "ciphersSuites": ["TLS_AES_128_GCM_SHA256", "TLS_CHACHA20_POLY1305_SHA256"], "message": "Client Hello"}' \
    "http://$server_ip:8080/clienthello" >res

  if [ $? -ne 0 ]; then
    exit_with_error "Server Certificate is invalid." 5
  fi

  jq -r '.serverCert' res >cert.pem
  session_id=$(jq -r '.sessionID' res)
  rm res
  echo "Step 2: Client Hello Message Sent and Server Response Received"
}

# Function to perform server certificate verification
server_cert_verification() {
  echo "Step 3: Verifying Server Certificate"
  wget "https://alonitac.github.io/DevOpsTheHardWay/networking_project/cert-ca-aws.pem"

  if [ $? -ne 0 ]; then
    exit_with_error "Server Certificate is invalid." 5
  fi

  openssl verify -CAfile cert-ca-aws.pem cert.pem

  if [ $? -ne 0 ]; then
    exit_with_error "Server Certificate is invalid." 5
  fi

  rm cert-ca-aws.pem
  echo "Step 3: Server Certificate Verified"
}

# Function to perform client-server master-key exchange
client_server_key_exchange() {
  echo "Step 4: Generating Master Key"
  openssl rand -base64 32 >master-key
  master_key=$(cat master-key)
  master_key_enc=$(openssl smime -encrypt -aes-256-cbc -in master-key -outform DER cert.pem | base64 -w 0)
  rm cert.pem
  rm master-key

  sample_message_sent="Hi server, please encrypt me and send to client!"
  body="{\"sessionID\": \"$session_id\",\"masterKey\": \"$master_key_enc\",\"sampleMessage\": \"$sample_message_sent\"}"

  echo "Step 5: Sending Master Key to Server and Receiving Response"
  sample_message_rec=$(curl -s -X POST -H "Content-Type: application/json" -d "$body" "$1:8080/keyexchange" | jq -r '.encryptedSampleMessage')

  decrypt_message=$(echo "$sample_message_rec" | base64 -d | openssl enc -d -aes-256-cbc -pbkdf2 -k "$master_key")
  echo "Step 6: Master Key Exchange Completed"
}

# Function to perform client verification message
client_verification_message() {
  echo "Step 7: Verifying Client Message"
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
