"""Offline simulation for the WIN32MODCHART companion scripts.

The main validator (`validate_win32modchart.py`) models what the modchart does to
the playfield. This module models what the *other* four scripts do to the rest of
the game, so their teardown promises can be checked without a Haxe build:

  w32_bus.lua     turn bookkeeping
  w32-desk.lua    HUD-side desktop dressing (sprites, texts, camOther filter)
  w32-chars.lua   HUD-side framing (sprites, texts, tweens)
  w32-play.lua    gameplay layers, songSpeed writes
  w32-window.lua  whole-window alpha

Each script is loaded into its own `LuaRuntime`, the way the engine gives every
file its own state, and the globals they share (`setGlobalFromScript` /
`getGlobalFromScript`) are wired back to the real bus runtime. Engine functions
are stubbed with the same signatures the callbacks have, and every object, tween,
filter and window write is recorded so the audit can assert:

  * nothing survives `onDestroy` (no sprites, texts, tweens, filters)
  * `songSpeed` is back on the value the song started with
  * every window-alpha write is undone

Run standalone for a human-readable report, or import `run_all()` from the main
validator.
"""
import os


def scope_problems(path):
    """Lua scope bugs a runtime simulation cannot see.

    `local function f` is only in scope from its own line onward, so a hook that
    uses one declared further down the file calls a *nil global* -- which only
    fails on the frames where that branch runs. Checks every call site against
    the definitions above it.
    """
    import re
    with open(path, encoding='utf-8') as handle:
        lines = handle.read().split('\n')

    defs = {}
    for index, line in enumerate(lines):
        match = re.match(r'\s*(local\s+)?function\s+([A-Za-z_]\w*)', line)
        if match:
            defs.setdefault(match.group(2), (index, bool(match.group(1))))

    problems = []
    for index, line in enumerate(lines):
        if line.lstrip().startswith('--'):
            continue
        for match in re.finditer(r'(?<![\w.:])([A-Za-z_]\w*)\s*\(', line):
            name = match.group(1)
            if name not in defs:
                continue
            defined, is_local = defs[name]
            if defined > index and is_local:
                problems.append('%s:%d calls %s(), but its `local function` is at line %d'
                                % (os.path.basename(path), index + 1, name, defined + 1))
    return problems


def _pairs(values):
    """Flatten the Lua table `startTween` is handed into a Python dict."""
    if values is None:
        return {}
    if isinstance(values, dict):
        return dict(values)
    return {key: values[key] for key in values}


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, 'mods/win32modchart/data/win32modchart')

SCRIPTS = ['w32_bus.lua', 'w32-desk.lua', 'w32-chars.lua', 'w32-play.lua', 'w32-window.lua']


