#!/bin/bash

# Cloudflare Tunnel Setup Script for n8n
# This script helps set up separate subdomains for UI and webhooks

set -e

echo "🚀 Setting up Cloudflare Tunnel for n8n with separate subdomains..."

# Check if cloudflared is installed
if ! command -v cloudflared &> /dev/null; then
    echo "❌ cloudflared is not installed. Please install it first:"
    echo "   macOS: brew install cloudflare/cloudflare/cloudflared"
    echo "   Linux: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/"
    exit 1
fi

# Load domain from .env file if it exists
if [ -f .env ]; then
    source .env
    if [ -n "$DOMAIN" ]; then
        echo "📝 Found domain in .env: ${DOMAIN}"
    else
        echo "⚠️  DOMAIN not found in .env file"
        read -p "Enter your main domain (e.g., yourdomain.com): " DOMAIN
    fi
else
    echo "📝 No .env file found"
    read -p "Enter your main domain (e.g., yourdomain.com): " DOMAIN
fi

# Validate domain format
if [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
    echo "❌ Invalid domain format. Please enter a valid domain (e.g., example.com)"
    exit 1
fi

read -p "Enter your Cloudflare tunnel name: " TUNNEL_NAME

# Create subdomains
UI_SUBDOMAIN="n8n.${DOMAIN}"
WEBHOOK_SUBDOMAIN="webhook.${DOMAIN}"

echo "📝 Configuring subdomains:"
echo "   UI: ${UI_SUBDOMAIN}"
echo "   Webhook: ${WEBHOOK_SUBDOMAIN}"

# Create tunnel
echo "🔧 Creating Cloudflare tunnel..."
cloudflared tunnel create ${TUNNEL_NAME}

# Get tunnel ID
TUNNEL_ID=$(cloudflared tunnel list --name ${TUNNEL_NAME} --format json | jq -r '.[0].id')

echo "📋 Tunnel ID: ${TUNNEL_ID}"

# Create credentials file
CREDENTIALS_FILE="./tunnel-credentials.json"
cloudflared tunnel token ${TUNNEL_ID} > ${CREDENTIALS_FILE}

# Generate config from template
echo "📄 Generating cloudflared configuration..."

# Use sed to replace template variables
cp cloudflared-config.template.yml cloudflared-config.yml
sed -i.bak "s/{{TUNNEL_ID}}/${TUNNEL_ID}/g" cloudflared-config.yml
sed -i.bak "s/{{DOMAIN}}/${DOMAIN}/g" cloudflared-config.yml

# Create DNS records
echo "🌐 Creating DNS records..."
cloudflared tunnel route dns ${TUNNEL_NAME} ${UI_SUBDOMAIN}
cloudflared tunnel route dns ${TUNNEL_NAME} ${WEBHOOK_SUBDOMAIN}

# Create .env file from example if it doesn't exist
if [ ! -f .env ]; then
    cp env.example .env
    sed -i.bak "s/yourdomain.com/${DOMAIN}/g" .env
    echo "✅ Created .env file with your domain"
else
    # Update existing .env file with new domain
    sed -i.bak "s/^DOMAIN=.*/DOMAIN=${DOMAIN}/g" .env
    sed -i.bak "s/^N8N_HOST=.*/N8N_HOST=${UI_SUBDOMAIN}/g" .env
    sed -i.bak "s|^WEBHOOK_URL=.*|WEBHOOK_URL=https://${WEBHOOK_SUBDOMAIN}|g" .env
    echo "✅ Updated .env file with your domain"
fi

echo "🎉 Setup complete!"
echo ""
echo "Next steps:"
echo "1. Update your .env file with your authentication credentials"
echo "2. Start the tunnel: cloudflared tunnel run ${TUNNEL_NAME}"
echo "3. Start n8n: docker-compose up -d"
echo ""
echo "Your n8n will be available at:"
echo "   UI: https://${UI_SUBDOMAIN}"
echo "   Webhooks: https://${WEBHOOK_SUBDOMAIN}" 