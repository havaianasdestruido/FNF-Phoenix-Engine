#!/usr/bin/env node
/**
 * Checks the production homepage and FAQ page, not just the metadata helpers.
 * Docusaurus must prerender JSON-LD into <head> so crawlers do not need to
 * execute JavaScript, and every structured-data claim must be visibly rendered.
 * Runs automatically after `npm run build` (also used by the Pages workflow).
 */
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

import {createEngineStructuredData, engine, platformGroups} from '../src/data/engine.mjs';
import {createFaqStructuredData, homepageFaqEntries} from '../src/data/faq.mjs';

const websiteDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

// The production HTML minifier may remove quotes around attribute values.
const scriptPattern = /<script\b(?=[^>]*\btype\s*=\s*(?:"application\/ld\+json"|'application\/ld\+json'|application\/ld\+json(?=[\s>])))[^>]*>([\s\S]*?)<\/script>/gi;
const canonicalPattern = /<link\b(?=[^>]*\brel\s*=\s*["']?canonical["']?)[^>]*\bhref\s*=\s*(?:"([^"]+)"|'([^']+)'|([^\s>]+))/i;
const robotsPattern = /<meta\b(?=[^>]*\bname\s*=\s*["']?robots["']?(?=[\s>]))[^>]*>/gi;

function readBuiltPage(relativePath, label) {
  const fullPath = path.join(websiteDir, 'build', relativePath);
  assert.ok(fs.existsSync(fullPath), `${label} build artifact must exist: build/${relativePath}`);

  const html = fs.readFileSync(fullPath, 'utf8');
  const head = html.match(/<head\b[^>]*>([\s\S]*?)<\/head>/i)?.[1];
  assert.ok(head, `${label} must have a <head>`);

  const blocks = [...head.matchAll(scriptPattern)];
  assert.equal(blocks.length, 1, `${label} head must contain exactly one JSON-LD block`);

  const canonical = head.match(canonicalPattern);
  assert.ok(canonical, `${label} must have a canonical URL`);
  const pageUrl = new URL(canonical[1] ?? canonical[2] ?? canonical[3]);

  const robotsTags = [...head.matchAll(robotsPattern)];
  for (const [tag] of robotsTags) {
    assert.doesNotMatch(tag, /\bnoindex\b/i, `${label} must not ask crawlers to skip it`);
  }

  return {
    html,
    head,
    data: JSON.parse(blocks[0][1]),
    pageUrl,
  };
}

function toVisibleText(fragment) {
  return fragment
    .replace(/<svg\b[\s\S]*?<\/svg>/gi, '')
    .replace(/<\/?(?:section|article|div|p|h[1-6]|ul|ol|li|nav|header|footer|br)\b[^>]*>/gi, ' ')
    .replace(/<[^>]*>/g, '')
    .replace(/&#8203;|&#x200b;|\u200B/gi, '')
    .replace(/&#x27;|&#39;|&apos;/gi, "'")
    .replace(/&quot;/gi, '"')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&mdash;/gi, '—')
    .replace(/&ndash;/gi, '–')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/\s+/g, ' ')
    .trim();
}

// 1. Homepage checks (`build/index.html`)
const home = readBuiltPage('index.html', 'Homepage');
assert.deepEqual(home.data, createEngineStructuredData(home.pageUrl.origin, home.pageUrl.pathname));
assert.equal(home.data.url, home.pageUrl.href, 'JSON-LD must describe the canonical homepage');

const imagePath = path.join(websiteDir, 'build', home.data.image.slice(home.data.url.length));
assert.ok(fs.existsSync(imagePath), `Structured-data image must exist: ${home.data.image}`);

const platformSection = home.html.match(
  /<section\b(?=[^>]*\baria-labelledby\s*=\s*["']?engine-platforms["']?(?=[\s>]))[^>]*>([\s\S]*?)<\/section>/i,
)?.[1];
assert.ok(platformSection, 'Homepage must visibly describe its platform targets');
const visiblePlatforms = toVisibleText(platformSection);
for (const target of platformGroups.flatMap((group) => group.targets)) {
  assert.match(visiblePlatforms, new RegExp(`\\b${target}\\b`), `${target} must be visible without JavaScript`);
}

const homeFaqSection = home.html.match(
  /<section\b(?=[^>]*\baria-labelledby\s*=\s*["']?faq["']?(?=[\s>]))[^>]*>([\s\S]*?)<\/section>/i,
)?.[1];
assert.ok(homeFaqSection, 'Homepage must visibly render its FAQ preview section');
const visibleHomeFaq = toVisibleText(homeFaqSection);
for (const entry of homepageFaqEntries) {
  assert.ok(
    visibleHomeFaq.includes(entry.question),
    `Homepage FAQ must visibly include question: ${entry.question}`,
  );
}

// 2. Dedicated FAQ page checks (`build/faq.html`)
const faq = readBuiltPage('faq.html', 'FAQ page');
const expectedFaqData = createFaqStructuredData(home.pageUrl.origin, home.pageUrl.pathname);
assert.deepEqual(faq.data, expectedFaqData);

const [webPageNode, breadcrumbNode, faqPageNode] = faq.data['@graph'];
assert.equal(webPageNode.url, faq.pageUrl.href, 'FAQ WebPage node must match canonical FAQ URL');
assert.equal(breadcrumbNode.itemListElement[0].item, home.pageUrl.href);
assert.equal(breadcrumbNode.itemListElement[1].item, faq.pageUrl.href);

const breadcrumbsNav = faq.html.match(
  /<nav\b(?=[^>]*\baria-label\s*=\s*["']?Breadcrumbs["']?(?=[\s>]))[^>]*>([\s\S]*?)<\/nav>/i,
)?.[1];
assert.ok(breadcrumbsNav, 'FAQ page must visibly render breadcrumbs');
const visibleBreadcrumbs = toVisibleText(breadcrumbsNav);
assert.ok(visibleBreadcrumbs.includes(engine.name), 'FAQ breadcrumbs must include the site name');
assert.ok(visibleBreadcrumbs.includes('FAQ'), 'FAQ breadcrumbs must include FAQ');

const faqSection = faq.html.match(
  /<section\b(?=[^>]*\baria-labelledby\s*=\s*["']?faq-heading["']?(?=[\s>]))[^>]*>([\s\S]*?)<\/section>/i,
)?.[1];
assert.ok(faqSection, 'FAQ page must visibly render its Q&A section');
const visibleFaqText = toVisibleText(faqSection);

for (const entity of faqPageNode.mainEntity) {
  assert.ok(
    visibleFaqText.includes(entity.name),
    `FAQ page must visibly render question without JavaScript: ${entity.name}`,
  );
  assert.ok(
    visibleFaqText.includes(entity.acceptedAnswer.text),
    `FAQ page must visibly render answer without JavaScript for: ${entity.name}`,
  );
}

console.log(
  `[structured-data] Verified build/index.html and build/faq.html (${faqPageNode.mainEntity.length} Q&As, canonical URLs, breadcrumbs and image).`,
);

// Generated reference pages publish the exact same Q&As visibly and in JSON-LD.
for (const relativePath of [
  'docs/reference/backend/Paths.html',
  'docs/modding/lua-api-reference.html',
  'docs/modding/python-api-reference.html',
]) {
  const html = fs.readFileSync(path.join(websiteDir, 'build', relativePath), 'utf8');
  const head = html.match(/<head\b[^>]*>([\s\S]*?)<\/head>/i)[1];
  const data = [...head.matchAll(scriptPattern)].map((match) => JSON.parse(match[1]))
    .find((item) => item['@type'] === 'FAQPage');
  assert.ok(data?.mainEntity.length, `${relativePath} must have a FAQPage`);
  const visible = toVisibleText(html.replace(/<head\b[^>]*>[\s\S]*?<\/head>/i, '')
    .replace(/&#123;/g, '{').replace(/&#125;/g, '}'));
  for (const entry of data.mainEntity) {
    assert.ok(visible.includes(entry.name), `${relativePath}: question must be visible: ${entry.name}`);
    assert.ok(visible.includes(entry.acceptedAnswer.text), `${relativePath}: answer must be visible: ${entry.name}`);
  }
}
console.log('[structured-data] Verified generated Haxe, Lua and Python function Q&As.');
