#!/bin/bash

# Ensure the script is executed with a HOST_STRING argument
if [ -z "$1" ]; then
  printf "\n${RED}%s${NC}\n" "Error: HOST_STRING is required. Please provide a host name."
  printf "${YELLOW}%s${NC}\n" "Usage: ./issue_cert_template.sh <hostname>"
  echo
  exit 1
fi

source ./env.sh

# Override the HOST_STRING in env.sh with the passed argument ($1)
HOST="$1"
SUBJECT_CN="$SUBJECT_CN_STRING"
VAULT_ROLE="$VAULT_ROLE_STRING"
IP_SAN1="$IP_SAN1_STRING"
ALT_NAME1="$ALT_NAME1_STRING"
TTL="$TTL_STRING"
KEY_TYPE="$KEY_TYPE_STRING"
KEY_BITS="$KEY_BITS_STRING"
NO_TLS="$NO_TLS_STRING"

OUT_DIR="${SUBJECT_CN}"
OUT_FILE="${HOST}_csr_signed_output_$(date +%Y%m%d%H%M%S).json"

# Create output directory if it doesn't exist
if [ ! -d "${OUT_DIR}" ]; then
  mkdir "${OUT_DIR}"
  printf "\n${GREEN}%s${NC}\n" "Created output directory: ${OUT_DIR}"
fi

# Issue certificate
printf "\n${CYAN}%s${NC}\n" "*** Issuing Certificate for ${SUBJECT_CN} ***"
vault write "${NO_TLS}" -format=json pki_int/issue/"${VAULT_ROLE}" \
  common_name="${SUBJECT_CN}" \
  ip_sans="${IP_SAN1}" \
  alt_names="${ALT_NAME1}" \
  key_type="${KEY_TYPE}" \
  key_bits="${KEY_BITS}" \
  ttl="${TTL}" | tee "${OUT_DIR}/${OUT_FILE}"

# Extract certificate and private key
printf "\n${CYAN}%s${NC}\n" "*** Extracting Certificate and Private Key ***"
jq -r '.data.certificate,.data.issuing_ca' "${OUT_DIR}/${OUT_FILE}" > \
  "${OUT_DIR}/${HOST}_cert.crt"
jq -r '.data.private_key' "$OUT_DIR/${OUT_FILE}" >"${OUT_DIR}/${HOST}_cert.key"

# Create a timestamp file
touch "${OUT_DIR}/created_$(date +"%Y-%m-%d--%H-%M-%S")"
printf "\n${GREEN}%s${NC}\n" "Timestamp file created in ${OUT_DIR}"

# Copy files to Docker directory
cp "${OUT_DIR}/${HOST}_cert.crt" ./docker/.
cp "${OUT_DIR}/${HOST}_cert.key" ./docker/.
printf "\n${YELLOW}%s${NC}\n" "*** Copied ${HOST}_cert.crt to ./docker/${HOST}_cert.crt ***"
printf "${YELLOW}%s${NC}\n" "*** Copied ${HOST}_cert.key to ./docker/${HOST}_cert.key ***"

# Provide usage instructions
printf "\n${CYAN}%s${NC}\n" "*** To view ${HOST}_cert.key private certificate execute this command: ***"
printf "${MAGENTA}%s${NC}\n" "openssl pkey -in ${OUT_DIR}/${HOST}_cert.key -check"

printf "\n${CYAN}%s${NC}\n" "*** To view ${HOST}_cert.key public certificate execute this command: ***"
printf "${MAGENTA}%s${NC}\n" "openssl pkey -in ${OUT_DIR}/${HOST}_cert.key -pubout"

printf "\n${CYAN}%s${NC}\n" "*** To view ${HOST}_cert.crt public certificate execute this command: ***"
printf "${MAGENTA}%s${NC}\n" "openssl x509 -in ${OUT_DIR}/${HOST}_cert.crt -text -noout"

# Final confirmation
printf "\n${GREEN}%s${NC}\n" "✅ Certificate and key generated successfully for ${SUBJECT_CN}"
printf "${CYAN}%s${NC}\n" "Edit the Dockerfile in ./docker to create the image and execute the container."
