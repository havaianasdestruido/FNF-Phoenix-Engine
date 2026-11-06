#!/usr/bin/env node
/**
 * Checks the production homepage, not just the metadata helper. Docusaurus must
 * prerender the JSON-LD into <head> so crawlers do not need to execute JavaScript.
 * Runs automatically after `npm run build` (also used by the Pages workflow).
 */
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

import {createEngineStructuredData, platformGroups} from '../src/data/engine.mjs';

const websiteDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const html = fs.readFileSync(path.join(websiteDir, 'build/index.html'), 'utf8');
const head = html.match(/<head\b[^>]*>([\s\S]*?)<\/head>/i)?.[1];
assert.ok(head, 'Homepage must have a <head>');

// The production HTML minifier may remove quotes around attribute values.
const scriptPattern = /<script\b(?=[^>]*\btype\s*=\s*(?:"application\/ld\+json"|'application\/ld\+json'|application\/ld\+json(?=[\s>])))[^>]*>([\s\S]*?)<\/script>/gi;
const blocks = [...head.matchAll(scriptPattern)];
assert.equal(blocks.length, 1, 'Homepage head must contain exactly one JSON-LD block');

const data = JSON.parse(blocks[0][1]);
const canonical = head.match(/<link\b(?=[^>]*\brel\s*=\s*["']?canonical["']?)[^>]*\bhref\s*=\s*(?:"([^"]+)"|'([^']+)'|([^\s>]+))/i);
assert.ok(canonical, 'Homepage must have a canonical URL');
const pageUrl = new URL(canonical[1] ?? canonical[2] ?? canonical[3]);
assert.deepEqual(data, createEngineStructuredData(pageUrl.origin, pageUrl.pathname));
assert.equal(data.url, pageUrl.href, 'JSON-LD must describe the canonical homepage');

const imagePath = path.join(websiteDir, 'build', data.image.slice(data.url.length));
assert.ok(fs.existsSync(imagePath), `Structured-data image must exist: ${data.image}`);

const platformSection = html.match(/<section\b(?=[^>]*\baria-labelledby\s*=\s*["']?engine-platforms["']?(?=[\s>]))[^>]*>([\s\S]*?)<\/section>/i)?.[1];
assert.ok(platformSection, 'Homepage must visibly describe its platform targets');
const visibleText = platformSection.replace(/<[^>]*>/g, ' ');
for (const target of platformGroups.flatMap((group) => group.targets)) {
  assert.match(visibleText, new RegExp(`\\b${target}\\b`), `${target} must be visible without JavaScript`);
}

const robotsTags = [...head.matchAll(/<meta\b(?=[^>]*\bname\s*=\s*["']?robots["']?(?=[\s>]))[^>]*>/gi)];
for (const [tag] of robotsTags) {
  assert.doesNotMatch(tag, /\bnoindex\b/i, 'Homepage must not ask crawlers to skip it');
}

console.log('[structured-data] JSON-LD, canonical URLs, image and all platform targets verified in build/index.html.');
