#!/bin/bash
set -euo pipefail

# Handle undefined variables gracefully
set +u

# Vertex AI Workbench Startup Script
# This script sets up Ollama, code-server, and AI models on a GCP workbench instance

LOG_FILE="/var/log/ai-workbench-setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "🚀 Starting AI Workbench setup at $(date)"
echo "📋 Project: ${project_name}"
echo "👤 User: ${user_email}"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Wait for any automatic package updates to complete
log "⏳ Waiting for automatic package updates to complete..."
while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
    log "   Waiting for package manager lock to be released..."
    sleep 10
done

# Update system packages
log "📦 Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
# Kill any stuck package processes
sudo killall apt apt-get dpkg >/dev/null 2>&1 || true
# Clean up any lock files
sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock >/dev/null 2>&1 || true
# Configure any interrupted packages
sudo dpkg --configure -a >/dev/null 2>&1 || true
# Now safely update
apt-get update -q
apt-get upgrade -yq

# Install essential tools
log "🔧 Installing essential tools..."
# Wait again before installing packages
while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
    log "   Waiting for package manager before installing tools..."
    sleep 5
done

apt-get install -yq \
    curl \
    wget \
    git \
    htop \
    vim \
    nano \
    tmux \
    screen \
    jq \
    unzip \
    build-essential \
    python3-pip \
    nodejs \
    npm \
    docker.io \
    nvidia-container-toolkit

# Start and enable Docker
log "🐳 Setting up Docker..."
systemctl start docker
systemctl enable docker
usermod -aG docker jupyter
# Note: $USER is not available in startup script context
if [ -n "$${USER:-}" ]; then
    usermod -aG docker $$USER
fi

# Configure NVIDIA Container Runtime (if GPU is present)
if lspci | grep -i nvidia > /dev/null; then
    log "🎮 Configuring NVIDIA Container Runtime..."
    nvidia-ctk runtime configure --runtime=docker
    systemctl restart docker
fi

# Install Ollama
log "🤖 Installing Ollama..."
if ! command_exists ollama; then
    log "   Downloading Ollama installer..."
    # Retry download up to 3 times on failure
    for attempt in 1 2 3; do
        log "   Attempt $attempt/3 to install Ollama..."
        if curl -fsSL https://ollama.com/install.sh | sh; then
            log "✅ Ollama installed successfully"
            break
        else
            log "⚠️ Ollama installation attempt $attempt failed"
            if [ $attempt -eq 3 ]; then
                log "❌ All Ollama installation attempts failed"
                exit 1
            fi
            log "   Waiting 30 seconds before retry..."
            sleep 30
        fi
    done
    
    # Create systemd service for Ollama
    cat << 'EOF' > /etc/systemd/system/ollama.service
[Unit]
Description=Ollama Service
After=network-online.target

[Service]
ExecStart=/usr/local/bin/ollama serve
User=jupyter
Group=jupyter
Restart=always
RestartSec=3
Environment="OLLAMA_HOST=0.0.0.0"
Environment="OLLAMA_ORIGINS=*"

[Install]
WantedBy=default.target
EOF
    
    systemctl daemon-reload
    systemctl enable ollama
    systemctl start ollama
else
    log "✅ Ollama already installed"
fi

# Wait for Ollama to be ready
log "⏳ Waiting for Ollama to be ready..."
timeout=60
while ! curl -sf http://localhost:11434/api/tags > /dev/null 2>&1; do
    if [ $timeout -eq 0 ]; then
        log "❌ Timeout waiting for Ollama to start"
        exit 1
    fi
    sleep 2
    ((timeout--))
done
log "✅ Ollama is ready"

# Install AI models
log "📥 Installing AI models..."
models='${ollama_models}'
echo "$models" | jq -r '.[]' | while read -r model; do
    log "🔄 Pulling model: $model"
    sudo -u jupyter /usr/local/bin/ollama pull "$model" || log "⚠️  Failed to pull $model"
done

# Install code-server
log "💻 Installing code-server..."
if ! command_exists code-server; then
    # Wait for package manager to be free
    while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
        log "   Waiting for package manager before installing code-server..."
        sleep 5
    done
    
    # Set HOME for the installation script
    export HOME=/root
    log "   Downloading and installing code-server..."
    curl -fsSL https://code-server.dev/install.sh | sh
    
    # Verify installation
    if command_exists code-server; then
        log "✅ code-server installed successfully"
    else
        log "❌ code-server installation failed"
        exit 1
    fi
else
    log "✅ code-server already installed"
fi

# Configure code-server
log "🔧 Configuring code-server..."
sudo -u jupyter mkdir -p /home/jupyter/.config/code-server
sudo -u jupyter cat << EOF > /home/jupyter/.config/code-server/config.yaml
bind-addr: 0.0.0.0:8080
auth: password
password: ${code_server_password}
cert: false
EOF

# Create code-server systemd service
log "🔧 Creating code-server systemd service..."
cat << 'EOF' > /etc/systemd/system/code-server.service
[Unit]
Description=code-server
After=network.target