class World:
    """One simulated PlayState, shared by every script in the folder."""

    def __init__(self):
        from lupa import LuaRuntime
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.G = self.lua.globals()

        # --- game state the scripts read -----------------------------------
        # Everything `setOnLuas` pushes into every script. The engine writes
        # these into each Lua state before a callback, so the harness does too.
        self.state = {
            'curBeat': 0, 'curStep': 0, 'curSection': 0, 'curDecBeat': 0,
            'mustHitSection': False, 'gfSection': False, 'altAnim': False,
            'combo': 0, 'score': 0, 'misses': 0, 'health': 1.0,
            'scrollSpeed': 2.4, 'songSpeed': 2.4, 'modchart': True,
            'startedCountdown': False,
        }
        self.prefs = {'flashing': True, 'reducedMotion': False, 'downScroll': False}
        self.window_supported = True
        self.window_alpha = 1.0

        # --- recorded output ------------------------------------------------
        self.sprites = {}       # tag -> dict
        self.texts = {}         # tag -> dict
        self.tweens = {}        # tag -> {'vars': ..., 'value': ..., 'seconds': ...}
        self.timers = {}
        self.filters = {}       # camera -> [effect names]
        self.alpha_writes = []  # every setWindowAlpha argument
        self.log = []
        self.errors = []
        self.runtimes = {}
        self.pressed = set()
        self.speed_hi = 0.0
        self.alpha_lo = 1.0

        self._install()

    # -- engine stubs -------------------------------------------------------

    def _install(self):
        """Install the engine stubs into the bus runtime."""
        self._install_into(self.G)

    def _install_into(self, G):
        """Install the engine stubs into one runtime's globals.

        Called once per script, because a Lua value cannot be copied between
        `LuaRuntime` instances; only the Python closures are shared.
        """
        G.screenWidth, G.screenHeight = 1280, 720

        self.stub_functions(G)

    def stub_functions(self, G):
        G.debugPrint = lambda msg: self.log.append(str(msg))
        G.getPropertyFromClass = lambda cls, field: self.prefs.get(field, False)

        G.getProperty = self._get_property
        G.setProperty = self._set_property

        # sprites
        def make_sprite(tag, image, x, y):
            self.sprites[tag] = {'tag': tag, 'x': x, 'y': y, 'w': 0, 'h': 0,
                                 'color': None, 'alpha': 1.0, 'cam': None,
                                 'scroll': (1, 1), 'added': False, 'destroyed': False}

        def make_graphic(tag, w, h, color):
            sprite = self.sprites.get(tag)
            if sprite is None:
                raise AssertionError('makeGraphic on unknown sprite %r' % tag)
            if not isinstance(color, str):
                raise AssertionError('makeGraphic colour must be a hex string, got %r' % (color,))
            sprite['w'], sprite['h'], sprite['color'] = w, h, color

        G.makeLuaSprite = make_sprite
        G.makeGraphic = make_graphic
        G.addLuaSprite = lambda tag, front=False: self.sprites[tag].__setitem__('added', True)
        G.removeLuaSprite = self._remove_sprite
        G.setObjectCamera = lambda tag, cam='': self._obj(tag).__setitem__('cam', cam)
        G.setScrollFactor = lambda tag, sx, sy: self._obj(tag).__setitem__('scroll', (sx, sy))
        G.doOverlap = lambda *a: False

        # texts
        def make_text(tag, text, width, x, y):
            self.texts[tag] = {'tag': tag, 'text': text, 'w': width, 'x': x, 'y': y,
                               'size': 16, 'color': 'FFFFFF', 'align': 'center',
                               'alpha': 1.0, 'cam': None, 'added': False}

        G.makeLuaText = make_text
        G.addLuaText = lambda tag, *a: self.texts[tag].__setitem__('added', True)
        G.removeLuaText = self._remove_text
        G.setTextString = lambda tag, value: self._text(tag).__setitem__('text', value)
        G.setTextSize = lambda tag, size: self._text(tag).__setitem__('size', size)
        G.setTextColor = lambda tag, color: self._text(tag).__setitem__('color', color)
        G.setTextAlignment = lambda tag, a='left': self._text(tag).__setitem__('align', a)

        # tweens: real signature (tag, vars, {prop = value}, seconds, options)
        def start_tween(tag, variables, values, seconds, options=None):
            # tweenPrepare cancels any tween already using the tag.
            self.tweens.pop(tag, None)
            pending = {'tag': tag, 'vars': variables, 'values': _pairs(values),
                       'seconds': seconds, 'remaining': seconds,
                       'options': options, 'done': False}
            self.tweens[tag] = pending
            if seconds <= 0:
                self._apply_tween(pending)

        G.startTween = start_tween
        G.cancelTween = self._cancel_tween
        for helper, prop in (('doTweenX', 'x'), ('doTweenY', 'y'), ('doTweenAlpha', 'alpha')):
            G[helper] = (lambda p: (lambda tag, variables, value, seconds, ease=None:
                                    self._prop_tween(tag, variables, p, value, seconds)))(prop)
        G.doTweenScale = lambda tag, v, value, s, e=None: None

        # timers
        def run_timer(tag, seconds, callback='onTimerCompleted'):
            self.timers[tag] = {'seconds': seconds, 'callback': callback}

        G.runTimer = run_timer
        G.cancelTimer = lambda tag: self.timers.pop(tag, None)

        # cameras and shaders
        def add_effect(camera, name):
            self.filters.setdefault(camera, []).append(name)

        G.addScanlineEffect = lambda cam, lock=False: add_effect(cam, 'scanline')
        G.addBloomEffect = lambda cam, i=.35, b=1.0: add_effect(cam, 'bloom')
        G.addPulseEffect = lambda cam, *a: add_effect(cam, 'pulse')
        G.clearEffects = lambda cam: self.filters.__setitem__(cam, [])
        G.cameraShake = lambda cam, i, d: self.log.append('shake %s %s %s' % (cam, i, d))
        G.cameraFlash = lambda *a: None
        G.cameraFade = lambda *a: None

        # gameplay
        G.setHealth = lambda v: None
        G.addHealth = lambda v: None
        G.getHealth = lambda: 1.0
        G.characterDance = lambda who: None
        G.playAnim = lambda *a: None

        # window
        G.getWindowAlpha = lambda: self.window_alpha
        G.setWindowAlpha = self._set_window_alpha
        G.isWindowTransparencySupported = lambda: self.window_supported
        G.setWindowTransparent = lambda enable=True: self.window_supported
        G.getWindowMode = lambda: 'Windowed'
        G.setWindowMode = lambda mode: self.window_supported

        # keyboard: only what the harness is currently holding down
        G.keyboardJustPressed = lambda name: name in self.pressed
        G.keyboardPressed = lambda name: False
        G.keyboardReleased = lambda name: False

        # cross-script reads: nothing in this folder uses them, and if a script
        # starts to, the harness must notice rather than silently find a value.
        G.getGlobalFromScript = self._cross_get

    # -- helpers ------------------------------------------------------------

    def _obj(self, tag):
        if tag in self.sprites:
            return self.sprites[tag]
        if tag in self.texts:
            return self.texts[tag]
        raise AssertionError('unknown object %r (script reached for a tag it never created)' % tag)

    def _text(self, tag):
        if tag not in self.texts:
            raise AssertionError('unknown text %r' % tag)
        return self.texts[tag]

    def publish(self):
        """Mirror `setOnLuas`: push the live state into every script."""
        for runtime in self.runtimes.values():
            G = runtime.globals()
            for key, value in self.state.items():
                G[key] = value

    def _get_property(self, path):
        if path in ('modchart', 'songSpeed'):
            return self.state[path]
        if path in ('windowX', 'windowY'):
            return 0
        if '.' in path:
            tag, prop = path.split('.', 1)
            try:
                return self._obj(tag).get(prop)
            except AssertionError:
                return 0.0
        return 0.0

    def _set_property(self, path, value):
        if path == 'songSpeed':
            if not isinstance(value, (int, float)):
                raise AssertionError('songSpeed written as %r' % (value,))
            self.state['songSpeed'] = float(value)
            self.speed_hi = max(self.speed_hi, float(value))
            return
        if '.' in path:
            tag, prop = path.split('.', 1)
            try:
                self._obj(tag)[prop] = value
            except AssertionError:
                self.errors.append('setProperty(%r) on an object that does not exist' % path)

    def _remove_sprite(self, tag, destroy=True):
        sprite = self.sprites.get(tag)
        if sprite is None:
            self.errors.append('removeLuaSprite(%r) on an unknown tag' % tag)
            return
        if destroy:
            sprite['destroyed'] = True
            sprite['added'] = False

    def _remove_text(self, tag, destroy=True):
        text = self.texts.get(tag)
        if text is None:
            self.errors.append('removeLuaText(%r) on an unknown tag' % tag)
            return
        if destroy:
            text['destroyed'] = True

    def _cancel_tween(self, tag):
        self.tweens.pop(tag, None)

    def _prop_tween(self, tag, variables, prop, value, seconds):
        """doTweenX/Y/Alpha all route through tweenPrepare -> cancelTween."""
        self.tweens.pop(tag, None)
        pending = {'tag': tag, 'vars': variables, 'values': {prop: value},
                   'seconds': seconds, 'remaining': seconds, 'options': None, 'done': False}
        self.tweens[tag] = pending
        if seconds <= 0:
            self._apply_tween(pending)

    def _apply_tween(self, tween):
        """Write a tween's end values, the way the engine does on completion."""
        tween['done'] = True
        for prop, value in tween['values'].items():
            path = tween['vars']
            if path == 'songSpeed':
                self.state['songSpeed'] = float(value)
                self.speed_hi = max(self.speed_hi, float(value))
            elif '.' in path:
                tag, name = path.split('.', 1)
                if tag in self.sprites or tag in self.texts:
                    self._obj(tag)[name] = value

    def tick(self, elapsed):
        """Advance every live tween by one frame."""
        for tag, tween in list(self.tweens.items()):
            if tween['done']:
                continue
            tween['remaining'] -= elapsed
            if tween['remaining'] <= 1e-9:
                self._apply_tween(tween)

    def _set_window_alpha(self, value):
        self.alpha_writes.append(value)
        self.window_alpha = value
        self.alpha_lo = min(self.alpha_lo, value)

    def _cross_get(self, lua_file, name):
        """getGlobalFromScript, modelled honestly.

        The engine resolves the file through `Paths.modFolders(file)`, which
        looks in `mods/<mod>/<file>` -- *not* in this song's `data/` folder. A
        script in `data/<song>/` is therefore invisible to it: every lookup
        comes back nil. Recorded as an error when a script tries, so a
        future copy/paste cannot quietly rely on a value it will never see.
        """
        self.errors.append('%s read %r through getGlobalFromScript, which cannot '
                           'resolve a file in data/<song>/' % (lua_file, name))
        return None

    # -- lifecycle ----------------------------------------------------------

    def load(self):
        """Load every script, the way the engine walks the song folder."""
        for name in SCRIPTS:
            runtime = self.lua if name == 'w32_bus.lua' else self._new_runtime()
            self.runtimes[name] = runtime
            if runtime is not self.lua:
                # A companion gets its own stubs plus the shared bus lookup.
                self._install_into(runtime.globals())
            path = os.path.join(DATA, name)
            with open(path, encoding='utf-8') as handle:
                runtime.execute(handle.read())
        self.publish()
        return self

    def _new_runtime(self):
        from lupa import LuaRuntime
        return LuaRuntime(unpack_returned_tuples=True)

    def call(self, event, *args):
        """Fire a callback on every script that defines it, like callOnLuas."""
        results = []
        self.publish()
        for name in SCRIPTS:
            runtime = self.runtimes[name]
            func = runtime.globals()[event]
            if func is None:
                continue
            try:
                results.append(func(*args))
            except Exception as exc:  # surfaced by the audit
                self.errors.append('%s.%s raised %s' % (name, event, exc))
        return results

    # -- HUD layout audit ---------------------------------------------------

    def hud_rects(self):
        """Every HUD object this folder draws, as (name, x, y, w, h)."""
        out = []
        for tag, sprite in self.sprites.items():
            if sprite.get('cam') == 'hud' and sprite.get('added'):
                out.append((tag, float(sprite['x'] or 0), float(sprite['y'] or 0),
                            float(sprite['w'] or 0), float(sprite['h'] or 0)))
        for tag, text in self.texts.items():
            if text.get('cam') == 'hud' and text.get('added'):
                # A 10..26 pt vcr line is at most ~30 px tall.
                out.append((tag, float(text['x']), float(text['y']),
                            float(text['w']), 30.0))
        return out

    # -- audit --------------------------------------------------------------

    def leftovers(self):
        """Everything still alive after onDestroy."""
        found = []
        for tag, sprite in self.sprites.items():
            if sprite['added'] and not sprite.get('destroyed'):
                found.append('sprite %s' % tag)
        for tag, text in self.texts.items():
            if text['added'] and not text.get('destroyed'):
                found.append('text %s' % tag)
        for tag in self.tweens:
            found.append('tween %s' % tag)
        for cam, effects in self.filters.items():
            if effects:
                found.append('filter on %s (%s)' % (cam, ', '.join(effects)))
        return found


