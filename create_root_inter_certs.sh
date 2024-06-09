#!/bin/bash
# edit env.sh as required.  Refer to README.md for more details.

source ./env.sh

DOMAIN="$DOMAIN_STRING"
ISSUER_NAME_CN="$ISSUER_NAME_CN_STRING"
VAULT_ROLE="$VAULT_ROLE_STRING"

ROOT_INTER_DIR="./root_inter_certs"
CN_ROOT="${ISSUER_NAME_CN} Root Authority"
CN_INTER="${ISSUER_NAME_CN} Intermediate Authority"
CN_ROOT_NO_SPACE="${CN_ROOT// /_}"
CN_INTER_NO_SPACE="${CN_INTER// /_}"
ADDRESS="$VAULT_ADDR"
NO_TLS="$NO_TLS_STRING"
KEY_TYPE="$KEY_TYPE_STRING"
KEY_BITS="$KEY_BITS_STRING"

mkdir "$ROOT_INTER_DIR"

printf "\n%s" \
  "" \
  "*** Create Root Certificate ***" \
  "" \
  ""

# login/authenticate locally
vault login "${NO_TLS}" "$(cat root_token)"
echo

# enable the PKI secrets engine
vault secrets enable "${NO_TLS}" pki
echo

# increase TTL by tuning the secrets engine, set to 30 days
vault secrets tune "${NO_TLS}" -max-lease-ttl=87600h pki
echo

# configure a CA certificate and private key;
# the private key is stored internally in Vault
vault write "${NO_TLS}" -field=certificate pki/root/generate/internal \
  common_name="${CN_ROOT}" key_type="${KEY_TYPE}" ttl=87600h ou="my dept" |
  tee "$ROOT_INTER_DIR/$CN_ROOT_NO_SPACE.root_cert.crt"
echo

# list the issuer information for the root CA
# vault list pki/issuers/

# read the issuer with its ID to get the certificates
# and other metadata about the issuer.
# vault read pki/issuer/<number/id output from previous command>

# configure the CA and the CRL URLs.
vault write "${NO_TLS}" pki/config/urls \
  issuing_certificates="${ADDRESS}/v1/pki/ca" \
  crl_distribution_points="${ADDRESS}/v1/pki/crl"
echo

printf "\n%s" \
  "" \
  "*** Create Intermediate Certificate ***" \
  "" \
  ""

# enable the pki secrets engine at the pki_int path
vault secrets enable "${NO_TLS}" -path=pki_int pki
echo

# Tune the pki_int secrets engine to issue certificates with a maximum
# time-to-live (TTL) of 43800 hours or five years
vault secrets tune "${NO_TLS}" -max-lease-ttl=43800h pki_int
echo

# Generate an intermediate and save the CSR as $CN_pki_intermediate.csr
vault write "${NO_TLS}" -format=json \
  pki_int/intermediate/generate/internal \
  common_name="${CN_INTER}" key_type="${KEY_TYPE}" | jq -r '.data.csr' > \
  "$ROOT_INTER_DIR/$CN_INTER_NO_SPACE"_pki_intermediate.csr
echo

# Sign the intermediate certificate with the root CA private key,
# and save the generated certificate as intermediate.cert.pem
vault write "${NO_TLS}" -format=json pki/root/sign-intermediate \
  csr=@"$ROOT_INTER_DIR/$CN_INTER_NO_SPACE"_pki_intermediate.csr \
  format=pem_bundle ttl="43800h" | jq -r '.data.certificate' > \
  "$ROOT_INTER_DIR/$CN_INTER_NO_SPACE"_signed_by_root.cert.pem
echo

# Import the signed CSR into Vault
vault write "${NO_TLS}" pki_int/intermediate/set-signed \
  certificate=@"$ROOT_INTER_DIR/$CN_INTER_NO_SPACE"_signed_by_root.cert.pem
echo

# Create a role named $VAULT_ROLE which will allow subdomains,
# and specify the default issuer ref ID as the value of issuer_ref
vault write "${NO_TLS}" pki_int/roles/"$VAULT_ROLE" \
  allowed_domains="${DOMAIN}" allow_subdomains=true allowed_common_names="*" max_ttl="43800h" \
  key_type="${KEY_TYPE}" key_bits="${KEY_BITS}"
echo

printf "\n%s" \
  "*** To view root certificate execute the following command:***" \
  "openssl x509 -in ${ROOT_INTER_DIR}/${CN_ROOT_NO_SPACE}.root_cert.crt\
  -text -noout" \
  "" \
  "" \
  "*** To view intermediate certificate execute the following command:***" \
  "openssl x509 -in \
  ${ROOT_INTER_DIR}/${CN_INTER_NO_SPACE}_signed_by_root.cert.pem -text -noout" \
  "" \
  ""

touch "${ROOT_INTER_DIR}/created_$(date +"%Y-%m-%d--%H-%M-%S")"
