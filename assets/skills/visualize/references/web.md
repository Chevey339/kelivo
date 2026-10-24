# Self-contained Web preview

Use native components for supported charts, forms, tables and calculators. Only
choose Web for a useful interaction the native catalog cannot express.
A separate top-level `kelivo-web` fence starts with exactly these JSON fields:
{"version":1,"title":"Example animation","summary":"A self-contained synthetic demonstration."}
The next line begins the complete HTML document. Scripts/styles are inline;
images/fonts use data URLs. No CDN, network, file access, host bridge or tools.
The app creates the WebView only after generation completes and the user clicks
Open. At most 3 Web blocks per message, independently
of native blocks. Closing discards changes; reopening starts over. Web state is
not attached to chat, sent to a model or persisted by this feature.

Previews currently run on Android, iOS and macOS. Windows activation is deferred;
Windows and Linux provide source/copy/HTML export. The parent CSP and opaque-origin
sandbox restrict ordinary network/navigation/storage/capabilities. They do not
provide OS-level offline isolation; WebRTC is an explicitly accepted residual
risk. Never claim the preview is absolutely offline or request credentials.
