import 'dart:convert';
import 'dart:isolate';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// An explicit single-file application. Storage is never served as a resource.
class BrowserWorkspaceApp {
  BrowserWorkspaceApp(this.entry);

  final String entry;
  String get dataDirectory => '$entry.data';

  static bool isEntry(String path) => path.endsWith('.app.html');
  static bool isDataPath(String path) => path
      .replaceAll(r'\', '/')
      .split('/')
      .any(
        (part) => part
            .toLowerCase()
            .trimRight()
            .replaceAll(RegExp(r'\.+$'), '')
            .endsWith('.app.html.data'),
      );

  static const headers = <String, String>{
    'Connection-Allowlist': '()',
    'X-DNS-Prefetch-Control': 'off',
    'Content-Security-Policy':
        "default-src 'none'; script-src 'unsafe-inline'; "
        "style-src 'unsafe-inline'; img-src data: blob:; font-src data:; "
        "connect-src 'none'; frame-src 'none'; worker-src 'none'; "
        "object-src 'none'; base-uri 'none'; form-action 'none'; "
        "frame-ancestors 'none'",
  };

  // Chromium 152 shipped the network-layer policy, including WebRTC in
  // initial about:blank frames where Android document-start scripts may not run.
  static bool supportsConnectionAllowlist(String? nativeVersion) {
    final match = nativeVersion == null
        ? null
        : RegExp(r'^(?:[A-Za-z ]+/)?([0-9]+)\.').firstMatch(nativeVersion);
    return match != null && (int.tryParse(match.group(1)!) ?? 0) >= 152;
  }

  bool acceptsResource(Uri uri) => uri.pathSegments.join('/') == entry;

  bool acceptsCaller(
    String? origin,
    bool mainFrame,
    String host, {
    required bool android,
  }) {
    final uri = origin == null ? null : Uri.tryParse(origin);
    return mainFrame &&
        uri != null &&
        uri.scheme == (android ? 'https' : 'kelivo') &&
        uri.host == host &&
        !uri.hasPort &&
        uri.userInfo.isEmpty &&
        (uri.path.isEmpty || uri.path == '/') &&
        !uri.hasQuery &&
        !uri.hasFragment;
  }
}

/// The fork forwards these response headers to each native custom-scheme API.
class BrowserWorkspaceAppResponse extends CustomSchemeResponse {
  BrowserWorkspaceAppResponse({required super.data, required super.contentType})
    : super(contentEncoding: 'utf-8');

