// Run with: node test/native/browser_viewport_anchor_test.mjs
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const source = fs.readFileSync(new URL('../../lib/core/services/browser/browser_viewport_anchor.dart', import.meta.url), 'utf8');
const script = source.match(/const browserViewportAnchorScript = r'''([\s\S]*?)''';/)[1];
const listeners = new Map();
const root = {scrollHeight: 2000};
let contentResize;
let contentMutation;
const moves = [];
const document = {
  scrollingElement: root, documentElement: root, body: {}, readyState: 'complete',
  activeElement: null,
  addEventListener(name, handler) { listeners.set(name, handler); },
};
const window = {
  innerHeight: 687, innerWidth: 390, scrollY: 0, scrollX: 0,
  addEventListener(name, handler) { listeners.set(name, handler); },
  scrollTo(value) { this.scrollY = value.top; moves.push(value); },
};
window.top = window;
vm.runInNewContext(script, {
  document, window,
  ResizeObserver: class {
    constructor(callback) { contentResize = callback; }
    observe() {}
  },
  MutationObserver: class {
    constructor(callback) { contentMutation = callback; }
    observe() {}
  },
});
const event = name => listeners.get(name)?.();
const scroll = value => { window.scrollY = value; event('scroll'); };
const resize = (height, content = root.scrollHeight) => {
  window.innerHeight = height;
  root.scrollHeight = content;
  event('resize');
};

// Page load and content growth at the top cannot pin a new document to its end.
contentResize();
resize(721, 2040);
assert.equal(window.scrollY, 0);
assert.equal(moves.length, 0);

// Viewport-relative document growth is measured after reflow.
scroll(2040 - 721);
resize(687, 1972);
assert.equal(window.scrollY, 1972 - 687);
assert.equal(moves.at(-1).behavior, 'instant');
resize(721, 2040);
assert.equal(window.scrollY, 2040 - 721);

// Ordinary appended content updates the baseline, never sticks to the new end.
const beforeAppend = window.scrollY;
root.scrollHeight += 240;
contentResize();
assert.equal(window.scrollY, beforeAppend);
const beforeResize = moves.length;
resize(687);
assert.equal(window.scrollY, beforeAppend);
assert.equal(moves.length, beforeResize);

// Absolute overflow can grow scrollHeight without any root/body box resize.
scroll(root.scrollHeight - window.innerHeight);
const beforeOverflowAppend = window.scrollY;
root.scrollHeight += 240;
contentMutation();
resize(721);
assert.equal(window.scrollY, beforeOverflowAppend);

// An asynchronously loaded image can grow that same overflow after insertion.
scroll(root.scrollHeight - window.innerHeight);
const beforeImageLoad = window.scrollY;
root.scrollHeight += 200;
event('load');
resize(687);
assert.equal(window.scrollY, beforeImageLoad);

// Middle-of-page reading, top bounce and keyboard caret avoidance retain control.
scroll(300);
resize(721);
assert.equal(window.scrollY, 300);
scroll(-20);
resize(687);
assert.equal(window.scrollY, -20);

// Insets may preserve a reading position beyond the new end. Clamp only after
// CSS reflow, when viewport-relative content has its final height.
root.scrollHeight = 2044;
scroll(1337);
resize(746);
assert.equal(window.scrollY, 1298);
resize(687);
assert.equal(window.scrollY, 1357, 'the newly reached footer remains anchored');
root.scrollHeight = 1418;
scroll(711);
resize(746, 1536);
assert.equal(window.scrollY, 711, 'dvh content growth must preserve a legal reading position');
resize(687, 1418);
assert.equal(window.scrollY, 711);

// A gesture can move the document in the same frame as a toolbar resize.
// Do not restore the previous offset over a new, still-valid user position.
scroll(300);
window.scrollY = 340;
resize(721);
assert.equal(window.scrollY, 340);

scroll(root.scrollHeight - window.innerHeight);
document.activeElement = {tagName: 'INPUT', type: 'text'};
const beforeKeyboard = window.scrollY;
resize(387);
assert.equal(window.scrollY, beforeKeyboard, 'keyboard resize must let WebKit reveal the focused field');
document.activeElement = null;

// BFCache restoration establishes a fresh baseline instead of reviving an old anchor.
window.scrollY = 100;
event('pageshow');
resize(687);
assert.equal(window.scrollY, 100);
console.log('Viewport anchor: resize/reflow, append, reading, bounce, keyboard and restoration passed');
