# AI Development Server - Google Cloud Vertex AI Workbench

.PHONY: help init plan apply destroy status tunnel ssh logs clean setup

# Default target
help: ## Show this help message
	@echo "AI Development Server (GCP Vertex AI Workbench) - Available commands:"
	@echo
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

setup: ## Run the complete setup process
	@./scripts/setup.sh

quick-start: ## Interactive quick start setup
	@./scripts/quick-start-v2.sh

init: ## Initialize Terraform
	terraform init

plan: ## Plan Terraform changes
	terraform plan

apply: ## Apply Terraform configuration
	terraform apply

destroy: ## Destroy all infrastructure
	terraform destroy

status: ## Show workbench instance status
	@echo "📊 Workbench Status:"
	@if terraform output workbench_name >/dev/null 2>&1; then \
		INSTANCE_NAME=$$(terraform output -raw workbench_name); \
		PROJECT_ID=$$(terraform output -raw project_id 2>/dev/null || echo "unknown"); \
		ZONE=$$(terraform output -raw zone 2>/dev/null || echo "unknown"); \
		echo "  Instance: $$INSTANCE_NAME"; \
		echo "  Status: $$(gcloud compute instances describe $$INSTANCE_NAME --zone=$$ZONE --project=$$PROJECT_ID --format='value(status)' 2>/dev/null || echo 'UNKNOWN')"; \
	else \
		echo "  No workbench instance found. Run 'make apply' first."; \
	fi
	@echo
	@echo "🔗 Access Information:"
	@if terraform output jupyter_url >/dev/null 2>&1; then \
		echo "  JupyterLab: $$(terraform output -raw jupyter_url)"; \
		echo "  SSH Tunnel: $$(terraform output -raw ssh_tunnel_command)"; \
	else \
		echo "  Deploy infrastructure first with 'make apply'"; \
	fi

ssh: ## SSH into the workbench instance
	@if terraform output ssh_command >/dev/null 2>&1; then \
		echo "🔗 Connecting to workbench..."; \
		eval "$$(terraform output -raw ssh_command)"; \
	else \
		echo "❌ No workbench instance found. Run 'make apply' first."; \
	fi

tunnel: ## Create SSH tunnel for local development (code-server + Ollama)
	@if terraform output ssh_tunnel_command >/dev/null 2>&1; then \
		echo "🔗 Creating SSH tunnel for local development..."; \
		echo "   code-server: http://localhost:8080"; \
		echo "   Ollama API:  http://localhost:11434"; \
		echo ""; \
		echo "Press Ctrl+C to stop the tunnel"; \
		eval "$$(terraform output -raw ssh_tunnel_command)"; \
	else \
		echo "❌ No workbench instance found. Run 'make apply' first."; \
	fi

logs: ## Show workbench setup logs
	@if terraform output ssh_command >/dev/null 2>&1; then \
		echo "📋 Fetching setup logs from workbench..."; \
		eval "$$(terraform output -raw ssh_command)" -- 'sudo tail -50 /var/log/ai-workbench-setup.log' 2>/dev/null || \
		echo "❌ Could not fetch logs. The instance might not be ready yet."; \
	else \
		echo "❌ No workbench instance found. Run 'make apply' first."; \
	fi

setup-status: ## Check if workbench setup is complete
	@if terraform output ssh_command >/dev/null 2>&1; then \
		echo "🔍 Checking setup status..."; \
		if eval "$$(terraform output -raw ssh_command)" -- 'test -f /var/log/ai-workbench-setup-complete' 2>/dev/null; then \
			echo "✅ Workbench setup is complete!"; \
			echo ""; \
			eval "$$(terraform output -raw ssh_command)" -- 'sudo tail -10 /var/log/ai-workbench-setup.log' 2>/dev/null || true; \
		else \
			echo "⏳ Setup still in progress or failed. Check logs with 'make logs'"; \
		fi \
	else \
		echo "❌ No workbench instance found. Run 'make apply' first."; \
	fi

models: ## List installed Ollama models
	@if terraform output ssh_command >/dev/null 2>&1; then \
		echo "🤖 Installed Ollama models:"; \
		eval "$$(terraform output -raw ssh_command)" -- 'ollama list' 2>/dev/null || \
		echo "❌ Could not fetch models. The instance might not be ready yet."; \
	else \
		echo "❌ No workbench instance found. Run 'make apply' first."; \
	fi

install-model: ## Install a specific Ollama model (usage: make install-model MODEL=llama3.1:8b)
	@if [ -z "$(MODEL)" ]; then \
		echo "❌ Please specify a model. Usage: make install-model MODEL=llama3.1:8b"; \
		exit 1; \
	fi
	@if terraform output ssh_command >/dev/null 2>&1; then \
		echo "📥 Installing model: $(MODEL)"; \
		eval "$$(terraform output -raw ssh_command)" -- 'ollama pull $(MODEL)' || \
		echo "❌ Failed to install model. Check if the workbench is ready."; \
	else \
		echo "❌ No workbench instance found. Run 'make apply' first."; \
	fi

