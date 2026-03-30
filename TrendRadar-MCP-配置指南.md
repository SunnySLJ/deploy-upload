# TrendRadar MCP 配置指南

## ⚠️ 前提条件

**需要安装 Cherry Studio**

下载地址：https://cherry-ai.com/ 或 https://github.com/kangfenmao/cherry-studio

安装后继续以下步骤。

---

## 📋 手动配置步骤

### 步骤 1: 打开 Cherry Studio 设置

1. 打开 Cherry Studio 应用程序
2. 点击左下角 **设置** 图标 (⚙️)
3. 选择 **MCP Servers** 标签页

### 步骤 2: 添加 MCP 服务器

1. 点击 **添加服务器** 或 **+** 按钮
2. 填写以下信息：

| 字段 | 填写内容 |
|------|----------|
| **名称** | `TrendRadar` |
| **描述** | `新闻热点聚合工具` |
| **类型** | `STDIO` |
| **命令** | `/Users/mima0000/.local/bin/uv` |

### 步骤 3: 配置参数

在 **参数 (Args)** 输入框中，**每行填写一个参数**：

```
--directory
/Users/mima0000/.openclaw/workspace/TrendRadar
run
python
-m
mcp_server.server
```

**⚠️ 重要提示**：
- 每个参数必须单独占一行
- 不要把所有参数写在一行

### 步骤 4: 保存并启用

1. 点击 **保存** 按钮
2. 确保 MCP 开关已启用（显示为绿色）
3. 如果看不到 TrendRadar，重启 Cherry Studio

---

## ✅ 验证配置

### 测试连接

在 Cherry Studio 聊天窗口中，发送以下消息：

```
查看今天的热点新闻
```

**成功的标志**：
- AI 会调用 MCP 工具
- 能看到工具调用的日志
- 返回真实的热点新闻

### 可用命令

配置成功后，可以使用以下命令：

- "查看今天的热点新闻"
- "获取微博热搜 TOP10"
- "最近有什么科技新闻"
- "分析知乎热门话题"
- "查看抖音热榜"
- "获取哔哩哔哩热门"

---

## 🐛 故障排查

### 问题 1: 找不到 Cherry Studio

**解决方案**：
1. 下载并安装 Cherry Studio
2. 下载地址：https://github.com/kangfenmao/cherry-studio/releases

### 问题 2: MCP 服务器显示"未连接"

**解决方案**：
1. 检查 UV 路径：
   ```bash
   ls -la /Users/mima0000/.local/bin/uv
   ```
2. 如果文件不存在，重新安装 UV：
   ```bash
   curl -LsSf https://astral.sh/uv/install.sh | sh
   ```

### 问题 3: 调用 MCP 工具失败

**解决方案**：
1. 检查 TrendRadar 项目是否存在：
   ```bash
   ls -la /Users/mima0000/.openclaw/workspace/TrendRadar
   ```
2. 检查虚拟环境：
   ```bash
   ls -la /Users/mima0000/.openclaw/workspace/TrendRadar/.venv
   ```
3. 重启 Cherry Studio

### 问题 4: 参数配置错误

**确保参数格式正确**：

```
❌ 错误（所有参数在一行）：
--directory /Users/mima0000/.openclaw/workspace/TrendRadar run python -m mcp_server.server

✅ 正确（每行一个参数）：
--directory
/Users/mima0000/.openclaw/workspace/TrendRadar
run
python
-m
mcp_server.server
```

---

## 📖 快速参考卡片

复制以下内容作为参考：

```
╔═══════════════════════════════════════════════════╗
║          TrendRadar MCP 配置信息                   ║
╠═══════════════════════════════════════════════════╣
║ 名称：TrendRadar                                  ║
║ 类型：STDIO                                       ║
║ 命令：/Users/mima0000/.local/bin/uv               ║
║ 参数：                                            ║
║   --directory                                     ║
║   /Users/mima0000/.openclaw/workspace/TrendRadar  ║
║   run                                             ║
║   python                                          ║
║   -m                                              ║
║   mcp_server.server                               ║
╚═══════════════════════════════════════════════════╝
```

---

## 🎯 配置完成后

回到聊天窗口，告诉我：
- "配置好了"
- "测试 TrendRadar"

我会帮你验证 MCP 连接！🦐
