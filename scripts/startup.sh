#!/bin/bash
set -euo pipefail

echo "🚀 Starting AI Development Server setup..."

# --- 1. Mount Data Disk ---
# Note: Shell variables are escaped with $$ so Terraform's templatefile() ignores them.
DATA_DISK_DEVICE_ID="google-data-disk"
DATA_DISK_DEVICE_PATH="/dev/disk/by-id/$${DATA_DISK_DEVICE_ID}"
MOUNT_POINT="/home/jupyter"

echo ">>> Checking for data disk at $${DATA_DISK_DEVICE_PATH}..."

while [ ! -e "$${DATA_DISK_DEVICE_PATH}" ]; do
  echo "Waiting for data disk to appear..."
  sleep 5
done
echo "Data disk found."

if ! blkid "$${DATA_DISK_DEVICE_PATH}"; then
  echo ">>> Formatting data disk..."
  mkfs.ext4 -m 0 -E lazy_itable_init=0,lazy_journal_init=0,discard "$${DATA_DISK_DEVICE_PATH}"
else
  echo ">>> Data disk is already formatted."
fi

echo ">>> Mounting data disk to $${MOUNT_POINT}..."
mkdir -p "$${MOUNT_POINT}"

# CORRECTED: Only mount the disk if it's not already mounted to the target.
if ! grep -qs "$${MOUNT_POINT} " /proc/mounts; then
  mount -o discard,defaults "$${DATA_DISK_DEVICE_PATH}" "$${MOUNT_POINT}"
  echo "Mount successful."
else
  echo "Data disk is already mounted."
fi

chmod a+w "$${MOUNT_POINT}"

if ! grep -q "$${DATA_DISK_DEVICE_PATH}" /etc/fstab; then
  echo ">>> Adding data disk to /etc/fstab for auto-mounting..."
  echo "$${DATA_DISK_DEVICE_PATH} $${MOUNT_POINT} ext4 discard,defaults,nofail 0 2" >> /etc/fstab
else
  echo ">>> Data disk already in /etc/fstab."
fi
echo "✅ Data disk mounted."

echo ">>> Creating source directories for Docker bind mounts..."
mkdir -p /home/jupyter/ollama
mkdir -p /home/jupyter/code-server

echo ">>> Checking for NVIDIA driver..."
# Check if nvidia-smi is available. If not, the driver needs to be installed.
if ! command -v nvidia-smi &> /dev/null; then
  echo "NVIDIA driver not found. Running the non-interactive installer..."
  # This script is included in the VM image and handles the installation.
  # It automatically runs non-interactively when called from another script.
  /opt/deeplearning/install-driver.sh
  echo "✅ NVIDIA driver installed."
else
  echo "✅ NVIDIA driver already present. Skipping installation."
fi
# --- END OF NEW BLOCK ---

# --- 3. Configure Docker Permissions ---
echo ">>> Configuring Docker permissions..."
# This variable is from Terraform, so it is NOT escaped.
USER_EMAIL="${user_email}"
OS_USER=$(echo "$${USER_EMAIL}" | tr '@.' '__')
usermod -aG docker "$${OS_USER}"
echo "✅ User $${OS_USER} added to the docker group."

# --- 4. Install Docker Compose v2 ---
echo ">>> Installing Docker Compose v2 plugin..."
COMPOSE_VERSION="v2.27.0"
DOCKER_CONFIG_PATH="/usr/local/lib/docker/cli-plugins"
mkdir -p "$${DOCKER_CONFIG_PATH}"
curl -SL "https://github.com/docker/compose/releases/download/$${COMPOSE_VERSION}/docker-compose-linux-x86_64" -o "$${DOCKER_CONFIG_PATH}/docker-compose"
chmod +x "$${DOCKER_CONFIG_PATH}/docker-compose"
echo "✅ Docker Compose installed."

echo ">>> Installing Google Cloud Ops Agent for monitoring..."
# Check if the agent is already installed to make this script safe to re-run.
if ! command -v google-cloud-ops-agent &> /dev/null; then
  # The '--quiet' flag suppresses the normal output but will still show errors if it fails.
  curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
  bash add-google-cloud-ops-agent-repo.sh --also-install --quiet
  echo "✅ Ops Agent installed."
else
  echo "✅ Ops Agent already present. Skipping installation."
fi

# --- 5. Deploy Docker Compose Application ---
APP_DIR="/opt/ai-dev-server"
echo ">>> Deploying Docker Compose stack to $${APP_DIR}..."
mkdir -p "$${APP_DIR}"
chown -R "$${OS_USER}":"$${OS_USER}" "$${APP_DIR}"
# Create the docker-compose.yml. The password is now baked directly into this content by Terraform.
cat <<EOF > "$${APP_DIR}/docker-compose.yml"
${docker_compose_content}
EOF

# Create the code-server config.yaml from content passed by Terraform
cat <<EOF > "$${APP_DIR}/code-server-config.yaml"
${code_server_config_content}
EOF

# The .env file is no longer needed.

# Go to the app directory and start the services.
cd "$${APP_DIR}"
docker compose up -d
echo "✅ Docker Compose services started."

# --- 6. Initial Ollama Model Pull ---
echo ">>> Starting initial Ollama model downloads..."
# This variable is from Terraform, so it is NOT escaped.
MODELS_JSON='${ollama_models}'
echo "$${MODELS_JSON}" | jq -r '.[]' | while read model; do
    (docker exec ollama ollama pull "$model") &
done
echo "✅ Model downloads initiated in the background."

# --- 7. Start Idle Shutdown Monitor ---
# This variable is from Terraform, so it is NOT escaped.
IDLE_TIMEOUT_SECONDS="${idle_shutdown_timeout}"
(
  IDLE_COUNTER=0
  CHECK_INTERVAL=300

  while true; do
    GPU_UTILIZATION=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | head -n 1 || echo 0)
    ACTIVE_SESSIONS=$(who | wc -l)
    
    if (( $(echo "$GPU_UTILIZATION < 5" | bc -l) )) && (( ACTIVE_SESSIONS == 0 )); then
      ((IDLE_COUNTER+=CHECK_INTERVAL))
    else
      IDLE_COUNTER=0
    fi

    if (( IDLE_COUNTER >= IDLE_TIMEOUT_SECONDS )); then
      INSTANCE_NAME=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/name)
      INSTANCE_ZONE=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/zone | cut -d'/' -f4)
      gcloud compute instances stop "$INSTANCE_NAME" --zone="$INSTANCE_ZONE"
      break
    fi
    
    sleep $CHECK_INTERVAL
  done
) > /var/log/idle-shutdown.log 2>&1 &
echo "✅ Idle shutdown monitor configured for $${IDLE_TIMEOUT_SECONDS} seconds."

echo "🎉 AI Development Server setup complete!"