# 🤖 AI Development Server - GCP Vertex AI Workbench

Infrastructure-as-Code setup for a powerful AI development environment using Google Cloud Vertex AI Workbench, optimized for coding AI models like Codestral, Mistral, and compatible with Continue.dev.

## 🎯 Overview

This project creates a cloud-based AI development environment featuring:

- **🧠 Vertex AI Workbench**: Managed Jupyter environment with GPU support
- **🤖 Ollama**: Self-hosted LLM server for coding AI models
- **💻 code-server**: Web-based VS Code accessible from any device
- **🔧 Continue.dev**: Pre-configured AI coding assistant
- **☁️ Cloud Storage**: Model storage and backup
- **🛡️ Security**: VPC isolation and IAM controls

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────┐
│                GCP Project                       │
│  ┌─────────────────────────────────────────────┐ │
│  │           VPC Network                        │ │
│  │  ┌─────────────────────────────────────────┐ │ │
│  │  │      Vertex AI Workbench                │ │ │
│  │  │                                         │ │ │
│  │  │  JupyterLab (:8888)                    │ │ │
│  │  │  code-server (:8080) ──┐               │ │ │
│  │  │  Ollama API (:11434) ─┐│               │ │ │
│  │  │                       ││               │ │ │
│  │  └───────────────────────││──────────────┘ │ │
│  └──────────────────────────││────────────────┘ │
└───────────────────────────SSH Tunnel ───────────┘
                             ││
                    ┌────────┘│
                    │         │
           Your Local VS Code  │
           with Continue.dev   │
                              │
                    Your Mobile Browser
```

## 🚀 Quick Start

### Prerequisites

- Google Cloud SDK (`gcloud`) installed and authenticated
- Terraform >= 1.0 installed
- A GCP project with billing enabled

### 1. Configure Your Environment

```bash
# Clone and setup
git clone <this-repo>
cd ai-development-server

# Create your config
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your GCP project details
```

### 2. Quick Start (Recommended)

```bash
# Run the interactive setup
./scripts/quick-start.sh
```

**Or manual setup:**

```bash
# Choose your configuration based on needs and budget
make config-cpu    # CPU-only: ~$35-70/month for 3-6 hours/day
make config-t4     # T4 GPU: ~$67-135/month for 3-6 hours/day
make config-l4     # L4 GPU: ~$125-250/month for 3-6 hours/day

# Deploy
make init
make apply
```

### 3. Access Your Environment

```bash
# Check status
make status

# Create SSH tunnel for local development
make tunnel

# Or SSH directly to the workbench
make ssh
```

## 📋 Configuration Options

### Machine Types for AI Development

Choose based on your needs:

| Machine Type     | vCPUs | RAM  | Best For                |
| ---------------- | ----- | ---- | ----------------------- |
| `n1-standard-8`  | 8     | 30GB | General coding models   |
| `n1-standard-16` | 16    | 60GB | Larger models           |
| `n1-highmem-8`   | 8     | 52GB | Memory-intensive models |
| `c2-standard-16` | 16    | 64GB | High-performance CPU    |

### GPU Options

Recommended for faster inference:

| GPU Type            | Memory | Best For                      | Cost Level |
| ------------------- | ------ | ----------------------------- | ---------- |
| `NVIDIA_TESLA_T4`   | 16GB   | Cost-effective inference      | $          |
| `NVIDIA_L4`         | 24GB   | Latest gen, great performance | $$         |
| `NVIDIA_TESLA_V100` | 16GB   | High-end training/inference   | $$$        |

### Pre-installed AI Models

The workbench comes with coding-optimized models:

- **Codestral 22B**: Mistral's specialized coding model
- **Mistral Nemo 12B**: Latest general-purpose model
- **Llama 3.1 8B**: Meta's efficient model
- **DeepSeek Coder 6.7B**: Specialized for code generation

## 🔧 Usage

### Continue.dev Setup

1. **Via SSH Tunnel (Recommended):**

   ```bash
   make tunnel  # Creates local tunnel
   # Access code-server at http://localhost:8080
   # Configure Continue.dev with endpoint: http://localhost:11434
   ```

2. **Get Continue.dev Configuration:**
   ```bash
   make continue-config  # Shows JSON config to copy
   ```

### Model Management

```bash
# List installed models
make models

