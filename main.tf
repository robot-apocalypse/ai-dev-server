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

resource "google_project_service" "aiplatform" {
  service            = "aiplatform.googleapis.com"
  disable_on_destroy = false
  depends_on         = [google_project_service.compute]
}

# Create VPC network
resource "google_compute_network" "ai_network" {
  name                    = "${var.project_name}-network"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.compute]
}

resource "google_compute_subnetwork" "ai_subnet" {
  name                     = "${var.project_name}-subnet"
  ip_cidr_range            = "10.0.0.0/24"
  region                   = var.region
  network                  = google_compute_network.ai_network.id
  private_ip_google_access = true
}

# Firewall rule to allow SSH via Google's IAP
resource "google_compute_firewall" "allow_iap_ssh" {
  name          = "${var.project_name}-allow-iap-ssh"
  network       = google_compute_network.ai_network.name
  source_ranges = ["35.235.240.0/20"] # Google's IAP IP range

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags = ["ai-dev-instance"]
}

# Service account for the instance
resource "google_service_account" "instance_sa" {
  account_id   = "${var.project_name}-instance-sa"
  display_name = "AI Development Instance Service Account"
  description  = "Service account for AI development GCE instance"
}

# IAM roles for the service account
resource "google_project_iam_member" "instance_compute_admin" {
  project = var.project_id
  role    = "roles/compute.instanceAdmin.v1"
  member  = "serviceAccount:${google_service_account.instance_sa.email}"
}

resource "google_project_iam_member" "instance_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.instance_sa.email}"
}

resource "google_project_iam_member" "instance_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.instance_sa.email}"
}

resource "google_project_iam_member" "instance_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.instance_sa.email}"
}

resource "google_service_account_iam_member" "instance_sa_user" {
  service_account_id = google_service_account.instance_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "user:${var.user_email}"
}

# GCE Instance Resource
resource "google_compute_instance" "ai_instance" {
  name         = "${var.project_name}-instance"
  zone         = var.zone
  machine_type = var.machine_type
  tags         = ["ai-dev-instance"]

  boot_disk {
    initialize_params {
      image = "projects/ml-images/global/images/c0-deeplearning-common-cu113-v20241118-debian-11"
      size  = var.boot_disk_size_gb
      type  = "pd-ssd"
    }
  }

  attached_disk {
    source      = google_compute_disk.data_disk.name
    device_name = "data-disk"
  }



  dynamic "guest_accelerator" {
    for_each = !startswith(var.machine_type, "g2") && var.accelerator_type != "" ? [1] : []
    content {
      type  = var.accelerator_type
      count = var.accelerator_count
    }
  }

  scheduling {
    on_host_maintenance = "TERMINATE"
  }

  network_interface {
    network    = google_compute_network.ai_network.id
    subnetwork = google_compute_subnetwork.ai_subnet.id
    # No access_config block means no public IP, which is more secure.
  }

  service_account {
    email  = google_service_account.instance_sa.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    "enable-oslogin"     = "TRUE"
    "install-gpu-driver" = "True"
    "startup-script" = templatefile("${path.module}/scripts/startup.sh", {
      user_email            = var.user_email
      ollama_models         = jsonencode(var.ollama_models)
      idle_shutdown_timeout = var.idle_shutdown_timeout * 60,

      # Render the compose file first, injecting the password directly into it
      docker_compose_content = templatefile("${path.module}/docker/docker-compose.yml", {
        password_placeholder = var.code_server_password
      }),

      # Pass the static code-server config content
      code_server_config_content = file("${path.module}/docker/config/code-server/config.yaml")
    })
  }

  labels = {
    environment = var.environment
    purpose     = "ai-development"
    managed-by  = "terraform"
    cost-center = var.cost_center
  }

  depends_on = [
    google_project_service.aiplatform,
    google_service_account_iam_member.instance_sa_user
  ]
}

# Data disk for models and persistent storage
resource "google_compute_disk" "data_disk" {
  name = "${var.project_name}-instance-data"
  type = "pd-ssd"
  zone = var.zone
  size = var.data_disk_size_gb
  labels = {
    environment = var.environment
  }
}

# Cloud Storage bucket for backups
resource "google_storage_bucket" "model_storage" {
  name          = "${var.project_id}-${var.project_name}-models"
  location      = var.region
  force_destroy = var.force_destroy_bucket

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 30
    }
  }

  labels = {
    environment = var.environment
    purpose     = "ai-models"
    managed-by  = "terraform"
  }
}

# --- NAT Gateway for Outbound Internet Access ---

resource "google_compute_router" "router" {
  name    = "${var.project_name}-router"
  network = google_compute_network.ai_network.id
  region  = var.region
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.project_name}-nat-gateway"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  nat_ip_allocate_option = "AUTO_ONLY"

  subnetwork {
    name                    = google_compute_subnetwork.ai_subnet.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
