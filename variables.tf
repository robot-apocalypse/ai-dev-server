# GCP Project Configuration
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone for the workbench instance"
  type        = string
  default     = "us-central1-a"
}

variable "user_email" {
  description = "Email of the user who will access the workbench"
  type        = string
}

# Project Configuration
variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "ai-dev"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "ai-development"
}

# Workbench Configuration
variable "machine_type" {
  description = "Machine type for the workbench instance"
  type        = string
  default     = "n1-standard-8"
  validation {
    condition = contains([
      "n1-standard-4", "n1-standard-8", "n1-standard-16",
      "n1-highmem-4", "n1-highmem-8", "n1-highmem-16",
      "n2-standard-4", "n2-standard-8", "n2-standard-16",
      "n2-highmem-4", "n2-highmem-8", "n2-highmem-16",
      "c2-standard-8", "c2-standard-16", "c2-standard-30"
    ], var.machine_type)
    error_message = "Machine type must be a valid GCP machine type suitable for AI workloads."
  }
}

variable "workbench_image_project" {
  description = "Project containing the workbench image"
  type        = string
  default     = "deeplearning-platform-release"
}

variable "workbench_image_family" {
  description = "Image family for the workbench"
  type        = string
  default     = "pytorch-2-7-cu128-ubuntu-2204-nvidia-570"
}

# GPU Configuration
variable "accelerator_type" {
  description = "GPU accelerator type (empty string for no GPU)"
  type        = string
  default     = ""
  validation {
    condition = var.accelerator_type == "" || contains([
      "NVIDIA_TESLA_T4",
      "NVIDIA_TESLA_V100", 
      "NVIDIA_TESLA_P100",
      "NVIDIA_TESLA_K80",
      "NVIDIA_L4",
      "NVIDIA_A100_80GB",
      "NVIDIA_H100_80GB"
    ], var.accelerator_type)
    error_message = "Accelerator type must be a valid GPU type or empty string for no GPU."
  }
}

variable "accelerator_count" {
  description = "Number of GPUs"
  type        = number
  default     = 1
  validation {
    condition     = var.accelerator_count >= 1 && var.accelerator_count <= 4
    error_message = "Accelerator count must be between 1 and 4."
  }
}

# Storage Configuration
variable "boot_disk_size_gb" {
  description = "Size of the boot disk in GB"
  type        = number
  default     = 100
  validation {
    condition     = var.boot_disk_size_gb >= 50 && var.boot_disk_size_gb <= 1000
    error_message = "Boot disk size must be between 50GB and 1000GB."
  }
}

variable "data_disk_size_gb" {
  description = "Size of the data disk in GB for models and workspace"
  type        = number
  default     = 500
  validation {
    condition     = var.data_disk_size_gb >= 100 && var.data_disk_size_gb <= 2000
    error_message = "Data disk size must be between 100GB and 2000GB."
  }
}

# Network Configuration
variable "no_public_ip" {
  description = "If true, the workbench will not have a public IP"
  type        = bool
  default     = false
}

variable "allowed_ip_ranges" {
  description = "IP ranges allowed to access the workbench"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # WARNING: This allows all IPs. Restrict in production.
}

# Authentication
variable "code_server_password" {
  description = "Password for code-server authentication"
  type        = string
  sensitive   = true
}

# AI Models Configuration
variable "ollama_models" {
  description = "List of Ollama models to pre-install"
  type        = list(string)
  default     = [
    "codestral:22b",
    "mistral-nemo:12b",
    "llama3.1:8b",
    "deepseek-coder:6.7b"
  ]
}

variable "ollama_models_small" {
  description = "List of smaller Ollama models (for lower-spec instances)"
  type        = list(string)
  default     = [
    "codestral:22b-q4_0",
    "mistral-nemo:12b-q4_0", 
    "llama3.1:8b-q4_0",
    "phi3:3.8b"
  ]
}

# Storage bucket configuration
variable "force_destroy_bucket" {
  description = "Allow Terraform to destroy the bucket even if it contains objects"
  type        = bool
  default     = false
}

# Preemptible instance option for cost savings
variable "preemptible" {
  description = "Use preemptible instances for 60-90% cost savings (may be interrupted)"
  type        = bool
  default     = false
}

# Idle shutdown configuration
variable "idle_shutdown_timeout" {
  description = "Idle shutdown timeout in minutes (90 = 1.5 hours, 15 = 15 minutes)"
  type        = number
  default     = 15
  validation {
    condition     = var.idle_shutdown_timeout >= 10 && var.idle_shutdown_timeout <= 1440
    error_message = "Idle shutdown timeout must be between 10 minutes and 24 hours (1440 minutes)."
  }
}
