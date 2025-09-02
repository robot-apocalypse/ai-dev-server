#!/bin/bash
set -euo pipefail

# Ollama Model Installation Script
echo "🤖 Ollama Model Installation Script"

CONTAINER_NAME=${1:-$(terraform output -raw ollama_container_name 2>/dev/null || echo "ai-dev-ollama")}

# Check if Ollama container is running
check_ollama() {
    if ! docker ps --format "table {{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
        echo "❌ Ollama container '$CONTAINER_NAME' is not running"
        echo "   Run 'terraform apply' first to start the services"
        exit 1
    fi
    
    # Wait for Ollama API to be ready
    echo "⏳ Waiting for Ollama API to be ready..."
    timeout=60
    while ! curl -sf http://localhost:11434/api/tags > /dev/null 2>&1; do
        if [ $timeout -eq 0 ]; then
            echo "❌ Timeout waiting for Ollama API"
            exit 1
        fi
        sleep 2
        ((timeout--))
    done
    echo "✅ Ollama API is ready"
}

# List available models
list_models() {
    echo "📋 Currently installed models:"
    docker exec $CONTAINER_NAME ollama list
    echo ""
}

# Install model
install_model() {
    local model=$1
    echo "📥 Installing model: $model"
    
    if docker exec $CONTAINER_NAME ollama pull "$model"; then
        echo "✅ Successfully installed: $model"
    else
        echo "❌ Failed to install: $model"
        return 1
    fi
}

# Remove model
remove_model() {
    local model=$1
    echo "🗑️  Removing model: $model"
    
    if docker exec $CONTAINER_NAME ollama rm "$model"; then
        echo "✅ Successfully removed: $model"
    else
        echo "❌ Failed to remove: $model"
        return 1
    fi
}

# Show popular models
show_popular_models() {
    echo "🔥 Popular models for development:"
    echo ""
    echo "Code Generation:"
    echo "  • codellama:7b        - Meta's CodeLlama 7B"
    echo "  • codellama:13b       - Meta's CodeLlama 13B"
    echo "  • deepseek-coder:6.7b - DeepSeek Coder 6.7B"
    echo ""
    echo "General Purpose:"
    echo "  • llama3.1:8b        - Meta's Llama 3.1 8B"
    echo "  • llama3.1:70b       - Meta's Llama 3.1 70B (requires ~40GB RAM)"
    echo "  • mistral:7b          - Mistral 7B"
    echo "  • phi3:3.8b          - Microsoft Phi-3 3.8B"
    echo ""
    echo "Lightweight:"
    echo "  • phi3:mini          - Microsoft Phi-3 Mini (3.8B)"
    echo "  • gemma:2b           - Google Gemma 2B"
    echo "  • tinyllama:1.1b     - TinyLlama 1.1B"
    echo ""
}

# Show usage
usage() {
    echo "Usage: $0 [COMMAND] [MODEL]"
    echo ""
    echo "Commands:"
    echo "  list              List installed models"
    echo "  install <model>   Install a specific model"
    echo "  remove <model>    Remove a specific model"
    echo "  popular           Show popular models"
    echo "  install-recommended Install recommended models"
    echo ""
    echo "Examples:"
    echo "  $0 list"
    echo "  $0 install llama3.1:8b"
    echo "  $0 remove codellama:7b"
    echo "  $0 install-recommended"
}

# Install recommended models
install_recommended() {
    local models=(
        "llama3.1:8b"
        "codellama:7b"
        "mistral:7b"
        "phi3:3.8b"
    )
    
    echo "🚀 Installing recommended models..."
    for model in "${models[@]}"; do
        install_model "$model"
        echo ""
    done
    
    echo "✅ All recommended models installed!"
}

# Main execution
main() {
    check_ollama
    
    case "${1:-list}" in
        list)
            list_models
            ;;
        install)
            if [ $# -lt 2 ]; then
                echo "❌ Please specify a model to install"
                usage
                exit 1
            fi
            install_model "$2"
            ;;
        remove)
            if [ $# -lt 2 ]; then
                echo "❌ Please specify a model to remove"
                usage
                exit 1
            fi
            remove_model "$2"
            ;;
        popular)
            show_popular_models
            ;;
        install-recommended)
            install_recommended
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            echo "❌ Unknown command: $1"
            usage
            exit 1
            ;;
    esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi