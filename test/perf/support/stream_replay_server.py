# Deterministic loopback fixture for concurrent_streaming_performance_test.dart.
# Run: python3 test/perf/support/stream_replay_server.py
# Then: adb reverse tcp:8790 tcp:8790
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs
import json, threading, time
barrier = threading.Barrier(1)
reasoning_seed = ('正在分析长文本，保留 Markdown **粗体**、中文和 English。\n\n' * 1800)
reasoning_delta = '继续分析上下文并核对事实。'
text_delta = '正文持续输出，保留 **Markdown** 和文字选择。 '
def frame(delta):
    return ('data: ' + json.dumps({'id':'replay','object':'chat.completion.chunk','choices':[{'index':0,'delta':delta,'finish_reason':None}]},ensure_ascii=False) + '\n\n').encode()
reason_wire = frame({'reasoning_content':reasoning_delta})
text_wire = frame({'content':text_delta})
class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args): pass
    def do_GET(self):
        global barrier
        query=parse_qs(urlparse(self.path).query)
        if urlparse(self.path).path=='/reset':
            barrier=threading.Barrier(int(query['streams'][0]))
        self.send_response(200);self.end_headers();self.wfile.write(b'ok')
    def do_POST(self):
        request=json.loads(self.rfile.read(int(self.headers.get('Content-Length',0))))
        if not request.get('stream'):
            self.send_response(200);self.send_header('Content-Type','application/json');self.end_headers()
            self.wfile.write(b'{"choices":[{"message":{"content":"Performance replay"}}]}');return
        barrier.wait(timeout=30)
        self.send_response(200);self.send_header('Content-Type','text/event-stream; charset=utf-8');self.end_headers()
        try:
            self.wfile.write(frame({'reasoning_content':reasoning_seed}));self.wfile.flush()
            for i in range(240):
                self.wfile.write(reason_wire);self.wfile.flush();time.sleep(.01)
            for i in range(720):
                if i==480: time.sleep(3)
                self.wfile.write(text_wire);self.wfile.flush();time.sleep(.01)
            self.wfile.write(b'data: [DONE]\n\n');self.wfile.flush()
        except (BrokenPipeError,ConnectionResetError): pass
ThreadingHTTPServer(('127.0.0.1',8790), Handler).serve_forever()
