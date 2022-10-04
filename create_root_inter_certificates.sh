#!/bin/bash

# edit ISSUER_NAME_CN for the Certificate Authority (CA) want to appear on certificates.
# edit DOMAIN for the allowed domains the CA is allowed to certify
# edit VAULT_ROLE if you desire.  This role name *must* match the role name in issue_cert_template.sh
# if the VAULT_ROLE value does not match, certificates will not be signed/issued.

DOMAIN="middleearth.test"
ISSUER_NAME_CN="Lord of the Rings"
VAULT_ROLE="middle_earth_role"

ROOT_INTER_FOLDER="./root_inter_certs"
ROOT="Root"
INTERMEDIATE="Intermediate"
CN_ROOT="${ISSUER_NAME_CN} ${ROOT} Authority"
CN_INTERMEDIATE="${ISSUER_NAME_CN} ${INTERMEDIATE} Authority"
CN_ROOT_NO_SPACE=${CN_ROOT// /_}
CN_INTERMEDIATE_NO_SPACE=${CN_INTERMEDIATE// /_}
ADDRESS="http://127.0.0.1:8200"


mkdir $ROOT_INTER_FOLDER

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
#vault write -address=$ADDRESS -tls-skip-verify -field=certificate pki/root/generate/internal common_name="$CN_ROOT" issuer_name="$ROOT" ttl=87600h | tee "$ROOT_INTER_FOLDER/$CN_ROOT_NO_SPACE.root_cert.crt"
vault write -address=$ADDRESS -tls-skip-verify -field=certificate pki/root/generate/internal common_name="$CN_ROOT" ttl=87600h | tee "$ROOT_INTER_FOLDER/$CN_ROOT_NO_SPACE.root_cert.crt"
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

# Generate an intermediate and save the CSR as $CN_pki_intermediate.csr
#vault write -address=$ADDRESS -tls-skip-verify -format=json pki_int/intermediate/generate/internal common_name="$CN_INTERMEDIATE" issuer_name="$INTERMEDIATE" | jq -r '.data.csr' > "$ROOT_INTER_FOLDER/$CN_INTERMEDIATE_NO_SPACE"_pki_intermediate.csr
vault write -address=$ADDRESS -tls-skip-verify -format=json pki_int/intermediate/generate/internal common_name="$CN_INTERMEDIATE" | jq -r '.data.csr' > "$ROOT_INTER_FOLDER/$CN_INTERMEDIATE_NO_SPACE"_pki_intermediate.csr
echo

# Sign the intermediate certificate with the root CA private key, and save the generated certificate as intermediate.cert.pem
vault write -address=$ADDRESS -tls-skip-verify -format=json pki/root/sign-intermediate csr=@"$ROOT_INTER_FOLDER/$CN_INTERMEDIATE_NO_SPACE"_pki_intermediate.csr format=pem_bundle ttl="43800h" | jq -r '.data.certificate' > "$ROOT_INTER_FOLDER/$CN_INTERMEDIATE_NO_SPACE"_signed_by_root.cert.pem
echo

# Import the signed CSR into Vault
vault write -address=$ADDRESS -tls-skip-verify pki_int/intermediate/set-signed certificate=@"$ROOT_INTER_FOLDER/$CN_INTERMEDIATE_NO_SPACE"_signed_by_root.cert.pem
echo

# Create a role named emiddle_earth_role which allows subdomains, and specify the default issuer ref ID as the value of issuer_ref
vault write -address=$ADDRESS -tls-skip-verify pki_int/roles/"$VAULT_ROLE" allowed_domains="$DOMAIN" allow_subdomains=true max_ttl="43800h"
echo

printf "\n%s" \
    "*** To view root certificate execute the following command:***"\
    "openssl x509 -in ${ROOT_INTER_FOLDER}/${CN_ROOT_NO_SPACE}.root_cert.crt -text -noout"\
    ""\
    ""\
    "*** To view intermediate certificate execute the following command:***"\
    "openssl x509 -in ${ROOT_INTER_FOLDER}/${CN_INTERMEDIATE_NO_SPACE}_signed_by_root.cert.pem -text -noout"\
    ""\
    ""

touch ${ROOT_INTER_FOLDER}/created_$(date +"%Y-%m-%d--%H-%M-%S")
