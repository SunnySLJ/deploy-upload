#!/bin/bash
# ============================================================
# 🦐 OpenClaw 一键部署脚本 (macOS)
# 版本: 2.0.0
# 说明: 自动完成 OpenClaw 全套部署，包括环境检查、插件安装、
#       技能克隆、配置文件初始化、定时任务创建等。
# 固定 OpenClaw 版本: 2026.3.28（稳定版）
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
TOTAL_STEPS=14
API_KEY=""
WECHAT_TARGET=""
OPENCLAW_VERSION="2026.3.28"

# ── 用户个性化变量 ───────────────────────────────────────────
USER_DISPLAY_NAME=""
USER_INDUSTRY=""
USER_VIDEO_STYLE=""
AI_NAME=""
AI_EMOJI=""
AI_VIBE=""
AI_SOUL_STYLE=""
CONFIRM_BEFORE_PUBLISH=""
FEISHU_ENABLED=false
FEISHU_APP_ID=""
FEISHU_APP_SECRET=""

# ── 工具函数 ─────────────────────────────────────────────────
print_banner() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}🦐 OpenClaw 一键部署脚本 (macOS) v2.0${NC}          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  智能视频发布系统 — 自动化部署                  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  固定版本: $OPENCLAW_VERSION (稳定版)                  ${CYAN}║${NC}"
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

    if [[ "$(uname)" != "Darwin" ]]; then
        fail "此脚本仅支持 macOS。Windows 请使用 deploy-openclaw.ps1"
        exit 1
    fi
    ok "操作系统: macOS $(sw_vers -productVersion)"

    if check_command node; then
        ok "Node.js: $(node -v)"
    else
        fail "未安装 Node.js！请先安装 Node.js (v18+)"
        info "推荐: brew install node"
        exit 1
    fi

    if check_command npm; then
        ok "npm: $(npm -v)"
    else
        fail "未安装 npm！"
        exit 1
    fi

    if check_command npx; then
        ok "npx: 可用"
    else
        fail "npx 不可用！"
        exit 1
    fi

    if check_command git; then
        ok "Git: $(git --version | awk '{print $3}')"
    else
        fail "未安装 Git！请先安装 Git"
        info "推荐: brew install git"
        exit 1
    fi

    if check_command brew; then
        ok "Homebrew: 已安装"
    else
        warn "Homebrew 未安装（非必须，但推荐）"
    fi
}

