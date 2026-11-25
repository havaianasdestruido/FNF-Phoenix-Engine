"""Offline validator for mods/win32modchart.

Runs the real Lua script against a faithful Python port of
  source/modchart/ModchartEvent.hx, ModchartEventManager.hx, PercentStore.hx
and of the modifier maths the script uses. It reports ease overlap on the same
(percent, side), the displacement budget the player can ever see, leftover
displacement between blocks, and the GDI call order.

Usage:  python3 tools/validate_win32modchart.py
Requires lupa (``pip install lupa``); see docs/HAXE_LINUX.md for the venv recipe.
"""
import json
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # repo root
LUA = os.path.join(ROOT, 'mods/win32modchart/data/win32modchart/win32modchart-erect.lua')
CHART = os.path.join(ROOT, 'mods/win32modchart/data/win32modchart/win32modchart-erect.json')

# --- ModchartEase ------------------------------------------------------------
def linear(t): return t
def sine_out(t): return math.sin(t * math.pi / 2)
def sine_in(t): return 1 - math.cos(t * math.pi / 2)
def sine_in_out(t): return -(math.cos(math.pi * t) - 1) / 2
def quad_out(t): return 1 - (1 - t) * (1 - t)
def quad_in(t): return t * t
def quad_in_out(t): return 2 * t * t if t < 0.5 else 1 - (-2 * t + 2) ** 2 / 2
EASES = {'linear': linear, 'sineOut': sine_out, 'sineIn': sine_in, 'sineInOut': sine_in_out,
         'quadOut': quad_out, 'quadIn': quad_in, 'quadInOut': quad_in_out}

# Modifiers that ship a non-zero default (Scale.hx, Transform.hx xmod, alpha).
NEUTRAL = {'xmod': 1.0, 'scale': 1.0, 'scalex': 1.0, 'scaley': 1.0, 'alpha': 1.0}

def norm(name):
    return str(name).lower().strip()

def clamp(v, lo, hi):
    return max(lo, min(hi, v))

class PercentStore:
    def __init__(self):
        self.data = {}

    def get(self, name, player):
        row = self.data.get(norm(name))
        key = int(player)
        if row is None or key not in row:
            return NEUTRAL.get(norm(name), 0.0)
        return row[key]

    def set(self, name, value, player):
        row = self.data.setdefault(norm(name), {})
        sides = [int(player)] if int(player) >= 0 else [0, 1]
        for side in sides:
            row[side] = float(value)

SET, EASE, CALLBACK = 0, 1, 2

class Event:
    """ModchartEvent.hx: eases capture their start value on the first update."""
    def __init__(self, kind, name, beat, length=0.0, target=0.0, player=-1, ease=linear):
        self.kind, self.name, self.beat, self.length = kind, name, beat, length
        self.target, self.player, self.ease = target, player, ease
        self.fired = False
        self.entries = [None, None]
        self.callback = None

    def update(self, cur, store):
        if self.kind == SET:
            if cur >= self.beat and not self.fired:
                store.set(self.name, self.target, self.player)
                self.fired = True
        elif self.kind == EASE:
            if self.fired:
                return
            progress = 1.0 if self.length <= 0 else clamp((cur - self.beat) / self.length, 0, 1)
            eased = self.ease(progress)
            for side in ([self.player] if self.player >= 0 else [0, 1]):
                if self.entries[side] is None:
                    self.entries[side] = store.get(self.name, side)
                start = self.entries[side]
                store.set(self.name, start + (self.target - start) * eased, side)
            if cur >= self.beat + self.length:
                self.fired = True
        else:
            if cur >= self.beat and not self.fired:
                self.fired = True
                if self.callback:
                    self.callback(cur)

