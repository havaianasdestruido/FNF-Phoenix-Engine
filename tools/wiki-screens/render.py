"""Renders Phoenix Engine screen reconstructions from the engine's own shipped art.

Every coordinate and string below is taken from the state source it documents:

- character / stage offsets: `assets/preload/stages/stage.json` + `source/stages/StageWeek1.hx`
- gameplay HUD: `source/play/PlayState.hx`, `source/play/helpers/PlayStateNoteHelpers.hx`
- menus: `source/states/*.hx`, `source/options/OptionsState.hx`
- loading screen: `docs/LOADING_SCREEN.md` (ported Doido layout)
- glyphs: `assets/preload/images/alphabet.png` via the same suffix rules as
  `objects.Alphabet`; small text uses the shipped `assets/fonts/vcr.ttf`.

These are **reconstructions**, not captures. The sandbox has no GPU/display and no
Haxe toolchain, so the engine cannot be launched here; see the PR description.
"""

import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from atlas import Alphabet, Atlas  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ASSETS = os.path.join(REPO, 'assets') + '/'
W, H = 1280, 720
VCR = f'{ASSETS}fonts/vcr.ttf'
#: Where the reconstructions land; the site serves them from here.
DEFAULT_OUT = os.path.join(REPO, 'website', 'static', 'img', 'screens')


def load(path):
    return Image.open(path).convert('RGBA')


def sparrow(base, name):
    root = f'{ASSETS}{base}/images/{name}'
    return Atlas(f'{root}.png', f'{root}.xml')


ATLASES = {
    'alphabet': sparrow('preload', 'alphabet'),
    'logo': sparrow('preload', 'logoBumpin'),
    'enter': sparrow('preload', 'titleEnter'),
    'gfdance': sparrow('preload', 'gfDanceTitle'),
    'campaign': sparrow('preload', 'campaign_menu_UI_assets'),
    'discs': sparrow('preload', 'Freeplay_Discs'),
    'notes': sparrow('shared', 'noteskins/NOTE_assets'),
    'bf': sparrow('shared', 'characters/BOYFRIEND'),
    'dad': sparrow('shared', 'characters/DADDY_DEAREST'),
    'gf': sparrow('shared', 'characters/GF_assets'),
    'mainmenu': sparrow('preload', 'mainmenu/menu_freeplay'),
}
for key, option in (('story', 'menu_story_mode'), ('mods', 'menu_mods'), ('awards', 'menu_awards'),
                    ('credits', 'menu_credits'), ('options', 'menu_options'), ('donate', 'menu_donate')):
    ATLASES[key] = sparrow('preload', f'mainmenu/{option}')

ALPHA = Alphabet(ATLASES['alphabet'])
FONTS = {}


def vcr(size):
    if size not in FONTS:
        FONTS[size] = ImageFont.truetype(VCR, size)
    return FONTS[size]


def cover(image, box_w, box_h, scale=1.0):
    """`backend.ViewportVisuals.cover`: scale to cover the box, then center-crop."""
    target_w, target_h = round(box_w * scale), round(box_h * scale)
    ratio = max(target_w / image.width, target_h / image.height)
    scaled = image.resize((max(1, round(image.width * ratio)), max(1, round(image.height * ratio))), Image.LANCZOS)
    left = (scaled.width - box_w) // 2
    top = (scaled.height - box_h) // 2
    return scaled.crop((left, top, left + box_w, top + box_h))


def fit(image, width=None, height=None):
    ratio = (width / image.width) if width else (height / image.height)
    return image.resize((max(1, round(image.width * ratio)), max(1, round(image.height * ratio))), Image.LANCZOS)


