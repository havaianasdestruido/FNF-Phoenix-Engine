#!/usr/bin/env node
/**
 * Publishes the sitemap as plain text (`sitemap.txt`) instead of XML.
 *
 *   node scripts/generate-sitemap-txt.mjs
 *
 * GitHub Pages intermittently serves `sitemap.xml` in a way Google Search
 * Console refuses to fetch ("Couldn't fetch"), even when the file is valid and
 * answers HTTP 200. A plain-text sitemap — one absolute URL per line — is
 * parsed by the same crawlers and is the documented workaround, so the build
 * converts the `<loc>` entries Docusaurus generated and deletes the XML file:
 * the deployed site only ever exposes `sitemap.txt`.
 *
 * Runs automatically after `npm run build` (also used by the Pages workflow).
 */

import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const websiteDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

const locPattern = /<loc>\s*([^<]*?)\s*<\/loc>/gi;
const entityPattern = /&(?:#(\d+)|#x([0-9a-f]+)|(amp|lt|gt|quot|apos));/gi;
const namedEntities = {amp: '&', lt: '<', gt: '>', quot: '"', apos: "'"};

/** Turns the XML entities Docusaurus escapes into the characters they stand for. */
export function decodeXmlEntities(value) {
  return value.replace(entityPattern, (match, decimal, hex, named) => {
    if (named) return namedEntities[named.toLowerCase()];
    const codePoint = decimal ? Number.parseInt(decimal, 10) : Number.parseInt(hex, 16);
    return Number.isFinite(codePoint) ? String.fromCodePoint(codePoint) : match;
  });
}

/**
 * Extracts the page URLs from an XML sitemap, in document order, without
 * duplicates. Every entry must be an absolute http(s) URL: a text sitemap has
 * no room for relative paths, and a bad line makes the whole file unreadable
 * for the crawler.
 */
export function parseSitemapUrls(xml, {siteUrl} = {}) {
  assert.match(xml, /<urlset\b/i, 'sitemap must be a <urlset>, not a sitemap index');

  const urls = [];
  const seen = new Set();
  for (const match of xml.matchAll(locPattern)) {
    const url = decodeXmlEntities(match[1]).trim();
    if (seen.has(url)) continue;
    seen.add(url);

    let parsed;
    try {
      parsed = new URL(url);
    } catch {
      assert.fail(`sitemap entry is not an absolute URL: ${url}`);
    }
    assert.match(parsed.protocol, /^https?:$/, `sitemap entry must be http(s): ${url}`);
    if (siteUrl) {
      const root = new URL(siteUrl);
      assert.equal(parsed.origin, root.origin, `sitemap entry must live under the configured site URL: ${url}`);
      assert.ok(parsed.pathname.startsWith(root.pathname),
        `sitemap entry must live under the configured site URL: ${url}`);
    }
    urls.push(url);
  }

  return urls;
}

/** Renders a plain-text sitemap: one absolute URL per line. */
export function renderSitemapTxt(urls) {
  assert.ok(urls.length > 0, 'a text sitemap needs at least one URL');
  return `${urls.join('\n')}\n`;
}

/**
 * Reads the XML sitemap Docusaurus generated in `outDir`, writes `sitemap.txt`
 * beside it and deletes the XML file.
 */
export function writeSitemapTxt(outDir = path.join(websiteDir, 'build')) {
  const xmlPath = path.join(outDir, 'sitemap.xml');
  const txtPath = path.join(outDir, 'sitemap.txt');

  assert.ok(
    fs.existsSync(xmlPath),
    'build/sitemap.xml is missing — run `npm run build` (the sitemap plugin must stay enabled)',
  );

  const urls = parseSitemapUrls(fs.readFileSync(xmlPath, 'utf8'));
  fs.writeFileSync(txtPath, renderSitemapTxt(urls));

  // GitHub Pages is the reason we switched to .txt, so never ship the XML
  // file: leaving it in the artifact is what reproduces the crawl failure.
  fs.rmSync(xmlPath);

  return {path: txtPath, urls};
}

// Only act when run as a script (`node scripts/generate-sitemap-txt.mjs`); the
// tests import the helpers above and must not touch the build directory.
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const {urls} = writeSitemapTxt();
  console.log(`[sitemap] Wrote build/sitemap.txt (${urls.length} URLs) and removed build/sitemap.xml.`);
}
