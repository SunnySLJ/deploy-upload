#!/usr/bin/env python3
# -*- utf-8 -*-
"""
列出可用模型的小工具
"""

import sys
import os
from pathlib import Path

# 添加项目路径
project_path = Path("/Users/mima0000/.openclaw/workspace/openclaw_upload")
sys.path.insert(0, str(project_path))

# 切换到项目目录
os.chdir(project_path)

import requests
import yaml

def load_config():
    config_path = project_path / "flash_longxia/config.yaml"
    with open(config_path, 'r', encoding='utf-8') as f:
        return yaml.safe_load(f)

def fetch_model_options(base_url: str, session, model_config_url: str = None) -> list[dict]:
    """获取视频模型配置列表。"""
    import json
    url = (model_config_url or f"{base_url}/api/v1/globalConfig/getModel").rstrip("/")
    resp = session.get(url, params={"modelType": 1}, timeout=15)
    data = resp.json()
    if data.get("code") not in (200, 0):
        raise RuntimeError(f"获取模型配置失败：{data}")
    items = data.get("data")
    if not isinstance(items, list):
        raise RuntimeError(f"模型配置返回格式异常：{data}")
    return items

def print_model_options(model_items: list[dict]) -> None:
    """打印模型及其支持的时长、比例。"""
    print("可用模型:", flush=True)
    for item in model_items:
        model_info = item.get("model") or {}
        model_value = str(model_info.get("value") or "").strip()
        model_label = str(model_info.get("label") or model_value).strip()
        if not model_value:
            continue

        durations = [
            str(opt.get("value"))
            for opt in item.get("time") or []
            if opt.get("value") is not None
        ]
        resolutions = [
            str(opt.get("value"))
            for opt in item.get("resolution") or []
            if opt.get("value")
        ]
        print(
            f"  - {model_value} ({model_label})"
            f" | durations={', '.join(durations) or '-'}"
            f" | aspectRatios={', '.join(resolutions) or '-'}",
            flush=True,
        )

def main():
    config = load_config()
    base_url = config["base_url"].rstrip('/')
    model_config_url = config.get("model_config_url", f"{base_url}/api/v1/globalConfig/getModel")

    # 读取token
    token_file = project_path / "flash_longxia/token.txt"
    token = token_file.read_text(encoding="utf-8").strip()

    session = requests.Session()
    session.headers.update({
        "token": token,
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Accept": "application/json",
    })

    try:
        model_items = fetch_model_options(base_url, session, model_config_url=model_config_url)
        print_model_options(model_items)
        return model_items
    except Exception as e:
        print(f'获取模型列表失败: {e}')
        return None

if __name__ == "__main__":
    main()