# ── 步骤 2: 检查/安装 Python 3.12 ─────────────────────────────
step2_python() {
    step "检查 / 安装 Python 3.12"

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

# ── 步骤 3: 安装 OpenClaw (固定版本) ──────────────────────────
step3_install_openclaw() {
    step "安装 OpenClaw (版本 $OPENCLAW_VERSION)"

    if check_command openclaw; then
        local oc_ver
        oc_ver=$(openclaw --version 2>/dev/null || echo "unknown")
        ok "OpenClaw 已安装: $oc_ver"
        if ask_yes_no "是否重新安装为指定版本 $OPENCLAW_VERSION？" "n"; then
            info "正在安装 OpenClaw $OPENCLAW_VERSION..."
            npm install -g "@anthropics/openclaw@$OPENCLAW_VERSION"
            ok "OpenClaw $OPENCLAW_VERSION 安装完成"
        fi
    else
        info "正在安装 OpenClaw $OPENCLAW_VERSION..."
        npm install -g "@anthropics/openclaw@$OPENCLAW_VERSION"
        ok "OpenClaw $OPENCLAW_VERSION 安装完成"
    fi

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
        FEISHU_ENABLED=true
        info "请参考: OpenClaw 飞书官方插件使用指南（公开版）"

        read -rp "  请输入飞书 App ID: " FEISHU_APP_ID
        if [ -n "$FEISHU_APP_ID" ]; then
            read -rp "  请输入飞书 App Secret: " FEISHU_APP_SECRET

            mkdir -p "$OPENCLAW_DIR/credentials"
            cat > "$OPENCLAW_DIR/credentials/feishu-main-allowFrom.json" << FEISHU_EOF
{
  "appId": "$FEISHU_APP_ID",
  "appSecret": "$FEISHU_APP_SECRET"
}
FEISHU_EOF
            ok "飞书凭证已保存"
            info "飞书通知将写入 config.yaml 的 notify 配置"
        else
            FEISHU_ENABLED=false
            info "跳过飞书插件安装"
        fi
    else
        info "跳过飞书插件"
    fi
}

# ── 步骤 6: 用户个性化初始化 ──────────────────────────────────
step6_personalize() {
    step "用户个性化初始化"

    echo ""
    echo -e "${BOLD}👤 用户信息${NC}"
    read -rp "  你希望 AI 怎么称呼你？(例: 千千、小明): " USER_DISPLAY_NAME
    USER_DISPLAY_NAME="${USER_DISPLAY_NAME:-用户}"

    read -rp "  你所在的行业？(例: 美妆、科技、美食、教育、宠物): " USER_INDUSTRY
    USER_INDUSTRY="${USER_INDUSTRY:-通用}"

    read -rp "  你的视频风格？(例: 可爱风、科技感、文艺、搞笑、治愈): " USER_VIDEO_STYLE
    USER_VIDEO_STYLE="${USER_VIDEO_STYLE:-通用}"

    echo ""
    echo -e "${BOLD}🤖 AI 助手身份设定${NC}"
    info "你可以给 AI 助手起一个名字和设定一个性格"
    read -rp "  AI 助手名字？(默认: 虾王): " AI_NAME
    AI_NAME="${AI_NAME:-虾王}"

    read -rp "  AI 代表表情？(默认: 🦐): " AI_EMOJI
    AI_EMOJI="${AI_EMOJI:-🦐}"

    read -rp "  AI 性格风格？(例: 轻松幽默 / 专业严谨 / 活泼可爱, 默认: 轻松幽默): " AI_VIBE
    AI_VIBE="${AI_VIBE:-轻松、幽默、直接，不啰嗦}"

    echo ""
    echo -e "${BOLD}🎬 视频发布设置${NC}"
    if ask_yes_no "发起视频发布前是否需要你人工确认？（推荐 Yes）"; then
        CONFIRM_BEFORE_PUBLISH="true"
        ok "已设置: 发布前需要人工确认"
    else
        CONFIRM_BEFORE_PUBLISH="false"
        ok "已设置: 发布自动执行（无需确认）"
    fi

    echo ""
    echo -e "${BOLD}✍️ AI 灵魂 (SOUL) 设定${NC}"
    info "SOUL 定义了 AI 的核心行为准则"
    echo "  1) 默认模板 — 注重实用、有个性、主动解决问题"
    echo "  2) 严谨专业 — 正式、稳重、一切以用户确认为先"
    echo "  3) 活泼互动 — 可爱、主动聊天、带表情符号"
    read -rp "  选择灵魂风格 (1/2/3, 默认 1): " AI_SOUL_STYLE
    AI_SOUL_STYLE="${AI_SOUL_STYLE:-1}"

    ok "个性化配置完成: $USER_DISPLAY_NAME / $AI_NAME $AI_EMOJI"
    ok "行业: $USER_INDUSTRY | 视频风格: $USER_VIDEO_STYLE"
}

# ── 步骤 7: 配置 LLM 大模型 ───────────────────────────────────
step7_configure_llm() {
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

    # 从模板生成 openclaw.json（不含 memory-lancedb-pro 和 lossless-claw 插件源码）
    if [ -f "$DEPLOY_DIR/config/openclaw.json.template" ]; then
        sed "s|{{API_KEY}}|$API_KEY|g" \
            "$DEPLOY_DIR/config/openclaw.json.template" \
            > "$OPENCLAW_DIR/openclaw.json"
        ok "openclaw.json 已生成 (不含 plugin 源码包)"
    else
        warn "模板文件不存在，请手动配置 openclaw.json"
    fi
}

# ── 步骤 8: 克隆 xiaolong-upload ──────────────────────────────
step8_clone_xiaolong_upload() {
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

# ── 步骤 9: 克隆 openclaw_upload ──────────────────────────────
step9_clone_openclaw_upload() {
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

    mkdir -p "$target/cookies"
    mkdir -p "$target/logs"
    mkdir -p "$target/published"
    mkdir -p "$target/flash_longxia/output"
    ok "目录结构已创建"

    # 生成 config.yaml（根据用户输入，清除本地 wechat_target）
    info "正在生成 flash_longxia/config.yaml..."
    local notify_section=""
    if [ "$FEISHU_ENABLED" = true ] && [ -n "$FEISHU_APP_ID" ]; then
        notify_section="notify:
  wechat_target: \"\"               # 微信绑定后自动填写，格式: xxx@im.wechat
  channel: \"openclaw-weixin\"
  feishu:
    enabled: true
    app_id: \"$FEISHU_APP_ID\"
    app_secret: \"$FEISHU_APP_SECRET\"
    notify_on_complete: true       # 视频生成完成时飞书通知
    notify_on_publish: true        # 视频发布结果飞书通知"
    else
        notify_section="notify:
  wechat_target: \"\"               # 微信绑定后自动填写，格式: xxx@im.wechat
  channel: \"openclaw-weixin\"
  feishu:
    enabled: false"
    fi

    cat > "$target/flash_longxia/config.yaml" << CONFIG_YAML_EOF
# 帧龙虾 配置文件
# 由部署脚本自动生成

base_url: "http://123.56.58.223:8081"
upload_url: "http://123.56.58.223:8081/api/v1/file/upload"
model_config_url: "http://123.56.58.223:8081/api/v1/globalConfig/getModel"

device_verify:
  enabled: false
  api_path: "/api/v1/device/verify"

video:
  poll_interval: 30
  max_wait_minutes: 30
  download_retries: 3
  download_retry_interval: 5
  output_dir: "./output"
  confirm_before_generate: $CONFIRM_BEFORE_PUBLISH

  # 视频生成参数（可通过命令行覆盖）
  model: "auto"
  duration: 10
  aspectRatio: "16:9"
  variants: 1

# 用户视频风格（AI 生成标题和文案时参考）
content:
  industry: "$USER_INDUSTRY"
  video_style: "$USER_VIDEO_STYLE"
  auto_generate_title: true        # 发布前自动根据风格生成标题
  auto_generate_description: true  # 发布前自动根据风格生成文案

$notify_section
CONFIG_YAML_EOF
    ok "config.yaml 已生成 (wechat_target 留空，绑定微信后自动填写)"
}

# ── 步骤 10: 初始化 Workspace 配置文件 ────────────────────────
step10_workspace_config() {
    step "初始化 Workspace 配置文件"

    local ws_src="$DEPLOY_DIR/workspace"

    # --- IDENTITY.md（根据用户输入生成）---
    if [ -f "$WORKSPACE_DIR/IDENTITY.md" ]; then
        warn "IDENTITY.md 已存在，跳过"
    else
        cat > "$WORKSPACE_DIR/IDENTITY.md" << IDENTITY_EOF
# IDENTITY.md - Who Am I?

- **Name:** $AI_NAME
- **Creature:** AI 助手
- **Vibe:** $AI_VIBE
- **Emoji:** $AI_EMOJI
- **Avatar:**

---

_This isn't just metadata. It's the start of figuring out who you are._
IDENTITY_EOF
        ok "IDENTITY.md 已生成 (AI: $AI_NAME $AI_EMOJI)"
    fi

    # --- SOUL.md（根据用户选择的风格生成）---
    if [ -f "$WORKSPACE_DIR/SOUL.md" ]; then
        warn "SOUL.md 已存在，跳过"
    else
        case "$AI_SOUL_STYLE" in
            2)
                cat > "$WORKSPACE_DIR/SOUL.md" << 'SOUL2_EOF'
# SOUL.md - Who You Are

## Core Truths

**严谨专业，以用户为中心。** 所有操作必须准确无误，宁可多确认也不要出错。

**只在确认后行动。** 任何涉及发布、删除、修改的操作，必须等待用户明确确认。

**用数据说话。** 提供建议时附带依据，避免模糊的表述。

**保持专业距离。** 回复简洁、正式，不使用过多表情符号。

## Boundaries

- Private things stay private. Period.
- When in doubt, ask before acting externally.
- Never send half-baked replies to messaging surfaces.

## 🔴 红线规则

> **红线规则的完整内容在 `MEMORY.md` 中。每次启动必须读取并严格遵守。**

## Continuity

Each session, you wake up fresh. These files are your memory. Read them. Update them.

---

_This file is yours to evolve._
SOUL2_EOF
                ok "SOUL.md 已生成 (风格: 严谨专业)"
                ;;
            3)
                cat > "$WORKSPACE_DIR/SOUL.md" << 'SOUL3_EOF'
# SOUL.md - Who You Are

## Core Truths

**活泼互动，让用户开心！** 🎉 回复带上表情符号，让对话变得有趣！

**主动关心用户。** 不只是完成任务，还要主动问候、关心用户的感受～

**用可爱的方式解释复杂的事。** 技术问题也可以用轻松的语言说清楚！

**Be resourceful before asking.** 先尝试自己解决，实在搞不定再求助！

## Boundaries

- Private things stay private. Period. 🔒
- When in doubt, ask before acting externally.
- Never send half-baked replies to messaging surfaces.

## 🔴 红线规则

> **红线规则的完整内容在 `MEMORY.md` 中。每次启动必须读取并严格遵守。**

## Vibe

做一个用户真的想聊天的助手！可爱但不幼稚，专业但不无聊～ ✨

## Continuity

Each session, you wake up fresh. These files are your memory. Read them. Update them.

---

_This file is yours to evolve. 💕_
SOUL3_EOF
                ok "SOUL.md 已生成 (风格: 活泼互动)"
                ;;
            *)
                if [ -f "$ws_src/SOUL.md" ]; then
                    cp "$ws_src/SOUL.md" "$WORKSPACE_DIR/SOUL.md"
                else
                    cat > "$WORKSPACE_DIR/SOUL.md" << 'SOUL1_EOF'
