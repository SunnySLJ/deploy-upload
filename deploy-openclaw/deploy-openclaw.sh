#!/bin/bash
# ============================================================
# 🦐 OpenClaw 一键部署脚本 (macOS)
# 版本: 1.0.0
# 说明: 自动完成 OpenClaw 全套部署，包括环境检查、插件安装、
#       技能克隆、配置文件初始化、定时任务创建等。
# ============================================================

set -euo pipefail

# ── 颜色定义 ─────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ── 全局变量 ─────────────────────────────────────────────────
OPENCLAW_DIR="$HOME/.openclaw"
WORKSPACE_DIR="$OPENCLAW_DIR/workspace"
SKILLS_DIR="$OPENCLAW_DIR/skills"
DEPLOY_DIR="$(cd "$(dirname "$0")" && pwd)"
PYTHON_CMD=""
STEP_COUNT=0
TOTAL_STEPS=13
API_KEY=""
WECHAT_TARGET=""

# ── 工具函数 ─────────────────────────────────────────────────
print_banner() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}🦐 OpenClaw 一键部署脚本 (macOS)${NC}               ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  虾王智能视频发布系统 — 自动化部署              ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
}

step() {
    STEP_COUNT=$((STEP_COUNT + 1))
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}[步骤 $STEP_COUNT/$TOTAL_STEPS] $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

ok()   { echo -e "  ${GREEN}✅ $1${NC}"; }
warn() { echo -e "  ${YELLOW}⚠️  $1${NC}"; }
fail() { echo -e "  ${RED}❌ $1${NC}"; }
info() { echo -e "  ${CYAN}ℹ️  $1${NC}"; }

ask_yes_no() {
    local prompt="$1"
    local default="${2:-y}"
    local answer
    if [ "$default" = "y" ]; then
        read -rp "  $prompt [Y/n]: " answer
        answer="${answer:-y}"
    else
        read -rp "  $prompt [y/N]: " answer
        answer="${answer:-n}"
    fi
    [[ "$answer" =~ ^[Yy] ]]
}

check_command() {
    command -v "$1" &>/dev/null
}

# ── 步骤 1: 检查系统环境 ──────────────────────────────────────
step1_system_check() {
    step "检查系统环境"

    # 检查 macOS
    if [[ "$(uname)" != "Darwin" ]]; then
        fail "此脚本仅支持 macOS。Windows 请使用 deploy-openclaw.ps1"
        exit 1
    fi
    ok "操作系统: macOS $(sw_vers -productVersion)"

    # 检查 Node.js
    if check_command node; then
        local node_ver
        node_ver=$(node -v)
        ok "Node.js: $node_ver"
    else
        fail "未安装 Node.js！请先安装 Node.js (v18+)"
        info "推荐: brew install node"
        exit 1
    fi

    # 检查 npm
    if check_command npm; then
        ok "npm: $(npm -v)"
    else
        fail "未安装 npm！"
        exit 1
    fi

    # 检查 npx
    if check_command npx; then
        ok "npx: 可用"
    else
        fail "npx 不可用！"
        exit 1
    fi

    # 检查 git
    if check_command git; then
        ok "Git: $(git --version | awk '{print $3}')"
    else
        fail "未安装 Git！请先安装 Git"
        info "推荐: brew install git"
        exit 1
    fi

    # 检查 Homebrew
    if check_command brew; then
        ok "Homebrew: 已安装"
    else
        warn "Homebrew 未安装（非必须，但推荐）"
    fi
}

# ── 步骤 2: 检查/安装 Python 3.12 ─────────────────────────────
step2_python() {
    step "检查 / 安装 Python 3.12"

    # 按优先级查找 Python 3.12
    local candidates=(
        "/opt/homebrew/bin/python3.12"
        "/usr/local/bin/python3.12"
        "python3.12"
    )

    for cmd in "${candidates[@]}"; do
        if command -v "$cmd" &>/dev/null; then
            local ver
            ver=$("$cmd" --version 2>&1 | awk '{print $2}')
            if [[ "$ver" == 3.12* ]]; then
                PYTHON_CMD="$cmd"
                ok "Python 3.12: $PYTHON_CMD ($ver)"
                return
            fi
        fi
    done

    # 未找到 Python 3.12
    warn "未找到 Python 3.12"
    if check_command brew; then
        if ask_yes_no "是否使用 Homebrew 安装 Python 3.12？"; then
            info "正在安装 Python 3.12..."
            brew install python@3.12
            PYTHON_CMD="/opt/homebrew/bin/python3.12"
            ok "Python 3.12 安装完成: $PYTHON_CMD"
        else
            fail "Python 3.12 是必需的，请手动安装后重试"
            exit 1
        fi
    else
        fail "请先安装 Python 3.12"
        info "推荐: brew install python@3.12"
        exit 1
    fi
}

