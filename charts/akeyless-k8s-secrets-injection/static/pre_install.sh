#!/bin/sh
# This script generates the required certificates for akeyless-secret-injection
# Please run the script from the "static" folder and then deploy the manifest into k8s.

# Generate CA key
openssl genrsa -out ca.key 2048

# Generate CA certificate
openssl req -x509 -new -nodes -key ca.key -subj "/CN=akeyless-secrets-injection.akeyless.svc" -days 365 -out ca.crt

# Generate server key
openssl genrsa -out server.key 2048

# Create a CSR configuration file

cat > csr.conf << EOF
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[ dn ]
CN = akeyless-secrets-injection.akeyless.svc

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = akeyless-secrets-injection.akeyless.svc

[ v3_ext ]
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=CA:FALSE
keyUsage=keyEncipherment,dataEncipherment
extendedKeyUsage=serverAuth,clientAuth
subjectAltName=@alt_names
EOF

# Generate server key from csr
openssl req -new -key server.key -out server.csr -config csr.conf

# Generate server certificate
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365 -extensions v3_ext -extfile csr.conf

# convert certificates into base64
# replace server key and cert contant in  __servingKey__, __servingCert__ placeholders
# replace CA cert placeholders in both caCert secret and MutatingWebhookConfiguration caBundle fileds 
SERVER_KEY=$(cat server.key | base64)
SERVER_CERT=$(cat server.crt | base64)
CA_CERT=$(cat ca.crt | base64)
FILE_PATH="$PWD/deploy.yaml"

sed -i "s/__serverKey__/${SERVER_KEY}/" "${FILE_PATH}"
sed -i "s,__serverCert__,$SERVER_CERT," "${FILE_PATH}"
sed -i "s,__caCert__,$CA_CERT," "${FILE_PATH}"

# deploy manifest
# "kubectl apply -f deploy.yaml"