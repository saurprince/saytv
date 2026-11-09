#!/usr/bin/env python3
"""Tests for everything a phone app needs from the TV. Run one test at a time:

  python tv_tests.py discover        # does the TV announce itself on the network (mDNS)?
  python tv_tests.py hold [seconds]  # one long-lived connection: pings, live volume pushes, commands after a long idle
  python tv_tests.py setvol N        # step the volume to level N using the TV's own level reports
  python tv_tests.py keys            # press every key the app needs and show the kernel-level evidence
  python tv_tests.py apps            # open every installed app by link and check it comes to the front
  python tv_tests.py wake            # wake from the screensaver: HOME vs WAKEUP

The TV address is the first argument after the test name if given as HOST=ip. Uses atvremote.py and adb (loopback is not used).
"""
import os
import re
import socket
import struct
import subprocess
import sys
import threading
import time

import atvremote as a

ADB = os.environ.get("ADB", "adb")  # path to adb if it is not on PATH
HOST = os.environ.get("TV_HOST", "192.168.1.20")  # set TV_HOST to your TV's address
DEV = HOST + ":5555"

OTT = {   # name -> package (only the ones installed on the tested TV)
    "netflix": "com.netflix.ninja",
    "prime video": "com.amazon.amazonvideo.livingroom",
    "apple tv": "com.apple.atve.androidtv.appletv",
    "youtube": "com.google.android.youtube.tv",
    "hotstar": "in.startv.hotstar",
    "sonyliv": "com.sonyliv",
    "zee5": "com.graymatrix.did",
    "jiotv": "com.jio.jioplay.tv",
    "jio cinema": "com.jio.media.stb.ondemand",
    "tvf play": "com.tvf.tvfplay.tv",
    "spotify": "com.spotify.tv.android",
    "mx player": "com.mxtech.videoplayer.television",
}


def adb(cmd, timeout=25):
    r = subprocess.run([ADB, "-s", DEV, "shell", cmd], capture_output=True, text=True, timeout=timeout)
    return (r.stdout + r.stderr).strip()


def focus():
    out = adb("dumpsys window | grep -m1 mCurrentFocus")
    m = re.search(r"u0 (\S+?)\}", out)
    return m.group(1) if m else out.split("\n")[0]


def own_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.connect((HOST, 9))
    ip = s.getsockname()[0]
    s.close()
    return ip


# ---------------------------------------------------------------- mDNS
def dns_name(buf, i):
    labels, end = [], None
    while True:
        n = buf[i]
        if n == 0:
            i += 1
            break
        if n & 0xC0 == 0xC0:
            if end is None:
                end = i + 2
            i = ((n & 0x3F) << 8) | buf[i + 1]
            continue
        labels.append(buf[i + 1:i + 1 + n].decode(errors="replace"))
        i += 1 + n
    return ".".join(labels), (end if end is not None else i)


def parse_dns(buf):
    qd, an, ns, ar = struct.unpack(">4H", buf[4:12])
    i = 12
    for _ in range(qd):
        _, i = dns_name(buf, i)
        i += 4
    records = []
    for _ in range(an + ns + ar):
        name, i = dns_name(buf, i)
        rtype, _cls, _ttl, rdlen = struct.unpack(">HHIH", buf[i:i + 10])
        i += 10
        rdata = buf[i:i + rdlen]
        if rtype == 12:
            records.append((name, "PTR", dns_name(buf, i)[0]))
        elif rtype == 33:
            port = struct.unpack(">H", rdata[4:6])[0]
            records.append((name, "SRV", "port %d -> %s" % (port, dns_name(buf, i + 6)[0])))
        elif rtype == 1:
            records.append((name, "A", socket.inet_ntoa(rdata)))
        elif rtype == 16:
            txt, j = [], 0
            while j < len(rdata):
                n = rdata[j]
                txt.append(rdata[j + 1:j + 1 + n].decode(errors="replace"))
                j += 1 + n
            records.append((name, "TXT", txt))
        i += rdlen
    return records


