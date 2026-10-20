#!/bin/bash
# Creates a self-signed code signing certificate ("MacZones Dev") in the login keychain.
# Signing with a stable identity keeps the Accessibility permission across rebuilds.
set -euo pipefail

NAME="MacZones Dev"
if security find-certificate -c "$NAME" >/dev/null 2>&1; then
    echo "Certificate '$NAME' already exists"
    exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/cert.cnf" <<CNF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
CNF

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/cert.cnf" 2>/dev/null
openssl pkcs12 -export -legacy -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -out "$TMP/cert.p12" -passout pass:maczones 2>/dev/null \
  || openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -out "$TMP/cert.p12" -passout pass:maczones

security import "$TMP/cert.p12" -k "$HOME/Library/Keychains/login.keychain-db" \
    -P maczones -T /usr/bin/codesign
echo "Created certificate '$NAME'"
