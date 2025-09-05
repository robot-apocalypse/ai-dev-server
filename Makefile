# AI Development Server - Google Cloud GCE Instance

.PHONY: help init plan apply destroy status tunnel ssh logs ollama-logs clean setup remove-models

# Default target
help: ## Show this help message
	@echo "AI Development Server (GCP Instance) - Available commands:"
	@echo
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

quick-start: ## Run the interactive first-time setup process
	@./scripts/quick-start.sh

init: ## Initialize Terraform
	terraform init

plan: ## Plan Terraform changes
	terraform plan

apply: ## Apply Terraform configuration
	terraform apply

destroy: ## Destroy all infrastructure
	terraform destroy

status: ## Show instance status and connection info
	@echo "📊 Instance Status:"
	@if terraform output instance_name >/dev/null 2>&1; then \
		INSTANCE_NAME=$$(terraform output -raw instance_name); \
		PROJECT_ID=$$(terraform output -raw project_id); \
		ZONE=$$(terraform output -raw zone); \
		echo "  Instance: $$INSTANCE_NAME"; \
		echo "  Status: $$(gcloud compute instances describe $$INSTANCE_NAME --zone=$$ZONE --project=$$PROJECT_ID --format='value(status)' 2>/dev/null || echo 'UNKNOWN')"; \
	else \
		echo "  No instance found. Run 'make apply' first."; \
	fi
	@echo
	@echo "🔗 Access Information:"
	@if terraform output ssh_tunnel_command >/dev/null 2>&1; then \
		echo "  SSH Tunnel Command: make tunnel"; \
		echo "  Code Server: $$(terraform output -raw code_server_url)"; \
		echo "  Ollama API:  $$(terraform output -raw ollama_api_url)"; \
	else \
		echo "  Deploy infrastructure first with 'make apply'"; \
	fi

ssh: ## SSH into the instance
	@if terraform output ssh_command >/dev/null 2>&1; then \
		echo "🔗 Connecting to instance..."; \
		$$(terraform output -raw ssh_command); \
	else \
		echo "❌ No instance found. Run 'make apply' first."; \
	fi

tunnel: ## Create SSH tunnel for local development
	@if terraform output ssh_tunnel_command >/dev/null 2>&1; then \
		echo "🔗 Creating SSH tunnel for local development..."; \
		echo "   Code Server: http://localhost:3000"; \
		echo "   Ollama API:  http://localhost:11434"; \
		echo ""; \
		echo "Press Ctrl+C to stop the tunnel"; \
		$$(terraform output -raw ssh_tunnel_command); \
	else \
		echo "❌ No instance found. Run 'make apply' first."; \
	fi

logs: ## Follow the VM startup script logs in real-time
	@if terraform output ssh_command >/dev/null 2>&1; then \
		echo "📋 Following startup script logs from instance... (Press Ctrl+C to stop)"; \
		$$(terraform output -raw ssh_command) -- 'sudo journalctl -u google-startup-scripts.service -f --no-pager'; \
	else \
		echo "❌ No instance found. Run 'make apply' first."; \
	fi

ollama-logs: ## Follow the logs of the ollama container in real-time
	@if terraform output ssh_command >/dev/null 2>&1; then \
		echo "📋 Following ollama container logs from instance... (Press Ctrl+C to stop)"; \
		$$(terraform output -raw ssh_command) -- 'docker logs -f ollama'; \
	else \
		echo "❌ No instance found. Run 'make apply' first."; \
	fi

setup-status: ## Check if the startup script and Docker services are complete
	@if terraform output ssh_command >/dev/null 2>&1; then \
		echo "🔍 Checking setup status..."; \
		if $$(terraform output -raw ssh_command) -- 'docker ps --filter "name=ollama" --filter "status=running" -q' | grep -q .; then \
			echo "✅ Docker services are up and running!"; \
		else \
			echo "⏳ Setup still in progress or failed. Check logs with 'make logs'"; \
		fi \
	else \
		echo "❌ No instance found. Run 'make apply' first."; \
	fi

models: ## List installed Ollama models
	@if terraform output ssh_command >/dev/null 2>&1; then \
		echo "🤖 Installed Ollama models:"; \
		$$(terraform output -raw ssh_command) -- 'docker exec ollama ollama list'; \
	else \
		echo "❌ No instance found. Run 'make apply' first."; \
	fi

install-model: ## Install a specific Ollama model (usage: make install-model MODEL=llama3.1:8b)
	@if [ -z "$(MODEL)" ]; then \
		echo "❌ Please specify a model. Usage: make install-model MODEL=llama3.1:8b"; \
		exit 1; \
	fi
	@if terraform output ssh_command >/dev/null 2>&1; then \
		echo "📥 Installing model: $(MODEL)"; \
		$$(terraform output -raw ssh_command) -- 'docker exec ollama ollama pull $(MODEL)'; \
	else \
		echo "❌ No instance found. Run 'make apply' first."; \
	fi

remove-models: ## Remove all installed Ollama models
	@if terraform output ssh_command >/dev/null 2>&1; then \
		echo "🗑️ Removing all installed Ollama models..."; \
		$$(terraform output -raw ssh_command) -- 'docker exec ollama ollama list | tail -n +2 | awk '\''{print $$1}'\'' | xargs -I {} docker exec ollama ollama rm {}'; \
		echo "✅ All models removed."; \
	else \
		echo "❌ No instance found. Run 'make apply' first."; \
	fi

config-l4: ## Switch to L4 GPU configuration
	@./scripts/switch-config.sh gpu-l4

restart-services: ## Restart the Docker Compose services on the instance
	@if terraform output ssh_command >/dev/null 2>&1; then \
		echo "🔄 Restarting Docker Compose services..."; \
		$$(terraform output -raw ssh_command) -- 'cd /opt/ai-dev-server && docker compose restart'; \
		echo "✅ Services restarted"; \
	else \
		echo "❌ No instance found. Run 'make apply' first."; \
	fi

service-status: ## Check status of Docker Compose services on the instance
	@if terraform output ssh_command >/dev/null 2>&1; then \
		echo "🔍 Docker Compose Service Status:"; \
		$$(terraform output -raw ssh_command) -- 'cd /opt/ai-dev-server && docker compose ps'; \
	else \
		echo "❌ No instance found. Run 'make apply' first."; \
	fi

rerun-startup: ## Push the latest startup.sh to the VM and re-run it
	@echo " M Updating VM metadata with the latest startup script..."
	@terraform apply -auto-approve -target=google_compute_instance.ai_instance
	@echo " M Triggering the startup script on the VM..."
	@$$(terraform output -raw ssh_command) -- 'sudo google_metadata_script_runner startup'

update-app: ## Copy the latest docker-compose.yml and redeploy the app stack
	@echo " M Copying latest docker-compose.yml to the instance..."
	@INSTANCE_NAME=$$(terraform output -raw instance_name); \
	PROJECT_ID=$$(terraform output -raw project_id); \
	ZONE=$$(terraform output -raw zone); \
	gcloud compute scp ./docker/docker-compose.yml $$INSTANCE_NAME:/opt/ai-dev-server/docker-compose.yml --project=$$PROJECT_ID --zone=$$ZONE
	@echo " M Redeploying services with 'docker compose up -d'..."
	@$$(terraform output -raw ssh_command) -- 'cd /opt/ai-dev-server && docker compose up -d'
	@echo "✅ Application update complete."

continue-config: ## Show Continue.dev configuration
	@if terraform output continue_config_local >/dev/null 2>&1; then \
		echo "🔧 Continue.dev Configuration (for local VS Code via SSH tunnel):"; \
		terraform output -raw continue_config_local | jq .; \
	else \
		echo "❌ No configuration available. Run 'make apply' first."; \
	fi

info: ## Show all connection information from terraform outputs
	@if terraform output setup_instructions >/dev/null 2>&1; then \
		terraform output -raw setup_instructions; \
	else \
		echo "❌ Infrastructure not deployed. Run 'make apply' first."; \
	fi

# Configuration switching
switch-config: ## Switch between different cost/performance configurations
	@./scripts/switch-config.sh

config-cpu: ## Switch to CPU-only configuration
	@./scripts/switch-config.sh cpu-only

config-t4: ## Switch to T4 GPU configuration
	@./scripts/switch-config.sh gpu-t4

config-l4: ## Switch to L4 GPU configuration
	@./scripts/switch-config.sh gpu-l4
