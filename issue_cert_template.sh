!/bin/bash

# Ensure the script is executed with a HOST_STRING argument
if [ -z "$1" ]; then
  printf "\n${RED}%s${NC}\n" "Error: HOST_STRING is required. Please provide a host name."
  printf "${YELLOW}%s${NC}\n" "Usage: ./issue_cert_template.sh <hostname>"
  echo
  exit 1
fi

# edit env.sh as required.  Refer to README.md for more details.

source ./env.sh

# Override the HOST_STRING in env.sh with the passed argument ($1)
HOST="$1"
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
# cp "${OUT_DIR}/${HOST}_cert.crt" ./docker/.
# cp "${OUT_DIR}/${HOST}_cert.key" ./docker/.
# printf "\n${YELLOW}%s${NC}\n" "*** Copied ${HOST}_cert.crt to ./docker/${HOST}_cert.crt ***"
# printf "${YELLOW}%s${NC}\n" "*** Copied ${HOST}_cert.key to ./docker/${HOST}_cert.key ***"

# Provide usage instructions
printf "\n${CYAN}%s${NC}\n" "*** To view ${HOST}_cert.key private certificate execute this command: ***"
printf "${MAGENTA}%s${NC}\n" "openssl pkey -in ${OUT_DIR}/${HOST}_cert.key -check"

printf "\n${CYAN}%s${NC}\n" "*** To view ${HOST}_cert.key public certificate execute this command: ***"
printf "${MAGENTA}%s${NC}\n" "openssl pkey -in ${OUT_DIR}/${HOST}_cert.key -pubout"

printf "\n${CYAN}%s${NC}\n" "*** To view ${HOST}_cert.crt public certificate execute this command: ***"
printf "${MAGENTA}%s${NC}\n" "openssl x509 -in ${OUT_DIR}/${HOST}_cert.crt -text -noout"

# Final confirmation
printf "\n${GREEN}%s${NC}\n" "✅ Certificate and key generated successfully for ${SUBJECT_CN}"
#printf "${CYAN}%s${NC}\n" "Edit the Dockerfile in ./docker to create the image and execute the container."

# --------------------------------------
# 🛡️ STEP 1: Concatenate Certificates
# --------------------------------------

mkdir ./docker

CHAIN_CERT="${OUT_DIR}/${HOST}_chain_cert.crt"
cat "${OUT_DIR}/${HOST}_cert.crt" "${INTERMEDIATE_DIR}/${CN_INTER_NO_SPACE}_signed_by_root.cert.pem" >"${CHAIN_CERT}"

printf "\n${GREEN}%s${NC}\n" "✅ Concatenated leaf and intermediate certificates into: ${CHAIN_CERT}"

# --------------------------------------
# 📁 STEP 2: Copy Certificates to Docker Directory
# --------------------------------------

# Copy concatenated chain cert and key to Docker directory
cp "${CHAIN_CERT}" ./docker/
cp "${OUT_DIR}/${HOST}_cert.key" ./docker/

printf "\n${YELLOW}%s${NC}\n" "*** Copied concatenated certificate to ./docker/${HOST}_chain_cert.crt ***"
printf "${YELLOW}%s${NC}\n" "*** Copied private key to ./docker/${HOST}_cert.key ***"

# --------------------------------------
# 🐳 STEP 3: Generate Dockerfile
# --------------------------------------

cat <<EOF >./docker/Dockerfile
# Dockerfile for serving certificates via Nginx
FROM nginx:alpine

# Install OpenSSL for debugging
RUN apk add --no-cache openssl

# Create SSL directory
RUN mkdir -p /etc/nginx/ssl

# Copy certificate chain and key
COPY ${HOST}_chain_cert.crt /etc/nginx/ssl/server.crt
COPY ${HOST}_cert.key /etc/nginx/ssl/server.key
COPY nginx.conf /etc/nginx/nginx.conf

# Expose HTTPS port
EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]
EOF

printf "\n${GREEN}%s${NC}\n" "✅ Dockerfile generated at ./docker/Dockerfile"

# --------------------------------------
# ⚙️ STEP 4: Generate nginx.conf
# --------------------------------------

cat <<EOF >./docker/nginx.conf
# nginx.conf for TLS termination with certificate chain
worker_processes 1;

events {
    worker_connections 1024;
}

http {
    server {
        listen 443 ssl;
        server_name localhost;

        ssl_certificate /etc/nginx/ssl/server.crt;
        ssl_certificate_key /etc/nginx/ssl/server.key;

        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;

        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
    }
}
EOF

printf "\n${GREEN}%s${NC}\n" "✅ nginx.conf generated at ./docker/nginx.conf"

# --------------------------------------
# 🛠️ STEP 5: Build and Run Docker Container
# --------------------------------------

# Navigate to docker directory
cd ./docker || exit

# Build Docker Image
docker build -t nginx-tls-cert .

# Run Docker Container
docker run -d --name nginx-tls-cert -p 443:443 nginx-tls-cert

printf "\n${GREEN}%s${NC}\n" "✅ Docker container is running with HTTPS enabled."
printf "${CYAN}%s${NC}\n" "🌐 Access the server via: https://localhost"

# --------------------------------------
# 🔍 STEP 6: Verify SSL Chain (Optional)
# --------------------------------------

printf "\n${CYAN}%s${NC}\n" "*** Verify SSL certificate with OpenSSL command: ***"
printf "${MAGENTA}%s${NC}\n" "openssl s_client -connect localhost:443 -showcerts"
