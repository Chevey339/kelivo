// Run with: node test/native/browser_scroll_observer_test.mjs
// Execute the shipped document observer with trusted input and frame delivery
// controlled separately, as WebKit does during scroll deceleration.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const source = fs.readFileSync(new URL('../../lib/core/services/browser/browser_scroll_observer.dart', import.meta.url), 'utf8');
const script = source.match(/const browserScrollObserverScript = r'''([\s\S]*?)''';/)[1];
const listeners = new Map();
const frames = new Map();
const updates = [];
let frameId = 0;
let now = 0;
const document = {
  documentElement: {clientHeight: 800, scrollHeight: 3000},
  body: {scrollHeight: 3000},
  onscrollend: null,
  addEventListener(name, handler) { listeners.set(name, handler); },
};
const window = {
  document, innerHeight: 800, scrollY: 0,
  getComputedStyle(element) { return {overflowY: element.overflowY}; },
  flutter_inappwebview: {callHandler: async (_, value) => { updates.push(value); return true; }},
  addEventListener(name, handler) { listeners.set(name, handler); },
};
window.top = window;
vm.runInNewContext(script, {
  window, document, performance: {timeOrigin: 1, now: () => now},
  requestAnimationFrame(handler) { frames.set(++frameId, handler); return frameId; },
  cancelAnimationFrame(id) { frames.delete(id); },
});
await Promise.resolve();
const dispatch = (type, rest = {}) => listeners.get(type)?.({type, isTrusted: true, target: document, ...rest});
const touch = (type, x, y, rest = {}) => dispatch(type, {touches: type === 'touchend' || type === 'touchcancel' ? [] : [{clientX: x, clientY: y}], ...rest});
const frame = (elapsed = 64) => {
  now += elapsed;
  for (const [id, handler] of [...frames]) { frames.delete(id); handler(now); }
};
const last = () => updates.at(-1);

touch('touchstart', 100, 200); frame();
assert.equal(last().isUserInteracting, true);
touch('touchmove', 100, 160);
window.scrollY = 40; dispatch('scroll'); frame();
assert.equal(last().gestureDelta, 40);
assert.equal(last().offset, 40);
assert.equal(last().isUserInteracting, true);
assert.equal(last().phase, 'update');
touch('touchend');
assert.equal(last().isUserInteracting, false);
assert.equal(last().gestureDelta, 0);
window.scrollY = 100; dispatch('scroll'); frame();
assert.equal(last().isUserInteracting, false, 'native momentum is not finger input');
assert.equal(last().gestureDelta, 0);

// A pending native momentum frame must be consumed as baseline at touch-down.
window.scrollY = 400; dispatch('scroll');
touch('touchstart', 100, 200);
assert.equal(last().offset, 400);
assert.equal(last().phase, 'metrics');
assert.equal(last().gestureDelta, 0);
frame();
assert.equal(last().phase, 'metrics');
touch('touchend');

window.scrollY = 2200;
touch('touchstart', 100, 200); frame();
touch('touchmove', 100, 150); frame();
assert.equal(last().offset, 2200, 'scrollY is pinned at the document boundary');
assert.equal(last().gestureDelta, 50, 'manual input still reaches the toolbar');
touch('touchmove', 100, 120);
touch('touchcancel');
assert.equal(last().gestureDelta, 0, 'cancellation discards the queued move');
assert.equal(last().isUserInteracting, false);

window.scrollY = -80; dispatch('scroll'); frame();
window.scrollY = 20; dispatch('scroll'); frame();
assert.equal(last().isUserInteracting, false, 'rubber-band recovery remains passive');
touch('touchstart', 100, 200); frame();
const horizontalCount = updates.length;
touch('touchmove', 40, 199); frame();
assert.equal(updates.length, horizontalCount, 'horizontal carousel does not create vertical intent');
touch('touchend');
touch('touchstart', 100, 200, {isTrusted: false});
touch('touchmove', 100, 100, {isTrusted: false}); frame();
assert.equal(last().isUserInteracting, false, 'synthetic events cannot impersonate input');
touch('touchstart', 100, 200, {touches: [{clientX: 100, clientY: 200}, {clientX: 200, clientY: 200}]}); frame();
assert.equal(last().isUserInteracting, false, 'pinch gestures do not control the toolbar');

// A short flick can end before the compositor delivers any scroll position.
// Its explicit finger delta must survive the end flush separately from the
// later passive offset; the Flutter consumer cannot rely only on scrollY.
window.scrollY = 500;
touch('touchstart', 100, 200); frame();
touch('touchmove', 100, 176);
const releaseIndex = updates.length;
touch('touchend');
assert.equal(updates[releaseIndex].offset, 500);
assert.equal(updates[releaseIndex].gestureDelta, 24);
assert.equal(updates[releaseIndex].isUserInteracting, true);
assert.equal(last().isUserInteracting, false);
window.scrollY = 524; dispatch('scroll'); frame();
assert.equal(last().offset, 524);
assert.equal(last().gestureDelta, 0);
assert.equal(last().isUserInteracting, false);
const momentumStart = updates.length;
for (let i = 0; i < 120; i++) {
  window.scrollY += 1;
  dispatch('scroll');
  frame(1000 / 120);
}
const momentumMessages = updates.length - momentumStart;
assert.ok(momentumMessages <= 16, `120 momentum frames sent ${momentumMessages} messages`);
dispatch('scrollend');
assert.equal(last().offset, window.scrollY, 'scroll end immediately delivers final geometry');
touch('touchstart', 100, 200);
touch('touchmove', 100, 190); frame(8);
touch('touchmove', 100, 180); frame(8);
assert.equal(last().gestureDelta, 20, 'coalescing retains every finger delta');
touch('touchmove', 100, 170); frame(4);
touch('touchend');
assert.equal(updates.at(-2).gestureDelta, 10, 'release bypasses the frame budget');
assert.equal(last().isUserInteracting, false);


// Full-height apps often scroll an inner element, not window/document.
const nested = {clientHeight: 600, scrollHeight: 2400, scrollTop: 100,
  overflowY: 'auto', isConnected: true, parentElement: document.body};
const child = {parentElement: nested};
touch('touchstart', 100, 200, {target: child});
assert.equal(last().viewportExtent, 600);
assert.equal(last().contentExtent, 2400);
touch('touchmove', 100, 160, {target: child});
nested.scrollTop = 140;
dispatch('scroll', {target: nested}); frame();
assert.equal(last().offset, 140);
assert.equal(last().gestureDelta, 40);
touch('touchend');
nested.scrollTop = 200;
dispatch('scroll', {target: nested}); frame();
assert.equal(last().offset, 200);
assert.equal(last().isUserInteracting, false);
dispatch('scrollend', {target: nested});
assert.equal(last().phase, 'end');
touch('touchstart', 100, 200);
assert.equal(last().offset, window.scrollY, 'a root gesture resets nested metrics');
touch('touchend');

console.log(`Browser scroll observer checks passed; 120 momentum frames -> ${momentumMessages} bridge updates.`);
