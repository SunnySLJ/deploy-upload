#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
后台轮询脚本，用于监控视频生成任务并在完成后发送微信通知
"""

import json
import os
import sys
import time
from pathlib import Path

import requests
import yaml

# 从主脚本复制相关函数
def load_config():
    config_path = Path(__file__).parent / "flash_longxia" / "config.yaml"
    DEFAULT_CONFIG = {
        "base_url": "http://123.56.58.223:8081",
        "upload_url": "http://123.56.58.223:8081/api/v1/file/upload",
        "device_verify": {
            "enabled": False,
            "api_path": "/api/v1/device/verify",
        },
        "video": {
            "poll_interval": 30,
            "max_wait_minutes": 30,
            "download_retries": 3,
            "download_retry_interval": 5,
            "output_dir": "./output",
        },
    }
    
    result = {k: dict(v) if isinstance(v, dict) else v for k, v in DEFAULT_CONFIG.items()}
    if config_path.exists():
        loaded = yaml.safe_load(config_path.read_text(encoding="utf-8")) or {}
        for k, v in loaded.items():
            if k in result and isinstance(result[k], dict) and isinstance(v, dict):
                result[k] = {**result[k], **v}
            else:
                result[k] = v
    return result

def load_saved_token():
    TOKEN_FILE = Path(__file__).parent / "flash_longxia" / "token.txt"
    if TOKEN_FILE.exists():
        t = TOKEN_FILE.read_text(encoding="utf-8").strip()
        return t if t else None
    return None

def fetch_video_by_id(base_url: str, session: requests.Session, video_id: str) -> dict | None:
    url = f"{base_url}/api/v1/aiMediaGenerations/getById"
    try:
        resp = session.get(url, params={"id": video_id}, timeout=15)
        data = resp.json()
        if data.get("code") in (200, 0):
            return data.get("data")
        return None
    except Exception:
        return None

def _extract_video_url_from_rep_msg(record: dict) -> str | None:
    rep_msg = record.get("repMsg")
    if not rep_msg or not isinstance(rep_msg, str):
        return None
    try:
        parsed = json.loads(rep_msg)
    except Exception:
        return None
    data = parsed.get("data") if isinstance(parsed, dict) else None
    if not isinstance(data, dict):
        return None
    result = data.get("result")
    if isinstance(result, list) and result:
        first = result[0]
        if isinstance(first, str) and first.startswith("http"):
            return first
    return None

def get_video_url(record: dict) -> str | None:
    return (
        record.get("videoUrl")
        or record.get("mediaUrl")
        or record.get("url")
        or record.get("videoPath")
        or record.get("path")
    )

def download_video(
    video_url: str,
    output_dir: str,
    filename: str | None = None,
    session: requests.Session | None = None,
    retries: int = 3,
    retry_interval: int = 5,
) -> str:
    """流式下载 MP4 到本地，返回绝对路径。"""
    os.makedirs(output_dir, exist_ok=True)
    if not filename:
        filename = f"video_{int(time.time())}_{int(time.time()*1000)%1000}.mp4"
    path = os.path.join(output_dir, filename)
    req = session.get if session else requests.get
    attempts = max(1, retries)
    last_err: Exception | None = None

    for i in range(1, attempts + 1):
        try:
            resp = req(video_url, stream=True, timeout=60)
            resp.raise_for_status()
            with open(path, "wb") as f:
                for chunk in resp.iter_content(chunk_size=8192):
                    f.write(chunk)
            return os.path.abspath(path)
        except Exception as e:
            last_err = e
            if i < attempts:
                print(f"[下载] 第{i}次失败，{retry_interval}s 后重试: {e}", flush=True)
                time.sleep(max(1, retry_interval))

    raise RuntimeError(f"下载失败，已重试 {attempts} 次: {last_err}")

def send_wechat_message(target, message, media_file=None):
    """
    发送微信消息的函数
    """
    import subprocess
    try:
        if media_file and os.path.exists(media_file):
            # 发送带媒体文件的消息
            cmd = [
                "openclaw", "message", "send",
                "--channel=openclaw-weixin",
                "-t", target,
                "-m", message,
                "--media", media_file
            ]
        else:
            # 发送纯文本消息
            cmd = [
                "openclaw", "message", "send",
                "--channel=openclaw-weixin",
                "-t", target,
                "-m", message
            ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode == 0:
            print(f"微信消息发送成功: {message}")
            return True
        else:
            print(f"微信消息发送失败: {result.stderr}")
            return False
    except Exception as e:
        print(f"发送微信消息时出现异常: {e}")
        return False

def poll_and_notify(task_id, wechat_target):
    """
    轮询任务状态并在完成后下载视频并发送微信通知
    """
    config = load_config()
    base_url = config["base_url"].rstrip("/")
    video_cfg = config.get("video", {})
    
    token_val = load_saved_token()
    if not token_val:
        print("[错误] 无法加载token，退出")
        return False

    session = requests.Session()
    session.headers.update({
        "token": token_val,
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Accept": "application/json",
    })

    poll_interval = video_cfg.get("poll_interval", 30)
    max_wait_minutes = video_cfg.get("max_wait_minutes", 30)
    max_elapsed = max_wait_minutes * 60
    elapsed = 0
    
    print(f"开始轮询任务 {task_id}，每 {poll_interval} 秒查询一次，最多等待 {max_wait_minutes} 分钟")
    
    while elapsed < max_elapsed:
        try:
            record = fetch_video_by_id(base_url, session, task_id)
            if record:
                # 检查 mediaUrl 是否存在（这是关键完成标准）
                media_url = get_video_url(record) or _extract_video_url_from_rep_msg(record)
                if media_url:
                    print(f"检测到视频已生成，开始下载...")
                    
                    # 下载视频
                    output_dir = Path(__file__).parent / "flash_longxia" / video_cfg.get("output_dir", "./output")
                    local_path = download_video(
                        media_url,
                        str(output_dir),
                        session=session,
                        retries=video_cfg.get("download_retries", 3),
                        retry_interval=video_cfg.get("download_retry_interval", 5),
                    )
                    
                    print(f"视频已下载到: {local_path}")
                    
                    # 发送微信通知
                    message = f"视频生成完成！任务ID: {task_id}"
                    success = send_wechat_message(wechat_target, message, local_path)
                    
                    if success:
                        print("微信通知发送成功")
                        return True
                    else:
                        print("微信通知发送失败")
                        return False
                else:
                    print(f"任务仍在处理中... (elapsed: {elapsed}/{max_elapsed}s)")
            else:
                print(f"暂无任务数据... (elapsed: {elapsed}/{max_elapsed}s)")
        
        except Exception as e:
            print(f"轮询过程中出现异常: {e}")
        
        time.sleep(poll_interval)
        elapsed += poll_interval
        
    print(f"轮询超时，任务 {task_id} 未在规定时间内完成")
    
    # 发送超时通知
    timeout_message = f"视频生成超时！任务ID: {task_id}，已在 {max_wait_minutes} 分钟内未完成"
    send_wechat_message(wechat_target, timeout_message)
    
    return False

def main():
    if len(sys.argv) < 3:
        print("用法: python poll_and_notify.py <task_id> <wechat_target>")
        print("示例: python poll_and_notify.py abc123 o9cq80zNpOiKXmKuyo7jrp0WpX9Y@im.wechat")
        sys.exit(1)

    task_id = sys.argv[1]
    wechat_target = sys.argv[2]
    
    poll_and_notify(task_id, wechat_target)

if __name__ == "__main__":
    main()