  @override
  Map<String, dynamic> toMap() => {
    ...super.toMap(),
    'headers': BrowserWorkspaceApp.headers,
  };
}

const browserStorageHandler = 'kelivoWorkspaceStorage';
const browserStorageTransport = '__kelivoStorageTransport';
const browserStorageScriptGroup = 'kelivo-workspace-storage';

Future<Object?> decodeWorkspaceMessage(String value) =>
    Isolate.run(() => jsonDecode(value));
Future<String> encodeWorkspaceMessage(Map<String, Object?> value) =>
    Isolate.run(() => jsonEncode(value));

/// Check before calling page code: a newly navigated page can define its own
/// reply handler, so the handler's token check alone cannot protect old data.
String browserStorageReplyScript(String document, String encoded) =>
    'if (window.__kelivoStorageDocument === ${jsonEncode(document)}) {'
    'window.__kelivoStorageReply?.($encoded); }';

/// Installed only for application entries, before any page script executes.
String browserStorageScript(
  String host,
  String entry, {
  required bool windows,
}) =>
    '''
(() => {
  // Initial about:blank frames can exist even with frame-src 'none'. Harden
  // every same-origin realm before app code can borrow its peer network API.
  try {
    if (window.top.location.hostname !== ${jsonEncode(host)}) return;
  } catch (_) { return; }
  for (const key of ['RTCPeerConnection', 'webkitRTCPeerConnection']) {
    Object.defineProperty(window, key, {value: undefined, configurable: false});
  }
  if (window !== window.top ||
      decodeURIComponent(location.pathname) !== ${jsonEncode('/$entry')}) return;
  // WebView2 can replace blocked network navigations with an error document.
  // Keep this workaround off Android, whose local application origin is HTTPS.
  if ($windows) {
    addEventListener('click', event => {
      const link = event.composedPath().find(node => node instanceof HTMLAnchorElement);
      if (link && (link.protocol === 'http:' || link.protocol === 'https:')) {
        event.preventDefault();
      }
    }, true);
    // Detached download anchors do not dispatch through the window listener.
    const click = HTMLAnchorElement.prototype.click;
    HTMLAnchorElement.prototype.click = function() {
      if (this.protocol !== 'http:' && this.protocol !== 'https:') {
        return Reflect.apply(click, this, []);
      }
    };
    window.navigation?.addEventListener('navigate', event => {
      const url = new URL(event.destination.url);
      if (url.protocol === 'http:' || url.protocol === 'https:') {
        event.preventDefault();
      }
    });
  }
  const newDocumentId = () => Array.from(crypto.getRandomValues(new Uint32Array(4)),
      n => n.toString(16)).join('-');
  let documentId = newDocumentId();
  Object.defineProperty(window, '__kelivoStorageDocument', {get: () => documentId});
  const pending = new Map();
  let sequence = 0;
  const reply = response => {
    if (!response || response.document !== documentId) return;
    const call = pending.get(response.id);
    if (!call) return;
    pending.delete(response.id);
    clearTimeout(call.timer);
    if (response.error) {
      const error = new Error(response.error);
      error.code = response.error;
      call.reject(error);
    } else call.resolve(response.result);
  };
  Object.defineProperty(window, '__kelivoStorageReply', {value: reply});
  const call = (operation, args) => new Promise((resolve, reject) => {
    if (pending.size >= 8) { reject(new Error('storage_busy')); return; }
    const id = ++sequence;
    const message = {id, document: documentId, operation, ...args};
    const timer = setTimeout(() => {
      pending.delete(id);
      reject(new Error('storage_timeout'));
    }, 30000);
    pending.set(id, {resolve, reject, timer});
    try {
      ${windows ? "window.flutter_inappwebview.callHandler('$browserStorageHandler', message).then(reply, error => reply({id, document: documentId, error: String(error)}));" : "window.$browserStorageTransport.postMessage(JSON.stringify(message));"}
    } catch (error) { reply({id, document: documentId, error: String(error)}); }
  });
  let ready = call('ready', {});
  addEventListener('pageshow', event => {
    if (event.persisted) {
      documentId = newDocumentId();
      ready = call('ready', {});
    }
  });
  const readFile = path => ready.then(() => call('read', {path}));
  const writeFile = (path, content, version) => {
    if (typeof content !== 'string') return Promise.reject(new Error('storage_invalid_request'));
    if (content.length > 2097152) {
      return Promise.reject(new Error('storage_too_large'));
    }
    return ready.then(() => call('write', {path, content, version}));
  };
  const versions = new Map(), queued = new Map(), active = new Map();
  addEventListener('pagehide', () => {
    for (const call of pending.values()) {
      clearTimeout(call.timer);
      call.reject(new Error('storage_document_changed'));
    }
    pending.clear();
    for (const job of queued.values()) {
      clearTimeout(job.timer);
      job.reject(new Error('storage_document_changed'));
    }
    queued.clear();
  });
  const readJson = async (path, initial = {}) => {
    const result = await readFile(path);
    const data = result.content === null ? initial : JSON.parse(result.content);
    versions.set(path, result.version);
    return data;
  };
  const flushJson = path => {
    const job = queued.get(path);
    if (!job || !job.ready || active.has(path)) return;
    queued.delete(path);
    const write = Promise.resolve().then(() => {
      if (!versions.has(path)) throw new Error('storage_read_required');
      return writeFile(path, JSON.stringify(job.value), versions.get(path));
    });
    active.set(path, write);
    const finish = () => {
      active.delete(path);
      flushJson(path);
    };
    write.then(result => {
      versions.set(path, result.version);
      job.resolve(result);
      finish();
    }, error => {
      versions.delete(path);
      job.reject(error);
      finish();
    });
  };
  const saveJson = (path, value) => {
    if (!versions.has(path)) return Promise.reject(new Error('storage_read_required'));
    let job = queued.get(path);
    if (!job) {
      if (queued.size >= 8) return Promise.reject(new Error('storage_busy'));
      job = {};
      job.promise = new Promise((resolve, reject) => Object.assign(job, {resolve, reject}));
      queued.set(path, job);
    }
    job.value = value;
    job.ready = false;
    clearTimeout(job.timer);
    job.timer = setTimeout(() => {
      job.ready = true;
      flushJson(path);
    }, 300);
    return job.promise;
  };
  const api = Object.freeze({
    get ready() { return ready; },
    readFile, writeFile, readJson, saveJson
  });
  Object.defineProperty(window, 'kelivo', {value: api});
})();
''';
