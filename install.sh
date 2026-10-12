#!/usr/bin/env bash

# ==============================================================================
# Claude Code + DeepSeek API Suite - Installer
#
# Kiến trúc quy trình:
#   1. Chạy lệnh (Khởi động bộ cài đặt)
#   2. Cài đặt các package cần thiết (curl, git, python3, Claude Code, ~/.local/bin PATH)
#   3. TUI yêu cầu người dùng nhập API Key (Giao diện TUI, hướng dẫn, chọn Profile)
#   4. API Key được viết vào configure và tạo configure (key.env, profile.env, settings)
#   5. Add to bashrc, zshrc tùy môi trường (Cô lập cấu hình, auto-reload)
# ==============================================================================

set -e

# Thiết lập màu sắc hiển thị TUI
BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
DIM='\033[2m'
NC='\033[0m'

if [ -n "$NO_COLOR" ] || [ ! -t 1 ]; then
    BOLD="" CYAN="" GREEN="" YELLOW="" RED="" BLUE="" DIM="" NC=""
fi

# Hàm đọc input an toàn từ /dev/tty (tương thích cả khi chạy qua pipe curl | bash)
prompt_tty() {
    local prompt_msg="$1"
    local var_name="$2"
    local input_val=""

    printf "%b" "$prompt_msg"
    if [ -r /dev/tty ]; then
        read -r input_val < /dev/tty || true
    elif [ -t 0 ]; then
        read -r input_val || true
    fi
    eval "$var_name=\"\$input_val\""
}

