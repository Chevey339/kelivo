import 'browser_engine.dart';

const browserScrollHandlerName = 'kelivoBrowserScroll';
const browserScrollIdentityScript =
    'window.__kelivoBrowserScroll?.documentId ?? null';

/// Checks a new document once, then accepts ordered pushes without a JS query
/// on each frame. Navigation/disposal invalidate any pending handshake too.
class BrowserScrollObserver {
  BrowserScrollObserver({required this.readDocumentId, required this.onUpdate});
  final Future<Object?> Function() readDocumentId;
  final void Function(BrowserScrollState) onUpdate;
  int _generation = 0;
  int _sequence = -1;
  String? _documentId;
  String? _retiredDocumentId;
  bool? _supportsScrollEnd;
  bool _disposed = false;
  bool get hasDocument => _documentId != null;

  void invalidate({bool navigation = true}) {
    _generation++;
    if (navigation && _documentId != null) _retiredDocumentId = _documentId;
    _documentId = null;
    _supportsScrollEnd = null;
    _sequence = -1;
    if (!_disposed) onUpdate(const BrowserScrollState.reset());
  }

  /// A completed load may legitimately retain the old DOM (native reattach,
  /// BFCache, or a navigation that kept the current document).
  void allowCurrentDocument() => _retiredDocumentId = null;

  void dispose() {
    _disposed = true;
    invalidate();
  }

  Future<bool> handle(List<dynamic> arguments) async {
    if (_disposed || arguments.length != 1 || arguments.single is! Map) {
      return false;
    }
    final data = arguments.single as Map;
    final id = data['documentId'];
    final sequence = data['sequence'];
    final kind = data['phase'];
    if (id is! String ||
        id.isEmpty ||
        id.length > 128 ||
        sequence is! int ||
        sequence < 0) {
      return false;
    }
    if (kind == 'suspend') {
      if (id != _documentId || sequence <= _sequence) return false;
      invalidate(navigation: false);
      return true;
    }
    final phase = BrowserScrollPhase.values
        .where((value) => value.name == kind)
        .firstOrNull;
    final offset = data['offset'];
    final viewport = data['viewportExtent'];
    final content = data['contentExtent'];
    final supportsEnd = data['supportsScrollEnd'];
    final interacting = data['isUserInteracting'];
    final gestureDelta = data['gestureDelta'];
    if (phase == null ||
        offset is! num ||
        !offset.isFinite ||
        viewport is! num ||
        !viewport.isFinite ||
        viewport <= 0 ||
        content is! num ||
        !content.isFinite ||
        content < 0 ||
        supportsEnd is! bool ||
        interacting is! bool ||
        gestureDelta is! num ||
        !gestureDelta.isFinite ||
        (!interacting && gestureDelta != 0) ||
        (phase == BrowserScrollPhase.end && !supportsEnd)) {
      return false;
    }
    if (phase == BrowserScrollPhase.reset) {
      if (id == _retiredDocumentId) return false;
      final generation = _generation;
      Object? current;
      try {
        current = await readDocumentId();
      } catch (_) {
        return false;
      }
      if (_disposed || generation != _generation || current != id) return false;
      if (_documentId == id && sequence <= _sequence) return false;
      _documentId = id;
      _supportsScrollEnd = supportsEnd;
    } else if (_documentId != id ||
        sequence <= _sequence ||
        supportsEnd != _supportsScrollEnd) {
      return false;
    }
    _sequence = sequence;
    onUpdate(
      BrowserScrollState(
        offset: offset.toDouble(),
        viewportExtent: viewport.toDouble(),
        contentExtent: content.toDouble(),
        phase: phase,
        supportsScrollEnd: supportsEnd,
        isUserInteracting: interacting,
        gestureDelta: gestureDelta.toDouble(),
      ),
    );
    return true;
  }
}

