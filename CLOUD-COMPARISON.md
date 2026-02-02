# Azure vs GCP Deployment Quick Reference

This document provides a side-by-side comparison of deploying vid2story on Azure vs GCP.

## Quick Command Comparison

| Task | Azure | GCP |
|------|-------|-----|
| **Create GPU VM** | `az vm create --name vid2story-vm --resource-group vid2story-rg --size Standard_NC8as_T4_v3` | `gcloud compute instances create vid2story-vm --machine-type=n1-standard-8 --accelerator=type=nvidia-tesla-t4,count=1` |
| **Create CPU VM** | `az vm create --name vid2story-vm --resource-group vid2story-rg --size Standard_D4s_v3` | `gcloud compute instances create vid2story-vm --machine-type=n1-standard-4` |
| **Open Firewall** | `az network nsg rule create --nsg-name vid2story-nsg --name allow-http-https` | `gcloud compute firewall-rules create allow-http-https --allow=tcp:80,tcp:443` |
| **SSH Access** | `ssh azureuser@vid2story.region.cloudapp.azure.com` | `gcloud compute ssh vid2story-vm --zone=us-west1-b` |
| **Start VM** | `az vm start --name vid2story-vm --resource-group vid2story-rg` | `gcloud compute instances start vid2story-vm --zone=us-west1-b` |
| **Stop VM** | `az vm stop --name vid2story-vm --resource-group vid2story-rg` | `gcloud compute instances stop vid2story-vm --zone=us-west1-b` |
| **Delete VM** | `az vm delete --name vid2story-vm --resource-group vid2story-rg` | `gcloud compute instances delete vid2story-vm --zone=us-west1-b` |

## VM Size Comparison

### GPU Options

| Azure | GCP | vCPUs | RAM | GPU | Notes |
|-------|-----|-------|-----|-----|-------|
| Standard_NC8as_T4_v3 | n1-standard-8 + T4 | 8 | 30-56GB | NVIDIA T4 | Recommended for production |
| Standard_NC6s_v3 | n1-standard-4 + T4 | 6 | 112GB | Tesla V100 | Higher memory option |

### CPU Options

| Azure | GCP | vCPUs | RAM | Notes |
|-------|-----|-------|-----|-------|
| Standard_D4s_v3 | n1-standard-4 | 4 | 16GB | Budget option for testing |
| Standard_D8s_v3 | n1-standard-8 | 8 | 32GB | Better for CPU processing |

## Pricing Comparison (Approximate)

Prices vary by region and commitment. These are rough estimates:

### GPU VMs (per hour)

| Configuration | Azure | GCP | GCP with 1-yr commitment |
|--------------|-------|-----|--------------------------|
| 8 vCPU + T4 GPU | ~$0.90/hr | ~$0.80/hr | ~$0.50/hr |
| Storage (500GB) | ~$0.05/hr | ~$0.04/hr | Same |

### CPU VMs (per hour)

| Configuration | Azure | GCP | GCP with 1-yr commitment |
|--------------|-------|-----|--------------------------|
| 4 vCPU, 16GB RAM | ~$0.20/hr | ~$0.19/hr | ~$0.13/hr |

**Monthly estimates (24/7 operation):**
- GPU VM: ~$650/month (Azure), ~$580/month (GCP), ~$365/month (GCP committed)
- CPU VM: ~$145/month (Azure), ~$137/month (GCP), ~$94/month (GCP committed)

## Key Differences

### Disk Configuration

**Azure:**
- Boot disk: `/dev/sda`
- Data disk: `/dev/sdc`
- Requires explicit disk attachment

**GCP:**
- Boot disk: `/dev/sda`
- Data disk: `/dev/sdb`
- Can be added at VM creation with `--create-disk`

### Networking

**Azure:**
- Network Security Groups (NSGs)
- Public IP auto-assigned
- DNS: `vmname.region.cloudapp.azure.com`

**GCP:**
- Firewall rules with tags
- External IP ephemeral by default
- DNS: Must configure Cloud DNS or use IP

### GPU Quotas

**Azure Free Trial:**
- Default: 4 CPU cores in most regions
- GPU quota: Usually 0, requires upgrade

**GCP Free Trial:**
- Default: 8 CPU cores in most regions
- GPU quota: Usually 0, requires request
- $300 free credits for 90 days

## Deployment Scripts

### Azure
- Guide: [DEPLOY.md](DEPLOY.md)
- Script: [deploy.sh](deploy.sh)
- DNS Pattern: `vmname.region.cloudapp.azure.com`

### GCP
- Guide: [DEPLOY-GCP.md](DEPLOY-GCP.md)
- Script: [deploy-gcp.sh](deploy-gcp.sh)
- IP-based access by default

## Regional Availability

### GPU Regions

**Azure T4 Availability:**
- East US
- West US 2
- West Europe
- Southeast Asia

**GCP T4 Availability:**
- us-west1 (Oregon)
- us-central1 (Iowa)
- us-east1 (South Carolina)
- europe-west1 (Belgium)
- asia-southeast1 (Singapore)

Check current availability:
- Azure: [VM sizes by region](https://azure.microsoft.com/en-us/explore/global-infrastructure/products-by-region/)
- GCP: [GPU regions](https://cloud.google.com/compute/docs/gpus/gpu-regions-zones)

## Quota Request Process

### Azure
1. Portal → Subscriptions → Usage + quotas
2. Search for "Standard NCASv3_T4 Family vCPUs"
3. Request increase
4. Wait 1-5 business days

### GCP
1. Console → IAM & Admin → Quotas
2. Search for "NVIDIA T4 GPUs" or "GPUs (all regions)"
3. Request increase
4. Provide justification
5. Wait 1-3 business days

## Best Practices

### When to Use Azure
- Already using Azure services
- Need Azure-specific integrations
- Prefer Azure Portal UI
- Have existing Azure credits

### When to Use GCP
- Better GPU availability in your region
- Lower cost with committed use discounts
- Prefer gcloud CLI workflow
- Have GCP free credits ($300)

### Multi-Cloud Strategy
Consider running both:
- **Azure**: Production deployment with committed resources
- **GCP**: Backup/overflow for high-demand periods
- Both scripts use same app configuration
- Database can be synced or kept separate

## Migration Between Clouds

To migrate from Azure to GCP (or vice versa):

1. **Backup data:**
   ```bash
   tar -czf backup.tar.gz ~/datadrive/vid2story/data/
   ```

2. **Transfer:**
   ```bash
   # Download from source
   scp user@source-vm:~/backup.tar.gz .
   
   # Upload to destination
   scp backup.tar.gz user@dest-vm:~
   ```

3. **Restore:**
   ```bash
   tar -xzf backup.tar.gz
   ```

4. **Update .env:**
   - Change BASE_URL to new domain/IP
   - Verify all paths match new environment

5. **Restart:**
   ```bash
   pm2 restart all --update-env
   ```

## Support Resources

### Azure
- [Azure Documentation](https://docs.microsoft.com/azure/)
- [Azure Support](https://azure.microsoft.com/en-us/support/options/)
- [Azure Community](https://techcommunity.microsoft.com/t5/azure/ct-p/Azure)

### GCP
- [GCP Documentation](https://cloud.google.com/docs)
- [GCP Support](https://cloud.google.com/support)
- [GCP Community](https://www.googlecloudcommunity.com/)

### vid2story
- [GitHub Repository](https://github.com/newpress-media/vid2story)
- [Issue Tracker](https://github.com/newpress-media/vid2story/issues)
