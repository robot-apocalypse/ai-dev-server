#!/bin/bash
# Fixed configuration switching script for AI Development Server

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Available configurations
CONFIGS=(
    "cpu-only:CPU-only (n1-standard-8, no GPU) - ~\$120/month for 8 hours/day"
    "gpu-t4:T4 GPU (n1-standard-8 + T4) - ~\$200/month for 8 hours/day"
    "gpu-l4:L4 GPU (n1-standard-16 + L4) - ~\$350/month for 8 hours/day"
)

show_usage() {
    echo "Usage: $0 [config-name]"
    echo ""
    echo "Available configurations:"
    for config in "${CONFIGS[@]}"; do
        name="${config%%:*}"
        desc="${config#*:}"
        echo "  $name - $desc"
    done
    echo ""
    echo "Examples:"
    echo "  $0 cpu-only     # Switch to CPU-only configuration"
    echo "  $0 gpu-t4       # Switch to T4 GPU configuration"
    echo "  $0 gpu-l4       # Switch to L4 GPU configuration"
    echo ""
    echo "Current configuration:"
    if [ -f "$PROJECT_ROOT/terraform.tfvars" ]; then
        if [ -L "$PROJECT_ROOT/terraform.tfvars" ]; then
            current_link=$(readlink "$PROJECT_ROOT/terraform.tfvars" 2>/dev/null || echo "")
            if [ -n "$current_link" ]; then
                current_config=$(basename "$current_link" | sed 's/terraform.tfvars.//')
                echo "  Active: $current_config"
            else
                echo "  Custom configuration"
            fi
        else
            echo "  Custom configuration (not managed by this script)"
        fi
    else
        echo "  No active configuration"
    fi
}

switch_config() {
    local config_name="$1"
    local config_file="terraform.tfvars.$config_name"
    
    # Validate configuration exists
    if [ ! -f "$PROJECT_ROOT/$config_file" ]; then
        echo "❌ Configuration '$config_name' not found!"
        echo "   Expected file: $config_file"
        echo ""
        echo "Available configuration files:"
        ls -la "$PROJECT_ROOT"/terraform.tfvars.* 2>/dev/null || echo "No configuration files found"
        echo ""
        show_usage
        exit 1
    fi
    
    # Remove existing terraform.tfvars (if it's a symlink or file)
    if [ -f "$PROJECT_ROOT/terraform.tfvars" ] || [ -L "$PROJECT_ROOT/terraform.tfvars" ]; then
        rm "$PROJECT_ROOT/terraform.tfvars"
    fi
    
    # Create symlink to the chosen configuration
    cd "$PROJECT_ROOT"
    ln -s "$config_file" terraform.tfvars
    
    echo "✅ Switched to configuration: $config_name"
    echo ""
    
    # Show configuration details (with safer commands)
    echo "📋 Configuration details:"
    MACHINE_TYPE=$(grep '^machine_type' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo 'Unknown')
    GPU_TYPE=$(grep '^accelerator_type' "$config_file" 2>/dev/null | cut -d'"' -f2 | grep -v '^[[:space:]]*$' || echo 'None')
    echo "   Machine type: $MACHINE_TYPE"
    echo "   GPU: $GPU_TYPE"
    
    # Show first few models safely
    echo "   Models:"
    grep -A 10 '^ollama_models' "$config_file" 2>/dev/null | grep -o '"[^"]*"' | head -3 | while read -r model; do
        echo "     - $model"
    done
    
    echo ""
    echo "🚀 Next steps:"
    echo "   1. Update project_id and user_email in terraform.tfvars if needed"
    echo "   2. Run 'make apply' to deploy/update infrastructure"
    echo "   3. Use 'make status' to check deployment"
}

# Main logic - handle arguments safely
ARG1="${1:-}"

case "$ARG1" in
    ""|"-h"|"--help")
        show_usage
        ;;
    *)
        # Check if the provided config is valid
        config_name="$ARG1"
        valid_config="false"
        
        for config in "${CONFIGS[@]}"; do
            name="${config%%:*}"
            if [ "$name" = "$config_name" ]; then
                valid_config="true"
                break
            fi
        done
        
        if [ "$valid_config" = "true" ]; then
            switch_config "$config_name"
        else
            echo "❌ Invalid configuration: $config_name"
            echo ""
            show_usage
            exit 1
        fi
        ;;
esac