// Save persistence in the browser: visit 1 saves a game, the browser is closed
// completely, visit 2 (same browser profile, like reopening the iPad app) checks
// that the save and the Continue button are still there.
//   node tools/web_save_test.js <url> <outdir>
const puppeteer = require(process.env.PUPPETEER_PATH || 'puppeteer-core');
const fs = require('fs');
const path = require('path');
const [url, out] = process.argv.slice(2);
fs.mkdirSync(out, { recursive: true });
const profile = path.join(out, 'chrome-profile');

async function visit(mode) {
  const browser = await puppeteer.launch({
    executablePath: process.env.CHROME || '/usr/bin/google-chrome', headless: true, userDataDir: profile,
    args: ['--no-sandbox', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--window-size=1366,1024'],
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1366, height: 1024 });
  let done = false, fails = 0;
  page.on('console', async (msg) => {
    const t = msg.text();
    if (t.includes('AUTOTEST') || t.includes('SCRIPT ERROR')) console.log(`[${mode}] ${t}`);
    if (t.includes('AUTOTEST FAIL') || t.includes('SCRIPT ERROR')) fails++;
    const m = t.match(/AUTOTEST SHOT (\S+)/);
    if (m) { try { await page.screenshot({ path: path.join(out, `web_${m[1]}.png`) }); } catch (e) {} }
    if (t.includes('AUTOTEST SUMMARY')) done = true;
  });
  await page.goto(`${url}?autotest=${mode}`, { waitUntil: 'load', timeout: 120000 });
  const limit = Date.now() + 900000;
  while (!done && Date.now() < limit) await new Promise((r) => setTimeout(r, 1000));
  await browser.close();   // the whole browser goes away, as when the app is closed
  return done && fails === 0;
}

(async () => {
  fs.rmSync(profile, { recursive: true, force: true });
  const a = await visit('websave1');
  const b = await visit('websave2');
  console.log(`WEBSAVE visit1=${a} visit2=${b}`);
  process.exit(a && b ? 0 : 1);
})();