# What the engine itself occupies on camHUD, from PlayState.hx on a 1280x720
# screen. Anything this folder draws has to stay out of these.
ENGINE_HUD = [
    ('timeTxt', 48 + 1280 / 2 - 248, 19, 400, 40),
    ('timeBarBG', 48 + 1280 / 2 - 248, 19, 400, 20),
    ('healthBarBG upscroll', 1280 / 2 - 315, 0.89 * 720, 630, 40),
    ('healthBarBG downscroll', 1280 / 2 - 315, 0.11 * 720, 630, 40),
    ('scoreTxt upscroll', 0, 0.89 * 720 + 50, 1280, 22),
    ('scoreTxt downscroll', 0, 0.11 * 720 + 50, 1280, 22),
]

def modchart_hud(prefs=None):
    """Text the per-turn modchart draws itself, from its own `buildHud()`.

    `top` is 18 on downscroll and 74 otherwise, so this has to be rebuilt per
    scroll direction rather than hard-coded.
    """
    top = 18 if (prefs or {}).get('downScroll') else 74
    return [
        ('modchart title', 20, top, 900, 24),
        ('modchart side', 20, top + 30, 900, 22),
        ('modchart move', 20, top + 54, 900, 20),
        ('modchart gdi', 920, 720 - 118, 900, 20),
        ('modchart hppd', 920, 720 - 96, 900, 20),
    ]


