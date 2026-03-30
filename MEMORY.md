# MEMORY.md - 千千的长期记忆

---

## 🦐 虾王的职责

### 📷 图片生成视频

**核心流程**：
1. **接收照片** → 检查是否重复（对比文件名或内容）
2. **关键字触发** → 检测到"生成视频"、"图生视频"、"图片转视频"等关键字
3. **调用技能** → 使用 flash-longxia SKILL 执行生成
4. **后台轮询监控** → 独立子任务轮询检查视频生成状态（不占用主会话）
   - 每30秒检查一次
   - **单个视频最多等30分钟**，超时则放弃（当它生成失败）
5. **生成成功** → 自动发微信通知用户，并发送视频文件
6. **等待确认** → 用户明确说"可以发布"后才执行上传

**规则**：
- ✅ 重复照片 → 提示用户已处理过
- ✅ 非重复 + 有关键字 → 自动调用技能生成
- ✅ 轮询在后台运行，不阻塞主会话
- ❌ 单个视频超时30分钟 → 放弃，不再查询
- ❌ 没有关键字 → 不生成，等用户明确要求
- ❌ **用户没确认 → 绝对不能生成！**

**⚠️ 硬性规定**：
- 生成视频前必须问用户确认，只有用户说"确认生成"才能执行
- 发布视频前必须问用户确认，只有用户说"可以发布"才能执行
- 平台未登录时必须用 auth 技能获取二维码发送给用户，禁止做其他操作

---

### 📤 四平台发布

**触发条件**：用户说"发布"、"上传"、"发到抖音"等

**执行流程**：
1. **检测关键字** → 判断要发布到哪些平台
2. **检查登录** → 各平台登录状态
3. **按优先级发布** → 抖音 → 小红书 → 快手 → 视频号
4. **遇登录失效则跳过** → 继续下一个平台
5. **汇总结果** → 通知用户哪些成功、哪些需要重新登录

**多平台优先级**：抖音 > 小红书 > 快手 > 视频号

**规则**：
- ✅ 单平台 → 直接上传
- ✅ 多平台 → 按优先级顺序发布
- ✅ 登录失效 → 跳过，继续下一个
- ✅ 全部发布完成 → 通知用户结果
- ❌ 某个平台登录失效 → 跳过，不阻塞

---

### 🔐 登录状态检测与扫码登录

**触发条件**：用户配置了检查时间，或每天定时触发

**执行流程**：
1. **初始化配置** → 用户设定每日检查登录的时间段（如每天 9:00）
2. **定时检查** → 每天在设定时间检查四个平台登录状态
3. **检测登录** → 逐个检查抖音、小红书、快手、视频号
4. **失效则扫码** → 登录过期则调用 auth SKILL 获取二维码
5. **逐个发送** → 一个平台一个平台来，不能同时发二维码
6. **用户扫码** → 发送后等待用户完成登录

**检查优先级**：抖音 → 小红书 → 快手 → 视频号（一个个来）

**规则**：
- ✅ 用户配置时间 → 按设定时间检查
- ✅ 登录过期 → 调用 auth SKILL 获取二维码
- ✅ 微信通知 → 发送二维码图片给用户
- ✅ 逐个平台 → 不能同时发多个二维码
- ❌ 正在登录中 → 不重复发送

---

## 🎬 图片生成视频工作流

**触发词**: "生成视频"、"图片转视频"、"图生视频"

**技能**: flash-longxia (帧龙虾)

**技能文档**: `/Users/mima0000/.openclaw/workspace/openclaw_upload/skills/flash-longxia/SKILL.md`

**位置**: `/Users/mima0000/.openclaw/workspace/openclaw_upload/flash_longxia/`

**执行命令**:
```bash
cd /Users/mima0000/.openclaw/workspace/openclaw_upload/flash_longxia
python3 zhenlongxia_workflow.py "<图片路径>" [--model=xxx] [--style=xxx] [--duration=N] [--aspect-ratio=XXX] [--quality=xxx]
```

**可选参数**（⚠️ 以代码和 SKILL.md 为准！）:
| 参数 | 选项 | 默认值 | 说明 |
|------|------|--------|------|
| `--model` | `auto` | auto | **只允许 auto！** |
| `--duration` | `10`, `15`, `20` (秒) | 10 | 视频时长，最小 10 秒 |
| `--aspectRatio` | `16:9`, `9:16`, `1:1` | 16:9 | 画面比例（**驼峰写法**） |
| `--variants` | 数字 | 1 | 生成变体数量 |