# ── 步骤 3: 安装 OpenClaw ──────────────────────────────────────
step3_install_openclaw() {
    step "安装 OpenClaw"

    if check_command openclaw; then
        local oc_ver
        oc_ver=$(openclaw --version 2>/dev/null || echo "unknown")
        ok "OpenClaw 已安装: $oc_ver"
        if ask_yes_no "是否重新安装/更新 OpenClaw？" "n"; then
            info "正在更新 OpenClaw..."
            npm install -g @anthropics/openclaw@latest
            ok "OpenClaw 更新完成"
        fi
    else
        info "正在安装 OpenClaw..."
        npm install -g @anthropics/openclaw@latest
        ok "OpenClaw 安装完成"
    fi

    # 确保目录结构存在
    mkdir -p "$OPENCLAW_DIR"
    mkdir -p "$WORKSPACE_DIR"
    mkdir -p "$SKILLS_DIR"
    mkdir -p "$WORKSPACE_DIR/inbound_images"
    mkdir -p "$WORKSPACE_DIR/inbound_videos"
    mkdir -p "$WORKSPACE_DIR/logs/auth_qr"
    mkdir -p "$WORKSPACE_DIR/memory"
    ok "目录结构已创建"
}

# ── 步骤 4: 安装微信插件 ──────────────────────────────────────
step4_wechat_plugin() {
    step "安装微信插件"

    info "正在安装 OpenClaw 微信插件..."
    npx -y @tencent-weixin/openclaw-weixin-cli@latest install

    ok "微信插件安装完成"
    echo ""
    warn "⚡ 请在 OpenClaw 启动后通过微信扫码完成授权绑定"
    warn "   绑定命令: openclaw channel connect openclaw-weixin"
}

# ── 步骤 5: 安装飞书插件（可选） ──────────────────────────────
step5_feishu_plugin() {
    step "安装飞书插件（可选）"

    if ask_yes_no "是否安装飞书插件？" "n"; then
        info "正在安装飞书插件..."
        info "请参考: OpenClaw 飞书官方插件使用指南（公开版）"

        local feishu_app_id feishu_app_secret
        read -rp "  请输入飞书 App ID (留空跳过): " feishu_app_id
        if [ -n "$feishu_app_id" ]; then
            read -rp "  请输入飞书 App Secret: " feishu_app_secret

            # 保存飞书凭证
            mkdir -p "$OPENCLAW_DIR/credentials"
            cat > "$OPENCLAW_DIR/credentials/feishu-main-allowFrom.json" << FEISHU_EOF
{
  "appId": "$feishu_app_id",
  "appSecret": "$feishu_app_secret"
}
FEISHU_EOF
            ok "飞书凭证已保存"
        else
            info "跳过飞书插件安装"
        fi
    else
        info "跳过飞书插件"
    fi
}

# ── 步骤 6: 配置 LLM 大模型 ───────────────────────────────────
step6_configure_llm() {
    step "配置 LLM 大模型"

    if [ -f "$OPENCLAW_DIR/openclaw.json" ]; then
        warn "检测到已有 openclaw.json 配置"
        if ! ask_yes_no "是否覆盖现有配置？" "n"; then
            info "保留现有配置"
            return
        fi
    fi

    echo ""
    info "请输入百炼 (DashScope) API Key:"
    read -rp "  API Key (sk-sp-xxx): " API_KEY

    if [ -z "$API_KEY" ]; then
        warn "未输入 API Key，使用模板中的占位符"
        API_KEY="{{YOUR_API_KEY}}"
    fi

    # 从模板生成 openclaw.json
    if [ -f "$DEPLOY_DIR/config/openclaw.json.template" ]; then
        sed "s|{{API_KEY}}|$API_KEY|g" \
            "$DEPLOY_DIR/config/openclaw.json.template" \
            > "$OPENCLAW_DIR/openclaw.json"
        ok "openclaw.json 已生成"
    else
        warn "模板文件不存在，请手动配置 openclaw.json"
    fi
}

