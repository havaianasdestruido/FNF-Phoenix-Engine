import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import {fileURLToPath} from 'node:url';

import {missingScreenshots, mirrorScreenshots} from '../scripts/mirror-wiki-images.mjs';

const websiteRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const pagesDir = path.join(websiteRoot, 'docs', 'screenshots');
const imagesDir = path.join(websiteRoot, 'static', 'img', 'screens');

test('every referenced screen image exists in static/img/screens', () => {
  assert.deepEqual(missingScreenshots(), []);
});

test('each screen page has at least one image and a title', () => {
  const pages = fs.readdirSync(pagesDir).filter((file) => file.endsWith('.md'));
  assert.ok(pages.length >= 4, `expected the screen pages, found ${pages.length}`);
  for (const page of pages) {
    const source = fs.readFileSync(path.join(pagesDir, page), 'utf8');
    assert.match(source, /^title: .+$/m, `${page} has no title`);
    if (page === 'intro.md') continue;
    assert.match(source, /!\[[^\]]+\]\(\.\.\/\.\.\/static\/img\/screens\/[\w.-]+\.png\)/, `${page} has no image`);
  }
});

test('the screen images are 720p PNGs of a sane weight', () => {
  const images = fs.readdirSync(imagesDir).filter((file) => file.endsWith('.png'));
  assert.ok(images.length >= 20, `expected the screenshot set, found ${images.length}`);
  for (const image of images) {
    const buffer = fs.readFileSync(path.join(imagesDir, image));
    assert.equal(buffer.subarray(1, 4).toString('ascii'), 'PNG', `${image} is not a PNG`);
    // IHDR width/height are big-endian 32-bit values at offsets 16 and 20.
    assert.equal(buffer.readUInt32BE(16), 1280, `${image} is not 1280 wide`);
    assert.equal(buffer.readUInt32BE(20), 720, `${image} is not 720 tall`);
    assert.ok(buffer.length < 900 * 1024, `${image} is ${buffer.length} bytes, over the 900 KiB budget`);
  }
});

test('mirroring copies the images and repoints the doc references', () => {
  const wikiDir = fs.mkdtempSync(path.join(os.tmpdir(), 'phoenix-wiki-'));
  const mirroredPages = path.join(wikiDir, 'Website-Docs', 'screenshots');
  fs.mkdirSync(mirroredPages, {recursive: true});
  fs.writeFileSync(
    path.join(mirroredPages, 'menus.md'),
    '![Main menu](../../static/img/screens/mainmenu.png)\n',
  );

  const result = mirrorScreenshots(wikiDir);

  assert.ok(result.copied > 0);
  assert.deepEqual(result.rewritten, ['menus.md']);
  assert.equal(
    fs.readFileSync(path.join(mirroredPages, 'menus.md'), 'utf8'),
    '![Main menu](../screens/img/mainmenu.png)\n',
  );
  assert.ok(fs.existsSync(path.join(wikiDir, 'Website-Docs', 'screens', 'img', 'mainmenu.png')));
});

test('mirroring fails loudly when the docs were not rsynced first', () => {
  const wikiDir = fs.mkdtempSync(path.join(os.tmpdir(), 'phoenix-wiki-'));
  assert.throws(() => mirrorScreenshots(wikiDir), /No mirrored screens pages/);
});
