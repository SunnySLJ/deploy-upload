# ============================================================
# 🦐 OpenClaw 一键部署脚本 (Windows PowerShell)
# 版本: 1.0.0
# 用法: 以管理员身份运行 PowerShell，执行:
#       .\deploy-openclaw.ps1
# ============================================================

$ErrorActionPreference = "Stop"

# ── 全局变量 ─────────────────────────────────────────────────
$OpenClawDir = "$env:USERPROFILE\.openclaw"
$WorkspaceDir = "$OpenClawDir\workspace"
$SkillsDir = "$OpenClawDir\skills"
$DeployDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PythonCmd = ""
$StepCount = 0
$TotalSteps = 13
$ApiKey = ""
$WechatTarget = ""

# ── 工具函数 ─────────────────────────────────────────────────
function Print-Banner {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  🦐 OpenClaw 一键部署脚本 (Windows)               ║" -ForegroundColor Cyan
    Write-Host "║  虾王智能视频发布系统 — 自动化部署                ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Step($msg) {
    $script:StepCount++
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host "[步骤 $StepCount/$TotalSteps] $msg" -ForegroundColor White
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
}

function OK($msg)   { Write-Host "  ✅ $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "  ⚠️  $msg" -ForegroundColor Yellow }
function Fail($msg) { Write-Host "  ❌ $msg" -ForegroundColor Red }
function Info($msg) { Write-Host "  ℹ️  $msg" -ForegroundColor Cyan }

function Ask-YesNo($prompt, $default = "y") {
    if ($default -eq "y") {
        $answer = Read-Host "  $prompt [Y/n]"
        if ([string]::IsNullOrEmpty($answer)) { $answer = "y" }
    } else {
        $answer = Read-Host "  $prompt [y/N]"
        if ([string]::IsNullOrEmpty($answer)) { $answer = "n" }
    }
    return $answer -match "^[Yy]"
}

function Test-CommandExists($cmd) {
    return [bool](Get-Command $cmd -ErrorAction SilentlyContinue)
}

# ── 步骤 1: 检查系统环境 ──────────────────────────────────────
function Step1-SystemCheck {
    Step "检查系统环境"

    # 检查 Windows
    $osInfo = Get-CimInstance Win32_OperatingSystem
    OK "操作系统: Windows $($osInfo.Version)"

    # 检查 Node.js
    if (Test-CommandExists "node") {
        $nodeVer = & node -v 2>$null
        OK "Node.js: $nodeVer"
    } else {
        Fail "未安装 Node.js！请先安装 Node.js (v18+)"
        Info "下载: https://nodejs.org/"
        exit 1
    }

    # 检查 npm
    if (Test-CommandExists "npm") {
        $npmVer = & npm -v 2>$null
        OK "npm: $npmVer"
    } else {
        Fail "未安装 npm！"
        exit 1
    }

    # 检查 git
    if (Test-CommandExists "git") {
        $gitVer = & git --version 2>$null
        OK "Git: $gitVer"
    } else {
        Fail "未安装 Git！请先安装 Git"
        Info "下载: https://git-scm.com/download/win"
        exit 1
    }
}

# ── 步骤 2: 检查/安装 Python 3.12 ─────────────────────────────
function Step2-Python {
    Step "检查 / 安装 Python 3.12"

    # 尝试 py launcher
    if (Test-CommandExists "py") {
        try {
            $ver = & py -3.12 --version 2>$null
            if ($ver -match "3\.12") {
                $script:PythonCmd = "py -3.12"
                OK "Python 3.12: $ver (via py launcher)"
                return
            }
        } catch {}
    }

    # 尝试 python3.12
    if (Test-CommandExists "python3.12") {
        $ver = & python3.12 --version 2>$null
        if ($ver -match "3\.12") {
            $script:PythonCmd = "python3.12"
            OK "Python 3.12: $ver"
            return
        }
    }

    # 尝试 python
    if (Test-CommandExists "python") {
        $ver = & python --version 2>$null
        if ($ver -match "3\.12") {
            $script:PythonCmd = "python"
            OK "Python 3.12: $ver"
            return
        }
    }

    Fail "未找到 Python 3.12"
    Info "请从 https://www.python.org/downloads/ 下载安装 Python 3.12"
    Info "安装时请勾选 'Add Python to PATH' 和 'py launcher'"
    exit 1
}

# ── 步骤 3: 安装 OpenClaw ──────────────────────────────────────
function Step3-InstallOpenClaw {
    Step "安装 OpenClaw"

    if (Test-CommandExists "openclaw") {
        $ocVer = & openclaw --version 2>$null
        OK "OpenClaw 已安装: $ocVer"
        if (Ask-YesNo "是否重新安装/更新 OpenClaw？" "n") {
            Info "正在更新 OpenClaw..."
            & npm install -g @anthropics/openclaw@latest
            OK "OpenClaw 更新完成"
        }
    } else {
        Info "正在安装 OpenClaw..."
        & npm install -g @anthropics/openclaw@latest
        OK "OpenClaw 安装完成"
    }

    # 确保目录结构
    $dirs = @(
        $OpenClawDir,
        $WorkspaceDir,
        $SkillsDir,
        "$WorkspaceDir\inbound_images",
        "$WorkspaceDir\inbound_videos",
        "$WorkspaceDir\logs\auth_qr",
        "$WorkspaceDir\memory"
    )
    foreach ($d in $dirs) {
        New-Item -ItemType Directory -Path $d -Force | Out-Null
    }
    OK "目录结构已创建"
}

# ── 步骤 4: 安装微信插件 ──────────────────────────────────────
function Step4-WechatPlugin {
    Step "安装微信插件"

    Info "正在安装 OpenClaw 微信插件..."
    & npx -y "@tencent-weixin/openclaw-weixin-cli@latest" install

    OK "微信插件安装完成"
    Warn "⚡ 请在 OpenClaw 启动后通过微信扫码完成授权绑定"
    Warn "   绑定命令: openclaw channel connect openclaw-weixin"
}

# ── 步骤 5: 安装飞书插件（可选） ──────────────────────────────
function Step5-FeishuPlugin {
    Step "安装飞书插件（可选）"

    if (Ask-YesNo "是否安装飞书插件？" "n") {
        Info "请参考: OpenClaw 飞书官方插件使用指南（公开版）"

        $feishuAppId = Read-Host "  请输入飞书 App ID (留空跳过)"
        if (-not [string]::IsNullOrEmpty($feishuAppId)) {
            $feishuAppSecret = Read-Host "  请输入飞书 App Secret"

            $credDir = "$OpenClawDir\credentials"
            New-Item -ItemType Directory -Path $credDir -Force | Out-Null
            @{
                appId = $feishuAppId
                appSecret = $feishuAppSecret
            } | ConvertTo-Json | Set-Content "$credDir\feishu-main-allowFrom.json" -Encoding UTF8
            OK "飞书凭证已保存"
        } else {
            Info "跳过飞书插件安装"
        }
    } else {
        Info "跳过飞书插件"
    }
}

# ── 步骤 6: 配置 LLM 大模型 ───────────────────────────────────
function Step6-ConfigureLLM {
    Step "配置 LLM 大模型"

    $configPath = "$OpenClawDir\openclaw.json"

    if (Test-Path $configPath) {
        Warn "检测到已有 openclaw.json 配置"
        if (-not (Ask-YesNo "是否覆盖现有配置？" "n")) {
            Info "保留现有配置"
            return
        }
    }

    Write-Host ""
    Info "请输入百炼 (DashScope) API Key:"
    $script:ApiKey = Read-Host "  API Key (sk-sp-xxx)"

    if ([string]::IsNullOrEmpty($ApiKey)) {
        Warn "未输入 API Key，使用占位符"
        $script:ApiKey = "{{YOUR_API_KEY}}"
    }

    $templatePath = "$DeployDir\config\openclaw.json.template"
    if (Test-Path $templatePath) {
        $content = Get-Content $templatePath -Raw
        $content = $content -replace '\{\{API_KEY\}\}', $ApiKey
        $content | Set-Content $configPath -Encoding UTF8
        OK "openclaw.json 已生成"
    } else {
        Warn "模板文件不存在，请手动配置 openclaw.json"
    }
}

# ── 步骤 7: 克隆 xiaolong-upload ──────────────────────────────
function Step7-CloneXiaolongUpload {
    Step "安装 xiaolong-upload（图片生成视频 Skill）"

    $target = "$WorkspaceDir\xiaolong-upload"

    if (Test-Path $target) {
        OK "xiaolong-upload 已存在"
        if (Ask-YesNo "是否拉取最新代码？") {
            Info "正在更新..."
            Push-Location $target
            & git pull origin main 2>$null
            if ($LASTEXITCODE -ne 0) { & git pull origin master 2>$null }
            Pop-Location
            OK "已更新到最新代码"
        }
    } else {
        Info "正在克隆 xiaolong-upload..."
        & git clone "https://github.com/SunnySLJ/xiaolong-upload.git" $target
        OK "克隆完成"
    }

    # 安装 Python 依赖
    if (Test-Path "$target\requirements.txt") {
        Info "正在安装 Python 依赖..."
        Push-Location $target
        & $PythonCmd -m venv .venv 2>$null
        if (Test-Path ".venv\Scripts\pip.exe") {
            & .venv\Scripts\pip.exe install -r requirements.txt -q
        }
        Pop-Location
        OK "Python 依赖已安装"
    }
}

# ── 步骤 8: 克隆 openclaw_upload ──────────────────────────────
function Step8-CloneOpenclawUpload {
    Step "安装 openclaw_upload（视频号发布 Skill）"

    $target = "$WorkspaceDir\openclaw_upload"

    if (Test-Path $target) {
        OK "openclaw_upload 已存在"
        if (Ask-YesNo "是否拉取最新代码？") {
            Info "正在更新..."
            Push-Location $target
            & git pull origin main 2>$null
            if ($LASTEXITCODE -ne 0) { & git pull origin master 2>$null }
            Pop-Location
            OK "已更新到最新代码"
        }
    } else {
        Info "正在克隆 openclaw_upload..."
        & git clone "https://github.com/SunnySLJ/openclaw_upload.git" $target
        OK "克隆完成"
    }

    # 安装 Python 依赖
    if (Test-Path "$target\requirements.txt") {
        Info "正在安装 Python 依赖..."
        Push-Location $target
        & $PythonCmd -m venv .venv 2>$null
        if (Test-Path ".venv\Scripts\pip.exe") {
            & .venv\Scripts\pip.exe install -r requirements.txt -q
        }
        Pop-Location
        OK "Python 依赖已安装"
    }

    # 创建必要目录
    $subdirs = @("cookies", "logs", "published", "flash_longxia\output")
    foreach ($d in $subdirs) {
        New-Item -ItemType Directory -Path "$target\$d" -Force | Out-Null
    }
    OK "目录结构已创建"
}

# ── 步骤 9: 复制 Workspace 配置文件 ───────────────────────────
function Step9-WorkspaceConfig {
    Step "初始化 Workspace 配置文件"

    $wsSrc = "$DeployDir\workspace"
    $files = @("AGENTS.md", "IDENTITY.md", "SOUL.md", "USER.md", "MEMORY.md", "HEARTBEAT.md", "TOOLS.md")

    foreach ($f in $files) {
        $srcFile = "$wsSrc\$f"
        $dstFile = "$WorkspaceDir\$f"
        if (Test-Path $srcFile) {
            if (Test-Path $dstFile) {
                Warn "$f 已存在，跳过（避免覆盖）"
            } else {
                $content = Get-Content $srcFile -Raw
                $content = $content -replace '\{\{HOME\}\}', $env:USERPROFILE
                $content = $content -replace '\{\{PYTHON_CMD\}\}', $PythonCmd
                $content | Set-Content $dstFile -Encoding UTF8
                OK "$f 已复制"
            }
        } else {
            Warn "$f 模板不存在，跳过"
        }
    }
}

# ── 步骤 10: 安装 Skills ──────────────────────────────────────
function Step10-InstallSkills {
    Step "安装 Skills（技能）"

    $skillSrc = "$DeployDir\skills"
    $skillNames = @("flash-longxia", "auth", "longxia-upload", "longxia-bootstrap")

    foreach ($skill in $skillNames) {
        $src = "$skillSrc\$skill"
        $dst = "$SkillsDir\$skill"
        if (Test-Path $src) {
            if (Test-Path $dst) {
                Warn "Skill [$skill] 已存在，跳过"
            } else {
                Copy-Item -Path $src -Destination $dst -Recurse
                OK "Skill [$skill] 已安装"
            }
        } else {
            Warn "Skill [$skill] 模板不存在，跳过"
        }
    }

    # 更新 bootstrap 配置
    $bootstrapConfig = "$SkillsDir\longxia-bootstrap\project_config.json"
    if (Test-Path (Split-Path $bootstrapConfig)) {
        @{
            project_root = "$WorkspaceDir\xiaolong-upload"
            python_cmd = $PythonCmd
        } | ConvertTo-Json | Set-Content $bootstrapConfig -Encoding UTF8
        OK "longxia-bootstrap 配置已更新"
    }
}

# ── 步骤 11: 配置 Memory 插件 ─────────────────────────────────
function Step11-ConfigureMemory {
    Step "配置 Memory 插件"

    $memDirs = @(
        "$OpenClawDir\memory",
        "$WorkspaceDir\memory",
        "$WorkspaceDir\plugins",
        "$OpenClawDir\memory-md"
    )
    foreach ($d in $memDirs) {
        New-Item -ItemType Directory -Path $d -Force | Out-Null
    }

    Info "Memory 插件 (memory-lancedb-pro) 已在 openclaw.json 中配置"
    Info "首次启动 OpenClaw 时将自动初始化向量数据库"
    OK "Memory 目录结构已创建"
}

# ── 步骤 12: 创建定时任务 ─────────────────────────────────────
function Step12-CreateCron {
    Step "创建定时任务"

    New-Item -ItemType Directory -Path "$OpenClawDir\cron" -Force | Out-Null

    Write-Host ""
    Info "定时任务 1: 每日登录状态检查"
    $loginCheckTime = Read-Host "  每天几点检查登录状态？(默认 10:10，格式 HH:MM)"
    if ([string]::IsNullOrEmpty($loginCheckTime)) { $loginCheckTime = "10:10" }

    Write-Host ""
    Info "定时任务 2: 每周视频文件清理"
    Write-Host "  0=周日 1=周一 2=周二 3=周三 4=周四 5=周五 6=周六"
    $cleanupDay = Read-Host "  每周几清理视频文件？(默认 2=周二)"
    if ([string]::IsNullOrEmpty($cleanupDay)) { $cleanupDay = "2" }

    $cleanupHour = Read-Host "  几点执行清理？(默认 01:00，格式 HH:MM)"
    if ([string]::IsNullOrEmpty($cleanupHour)) { $cleanupHour = "01:00" }

    # 解析时间
    $loginParts = $loginCheckTime -split ":"
    $loginH = $loginParts[0]; $loginM = $loginParts[1]

    $cleanupParts = $cleanupHour -split ":"
    $cleanupH = $cleanupParts[0]; $cleanupM = $cleanupParts[1]

    $nowMs = [long]([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())
    $id1 = [guid]::NewGuid().ToString()
    $id2 = [guid]::NewGuid().ToString()

    $cronJson = @{
        version = 1
        jobs = @(
            @{
                id = $id1
                agentId = "main"
                sessionKey = "agent:main:main"
                name = "login-status-daily-check"
                enabled = $true
                createdAtMs = $nowMs
                updatedAtMs = $nowMs
                schedule = @{
                    kind = "cron"
                    expr = "$loginM $loginH * * *"
                    tz = "Asia/Shanghai"
                }
                sessionTarget = "main"
                wakeMode = "now"
                payload = @{
                    kind = "systemEvent"
                    text = "执行每日平台登录状态检查：cd ~/.openclaw/workspace/xiaolong-upload && $PythonCmd skills/auth/scripts/scheduled_login_check.py"
                }
                state = @{ consecutiveErrors = 0 }
            },
            @{
                id = $id2
                agentId = "main"
                sessionKey = "agent:main:main"
                name = "video-cleanup-weekly"
                enabled = $true
                createdAtMs = $nowMs
                updatedAtMs = $nowMs
                schedule = @{
                    expr = "$cleanupM $cleanupH * * $cleanupDay"
                    kind = "cron"
                    tz = "Asia/Shanghai"
                }
                sessionTarget = "main"
                wakeMode = "now"
                payload = @{
                    kind = "systemEvent"
                    text = "执行视频清理技能：cd ~/.openclaw/workspace/xiaolong-upload && $PythonCmd scripts/cleanup_uploaded_videos.py"
                }
                state = @{ consecutiveErrors = 0 }
            }
        )
    } | ConvertTo-Json -Depth 10

    $cronJson | Set-Content "$OpenClawDir\cron\jobs.json" -Encoding UTF8

    OK "登录检查: 每天 $loginCheckTime"
    OK "视频清理: 每周 $cleanupDay 的 $cleanupHour"

    # 复制登录检查配置
    $loginConfigSrc = "$DeployDir\config\login_check_config.json"
    if (Test-Path $loginConfigSrc) {
        $authDir = "$SkillsDir\auth"
        New-Item -ItemType Directory -Path $authDir -Force | Out-Null
        $content = Get-Content $loginConfigSrc -Raw
        $content = $content -replace '\{\{LOGIN_CHECK_TIME\}\}', $loginCheckTime
        $content | Set-Content "$authDir\login_check_config.json" -Encoding UTF8
        OK "登录检查配置已保存"
    }
}

# ── 步骤 13: 配置 Token 和微信推送 ────────────────────────────
function Step13-ConfigureToken {
    Step "配置 Token 和微信推送"

    Write-Host ""
    Info "视频生成 API Token（用于帧龙虾图生视频）"
    $videoToken = Read-Host "  请输入视频生成 API Token (留空跳过)"
    if (-not [string]::IsNullOrEmpty($videoToken)) {
        $tokenDir = "$WorkspaceDir\openclaw_upload\flash_longxia"
        New-Item -ItemType Directory -Path $tokenDir -Force | Out-Null
        $videoToken | Set-Content "$tokenDir\token.txt" -Encoding UTF8 -NoNewline
        OK "视频 Token 已保存到 flash_longxia\token.txt"
    } else {
        Warn "跳过 Token 配置，请后续手动配置"
    }

    Write-Host ""
    Info "微信推送目标（用于接收通知）"
    $script:WechatTarget = Read-Host "  请输入微信 Target ID (格式: xxx@im.wechat，留空跳过)"
    if (-not [string]::IsNullOrEmpty($WechatTarget)) {
        OK "微信 Target: $WechatTarget"
    } else {
        Warn "跳过微信推送配置"
        Info "启动 OpenClaw 后执行: openclaw channel connect openclaw-weixin"
    }
}

# ── 部署验证 ──────────────────────────────────────────────────
function Verify-Deployment {
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host "[验证] 部署结果检查" -ForegroundColor White
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue

    $allOk = $true

    $checkFiles = @{
        "$OpenClawDir\openclaw.json" = "核心配置"
        "$WorkspaceDir\MEMORY.md" = "红线规则"
        "$WorkspaceDir\SOUL.md" = "AI 灵魂"
        "$WorkspaceDir\USER.md" = "用户偏好"
        "$WorkspaceDir\TOOLS.md" = "工具配置"
        "$OpenClawDir\cron\jobs.json" = "定时任务"
    }

    foreach ($item in $checkFiles.GetEnumerator()) {
        if (Test-Path $item.Key) { OK "$($item.Value): ✓" }
        else { Fail "$($item.Value): 缺失"; $allOk = $false }
    }

    $checkDirs = @{
        "$WorkspaceDir\xiaolong-upload" = "xiaolong-upload 项目"
        "$WorkspaceDir\openclaw_upload" = "openclaw_upload 项目"
    }

    foreach ($item in $checkDirs.GetEnumerator()) {
        if (Test-Path $item.Key) { OK "$($item.Value): ✓" }
        else { Fail "$($item.Value): 缺失"; $allOk = $false }
    }

    $skills = @("flash-longxia", "auth", "longxia-upload", "longxia-bootstrap")
    foreach ($s in $skills) {
        if (Test-Path "$SkillsDir\$s") { OK "Skill [$s]: ✓" }
        else { Warn "Skill [$s]: 未安装" }
    }

    Write-Host ""
    if ($allOk) {
        Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "║  🎉 部署完成！所有检查通过                       ║" -ForegroundColor Green
        Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Green
    } else {
        Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Yellow
        Write-Host "║  ⚠️  部署完成，但有部分项目需要手动处理           ║" -ForegroundColor Yellow
        Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "📋 后续操作：" -ForegroundColor White
    Write-Host "  1. 启动 OpenClaw:  openclaw"
    Write-Host "  2. 绑定微信:       openclaw channel connect openclaw-weixin"
    Write-Host "  3. 扫码微信授权"
    Write-Host "  4. 告诉虾王: `"帮我安装 xiaolong-upload 和 openclaw_upload`""
    Write-Host "  5. 根据需要定制 USER.md 中的用户偏好"
    Write-Host ""
    Write-Host "  Python: $PythonCmd" -ForegroundColor Cyan
    Write-Host "  工作区: $WorkspaceDir" -ForegroundColor Cyan
    Write-Host ""
}

# ── 主函数 ────────────────────────────────────────────────────
function Main {
    Print-Banner

    Write-Host "部署模式：" -ForegroundColor White
    Write-Host "  1) 全新部署 — 从零安装所有组件"
    Write-Host "  2) 迁移部署 — 仅复制配置文件和技能（OpenClaw 已安装）"
    Write-Host ""
    $mode = Read-Host "请选择 (1/2, 默认 1)"
    if ([string]::IsNullOrEmpty($mode)) { $mode = "1" }

    switch ($mode) {
        "1" {
            Step1-SystemCheck
            Step2-Python
            Step3-InstallOpenClaw
            Step4-WechatPlugin
            Step5-FeishuPlugin
            Step6-ConfigureLLM
            Step7-CloneXiaolongUpload
            Step8-CloneOpenclawUpload
            Step9-WorkspaceConfig
            Step10-InstallSkills
            Step11-ConfigureMemory
            Step12-CreateCron
            Step13-ConfigureToken
            Verify-Deployment
        }
        "2" {
            Step1-SystemCheck
            Step2-Python
            $script:StepCount = 2
            Step6-ConfigureLLM
            Step7-CloneXiaolongUpload
            Step8-CloneOpenclawUpload
            Step9-WorkspaceConfig
            Step10-InstallSkills
            Step11-ConfigureMemory
            Step12-CreateCron
            Step13-ConfigureToken
            Verify-Deployment
        }
        default {
            Fail "无效选择"
            exit 1
        }
    }
}

Main
