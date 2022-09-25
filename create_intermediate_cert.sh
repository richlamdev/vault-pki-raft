#!/bin/bash

COMMON_NAME="Lord of the Rings Intermediate Authority"
ADDRESS="http://127.0.0.1:8200"

set -aex
vault secrets enable -address=$ADDRESS -tls-skip-verify -path=pki_int pki
vault secrets tune -address=$ADDRESS -tls-skip-verify -max-lease-ttl=70080h pki_int

vault write -address=$ADDRESS -tls-skip-verify -format=json pki_int/intermediate/generate/internal common_name="$COMMON_NAME" | jq -r '.data.csr' > "$COMMON_NAME"_pki_intermediate.csr

vault write -address=$ADDRESS -tls-skip-verify -format=json pki/root/sign-intermediate csr=@"$COMMON_NAME"_pki_intermediate.csr format=pem_bundle ttl="43800h" | jq -r '.data.certificate' > lord_of_the_rings_signed_by_root.cert.pem

vault write -address=$ADDRESS -tls-skip-verify pki_int/intermediate/set-signed certificate=@lord_of_the_rings_signed_by_root.cert.pem

vault write -address=$ADDRESS -tls-skip-verify pki_int/roles/lord_of_the_rings allowed_domains="middleearth.test" allow_subdomains=true max_ttl="43800h" 