class Manager:
    """ModchartEventManager.hx, plus an overlap audit and a call log."""
    def __init__(self):
        self.events = []
        self.store = PercentStore()
        self.lua = None
        self.overlaps = []
        self.calls = []

    def add(self, event):
        pos = len(self.events)
        while pos > 0 and self.events[pos - 1].beat > event.beat:
            pos -= 1
        self.events.insert(pos, event)
        if event.kind == EASE:
            for other in self.events:
                if other is event or other.kind != EASE:
                    continue
                if norm(other.name) != norm(event.name) or other.player != event.player:
                    continue
                # Two eases on one (percent, side) may not share a frame.
                if other.beat < event.beat + event.length - 1e-6 and \
                   event.beat < other.beat + other.length - 1e-6:
                    self.overlaps.append((norm(event.name), event.player,
                                          round(event.beat, 2), round(other.beat, 2)))

    def update(self, cur):
        for event in list(self.events):
            event.update(cur, self.store)
        self.events = [e for e in self.events if not e.fired]

    def fire(self, name, beat):
        self.calls.append((name, beat))
        globals_ = self.lua.globals()
        if globals_[name] is not None:
            globals_[name](beat)

def build(prefs=None):
    from lupa import LuaRuntime
    prefs = dict(prefs or {})
    defaults = {'flashing': True, 'reducedMotion': False, 'downScroll': False}
    defaults.update(prefs)

    lua = LuaRuntime(unpack_returned_tuples=True)
    mgr = Manager()
    mgr.lua = lua
    G = lua.globals()
    texts, objects, gdi = {}, {}, []

    G.debugPrint = lambda msg: None
    G.addModifier = lambda *a: True
    G.getModchartModifiers = lambda: lua.table()
    G.setPercent = lambda n, v, p=-1, f=-1: mgr.store.set(n, v, p)
    G.modSet = lambda n, b, v, p=-1, f=-1: mgr.add(Event(SET, n, b, 0, v, p))
    G.modEase = lambda n, b, l, v, e, p=-1, f=-1: mgr.add(Event(EASE, n, b, l, v, p, EASES.get(e, linear)))
    G.modCallback = lambda b, name, f=-1: _add_callback(mgr, b, name)
    G.resetModchart = lambda: None
    G.getProperty = lambda *a: 0.0
    G.getPropertyFromClass = lambda cls, field: defaults.get(field, False)

    def make_text(tag, text, width, x, y):
        objects[tag] = {'text': text, 'x': x, 'y': y, 'width': width, 'alpha': 1.0}
        texts[tag] = text

    def set_text(tag, value):
        if tag not in objects:
            texts[tag] = '<missing:%s>' % tag
            return
        objects[tag]['text'] = value
        texts[tag] = value

    def set_prop(path, value):
        if '.' not in path:
            return
        tag, prop = path.split('.', 1)
        if tag in objects:
            objects[tag][prop] = value

    G.makeLuaText = make_text
    G.addLuaText = lambda tag: objects.get(tag, {}).setdefault('added', True)
    G.setTextString = set_text
    G.setProperty = set_prop
    for name in ('setTextSize', 'setTextFont', 'setTextColor', 'setTextBorder', 'setTextAlignment',
                 'doTweenAlpha', 'cameraShake', 'setHealthBarColors', 'setTimeBarColors',
                 'doTweenZoom', 'gdiSetEffectWait'):
        G[name] = (lambda n: (lambda *a: None))(name)

    G.screenWidth, G.screenHeight = 1280, 720
    G.gdiInit = lambda: True
    G.gdiIsInitialized = lambda: True
    for name in ('gdiRegisterEffect', 'gdiEnableEffect', 'gdiDisableEffect', 'gdiUnregisterEffect',
                 'gdiSetEffectTitleText', 'gdiSetTitleText', 'gdiDrawIcons', 'gdiScreenBlink',
                 'gdiScreenGlitches', 'gdiScreenTunnel', 'gdiScreenShake', 'gdiSetPaused',
                 'gdiDestroy', 'gdiHppdStopAll', 'gdiHppdTrigger'):
        G[name] = (lambda n: (lambda *a: (gdi.append((n,) + a), True)[1]))(name)
    # docs/GDI_HPPD.md
    heavy = {1, 2, 5, 6, 7, 8, 9, 10, 11, 13, 14, 15, 17, 19, 20, 21, 22, 23, 24, 40, 48} | set(range(50, 64))
    G.gdiHppdIsHeavy = lambda i: int(i) in heavy or 101 <= int(i) <= 131
    G.gdiHppdIsRunning = lambda i: False
    G.curBeat = 0

    with open(LUA, encoding='utf-8') as handle:
        lua.execute(handle.read())
    G.onCreatePost()
    return lua, mgr, G, texts, objects, gdi

