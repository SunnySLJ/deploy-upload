const puppeteer = require('puppeteer');

(async () => {
  const browser = await puppeteer.launch({ 
    headless: 'new', 
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage'] 
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1920, height: 1080 });
  await page.goto('https://channels.weixin.qq.com/platform/post/create', { 
    waitUntil: 'networkidle2', 
    timeout: 30000 
  });
  await new Promise(r => setTimeout(r, 3000));
  await page.screenshot({ 
    path: '/Users/mima0000/.openclaw/workspace/qr-code.png',
    fullPage: false 
  });
  await browser.close();
  console.log('QR code saved!');
})();
