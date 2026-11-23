"""Minimal Sparrow/Starling atlas reader + Alphabet renderer for Phoenix Engine art.

Frames are (`x`, `y`, `width`, `height`, `frameX`, `frameY`, `frameWidth`,
`frameHeight`), matching what `FlxAtlasFrames.fromSparrow` produces: a frame with
`frameX/frameY` offsets is cropped inside a larger logical frame, so the crop has to be
placed at `-frameX, -frameY` inside a `frameWidth x frameHeight` box.
"""
import re
import xml.etree.ElementTree as ET

from PIL import Image


class Atlas:
    def __init__(self, image_path, xml_path):
        self.image = Image.open(image_path).convert('RGBA')
        self.frames = {}
        tree = ET.parse(xml_path)
        for sub in tree.getroot().iter('SubTexture'):
            name = sub.get('name')
            x = int(sub.get('x')); y = int(sub.get('y'))
            w = int(sub.get('width')); h = int(sub.get('height'))
            fx = int(sub.get('frameX') or 0); fy = int(sub.get('frameY') or 0)
            fw = int(sub.get('frameWidth') or w); fh = int(sub.get('frameHeight') or h)
            self.frames[name] = (x, y, w, h, fx, fy, fw, fh)

    def prefixes(self):
        """Every prefix with the trailing frame counter and Flixel's ` instance` dropped."""
        return sorted({self._prefix_of(n) for n in self.frames})

    @staticmethod
    def _prefix_of(name):
        return re.sub(r'\d+$', '', name).replace(' instance ', ' ').strip()

    def frame_for(self, prefix, index=0):
        """Return the atlas frame name for `prefix` at `index`, clamping to the range."""
        names = sorted(n for n in self.frames if self._prefix_of(n) == prefix)
        if not names:
            raise KeyError(prefix)
        return names[min(index, len(names) - 1)]

    def render(self, prefix, index=0, scale=1.0):
        """Return an RGBA image of the logical frame box, cropped art placed correctly."""
        name = self.frame_for(prefix, index)
        x, y, w, h, fx, fy, fw, fh = self.frames[name]
        crop = self.image.crop((x, y, x + w, y + h))
        box = Image.new('RGBA', (fw, fh), (0, 0, 0, 0))
        box.alpha_composite(crop, (-fx, -fy))
        if scale != 1.0:
            box = box.resize((max(1, round(fw * scale)), max(1, round(fh * scale))), Image.LANCZOS)
        return box


ALPHABET_LETTERS = set('abcdefghijklmnopqrstuvwxyz0123456789')

# Prefixes present in the shipped `alphabet.png`. `AlphaCharacter.setupImageGlyph`
# normalises whitespace to `space normal`, so a space has no glyph of its own.
SPACE_PREFIX = 'space normal'


class Alphabet:
    """Renders text with the engine's own `alphabet.png`, the way `objects.Alphabet` does.

    `bold=True` picks the `"<char> bold"` frames (the display face used for song and
    menu labels); `bold=False` picks `"<char> uppercase"` / `"<char> lowercase"` for
    letters and `"<char> normal"` for everything else, matching the suffix rules in
    `AlphaCharacter.setupImageGlyph`.
    """

    def __init__(self, atlas, letter_spacing=0):
        self.atlas = atlas
        self.letter_spacing = letter_spacing

    def _prefix(self, char, bold):
        lower = char.lower()
        if bold:
            return f'{lower} bold'
        if lower in ALPHABET_LETTERS:
            return f'{lower} uppercase' if lower != char else f'{lower} lowercase'
        return f'{lower} normal'

    def _glyph(self, char, bold):
        for prefix in (self._prefix(char, bold), f'{char.lower()} bold', f'{char.lower()} normal'):
            try:
                return self.atlas.render(prefix)
            except KeyError:
                continue
        return None

    def render(self, text, bold=True):
        try:
            gap = self.atlas.render(SPACE_PREFIX).width
        except KeyError:
            gap = 24
        glyphs = []
        for char in text:
            if char == ' ':
                glyphs.append(('space', gap))
                continue
            glyph = self._glyph(char, bold)
            if glyph is not None:
                glyphs.append(('glyph', glyph))
        width = sum(item[1].width if item[0] == 'glyph' else item[1] for item in glyphs)
        width += self.letter_spacing * max(0, len(glyphs) - 1)
        height = max((item[1].height for item in glyphs if item[0] == 'glyph'), default=1)
        out = Image.new('RGBA', (max(1, width), max(1, height)), (0, 0, 0, 0))
        x = 0
        for kind, value in glyphs:
            if kind == 'glyph':
                out.alpha_composite(value, (x, 0))
                x += value.width + self.letter_spacing
            else:
                x += value + self.letter_spacing
        return out
