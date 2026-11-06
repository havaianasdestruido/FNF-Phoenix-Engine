import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import {
  decodeXmlEntities,
  parseSitemapUrls,
  renderSitemapTxt,
} from '../scripts/generate-sitemap-txt.mjs';

const xmlFor = (...urls) => `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls.map((url) => `  <url><loc>${url}</loc><lastmod>2026-11-06T00:00:00.000Z</lastmod></url>`).join('\n')}
</urlset>`;

test('extracts every <loc> entry in document order without duplicates', () => {
  const urls = parseSitemapUrls(xmlFor(
    'https://havaianasdestruido.github.io/FNF-Phoenix-Engine/',
    'https://havaianasdestruido.github.io/FNF-Phoenix-Engine/faq',
    'https://havaianasdestruido.github.io/FNF-Phoenix-Engine/faq',
  ));

  assert.deepEqual(urls, [
    'https://havaianasdestruido.github.io/FNF-Phoenix-Engine/',
    'https://havaianasdestruido.github.io/FNF-Phoenix-Engine/faq',
  ]);
});

test('unescapes XML entities so the text sitemap has the real URLs', () => {
  assert.equal(decodeXmlEntities('a&amp;b'), 'a&b');
  assert.equal(decodeXmlEntities('&quot;x&quot;'), '"x"');
  assert.equal(decodeXmlEntities('&#39;'), "'");
  assert.equal(decodeXmlEntities('&#x27;'), "'");

  assert.deepEqual(parseSitemapUrls(xmlFor('https://example.com/docs?a=1&amp;b=2')), [
    'https://example.com/docs?a=1&b=2',
  ]);
});

test('rejects entries that crawlers could not follow', () => {
  assert.throws(() => parseSitemapUrls(xmlFor('/docs/intro')), /not an absolute URL/);
  assert.throws(() => parseSitemapUrls(xmlFor('ftp://example.com/docs')), /must be http\(s\)/);
  assert.throws(
    () => parseSitemapUrls(xmlFor('https://example.com/docs'), {siteUrl: 'https://example.com/engine/'}),
    /configured site URL/,
  );
  assert.throws(() => parseSitemapUrls('<sitemapindex></sitemapindex>'), /must be a <urlset>/);
});

test('renders one URL per line, with a trailing newline', () => {
  const urls = ['https://example.com/', 'https://example.com/faq'];
  assert.equal(renderSitemapTxt(urls), 'https://example.com/\nhttps://example.com/faq\n');
  assert.throws(() => renderSitemapTxt([]), /at least one URL/);
});

test('writes build/sitemap.txt and removes build/sitemap.xml', async () => {
  const {writeSitemapTxt} = await import('../scripts/generate-sitemap-txt.mjs');
  const outDir = fs.mkdtempSync(path.join(os.tmpdir(), 'phoenix-sitemap-'));
  fs.writeFileSync(path.join(outDir, 'sitemap.xml'), xmlFor(
    'https://havaianasdestruido.github.io/FNF-Phoenix-Engine/',
    'https://havaianasdestruido.github.io/FNF-Phoenix-Engine/faq',
  ));

  try {
    const {urls} = writeSitemapTxt(outDir);

    assert.equal(urls.length, 2);
    assert.equal(
      fs.readFileSync(path.join(outDir, 'sitemap.txt'), 'utf8'),
      `${urls.join('\n')}\n`,
      'the text sitemap is one URL per line',
    );
    assert.ok(!fs.existsSync(path.join(outDir, 'sitemap.xml')), 'the XML sitemap must not be deployed');
  } finally {
    fs.rmSync(outDir, {recursive: true, force: true});
  }
});

test('fails loudly when the build produced no sitemap', async () => {
  const {writeSitemapTxt} = await import('../scripts/generate-sitemap-txt.mjs');
  const outDir = fs.mkdtempSync(path.join(os.tmpdir(), 'phoenix-sitemap-empty-'));
  try {
    assert.throws(() => writeSitemapTxt(outDir), /sitemap\.xml is missing/);
  } finally {
    fs.rmSync(outDir, {recursive: true, force: true});
  }
});
