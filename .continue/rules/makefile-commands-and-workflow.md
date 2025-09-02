---
globs: Makefile
alwaysApply: false
---

The Makefile provides key commands: make quick-start (interactive setup), make config-cpu/config-t4/config-l4 (switch configurations), make apply (deploy), make destroy (cleanup), make status (check instance), make tunnel (SSH tunnel for local access), make ssh (direct SSH), make logs (view setup logs), make setup-status (check if setup complete). The project supports switching between cost/performance configurations without losing data via symlinked terraform.tfvars files.