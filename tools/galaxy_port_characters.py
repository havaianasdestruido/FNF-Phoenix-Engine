#!/usr/bin/env python3
"""Galaxy -> Phoenix character port.

Copies the five GalaxyMod character atlases into assets/preload/images/characters/,
writes matching character JSONs (assets/preload/characters/), crops the four
Galaxy health icons out of iconGrid.png, and appends the character names to
assets/preload/data/characterList.txt.

Animation maps (anim name, atlas prefix, loop, offsets) are transcribed
verbatim from GalaxyMod's own source/Character.hx so the engine plays exactly
what the mod plays.
"""
import json
import os
import shutil
import sys
import xml.etree.ElementTree as ET

GALAXY = '/tmp/galaxy'
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image  # noqa: E402

# (anim, prefix, loop, [ox, oy]) — from /tmp/galaxy/source/Character.hx
CHARACTERS = [
    {
        'json': 'bf-space',
        'image': 'Galaxy-BF',
        'atlas': 'somewhere/Galaxy-BF',
        'position': [0, 350],
        'isPlayer': True,
        'flip_x': True,
        'healthicon': 'bf',
        'icon': None,
        'colors': [49, 176, 209],
        'anims': [
            ('idle', 'idle', False, [-5, 0]),
            ('singUP', 'up0', False, [-29, 27]),
            ('singLEFT', 'left0', False, [12, -6]),
            ('singRIGHT', 'right0', False, [-38, -7]),
            ('singDOWN', 'down0', False, [-10, -50]),
            ('singUPmiss', 'up MISS', False, [-29, 27]),
            ('singLEFTmiss', 'left MISS', False, [12, 24]),
            ('singRIGHTmiss', 'right MISS', False, [-30, 21]),
            ('singDOWNmiss', 'down miss', False, [-11, -19]),
            ('firstDeath', 'die0', False, [154, 274]),
            ('deathLoop', 'die animation', True, [41, 61]),
            ('deathConfirm', 'die confirm', False, [34, 94]),
        ],
    },
    {
        'json': 'kastimagina',
        'image': 'Kastimagina',
        'atlas': 'ship/Kastimagina',
        'position': [0, 0],
        'isPlayer': False,
        'flip_x': False,
        'healthicon': 'kastimagina',
        'icon': [24, 25],
        'colors': [146, 113, 253],
        'anims': [
            ('idle', 'Kastimagina Idle', False, [0, 0]),
            ('singUP', 'Kastimagina Up', False, [41, 9]),
            ('singRIGHT', 'Kastimagina Right', False, [-53, 6]),
            ('singDOWN', 'Kastimagina Down', False, [-9, -9]),
            ('singLEFT', 'Kastimagina Left', False, [75, 14]),
            ('singUP-alt', 'jumpup', False, [57, 265]),
            ('singDOWN-alt', 'jumpdown', False, [74, 155]),
            ('singLEFT-alt', 'jumpleft', False, [36, 195]),
            ('singRIGHT-alt', 'jumpright', False, [1, 211]),
        ],
    },
    {
        'json': 'kalisa',
        'image': 'Kalisa',
        'atlas': 'cor/Kalisa',
        'position': [0, 0],
        'isPlayer': False,
        'flip_x': False,
        'healthicon': 'kalisa',
        'icon': [26, 27],
        'colors': [146, 113, 253],
        'anims': [
            ('idle', 'Kalifa idle', False, [0, 0]),
            ('singUP', 'Kalifa up', False, [-170, 37]),
            ('singDOWN', 'Kalifa down', False, [-26, 48]),
            ('singLEFT', 'Kalifa left', False, [-78, -36]),
            ('singRIGHT', 'Kalifa right', False, [9, -7]),
        ],
    },
    {
        'json': 'mathena',
        'image': 'mathena',
        'atlas': 'ship/mathena',
        'position': [0, 0],
        'isPlayer': False,
        'flip_x': False,
        'healthicon': 'mathena',
        'icon': [28, 29],
        'colors': [146, 113, 253],
        'anims': [
            ('idle', 'mathena_Idle.swf', False, [0, 0]),
            ('singUP', 'mathena_up.swf', False, [-99, 103]),
            ('singDOWN', 'mathena_Down.swf', False, [24, 2]),
            ('singLEFT', 'mathena_Left.swf', False, [86, 18]),
            ('singRIGHT', 'mathena_Right.swf', False, [-26, 16]),
        ],
    },
    {
        'json': 'unknown',
        'image': 'unknown',
        'atlas': 'somewhere/unknown',
        'position': [0, 0],
        'isPlayer': False,
        'flip_x': False,
        'healthicon': 'unknown',
        'icon': [30, 30],
        'colors': [146, 113, 253],
        'anims': [
            ('idle', 'unknown Idle0', False, [0, 0]),
            ('singUP', 'unknown Up', False, [-270, 228]),
            ('singRIGHT', 'unknown Right', False, [-223, -34]),
            ('singDOWN', 'unknown Down', False, [-173, -121]),
            ('singLEFT', 'unknown Left', False, [181, -134]),
            ('singPOSE1', 'unknown IdleA', False, [0, 0]),
            ('singPOSE2', 'unknown IdleB', False, [0, 0]),
        ],
    },
]

