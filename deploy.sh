#!/bin/bash
set -e

# vid2story Azure VM Deployment Script
# Based on vm.md instructions
# Run this script on a fresh Ubuntu 24.04 VM

echo "========================================="
echo "vid2story Azure VM Deployment"
echo "========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on Ubuntu
if [ ! -f /etc/lsb-release ] || ! grep -q "Ubuntu" /etc/lsb-release; then
    print_error "This script is designed for Ubuntu. Exiting."
    exit 1
fi

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    print_error "Please do not run this script as root. Use a regular user with sudo privileges."
    exit 1
fi

# Step 1: System Updates and Package Installation
print_info "Step 1: Installing system packages..."
sudo apt update
sudo apt upgrade -y
sudo apt install -y git-lfs build-essential pkg-config libclang-dev
sudo apt install -y libssl-dev ca-certificates
sudo apt install -y libavutil-dev libavcodec-dev libavformat-dev libavfilter-dev libavdevice-dev
sudo apt install -y ttf-mscorefonts-installer

# Step 2: NVIDIA Driver Setup (if GPU available)
print_warning "NVIDIA driver installation requires a reboot. This section is commented out."
print_warning "Uncomment and run separately if you have a GPU VM."
# Uncomment below if you have an Azure GPU VM (Standard NC8as T4 v3)
# print_info "Step 2: Installing NVIDIA drivers..."
# wget https://us.download.nvidia.com/tesla/580.95.05/nvidia-driver-local-repo-ubuntu2404-580.95.05_1.0-1_amd64.deb
# sudo dpkg -i nvidia-driver-local-repo-ubuntu2404-580.95.05_1.0-1_amd64.deb
# sudo cp /var/nvidia-driver-local-repo-ubuntu2404-580.95.05/nvidia-driver-local-*-keyring.gpg /usr/share/keyrings/
# sudo apt update
# sudo apt install -y cuda-drivers
# print_warning "NVIDIA drivers installed. System will reboot in 10 seconds..."
# sleep 10
# sudo reboot

# Step 3: CUDA, CUDNN and TensorRT Installation
print_warning "CUDA/CUDNN/TensorRT installation is skipped by default."
print_warning "Uncomment if you have a GPU VM and need GPU acceleration."
# Uncomment below for GPU VMs
# print_info "Step 3: Installing CUDA toolkit..."
# wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-ubuntu2404.pin
# sudo mv cuda-ubuntu2404.pin /etc/apt/preferences.d/cuda-repository-pin-600
# wget https://developer.download.nvidia.com/compute/cuda/13.0.2/local_installers/cuda-repo-ubuntu2404-13-0-local_13.0.2-580.95.05-1_amd64.deb
# sudo dpkg -i cuda-repo-ubuntu2404-13-0-local_13.0.2-580.95.05-1_amd64.deb
# sudo cp /var/cuda-repo-ubuntu2404-13-0-local/cuda-*-keyring.gpg /usr/share/keyrings/
# sudo apt update
# sudo apt install -y cuda-toolkit-13-0

# print_info "Installing cuDNN..."
# wget https://developer.download.nvidia.com/compute/cudnn/9.14.0/local_installers/cudnn-local-repo-ubuntu2404-9.14.0_1.0-1_amd64.deb
# sudo dpkg -i cudnn-local-repo-ubuntu2404-9.14.0_1.0-1_amd64.deb
# sudo cp /var/cudnn-local-repo-ubuntu2404-9.14.0/cudnn-local-*-keyring.gpg /usr/share/keyrings/
# sudo apt update
# sudo apt install -y cudnn

# print_info "Installing TensorRT..."
# wget https://developer.download.nvidia.com/compute/tensorrt/10.13.3/local_installers/nv-tensorrt-local-repo-ubuntu2404-10.13.3-cuda-13.0_1.0-1_amd64.deb
# sudo dpkg -i nv-tensorrt-local-repo-ubuntu2404-10.13.3-cuda-13.0_1.0-1_amd64.deb
# sudo cp /var/nv-tensorrt-local-repo-ubuntu2404-10.13.3-cuda-13.0/nv-tensorrt-local-*-keyring.gpg /usr/share/keyrings/
# sudo apt update
# sudo apt install -y tensorrt
# sudo apt install -y libcublas12 libcudart12 libcufft11

# Step 4: Data Drive Setup
print_info "Step 4: Checking for data drive..."
# Check if there's a separate data disk (look for sdc or nvme1n1, not sda which is OS disk)
if [ -b /dev/sdc ]; then
    print_warning "Found /dev/sdc (data disk). Setting up data drive..."
    print_warning "This will FORMAT /dev/sdc. Press Ctrl+C within 10 seconds to cancel..."
    sleep 10
    
    sudo parted /dev/sdc mklabel gpt
    sudo parted -a opt /dev/sdc mkpart primary ext4 0% 100%
    sudo mkfs.ext4 /dev/sdc1
    sudo mkdir -p /datadrive
    sudo mount /dev/sdc1 /datadrive
    
    # Get UUID and add to fstab
    UUID=$(sudo blkid -s UUID -o value /dev/sdc1)
    if ! grep -q "$UUID" /etc/fstab; then
        echo "UUID=$UUID /datadrive ext4 defaults,nofail 0 0" | sudo tee -a /etc/fstab
    fi
    
    sudo mount -a
    sudo chown $USER:$USER /datadrive
    print_info "Data drive mounted at /datadrive"
