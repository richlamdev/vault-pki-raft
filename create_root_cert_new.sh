#!/bin/bash

ADDRESS="http://127.0.0.1:8200"
CA="Lord of the Rings"
ISSUER="my_issuer_name"
ROOT="root"

set -aex

# login/authenticate locally
vault login -address=$ADDRESS -tls-skip-verify $(cat root_token-vault_2)

# enable the PKI secrets engine
vault secrets enable -address=$ADDRESS -tls-skip-verify pki

# increase TTL by tuning the secrets engine, set to 30 days
vault secrets tune -address=$ADDRESS -tls-skip-verify -max-lease-ttl=87600h pki

# configure a CA certificate and private key; private key is stored internally in Vault
vault write -address=$ADDRESS -tls-skip-verify -field=certificate pki/root/generate/internal common_name="$CA" issuer_name="$ISSUER-$ROOT" ttl=87600h | tee "$CA.root_cert.crt"

# list the issuer information for the root CA
# vault list -address=$ADDRESS pki/issuers/

# read the issuer with its ID to get the certificates and other metadata about the issuer.
# vault read pki/issuer/<number/id output from previous command>

# configure the CA and the CRL URLs.
echo
vault write -address=$ADDRESS -tls-skip-verify pki/config/urls issuing_certificates="https://127.0.0.1:8200/v1/pki/ca" crl_distribution_points="https://127.0.0.1:8200/v1/pki/crl"


# Create Intermediate Certificate

COMMON_NAME="Lord of the Rings Intermediate Authority"
INTERMEDIATE="intermediate"
INTER_CA="lotro"


# enable the pki secrets engine at the pki_int path
vault secrets enable -address=$ADDRESS -tls-skip-verify -path=pki_int pki

# Tune the pki_int secrets engine to issue certificates with a maximum time-to-live (TTL) of 70080 hours
vault secrets tune -address=$ADDRESS -tls-skip-verify -max-lease-ttl=70080h pki_int

# Generate an intermediate and save the CSR as $COMMON_NAME_pki_intermediate.csr
vault write -address=$ADDRESS -tls-skip-verify -format=json pki_int/intermediate/generate/internal common_name="$COMMON_NAME" issuer_name="$ISSUER-$INTERMEDIATE" | jq -r '.data.csr' > "$COMMON_NAME"_pki_intermediate.csr

# Sign the intermediate certificate with the root CA private key, and save the generated certificate as intermediate.cert.pem
vault write -address=$ADDRESS -tls-skip-verify -format=json pki/root/sign-intermediate csr=@"$COMMON_NAME"_pki_intermediate.csr format=pem_bundle ttl="43800h" | jq -r '.data.certificate' > "$INTER_CA"_signed_by_root.cert.pem

# Import the signed CSR into Vault
vault write -address=$ADDRESS -tls-skip-verify pki_int/intermediate/set-signed certificate=@"$INTER_CA"_signed_by_root.cert.pem

# Create a role named example-dot-com which allows subdomains, and specify the default issuer ref ID as the value of issuer_ref
vault write -address=$ADDRESS -tls-skip-verify pki_int/roles/"$INTER_CA" allowed_domains="middleearth.test" allow_subdomains=true max_ttl="43800h" 