# ── 步骤 7: 克隆 xiaolong-upload ──────────────────────────────
step7_clone_xiaolong_upload() {
    step "安装 xiaolong-upload（图片生成视频 Skill）"

    local target="$WORKSPACE_DIR/xiaolong-upload"

    if [ -d "$target" ]; then
        ok "xiaolong-upload 已存在"
        if ask_yes_no "是否拉取最新代码？"; then
            info "正在更新..."
            cd "$target"
            git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || warn "git pull 失败，请手动更新"
            cd - > /dev/null
            ok "已更新到最新代码"
        fi
    else
        info "正在克隆 xiaolong-upload..."
        git clone https://github.com/SunnySLJ/xiaolong-upload.git "$target"
        ok "克隆完成"
    fi

    # 安装 Python 依赖
    if [ -f "$target/requirements.txt" ]; then
        info "正在安装 Python 依赖..."
        cd "$target"
        "$PYTHON_CMD" -m venv .venv 2>/dev/null || true
        if [ -f ".venv/bin/pip" ]; then
            .venv/bin/pip install -r requirements.txt -q
        else
            "$PYTHON_CMD" -m pip install -r requirements.txt -q 2>/dev/null || warn "依赖安装失败，请手动安装"
        fi
        cd - > /dev/null
        ok "Python 依赖已安装"
    fi

    # 安装 Node.js 依赖 (如果有 package.json)
    if [ -f "$target/package.json" ]; then
        info "正在安装 Node.js 依赖..."
        cd "$target"
        npm install --silent 2>/dev/null || warn "npm install 失败"
        cd - > /dev/null
        ok "Node.js 依赖已安装"
    fi
}

# ── 步骤 8: 克隆 openclaw_upload ──────────────────────────────
step8_clone_openclaw_upload() {
    step "安装 openclaw_upload（视频号发布 Skill）"

    local target="$WORKSPACE_DIR/openclaw_upload"

    if [ -d "$target" ]; then
        ok "openclaw_upload 已存在"
        if ask_yes_no "是否拉取最新代码？"; then
            info "正在更新..."
            cd "$target"
            git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || warn "git pull 失败，请手动更新"
            cd - > /dev/null
            ok "已更新到最新代码"
        fi
    else
        info "正在克隆 openclaw_upload..."
        git clone https://github.com/SunnySLJ/openclaw_upload.git "$target"
        ok "克隆完成"
    fi

    # 安装 Python 依赖
    if [ -f "$target/requirements.txt" ]; then
        info "正在安装 Python 依赖..."
        cd "$target"
        "$PYTHON_CMD" -m venv .venv 2>/dev/null || true
        if [ -f ".venv/bin/pip" ]; then
            .venv/bin/pip install -r requirements.txt -q
        else
            "$PYTHON_CMD" -m pip install -r requirements.txt -q 2>/dev/null || warn "依赖安装失败，请手动安装"
        fi
        cd - > /dev/null
        ok "Python 依赖已安装"
    fi

    # 创建必要目录
    mkdir -p "$target/cookies"
    mkdir -p "$target/logs"
    mkdir -p "$target/published"
    mkdir -p "$target/flash_longxia/output"
    ok "目录结构已创建"
}

# ── 步骤 9: 复制 Workspace 配置文件 ───────────────────────────
step9_workspace_config() {
    step "初始化 Workspace 配置文件"

    local ws_src="$DEPLOY_DIR/workspace"
    local files=("AGENTS.md" "IDENTITY.md" "SOUL.md" "USER.md" "MEMORY.md" "HEARTBEAT.md" "TOOLS.md")

    for f in "${files[@]}"; do
        if [ -f "$ws_src/$f" ]; then
            if [ -f "$WORKSPACE_DIR/$f" ]; then
                warn "$f 已存在，跳过（避免覆盖）"
            else
                # 复制并替换路径占位符
                sed "s|{{HOME}}|$HOME|g; s|{{PYTHON_CMD}}|$PYTHON_CMD|g" \
                    "$ws_src/$f" > "$WORKSPACE_DIR/$f"
                ok "$f 已复制"
            fi
        else
            warn "$f 模板不存在，跳过"
        fi
    done
}