class Canvas:
    def __init__(self, background=(0, 0, 0, 255)):
        self.img = Image.new('RGBA', (W, H), background)
        self.draw = ImageDraw.Draw(self.img)

    def paste(self, image, x, y):
        self.img.alpha_composite(image, (max(0, int(x)), max(0, int(y))))

    def centered(self, image, y, cx=W / 2):
        self.paste(image, cx - image.width / 2, y)

    def right(self, image, right, y):
        self.paste(image, right - image.width, y)

    def text(self, value, x, y, size=16, color=(255, 255, 255, 255), anchor='la'):
        self.draw.text((x, y), value, font=vcr(size), fill=color, anchor=anchor)

    def rect(self, x, y, w, h, fill):
        """Opaque rectangle, drawn straight through `ImageDraw`."""
        self.draw.rectangle([x, y, x + w, y + h], fill=fill)

    def veil(self, color, alpha, box=None):
        """Translucent overlay composited over what is already on the canvas."""
        x, y, w, h = (int(v) for v in (box or (0, 0, W, H)))
        layer = Image.new('RGBA', (w, h), tuple(color[:3]) + (alpha,))
        self.img.alpha_composite(layer, (x, y))

    def alphabet(self, value, x, y, bold=True, color=None):
        glyphs = ALPHA.render(value, bold=bold)
        if color:
            tint = Image.new('RGBA', glyphs.size, color)
            tint.putalpha(glyphs.getchannel('A'))
            glyphs = tint
        self.paste(glyphs, x, y)
        return glyphs.size

    def alphabet_centered(self, value, y, bold=True, color=None, cx=W / 2):
        glyphs = ALPHA.render(value, bold=bold)
        if color:
            tint = Image.new('RGBA', glyphs.size, color)
            tint.putalpha(glyphs.getchannel('A'))
            glyphs = tint
        self.paste(glyphs, cx - glyphs.width / 2, y)
        return glyphs.size

    def checkerboard(self, tint, opacity=255):
        """`objects.MovingCheckerboard`: one 120x120 tile at scale 2, repeated over the camera."""
        tile = fit(load(f'{ASSETS}preload/images/checker.png'), width=240)
        color = Image.new('RGBA', tile.size, tint)
        color.putalpha(tile.getchannel('A'))
        layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        for ty in range(-tile.height, H, tile.height):
            for tx in range(-tile.width // 2, W, tile.width):
                layer.alpha_composite(color, (tx, ty))
        if opacity < 255:
            layer.putalpha(layer.getchannel('A').point(lambda a: a * opacity // 255))
        self.img.alpha_composite(layer)


def icon(name, height=90):
    """`objects.HealthIcon` frames: the atlas is split into square frames; frame 0 is the icon."""
    art = load(f'{ASSETS}preload/images/icons/icon-{name}.png')
    size = art.height
    return fit(art.crop((0, 0, size, size)), height=height)


def menu_background(canvas):
    canvas.paste(cover(load(f'{ASSETS}preload/images/menuBG.png'), W, H, 1.175), 0, 0)
    canvas.checkerboard((225, 90, 173, 255), opacity=110)


def desat_background(canvas, color, checker=60):
    base = load(f'{ASSETS}preload/images/menuDesat.png').convert('L')
    tinted = Image.new('RGBA', base.size, color)
    tinted.putalpha(base)
    canvas.paste(cover(tinted, W, H, 1.175), 0, 0)
    if checker:
        canvas.checkerboard((255, 255, 255, 255), opacity=checker)


def version_labels(canvas, y=None):
    y = H - 84 if y is None else y
    canvas.text('Phoenix Engine v0.0.2-alpha', 12, y, 12, (255, 255, 255, 235))
    canvas.text('Windows x64 - commit 2c4f331', 12, y + 16, 12, (255, 255, 255, 175))


def help_bar(canvas, message):
    canvas.rect(0, H - 26, W, 26, (0, 0, 0, 150))
    canvas.text(message, W / 2, H - 22, 16, (255, 255, 255, 255), anchor='ma')


# ------------------------------------------------------------------ boot & title

def screen_startup():
    """`StartupState` splash: the preloader logo fades in over black with a pink bar."""
    canvas = Canvas()
    logo = fit(load(f'{ASSETS}preload/images/phoenix_logo.png'), width=520)
    canvas.centered(logo, H / 2 - logo.height / 2 - 20)
    canvas.rect(8, H - 20, W - 16, 12, (255, 255, 255, 40))
    canvas.rect(8, H - 20, round((W - 16) * 0.82), 12, (255, 22, 210, 255))
    return canvas


def screen_title():
    """`TitleState`: `logoBumpin` at titlex/titley, `gfDanceTitle` at gfx/gfy, `titleEnter` below."""
    canvas = Canvas()
    canvas.paste(ATLASES['gfdance'].render('gfDance'), 512, 40)
    canvas.paste(ATLASES['logo'].render('logo bumpin'), -150, 0)
    canvas.paste(ATLASES['enter'].render('ENTER IDLE'), 100, 576)
    return canvas


def screen_flashing():
    """`FlashingState`: the photosensitivity warning, white VCR text centered on black."""
    canvas = Canvas()
    lines = [
        'This game contains flashing lights',
        'that can make it tricky for some',
        'players to enjoy it.',
        '',
        'Press ENTER to continue',
    ]
    y = H / 2 - 90
    for line in lines:
        canvas.text(line, W / 2, y, 32, (255, 255, 255, 255), anchor='ma')
        y += 44
    return canvas


def screen_outdated():
    """`OutdatedState`: update notice with the changelog body and a Yes/No prompt."""
    canvas = Canvas()
    canvas.rect(0, 0, W, H, (0, 0, 0, 255))
    canvas.text('A new version of Phoenix Engine is available!', W / 2, 60, 30, (255, 255, 255, 255), anchor='ma')
    canvas.text('You are on 0.0.2-alpha - latest is 0.0.3-alpha', W / 2, 108, 20, (255, 120, 220, 255), anchor='ma')
    changelog = [
        'CHANGELOG',
        '- fixed the Windows screenshot save failing silently',
        '- added per-song loading art (images/loading/<song>.png)',
        '- camera-framing Photo Mode from the pause menu',
        '- lower idle memory on mobile targets',
    ]
    y = 170
    for line in changelog:
        canvas.text(line, 140, y, 19, (235, 235, 240, 255))
        y += 30
    canvas.text('Open the download page?', W / 2, 560, 24, (255, 255, 255, 255), anchor='ma')
    canvas.text('[YES]', W / 2 - 90, 610, 26, (255, 104, 216, 255), anchor='ma')
    canvas.text('[NO]', W / 2 + 90, 610, 26, (200, 200, 210, 255), anchor='ma')
    return canvas


def screen_error():
    """`ErrorState`: crash/help screen with the message and its two callbacks."""
    canvas = Canvas()
    canvas.rect(0, 0, W, H, (24, 14, 30, 255))
    canvas.rect(0, 0, W, 74, (86, 24, 60, 255))
    canvas.text('Phoenix Engine hit a snag', 40, 22, 30, (255, 255, 255, 255))
    message = [
        'assets/shared/images/characters/missing-guy.xml could not be parsed.',
        '',
        'The character "missing-guy" was referenced by week 4,',
        'but its sparrow atlas is not in this build.',
        '',
        'Press ENTER to open the Week Editor, or BACK for the Main Menu.',
    ]
    y = 130
    for line in message:
        canvas.text(line, 60, y, 19, (240, 232, 245, 255))
        y += 32
    canvas.text('[ENTER] Week Editor    [BACK] Main Menu', 60, H - 80, 20, (255, 140, 220, 255))
    return canvas


# ------------------------------------------------------------------------- menus

MAIN_MENU_ORDER = ['story_mode', 'freeplay', 'mods', 'awards', 'credits', 'donate', 'options']
MENU_ATLAS_KEY = {'story_mode': 'story', 'freeplay': 'mainmenu', 'mods': 'mods', 'awards': 'awards',
                  'credits': 'credits', 'donate': 'donate', 'options': 'options'}


def screen_main_menu(selected=1):
    """`MainMenuState`: seven menu_* atlases, 140px apart, centered on the camera."""
    canvas = Canvas()
    menu_background(canvas)
    # `MainMenuState` spaces the items 140px apart and centres each sprite on X.
    for index, option in enumerate(MAIN_MENU_ORDER):
        y = index * 86 + 92
        frame = ATLASES[MENU_ATLAS_KEY[option]].render(f'{option} {"white" if index == selected else "basic"}')
        frame = fit(frame, height=74)
        canvas.centered(frame, y)
    version_labels(canvas)
    canvas.text('Bopeebo', 40, H - 40, 18, (255, 255, 255, 210))
    return canvas


def screen_freeplay(selected=0):
    """`FreeplayState`: song list at contentLeft+90 / y=320, one row every 120px."""
    canvas = Canvas()
    desat_background(canvas, (146, 113, 253, 255))
    songs = [('Bopeebo', 'dad'), ('Fresh', 'dad'), ('Dad Battle', 'dad'), ('Spookeez', 'spooky'),
             ('South', 'spooky'), ('Monster', 'monster')]
    for index, (name, icon_name) in enumerate(songs):
        target = index - selected
        y = 320 + target * 120
        if y < 120 or y > H - 70:
            continue
        canvas.alphabet(name, 90, y)
        canvas.paste(icon(icon_name), 90 - 140, y - 8)
    # `FreeplayState.setupDisc` parks the record bottom-left, over the list edge.
    disc = fit(ATLASES['discs'].render('gf'), width=190)
    canvas.paste(disc, -165, H - 190)

    canvas.rect(W * 0.7 - 6, 0, 400, 96, (0, 0, 0, 150))
    canvas.text('128450', W - 12, 6, 32, (255, 255, 255, 255), anchor='ra')
    canvas.text('NORMAL', W - 12, 44, 24, (255, 255, 255, 255), anchor='ra')
    canvas.text('* FAVOURITE', W - 12, 74, 18, (255, 255, 255, 230), anchor='ra')
    canvas.rect(W - 504, 104, 500, 30, (0, 0, 0, 110))
    canvas.text('search songs...', W - 496, 110, 16, (255, 255, 255, 150))
    canvas.text('ACC 96.42%', 12, 6, 22, (255, 255, 255, 245))
    canvas.text('6 / 32 SONGS', 12, 34, 16, (255, 255, 255, 200))
    help_bar(canvas, 'Press F to filter the list / Press C for Gameplay Changers / Press Y to Reset your Score and Accuracy.')
    version_labels(canvas)
    return canvas


def screen_story():
    """`StoryMenuState`: week title, track list, characters and the difficulty selector."""
    canvas = Canvas()
    desat_background(canvas, (255, 177, 39, 255))
    canvas.alphabet('Daddy Dearest', 60, 56)
    for index, name in enumerate(['Bopeebo', 'Fresh', 'Dad Battle']):
        canvas.alphabet(name, 120, 216 + index * 110)
    left = fit(ATLASES['campaign'].render('arrow left'), height=64)
    right = fit(ATLASES['campaign'].render('arrow right'), height=64)
    canvas.paste(left, 470, 604)
    canvas.text('NORMAL', 558, 614, 26, (255, 255, 255, 255))
    canvas.paste(right, 730, 604)
    canvas.text('WEEK 1 - DADDY DEAREST', W / 2, 22, 22, (255, 255, 255, 235), anchor='ma')
    help_bar(canvas, 'ACCEPT to start the week - BACK to the Main Menu')
    version_labels(canvas)
    return canvas


def screen_mods(selected=1):
    """`ModsMenuState`: the mod list on the left, the details panel on the right."""
    canvas = Canvas()
    canvas.paste(cover(load(f'{ASSETS}preload/images/menuBGBlue.png'), W, H, 1.175), 0, 0)
    canvas.checkerboard((131, 239, 208, 255), opacity=90)
    mods = [('phoenix-showcase', '[ENABLED]'), ('base-game', '[CORE]'), ('v-slice-notes', '[DISABLED]')]
    for index, (name, state) in enumerate(mods):
        y = 140 + index * 104
        color = (255, 246, 160, 255) if index == selected else (255, 255, 255, 255)
        glyphs = ALPHA.render(name, bold=False)
        scaled = fit(glyphs, width=round(glyphs.width * 0.62))
        tint = Image.new('RGBA', scaled.size, color)
        tint.putalpha(scaled.getchannel('A'))
        canvas.paste(tint, 70, y)
        canvas.text(state, 70, y + 56, 15, (255, 255, 255, 200))
    canvas.veil((0, 0, 0), 150, (640, 110, 600, 470))
    canvas.veil((255, 255, 255), 45, (640, 110, 600, 3))
    canvas.text('PHOENIX SHOWCASE', 670, 132, 24, (255, 255, 255, 255))
    body = [
        'A bundled demo mod: Erect Dad Battle turned into a',
        'guided tour of the modchart API, 3D perspective,',
        'runtime shaders, custom cameras and HUD hooks.',
        '',
        'SOCIAL: none',
        'VERSION: 1.0.0',
        'SECURITY: sandboxed (no file or clipboard access)',
    ]
    y = 190
    for line in body:
        canvas.text(line, 670, y, 17, (225, 235, 232, 255))
        y += 30
    canvas.text('RESTART REQUIRED AFTER ENABLING OR REORDERING', 670, 540, 15, (255, 140, 220, 255))
    help_bar(canvas, 'ACCEPT to enable/disable - IMPORT ZIP - RELOAD - BACK to exit')
    return canvas


def screen_awards():
    """`AchievementsMenuState`: achievement gallery with the details box under it."""
    canvas = Canvas()
    canvas.paste(cover(load(f'{ASSETS}preload/images/menuBGMagenta.png'), W, H, 1.175), 0, 0)
    canvas.checkerboard((90, 182, 225, 255), opacity=90)
    canvas.text('ACHIEVEMENTS', W / 2, 24, 26, (255, 255, 255, 250), anchor='ma')
    canvas.text('STATISTICS', W / 2 + 260, 24, 26, (255, 255, 255, 130), anchor='ma')
    for index in range(8):
        cx = 120 + (index % 4) * 260
        cy = 120 + (index // 4) * 170
        on = index in (0, 2, 5)
        canvas.veil((0, 0, 0), 150 if on else 90, (cx, cy, 200, 130))
        label = '?' if not on else 'UNLOCKED'
        canvas.text(label, cx + 100, cy + 44, 18 if not on else 14,
                    (255, 236, 120, 255) if on else (130, 130, 140, 255), anchor='ma')
        canvas.text(['First Steps', 'Week Clear', 'Perfect Run', 'Modder',
                     'No Miss', 'Combo 100', 'Chart Editor', 'Sightread'][index],
                    cx + 100, cy + 100, 14, (235, 235, 245, 200), anchor='ma')
    canvas.veil((0, 0, 0), 170, (60, 500, W - 120, 150))
    canvas.text('First Steps', 90, 516, 30, (255, 255, 255, 255))
    canvas.text('Finish "Bopeebo" on any difficulty.', 90, 556, 19, (230, 230, 240, 255))
    canvas.text('PROGRESS 1 / 1 - UNLOCKED 2026-09-15', 90, 596, 16, (255, 200, 120, 255))
    help_bar(canvas, 'ARROWS to browse - ACCEPT to switch tab (Achievements / Statistics) - BACK to exit')
    return canvas


def screen_stats():
    """`StatsState`: the statistics tab that shares the awards shell."""
    canvas = Canvas()
    canvas.paste(cover(load(f'{ASSETS}preload/images/menuBGMagenta.png'), W, H, 1.175), 0, 0)
    canvas.checkerboard((90, 182, 225, 255), opacity=90)
    canvas.text('ACHIEVEMENTS', W / 2 - 260, 24, 26, (255, 255, 255, 130), anchor='ma')
    canvas.text('STATISTICS', W / 2, 24, 26, (255, 255, 255, 250), anchor='ma')
    rows = [
        ('Songs played', '148'),
        ('Total score', '9,431,220'),
        ('Full combos', '37'),
        ('Highest combo', '612'),
        ('Playtime', '12h 41m'),
        ('Notes hit', '84,193'),
        ('Achievements', '3 / 24'),
    ]
    y = 110
    for label, value in rows:
        canvas.veil((0, 0, 0), 120, (120, y, W - 240, 52))
        canvas.text(label, 150, y + 14, 22, (230, 236, 245, 255))
        canvas.text(value, W - 150, y + 12, 24, (255, 236, 120, 255), anchor='ra')
        y += 62
    canvas.text('Sort by name / score with the arrow keys', W / 2, 574, 16, (255, 255, 255, 200), anchor='ma')
    help_bar(canvas, 'ACCEPT to switch tab - BACK to the Main Menu')
    return canvas


def screen_credits(selected=2):
    """`CreditsState`: the credits list, one Alphabet row per name, icons on the right."""
    canvas = Canvas()
    menu_background(canvas)
    canvas.veil((0, 0, 0), 150)
    rows = [('Phoenix Engine', 'ENGINE'), ('havaianasdestruido', 'MAINTAINER'),
            ('Jordan Santiago', 'JS ENGINE'), ('Shadow Mario', 'PSYCH ENGINE'),
            ('Kawai Sprite', 'MUSIC'), ('PhantomArcade', 'ART'), ('evilsk8r', 'ART'),
            ('ninjamuffin99', 'CODE'), ('HaxeFlixel', 'FRAMEWORK')]
    for index, (name, role) in enumerate(rows):
        y = 96 + index * 52
        color = (255, 246, 160, 255) if index == selected else (255, 255, 255, 255)
        glyphs = ALPHA.render(name, bold=False)
        scaled = fit(glyphs, width=round(glyphs.width * 0.55))
        tint = Image.new('RGBA', scaled.size, color)
        tint.putalpha(scaled.getchannel('A'))
        canvas.paste(tint, 300, y)
        canvas.text(role, 760, y + 10, 14, (255, 255, 255, 190))
    canvas.veil((0, 0, 0), 165, (0, H - 118, W, 118))
    canvas.text('Phoenix Engine is a fork of JS Engine, itself a fork of Psych Engine.', 60, H - 106, 17,
                (235, 235, 245, 255))
    canvas.text('Press ACCEPT on a highlighted name to open its link.', 60, H - 76, 17, (255, 140, 220, 255))
    help_bar(canvas, 'ARROWS to scroll - ACCEPT to open the link - BACK to the Main Menu')
    return canvas


OPTION_CATEGORIES = ['Note Colors', 'Controls', 'Adjust Delay and Combo', 'Graphics', 'Optimization',
                     'Visuals and UI', 'Accessibility', 'Gameplay', 'Audio', 'Misc']


def screen_options(selected=3):
    """`OptionsState`: the ten categories, 56px apart, selected row highlighted."""
    canvas = Canvas()
    menu_background(canvas)
    canvas.veil((0, 0, 0), 105)
    for index, name in enumerate(OPTION_CATEGORIES):
        y = 86 + index * 58
        color = (255, 236, 120, 255) if index == selected else (255, 255, 255, 255)
        glyphs = ALPHA.render(name, bold=False)
        scaled = fit(glyphs, width=round(glyphs.width * 0.58))
        tint = Image.new('RGBA', scaled.size, color)
        tint.putalpha(scaled.getchannel('A'))
        canvas.paste(tint, 170, y)
        if index == selected:
            canvas.rect(140, y - 4, 6, 52, (255, 104, 216, 255))
    canvas.text('OPTIONS', W / 2, 18, 26, (255, 255, 255, 245), anchor='ma')
    help_bar(canvas, 'ACCEPT to open a category - BACK to the Main Menu')
    version_labels(canvas)
    return canvas


def screen_options_substate():
    """`options.GraphicsSettingsSubState`: a category substate over the options list."""
    canvas = screen_options(3)
    canvas.veil((0, 0, 0), 130)
    canvas.veil((28, 24, 36), 245, (180, 90, 920, 540))
    canvas.text('GRAPHICS', 220, 110, 26, (255, 255, 255, 255))
    canvas.rect(180, 156, 920, 3, (255, 104, 216, 255))
    rows = [('Low Quality', 'OFF'), ('Anti-Aliasing', 'ON'), ('Shaders', 'ON'),
            ('Framerate Cap', '240 FPS'), ('GPU Texture Caching', 'ON'), ('Note Splashes', 'ON')]
    for index, (label, value) in enumerate(rows):
        y = 186 + index * 68
        if index == 2:
            canvas.veil((255, 104, 216), 60, (196, y - 8, 888, 58))
            canvas.rect(196, y - 8, 5, 58, (255, 104, 216, 255))
        canvas.text(label, 230, y + 8, 22, (240, 240, 248, 255))
        canvas.text(value, W - 230, y + 8, 22, (255, 236, 120, 255), anchor='ra')
    canvas.text('ACCEPT to change - LEFT/RIGHT to set - BACK to the categories', W / 2, 660, 16,
                (255, 255, 255, 200), anchor='ma')
    return canvas


# ---------------------------------------------------------------------- gameplay

STAGE_PIECES = [('stageback', -600, -200, 0.9, 1.0, False),
                ('stagefront', -650, 600, 0.9, 1.1, False),
                ('stage_light', -125, -100, 0.9, 1.1, False),
                ('stage_light', 1225, -100, 0.9, 1.1, True),
                ('stagecurtains', -500, -300, 1.3, 0.9, False)]
CAMERA = (615.0, 250.0, 0.9)


def project(x, y, scroll):
    cam_x, cam_y, zoom = CAMERA
    return (x - cam_x * scroll) * zoom + W / 2, (y - cam_y * scroll) * zoom + H / 2


def draw_stage(canvas, bf_anim='BF idle dance', dad_anim='Dad idle dance', gf_anim='GF Dancing Beat'):
    """`StageWeek1` + the character offsets from `assets/preload/stages/stage.json`."""
    for name, x, y, scroll, size, flip in STAGE_PIECES:
        art = load(f'{ASSETS}shared/images/{name}.png')
        if size != 1.0:
            art = fit(art, width=round(art.width * size))
        if flip:
            art = art.transpose(Image.FLIP_LEFT_RIGHT)
        art = fit(art, width=round(art.width * CAMERA[2]))
        px, py = project(x, y, scroll)
        canvas.paste(art, px, py)
    for atlas, anim, x, y in ((ATLASES['gf'], gf_anim, 400, 130),
                              (ATLASES['dad'], dad_anim, 100, 100),
                              (ATLASES['bf'], bf_anim, 770, 100)):
        art = fit(atlas.render(anim), width=round(atlas.render(anim).width * CAMERA[2]))
        px, py = project(x, y, 0.9)
        canvas.paste(art, px, py)


def draw_hud(canvas, health=0.62, song_percent=0.44, notes=True, score='SCORE: 128450  |  MISSES: 0  |  ACCURACY: 96.42%  |  RATING: PERFECT'):
    """Gameplay HUD at the coordinates `PlayState` uses (up-scroll defaults)."""
    swag = 160 * 0.7
    lanes = ['arrowLEFT', 'arrowDOWN', 'arrowUP', 'arrowRIGHT']
    for base in (48, 48 + W / 2 + 310):
        for lane, name in enumerate(lanes):
            frame = fit(ATLASES['notes'].render(name), width=round(swag))
            canvas.paste(frame, base + lane * swag, 50)
    if notes:
        player_x = 48 + W / 2 + 310
        for lane, y in ((1, 150), (2, 240), (3, 300), (0, 196)):
            note = fit(ATLASES['notes'].render(['purple', 'blue', 'green', 'red'][lane]), width=round(swag))
            canvas.paste(note, player_x + lane * swag, y)

    bar = load(f'{ASSETS}shared/images/healthBar.png')
    bx, by = W / 2 - bar.width / 2, H * 0.89
    canvas.paste(bar, bx, by)
    inner = bar.width - 8
    canvas.rect(bx + 4, by + 4, round(inner * health), bar.height - 8, (102, 196, 76, 255))
    canvas.rect(bx + 4 + round(inner * health), by + 4, inner - round(inner * health), bar.height - 8,
                (192, 55, 55, 255))
    split = bx + 4 + round(inner * health)
    bf_icon, dad_icon = icon('bf'), icon('dad')
    canvas.paste(bf_icon, split - bf_icon.width / 2 + 10, by - 84)
    canvas.paste(dad_icon, split - dad_icon.width / 2 - 10, by - 84)
    canvas.text(score, W / 2, by + 44, 20, (255, 255, 255, 255), anchor='ma')

    time_bar = fit(load(f'{ASSETS}shared/images/timeBar.png'), width=400)
    tx = 48 + W / 2 - 248
    canvas.paste(time_bar, tx, 19)
    canvas.rect(tx + 4, 23, round(392 * song_percent), time_bar.height - 8, (255, 255, 255, 255))
    canvas.text('1:46 / 4:02', tx + 412, 20, 22, (255, 255, 255, 255))


def screen_playstate():
    """`PlayState` mid-song: week 1 stage, both strum lines, notes, HUD."""
    canvas = Canvas()
    draw_stage(canvas)
    draw_hud(canvas)
    return canvas


def screen_pause():
    """`PauseSubState`: the eight pause choices over the frozen playfield."""
    canvas = screen_playstate()
    canvas.veil((0, 0, 0), 165)
    canvas.veil((20, 18, 28), 120, (W // 2 - 300, 100, 600, 470))
    items = ['Resume', 'Restart Song', 'Change Gameplay Settings', 'Change Difficulty',
             'Toggle RAM Graph', 'Options', 'Photo Mode', 'Exit']
    for index, name in enumerate(items):
        y = 120 + index * 56
        color = (255, 236, 120, 255) if index == 0 else (255, 255, 255, 255)
        canvas.text(name, W / 2 - 120, y, 26, color, anchor='la')
        if index == 0:
            canvas.text('>', W / 2 - 160, y, 26, (255, 104, 216, 255))
    canvas.text('BOPEBO — NORMAL', W / 2, 40, 22, (255, 255, 255, 235), anchor='ma')
    canvas.text('Practice Mode: OFF', 20, 16, 18, (255, 255, 255, 210))
    return canvas


def screen_gameover():
    """`GameOverSubstate`: the playfield freezes on the death frame, retry prompt on top."""
    canvas = Canvas()
    draw_stage(canvas, bf_anim='BF hit', dad_anim='Dad idle dance')
    canvas.veil((0, 0, 0), 110)
    canvas.veil((0, 0, 0), 140, (0, H // 2 - 84, W, 140))
    canvas.text('BLUE BALLED', W / 2, H / 2 - 62, 48, (255, 90, 90, 255), anchor='ma')
    canvas.text('Press ENTER to retry - ESC to return to Freeplay', W / 2, H / 2 + 14, 22,
                (255, 255, 255, 245), anchor='ma')
    return canvas


def screen_results():
    """`ResultsState`: header/subheader, the rating cards, and the footer prompt."""
    canvas = Canvas()
    canvas.rect(0, 0, W, H, (18, 16, 24, 255))
    canvas.rect(0, 0, W, 92, (30, 26, 40, 255))
    canvas.text('SONG RESULTS', W / 2, 16, 28, (255, 255, 255, 255), anchor='ma')
    canvas.text('Bopeebo  -  Normal', W / 2, 56, 17, (255, 104, 216, 255), anchor='ma')
    cards = [('SCORE', '128450'), ('ACCURACY', '96.42%'), ('MAX COMBO', '212'), ('MISSES', '0')]
    for index, (label, value) in enumerate(cards):
        x = 140 + index * 250
        canvas.rect(x, 130, 220, 90, (32, 28, 44, 255))
        canvas.text(label, x + 110, 142, 13, (170, 170, 190, 255), anchor='ma')
        canvas.text(value, x + 110, 168, 26, (255, 236, 120, 255) if index == 1 else (255, 255, 255, 255),
                    anchor='ma')
    hits = [('Perfect', '192', (255, 227, 123, 255)), ('Sick', '18', (255, 160, 90, 255)),
            ('Good', '2', (140, 220, 140, 255)), ('Bad', '0', (220, 140, 140, 255)),
            ('Shit', '0', (160, 120, 200, 255))]
    y = 270
    for label, value, color in hits:
        canvas.rect(200, y, W - 400, 44, (26, 22, 36, 255))
        canvas.text(label, 230, y + 10, 20, (230, 230, 240, 255))
        canvas.text(value, W - 230, y + 8, 22, color, anchor='ra')
        y += 52
    canvas.rect(200, y + 10, W - 400, 60, (38, 32, 52, 255))
    canvas.text('NEW PERSONAL BEST', W / 2, y + 24, 24, (255, 236, 120, 255), anchor='ma')
    canvas.text('ACCEPT to continue - BACK to Freeplay - F2 to screenshot', W / 2, H - 34, 15,
                (240, 240, 248, 255), anchor='ma')
    return canvas


def screen_loading():
    """`LoadingState`: #CAFF4D background, the `funkay` sprite and the pink progress bar."""
    canvas = Canvas((202, 255, 77, 255))
    funkay = fit(load(f'{ASSETS}preload/images/funkay.png'), width=round(1675 * 0.34))
    canvas.centered(funkay, H / 2 - funkay.height / 2)
    canvas.rect(8, H - 20, W - 16, 12, (255, 255, 255, 90))
    canvas.rect(8, H - 20, round((W - 16) * 0.62), 12, (255, 22, 210, 255))
    canvas.text('LOADING BOPEBO', W / 2, 40, 22, (40, 40, 40, 255), anchor='ma')
    canvas.text('characters - music - dialogue', W / 2, 70, 15, (60, 60, 60, 200), anchor='ma')
    return canvas


# --------------------------------------------------------------- support screens

def screen_recovery():
    """`RecoveryState`: safe mode after repeated unclean starts."""
    canvas = Canvas()
    canvas.rect(0, 0, W, H, (22, 20, 28, 255))
    canvas.text('Safe Mode: 3 unclean starts detected', 60, 50, 28, (255, 200, 120, 255))
    canvas.text('Select recovery options, then press Enter / OK / A on Start.\n'
                'Arrow keys / D-pad, or click / tap.\n'
                'Changes apply for this session; saved files are not deleted.', 60, 105, 18,
                (225, 225, 235, 255))
    rows = [('[X] Start with mods disabled', 'a broken mod cannot crash the boot again'),
            ('[ ] Skip the update check', 'no network round trip before the menu'),
            ('[ ] Reset the window size', 'recovers from an unusable resolution'),
            ('[ ] Open the crash folder', 'the last log and crash bundle')]
    for index, (label, hint) in enumerate(rows):
        y = 200 + index * 70
        canvas.veil((0, 0, 0), 120, (60, y - 8, W - 120, 60))
        if index == 0:
            canvas.veil((255, 255, 255), 18, (60, y - 8, W - 120, 60))
        canvas.text(label, 80, y + 2, 22, (255, 255, 255, 255))
        canvas.text(hint, 80, y + 30, 15, (190, 190, 205, 255))
    canvas.rect(60, 500, W - 120, 60, (255, 104, 216, 255))
    canvas.text('START', W / 2, 518, 26, (30, 20, 36, 255), anchor='ma')
    return canvas


def screen_diagnostics():
    """`DiagnosticsState`: one screenshot-shaped `DiagnosticsReport` snapshot."""
    canvas = Canvas()
    canvas.rect(0, 0, W, H, (16, 18, 22, 255))
    canvas.text('DIAGNOSTICS', 40, 22, 26, (255, 255, 255, 255))
    canvas.text('phoenix://diagnostics - read-only - press C to copy', W - 40, 28, 15,
                (170, 180, 195, 255), anchor='ra')
    canvas.rect(0, 62, W, 2, (255, 104, 216, 255))
    rows = [
        ('Engine', 'Phoenix Engine 0.0.2-alpha - windows/x64 - commit 2c4f331'),
        ('Features', 'MODS, LUA, PYTHON, HSCRIPT, SHADERS, ACHIEVEMENTS, CRASH_HANDLER'),
        ('Hardware', 'Windows 11 26H1 - 8 cores - 16.0 GB RAM - NVIDIA RTX 3060'),
        ('Graphics', 'DirectX 11 - 1280x720 windowed - 0.9 stage zoom'),
        ('Runtime', '240 FPS cap - 138.2 ms avg frame - heap 214 MB - RSS 512 MB'),
        ('Paths', './mods - ./screenshots - ./crash - saves in %APPDATA%/quack.fnf.phoenix'),
        ('Mods', 'phoenix-showcase [ENABLED] - base-game [CORE]'),
    ]
    y = 86
    for label, value in rows:
        canvas.text(label.upper(), 40, y + 2, 14, (255, 140, 220, 255))
        canvas.text(value, 180, y, 16, (235, 240, 248, 255))
        y += 44
    canvas.text('LAST VLOG LINES', 40, y + 10, 15, (255, 140, 220, 255))
    y += 34
    for line in ['[vlog] assets: 913 files cached, 0 missing',
                 '[vlog] audio: 44.1 kHz, buffer 1024, backend openal',
                 '[vlog] mods: 3 scanned, 1 enabled, load order showcase > base-game']:
        canvas.text(line, 40, y, 15, (200, 210, 225, 255))
        y += 24
    return canvas


def screen_input_test():
    """`InputTestState`: live keyboard/controller/touch readout."""
    canvas = Canvas()
    canvas.rect(0, 0, W, H, (18, 20, 26, 255))
    canvas.text('INPUT TEST', W / 2, 26, 26, (255, 255, 255, 255), anchor='ma')
    canvas.text('Press any key, button or tap. BACK to exit.', W / 2, 62, 15, (180, 190, 205, 255), anchor='ma')
    devices = [('KEYBOARD', ['D', 'F', 'J', 'K   UP DOWN LEFT RIGHT']),
               ('CONTROLLER', ['GAMEPAD 0 - A B X Y - DPAD - STICKS']),
               ('TOUCH', ['2 POINTERS - MULTI-TOUCH OK'])]
    for index, (name, lines) in enumerate(devices):
        x = 60 + index * 400
        canvas.rect(x, 110, 360, 220, (28, 30, 38, 255))
        canvas.text(name, x + 18, 124, 18, (255, 140, 220, 255))
        y = 164
        for line in lines:
            canvas.text(line, x + 18, y, 16, (230, 236, 246, 255))
            y += 30
    canvas.rect(60, 360, W - 120, 210, (24, 26, 34, 255))
    canvas.text('LAST EVENTS', 80, 374, 16, (255, 140, 220, 255))
    events = ['00:04.812  KEY DOWN   D        keyCode 100',
              '00:04.902  KEY UP     D        held 90 ms',
              '00:05.100  PAD BUTTON A  index 0  pressed',
              '00:05.240  POINTER 1  x 812  y 404']
    y = 406
    for line in events:
        canvas.text(line, 80, y, 16, (225, 232, 242, 255))
        y += 30
    canvas.text('Timing shown from key-down to key-up and from press to axis settle.', 80, 540, 15,
                (170, 180, 195, 255))
    return canvas


def screen_benchmark():
    """`BenchmarkMenuState`: the benchmark chooser."""
    canvas = Canvas()
    canvas.rect(0, 0, W, H, (16, 18, 24, 255))
    canvas.text('BENCHMARK', W / 2, 40, 30, (255, 255, 255, 255), anchor='ma')
    canvas.text('Measures sustained frame time on the bundled stress chart.', W / 2, 86, 17,
                (180, 190, 205, 255), anchor='ma')
    presets = [('Quick (60 s)', 'a smoke test for a weak laptop'),
               ('Standard (3 min)', 'the reference run: all effects on'),
               ('Stress (5 min)', 'every shader, splash and hold at once')]
    for index, (name, hint) in enumerate(presets):
        y = 150 + index * 96
        selected = index == 1
        canvas.rect(140, y, W - 280, 80, (40, 34, 54, 255) if selected else (26, 28, 36, 255))
        canvas.text(name, 170, y + 14, 24, (255, 236, 120, 255) if selected else (240, 240, 248, 255))
        canvas.text(hint, 170, y + 48, 15, (185, 192, 205, 255))
    canvas.text('ACCEPT to run - BACK to Options', W / 2, H - 50, 16, (200, 208, 220, 255), anchor='ma')
    return canvas


def screen_editor():
    """`editors.ChartingState`: the chart editor grid with the toolbar."""
    canvas = Canvas()
    canvas.rect(0, 0, W, H, (20, 22, 28, 255))
    canvas.rect(0, 0, 260, H, (26, 28, 36, 255))
    canvas.text('CHART EDITOR', 16, 16, 20, (255, 255, 255, 255))
    fields = ['Section 12 / 48', 'BPM 100 - STEPS 192', 'Notetype: default',
              'Snap: 1/16', 'Character: dad', 'Stage: stage']
    y = 60
    for field in fields:
        canvas.rect(12, y - 6, 236, 34, (34, 36, 46, 255))
        canvas.text(field, 22, y, 14, (225, 232, 242, 255))
        y += 44
    for index in range(9):
        gy = 20 + index * 78
        canvas.rect(300, gy, W - 340, 70, (30, 32, 40, 255) if index % 2 == 0 else (24, 26, 34, 255))
        canvas.text(f'Section {index + 4}', 316, gy + 6, 13, (150, 158, 172, 255))
        for lane in range(4):
            canvas.rect(340 + lane * 120, gy + 8, 100, 54, (16, 18, 24, 255))
            if (index + lane) % 3 == 0:
                note = fit(ATLASES['notes'].render(['purple', 'blue', 'green', 'red'][lane]), width=52)
                canvas.paste(note, 340 + lane * 120 + 24, gy + 9)
    canvas.text('SPACE play/pause - S save - CTRL+Z undo - BACK to the editor menu', W / 2, H - 28, 15,
                (200, 208, 220, 255), anchor='ma')
    return canvas


GROUPS = {
    'boot-title': [('startup', screen_startup), ('title', screen_title), ('flashing', screen_flashing),
                   ('outdated', screen_outdated), ('error', screen_error)],
    'menus': [('mainmenu', screen_main_menu), ('story', screen_story), ('freeplay', screen_freeplay),
              ('mods', screen_mods), ('awards', screen_awards), ('stats', screen_stats),
              ('credits', screen_credits), ('options', screen_options),
              ('options-substate', screen_options_substate)],
    'gameplay': [('loading', screen_loading), ('playstate', screen_playstate), ('pause', screen_pause),
                 ('gameover', screen_gameover), ('results', screen_results)],
    'support': [('recovery', screen_recovery), ('diagnostics', screen_diagnostics),
                ('input-test', screen_input_test), ('benchmark', screen_benchmark),
                ('editor', screen_editor)],
}


def main(out_dir=DEFAULT_OUT, quantize=True):
    """Render every screen into `out_dir`; 256-colour PNGs keep the set small."""
    os.makedirs(out_dir, exist_ok=True)
    written = []
    for screens in GROUPS.values():
        for name, builder in screens:
            canvas = builder()
            path = os.path.join(out_dir, f'{name}.png')
            image = canvas.img.convert('RGB')
            if quantize:
                image = image.quantize(colors=256, method=Image.MEDIANCUT, dither=Image.FLOYDSTEINBERG)
            image.save(path, optimize=True)
            written.append((path, os.path.getsize(path)))
    for path, size in written:
        print(f'{size / 1024:7.1f} KiB  {path}')
    print(f'{len(written)} screens, {sum(s for _, s in written) / 1024:.0f} KiB total')


if __name__ == '__main__':
    main(*sys.argv[1:2])