# Hàm ẩn bớt ký tự API Key khi hiển thị trên màn hình
mask_key() {
    local k="$1"
    local len=${#k}
    if [ "$len" -le 10 ]; then
        echo "********"
    else
        local prefix="${k:0:7}"
        local suffix="${k: -4}"
        echo "${prefix}****************${suffix}"
    fi
}

echo -e "${CYAN}========================================================================${NC}"
echo -e "${BOLD}${CYAN}   ⚡ Claude Code + DeepSeek API Suite - Installer${NC}"
echo -e "${CYAN}========================================================================${NC}"
echo -e "Kiến trúc: Claude Code CLI + DeepSeek V4 API (Pro & Flash) + Context Profiles"
echo ""

# ------------------------------------------------------------------------------
# 1. CÀI ĐẶT CÁC PACKAGE CẦN THIẾT
# ------------------------------------------------------------------------------
echo -e "${BLUE}📦 [1/4] Kiểm tra và cài đặt các package cần thiết...${NC}"

# Đảm bảo ~/.local/bin có trong PATH ngay trong phiên làm việc này
[ -d "$HOME/.local/bin" ] && case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac

# Kiểm tra curl
if command -v curl &>/dev/null; then
    echo -e "  ${GREEN}✔${NC} curl: $(curl --version 2>&1 | head -n 1 | awk '{print $1, $2}')"
else
    echo -e "  ${RED}❌ curl chưa được cài đặt. Vui lòng cài đặt curl trước khi tiếp tục.${NC}"
    exit 1
fi

# Kiểm tra python3
if command -v python3 &>/dev/null; then
    echo -e "  ${GREEN}✔${NC} python3: $(python3 --version 2>&1)"
else
    echo -e "  ${YELLOW}⚠️ python3 chưa cài đặt. Một số bước đồng bộ JSON có thể bị giới hạn.${NC}"
fi

# Kiểm tra git
if command -v git &>/dev/null; then
    echo -e "  ${GREEN}✔${NC} git: $(git --version 2>&1)"
else
    echo -e "  ${YELLOW}⚠️ git chưa cài đặt. Sẽ bỏ qua bước clone Skills mở rộng.${NC}"
fi

# Kiểm tra và tự động cài đặt Claude Code chính hãng
if command -v claude &>/dev/null || [ -f "$HOME/.local/bin/claude" ]; then
    echo -e "  ${GREEN}✔${NC} Claude Code: Đã có sẵn trên hệ thống"
else
    echo -e "  ${YELLOW}⚡ Chưa tìm thấy Claude Code. Đang tiến hành cài đặt tự động từ Anthropic...${NC}"
    curl -fsSL https://claude.ai/install.sh | bash
    [ -d "$HOME/.local/bin" ] && case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
    echo -e "  ${GREEN}✔${NC} Claude Code: Cài đặt thành công!"
fi

# ------------------------------------------------------------------------------
# 2. TUI YÊU CẦU NGƯỜI DÙNG NHẬP API KEY & CHỌN PROFILE
# ------------------------------------------------------------------------------
echo ""
echo -e "${BLUE}🔑 [2/4] Thiết lập DeepSeek API Key & Profile...${NC}"

CONFIG_DIR="$HOME/.config/claude-deepseek"
LEGACY_CONFIG_DIR="$HOME/.config/mg-deepseek"

# Tự động di chuyển dữ liệu cấu hình cũ nếu có
if [ -d "$LEGACY_CONFIG_DIR" ] && [ ! -d "$CONFIG_DIR" ]; then
    echo -e "  ${YELLOW}📦 Đang di dời cấu hình cũ từ $LEGACY_CONFIG_DIR sang $CONFIG_DIR...${NC}"
    mv "$LEGACY_CONFIG_DIR" "$CONFIG_DIR"
elif [ -d "$LEGACY_CONFIG_DIR" ] && [ -d "$CONFIG_DIR" ]; then
    cp -n "$LEGACY_CONFIG_DIR"/* "$CONFIG_DIR"/ 2>/dev/null || true
    rm -rf "$LEGACY_CONFIG_DIR"
fi

mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"

KEY_FILE="$CONFIG_DIR/key.env"
existing_key=""

# Kiểm tra biến môi trường hoặc key.env đã lưu trước đó
if [ -n "$DEEPSEEK_API_KEY" ] && [ "$DEEPSEEK_API_KEY" != "sk-your-key-here" ]; then
    existing_key="$DEEPSEEK_API_KEY"
elif [ -f "$KEY_FILE" ]; then
    existing_key=$(sed -E -n 's/^[[:space:]]*(export[[:space:]]+)?DEEPSEEK_API_KEY[[:space:]]*=[[:space:]]*["'"'"']?([^"'"'"'[:space:]#]+).*/\2/p' "$KEY_FILE" | tail -n 1)
fi

# Hiển thị khung TUI cấu hình API Key
echo -e "${CYAN}┌────────────────────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│${NC}                   ${BOLD}CẤU HÌNH DEEPSEEK API KEY${NC}                            ${CYAN}│${NC}"
echo -e "${CYAN}├────────────────────────────────────────────────────────────────────────┤${NC}"
echo -e "${CYAN}│${NC}  • Lấy API Key chính thức tại: ${BOLD}https://platform.deepseek.com/api_keys${NC}   ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}  • Khóa lưu bảo mật tại: ${DIM}~/.config/claude-deepseek/key.env${NC}             ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}  • Phân quyền an toàn: ${GREEN}chmod 600${NC} (Chỉ riêng tài khoản của bạn đọc được) ${CYAN}│${NC}"
echo -e "${CYAN}└────────────────────────────────────────────────────────────────────────┘${NC}"

api_key=""
if [ -n "$existing_key" ] && [ "$existing_key" != "sk-your-key-here" ]; then
    masked=$(mask_key "$existing_key")
    echo -e "  ${GREEN}✔${NC} Tìm thấy API Key hiện tại: ${BOLD}${masked}${NC}"
    if [ -r /dev/tty ] || [ -t 0 ]; then
        prompt_tty "  Nhấn ${BOLD}[Enter]${NC} để dùng lại key này, hoặc nhập key mới: " user_input
        user_input=$(echo "$user_input" | tr -d "'\" ")
        if [ -n "$user_input" ]; then
            api_key="$user_input"
        else
            api_key="$existing_key"
        fi
    else
        api_key="$existing_key"
    fi
else
    if [ -r /dev/tty ] || [ -t 0 ]; then
        prompt_tty "  ${YELLOW}Nhập DeepSeek API Key (sk-...): ${NC}" api_key
        api_key=$(echo "$api_key" | tr -d "'\" ")
    fi
fi

if [ -z "$api_key" ] || [ "$api_key" = "sk-your-key-here" ]; then
    echo ""
    echo -e "  ${RED}❌ Lỗi: DeepSeek API Key không được để trống!${NC}"
    echo -e "  💡 Gợi ý: Nếu chạy cài đặt tự động/headless, bạn có thể truyền key trước:"
    echo -e "     ${BOLD}DEEPSEEK_API_KEY=\"sk-your-key\" curl -fsSL https://... | bash${NC}"
    exit 1
fi

# TUI chọn Model & Context Profile ban đầu
chosen_model="deepseek-v4-pro"
chosen_context="128k"

if [ -r /dev/tty ] || [ -t 0 ]; then
    echo ""
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}               ${BOLD}CHỌN PROFILE MẶC ĐỊNH (MODEL & CONTEXT)${NC}                  ${CYAN}│${NC}"
    echo -e "${CYAN}├────────────────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC}  ${BOLD}DeepSeek V4 Pro${NC} (Lập trình chuyên sâu, suy luận logic):               ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}    ${BOLD}1)${NC} Pro  - 128K Context  ${GREEN}(Khuyên dùng: Siêu rẻ, tiết kiệm token)${NC}   ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}    ${BOLD}2)${NC} Pro  - 256K Context  (Cân bằng chi phí & ngữ cảnh)             ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}    ${BOLD}3)${NC} Pro  - 500K Context  (Dự án lớn, refactor module)              ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}    ${BOLD}4)${NC} Pro  - 1M   Context  (Maximum Context - 1 triệu tokens)        ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}                                                                        ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${BOLD}DeepSeek Flash${NC} (Tốc độ cao, phản hồi tức thì):                     ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}    ${BOLD}5)${NC} Flash - 128K Context (Siêu tốc độ & siêu rẻ)                   ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}    ${BOLD}6)${NC} Flash - 256K Context (Nhanh & cân bằng)                        ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}    ${BOLD}7)${NC} Flash - 500K Context (Dự án lớn, tốc độ cao)                   ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}    ${BOLD}8)${NC} Flash - 1M   Context (Maximum Context, tốc độ cao)             ${CYAN}│${NC}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────────────────┘${NC}"
    prompt_tty "  Chọn profile [1-8] (Mặc định: 1 - Pro 128K): " profile_input
    profile_input=$(echo "$profile_input" | tr -d ' ')
    case "$profile_input" in
        1|"") chosen_model="deepseek-v4-pro"; chosen_context="128k" ;;
        2)    chosen_model="deepseek-v4-pro"; chosen_context="256k" ;;
        3)    chosen_model="deepseek-v4-pro"; chosen_context="500k" ;;
        4)    chosen_model="deepseek-v4-pro"; chosen_context="1m" ;;
        5)    chosen_model="deepseek-flash";  chosen_context="128k" ;;
        6)    chosen_model="deepseek-flash";  chosen_context="256k" ;;
        7)    chosen_model="deepseek-flash";  chosen_context="500k" ;;
        8)    chosen_model="deepseek-flash";  chosen_context="1m" ;;
        *)    echo "  ℹ️  Lựa chọn không xác định, sử dụng mặc định: Pro (128K context)" ;;
    esac
