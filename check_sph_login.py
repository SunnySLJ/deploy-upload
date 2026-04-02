#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
检查视频号登录状态
"""
import asyncio
import os
from pathlib import Path

# 添加项目路径
_PROJECT_ROOT = Path(__file__).parent / "xiaolong-upload"
if str(_PROJECT_ROOT) not in os.sys.path:
    os.sys.path.insert(0, str(_PROJECT_ROOT))

async def check_shipinhao_login():
    """检查视频号登录状态"""
    print("正在检查视频号登录状态...")
    
    try:
        from platforms.shipinhao_upload.common import check_login_status
        # 调用检查登录状态的函数
        is_logged_in = await check_login_status()
        
        if is_logged_in:
            print("✓ 视频号已登录")
        else:
            print("✗ 视频号未登录或会话已过期")
        
        return is_logged_in
        
    except ImportError:
        # 如果上面的模块不存在，我们尝试另一种方法
        print("正在使用备用方法检查视频号登录状态...")
        
        try:
            # 检查cookie文件是否存在
            from platforms.shipinhao_upload.conf import COOKIES_DIR
            account_file = str(COOKIES_DIR / "shipinhao_default.json")
            
            if os.path.exists(account_file):
                print(f"✓ Cookie文件存在: {account_file}")
            else:
                print(f"✗ Cookie文件不存在: {account_file}")
                
            # 检查Chrome进程是否在运行
            import subprocess
            result = subprocess.run(['pgrep', '-f', 'remote-debugging-port=9226'], 
                                  capture_output=True, text=True)
            if result.returncode == 0:
                print("✓ Chrome进程正在运行（端口9226）")
            else:
                print("✗ Chrome进程未运行（端口9226）")
                
            # 尝试连接浏览器
            try:
                import nodriver
                from platforms.shipinhao_upload.conf import CDP_ENDPOINT
                
                # 连接到现有的Chrome实例
                browser = await nodriver.start(
                    browser_args=[f'--remote-debugging-port=9226', 
                                 '--user-data-dir=/Users/mima0000/.openclaw/workspace/xiaolong-upload/cookies/chrome_connect_sph']
                )
                
                # 访问视频号页面
                tab = await browser.get('https://channels.weixin.qq.com/platform/post/create')
                await tab.sleep(3)
                
                # 检查URL是否为登录页面
                current_url = tab.url.lower()
                if 'login' in current_url or 'passport' in current_url:
                    print("✗ 当前状态：需要登录（重定向到登录页面）")
                    is_logged_in = False
                else:
                    print("✓ 当前状态：已登录（未重定向到登录页面）")
                    is_logged_in = True
                
                # 不关闭浏览器，因为它已经在运行
                print("保持浏览器连接状态...")
                return is_logged_in
                
            except Exception as e:
                print(f"连接浏览器时出错: {e}")
                return False
                
        except Exception as e:
            print(f"检查过程中出现错误: {e}")
            import traceback
            traceback.print_exc()
            return False

if __name__ == "__main__":
    # 在事件循环中运行异步函数
    is_logged_in = asyncio.run(check_shipinhao_login())
    print(f"\n最终结果: {'已登录' if is_logged_in else '未登录'}")