def discover(service="_androidtvremote2._tcp.local", seconds=5):
    q = b"\x00\x00\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00"
    for label in service.split("."):
        q += bytes([len(label)]) + label.encode()
    q += b"\x00" + struct.pack(">HH", 12, 1)               # PTR, class IN (multicast answer wanted)
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(("", 5353))                                      # listen where multicast answers arrive
    s.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP,
                 socket.inet_aton("224.0.0.251") + socket.inet_aton(own_ip()))
    s.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_IF, socket.inet_aton(own_ip()))
    s.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 255)
    s.settimeout(1)
    s.sendto(q, ("224.0.0.251", 5353))
    seen, end = [], time.time() + seconds
    while time.time() < end:
        try:
            data, src = s.recvfrom(9000)
        except socket.timeout:
            continue
        try:
            for rec in parse_dns(data):
                if (src[0],) + rec not in seen:
                    seen.append((src[0],) + rec)
        except Exception as e:                              # noqa: BLE001 - a malformed packet is just skipped
            print("  (skipped a packet from", src[0], e, ")")
    s.close()
    return seen


def ask_tv_directly(service, seconds=3):
    """Unicast mDNS query straight to the TV (a 'legacy unicast' query from a random port)."""
    q = b"\x12\x34\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00"
    for label in service.split("."):
        q += bytes([len(label)]) + label.encode()
    q += b"\x00" + struct.pack(">HH", 12, 1)
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.bind((own_ip(), 0))
    s.settimeout(1)
    s.sendto(q, (HOST, 5353))
    out, end = [], time.time() + seconds
    while time.time() < end:
        try:
            data, src = s.recvfrom(9000)
        except socket.timeout:
            continue
        try:
            out += [(src[0],) + r for r in parse_dns(data)]
        except Exception as e:                              # noqa: BLE001
            out.append((src[0], "unparsed", str(e)))
    s.close()
    return out


def t_discover(service=None):
    for svc in ([service] if service else ["_androidtvremote2._tcp.local", "_services._dns-sd._udp.local"]):
        print("multicast query for", svc)
        recs = [r for r in discover(svc) if r[0] == HOST]
        print("  answers from the TV:", recs or "none")
        direct = ask_tv_directly(svc)
        print("  direct query to the TV:", direct or "no answer")


# (the overheard answers of other devices on the network are deliberately not printed)


# ---------------------------------------------------------------- long-lived connection
class Logged(a.Remote):
    def __init__(self, host):
        self.t0 = time.time()
        self.log = []
        self.pings = 0
        super().__init__(host)

    def _handle(self, raw):
        m = a.parse(raw)
        if 8 in m:
            self.pings += 1
        if 50 in m:
            v = a.parse(m[50][0])
            self.log.append((round(time.time() - self.t0, 1), "volume push", v.get(7, [0])[0], bool(v.get(8, [0])[0])))
        return super()._handle(raw)


def t_hold(seconds=150):
    r = Logged(HOST)
    print("connected; model:", r.info.get("model"), "volume:", r.info.get("volume"))
    start_level = r.info["volume"]["level"]
    t0 = time.time()
    sent = {}
    try:
        while time.time() - t0 < seconds:
            r.listen(1)
            el = time.time() - t0
            if el > 10 and "up" not in sent:
                r.key(24)
                sent["up"] = round(el, 1)
            if el > 20 and "down" not in sent:
                r.key(25)
                sent["down"] = round(el, 1)
        r.key(24)                                           # after a long idle: does a command still work?
        sent["up after idle"] = round(time.time() - t0, 1)
        r.listen(2)
        r.key(25)
        r.listen(2)
    finally:
        r.close()
    print("held the connection for %d s; pings answered: %d" % (seconds, r.pings))
    print("commands sent at (s):", sent)
    print("volume pushes seen by the client:")
    for row in r.log:
        print("  ", row)
    print("start level %s, last pushed level %s" % (start_level, r.log[-1][2] if r.log else "none"))


# ---------------------------------------------------------------- set volume
def set_volume(r, target, timeout_per_step=2.0):
    """Step to `target` using the level the TV reports. Returns the number of key presses used."""
    presses = 0
    for _round in range(4):                                 # burst, let the level settle, correct any remainder
        cur = r.info["volume"]["level"]
        delta = target - cur
        if delta == 0:
            return presses
        for _ in range(abs(delta)):
            r.key(24 if delta > 0 else 25)
            presses += 1
            time.sleep(0.06)
        last_change, last = time.time(), r.info["volume"]["level"]
        while time.time() - last_change < 0.8 and time.time() - last_change < timeout_per_step + 3:
            r.listen(0.1)
            if r.info["volume"]["level"] != last:
                last, last_change = r.info["volume"]["level"], time.time()
    return presses


