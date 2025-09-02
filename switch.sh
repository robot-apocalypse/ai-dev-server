#!/bin/bash
# Simple config switcher

CONFIG=${1:-gpu-t4}

if [ -f "terraform.tfvars.$CONFIG" ]; then
    cp "terraform.tfvars.$CONFIG" "terraform.tfvars"
    echo "✅ Switched to $CONFIG configuration"
    echo "📋 Current config:"
    echo "   Machine: $(grep 'machine_type' terraform.tfvars | cut -d'"' -f2)"
    echo "   GPU: $(grep 'accelerator_type' terraform.tfvars | cut -d'"' -f2)"
    echo ""
    echo "🚀 Run: make apply"
else
    echo "❌ Config file terraform.tfvars.$CONFIG not found"
    echo "Available configs:"
    ls terraform.tfvars.* 2>/dev/null || echo "None found"
fi