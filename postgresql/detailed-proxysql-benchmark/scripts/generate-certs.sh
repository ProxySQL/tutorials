#!/usr/bin/env bash
set -e

CERT_DIR="./certs"
mkdir -p "${CERT_DIR}"

echo "Generating CA..."
openssl genrsa -out "${CERT_DIR}/ca.key" 4096
openssl req -new -x509 -days 3650 -key "${CERT_DIR}/ca.key" -out "${CERT_DIR}/ca.crt" -subj "/CN=Benchmark-CA"

echo "Generating Server Certificate..."
openssl genrsa -out "${CERT_DIR}/server.key" 4096
openssl req -new -key "${CERT_DIR}/server.key" -out "${CERT_DIR}/server.csr" -subj "/CN=postgresql"
openssl x509 -req -in "${CERT_DIR}/server.csr" -CA "${CERT_DIR}/ca.crt" -CAkey "${CERT_DIR}/ca.key" -CAcreateserial -out "${CERT_DIR}/server.crt" -days 365

echo "Generating Client Certificate..."
openssl genrsa -out "${CERT_DIR}/client.key" 4096
openssl req -new -key "${CERT_DIR}/client.key" -out "${CERT_DIR}/client.csr" -subj "/CN=appuser"
openssl x509 -req -in "${CERT_DIR}/client.csr" -CA "${CERT_DIR}/ca.crt" -CAkey "${CERT_DIR}/ca.key" -CAcreateserial -out "${CERT_DIR}/client.crt" -days 365

echo "Organizing certs for PostgreSQL (UID 999) and PgBouncer (UID 70)..."
mkdir -p "${CERT_DIR}/postgres" "${CERT_DIR}/pgbouncer"

cp "${CERT_DIR}/ca.crt" "${CERT_DIR}/server.crt" "${CERT_DIR}/server.key" "${CERT_DIR}/postgres/"
cp "${CERT_DIR}/ca.crt" "${CERT_DIR}/server.crt" "${CERT_DIR}/server.key" "${CERT_DIR}/pgbouncer/"

# Fix permissions
chmod 0600 "${CERT_DIR}/postgres/server.key" "${CERT_DIR}/pgbouncer/server.key"
chmod 0644 "${CERT_DIR}/postgres/server.crt" "${CERT_DIR}/pgbouncer/server.crt"
chmod 0644 "${CERT_DIR}/postgres/ca.crt" "${CERT_DIR}/pgbouncer/ca.crt"

# Set ownership
docker run --rm -v "$(pwd)/${CERT_DIR}:/certs" alpine sh -c "chown -R 999:999 /certs/postgres && chown -R 70:70 /certs/pgbouncer"

echo "Certificates generated and organized for all services."
