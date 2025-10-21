#!/bin/bash
# DevOps Stage 1 - Automated Deployment Script (with Logging & Error Handling)
# Author: Yinusa Kolawole
# Slack Name: KolaDevOps
# Date: $(date)

set -Eeuo pipefail  # Safer error handling
trap 'echo "❌ Error on line $LINENO. Check the log file: $LOG_FILE"; exit 1' ERR

# ====== COLORS ======
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
RESET="\033[0m"

# ====== LOGGING ======
LOG_DIR="./logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/deploy_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo -e "${BLUE}=========================================${RESET}"
echo -e "${YELLOW}🚀 Starting Deployment Script...${RESET}"
echo -e "${BLUE}=========================================${RESET}"

# ====== USER INPUT ======
read -p "Enter GitHub repository URL: " REPO_URL
read -p "Is this a private repo (y/n)? " IS_PRIVATE
if [[ "$IS_PRIVATE" =~ ^[Yy]$ ]]; then
    read -p "Enter your Personal Access Token (PAT): " PAT
fi
read -p "Branch to deploy (default: main): " BRANCH
BRANCH=${BRANCH:-main}

read -p "Remote SSH username (e.g. ubuntu): " SSH_USER
read -p "Remote server IP address: " SERVER_IP
read -p "Path to SSH private key (e.g. ~/Downloads/devops-key.pem): " SSH_KEY
read -p "Application internal port (e.g. 3000): " APP_PORT

echo -e "${YELLOW}🔍 Checking Git repository...${RESET}"

# ====== CLONE OR UPDATE REPO ======
if [ -d "$(basename $REPO_URL .git)" ]; then
    echo "Repository exists, pulling latest changes..."
    cd "$(basename $REPO_URL .git)"
    git pull origin $BRANCH
else
    echo "Cloning repository..."
    git clone -b $BRANCH $REPO_URL
    cd "$(basename $REPO_URL .git)"
fi

echo -e "${GREEN}✅ Repository ready.${RESET}"

# ====== SSH CONNECTION TEST ======
echo -e "${YELLOW}🔗 Testing SSH connection to remote server...${RESET}"
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no $SSH_USER@$SERVER_IP "echo Connection successful!"

echo -e "${GREEN}✅ SSH connection established.${RESET}"

# ====== REMOTE SETUP ======
echo -e "${YELLOW}⚙️ Setting up remote environment...${RESET}"

ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no $SSH_USER@$SERVER_IP <<EOF
    set -e
    sudo apt update -y
    sudo apt install -y docker.io docker-compose nginx
    sudo systemctl enable docker --now
    sudo systemctl enable nginx --now

    mkdir -p /home/$SSH_USER/app
EOF

# ====== FILE TRANSFER ======
echo -e "${YELLOW}📦 Transferring project files...${RESET}"
scp -i "$SSH_KEY" -r . $SSH_USER@$SERVER_IP:/home/$SSH_USER/app/

echo -e "${GREEN}✅ Files transferred successfully.${RESET}"

# ====== DEPLOYMENT ======
echo -e "${YELLOW}🚧 Building and starting Docker container...${RESET}"

ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no $SSH_USER@$SERVER_IP <<EOF
    set -e
    cd /home/$SSH_USER/app
    docker-compose down || true
    docker-compose up -d --build

    # Configure Nginx reverse proxy
    sudo bash -c 'cat > /etc/nginx/sites-available/app.conf <<NGINX_CONF
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://127.0.0.1:$APP_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
NGINX_CONF'

    sudo ln -sf /etc/nginx/sites-available/app.conf /etc/nginx/sites-enabled/app.conf
    sudo nginx -t
    sudo systemctl reload nginx
EOF

# ====== COMPLETE ======
echo -e "${BLUE}=========================================${RESET}"
echo -e "${GREEN}🎉 Deployment completed successfully!${RESET}"
echo -e "🌐 Visit: ${YELLOW}http://$SERVER_IP${RESET}"
echo -e "📝 Logs saved to: ${YELLOW}$LOG_FILE${RESET}"
echo -e "${BLUE}=========================================${RESET}"