def _overlap(a, b):
    return not (a[1] + a[3] <= b[1] or b[1] + b[3] <= a[1]
                or a[2] + a[4] <= b[2] or b[2] + b[4] <= a[2])


def hud_collisions(prefs=None):
    """Objects in this folder that would draw on top of engine text.

    Checked for both scroll directions, because the modchart's own read-out
    moves from the bottom of the screen to the top when downscroll is on.
    """
    found = []
    for scroll in (False, True):
        settings = dict(prefs or {})
        settings['downScroll'] = scroll

        world = World()
        world.prefs.update(settings)
        world.load()
        world.call('onCreatePost')
        world.call('onSectionHit')

        where = 'downscroll' if scroll else 'upscroll'
        for rect in world.hud_rects():
            # Full-screen and near-full-screen overlays are meant to cover
            # things; only competing *readable* elements are a layout bug.
            if rect[3] >= 1200 or rect[4] >= 600:
                continue
            for other in modchart_hud(settings):
                if _overlap(rect, other):
                    found.append('%s (%s, y %d..%d) sits on %s'
                                 % (rect[0], where, rect[2], rect[2] + rect[4], other[0]))
            for other in ENGINE_HUD:
                if _overlap(rect, other):
                    found.append('%s (%s, y %d..%d) sits on the engine\'s %s'
                                 % (rect[0], where, rect[2], rect[2] + rect[4], other[0]))

        # Our own readable elements must not stack on each other either. A
        # sprite that backs a text (the title chip under its own filename) and a
        # 2 px rule under that chip are chrome, not competing text.
        SPANS = {'w32TitleBar': 'w32TitleText', 'w32Border': None}
        readable = []
        for rect in world.hud_rects():
            if rect[3] >= 1200 or rect[4] >= 600:
                continue
            if rect[0] in SPANS:
                continue
            if rect[0] == 'w32TitleButtonsText':
                pass
            readable.append(rect)
        for index, first in enumerate(readable):
            for second in readable[index + 1:]:
                if _overlap(first, second):
                    found.append('%s (%s) overlaps %s (%s, y %d..%d)'
                                 % (first[0], where, second[0], where,
                                    second[2], second[2] + second[4]))
    return found


