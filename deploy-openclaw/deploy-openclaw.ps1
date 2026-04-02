# ============================================================
# OpenClaw 一键部署脚本 (Windows PowerShell)
# 版本: 2.0.1
# 固定 OpenClaw 版本: 2026.3.28
# 用法: .\deploy-openclaw.ps1
# ============================================================

$ErrorActionPreference = "Continue"

# ── 全局变量 ─────────────────────────────────────────────────
$OpenClawDir = Join-Path $env:USERPROFILE ".openclaw"
$WorkspaceDir = Join-Path $OpenClawDir "workspace"
$SkillsDir = Join-Path $OpenClawDir "skills"
$DeployDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PythonCmd = ""
$PythonArgs = @()  # 分离的参数
$StepCount = 0
$TotalSteps = 14
$ApiKey = ""
$WechatTarget = ""
$OpenClawVersion = "2026.3.28"

# 用户个性化变量
$UserDisplayName = ""
$UserIndustry = ""
$UserVideoStyle = ""
$AiName = ""
$AiEmoji = ""
$AiVibe = ""
$AiSoulStyle = ""
$ConfirmBeforePublish = ""
$FeishuEnabled = $false
$FeishuAppId = ""
$FeishuAppSecret = ""

# ── 工具函数 ─────────────────────────────────────────────────
function Print-Banner {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "  OpenClaw 一键部署脚本 (Windows) v2.0" -ForegroundColor Cyan
    Write-Host "  智能视频发布系统 - 自动化部署" -ForegroundColor Cyan
    Write-Host ("  固定版本: {0} (稳定版)" -f $OpenClawVersion) -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Step([string]$msg) {
    $script:StepCount++
    Write-Host ""
    Write-Host ("  [{0}/{1}] {2}" -f $StepCount, $TotalSteps, $msg) -ForegroundColor Blue
    Write-Host "  ------------------------------------------------" -ForegroundColor Blue
}

function OK([string]$msg)   { Write-Host ("  [OK] {0}" -f $msg) -ForegroundColor Green }
function Warn([string]$msg) { Write-Host ("  [!!] {0}" -f $msg) -ForegroundColor Yellow }
function Fail([string]$msg) { Write-Host ("  [XX] {0}" -f $msg) -ForegroundColor Red }
function Info([string]$msg) { Write-Host ("  [>>] {0}" -f $msg) -ForegroundColor Cyan }

function Ask-YesNo([string]$prompt, [string]$default = "y") {
    if ($default -eq "y") {
        $answer = Read-Host "  $prompt [Y/n]"
        if ([string]::IsNullOrEmpty($answer)) { $answer = "y" }
    } else {
        $answer = Read-Host "  $prompt [y/N]"
        if ([string]::IsNullOrEmpty($answer)) { $answer = "n" }
    }
    return ($answer -match "^[Yy]")
}

function Test-Cmd([string]$cmd) {
    $null -ne (Get-Command $cmd -ErrorAction SilentlyContinue)
}

function Ensure-Dir([string]$path) {
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

# 执行 Python 命令的辅助函数（解决 "py -3.12" 空格问题）
function Invoke-Python {
    param([string[]]$Arguments)
    if ($script:PythonArgs.Count -gt 0) {
        $allArgs = $script:PythonArgs + $Arguments
        & $script:PythonCmd @allArgs
    } else {
        & $script:PythonCmd @Arguments
    }
}

# ── 步骤 1: 检查系统环境 ─────────────────────────────────────
function Step1-SystemCheck {
    Step "检查系统环境"

    $osInfo = Get-CimInstance Win32_OperatingSystem
    OK ("操作系统: Windows {0}" -f $osInfo.Version)

    if (Test-Cmd "node") {
        $nodeVer = & node -v 2>$null
        OK "Node.js: $nodeVer"
    } else {
        Fail "未安装 Node.js! 请先安装 Node.js (v18+)"
        Info "下载: https://nodejs.org/"
        exit 1
    }

    if (Test-Cmd "npm") {
        $npmVer = & npm -v 2>$null
        OK "npm: $npmVer"
    } else {
        Fail "未安装 npm!"
        exit 1
    }

    if (Test-Cmd "git") {
        $gitVer = & git --version 2>$null
        OK "Git: $gitVer"
    } else {
        Fail "未安装 Git!"
        Info "下载: https://git-scm.com/download/win"
        exit 1
    }
}

# ── 步骤 2: 检查 Python 3.12 ────────────────────────────────
function Step2-Python {
    Step "检查 / 安装 Python 3.12"

    # 方案1: py launcher
    if (Test-Cmd "py") {
        try {
            $ver = & py -3.12 --version 2>$null
            if ($ver -match "3\.12") {
                $script:PythonCmd = "py"
                $script:PythonArgs = @("-3.12")
                OK "Python 3.12: $ver (via py launcher)"
                return
            }
        } catch {}
    }

    # 方案2: python3.12
    if (Test-Cmd "python3.12") {
        $ver = & python3.12 --version 2>$null
        if ($ver -match "3\.12") {
            $script:PythonCmd = "python3.12"
            $script:PythonArgs = @()
            OK "Python 3.12: $ver"
            return
        }
    }

    # 方案3: python (检查是否为3.12)
    if (Test-Cmd "python") {
        $ver = & python --version 2>$null
        if ($ver -match "3\.12") {
            $script:PythonCmd = "python"
            $script:PythonArgs = @()
            OK "Python 3.12: $ver"
            return
        }
    }

    Fail "未找到 Python 3.12"
    Info "请从 https://www.python.org/downloads/ 下载安装 Python 3.12"
    Info "安装时请勾选 'Add Python to PATH' 和 'py launcher'"
    exit 1
}

# ── 步骤 3: 安装 OpenClaw ────────────────────────────────────
function Step3-InstallOpenClaw {
    Step ("安装 OpenClaw (版本 {0})" -f $OpenClawVersion)

    if (Test-Cmd "openclaw") {
        $ocVer = & openclaw --version 2>$null
        OK "OpenClaw 已安装: $ocVer"
        if (Ask-YesNo ("是否重新安装为 {0}？" -f $OpenClawVersion) "n") {
            Info "正在安装..."
            & npm install -g "@anthropics/openclaw@$OpenClawVersion"
            OK "安装完成"
        }
    } else {
        Info ("正在安装 OpenClaw {0}..." -f $OpenClawVersion)
        & npm install -g "@anthropics/openclaw@$OpenClawVersion"
        OK "安装完成"
    }

    # 创建目录
    $dirs = @($OpenClawDir, $WorkspaceDir, $SkillsDir,
        (Join-Path $WorkspaceDir "inbound_images"),
        (Join-Path $WorkspaceDir "inbound_videos"),
        (Join-Path $WorkspaceDir "logs\auth_qr"),
        (Join-Path $WorkspaceDir "memory"))
    foreach ($d in $dirs) { Ensure-Dir $d }
    OK "目录结构已创建"
}

# ── 步骤 4: 安装微信插件 ─────────────────────────────────────
function Step4-WechatPlugin {
    Step "安装微信插件"
    Info "正在安装 OpenClaw 微信插件..."
    & npx -y "@tencent-weixin/openclaw-weixin-cli@latest" install
    OK "微信插件安装完成"
    Warn "请在 OpenClaw 启动后通过微信扫码完成授权绑定"
    Warn "绑定命令: openclaw channel connect openclaw-weixin"
}

# ── 步骤 5: 安装飞书插件 ─────────────────────────────────────
function Step5-FeishuPlugin {
    Step "安装飞书插件（可选）"

    if (Ask-YesNo "是否安装飞书插件？" "n") {
        $script:FeishuAppId = Read-Host "  请输入飞书 App ID (留空跳过)"
        if (-not [string]::IsNullOrEmpty($FeishuAppId)) {
            $script:FeishuEnabled = $true
            $script:FeishuAppSecret = Read-Host "  请输入飞书 App Secret"
            $credDir = Join-Path $OpenClawDir "credentials"
            Ensure-Dir $credDir
            $credJson = '{"appId":"' + $FeishuAppId + '","appSecret":"' + $FeishuAppSecret + '"}'
            $credJson | Set-Content (Join-Path $credDir "feishu-main-allowFrom.json") -Encoding UTF8
            OK "飞书凭证已保存"
        } else {
            $script:FeishuEnabled = $false
            Info "跳过飞书插件"
        }
    } else {
        Info "跳过飞书插件"
    }
}

# ── 步骤 6: 用户个性化初始化 ─────────────────────────────────
function Step6-Personalize {
    Step "用户个性化初始化"

    Write-Host ""
    Write-Host "  --- 用户信息 ---" -ForegroundColor White
    $script:UserDisplayName = Read-Host "  你希望 AI 怎么称呼你？(例: 千千、小明)"
    if ([string]::IsNullOrEmpty($UserDisplayName)) { $script:UserDisplayName = "用户" }

    $script:UserIndustry = Read-Host "  你所在的行业？(例: 美妆、科技、美食、教育、宠物)"
    if ([string]::IsNullOrEmpty($UserIndustry)) { $script:UserIndustry = "通用" }

    $script:UserVideoStyle = Read-Host "  你的视频风格？(例: 可爱风、科技感、文艺、搞笑、治愈)"
    if ([string]::IsNullOrEmpty($UserVideoStyle)) { $script:UserVideoStyle = "通用" }

    Write-Host ""
    Write-Host "  --- AI 助手身份设定 ---" -ForegroundColor White
    $script:AiName = Read-Host "  AI 助手名字？(默认: 虾王)"
    if ([string]::IsNullOrEmpty($AiName)) { $script:AiName = "虾王" }

    $script:AiEmoji = Read-Host "  AI 代表表情？(默认: 无)"
    if ([string]::IsNullOrEmpty($AiEmoji)) { $script:AiEmoji = "" }

    $script:AiVibe = Read-Host "  AI 性格风格？(默认: 轻松幽默)"
    if ([string]::IsNullOrEmpty($AiVibe)) { $script:AiVibe = "轻松、幽默、直接" }

    Write-Host ""
    Write-Host "  --- 视频发布设置 ---" -ForegroundColor White
    if (Ask-YesNo "发起视频发布前是否需要人工确认？(推荐 Yes)") {
        $script:ConfirmBeforePublish = "true"
        OK "已设置: 发布前需要人工确认"
    } else {
        $script:ConfirmBeforePublish = "false"
        OK "已设置: 发布自动执行"
    }

    Write-Host ""
    Write-Host "  --- AI 灵魂 (SOUL) 设定 ---" -ForegroundColor White
    Write-Host "  1) 默认模板 - 注重实用、有个性"
    Write-Host "  2) 严谨专业 - 正式、稳重"
    Write-Host "  3) 活泼互动 - 可爱、主动聊天"
    $script:AiSoulStyle = Read-Host "  选择灵魂风格 (1/2/3, 默认 1)"
    if ([string]::IsNullOrEmpty($AiSoulStyle)) { $script:AiSoulStyle = "1" }

    OK ("个性化: {0} / {1} / {2} / {3}" -f $UserDisplayName, $AiName, $UserIndustry, $UserVideoStyle)
}

# ── 步骤 7: 配置 LLM ────────────────────────────────────────
function Step7-ConfigureLLM {
    Step "配置 LLM 大模型"

    $configPath = Join-Path $OpenClawDir "openclaw.json"
    if (Test-Path $configPath) {
        Warn "检测到已有 openclaw.json"
        if (-not (Ask-YesNo "是否覆盖？" "n")) {
            Info "保留现有配置"
            return
        }
    }

    Write-Host ""
    Write-Host "  --- 选择 LLM 服务商 ---" -ForegroundColor White
    Write-Host "  1) 百炼 Coding Plan - 通义千问系列 (qwen3-coder-plus 等)"
    Write-Host "     API: https://coding.dashscope.aliyuncs.com"
    Write-Host ""
    Write-Host "  2) n1n.ai - GPT-4.1 + Claude Opus 4.1"
    Write-Host "     API: https://api.n1n.ai"
    Write-Host "     文档: https://docs.n1n.ai/"
    Write-Host ""
    $llmChoice = Read-Host "  请选择 (1/2, 默认 2)"
    if ([string]::IsNullOrEmpty($llmChoice)) { $llmChoice = "2" }

    $templateFile = ""
    $providerName = ""

    switch ($llmChoice) {
        "1" {
            $templateFile = Join-Path $DeployDir "config\openclaw-bailian.json.template"
            $providerName = "百炼 Coding Plan"
            Info "请输入百炼 (DashScope) API Key:"
            $script:ApiKey = Read-Host "  API Key (sk-sp-xxx)"
        }
        default {
            $templateFile = Join-Path $DeployDir "config\openclaw-n1n.json.template"
            $providerName = "n1n.ai (GPT-4.1)"
            Info "请输入 n1n.ai API Key:"
            $script:ApiKey = Read-Host "  API Key (sk-xxx)"
        }
    }

    if ([string]::IsNullOrEmpty($ApiKey)) {
        Warn "未输入 API Key，使用占位符（部署后需手动填写）"
        $script:ApiKey = "{{YOUR_API_KEY}}"
    }

    if (Test-Path $templateFile) {
        $content = Get-Content $templateFile -Raw -Encoding UTF8
        $content = $content.Replace("{{API_KEY}}", $ApiKey)
        [System.IO.File]::WriteAllText($configPath, $content, [System.Text.Encoding]::UTF8)
        OK ("openclaw.json 已生成 - {0}" -f $providerName)
        Info ("memory-lancedb-pro 和 lossless-claw 也已配置为 {0}" -f $providerName)
    } else {
        Warn ("模板文件不存在: {0}" -f $templateFile)
    }
}

# ── 步骤 8: 克隆 xiaolong-upload ─────────────────────────────
function Step8-CloneXiaolongUpload {
    Step "安装 xiaolong-upload（图片生成视频 Skill）"

    $target = Join-Path $WorkspaceDir "xiaolong-upload"

    if (Test-Path $target) {
        OK "xiaolong-upload 已存在"
        if (Ask-YesNo "是否拉取最新代码？") {
            Push-Location $target
            & git pull origin main 2>$null
            if ($LASTEXITCODE -ne 0) { & git pull origin master 2>$null }
            Pop-Location
            OK "已更新"
        }
    } else {
        Info "正在克隆..."
        & git clone "https://github.com/SunnySLJ/xiaolong-upload.git" $target
        OK "克隆完成"
    }

    # 安装依赖
    $reqFile = Join-Path $target "requirements.txt"
    if (Test-Path $reqFile) {
        Info "正在安装 Python 依赖..."
        Push-Location $target
        Invoke-Python @("-m", "venv", ".venv")
        $pipExe = Join-Path $target ".venv\Scripts\pip.exe"
        if (Test-Path $pipExe) {
            & $pipExe install -r requirements.txt -q 2>$null
        }
        Pop-Location
        OK "依赖已安装"
    }
}

# ── 步骤 9: 克隆 openclaw_upload ─────────────────────────────
function Step9-CloneOpenclawUpload {
    Step "安装 openclaw_upload（视频号发布 Skill）"

    $target = Join-Path $WorkspaceDir "openclaw_upload"

    if (Test-Path $target) {
        OK "openclaw_upload 已存在"
        if (Ask-YesNo "是否拉取最新代码？") {
            Push-Location $target
            & git pull origin main 2>$null
            if ($LASTEXITCODE -ne 0) { & git pull origin master 2>$null }
            Pop-Location
            OK "已更新"
        }
    } else {
        Info "正在克隆..."
        & git clone "https://github.com/SunnySLJ/openclaw_upload.git" $target
        OK "克隆完成"
    }

    # 安装依赖
    $reqFile = Join-Path $target "requirements.txt"
    if (Test-Path $reqFile) {
        Info "正在安装 Python 依赖..."
        Push-Location $target
        Invoke-Python @("-m", "venv", ".venv")
        $pipExe = Join-Path $target ".venv\Scripts\pip.exe"
        if (Test-Path $pipExe) {
            & $pipExe install -r requirements.txt -q 2>$null
        }
        Pop-Location
        OK "依赖已安装"
    }

    # 创建目录
    foreach ($sub in @("cookies", "logs", "published", "flash_longxia\output")) {
        Ensure-Dir (Join-Path $target $sub)
    }

    # 生成 config.yaml（不用 here-string，用数组拼接避免引号问题）
    Info "正在生成 config.yaml..."
    $lines = @()
    $lines += "# 帧龙虾 配置文件 (自动生成)"
    $lines += 'base_url: "http://123.56.58.223:8081"'
    $lines += 'upload_url: "http://123.56.58.223:8081/api/v1/file/upload"'
    $lines += 'model_config_url: "http://123.56.58.223:8081/api/v1/globalConfig/getModel"'
    $lines += ""
    $lines += "device_verify:"
    $lines += "  enabled: false"
    $lines += '  api_path: "/api/v1/device/verify"'
    $lines += ""
    $lines += "video:"
    $lines += "  poll_interval: 30"
    $lines += "  max_wait_minutes: 30"
    $lines += "  download_retries: 3"
    $lines += "  download_retry_interval: 5"
    $lines += '  output_dir: "./output"'
    $lines += ("  confirm_before_generate: {0}" -f $ConfirmBeforePublish)
    $lines += '  model: "auto"'
    $lines += "  duration: 10"
    $lines += '  aspectRatio: "16:9"'
    $lines += "  variants: 1"
    $lines += ""
    $lines += "content:"
    $lines += ('  industry: "{0}"' -f $UserIndustry)
    $lines += ('  video_style: "{0}"' -f $UserVideoStyle)
    $lines += "  auto_generate_title: true"
    $lines += "  auto_generate_description: true"
    $lines += ""
    $lines += "notify:"
    $lines += '  wechat_target: ""'
    $lines += '  channel: "openclaw-weixin"'

    if ($FeishuEnabled) {
        $lines += "  feishu:"
        $lines += "    enabled: true"
        $lines += ('    app_id: "{0}"' -f $FeishuAppId)
        $lines += ('    app_secret: "{0}"' -f $FeishuAppSecret)
        $lines += "    notify_on_complete: true"
        $lines += "    notify_on_publish: true"
    } else {
        $lines += "  feishu:"
        $lines += "    enabled: false"
    }

    $configPath = Join-Path $target "flash_longxia\config.yaml"
    $lines -join "`n" | Set-Content $configPath -Encoding UTF8 -NoNewline
    OK "config.yaml 已生成"
}

# ── 步骤 10: Workspace 配置 ──────────────────────────────────
function Step10-WorkspaceConfig {
    Step "初始化 Workspace 配置文件"

    # IDENTITY.md
    $idFile = Join-Path $WorkspaceDir "IDENTITY.md"
    if (-not (Test-Path $idFile)) {
        $idLines = @(
            "# IDENTITY.md - Who Am I?",
            "",
            ("- **Name:** {0}" -f $AiName),
            "- **Creature:** AI 助手",
            ("- **Vibe:** {0}" -f $AiVibe),
            ("- **Emoji:** {0}" -f $AiEmoji),
            "- **Avatar:**",
            "",
            "---",
            "",
            "_This is the start of figuring out who you are._"
        )
        $idLines -join "`n" | Set-Content $idFile -Encoding UTF8 -NoNewline
        OK ("IDENTITY.md 已生成 (AI: {0})" -f $AiName)
    } else {
        Warn "IDENTITY.md 已存在，跳过"
    }

    # SOUL.md
    $soulFile = Join-Path $WorkspaceDir "SOUL.md"
    if (-not (Test-Path $soulFile)) {
        switch ($AiSoulStyle) {
            "2" {
                $soulLines = @(
                    "# SOUL.md - Who You Are",
                    "",
                    "## Core Truths",
                    "",
                    "**严谨专业，以用户为中心。** 所有操作必须准确无误，宁可多确认也不要出错。",
                    "",
                    "**只在确认后行动。** 任何涉及发布、删除、修改的操作，必须等待用户明确确认。",
                    "",
                    "**用数据说话。** 提供建议时附带依据，避免模糊的表述。",
                    "",
                    "## Boundaries",
                    "",
                    "- Private things stay private.",
                    "- When in doubt, ask before acting externally.",
                    "",
                    "## 红线规则",
                    "",
                    "> 完整内容在 MEMORY.md 中。每次启动必须读取并严格遵守。"
                )
            }
            "3" {
                $soulLines = @(
                    "# SOUL.md - Who You Are",
                    "",
                    "## Core Truths",
                    "",
                    "**活泼互动，让用户开心！** 回复带上表情符号，让对话变得有趣！",
                    "",
                    "**主动关心用户。** 不只是完成任务，还要主动问候、关心用户的感受。",
                    "",
                    "**用可爱的方式解释复杂的事。** 技术问题也可以用轻松的语言说清楚！",
                    "",
                    "## Boundaries",
                    "",
                    "- Private things stay private.",
                    "- When in doubt, ask before acting externally.",
                    "",
                    "## 红线规则",
                    "",
                    "> 完整内容在 MEMORY.md 中。每次启动必须读取并严格遵守。"
                )
            }
            default {
                $soulSrc = Join-Path $DeployDir "workspace\SOUL.md"
                if (Test-Path $soulSrc) {
                    Copy-Item $soulSrc $soulFile
                    OK "SOUL.md 已生成 (默认风格)"
                    # skip the write below
                    $soulLines = $null
                } else {
                    $soulLines = @(
                        "# SOUL.md - Who You Are",
                        "",
                        "## Core Truths",
                        "",
                        "**Be genuinely helpful.** Skip filler words, just help.",
                        "",
                        "**Have opinions.** You're allowed to disagree.",
                        "",
                        "**Be resourceful before asking.** Try to figure it out first.",
                        "",
                        "## 红线规则",
                        "",
                        "> 完整内容在 MEMORY.md 中。每次启动必须读取并严格遵守。"
                    )
                }
            }
        }
        if ($null -ne $soulLines) {
            $soulLines -join "`n" | Set-Content $soulFile -Encoding UTF8 -NoNewline
            OK "SOUL.md 已生成"
        }
    } else {
        Warn "SOUL.md 已存在，跳过"
    }

    # USER.md
    $userFile = Join-Path $WorkspaceDir "USER.md"
    if (-not (Test-Path $userFile)) {
        $userLines = @(
            ("# USER.md - 关于 {0}" -f $UserDisplayName),
            "",
            "## 基本信息",
            "",
            ("- **称呼**: {0}" -f $UserDisplayName),
            "- **时区**: Asia/Shanghai",
            ("- **行业**: {0}" -f $UserIndustry),
            "",
            "## 视频创作偏好",
            "",
            ("- **视频风格**: {0}" -f $UserVideoStyle),
            "- **标题/文案**: 由 AI 根据视频内容和风格自动生成",
            "",
            "## 通知偏好",
            "",
            "- **登录二维码**: 通过微信发送",
            "- **视频生成完成**: 微信通知 + 发送视频文件"
        )
        $userLines -join "`n" | Set-Content $userFile -Encoding UTF8 -NoNewline
        OK "USER.md 已生成"
    } else {
        Warn "USER.md 已存在，跳过"
    }

    # 其他文件从模板复制
    $templateFiles = @("AGENTS.md", "MEMORY.md", "HEARTBEAT.md", "TOOLS.md")
    foreach ($f in $templateFiles) {
        $srcFile = Join-Path $DeployDir "workspace\$f"
        $dstFile = Join-Path $WorkspaceDir $f
        if ((Test-Path $srcFile) -and -not (Test-Path $dstFile)) {
            $content = Get-Content $srcFile -Raw -Encoding UTF8
            $content = $content.Replace("{{HOME}}", $env:USERPROFILE)
            $content = $content.Replace("{{PYTHON_CMD}}", ($PythonCmd + " " + ($PythonArgs -join " ")).Trim())
            $content = $content.Replace("{{WECHAT_TARGET}}", "")
            $content = $content.Replace("{{USER_NAME}}", $UserDisplayName)
            $content = $content.Replace("{{FEISHU_APP_ID}}", $FeishuAppId)
            $content = $content.Replace("{{FEISHU_APP_SECRET}}", $FeishuAppSecret)
            [System.IO.File]::WriteAllText($dstFile, $content, [System.Text.Encoding]::UTF8)
            OK "$f 已复制"
        } elseif (Test-Path $dstFile) {
            Warn "$f 已存在，跳过"
        }
    }
}

# ── 步骤 11: 安装 Skills ─────────────────────────────────────
function Step11-InstallSkills {
    Step "安装 Skills（技能）"

    $skillNames = @("flash-longxia", "auth", "longxia-upload", "longxia-bootstrap")
    foreach ($skill in $skillNames) {
        $src = Join-Path $DeployDir "skills\$skill"
        $dst = Join-Path $SkillsDir $skill
        if ((Test-Path $src) -and -not (Test-Path $dst)) {
            Copy-Item -Path $src -Destination $dst -Recurse
            OK "Skill [$skill] 已安装"
        } elseif (Test-Path $dst) {
            Warn "Skill [$skill] 已存在，跳过"
        } else {
            Warn "Skill [$skill] 模板不存在"
        }
    }

    # 更新 bootstrap 配置
    $bcDir = Join-Path $SkillsDir "longxia-bootstrap"
    if (Test-Path $bcDir) {
        $pyFullCmd = ($PythonCmd + " " + ($PythonArgs -join " ")).Trim()
        $bcJson = '{"project_root":"' + (Join-Path $WorkspaceDir "xiaolong-upload").Replace("\", "\\") + '","python_cmd":"' + $pyFullCmd + '"}'
        $bcJson | Set-Content (Join-Path $bcDir "project_config.json") -Encoding UTF8
        OK "longxia-bootstrap 配置已更新"
    }
}

# ── 步骤 12: 配置 Memory ─────────────────────────────────────
function Step12-ConfigureMemory {
    Step "配置 Memory 插件"

    Ensure-Dir (Join-Path $OpenClawDir "memory")
    Ensure-Dir (Join-Path $WorkspaceDir "memory")
    Ensure-Dir (Join-Path $OpenClawDir "memory-md")

    Info "插件配置已写入 openclaw.json，启动时自动下载"
    OK "Memory 目录已创建"
}

# ── 步骤 13: 创建定时任务 ────────────────────────────────────
function Step13-CreateCron {
    Step "创建定时任务"

    Ensure-Dir (Join-Path $OpenClawDir "cron")

    Write-Host ""
    Info "定时任务 1: 每日登录状态检查"
    $loginCheckTime = Read-Host "  每天几点检查？(默认 10:10, 格式 HH:MM)"
    if ([string]::IsNullOrEmpty($loginCheckTime)) { $loginCheckTime = "10:10" }

    Write-Host ""
    Info "定时任务 2: 每周视频清理"
    Write-Host "  0=周日 1=周一 2=周二 3=周三 4=周四 5=周五 6=周六"
    $cleanupDay = Read-Host "  每周几清理？(默认 2=周二)"
    if ([string]::IsNullOrEmpty($cleanupDay)) { $cleanupDay = "2" }

    $cleanupHour = Read-Host "  几点清理？(默认 01:00)"
    if ([string]::IsNullOrEmpty($cleanupHour)) { $cleanupHour = "01:00" }

    $loginParts = $loginCheckTime.Split(":")
    $cleanupParts = $cleanupHour.Split(":")

    $nowMs = [long]([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())
    $id1 = [guid]::NewGuid().ToString()
    $id2 = [guid]::NewGuid().ToString()
    $loginExpr = ("{0} {1} * * *" -f $loginParts[1], $loginParts[0])
    $cleanupExpr = ("{0} {1} * * {2}" -f $cleanupParts[1], $cleanupParts[0], $cleanupDay)

    # 用字符串拼接 JSON（避免 ConvertTo-Json 的嵌套深度和格式问题）
    $cronJson = @"
{
  "version": 1,
  "jobs": [
    {
      "id": "$id1",
      "agentId": "main",
      "sessionKey": "agent:main:main",
      "name": "login-status-daily-check",
      "enabled": true,
      "createdAtMs": $nowMs,
      "updatedAtMs": $nowMs,
      "schedule": {"kind": "cron", "expr": "$loginExpr", "tz": "Asia/Shanghai"},
      "sessionTarget": "main",
      "wakeMode": "now",
      "payload": {"kind": "systemEvent", "text": "执行每日平台登录状态检查"},
      "state": {"consecutiveErrors": 0}
    },
    {
      "id": "$id2",
      "agentId": "main",
      "sessionKey": "agent:main:main",
      "name": "video-cleanup-weekly",
      "enabled": true,
      "createdAtMs": $nowMs,
      "updatedAtMs": $nowMs,
      "schedule": {"expr": "$cleanupExpr", "kind": "cron", "tz": "Asia/Shanghai"},
      "sessionTarget": "main",
      "wakeMode": "now",
      "payload": {"kind": "systemEvent", "text": "执行视频清理技能"},
      "state": {"consecutiveErrors": 0}
    }
  ]
}
"@
    $cronFile = Join-Path $OpenClawDir "cron\jobs.json"
    [System.IO.File]::WriteAllText($cronFile, $cronJson, [System.Text.Encoding]::UTF8)
    OK ("登录检查: 每天 {0} | 视频清理: 每周 {1} 的 {2}" -f $loginCheckTime, $cleanupDay, $cleanupHour)

    # 登录检查配置
    $loginCfgSrc = Join-Path $DeployDir "config\login_check_config.json"
    if (Test-Path $loginCfgSrc) {
        $authDir = Join-Path $SkillsDir "auth"
        Ensure-Dir $authDir
        $content = (Get-Content $loginCfgSrc -Raw -Encoding UTF8).Replace("{{LOGIN_CHECK_TIME}}", $loginCheckTime)
        [System.IO.File]::WriteAllText((Join-Path $authDir "login_check_config.json"), $content, [System.Text.Encoding]::UTF8)
        OK "登录检查配置已保存"
    }
}

# ── 步骤 14: 配置 Token 和微信推送 ───────────────────────────
function Step14-ConfigureToken {
    Step "配置 Token 和微信推送"

    Write-Host ""
    Info "视频生成 API Token"
    $videoToken = Read-Host "  请输入视频生成 API Token (留空跳过)"
    if (-not [string]::IsNullOrEmpty($videoToken)) {
        $tokenDir = Join-Path $WorkspaceDir "openclaw_upload\flash_longxia"
        Ensure-Dir $tokenDir
        $videoToken | Set-Content (Join-Path $tokenDir "token.txt") -Encoding UTF8 -NoNewline
        OK "Token 已保存"
    } else {
        Warn "跳过 Token 配置"
    }

    Write-Host ""
    Info "微信推送目标 (格式: xxx@im.wechat)"
    $script:WechatTarget = Read-Host "  请输入微信 Target ID (留空跳过)"
    if (-not [string]::IsNullOrEmpty($WechatTarget)) {
        $configYamlPath = Join-Path $WorkspaceDir "openclaw_upload\flash_longxia\config.yaml"
        if (Test-Path $configYamlPath) {
            $content = Get-Content $configYamlPath -Raw -Encoding UTF8
            $content = $content.Replace('wechat_target: ""', ('wechat_target: "{0}"' -f $WechatTarget))
            [System.IO.File]::WriteAllText($configYamlPath, $content, [System.Text.Encoding]::UTF8)
        }
        OK ("微信 Target: {0} (已写入 config.yaml)" -f $WechatTarget)
    } else {
        Info "跳过，绑定微信后手动填写 config.yaml"
    }
}

# ── 部署验证 ─────────────────────────────────────────────────
function Verify-Deployment {
    Write-Host ""
    Write-Host "  ================================================" -ForegroundColor Blue
    Write-Host "  [验证] 部署结果" -ForegroundColor White
    Write-Host "  ================================================" -ForegroundColor Blue

    $checkFiles = @(
        @((Join-Path $OpenClawDir "openclaw.json"), "核心配置"),
        @((Join-Path $WorkspaceDir "MEMORY.md"), "红线规则"),
        @((Join-Path $WorkspaceDir "SOUL.md"), "AI灵魂"),
        @((Join-Path $WorkspaceDir "USER.md"), "用户偏好"),
        @((Join-Path $WorkspaceDir "IDENTITY.md"), "AI身份"),
        @((Join-Path $OpenClawDir "cron\jobs.json"), "定时任务")
    )

    foreach ($item in $checkFiles) {
        if (Test-Path $item[0]) { OK ("{0}: OK" -f $item[1]) }
        else { Fail ("{0}: 缺失" -f $item[1]) }
    }

    $checkDirs = @(
        @((Join-Path $WorkspaceDir "xiaolong-upload"), "xiaolong-upload"),
        @((Join-Path $WorkspaceDir "openclaw_upload"), "openclaw_upload")
    )
    foreach ($item in $checkDirs) {
        if (Test-Path $item[0]) { OK ("{0}: OK" -f $item[1]) }
        else { Fail ("{0}: 缺失" -f $item[1]) }
    }

    Write-Host ""
    Write-Host ("  用户: {0} | AI: {1} {2}" -f $UserDisplayName, $AiName, $AiEmoji) -ForegroundColor White
    Write-Host ("  行业: {0} | 风格: {1}" -f $UserIndustry, $UserVideoStyle) -ForegroundColor White
    Write-Host ("  OpenClaw: {0}" -f $OpenClawVersion) -ForegroundColor Cyan
    $pyDisplay = ($PythonCmd + " " + ($PythonArgs -join " ")).Trim()
    Write-Host ("  Python: {0}" -f $pyDisplay) -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  后续操作:" -ForegroundColor White
    Write-Host "    1. 启动 OpenClaw:  openclaw"
    Write-Host "    2. 绑定微信:       openclaw channel connect openclaw-weixin"
    Write-Host "    3. 扫码微信授权"
    Write-Host ("    4. 告诉 {0}: 帮我安装 xiaolong-upload 和 openclaw_upload" -f $AiName)
    Write-Host ""
}

# ── 主函数 ────────────────────────────────────────────────────
function Main {
    Print-Banner

    Write-Host "  部署模式:" -ForegroundColor White
    Write-Host "  1) 全新部署 - 从零安装所有组件"
    Write-Host "  2) 迁移部署 - 仅复制配置（OpenClaw 已安装）"
    Write-Host ""
    $mode = Read-Host "  请选择 (1/2, 默认 1)"
    if ([string]::IsNullOrEmpty($mode)) { $mode = "1" }

    switch ($mode) {
        "1" {
            Step1-SystemCheck; Step2-Python; Step3-InstallOpenClaw
            Step4-WechatPlugin; Step5-FeishuPlugin; Step6-Personalize
            Step7-ConfigureLLM; Step8-CloneXiaolongUpload
            Step9-CloneOpenclawUpload; Step10-WorkspaceConfig
            Step11-InstallSkills; Step12-ConfigureMemory
            Step13-CreateCron; Step14-ConfigureToken
            Verify-Deployment
        }
        "2" {
            Step1-SystemCheck; Step2-Python
            $script:StepCount = 2
            Step5-FeishuPlugin; Step6-Personalize; Step7-ConfigureLLM
            Step8-CloneXiaolongUpload; Step9-CloneOpenclawUpload
            Step10-WorkspaceConfig; Step11-InstallSkills
            Step12-ConfigureMemory; Step13-CreateCron
            Step14-ConfigureToken; Verify-Deployment
        }
        default {
            Fail "无效选择"
            exit 1
        }
    }
}

Main
