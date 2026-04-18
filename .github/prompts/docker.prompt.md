---
description: Docker build, scan, and image management
agent: "agent"
argument-hint: "[build service|build all|scan service]"
---


Docker management: {{input}}

## Instructions

### Determine action from arguments:

| Argument | Action |
|----------|--------|
| `build <service>` | `docker build -t <service>:latest -f <service>/Dockerfile .` |
| `build all` | Build all services (use project-specific build command) |
| `scan <service>` | `{{SCANNER_TOOL}} image <service>:latest` |
| `compose up` | `docker compose up -d` |
| `compose down` | `docker compose down` |
| `compose logs <service>` | `docker compose logs --tail 50 <service>` |
| `prune` | `docker system prune -f` (safe — does NOT remove named volumes) |

### ⚠️ Pitfalls:
- Always check that Dockerfile `COPY` paths match actual build output
- Multi-stage builds: verify the final stage has all required runtime dependencies
