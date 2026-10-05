# Claude Code + DeepSeek API Auto-Installer

This repository contains an auto-install and management suite to configure [Claude Code](https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview) to securely use the **DeepSeek API** with custom subagents and skills.

This setup uses the [MG-Cafe](https://github.com/MG-Cafe/claudecode-deepseek-stack) approach to route requests through DeepSeek while keeping your shell configuration clean, modular, and isolated.

---

## 🚀 Quick Start

### 1. Installation

Run this command in your terminal:

```bash
curl -sL https://raw.githubusercontent.com/ryzen30xx/claude-deepseek-setup/main/install.sh | bash
```

*(Or clone the repository and run `./install.sh` / `source ./install.sh`)*

During installation, the script will:
1. Ensure Claude Code is installed.
2. Prompt for your **DeepSeek API Key** (or detect and auto-standardize your existing key in `~/.config/mg-deepseek/key.env`).
3. Pull custom skills (Task Router, etc.) into `~/.claude/skills/`.
4. Deploy the modular runner script to `~/.config/mg-deepseek/claude-ds.sh`.
5. Add an isolated, clean source block in your `~/.zshrc` (or `~/.bashrc`).
6. **Automatically reload your shell (`~/.zshrc`)** so you can immediately start using `claude-ds` without manual steps!

---

## 💻 Usage

### 1. Default Mode (Task Router Orchestrator + DeepSeek V4 Pro)
Claude Code will act as the Task Router, analyze your prompt, and orchestrate tasks using DeepSeek V4 Pro:

```bash
claude-ds "Please write the login screen using Flutter"
```

### 2. Fast Mode (DeepSeek V4 Flash)
Use the faster and lower-cost model (ideal for quick questions, documentation, or basic scripts):

```bash
claude-ds flash "Write the API documentation for the shopping cart"
# or
claude-ds --flash "Write the API documentation for the shopping cart"
```

### 3. Interactive Session
Launch an interactive Claude session directly:

```bash
claude-ds
```

---

## 🧩 Architecture & Isolation

Unlike naive installers that append huge function definitions into your `.zshrc`, this setup keeps your shell rc file completely minimal and isolated:

In `~/.zshrc`:
```zsh
# >>> claude-code-deepseek >>>
# Claude Code with DeepSeek API (MG-Cafe stack)
[ -f "$HOME/.config/mg-deepseek/claude-ds.sh" ] && source "$HOME/.config/mg-deepseek/claude-ds.sh"
# <<< claude-code-deepseek <<<
```

- **Robust Key Parsing**: Handles formatting variations in `~/.config/mg-deepseek/key.env` (supports `export`, spaces around `=`, single or double quotes) without breaking shell syntax.
- **Isolated Settings**: Generates temporary, isolated DeepSeek settings in `~/.config/mg-deepseek/claude-deepseek-settings.json` with strict 600 permissions.
- **Auto-Reload**: Automatically sources `~/.zshrc` so you can type `claude-ds` right after install.

---

## 🗑️ Clean Uninstallation

To completely remove the DeepSeek setup and revert all shell changes:

### Via One-Liner:
```bash
curl -sL https://raw.githubusercontent.com/ryzen30xx/claude-deepseek-setup/main/uninstall.sh | bash
```

### Or Locally:
```bash
./uninstall.sh
```

**Options:**
- `./uninstall.sh -y`: Run non-interactively without confirmation.
- `./uninstall.sh --purge-skills`: Also remove installed custom skills from `~/.claude/skills/`.
- `./uninstall.sh --all`: Purge everything including custom skills and Claude Code CLI binary.

---

## 🔒 Security Note
This repository does **not** contain any API keys. Your DeepSeek API key is stored strictly on your local machine in `~/.config/mg-deepseek/key.env` with restricted read/write permissions (`chmod 600`).