fi

# ------------------------------------------------------------------------------
# 3. API KEY ĐƯỢC VIẾT VÀO CONFIGURE VÀ TẠO CONFIGURE
# ------------------------------------------------------------------------------
echo ""
echo -e "${BLUE}⚙️  [3/4] Ghi cấu hình và triển khai môi trường...${NC}"

# Ghi API Key vào key.env
echo "export DEEPSEEK_API_KEY=\"$api_key\"" > "$KEY_FILE"
chmod 600 "$KEY_FILE"
echo -e "  ${GREEN}✔${NC} Đã ghi API Key bảo mật vào: ${DIM}$KEY_FILE${NC} (chmod 600)"

# Ghi Profile mặc định vào profile.env
PROFILE_FILE="$CONFIG_DIR/profile.env"
cat > "$PROFILE_FILE" << EOF
export DEFAULT_MODEL="$chosen_model"
export DEFAULT_CONTEXT="$chosen_context"
EOF
chmod 600 "$PROFILE_FILE"
echo -e "  ${GREEN}✔${NC} Đã tạo Profile mặc định: ${BOLD}$chosen_model${NC} [${BOLD}$chosen_context${NC}]"

# Tải Skills mở rộng từ GitHub
echo -e "  ⚡ Đang đồng bộ Claude Code Skills..."
mkdir -p "$HOME/.claude/skills"
SKILLS_REPO_URL="https://github.com/ryzen30xx/Skills.git"
TEMP_SKILLS_DIR="/tmp/claude-skills-clone"
rm -rf "$TEMP_SKILLS_DIR"

