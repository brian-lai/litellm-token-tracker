# litellm_token_tracker

> **Workflow Methodology:** Follow `~/.agents/AGENTS.md`

## About

macOS menu bar app for tracking dollar spend from a self-hosted LiteLLM proxy.

The initial product goal is a lightweight menu bar utility that can authenticate to the LiteLLM API, read spend and usage data, and present current cost status without requiring the LiteLLM admin UI to stay open.

## API Context

- LiteLLM Swagger UI: `https://litellm-api.up.railway.app/`
- OpenAPI spec: `https://litellm-api.up.railway.app/openapi.json`
- Captured planning input: `context/data/2026-05-18-litellm-openapi.json`
- API title/version observed on initialization: `LiteLLM API` / `1.82.6`

## Expected Tech Direction

- macOS menu bar app.
- Prefer native macOS implementation unless planning identifies a better fit.
- Store API credentials locally using macOS Keychain.
- Treat spend data as sensitive operational data.

## Structure

```
context/
├── data/       # API specs, payload samples, research inputs
├── plans/      # Pre-work planning documents
├── summaries/  # Post-work reports
├── archives/   # Archived active context snapshots
└── servers/    # MCP tool wrappers
```

## Conventions

- Follow the PARA workflow for all git changes.
- Keep API keys and LiteLLM credentials out of git.
- Add tests before implementation during PARA execution.

## Getting Started

```bash
$para-plan "Build a macOS menu bar app to track dollar spend from the self-hosted LiteLLM API"
```