def t_setvol(target):
    r = a.Remote(HOST)
    try:
        start = r.info["volume"]["level"]
        t = time.time()
        n = set_volume(r, target)
        print("from %d to %d: %d key presses in %.1f s, TV reports %s" % (start, target, n, time.time() - t, r.info["volume"]))
        t = time.time()
        n = set_volume(r, start)
        print("back to %d: %d key presses in %.1f s, TV reports %s" % (start, n, time.time() - t, r.info["volume"]))
    finally:
        r.close()


# ---------------------------------------------------------------- kernel-level evidence
class KernelEvents:
    """`getevent -l` on the TV, so every injected key can be seen leaving the virtual remote."""

    def __init__(self):
        self.proc = subprocess.Popen([ADB, "-s", DEV, "shell", "getevent -l"], stdout=subprocess.PIPE,
                                     stderr=subprocess.STDOUT, text=True, bufsize=1)
        self.lines, self.names, self.cur = [], {}, None
        threading.Thread(target=self._read, daemon=True).start()

    def _read(self):
        for line in self.proc.stdout:
            line = line.rstrip()
            m = re.match(r"add device \d+: (\S+)", line)
            if m:
                self.cur = m.group(1)
            m = re.match(r'\s+name:\s+"(.+)"', line)
            if m and self.cur:
                self.names[self.cur] = m.group(1)
            self.lines.append(line)

    def keys_since(self, index):
        found = []
        for line in self.lines[index:]:
            m = re.match(r"(\S+): EV_KEY\s+(\S+)\s+DOWN", line)
            if m and self.names.get(m.group(1)) == "virtual-remote":
                found.append(m.group(2))
        return found

    def stop(self):
        self.proc.terminate()


NAV_KEYS = [("UP", 19), ("DOWN", 20), ("LEFT", 21), ("RIGHT", 22), ("CENTER", 23), ("BACK", 4), ("MENU", 82)]
MEDIA_KEYS = [("PLAY_PAUSE", 85), ("PLAY", 126), ("PAUSE", 127), ("STOP", 86), ("NEXT", 87), ("PREVIOUS", 88),
              ("REWIND", 89), ("FAST_FORWARD", 90)]
INPUT_KEYS = [("TV_INPUT", 178), ("HDMI_1", 243), ("HDMI_2", 244), ("HDMI_3", 245), ("HDMI_4", 246)]
OTHER_KEYS = [("CHANNEL_UP", 166), ("CHANNEL_DOWN", 167), ("SETTINGS", 176)]


def press(r, ke, name, code, wait=0.9):
    mark = len(ke.lines)
    r.key(code)
    r.listen(wait)
    kernel = ke.keys_since(mark)
    return kernel


GROUPS = {
    "arrows": NAV_KEYS[:4],
    "media": MEDIA_KEYS,
    "media_safe": [k for k in MEDIA_KEYS if k[0] in ("PAUSE", "STOP", "NEXT", "PREVIOUS", "REWIND", "FAST_FORWARD")],
    "media_play": [k for k in MEDIA_KEYS if k[0] in ("PLAY_PAUSE", "PLAY")],
    "center": [NAV_KEYS[4]],
    "back_menu": NAV_KEYS[5:],
    "other": OTHER_KEYS,
    "inputs": INPUT_KEYS,
}


def t_prep():
    """HOME (wakes), mute, open Netflix as a harmless place to press keys; leaves it open for a look."""
    r = a.Remote(HOST)
    try:
        r.key(3)
        r.listen(2)
        if not r.info["volume"]["muted"]:
            r.key(164)
            r.listen(1)
        print("muted:", r.info.get("volume"))
        r.app("market://launch?id=com.netflix.ninja")
        r.listen(7)
        print("focus:", focus())
        print("media sessions in front:", adb("dumpsys media_session | grep -iE 'Media button session|media button' | head -3") or "(none)")
    finally:
        r.close()


def t_group(names):
    ke = KernelEvents()
    time.sleep(1.5)
    r = a.Remote(HOST)
    try:
        for g in names:
            for name, code in GROUPS[g]:
                k = press(r, ke, name, code, wait=2.5 if g == "inputs" else 0.9)
                print("  %-14s %-4s kernel: %-28s focus: %s" % (name, code, ",".join(k) or "NONE", focus()))
                if g == "inputs":
                    r.key(3)
                    r.listen(1.5)
    finally:
        r.close()
        ke.stop()


def t_finish():
    r = a.Remote(HOST)
    try:
        r.key(3)
        r.listen(2)
        if r.info["volume"]["muted"]:
            r.key(164)
            r.listen(1)
        print("final:", r.info.get("volume"), "focus:", focus())
    finally:
        r.close()