# ── 步骤 10: 安装 Skills ──────────────────────────────────────
step10_install_skills() {
    step "安装 Skills（技能）"

    local skill_src="$DEPLOY_DIR/skills"

    # 安装每个 skill
    local skill_names=("flash-longxia" "auth" "longxia-upload" "longxia-bootstrap")
    for skill in "${skill_names[@]}"; do
        if [ -d "$skill_src/$skill" ]; then
            if [ -d "$SKILLS_DIR/$skill" ]; then
                warn "Skill [$skill] 已存在，跳过"
            else
                cp -r "$skill_src/$skill" "$SKILLS_DIR/$skill"
                ok "Skill [$skill] 已安装"
            fi
        else
            warn "Skill [$skill] 模板不存在，跳过"
        fi
    done

    # 更新 longxia-bootstrap 的 project_config.json
    local bootstrap_config="$SKILLS_DIR/longxia-bootstrap/project_config.json"
    if [ -f "$bootstrap_config" ]; then
        cat > "$bootstrap_config" << BOOTSTRAP_EOF
{
  "project_root": "$WORKSPACE_DIR/xiaolong-upload",
  "python_cmd": "$PYTHON_CMD"
}
BOOTSTRAP_EOF
        ok "longxia-bootstrap 配置已更新"
    fi
}

# ── 步骤 11: 配置 Memory 插件 ─────────────────────────────────
step11_configure_memory() {
    step "配置 Memory 插件"

    # 创建 memory 目录
    mkdir -p "$OPENCLAW_DIR/memory"
    mkdir -p "$WORKSPACE_DIR/memory"
    mkdir -p "$WORKSPACE_DIR/plugins"

    # 创建 memory-md 目录 (用于 mdMirror)
    mkdir -p "$OPENCLAW_DIR/memory-md"

    info "Memory 插件 (memory-lancedb-pro) 已在 openclaw.json 中配置"
    info "首次启动 OpenClaw 时将自动初始化向量数据库"
    ok "Memory 目录结构已创建"
}

# ── 步骤 12: 创建定时任务 ─────────────────────────────────────
step12_create_cron() {
    step "创建定时任务"

    mkdir -p "$OPENCLAW_DIR/cron"

    # 交互式配置
    echo ""
    info "定时任务 1: 每日登录状态检查"
    local login_check_time
    read -rp "  每天几点检查登录状态？(默认 10:10，格式 HH:MM): " login_check_time
    login_check_time="${login_check_time:-10:10}"

    echo ""
    info "定时任务 2: 每周视频文件清理"
    echo "  0=周日 1=周一 2=周二 3=周三 4=周四 5=周五 6=周六"
    local cleanup_day
    read -rp "  每周几清理视频文件？(默认 2=周二): " cleanup_day
    cleanup_day="${cleanup_day:-2}"

    local cleanup_hour
    read -rp "  几点执行清理？(默认 01:00，格式 HH:MM): " cleanup_hour
    cleanup_hour="${cleanup_hour:-01:00}"

    # 解析时间
    local login_h login_m
    login_h=$(echo "$login_check_time" | cut -d: -f1)
    login_m=$(echo "$login_check_time" | cut -d: -f2)

    local cleanup_h cleanup_m
    cleanup_h=$(echo "$cleanup_hour" | cut -d: -f1)
    cleanup_m=$(echo "$cleanup_hour" | cut -d: -f2)

    # 生成 cron jobs
    local now_ms
    now_ms=$(date +%s)000

    cat > "$OPENCLAW_DIR/cron/jobs.json" << CRON_EOF
{
  "version": 1,
  "jobs": [
    {
      "id": "$(uuidgen | tr '[:upper:]' '[:lower:]')",
      "agentId": "main",
      "sessionKey": "agent:main:main",
      "name": "login-status-daily-check",
      "enabled": true,
      "createdAtMs": $now_ms,
      "updatedAtMs": $now_ms,
      "schedule": {
        "kind": "cron",
        "expr": "$login_m $login_h * * *",
        "tz": "Asia/Shanghai"
      },
      "sessionTarget": "main",
      "wakeMode": "now",
      "payload": {
        "kind": "systemEvent",
        "text": "执行每日平台登录状态检查：cd ~/.openclaw/workspace/xiaolong-upload && $PYTHON_CMD skills/auth/scripts/scheduled_login_check.py"
      },
      "state": {
        "consecutiveErrors": 0
      }
    },
    {
      "id": "$(uuidgen | tr '[:upper:]' '[:lower:]')",
      "agentId": "main",
      "sessionKey": "agent:main:main",
      "name": "video-cleanup-weekly",
      "enabled": true,
      "createdAtMs": $now_ms,
      "updatedAtMs": $now_ms,
      "schedule": {
        "expr": "$cleanup_m $cleanup_h * * $cleanup_day",
        "kind": "cron",
        "tz": "Asia/Shanghai"
      },
      "sessionTarget": "main",
      "wakeMode": "now",
      "payload": {
        "kind": "systemEvent",
        "text": "执行视频清理技能：cd ~/.openclaw/workspace/xiaolong-upload && $PYTHON_CMD scripts/cleanup_uploaded_videos.py"
      },
      "state": {
        "consecutiveErrors": 0
      }
    }
  ]
}
CRON_EOF

    ok "登录检查: 每天 $login_check_time"
    ok "视频清理: 每周 $cleanup_day 的 $cleanup_hour"

    # 复制登录检查配置
    if [ -f "$DEPLOY_DIR/config/login_check_config.json" ]; then
        local auth_skill_dir="$SKILLS_DIR/auth"
        mkdir -p "$auth_skill_dir"
        # 更新检查时间
        sed "s|{{LOGIN_CHECK_TIME}}|$login_check_time|g" \
            "$DEPLOY_DIR/config/login_check_config.json" \
            > "$auth_skill_dir/login_check_config.json"
        ok "登录检查配置已保存"
    fi
}

