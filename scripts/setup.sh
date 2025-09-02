#!/bin/bash
set -euo pipefail

# AI Development Server Setup Script
echo "🚀 Setting up AI Development Server..."

# Check requirements
check_requirements() {
    echo "📋 Checking requirements..."
    
    if ! command -v terraform &> /dev/null; then
        echo "❌ Terraform is not installed. Please install Terraform first."
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        echo "❌ Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        echo "❌ Docker daemon is not running. Please start Docker first."
        exit 1
    fi
    
    echo "✅ All requirements met!"
}

# Setup terraform.tfvars if it doesn't exist
setup_config() {
    if [ ! -f terraform.tfvars ]; then
        echo "📝 Creating terraform.tfvars from template..."
        cp terraform.tfvars.example terraform.tfvars
        
        # Generate a random password if not set
        if grep -q "your-secure-password-here" terraform.tfvars; then
            PASSWORD=$(openssl rand -base64 24)
            sed -i.bak "s/your-secure-password-here/$PASSWORD/" terraform.tfvars
            rm terraform.tfvars.bak 2>/dev/null || true
            echo "🔐 Generated random password for code-server"
        fi
        
        echo "⚠️  Please review and customize terraform.tfvars before proceeding"
        echo "📂 File location: $(pwd)/terraform.tfvars"
        read -p "Press Enter to continue after reviewing the config..."
    fi
}

# Deploy infrastructure
deploy() {
    echo "🏗️  Deploying infrastructure..."
    
    terraform init
    terraform plan
    
    read -p "Do you want to apply these changes? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        terraform apply
        echo "✅ Infrastructure deployed!"
    else
        echo "❌ Deployment cancelled"
        exit 1
    fi
}

# Install Ollama models
install_models() {
    echo "🤖 Installing Ollama models..."
    
    # Wait for Ollama to be ready
    echo "⏳ Waiting for Ollama to be ready..."
    timeout=60
    while ! curl -s http://localhost:11434/api/tags > /dev/null; do
        if [ $timeout -eq 0 ]; then
            echo "❌ Timeout waiting for Ollama to start"
            exit 1
        fi
        sleep 2
        ((timeout--))
    done
    
    # Get models from terraform.tfvars
    models=$(grep -E '^ollama_models' terraform.tfvars | sed 's/.*= *\[//' | sed 's/\]//' | tr -d '"' | tr ',' '\n' | xargs)
    
    for model in $models; do
        echo "📥 Pulling model: $model"
        docker exec -t $(terraform output -raw ollama_container_name) ollama pull $model
    done
    
    echo "✅ All models installed!"
}

# Show connection info
show_info() {
    echo ""
    echo "🎉 Setup complete! Here's how to connect:"
    echo ""
    echo "🌐 code-server: $(terraform output -raw code_server_url)"
    echo "🤖 Ollama API: $(terraform output -raw ollama_api_url)"
    echo ""
    echo "📖 Continue.dev configuration:"
    terraform output -raw continue_config | jq .
    echo ""
    echo "🔧 Next steps:"
    echo "1. Open code-server in your browser"
    echo "2. Install the Continue extension"
    echo "3. Configure Continue with the Ollama endpoint above"
    echo ""
}

# Main execution
main() {
    check_requirements
    setup_config
    deploy
    install_models
    show_info
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi