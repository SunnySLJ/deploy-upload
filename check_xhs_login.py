#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
检查小红书登录状态
"""
import asyncio
import os
from pathlib import Path

# 添加项目路径
_PROJECT_ROOT = Path(__file__).parent / "xiaolong-upload"
if str(_PROJECT_ROOT) not in os.sys.path:
    os.sys.path.insert(0, str(_PROJECT_ROOT))

from platforms.xhs_upload.api import upload_to_xiaohongshu

async def check_xiaohongshu_login():
    """检查小红书登录状态"""
    print("正在检查小红书登录状态...")
    
    # 检查cookie文件是否存在
    from conf import COOKIES_DIR
    account_file = str(COOKIES_DIR / "xiaohongshu_default.json")
    
    if os.path.exists(account_file):
        print(f"✓ Cookie文件存在: {account_file}")
    else:
        print(f"✗ Cookie文件不存在: {account_file}")
    
    # 尝试连接浏览器并检查登录状态
    try:
        from xiaohongshu.main import _check_logged_in
        from xiaohongshu.browser import get_browser
        
        # 获取浏览器实例
        res = await get_browser(headless=False, account_name="default", try_reuse=True)
        browser, was_reused = res if isinstance(res, tuple) else (res, False)
        
        print(f"浏览器连接状态: {'已复用' if was_reused else '新建'}")
        
        # 检查登录状态
        logged_in, tab = await _check_logged_in(browser, account_file, "default")
        
        if logged_in:
            print("✓ 小红书已登录")
        else:
            print("✗ 小红书未登录或会话已过期")
            
        # 清理资源
        if not was_reused:
            browser.stop()
        
        return logged_in
        
    except Exception as e:
        print(f"检查过程中出现错误: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    # 在事件循环中运行异步函数
    is_logged_in = asyncio.run(check_xiaohongshu_login())
    print(f"\n最终结果: {'已登录' if is_logged_in else '未登录'}")