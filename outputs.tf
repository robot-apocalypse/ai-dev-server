# Workbench Instance Outputs
output "workbench_name" {
  description = "Name of the Vertex AI Workbench instance"
  value       = google_workbench_instance.ai_workbench.name
}

output "workbench_proxy_uri" {
  description = "Proxy URI to access the workbench (JupyterLab)"
  value       = google_workbench_instance.ai_workbench.proxy_uri
}

output "workbench_instance_owners" {
  description = "Instance owners with access to the workbench"
  value       = google_workbench_instance.ai_workbench.instance_owners
}

output "workbench_service_account" {
  description = "Service account used by the workbench"
  value       = google_workbench_instance.ai_workbench.gce_setup[0].service_accounts[0].email
}

# Network Outputs
output "workbench_network" {
  description = "Network used by the workbench"
  value       = google_compute_network.ai_network.name
}

output "workbench_subnet" {
  description = "Subnet used by the workbench"
  value       = google_compute_subnetwork.ai_subnet.name
}

# Access Information
output "code_server_url" {
  description = "URL to access code-server (via SSH tunnel or proxy)"
  value       = "http://localhost:8080 (requires SSH tunnel to workbench)"
}

output "ollama_api_url" {
  description = "URL for Ollama API (via SSH tunnel or proxy)"
  value       = "http://localhost:11434 (requires SSH tunnel to workbench)"
}

output "jupyter_url" {
  description = "Direct JupyterLab URL"
  value       = google_workbench_instance.ai_workbench.proxy_uri
}

# SSH Connection Information
output "ssh_command" {
  description = "SSH command to connect to the workbench"
  value       = "gcloud compute ssh --zone=${var.zone} --project=${var.project_id} ${google_workbench_instance.ai_workbench.name}"
}

output "ssh_tunnel_command" {
  description = "SSH tunnel command for local development"
  value       = "gcloud compute ssh --zone=${var.zone} --project=${var.project_id} ${google_workbench_instance.ai_workbench.name} -- -L 8080:localhost:8080 -L 11434:localhost:11434 -N"
}

# Storage Outputs
output "model_storage_bucket" {
  description = "Cloud Storage bucket for model storage"
  value       = google_storage_bucket.model_storage.name
}

output "model_storage_url" {
  description = "Cloud Storage bucket URL"
  value       = google_storage_bucket.model_storage.url
}

# Continue.dev Configuration
output "continue_config_local" {
  description = "Configuration for Continue.dev when using SSH tunnel"
  value = jsonencode({
    models = [
      {
        title    = "Codestral (Ollama)"
        provider = "ollama"
        model    = "codestral:22b"
        apiBase  = "http://localhost:11434"
      },
      {
        title    = "Mistral Nemo (Ollama)"
        provider = "ollama"  
        model    = "mistral-nemo:12b"
        apiBase  = "http://localhost:11434"
      },
      {
        title    = "Llama 3.1 (Ollama)"
        provider = "ollama"
        model    = "llama3.1:8b"
        apiBase  = "http://localhost:11434"
      },
      {
        title    = "DeepSeek Coder (Ollama)"
        provider = "ollama"
        model    = "deepseek-coder:6.7b"
        apiBase  = "http://localhost:11434"
      }
    ]
  })
}

output "continue_config_workbench" {
  description = "Configuration for Continue.dev when running on the workbench"
  value = jsonencode({
    models = [
      {
        title    = "Codestral (Ollama)"
        provider = "ollama"
        model    = "codestral:22b"
        apiBase  = "http://localhost:11434"
      },
      {
        title    = "Mistral Nemo (Ollama)"
        provider = "ollama"
        model    = "mistral-nemo:12b"
        apiBase  = "http://localhost:11434"
      }
    ]
  })
}

# Instance Information
output "machine_type" {
  description = "Machine type of the workbench instance"
  value       = var.machine_type
}

output "accelerator_config" {
  description = "GPU configuration"
  value = var.accelerator_type != "" ? "${var.accelerator_type} (${var.accelerator_count})" : "No GPU configured"
}

# Setup Instructions
output "setup_instructions" {
  description = "Next steps to access your AI development environment"
  value = <<-EOT
    🚀 Your AI Development Workbench is ready!
    
    📋 Access Methods:
    
    1. JupyterLab (Direct): ${google_workbench_instance.ai_workbench.proxy_uri}
    
    2. SSH Tunnel (Recommended for VS Code + Continue.dev):
       gcloud compute ssh --zone=${var.zone} --project=${var.project_id} ${google_workbench_instance.ai_workbench.name} -- -L 8080:localhost:8080 -L 11434:localhost:11434 -N
       
       Then access:
       - code-server: http://localhost:8080
       - Ollama API: http://localhost:11434
    
    3. SSH Direct Access:
       gcloud compute ssh --zone=${var.zone} --project=${var.project_id} ${google_workbench_instance.ai_workbench.name}
    
    🔧 Continue.dev Setup:
    - Use the configuration from 'continue_config_local' output
    - Install Continue extension in VS Code
    - Configure with Ollama endpoint: http://localhost:11434
    
    🤖 Pre-installed Models:
    ${jsonencode(var.ollama_models)}
    
    ⚠️  Note: Allow 5-10 minutes for initial setup to complete.
  EOT
}