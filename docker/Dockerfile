# Dockerfile for serving certificates via Nginx
FROM nginx:alpine

# Install OpenSSL for debugging
RUN apk add --no-cache openssl

# Create SSL directory
RUN mkdir -p /etc/nginx/ssl

# Copy certificate chain and key
COPY alpha_chain_cert.crt /etc/nginx/ssl/server.crt
COPY alpha_cert.key /etc/nginx/ssl/server.key
COPY nginx.conf /etc/nginx/nginx.conf

# Expose HTTPS port
EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]
