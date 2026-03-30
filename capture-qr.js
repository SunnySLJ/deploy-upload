const puppeteer = require('puppeteer');

(async () => {
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  
  const page = await browser.newPage();
  await page.setViewport({ width: 1200, height: 800 });
  await page.goto('https://channels.weixin.qq.com/platform/post/create', {
    waitUntil: 'networkidle2',
    timeout: 30000
  });
  
  // Wait for QR code to load
  await page.waitForSelector('.wx_qrcode', { timeout: 10000 }).catch(() => {});
  await new Promise(r => setTimeout(r, 3000));
  
  await page.screenshot({
    path: '/Users/mima0000/.openclaw/workspace/wechat-qr.png',
    fullPage: false
  });
  
  await browser.close();
  console.log('QR code screenshot saved to wechat-qr.png');
})();