[Service]
Type=exec
ExecStart=/usr/bin/code-server --config /home/jupyter/.config/code-server/config.yaml /home/jupyter
Restart=always
User=jupyter
Group=jupyter
Environment=HOME=/home/jupyter

[Install]
WantedBy=multi-user.target
EOF

log "🔧 Starting code-server service..."
systemctl daemon-reload
systemctl enable code-server
systemctl start code-server

# Wait a moment for code-server to start
sleep 5

# Verify code-server is running
if systemctl is-active --quiet code-server; then
    log "✅ code-server service is running"
else
    log "❌ code-server service failed to start"
    systemctl status code-server || true
fi

# Mount and setup data disk
log "💾 Setting up persistent data disk..."
# Check if data disk exists and mount it
if [ -b "/dev/sdb" ]; then
    log "   Found data disk /dev/sdb (150GB)"
    
    # Create filesystem if needed
    if ! file -s /dev/sdb | grep -q ext4; then
        log "   Creating ext4 filesystem on data disk..."
        mkfs.ext4 -F /dev/sdb
    fi
    
    # Create mount point and mount
    mkdir -p /mnt/data
    if ! mountpoint -q /mnt/data; then
        log "   Mounting data disk to /mnt/data..."
        mount /dev/sdb /mnt/data
        
        # Add to fstab for persistence
        if ! grep -q "/dev/sdb" /etc/fstab; then
            echo '/dev/sdb /mnt/data ext4 defaults 0 2' >> /etc/fstab
            log "   Added data disk to fstab for auto-mount"
        fi
    fi
    
    # Create workspace directories on data disk
    log "   Creating workspace structure on data disk..."
    mkdir -p /mnt/data/jupyter/{workspace,repositories,projects,models,ollama}
    
    # Create symlinks from jupyter home to data disk
    sudo -u jupyter ln -sf /mnt/data/jupyter/workspace /home/jupyter/workspace
    sudo -u jupyter ln -sf /mnt/data/jupyter/repositories /home/jupyter/repositories
    sudo -u jupyter ln -sf /mnt/data/jupyter/projects /home/jupyter/projects
    sudo -u jupyter ln -sf /mnt/data/jupyter/models /home/jupyter/models
    
    # Move Ollama data to data disk if it exists
    if [ -d "/home/jupyter/.ollama" ]; then
        log "   Moving Ollama data to persistent storage..."
        cp -r /home/jupyter/.ollama/* /mnt/data/jupyter/ollama/ 2>/dev/null || true
    fi
    sudo -u jupyter ln -sf /mnt/data/jupyter/ollama /home/jupyter/.ollama
    
    # Set proper ownership
    chown -R jupyter:jupyter /mnt/data/jupyter/
    
    log "✅ Data disk setup complete - 150GB persistent storage ready"
else
    log "⚠️ No data disk found, using boot disk for storage"
    # Fallback to boot disk
    sudo -u jupyter mkdir -p /home/jupyter/workspace
    sudo -u jupyter mkdir -p /home/jupyter/projects
    sudo -u jupyter mkdir -p /home/jupyter/models
fi

# Install VS Code extensions for code-server
log "🔌 Installing VS Code extensions..."
sudo -u jupyter mkdir -p /home/jupyter/.local/share/code-server/extensions

# List of essential extensions
extensions=(
    "continue.continue"
    "ms-python.python"
    "ms-vscode.vscode-typescript-next"
    "hashicorp.terraform"
    "ms-vscode.vscode-docker"
    "ms-vscode.vscode-json"
    "redhat.vscode-yaml"
    "eamodio.gitlens"
    "esbenp.prettier-vscode"
    "pkief.material-icon-theme"
)

for extension in "$${extensions[@]}"; do
    log "🔌 Installing extension: $extension"
    sudo -u jupyter code-server --install-extension "$extension" || log "⚠️  Failed to install $extension"
done

# Configure Continue extension
log "🤖 Configuring Continue extension..."
sudo -u jupyter mkdir -p /home/jupyter/.continue
sudo -u jupyter cat << 'EOF' > /home/jupyter/.continue/config.json
{
  "models": [
    {
      "title": "Codestral (Ollama)",
      "provider": "ollama",
      "model": "codestral:22b",
      "apiBase": "http://localhost:11434"
    },
    {
      "title": "Mistral Nemo (Ollama)", 
      "provider": "ollama",
      "model": "mistral-nemo:12b",
      "apiBase": "http://localhost:11434"
    },
    {
      "title": "Llama 3.1 (Ollama)",
      "provider": "ollama", 
      "model": "llama3.1:8b",
      "apiBase": "http://localhost:11434"
    },
    {
      "title": "DeepSeek Coder (Ollama)",
      "provider": "ollama",
      "model": "deepseek-coder:6.7b", 
      "apiBase": "http://localhost:11434"
    }
  ],
  "tabAutocompleteModel": {
    "title": "DeepSeek Coder",
    "provider": "ollama",
    "model": "deepseek-coder:6.7b",
    "apiBase": "http://localhost:11434"
  }
}
EOF

# Set proper ownership
chown -R jupyter:jupyter /home/jupyter/.continue
chown -R jupyter:jupyter /home/jupyter/.config
chown -R jupyter:jupyter /home/jupyter/.local

# Create helpful scripts
log "📜 Creating helper scripts..."

# Model management script
cat << 'EOF' > /home/jupyter/manage-models.sh
#!/bin/bash
# AI Model Management Script

case "$1" in
    list)
        echo "📋 Installed models:"
        ollama list
        ;;
    pull)
        if [ -z "$2" ]; then
            echo "❌ Please specify a model to pull"
            echo "Usage: $0 pull <model-name>"
            exit 1
        fi
        echo "📥 Pulling model: $2"
        ollama pull "$2"
        ;;
    remove)
        if [ -z "$2" ]; then
            echo "❌ Please specify a model to remove"
            echo "Usage: $0 remove <model-name>" 
            exit 1
        fi
        echo "🗑️ Removing model: $2"
        ollama rm "$2"
        ;;
    status)
        echo "🔍 Service status:"
        systemctl status ollama --no-pager -l
        systemctl status code-server --no-pager -l
        ;;
    *)
        echo "AI Model Management"
        echo "Usage: $0 {list|pull|remove|status} [model-name]"
        echo ""
        echo "Examples:"
        echo "  $0 list                    # List installed models"
        echo "  $0 pull llama3.1:8b       # Pull a new model"
        echo "  $0 remove mistral:7b      # Remove a model"
        echo "  $0 status                 # Check service status"
        ;;
esac
EOF

chmod +x /home/jupyter/manage-models.sh
chown jupyter:jupyter /home/jupyter/manage-models.sh

# Create welcome message
cat << EOF > /home/jupyter/README.md
# 🤖 AI Development Workbench

Welcome to your AI development environment! This workbench comes pre-configured with:

## 🛠️ Services Running

- **Ollama**: AI model server running on \`localhost:11434\`
- **code-server**: VS Code in the browser on \`localhost:8080\`
- **JupyterLab**: Native notebook interface

## 🔗 Access URLs

- JupyterLab: Access via Google Cloud Console
- code-server: \`http://localhost:8080\` (password: configured via Terraform)
- Ollama API: \`http://localhost:11434\`

## 🤖 Pre-installed Models

$$(echo '${ollama_models}' | jq -r '.[] | "- " + .')

## 🔧 Management

Use the helper script to manage models:
\`\`\`bash
./manage-models.sh list     # List models
./manage-models.sh status   # Check services
\`\`\`

## 🎯 Continue.dev Setup

The Continue extension is pre-configured and ready to use with your local Ollama models!

## 📁 Directory Structure

- \`~/workspace\` - Your main development workspace (150GB persistent data disk)
- \`~/repositories\` - Git repositories and source code
- \`~/projects\` - Additional projects directory  
- \`~/models\` - Custom model storage
- \`~/.ollama\` - AI models storage (persistent)
- \`~/.continue\` - Continue extension configuration

## 💾 Storage Layout

- **Boot Disk (100GB):** OS, applications, system files
- **Data Disk (150GB):** Your code, models, workspace - all persistent!
- **Mount Point:** \`/mnt/data\` contains your persistent data

## 🔍 Logs

- Setup log: \`/var/log/ai-workbench-setup.log\`
- Ollama logs: \`sudo journalctl -u ollama -f\`
- code-server logs: \`sudo journalctl -u code-server -f\`

Enjoy your AI development environment! 🚀
EOF

chown jupyter:jupyter /home/jupyter/README.md

# Final status check
log "🔍 Final status check..."
if systemctl is-active --quiet ollama; then
    log "✅ Ollama service is running"
else
    log "❌ Ollama service is not running"
fi

if systemctl is-active --quiet code-server; then
    log "✅ code-server service is running"
else
    log "❌ code-server service is not running"
fi

# Create completion marker
touch /var/log/ai-workbench-setup-complete
chown jupyter:jupyter /var/log/ai-workbench-setup-complete

log "🎉 AI Workbench setup completed successfully!"
log "📋 Access information:"
log "   - JupyterLab: Use the proxy URI from the Google Cloud Console"
log "   - code-server: http://localhost:8080 (via SSH tunnel)"
log "   - Ollama API: http://localhost:11434 (via SSH tunnel)"
log ""
log "🔗 SSH tunnel command:"
log "   gcloud compute ssh --zone=$(curl -H 'Metadata-Flavor: Google' http://metadata.google.internal/computeMetadata/v1/instance/zone | cut -d/ -f4) --project=$(curl -H 'Metadata-Flavor: Google' http://metadata.google.internal/computeMetadata/v1/project/project-id) $(curl -H 'Metadata-Flavor: Google' http://metadata.google.internal/computeMetadata/v1/instance/name) -- -L 8080:localhost:8080 -L 11434:localhost:11434 -N"

echo "Setup completed at $(date)" >> /var/log/ai-workbench-setup.log