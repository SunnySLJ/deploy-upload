#!/bin/bash
# OpenClaw 配置包快速导出脚本
# 用于将当前配置打包，方便复制到其他 OpenClaw 实例

set -e

echo "🦐 虾王 OpenClaw 配置包导出脚本"
echo "================================"

# 配置
EXPORT_DIR="$HOME/Desktop/openclaw-export-$(date +%Y%m%d-%H%M%S)"
WORKSPACE_DIR="$HOME/.openclaw/workspace"
SKILLS_DIR="$HOME/.openclaw/skills"

# 创建导出目录
echo ""
echo "📦 正在创建导出目录..."
mkdir -p "$EXPORT_DIR"
mkdir -p "$EXPORT_DIR/workspace"
mkdir -p "$EXPORT_DIR/skills"
mkdir -p "$EXPORT_DIR/docs"

# 复制工作区文件
echo ""
echo "📁 正在复制工作区配置..."

# 核心配置文件（模板化）
cp "$WORKSPACE_DIR/INIT-TEMPLATE.md" "$EXPORT_DIR/docs/" 2>/dev/null || echo "  - INIT-TEMPLATE.md: 跳过（不存在）"
cp "$WORKSPACE_DIR/DEPLOYMENT.md" "$EXPORT_DIR/docs/" 2>/dev/null || echo "  - DEPLOYMENT.md: 跳过（不存在）"
cp "$WORKSPACE_DIR/SOP.md" "$EXPORT_DIR/docs/" 2>/dev/null || echo "  - SOP.md: 跳过（不存在）"
cp "$WORKSPACE_DIR/CHANGELOG.md" "$EXPORT_DIR/docs/" 2>/dev/null || echo "  - CHANGELOG.md: 跳过（不存在）"
cp "$WORKSPACE_DIR/PACKAGE-README.md" "$EXPORT_DIR/docs/" 2>/dev/null || echo "  - PACKAGE-README.md: 跳过（不存在）"
cp "$WORKSPACE_DIR/CHANGELOG.md" "$EXPORT_DIR/docs/" 2>/dev/null || echo "  - CHANGELOG.md: 跳过（不存在）"

# 模板文件
cp "$WORKSPACE_DIR/MEMORY.template.md" "$EXPORT_DIR/workspace/" 2>/dev/null || echo "  - MEMORY.template.md: 跳过"
cp "$WORKSPACE_DIR/USER.template.md" "$EXPORT_DIR/workspace/" 2>/dev/null || echo "  - USER.template.md: 跳过"
cp "$WORKSPACE_DIR/IDENTITY.template.md" "$EXPORT_DIR/workspace/" 2>/dev/null || echo "  - IDENTITY.template.md: 跳过"
cp "$WORKSPACE_DIR/HEARTBEAT.template.md" "$EXPORT_DIR/workspace/" 2>/dev/null || echo "  - HEARTBEAT.template.md: 跳过"

# 复制技能目录
echo ""
echo "🔧 正在复制技能..."

# flash-longxia
if [ -d "$SKILLS_DIR/flash-longxia" ]; then
    echo "  - flash-longxia: 复制中..."
    cp -r "$SKILLS_DIR/flash-longxia" "$EXPORT_DIR/skills/"
else
    echo "  - flash-longxia: 未找到"
fi

# auth
if [ -d "$SKILLS_DIR/auth" ]; then
    echo "  - auth: 复制中..."
    cp -r "$SKILLS_DIR/auth" "$EXPORT_DIR/skills/"
else
    echo "  - auth: 未找到"
fi

# longxia-upload
if [ -d "$SKILLS_DIR/longxia-upload" ]; then
    echo "  - longxia-upload: 复制中..."
    cp -r "$SKILLS_DIR/longxia-upload" "$EXPORT_DIR/skills/"
else
    echo "  - longxia-upload: 未找到"
fi

