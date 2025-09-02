---
alwaysApply: true
---

Project uses symlinked terraform.tfvars files for easy configuration switching: terraform.tfvars.cpu-only (~$35-70/month for 3-6 hrs/day), terraform.tfvars.gpu-t4 (~$67-135/month), terraform.tfvars.gpu-l4 (~$125-250/month). Cost optimization includes 15-minute auto-shutdown, preemptible instance options, and right-sized storage. User ian@peakscale.solutions deploys to GCP project development-436501. Configuration switching works via make config-cpu/config-t4/config-l4 commands.