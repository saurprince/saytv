#!/usr/bin/env python3
"""Minimal Android TV Remote (v2) client: pair with a TV, read its state, send keys, open apps.

This is the protocol Google's own "Google TV" / "Android TV Remote" apps use (TV ports 6467 for pairing,
6466 for the remote). It exists to prove the protocol on one TV before an iPhone app is written, and to
serve as the reference for that app. Standard library plus `cryptography` only.

  python atvremote.py pair   <tv-ip> [--code-file FILE]   # start pairing; the TV shows a 6-character code
  python atvremote.py status <tv-ip>                      # read-only: TV model, volume, current app
  python atvremote.py key    <tv-ip> VOLUME_UP HOME ...   # send key names or numbers
  python atvremote.py app    <tv-ip> <link>               # open an app / link, e.g. market://launch?id=com.netflix.ninja

The client certificate (client/cert.pem, client/key.pem) IS the pairing credential: never publish it.
Protocol layout follows the open-source project tronikos/androidtvremote2 (Apache-2.0), re-implemented here.
"""
import hashlib
import os
import socket
import ssl
import sys
import time

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import NameOID
import datetime

HERE = os.path.dirname(os.path.abspath(__file__))
CLIENT_DIR = os.path.join(HERE, "client")
CERT = os.path.join(CLIENT_DIR, "cert.pem")
KEY = os.path.join(CLIENT_DIR, "key.pem")
CLIENT_NAME = "Claude test (PC)"

PAIRING_PORT, REMOTE_PORT = 6467, 6466
FEATURES = 1 + 2 + 32 + 64 + 512        # ping, key, power, volume, app link

KEYS = {
    "HOME": 3, "BACK": 4, "UP": 19, "DOWN": 20, "LEFT": 21, "RIGHT": 22, "CENTER": 23, "OK": 23,
    "VOLUME_UP": 24, "VOLUME_DOWN": 25, "POWER": 26, "MUTE": 164, "VOLUME_MUTE": 164, "MIC_MUTE": 91,
    "PLAY_PAUSE": 85, "STOP": 86, "NEXT": 87, "PREVIOUS": 88, "REWIND": 89, "FAST_FORWARD": 90,
    "PLAY": 126, "PAUSE": 127, "TV_POWER": 177, "TV_INPUT": 178, "SLEEP": 223, "WAKEUP": 224,
    "HDMI_1": 243, "HDMI_2": 244, "HDMI_3": 245, "HDMI_4": 246, "MENU": 82, "SETTINGS": 176,
    "CHANNEL_UP": 166, "CHANNEL_DOWN": 167,
}


# ---- tiny protobuf codec (varint and length-delimited only; that is all this protocol needs) ----
def varint(n):
    out = b""
    while True:
        b = n & 0x7F
        n >>= 7
        if n:
            out += bytes([b | 0x80])
        else:
            return out + bytes([b])


def f_int(field, value):
    return varint(field << 3) + varint(value)


def f_bytes(field, data):
    return varint(field << 3 | 2) + varint(len(data)) + data


def f_str(field, text):
    return f_bytes(field, text.encode())


def read_varint(buf, i):
    shift = value = 0
    while True:
        b = buf[i]
        i += 1
        value |= (b & 0x7F) << shift
        if not b & 0x80:
            return value, i
        shift += 7


def parse(buf):
    """-> {field: [value, ...]}; varints as int, length-delimited as bytes."""
    out, i = {}, 0
    while i < len(buf):
        key, i = read_varint(buf, i)
        field, wire = key >> 3, key & 7
        if wire == 0:
            value, i = read_varint(buf, i)
        elif wire == 2:
            n, i = read_varint(buf, i)
            value, i = buf[i:i + n], i + n
        elif wire == 1:
            value, i = buf[i:i + 8], i + 8
        elif wire == 5:
            value, i = buf[i:i + 4], i + 4
        else:
            raise ValueError("unsupported wire type %d" % wire)
        out.setdefault(field, []).append(value)
    return out