else
    print_info "No separate data disk found. Using home directory."
    mkdir -p $HOME/datadrive
fi

# Set working directory
if [ -d /datadrive ]; then
    WORK_DIR=/datadrive
else
    WORK_DIR=$HOME/datadrive
fi

print_info "Working directory: $WORK_DIR"

# Step 5: Rust and land2port Installation
print_info "Step 5: Installing Rust and building land2port..."
if ! command -v cargo &> /dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
fi

cd $WORK_DIR
if [ ! -d "land2port" ]; then
    git clone https://github.com/paulingalls/land2port.git
fi
cd land2port
cargo build --release
print_info "land2port built successfully at $WORK_DIR/land2port"

# Step 6: Node.js and vid2story Setup
print_info "Step 6: Setting up Node.js and vid2story application..."

# Install nvm if not present
if [ ! -d "$HOME/.nvm" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
fi

# Load nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install Node.js LTS
nvm install --lts
nvm use --lts

# Install pnpm
if ! command -v pnpm &> /dev/null; then
    npm install -g pnpm
fi

# Install PM2
if ! command -v pm2 &> /dev/null; then
    npm install -g pm2
fi

# Clone/update vid2story repository
cd $WORK_DIR
if [ ! -d "vid2story" ]; then
    print_info "Cloning vid2story repository..."
    git clone https://github.com/newpress-media/vid2story.git
else
    print_info "Updating vid2story repository..."
    cd vid2story
    git pull
fi

cd $WORK_DIR/vid2story

# Install dependencies and build
print_info "Installing dependencies..."
pnpm install

print_info "Building application..."
pnpm build

# Run database migrations
print_info "Running database migrations..."
pnpm db:migrate

# Create necessary directories
mkdir -p uploads
mkdir -p data

# Setup environment file
if [ ! -f .env ]; then
    print_info "Creating .env file from template..."
    cp .env.example .env
    
    # Update paths in .env
    sed -i "s|LAND2PORT_PATH=.*|LAND2PORT_PATH=\"$WORK_DIR/land2port\"|g" .env
    sed -i "s|LAND2PORT_DEVICE=.*|LAND2PORT_DEVICE=\"cuda\"|g" .env
    sed -i "s|BASE_URL=.*|BASE_URL=\"http://localhost\"|g" .env
    
    print_warning "Please edit .env file and add your OPENAI_API_KEY and other settings"
    print_warning "File location: $WORK_DIR/vid2story/.env"
else
    print_info ".env file already exists"
fi

# Step 7: PM2 Setup
print_info "Step 7: Setting up PM2 process manager..."
pm2 start ecosystem.config.js
pm2 save
pm2 startup | tail -n 1 | bash
print_info "Application started with PM2"

# Step 8: Nginx Configuration
print_info "Step 8: Installing and configuring Nginx..."
sudo apt install -y nginx

# Copy nginx configuration
if [ -f "nginx.conf" ]; then
    sudo cp nginx.conf /etc/nginx/sites-available/vid2story.conf
    sudo ln -sf /etc/nginx/sites-available/vid2story.conf /etc/nginx/sites-enabled/
    sudo rm -f /etc/nginx/sites-enabled/default
    
    # Update server_name with actual hostname if available
    HOSTNAME=$(hostname -f)
    print_info "Detected hostname: $HOSTNAME"
    print_warning "Please update server_name in /etc/nginx/sites-available/vid2story.conf"
    
    # Test nginx configuration
    sudo nginx -t && sudo systemctl restart nginx
    print_info "Nginx configured and restarted"
else
    print_warning "nginx.conf not found. Please configure Nginx manually."
fi

# Step 9: SSL Certificate (optional)
print_info "Step 9: SSL certificate setup (optional)..."
print_warning "To add SSL certificates, run:"
print_warning "  sudo snap install --classic certbot"
print_warning "  sudo ln -s /snap/bin/certbot /usr/bin/certbot"
print_warning "  sudo certbot --nginx"

# Final summary
echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
print_info "Application directory: $WORK_DIR/vid2story"
print_info "land2port directory: $WORK_DIR/land2port"
print_info ""
print_info "Next steps:"
print_info "1. Edit $WORK_DIR/vid2story/.env and add your API keys"
print_info "2. Update server_name in /etc/nginx/sites-available/vid2story.conf"
print_info "3. Restart the application: cd $WORK_DIR/vid2story && pm2 restart all"
print_info "4. Check logs: pm2 logs"
print_info "5. (Optional) Set up SSL with: sudo certbot --nginx"
print_info ""
print_info "Useful commands:"
print_info "  pm2 status       - Check application status"
print_info "  pm2 logs         - View application logs"
print_info "  pm2 restart all  - Restart application"
print_info "  sudo nginx -t    - Test nginx configuration"
echo "========================================="