/// Installed at document start, main frame only. No timers infer scroll end.
/// A single pending rAF batches scroll/resize metrics. Finger intent is sent
/// at most once per 16ms, passive momentum at most once per 64ms. This only
/// limits bridge messages, not WebView rendering or Flutter's chrome spring.
/// Touch boundaries and a real scroll end always flush immediately.
const browserScrollObserverScript = r'''
(() => {
  if (window !== window.top) return;
  if (window.__kelivoBrowserScroll) {
    window.__kelivoBrowserScroll.refresh();
    return;
  }
  const documentId = String(performance.timeOrigin) + ':' + Math.random().toString(36).slice(2);
  const supportsScrollEnd = 'onscrollend' in document;
  let sequence = 0, frame = 0, ready = false, connecting = false, active = true;
  let pending = 'metrics', connection = 0;
  let lastSent = -Infinity;
  let touching = false, touchX = 0, touchY = 0, gestureDelta = 0;
  let scroller = null;
  const isNestedScroller = (element) => element && element !== document &&
    element !== document.documentElement && element !== document.body &&
    element.clientHeight > 0 && element.scrollHeight > element.clientHeight + 1 &&
    /^(auto|scroll|overlay)$/.test(window.getComputedStyle(element).overflowY);
  const scrollContainer = (target) => {
    for (let element = target; element && element !== document; element = element.parentElement) {
      if (isNestedScroller(element)) return element;
    }
    return null;
  };
  const geometry = (phase) => {
    const root = document.documentElement, body = document.body;
    if (scroller && !scroller.isConnected) scroller = null;
    const viewportExtent = Math.max(1, scroller?.clientHeight || window.innerHeight || root?.clientHeight || 1);
    return {
      documentId, sequence: ++sequence, phase, supportsScrollEnd,
      isUserInteracting: touching, gestureDelta,
      offset: scroller ? scroller.scrollTop : window.scrollY,
      viewportExtent,
      contentExtent: scroller ? Math.max(viewportExtent, scroller.scrollHeight) : Math.max(viewportExtent, root?.scrollHeight || 0, body?.scrollHeight || 0)
    };
  };
  const bridge = (payload) => window.flutter_inappwebview.callHandler('kelivoBrowserScroll', payload);
  const flush = () => {
    if (frame) cancelAnimationFrame(frame);
    frame = 0;
    if (!active || !ready) return;
    const phase = pending;
    pending = 'metrics';
    const payload = geometry(phase);
    gestureDelta = 0;
    lastSent = performance.now();
    bridge(payload).catch(() => {});
  };
  const deliverFrame = () => {
    frame = 0;
    if (!active || !ready) return;
    if (pending === 'update' &&
        performance.now() - lastSent < (touching ? 16 : 64)) {
      frame = requestAnimationFrame(deliverFrame);
      return;
    }
    flush();
  };
  const schedule = (phase) => {
    if (!active) return;
    if (phase !== 'metrics' || pending === 'metrics') pending = phase;
    if (phase === 'end') flush();
    else if (!frame) frame = requestAnimationFrame(deliverFrame);
  };
  const connect = () => {
    if (!active || connecting || !window.flutter_inappwebview?.callHandler) return;
    connecting = true;
    ready = false;
    const attempt = ++connection;
    bridge(geometry('reset')).then((accepted) => {
      if (!active || attempt !== connection) return;
      connecting = false;
      ready = accepted === true;
      if (ready) flush();
    }).catch(() => { if (attempt === connection) connecting = false; });
  };
  const refresh = () => ready ? schedule('metrics') : connect();
  window.__kelivoBrowserScroll = {
    documentId, refresh,
    reconnect: () => { connection++; connecting = false; ready = false; connect(); }
  };
  document.addEventListener('touchstart', (event) => {
    if (!event.isTrusted) return;
    scroller = scrollContainer(event.target);
    touching = event.touches.length === 1;
    gestureDelta = 0;
    if (touching) {
      touchX = event.touches[0].clientX;
      touchY = event.touches[0].clientY;
    }
    // Establish a baseline synchronously before this gesture's first move. A
    // queued momentum scroll from the previous gesture must not inherit it.
    pending = 'metrics';
    flush();
  }, {passive: true, capture: true});
  document.addEventListener('touchmove', (event) => {
    if (!event.isTrusted || !touching || event.touches.length !== 1) return;
    const touch = event.touches[0];
    const dx = touchX - touch.clientX, dy = touchY - touch.clientY;
    touchX = touch.clientX; touchY = touch.clientY;
    // Horizontal carousels and pinches cannot operate the browser chrome.
    if (Math.abs(dy) <= Math.abs(dx)) return;
    if (Math.sign(dy) !== Math.sign(gestureDelta)) gestureDelta = 0;
    gestureDelta += dy;
    schedule('update');
  }, {passive: true, capture: true});
  const release = (event) => {
    if (!event.isTrusted) return;
    // Preserve a move batched just before release, then explicitly separate all
    // following native scroll callbacks from the completed finger gesture.
    if (touching && event.type !== 'touchcancel') flush();
    touching = false; gestureDelta = 0;
    pending = 'metrics';
    flush();
  };
  document.addEventListener('touchend', release, {passive: true, capture: true});
  document.addEventListener('touchcancel', release, {passive: true, capture: true});
  document.addEventListener('scroll', (event) => {
    if (!event.isTrusted) return;
    if (event.target === document) scroller = null;
    else if (isNestedScroller(event.target)) scroller = event.target;
    else return;
    schedule('update');
  }, {passive: true, capture: true});
  if (supportsScrollEnd) document.addEventListener('scrollend', (event) => {
    if ((event.target === document || event.target === scroller) && event.isTrusted) schedule('end');
  }, {passive: true, capture: true});
  window.addEventListener('resize', () => schedule('metrics'), {passive: true});
  window.addEventListener('flutterInAppWebViewPlatformReady', refresh);
  window.addEventListener('pageshow', () => { active = true; refresh(); });
  window.addEventListener('pagehide', () => {
    if (ready) bridge(geometry('suspend')).catch(() => {});
    active = false; ready = false; connecting = false; connection++;
    touching = false; gestureDelta = 0;
    if (frame) cancelAnimationFrame(frame);
    frame = 0;
  });
  document.addEventListener('DOMContentLoaded', refresh, {once: true});
  if (typeof ResizeObserver === 'function') {
    const observer = new ResizeObserver(() => schedule('metrics'));
    const observe = () => {
      if (document.documentElement) observer.observe(document.documentElement);
      if (document.body) observer.observe(document.body);
    };
    observe();
    document.addEventListener('DOMContentLoaded', observe, {once: true});
  }
  connect();
})();
''';