# ── 步骤 13: 配置 Token 和微信推送 ────────────────────────────
step13_configure_token() {
    step "配置 Token 和微信推送"

    # 视频生成 API Token
    echo ""
    info "视频生成 API Token（用于帧龙虾图生视频）"
    local video_token
    read -rp "  请输入视频生成 API Token (留空跳过): " video_token
    if [ -n "$video_token" ]; then
        local token_dir="$WORKSPACE_DIR/openclaw_upload/flash_longxia"
        mkdir -p "$token_dir"
        echo "$video_token" > "$token_dir/token.txt"
        ok "视频 Token 已保存到 flash_longxia/token.txt"
    else
        warn "跳过 Token 配置，请后续手动配置"
    fi

    # 微信推送目标
    echo ""
    info "微信推送目标（用于接收通知）"
    read -rp "  请输入微信 Target ID (格式: xxx@im.wechat，留空跳过): " WECHAT_TARGET
    if [ -n "$WECHAT_TARGET" ]; then
        ok "微信 Target: $WECHAT_TARGET"
        # 更新到 TOOLS.md
        if [ -f "$WORKSPACE_DIR/TOOLS.md" ]; then
            sed -i '' "s|{{WECHAT_TARGET}}|$WECHAT_TARGET|g" "$WORKSPACE_DIR/TOOLS.md" 2>/dev/null || true
        fi
    else
        warn "跳过微信推送配置"
        info "启动 OpenClaw 后执行: openclaw channel connect openclaw-weixin"
    fi
}

