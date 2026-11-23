#!/usr/bin/env node

/**
 * Makes the mirrored wiki copy of `website/docs/` render its images.
 *
 * The site mirror in `.github/workflows/mirror-wiki.yml` rsyncs `website/docs/`
 * into the wiki repository's `Website-Docs/` subtree. Doc pages reference their
 * screenshots as `../../static/img/screens/<name>.png`, which Docusaurus
 * resolves against `website/static/`. A GitHub wiki has no `static/` directory
 * and no asset pipeline, so the same reference would 404 there.
 *
 * This script copies the screenshot folder into the wiki as
 * `Website-Docs/screens/img/` and rewrites the references in the mirrored pages
 * from `../../static/img/screens/` to `../screens/img/`, which is what a page
 * living at `Website-Docs/screenshots/<page>.md` needs.
 *
 * Usage: `node website/scripts/mirror-wiki-images.mjs <wiki-checkout>`
 * Run it after the docs rsync and before the wiki commit.
 */

import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const websiteRoot = path.resolve(__dirname, '..');
const sourceImages = path.join(websiteRoot, 'static', 'img', 'screens');

/** Reference written by authoring, relative to `website/docs/screenshots/`. */
const AUTHORED = '../../static/img/screens/';
/** Reference that resolves inside the wiki checkout. */
const MIRRORED = '../screens/img/';

/**
 * Copies the screenshots into a wiki checkout and repoints the doc references.
 *
 * @param {string} wikiDir path to the cloned wiki repository
 * @returns {{copied: number, rewritten: string[]}} what the run changed
 */
export function mirrorScreenshots(wikiDir) {
  const pagesDir = path.join(wikiDir, 'Website-Docs', 'screenshots');
  const imagesDir = path.join(wikiDir, 'Website-Docs', 'screens', 'img');
  if (!fs.existsSync(pagesDir)) {
    throw new Error(`No mirrored screens pages at ${pagesDir}; run the docs rsync first.`);
  }
  if (!fs.existsSync(sourceImages)) {
    throw new Error(`No screenshots at ${sourceImages}.`);
  }

  fs.mkdirSync(imagesDir, {recursive: true});
  const images = fs.readdirSync(sourceImages).filter((file) => file.endsWith('.png'));
  for (const image of images) {
    fs.copyFileSync(path.join(sourceImages, image), path.join(imagesDir, image));
  }

  const rewritten = [];
  for (const page of fs.readdirSync(pagesDir).filter((file) => file.endsWith('.md'))) {
    const file = path.join(pagesDir, page);
    const source = fs.readFileSync(file, 'utf8');
    if (!source.includes(AUTHORED)) continue;
    fs.writeFileSync(file, source.split(AUTHORED).join(MIRRORED));
    rewritten.push(page);
  }

  return {copied: images.length, rewritten};
}

/**
 * Every `../../static/img/screens/<name>.png` reference the docs use, so the
 * caller (and `npm run test:seo`) can assert each one exists on disk.
 *
 * @param {string} [pagesDir] defaults to `website/docs/screenshots`
 * @returns {Array<{page: string, image: string}>} missing references
 */
export function missingScreenshots(pagesDir = path.join(websiteRoot, 'docs', 'screenshots')) {
  const missing = [];
  for (const page of fs.readdirSync(pagesDir).filter((file) => file.endsWith('.md'))) {
    const source = fs.readFileSync(path.join(pagesDir, page), 'utf8');
    for (const match of source.matchAll(/\(\.\.\/\.\.\/static\/img\/screens\/([\w.-]+\.png)\)/g)) {
      if (!fs.existsSync(path.join(sourceImages, match[1]))) {
        missing.push({page, image: match[1]});
      }
    }
  }
  return missing;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const wikiDir = process.argv[2];
  if (!wikiDir) {
    console.error('usage: node website/scripts/mirror-wiki-images.mjs <wiki-checkout>');
    process.exit(1);
  }
  const missing = missingScreenshots();
  if (missing.length) {
    for (const entry of missing) console.error(`missing ${entry.image} (referenced by ${entry.page})`);
    process.exit(1);
  }
  const result = mirrorScreenshots(wikiDir);
  console.log(`[wiki-images] copied ${result.copied} screenshots, rewrote ${result.rewritten.length} pages.`);
}
