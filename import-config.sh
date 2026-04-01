#!/bin/bash
# OpenClaw 配置包导入脚本
# 用于在新 OpenClaw 实例中导入配置包

set -e

echo "🦐 虾王 OpenClaw 配置包导入脚本"
echo "================================"
echo ""

# 检查参数
if [ -z "$1" ]; then
    echo "用法：$0 <配置包路径>"
    echo ""
    echo "示例："
    echo "  $0 ~/Desktop/openclaw-export-20260331-120000"
    echo "  $0 /path/to/openclaw-export"
    echo ""
    exit 1
fi

EXPORT_DIR="$1"

# 验证目录存在
if [ ! -d "$EXPORT_DIR" ]; then
    echo "❌ 错误：目录不存在：$EXPORT_DIR"
    exit 1
fi

# 检查必要文件
echo "🔍 检查配置包完整性..."

MISSING_FILES=()

if [ ! -d "$EXPORT_DIR/skills/flash-longxia" ]; then
    MISSING_FILES+=("skills/flash-longxia")
fi
if [ ! -d "$EXPORT_DIR/skills/auth" ]; then
    MISSING_FILES+=("skills/auth")
fi
if [ ! -d "$EXPORT_DIR/skills/longxia-upload" ]; then
    MISSING_FILES+=("skills/longxia-upload")
fi
if [ ! -d "$EXPORT_DIR/workspace/xiaolong-upload" ]; then
    MISSING_FILES+=("workspace/xiaolong-upload")
fi

if [ ${#MISSING_FILES[@]} -gt 0 ]; then
    echo "⚠️  警告：以下必要文件/目录缺失："
    for file in "${MISSING_FILES[@]}"; do
        echo "   - $file"
    done
    echo ""
    read -p "是否继续导入？(y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ 导入已取消"
        exit 1
    fi
fi

# 创建必要的目录
echo ""
echo "📁 创建必要的目录..."

mkdir -p "$HOME/.openclaw/skills"
mkdir -p "$HOME/.openclaw/workspace"

# 复制技能
echo ""
echo "🔧 正在复制技能..."

if [ -d "$EXPORT_DIR/skills" ]; then
    cp -r "$EXPORT_DIR/skills"/* "$HOME/.openclaw/skills/"
    echo "  ✅ 技能复制完成"
else
    echo "  ⚠️  技能目录不存在，跳过"
fi

# 复制工作区
echo ""
echo "📁 正在复制工作区..."

if [ -d "$EXPORT_DIR/workspace/xiaolong-upload" ]; then
    cp -r "$EXPORT_DIR/workspace/xiaolong-upload" "$HOME/.openclaw/workspace/"
    echo "  ✅ xiaolong-upload 复制完成"
fi

# 复制模板文件
echo ""
echo "📄 正在复制模板文件..."

TEMPLATE_FILES=("MEMORY.template.md" "USER.template.md" "IDENTITY.template.md" "HEARTBEAT.template.md")

for file in "${TEMPLATE_FILES[@]}"; do
    if [ -f "$EXPORT_DIR/workspace/$file" ]; then
        cp "$EXPORT_DIR/workspace/$file" "$HOME/.openclaw/workspace/$file"
        echo "  ✅ $file"
    else
        echo "  ⚠️  $file: 不存在"
    fi
done

# 复制文档
echo ""
echo "📚 正在复制文档..."

if [ -d "$EXPORT_DIR/docs" ]; then
    cp "$EXPORT_DIR/docs"/* "$HOME/.openclaw/workspace/" 2>/dev/null || true
    echo "  ✅ 文档复制完成"
fi

# 复制 README（如果有）
if [ -f "$EXPORT_DIR/README.md" ]; then
    cp "$EXPORT_DIR/README.md" "$HOME/Desktop/"
    echo "  ✅ README.md 已复制到桌面"
fi

# 生成配置清单
echo ""
echo "📋 生成配置清单..."

CATALOG_FILE="$HOME/.openclaw/workspace/IMPORT-CATALOG-$(date +%Y%m%d-%H%M%S).md"

cat > "$CATALOG_FILE" << EOF
# OpenClaw 配置导入清单

导入时间：$(date +"%Y-%m-%d %H:%M:%S")
导入源：$EXPORT_DIR

## 已导入的文件

### 技能
$(ls -1 "$HOME/.openclaw/skills/" 2>/dev/null | sed 's/^/- /')

### 工作区
$(ls -1 "$HOME/.openclaw/workspace/" 2>/dev/null | sed 's/^/- /')

## 待配置项目

请按照以下顺序配置：

1. [ ] **IDENTITY.md** - 配置 AI 身份（名称、人设、风格）
2. [ ] **USER.md** - 配置用户偏好（称呼、风格、平台）
3. [ ] **MEMORY.md** - 配置红线规则（API 接口、Token 路径）
4. [ ] **HEARTBEAT.md** - 配置心跳任务（检查时间）
5. [ ] **openclaw.json** - 配置 API 密钥
6. [ ] **微信绑定** - 执行 \`openclaw channels login --channel openclaw-weixin\`
7. [ ] **Cron 任务** - 配置定时任务

## 参考文档

- [DEPLOYMENT.md](./DEPLOYMENT.md) - 完整部署指南
- [INIT-TEMPLATE.md](./INIT-TEMPLATE.md) - 初始化配置说明
- [SOP.md](./SOP.md) - 标准操作流程

---

祝部署顺利！🦐
EOF

echo "  ✅ 配置清单已生成：$CATALOG_FILE"

# 显示后续步骤
echo ""
echo "================================"
echo "✅ 导入完成！"
echo ""
echo "📋 后续步骤："
echo ""
echo "  1. 配置 AI 身份:"
echo "     cp ~/.openclaw/workspace/IDENTITY.template.md ~/.openclaw/workspace/IDENTITY.md"
echo "     # 然后编辑 IDENTITY.md"
echo ""
echo "  2. 配置用户偏好:"
echo "     cp ~/.openclaw/workspace/USER.template.md ~/.openclaw/workspace/USER.md"
echo "     # 然后编辑 USER.md"
echo ""
echo "  3. 配置红线规则:"
echo "     cp ~/.openclaw/workspace/MEMORY.template.md ~/.openclaw/workspace/MEMORY.md"
echo "     # 然后编辑 MEMORY.md，填充 API 配置"
echo ""
echo "  4. 配置心跳任务:"
echo "     cp ~/.openclaw/workspace/HEARTBEAT.template.md ~/.openclaw/workspace/HEARTBEAT.md"
echo "     # 然后编辑 HEARTBEAT.md"
echo ""
echo "  5. 配置 openclaw.json:"
echo "     openclaw config set env.ANTHROPIC_AUTH_TOKEN 'sk-your-token'"
echo ""
echo "  6. 绑定微信:"
echo "     openclaw channels login --channel openclaw-weixin"
echo ""
echo "  7. 查看配置清单:"
echo "     cat $CATALOG_FILE"
echo ""
echo "================================"
echo ""
echo "🦐 祝部署顺利！"
