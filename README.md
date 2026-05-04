# Claude Code + DeepSeek API Auto-Installer

This repository contains a backup of custom subagents (Task Router, Coding Agent, Tester Agent, etc.) and an auto-install script to configure [Claude Code](https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview) to securely use the **DeepSeek API**.

This setup uses the [MG-Cafe](https://github.com/MG-Cafe/claudecode-deepseek-stack) approach to bypass Anthropic's hardcoded providers and adds a custom alias (`claude-ds`) to your shell.

## 🚀 One-Liner Installation

To automatically install Claude Code, set up the DeepSeek configuration, and copy the custom skills on a new Mac, simply paste this command into your terminal:

```bash
git clone https://github.com/ryzen30xx/claude-deepseek-setup.git ~/.claude-deepseek-setup && ~/.claude-deepseek-setup/install.sh
```

During installation, the script will prompt you to enter your **DeepSeek API Key** and securely save it.

## 💻 Usage

After installation, reload your terminal (`source ~/.zshrc`).

### 1. Default Mode (Task Router Orchestrator + DeepSeek V4 Pro)
Just type the command. Claude Code will act as the Task Router, analyze your prompt, and automatically spawn the correct subagent in a background terminal.

```bash
claude-ds "Please write the login screen using Flutter"
```

### 2. Fast Mode (DeepSeek V4 Flash)
To explicitly use the cheaper and faster model (great for documentation or basic tasks), add the word `flash`:

```bash
claude-ds flash "Write the API documentation for the shopping cart"
```

## 🔒 Security Note
This repository does **not** contain any API keys. Your DeepSeek API key is saved locally in `~/.config/mg-deepseek/key.env` during the installation process.