def t_keys():
    ke = KernelEvents()
    time.sleep(1.5)
    r = a.Remote(HOST)
    results = []
    try:
        print("start focus:", focus())
        r.key(3)                                            # HOME: wake and a known place to start
        r.listen(2)
        print("after HOME :", focus())
        r.key(164)                                          # mute so apps that autoplay stay quiet
        r.listen(1)
        print("muted      :", r.info.get("volume"))
        r.app("market://launch?id=com.netflix.ninja")       # Netflix: harmless target for navigation and media keys
        r.listen(7)
        print("netflix focus:", focus())
        sess = adb("dumpsys media_session | grep -i 'media button session'")
        print("media button session:", sess or "(none reported)")
        for group in (NAV_KEYS[:-2], MEDIA_KEYS):
            for name, code in group:
                k = press(r, ke, name, code)
                results.append((name, code, k, focus()))
                print("  %-14s %-4s kernel: %-28s focus: %s" % (name, code, ",".join(k) or "NONE", results[-1][3]))
        for name, code in NAV_KEYS[-2:] + OTHER_KEYS:
            k = press(r, ke, name, code)
            results.append((name, code, k, focus()))
            print("  %-14s %-4s kernel: %-28s focus: %s" % (name, code, ",".join(k) or "NONE", results[-1][3]))
        r.key(3)
        r.listen(2)
        print("HOME again :", focus())
        for name, code in INPUT_KEYS:
            k = press(r, ke, name, code, wait=2.5)
            results.append((name, code, k, focus()))
            print("  %-14s %-4s kernel: %-28s focus: %s" % (name, code, ",".join(k) or "NONE", results[-1][3]))
            r.key(3)
            r.listen(1.5)
        r.key(164)                                          # unmute
        r.listen(1)
        print("unmuted    :", r.info.get("volume"), "final focus:", focus())
    finally:
        r.close()
        ke.stop()


# ---------------------------------------------------------------- app links
def t_apps(only=None):
    r = a.Remote(HOST)
    before = {pkg: adb("pidof " + pkg) for pkg in OTT.values()}
    print("running before:", [n for n, p in OTT.items() if before[p]])
    try:
        r.key(3)
        r.listen(2)
        r.key(164)
        r.listen(1)
        print("muted:", r.info.get("volume"))
        for name, pkg in OTT.items():
            if only and name not in only:
                continue
            t = time.time()
            r.app("market://launch?id=" + pkg)
            r.listen(1)
            ok, f = False, ""
            while time.time() - t < 14:
                r.listen(1)
                f = focus()
                if f.startswith(pkg):
                    ok = True
                    break
            print("  %-12s %-5s after %4.1f s  focus: %s" % (name, "OK" if ok else "FAIL", time.time() - t, f))
            r.key(3)
            r.listen(1.5)
        r.key(164)
        r.listen(1)
        print("unmuted:", r.info.get("volume"), "focus:", focus())
    finally:
        r.close()
    stop = [pkg for pkg in OTT.values() if not before[pkg] and adb("pidof " + pkg)]
    for pkg in stop:                                        # leave the TV's memory as it was
        adb("am force-stop " + pkg)
    print("stopped again (were not running before):", stop)


# ---------------------------------------------------------------- wake
def t_wake():
    for label, code in (("HOME", 3), ("WAKEUP", 224)):
        adb("service call dreams 1")                        # start the screensaver
        time.sleep(3)
        before = focus()
        r = a.Remote(HOST)
        try:
            r.key(code)
            r.listen(2.5)
        finally:
            r.close()
        print("%-7s from %-45s -> %s" % (label, before, focus()))
        r_home = a.Remote(HOST)
        r_home.key(3)
        r_home.listen(1.5)
        r_home.close()


if __name__ == "__main__":
    test = sys.argv[1] if len(sys.argv) > 1 else ""
    arg = sys.argv[2] if len(sys.argv) > 2 else None
    if test == "discover":
        t_discover()
    elif test == "hold":
        t_hold(int(arg) if arg else 150)
    elif test == "setvol" and arg:
        t_setvol(int(arg))
    elif test == "keys":
        t_keys()
    elif test == "prep":
        t_prep()
    elif test == "group":
        t_group(arg.split(","))
    elif test == "finish":
        t_finish()
    elif test == "apps":
        t_apps(arg.split(",") if arg else None)
    elif test == "wake":
        t_wake()
    else:
        print(__doc__)
