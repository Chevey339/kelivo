"""Local, bounded SSE stream for the dedicated Flutter smoke entrypoint."""
import argparse
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Stream(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/stream":
            self.send_error(404)
            return
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        try:
            for step in range(self.server.steps):
                self.wfile.write(f"data: {step}\n\n".encode())
                self.wfile.flush()
                time.sleep(1)
        except (BrokenPipeError, ConnectionResetError):
            pass


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8769)
    parser.add_argument("--steps", type=int, default=90)
    args = parser.parse_args()
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Stream)
    server.steps = max(1, min(args.steps, 900))
    server.serve_forever()
