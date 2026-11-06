import assert from 'node:assert/strict';
import test from 'node:test';

import {createEngineStructuredData, engine, platformGroups} from '../src/data/engine.mjs';

const siteUrl = 'https://havaianasdestruido.github.io';
const baseUrl = '/FNF-Phoenix-Engine/';

test('describes the engine as a free software and web application', () => {
  const data = createEngineStructuredData(siteUrl, baseUrl);

  assert.equal(data['@context'], 'https://schema.org');
  assert.ok(data['@type'].includes('SoftwareApplication'));
  assert.ok(data['@type'].includes('WebApplication'));
  assert.equal(data.name, engine.name);
  assert.equal(data.applicationCategory, 'GameApplication');
  assert.deepEqual(data.offers, {'@type': 'Offer', price: 0});
  assert.equal(data.isAccessibleForFree, true);
  assert.equal(data.license, engine.licenseUrl);
  assert.equal(data.downloadUrl, engine.releasesUrl);
  assert.deepEqual(data.sameAs, [engine.repositoryUrl]);
});

test('lists operating systems separately from browser and runtime targets', () => {
  const data = createEngineStructuredData(siteUrl, baseUrl);

  assert.deepEqual(data.operatingSystem, ['Windows', 'Linux', 'macOS', 'Android', 'iOS']);
  assert.match(data.browserRequirements, /HTML5/);
  assert.deepEqual(platformGroups.map((group) => group.label), [
    'Desktop', 'Mobile', 'Browser', 'Additional runtimes',
  ]);
  assert.deepEqual(platformGroups.flatMap((group) => group.targets), [
    'Windows', 'Linux', 'macOS', 'Android', 'iOS', 'HTML5', 'Neko', 'Flash', 'AIR',
  ]);
  for (const runtime of ['HTML5', 'Neko', 'Flash', 'AIR']) {
    assert.ok(!data.operatingSystem.includes(runtime), `${runtime} is not an operating system`);
  }
});

test('uses absolute deployment URLs, including the GitHub Pages base path', () => {
  const data = createEngineStructuredData(siteUrl, baseUrl);

  assert.equal(data.url, `${siteUrl}${baseUrl}`);
  assert.equal(data.image, `${siteUrl}${baseUrl}img/phoenix-icon.png`);
  assert.deepEqual(
    JSON.parse(JSON.stringify(data)),
    data,
    'the JSON-LD payload must survive serialization without losing values',
  );

  const customSite = createEngineStructuredData('https://example.com', '/engine/');
  assert.equal(customSite.url, 'https://example.com/engine/');
  assert.equal(customSite.image, 'https://example.com/engine/img/phoenix-icon.png');
});

test('does not fabricate ratings or reviews for rich-result eligibility', () => {
  const data = createEngineStructuredData(siteUrl, baseUrl);

  assert.ok(!Object.hasOwn(data, 'aggregateRating'));
  assert.ok(!Object.hasOwn(data, 'review'));
});
