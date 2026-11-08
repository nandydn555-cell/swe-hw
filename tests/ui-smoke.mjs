// Isolated headless UI regression tests. Supabase requests are mocked: this
// verifies browser behavior, not production RLS. Never reads a personal profile.
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdir } from 'node:fs/promises';
const { chromium } = await import(process.env.PLAYWRIGHT_MODULE || 'playwright');
const port = 4175;
const server = spawn(process.execPath, ['node_modules/vite/bin/vite.js', '--host', '127.0.0.1', '--port', String(port), '--strictPort'], { stdio: 'pipe', windowsHide: true });
let browser;
try {
  await new Promise((resolve, reject) => { server.stdout.on('data', data => { if (String(data).includes('Local:')) resolve(); }); server.once('error', reject); server.once('exit', code => reject(new Error(`Vite exited ${code}`))); });
  browser = await chromium.launch({ channel: process.env.BROWSER_CHANNEL || 'msedge', headless: true });
  const context = await browser.newContext({ viewport: { width: 1440, height: 1000 } });
  const page = await context.newPage();
  const errors = []; page.on('pageerror', error => errors.push(error.message));
  let identity = null;
  const users = { admin: { id: '11111111-1111-4111-8111-111111111111', email: 'admin@example.test' }, student: { id: '22222222-2222-4222-8222-222222222222', email: 'student@example.test' } };
  const db = {
    profiles: Object.entries(users).map(([role, u]) => ({ ...u, role: role === 'admin' ? 'admin' : 'creator', display_name: role, bio: '', avatar_url: '' })),
    exhibits: [{ id: 'server-work', title: 'Server React project', description: 'A real server fixture', category: 'Технологи', creator_id: users.student.id, technology_stack: ['React', 'Python'], year_created: 2026, status: 'published', image_url: '' }],
    teachers: [{ id: 'server-teacher', name: 'Server Teacher', position: 'Teacher', courses: ['Web'], bio: 'Teacher bio', photo_url: '/teachers/ganbold.jpg' }],
    events: [{ id: 'server-event', title: 'Server Event', event_date: '2026-03-26', description: 'Event description', cover_image_url: '/events/projects-2026-cover.jpg' }],
    event_photos: [], time_capsules: [], exhibition_categories: []
  };
  const patches = [];
  await context.route('**/*.supabase.co/**', async route => {
    const request = route.request(), url = new URL(request.url()), method = request.method();
    const json = (body, status = 200) => route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body) });
    if (url.pathname.includes('/auth/v1/token')) {
      const credentials = request.postDataJSON(); identity = credentials.email.startsWith('admin') ? 'admin' : 'student';
      const user = { ...users[identity], aud: 'authenticated', role: 'authenticated', app_metadata: {}, user_metadata: {}, created_at: new Date().toISOString() };
      const token = `${Buffer.from('{}').toString('base64url')}.${Buffer.from(JSON.stringify({ sub: user.id, exp: Math.floor(Date.now()/1000)+3600 })).toString('base64url')}.signature`;
      return json({ access_token: token, refresh_token: 'test-refresh', token_type: 'bearer', expires_in: 3600, user });
    }
    if (url.pathname.includes('/auth/v1/logout')) { identity = null; return json({}); }
    if (url.pathname.includes('/auth/v1/user')) return json(users[identity]);
    if (url.pathname.includes('/rest/v1/rpc/is_admin')) return json(identity === 'admin');
    if (url.pathname.includes('/storage/v1/object/')) return json({ Key: 'test-object' });
    const table = url.pathname.split('/rest/v1/')[1];
    if (!db[table]) return json({ message: 'Unexpected test request' }, 400);
    const matches = row => [...url.searchParams].every(([key, value]) => !value.startsWith('eq.') || String(row[key]) === value.slice(3));
    let rows = db[table].filter(matches);
    if (table === 'exhibits' && identity !== 'admin') rows = rows.filter(row => row.status === 'published' || row.creator_id === users[identity]?.id);
    if (method === 'GET') return json(request.headers().accept?.includes('vnd.pgrst.object') ? rows[0] : rows);
    if (method === 'POST') { const input = request.postDataJSON(); rows = (Array.isArray(input) ? input : [input]).map(row => ({ id: crypto.randomUUID(), ...row })); db[table].push(...rows); }
    if (method === 'PATCH') { const patch = request.postDataJSON(); patches.push({ table, patch }); rows.forEach(row => Object.assign(row, patch)); }
    if (method === 'DELETE') db[table] = db[table].filter(row => !rows.includes(row));
    return json(request.headers().accept?.includes('vnd.pgrst.object') ? rows[0] : rows);
  });
  await page.goto(`http://127.0.0.1:${port}/`);
  await page.locator('.art-card').first().waitFor();
  assert.equal(await page.locator('.art-card').count(), 1, 'server records must not be padded with static archive');
  await page.getByPlaceholder('Бүтээл, бүтээгч, сэдэв, оноор хайх...').fill('unmatched-query');
  await page.getByText('Илэрц олдсонгүй', { exact: true }).waitFor();
  await page.getByPlaceholder('Бүтээл, бүтээгч, сэдэв, оноор хайх...').fill('');
  await page.locator('.art-image').first().click();
  assert.equal(await page.locator('.owner-actions').count(), 0);
  await page.keyboard.press('Escape');
  async function login(role) {
    await page.getByRole('button', { name: 'Нэвтрэх', exact: true }).first().click();
    await page.locator('input[name=email]').fill(users[role].email);
    await page.locator('input[name=password]').fill('test-password');
    await page.locator('.form-modal button[type=submit], .form-modal .submit').click();
    await page.getByRole('button', { name: /Гарах/ }).waitFor();
  }
  await login('admin');
  await page.locator('#admin').waitFor();
  await page.locator('.admin-row').filter({ hasText: 'Server React project' }).getByRole('button', { name: 'Засах', exact: true }).click();
  assert.equal(await page.locator('.admin-form').getByLabel('Технологи', { exact: true }).inputValue(), 'React, Python');
  await page.locator('.admin-form textarea').fill('Edited by admin');
  await page.locator('.admin-form').getByRole('button', { name: /Өөрчлөлт хадгалах/ }).click();
  await page.getByText('Өгөгдлийг хадгаллаа.', { exact: true }).waitFor();
  assert.deepEqual(patches.find(p => p.table === 'exhibits').patch.technology_stack, ['React', 'Python']);
  await page.locator('.event-meta button').first().click();
  await page.locator('.gallery-upload input[type=file]').setInputFiles('public/events/projects-2026-cover.jpg');
  await page.locator('.gallery-upload').getByLabel('Тайлбар', {exact:true}).fill('Uploaded gallery test');
  await page.locator('.gallery-upload button').click();
  await page.locator('.gallery-grid').getByText('Uploaded gallery test', {exact:true}).waitFor();
  page.once('dialog', dialog => dialog.accept('Edited caption'));
  await page.locator('.gallery-actions').getByRole('button', {name:'Тайлбар засах'}).click();
  await page.locator('.gallery-grid').getByText('Edited caption', {exact:true}).waitFor();
  page.once('dialog', dialog => dialog.accept());
  await page.locator('.gallery-actions').getByRole('button', {name:'Зураг устгах'}).click();
  await page.getByText('Энэ цомогт зураг хараахан алга', {exact:true}).waitFor();
  assert.equal(db.event_photos.length,0);
  await page.keyboard.press('Escape');
  await page.locator('.admin-tabs').getByRole('button', { name: 'Багш', exact: true }).click();
  page.once('dialog', dialog => dialog.accept());
  await page.locator('.admin-row').filter({ hasText: 'Server Teacher' }).getByRole('button', { name: 'Устгах', exact: true }).click();
  await page.getByText('Өгөгдлийг устгалаа.', { exact: true }).waitFor();
  await page.reload(); await page.locator('#admin').waitFor();
  assert.equal(await page.locator('.person').count(), 0, 'deleted teachers must stay deleted on reload');
  await page.getByRole('button', { name: /Гарах/ }).click();
  await login('student');
  await page.locator('.student-work').waitFor();
  await page.locator('.student-profile').getByLabel('Нэр', {exact:true}).fill('Student updated');
  await page.locator('.student-profile .submit').click();
  await page.getByText('Оюутны профайлыг хадгаллаа.',{exact:true}).waitFor();
  assert.equal(db.profiles.find(p=>p.id===users.student.id).display_name,'Student updated');
  await page.locator('.student-work').getByRole('button', { name: 'Засах', exact: true }).click();
  await page.locator('.form-modal textarea').fill('Student revision');
  await page.locator('.form-modal .submit').click();
  await page.getByText('Бүтээлийг шинэчиллээ.', { exact: true }).waitFor();
  assert.equal(db.exhibits[0].status, 'pending', 'published owner edits must return to moderation');
  assert.equal(await page.locator('.art-card').count(), 0, 'pending revision must leave the public collection');
  await page.locator('.student-work-image').click();
  page.once('dialog', dialog => dialog.accept());
  await page.locator('.owner-actions').getByRole('button', { name: 'Устгах', exact: true }).click();
  await page.getByText('Бүтээлийг устгалаа.', { exact: true }).waitFor();
  assert.equal(db.exhibits.length, 0);
  await page.getByRole('button', { name: /Гарах/ }).click();
  await login('admin'); await page.locator('#admin').waitFor();
  await page.getByRole('button', { name: 'Архив оруулах', exact: true }).click();
  await page.locator('.toast').filter({ hasText: 'Архив хадгаллаа:' }).waitFor({ timeout: 60000 });
  assert.equal(db.exhibits.length, 7); assert.equal(db.teachers.length, 10);
  assert.ok(db.event_photos.length >= 7);
  await page.getByRole('button',{name:'Захиа үлдээх',exact:true}).click();
  await page.locator('textarea[name=message]').fill('A note for the future');
  await page.locator('input[name=author]').fill('Test author');
  await page.locator('.form-modal .submit').click();
  await page.getByText('Таны захиа цагийн капсулд хадгалагдлаа.',{exact:true}).waitFor();
  await page.locator('.capsule-review').getByRole('button',{name:'Нийтлэх',exact:true}).click();
  await page.locator('.capsule-review').getByRole('button',{name:'Нуух',exact:true}).waitFor();
  assert.equal(db.time_capsules[0].approved,true);
  const before = [db.exhibits.length, db.teachers.length, db.event_photos.length];
  await page.getByRole('button', { name: 'Архив оруулах', exact: true }).click();
  await page.locator('.toast').filter({ hasText: '0 багш, 0 үйл явдал, 0 бүтээл, 0 зураг' }).waitFor();
  assert.deepEqual([db.exhibits.length, db.teachers.length, db.event_photos.length], before);
  await mkdir('tmp/qa', { recursive: true });
  for (const width of [1440, 768, 390, 360]) {
    await page.setViewportSize({ width, height: 1000 });
    await page.evaluate(()=>scrollTo(0,0));
    await page.screenshot({ path: `tmp/qa/museum-${width}.png`, fullPage: true });
    const size = await page.evaluate(() => ({ viewport: innerWidth, content: document.documentElement.scrollWidth }));
    assert.ok(size.content <= size.viewport, `horizontal overflow at ${width}: ${size.content}`);
  }
  assert.deepEqual(errors, []);
  console.log('PASS: browse, search, dialogs, admin array edit, gallery upload/edit/delete, profile update, persistent deletion, owner revision/delete, capsule moderation, archive import/retry, responsive overflow; no browser exceptions.');
} finally { await browser?.close(); server.kill(); }