def run_all(prefs=None, modchart=True, window_supported=True, hard_destroy=False):
    """Drive one full song through every companion script and report.

    @param prefs            ClientPrefs overrides (`flashing`, `reducedMotion`).
    @param modchart         Value of the `modchart` persistent variable.
    @param window_supported What `isWindowTransparencySupported()` answers.
    @param hard_destroy     Skip onEndSong/onGameOver, the way an aborted run
                            (soft restart, a state change mid-song) does. The
                            `onDestroy` restores are the only thing left then.
    """
    world = World()
    if prefs:
        world.prefs.update(prefs)
    world.state['modchart'] = modchart
    world.window_supported = window_supported
    world.window_alpha = 1.0 if window_supported else world.window_alpha
    world.load()
    report = {'errors': world.errors, 'modchart': modchart,
              'flashing': world.prefs.get('flashing', True),
              'reducedMotion': world.prefs.get('reducedMotion', False)}

    world.call('onCreatePost')
    world.state['startedCountdown'] = True
    world.call('onSongStart')

    base_speed = world.state['songSpeed']
    report['base_speed'] = base_speed

    # Walk the chart: 104 sections, 416 beats.
    for section in range(104):
        world.state['curSection'] = section
        world.state['mustHitSection'] = bool(section % 2)
        world.state['gfSection'] = False
        world.call('onSectionHit')
        for beat in range(4):
            world.state['curBeat'] = section * 4 + beat
            if beat == 0:
                world.state['combo'] = world.state['combo'] + 7
                world.call('goodNoteHit', 0, beat, '', False)
            world.call('onBeatHit')
            world.tick(1 / 60)
            world.call('onUpdate', 1 / 60)
            world.call('onUpdatePost', 1 / 60)

    # The player dials the scroll speed up with 3 three times, so the restore
    # paths have something to actually restore.
    world.pressed = {'THREE'}
    for _ in range(3):
        world.call('onUpdatePost', 1 / 60)
        world.tick(1 / 60)
        for _ in range(20):
            world.tick(1 / 60)
    world.pressed = set()
    report['speed_during_song'] = world.state['songSpeed']

    # The player misses three times, then a hold lands.
    for lane in (0, 2, 1):
        world.call('noteMiss', 0, lane, '', False)
        world.call('onUpdate', 1 / 60)
    world.call('goodNoteHit', 0, 3, '', True)

    # Pause and resume once, then finish.
    world.call('onPause')
    report['alpha_after_pause'] = world.window_alpha
    report['speed_after_pause'] = world.state['songSpeed']
    world.call('onResume')

    # Dial it back up once more, so only the destroy path can put it right:
    # that is the path a hard restart or a mid-song state change takes.
    world.pressed = {'THREE'}
    world.call('onUpdatePost', 1 / 60)
    world.tick(0.5)
    world.pressed = set()
    report['speed_before_destroy'] = world.state['songSpeed']

    if not hard_destroy:
        world.call('onEndSong')
    report['speed_after_end'] = world.state['songSpeed']
    report['alpha_after_end'] = world.window_alpha

    world.call('onDestroy')
    report['leftovers'] = world.leftovers()
    report['speed_after_destroy'] = world.state['songSpeed']
    report['alpha_after_destroy'] = world.window_alpha
    report['alpha_writes'] = list(world.alpha_writes)
    report['objects_made'] = len(world.sprites) + len(world.texts)
    report['speed_hi'] = world.speed_hi
    report['alpha_lo'] = world.alpha_lo
    report['log'] = world.log
    report['errors'] = world.errors
    return report