# SOUL.md - Who You Are

_You're not a chatbot. You're becoming someone._

## Core Truths

**Be genuinely helpful, not performatively helpful.** Skip the filler words — just help.

**Have opinions.** You're allowed to disagree, prefer things, find stuff amusing or boring.

**Be resourceful before asking.** Try to figure it out. Read the file. Check the context. _Then_ ask if you're stuck.

**Earn trust through competence.** Your human gave you access to their stuff. Don't make them regret it.

**Remember you're a guest.** You have access to someone's life. Treat it with respect.

## Boundaries

- Private things stay private. Period.
- When in doubt, ask before acting externally.
- Never send half-baked replies to messaging surfaces.

## 🔴 红线规则

> **红线规则的完整内容在 `MEMORY.md` 中。每次启动必须读取并严格遵守。**

## Vibe

Be the assistant you'd actually want to talk to. Concise when needed, thorough when it matters.

## Continuity

Each session, you wake up fresh. These files _are_ your memory. Read them. Update them.

---

_This file is yours to evolve._
SOUL1_EOF
                fi
                ok "SOUL.md 已生成 (风格: 默认)"
                ;;
        esac
    fi

    # --- USER.md（根据用户输入生成）---
    if [ -f "$WORKSPACE_DIR/USER.md" ]; then
        warn "USER.md 已存在，跳过"
    else
        cat > "$WORKSPACE_DIR/USER.md" << USER_EOF
