#!/usr/bin/env python3
# -*- utf-8 -*-
"""
模型查询工具 - 仅用于演示可用的模型参数
"""

import os
import sys
from pathlib import Path

# 设置环境变量指向仓库
os.environ['OPENCLAW_UPLOAD_ROOT'] = '/Users/mima0000/.openclaw/workspace/openclaw_upload'

def list_available_models():
    """展示可用的模型类型，基于常见的AI视频生成模型"""
    print("=== 可用视频生成模型 ===")
    print("1. auto - 自动选择最佳模型")
    print("2. sora2-new - Sora 2代新模型")
    print("3. grok_imagine - Grok Imagine 模型")
    print("4. deep_seek - DeepSeek 视频生成模型")
    print("5. seed_v2 - Seed v2 视频生成模型")
    print("")
    print("=== 支持的时长选项 ===")
    print("- 5秒")
    print("- 10秒 (默认)")
    print("- 15秒")
    print("- 30秒")
    print("")
    print("=== 支持的画面比例 ===")
    print("- 16:9 (宽屏，适合YouTube等平台)")
    print("- 9:16 (竖屏，适合抖音、Instagram Stories)")
    print("- 1:1 (方形，适合Instagram等平台)")
    print("- 4:3 (传统电视比例)")
    print("")
    print("注意：实际可用的模型和参数可能因API提供商而异")

def select_image_and_generate():
    """选择图片并准备生成视频"""
    image_dir = Path("/Users/mima0000/.openclaw/workspace/inbound_images/")
    image_files = list(image_dir.glob("*.jpg"))
    
    if not image_files:
        print("错误：未找到任何图片文件")
        return
    
    print(f"\n=== 找到 {len(image_files)} 张图片 ===")
    for i, img in enumerate(image_files[:5]):  # 显示前5张
        print(f"{i+1}. {img.name}")
    if len(image_files) > 5:
        print(f"... 还有 {len(image_files)-5} 张图片")
    
    print(f"\n将使用第一张图片: {image_files[0].name}")
    print("\n=== 视频生成参数 ===")
    print("模型: auto (自动选择)")
    print("时长: 10秒")
    print("画面比例: 16:9")
    print("变体数量: 1")
    
    print(f"\n准备生成命令:")
    print(f"python3 zhenlongxia_workflow.py {image_files[0]} --model=auto --duration=10 --aspectRatio=16:9 --yes")
    
    return str(image_files[0])

if __name__ == "__main__":
    print("龙虾视频生成工具 - 模型查询")
    print("="*40)
    
    list_available_models()
    selected_image = select_image_and_generate()
    
    print(f"\n下一步操作:")
    print("1. 运行预检脚本: python3 scripts/preflight.py")
    print("2. 列出实际可用模型: python3 scripts/generate_video.py --list-models")
    print("3. 生成视频: python3 scripts/generate_video.py <图片路径> --model=auto --duration=10 --aspectRatio=16:9 --yes")