# Use NGINX base image
FROM nginx:latest

# Copy HTML into NGINX directory
COPY index.html /usr/share/nginx/html/index.html

# Expose port 80
EXPOSE 80