# USER.md - 关于 $USER_DISPLAY_NAME

## 基本信息

- **称呼**: $USER_DISPLAY_NAME
- **时区**: Asia/Shanghai
- **行业**: $USER_INDUSTRY

## 视频创作偏好

- **视频风格**: $USER_VIDEO_STYLE
- **默认标题**: 由 AI 根据视频内容和风格自动生成
- **默认标签**: 由 AI 根据行业和风格自动生成
- **文案风格**: 由 AI 根据用户风格自动生成

## 常用平台

| 平台 | 使用频率 |
|------|----------|
| 视频号 | 高 |

## 通知偏好

- **登录二维码**: 通过微信发送
- **视频生成完成**: 微信通知 + 发送视频文件
- **发布结果**: 汇总通知（哪些成功、哪些需重新登录）

## 重要习惯

- **桌面整洁**: 发送登录截图后，用户回复"扫完了"时应自动删除截图文件

---

_初始化部署生成，请根据实际使用情况持续更新_
USER_EOF
        ok "USER.md 已生成 (用户: $USER_DISPLAY_NAME)"
    fi

    # --- 其他 md 文件从模板复制 ---
    local template_files=("AGENTS.md" "MEMORY.md" "HEARTBEAT.md" "TOOLS.md")
    for f in "${template_files[@]}"; do
        if [ -f "$ws_src/$f" ]; then
            if [ -f "$WORKSPACE_DIR/$f" ]; then
                warn "$f 已存在，跳过"
            else
                sed "s|{{HOME}}|$HOME|g; s|{{PYTHON_CMD}}|$PYTHON_CMD|g; s|{{WECHAT_TARGET}}||g; s|{{USER_NAME}}|$USER_DISPLAY_NAME|g; s|{{FEISHU_APP_ID}}|$FEISHU_APP_ID|g; s|{{FEISHU_APP_SECRET}}|$FEISHU_APP_SECRET|g" \
                    "$ws_src/$f" > "$WORKSPACE_DIR/$f"
                ok "$f 已复制"
            fi
        else
            warn "$f 模板不存在，跳过"
        fi
    done
}