# ── 部署完成验证 ──────────────────────────────────────────────
verify_deployment() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}[验证] 部署结果检查${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    local all_ok=true

    # 检查核心文件
    local check_files=(
        "$OPENCLAW_DIR/openclaw.json:核心配置"
        "$WORKSPACE_DIR/MEMORY.md:红线规则"
        "$WORKSPACE_DIR/SOUL.md:AI 灵魂"
        "$WORKSPACE_DIR/USER.md:用户偏好"
        "$WORKSPACE_DIR/TOOLS.md:工具配置"
        "$OPENCLAW_DIR/cron/jobs.json:定时任务"
    )

    for item in "${check_files[@]}"; do
        local file="${item%%:*}"
        local desc="${item##*:}"
        if [ -f "$file" ]; then
            ok "$desc: ✓"
        else
            fail "$desc: 缺失 ($file)"
            all_ok=false
        fi
    done

    # 检查项目目录
    local check_dirs=(
        "$WORKSPACE_DIR/xiaolong-upload:xiaolong-upload 项目"
        "$WORKSPACE_DIR/openclaw_upload:openclaw_upload 项目"
    )

    for item in "${check_dirs[@]}"; do
        local dir="${item%%:*}"
        local desc="${item##*:}"
        if [ -d "$dir" ]; then
            ok "$desc: ✓"
        else
            fail "$desc: 缺失"
            all_ok=false
        fi
    done

    # 检查 Skills
    local check_skills=("flash-longxia" "auth" "longxia-upload" "longxia-bootstrap")
    for skill in "${check_skills[@]}"; do
        if [ -d "$SKILLS_DIR/$skill" ]; then
            ok "Skill [$skill]: ✓"
        else
            warn "Skill [$skill]: 未安装"
        fi
    done

    echo ""
    if $all_ok; then
        echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║${NC}  ${BOLD}🎉 部署完成！所有检查通过${NC}                       ${GREEN}║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    else
        echo -e "${YELLOW}╔══════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║${NC}  ${BOLD}⚠️  部署完成，但有部分项目需要手动处理${NC}           ${YELLOW}║${NC}"
        echo -e "${YELLOW}╚══════════════════════════════════════════════════╝${NC}"
    fi

    echo ""
    echo -e "${BOLD}📋 后续操作：${NC}"
    echo "  1. 启动 OpenClaw:  openclaw"
    echo "  2. 绑定微信:       openclaw channel connect openclaw-weixin"
    echo "  3. 扫码微信授权"
    echo "  4. 告诉虾王: \"帮我安装 xiaolong-upload 和 openclaw_upload\""
    echo "  5. 根据需要定制 USER.md 中的用户偏好"
    echo ""
    echo -e "${CYAN}  Python: $PYTHON_CMD${NC}"
    echo -e "${CYAN}  工作区: $WORKSPACE_DIR${NC}"
    echo ""
}

# ── 更新本地 skill 代码功能 ───────────────────────────────────
setup_skill_updater() {
    # 创建一个简单的 skill 更新脚本
    cat > "$WORKSPACE_DIR/update-skills.sh" << 'UPDATE_EOF'
#!/bin/bash
# 🦐 Skill 代码同步脚本
# 拉取 xiaolong-upload 和 openclaw_upload 的最新代码

set -e

echo "🔄 正在更新 skill 代码..."

WORKSPACE="$HOME/.openclaw/workspace"

# 更新 xiaolong-upload
if [ -d "$WORKSPACE/xiaolong-upload/.git" ]; then
    echo "  📦 xiaolong-upload..."
    cd "$WORKSPACE/xiaolong-upload"
    git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || echo "  ⚠️ 更新失败"
    cd - > /dev/null
fi

# 更新 openclaw_upload
if [ -d "$WORKSPACE/openclaw_upload/.git" ]; then
    echo "  📦 openclaw_upload..."
    cd "$WORKSPACE/openclaw_upload"
    git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || echo "  ⚠️ 更新失败"
    cd - > /dev/null
fi

echo "✅ Skill 代码更新完成！"
UPDATE_EOF
    chmod +x "$WORKSPACE_DIR/update-skills.sh"
}

# ── 主函数 ────────────────────────────────────────────────────
main() {
    print_banner

    echo -e "${BOLD}部署模式：${NC}"
    echo "  1) 全新部署 — 从零安装所有组件"
    echo "  2) 迁移部署 — 仅复制配置文件和技能（OpenClaw 已安装）"
    echo ""
    local mode
    read -rp "请选择 (1/2, 默认 1): " mode
    mode="${mode:-1}"

    case "$mode" in
        1)
            step1_system_check
            step2_python
            step3_install_openclaw
            step4_wechat_plugin
            step5_feishu_plugin
            step6_configure_llm
            step7_clone_xiaolong_upload
            step8_clone_openclaw_upload
            step9_workspace_config
            step10_install_skills
            step11_configure_memory
            step12_create_cron
            step13_configure_token
            setup_skill_updater
            verify_deployment
            ;;
        2)
            step1_system_check
            step2_python
            STEP_COUNT=2
            # 跳过安装，直接配置
            step6_configure_llm
            step7_clone_xiaolong_upload
            step8_clone_openclaw_upload
            step9_workspace_config
            step10_install_skills
            step11_configure_memory
            step12_create_cron
            step13_configure_token
            setup_skill_updater
            verify_deployment
            ;;
        *)
            fail "无效选择"
            exit 1
            ;;
    esac
}

main "$@"
