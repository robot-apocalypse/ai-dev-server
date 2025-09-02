---
alwaysApply: true
---

Current deployment status: Workbench instance successfully created and running, Ollama service active with models, code-server accessible via tunnel on port 8080, but Terraform state shows PROVISIONING (known issue with new google_workbench_instance resource). Data disk (/dev/sdb 150GB) needs mounting to /mnt/data for persistent storage. Startup script updated with data disk mounting, package manager lock handling, and retry logic. SSH tunnel working, VS Code Server accessible at localhost:8080 with password 'ianiscool'. Ready for GitHub repository cloning to persistent storage.