if command -v gh &> /dev/null && gh auth status &> /dev/null; then
    gh repo clone "$SKILLS_REPO_URL" "$TEMP_SKILLS_DIR" 2>/dev/null || GIT_TERMINAL_PROMPT=0 git clone "$SKILLS_REPO_URL" "$TEMP_SKILLS_DIR" 2>/dev/null || true
else
    GIT_TERMINAL_PROMPT=0 git clone "$SKILLS_REPO_URL" "$TEMP_SKILLS_DIR" 2>/dev/null || true
fi

if [ -d "$TEMP_SKILLS_DIR" ] && [ -n "$(ls -A "$TEMP_SKILLS_DIR" 2>/dev/null)" ]; then
    find "$TEMP_SKILLS_DIR" -mindepth 1 -maxdepth 1 -exec basename {} \; > "$CONFIG_DIR/installed_skills.txt"
    cp -R "$TEMP_SKILLS_DIR/"* "$HOME/.claude/skills/"
    rm -rf "$TEMP_SKILLS_DIR"
    echo -e "  ${GREEN}✔${NC} Đã cài đặt skills vào ~/.claude/skills/"
else
    echo -e "  ℹ️  Kho Skills đã sẵn sàng hoặc bỏ qua."
fi

# Cấu hình Claude Code toàn cục (~/.claude/settings.json)
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

# Tự động approve workspace trust cho thư mục $HOME trong ~/.claude.json
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
echo -e "  ${GREEN}✔${NC} Đã cấu hình modelPicker và tự động cấp trust cho workspace $HOME"

# Triển khai runner script claude-ds.sh vào CONFIG_DIR
SCRIPT_TARGET="$CONFIG_DIR/claude-ds.sh"

cat > "$SCRIPT_TARGET" << 'RUNNER_EOF'
#!/usr/bin/env bash

# ==============================================================================
# Claude Code + DeepSeek API Integration
# Context Profiles: 128K, 256K, 500K, 1M
# Model Profiles: deepseek-v4-pro (Pro), deepseek-flash (Flash)
# ==============================================================================

