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
  assert.equal((await run('click',{ref:old})).ok,true); checks++;
  snap = await snapshot();
  assert.equal((await run('click',{ref:snap.elements.find(el=>el.name==='Change').ref})).ok,true);
  assert.equal(await page.locator('#status').innerText(),'changed');
  assert.equal((await run('click',{ref:snap.elements.find(el=>el.name==='Change').ref})).ok,true); checks++;
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
  await page.setContent(`<main><div id="ticker">0</div><input id="value" placeholder="Hint only">
    <input id="reject" oninput="this.value=''">
    <input id="date" type="date"><input id="readonly" readonly>
    <select id="choice"><option value="a">One</option><option value="b">Two</option><option disabled value="c">Three</option></select>
    <a id="link" href="https://example.com/a">Stable link</a><button id="replace">Before</button></main>`);
  snap = await snapshot();
  const valueRef = snap.elements.find(e=>e.placeholder==='Hint only').ref;
  await page.locator('#ticker').evaluate(el=>el.textContent='1');
  assert.equal((await run('type',{ref:valueRef,text:'hello'})).verified,true);
  assert.equal((await run('type',{ref:valueRef,text:' again',clear_first:false})).verified,true); checks++;
  assert.match((await run('type',{selector:'#reject',text:'no'})).error,/input_value_rejected/);
  assert.match((await run('type',{selector:'#date',text:'invalid date'})).error,/input_value_rejected/);
  assert.match((await run('type',{selector:'#readonly',text:'no'})).error,/element_not_editable/); checks++;
  assert.equal((await run('select_option',{selector:'#choice',option_label:'Two'})).value,'b');
  assert.match((await run('select_option',{selector:'#choice',option_value:'c'})).error,/option_disabled/); checks++;
  snap = await snapshot();
  const linkRef = snap.elements.find(e=>e.tag==='a').ref;
  await page.locator('#link').evaluate(el=>el.href='https://example.com/b');
  assert.match((await run('click',{ref:linkRef})).error,/stale_ref/);
  const replacedRef = snap.elements.find(e=>e.name==='Before').ref;
  await page.locator('#replace').evaluate(el=>el.outerHTML='<button id="replace">Before</button>');
  assert.match((await run('click',{ref:replacedRef})).error,/stale_ref/); checks++;
  await page.setContent('<main><p>'+ 'x'.repeat(2200) +'</p>'+Array.from({length:12},(_,i)=>`<button>Item ${i}</button>`).join('')+'<button style="display:none">Hidden</button></main>');
  const first = await run('extract',{format:'text',max_chars:1000});
  const rest = await run('extract',{format:'text',max_chars:30000,offset:first.next_offset});
  assert.equal(first.truncated,true); assert.equal(rest.truncated,false);
  assert.equal(first.content.length+rest.content.length,first.total_chars); checks++;
  snap = await snapshot({max_elements:5,include_text:false});
  const second = await snapshot({max_elements:20,include_text:false,offset:snap.next_offset});
  assert.equal(snap.elements.length,5); assert.equal(second.elements.length,7);
  assert.equal(second.truncated,false); assert.equal(second.next_offset,null); checks++;
  await page.locator('main').evaluate(el=>el.innerHTML='<a href="https://example.com/?q='+ 'a'.repeat(12000)+'">Long</a>');
  snap = await snapshot();
  assert.equal(snap.elements[0].href.length,512); assert.equal(snap.elements[0].href_truncated,true);
  assert.ok(JSON.stringify(snap).length<2000); checks++;
  assert.equal((await snapshot({include_elements:false})).truncated,false); checks++;
  await page.setContent('<div contenteditable="true" id="editor">Draft</div>');
  const editor = (await snapshot()).elements[0].ref;
  assert.equal((await run('type',{ref:editor,text:'New draft'})).verified,true);
  assert.equal((await run('press',{ref:editor,key:'Enter'})).ok,true); checks++;
  await page.setContent('<button id="far" style="margin-top:2000px" onclick="this.dataset.clicked=1">Far</button>');
  assert.equal((await run('click',{selector:'#far'})).ok,true);
  assert.equal(await page.locator('#far').getAttribute('data-clicked'),'1');
  assert.ok(await page.evaluate(()=>scrollY)>0); checks++;
  // A previously visible ref remains usable after scrolling out of view.
  const farRef = (await snapshot()).elements[0].ref;
  await page.evaluate(()=>scrollTo(0,0));
  assert.equal((await run('click',{ref:farRef})).ok,true); checks++;
  await page.setContent('<div id="box" style="height:100px;overflow:auto"><input id="deep" style="margin-top:600px"></div>');
  assert.equal((await run('type',{selector:'#deep',text:'scrolled'})).verified,true);
  assert.equal(await page.locator('#deep').inputValue(),'scrolled');
  assert.ok(await page.locator('#box').evaluate(el=>el.scrollTop)>0); checks++;
  await page.setContent('<iframe style="margin-top:2000px" srcdoc="<select id=choice style=margin-top:500px><option value=a>A</option><option value=b>B</option></select>"></iframe>');
  await page.locator('iframe').contentFrame().locator('select').waitFor({state:'attached'});
  assert.equal((await run('select_option',{selector:'#choice',option_value:'b'})).verified,true); checks++;
  await page.setContent('<button id="blocked" onclick="window.badClick=true">Blocked</button><div style="position:fixed;inset:0;background:gray;z-index:99"></div>');
  assert.match((await run('click',{selector:'#blocked'})).error,/element_covered/);
  assert.equal(await page.evaluate(()=>window.badClick),undefined); checks++;
  await page.setContent('<button id="replaceScroll" style="margin-top:2000px">Replace</button>');
  await page.evaluate(()=>addEventListener('scroll',()=>{
    document.querySelector('#replaceScroll').outerHTML='<button id="replaceScroll" style="margin-top:2000px" onclick="window.badScrollClick=true">Replace</button>';
  },{once:true}));
  assert.match((await run('click',{selector:'#replaceScroll'})).error,/stale_ref/);
  assert.equal(await page.evaluate(()=>window.badScrollClick),undefined); checks++;
  await page.setContent('<button style="width:200px;height:60px" onclick="window.coordsClicked=true">Here</button><div style="height:2000px"></div>');
  await page.evaluate(()=>scrollTo(0,0));
  assert.equal((await run('click',{x:20,y:20})).ok,true);
  assert.equal(await page.evaluate(()=>scrollY),0);
  assert.equal(await page.evaluate(()=>window.coordsClicked),true);
  assert.equal((await run('click',{selector:'button'})).ok,true);
  assert.equal(await page.evaluate(()=>scrollY),0); checks++;
  console.log(`PASS: ${checks} browser automation checks in ${await browser.version()}`);
} finally { await browser.close(); }
