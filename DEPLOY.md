# Azure Deployment Guide for vid2story

This guide provides step-by-step instructions for deploying the vid2story application to an Azure Ubuntu VM with GPU support.

## Prerequisites

- Azure account with active subscription
- SSH client (terminal on macOS/Linux, PuTTY on Windows)
- OpenAI API key for video transcription and processing

## Quick Start

For a fully automated deployment (CPU-only), SSH into your Azure VM and run:

```bash
curl -fsSL https://raw.githubusercontent.com/newpress-media/vid2story/main/deploy.sh | bash
```

For GPU support, see the detailed steps below.

## Detailed Deployment Steps

### 1. Provision Azure VM

#### Option A: Using Azure Portal

1. Go to Azure Portal → Virtual Machines → Create
2. **Basics**:
   - Resource Group: Create new or use existing
   - VM Name: `vid2story-vm`
   - Region: Choose your preferred region (e.g., East US)
   - Image: `Ubuntu 24.04 LTS`
   - Size: 
     - For GPU support: `Standard NC8as T4 v3` (8 vCPUs, 56 GiB RAM, NVIDIA T4 GPU)
     - For CPU-only: `Standard D4s v3` or larger (4+ vCPUs, 16+ GiB RAM)
   - Authentication: SSH public key (recommended) or password

3. **Disks**:
   - OS disk: Premium SSD (128 GB minimum)
   - Add data disk: 1 TB+ Premium SSD for video storage and processing
   - Enable "Delete with VM" for easier cleanup

4. **Networking**:
   - Create new virtual network or use existing
   - Public IP: Create new (Static recommended)
   - NIC NSG: Basic
   - Inbound ports: 22 (SSH), 80 (HTTP), 443 (HTTPS)
   - Optionally configure DNS name: `vid2story-yourname.eastus.cloudapp.azure.com`

5. **Review + Create** → Create

#### Option B: Using Azure CLI

```bash
# Create resource group
az group create --name vid2story-rg --location eastus

# Create VM with GPU
az vm create \
  --resource-group vid2story-rg \
  --name vid2story-vm \
  --image Ubuntu2404 \
  --size Standard_NC8as_T4_v3 \
  --admin-username azureuser \
  --generate-ssh-keys \
  --public-ip-sku Standard \
  --nsg-rule SSH

# Add data disk (1 TB)
az vm disk attach \
  --resource-group vid2story-rg \
  --vm-name vid2story-vm \
  --name vid2story-data-disk \
  --new \
  --size-gb 1024 \
  --sku Premium_LRS

# Open HTTP and HTTPS ports
az vm open-port --port 80 --resource-group vid2story-rg --name vid2story-vm --priority 1001
az vm open-port --port 443 --resource-group vid2story-rg --name vid2story-vm --priority 1002

# Configure DNS name (optional)
az network public-ip update \
  --resource-group vid2story-rg \
  --name vid2story-vmPublicIP \
  --dns-name vid2story-yourname
```

### 2. Connect to VM

Get your VM's public IP address:

```bash
az vm show -d -g vid2story-rg -n vid2story-vm --query publicIps -o tsv
```

SSH into the VM:

```bash
ssh azureuser@<your-vm-ip-or-dns-name>
```

### 3. Run Deployment Script

Clone the repository and run the deployment script:

```bash
# Clone the repository
git clone https://github.com/newpress-media/vid2story.git
cd vid2story

# Make the deployment script executable
chmod +x deploy.sh

# Run the deployment script
./deploy.sh
```

**Note**: The script will:
- Install system dependencies
- Set up the data drive at `/datadrive`
- Install Rust and build land2port
- Install Node.js and deploy the application
- Set up PM2 process manager
- Configure Nginx reverse proxy

For GPU VMs, you'll need to uncomment and run the NVIDIA/CUDA installation sections (see below).

### 4. GPU Setup (For NC-Series VMs Only)

If you're using a GPU VM like `Standard NC8as T4 v3`, uncomment the GPU sections in `deploy.sh`:

1. Edit the deployment script:
   ```bash
   nano deploy.sh
   ```

2. Uncomment these sections:
   - Step 2: NVIDIA Driver Setup
   - Step 3: CUDA, CUDNN, and TensorRT Installation

3. Run the script - it will install drivers and reboot:
   ```bash
   ./deploy.sh
   ```

4. After reboot, verify GPU is detected:
   ```bash
   nvidia-smi
   ```

5. Re-run the script to complete remaining steps:
   ```bash
   cd /datadrive/vid2story
   ./deploy.sh
   ```

### 5. Configure Environment Variables

Edit the `.env` file with your settings:

```bash
cd /datadrive/vid2story
nano .env
```

Update these critical values:

```bash
# Production environment
NODE_ENV=production

# Your OpenAI API key (required)
OPENAI_API_KEY=sk-your-actual-openai-api-key-here

# Your VM's public URL
BASE_URL=http://vid2story-yourname.eastus.cloudapp.azure.com

# land2port path (auto-configured by deploy.sh)
LAND2PORT_PATH="/datadrive/land2port"

# Device: "cuda" for GPU VMs, "cpu" for non-GPU VMs
LAND2PORT_DEVICE="cuda"
```

Save and exit (Ctrl+X, Y, Enter).

### 6. Configure Nginx

Update the server name in the Nginx configuration:

```bash
sudo nano /etc/nginx/sites-available/vid2story.conf
```

Change `server_name` to match your VM's DNS name or IP:

```nginx
server_name vid2story-yourname.eastus.cloudapp.azure.com;
# or
server_name 20.123.45.67;  # Your VM's public IP
```

Test and reload Nginx:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

### 7. Start the Application

Restart the application with updated configuration:

```bash
cd /datadrive/vid2story
pm2 restart all
pm2 logs  # Check for any errors
```

### 8. Set Up SSL (Recommended)

Secure your application with Let's Encrypt SSL certificate:

```bash
# Install Certbot
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot

# Obtain and install SSL certificate
sudo certbot --nginx
```

Follow the prompts to configure SSL. Certbot will automatically update your Nginx configuration.

### 9. Verify Deployment

Test your deployment:

1. **HTTP Access**: Visit `http://your-vm-dns-name.eastus.cloudapp.azure.com`
2. **HTTPS Access** (if SSL configured): `https://your-vm-dns-name.eastus.cloudapp.azure.com`
3. **Upload Test**: Try uploading a small video file

## Useful Commands

### Application Management

```bash
# Check application status
pm2 status

# View logs
pm2 logs

# Restart application
pm2 restart vid2story

# Stop application
pm2 stop vid2story

# View detailed info
pm2 show vid2story
```

### Nginx Management

```bash
# Test configuration
sudo nginx -t

# Reload configuration
sudo systemctl reload nginx

# Restart Nginx
sudo systemctl restart nginx

# View access logs
sudo tail -f /var/log/nginx/vid2story-access.log

# View error logs
sudo tail -f /var/log/nginx/vid2story-error.log
```

### System Monitoring

```bash
# Check disk usage
df -h

# Check memory usage
free -h

# Check GPU usage (GPU VMs only)
nvidia-smi

# Check running processes
htop
```

### Application Updates

To update the application:

```bash
cd /datadrive/vid2story
git pull
pnpm install
pnpm build
pnpm db:migrate
pm2 restart all
```

## Troubleshooting

### Application won't start

1. Check PM2 logs:
   ```bash
   pm2 logs --err
   ```

2. Verify environment variables:
   ```bash
   cat /datadrive/vid2story/.env
   ```

3. Check if port 3000 is available:
   ```bash
   sudo netstat -tulpn | grep 3000
   ```

### Can't access via browser

1. Verify Nginx is running:
   ```bash
   sudo systemctl status nginx
   ```

2. Check Nginx error logs:
   ```bash
   sudo tail -50 /var/log/nginx/vid2story-error.log
   ```

3. Verify firewall rules in Azure NSG allow ports 80/443

4. Test local connectivity:
   ```bash
   curl http://localhost
   ```

### Database errors

1. Check if data directory exists:
   ```bash
   ls -la /datadrive/vid2story/data/
   ```

2. Verify permissions:
   ```bash
   sudo chown -R azureuser:azureuser /datadrive/vid2story
   ```

3. Re-run migrations:
   ```bash
   cd /datadrive/vid2story
   pnpm db:migrate
   ```

### GPU not detected

1. Verify driver installation:
   ```bash
   nvidia-smi
   ```

2. Check CUDA installation:
   ```bash
   nvcc --version
   ```

3. Reinstall drivers if needed (see [vm.md](vm.md))

### Disk space issues

1. Check disk usage:
   ```bash
   df -h
   ```

2. Clean up old uploads if needed:
   ```bash
   cd /datadrive/vid2story/uploads
   # Review and delete old files
   ```

3. Clear PM2 logs:
   ```bash
   pm2 flush
   ```

## Maintenance

### Regular Backups

Back up critical data regularly:

```bash
# Backup database
cp /datadrive/vid2story/data/sqlite.db ~/backups/sqlite-$(date +%Y%m%d).db

# Backup .env file
cp /datadrive/vid2story/.env ~/backups/env-$(date +%Y%m%d).backup
```

### System Updates

Keep the system updated:

```bash
sudo apt update
sudo apt upgrade -y
```

### Log Rotation

PM2 handles log rotation automatically. For Nginx logs:

```bash
sudo logrotate -f /etc/logrotate.d/nginx
```

### Monitoring

Consider setting up Azure Monitor or Application Insights for production monitoring.

## Security Best Practices

1. **SSH Key Only**: Disable password authentication in `/etc/ssh/sshd_config`
2. **Firewall**: Use Azure NSG to restrict access
3. **Updates**: Keep system and dependencies updated
4. **Secrets**: Never commit `.env` file to git
5. **SSL**: Always use HTTPS in production
6. **Backups**: Regular automated backups
7. **Monitoring**: Set up alerts for high CPU/memory/disk usage

## Cost Optimization

- **Auto-shutdown**: Configure VM to shut down during off-hours
- **Reserved Instances**: Save up to 72% with 1-year or 3-year reservations
- **Right-size**: Monitor resource usage and adjust VM size as needed
- **Spot VMs**: Use Azure Spot VMs for non-production environments

## Additional Resources

- [Azure VM Documentation](https://docs.microsoft.com/azure/virtual-machines/)
- [PM2 Documentation](https://pm2.keymetrics.io/docs/usage/quick-start/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Let's Encrypt](https://letsencrypt.org/)

## Support

For issues specific to vid2story, see the main repository:
https://github.com/newpress-media/vid2story
