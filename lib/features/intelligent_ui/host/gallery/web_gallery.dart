/// Self-contained, synthetic development fixture. Never calls the network.
const genUiWebGallerySource =
    '''{"version":1,"title":"Local counter","summary":"A self-contained web example. Changes are discarded on close."}
<!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">
<style>body{font:18px system-ui;padding:24px}button{font:inherit;padding:12px 20px}output{display:block;margin:20px 0;font-size:36px}</style></head>
<body><h1>Local counter</h1><output id="count">0</output><button onclick="count.textContent=Number(count.textContent)+1">Add one</button></body></html>
''';

/// Dark page used beside the unstyled counter to inspect platform-view loading
/// and exit frames. The opaque sandbox remains identical to production.
const genUiWebDarkGallerySource =
    '''{"version":1,"title":"Canvas 指针交互演示","summary":"点击或拖动页面画布。自包含演示，无网络请求。"}
<!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">
<style>html,body{margin:0;width:100%;height:100%;background:#101114;color:#eee;font:16px system-ui;overflow:hidden}canvas{display:block;width:100%;height:100%;touch-action:none}p{position:absolute;bottom:12px;inset-inline:16px;pointer-events:none;color:#9a9da5}</style></head>
<body><canvas id="canvas"></canvas><p>点击或拖动画布</p><script>
const canvas=document.getElementById('canvas'),ctx=canvas.getContext('2d');
function paint(x,y){ctx.fillStyle='#101114';ctx.fillRect(0,0,canvas.width,canvas.height);ctx.fillStyle='#93c5fd';for(let i=0;i<24;i++){const angle=i*Math.PI/12,r=12+(i%4)*9;ctx.beginPath();ctx.arc(x+Math.cos(angle)*r,y+Math.sin(angle)*r,3,0,Math.PI*2);ctx.fill()}}
function resize(){canvas.width=innerWidth;canvas.height=innerHeight;paint(innerWidth/2,innerHeight/2)}
canvas.onpointerdown=canvas.onpointermove=e=>paint(e.clientX,e.clientY);onresize=resize;resize();
</script></body></html>
''';