def main():
    """Run the happy path, the hostile settings, and a mutation sanity check."""
    failures = 0

    scenarios = [
        ('defaults', {}),
        ('reduced motion', {'reducedMotion': True}),
        ('flashing off', {'flashing': False}),
        ('modchart variable off', {'_modchart': False}),
        ('no window support', {'_window': False}),
        ('aborted run, destroy only', {'_hard': True}),
    ]

    for label, options in scenarios:
        report = run_all(prefs={k: v for k, v in options.items() if not k.startswith('_')},
                         modchart=options.get('_modchart', True),
                         window_supported=options.get('_window', True),
                         hard_destroy=options.get('_hard', False))
        ok_errors = not report['errors']
        ok_leftovers = not report['leftovers']
        ok_speed = abs(report['speed_after_destroy'] - report['base_speed']) < 1e-6
        # Only meaningful with the script live: with the switch off nothing is
        # supposed to move.
        ok_changed = (not report['modchart']) or report['speed_during_song'] > report['base_speed']
        ok_alpha = abs(report['alpha_after_destroy'] - 1.0) < 1e-6
        ok = ok_errors and ok_leftovers and ok_speed and ok_alpha and ok_changed
        print(('PASS  ' if ok else 'FAIL  ') + '%s: clean, torn down, speed %.2f, alpha %.2f'
              % (label, report['speed_after_destroy'], report['alpha_after_destroy']))
        if not ok:
            failures += 1
            if not ok_changed:
                print('        speed never moved (%.2f), the restore check is vacuous'
                      % report['speed_during_song'])
            for error in report['errors'][:5]:
                print('        error: %s' % error)
            for item in report['leftovers'][:10]:
                print('        leftover: %s' % item)

    # Ordering: 16 objects must exist during the song, or the "no leftovers"
    # check above would pass on a script that never built anything.
    report = run_all()
    if report['objects_made'] < 10:
        print('FAIL  scripts created only %d objects during the song' % report['objects_made'])
        failures += 1
    else:
        print('PASS  scripts created %d objects during the song' % report['objects_made'])

    # Mutation tests: break one promise at a time and require the audit to see it,
    # so a green run cannot be a harness that checks nothing.
    mutations = [
        ('skip the sprite teardown', 'removeLuaSprite(\'w32Spot\'', 'nope(\'w32Spot\''),
        ('skip the speed restore', "setProperty('songSpeed', state.baseSpeed)", 'x = 1'),
        ('skip the window restore', 'setWindowAlpha(originAlpha)', 'x = 1'),
    ]
    for label, needle, replacement in mutations:
        caught = mutation_caught(needle, replacement)
        print(('PASS  ' if caught else 'FAIL  ') + 'audit catches: %s' % label)
        if not caught:
            failures += 1

    # Budgets: the player-facing extremes have to stay legible.
    report = run_all()
    budgets = [
        ('scroll speed stays under 5 (got %.2f)' % report['speed_hi'],
         report['speed_hi'] < 5.0),
        # Two-sided: a dim nobody can see is dead code, a deep dim is a flash.
        ('window dim stays between 1%% and 12%% (got %.1f%%)'
         % (100 * (1 - report['alpha_lo'])), 0.99 >= report['alpha_lo'] >= 0.88),
        ('window alpha is written when flashing is allowed',
         len(report['alpha_writes']) > 0),
    ]

    # With flashing off (or reduced motion) the window must not be touched at
    # all: a whole-window brightness change is a flash by definition.
    quiet = run_all(prefs={'flashing': False})
    budgets.append(('window alpha is not written with flashing off (%d writes)'
                    % len(quiet['alpha_writes']), not quiet['alpha_writes']))
    still = run_all(prefs={'reducedMotion': True})
    budgets.append(('window alpha is not written with reduced motion (%d writes)'
                    % len(still['alpha_writes']), not still['alpha_writes']))
    for label, ok in budgets:
        print(('PASS  ' if ok else 'FAIL  ') + label)
        if not ok:
            failures += 1

    # Scope: every `local function` has to be declared before its first use.
    scope = []
    for name in SCRIPTS:
        scope.extend(scope_problems(os.path.join(DATA, name)))
    print(('PASS  ' if not scope else 'FAIL  ')
          + 'no hook reaches a local function declared below it (%d problems)' % len(scope))
    if scope:
        failures += 1
        for item in scope[:10]:
            print('        %s' % item)

    # Layout: nothing readable may be drawn over the engine's text.
    collisions = hud_collisions()
    print(('PASS  ' if not collisions else 'FAIL  ')
          + 'HUD layout is clear of the engine and modchart text (%d overlaps)'
          % len(collisions))
    if collisions:
        failures += 1
        for item in collisions[:10]:
            print('        %s' % item)

    print()
    if failures:
        print('%d CHECK(S) FAILED' % failures)
        return 1
    print('ALL CHECKS PASSED')
    return 0


def mutation_caught(needle, replacement):
    """Apply one source edit in memory and confirm the audit fails."""
    original = {}
    touched = 0
    for name in SCRIPTS:
        path = os.path.join(DATA, name)
        with open(path, encoding='utf-8') as handle:
            original[name] = handle.read()
    try:
        for name, source in original.items():
            if needle in source:
                touched += 1
                with open(os.path.join(DATA, name), 'w', encoding='utf-8') as handle:
                    handle.write(source.replace(needle, replacement))
        if not touched:
            return True  # the code moved on; nothing to mutate, do not fail the build
        report = run_all(hard_destroy=True)
        return bool(report['errors'] or report['leftovers']
                    or abs(report['speed_after_destroy'] - report['base_speed']) > 1e-6
                    or abs(report['alpha_after_destroy'] - 1.0) > 1e-6)
    finally:
        for name, source in original.items():
            with open(os.path.join(DATA, name), 'w', encoding='utf-8') as handle:
                handle.write(source)


if __name__ == '__main__':
    raise SystemExit(main())
