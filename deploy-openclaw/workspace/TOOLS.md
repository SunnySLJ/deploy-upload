# TOOLS.md - 本地配置与操作命令

## 平台端口配置

| 平台 | Chrome 端口 | Cookies 目录 |
|------|------------|-------------|
| 抖音 | 9224 | `cookies/chrome_connect_dy` |
| 小红书 | 9223 | `cookies/chrome_connect_xhs` |
| 快手 | 9225 | `cookies/chrome_connect_ks` |
| 视频号 | 9226 | `cookies/chrome_connect_sph` |

## 重要目录

| 用途 | 路径 |
|------|------|
| 图片保存 | `{{HOME}}/.openclaw/workspace/inbound_images/` |
| 视频生成 | `{{HOME}}/.openclaw/workspace/openclaw_upload/flash_longxia/` |
| 视频输出 | `{{HOME}}/.openclaw/workspace/openclaw_upload/flash_longxia/output/` |
| 多平台上传 | `{{HOME}}/.openclaw/workspace/openclaw_upload/` |
| Cookies 保存 | `{{HOME}}/.openclaw/workspace/openclaw_upload/cookies/` |
| 登录二维码截图 | `{{HOME}}/.openclaw/workspace/logs/auth_qr/` |

## 两个核心技能

### 1️⃣ 图片生成视频 - flash_longxia (帧龙虾)

```bash
cd {{HOME}}/.openclaw/workspace/openclaw_upload

# 查询可用模型参数（必须先查）
{{PYTHON_CMD}} flash_longxia/zhenlongxia_workflow.py --list-models

# 生成视频（默认参数：auto 模型, 10 秒, 9:16 竖屏）
{{PYTHON_CMD}} flash_longxia/zhenlongxia_workflow.py <图片路径> --model=auto --duration=10 --aspectRatio=9:16 --variants=1 --yes
```

**流程**: 上传图片 → 图生文 → 生成视频任务 → 后台轮询 → 下载 MP4

### 2️⃣ 多平台视频发布

```bash
cd {{HOME}}/.openclaw/workspace/openclaw_upload

# 视频号上传（当前唯一开放平台）
AUTH_MODE=profile .venv313/bin/python3 platforms/shipinhao_upload/upload.py "<视频路径>" "<标题>" "<文案>" "<标签>"
```

**⚠️ 当前仅开放视频号**，其他平台（抖音、小红书、快手）暂时关闭。

## Python 环境

- **统一使用 `python3.12`**
- macOS 优先使用：`/opt/homebrew/bin/python3.12`
- Windows 优先使用：`py -3.12`
- 如果项目有 `.venv`，使用 `.venv/bin/python3.12`

## 微信通知配置

- **微信 Target**: `{{WECHAT_TARGET}}`
- **Channel**: `openclaw-weixin`
- **发送命令**: `openclaw message send --channel=openclaw-weixin -t "{{WECHAT_TARGET}}" -m "消息内容" --media=视频路径`

## 飞书通知配置

- **App ID:** `{{FEISHU_APP_ID}}`
- **App Secret:** `{{FEISHU_APP_SECRET}}`

## 用户的视频偏好

- **风格**: 可爱风
- **标题格式**: 表情符号 + 短标题（如 "✨可爱日常～"）
- **文案风格**: 可爱、元气、带表情符号
- **默认标签**: 可爱，日常，生活记录
- **文案模板**: 今天是元气满满的一天呀 🎀 / 可可爱爱没有脑袋～ 💕

---

_请根据实际环境修改 {{HOME}} 和 {{PYTHON_CMD}} 占位符_
