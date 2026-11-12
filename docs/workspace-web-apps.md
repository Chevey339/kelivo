# Persistent workspace web apps

The first version supports offline, single-file applications named `NAME.app.html`.
Open the file in Kelivo's browser through `kelivo://workspace/path/NAME.app.html`.
The application owns `path/NAME.app.html.data/` beside its HTML file. All API
paths are relative to that data directory, not to the workspace or HTML URL.

Ordinary HTML pages retain their normal browsing behavior and have no file API.
Application entries have a separate origin and only load their entry HTML;
inline JavaScript/CSS and embedded images/fonts are supported. Network requests,
external assets (including CDN scripts), frames, popups, downloads and page-initiated
external navigation are blocked. The browser's address bar can navigate elsewhere.
Application data directories are never served through workspace resource URLs.
Each application also has its own cookie domain, so it cannot pass saved data
to an ordinary workspace page through a shared parent-domain cookie.

## JSON applications

```html
<!doctype html>
<meta charset="utf-8">
<title>Notes</title>
<textarea id="note"></textarea>
<output id="status"></output>
<script>
(async () => {
  const note = document.querySelector('#note');
  const status = document.querySelector('#status');
  try {
    const state = await kelivo.readJson('state.json', { text: '' });
    note.value = state.text;
    let revision = 0;
    note.addEventListener('input', async () => {
      const current = ++revision;
      status.textContent = 'Saving…';
      try {
        await kelivo.saveJson('state.json', { text: note.value });
        if (current === revision) status.textContent = 'Saved';
      } catch (error) {
        if (current === revision) status.textContent = 'Not saved: ' + error.message;
      }
    });
  } catch (error) {
    status.textContent = 'Could not load: ' + error.message;
  }
})();
</script>
```

`readJson(path, initialValue)` reads current data and remembers its version.
`saveJson(path, value)` coalesces calls to that path for 300 ms. Its promise resolves
after publication, not when a save is scheduled. Wait for success before closing
the page. During a slow write, only the latest waiting value is retained for that
path; intermediate waiting saves share its result. With no pending work, the SDK
has no polling or autosave timer.
Always read first. After any failed save, reread and resolve the user's unsaved
changes before saving again. The wrapper never silently adopts a newer version
to overwrite someone else's changes.

## Text API

```js
await kelivo.ready;
const { content, version } = await kelivo.readFile('notes.txt');
const saved = await kelivo.writeFile('notes.txt', 'New content', version);
// saved: { version: "<sha256>", bytes: 11 }
```

A missing file returns `{content: null, version: null}`. Explicit `null` in
`writeFile` means create only. Existing files require the exact version returned
by a read or previous successful write. A changed file rejects with
`storage_conflict`; do not blindly retry with a new version.

Only UTF-8 `.json`, `.txt`, `.md` and `.csv` files up to 2 MiB are supported.
Paths must be relative, with at most eight components. Parents are created on
write. Absolute paths, traversal, device names and symbolic links are rejected.
There is no directory listing, deletion, binary API or additional-path grant.

The conversation's current workspace binding and its `read_file` / `write_file`
switches apply to all page calls, including calls triggered by AI automation.
Skills and read-only external mounts retain their existing write restrictions.
Closing, navigating or rebinding invalidates queued work and stale replies.
An already published file is not rolled back by navigation. Temporary chats can
bind a real workspace: their written files persist after the chat is discarded.

## Reliability and performance

Writes use random staging files and atomic publication on the same filesystem.
Hashing, text conversion and file I/O run in short-lived worker isolates.
The host processes at most eight file calls per page, with bounded pending reply
acknowledgements; large bridge JSON is also processed off the UI isolate.
File panels refresh from coalesced change events, with one directory scan in
flight at a time, without polling or filesystem watchers.

Web app operations and the AI `write_file` / `edit_file` tools share per-file
exclusion across tabs and conversations. Shell commands, external editors and
other processes do not participate in that lock: hashes detect observed changes
but are not a filesystem-wide compare-and-swap guarantee. Atomic replacement
protects against partial publication, not arbitrary external concurrent writers
or power loss guarantees beyond the filesystem.

Android and Windows require a Chromium engine of version 152 or later, which
enforces `Connection-Allowlist: ()` at the network layer (including WebRTC in
initial empty frames). Android also requires native Web Message Listener and
document-start script support. The version comes from the loaded native provider
or the current WebView2 instance, never the page's user agent. Unsupported
engines reject application loading; there is no fallback to the unrestricted
legacy JavaScript interface. See the [Chromium policy documentation](https://developer.chrome.com/blog/connection-allowlist-announcement).
Windows origin/frame metadata is supplied by the native execution context.
Apple platforms use WebKit's native frame origin. Page-supplied origins are
never authorization evidence.

Functional runtime check (use an isolated runner/device):

```sh
flutter test integration_test/browser_workspace_app_runtime_test.dart -d DEVICE
# Include WebView/bridge latency and main-isolate timer-delay measurements:
flutter test integration_test/browser_workspace_app_runtime_test.dart -d DEVICE --dart-define=KELIVO_STORAGE_PERF=true
```

File-service timing benchmark (not a test, no app data):

```sh
dart run test/perf/browser_workspace_storage_bench.dart
```

The benchmark excludes WebView IPC and production permission lookups. Use the
integration test and real target devices to assess end-to-end latency; a desktop
timing alone does not establish mobile performance.
