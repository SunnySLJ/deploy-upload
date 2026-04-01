# HEARTBEAT.md - 定时任务配置

## 每日定时任务

### 登录状态检查

- **时间**: 每天 10:10（可配置）
- **配置文件**: `xiaolong-upload/skills/auth/login_check_config.json`
- **任务**: 检查四个平台登录状态（抖音 → 小红书 → 快手 → 视频号）
- **执行**: 若登录失效，自动尝试恢复会话；如失败则发送微信通知
- **Cron ID**: `6482a7da-40c2-45d5-b74d-e8858845f8c0`

### 视频输出目录清理

- **时间**: 每周二凌晨 01:00
- **任务**: 清理 `flash_longxia/output/` 目录
- **规则**: 保留最近 7 天的视频文件
- **Cron ID**: `b6bf9379-21c9-4319-93ac-018ca84cfb0e`

### 视频完成通知检查 ⭐ NEW

- **频率**: 每 60 秒检查一次
- **脚本**: `openclaw_upload/flash_longxia/check_video_notifications.py`
- **任务**: 读取 `completed_notification.json` → 发送微信通知 → 清理文件
- **Cron ID**: `d6fe19aa-dd3f-46a6-a810-11bf7f6f0a8e`
- **流程**:
  1. 检查 `completed_notification.json` 是否存在
  2. 读取任务 ID 和视频路径
  3. 调用 `openclaw message send` 发送微信通知（附带视频文件）
  4. 标记为已处理，清空通知文件

## 心跳检查项（每次心跳轮询 2-4 项）

- [ ] 检查平台登录状态（轮换检查）
- [ ] 检查是否有待处理的视频生成任务
- [ ] 检查通知队列（已由 cron 自动处理）

## 心跳状态追踪

记录在 `memory/heartbeat-state.json`：

```json
{
  "lastChecks": {
    "login_status": null,
    "video_tasks": null,
    "video_notifications": null
  },
  "lastOutreach": null
}
```

---

_最后更新：2026-03-31_
