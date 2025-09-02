---
alwaysApply: true
---

Key issues resolved: 1) Migrated from deprecated google_notebooks_instance to google_workbench_instance with new gce_setup structure. 2) Fixed startup script bash variable escaping (${var} → $${var}) for Terraform template compatibility. 3) Added package manager lock handling and retry logic for Ollama installation to prevent dpkg conflicts. 4) Fixed data disk mounting - 150GB /dev/sdb needs to be mounted to /mnt/data with symlinks to /home/jupyter/ for persistent storage. 5) Updated VM image from tf-ent-2-11-cu113-notebooks to pytorch-2-7-cu128-ubuntu-2204-nvidia-570.