def _add_callback(mgr, beat, name):
    event = Event(CALLBACK, name, beat)
    event.callback = lambda fire_beat: mgr.fire(name, fire_beat)
    mgr.add(event)

def displacement(store, side):
    """What the player can actually see, in px / deg / scale.

    Transform.hx adds `x + xoffset + x<lane>` to each lane separately, so the
    worst case is the largest single lane, not the sum over lanes.
    """
    lanes = [store.get('x', side) + store.get('xoffset', side) + store.get('x%d' % lane, side)
             for lane in range(4)]
    x = max(lanes, key=abs)
    y = store.get('y', side) + store.get('yoffset', side)
    invert = abs(store.get('invert', side)) * 112        # Invert.hx: 112 px per lane
    rot = sum(store.get(n, side) for n in ('rotateZ', 'centerRotateZ', 'localRotateZ'))
    bounce = abs(store.get('bounceY', side)) * 112       # Bounce.hx
    drunk = abs(store.get('drunkX', side)) * 56          # Drunk.hx
    saw = abs(store.get('sawtooth', side)) * 112         # SawTooth.hx
    scale = store.get('scale', side) * (1 - store.get('zoom', side) * 0.5)  # Scale + Zoom.hx
    return (abs(x) + invert + drunk + saw, abs(y) + bounce, abs(rot), scale)

def audit(step=0.05, max_beat=420.0):
    lua, mgr, G, texts, objects, gdi = build()
    peak = {'x': 0.0, 'y': 0.0, 'rot': 0.0, 'min': 1.0, 'max': 1.0}
    leftovers = []
    both = 0
    beat = 0.0
    while beat <= max_beat:
        G.curBeat = int(beat)
        mgr.update(beat)
        rows = {}
        for side in (0, 1):
            rows[side] = displacement(mgr.store, side)
            dx, dy, rot, scale = rows[side]
            peak['x'] = max(peak['x'], dx)
            peak['y'] = max(peak['y'], dy)
            peak['rot'] = max(peak['rot'], rot)
            peak['min'] = min(peak['min'], scale)
            peak['max'] = max(peak['max'], scale)
        if all(rows[s][0] > 2 or rows[s][1] > 2 or rows[s][2] > 0.3 or abs(rows[s][3] - 1) > 0.005
               for s in (0, 1)):
            both += 1
        # Between blocks every percent must be back home.
        if abs(beat - round(beat)) < 1e-9 and int(round(beat)) % 4 == 0 and beat >= 6:
            for side in (0, 1):
                dx, dy, rot, scale = rows[side]
                if dx > 1 or dy > 1 or rot > 0.15 or abs(scale - 1) > 0.01:
                    leftovers.append((round(beat, 2), side, round(dx, 1), round(dy, 1),
                                      round(rot, 2), round(scale, 3)))
        beat += step
    return mgr, texts, objects, gdi, peak, leftovers, both