clean: ## Clean up local Terraform state
	rm -rf .terraform/
	rm -f .terraform.lock.hcl
	rm -f terraform.tfstate.backup

restart-services: ## Restart Ollama and code-server services
	@if terraform output ssh_command >/dev/null 2>&1; then \
		echo "🔄 Restarting services..."; \
		eval "$$(terraform output -raw ssh_command)" -- 'sudo systemctl restart ollama code-server'; \
		echo "✅ Services restarted"; \
	else \
		echo "❌ No workbench instance found. Run 'make apply' first."; \
	fi

service-status: ## Check status of services on the workbench
	@if terraform output ssh_command >/dev/null 2>&1; then \
		echo "🔍 Service Status:"; \
		eval "$$(terraform output -raw ssh_command)" -- 'systemctl status ollama code-server --no-pager -l' 2>/dev/null || \
		echo "❌ Could not fetch service status."; \
	else \
		echo "❌ No workbench instance found. Run 'make apply' first."; \
	fi

continue-config: ## Show Continue.dev configuration
	@if terraform output continue_config_local >/dev/null 2>&1; then \
		echo "🔧 Continue.dev Configuration (for local VS Code via SSH tunnel):"; \
		terraform output -raw continue_config_local | jq .; \
		echo ""; \
		echo "📝 To use:"; \
		echo "1. Run 'make tunnel' to create SSH tunnel"; \
		echo "2. Copy the above JSON to your Continue config"; \
		echo "3. Install Continue extension in VS Code"; \
	else \
		echo "❌ No configuration available. Run 'make apply' first."; \
	fi

info: ## Show all connection information
	@echo "🚀 AI Development Workbench Information"
	@echo "======================================"
	@if terraform output setup_instructions >/dev/null 2>&1; then \
		terraform output -raw setup_instructions; \
	else \
		echo "❌ Infrastructure not deployed. Run 'make apply' first."; \
	fi

# Development shortcuts
dev-tunnel: tunnel  ## Alias for tunnel command

backup: ## Create backup of important workbench data  
	@if terraform output ssh_command >/dev/null 2>&1; then \
		echo "💾 Creating backup..."; \
		TIMESTAMP=$$(date +%Y%m%d_%H%M%S); \
		mkdir -p backups/$$TIMESTAMP; \
		echo "📦 Backing up Ollama models and configurations..."; \
		eval "$$(terraform output -raw ssh_command)" -- 'sudo tar -czf /tmp/workbench-backup.tar.gz /home/jupyter/.ollama /home/jupyter/.continue /home/jupyter/workspace /home/jupyter/projects 2>/dev/null'; \
		scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $$(terraform output -raw ssh_command | sed 's/gcloud compute ssh/gcloud compute scp/; s/--zone=/--zone /; s/--project=/--project /; s/ai-dev-workbench:/tmp\/workbench-backup.tar.gz/') backups/$$TIMESTAMP/ 2>/dev/null; \
		echo "✅ Backup created in backups/$$TIMESTAMP/"; \
	else \
		echo "❌ No workbench instance found. Run 'make apply' first."; \
	fi

# Configuration switching
switch-config: ## Switch between different cost/performance configurations
	@./scripts/switch-config-fixed.sh

config-cpu: ## Switch to CPU-only configuration (lowest cost)
	@./scripts/switch-config-fixed.sh cpu-only

config-t4: ## Switch to T4 GPU configuration (balanced cost/performance)
	@./scripts/switch-config-fixed.sh gpu-t4

config-l4: ## Switch to L4 GPU configuration (high performance)
	@./scripts/switch-config-fixed.sh gpu-l4

# Cost monitoring with hourly estimates for intermittent use
cost-estimate: ## Show estimated costs for different usage patterns
	@echo "💰 Estimated Costs Based on Usage Patterns:"
	@echo "==========================================="
	@echo "Current configuration:"
	@echo "  Instance type: $$(terraform output -raw machine_type 2>/dev/null || echo 'Unknown')"
	@echo "  GPU: $$(terraform output -raw accelerator_config 2>/dev/null || echo 'None')"
	@echo ""
	@echo "📊 Cost estimates for different usage patterns:"
	@echo "  Light use (2-3 hours/day):  ~25% of monthly rate"
	@echo "  Medium use (6-8 hours/day): ~33% of monthly rate"
	@echo "  Heavy use (12+ hours/day):  ~50% of monthly rate"
	@echo ""
	@echo "💡 Cost-saving tips:"
	@echo "  - Use preemptible instances for 60-90% discount"
	@echo "  - Auto-shutdown after 15 minutes idle (already configured)"
	@echo "  - Switch configurations based on workload needs"
	@echo ""
	@echo "⚠️  For exact pricing, use GCP Pricing Calculator:"
	@echo "   https://cloud.google.com/products/calculator"