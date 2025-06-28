# Cloudflare Tunnel Setup for n8n with Separate Subdomains

This guide explains how to set up n8n with separate subdomains for the UI and webhooks using Cloudflare tunnels.

## Overview

- **UI Subdomain**: `n8n.yourdomain.com` - Main n8n interface
- **Webhook Subdomain**: `webhook.yourdomain.com` - Webhook endpoints only

## Prerequisites

1. A domain managed by Cloudflare
2. Cloudflare account with API access
3. `cloudflared` CLI tool installed
4. `jq` command-line JSON processor

## Quick Setup

### 1. Run the Setup Script

```bash
./setup-cloudflare-tunnel.sh
```

The script will:

- Prompt for your domain (or read from existing .env)
- Create a Cloudflare tunnel
- Set up DNS records for both subdomains
- Generate the tunnel configuration from template
- Create/update your `.env` file

### 2. Obtain Tunnel Credentials File (IMPORTANT!)

After creating your tunnel, **cloudflared** will generate a credentials file in your home directory, typically at:

```
~/.cloudflared/<TUNNEL_ID>.json
```

**Copy this file to your project directory as `tunnel-credentials.json`:**

```bash
cp ~/.cloudflared/<TUNNEL_ID>.json ./tunnel-credentials.json
```

> **Note**: The credentials file is mounted into the Docker container at `/etc/cloudflared/creds/credentials.json` as configured in `docker-compose.yml`. This path is static and doesn't need to be customized.

> **Do NOT use `cloudflared tunnel token <TUNNEL_ID>` to generate this file.**
> That command outputs a base64 token, not the required JSON credentials file.

### 3. Update Environment Variables

Edit your `.env` file and set your authentication credentials:

```bash
# The script creates .env from env.example
# Just update the authentication credentials:
N8N_BASIC_AUTH_USER=your_username
N8N_BASIC_AUTH_PASSWORD=your_password
```

### 4. Configure Security (IMPORTANT!)

Set up Cloudflare Firewall Rules to prevent UI access on the webhook subdomain:

#### **Step 1: Go to Cloudflare Dashboard**

