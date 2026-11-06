import assert from 'node:assert/strict';
import test from 'node:test';

import {createEngineStructuredData, engine, platformGroups} from '../src/data/engine.mjs';
import {
  allFaqEntries,
  createFaqStructuredData,
  extraFaqEntries,
  faqPageMeta,
  homepageFaqEntries,
  stripInlineMarkup,
  tokenizeInlineMarkup,
} from '../src/data/faq.mjs';

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

test('builds FAQ @graph with WebPage, BreadcrumbList and sixteen Question entities', () => {
  const data = createFaqStructuredData(siteUrl, baseUrl);
  const expectedHomepageUrl = `${siteUrl}${baseUrl}`;
  const expectedFaqUrl = `${siteUrl}${baseUrl}faq`;

  assert.equal(data['@context'], 'https://schema.org');
  assert.equal(data['@graph'].length, 3);

  const [webPage, breadcrumb, faqPage] = data['@graph'];

  assert.deepEqual(webPage, {
    '@type': 'WebPage',
    '@id': `${expectedFaqUrl}#webpage`,
    url: expectedFaqUrl,
    name: faqPageMeta.name,
    description: faqPageMeta.description,
    inLanguage: 'en',
    isPartOf: {'@id': `${expectedHomepageUrl}#website`},
    dateModified: faqPageMeta.dateModified,
  });

  assert.deepEqual(breadcrumb, {
    '@type': 'BreadcrumbList',
    '@id': `${expectedFaqUrl}#breadcrumb`,
    itemListElement: [
      {
        '@type': 'ListItem',
        position: 1,
        name: engine.name,
        item: expectedHomepageUrl,
      },
      {
        '@type': 'ListItem',
        position: 2,
        name: 'FAQ',
        item: expectedFaqUrl,
      },
    ],
  });

  assert.equal(faqPage['@type'], 'FAQPage');
  assert.equal(faqPage['@id'], `${expectedFaqUrl}#faq`);
  assert.equal(homepageFaqEntries.length, 8);
  assert.equal(extraFaqEntries.length, 8);
  assert.equal(allFaqEntries.length, 16);
  assert.equal(faqPage.mainEntity.length, 16);
});

test('strips inline markdown links and code spans from FAQ JSON-LD answers', () => {
  const data = createFaqStructuredData(siteUrl, baseUrl);
  const faqPage = data['@graph'][2];
  const ids = new Set();
  const questions = new Set();

  for (const [index, entry] of allFaqEntries.entries()) {
    assert.match(entry.id, /^[a-z0-9-]+$/, `FAQ id must be a URL-safe slug: ${entry.id}`);
    assert.ok(!ids.has(entry.id), `Duplicate FAQ id: ${entry.id}`);
    ids.add(entry.id);

    assert.ok(entry.question.endsWith('?'), `Question must end with "?": ${entry.question}`);
    assert.ok(!questions.has(entry.question), `Duplicate FAQ question: ${entry.question}`);
    questions.add(entry.question);

    const entity = faqPage.mainEntity[index];
    assert.equal(entity['@type'], 'Question');
    assert.equal(entity.name, entry.question);
    assert.equal(entity.acceptedAnswer['@type'], 'Answer');

    const answerText = entity.acceptedAnswer.text;
    assert.ok(answerText.length >= 120, `Answer is unexpectedly short for: ${entry.question}`);
    assert.doesNotMatch(answerText, /\[[^\]]+\]\([^)]+\)/, 'Markdown links must not leak into JSON-LD');
    assert.doesNotMatch(answerText, /`/, 'Backticks must not leak into JSON-LD');
    assert.doesNotMatch(answerText, /<[^>]+>/, 'HTML tags must not leak into JSON-LD');
  }

  const tokens = tokenizeInlineMarkup('Run `lime test` via the [build guide](/docs/getting-started/building).');
  assert.deepEqual(tokens, [
    {type: 'text', text: 'Run '},
    {type: 'code', text: 'lime test'},
    {type: 'text', text: ' via the '},
    {type: 'link', text: 'build guide', href: '/docs/getting-started/building'},
    {type: 'text', text: '.'},
  ]);
  assert.equal(
    stripInlineMarkup('Run `lime test` via the [build guide](/docs/getting-started/building).'),
    'Run lime test via the build guide.',
  );
});

test('adapts FAQ @graph URLs to custom origins and base paths', () => {
  const customWithSlash = createFaqStructuredData('https://example.com', '/engine/');
  const customWithoutSlash = createFaqStructuredData('https://example.com', '/engine');
  assert.deepEqual(customWithoutSlash, customWithSlash);

  const [webPage, breadcrumb, faqPage] = customWithSlash['@graph'];
  assert.equal(webPage['@id'], 'https://example.com/engine/faq#webpage');
  assert.equal(webPage.url, 'https://example.com/engine/faq');
  assert.deepEqual(webPage.isPartOf, {'@id': 'https://example.com/engine/#website'});
  assert.equal(breadcrumb['@id'], 'https://example.com/engine/faq#breadcrumb');
  assert.equal(breadcrumb.itemListElement[0].item, 'https://example.com/engine/');
  assert.equal(breadcrumb.itemListElement[1].item, 'https://example.com/engine/faq');
  assert.equal(faqPage['@id'], 'https://example.com/engine/faq#faq');

  assert.deepEqual(
    JSON.parse(JSON.stringify(customWithSlash)),
    customWithSlash,
    'the FAQ JSON-LD payload must survive serialization without losing values',
  );
});
