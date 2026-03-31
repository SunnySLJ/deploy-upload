#!/bin/bash

# Script to demonstrate the flash-longxia workflow for generating video from image
# This script shows how the workflow would be executed once an image is provided

echo "龙虾视频生成工具 - Flash Longxia"
echo "================================"

# Check if image path is provided
if [ $# -eq 0 ]; then
    echo "请提供一个图片路径作为参数"
    echo "用法: $0 <图片路径> [选项]"
    echo "例如: $0 /path/to/image.jpg"
    exit 1
fi

IMAGE_PATH="$1"
echo "正在处理图片: $IMAGE_PATH"

# Check if image file exists
if [ ! -f "$IMAGE_PATH" ]; then
    echo "错误: 图片文件不存在 - $IMAGE_PATH"
    exit 1
fi

echo "验证图片文件..."
file "$IMAGE_PATH"

# Navigate to the flash_longxia directory and run the workflow
cd /Users/mima0000/.openclaw/workspace/openclaw_upload/flash_longxia

echo "启动真龙虾工作流..."
echo "运行命令: python3 zhenlongxia_workflow.py \"$IMAGE_PATH\" --model=auto --duration=10 --aspectRatio=16:9 --variants=1"

# Note: We're showing the command that would be executed, but not actually executing it
# because we don't have a valid token or image to process
echo ""
echo "如果要实际执行，需要确保以下条件满足:"
echo "1. flash_longxia/token.txt 文件存在或通过 --token 参数提供"
echo "2. 图片路径有效"
echo "3. API 服务可访问"
echo ""
echo "命令格式:"
echo "python3 zhenlongxia_workflow.py <图片路径> --model=auto --duration=10 --aspectRatio=16:9 --variants=1 [--yes]"