**注意**：
- ❌ 没有 `--style` 参数
- ❌ 没有 `--quality` 参数
- ❌ 没有 `--aspect-ratio`（是 `--aspectRatio` 用驼峰！）

**示例**:
```bash
# 竖屏 9:16
python3 zhenlongxia_workflow.py image.jpg --model=auto --aspectRatio=9:16

# 默认参数
python3 zhenlongxia_workflow.py image.jpg
```

**输出**: `flash_longxia/output/video.mp4`

**Token**: 已配置在 `token.txt`

**完整流程**:
1. 保存图片到 `inbound_images/`
2. 启动帧龙虾生成视频（后台运行）
3. **使用 cron 或后台进程轮询检查输出文件**
4. 视频生成完成后，自动发送视频文件给用户微信确认
5. 用户回复"可以发布"或"确认发布"后，再执行四平台上传
6. 上传到抖音/快手/小红书/视频号

**重要**: 
- 生成视频后必须等用户确认才能发布，不要自动上传！
- **等待视频生成时使用 cron/后台任务轮询，不要阻塞主会话**
- **⚠️ 禁止多次调用：每次生成视频只能调用一次 workflow，调用前检查 output 目录是否已有待处理的视频，避免重复生成**
- 轮询检查目录：`flash_longxia/output/`
- 检查文件后缀：`.mp4`

---

## 📤 多平台视频发布

**触发词**: "上传视频"、"发布视频"、"多平台上传"、"可以发布"、"确认发布"

**位置**: `/Users/mima0000/.openclaw/workspace/xiaolong-upload/`

**支持平台**: 抖音 ✅、快手 ✅、视频号 ✅、小红书 ✅

**执行命令**:
```bash
cd /Users/mima0000/.openclaw/workspace/xiaolong-upload
/opt/homebrew/bin/python3.11 upload.py -p <平台> "<视频路径>" "<标题>" "<文案>" "<标签>"
```

**Cookies**: 已保存在 `cookies/<平台>/` 目录

**登录失效自动通知**: 
- 检测到登录失效时自动截取登录二维码
- 截图保存到 `logs/auth_qr/<平台>_login_qr.png`
- 自动发送微信通知给用户扫码登录
- **用户确认登录后自动删除截图**（保持桌面整洁）

**手动生成登录二维码**（当用户说"XX 登录"、"重新登录 XX"、"XX 又掉了"时）:
```python
cd /Users/mima0000/.openclaw/workspace/xiaolong-upload
/opt/homebrew/bin/python3.11 -c "
import sys
sys.path.insert(0, 'skills/auth/scripts')
from platform_login import open_target_tab, capture_login_screenshot, send_wechat_notification
import time

platform = '<平台>'  # douyin | kuaishou | xiaohongshu | shipinhao
open_target_tab(platform)  # 打开登录页
time.sleep(5)  # 等待页面加载
result = capture_login_screenshot(platform)
if result:
    send_wechat_notification(platform, result)
"
```

**平台代码对照**:
| 平台 | 代码 | Chrome 端口 |
|------|------|-------------|
| 抖音 | `douyin` | 9224 |
| 快手 | `kuaishou` | 9225 |
| 小红书 | `xiaohongshu` | 9223 |
| 视频号 | `shipinhao` | 9226 |

**注意事项**:
- 如果端口未监听，需要先启动 Chrome: `launch_connect_chrome('<平台>')`
- 快手需要额外调用 `open_target_tab()` 打开登录页
- 截图自动保存到 `logs/auth_qr/` 目录
- 发送微信使用 `openclaw message send --channel openclaw-weixin --media <截图路径>`

**发布前确认**: 必须等用户明确说"可以发布"或"确认发布"后才能执行上传

**自动清理任务**:
- ⏰ 每天凌晨 1:00 自动清理 `flash_longxia/output/` 目录
- 📅 保留最近 1 天的视频文件
- 🧹 避免 output 目录积累大量视频文件

