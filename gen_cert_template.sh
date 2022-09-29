#!/bin/bash

HOST="template"
DOMAIN="middleearth.test"
COMMON_NAME=${HOST}.${DOMAIN}
IP_SAN1="192.168.50.1"
IP_SAN2=""
ALT_NAME1=${COMMON_NAME}
ALT_NAME2=""

TTL="9552h"
OUTPUT_DIR=${COMMON_NAME}
OUTPUT_FILE=${HOST}_csr_signed_output.json
ROLE="middle_earth_role"
ADDRESS="http://127.0.0.1:8200"


if [ ! -d $OUTPUT_DIR ]
  then
    mkdir $OUTPUT_DIR
  fi

vault write -address=$ADDRESS -format=json pki_int/issue/$ROLE common_name=${COMMON_NAME} ip_sans=${IP_SAN1} alt_names=${ALT_NAME1} ttl=${TTL} | tee $OUTPUT_DIR/${OUTPUT_FILE}
#vault write -address=$ADDRESS -format=json pki_int/issue/"$ROLE" common_name=${COMMON_NAME} ip_sans="${IP_SAN1},${IP_SAN2}" alt_names="${ALT_NAME1},${ALT_NAME2}" ttl=${TTL} | tee ${OUTPUT_FILE}

jq -r '.data.certificate,.data.issuing_ca' ${OUTPUT_DIR}/${OUTPUT_FILE} > ${OUTPUT_DIR}/${HOST}_cert.crt
jq -r '.data.private_key' $OUTPUT_DIR/${OUTPUT_FILE} > ${OUTPUT_DIR}/${HOST}_cert.key

echo "*** View ${HOST}_cert.key private certificate ***"
openssl rsa -in ${OUTPUT_DIR}/${HOST}_cert.key -check | head -n20

echo
echo
echo
echo "*** View ${HOST}_cert.crt public certificate ***"
openssl x509 -in ${OUTPUT_DIR}/${HOST}_cert.crt -text -noout | head -n50
