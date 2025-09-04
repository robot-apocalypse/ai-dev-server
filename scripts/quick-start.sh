#!/bin/bash
set -euo pipefail

# Quick start script for AI Development Server

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🚀 AI Development Server - Quick Start"
echo "======================================"
echo ""

# Check if gcloud is installed and configured
if ! command -v gcloud &> /dev/null; then
    echo "❌ Google Cloud SDK (gcloud) is not installed."
    echo "   Please install it from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform is not installed."
    echo "   Please install it from: https://terraform.io/downloads"
    exit 1
fi

# Check if user is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1 > /dev/null 2>&1; then
    echo "❌ Not authenticated with Google Cloud."
    echo "   Run: gcloud auth login"
    exit 1
fi

# Get current project
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")
if [ -z "$CURRENT_PROJECT" ]; then
    echo "❌ No Google Cloud project is set."
    echo "   Run: gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

echo "✅ Environment checks passed"
echo "   Project: $CURRENT_PROJECT"
echo "   User: $(gcloud auth list --filter=status:ACTIVE --format='value(account)' | head -n1)"
echo ""

# Check if configuration exists
if [ ! -f "$PROJECT_ROOT/terraform.tfvars" ]; then
    echo "🔧 Setting up initial configuration..."
    echo ""
    echo "Which configuration would you like to start with?"
    echo ""
    echo "1) CPU-only (cheapest - ~\$40-120/month for intermittent use)"
    echo "   - Good for: Learning, light development, small models"
    echo "   - Models: Quantized versions (phi3:3.8b, llama3.1:8b-q4_0)"
    echo ""
    echo "2) T4 GPU (balanced - ~\$80-200/month for intermittent use)" 
    echo "   - Good for: Most development work, moderate inference speed"
    echo "   - Models: Full models (codestral:22b, mistral-nemo:12b)"
    echo ""
    echo "3) L4 GPU (high-performance - ~\$150-350/month for intermittent use)"
    echo "   - Good for: Heavy workloads, large models, fastest inference"
    echo "   - Models: Large models (llama3.1:70b, deepseek-coder:33b)"
    echo ""
    read -p "Enter your choice (1-3): " choice
    
    case "$choice" in
        1)
            CONFIG="cpu-only"
            ;;
        2) 
            CONFIG="gpu-t4"
            ;;
        3)
            CONFIG="gpu-l4"
            ;;
        *)
            echo "❌ Invalid choice. Defaulting to T4 GPU configuration."
            CONFIG="gpu-t4"
            ;;
    esac
    
    # Check if the config file exists
    if [ ! -f "$PROJECT_ROOT/terraform.tfvars.$CONFIG" ]; then
        echo "❌ Configuration file terraform.tfvars.$CONFIG not found!"
        echo "Available files:"
        ls -la "$PROJECT_ROOT"/terraform.tfvars.* || echo "No configuration files found"
        exit 1
    fi
    
    # Copy the chosen configuration
    cp "$PROJECT_ROOT/terraform.tfvars.$CONFIG" "$PROJECT_ROOT/terraform.tfvars"
    
    echo "✅ Created terraform.tfvars with $CONFIG configuration"
    echo ""
fi

# Get user email for the configuration
USER_EMAIL=$(gcloud auth list --filter=status:ACTIVE --format='value(account)' | head -n1)

# Update the configuration with current project and user
echo "🔧 Updating configuration with your project details..."

# Use a more compatible sed approach
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/your-gcp-project-id/$CURRENT_PROJECT/g" "$PROJECT_ROOT/terraform.tfvars"
    sed -i '' "s/your-email@example.com/$USER_EMAIL/g" "$PROJECT_ROOT/terraform.tfvars"
else
    # Linux
    sed -i "s/your-gcp-project-id/$CURRENT_PROJECT/g" "$PROJECT_ROOT/terraform.tfvars"
    sed -i "s/your-email@example.com/$USER_EMAIL/g" "$PROJECT_ROOT/terraform.tfvars"
fi

# Prompt for password
echo ""
read -s -p "🔐 Set a password for code-server access: " CODE_SERVER_PASSWORD
echo ""

# Update password in config
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/your-secure-password-here/$CODE_SERVER_PASSWORD/g" "$PROJECT_ROOT/terraform.tfvars"
else
    # Linux
    sed -i "s/your-secure-password-here/$CODE_SERVER_PASSWORD/g" "$PROJECT_ROOT/terraform.tfvars"
fi

echo "✅ Configuration updated successfully"
echo ""

# Show current configuration
echo "📋 Current Configuration:"
echo "   Project: $CURRENT_PROJECT"  
echo "   User: $USER_EMAIL"
echo "   Machine: $(grep '^machine_type' "$PROJECT_ROOT/terraform.tfvars" | cut -d'"' -f2)"
GPU_TYPE=$(grep '^accelerator_type' "$PROJECT_ROOT/terraform.tfvars" | cut -d'"' -f2 || echo '')
if [ -z "$GPU_TYPE" ]; then
    echo "   GPU: None"
else
    echo "   GPU: $GPU_TYPE"
fi
echo ""

# Initialize Terraform if needed
if [ ! -d "$PROJECT_ROOT/.terraform" ]; then
    echo "🔧 Initializing Terraform..."
    cd "$PROJECT_ROOT"
    terraform init
    echo ""
fi

echo "🚀 Ready to deploy! Next steps:"
echo ""
echo "1. Review the configuration:"
echo "   cat terraform.tfvars"
echo ""
echo "2. Deploy the infrastructure:"
echo "   make apply"
echo ""
echo "3. Check deployment status:"
echo "   make status"
echo ""
echo "4. Create SSH tunnel for local development:"
echo "   make tunnel"
echo ""
echo "5. Access your development environment:"
echo "   - JupyterLab: Direct link from 'make status'"
echo "   - code-server: http://localhost:8080 (via tunnel)"
echo "   - Ollama API: http://localhost:11434 (via tunnel)"
echo ""
echo "💡 Cost-saving tips:"
echo "   - Instance auto-shuts down after 15 minutes of inactivity"
echo "   - Use 'make destroy' when done to avoid charges"
echo "   - Switch configurations anytime with 'make switch-config'"
echo ""
echo "📖 For help: make help"