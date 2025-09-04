# --- Core Instance Outputs ---

output "instance_name" {
  description = "Name of the GCE instance."
  value       = google_compute_instance.ai_instance.name
}

output "instance_service_account" {
  description = "Service account used by the instance."
  value       = google_compute_instance.ai_instance.service_account[0].email
}

output "project_id" {
  description = "The GCP project ID."
  value       = var.project_id
}

output "zone" {
  description = "The GCP zone of the instance."
  value       = var.zone
}

# --- Network Outputs ---

output "network_name" {
  description = "Network used by the instance."
  value       = google_compute_network.ai_network.name
}

output "subnet_name" {
  description = "Subnet used by the instance."
  value       = google_compute_subnetwork.ai_subnet.name
}

# --- Access Information ---

output "code_server_url" {
  description = "URL to access code-server (via SSH tunnel)."
  value       = "http://localhost:3000"
}

output "ollama_api_url" {
  description = "URL for Ollama API (via SSH tunnel)."
  value       = "http://localhost:11434"
}

# --- SSH Connection Information ---

output "ssh_command" {
  description = "SSH command to connect to the instance."
  value       = local.ssh_command
}

output "ssh_tunnel_command" {
  description = "SSH tunnel command for local development."
  value       = local.ssh_tunnel_command
}

# --- Storage Outputs ---

output "model_storage_bucket" {
  description = "Cloud Storage bucket for model storage."
  value       = google_storage_bucket.model_storage.name
}

# --- Continue.dev Configuration ---

output "continue_config_local" {
  description = "Configuration for Continue.dev when using SSH tunnel."
  sensitive   = true
  value = jsonencode({
    models = [
      for model in var.ollama_models : {
        title    = "Ollama (${model})"
        provider = "ollama"
        model    = model
        apiBase  = "http://localhost:11434"
      }
    ]
  })
}

# --- Instance Configuration Information ---

output "machine_type" {
  description = "Machine type of the instance."
  value       = var.machine_type
}

output "accelerator_config" {
  description = "GPU configuration."
  # Improved logic to handle built-in GPUs for g2 instances
  value       = substr(var.machine_type, 0, 2) == "g2" ? "NVIDIA L4 (included with g2 instance)" : (var.accelerator_type != "" ? "${var.accelerator_type} (${var.accelerator_count})" : "No GPU configured")
}

# --- Setup Instructions ---

output "setup_instructions" {
  description = "Next steps to access your AI development environment."
  value = <<-EOT
    🚀 Your AI Development VM is ready!
    
    📋 Access Methods:
    
    1. SSH Tunnel (Recommended for VS Code + Continue.dev):
       ${local.ssh_tunnel_command}
       
       Then access:
       - code-server: http://localhost:3000
       - Ollama API:  http://localhost:11434
    
    2. SSH Direct Access:
       ${local.ssh_command}
    
    🔧 Continue.dev Setup:
    - Run 'make continue-config' to get the JSON config.
    - Install Continue extension in VS Code.
    
    🤖 Models to be installed by startup script:
    ${jsonencode(var.ollama_models)}
    
    ⚠️  Note: Allow 5-10 minutes for the startup script to complete.
        Check progress with 'make logs' or 'make setup-status'.
  EOT
}

# --- Locals for cleaner code ---
locals {
  # Updated to reference the new instance name
  ssh_command        = "gcloud compute ssh --zone=${var.zone} --project=${var.project_id} ${google_compute_instance.ai_instance.name}"
  ssh_tunnel_command = "gcloud compute ssh --zone=${var.zone} --project=${var.project_id} ${google_compute_instance.ai_instance.name} -- -N -L 3000:localhost:3000 -L 11434:localhost:11434"
}