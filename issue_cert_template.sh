#!/bin/bash

# edit the HOST and DOMAIN for the Subject-Common Name (SUBJECT_CN) you want to appear on the certificate
# edit or omit the IP address in the Subject Alternative Name (SAN)
# edit the TTL to set the certificate expiry, presently set to 9552hours or 398 days
# Reference: https://support.apple.com/en-ca/HT211025
# edit VAULT_ROLE if you desire.  This role name *must* match the role name in create_root_inter_certificates.sh
# if the VAULT_ROLE value does not match, certificates will not be signed/issued.
HOST="template"
DOMAIN="middleearth.test"
SUBJECT_CN=${HOST}.${DOMAIN}
VAULT_ROLE="middle_earth_role"
IP_SAN1="192.168.50.1"
#IP_SAN2=""
ALT_NAME1=${SUBJECT_CN}
#ALT_NAME2=""
TTL="9552h"

OUTPUT_DIR=${SUBJECT_CN}
OUTPUT_FILE=${HOST}_csr_signed_output.json
ADDRESS="http://127.0.0.1:8200"


if [ ! -d $OUTPUT_DIR ]
  then
    mkdir $OUTPUT_DIR
  fi

vault write -address=$ADDRESS -format=json pki_int/issue/$VAULT_ROLE common_name=${SUBJECT_CN} ip_sans=${IP_SAN1} alt_names=${ALT_NAME1} ttl=${TTL} | tee $OUTPUT_DIR/${OUTPUT_FILE}
#vault write -address=$ADDRESS -format=json pki_int/issue/"$VAULT_ROLE" common_name=${SUBJECT_CN} ip_sans="${IP_SAN1},${IP_SAN2}" alt_names="${ALT_NAME1},${ALT_NAME2}" ttl=${TTL} | tee ${OUTPUT_FILE}

jq -r '.data.certificate,.data.issuing_ca' ${OUTPUT_DIR}/${OUTPUT_FILE} > ${OUTPUT_DIR}/${HOST}_cert.crt
jq -r '.data.private_key' $OUTPUT_DIR/${OUTPUT_FILE} > ${OUTPUT_DIR}/${HOST}_cert.key

printf "\n%s" \
  "*** To view ${HOST}_cert.key private certificate execute the following command:***"\
  "openssl rsa -in ${OUTPUT_DIR}/${HOST}_cert.key -check"\
  ""\
  ""\
  "*** To view ${HOST}_cert.crt public certificate execute the following command:***"\
  "openssl x509 -in ${OUTPUT_DIR}/${HOST}_cert.crt -text -noout"\
  ""\
  ""

touch ${OUTPUT_DIR}/created_$(date +"%Y-%m-%d--%H-%M-%S")
