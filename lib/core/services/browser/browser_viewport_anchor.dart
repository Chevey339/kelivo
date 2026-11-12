/// Keep a reached document footer visible and clamp positions beyond its end
/// when iOS browser chrome changes the layout viewport. DOM resize events use
/// the new viewport-relative CSS geometry after the native setter has returned.
const browserViewportAnchorScript = r'''
(() => {
  if (window !== window.top || window.__kelivoViewportAnchor) return;
  window.__kelivoViewportAnchor = true;
  let previous = null;
  const update = (allowAnchor = true) => {
    const root = document.scrollingElement;
    if (!root) return;
    const height = window.innerHeight;
    const width = window.innerWidth;
    const end = Math.max(0, root.scrollHeight - height);
    const focused = document.activeElement;
    const editing = focused?.isContentEditable || focused?.tagName === 'TEXTAREA' ||
      (focused?.tagName === 'INPUT' &&
       !/^(button|submit|reset|checkbox|radio|range|color|file|hidden)$/.test(focused.type));
    if (allowAnchor && previous && (previous.height !== height || previous.width !== width) && !editing) {
      const atEnd = previous.end > 0 && previous.offset >= previous.end - 1;
      if (atEnd || window.scrollY > end) {
        window.scrollTo({left: window.scrollX, top: end, behavior: 'instant'});
      }
    }
    previous = {height, width, end, offset: window.scrollY};
  };
  window.addEventListener('resize', () => update(), {passive: true});
  document.addEventListener('scroll', () => update(), {passive: true});
  document.addEventListener('load', () => update(false), {capture: true, passive: true});
  window.addEventListener('pageshow', () => { previous = null; update(); });
  const observe = () => {
    const observer = new ResizeObserver(() => update());
    observer.observe(document.documentElement);
    if (document.body) observer.observe(document.body);
    // Overflowing descendants can change scrollHeight without resizing either
    // observed box. DOM additions refresh the baseline without scrolling.
    const mutations = new MutationObserver(() => update(false));
    mutations.observe(document.documentElement, {
      childList: true, subtree: true, characterData: true
    });
    update();
  };
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', observe, {once: true});
  } else {
    observe();
  }
})();
''';
