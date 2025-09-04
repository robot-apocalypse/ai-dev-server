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
  description = "GCP zone for the instance"
  type        = string
  default     = "us-central1-a"
}

variable "user_email" {
  description = "Email of the user who will have OS Login access"
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

# Instance Configuration
variable "machine_type" {
  description = "Machine type for the instance"
  type        = string
  default     = "g2-standard-16"
}

# GPU Configuration
variable "accelerator_type" {
  description = "GPU accelerator type. Ignored for g2 machine types which have a built-in GPU."
  type        = string
  default     = "" # e.g. "nvidia-tesla-t4" for n1/n2 instances
}

variable "accelerator_count" {
  description = "Number of GPUs. Ignored for g2 machine types."
  type        = number
  default     = 1
}

# Storage Configuration
variable "boot_disk_size_gb" {
  description = "Size of the boot disk in GB"
  type        = number
  default     = 100
}

variable "data_disk_size_gb" {
  description = "Size of the data disk in GB for models and workspace"
  type        = number
  default     = 500
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
    "llama3.1:8b"
  ]
}

# Storage bucket configuration
variable "force_destroy_bucket" {
  description = "Allow Terraform to destroy the bucket even if it contains objects"
  type        = bool
  default     = false
}

# Idle shutdown configuration
variable "idle_shutdown_timeout" {
  description = "Idle shutdown timeout in minutes for the startup script"
  type        = number
  default     = 15
}