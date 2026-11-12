// Run with: node test/native/browser_history_observer_test.mjs
// Exercise the shipped observer, not a reimplementation of its event rules.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const source = fs.readFileSync(new URL('../../lib/core/services/browser/browser_native_engine.dart', import.meta.url), 'utf8');
const script = source.match(/const browserHistoryObserverScript = r'''([\s\S]*?)''';/)[1];
const listeners = new Map(), timers = [], calls = [];
const window = {flutter_inappwebview: {callHandler: async (...args) => calls.push(args)}};
const history = {pushState: () => 'pushed', replaceState: () => 'replaced'};
const context = vm.createContext({window, history, performance: {timeOrigin: 100},
  addEventListener: (name, handler) => listeners.set(name, handler),
  setTimeout: handler => timers.push(handler)});
vm.runInContext(script, context);
const state = window.__kelivoBrowserHistoryDocument;
assert.equal(state.traversal, 0);
assert.ok(state.id);
assert.equal(history.pushState({}, '', '/next'), 'pushed');
assert.equal(history.replaceState({}, '', '/next'), 'replaced');
assert.equal(timers.length, 1, 'batch consecutive History API changes');
assert.equal(state.traversal, 0, 'push/replace is not traversal completion');
timers.shift()();
assert.deepEqual(calls, [['kelivoBrowserHistory']]);
listeners.get('popstate')({isTrusted: false});
assert.equal(state.traversal, 0, 'synthetic events do not acknowledge traversal');
listeners.get('popstate')({isTrusted: true});
assert.equal(state.traversal, 1);
listeners.get('hashchange')({isTrusted: true});
assert.equal(state.traversal, 2);
assert.equal(timers.length, 1);
timers.shift()();
vm.runInContext(script, context);
assert.equal(window.__kelivoBrowserHistoryDocument, state, 'reattach retains document identity');
assert.equal(state.traversal, 2);
console.log('Browser history observer event checks passed.');
