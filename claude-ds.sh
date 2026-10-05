#!/usr/bin/env bash

# ==============================================================================
# Claude Code + DeepSeek API Integration (MG-Cafe stack)
# ==============================================================================

claude-ds() {
    local config_dir="$HOME/.config/mg-deepseek"
    local key_file="$config_dir/key.env"
    local settings_file="$config_dir/claude-deepseek-settings.json"

    # Safely extract DEEPSEEK_API_KEY without relying on blind 'source'
    # Handles: spaces around '=', quotes (single/double), optional 'export' prefix
    local api_key=""
    if [ -n "$DEEPSEEK_API_KEY" ] && [ "$DEEPSEEK_API_KEY" != "sk-your-key-here" ]; then
        api_key="$DEEPSEEK_API_KEY"
    elif [ -f "$key_file" ]; then
        api_key=$(sed -E -n 's/^[[:space:]]*(export[[:space:]]+)?DEEPSEEK_API_KEY[[:space:]]*=[[:space:]]*["'"'"']?([^"'"'"'[:space:]#]+).*/\2/p' "$key_file" | tail -n 1)
    fi

    if [ -z "$api_key" ] || [ "$api_key" = "sk-your-key-here" ]; then
        echo "Error: Please set your actual DEEPSEEK_API_KEY in ~/.config/mg-deepseek/key.env"
        return 1
    fi

    # Standardize key.env file format if needed
    if [ -f "$key_file" ] && ! grep -q "^export DEEPSEEK_API_KEY=\"$api_key\"$" "$key_file" 2>/dev/null; then
        echo "export DEEPSEEK_API_KEY=\"$api_key\"" > "$key_file"
        chmod 600 "$key_file"
    fi

    export DEEPSEEK_API_KEY="$api_key"

    local selected_model="deepseek-v4-pro"

    # Check if the first argument is "flash" or "pro" or uses flags
    if [ "$1" = "flash" ] || [ "$1" = "--flash" ] || [ "$1" = "deepseek-flash" ]; then
        selected_model="deepseek-flash"
        shift
    elif [ "$1" = "pro" ] || [ "$1" = "--pro" ] || [ "$1" = "deepseek-v4-pro" ]; then
        selected_model="deepseek-v4-pro"
        shift
    fi

    # Generate the strict settings JSON to neutralize other defaults
    mkdir -p "$config_dir"
    cat > "$settings_file" <<EOF
{
  "env": {
    "CLAUDE_CODE_USE_VERTEX": "",
    "ANTHROPIC_VERTEX_PROJECT_ID": "",
    "CLOUD_ML_REGION": "",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "",
    "ANTHROPIC_BASE_URL": "https://api.deepseek.com/anthropic",
    "ANTHROPIC_AUTH_TOKEN": "$DEEPSEEK_API_KEY",
    "ANTHROPIC_API_KEY": "$DEEPSEEK_API_KEY",
    "CLAUDE_CODE_MAX_CONTEXT_TOKENS": "1000000",
    "CLAUDE_CODE_DISABLE_UNKNOWN_MODEL_WINDOW_ENFORCEMENT": "1"
  }
}
EOF
    chmod 600 "$settings_file"

    # Run using --bare and mapping to selected model, using task-router as the default persona if available
    local prompt_file="$HOME/.claude/skills/task-router/SKILL.md"
    if [ -f "$prompt_file" ]; then
        claude --bare --settings "$settings_file" --model "$selected_model" --system-prompt-file "$prompt_file" --dangerously-skip-permissions "$@"
    else
        claude --bare --settings "$settings_file" --model "$selected_model" --dangerously-skip-permissions "$@"
    fi
}

# Allow running directly as a script if not sourced
is_sourced() {
    if [ -n "$ZSH_VERSION" ]; then
        [[ "$ZSH_EVAL_CONTEXT" == *:file* ]]
    elif [ -n "$BASH_VERSION" ]; then
        [ "${BASH_SOURCE[0]}" != "$0" ]
    else
        return 1
    fi
}

if ! is_sourced; then
    claude-ds "$@"
fi
