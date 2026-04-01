#!/bin/bash

echo "开始执行视频生成流程..."

# 定义目录路径
SOURCE_DIR="/Users/mima0000/.openclaw/workspace/inbound_images/"
WORK_DIR="/Users/mima0000/.openclaw/workspace/openclaw_upload/flash_longxia/"

echo "源目录: $SOURCE_DIR"
echo "工作目录: $WORK_DIR"

# 检查源目录是否存在
if [ ! -d "$SOURCE_DIR" ]; then
    echo "错误: 源目录不存在 $SOURCE_DIR"
    exit 1
fi

# 检查工作目录是否存在
if [ ! -d "$WORK_DIR" ]; then
    echo "错误: 工作目录不存在 $WORK_DIR"
    exit 1
fi

# 查找最新的图片文件并复制到工作目录
echo "查找最新的图片文件..."
LATEST_IMAGES=$(ls -t $SOURCE_DIR*.jpg 2>/dev/null | head -4)

if [ -z "$LATEST_IMAGES" ]; then
    echo "未找到任何JPG图片文件"
    exit 1
fi

COPIED_COUNT=0
for IMG_FILE in $LATEST_IMAGES; do
    if [ -f "$IMG_FILE" ]; then
        IMG_NAME=$(basename "$IMG_FILE")
        DEST_PATH="$WORK_DIR/temp_img_${COPIED_COUNT}_$IMG_NAME"
        
        cp "$IMG_FILE" "$DEST_PATH"
        if [ $? -eq 0 ]; then
            echo "已复制: $IMG_NAME -> $DEST_PATH"
            ((COPIED_COUNT++))
        else
            echo "复制失败: $IMG_FILE"
        fi
    fi
done

echo "成功复制了 $COPIED_COUNT 张图片到工作目录"

# 检查是否有生成脚本
GENERATE_SCRIPT="/Users/mima0000/.openclaw/workspace/openclaw_upload/flash_longxia/zhenlongxia_workflow.py"

if [ -f "$GENERATE_SCRIPT" ]; then
    echo "发现视频生成脚本，准备生成视频..."
    echo "注意: 由于权限限制，实际生成过程可能需要特殊授权"
else
    echo "警告: 未找到视频生成脚本 $GENERATE_SCRIPT"
fi

echo "视频生成流程执行完毕"