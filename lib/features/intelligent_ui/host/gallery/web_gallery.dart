/// Self-contained, synthetic development fixture. Never calls the network.
const genUiWebGallerySource =
    '''{"version":1,"title":"Local counter","summary":"A self-contained web example. Changes are discarded on close."}
<!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">
<style>body{font:18px system-ui;padding:24px}button{font:inherit;padding:12px 20px}output{display:block;margin:20px 0;font-size:36px}</style></head>
<body><h1>Local counter</h1><output id="count">0</output><button onclick="count.textContent=Number(count.textContent)+1">Add one</button></body></html>
''';
