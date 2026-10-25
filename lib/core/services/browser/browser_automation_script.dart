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
  state = {document, refs:new Map()};
  window[key] = state;
}
const fail = (message) => { throw new Error(message); };
const clean = (value, limit=200) => String(value || '').replace(/\s+/g, ' ').trim().slice(0, limit);
const roots = [];
const visitRoot = (root) => {
  roots.push(root);
  for (const el of root.querySelectorAll('*')) {
    if (el.shadowRoot) visitRoot(el.shadowRoot);
    if (el.tagName === 'IFRAME') {
      try { if (el.contentDocument) { visitRoot(el.contentDocument); } } catch (_) {}
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
    const f = frame.getBoundingClientRect(); x += f.x + frame.clientLeft; y += f.y + frame.clientTop;
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
        const dx = r.x + el.clientLeft, dy = r.y + el.clientTop;
        const child = el.contentDocument?.elementFromPoint(x-dx, y-dy);
        if (child) { x -= dx; y -= dy; el = child; continue; }
      } catch (_) {}
    }
    break;
  }
  return el;
};
const target = (optional=false) => {
  let el;
  if (args.ref) {
    const saved = state.refs.get(args.ref);
    if (!saved || !saved.el.isConnected || saved.document !== saved.el.ownerDocument ||
        state.snapshotUrl !== location.href) fail('stale_ref: element or page changed; take a fresh snapshot');
    el = saved.el;
    try {
      let view = saved.document.defaultView;
      if (!view || view.document !== saved.document) fail('stale_ref');
      while (view !== window) {
        const frame = view.frameElement;
        if (!frame?.isConnected) fail('stale_ref');
        view = frame.ownerDocument.defaultView;
      }
    } catch (_) { fail('stale_ref: frame navigated; take a fresh snapshot'); }
    if (saved.identity !== identity(el)) fail('stale_ref: element identity changed; take a fresh snapshot');
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
const editable = (el) => el && (el.matches('textarea') || el.isContentEditable ||
  (el.tagName === 'INPUT' && !['checkbox','radio','file','button','submit','reset','image','hidden','range','color'].includes(el.type)));
const semanticName = el => clean(el.getAttribute('aria-label') ||
  (el.labels ? Array.from(el.labels).map(l => l.innerText).join(' ') : '') ||
  (el.matches('input,textarea,select') || el.isContentEditable ? '' : el.innerText) || el.getAttribute('title') || el.getAttribute('alt'));
const identity = el => JSON.stringify([el.tagName, el.id, el.getAttribute('name'), el.getAttribute('role'), el.type, el.href, semanticName(el)]);
const inputValue = el => el.isContentEditable ? el.textContent : el.value;
const inputFrame = () => new Promise(resolve => {
  let frame, timer;
  const done = () => { cancelAnimationFrame(frame); clearTimeout(timer); resolve(); };
  frame = requestAnimationFrame(done);
  timer = setTimeout(done, 50);
});
// Check the element's local viewport and clipping ancestors, including
// same-origin frames. Already visible targets do not scroll or wait a frame.
const clipped = el => {
  const r = el.getBoundingClientRect(), view = el.ownerDocument.defaultView;
  if (r.top < 0 || r.left < 0 || r.bottom > view.innerHeight || r.right > view.innerWidth) return true;
  let parent = el.parentElement || el.getRootNode().host;
  while (parent) {
    const style = view.getComputedStyle(parent), p = parent.getBoundingClientRect();
    if (/(auto|scroll|hidden|clip)/.test(style.overflowY) && (r.top < p.top || r.bottom > p.bottom)) return true;
    if (/(auto|scroll|hidden|clip)/.test(style.overflowX) && (r.left < p.left || r.right > p.right)) return true;
    parent = parent.parentElement || parent.getRootNode().host;
  }
  return view !== window && view.frameElement ? clipped(view.frameElement) : false;
};
const prepareTarget = async () => {
  const el = target(), originalIdentity = identity(el);
  const coordinate = Number.isFinite(args.x) && Number.isFinite(args.y);
  if (!coordinate && clipped(el)) {
    el.scrollIntoView({block:'nearest',inline:'nearest',behavior:'instant'});
    let view = el.ownerDocument.defaultView;
    while (view && view !== window) {
      const frame = view.frameElement;
      if (!frame) break;
      frame.scrollIntoView({block:'nearest',inline:'nearest',behavior:'instant'});
      view = frame.ownerDocument.defaultView;
    }
    await inputFrame();
    roots.length = 0;
    if (!el.isConnected || target() !== el || identity(el) !== originalIdentity) {
      fail('stale_ref: target changed while scrolling; take a fresh snapshot');
    }
  }
  if (!visible(el)) fail('element_not_visible');
  const r = rect(el);
  const x = coordinate ? args.x : Math.max(0,Math.min(innerWidth-1,r.x+r.width/2));
  const y = coordinate ? args.y : Math.max(0,Math.min(innerHeight-1,r.y+r.height/2));
  const hit = pointTarget(x,y);
  if (!hit || (hit !== el && !el.contains(hit))) fail('element_covered: dismiss the overlay and take a fresh snapshot');
  return {el,x,y};
};
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
const page = () => ({url:location.href, title:document.title, viewport:{width:innerWidth,height:innerHeight}, scroll:{x:scrollX,y:scrollY}});
try {
  let result;
  switch (action) {
    case 'snapshot': {
      state.refs.clear();
      ensureRoots();
      const elements = [], selector = 'a[href],button,input:not([type=hidden]),textarea,select,summary,[role=button],[role=link],[role=textbox],[role=checkbox],[role=combobox],[role=tab],[contenteditable=true],[tabindex]';
      const candidates = args.include_elements === false ? [] : roots.flatMap(root => Array.from(root.querySelectorAll(selector)));
      const offset = args.offset || 0, budget = args.max_chars || 16000;
      const fullText = args.include_text === false ? '' : (document.body?.innerText || '').replace(/\s+/g,' ').trim();
      const text = fullText.slice(0,Math.min(4000,Math.floor(budget/2)));
      let count = 0, seen = 0, used = text.length, more = false;
      for (const el of candidates) {
        if (!visible(el)) continue;
        if (seen++ < offset) continue;
        if (count >= (args.max_elements || 80)) { more = true; break; }
        const ref = `${args.snapshot_id}:e${count}`;
        const tag = el.tagName.toLowerCase();
        const name = semanticName(el) || clean(el.getAttribute('placeholder'));
        const entry = {ref,tag,role:el.getAttribute('role') || tag,name,rect:rect(el)};
        if (el.type) entry.type = el.type;
        if (el.disabled) entry.disabled = true;
        if (el.readOnly) entry.readonly = true;
        if (el.hasAttribute('placeholder')) entry.placeholder = clean(el.getAttribute('placeholder'));
        if ('checked' in el) entry.checked = el.checked;
        if ('value' in el) entry.value = el.type === 'password' ? '[redacted]' : clean(el.value);
        if (el.href && /^(https?|kelivo):/.test(el.href)) {
          entry.href = el.href.slice(0,512);
          if (el.href.length > 512) { entry.href_truncated = true; entry.href_length = el.href.length; }
        }
        if (el.tagName === 'SELECT') entry.options = Array.from(el.options).slice(0,30).map(o => ({value:clean(o.value),label:clean(o.label),selected:o.selected,disabled:o.disabled}));
        const length = JSON.stringify(entry).length;
        if (used + length > budget) {
          if (!count) fail('snapshot_budget_too_small: increase max_chars or disable include_text');
          more = true; break;
        }
        state.refs.set(ref, {el, document:el.ownerDocument, identity:identity(el)});
        elements.push(entry); count++; used += length;
      }
      state.snapshotUrl = location.href;
      result = {...page(),snapshot_id:args.snapshot_id,elements:args.include_elements === false ? [] : elements,
        truncated:more, offset, next_offset:more && count ? offset+count : null,
        limitations:'Refs identify unchanged elements in the current document, open shadow roots and same-origin frames. Detached or repurposed elements require a new snapshot. Cross-origin frames and trusted native input may need human control.'};
      if (args.include_text !== false) { result.text = text; result.text_truncated = fullText.length > text.length; }
      break;
    }
    case 'extract': {
      const root = document.querySelector('main,article,[role=main]') || document.body;
      if (!root) fail('page_not_ready');
      let content;
      if (args.format === 'html') {
        const copy = root.cloneNode(true);
        copy.querySelectorAll('script,style,noscript,input[type=password]').forEach(el => el.remove());
        content = copy.outerHTML;
      } else if (args.format === 'markdown') {
        const copy = root.cloneNode(true);
        copy.querySelectorAll('script,style,noscript').forEach(el => el.remove());
        copy.querySelectorAll('h1,h2,h3,h4,h5,h6').forEach(el => {el.textContent = '#'.repeat(Number(el.tagName[1]))+' '+el.textContent+'\n';});
        copy.querySelectorAll('a[href]').forEach(el => {
          const href = el.getAttribute('href');
          try { const url = new URL(href,location.href); if (/^https?:$/.test(url.protocol)) el.textContent = '['+clean(el.textContent)+']('+url.href+')'; } catch (_) {}
        });
        copy.querySelectorAll('p,div,section,article,li,pre,br').forEach(el => el.appendChild(document.createTextNode('\n')));
        content = copy.textContent.replace(/\n[ \t]+/g,'\n').replace(/\n{3,}/g,'\n\n').trim();
      } else content = root.innerText;
      const offset = args.offset || 0, end = Math.min(content.length, offset + args.max_chars);
      result = {...page(),format:args.format,content:content.slice(offset,end),offset,
        truncated:end < content.length,total_chars:content.length,next_offset:end < content.length ? end : null};
      break;
    }
    case 'click': {
      result = (async () => {
        const {el,x,y} = await prepareTarget();
        if (el.disabled) fail('element_disabled');
        el.focus({preventScroll:true});
        if (args.button === 'right') el.dispatchEvent(new MouseEvent('contextmenu',{bubbles:true,cancelable:true,button:2,clientX:x,clientY:y}));
        else { el.click(); if (args.click_count === 2) { el.click(); el.dispatchEvent(new MouseEvent('dblclick',{bubbles:true,cancelable:true,detail:2})); } }
        return {clicked:true};
      })(); break;
    }
    case 'type': {
      result = (async () => {
        const {el} = await prepareTarget();
        if (!editable(el) || el.disabled || el.readOnly) fail('element_not_editable');
        el.focus({preventScroll:true});
        const desired = args.clear_first === false ? inputValue(el) + args.text : args.text;
        setText(el, desired);
        await inputFrame();
        if (!el.isConnected) fail('input_target_replaced: input was replaced; inspect the page before retrying');
        if (inputValue(el) !== desired) fail('input_value_rejected: field did not retain the requested value; check its format or page validation before retrying');
        return {typed:true,verified:true,characters:args.text.length};
      })(); break;
    }
    case 'select_option': {
      result = (async () => {
        const {el} = await prepareTarget();
        if (el.tagName !== 'SELECT' || el.disabled) fail('element_not_selectable');
        const matches = Array.from(el.options).filter(o => args.option_value !== undefined ? o.value === args.option_value : o.label === args.option_label);
        if (matches.length !== 1) fail(matches.length ? 'ambiguous_option' : 'option_not_found');
        if (matches[0].disabled || matches[0].parentElement.disabled) fail('option_disabled');
        for (const option of el.options) option.selected = option === matches[0];
        const view = el.ownerDocument.defaultView;
        el.dispatchEvent(new view.Event('input',{bubbles:true}));
        el.dispatchEvent(new view.Event('change',{bubbles:true}));
        await inputFrame();
        if (!el.isConnected || el.value !== matches[0].value) fail('input_value_rejected: selection was reset by the page');
        return {selected:true,verified:true,value:clean(el.value),label:clean(matches[0].label)};
      })(); break;
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
      result = {pressed:args.key,synthetic:true}; break;
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
      result = {...page(),scrolled:true}; break;
    }
    case 'wait': result = {...page(),ready:args.wait_for ? Boolean(query(args.wait_for)) : document.readyState !== 'loading'}; break;
    default: fail('unsupported_dom_action');
  }
  const success = data => JSON.stringify({ok:true,...data});
  return result instanceof Promise ? result.then(success, error => JSON.stringify({ok:false,error:String(error.message || error)})) : success(result);
} catch (error) {
  return JSON.stringify({ok:false,error:String(error.message || error)});
}
''';
}
