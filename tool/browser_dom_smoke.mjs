// Real Chromium coverage for the exact JavaScript embedded in the Dart tool.
// Usage: KELIVO_PLAYWRIGHT_MODULE=/path/to/playwright node tool/browser_dom_smoke.mjs
// Optional: KELIVO_CHROME_EXECUTABLE=/path/to/chrome
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
const require = createRequire(import.meta.url);
const {chromium} = require(process.env.KELIVO_PLAYWRIGHT_MODULE || 'playwright');
const source = readFileSync(new URL('../lib/core/services/browser/browser_automation_script.dart', import.meta.url),'utf8');
const implementation = source.match(/static const _implementation = r'''([\s\S]*?)''';/)[1];
const browser = await chromium.launch({
  executablePath:process.env.KELIVO_CHROME_EXECUTABLE || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  headless:true,
});
let checks = 0, snapshotId = 0;
try {
  const page = await browser.newPage({viewport:{width:1000,height:900}});
  await page.setContent(`<!doctype html><title>Browser fixture</title>
    <main><h1>Fixture article</h1><p>Readable content <a href="https://example.com/docs">Docs</a></p>
    <form onsubmit="event.preventDefault(); document.querySelector('#status').textContent='submitted'">
      <label>Name<input id="name" value="old"></label>
      <label>Password<input id="password" type="password" value="do-not-leak"></label>
      <button id="submit" type="submit">Submit</button>
    </form><button id="change" onclick="document.querySelector('#status').textContent='changed'">Change</button>
    <div id="status">ready</div><div id="shadow"></div>
    <iframe id="frame" srcdoc="<button onclick='this.textContent=&quot;Frame clicked&quot;'>Frame action</button>"></iframe>
    <script>window.fixtureSecret = 'script-not-readable';</script></main>`);
  await page.evaluate(() => {document.querySelector('#shadow').attachShadow({mode:'open'}).innerHTML='<input aria-label="Shadow input">';});
  await page.locator('#frame').contentFrame().getByRole('button').waitFor();
  const run = async (action,args={}) => JSON.parse(await page.evaluate(
    `(() => {const action=${JSON.stringify(action)};const args=${JSON.stringify(args)};${implementation}})()`));
  const snapshot = (args={}) => run('snapshot',{snapshot_id:`test${++snapshotId}`,max_elements:80,...args});
  let snap = await snapshot();
  assert.equal(snap.ok,true); assert.equal(JSON.stringify(snap).includes('do-not-leak'),false);
  assert.equal(snap.elements.find(el=>el.type==='password').value,'[redacted]'); checks++;
  assert.match(snap.text,/Readable content/);
  assert.equal(snap.text.includes('script-not-readable'),false); checks++;
  assert.equal(Object.hasOwn(await snapshot({include_text:false}),'text'),false); checks++;
  snap = await snapshot();
  const old = snap.elements.find(el=>el.name==='Change').ref;
  await page.evaluate(()=>{document.querySelector('#status').textContent='external mutation';});
  assert.match((await run('click',{ref:old})).error,/stale_ref/); checks++;
  snap = await snapshot();
  assert.equal((await run('click',{ref:snap.elements.find(el=>el.name==='Change').ref})).ok,true);
  assert.equal(await page.locator('#status').innerText(),'changed');
  assert.match((await run('click',{ref:snap.elements.find(el=>el.name==='Change').ref})).error,/stale_ref/); checks++;
  assert.equal((await run('type',{selector:'#name',text:'Kelivo',clear_first:true})).ok,true);
  assert.equal(await page.locator('#name').inputValue(),'Kelivo');
  await run('type',{selector:'#name',text:' browser',clear_first:false});
  assert.equal(await page.locator('#name').inputValue(),'Kelivo browser'); checks++;
  assert.match((await run('click',{selector:'button'})).error,/ambiguous_selector/); checks++;
  assert.match((await run('click',{x:1001,y:10})).error,/coordinates_outside_viewport/); checks++;
  await page.evaluate(()=>{const overlay=document.createElement('div');overlay.id='overlay';overlay.style='position:fixed;inset:0;z-index:999;background:white';document.body.append(overlay);});
  assert.match((await run('click',{selector:'#change'})).error,/element_covered/);
  await page.locator('#overlay').evaluate(el=>el.remove()); checks++;
  snap = await snapshot();
  assert.equal((await run('type',{ref:snap.elements.find(el=>el.name==='Shadow input').ref,text:'shadow works'})).ok,true);
  assert.equal(await page.getByRole('textbox',{name:'Shadow input'}).inputValue(),'shadow works'); checks++;
  snap = await snapshot();
  assert.equal((await run('click',{ref:snap.elements.find(el=>el.name==='Frame action').ref})).ok,true);
  assert.equal(await page.locator('#frame').contentFrame().getByRole('button').innerText(),'Frame clicked'); checks++;
  const markdown = await run('extract',{format:'markdown',max_chars:16000});
  assert.match(markdown.content,/# Fixture article/); assert.match(markdown.content,/\[Docs\]\(https:\/\/example.com\/docs\)/);
  assert.equal(markdown.content.includes('script-not-readable'),false); checks++;
  const html = await run('extract',{format:'html',max_chars:16000});
  assert.equal(html.content.includes('do-not-leak'),false); assert.equal(html.content.includes('<script'),false); checks++;
  await run('press',{selector:'#name',key:'Enter'});
  assert.equal(await page.locator('#status').innerText(),'submitted'); checks++;
  snap = await snapshot();
  assert.match(snap.text,/submitted/);
  assert.equal(snap.elements.some(el=>el.name==='submitted'),false); checks++;
  await page.evaluate(()=>{location.hash='new-location';});
  assert.match((await run('click',{ref:snap.elements[0].ref})).error,/stale_ref/); checks++;
  snap = await snapshot();
  await page.locator('#frame').evaluate(el=>{el.srcdoc='<button>Replacement frame</button>';});
  await page.locator('#frame').contentFrame().getByRole('button',{name:'Replacement frame'}).waitFor();
  assert.match((await run('click',{ref:snap.elements.find(el=>el.name==='Frame clicked').ref})).error,/stale_ref/); checks++;
  await page.setContent('<button>New document</button>');
  assert.match((await run('click',{ref:snap.elements[0].ref})).error,/stale_ref/); checks++;
  await page.evaluate(()=>{const text=document.createElement('p');text.textContent='x'.repeat(5000);document.body.append(text);});
  assert.equal((await snapshot()).text.length,4000); checks++;
  console.log(`PASS: ${checks} browser automation checks in ${await browser.version()}`);
} finally { await browser.close(); }