# Install a new model
make install-model MODEL=llama3.1:70b

# Check service status
make service-status
```

### Development Workflow

1. **Local VS Code + SSH Tunnel:**

   - Run `make tunnel`
   - Connect VS Code to tunnel
   - Use Continue.dev with local Ollama endpoint

2. **Browser-based Development:**

   - Access JupyterLab directly via GCP Console
   - Use built-in code-server at `:8080`

3. **Mobile Development:**
   - Access via mobile browser through SSH tunnel
   - Full VS Code experience on phone/tablet

## 🛠️ Management Commands

```bash
make help              # Show all commands
make status            # Instance status
make logs              # Setup logs
make setup-status      # Check if setup complete
make restart-services  # Restart Ollama/code-server
make backup            # Backup data
make cost-estimate     # Cost estimation
```

## 💰 Cost Optimization for Intermittent Use

**Perfect for your use case** (few hours throughout the day with 15-minute auto-shutdown):

### Configuration Options:

| Configuration                    | Hourly Rate | 3 hrs/day Cost | 6 hrs/day Cost | 12 hrs/day Cost |
| -------------------------------- | ----------- | -------------- | -------------- | --------------- |
| **CPU-only** (n1-standard-8)     | ~$0.38      | ~$35/month     | ~$70/month     | ~$140/month     |
| **T4 GPU** (n1-standard-8 + T4)  | ~$0.73      | ~$67/month     | ~$135/month    | ~$270/month     |
| **L4 GPU** (n1-standard-16 + L4) | ~$1.36      | ~$125/month    | ~$250/month    | ~$500/month     |

### Smart Configuration Switching:

```bash
make config-cpu    # Switch to CPU-only for light work
make config-t4     # Switch to T4 GPU for moderate AI tasks
make config-l4     # Switch to L4 GPU for heavy workloads
make apply         # Apply the new configuration
```

**Cost-saving features built-in:**

- ⏱️ **Auto-shutdown after 15 minutes idle** (configurable)
- 🔄 **Easy config switching** without data loss
- 💾 **Persistent storage** - models and data survive config changes
- 📊 **Usage tracking** via GCP billing

## 🔒 Security

- **Network Isolation**: Resources in dedicated VPC
- **Firewall Rules**: Restricted access by IP ranges
- **IAM Controls**: Least-privilege service accounts
- **Private Access**: Option to disable public IPs

**Production Security:**

```hcl
# In terraform.tfvars
no_public_ip = true
allowed_ip_ranges = ["YOUR.OFFICE.IP/32"]
```

## 📱 Mobile Development

Access your full AI development environment from your phone:

1. Setup SSH tunnel from your phone using apps like Termius
2. Access code-server in mobile browser
3. Use Continue.dev for AI assistance on mobile

Perfect for:

- Code reviews on the go
- Quick bug fixes
- Learning and experimentation

## 🔄 Backup & Recovery

```bash
# Create backup
make backup

# Backup includes:
# - Ollama models and configs
# - code-server settings
# - workspace files
# - Continue.dev configuration
```

## 🐛 Troubleshooting

### Setup Issues

```bash
make setup-status  # Check setup completion
make logs          # View setup logs
make ssh           # Direct access to troubleshoot
```

### Service Issues

```bash
make service-status    # Check Ollama/code-server
make restart-services  # Restart services
```

### Network Issues

```bash
make status   # Check instance status
gcloud compute instances list  # Direct GCP check
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Test with a dev environment
4. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details.

---

**Ready to supercharge your AI development?** 🚀

```bash
make setup  # Get started in minutes!
```