- Log into [dash.cloudflare.com](https://dash.cloudflare.com)
- Select your domain
- Go to **"Security" > "WAF" > "Firewall Rules"**

#### **Step 2: Create Firewall Rule for Main Page**

- Click **"Create Firewall Rule"**
- **Rule name**: `Block main page on webhook subdomain`
- **Field**: `Hostname`
- **Operator**: `equals`
- **Value**: `webhook.yourdomain.com`
- **Additional filters**:
  - Click **"Add filter"**
  - **Field**: `URI Path`
  - **Operator**: `equals`
  - **Value**: `/`
- **Action**: `Block`
- Click **"Deploy"**

#### **Step 3: Create Firewall Rule for Signin Page**

- Click **"Create Firewall Rule"** again
- **Rule name**: `Block signin on webhook subdomain`
- **Field**: `Hostname`
- **Operator**: `equals`
- **Value**: `webhook.yourdomain.com`
- **Additional filters**:
  - Click **"Add filter"**
  - **Field**: `URI Path`
  - **Operator**: `equals`
  - **Value**: `/signin`
- **Action**: `Block`
- Click **"Deploy"**

### 5. Start the Services

```bash
docker-compose up -d
```

## Domain Configuration

The domain is now configurable through environment variables:

```bash
# Main domain (required)
DOMAIN=yourdomain.com

# Automatically generated subdomains
N8N_HOST=n8n.${DOMAIN}
WEBHOOK_URL=https://webhook.${DOMAIN}
```

### Updating Domain

To change your domain after initial setup:

```bash
./update-domain.sh
```

This script will:

- Update the domain in `.env`
- Update the cloudflared configuration
- Provide instructions for DNS updates

## Security Configuration

### **Why This Security Setup?**

This configuration provides **layered security**:

1. **UI Protection**: `n8n.yourdomain.com` requires authentication
2. **Webhook Isolation**: `webhook.yourdomain.com` blocks all UI access
3. **Path-Based Security**: Only webhook endpoints are accessible
4. **HTTPS Everywhere**: Cloudflare provides SSL/TLS encryption

### **What Gets Blocked vs Allowed**

#### **On webhook.yourdomain.com:**

- ✅ **Allowed**: `/webhook/*`, `/webhook-test/*`, `/mcp/*`
- ❌ **Blocked**: `/` (main page), `/signin`, `/login`, `/dashboard`, and all other UI paths

#### **On n8n.yourdomain.com:**

- ✅ **Allowed**: Everything (with authentication)

### **Testing Your Security**

After setup, test these URLs:

```bash
# Should be blocked (403/404)
curl -I https://webhook.yourdomain.com/
curl -I https://webhook.yourdomain.com/signin

# Should work (200)
curl -I https://webhook.yourdomain.com/webhook/test
curl -I https://webhook.yourdomain.com/webhook-test/abc
curl -I https://webhook.yourdomain.com/mcp/def

# Should require auth
curl -I https://n8n.yourdomain.com/
```

## Manual Setup

If you prefer to set up manually or the script doesn't work:

### 1. Set Environment Variables

```bash
cp env.example .env
# Edit .env and set your domain and credentials
```

### 2. Create Tunnel

```bash
cloudflared tunnel create n8n-tunnel
```

### 3. Get Tunnel ID

```bash
cloudflared tunnel list --name n8n-tunnel --format json | jq -r '.[0].id'
```

### 4. Obtain Tunnel Credentials File

After creating the tunnel, copy the credentials file:

```bash
cp ~/.cloudflared/<TUNNEL_ID>.json ./tunnel-credentials.json
```

### 5. Generate Configuration

```bash
# Copy template and replace variables
cp cloudflared-config.template.yml cloudflared-config.yml
sed -i "s/{{TUNNEL_ID}}/<YOUR_TUNNEL_ID>/g" cloudflared-config.yml
sed -i "s/{{DOMAIN}}/$(grep DOMAIN .env | cut -d'=' -f2)/g" cloudflared-config.yml
```

### 6. Create DNS Records

```bash
source .env
cloudflared tunnel route dns n8n-tunnel n8n.${DOMAIN}
cloudflared tunnel route dns n8n-tunnel webhook.${DOMAIN}
```

## Configuration Files

### cloudflared-config.template.yml

Template file that gets processed to create the actual configuration:

```yaml
tunnel: { { TUNNEL_ID } }
credentials-file: /etc/cloudflared/creds/credentials.json

ingress:
  - hostname: n8n.{{DOMAIN}}
    service: http://n8n:5678
    originRequest:
      noTLSVerify: true

  - hostname: webhook.{{DOMAIN}}
    service: http://n8n:5678
    originRequest:
      noTLSVerify: true

  - service: http_status:404
```

### Environment Variables

In your `.env` file:

```bash
DOMAIN=yourdomain.com
N8N_HOST=n8n.${DOMAIN}
WEBHOOK_URL=https://webhook.${DOMAIN}
```

## How It Works

1. **Template Processing**: The setup script processes `cloudflared-config.template.yml` to create the actual config
2. **Environment Variables**: Domain is stored in `DOMAIN` variable and used throughout
3. **Single Tunnel**: One Cloudflare tunnel handles both subdomains
4. **Hostname Routing**: Cloudflare routes traffic based on the hostname
5. **Webhook Separation**: n8n uses the `WEBHOOK_URL` for webhook endpoints
6. **Security Layering**: Firewall Rules prevent unauthorized access

## Benefits

- **Free**: Works on all Cloudflare plans
- **Configurable**: Domain is easily changeable via environment variables
- **Template-based**: Configuration is generated from templates
- **Security**: Webhooks are isolated on a separate subdomain with login blocked
- **Simplicity**: Single tunnel to manage
- **Flexibility**: Easy to add more subdomains later
- **Cost-effective**: Uses one tunnel instead of multiple

## Troubleshooting

### Security Issues

- **Users can still access UI on webhook subdomain**

  - Check that both Firewall Rules are deployed and active
  - Verify the rules match your exact domain and paths (`/` and `/signin`)
  - Test with `curl -I https://webhook.yourdomain.com/` and `curl -I https://webhook.yourdomain.com/signin`

- **Webhooks are blocked**
  - Ensure the rules only block specific paths, not `/webhook/*`
  - Check Cloudflare logs for blocked requests
  - Verify webhook paths are not being caught by the blocking rules

### Credentials File Issues

- **Error: Invalid JSON when parsing credentials file**
  - Make sure you copied the JSON file from `~/.cloudflared/<TUNNEL_ID>.json`.
  - Do **not** use the output of `cloudflared tunnel token ...` as the credentials file.
  - The credentials file must be valid JSON, not a base64 string.

### Domain Not Working

1. Check that `DOMAIN` is set correctly in `.env`
2. Verify DNS records in Cloudflare dashboard
3. Run `./update-domain.sh` to fix configuration

### Tunnel Not Starting

1. Check credentials file exists and is readable
2. Verify tunnel ID in configuration
3. Check Cloudflare dashboard for tunnel status

### DNS Not Resolving

1. Wait 5-10 minutes for DNS propagation
2. Check DNS records in Cloudflare dashboard
3. Verify tunnel is running and healthy

### Webhooks Not Working

1. Ensure `WEBHOOK_URL` is set correctly in `.env`
2. Check that webhook subdomain is accessible
3. Verify n8n is using the correct webhook URL

## Security Considerations

- Review Cloudflare Firewall Rules regularly
- Consider additional security measures for production
- Use strong authentication credentials
- Keep tunnel credentials secure
- Regularly update cloudflared
- Monitor tunnel logs for unusual activity

## Monitoring

Check tunnel status:

```bash
cloudflared tunnel info n8n-tunnel
```

View tunnel logs:

Check Firewall Rule activity in Cloudflare dashboard:

- Go to **"Security" > "WAF" > "Firewall Rules"**
- Click on your rule to see activity logs

```bash
docker-compose logs cloudflared
```

## File Structure

```
n8n-test/
├── .env                          # Environment variables (generated)
├── env.example                   # Environment template
├── docker-compose.yml            # Docker services
├── cloudflared-config.template.yml  # Template for tunnel config
├── cloudflared-config.yml        # Generated tunnel config
├── tunnel-credentials.json       # Tunnel credentials (copied from ~/.cloudflared/)
├── setup-cloudflare-tunnel.sh    # Initial setup script
├── update-domain.sh              # Domain update script
└── CLOUDFLARE_SETUP.md           # This documentation
```
