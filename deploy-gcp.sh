#!/bin/bash
set -e

# vid2story GCP VM Deployment Script
# Run this script on a fresh Ubuntu 24.04 GCP VM

echo "========================================="
echo "vid2story GCP VM Deployment"
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
# Uncomment below if you have a GCP GPU VM (n1-standard-8 with T4 GPU)
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
print_info "Step 4: Checking for additional disks..."
# GCP attaches additional disks as /dev/sdb (not sdc like Azure)
if [ -b /dev/sdb ]; then
    print_warning "Found /dev/sdb (additional persistent disk). Setting up data drive..."
    print_warning "This will FORMAT /dev/sdb. Press Ctrl+C within 10 seconds to cancel..."
    sleep 10
    
    sudo parted /dev/sdb mklabel gpt
    sudo parted -a opt /dev/sdb mkpart primary ext4 0% 100%
    sudo mkfs.ext4 /dev/sdb1
    sudo mkdir -p /datadrive
    sudo mount /dev/sdb1 /datadrive
    
    # Get UUID and add to fstab
    UUID=$(sudo blkid -s UUID -o value /dev/sdb1)
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

# Determine base path for installation
if [ -d /datadrive ]; then
    BASE_PATH=/datadrive
else
    BASE_PATH=$HOME/datadrive
fi

print_info "Using base path: $BASE_PATH"

# Step 5: Install Rust
print_info "Step 5: Installing Rust..."
if ! command -v rustc &> /dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
else
    print_info "Rust already installed"
fi

# Step 6: Clone and build land2port
print_info "Step 6: Building land2port..."
cd $BASE_PATH
if [ ! -d "land2port" ]; then
    git clone https://github.com/newpress-media/land2port.git
    cd land2port
else
    cd land2port
    git pull
fi

# Build with CPU support by default
# For GPU: build with --features cuda after installing CUDA
print_info "Building land2port with CPU support..."
cargo build --release
print_info "land2port built successfully at: $BASE_PATH/land2port/target/release/land2port"

# Step 7: Install Node.js via nvm
print_info "Step 7: Installing Node.js..."
if [ ! -d "$HOME/.nvm" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
else
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
fi

nvm install 24
nvm use 24
node --version

# Step 8: Install pnpm
print_info "Step 8: Installing pnpm..."
if ! command -v pnpm &> /dev/null; then
    npm install -g pnpm@10
fi

# Step 9: Install PM2 globally
print_info "Step 9: Installing PM2..."
npm install -g pm2

# Step 10: Clone vid2story repository
print_info "Step 10: Cloning vid2story repository..."
cd $BASE_PATH
if [ ! -d "vid2story" ]; then
    git clone https://github.com/newpress-media/vid2story.git
    cd vid2story
else
    cd vid2story
    git pull
fi

# Step 11: Install dependencies
print_info "Step 11: Installing dependencies..."
pnpm install

# Step 12: Build the application
print_info "Step 12: Building application..."
pnpm build

# Step 13: Setup environment file
print_info "Step 13: Setting up environment..."
if [ ! -f .env ]; then
    cp .env.example .env
    print_info "Created .env file. Please configure it with your settings."
    
    # Set default paths in .env
    sed -i "s|LAND2PORT_PATH=.*|LAND2PORT_PATH=$BASE_PATH/land2port/target/release/land2port|g" .env
    sed -i "s|DATABASE_PATH=.*|DATABASE_PATH=$BASE_PATH/vid2story/data/sqlite.db|g" .env
    sed -i "s|UPLOADS_DIR=.*|UPLOADS_DIR=$BASE_PATH/vid2story/public/uploads|g" .env
    sed -i "s|NODE_ENV=.*|NODE_ENV=production|g" .env
    sed -i "s|LAND2PORT_DEVICE=.*|LAND2PORT_DEVICE=cpu|g" .env
    
    print_warning "Please edit .env and add your OPENAI_API_KEY and BASE_URL"
else
    print_info ".env file already exists"
fi

# Step 14: Create necessary directories
print_info "Step 14: Creating directories..."
mkdir -p public/uploads
mkdir -p public/generated
mkdir -p data
mkdir -p logs

# Step 15: Run database migrations
print_info "Step 15: Running database migrations..."
pnpm db:migrate

# Step 16: Setup PM2
print_info "Step 16: Setting up PM2..."
pm2 start ecosystem.config.js
pm2 save
pm2 startup | tail -n 1 | bash

print_info "PM2 configured and running"

# Step 17: Install and configure Nginx
print_info "Step 17: Installing and configuring Nginx..."
sudo apt install -y nginx

# Create nginx configuration
sudo tee /etc/nginx/sites-available/vid2story.conf > /dev/null << 'EOF'
server {
    listen 80;
    server_name _;

    client_max_body_size 3G;
    client_body_timeout 300s;
    proxy_connect_timeout 300s;
    proxy_send_timeout 300s;
    proxy_read_timeout 300s;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # Serve static files directly
    location /public/ {
        alias /home/$USER/datadrive/vid2story/public/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    location /uploads/ {
        alias /home/$USER/datadrive/vid2story/public/uploads/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
EOF

# Update user in nginx config
sudo sed -i "s/\$USER/$USER/g" /etc/nginx/sites-available/vid2story.conf

# Enable site
sudo ln -sf /etc/nginx/sites-available/vid2story.conf /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test and restart nginx
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx

print_info "Nginx configured and running"

# Print summary
echo ""
echo "========================================="
print_info "Deployment Complete!"
echo "========================================="
echo ""
print_info "Next steps:"
echo "1. Get your VM's external IP:"
echo "   gcloud compute instances describe \$(hostname) --zone=\$(gcloud compute instances list --filter=\"name=\$(hostname)\" --format=\"get(zone)\" 2>/dev/null | awk -F/ '{print \$NF}') --format=\"get(networkInterfaces[0].accessConfigs[0].natIP)\" 2>/dev/null"
echo ""
echo "2. Edit the .env file:"
echo "   cd $BASE_PATH/vid2story"
echo "   nano .env"
echo "   - Add your OPENAI_API_KEY"
echo "   - Set BASE_URL to http://YOUR_EXTERNAL_IP"
echo ""
echo "3. Restart the application:"
echo "   export NVM_DIR=\"\$HOME/.nvm\""
echo "   source \"\$NVM_DIR/nvm.sh\""
echo "   pm2 restart all --update-env"
echo ""
echo "4. Access your application at: http://YOUR_EXTERNAL_IP"
echo ""
print_info "Monitor logs with: pm2 logs"
print_info "Monitor system with: pm2 monit"
echo ""
print_warning "For GPU support:"
print_warning "1. Uncomment GPU sections in this script (NVIDIA, CUDA, cuDNN, TensorRT)"
print_warning "2. Re-run the script after system reboot"
print_warning "3. Rebuild land2port with: cd $BASE_PATH/land2port && cargo build --release --features cuda"
print_warning "4. Update .env: LAND2PORT_DEVICE=\"cuda\""
print_warning "5. Restart: pm2 restart all --update-env"
echo ""