def main():
    failures = []

    # 1. The chart itself.
    with open(CHART, encoding='utf-8') as handle:
        raw = json.load(handle)
    song = raw['song']
    checks = [
        ('chart song is WIN32MODCHART', song['song'] == 'WIN32MODCHART'),
        ('chart folder matches formatToSongPath', song['song'].lower() == 'win32modchart'),
        ('bpm 190 / speed 2.4', song['bpm'] == 190.0 and song['speed'] == 2.4),
        ('no inline events', 'events' not in song),
    ]
    for label, ok in checks:
        print(('PASS  ' if ok else 'FAIL  ') + label)
        if not ok:
            failures.append(label)

    # 2. Every hand-over in the chart is a turn in the script, and vice versa.
    sections = song['notes']
    runs, start, cur = [], 0, sections[0]['mustHitSection']
    for index in range(1, len(sections)):
        if sections[index]['mustHitSection'] != cur:
            runs.append((cur, start, index - 1))
            start, cur = index, sections[index]['mustHitSection']
    runs.append((cur, start, len(sections) - 1))

    mgr, texts, objects, gdi, peak, leftovers, both = audit()

    turns = lua_turns()
    expected = [(('bf' if side else 'dad'), a * 4, (b - a + 1) * 4) for side, a, b in runs]
    actual = [(t['who'], t['beat'], t['beats']) for t in turns]
    ok = expected == actual
    print(('PASS  ' if ok else 'FAIL  ') + 'turn table matches the chart hand-overs (%d turns)' % len(expected))
    if not ok:
        failures.append('turn table')
        for want, have in zip(expected, actual):
            if want != have:
                print('        chart %s | script %s' % (want, have))

    # 2b. The source gate. A finding closes the script before it ever runs.
    findings = scan_source(LUA)
    ok = not findings
    print(('PASS  ' if ok else 'FAIL  ') + 'script passes ScriptSecurityScanner (%d findings)' % len(findings))
    if not ok:
        failures.append('security scanner')
        for number, rule, snippet in findings:
            print('        line %d [%s] %s' % (number, rule, snippet))
    for extra in ('pack.json', 'weeks/win32modchart-week.json'):
        path = os.path.join(ROOT, 'mods', 'win32modchart', extra)
        with open(path, encoding='utf-8') as handle:
            json.load(handle)
    print('PASS  pack.json and week JSON parse')

    # 3. Keyboard safety budgets.
    budgets = [
        ('|x| <= 64 px', peak['x'] <= 64.0, '%.1f' % peak['x']),
        ('|y| <= 40 px', peak['y'] <= 40.0, '%.1f' % peak['y']),
        ('|rotation| <= 8 deg', peak['rot'] <= 8.0, '%.1f' % peak['rot']),
        ('scale within 0.84..1.12', 0.84 <= peak['min'] and peak['max'] <= 1.12,
         '%.2f..%.2f' % (peak['min'], peak['max'])),
        ('no ease overlaps on one percent', not mgr.overlaps, '%d' % len(mgr.overlaps)),
        ('nothing left displaced between blocks', not leftovers, '%d' % len(leftovers)),
        ('never both sides moving at once', both == 0, '%d frames' % both),
    ]
    for label, ok, detail in budgets:
        print(('PASS  ' if ok else 'FAIL  ') + '%s (%s)' % (label, detail))
        if not ok:
            failures.append(label)

    # 4. GDI teardown: everything turned on is turned off again.
    enabled = [c[1] for c in gdi if c[0] == 'gdiEnableEffect']
    disabled = [c[1] for c in gdi if c[0] == 'gdiDisableEffect']
    unregistered = [c[1] for c in gdi if c[0] == 'gdiUnregisterEffect']
    ok = sorted(set(enabled)) == sorted(set(disabled)) == sorted(set(unregistered))
    print(('PASS  ' if ok else 'FAIL  ') + 'every GDI effect is disabled and unregistered'
          + (' (%s)' % ', '.join(sorted(set(enabled)))))
    if not ok:
        failures.append('GDI teardown')
        print('        enabled:      %s' % enabled)
        print('        disabled:     %s' % disabled)
        print('        unregistered: %s' % unregistered)
    for c in gdi:
        if c[0] in ('gdiDestroy', 'gdiHppdStopAll', 'gdiSetTitleText'):
            print('        %s%s' % (c[0], '' if c[0] == 'gdiDestroy' else str(c[1:])))

    # 5. HUD stories.
    ok = 'CLIMAX' in texts.get('w32Side', '')
    print(('PASS  ' if ok else 'FAIL  ') + 'HUD reaches the climax banner (%s)' % texts.get('w32Side'))
    if not ok:
        failures.append('HUD climax banner')
    print('        HUD: %s' % texts)
    print('        HUD objects: %s' % {k: (v['x'], v['y'], v['width']) for k, v in objects.items()})

    print()
    if failures:
        print('%d CHECK(S) FAILED: %s' % (len(failures), ', '.join(failures)))
        return 1
    print('ALL CHECKS PASSED')
    return 0

