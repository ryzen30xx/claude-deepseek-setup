#!/usr/bin/env bash

# ==============================================================================
# Claude Code + DeepSeek API Uninstaller
# ==============================================================================

set -e

FORCE=false
PURGE_SKILLS=false
PURGE_CLAUDE=false

# Parse flags
for arg in "$@"; do
    case "$arg" in
        -y|--yes)
            FORCE=true
            ;;
        --purge-skills)
            PURGE_SKILLS=true
            ;;
        --purge-claude|--all)
            PURGE_CLAUDE=true
            ;;
        -h|--help)
            echo "Usage: ./uninstall.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -y, --yes          Run non-interactively and confirm removal"
            echo "  --purge-skills     Remove all custom skills installed by this setup"
            echo "  --purge-claude     Also uninstall Claude Code CLI binary"
            echo "  --all              Remove everything including skills and Claude Code"
            echo "  -h, --help         Show this help message"
            exit 0
            ;;
    esac
done

echo "=================================================="
echo "   Claude Code DeepSeek API & Skills Uninstaller"
echo "=================================================="
echo ""

if [ "$FORCE" = false ]; then
    read -p "Are you sure you want to uninstall Claude Code DeepSeek setup? [y/N]: " confirm
    case "$confirm" in
        [yY][eE][sS]|[yY])
            ;;
        *)
            echo "Uninstallation cancelled."
            exit 0
            ;;
    esac
fi

CONFIG_DIR="$HOME/.config/mg-deepseek"

# 1. Clean Shell RC Files (~/.zshrc and ~/.bashrc)
echo ""
echo "Cleaning shell configuration files..."

clean_rc_file() {
    local rc_file="$1"
    [ ! -f "$rc_file" ] && return 0

    python3 -c "
import re
path = '$rc_file'
content = open(path).read()

# Remove isolated block
content = re.sub(r'\n*# >>> claude-code-deepseek >>>.*?# <<< claude-code-deepseek <<<\n*', '\n', content, flags=re.DOTALL)

# Remove legacy inline function if exists
content = re.sub(r'\n*# Run Claude Code with DeepSeek API \(MG-Cafe stack\)\nfunction claude-ds\(\) \{.*?\n\}\n*', '\n', content, flags=re.DOTALL)
content = re.sub(r'\n*function claude-ds\(\) \{.*?\n\}\n*', '\n', content, flags=re.DOTALL)

open(path, 'w').write(content)
" 2>/dev/null || true

    # Fallback with sed if needed
    if grep -q "# >>> claude-code-deepseek >>>" "$rc_file" 2>/dev/null; then
        sed -i.bak '/# >>> claude-code-deepseek >>>/,/# <<< claude-code-deepseek <<</d' "$rc_file" 2>/dev/null || true
        rm -f "${rc_file}.bak"
    fi

    echo "✅ Cleaned deepseek entries from $rc_file"
}

clean_rc_file "$HOME/.zshrc"
clean_rc_file "$HOME/.bashrc"

# 2. Clean Custom Skills
echo ""
echo "Cleaning custom skills..."
SKILLS_DIR="$HOME/.claude/skills"
MANIFEST_FILE="$CONFIG_DIR/installed_skills.txt"

if [ -f "$MANIFEST_FILE" ]; then
    while IFS= read -r skill_name || [ -n "$skill_name" ]; do
        [ -z "$skill_name" ] && continue
        if [ -d "$SKILLS_DIR/$skill_name" ]; then
            rm -rf "$SKILLS_DIR/$skill_name"
            echo "   - Removed skill: $skill_name"
        elif [ -f "$SKILLS_DIR/$skill_name" ]; then
            rm -f "$SKILLS_DIR/$skill_name"
            echo "   - Removed skill file: $skill_name"
        fi
    done < "$MANIFEST_FILE"
    echo "✅ Removed recorded skills from ~/.claude/skills/"
elif [ "$PURGE_SKILLS" = true ]; then
    # If explicit flag passed without manifest
    echo "Purging installed skills..."
    for default_skill in task-router coding-agent tester-agent planner-agent product-manager-agent doc-author-agent dart-best-practices flutter-expert flutter-animations flutter-testing bash-defensive-patterns; do
        if [ -e "$SKILLS_DIR/$default_skill" ]; then
            rm -rf "$SKILLS_DIR/$default_skill"
            echo "   - Removed: $default_skill"
        fi
    done
    echo "✅ Purged default skills."
else
    echo "ℹ️  No recorded skills manifest found. Existing skills in ~/.claude/skills/ preserved."
    echo "   (Use --purge-skills if you wish to remove default skills)"
fi

# 3. Remove DeepSeek Configuration Directory
echo ""
echo "Removing DeepSeek configuration directory..."
if [ -d "$CONFIG_DIR" ]; then
    rm -rf "$CONFIG_DIR"
    echo "✅ Removed $CONFIG_DIR"
else
    echo "ℹ️  $CONFIG_DIR does not exist."
fi

# 4. Optional: Uninstall Claude Code CLI
if [ "$PURGE_CLAUDE" = true ]; then
    echo ""
    echo "Removing Claude Code binary..."
    if [ -f "$HOME/.local/bin/claude" ] || [ -L "$HOME/.local/bin/claude" ]; then
        rm -f "$HOME/.local/bin/claude"
        rm -rf "$HOME/.local/share/claude" 2>/dev/null || true
        echo "✅ Removed Claude Code binary from ~/.local/bin/claude"
    fi
    if command -v npm &>/dev/null; then
        npm uninstall -g @anthropic-ai/claude-code 2>/dev/null || true
    fi
else
    echo ""
    echo "ℹ️  Claude Code binary was preserved (~/.local/bin/claude)."
    echo "   If you also want to remove Claude Code CLI completely, run:"
    echo "   rm -f ~/.local/bin/claude && rm -rf ~/.local/share/claude"
fi

# 5. Automatically reload shell configuration
echo ""
echo "Reloading shell configuration..."
if [ -f "$HOME/.zshrc" ]; then
    if [ -n "$ZSH_VERSION" ]; then
        source "$HOME/.zshrc" 2>/dev/null || true
    elif command -v zsh &> /dev/null; then
        zsh -c "source $HOME/.zshrc" 2>/dev/null || true
    fi
    echo "✅ Automatically reloaded ~/.zshrc"
fi

if [ -n "$BASH_VERSION" ] && [ -f "$HOME/.bashrc" ]; then
    source "$HOME/.bashrc" 2>/dev/null || true
    echo "✅ Automatically reloaded ~/.bashrc"
fi

echo ""
echo "=================================================="
echo "🎉 Uninstallation Complete!"
echo "DeepSeek integration has been cleanly removed."
echo "=================================================="
