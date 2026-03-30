const screenshot = require('screenshot-desktop');

screenshot().then((img) => {
  const fs = require('fs');
  fs.writeFileSync('/Users/mima0000/.openclaw/workspace/wechat-qr-screen.png', img);
  console.log('Screenshot saved!');
}).catch(err => console.error(err));