# Source gate, transcribed from source/backend/ScriptSecurityScanner.hx.
# Each entry is (rule id, EReg-equivalent pattern). `isCommentOnly` is applied
# per line exactly like the engine does.
SCANNER_RULES = [
    ('lua.os', r'\bos\s*(?:\.|\[)'),
    ('lua.io', r'\bio\s*(?:\.|\[)'),
    ('lua.package', r'\b(?:package\s*(?:\.|\[)|require\s*\(|module\s*\()'),
    ('lua.dynamic-code', r'\b(?:dofile|loadfile|loadstring|load)\s*\('),
    ('lua.native', r'\b(?:debug|ffi|jit)\s*(?:\.|\[|\()'),
    ('engine.file-read', r'\b(?:getTextFromFile|checkFileExists|directoryFileList)\b'),
    ('engine.file-write', r'\b(?:saveFile|deleteFile)\b'),
    ('engine.script-loader', r'\b(?:addLuaScript|addPythonScript|addHScript|addScript)\b'),
    ('engine.native-class',
     r'\b(?:getPropertyFromClass|setPropertyFromClass)\s*\(\s*["\'](?:Sys|Type|Reflect|StdFire|'
     r'LimeNativeText|sys\.|cpp\.|neko\.|hl\.|java\.|objc\.|haxe\.Http|backend\.(?:ModSecurity|Mods|'
     r'StdFire|LimeNativeText)|psychlua\.|openfl\.(?:Lib|net|filesystem)|lime\.(?:system|app|net)|'
     r'utils\.PlatformUtil|system\.|slushithings\.|android\.|ios\.|mac\.)'),
    ('process.shell',
     r'(?:\bpython(?:3(?:\.\d+)*)?\s+-[A-Za-z]*c\b|\bpy\s+-[A-Za-z]*c\b|\bcmd(?:\.exe)?\s*\/c\b|'
     r'\b(?:powershell|pwsh)(?:\.exe)?\b|\b(?:bash|sh)\s+-c\b|\/bin\/(?:bash|sh)\b|'
     r'\b(?:curl|wget)(?:\.exe)?\b)'),
    ('network.url', r'(?:https?|ftp|file):\/\/'),
    ('network.api',
     r'(?:\b(?:socket|requests?|urllib|ftplib)\s*(?:\.|\[|\()|\brequire\s*\(\s*["\'](?:socket|http|https|ssl|ftp))'),
]

def scan_source(path, language='lua'):
    """One-to-one with ScriptSecurityScanner.scan(): comment lines are skipped."""
    import re
    with open(path, encoding='utf-8') as handle:
        lines = handle.read().split('\n')
    findings = []
    for number, line in enumerate(lines, start=1):
        if line.endswith('\r'):
            line = line[:-1]
        stripped = line.lstrip()
        if language == 'lua':
            if stripped.startswith('--'):
                continue
        if not stripped:
            continue
        for rule, pattern in SCANNER_RULES:
            if re.search(pattern, line, re.IGNORECASE):
                findings.append((number, rule, line.strip()[:120]))
    return findings

def lua_turns():
    """Evaluate the script's own TURNS literal (it is a Lua local)."""
    from lupa import LuaRuntime
    with open(LUA, encoding='utf-8') as handle:
        source = handle.read()
    start = source.index('local TURNS = {')
    end = source.index('\n}', start) + 2
    literal = source[start + len('local '):end]
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('DAD = 0\nBF = 1\n' + literal)
    turns_lua = lua.globals().TURNS
    out = []
    for index in range(1, len(turns_lua) + 1):
        entry = turns_lua[index]
        out.append({'who': 'bf' if int(entry.who) == 1 else 'dad',
                    'beat': int(entry.beat), 'beats': int(entry.beats)})
    return out

if __name__ == '__main__':
    sys.exit(main())