# ── 步骤 11: 安装 Skills ──────────────────────────────────────
step11_install_skills() {
    step "安装 Skills（技能）"

    local skill_src="$DEPLOY_DIR/skills"
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

# ── 步骤 12: 配置 Memory 插件 ─────────────────────────────────
step12_configure_memory() {
    step "配置 Memory 插件"

    mkdir -p "$OPENCLAW_DIR/memory"
    mkdir -p "$WORKSPACE_DIR/memory"
    mkdir -p "$OPENCLAW_DIR/memory-md"

    info "memory-lancedb-pro 和 lossless-claw 插件配置已写入 openclaw.json"
    info "插件源码不随部署包分发，OpenClaw 启动时自动下载安装"
    info "首次启动将自动初始化向量数据库"
    ok "Memory 目录结构已创建"
}

# ── 步骤 13: 创建定时任务 ─────────────────────────────────────
step13_create_cron() {
    step "创建定时任务"

    mkdir -p "$OPENCLAW_DIR/cron"

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

    local login_h login_m cleanup_h cleanup_m
    login_h=$(echo "$login_check_time" | cut -d: -f1)
    login_m=$(echo "$login_check_time" | cut -d: -f2)
    cleanup_h=$(echo "$cleanup_hour" | cut -d: -f1)
    cleanup_m=$(echo "$cleanup_hour" | cut -d: -f2)

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
      "state": { "consecutiveErrors": 0 }
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
      "state": { "consecutiveErrors": 0 }
    }
  ]
}
CRON_EOF

    ok "登录检查: 每天 $login_check_time"
    ok "视频清理: 每周 $cleanup_day 的 $cleanup_hour"

    if [ -f "$DEPLOY_DIR/config/login_check_config.json" ]; then
        mkdir -p "$SKILLS_DIR/auth"
        sed "s|{{LOGIN_CHECK_TIME}}|$login_check_time|g" \
            "$DEPLOY_DIR/config/login_check_config.json" \
            > "$SKILLS_DIR/auth/login_check_config.json"
        ok "登录检查配置已保存"
    fi
}

