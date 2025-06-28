#!/bin/bash

# Update Domain Script for n8n Cloudflare Tunnel
# This script updates the domain in existing configurations

set -e

echo "🔄 Updating domain configuration..."

# Check if .env exists
if [ ! -f .env ]; then
    echo "❌ .env file not found. Please run setup-cloudflare-tunnel.sh first."
    exit 1
fi

# Load current domain
source .env
if [ -n "$DOMAIN" ]; then
    echo "📝 Current domain: ${DOMAIN}"
else
    echo "❌ DOMAIN not found in .env file"
    exit 1
fi

# Get new domain
read -p "Enter new domain (e.g., newdomain.com): " NEW_DOMAIN

# Validate domain format
if [[ ! "$NEW_DOMAIN" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
    echo "❌ Invalid domain format. Please enter a valid domain (e.g., example.com)"
    exit 1
fi

# Create new subdomains
NEW_UI_SUBDOMAIN="n8n.${NEW_DOMAIN}"
NEW_WEBHOOK_SUBDOMAIN="webhook.${NEW_DOMAIN}"

echo "📝 New subdomains:"
echo "   UI: ${NEW_UI_SUBDOMAIN}"
echo "   Webhook: ${NEW_WEBHOOK_SUBDOMAIN}"

# Update .env file
sed -i.bak "s/^DOMAIN=.*/DOMAIN=${NEW_DOMAIN}/g" .env
sed -i.bak "s/^N8N_HOST=.*/N8N_HOST=${NEW_UI_SUBDOMAIN}/g" .env
sed -i.bak "s|^WEBHOOK_URL=.*|WEBHOOK_URL=https://${NEW_WEBHOOK_SUBDOMAIN}|g" .env

# Update cloudflared config if it exists
if [ -f cloudflared-config.yml ]; then
    echo "📄 Updating cloudflared configuration..."
    sed -i.bak "s/${DOMAIN}/${NEW_DOMAIN}/g" cloudflared-config.yml
    echo "✅ Updated cloudflared-config.yml"
fi

echo "🎉 Domain updated successfully!"
echo ""
echo "Next steps:"
echo "1. Update your DNS records in Cloudflare dashboard"
echo "2. Restart the tunnel: docker-compose restart cloudflared"
echo "3. Restart n8n: docker-compose restart n8n"
echo ""
echo "Your n8n will now be available at:"
echo "   UI: https://${NEW_UI_SUBDOMAIN}"
echo "   Webhooks: https://${NEW_WEBHOOK_SUBDOMAIN}" 