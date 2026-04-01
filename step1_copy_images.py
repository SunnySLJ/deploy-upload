#!/usr/bin/env python3
"""
手动执行步骤1：复制最新图片到工作目录
"""
import os
import shutil
from pathlib import Path

def copy_latest_images():
    # 源目录和目标目录
    source_dir = Path("/Users/mima0000/.openclaw/workspace/inbound_images/")
    target_dir = Path("/Users/mima0000/.openclaw/workspace/openclaw_upload/flash_longxia/")
    
    # 获取最新的图片文件
    jpg_files = list(source_dir.glob("*.jpg"))
    if not jpg_files:
        print("未找到任何JPG图片文件")
        return []
    
    # 按修改时间排序，获取最新的4张
    sorted_files = sorted(jpg_files, key=lambda x: x.stat().st_mtime, reverse=True)[:4]
    
    copied_files = []
    for i, src_file in enumerate(sorted_files):
        dest_file = target_dir / f"latest_img_{i+1}_{src_file.name}"
        try:
            shutil.copy2(src_file, dest_file)
            print(f"✓ 复制: {src_file.name} -> {dest_file.name}")
            copied_files.append(str(dest_file))
        except Exception as e:
            print(f"✗ 复制失败 {src_file.name}: {str(e)}")
    
    print(f"成功复制了 {len(copied_files)} 张图片到工作目录")
    return copied_files

if __name__ == "__main__":
    print("执行步骤1: 复制最新图片到工作目录")
    copied = copy_latest_images()
    print(f"复制完成，共 {len(copied)} 个文件")