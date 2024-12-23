#!/bin/bash

# Ensure the script is executed with a HOST_STRING argument
if [ -z "$1" ]; then
  echo "Error: HOST_STRING is required. Please provide a host name."
  echo "Usage: ./issue_cert_template.sh <hostname>"
  exit 1
fi

source ./env.sh

# Override the HOST_STRING with the passed argument ($1)
HOST_STRING="$1"

HOST="$HOST_STRING"
#DOMAIN="$DOMAIN_STRING"
SUBJECT_CN="$SUBJECT_CN_STRING"
VAULT_ROLE="$VAULT_ROLE_STRING"
IP_SAN1="$IP_SAN1_STRING"
ALT_NAME1="$ALT_NAME1_STRING"
#IP_SAN2=""
#ALT_NAME2="$ALT_NAME2_STRING"
TTL="$TTL_STRING"
KEY_TYPE="$KEY_TYPE_STRING"
KEY_BITS="$KEY_BITS_STRING"

OUT_DIR="${SUBJECT_CN}"
#OUT_FILE="${HOST}_csr_signed_output.json"
OUT_FILE="${HOST}_csr_signed_output_$(date +%Y%m%d%H%M%S).json"
NO_TLS="$NO_TLS_STRING"

if [ ! -d "${OUT_DIR}" ]; then
  mkdir "${OUT_DIR}"
fi

vault write "${NO_TLS}" -format=json pki_int/issue/"${VAULT_ROLE}" \
  common_name="${SUBJECT_CN}" \
  ip_sans="${IP_SAN1}" \
  alt_names="${ALT_NAME1}" \
  key_type="${KEY_TYPE}" \
  key_bits="${KEY_BITS}" \
  ttl="${TTL}" | tee "${OUT_DIR}/${OUT_FILE}"

# alternative example command that allows multiple SAN entries
# adjust as needed, and populate variables accordingly at the top of this script
#vault write -format=json pki_int/issue/"$VAULT_ROLE" \
#      common_name=${SUBJECT_CN} ip_sans="${IP_SAN1},${IP_SAN2}" \
#      alt_names="${ALT_NAME1},${ALT_NAME2}" ttl=${TTL} | tee ${OUT_FILE}

jq -r '.data.certificate,.data.issuing_ca' "${OUT_DIR}/${OUT_FILE}" > \
  "${OUT_DIR}/${HOST}_cert.crt"

jq -r '.data.private_key' "$OUT_DIR/${OUT_FILE}" >"${OUT_DIR}/${HOST}_cert.key"

printf "\n%s" \
  "*** To view ${HOST}_cert.key private certificate execute this command:***" \
  "openssl pkey -in ${OUT_DIR}/${HOST}_cert.key -check" \
  "" \
  "*** To view ${HOST}_cert.key public certificate execute this command:***" \
  "openssl pkey -in ${OUT_DIR}/${HOST}_cert.key -pubout" \
  "" \
  "*** To view ${HOST}_cert.crt public certificate execute this command:***" \
  "openssl x509 -in ${OUT_DIR}/${HOST}_cert.crt -text -noout" \
  "" \
  ""

touch "${OUT_DIR}/created_$(date +"%Y-%m-%d--%H-%M-%S")"

cp "${OUT_DIR}/${HOST}_cert.crt" ./docker/.
cp "${OUT_DIR}/${HOST}_cert.key" ./docker/.

printf "\n%s" \
  "*** copied ${HOST}_cert.crt to ./docker/${HOST}_cert.crt***" \
  "" \
  "*** copied ${HOST}_cert.key to ./docker/${HOST}_cert.key***" \
  "" \
  "edit the DockerFile in ./docker to create the image and execute the container" \
  "" \
  ""
echo "✅ Certificate and key generated successfully for ${SUBJECT_CN}"