**Skill 方式**:
- 📦 技能名称：`video-cleanup`
- 📁 技能位置：`xiaolong-upload/skills/video-cleanup/`
- 🔧 执行脚本：`scripts/cleanup_uploaded_videos.py`
- ⚙️ 支持参数：`--manual` (手动模式), `--keep N` (保留 N 天)

## ⚠️ 硬性规定 - 必须使用技能！

### 📤 上传发布规则

**四平台上传必须通过 longxia-upload 技能执行！**

- ✅ 必须：调用 `upload.py` 或平台脚本执行上传
- ✅ 必须：上传前先检查登录状态 (`platform_login.py --check-only`)
- ❌ 禁止：直接用 browser 工具打开网页手动上传
- ❌ 禁止：绕过技能的文件上传流程

**原因**：技能封装了完整的登录态管理、错误处理、截图通知，直接操作 browser 无法复用这些功能。

**违规处理**：如技能执行失败，应修复技能代码，而非绕过。

### 🔐 登录规则（核心功能！）

**平台登录必须通过 auth 技能执行！这是最主要功能之一！**

- ✅ 必须：使用 `platform_login.py --platform <平台> --notify-wechat`
- ✅ 技能会自动在 `logs/auth_qr/<平台>_login_qr.png` 生成二维码
- ✅ 必须：从技能指定目录读取二维码图片，用 message 工具发送给用户
- ✅ 必须：登录完成后等待用户确认再发布
- ❌ 禁止：手动打开 Chrome 登录
- ❌ 禁止：绕过 auth 技能的登录流程
- ❌ 禁止：自己截图或用 browser 工具操作登录

**原因**：auth 技能确保登录态写入正确的 `cookies/chrome_connect_*` 目录，供上传技能复用。

### 📋 标准执行流程

1. **检查登录** → `platform_login.py --platform <平台> --check-only`
2. **如需登录** → `platform_login.py --platform <平台> --notify-wechat`
   - 技能会自动保存二维码到：`logs/auth_qr/<平台>_login_qr.png`
   - 从该路径读取图片，用 `message` 工具发送给用户
3. **等待确认** → 用户明确说"可以发布"或"确认发布"
4. **执行上传** → `upload.py --platform <平台> <视频路径> <标题> <文案> <标签>`

### 🔧 故障处理原则

- 技能执行失败 → 修复技能代码或配置
- 登录失效 → 用 auth 技能重新登录
- 浏览器连接失败 → 重启对应端口 Chrome 后重试
- 不绕过技能，不手动操作 browser

---

## 👤 用户偏好

- **称呼**: 千千
- **视频风格**: 可爱风
- **默认标签**: 可爱，日常，生活记录
- **文案风格**: 带表情符号，元气满满
- **默认标题**: 可爱日常

---

## 📁 重要目录

| 用途 | 路径 |
|------|------|
| 图片保存 | `/Users/mima0000/.openclaw/workspace/inbound_images/` |
| 视频生成 | `/Users/mima0000/.openclaw/workspace/openclaw_upload/flash_longxia/` |
| 视频输出 | `/Users/mima0000/.openclaw/workspace/openclaw_upload/flash_longxia/output/` |
| 多平台上传 | `/Users/mima0000/.openclaw/workspace/openclaw_upload/` |
| Cookies 保存 | `/Users/mima0000/.openclaw/workspace/openclaw_upload/cookies/` |

---

## 📝 经验教训

**2026-03-30**：用户只发了一张图片生成视频，但我反复尝试多次都被系统中断或超时（任务一直显示 status=None 处理中），结果浪费了大量时间。其实第一次生成的任务虽然被中断，但 output 目录已有之前生成好的视频。

另外用户说"模型选auto"，我不应该传的 `--model=auto`（系统没有这个选项），应该用默认参数或不传。

**教训**：
- ⚠️ 每次生成视频只能调用一次 workflow，调用前检查 output 目录是否已有待处理的视频
- ⚠️ 如果任务被中断，先检查 output 目录是否有已生成的视频，不要盲目重新调用
- ⚠️ 轮询等待时耐心等待，不要频繁中断重试
- ⚠️ model 只允许 `auto`，不要传其他值！
- ⚠️ aspectRatio 用驼峰写法（`--aspectRatio`，不是 `--aspect-ratio`）
- ⚠️ 不要使用 `--style` 和 `--quality` 参数

---

_最后更新：2026-03-30_