# 复制上传项目
echo ""
echo "📤 正在复制上传项目..."
if [ -d "$WORKSPACE_DIR/xiaolong-upload" ]; then
    # 排除不必要的文件
    rsync -av --exclude='.git' \
          --exclude='node_modules' \
          --exclude='.venv' \
          --exclude='__pycache__' \
          --exclude='*.pyc' \
          --exclude='logs/*' \
          --exclude='.DS_Store' \
          --exclude='back/*' \
          --exclude='cookies/*' \
          --exclude='inbound_images/*' \
          --exclude='inbound_videos/*' \
          --exclude='images/*' \
          --exclude='published/*' \
          --exclude='*.mp4' \
          --exclude='*.mov' \
          "$WORKSPACE_DIR/xiaolong-upload/" "$EXPORT_DIR/workspace/xiaolong-upload/"
    echo "  - xiaolong-upload: 复制完成"
else
    echo "  - xiaolong-upload: 未找到"
fi

# 创建 README
echo ""
echo "📝 正在创建 README..."
cat > "$EXPORT_DIR/README.md" << 'EOF'
# OpenClaw 配置包

> 🦐 虾王智能视频发布系统 - 配置导出包

## 📦 包内容

```
openclaw-export/
├── README.md              # 本文件
├── docs/                  # 文档
│   ├── INIT-TEMPLATE.md   # 初始化配置指南
│   ├── DEPLOYMENT.md      # 部署指南
│   └── SOP.md             # 标准操作流程
├── workspace/             # 工作区配置
│   ├── MEMORY.template.md      # 红线规则模板
│   ├── USER.template.md        # 用户偏好模板
│   ├── IDENTITY.template.md    # AI 身份模板
│   ├── HEARTBEAT.template.md   # 心跳任务模板
│   └── xiaolong-upload/        # 上传项目
└── skills/                # 技能
    ├── flash-longxia/     # 图生视频
    ├── auth/              # 登录管理
    └── longxia-upload/    # 上传发布
```

## 🚀 使用方法

### 1. 在新 OpenClaw 实例中安装

```bash
# 复制技能
cp -r skills/* ~/.openclaw/skills/

# 复制工作区配置
cp -r workspace/xiaolong-upload ~/.openclaw/workspace/
cp workspace/*.template.md ~/.openclaw/workspace/

# 复制文档（可选）
cp docs/* ~/.openclaw/workspace/
```

### 2. 配置模板文件

按照以下顺序配置：

1. `IDENTITY.template.md` → 配置 AI 身份
2. `USER.template.md` → 配置用户偏好
3. `MEMORY.template.md` → 配置红线规则（保留核心规则，填充 API 配置）
4. `HEARTBEAT.template.md` → 配置心跳任务

### 3. 完成部署

参考 `docs/DEPLOYMENT.md` 完成剩余步骤：
- 安装 OpenClaw
- 安装微信插件
- 绑定微信账号
- 配置 Cron 任务

## ⚠️ 注意事项

1. **不要复制敏感信息**：此导出包不包含 `openclaw.json` 等含 API 密钥的文件
2. **必须配置的内容**：
   - API Token 和接口地址
   - 微信绑定
   - 用户偏好配置
3. **Python 版本要求**：必须使用 Python 3.12

## 📞 需要帮助？

参考 `docs/DEPLOYMENT.md` 获取详细部署指南。

---

_导出时间：自动生成_
EOF

# 计算大小
echo ""
echo "📊 计算导出包大小..."
TOTAL_SIZE=$(du -sh "$EXPORT_DIR" | cut -f1)
FILE_COUNT=$(find "$EXPORT_DIR" -type f | wc -l | tr -d ' ')

echo ""
echo "================================"
echo "✅ 导出完成！"
echo ""
echo "📦 导出目录：$EXPORT_DIR"
echo "📊 文件大小：$TOTAL_SIZE"
echo "📄 文件数量：$FILE_COUNT"
echo ""
echo "下一步："
echo "  1. 将导出目录复制到目标机器"
echo "  2. 在新机器上运行导入脚本（或手动复制）"
echo "  3. 按照 README.md 配置"
echo ""
echo "================================"

# 可选：创建压缩包
echo ""
read -p "是否创建 ZIP 压缩包？(y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "📦 正在创建 ZIP 压缩包..."
    cd "$HOME/Desktop"
    zip -r "openclaw-export-$(date +%Y%m%d-%H%M%S).zip" "$(basename "$EXPORT_DIR")"
    echo "✅ ZIP 压缩包创建完成！"
fi
