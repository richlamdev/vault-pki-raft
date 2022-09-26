#!/bin/bash

HOST="template"
DOMAIN=".middleearth.test"
COMMON_NAME="${HOST}${DOMAIN}"
IP_SAN="192.168.50.1"
ALT_NAME1=${COMMON_NAME}
ALT_NAME2=""

TTL="41000h"
OUTPUT_FILE="${HOST}_csr_signed_output.json"

ROLE="lotro"

ADDRESS="http://127.0.0.1:8200"

vault write -address=$ADDRESS -format=json pki_int/issue/"$ROLE" common_name=${COMMON_NAME} ip_sans=${IP_SAN} alt_names="${ALT_NAME1},${ALT_NAME2}" ttl=${TTL} | tee ${OUTPUT_FILE}

jq -r '.data.certificate,.data.issuing_ca' $OUTPUT_FILE > ${HOST}_cert.crt
jq -r '.data.private_key' $OUTPUT_FILE > ${HOST}_cert.key
