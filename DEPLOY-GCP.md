# GCP Deployment Guide for vid2story

This guide provides step-by-step instructions for deploying the vid2story application to a Google Cloud Platform (GCP) Ubuntu VM with GPU support.

## Prerequisites

- GCP account with billing enabled
- `gcloud` CLI installed and configured ([Installation Guide](https://cloud.google.com/sdk/docs/install))
- SSH key configured for GCP
- Basic understanding of Linux command line

## Quick Start

```bash
# 1. Create GPU VM
gcloud compute instances create vid2story-vm \
  --project=YOUR_PROJECT_ID \
  --zone=us-west1-b \
  --machine-type=n1-standard-8 \
  --accelerator=type=nvidia-tesla-t4,count=1 \
  --image-family=ubuntu-2404-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=50GB \
  --boot-disk-type=pd-balanced \
  --create-disk=size=500GB,type=pd-balanced,auto-delete=yes \
  --maintenance-policy=TERMINATE \
  --tags=http-server,https-server

# 2. Configure firewall
gcloud compute firewall-rules create allow-http-https \
  --allow=tcp:80,tcp:443 \
  --target-tags=http-server,https-server

# 3. SSH into VM
gcloud compute ssh vid2story-vm --zone=us-west1-b

# 4. Run deployment script
curl -O https://raw.githubusercontent.com/newpress-media/vid2story/main/deploy-gcp.sh
chmod +x deploy-gcp.sh
./deploy-gcp.sh
```

## Detailed Setup

### 1. VM Configuration Options

#### GPU VM (Recommended)
For optimal performance with GPU acceleration:

```bash
gcloud compute instances create vid2story-vm \
  --project=YOUR_PROJECT_ID \
  --zone=us-west1-b \
  --machine-type=n1-standard-8 \
  --accelerator=type=nvidia-tesla-t4,count=1 \
  --image-family=ubuntu-2404-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=50GB \
  --boot-disk-type=pd-balanced \
  --create-disk=size=500GB,type=pd-balanced,auto-delete=yes \
  --maintenance-policy=TERMINATE \
  --metadata=startup-script='#!/bin/bash
echo "GCP_GPU=true" >> /etc/environment' \
  --tags=http-server,https-server
```

**GPU Specs:**
- Machine: n1-standard-8 (8 vCPUs, 30GB RAM)
- GPU: NVIDIA Tesla T4 (16GB)
- Boot disk: 50GB
- Data disk: 500GB

#### CPU-Only VM (For Testing)
If GPU quota is unavailable:

```bash
gcloud compute instances create vid2story-vm-cpu \
  --project=YOUR_PROJECT_ID \
  --zone=us-west1-b \
  --machine-type=n1-standard-4 \
  --image-family=ubuntu-2404-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=50GB \
  --boot-disk-type=pd-balanced \
  --create-disk=size=500GB,type=pd-balanced,auto-delete=yes \
  --tags=http-server,https-server
```

### 2. GPU Quota Considerations

GCP free tier and new accounts have GPU restrictions:

**Check your GPU quota:**
```bash
gcloud compute project-info describe --project=YOUR_PROJECT_ID
```

**Request quota increase:**
1. Go to [GCP Quotas](https://console.cloud.google.com/iam-admin/quotas)
2. Search for "GPUs (all regions)" or "NVIDIA T4 GPUs"
3. Select quota → Click "EDIT QUOTAS"
4. Request increase to at least 1
5. Provide justification: "Video processing application requiring GPU acceleration"

**GPU Availability by Region:**
- `us-west1` (Oregon) - Good T4 availability
- `us-central1` (Iowa) - Good T4 availability  
- `us-east1` (South Carolina) - Good T4 availability
- Check current availability: [GCP GPU Regions](https://cloud.google.com/compute/docs/gpus/gpu-regions-zones)

### 3. Firewall Configuration

Create firewall rules for HTTP/HTTPS:

```bash
# Allow HTTP and HTTPS traffic
gcloud compute firewall-rules create allow-http-https \
  --project=YOUR_PROJECT_ID \
  --allow=tcp:80,tcp:443 \
  --target-tags=http-server,https-server \
  --description="Allow HTTP and HTTPS traffic"

# Verify firewall rules
gcloud compute firewall-rules list
```

### 4. Static IP (Optional but Recommended)

Reserve a static external IP:

```bash
# Reserve static IP
gcloud compute addresses create vid2story-ip \
  --region=us-west1

# Get the IP address
gcloud compute addresses describe vid2story-ip \
  --region=us-west1 \
  --format="get(address)"

# Attach to VM
gcloud compute instances delete-access-config vid2story-vm \
  --access-config-name="external-nat" \
  --zone=us-west1-b

gcloud compute instances add-access-config vid2story-vm \
  --access-config-name="external-nat" \
  --address=vid2story-ip \
  --zone=us-west1-b
```

### 5. SSH Access

```bash
# SSH into VM
gcloud compute ssh vid2story-vm --zone=us-west1-b

# Or use standard SSH with external IP
ssh username@EXTERNAL_IP
```

### 6. Run Deployment Script

Once SSH'd into the VM:

```bash
# Download deployment script
curl -O https://raw.githubusercontent.com/newpress-media/vid2story/main/deploy-gcp.sh
chmod +x deploy-gcp.sh

# Run deployment
./deploy-gcp.sh
```

The script will:
1. Update system packages
2. Install dependencies (Node.js, Rust, FFmpeg, etc.)
3. Install NVIDIA drivers (if GPU VM)
4. Install CUDA, cuDNN, TensorRT (if GPU VM)
5. Build land2port with GPU support
6. Clone and build vid2story application
7. Configure PM2 and Nginx
8. Start the application

**For GPU VMs:** The script will prompt for a reboot after NVIDIA driver installation.

### 7. Post-Deployment Configuration

After deployment completes:

```bash
cd ~/datadrive/vid2story

# Configure environment
cp .env.example .env
nano .env
```

Update these values in `.env`:

```bash
NODE_ENV=production
PORT=3000

# OpenAI API key for transcription
OPENAI_API_KEY=your-openai-api-key-here

# Database path
DATABASE_PATH=/home/YOUR_USERNAME/datadrive/vid2story/data/sqlite.db

# Uploads directory
UPLOADS_DIR=/home/YOUR_USERNAME/datadrive/vid2story/public/uploads

# Public URL
BASE_URL=http://YOUR_EXTERNAL_IP

# Land2port configuration
LAND2PORT_PATH=/home/YOUR_USERNAME/datadrive/land2port/target/release/land2port

# Device: "cuda" for GPU VMs, "cpu" for non-GPU VMs
LAND2PORT_DEVICE="cuda"  # or "cpu" for CPU-only VMs
```

Run database migrations:

```bash
pnpm db:migrate
```

Restart the application:

```bash
export NVM_DIR="$HOME/.nvm"
source "$NVM_DIR/nvm.sh"
pm2 restart all --update-env
```

### 8. Verify Deployment

Check application status:

```bash
pm2 status
pm2 logs
```

For GPU VMs, verify GPU is detected:

```bash
nvidia-smi
```

Access the application:

```
http://YOUR_EXTERNAL_IP
```

### 9. SSL Certificate (Optional)

Set up HTTPS with Let's Encrypt:

```bash
# Install certbot
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot

# Get certificate (requires domain name)
sudo certbot --nginx -d yourdomain.com

# Auto-renewal is configured automatically
sudo certbot renew --dry-run
```

## VM Management

### Start VM
```bash
gcloud compute instances start vid2story-vm --zone=us-west1-b
```

### Stop VM
```bash
gcloud compute instances stop vid2story-vm --zone=us-west1-b
```

### Delete VM
```bash
gcloud compute instances delete vid2story-vm --zone=us-west1-b
```

### Resize VM
```bash
# Stop VM first
gcloud compute instances stop vid2story-vm --zone=us-west1-b

# Change machine type
gcloud compute instances set-machine-type vid2story-vm \
  --machine-type=n1-standard-16 \
  --zone=us-west1-b

# Start VM
gcloud compute instances start vid2story-vm --zone=us-west1-b
```

## Monitoring and Logs

### View Application Logs
```bash
# SSH into VM
gcloud compute ssh vid2story-vm --zone=us-west1-b

# View PM2 logs
export NVM_DIR="$HOME/.nvm"
source "$NVM_DIR/nvm.sh"
pm2 logs

# Monitor in real-time
pm2 monit
```

### Check System Resources
```bash
# CPU and memory
htop

# GPU usage (GPU VMs only)
watch -n 1 nvidia-smi

# Disk usage
df -h
```

### GCP Console Monitoring
- Navigate to [Compute Engine → VM Instances](https://console.cloud.google.com/compute/instances)
- Click on your VM
- View monitoring metrics (CPU, disk, network)

## Troubleshooting

### GPU Not Detected

If `nvidia-smi` shows errors:

1. Verify GPU VM was created with `--accelerator` flag
2. Check NVIDIA driver installation:
   ```bash
   sudo apt list --installed | grep nvidia
   ```
3. Reinstall drivers:
   ```bash
   sudo apt-get purge nvidia-*
   sudo apt-get autoremove
   # Re-run GPU sections of deploy-gcp.sh
   ```

### Application Won't Start

Check logs:
```bash
pm2 logs --lines 100
pm2 describe vid2story
```

Common issues:
- Database path incorrect
- Node.js not in PATH (source nvm)
- Port 3000 already in use
- Missing .env configuration

### Out of Disk Space

Check disk usage:
```bash
df -h
du -sh ~/datadrive/vid2story/public/generated/*
```

Clean up old jobs:
```bash
# Remove old video files
cd ~/datadrive/vid2story
node scripts/cleanup-old-jobs.js
```

Or resize disk:
```bash
gcloud compute disks resize vid2story-vm \
  --size=1000GB \
  --zone=us-west1-b

# Then expand filesystem
sudo resize2fs /dev/sdb
```

### SSL Certificate Issues

```bash
# Check nginx configuration
sudo nginx -t

# Restart nginx
sudo systemctl restart nginx

# Check certbot logs
sudo tail -f /var/log/letsencrypt/letsencrypt.log
```

## Cost Optimization

### Committed Use Discounts
Consider [committed use discounts](https://cloud.google.com/compute/docs/instances/committed-use-discounts-overview) for long-term deployments (1 or 3 year commitment).

### Preemptible VMs
For non-production workloads:
```bash
gcloud compute instances create vid2story-preemptible \
  --preemptible \
  --machine-type=n1-standard-8 \
  --accelerator=type=nvidia-tesla-t4,count=1 \
  --zone=us-west1-b
```

**Warning:** Preemptible VMs can be shut down at any time by GCP.

### Stop When Not in Use
Stop the VM when not processing videos:
```bash
gcloud compute instances stop vid2story-vm --zone=us-west1-b
```

You only pay for storage when stopped, not compute.

## Backup and Recovery

### Backup Data Disk

Create disk snapshot:
```bash
gcloud compute disks snapshot vid2story-vm-data \
  --snapshot-names=vid2story-backup-$(date +%Y%m%d) \
  --zone=us-west1-b
```

### Restore from Snapshot

```bash
gcloud compute disks create vid2story-vm-data-restored \
  --source-snapshot=vid2story-backup-YYYYMMDD \
  --zone=us-west1-b

# Attach to VM
gcloud compute instances attach-disk vid2story-vm \
  --disk=vid2story-vm-data-restored \
  --zone=us-west1-b
```

### Database Backup

```bash
# Copy database file
cp ~/datadrive/vid2story/data/sqlite.db ~/backups/sqlite-$(date +%Y%m%d).db

# Upload to Cloud Storage
gsutil cp ~/datadrive/vid2story/data/sqlite.db gs://your-bucket/backups/
```

## Migration from Azure

If migrating from an existing Azure deployment:

1. Backup your Azure data:
   ```bash
   # On Azure VM
   tar -czf vid2story-backup.tar.gz ~/datadrive/vid2story/data/
   ```

2. Transfer to GCP:
   ```bash
   # Download from Azure
   scp azureuser@azure-ip:~/vid2story-backup.tar.gz .
   
   # Upload to GCP
   gcloud compute scp vid2story-backup.tar.gz vid2story-vm:~ --zone=us-west1-b
   ```

3. Restore on GCP:
   ```bash
   # On GCP VM
   tar -xzf vid2story-backup.tar.gz
   ```

## Performance Benchmarks

Expected processing times with GPU (T4):

| Video Length | Portrait Conversion | Transcription | Total Time |
|--------------|-------------------|---------------|------------|
| 1 min        | 1-2 min           | 10-20 sec     | ~2 min     |
| 5 min        | 3-5 min           | 30-60 sec     | ~5 min     |
| 10 min       | 5-8 min           | 1-2 min       | ~8 min     |

CPU-only processing is **10-20x slower**.

## Additional Resources

- [GCP Compute Engine Docs](https://cloud.google.com/compute/docs)
- [GCP GPU Documentation](https://cloud.google.com/compute/docs/gpus)
- [GCP Pricing Calculator](https://cloud.google.com/products/calculator)
- [vid2story GitHub Repository](https://github.com/newpress-media/vid2story)

## Support

For issues specific to:
- **GCP infrastructure**: [GCP Support](https://cloud.google.com/support)
- **vid2story application**: [GitHub Issues](https://github.com/newpress-media/vid2story/issues)
