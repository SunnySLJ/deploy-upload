# 如何使用龙虾视频生成技能

## 准备工作

1. 确保已准备好一张图片（JPG, PNG, GIF, WEBP 格式）
2. 确认 token 文件存在：`/Users/mima0000/.openclaw/workspace/openclaw_upload/flash_longxia/token.txt`

## 使用方法

### 方法一：直接运行工作流脚本
```bash
cd /Users/mima0000/.openclaw/workspace/openclaw_upload/flash_longxia
python3 zhenlongxia_workflow.py <你的图片路径> --model=auto --duration=10 --aspectRatio=16:9 --variants=1
```

### 方法二：使用封装脚本
```bash
cd /Users/mima0000/.openclaw/workspace/openclaw_upload/skills/flash-longxia/scripts
python3 generate_video.py <你的图片路径> --model=auto --duration=10 --aspectRatio=16:9 --variants=1
```

## 工作流程说明

1. **图片上传**: 将图片上传到 `/api/v1/file/upload`
2. **AI 描述生成**: 调用 `/api/v1/aiMediaGenerations/imageToText` 生成提示词
3. **内容审核**: 校验提示词是否生成成功
4. **用户确认**: 询问用户是否继续进行视频生成
5. **视频生成**: 调用 `/api/v1/aiMediaGenerations/generateVideo` 创建视频任务
6. **返回任务ID**: 后续轮询与下载由其他组件处理

## 参数说明

- `--model=auto`: 使用自动选择模型
- `--duration=10`: 视频时长10秒
- `--aspectRatio=16:9`: 视频宽高比16:9
- `--variants=1`: 生成1个变体
- `--yes`: 跳过确认步骤（可选）

## 注意事项

- 如果提示词生成失败，则不会继续进行视频生成
- 默认会在视频生成前要求人工确认
- 生成的视频任务ID将用于后续的轮询和下载过程