#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
检查视频生成状态的脚本
"""
import time
import subprocess
import sys
import os
from datetime import datetime

def check_video_status(task_id):
    """检查视频生成状态"""
    cmd = [
        "python3.12", 
        "skills/flash-longxia/scripts/download_video.py", 
        str(task_id), 
        "--check-only"
    ]
    
    result = subprocess.run(cmd, capture_output=True, text=True, cwd="/Users/mima0000/.openclaw/workspace/openclaw_upload")
    return result.stdout

def download_video(task_id):
    """下载视频"""
    cmd = [
        "python3.12", 
        "skills/flash-longxia/scripts/download_video.py", 
        str(task_id)
    ]
    
    result = subprocess.run(cmd, capture_output=True, text=True, cwd="/Users/mima0000/.openclaw/workspace/openclaw_upload")
    return result.stdout, result.returncode

def main():
    task_id = 1789
    max_wait_time = 1800  # 30分钟，以秒为单位
    check_interval = 30   # 30秒检查一次
    
    start_time = time.time()
    
    print(f"[{datetime.now()}] 开始监控任务 {task_id} 的视频生成状态")
    print(f"最大等待时间: {max_wait_time/60} 分钟")
    
    while True:
        elapsed_time = time.time() - start_time
        
        # 检查是否超过最大等待时间
        if elapsed_time > max_wait_time:
            print(f"[{datetime.now()}] 超过最大等待时间 ({max_wait_time/60} 分钟)，停止监控")
            print(f"任务 {task_id} 未能在规定时间内完成")
            break
            
        print(f"[{datetime.now()}] 检查任务 {task_id} 状态...")
        
        status_output = check_video_status(task_id)
        print(status_output)
        
        # 检查输出中是否包含视频地址
        if "视频地址:" in status_output and "无" not in status_output.split("视频地址:")[-1]:
            print(f"[{datetime.now()}] 视频生成完成！正在下载...")
            
            # 下载视频
            download_output, return_code = download_video(task_id)
            print(download_output)
            
            if return_code == 0:
                print(f"[{datetime.now()}] 视频下载完成")
                
                # 检查下载的视频文件是否存在
                video_file = f"/Users/mima0000/.openclaw/workspace/openclaw_upload/flash_longxia/output/{task_id}.mp4"
                if os.path.exists(video_file):
                    print(f"[{datetime.now()}] 视频文件已保存至: {video_file}")
                    
                    # 准备通过微信发送视频
                    print(f"[{datetime.now()}] 准备通过微信发送视频给用户")
                    print("任务完成")
                    break
                else:
                    print(f"[{datetime.now()}] 错误：视频文件未找到: {video_file}")
            else:
                print(f"[{datetime.now()}] 视频下载失败")
                break
        else:
            print(f"[{datetime.now()}] 视频尚未生成完成，等待 {check_interval} 秒后重试...")
            time.sleep(check_interval)

if __name__ == "__main__":
    main()