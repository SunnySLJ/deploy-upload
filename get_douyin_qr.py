#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import time
import os

# 设置Chrome选项，连接到现有的调试端口
chrome_options = Options()
chrome_options.add_experimental_option('debuggerAddress', '127.0.0.1:9224')

# 创建WebDriver实例
driver = webdriver.Chrome(options=chrome_options)

# 导航到抖音创作者中心
driver.get('https://creator.douyin.com/creator-micro/content/upload')

# 等待页面加载
time.sleep(5)

# 等待登录相关的元素出现
try:
    # 等待页面完全加载
    WebDriverWait(driver, 10).until(
        EC.presence_of_element_located((By.TAG_NAME, "body"))
    )
    
    # 截图整个页面
    screenshot_path = '/Users/mima0000/.openclaw/workspace/xiaolong-upload/douyin_login_screenshot.png'
    driver.save_screenshot(screenshot_path)
    print(f'已保存抖音登录页面截图到: {screenshot_path}')
    
    # 尝试多种方式找到二维码
    qr_found = False
    
    # 方法1: 尝试查找二维码相关的class或id
    qr_selectors = [
        "div.qr-code", "div.login-qr", "div.qrcode", ".qr-code", ".login-qr", ".qrcode",
        "[class*='qr'][class*='code']", "[class*='login'][class*='qr']"
    ]
    
    for selector in qr_selectors:
        try:
            elements = driver.find_elements(By.CSS_SELECTOR, selector)
            if elements:
                for i, element in enumerate(elements):
                    # 创建安全的文件名
                    safe_selector = selector.replace('.', '_').replace('[', '_').replace(']', '_').replace(' ', '_').replace('-', '_')
                    element.screenshot(f'/Users/mima0000/.openclaw/workspace/xiaolong-upload/douyin_qr_code_{safe_selector}_{i}.png')
                    print(f'已保存二维码到: /Users/mima0000/.openclaw/workspace/xiaolong-upload/douyin_qr_code_{safe_selector}_{i}.png')
                    qr_found = True
        except:
            continue
    
    # 方法2: 查找包含登录或扫码文本的按钮或区域
    if not qr_found:
        text_selectors = [
            "//*[contains(text(), '登录') or contains(text(), '扫码') or contains(text(), '二维码') or contains(text(), 'QR')]",
            "//button[contains(text(), '登录') or contains(text(), '扫码')]",
            "//span[contains(text(), '登录') or contains(text(), '扫码')]"
        ]
        
        for selector in text_selectors:
            try:
                elements = driver.find_elements(By.XPATH, selector)
                if elements:
                    for i, element in enumerate(elements):
                        element.screenshot(f'/Users/mima0000/.openclaw/workspace/xiaolong-upload/douyin_login_element_{i}.png')
                        print(f'已保存登录元素截图: /Users/mima0000/.openclaw/workspace/xiaolong-upload/douyin_login_element_{i}.png')
                        qr_found = True
            except:
                continue
    
    # 方法3: 如果仍未找到，查找图片元素中可能包含二维码的
    if not qr_found:
        try:
            img_elements = driver.find_elements(By.TAG_NAME, 'img')
            for i, img in enumerate(img_elements):
                src = img.get_attribute('src')
                alt = img.get_attribute('alt')
                class_attr = img.get_attribute('class')
                
                # 检查图片属性是否与二维码相关
                if src and ('qrcode' in src.lower() or 'qr' in src.lower()):
                    img.screenshot(f'/Users/mima0000/.openclaw/workspace/xiaolong-upload/douyin_potential_qr_{i}.png')
                    print(f'发现潜在二维码图片: /Users/mima0000/.openclaw/workspace/xiaolong-upload/douyin_potential_qr_{i}.png')
                    qr_found = True
                
                if alt and ('二维码' in alt or 'qr' in alt.lower() or 'qrcode' in alt.lower()):
                    img.screenshot(f'/Users/mima0000/.openclaw/workspace/xiaolong-upload/douyin_alt_based_qr_{i}.png')
                    print(f'基于alt文本的二维码图片: /Users/mima0000/.openclaw/workspace/xiaolong-upload/douyin_alt_based_qr_{i}.png')
                    qr_found = True
                    
                if class_attr and ('qr' in class_attr.lower() or 'qrcode' in class_attr.lower()):
                    img.screenshot(f'/Users/mima0000/.openclaw/workspace/xiaolong-upload/douyin_class_based_qr_{i}.png')
                    print(f'基于class的二维码图片: /Users/mima0000/.openclaw/workspace/xiaolong-upload/douyin_class_based_qr_{i}.png')
                    qr_found = True
        except:
            pass
    
    if not qr_found:
        print('未能在页面上定位到明显的二维码元素，但已保存页面截图')
    
except Exception as e:
    print(f'操作过程中出错: {str(e)}')
    # 出错时也保存截图
    driver.save_screenshot('/Users/mima0000/.openclaw/workspace/xiaolong-upload/douyin_error_screenshot.png')
    print('已保存错误时的页面截图')

driver.quit()