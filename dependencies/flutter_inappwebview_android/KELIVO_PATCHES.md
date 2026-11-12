# Kelivo Android WebView patches

Vendored from pub.dev flutter_inappwebview_android 1.1.3, retaining its license.

- The visible/headless Dart hosts declare whether scroll and overscroll callbacks
  are subscribed. Native channel delegates omit those messages when absent;
  WebView scrolling and internal pull-to-refresh handling remain unchanged.
- A retained native WebView reattached with another composition mode synchronizes
  its input proxy, container, layer type and subscriptions. The document is kept,
  not reloaded. Both modes still use Android hardware accelerated WebView drawing.
  Selection-menu cleanup is prepared in both modes, so changing from a solid
  host to a texture host can dismiss selection without reloading the document.

- Screenshots draw directly into the requested output dimensions, then encode
  on a single background worker. Channel replies return on the main thread.

The browser uses hybrid composition for solid surfaces, texture composition for
Flutter glass/blur sampling. No device model lists or refresh-rate overrides.
