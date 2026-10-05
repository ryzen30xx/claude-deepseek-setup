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

# 2. Setup DeepSeek Configuration Directory
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
    echo "export DEEPSEEK_API_KEY=\"$existing_key\"" > "$KEY_FILE"
    chmod 600 "$KEY_FILE"
else
    printf "Enter your DeepSeek API Key (sk-...): "
    read -r api_key
    api_key=$(echo "$api_key" | tr -d "'\" ")
    if [ -z "$api_key" ]; then
        echo "Error: API Key cannot be empty."
        exit 1
    fi
    echo "export DEEPSEEK_API_KEY=\"$api_key\"" > "$KEY_FILE"
    chmod 600 "$KEY_FILE"
    echo "✅ API Key saved securely."
fi

# Initialize default profile (Pro + 128k context) if not already set
PROFILE_FILE="$CONFIG_DIR/profile.env"
if [ ! -f "$PROFILE_FILE" ]; then
    cat > "$PROFILE_FILE" << 'EOF'
export DEFAULT_MODEL="deepseek-v4-pro"
export DEFAULT_CONTEXT="128k"
EOF
    chmod 600 "$PROFILE_FILE"
    echo "✅ Initialized default profile: deepseek-v4-pro (128K context)"
fi

# 4. Pull Skills from External GitHub Repository
echo ""
echo "Installing custom Claude Code Skills from GitHub..."
mkdir -p "$HOME/.claude/skills"

SKILLS_REPO_URL="https://github.com/ryzen30xx/Skills.git"
TEMP_SKILLS_DIR="/tmp/claude-skills-clone"

echo "Cloning skills from $SKILLS_REPO_URL..."
rm -rf "$TEMP_SKILLS_DIR"
if command -v gh &> /dev/null && gh auth status &> /dev/null; then
    gh repo clone "$SKILLS_REPO_URL" "$TEMP_SKILLS_DIR" 2>/dev/null || git clone "$SKILLS_REPO_URL" "$TEMP_SKILLS_DIR" 2>/dev/null || true
else
    git clone "$SKILLS_REPO_URL" "$TEMP_SKILLS_DIR" 2>/dev/null || true
fi

if [ -d "$TEMP_SKILLS_DIR" ] && [ -n "$(ls -A "$TEMP_SKILLS_DIR" 2>/dev/null)" ]; then
    find "$TEMP_SKILLS_DIR" -mindepth 1 -maxdepth 1 -exec basename {} \; > "$CONFIG_DIR/installed_skills.txt"
    cp -R "$TEMP_SKILLS_DIR/"* "$HOME/.claude/skills/"
    rm -rf "$TEMP_SKILLS_DIR"
    echo "✅ Custom skills installed successfully to ~/.claude/skills/"
else
    echo "⚠️ Notice: Skills repository unavailable or already present. Continuing..."
fi

# 5. Configure Claude Code global settings (~/.claude/settings.json)
echo ""
echo "Configuring Claude Code model picker..."
mkdir -p "$HOME/.claude"
python3 - << 'PY_EOF' 2>/dev/null || true
import json, os

settings_path = os.path.expanduser("~/.claude/settings.json")
data = {}
if os.path.exists(settings_path):
    try:
        data = json.load(open(settings_path))
    except Exception:
        data = {}

data["model"] = "deepseek-v4-pro"
data["modelPicker"] = {
    "options": [
        {
            "model": "deepseek-v4-pro",
            "label": "DeepSeek V4 Pro",
            "description": "DeepSeek-V4-Pro-0813 · Reasoning & Coding"
        },
        {
            "model": "deepseek-flash",
            "label": "DeepSeek Flash",
            "description": "DeepSeek-V4.1-Flash · Fast & Efficient"
        }
    ],
    "replaceBuiltInOptions": True
}
data.pop("modelOverrides", None)
data["modelSettings"] = {
    "deepseek-v4-pro": {
        "effortLevel": "low"
    },
    "deepseek-flash": {
        "effortLevel": "low"
    }
}
data["skipDangerousModePermissionPrompt"] = True
data["theme"] = "dark"

with open(settings_path, "w") as f:
    json.dump(data, f, indent=2)

