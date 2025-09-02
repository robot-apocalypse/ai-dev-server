terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Enable required APIs
resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "notebooks" {
  service            = "notebooks.googleapis.com"
  disable_on_destroy = false
  depends_on         = [google_project_service.compute]
}

resource "google_project_service" "aiplatform" {
  service            = "aiplatform.googleapis.com"
  disable_on_destroy = false
  depends_on         = [google_project_service.compute]
}

# Create VPC network for the workbench
resource "google_compute_network" "ai_network" {
  name                    = "${var.project_name}-network"
  auto_create_subnetworks = false
  depends_on             = [google_project_service.compute]
}

resource "google_compute_subnetwork" "ai_subnet" {
  name          = "${var.project_name}-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.ai_network.id
}

# Firewall rules for workbench access
resource "google_compute_firewall" "allow_workbench" {
  name    = "${var.project_name}-allow-workbench"
  network = google_compute_network.ai_network.name

  allow {
    protocol = "tcp"
    ports    = ["8080", "8888", "11434", "22", "443", "80"]
  }

  source_ranges = var.allowed_ip_ranges
  target_tags   = ["ai-workbench"]
}

# Service account for the workbench instance
resource "google_service_account" "workbench_sa" {
  account_id   = "${var.project_name}-workbench-sa"
  display_name = "AI Workbench Service Account"
  description  = "Service account for AI development workbench"
}

# IAM roles for the service account
resource "google_project_iam_member" "workbench_compute_admin" {
  project = var.project_id
  role    = "roles/compute.instanceAdmin.v1"
  member  = "serviceAccount:${google_service_account.workbench_sa.email}"
}

resource "google_project_iam_member" "workbench_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.workbench_sa.email}"
}

resource "google_project_iam_member" "workbench_ai_platform" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.workbench_sa.email}"
}

resource "google_service_account_iam_member" "workbench_permissions" {
  service_account_id = google_service_account.workbench_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "user:${var.user_email}"
}

# Vertex AI Workbench Instance (new format)
resource "google_workbench_instance" "ai_workbench" {
  name     = "${var.project_name}-workbench"
  location = var.zone

  # Machine configuration
  gce_setup {
    machine_type = var.machine_type

    # Boot disk configuration
    boot_disk {
      disk_type    = "PD_SSD"
      disk_size_gb = var.boot_disk_size_gb
    }

    # Additional data disk for models and data
    data_disks {
      disk_type    = "PD_SSD"
      disk_size_gb = var.data_disk_size_gb
    }

    # Network configuration
    network_interfaces {
      network  = google_compute_network.ai_network.id
      subnet   = google_compute_subnetwork.ai_subnet.id
      nic_type = "GVNIC"
    }

    # Enable external IP access (can be disabled for security)
    disable_public_ip = var.no_public_ip

    # VM image configuration
    vm_image {
      project = var.workbench_image_project
      family  = var.workbench_image_family
    }

    # GPU configuration for AI workloads
    dynamic "accelerator_configs" {
      for_each = var.accelerator_type != "" ? [1] : []
      content {
        type       = var.accelerator_type
        core_count = var.accelerator_count
      }
    }

    # Service account with necessary permissions
    service_accounts {
      email = google_service_account.workbench_sa.email
    }

    # Startup script to install Ollama, code-server, and models
    metadata = {
      "enable-oslogin" = "TRUE"
      "startup-script" = templatefile("${path.module}/scripts/startup.sh", {
        project_name         = var.project_name
        ollama_models        = jsonencode(var.ollama_models)
        code_server_password = var.code_server_password
        user_email          = var.user_email
      })
    }

    # Network tags for firewall rules
    tags = ["ai-workbench"]

    # Shielded VM configuration
    shielded_instance_config {
      enable_secure_boot          = false
      enable_vtpm                 = false
      enable_integrity_monitoring = false
    }
  }

  # Labels for organization
  labels = {
    environment = var.environment
    purpose     = "ai-development"
    managed-by  = "terraform"
    cost-center = var.cost_center
  }

  # Instance owners
  instance_owners = [var.user_email]

  # Lifecycle management
  lifecycle {
    ignore_changes = [
      state,
      health_state,
      update_time
    ]
  }

  depends_on = [
    google_project_service.notebooks,
    google_project_service.aiplatform,
    google_service_account_iam_member.workbench_permissions
  ]

  # Add timeout for provisioning
  timeouts {
    create = "30m"
    update = "20m"
    delete = "20m"
  }
}

# Create a Cloud Storage bucket for model storage and backups
resource "google_storage_bucket" "model_storage" {
  name          = "${var.project_id}-${var.project_name}-models"
  location      = var.region
  force_destroy = var.force_destroy_bucket

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  labels = {
    environment = var.environment
    purpose     = "ai-models"
    managed-by  = "terraform"
  }
}