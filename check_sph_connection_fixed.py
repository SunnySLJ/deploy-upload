#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
检查视频号连接状态
"""
import asyncio
import os
import sys
from pathlib import Path

# 添加项目路径
_PROJECT_ROOT = Path(__file__).parent / "xiaolong-upload"
sys.path.insert(0, str(_PROJECT_ROOT))

# 添加子目录到路径
sys.path.insert(0, str(_PROJECT_ROOT / "platforms"))
sys.path.insert(0, str(_PROJECT_ROOT / "platforms" / "shipinhao_upload"))

async def check_shipinhao_connection():
    """检查视频号连接状态"""
    print("正在检查视频号连接状态...")
    
    # 检查Chrome进程是否运行
    import subprocess
    result = subprocess.run(['pgrep', '-f', 'remote-debugging-port=9226'], 
                          capture_output=True, text=True)
    if result.returncode == 0:
        print("✓ Chrome进程正在运行（端口9226）")
        print(f"  进程ID: {result.stdout.strip()}")
    else:
        print("✗ Chrome进程未运行（端口9226）")
        return False

    # 尝试连接到现有Chrome实例
    try:
        import nodriver as uc
        from shipinhao.browser import attach_login_chrome
        
        # 尝试连接现有的Chrome实例
        print("\n正在尝试连接到现有Chrome实例...")
        browser, tab = await attach_login_chrome()
        
        print("✓ 成功连接到Chrome实例")
        
        # 检查当前页面URL
        current_url = tab.url
        print(f"当前页面URL: {current_url}")
        
        # 判断是否在登录页面
        if "login" in current_url.lower() or "mp.weixin.qq.com" in current_url.lower():
            print("✗ 当前状态：需要登录（重定向到登录页面）")
            is_logged_in = False
        elif "post/create" in current_url.lower() or "channels.weixin.qq.com" in current_url.lower():
            print("✓ 当前状态：已在视频号平台页面")
            is_logged_in = True
        else:
            print("? 当前状态：未知页面")
            is_logged_in = False
            
        # 不关闭浏览器，因为它已经在运行
        print("\n保持浏览器连接状态...")
        return is_logged_in
        
    except ImportError as e:
        print(f"导入模块错误: {e}")
        return False
    except Exception as e:
        print(f"连接视频号时出错: {e}")
        print("这可能是因为Chrome实例尚未完全加载或页面状态不稳定")
        return False

if __name__ == "__main__":
    # 在事件循环中运行异步函数
    is_connected = asyncio.run(check_shipinhao_connection())
    print(f"\n最终结果: {'连接正常' if is_connected else '连接异常或需要重新登录'}")