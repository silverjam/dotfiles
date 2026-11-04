#!/usr/bin/env python3
"""Accept one WebSocket client and send it a command."""
import base64
import hashlib
import socket
import sys
import time

PORT = 17321
GUID = b'258EAFA5-E914-47DA-95CA-C5AB0DC85B11'

def read_request(conn):
    data = b''
    while b'\r\n\r\n' not in data:
        chunk = conn.recv(4096)
        if not chunk:
            return None
        data += chunk
    return data

def accept_key(request):
    for line in request.split(b'\r\n'):
        if line.lower().startswith(b'sec-websocket-key:'):
            key = line.split(b':', 1)[1].strip()
            return base64.b64encode(hashlib.sha1(key + GUID).digest())
    return None

def send_text(conn, text):
    data = text.encode()
    if len(data) < 126:
        conn.sendall(bytes((0x81, len(data))) + data)
    else:
        conn.sendall(bytes((0x81, 126)) + len(data).to_bytes(2, 'big') + data)

srv = socket.socket()
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(('127.0.0.1', PORT))
srv.listen()
srv.settimeout(2)

sent = False
try:
    conn, _ = srv.accept()
    conn.settimeout(2)
    request = read_request(conn)
    key = accept_key(request) if request else None
    if key:
        conn.sendall(b'HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\n'
                     b'Connection: Upgrade\r\nSec-WebSocket-Accept: ' + key + b'\r\n\r\n')
        send_text(conn, sys.argv[1])
        sent = True
    conn.close()
except socket.timeout:
    pass

sys.exit(0 if sent else 1)
