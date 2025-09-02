---
alwaysApply: true
---

Access methods: 1) SSH tunnel (make tunnel) provides localhost:8080 for VS Code Server and localhost:11434 for Ollama API. 2) Direct JupyterLab via proxy URI from Google Cloud Console. 3) Direct SSH (make ssh) for server management. User's workflow: intermittent usage (few hours/day) with 15-minute auto-shutdown for cost optimization. Continue.dev extension pre-configured to use local Ollama models for AI coding assistance. Code repositories should be cloned to ~/repositories (persistent data disk) for durability across reboots and config changes.