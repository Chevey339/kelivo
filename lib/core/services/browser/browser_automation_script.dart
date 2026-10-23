import 'dart:convert';

/// DOM automation runs inside the selected WebView. Values are JSON encoded,
/// never interpolated into JavaScript source as executable text.
abstract final class BrowserAutomationScript {
  static String build(String action, Map<String, dynamic> arguments) =>
      '(() => { const action = ${jsonEncode(action)}; '
      'const args = ${jsonEncode(arguments)}; $_implementation })()';

  static String evaluate(String script) =>
      '(async () => { try { const value = await (0, eval)(${jsonEncode(script)}); '
      'return JSON.stringify({ok:true, value:value === undefined ? null : value}); '
      '} catch (error) { return JSON.stringify({ok:false, '
      'error:String(error.message || error)}); } })()';

  static const _implementation = r'''
const key = '__kelivoBrowserAutomation';
let state = window[key];
if (!state || state.document !== document) {
  state = {document, refs:new Map(), observers:[], version:0, snapshotVersion:0};
  window[key] = state;
}
const fail = (message) => { throw new Error(message); };
const clean = (value, limit=200) => String(value || '').replace(/\s+/g, ' ').trim().slice(0, limit);
const roots = [];
const frameDocuments = [];
const visitRoot = (root) => {
  roots.push(root);
  for (const el of root.querySelectorAll('*')) {
    if (el.shadowRoot) visitRoot(el.shadowRoot);
    if (el.tagName === 'IFRAME') {
      try { if (el.contentDocument) { frameDocuments.push([el, el.contentDocument]); visitRoot(el.contentDocument); } } catch (_) {}
    }
  }
};
const ensureRoots = () => { if (!roots.length) visitRoot(document); };
const query = (selector) => {
  ensureRoots();
  const matches = roots.flatMap(root => Array.from(root.querySelectorAll(selector)));
  if (matches.length > 1) fail('ambiguous_selector: selector matched multiple elements; use a fresh snapshot ref');
  return matches[0];
};
const rect = (el) => {
  const r = el.getBoundingClientRect();
  let x = r.x, y = r.y, view = el.ownerDocument.defaultView;
  while (view && view !== window) {
    const frame = view.frameElement;
    if (!frame) break;
    const f = frame.getBoundingClientRect(); x += f.x; y += f.y;
    view = frame.ownerDocument.defaultView;
  }
  return {x:Math.round(x), y:Math.round(y), width:Math.round(r.width), height:Math.round(r.height)};
};
const visible = (el) => {
  const view = el.ownerDocument.defaultView;
  const style = view.getComputedStyle(el), r = rect(el);
  return style.display !== 'none' && style.visibility !== 'hidden' &&
    Number(style.opacity) !== 0 && r.width > 0 && r.height > 0 &&
    r.x + r.width > 0 && r.y + r.height > 0 && r.x < innerWidth && r.y < innerHeight;
};
const pointTarget = (x, y) => {
  let el = document.elementFromPoint(x, y);
  while (el) {
    if (el.shadowRoot) {
      const inner = el.shadowRoot.elementFromPoint(x, y);
      if (inner && inner !== el) { el = inner; continue; }
    }
    if (el.tagName === 'IFRAME') {
      try {
        const r = el.getBoundingClientRect();
        const child = el.contentDocument?.elementFromPoint(x-r.x, y-r.y);
        if (child) { x -= r.x; y -= r.y; el = child; continue; }
      } catch (_) {}
    }
    break;
  }
  return el;
};
const target = (optional=false) => {
  let el;
  if (args.ref) {
    if (state.snapshotUrl !== location.href || (state.frameDocuments || []).some(([frame, doc]) => frame.contentDocument !== doc)) {
      fail('stale_ref: page or frame navigated; take a fresh snapshot');
    }
    for (const observer of state.observers) {
      if (observer.takeRecords().length) state.version++;
    }
    if (state.version !== state.snapshotVersion) fail('stale_ref: page changed; take a fresh snapshot');
    el = state.refs.get(args.ref);
    if (!el || !el.isConnected) fail('stale_ref: ref is missing or detached; take a fresh snapshot');
  } else if (args.selector) {
    el = query(args.selector);
  } else if (Number.isFinite(args.x) && Number.isFinite(args.y)) {
    if (args.x < 0 || args.y < 0 || args.x >= innerWidth || args.y >= innerHeight) fail('coordinates_outside_viewport');
    el = pointTarget(args.x, args.y);
  } else if (optional) {
    return null;
  } else {
    fail('target_required: use a fresh snapshot ref, unique selector, or viewport x/y');
  }
  if (!el) fail('element_not_found');
  return el;
};
const editable = (el) => el && (el.matches('input:not([type=checkbox]):not([type=radio]):not([type=file]),textarea') || el.isContentEditable);
const setText = (el, value) => {
  const view = el.ownerDocument.defaultView;
  if (el.isContentEditable) el.textContent = value;
  else {
    const proto = el.tagName === 'TEXTAREA' ? view.HTMLTextAreaElement.prototype : view.HTMLInputElement.prototype;
    const setter = Object.getOwnPropertyDescriptor(proto, 'value')?.set;
    if (setter) setter.call(el, value); else el.value = value;
  }
  el.dispatchEvent(new view.InputEvent('input', {bubbles:true, inputType:'insertText', data:null}));
  el.dispatchEvent(new view.Event('change', {bubbles:true}));
};
const invalidate = () => { state.refs.clear(); state.version++; };
const page = () => ({url:location.href, title:document.title, viewport:{width:innerWidth,height:innerHeight}, scroll:{x:scrollX,y:scrollY}});
try {
  let result;
  switch (action) {
    case 'snapshot': {
      for (const observer of state.observers) observer.disconnect();
      state.observers = []; state.refs.clear();
      ensureRoots();
      const elements = [], selector = 'a[href],button,input:not([type=hidden]),textarea,select,summary,[role=button],[role=link],[role=textbox],[role=checkbox],[role=combobox],[role=tab],[contenteditable=true],[tabindex]';
      const candidates = roots.flatMap(root => Array.from(root.querySelectorAll(selector)));
      let count = 0;
      for (const el of candidates) {
        if (!visible(el)) continue;
        if (count >= (args.max_elements || 80)) break;
        const ref = `${args.snapshot_id}:e${count++}`;
        state.refs.set(ref, el);
        const tag = el.tagName.toLowerCase();
        const name = clean(el.getAttribute('aria-label') ||
          (el.labels ? Array.from(el.labels).map(l => l.innerText).join(' ') : '') ||
          el.innerText || el.getAttribute('placeholder') || el.getAttribute('title') || el.getAttribute('alt'));
        const entry = {ref,tag,role:el.getAttribute('role') || tag,name,rect:rect(el)};
        if (el.type) entry.type = el.type;
        if (el.disabled) entry.disabled = true;
        if ('checked' in el) entry.checked = el.checked;
        if ('value' in el && el.value) entry.value = el.type === 'password' ? '[redacted]' : clean(el.value);
        if (el.href && /^https?:/.test(el.href)) entry.href = el.href;
        elements.push(entry);
      }
      for (const root of roots) {
        const observer = new MutationObserver(() => { state.version++; });
        observer.observe(root, {subtree:true,childList:true,attributes:true,characterData:true});
        state.observers.push(observer);
      }
      state.snapshotVersion = state.version;
      state.snapshotUrl = location.href;
      state.frameDocuments = frameDocuments;
      result = {...page(),snapshot_id:args.snapshot_id,elements:args.include_elements === false ? [] : elements,
        truncated:candidates.length > elements.length,
        limitations:'Refs cover visible DOM elements, open shadow roots and same-origin frames. Cross-origin frames and trusted native input may need human control.'};
      if (args.include_text !== false) result.text = clean(document.body?.innerText, 4000);
      break;
    }
    case 'extract': {
      const root = document.querySelector('main,article,[role=main]') || document.body;
      if (!root) fail('page_not_ready');
      if (args.format === 'html') {
        const copy = root.cloneNode(true);
        copy.querySelectorAll('script,style,noscript,input[type=password]').forEach(el => el.remove());
        result = {...page(),format:'html',content:copy.outerHTML.slice(0,args.max_chars)};
      } else if (args.format === 'markdown') {
        const copy = root.cloneNode(true);
        copy.querySelectorAll('script,style,noscript').forEach(el => el.remove());
        copy.querySelectorAll('h1,h2,h3,h4,h5,h6').forEach(el => {el.textContent = '#'.repeat(Number(el.tagName[1]))+' '+el.textContent+'\n';});
        copy.querySelectorAll('a[href]').forEach(el => {
          const href = el.getAttribute('href');
          try { const url = new URL(href,location.href); if (/^https?:$/.test(url.protocol)) el.textContent = '['+clean(el.textContent)+']('+url.href+')'; } catch (_) {}
        });
        copy.querySelectorAll('p,div,section,article,li,pre,br').forEach(el => el.appendChild(document.createTextNode('\n')));
        result = {...page(),format:'markdown',content:copy.textContent.replace(/\n[ \t]+/g,'\n').replace(/\n{3,}/g,'\n\n').trim().slice(0,args.max_chars)};
      } else result = {...page(),format:'text',content:root.innerText.slice(0,args.max_chars)};
      break;
    }
    case 'click': {
      const el = target();
      if (!visible(el)) fail('element_not_visible');
      if (el.disabled) fail('element_disabled');
      const r = rect(el), x = Math.max(0,Math.min(innerWidth-1,r.x+r.width/2)), y = Math.max(0,Math.min(innerHeight-1,r.y+r.height/2));
      const hit = pointTarget(x,y);
      if (hit && hit !== el && !el.contains(hit)) fail('element_covered: dismiss the overlay and take a fresh snapshot');
      el.focus();
      if (args.button === 'right') el.dispatchEvent(new MouseEvent('contextmenu',{bubbles:true,cancelable:true,button:2,clientX:x,clientY:y}));
      else { el.click(); if (args.click_count === 2) { el.click(); el.dispatchEvent(new MouseEvent('dblclick',{bubbles:true,cancelable:true,detail:2})); } }
      invalidate(); result = {clicked:true}; break;
    }
    case 'type': {
      const el = target();
      if (!editable(el)) fail('element_not_editable');
      if (el.disabled || el.readOnly) fail('element_not_editable');
      el.focus();
      const old = el.isContentEditable ? el.textContent : el.value;
      setText(el, args.clear_first === false ? old + args.text : args.text);
      invalidate(); result = {typed:true,characters:args.text.length}; break;
    }
    case 'press': {
      const el = target(true) || document.activeElement || document.body;
      el.focus();
      const parts = args.key.split('+'), keyName = parts.pop();
      const init = {key:keyName,bubbles:true,cancelable:true,ctrlKey:parts.includes('Control'),metaKey:parts.includes('Meta'),altKey:parts.includes('Alt'),shiftKey:parts.includes('Shift')};
      const accepted = el.dispatchEvent(new KeyboardEvent('keydown',init));
      if (accepted) {
        if (keyName === 'Tab') {
          ensureRoots();
          const all = roots.flatMap(root => Array.from(root.querySelectorAll('a[href],button,input,textarea,select,[tabindex]'))).filter(e => visible(e) && !e.disabled && e.tabIndex >= 0);
          const next = all[(all.indexOf(el)+(init.shiftKey ? -1 : 1)+all.length)%all.length]; next?.focus();
        } else if ((init.ctrlKey || init.metaKey) && keyName.toLowerCase() === 'a' && typeof el.select === 'function') el.select();
        else if (keyName === 'Enter' && el.tagName === 'INPUT' && el.form) el.form.requestSubmit();
        else if (keyName === 'Enter' && el.matches('a,button,[role=button]')) el.click();
        else if (keyName === 'Backspace' && editable(el)) {
          const value = el.isContentEditable ? el.textContent : el.value;
          const start = el.selectionStart ?? value.length, end = el.selectionEnd ?? value.length;
          setText(el,value.slice(0,start === end ? Math.max(0,start-1) : start)+value.slice(end));
        }
      }
      el.dispatchEvent(new KeyboardEvent('keyup',init));
      invalidate(); result = {pressed:args.key,synthetic:true}; break;
    }
    case 'scroll': {
      let el = target(true), scroller = null;
      while (el && el !== el.ownerDocument.body) {
        const style = el.ownerDocument.defaultView.getComputedStyle(el);
        if (/(auto|scroll)/.test(style.overflowY+style.overflowX) && (el.scrollHeight>el.clientHeight || el.scrollWidth>el.clientWidth)) {scroller=el;break;}
        el = el.parentElement;
      }
      const amount = args.amount || 400, direction = args.direction || 'down';
      const left = direction === 'left' ? -amount : direction === 'right' ? amount : 0;
      const top = direction === 'up' ? -amount : direction === 'down' ? amount : 0;
      (scroller || window).scrollBy({left,top,behavior:'instant'});
      invalidate(); result = {...page(),scrolled:true}; break;
    }
    case 'wait': result = {ready:args.wait_for ? Boolean(query(args.wait_for)) : document.readyState !== 'loading'}; break;
    default: fail('unsupported_dom_action');
  }
  return JSON.stringify({ok:true,...result});
} catch (error) {
  return JSON.stringify({ok:false,error:String(error.message || error)});
}
''';
}
