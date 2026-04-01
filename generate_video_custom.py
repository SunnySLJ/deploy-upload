#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
自定义视频生成脚本，支持指定aspect ratio和duration
"""

import json
import os
import sys
import time
from pathlib import Path

import requests
import yaml

# ---------------------------------------------------------------------------
# 默认配置（可被同目录 config.yaml 覆盖，键合并规则见 load_config）
# ---------------------------------------------------------------------------
DEFAULT_CONFIG = {
    "base_url": "http://123.56.58.223:8081",
    "upload_url": "http://123.56.58.223:8081/api/v1/file/upload",
    "device_verify": {
        "enabled": False,  # True 时先调 device_verify 模块校验本机 MAC
        "api_path": "/api/v1/device/verify",
    },
    "video": {
        "poll_interval": 30,  # 秒：每次查询 getById 的间隔
        "max_wait_minutes": 30,  # 最长等待；超时则放弃下载
        "download_retries": 3,  # 下载失败后的重试次数
        "download_retry_interval": 5,  # 下载重试间隔（秒）
        "output_dir": "./output",  # 相对本脚本所在目录
    },
}


def load_config():
    """
    加载配置：先 DEFAULT_CONFIG，若存在 config.yaml 则合并。
    嵌套字典做浅合并（同名字典键会更新）。
    """
    config_path = Path(__file__).parent.parent / "Desktop/openclaw-backup/workspace/openclaw_upload/flash_longxia/config.yaml"
    result = {k: dict(v) if isinstance(v, dict) else v for k, v in DEFAULT_CONFIG.items()}
    if config_path.exists():
        loaded = yaml.safe_load(config_path.read_text(encoding="utf-8")) or {}
        for k, v in loaded.items():
            if k in result and isinstance(result[k], dict) and isinstance(v, dict):
                result[k] = {**result[k], **v}
            else:
                result[k] = v
    return result


# ---------------------------------------------------------------------------
# Token：与站点约定为 HTTP 头 token: <字符串>，非 Bearer
# ---------------------------------------------------------------------------
TOKEN_FILE = Path(__file__).parent.parent / "Desktop/openclaw-backup/workspace/openclaw_upload/flash_longxia/token.txt"


def load_saved_token():
    """从 token.txt 读取一行 Token；文件不存在或为空则返回 None。"""
    if TOKEN_FILE.exists():
        t = TOKEN_FILE.read_text(encoding="utf-8").strip()
        return t if t else None
    return None


# ---------------------------------------------------------------------------
# API 封装
# ---------------------------------------------------------------------------

def upload_image(upload_url, image_path, session):
    """POST 上传接口，返回图片可访问 URL（字符串或 data.url）。"""
    url = upload_url.rstrip("/")
    with open(image_path, "rb") as f:
        files = {"file": (os.path.basename(image_path), f)}
        resp = session.post(url, files=files, timeout=30)
    data = resp.json()
    if data.get("code") in (200, 0):
        d = data.get("data")
        if isinstance(d, str):
            return d
        if isinstance(d, dict):
            return d.get("url") or d.get("fileUrl") or d.get("path")
    print(f"[错误] 上传失败: {data}")
    return None


def image_to_text(
    base_url,
    image_url,
    session,
    image_type = 1,
):
    """
    POST /api/v1/aiMediaGenerations/imageToText
    image_type: 0 口播提示词，1 视频提示文案（本项目默认 1）
    """
    url = f"{base_url}/api/v1/aiMediaGenerations/imageToText"
    payload = {"imageType": image_type, "urlList": [image_url]}
    resp = session.post(url, json=payload, timeout=60)
    data = resp.json()
    if data.get("code") in (200, 0):
        d = data.get("data")
        if isinstance(d, str):
            return d
        if isinstance(d, dict):
            return d.get("systemPrompt") or d.get("prompt") or d.get("text") or str(d)
    print(f"[错误] 图生文失败: {data}")
    return None


def generate_video(
    base_url,
    image_url,
    system_prompt,
    session,
    aspect_ratio = "16:9",
    duration = 10,
    model = "auto",  # 添加模型参数
    **kwargs,
):
    """POST generateVideo，返回任务 id（用于后续 getById 轮询）。"""
    url = f"{base_url}/api/v1/aiMediaGenerations/generateVideo"
    payload = {
        "referenceImageUrls": [image_url],
        "prompt": system_prompt,
        "systemPrompt": system_prompt,
        "aspectRatio": aspect_ratio,
        "duration": duration,
        "model": model,  # 添加模型参数
    }
    payload.update({k: v for k, v in kwargs.items() if v is not None})
    resp = session.post(url, json=payload, timeout=30)
    data = resp.json()
    if data.get("code") in (200, 0):
        d = data.get("data")
        if isinstance(d, list) and d:
            d = d[0]
        if isinstance(d, dict):
            return str(d.get("id") or d.get("groupNo") or d.get("taskId") or d)
        return str(d) if d else None
    print(f"[错误] 生成视频失败: {data}")
    return None


def fetch_video_by_id(base_url, session, video_id):
    """GET getById?id=，成功时返回 data 字典（含 status、mediaUrl 等）。"""
    url = f"{base_url}/api/v1/aiMediaGenerations/getById"
    try:
        resp = session.get(url, params={"id": video_id}, timeout=15)
        data = resp.json()
        if data.get("code") in (200, 0):
            return data.get("data")
        return None
    except Exception:
        return None


# 与后端约定：完成态 / 失败态（见接口文档或抓包确认）
_STATUS_SUCCESS = ("2", 2, "completed", "success", "SUCCESS")
_STATUS_FAILED = ("3", 3, "failed", "FAILED", "error", "ERROR")
_STATUS_LABELS = {
    "0": "排队中",
    0: "排队中",
    "1": "生成中",
    1: "生成中",
    "2": "已完成",
    2: "已完成",
    "3": "已失败",
    3: "已失败",
    "completed": "已完成",
    "success": "已完成",
    "SUCCESS": "已完成",
    "failed": "已失败",
    "FAILED": "已失败",
    "error": "已失败",
    "ERROR": "已失败",
}


def _build_status_text(record: dict) -> str:
    """构建轮询日志里的状态文本，方便快速判断任务进度。"""
    status = record.get("status") or record.get("videoStatus") or record.get("taskStatus")
    status_label = _STATUS_LABELS.get(status, "处理中")
    req_msg = record.get("reqMsg") or ""
    rep_msg = record.get("repMsg") or record.get("message") or record.get("msg") or record.get("errorMsg") or ""
    return f"status={status}({status_label}), reqMsg={req_msg}, repMsg={rep_msg}"


def _extract_video_url_from_rep_msg(record):
    """
    兼容某些后端场景：
    顶层 status 仍是处理中，但 repMsg(JSON 字符串)里已经有 result 视频链接。
    """
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


def poll_video_status(
    base_url,
    session,
    task_id,
    poll_interval = 30,
    max_wait_minutes = 30,
):
    """
    轮询直到：成功返回整条记录；失败/超时返回 None。
    处理中状态继续 sleep poll_interval 秒。
    返回 (record, reason)，reason in {"success", "failed", "timeout"}。
    """
    max_elapsed = max_wait_minutes * 60
    elapsed = 0
    attempt = 0
    print(f"[轮询] 按 id={task_id} 查询 getById，每 {poll_interval}s 查一次，最多等 {max_wait_minutes} 分钟", flush=True)

    while elapsed < max_elapsed:
        attempt += 1
        try:
            record = fetch_video_by_id(base_url, session, task_id)
            if record:
                # 检查 mediaUrl 是否存在（这是关键完成标准）
                media_url = record.get("mediaUrl") or _extract_video_url_from_rep_msg(record)
                if media_url:
                    print(f"[轮询] 检测到 mediaUrl，任务完成 id={task_id}")
                    record["mediaUrl"] = media_url  # 确保 record 包含 mediaUrl
                    return record, "success"
                
                status = record.get("status") or record.get("videoStatus") or record.get("taskStatus")
                print(f"[轮询] 第{attempt}次: {_build_status_text(record)}", flush=True)
                rep_video_url = _extract_video_url_from_rep_msg(record)
                if rep_video_url:
                    record["mediaUrl"] = record.get("mediaUrl") or rep_video_url
                    print(f"[轮询] 第{attempt}次: repMsg 已包含成片链接，直接进入下载", flush=True)
                    return record, "success"
                if status in _STATUS_SUCCESS:
                    print(f"[轮询] 视频已完成 id={task_id}", flush=True)
                    return record, "success"
                if status in _STATUS_FAILED:
                    msg = record.get("msg") or record.get("message") or record.get("errorMsg", "")
                    print(f"[错误] 视频生成失败 status={status}, msg={msg}, record={record}", flush=True)
                    return None, "failed"
            else:
                print(f"[轮询] 第{attempt}次: 暂无数据（接口返回空 data）", flush=True)
        except Exception as e:
            print(f"[轮询] 第 {attempt} 次异常: {e}", flush=True)

        remaining = max_elapsed - elapsed
        sleep_sec = min(poll_interval, remaining)
        if sleep_sec <= 0:
            break
        print(f"[轮询] 等待中... ({int(elapsed)}s/{max_elapsed}s, 下次 {sleep_sec}s 后)", flush=True)
        time.sleep(sleep_sec)
        elapsed += sleep_sec

    print(f"[轮询] 已等待 {max_wait_minutes} 分钟，未获取到视频，停止轮询", flush=True)
    return None, "timeout"


def get_video_url(record):
    """从 getById 的 data 里取可下载的视频地址（字段名以实际返回为准）。"""
    return (
        record.get("videoUrl")
        or record.get("mediaUrl")
        or record.get("url")
        or record.get("videoPath")
        or record.get("path")
    )


def download_video(
    video_url,
    output_dir,
    filename = None,
    session = None,
    retries = 3,
    retry_interval = 5,
):
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


def run_workflow(
    image_path,
    aspect_ratio = "16:9",
    duration = 10,
    model = "auto",
    *,
    token = None,
):
    """串联上述步骤；任一步失败则 sys.exit(1)。"""
    config = load_config()
    base_url = config["base_url"].rstrip("/")
    upload_url = config.get("upload_url", f"{base_url}/api/v1/file/upload").rstrip("/")
    video_cfg = config.get("video", {})

    token_val = token or load_saved_token()
    if not token_val:
        print("[错误] 请将 Token 写入 flash_longxia/token.txt 或使用 --token=xxx", flush=True)
        sys.exit(1)

    session = requests.Session()
    session.headers.update({
        "token": token_val,
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Accept": "application/json",
    })
    print(f"[1/7] 使用 Token: {token_val[:8]}...", flush=True)

    # 可选：设备 MAC + 权限接口（实现见 device_verify.py）
    dev_cfg = config.get("device_verify", {}) or {}
    if dev_cfg.get("enabled"):
        if Path("device_verify.py").exists():
            import device_verify
            if not device_verify.run_device_verify(
                base_url, session, api_path=dev_cfg.get("api_path")
            ):
                print("[错误] 设备未授权，无法继续", flush=True)
                sys.exit(1)
        print("[2/7] 设备验证通过", flush=True)
    else:
        print("[2/7] 跳过设备验证（未启用）", flush=True)

    print(f"[3/7] 上传图片: {image_path}", flush=True)
    image_url = upload_image(upload_url, image_path, session)
    if not image_url:
        sys.exit(1)
    print(f"[OK] 图片已上传: {image_url}")

    print("[4/7] 图生文获取提示词...", flush=True)
    system_prompt = image_to_text(base_url, image_url, session)
    if not system_prompt:
        sys.exit(1)
    print(f"[OK] 系统提示词: {system_prompt[:80]}...")

    print(f"[5/7] 发起视频生成... (aspect_ratio={aspect_ratio}, duration={duration}, model={model})", flush=True)
    task_id = generate_video(base_url, image_url, system_prompt, session, 
                             aspect_ratio=aspect_ratio, duration=duration, model=model)
    if not task_id:
        sys.exit(1)
    print(f"[OK] 任务 ID: {task_id}")

    poll_int = video_cfg.get("poll_interval", 30)
    max_wait = video_cfg.get("max_wait_minutes", 30)
    print(f"[6/7] 轮询 getById(id={task_id}): 每{poll_int}s 查一次，最多等 {max_wait} 分钟", flush=True)
    record, reason = poll_video_status(
        base_url, session, task_id,
        poll_interval=poll_int,
        max_wait_minutes=max_wait,
    )
    if not record:
        if reason == "failed":
            print("[错误] 任务状态已失败，停止后续下载")
        else:
            print("[错误] 轮询超时，未获取到可下载视频")
        sys.exit(1)

    video_url = get_video_url(record)
    if not video_url:
        print("[错误] 无法解析视频 URL:", record)
        sys.exit(1)

    print("[7/7] 下载视频...", flush=True)
    output_dir = Path(__file__).parent.parent / "Desktop/openclaw-backup/workspace/openclaw_upload/flash_longxia" / video_cfg.get("output_dir", "./output")
    local_path = download_video(
        video_url,
        str(output_dir),
        session=session,
        retries=video_cfg.get("download_retries", 3),
        retry_interval=video_cfg.get("download_retry_interval", 5),
    )
    print(f"[完成] 视频已保存: {local_path}")
    return local_path, task_id


def main():
    if len(sys.argv) < 2:
        print("用法: python generate_video_custom.py <图片路径> [aspect_ratio] [duration] [model] [--token=xxx]")
        print("示例: python generate_video_custom.py ./my_image.jpg 9:16 10 auto")
        sys.exit(1)

    image_path = sys.argv[1]
    aspect_ratio = sys.argv[2] if len(sys.argv) > 2 else "16:9"
    duration = int(sys.argv[3]) if len(sys.argv) > 3 else 10
    model = sys.argv[4] if len(sys.argv) > 4 else "auto"
    
    if not os.path.isfile(image_path):
        print(f"错误: 文件不存在 {image_path}")
        sys.exit(1)

    token = None
    for arg in sys.argv[5:]:
        if arg.startswith("--token="):
            token = arg.split("=", 1)[1]

    result = run_workflow(image_path, aspect_ratio, duration, model, token=token)
    print(f"任务完成！视频保存至: {result[0]}, 任务ID: {result[1]}")


if __name__ == "__main__":
    main()