# Auto-approve workspace trust for home directory in ~/.claude.json
claude_json_path = os.path.expanduser("~/.claude.json")
if os.path.exists(claude_json_path):
    try:
        c = json.load(open(claude_json_path))
        home = os.path.expanduser("~")
        if "projects" not in c:
            c["projects"] = {}
        if home not in c["projects"]:
            c["projects"][home] = {}
        c["projects"][home]["hasTrustDialogAccepted"] = True
        json.dump(c, open(claude_json_path, "w"), indent=2)
    except Exception:
        pass
PY_EOF
echo "✅ Configured model picker in ~/.claude/settings.json"

# 6. Deploy claude-ds.sh script
echo ""
echo "Installing claude-ds runner script..."
SCRIPT_TARGET="$CONFIG_DIR/claude-ds.sh"

cat > "$SCRIPT_TARGET" << 'RUNNER_EOF'
#!/usr/bin/env bash

# ==============================================================================
# Claude Code + DeepSeek API Integration
# Context Profiles: 128K, 256K, 500K, 1M
# Model Profiles: deepseek-v4-pro (Pro), deepseek-flash (Flash)
# ==============================================================================

claude-ds() {
    local config_dir="$HOME/.config/mg-deepseek"
    local key_file="$config_dir/key.env"
    local profile_file="$config_dir/profile.env"
    local settings_file="$config_dir/claude-deepseek-settings.json"

    mkdir -p "$config_dir"

    # 1. Safely extract DEEPSEEK_API_KEY without relying on blind 'source'
    local api_key=""
    if [ -n "$DEEPSEEK_API_KEY" ] && [ "$DEEPSEEK_API_KEY" != "sk-your-key-here" ]; then
        api_key="$DEEPSEEK_API_KEY"
    elif [ -f "$key_file" ]; then
        api_key=$(sed -E -n 's/^[[:space:]]*(export[[:space:]]+)?DEEPSEEK_API_KEY[[:space:]]*=[[:space:]]*["'"'"']?([^"'"'"'[:space:]#]+).*/\2/p' "$key_file" | tail -n 1)
    fi

    if [ -z "$api_key" ] || [ "$api_key" = "sk-your-key-here" ]; then
        echo "❌ Error: Please set your actual DEEPSEEK_API_KEY in ~/.config/mg-deepseek/key.env"
        return 1
    fi

    # Standardize key.env file format if needed
    if [ -f "$key_file" ] && ! grep -q "^export DEEPSEEK_API_KEY=\"$api_key\"$" "$key_file" 2>/dev/null; then
        echo "export DEEPSEEK_API_KEY=\"$api_key\"" > "$key_file"
        chmod 600 "$key_file"
    fi

    export DEEPSEEK_API_KEY="$api_key"

    # 2. Read persistent default profile if configured
    local default_model="deepseek-v4-pro"
    local default_context="128k"

    if [ -f "$profile_file" ]; then
        local saved_m=$(sed -E -n 's/^[[:space:]]*(export[[:space:]]+)?DEFAULT_MODEL[[:space:]]*=[[:space:]]*["'"'"']?([^"'"'"'[:space:]#]+).*/\2/p' "$profile_file" | tail -n 1)
        [ -n "$saved_m" ] && default_model="$saved_m"
        local saved_c=$(sed -E -n 's/^[[:space:]]*(export[[:space:]]+)?DEFAULT_CONTEXT[[:space:]]*=[[:space:]]*["'"'"']?([^"'"'"'[:space:]#]+).*/\2/p' "$profile_file" | tail -n 1)
        [ -n "$saved_c" ] && default_context="$saved_c"
    fi

    # 3. Handle subcommands: help, config, profile / menu
    if [ "$1" = "help" ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        echo "========================================================================"
        echo "⚡ Claude Code with DeepSeek API Launcher"
        echo "========================================================================"
        echo "Usage:"
        echo "  claude-ds [model] [context] [claude-options...]"
        echo "  claude-ds profile                  Interactive profile selector"
        echo "  claude-ds config                   View current defaults"
        echo "  claude-ds config context <size>    Set persistent context (128k, 256k, 500k, 1m)"
        echo "  claude-ds config model <model>     Set persistent model (pro, flash)"
        echo ""
        echo "Models:"
        echo "  pro, deepseek-v4-pro               DeepSeek-V4-Pro-0813 (Reasoning & Coding)"
        echo "  flash, deepseek-flash              DeepSeek-V4.1-Flash (Fast & Efficient)"
        echo ""
        echo "Context Profiles:"
        echo "  128k (128,000 tokens)              Cost-Saver (Tiết kiệm token & chi phí tối đa)"
        echo "  256k (256,000 tokens)              Balanced (Cân bằng giữa ngữ cảnh và chi phí)"
        echo "  500k (500,000 tokens)              Deep Refactor (Cho dự án lớn & nhiều file)"
        echo "  1m   (1,000,000 tokens)            Maximum Context (Toàn bộ 1M context DeepSeek)"
        echo ""
        echo "Examples:"
        echo "  claude-ds                          Start with default profile"
        echo "  claude-ds 128k                     Start with 128K context"
        echo "  claude-ds pro 256k                 Start Pro with 256K context"
        echo "  claude-ds flash 128k               Start Flash with 128K context"
        echo "  claude-ds flash 1m \"Quick test\"    Start Flash with 1M context"
        echo "========================================================================"
        return 0
    fi

    if [ "$1" = "config" ]; then
        if [ "$2" = "context" ] && [ -n "$3" ]; then
            local new_c=$(echo "$3" | tr '[:upper:]' '[:lower:]')
            case "$new_c" in
                128k|256k|500k|1m|1000k)
                    [ "$new_c" = "1000k" ] && new_c="1m"
                    echo "export DEFAULT_MODEL=\"$default_model\"" > "$profile_file"
                    echo "export DEFAULT_CONTEXT=\"$new_c\"" >> "$profile_file"
                    chmod 600 "$profile_file"
                    echo "✅ Saved default context: $new_c"
                    return 0
                    ;;
                *)
                    echo "❌ Invalid context limit: $3. Choose: 128k, 256k, 500k, 1m"
                    return 1
                    ;;
            esac
        elif [ "$2" = "model" ] && [ -n "$3" ]; then
            local new_m=$(echo "$3" | tr '[:upper:]' '[:lower:]')
            case "$new_m" in
                pro|deepseek-v4-pro)
                    echo "export DEFAULT_MODEL=\"deepseek-v4-pro\"" > "$profile_file"
                    echo "export DEFAULT_CONTEXT=\"$default_context\"" >> "$profile_file"
                    chmod 600 "$profile_file"
                    echo "✅ Saved default model: deepseek-v4-pro"
                    return 0
                    ;;
                flash|deepseek-flash)
                    echo "export DEFAULT_MODEL=\"deepseek-flash\"" > "$profile_file"
                    echo "export DEFAULT_CONTEXT=\"$default_context\"" >> "$profile_file"
                    chmod 600 "$profile_file"
                    echo "✅ Saved default model: deepseek-flash"
                    return 0
                    ;;
                *)
                    echo "❌ Invalid model: $3. Choose: pro, flash"
                    return 1
                    ;;
            esac
        else
            echo "========================================================================"
            echo "Current Claude Code DeepSeek Defaults:"
            echo "  Default Model:   $default_model"
            echo "  Default Context: $default_context"
            echo ""
            echo "Change defaults via:"
            echo "  claude-ds config context <128k|256k|500k|1m>"
            echo "  claude-ds config model <pro|flash>"
            echo "========================================================================"
            return 0
        fi
    fi

    local selected_model=""
    local selected_context=""
    local pass_args=()

    # Interactive Profile Selector
    if [ "$1" = "profile" ] || [ "$1" = "-p" ] || [ "$1" = "menu" ]; then
        echo ""
        echo "========================================================================"
        echo "   ⚡ DeepSeek Model & Context Profile Selector"
        echo "========================================================================"
        echo "   DeepSeek V4 Pro (Reasoning & Coding):"
        echo "     1) Pro  - 128K Context  (Tiết kiệm chi phí, khuyên dùng hàng ngày)"
        echo "     2) Pro  - 256K Context  (Cân bằng chi phí & ngữ cảnh)"
        echo "     3) Pro  - 500K Context  (Deep Refactor, dự án lớn)"
        echo "     4) Pro  - 1M   Context  (Maximum Context - 1 triệu tokens)"
        echo ""
        echo "   DeepSeek Flash (Fast & Efficient):"
        echo "     5) Flash - 128K Context (Siêu tốc độ & siêu rẻ)"
        echo "     6) Flash - 256K Context (Nhanh & cân bằng)"
        echo "     7) Flash - 500K Context (Dự án lớn, tốc độ cao)"
        echo "     8) Flash - 1M   Context (Maximum Context, tốc độ cao)"
        echo "========================================================================"
        printf "Chọn profile [1-8] (mặc định 1): "
        read -r profile_choice
        case "$profile_choice" in
            1|"") selected_model="deepseek-v4-pro"; selected_context="128k" ;;
            2)    selected_model="deepseek-v4-pro"; selected_context="256k" ;;
            3)    selected_model="deepseek-v4-pro"; selected_context="500k" ;;
            4)    selected_model="deepseek-v4-pro"; selected_context="1m" ;;
            5)    selected_model="deepseek-flash";  selected_context="128k" ;;
            6)    selected_model="deepseek-flash";  selected_context="256k" ;;
            7)    selected_model="deepseek-flash";  selected_context="500k" ;;
            8)    selected_model="deepseek-flash";  selected_context="1m" ;;
            *)    echo "❌ Lựa chọn không hợp lệ."; return 1 ;;
        esac
        shift
        pass_args=("$@")
    else
        # 4. Parse Model & Context flags/arguments
        while [ $# -gt 0 ]; do
            local arg="$1"
            local lower_arg=$(echo "$arg" | tr '[:upper:]' '[:lower:]')
            case "$lower_arg" in
                pro|--pro|deepseek-v4-pro)
                    selected_model="deepseek-v4-pro"
                    shift
                    ;;
                flash|--flash|deepseek-flash)
                    selected_model="deepseek-flash"
                    shift
                    ;;
                128k|--128k)
                    selected_context="128k"
                    shift
                    ;;
                256k|--256k)
                    selected_context="256k"
                    shift
                    ;;
                500k|--500k)
                    selected_context="500k"
                    shift
                    ;;
                1m|--1m|1000k|--1000k)
                    selected_context="1m"
                    shift
                    ;;
                -c|--context)
                    if [ -n "$2" ]; then
                        local c_arg=$(echo "$2" | tr '[:upper:]' '[:lower:]')
                        case "$c_arg" in
                            128k|256k|500k|1m|1000k)
                                [ "$c_arg" = "1000k" ] && c_arg="1m"
                                selected_context="$c_arg"
                                shift 2
                                ;;
                            *)
                                echo "❌ Invalid context limit: $2. Choose: 128k, 256k, 500k, 1m"
                                return 1
                                ;;
                        esac
                    else
                        shift
                    fi
                    ;;
                -m|--model)
                    if [ -n "$2" ]; then
                        local m_arg=$(echo "$2" | tr '[:upper:]' '[:lower:]')
                        case "$m_arg" in
                            pro|deepseek-v4-pro)
                                selected_model="deepseek-v4-pro"
                                shift 2
                                ;;
                            flash|deepseek-flash)
                                selected_model="deepseek-flash"
                                shift 2
                                ;;
                            *)
                                echo "❌ Invalid model: $2. Choose: pro, flash"
                                return 1
                                ;;
                        esac
                    else
                        shift
                    fi
                    ;;
                *)
                    pass_args+=("$1")
                    shift
                    ;;
            esac
        done
    fi

    # Fallback to configured defaults if not specified
    [ -z "$selected_model" ] && selected_model="$default_model"
    [ -z "$selected_context" ] && selected_context="$default_context"

    # Map context profile to exact token limit & friendly label
    local max_tokens="128000"
    local context_label="128K (Cost-Saver)"
    case "$selected_context" in
        128k)
            max_tokens="128000"
            context_label="128K (Cost-Saver)"
            ;;
        256k)
            max_tokens="256000"
            context_label="256K (Balanced)"
            ;;
        500k)
            max_tokens="500000"
            context_label="500K (Deep Refactor)"
            ;;
        1m)
            max_tokens="1000000"
            context_label="1M (Maximum Context)"
            ;;
        *)
            max_tokens="128000"
            context_label="128K (Cost-Saver)"
            ;;
    esac

    # 5. Export session-level environment variables
    export ANTHROPIC_BASE_URL="https://api.deepseek.com/anthropic"
    export ANTHROPIC_AUTH_TOKEN="$api_key"
    export ANTHROPIC_API_KEY="$api_key"
    export CLAUDE_CODE_MAX_CONTEXT_TOKENS="$max_tokens"
    export CLAUDE_CODE_DISABLE_UNKNOWN_MODEL_WINDOW_ENFORCEMENT="1"

    # 6. Generate settings JSON file
    cat > "$settings_file" <<EOF
{
  "env": {
    "CLAUDE_CODE_USE_VERTEX": "",
    "ANTHROPIC_VERTEX_PROJECT_ID": "",
    "CLOUD_ML_REGION": "",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "",
    "ANTHROPIC_BASE_URL": "https://api.deepseek.com/anthropic",
    "ANTHROPIC_AUTH_TOKEN": "$api_key",
    "ANTHROPIC_API_KEY": "$api_key",
    "CLAUDE_CODE_MAX_CONTEXT_TOKENS": "$max_tokens",
    "CLAUDE_CODE_DISABLE_UNKNOWN_MODEL_WINDOW_ENFORCEMENT": "1"
  },
  "modelPicker": {
    "options": [
      {
        "model": "deepseek-v4-pro",
        "label": "DeepSeek V4 Pro",
        "description": "DeepSeek-V4-Pro-0813 · Context: $context_label · Reasoning & Coding"
      },
      {
        "model": "deepseek-flash",
        "label": "DeepSeek Flash",
        "description": "DeepSeek-V4.1-Flash · Context: $context_label · Fast & Efficient"
      }
    ],
    "replaceBuiltInOptions": true
  }
}
EOF
    chmod 600 "$settings_file"

    # 7. Construct policy-tier managed settings JSON string to suppress built-in Anthropic models
    local managed_settings="{\"availableModels\":[\"deepseek-v4-pro\",\"deepseek-flash\"],\"modelPicker\":{\"options\":[{\"model\":\"deepseek-v4-pro\",\"label\":\"DeepSeek V4 Pro\",\"description\":\"DeepSeek-V4-Pro-0813 · Context: ${context_label} · Reasoning & Coding\"},{\"model\":\"deepseek-flash\",\"label\":\"DeepSeek Flash\",\"description\":\"DeepSeek-V4.1-Flash · Context: ${context_label} · Fast & Efficient\"}],\"replaceBuiltInOptions\":true}}"

    # 8. Print informative startup banner
    echo "========================================================================"
    echo "⚡ Claude Code + DeepSeek API"
    echo "• Model:          $selected_model"
    echo "• Context Limit:  $max_tokens tokens [$context_label]"
    echo "• Endpoint:       https://api.deepseek.com/anthropic"
    echo "========================================================================"

    # 9. Execute Claude Code with Task Router persona if available
    local prompt_file="$HOME/.claude/skills/task-router/SKILL.md"
    local system_prompt_args=()
    if [ -f "$prompt_file" ]; then
        system_prompt_args=(--system-prompt-file "$prompt_file")
    fi

    claude --bare \
           --settings "$settings_file" \
           --managed-settings "$managed_settings" \
           --model "$selected_model" \
           "${system_prompt_args[@]}" \
           --dangerously-skip-permissions \
           "${pass_args[@]}"
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

# 7. Configure Shell RC files with isolated, clean source lines
echo ""
echo "Configuring shell profiles..."

CLEAN_BLOCK='# >>> claude-code-deepseek >>>
# Claude Code with DeepSeek API
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
content = re.sub(r'\n*# (?:Run )?Claude Code with DeepSeek API.*?\nfunction claude-ds\(\) \{.*?\n\}\n*', '\n', content, flags=re.DOTALL)
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

# 8. Automatically source / reload configuration
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
echo "Quick Commands:"
echo "  claude-ds                          # Default profile (Pro, 128K context)"
echo "  claude-ds 128k | 256k | 500k | 1m  # Choose context size"
echo "  claude-ds pro | flash              # Choose model"
echo "  claude-ds flash 128k               # Fast + Cost-saver"
echo "  claude-ds profile                  # Interactive profile menu"
echo "  claude-ds config                   # Manage persistent defaults"
echo "=================================================="
