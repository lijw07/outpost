#!/usr/bin/env python3
"""Read GDScript diagnostics from a disposable Godot editor's language server."""
import argparse
import json
from pathlib import Path
import socket
import subprocess
import time
from urllib.parse import unquote, urlparse


class LanguageServer:
    def __init__(self, connection):
        self.connection = connection
        self.buffer = b''
        connection.settimeout(0.2)

    def send(self, method, params, request_id=None):
        message = {'jsonrpc': '2.0', 'method': method, 'params': params}
        if request_id is not None:
            message['id'] = request_id
        body = json.dumps(message).encode()
        self.connection.sendall(f'Content-Length: {len(body)}\r\n\r\n'.encode() + body)

    def messages(self, deadline):
        while time.monotonic() < deadline:
            if b'\r\n\r\n' in self.buffer:
                header, body = self.buffer.split(b'\r\n\r\n', 1)
                fields = dict(line.split(b':', 1) for line in header.split(b'\r\n'))
                length = int(fields[b'Content-Length'])
                if len(body) >= length:
                    self.buffer = body[length:]
                    yield json.loads(body[:length])
                    continue
            try:
                data = self.connection.recv(1024 * 1024)
            except socket.timeout:
                continue
            if not data:
                raise RuntimeError('Godot language server disconnected')
            self.buffer += data


def audit(project, godot):
    project = project.resolve()
    if not (project / 'project.godot').is_file():
        raise RuntimeError('Missing project.godot')
    paths = sorted(p for folder in ['scripts', 'tools', 'tests']
                   for p in (project / folder).rglob('*.gd'))
    with socket.socket() as reservation:
        reservation.bind(('127.0.0.1', 0))
        port = reservation.getsockname()[1]
    log_path = project.parent / 'warning-editor.log'
    with log_path.open('w') as log:
        process = subprocess.Popen([godot, '--headless', '--editor', '--path', str(project),
                                    '--lsp-port', str(port), '--log-file', str(project.parent / 'warning-engine.log')],
                                   stdout=log, stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + 20
            while True:
                if process.poll() is not None:
                    raise RuntimeError(f'Editor exited during startup; see {log_path}')
                try:
                    connection = socket.create_connection(('127.0.0.1', port), timeout=0.5)
                    break
                except OSError:
                    if time.monotonic() >= deadline:
                        raise RuntimeError(f'Editor language server did not start; see {log_path}')
                    time.sleep(0.1)
            with connection:
                server = LanguageServer(connection)
                server.send('initialize', {'processId': None, 'rootUri': project.as_uri(), 'capabilities': {}}, 1)
                initialized = False
                for message in server.messages(time.monotonic() + 10):
                    if message.get('id') == 1:
                        if 'error' in message:
                            raise RuntimeError(str(message['error']))
                        initialized = True
                        break
                if not initialized:
                    raise RuntimeError('Language server initialization timed out')
                server.send('initialized', {})
                for path in paths:
                    server.send('textDocument/didOpen', {'textDocument': {
                        'uri': path.as_uri(), 'languageId': 'gdscript', 'version': 1, 'text': path.read_text()}})
                diagnostics = {}
                expected = set(paths)
                for message in server.messages(time.monotonic() + 15):
                    if message.get('method') == 'textDocument/publishDiagnostics':
                        params = message['params']
                        path = Path(unquote(urlparse(params['uri']).path)).resolve()
                        if path in expected:
                            diagnostics[path] = params['diagnostics']
                        if expected <= diagnostics.keys():
                            break
                missing = expected - diagnostics.keys()
                if missing:
                    raise RuntimeError(f'Missing diagnostics for {len(missing)} scripts')
                failures = 0
                for path, entries in diagnostics.items():
                    for entry in entries:
                        if entry.get('severity', 1) <= 2:
                            failures += 1
                            line = entry['range']['start']['line'] + 1
                            print(f'FAIL: {path.relative_to(project)}:{line}: {entry["message"]}')
                print(f'EDITOR CHECK: {len(paths)} scripts, {failures} warnings/errors')
                return int(failures > 0)
        finally:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', required=True, type=Path)
    parser.add_argument('--godot', required=True)
    options = parser.parse_args()
    raise SystemExit(audit(options.project, options.godot))
