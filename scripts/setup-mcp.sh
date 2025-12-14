#!/bin/bash
# setup-mcp.sh - Generate MCP configuration from environment variables
# Called on every sandbox launch to pick up env var changes
#
# Environment variables:
#   RAILWAY_TOKEN         - Railway API token
#   SUPABASE_ACCESS_TOKEN - Supabase access token
#   CONTEXT7_API_KEY      - Context7 API key

set -euo pipefail

MCP_FILE="$HOME/.claude.json"

# Build JSON using jq for proper escaping and validation
build_mcp_config() {
    local config='{"mcpServers":{}}'

    # Playwright (always enabled, no API key needed)
    config=$(echo "$config" | jq '.mcpServers.playwright = {
        "command": "npx",
        "args": ["@playwright/mcp"]
    }')
    echo "  + Playwright MCP enabled" >&2

    # Railway (if token provided)
    if [[ -n "${RAILWAY_TOKEN:-}" ]]; then
        config=$(echo "$config" | jq --arg token "$RAILWAY_TOKEN" '.mcpServers["railway-mcp-server"] = {
            "command": "npx",
            "args": ["-y", "@railway/mcp-server"],
            "env": {"RAILWAY_TOKEN": $token}
        }')
        echo "  + Railway MCP enabled" >&2
    else
        echo "  - Railway MCP skipped (no RAILWAY_TOKEN)" >&2
    fi

    # Supabase (local MCP server with personal access token)
    # Get your token from: https://supabase.com/dashboard/account/tokens
    if [[ -n "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
        local supabase_args='["-y", "@supabase/mcp-server-supabase@latest"]'
        if [[ -n "${SUPABASE_PROJECT_REF:-}" ]]; then
            supabase_args="["-y", \"@supabase/mcp-server-supabase@latest\", \"--project-ref\", \"${SUPABASE_PROJECT_REF}\"]"
        fi
        config=$(echo "$config" | jq --arg token "$SUPABASE_ACCESS_TOKEN" --argjson args "$supabase_args" '.mcpServers.supabase = {
            "command": "npx",
            "args": $args,
            "env": {"SUPABASE_ACCESS_TOKEN": $token}
        }')
        echo "  + Supabase MCP enabled (local)" >&2
    else
        echo "  - Supabase MCP skipped (no SUPABASE_ACCESS_TOKEN)" >&2
    fi

    # Context7 (if key provided)
    if [[ -n "${CONTEXT7_API_KEY:-}" ]]; then
        config=$(echo "$config" | jq --arg key "$CONTEXT7_API_KEY" '.mcpServers.context7 = {
            "command": "npx",
            "args": ["-y", "@upstash/context7-mcp", "--api-key", $key]
        }')
        echo "  + Context7 MCP enabled" >&2
    else
        echo "  - Context7 MCP skipped (no CONTEXT7_API_KEY)" >&2
    fi

    echo "$config"
}

echo "Configuring MCP servers..."
config=$(build_mcp_config)

# Write and validate
echo "$config" | jq '.' > "$MCP_FILE"

# Validate the generated JSON
if ! jq empty "$MCP_FILE" 2>/dev/null; then
    echo "ERROR: Generated invalid mcp.json" >&2
    cat "$MCP_FILE" >&2
    exit 1
fi

server_count=$(jq '.mcpServers | keys | length' "$MCP_FILE")
echo "MCP configuration complete: $server_count server(s) configured"