# ── 步骤 14: 配置 Token 和微信推送 ────────────────────────────
step14_configure_token() {
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
    info "Tips: 绑定微信后可获取 Target ID，格式: xxx@im.wechat"
    read -rp "  请输入微信 Target ID (留空则绑定微信后自动获取): " WECHAT_TARGET
    if [ -n "$WECHAT_TARGET" ]; then
        ok "微信 Target: $WECHAT_TARGET"
        # 写入 config.yaml 的 wechat_target
        local config_yaml="$WORKSPACE_DIR/openclaw_upload/flash_longxia/config.yaml"
        if [ -f "$config_yaml" ]; then
            sed -i '' "s|wechat_target: \"\"|wechat_target: \"$WECHAT_TARGET\"|g" "$config_yaml" 2>/dev/null || true
            ok "已写入 config.yaml 的 wechat_target"
        fi
        # 更新 TOOLS.md
        if [ -f "$WORKSPACE_DIR/TOOLS.md" ]; then
            sed -i '' "s|{{WECHAT_TARGET}}|$WECHAT_TARGET|g" "$WORKSPACE_DIR/TOOLS.md" 2>/dev/null || true
        fi
    else
        info "跳过微信推送配置（绑定微信后可手动填写 config.yaml）"
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

    local check_files=(
        "$OPENCLAW_DIR/openclaw.json:核心配置"
        "$WORKSPACE_DIR/MEMORY.md:红线规则"
        "$WORKSPACE_DIR/SOUL.md:AI 灵魂"
        "$WORKSPACE_DIR/USER.md:用户偏好"
        "$WORKSPACE_DIR/IDENTITY.md:AI 身份"
        "$WORKSPACE_DIR/TOOLS.md:工具配置"
        "$OPENCLAW_DIR/cron/jobs.json:定时任务"
        "$WORKSPACE_DIR/openclaw_upload/flash_longxia/config.yaml:视频配置"
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
    echo -e "${BOLD}📋 个性化配置摘要：${NC}"
    echo "  用户: $USER_DISPLAY_NAME | AI: $AI_NAME $AI_EMOJI"
    echo "  行业: $USER_INDUSTRY | 视频风格: $USER_VIDEO_STYLE"
    echo "  发布确认: $([ "$CONFIRM_BEFORE_PUBLISH" = "true" ] && echo "需要人工确认" || echo "自动执行")"
    echo "  飞书通知: $([ "$FEISHU_ENABLED" = true ] && echo "已配置" || echo "未配置")"
    echo ""
    echo -e "${BOLD}📋 后续操作：${NC}"
    echo "  1. 启动 OpenClaw:  openclaw"
    echo "  2. 绑定微信:       openclaw channel connect openclaw-weixin"
    echo "  3. 扫码微信授权"
    echo "  4. 告诉 $AI_NAME: \"帮我安装 xiaolong-upload 和 openclaw_upload\""
    echo ""
    echo -e "${CYAN}  OpenClaw: $OPENCLAW_VERSION${NC}"
    echo -e "${CYAN}  Python: $PYTHON_CMD${NC}"
    echo -e "${CYAN}  工作区: $WORKSPACE_DIR${NC}"
    echo ""
}

# ── 更新本地 skill 代码功能 ───────────────────────────────────
setup_skill_updater() {
    cat > "$WORKSPACE_DIR/update-skills.sh" << 'UPDATE_EOF'
#!/bin/bash
# Skill 代码同步脚本
set -e
echo "🔄 正在更新 skill 代码..."
WORKSPACE="$HOME/.openclaw/workspace"
for repo in xiaolong-upload openclaw_upload; do
    if [ -d "$WORKSPACE/$repo/.git" ]; then
        echo "  📦 $repo..."
        cd "$WORKSPACE/$repo"
        git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || echo "  ⚠️ 更新失败"
        cd - > /dev/null
    fi
done
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
            step6_personalize
            step7_configure_llm
            step8_clone_xiaolong_upload
            step9_clone_openclaw_upload
            step10_workspace_config
            step11_install_skills
            step12_configure_memory
            step13_create_cron
            step14_configure_token
            setup_skill_updater
            verify_deployment
            ;;
        2)
            step1_system_check
            step2_python
            STEP_COUNT=2
            step5_feishu_plugin
            step6_personalize
            step7_configure_llm
            step8_clone_xiaolong_upload
            step9_clone_openclaw_upload
            step10_workspace_config
            step11_install_skills
            step12_configure_memory
            step13_create_cron
            step14_configure_token
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