# ---- TLS + framing ----
def ensure_client_cert():
    if os.path.exists(CERT) and os.path.exists(KEY):
        return
    os.makedirs(CLIENT_DIR, exist_ok=True)
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "atvremote")])
    now = datetime.datetime.now(datetime.timezone.utc)
    cert = (x509.CertificateBuilder().subject_name(name).issuer_name(name).public_key(key.public_key())
            .serial_number(x509.random_serial_number()).not_valid_before(now - datetime.timedelta(days=1))
            .not_valid_after(now + datetime.timedelta(days=3650)).sign(key, hashes.SHA256()))
    with open(KEY, "wb") as f:
        f.write(key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.TraditionalOpenSSL,
                                  serialization.NoEncryption()))
    with open(CERT, "wb") as f:
        f.write(cert.public_bytes(serialization.Encoding.PEM))
    print("created a new client certificate in", CLIENT_DIR)


class Conn:
    def __init__(self, host, port):
        ensure_client_cert()
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE          # the TV's certificate is self-signed; the pairing code proves it
        ctx.load_cert_chain(CERT, KEY)
        raw = socket.create_connection((host, port), timeout=10)
        self.sock = ctx.wrap_socket(raw)
        self.sock.settimeout(10)

    def server_cert_der(self):
        return self.sock.getpeercert(True)

    def send(self, payload):
        self.sock.sendall(varint(len(payload)) + payload)

    def _read_exact(self, n):
        data = b""
        while len(data) < n:
            chunk = self.sock.recv(n - len(data))
            if not chunk:
                raise ConnectionError("the TV closed the connection")
            data += chunk
        return data

    def recv(self, timeout=None):
        if timeout is not None:
            self.sock.settimeout(timeout)
        shift = size = 0
        while True:
            b = self._read_exact(1)[0]
            size |= (b & 0x7F) << shift
            if not b & 0x80:
                break
            shift += 7
        return self._read_exact(size)

    def close(self):
        try:
            self.sock.close()
        except OSError:
            pass


# ---- pairing (port 6467) ----
def rsa_numbers(public_key):
    n = public_key.public_numbers()
    return n.n, n.e


