/**
 * Shared engine metadata for the homepage and its SoftwareApplication JSON-LD.
 * Keep the visible platform list and structured data in sync here.
 * See BUILDING.md and docs/architecture/platform-layer.md for target details.
 */
export const engine = {
  name: 'Phoenix Engine',
  alternateName: 'FNF Phoenix Engine',
  description:
    'A free, open-source Friday Night Funkin\' engine built on Haxe, OpenFL, Lime and HaxeFlixel, '
    + 'focused on performance on low-end devices and modding with Lua, Python and HScript.',
  repositoryUrl: 'https://github.com/havaianasdestruido/FNF-Phoenix-Engine',
  releasesUrl: 'https://github.com/havaianasdestruido/FNF-Phoenix-Engine/releases',
  licenseUrl: 'https://github.com/havaianasdestruido/FNF-Phoenix-Engine/blob/main/LICENSE',
};

export const platformGroups = [
  {label: 'Desktop', targets: ['Windows', 'Linux', 'macOS'], operatingSystems: true},
  {label: 'Mobile', targets: ['Android', 'iOS'], operatingSystems: true},
  {label: 'Browser', targets: ['HTML5'], operatingSystems: false},
  {label: 'Additional runtimes', targets: ['Neko', 'Flash', 'AIR'], operatingSystems: false},
];

/**
 * Build the homepage's structured data using Docusaurus's deployment settings.
 * Neko, Flash and AIR are runtimes, not operating systems. The HTML5 target is
 * represented by WebApplication instead of an invented operating system.
 *
 * @param {string} url Site origin from siteConfig.url.
 * @param {string} baseUrl Site base path from siteConfig.baseUrl.
 * @returns {Record<string, unknown>} A JSON-serializable schema.org object.
 */
export function createEngineStructuredData(url, baseUrl) {
  const homepageUrl = new URL(baseUrl, url).href;

  return {
    '@context': 'https://schema.org',
    '@type': ['SoftwareApplication', 'WebApplication'],
    name: engine.name,
    alternateName: engine.alternateName,
    description: engine.description,
    url: homepageUrl,
    image: new URL('img/phoenix-icon.png', homepageUrl).href,
    applicationCategory: 'GameApplication',
    applicationSubCategory: 'Game engine',
    operatingSystem: platformGroups
      .filter((group) => group.operatingSystems)
      .flatMap((group) => group.targets),
    browserRequirements: 'The HTML5 build requires a browser with JavaScript enabled.',
    downloadUrl: engine.releasesUrl,
    sameAs: [engine.repositoryUrl],
    license: engine.licenseUrl,
    isAccessibleForFree: true,
    offers: {
      '@type': 'Offer',
      price: 0,
    },
    // Do not copy the example ratings from Google's documentation: no verified
    // rating source exists here. Add aggregateRating/review only with real,
    // visible reviews, following Google's review-snippet guidelines.
  };
}
