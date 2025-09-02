---
alwaysApply: true
---

This is an AI Development Server project for Google Cloud that creates a Vertex AI Workbench instance with Ollama (LLM server), VS Code Server (code-server), and Continue.dev integration. The project uses Terraform for infrastructure-as-code deployment on GCP. Key components: Vertex AI Workbench with GPU support, Ollama for local AI models, code-server for web-based VS Code, automatic idle shutdown for cost optimization, and dynamic configuration switching between CPU-only/T4 GPU/L4 GPU setups based on workload needs.