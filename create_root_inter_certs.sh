#!/bin/bash
# edit env.sh as required. Refer to README.md for more details.

# Source environment variables
source ./env.sh

# Variables
DOMAIN="$DOMAIN_STRING"
ISSUER_NAME_CN="$ISSUER_NAME_CN_STRING"
VAULT_ROLE="$VAULT_ROLE_STRING"

ROOT_INTER_DIR="./root_inter_certs"
CN_ROOT="${ISSUER_NAME_CN} Root Certificate Authority"
CN_INTER="${ISSUER_NAME_CN} Intermediate Certificate Authority"
CN_ROOT_NO_SPACE="${CN_ROOT// /_}"
CN_INTER_NO_SPACE="${CN_INTER// /_}"
ADDRESS="$VAULT_ADDR"
NO_TLS="$NO_TLS_STRING"
KEY_TYPE="$KEY_TYPE_STRING"
KEY_BITS="$KEY_BITS_STRING"

mkdir "$ROOT_INTER_DIR"

# --- Root Certificate Creation ---
printf "\n${CYAN}%s${NC}\n" "*** Create Root Certificate ***"

# Login to Vault
printf "${MAGENTA}%s${NC}\n" "vault login \"${NO_TLS}\" \"\$(cat root_token)\""
vault login "${NO_TLS}" "$(cat root_token)"
echo

# Enable PKI Secrets Engine
printf "${MAGENTA}%s${NC}\n" "vault secrets enable \"${NO_TLS}\" pki"
vault secrets enable "${NO_TLS}" pki
echo

# Tune Secrets Engine
printf "${MAGENTA}%s${NC}\n" "vault secrets tune \"${NO_TLS}\" -max-lease-ttl=87600h pki"
vault secrets tune "${NO_TLS}" -max-lease-ttl=87600h pki
echo

# Generate Root Certificate
printf "${MAGENTA}%s${NC}\n" "vault write \"${NO_TLS}\" -field=certificate pki/root/generate/internal ..."
vault write "${NO_TLS}" -field=certificate pki/root/generate/internal \
  common_name="${CN_ROOT}" key_type="${KEY_TYPE}" ttl=87600h ou="my dept" |
  tee "$ROOT_INTER_DIR/$CN_ROOT_NO_SPACE.root_cert.crt"
echo

# Configure CA and CRL URLs
printf "${MAGENTA}%s${NC}\n" "vault write \"${NO_TLS}\" pki/config/urls ..."
vault write "${NO_TLS}" pki/config/urls \
  issuing_certificates="${ADDRESS}/v1/pki/ca" \
  crl_distribution_points="${ADDRESS}/v1/pki/crl"
echo

# --- Intermediate Certificate Creation ---
printf "\n${CYAN}%s${NC}\n" "*** Create Intermediate Certificate ***"

# Enable PKI Secrets Engine for Intermediate
printf "${MAGENTA}%s${NC}\n" "vault secrets enable \"${NO_TLS}\" -path=pki_int pki"
vault secrets enable "${NO_TLS}" -path=pki_int pki
echo

# Tune Intermediate Secrets Engine
printf "${MAGENTA}%s${NC}\n" "vault secrets tune \"${NO_TLS}\" -max-lease-ttl=43800h pki_int"
vault secrets tune "${NO_TLS}" -max-lease-ttl=43800h pki_int
echo

# Generate Intermediate CSR
printf "${MAGENTA}%s${NC}\n" "vault write \"${NO_TLS}\" -format=json pki_int/intermediate/generate/internal ..."
vault write "${NO_TLS}" -format=json \
  pki_int/intermediate/generate/internal \
  common_name="${CN_INTER}" key_type="${KEY_TYPE}" | jq -r '.data.csr' > \
  "$ROOT_INTER_DIR/$CN_INTER_NO_SPACE"_pki_intermediate.csr
echo

# Sign Intermediate CSR
printf "${MAGENTA}%s${NC}\n" "vault write \"${NO_TLS}\" -format=json pki/root/sign-intermediate ..."
vault write "${NO_TLS}" -format=json pki/root/sign-intermediate \
  csr=@"$ROOT_INTER_DIR/$CN_INTER_NO_SPACE"_pki_intermediate.csr \
  format=pem_bundle ttl="43800h" | jq -r '.data.certificate' > \
  "$ROOT_INTER_DIR/$CN_INTER_NO_SPACE"_signed_by_root.cert.pem
echo

# Import Intermediate Certificate
printf "${MAGENTA}%s${NC}\n" "vault write \"${NO_TLS}\" pki_int/intermediate/set-signed ..."
vault write "${NO_TLS}" pki_int/intermediate/set-signed \
  certificate=@"$ROOT_INTER_DIR/$CN_INTER_NO_SPACE"_signed_by_root.cert.pem
echo

# Create Vault Role
printf "${MAGENTA}%s${NC}\n" "vault write \"${NO_TLS}\" pki_int/roles/\"$VAULT_ROLE\" ..."
vault write "${NO_TLS}" pki_int/roles/"$VAULT_ROLE" \
  allowed_domains="*.${DOMAIN},${DOMAIN}" \
  allow_subdomains=true \
  allow_bare_domains=true \
  max_ttl="43800h" \
  key_type="${KEY_TYPE}" \
  key_bits="${KEY_BITS}" \
  issuer_ref="default"
echo

# --- Display Certificate Commands ---
printf "\n${CYAN}%s${NC}\n" "*** Certificate Review Commands ***"
printf "${GREEN}%s${NC}\n" "To view root certificate:"
printf "${YELLOW}%s${NC}\n" "openssl x509 -in ${ROOT_INTER_DIR}/${CN_ROOT_NO_SPACE}.root_cert.crt -text -noout"
echo

printf "${GREEN}%s${NC}\n" "To view intermediate certificate:"
printf "${YELLOW}%s${NC}\n" "openssl x509 -in ${ROOT_INTER_DIR}/${CN_INTER_NO_SPACE}_signed_by_root.cert.pem -text -noout"
echo

# Copy root certificate
printf "${CYAN}%s${NC}\n" "*** Copying Root Certificate to Docker Directory ***"
cp "${ROOT_INTER_DIR}/${CN_ROOT_NO_SPACE}.root_cert.crt" ./docker/.
printf "${GREEN}%s${NC}\n" "Copied to ./docker/${CN_ROOT_NO_SPACE}.root_cert.crt"
echo

# Create a timestamped file
touch "${ROOT_INTER_DIR}/created_$(date +"%Y-%m-%d--%H-%M-%S")"
printf "${GREEN}%s${NC}\n" "Timestamped file created successfully."
