// Run with: node test/native/browser_workspace_navigation_test.mjs
// Exercise the shipped WebView2 guard with each platform's real URL scheme.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const source = fs.readFileSync(new URL('../../lib/core/services/browser/browser_workspace_app.dart', import.meta.url), 'utf8');
const guard = source.slice(source.indexOf('  // WebView2 can replace'), source.indexOf('  const newDocumentId'));
assert.ok(guard.length > 0);

for (const [platform, windows, scheme] of [
  ['Windows', true, 'kelivo'],
  ['Android', false, 'https'],
  ['Apple', false, 'kelivo'],
]) {
  const base = `${scheme}://app-fixture.invalid/notes.app.html`;
  const listeners = new Map(), navigations = [];
  class Anchor {
    constructor(href) {
      this.url = new URL(href, base);
      this.clicks = 0;
    }
    get protocol() { return this.url.protocol; }
    click() { this.clicks++; }
  }
  const window = {navigation: {addEventListener: (_, handler) => navigations.push(handler)}};
  vm.runInNewContext(guard.replaceAll('$windows', String(windows)), {
    window, URL, HTMLAnchorElement: Anchor,
    addEventListener: (name, handler) => listeners.set(name, handler),
  });
  const click = href => {
    const link = new Anchor(href);
    let prevented = false;
    listeners.get('click')?.({composedPath: () => [link], preventDefault: () => prevented = true});
    link.click();
    return {prevented, clicks: link.clicks};
  };
  const navigate = href => {
    let prevented = false;
    for (const handler of navigations) {
      handler({destination: {url: new URL(href, base).href}, preventDefault: () => prevented = true});
    }
    return prevented;
  };
  for (const href of ['#settings', '#', `${base}#notes`]) {
    assert.deepEqual(click(href), {prevented: false, clicks: 1}, `${platform}: local anchor ${href}`);
    assert.equal(navigate(href), false, `${platform}: same-document navigation ${href}`);
  }
  if (windows) {
    for (const href of ['http://example.com/download', 'https://example.com/navigation']) {
      assert.deepEqual(click(href), {prevented: true, clicks: 0}, `Windows: network link ${href}`);
      assert.equal(navigate(href), true, `Windows: network navigation ${href}`);
    }
  }
}
console.log('Workspace navigation guards preserve local anchors and block Windows network departures.');
