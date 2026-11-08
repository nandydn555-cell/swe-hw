// Read-only smoke test against the configured public Supabase API.
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdir } from 'node:fs/promises';
const { chromium } = await import(process.env.PLAYWRIGHT_MODULE || 'playwright');
const server = spawn(process.execPath, ['node_modules/vite/bin/vite.js', '--host', '127.0.0.1', '--port', '4176', '--strictPort'], { stdio: 'pipe', windowsHide: true });
let browser;
try {
  await new Promise((resolve, reject) => { server.stdout.on('data', data => { if (String(data).includes('Local:')) resolve(); }); server.once('error', reject); server.once('exit', code => reject(new Error(`Vite exited ${code}`))); });
  browser = await chromium.launch({ channel: process.env.BROWSER_CHANNEL || 'msedge', headless: true });
  const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
  const errors = []; page.on('pageerror', error => errors.push(error.message));
  await page.goto('http://127.0.0.1:4176/');
  await page.locator('.art-card').first().waitFor();
  assert.ok(await page.locator('.art-card').count() >= 7);
  assert.equal(await page.locator('.person').count(), 10);
  assert.ok(await page.locator('.event-card').count() >= 5);
  await page.locator('.art-image').first().click();
  await page.locator('.detail-modal').waitFor();
  assert.equal(await page.locator('.owner-actions').count(), 0);
  await page.keyboard.press('Escape');
  await page.locator('.event-meta button').first().click();
  await page.locator('.gallery-grid img').first().waitFor();
  await page.locator('.gallery-grid img').first().evaluate(img => img.decode());
  await page.keyboard.press('Escape');
  await mkdir('tmp/qa', { recursive: true });
  for (const width of [1440, 768, 390, 360]) {
    await page.setViewportSize({ width, height: 1000 });
    await page.evaluate(() => scrollTo(0, 0));
    await page.screenshot({ path: `tmp/qa/live-${width}.png` });
    const size = await page.evaluate(() => ({ viewport: innerWidth, content: document.documentElement.scrollWidth }));
    assert.ok(size.content <= size.viewport, `overflow at ${width}`);
  }
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.locator('.people-grid').screenshot({ path: 'tmp/qa/live-teachers.png' });
  assert.deepEqual(errors, []);
  console.log('PASS: real Supabase content, seven exhibits, ten teachers, five events, gallery image loading, public permissions UI, four viewport widths, no browser exceptions.');
} finally { await browser?.close(); server.kill(); }
