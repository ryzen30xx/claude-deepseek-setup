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
echo "Setting up DeepSeek Configuration directory..."
CONFIG_DIR="$HOME/.config/mg-deepseek"
mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"

# 3. Prompt for API Key & Standardize key.env
KEY_FILE="$CONFIG_DIR/key.env"
existing_key=""
if [ -f "$KEY_FILE" ]; then
    existing_key=$(sed -E -n 's/^[[:space:]]*(export[[:space:]]+)?DEEPSEEK_API_KEY[[:space:]]*=[[:space:]]*["'"'"']?([^"'"'"'[:space:]#]+).*/\2/p' "$KEY_FILE" | tail -n 1)
fi

if [ -n "$existing_key" ] && [ "$existing_key" != "sk-your-key-here" ]; then
    echo "✅ DeepSeek API Key detected in $KEY_FILE"
    # Ensure standard formatting (no spaces around '=')
    echo "export DEEPSEEK_API_KEY=\"$existing_key\"" > "$KEY_FILE"
    chmod 600 "$KEY_FILE"
else
    read -p "Enter your DeepSeek API Key (sk-...): " api_key
    # Clean input of quotes and spaces
    api_key=$(echo "$api_key" | tr -d "'\" ")
    if [ -z "$api_key" ]; then
        echo "Error: API Key cannot be empty."
        exit 1
    fi
    echo "export DEEPSEEK_API_KEY=\"$api_key\"" > "$KEY_FILE"
    chmod 600 "$KEY_FILE"
    echo "✅ API Key saved securely."
fi

# 4. Pull Skills from External GitHub Repository
echo ""
echo "Installing custom Claude Code Skills from GitHub..."
mkdir -p "$HOME/.claude/skills"

SKILLS_REPO_URL="https://github.com/ryzen30xx/Skills.git"
TEMP_SKILLS_DIR="/tmp/claude-skills-clone"

echo "Cloning skills from $SKILLS_REPO_URL..."
rm -rf "$TEMP_SKILLS_DIR"
# Use 'gh' to clone if authenticated, else fallback to standard git
if command -v gh &> /dev/null && gh auth status &> /dev/null; then
    gh repo clone "$SKILLS_REPO_URL" "$TEMP_SKILLS_DIR" 2>/dev/null || git clone "$SKILLS_REPO_URL" "$TEMP_SKILLS_DIR" 2>/dev/null || true
else
    git clone "$SKILLS_REPO_URL" "$TEMP_SKILLS_DIR" 2>/dev/null || true
fi

if [ -d "$TEMP_SKILLS_DIR" ] && [ -n "$(ls -A "$TEMP_SKILLS_DIR" 2>/dev/null)" ]; then
    # Record list of installed skills for clean uninstallation
    find "$TEMP_SKILLS_DIR" -mindepth 1 -maxdepth 1 -exec basename {} \; > "$CONFIG_DIR/installed_skills.txt"
    cp -R "$TEMP_SKILLS_DIR/"* "$HOME/.claude/skills/"
    rm -rf "$TEMP_SKILLS_DIR"
    echo "✅ Custom skills installed successfully to ~/.claude/skills/"
else
    echo "⚠️ Notice: Skills repository unavailable or already present. Continuing..."
fi

# 5. Deploy claude-ds.sh script
echo ""
echo "Installing claude-ds runner script..."
SCRIPT_TARGET="$CONFIG_DIR/claude-ds.sh"

cat > "$SCRIPT_TARGET" << 'RUNNER_EOF'
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
    if [ "$1" = "flash" ] || [ "$1" = "--flash" ]; then
        selected_model="deepseek-v4-flash"
        shift
    elif [ "$1" = "pro" ] || [ "$1" = "--pro" ]; then
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
    "ANTHROPIC_API_KEY": "$DEEPSEEK_API_KEY"
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
RUNNER_EOF

chmod 755 "$SCRIPT_TARGET"
echo "✅ Installed claude-ds runner to $SCRIPT_TARGET"

# 6. Configure Shell RC files with isolated, clean source lines
echo ""
echo "Configuring shell profiles..."

CLEAN_BLOCK='# >>> claude-code-deepseek >>>
# Claude Code with DeepSeek API (MG-Cafe stack)
[ -f "$HOME/.config/mg-deepseek/claude-ds.sh" ] && source "$HOME/.config/mg-deepseek/claude-ds.sh"
# <<< claude-code-deepseek <<<'

configure_rc_file() {
    local rc_file="$1"
    [ ! -f "$rc_file" ] && return 0

    # Clean legacy inline function claude-ds if present
    if grep -q "function claude-ds()" "$rc_file" 2>/dev/null; then
        python3 -c "
import re
path = '$rc_file'
content = open(path).read()
content = re.sub(r'\n*# Run Claude Code with DeepSeek API \(MG-Cafe stack\)\nfunction claude-ds\(\) \{.*?\n\}\n*', '\n', content, flags=re.DOTALL)
content = re.sub(r'\n*function claude-ds\(\) \{.*?\n\}\n*', '\n', content, flags=re.DOTALL)
open(path, 'w').write(content)
" 2>/dev/null || true
    fi

    # Clean existing block if already present to avoid duplicates
    if grep -q "# >>> claude-code-deepseek >>>" "$rc_file" 2>/dev/null; then
        python3 -c "
import re
path = '$rc_file'
content = open(path).read()
content = re.sub(r'\n*# >>> claude-code-deepseek >>>.*?# <<< claude-code-deepseek <<<\n*', '\n', content, flags=re.DOTALL)
open(path, 'w').write(content)
" 2>/dev/null || true
    fi

    # Append clean block
    echo "" >> "$rc_file"
    echo "$CLEAN_BLOCK" >> "$rc_file"
    echo "✅ Updated isolated claude-ds configuration in $rc_file"
}

configure_rc_file "$HOME/.zshrc"
configure_rc_file "$HOME/.bashrc"

# 7. Automatically source / reload configuration
echo ""
echo "Reloading shell configuration..."

if [ -f "$HOME/.zshrc" ]; then
    if [ -n "$ZSH_VERSION" ]; then
        source "$HOME/.zshrc" 2>/dev/null || true
        echo "✅ Automatically reloaded ~/.zshrc in current session"
    elif command -v zsh &> /dev/null; then
        zsh -c "source $HOME/.zshrc" 2>/dev/null || true
        echo "✅ Pre-compiled and reloaded ~/.zshrc"
    fi
fi

if [ -n "$BASH_VERSION" ] && [ -f "$HOME/.bashrc" ]; then
    source "$HOME/.bashrc" 2>/dev/null || true
    echo "✅ Automatically reloaded ~/.bashrc in current session"
fi

# Always source the newly deployed runner script directly into current environment
if [ -f "$SCRIPT_TARGET" ]; then
    source "$SCRIPT_TARGET" 2>/dev/null || true
fi

echo ""
echo "=================================================="
echo "🎉 Installation Complete!"
echo "Shell configuration has been automatically reloaded."
echo ""
echo "To start Claude Code using DeepSeek, simply type:"
echo "  claude-ds"
echo "  claude-ds flash \"Your fast prompt here\""
echo "  claude-ds pro \"Your complex prompt here\""
echo "=================================================="
