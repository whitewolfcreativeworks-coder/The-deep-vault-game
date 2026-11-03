// Browser test for the web build: loads builds/web/index.html?autotest=<mode>
// in Chrome via puppeteer-core, relays the game's AUTOTEST console lines and
// screenshots the page whenever the game reports a shot. Optionally emulates
// an iPad (touch, 1366x1024 viewport).
//   node tools/web_test.js <url> <mode> <outdir> [ipad]
const puppeteer = require(process.env.PUPPETEER_PATH || 'puppeteer-core');
const fs = require('fs');
const path = require('path');

(async () => {
  const [url, mode, out, device] = process.argv.slice(2);
  fs.mkdirSync(out, { recursive: true });
  const browser = await puppeteer.launch({
    executablePath: process.env.CHROME || '/usr/bin/google-chrome',
    headless: true,
    args: ['--no-sandbox', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist',
      '--autoplay-policy=no-user-gesture-required', '--window-size=1366,1024'],
  });
  const page = await browser.newPage();
  if (device === 'ipad') {
    await page.setViewport({ width: 1366, height: 1024, isMobile: true, hasTouch: true, deviceScaleFactor: 1 });
    await page.setUserAgent('Mozilla/5.0 (iPad; CPU OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1');
  } else {
    await page.setViewport({ width: 1366, height: 768 });
  }
  let done = false, shots = 0, errors = [];
  const t0 = Date.now();
  page.on('console', async (msg) => {
    const t = msg.text();
    if (t.includes('AUTOTEST') || t.includes('ERROR') || t.includes('SCRIPT')) console.log(`[${((Date.now() - t0) / 1000).toFixed(0)}s] ${t}`);
    if (t.includes('SCRIPT ERROR') || t.includes('USER ERROR')) errors.push(t);
    const m = t.match(/AUTOTEST SHOT (\S+)/);
    if (m) {
      shots++;
      try { await page.screenshot({ path: path.join(out, `web_${m[1]}.png`) }); } catch (e) {}
    }
    if (t.includes('AUTOTEST SUMMARY')) done = true;
  });
  page.on('pageerror', (e) => { console.log('PAGEERROR', e.message); errors.push(e.message); });
  await page.goto(`${url}?autotest=${mode}`, { waitUntil: 'load', timeout: 120000 });
  // Godot's default shell starts on load; take an early screenshot of the boot progress
  await new Promise((r) => setTimeout(r, 8000));
  await page.screenshot({ path: path.join(out, 'web_boot.png') });
  const limit = Date.now() + (parseInt(process.env.WEB_TEST_TIMEOUT || '1500') * 1000);
  while (!done && Date.now() < limit) await new Promise((r) => setTimeout(r, 1000));
  await page.screenshot({ path: path.join(out, 'web_final.png') });
  console.log(`WEBTEST done=${done} shots=${shots} errors=${errors.length} seconds=${((Date.now() - t0) / 1000).toFixed(0)}`);
  await browser.close();
  process.exit(done ? 0 : 1);
})();
