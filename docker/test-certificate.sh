# Build the image
docker build -t my-nginx-image .

# Run the container and map port 443 to the host machine
docker run -d -p 443:443 my-nginx-image

# stop the container
# docker ps
# docker stop <container-id>
# docker rm <container-id>