def to_bytes(v):
    return v.to_bytes((v.bit_length() + 7) // 8, "big")


def outer(**parts):
    msg = f_int(1, 2) + f_int(2, 200)            # protocol_version 2, status OK
    for field, body in parts.items():
        msg += f_bytes({"request": 10, "options": 20, "configuration": 30, "secret": 40}[field], body)
    return msg


def expect(conn, field, what):
    msg = parse(conn.recv(15))
    status = msg.get(2, [0])[0]
    if status != 200 or field not in msg:
        raise RuntimeError("pairing: expected %s, got fields %s status %s" % (what, sorted(msg), status))
    return msg


def pair(host, code_file):
    conn = Conn(host, PAIRING_PORT)
    try:
        conn.send(outer(request=f_str(1, "atvremote") + f_str(2, CLIENT_NAME)))
        expect(conn, 11, "pairing_request_ack")
        encoding = f_int(1, 3) + f_int(2, 6)                    # hexadecimal, 6 symbols
        conn.send(outer(options=f_bytes(1, encoding) + f_int(3, 1)))   # preferred role: input
        expect(conn, 20, "options")
        conn.send(outer(configuration=f_bytes(1, encoding) + f_int(2, 1)))
        expect(conn, 31, "configuration_ack")
        print("PAIRING STARTED - the TV now shows a 6-character code.", flush=True)

        if code_file:
            print("waiting for the code in", code_file, flush=True)
            deadline = time.time() + 180
            while not (os.path.exists(code_file) and open(code_file).read().strip()):
                if time.time() > deadline:
                    raise TimeoutError("no code within 3 minutes")
                time.sleep(0.5)
            code = open(code_file).read().strip()
        else:
            code = input("code shown on the TV: ").strip()
        code = code.replace(" ", "").upper()
        if len(code) != 6 or any(c not in "0123456789ABCDEF" for c in code):
            raise ValueError("the code must be 6 hex characters")

        from cryptography.hazmat.primitives.serialization import load_pem_public_key  # noqa: F401
        client_cert = x509.load_pem_x509_certificate(open(CERT, "rb").read())
        server_cert = x509.load_der_x509_certificate(conn.server_cert_der())
        cn, ce = rsa_numbers(client_cert.public_key())
        sn, se = rsa_numbers(server_cert.public_key())
        h = hashlib.sha256()
        for part in (to_bytes(cn), to_bytes(ce), to_bytes(sn), to_bytes(se), bytes.fromhex(code[2:])):
            h.update(part)
        digest = h.digest()
        if digest[0] != int(code[:2], 16):
            raise ValueError("wrong code (the first byte does not match); type it again")
        conn.send(outer(secret=f_bytes(1, digest)))
        expect(conn, 41, "secret_ack")
        print("PAIRED. This PC is now a trusted remote for the TV.", flush=True)
    finally:
        conn.close()


# ---- remote (port 6466) ----
class Remote:
    def __init__(self, host):
        self.conn = Conn(host, REMOTE_PORT)
        self.info = {}
        self.features = 0
        self.started = False
        self._handshake()

    def _handle(self, raw):
        msg = parse(raw)
        if 1 in msg:                                   # remote_configure from the TV
            cfg = parse(msg[1][0])
            dev = parse(cfg.get(2, [b""])[0])
            self.info["model"] = dev.get(1, [b""])[0].decode(errors="replace")
            self.info["vendor"] = dev.get(2, [b""])[0].decode(errors="replace")
            self.features = FEATURES & cfg.get(1, [0])[0]
            device = (f_str(1, "Claude test") + f_str(2, "Claude") + f_int(3, 1) + f_str(4, "1")
                      + f_str(5, "atvremote") + f_str(6, "1.0.0"))
            self.conn.send(f_bytes(1, f_int(1, self.features) + f_bytes(2, device)))
        if 2 in msg:                                   # remote_set_active
            self.conn.send(f_bytes(2, f_int(1, self.features)))
        if 8 in msg:                                   # ping -> echo
            val = parse(msg[8][0]).get(1, [0])[0]
            self.conn.send(f_bytes(9, f_int(1, val)))
        if 40 in msg:                                  # remote_start: started = power state
            self.started = True
            self.info["screen_on"] = bool(parse(msg[40][0]).get(1, [0])[0])
        if 50 in msg:                                  # volume info
            v = parse(msg[50][0])
            self.info["volume"] = {"level": v.get(7, [0])[0], "max": v.get(6, [0])[0],
                                   "muted": bool(v.get(8, [0])[0]),
                                   "output": v.get(3, [b""])[0].decode(errors="replace")}
        if 20 in msg:                                  # ime key inject: carries the current app
            app = parse(parse(msg[20][0]).get(1, [b""])[0])
            if 12 in app:
                self.info["app"] = app[12][0].decode(errors="replace")
        if 3 in msg:
            self.info["error"] = "TV reported an error"
        return msg

    def _handshake(self):
        deadline = time.time() + 15
        while not self.started and time.time() < deadline:
            self._handle(self.conn.recv(5))
        # The TV creates a virtual input device for each client; keys sent before its own key-mapping layer
        # has registered that device (about 0.15 s later) are logged "not found keycode" and dropped.
        self.listen(1.5)

    def listen(self, seconds):
        end = time.time() + seconds
        while time.time() < end:
            try:
                self._handle(self.conn.recv(max(0.2, end - time.time())))
            except socket.timeout:
                break

    def key(self, code, direction=3):
        self.conn.send(f_bytes(10, f_int(1, code) + f_int(2, direction)))

    def app(self, link):
        self.conn.send(f_bytes(90, f_str(1, link)))

    def close(self):
        self.conn.close()


def key_code(name):
    n = name.upper().replace("KEYCODE_", "")
    return int(n) if n.isdigit() else KEYS[n]


def main(argv):
    if len(argv) < 3 or argv[1] not in ("pair", "status", "key", "app"):
        print(__doc__)
        return 2
    cmd, host = argv[1], argv[2]
    if cmd == "pair":
        code_file = argv[argv.index("--code-file") + 1] if "--code-file" in argv else None
        pair(host, code_file)
        return 0
    r = Remote(host)
    try:
        if cmd == "status":
            r.listen(3)
            print(r.info)
        elif cmd == "key":
            for name in argv[3:]:
                r.key(key_code(name))
                r.listen(0.4)
            print("sent:", " ".join(argv[3:]))
        elif cmd == "app":
            r.app(argv[3])
            r.listen(1)
            print("sent app link:", argv[3])
    finally:
        r.close()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