ICON_GRID = os.path.join(GALAXY, 'assets', 'preload', 'images', 'iconGrid.png')
CELL = 150


def atlas_frame_bases(xml_path):
    root = ET.parse(xml_path).getroot()
    import re
    bases = set()
    for s in root:
        name = s.attrib.get('name', '')
        bases.add(re.sub(r'\d+$', '', name))
    return bases


def check_prefix(frames, prefix):
    """prefix matches at least one frame name (prefix + digits) in the atlas."""
    import re
    pat = re.compile(re.escape(prefix) + r'\d+$')
    return any(pat.match(f) for f in frames)


def char_json(c):
    return {
        'animations': [
            {'offsets': list(offs), 'loop': loop, 'fps': 24, 'anim': anim, 'indices': [], 'name': prefix}
            for (anim, prefix, loop, offs) in c['anims']
        ],
        'vocals_file': '',
        'losing_colors': c['colors'],
        'isPlayer': c['isPlayer'],
        'no_antialiasing': False,
        'image': 'characters/' + c['image'],
        'shake_duration': 0,
        'trail_length': 4,
        'trail_delay': 24,
        'position': c['position'],
        'trail_diff': 0,
        'trail_alpha': 1,
        'health_drain': False,
        'shake_intensity': 0,
        'healthicon': c['healthicon'],
        'shake_screen': False,
        'drain_floor': 0,
        'flip_x': c['flip_x'],
        'healthbar_colors': c['colors'],
        'drain_amount': 0,
        'camera_position': [0, 0],
        'sing_duration': 4,
        'noteskin': None,
        'winning_colors': c['colors'],
        'scale': 1,
    }


def crop_icon(grid, cells, out_path):
    first, last = cells
    x0 = (min(first, last) % 10) * CELL
    y0 = (min(first, last) // 10) * CELL
    x1 = (max(first, last) % 10 + 1) * CELL
    y1 = (max(first, last) // 10 + 1) * CELL
    # keep the exact cell box: HealthIcon normalizes by aspect ratio
    # (2-cell -> 300x150 -> 150x150, 1-cell -> 150x150). Trimming would
    # change the aspect and shrink the icon.
    box = grid.crop((x0, y0, x1, y1))
    if box.getbbox() is None:
        raise SystemExit(f'empty icon crop {cells}')
    box.save(out_path)
    return box.size


def main():
    char_dir = os.path.join(REPO, 'assets', 'preload', 'images', 'characters')
    json_dir = os.path.join(REPO, 'assets', 'preload', 'characters')
    icon_dir = os.path.join(REPO, 'assets', 'preload', 'images', 'icons')
    os.makedirs(char_dir, exist_ok=True)
    os.makedirs(json_dir, exist_ok=True)
    os.makedirs(icon_dir, exist_ok=True)

    grid = Image.open(ICON_GRID)
    icon_size = CELL
    added = []
    for c in CHARACTERS:
        atlas_src = os.path.join(GALAXY, 'assets', 'weeks', 'images', c['atlas'])
        png, xml = atlas_src + '.png', atlas_src + '.xml'
        if not (os.path.exists(png) and os.path.exists(xml)):
            raise SystemExit(f'missing atlas: {png}')
        shutil.copy2(png, os.path.join(char_dir, c['image'] + '.png'))
        shutil.copy2(xml, os.path.join(char_dir, c['image'] + '.xml'))

        # every animation prefix must exist in the atlas
        frames = {s.attrib['name'] for s in ET.parse(xml).getroot()}
        for (anim, prefix, loop, offs) in c['anims']:
            if not check_prefix(frames, prefix):
                raise SystemExit(f"{c['json']}: prefix {prefix!r} not found for {anim}")

        with open(os.path.join(json_dir, c['json'] + '.json'), 'w') as f:
            json.dump(char_json(c), f, indent=1)
        added.append(c['json'])
        print(f"{c['json']}: {len(c['anims'])} anims, position {c['position']}")

        if c['icon']:
            size = crop_icon(grid, c['icon'], os.path.join(icon_dir, c['healthicon'] + '.png'))
            print(f"   icon {c['healthicon']}.png {size[0]}x{size[1]}")

    # characterList.txt (append names not already present)
    list_path = os.path.join(REPO, 'assets', 'preload', 'data', 'characterList.txt')
    existing = set()
    if os.path.exists(list_path):
        with open(list_path) as f:
            existing = {line.strip() for line in f if line.strip()}
    new_names = [n for n in added if n not in existing]
    if new_names:
        with open(list_path, 'a') as f:
            f.write(''.join(n + '\n' for n in new_names))
        print('characterList += ' + ', '.join(new_names))
    else:
        print('characterList unchanged')
    print('CHARACTERS DONE')


if __name__ == '__main__':
    main()
