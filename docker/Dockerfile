# Use the official Nginx image as the base image
FROM nginx

# Copy the self-signed certificate and key files to the container
COPY template_cert.crt /etc/nginx/ssl/
COPY template_cert.key /etc/nginx/ssl/

# Replace the default Nginx configuration file with our own
COPY nginx.conf /etc/nginx/nginx.conf

# Expose port 443 for HTTPS traffic
EXPOSE 443

