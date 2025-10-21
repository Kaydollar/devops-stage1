# Use official NGINX image as base
FROM nginx:latest

# Copy your custom webpage into NGINX's html folder
COPY index.html /usr/share/nginx/html/index.html

# Expose port 80 for web traffic
EXPOSE 80

# Start NGINX (default command)
CMD ["nginx", "-g", "daemon off;"]