claude-ds() {
    # Ensure ~/.local/bin is in PATH for standalone Claude Code binary
    [ -d "$HOME/.local/bin" ] && case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac

    # Auto-migrate legacy ~/.config/mg-deepseek if found
    if [ -d "$HOME/.config/mg-deepseek" ] && [ ! -d "$HOME/.config/claude-deepseek" ]; then
        mv "$HOME/.config/mg-deepseek" "$HOME/.config/claude-deepseek" 2>/dev/null || true
    fi

    local config_dir="$HOME/.config/claude-deepseek"
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
        echo "❌ Error: Please set your actual DEEPSEEK_API_KEY in ~/.config/claude-deepseek/key.env"
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
            local ctx_input=$(echo "$3" | tr '[:upper:]' '[:lower:]')
            case "$ctx_input" in
                128k|256k|500k|1m)
                    echo "export DEFAULT_MODEL=\"$default_model\"" > "$profile_file"
                    echo "export DEFAULT_CONTEXT=\"$ctx_input\"" >> "$profile_file"
                    chmod 600 "$profile_file"
                    echo "✅ Default context set to: $ctx_input"
                    return 0
                    ;;
                *)
                    echo "❌ Invalid context. Choose from: 128k, 256k, 500k, 1m"
                    return 1
                    ;;
            esac
        elif [ "$2" = "model" ] && [ -n "$3" ]; then
            local mdl_input=$(echo "$3" | tr '[:upper:]' '[:lower:]')
            case "$mdl_input" in
                pro|deepseek-v4-pro)
                    echo "export DEFAULT_MODEL=\"deepseek-v4-pro\"" > "$profile_file"
                    echo "export DEFAULT_CONTEXT=\"$default_context\"" >> "$profile_file"
                    chmod 600 "$profile_file"
                    echo "✅ Default model set to: deepseek-v4-pro"
                    return 0
                    ;;
                flash|deepseek-flash)
                    echo "export DEFAULT_MODEL=\"deepseek-flash\"" > "$profile_file"
                    echo "export DEFAULT_CONTEXT=\"$default_context\"" >> "$profile_file"
                    chmod 600 "$profile_file"
                    echo "✅ Default model set to: deepseek-flash"
                    return 0
                    ;;
                *)
                    echo "❌ Invalid model. Choose from: pro, flash"
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

    local selected_model="$default_model"
    local selected_context="$default_context"
    local pass_args=()

    # Interactive Profile Selector Menu
    if [ "$1" = "profile" ] || [ "$1" = "menu" ] || [ "$1" = "-p" ]; then
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
        if [ -r /dev/tty ]; then
            read -r profile_choice < /dev/tty || true
        else
            read -r profile_choice || true
        fi
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
                --pro|pro|deepseek-v4-pro)
                    selected_model="deepseek-v4-pro"
                    shift
                    ;;
                --flash|flash|deepseek-flash)
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
                *)
                    pass_args+=("$1")
                    shift
                    ;;
            esac
        done
    fi

    # 5. Map context profiles to CLAUDE_CODE_MAX_CONTEXT_TOKENS
    local max_tokens=128000
    local context_label="128K (Cost-Saver)"
    case "$selected_context" in
        128k)
            max_tokens=128000
            context_label="128K (Cost-Saver)"
            ;;
        256k)
            max_tokens=256000
            context_label="256K (Balanced)"
            ;;
        500k)
            max_tokens=500000
            context_label="500K (Deep Refactor)"
            ;;
        1m)
            max_tokens=1000000
            context_label="1M (Max Context)"
            ;;
        *)
            max_tokens=128000
            context_label="128K (Cost-Saver)"
            ;;
    esac

    # Set client-side context compression threshold
    export CLAUDE_CODE_MAX_CONTEXT_TOKENS="$max_tokens"
    export CLAUDE_CODE_DISABLE_UNKNOWN_MODEL_WINDOW_ENFORCEMENT="1"

    # 6. Generate session settings file
    cat > "$settings_file" << EOF
{
  "model": "$selected_model",
  "theme": "dark",
  "skipDangerousModePermissionPrompt": true,
  "modelSettings": {
    "deepseek-v4-pro": {
      "effortLevel": "low"
    },
    "deepseek-flash": {
      "effortLevel": "low"
    }
  },
  "env": {
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
echo -e "  ${GREEN}✔${NC} Đã cài đặt launcher script tại: $SCRIPT_TARGET"

# ------------------------------------------------------------------------------
# 4. ADD TO BASHRC, ZSHRC TÙY MÔI TRƯỜNG
# ------------------------------------------------------------------------------
echo ""
echo -e "${BLUE}🐚 [4/4] Tích hợp vào Shell profile theo môi trường...${NC}"

CLEAN_BLOCK='# >>> claude-code-deepseek >>>
# Claude Code with DeepSeek API
[ -d "$HOME/.local/bin" ] && case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
[ -f "$HOME/.config/claude-deepseek/claude-ds.sh" ] && source "$HOME/.config/claude-deepseek/claude-ds.sh"
# <<< claude-code-deepseek <<<'

configure_rc_file() {
    local rc_file="$1"
    [ ! -f "$rc_file" ] && return 0

    # Dọn sạch các hàm inline claude-ds cũ nếu có
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

    # Dọn dẹp block cũ hoặc các dòng mg-deepseek cũ
    python3 -c "
import re
path = '$rc_file'
content = open(path).read()
content = re.sub(r'\n*# >>> claude-code-deepseek >>>.*?# <<< claude-code-deepseek <<<\n*', '\n', content, flags=re.DOTALL)
content = re.sub(r'\n*\[ -f \"\$HOME/\.config/mg-deepseek/claude-ds\.sh\" \] && source \"\$HOME/\.config/mg-deepseek/claude-ds\.sh\"\n*', '\n', content)
open(path, 'w').write(content)
" 2>/dev/null || true

    # Thêm khối cấu hình cô lập mới
    echo "" >> "$rc_file"
    echo "$CLEAN_BLOCK" >> "$rc_file"
    echo -e "  ${GREEN}✔${NC} Đã tích hợp cấu hình cô lập vào ${BOLD}$rc_file${NC}"
}

user_shell=$(basename "${SHELL:-bash}")
target_rcs=()

[ -f "$HOME/.zshrc" ] && target_rcs+=("$HOME/.zshrc")
[ -f "$HOME/.bashrc" ] && target_rcs+=("$HOME/.bashrc")

# Nếu cả hai file rc đều chưa có, tự tạo theo shell của user
if [ ${#target_rcs[@]} -eq 0 ]; then
    if [ "$user_shell" = "zsh" ]; then
        touch "$HOME/.zshrc"
        target_rcs+=("$HOME/.zshrc")
    else
        touch "$HOME/.bashrc"
        target_rcs+=("$HOME/.bashrc")
    fi
fi

for rc in "${target_rcs[@]}"; do
    configure_rc_file "$rc"
done

# Tự động nạp lại cấu hình vào shell
if [ -f "$HOME/.zshrc" ] && [ "$user_shell" = "zsh" ]; then
    if [ -n "$ZSH_VERSION" ]; then
        source "$HOME/.zshrc" 2>/dev/null || true
    elif command -v zsh &>/dev/null; then
        zsh -c "source $HOME/.zshrc" 2>/dev/null || true
    fi
fi

if [ -f "$HOME/.bashrc" ] && [ "$user_shell" = "bash" ]; then
    if [ -n "$BASH_VERSION" ]; then
        source "$HOME/.bashrc" 2>/dev/null || true
    fi
fi

# Nạp trực tiếp runner vào phiên cài đặt hiện tại
if [ -f "$SCRIPT_TARGET" ]; then
    source "$SCRIPT_TARGET" 2>/dev/null || true
fi

# ------------------------------------------------------------------------------
# 5. TỔNG KẾT HOÀN TẤT
# ------------------------------------------------------------------------------
echo ""
echo -e "${GREEN}========================================================================${NC}"
echo -e "${BOLD}${GREEN}🎉 CÀI ĐẶT THÀNH CÔNG!${NC}"
echo -e "${GREEN}========================================================================${NC}"
echo -e "Toàn bộ cấu hình đã được thiết lập và kích hoạt sẵn sàng."
echo ""
echo -e "${BOLD}Các lệnh sử dụng nhanh:${NC}"
echo -e "  ${CYAN}claude-ds${NC}                          # Chạy với profile mặc định (${BOLD}$chosen_model${NC}, ${BOLD}$chosen_context${NC})"
echo -e "  ${CYAN}claude-ds profile${NC}                  # Menu TUI tương tác chọn model & context"
echo -e "  ${CYAN}claude-ds 128k${NC}                     # Chạy nhanh với 128K context (tiết kiệm chi phí)"
echo -e "  ${CYAN}claude-ds pro 256k${NC}                 # Chạy DeepSeek Pro với 256K context"
echo -e "  ${CYAN}claude-ds flash 128k${NC}               # Chạy DeepSeek Flash siêu tốc"
echo -e "  ${CYAN}claude-ds config${NC}                   # Xem và quản lý cấu hình mặc định"
echo -e "${GREEN}========================================================================${NC}"
