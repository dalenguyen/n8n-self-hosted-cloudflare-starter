# n8n Self-Hosted AI Agent Workflows Starter Template

A starter template for self-hosting **n8n** — a powerful workflow automation tool — using **Docker** and **Cloudflare Tunnel**. This setup enables you to expose your local n8n instance securely to the internet without complex firewall or port forwarding configurations.

## 🚀 Why Self-Host n8n with Cloudflare Tunnel?

- **💰 Cost-effective:** No monthly hosting fees beyond your own hardware and electricity
- **🔒 Secure:** Cloudflare Tunnel creates encrypted tunnels, hiding your server behind Cloudflare's network
- **🌐 Accessible:** Access your workflows remotely from anywhere with a custom domain
- **🔧 Flexible:** Run on any always-on device like a Raspberry Pi, old laptop, or home server
- **🤖 AI-Ready:** Perfect foundation for building AI agent workflows with local AI tools

## 📋 Prerequisites

- An always-on device (e.g., Raspberry Pi, old PC, home server)
- Docker and Docker Compose installed
- A free Cloudflare account
- A domain name managed by Cloudflare (can be purchased cheaply)
- Basic familiarity with command line and Docker

## 🏗️ Project Structure

```
n8n-self-hosted-cloudflare-starter/
├── docker-compose.yml      # Docker configuration for n8n
├── env.example             # Example environment variables
├── .env                    # Environment variables (create this)
├── .gitignore             # Git ignore rules
├── n8n_data/              # n8n data directory (auto-created)
│   ├── binaryData/        # Binary data storage
│   └── nodes/             # Custom nodes
└── README.md              # This file
```

## ⚙️ Quick Setup

### 1. Clone and Configure

```bash
# Clone this repository
git clone https://github.com/dalenguyen/n8n-self-hosted-cloudflare-starter.git
cd n8n-self-hosted-cloudflare-starter

# Create environment file
cp env.example .env
```

### 2. Configure Environment Variables

Edit the `.env` file with your credentials:

```dotenv
# .env
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=your_super_secret_password
```

> **⚠️ Important:** Add `.env` to your `.gitignore` file to prevent committing secrets.

### 3. Update Domain Configuration

Edit `docker-compose.yml` and replace the domain placeholders:

```yaml
environment:
  - N8N_HOST=your-subdomain.your-domain.com
  - WEBHOOK_URL=https://your-subdomain.your-domain.com
```

### 4. Start n8n

```bash
docker-compose up -d
```

n8n will be available locally at `http://localhost:5678`

## 🌐 Cloudflare Tunnel Setup

### 1. Install cloudflared

```bash
# macOS
brew install cloudflared

# Windows
winget install --id Cloudflare.cloudflared

# Linux (Debian/Ubuntu)
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o cloudflared.deb
sudo dpkg -i cloudflared.deb
```

### 2. Authenticate with Cloudflare

```bash
cloudflared login
```

This opens a browser to authorize your Cloudflare account.

### 3. Create and Configure Tunnel

```bash
# Create tunnel
cloudflared tunnel create n8n-tunnel

# Configure DNS
cloudflared tunnel route dns n8n-tunnel your-subdomain.your-domain.com

# Run tunnel
cloudflared tunnel run n8n-tunnel --url http://localhost:5678
```

### 4. Access Your n8n Instance

Visit `https://your-subdomain.your-domain.com` to access your n8n workflow editor.

## 🔒 Security Best Practices

1. **Keep basic auth enabled** in n8n for an extra security layer
2. **Use strong passwords** for your n8n admin account
3. **Enable Cloudflare Zero Trust Access** policies to restrict who can access your n8n UI
4. **Separate webhook URLs and UI access** with different hostnames for better security
5. **Regularly update** your Docker images and cloudflared

## 💾 Backup and Maintenance

### Automated Backup Script

Create a backup script (`backup.sh`):

```bash
#!/bin/bash
TIMESTAMP=$(date +"%Y%m%d")
tar -czf n8n_backup_$TIMESTAMP.tar.gz ./n8n_data
# Keep only last 7 backups
ls -tp | grep -v '/$' | tail -n +8 | xargs -I {} rm -- {}
```

### Schedule Backups with Cron

```bash
# Edit crontab
crontab -e

# Add daily backup at 2:00 AM
0 2 * * * /path/to/your/backup_script.sh
```

### Restore from Backup

```bash
# Stop n8n
docker-compose down

# Backup current data
mv ./n8n_data ./n8n_data_old

# Extract backup
tar -xzf n8n_backup_YYYYMMDD.tar.gz

# Restart n8n
docker-compose up -d
```

## 🤖 AI Agent Workflows

This template is perfect for building AI agent workflows. You can extend it with:

- **Self-hosted AI Starter Kit** by n8n (bundles with Ollama and Qdrant)
- **Local AI tools** like Ollama for privacy-conscious AI processing
- **Vector databases** for document processing and retrieval
- **Custom AI workflows** for scheduling, summarization, and chatbots

## 🛠️ Troubleshooting

### Common Issues

1. **Port already in use**: Change the port in `docker-compose.yml`
2. **Permission denied**: Ensure Docker has proper permissions
3. **Tunnel connection failed**: Check cloudflared authentication and DNS configuration
4. **Data persistence issues**: Verify volume mounting in `docker-compose.yml`

### Useful Commands

```bash
# View logs
docker-compose logs -f n8n

# Restart services
docker-compose restart

# Update n8n image
docker-compose pull && docker-compose up -d

# Check tunnel status
cloudflared tunnel list
```

## 📚 Resources

- [n8n Documentation](https://docs.n8n.io/)
- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [Original Blog Post](https://dalenguyen.me/blog/2025-06-21-n8n-free-self-hosted-ai-agents-with-cloudflare-tunnel)

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

---

**Happy workflow automation! 🚀**
