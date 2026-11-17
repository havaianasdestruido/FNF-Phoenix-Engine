#!/usr/bin/env python3
"""Galaxy -> Phoenix noteskin port (NOTE_assets).

Galaxy's NOTE_assets carries twelve extra frame sets that Phoenix's default
skin lacks and that the Galaxy week's M_ charts / Note rendering need:

    sblue / sgreen / spurple / sred        (synced static arrows)
    sblue release / sgreen release / spurple release / sred release
                                            (synced end-of-sustain releases)
    blue / green / purple / red release    (non-synced end-of-sustain releases)

Galaxy's Note.hx builds the anims 'bluesync'/'redsync'/... from the
'<color>sync' prefixes ('sblue0') and the '<color>syncrelease' anims from
'<color> release' — see /tmp/galaxy/source/Note.hx.

The eight frames are appended as one row on the right of the existing
NOTE_assets canvas (frames are <=157px tall, canvas is 238px tall, so the
height is unchanged) and registered in NOTE_assets.xml under their original
names (already 4-digit padded: sblue0000, "sblue release0000", ...).
"""
import os
import sys
import xml.etree.ElementTree as ET

GALAXY = '/tmp/galaxy'
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image  # noqa: E402

WANT = [
    'sblue0000', 'sgreen0000', 'spurple0000', 'sred0000',
    'sblue release0000', 'sgreen release0000', 'spurple release0000', 'sred release0000',
    # non-synced end-of-sustain release frames (Galaxy isEnd non-sync notes)
    'blue release0000', 'green release0000', 'purple release0000', 'red release0000',
]
CELL = 160


def main():
    g_png = os.path.join(GALAXY, 'assets', 'preload', 'images', 'NOTE_assets.png')
    g_xml = os.path.join(GALAXY, 'assets', 'preload', 'images', 'NOTE_assets.xml')
    p_png = os.path.join(REPO, 'assets', 'shared', 'images', 'noteskins', 'NOTE_assets.png')
    p_xml = os.path.join(REPO, 'assets', 'shared', 'images', 'noteskins', 'NOTE_assets.xml')

    src = Image.open(g_png).convert('RGBA')
    root = ET.parse(g_xml).getroot()
    frames = {s.attrib['name']: s.attrib for s in root}
    missing = [n for n in WANT if n not in frames]
    if missing:
        raise SystemExit(f'missing galaxy frames: {missing}')

    # idempotent: reset the tracked files to the pristine base atlas first
    import subprocess
    subprocess.run(['git', '-C', REPO, 'checkout', '--',
                    'assets/shared/images/noteskins/NOTE_assets.png',
                    'assets/shared/images/noteskins/NOTE_assets.xml'], check=True)

    proot = ET.parse(p_xml).getroot()
    pim = Image.open(p_png).convert('RGBA')
    W, H = pim.size

    # strip any previously ported copies of these frames from the base
    # (the committed atlas may already carry some of them)
    for s in list(proot):
        if s.attrib.get('name') in WANT:
            proot.remove(s)

    new_w = W + CELL * len(WANT)
    canvas = Image.new('RGBA', (new_w, H), (0, 0, 0, 0))
    canvas.paste(pim, (0, 0))

    placed = []
    for i, name in enumerate(WANT):
        a = frames[name]
        x, y = int(a['x']), int(a['y'])
        w, h = int(a['width']), int(a['height'])
        tile = src.crop((x, y, x + w, y + h))
        px = W + i * CELL
        py = 5
        canvas.paste(tile, (px, py), tile)
        el = ET.SubElement(proot, 'SubTexture')
        el.attrib = {'name': name, 'x': str(px), 'y': str(py), 'width': str(w), 'height': str(h)}
        placed.append(name)
    proot.attrib['width'] = str(new_w)

    # keep the packer header comment
    canvas.save(p_png)
    header = ('<?xml version="1.0" encoding="UTF-8"?>\n'
              '<!--\nCreated with Funkin Packer v0.1.3 https://neeeoo.github.io/funkin-packer/\n-->\n')
    body = ET.tostring(proot, encoding='unicode')
    with open(p_xml, 'w') as f:
        f.write(header + body + '\n')

    print(f'NOTE_assets: {W}x{H} -> {new_w}x{H}, added {len(placed)} frames:')
    for n in placed:
        print('  ', n)
    print('NOTESKIN DONE')


if __name__ == '__main__':
    main()
