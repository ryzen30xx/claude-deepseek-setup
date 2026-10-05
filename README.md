# Claude Code + DeepSeek API Auto-Installer

This repository contains an auto-install and management suite to configure [Claude Code](https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview) to securely use the **DeepSeek API** with custom context profiles, subagents, and skills.

Hệ thống này cung cấp kiến trúc hoàn chỉnh để định tuyến toàn bộ yêu cầu qua DeepSeek với khả năng quản lý context profile, loại bỏ bloatware, bảo vệ token ngân sách và cô lập shell tuyệt đối.

---

## 🚀 Quick Start

### 1. Installation

Run this command in your terminal:

```bash
curl -sL https://raw.githubusercontent.com/ryzen30xx/claude-deepseek-setup/main/install.sh | bash
```

*(Or clone the repository and run `./install.sh`)*

During installation, the script will:
1. Ensure Claude Code is installed.
2. Prompt for your **DeepSeek API Key** (or detect and auto-standardize your existing key in `~/.config/mg-deepseek/key.env`).
3. Initialize your default profile (`deepseek-v4-pro` with `128K` cost-saving context).
4. Pull custom skills (Task Router, etc.) into `~/.claude/skills/`.
5. Deploy the modular runner script to `~/.config/mg-deepseek/claude-ds.sh`.
6. Add an isolated source block in `~/.zshrc` (or `~/.bashrc`).
7. **Automatically reload your shell (`~/.zshrc`)** so you can immediately run `claude-ds`.

---

## ⚡ Context Profiles & Models

DeepSeek V4 supports a physical window of up to **1,000,000 tokens (1M)**. However, keeping 1M context in memory across long sessions consumes tokens rapidly. This suite introduces **Context Profiles** so you can control your token budget:

| Profile | Tokens | Auto-Compact | Use Case |
|---|---|---|---|
| **`128k`** *(Default)* | 128,000 | ~121K tokens | **Cost-Saver / Daily Coding**: Tiết kiệm chi phí tối đa, tốc độ nhanh, phù hợp làm việc hàng ngày. |
| **`256k`** | 256,000 | ~243K tokens | **Balanced**: Cân bằng giữa dung lượng ngữ cảnh và chi phí. |
| **`500k`** | 500,000 | ~475K tokens | **Deep Work**: Cho tác vụ phức tạp, refactor nhiều module. |
| **`1m`** | 1,000,000 | ~950K tokens | **Maximum Context**: Đọc và xử lý toàn bộ codebase khổng lồ. |

### Models Supported
- **`pro`** (`deepseek-v4-pro`): DeepSeek-V4-Pro-0813 — Mô hình lập trình và reasoning chuyên sâu.
- **`flash`** (`deepseek-flash`): DeepSeek-V4.1-Flash — Siêu nhanh, phản hồi tức thì, chi phí cực thấp.

---

## 💻 Usage

### 1. Run with Defaults (Pro + 128K Context)
```bash
claude-ds
```

### 2. Choose Context Limit
```bash
claude-ds 128k      # Chạy với giới hạn 128K tokens
claude-ds 256k      # Chạy với giới hạn 256K tokens
claude-ds 500k      # Chạy với giới hạn 500K tokens
claude-ds 1m        # Chạy với tối đa 1M tokens
```

### 3. Choose Model & Context
```bash
# DeepSeek V4 Pro
claude-ds pro 128k
claude-ds pro 256k
claude-ds pro 500k
claude-ds pro 1m

# DeepSeek Flash (Siêu nhanh & tiết kiệm)
claude-ds flash 128k
claude-ds flash 256k
claude-ds flash 500k
claude-ds flash 1m
```

*(Thứ tự tham số linh hoạt: `claude-ds flash 128k` hoặc `claude-ds 128k flash` đều hoạt động!)*

### 4. Interactive Profile Menu
Muốn chọn trực quan bằng bàn phím?
```bash
claude-ds profile
# hoặc: claude-ds -p
```
Hiển thị menu tương tác 8 lựa chọn kết hợp giữa Pro / Flash và các mức context.

### 5. Quản lý cấu hình mặc định (Persistent Config)
Bạn có thể đặt mức context hoặc model ưa thích làm mặc định vĩnh viễn:

```bash
# Xem cấu hình mặc định hiện tại:
claude-ds config

# Đặt context mặc định (ví dụ: 128k hoặc 256k):
claude-ds config context 128k

# Đặt model mặc định (pro hoặc flash):
claude-ds config model pro
```

### 6. Chạy kèm Prompt một lần (One-shot Prompt)
```bash
claude-ds flash 128k "Viết hàm parse JSON trong Python"
claude-ds pro 256k "Refactor authentication service"
```

---

## 🧩 Architecture & Isolation

Không giống như các bộ cài đặt thông thường chèn hàng trăm dòng code vào `.zshrc`, repository này sử dụng kiến trúc hoàn toàn cô lập:

Trong `~/.zshrc`:
```zsh
# >>> claude-code-deepseek >>>
# Claude Code with DeepSeek API
[ -f "$HOME/.config/mg-deepseek/claude-ds.sh" ] && source "$HOME/.config/mg-deepseek/claude-ds.sh"
# <<< claude-code-deepseek <<<
```

- **Robust Key Parsing**: Tự động nhận diện cấu hình `key.env` linh hoạt (hỗ trợ dấu nháy đơn, kép, khoảng trắng quanh dấu `=`, tiền tố `export`).
- **Policy-tier Managed Settings**: Tự động kích hoạt policy để ẩn hoàn toàn các model Anthropic mặc định (Opus, Fable, Sonnet, Haiku) và chỉ hiển thị danh mục DeepSeek.
- **Dynamic Auto-Compact Enforcement**: Đặt biến môi trường `CLAUDE_CODE_MAX_CONTEXT_TOKENS` theo đúng profile bạn chọn, kích hoạt cơ chế auto-compact thông minh của Claude Code khi đạt ngưỡng.
- **Auto-Reload**: Tự động reload `~/.zshrc` ngay sau khi cài đặt hoặc gỡ cài đặt.

---

## 🗑️ Clean Uninstallation

Để gỡ cài đặt hoàn toàn:

### Qua One-Liner:
```bash
curl -sL https://raw.githubusercontent.com/ryzen30xx/claude-deepseek-setup/main/uninstall.sh | bash
```

### Hoặc Tại Local:
```bash
./uninstall.sh
```

**Tham số:**
- `./uninstall.sh -y`: Gỡ cài đặt không cần xác nhận.
- `./uninstall.sh --purge-skills`: Xóa cả các custom skills trong `~/.claude/skills/`.
- `./uninstall.sh --all`: Xóa toàn bộ bao gồm config, skills và binary Claude Code.

---

## 🔒 Security Note
Repository này **không** lưu bất kỳ API Key nào. Khóa API DeepSeek được lưu bảo mật tại máy của bạn trong `~/.config/mg-deepseek/key.env` với phân quyền `chmod 600`.