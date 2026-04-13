---
description: Manage MCP (Model Context Protocol) servers — list, add, configure from Smithery Registry
effort: high
argument-hint: "[list|add <server>|status|format]"
---

Manage Model Context Protocol (MCP) servers for this project: $ARGUMENTS

> ultrathink — use extended reasoning for MCP server selection and configuration.

## MCP Tool Invocation Format

Once servers are configured in `.mcp.json`, invoke their tools using:
```
mcp__SERVER_KEY__TOOL_FUNCTION_NAME
```
Where `SERVER_KEY` is the key in `.mcp.json` under `mcpServers`.

## Instructions

### If `$ARGUMENTS` contains `list` or is empty:

1. Read `.mcp.json` to show currently configured servers
2. Show the invocation format for each tool
3. Suggest additional servers based on the tech stack in `claude/architecture.md`

### If `$ARGUMENTS` contains `add <server-name>`:

1. Check if the server name exists in the Smithery Registry: `https://registry.smithery.ai/servers/<name>`
2. Add the server configuration to `.mcp.json` under `mcpServers`
3. Update `.claude/settings.json` to include `allowedTools` permissions for the new server
4. Update `CLAUDE.md` — add a note to the Plugin Ecosystem or Critical Patterns section

### If `$ARGUMENTS` contains `status`:

1. Read `.mcp.json` — list all configured servers with their connection type
2. Check which tools each server provides
3. Verify `allowedTools` in `.claude/settings.json` is in sync with `.mcp.json`

### If `$ARGUMENTS` contains `format` or `invocations`:

Show all available MCP tool invocations from the current `.mcp.json`:

```
mcp__SERVER_KEY__TOOL_NAME
```

## Common MCP Servers by Project Type

### Web / Frontend projects
- `github` — `mcp__github__create_pull_request`, `mcp__github__list_commits`
- `web-search` — `mcp__web-search__search` (documentation lookup)
- `filesystem` — `mcp__filesystem__read_file`, `mcp__filesystem__write_file`

### Backend / API projects
- `postgres` — `mcp__postgres__query` (read-only DB access)
- `github` — PR management, issue tracking
- `web-search` — API documentation, best practices

### Data Science / ML projects
- `filesystem` — data file access
- `web-search` — research papers, library docs
- `documents` — reading large datasets or PDFs

### DevOps / Infrastructure projects
- `github` — workflow management
- `web-search` — Terraform/Kubernetes docs
- `filesystem` — config file management

## Adding a Server — Example Configuration

```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@github/mcp-server"],
      "env": {
        "GITHUB_TOKEN": "YOUR_GITHUB_TOKEN_HERE"
      },
      "startupTimeoutMillis": 10000
    },
    "web-search": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/web-search-mcp-claude-code"],
      "env": {
        "ANTHROPIC_API_KEY": "YOUR_API_KEY_HERE"
      }
    },
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres", "postgresql://user:pass@localhost/dbname"],
      "startupTimeoutMillis": 10000
    }
  }
}
```

## Security Best Practices

- **NEVER** hardcode API keys in `.mcp.json` — use env var placeholders like `"YOUR_API_KEY_HERE"`
- For database tools: prefer **read-only** access unless write is explicitly required
- Review `allowedTools` in `.claude/settings.json` — grant minimum required permissions
- Add `.mcp.json` to `.gitignore` if it contains sensitive env vars (or use a `.mcp.local.json`)

After any configuration changes, restart Claude Code for MCP servers to take effect.

