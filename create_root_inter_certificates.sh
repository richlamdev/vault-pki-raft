#!/bin/bash

ADDRESS="http://127.0.0.1:8200"
COMMON_NAME_ROOT="Lord of the Rings Root Authority"
ISSUER="my_issuer_name"
ROOT="Root"

COMMON_NAME_INTERMEDIATE="Lord of the Rings Intermediate Authority"
INTERMEDIATE="Intermediate"
ROLE="middle_earth_role"
ALLOWED_DOMAINS="middleearth.test"

#set -aex

printf "\n%s" \
  ""\
  "*** Create Root Certificate ***"\
  ""\
  ""\

# login/authenticate locally
vault login -address=$ADDRESS -tls-skip-verify $(cat root_token)
echo

# enable the PKI secrets engine
vault secrets enable -address=$ADDRESS -tls-skip-verify pki
echo

# increase TTL by tuning the secrets engine, set to 30 days
vault secrets tune -address=$ADDRESS -tls-skip-verify -max-lease-ttl=87600h pki
echo

# configure a CA certificate and private key; private key is stored internally in Vault
vault write -address=$ADDRESS -tls-skip-verify -field=certificate pki/root/generate/internal common_name="$COMMON_NAME_ROOT" issuer_name="$ISSUER-$ROOT" ttl=87600h | tee "$COMMON_NAME_ROOT.root_cert.crt"
echo

# list the issuer information for the root CA
# vault list -address=$ADDRESS pki/issuers/

# read the issuer with its ID to get the certificates and other metadata about the issuer.
# vault read pki/issuer/<number/id output from previous command>

# configure the CA and the CRL URLs.
vault write -address=$ADDRESS -tls-skip-verify pki/config/urls issuing_certificates="https://127.0.0.1:8200/v1/pki/ca" crl_distribution_points="https://127.0.0.1:8200/v1/pki/crl"
echo


printf "\n%s" \
  ""\
  "*** Create Intermediate Certificate ***"\
  ""\
  ""

# enable the pki secrets engine at the pki_int path
vault secrets enable -address=$ADDRESS -tls-skip-verify -path=pki_int pki
echo

# Tune the pki_int secrets engine to issue certificates with a maximum time-to-live (TTL) of 43800 hours or five years
vault secrets tune -address=$ADDRESS -tls-skip-verify -max-lease-ttl=43800h pki_int
echo

# Generate an intermediate and save the CSR as $COMMON_NAME_pki_intermediate.csr
vault write -address=$ADDRESS -tls-skip-verify -format=json pki_int/intermediate/generate/internal common_name="$COMMON_NAME_INTERMEDIATE" issuer_name="$ISSUER-$INTERMEDIATE" | jq -r '.data.csr' > "$COMMON_NAME_INTERMEDIATE"_pki_intermediate.csr
echo

# Sign the intermediate certificate with the root CA private key, and save the generated certificate as intermediate.cert.pem
vault write -address=$ADDRESS -tls-skip-verify -format=json pki/root/sign-intermediate csr=@"$COMMON_NAME_INTERMEDIATE"_pki_intermediate.csr format=pem_bundle ttl="43800h" | jq -r '.data.certificate' > "$COMMON_NAME_INTERMEDIATE"_signed_by_root.cert.pem
echo

# Import the signed CSR into Vault
vault write -address=$ADDRESS -tls-skip-verify pki_int/intermediate/set-signed certificate=@"$COMMON_NAME_INTERMEDIATE"_signed_by_root.cert.pem
echo

# Create a role named example-dot-com which allows subdomains, and specify the default issuer ref ID as the value of issuer_ref
vault write -address=$ADDRESS -tls-skip-verify pki_int/roles/"$ROLE" allowed_domains="$ALLOWED_DOMAINS" allow_subdomains=true max_ttl="43800h"
echo

#openssl x509 -in "$COMMON_NAME_ROOT.root_cert.crt" -text -noout
#echo
#echo
#openssl x509 -in "$COMMON_NAME_INTERMEDIATE"_signed_by_root.cert.pem -text -noout
