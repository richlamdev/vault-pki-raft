#!/bin/bash

ADDRESS="http://127.0.0.1:8200"
CA="Lord of the Rings"

set -aex

# login/authenticate locally
vault login -address=$ADDRESS -tls-skip-verify $(cat root_token-vault_2)

# enable the PKI secrets engine
vault secrets enable -address=$ADDRESS -tls-skip-verify pki

# increase TTL by tuning the secrets engine, set to 30 days
vault secrets tune -address=$ADDRESS -tls-skip-verify -max-lease-ttl=87600h pki

# configure a CA certificate and private key; private key is stored internally in Vault
vault write -address=$ADDRESS -tls-skip-verify -field=certificate pki/root/generate/internal common_name="$CA" ttl=87600h | tee "$CA.root_cert.crt"

# configure the CA and the CRL URLs.
echo
vault write -address=$ADDRESS -tls-skip-verify pki/config/urls issuing_certificates="https://127.0.0.1:8200/v1/pki/ca" crl_distribution_points="https://127.0.0.1:8200/v1/pki/crl"
