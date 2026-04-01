#!/usr/bin/env python3
# -*- utf-8 -*-
"""
从图片生成视频的脚本
"""

import sys
import os
from pathlib import Path
import time

# 添加项目路径
project_path = Path("/Users/mima0000/.openclaw/workspace/openclaw_upload")
sys.path.insert(0, str(project_path))

# 切换到项目目录
os.chdir(project_path)

def main():
    # 导入必要的模块
    from flash_longxia.zhenlongxia_workflow import run_workflow
    
    # 获取inbound_images目录中的图片
    inbound_images_dir = Path("/Users/mima0000/.openclaw/workspace/inbound_images/")
    image_files = list(inbound_images_dir.glob("*.jpg"))
    
    if not image_files:
        print("未找到任何图片文件")
        return
        
    # 选择第一张图片
    selected_image = str(image_files[0])
    print(f"使用图片: {selected_image}")
    
    # 使用默认参数运行工作流
    try:
        print("开始视频生成流程...")
        print("参数: model=auto, duration=10, aspectRatio=16:9")
        
        task_id = run_workflow(
            image_path=selected_image,
            model="auto",
            duration=10,
            aspectRatio="16:9",
            variants=1,
            auto_confirm=True
        )
        
        print(f"视频生成任务已提交，任务ID: {task_id}")
        print("后台轮询已启动，将在output目录生成视频")
        
    except Exception as e:
        print(f"视频生成过程中出现错误: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()