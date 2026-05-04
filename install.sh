#!/usr/bin/env bash

set -e

echo "=================================================="
echo "   Claude Code DeepSeek API & Skills Installer"
echo "=================================================="
echo ""

# 1. Install Claude Code if not installed
if ! command -v claude &> /dev/null && [ ! -f ~/.local/bin/claude ]; then
    echo "Installing Claude Code..."
    curl -fsSL https://claude.ai/install.sh | bash
    # Ensure local bin is in PATH for the rest of the script
    export PATH="$HOME/.local/bin:$PATH"
else
    echo "✅ Claude Code is already installed."
fi

# 2. Setup MG-Cafe DeepSeek Configuration Directory
echo ""
echo "Setting up DeepSeek Configuration..."
mkdir -p ~/.config/mg-deepseek
chmod 700 ~/.config/mg-deepseek

# 3. Prompt for API Key
if [ -f ~/.config/mg-deepseek/key.env ]; then
    echo "✅ DeepSeek API Key already configured in ~/.config/mg-deepseek/key.env"
else
    read -p "Enter your DeepSeek API Key (sk-...): " api_key
    if [ -z "$api_key" ]; then
        echo "Error: API Key cannot be empty."
        exit 1
    fi
    echo "export DEEPSEEK_API_KEY=\"$api_key\"" > ~/.config/mg-deepseek/key.env
    chmod 600 ~/.config/mg-deepseek/key.env
    echo "✅ API Key saved securely."
fi

# 4. Copy Skills to Global Directory
echo ""
echo "Installing custom Claude Code Skills (Sub-agents)..."
mkdir -p ~/.claude/skills
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

if [ -d "$SCRIPT_DIR/skills" ]; then
    cp -R "$SCRIPT_DIR/skills/"* ~/.claude/skills/
    echo "✅ Custom skills installed successfully to ~/.claude/skills/"
else
    echo "⚠️ Warning: 'skills' directory not found in the repository. Skipping skill installation."
fi

# 5. Add Shell Alias (claude-ds)
echo ""
echo "Configuring shell aliases..."

ALIAS_FUNC='
# Run Claude Code with DeepSeek API (MG-Cafe stack)
function claude-ds() {
    source ~/.config/mg-deepseek/key.env
    if [ -z "$DEEPSEEK_API_KEY" ] || [ "$DEEPSEEK_API_KEY" = "sk-your-key-here" ]; then
        echo "Error: Please set your actual DEEPSEEK_API_KEY in ~/.config/mg-deepseek/key.env"
        return 1
    fi
    
    local selected_model="deepseek-v4-pro"
    
    # Check if the first argument is "flash" or "pro"
    if [ "$1" = "flash" ]; then
        selected_model="deepseek-v4-flash"
        shift
    elif [ "$1" = "pro" ]; then
        selected_model="deepseek-v4-pro"
        shift
    fi

    # Generate the strict settings JSON to neutralize other defaults
    cat > ~/.config/mg-deepseek/claude-deepseek-settings.json <<EOF
{
  "env": {
    "CLAUDE_CODE_USE_VERTEX": "",
    "ANTHROPIC_VERTEX_PROJECT_ID": "",
    "CLOUD_ML_REGION": "",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "",
    "ANTHROPIC_BASE_URL": "https://api.deepseek.com/anthropic",
    "ANTHROPIC_AUTH_TOKEN": "$DEEPSEEK_API_KEY",
    "ANTHROPIC_API_KEY": "$DEEPSEEK_API_KEY"
  }
}
EOF
    chmod 600 ~/.config/mg-deepseek/claude-deepseek-settings.json
    
    # Run using --bare and mapping to selected model, using task-router as the default persona
    claude --bare --settings ~/.config/mg-deepseek/claude-deepseek-settings.json --model "$selected_model" --system-prompt-file ~/.claude/skills/task-router/SKILL.md --dangerously-skip-permissions "$@"
}'

append_to_rc() {
    local rc_file="$1"
    if [ -f "$rc_file" ]; then
        if ! grep -q "function claude-ds()" "$rc_file"; then
            echo "$ALIAS_FUNC" >> "$rc_file"
            echo "✅ Added claude-ds function to $rc_file"
        else
            echo "✅ claude-ds function already exists in $rc_file"
        fi
    fi
}

append_to_rc ~/.zshrc
append_to_rc ~/.bashrc

echo ""
echo "=================================================="
echo "🎉 Installation Complete!"
echo "Please restart your terminal or run: source ~/.zshrc"
echo ""
echo "To start Claude Code using DeepSeek, simply type:"
echo "  claude-ds"
echo "  claude-ds flash \"Your fast prompt here\""
echo "=================================================="
