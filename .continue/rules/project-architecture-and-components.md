---
alwaysApply: true
---

The project creates 13 Terraform resources: 3 GCP API services (compute, notebooks, aiplatform), VPC network with subnet and firewall rules, service account with IAM permissions, google_workbench_instance (migrated from deprecated google_notebooks_instance), and Cloud Storage bucket for model backup. The workbench runs Ubuntu 22.04 with PyTorch image, includes 100GB boot disk + 150GB data disk, and supports optional GPU acceleration (T4, L4, or CPU-only configs).