# Phoenix Engine documentation site

[Docusaurus 3](https://docusaurus.io/) site documenting the FNF Phoenix Engine codebase.
Published to GitHub Pages by `.github/workflows/docs.yml`.

## Run it

```bash
cd website
npm install
npm start          # dev server (regenerates the reference first)
npm run build      # production build into website/build (also runs docs and SEO checks)
npm run serve      # serve the production build
npm run lint:docs  # check the markdown conventions the site needs to render
npm run test:seo   # check the engine/platform and FAQ structured-data metadata
```

Node 20+ is required.

## What is generated

Two parts of the site are produced from the Haxe sources and are **git-ignored** — never
edit them by hand:

| Command | Reads | Writes |
|---|---|---|
| `npm run gen:api` | `source/**/*.hx` | `docs/reference/**` — one page per type, one index per package |
| `npm run gen:scripts` | `source/psychlua/**` | `docs/modding/lua-api-reference.md`, `docs/modding/python-api-reference.md` |
| `npm run gen` | both | both |

`npm start` and `npm run build` run `npm run gen` first, so the reference is always in
sync with the code. `npm run build` additionally runs `npm run lint:docs`, which rejects
markdown that builds fine but renders wrong — most often an admonition written as
`:::note Title` instead of `:::note[Title]`.

To document something in the reference, write a `/** ... */` doc comment on the Haxe type
or field, or a `//` comment directly above a `registerFunction(...)` call, and regenerate.

## Engine and FAQ structured data

The homepage describes Phoenix Engine with Google's `SoftwareApplication` JSON-LD
format. `src/data/engine.mjs` is the shared source for that metadata and the visible
platform cards in `src/pages/index.js`; update both together by editing that file.
The JSON-LD is prerendered into the HTML `<head>`, not injected only after JavaScript
loads. Canonical, image and download URLs use the configured site URL/base path.

- `operatingSystem` lists Windows, Linux, macOS, Android and iOS.
- HTML5 is described through the `WebApplication` type and browser requirements.
- Neko, Flash and AIR are visible compilation targets/runtimes, not operating systems.
- The engine is free and open source, so `offers.price` is `0`.

The `/faq` page (`src/pages/faq.js`) publishes a schema.org `@graph` containing
`WebPage`, `BreadcrumbList` and `FAQPage` (`mainEntity` with sixteen `Question` /
`Answer` entries). `src/data/faq.mjs` is the single source for those sixteen Q&As:
the first eight (`homepageFaqEntries`) also appear in the `#faq` preview section on
the homepage, while inline `[label](url)` links and `` `code` `` spans are rendered
visibly with `<FaqAnswer>` and stripped to plain text for `acceptedAnswer.text`.

Google also requires a real `aggregateRating` or `review` for software rich-result
eligibility. Neither is invented here: add one only when a verified, visible rating
source exists and follows Google's review-snippet guidelines. Valid markup alone
does not guarantee a rich result.

`npm run build` runs `test:seo` before building and `check-structured-data.mjs`
afterwards. The latter checks both `build/index.html` and `build/faq.html` for valid
JSON-LD, matching canonical/breadcrumb/image URLs, visible platform targets, every
visible Q&A question and answer, and no `noindex` directive.
After deployment, use Google's Rich Results Test and Search Console URL Inspection
to check the live pages; indexing can take time.

## Dependency overrides

Docusaurus pins a few transitive packages that the GitHub advisory database flags
(worker pools, the dev-server HTTP stack, the SVG/DOMPurify/Mermaid chain). Their
direct parents cannot move yet — `@docusaurus/core` still declares
`tinypool: ^1.0.2` and `webpack-dev-server: ^5.2.2`, so a plain
`npm install` keeps resolving the vulnerable versions.

`package.json` therefore uses npm `overrides` to force the patched release of each
one. The overrides are deliberate and have to stay:

| Package | Override | Why the parent cannot move |
|---|---|---|
| `tinypool` | `2.2.0` | `@docusaurus/core` asks for `^1.0.2`; 2.x is API-compatible for the SSG pool it creates |
| `serialize-javascript` | `7.1.4` | `copy-webpack-plugin`/`css-minimizer-webpack-plugin` ask for `^6`; 7.x keeps the same default export |
| `minimatch` | `11.0.4` | `serve-handler@6.1.7` (latest) pins `3.1.5`; the APIs it uses are stable |
| `uuid` | `11.1.1` | `sockjs` asks for `^8.3.2`; only `v4()` is used |
| `postcss-selector-parser` | `6.1.5` | 6.x parents need `^6`; the `^7` copies are resolved separately and are already patched |
| `katex` | `0.18.10` | `mermaid` asks for `^0.16.47`; 0.18.x is the first patched line (`0.18.11` was published broken) |
| `dompurify`, `follow-redirects`, `launch-editor`, `joi`, `body-parser`, `qs`, `fast-uri` | latest patch | declared ranges are compatible, the override just skips a stale lock entry |

Bumping `@docusaurus/*` can make some of these unnecessary; drop an override only
after `npm audit --omit=dev --audit-level=low` (and the plain audit) comes back with
nothing but `deepmerge` (no patched release exists upstream). Do not run
`npm audit fix --force` here: it downgrades Docusaurus to 3.7.0 and breaks the build.

After changing an override, verify with a clean `rm -rf node_modules && npm ci &&
npm run build` and a quick `npm start` — the dev server is what exercises
`webpack-dev-server` and `sockjs`.

## Layout

```text
docs/
├── intro.md
├── getting-started/   requirements, building, running, project.hxp, troubleshooting
├── architecture/      overview, source tree, boot, state flow, paths, timing, patches
├── subsystems/        gameplay, charts, characters, shaders, options, editors, audio, mobile…
├── modding/           folder layout, Lua, Python, HScript, hooks, events/notetypes
├── contributing/      workflow, code style, CI, docs
└── reference/         GENERATED
scripts/
├── haxe-parser.mjs          dependency-free Haxe parser
├── generate-api-docs.mjs    code reference generator
├── generate-script-api.mjs  Lua/Python API generator
├── check-doc-syntax.mjs     markdown/admonition lint
└── check-structured-data.mjs  production homepage and FAQ JSON-LD check
src/
├── components/FaqAnswer/    renders inline FAQ links and code tokens
├── data/engine.mjs          shared engine metadata and platform targets
├── data/faq.mjs             shared Q&A copy and FAQPage @graph builder
└── pages/
    ├── index.js             homepage, visible platforms, FAQ preview and JSON-LD head tag
    └── faq.js               dedicated FAQ page, breadcrumbs and @graph JSON-LD head tag
tests/
└── structured-data.test.mjs  metadata regression tests
```

`sidebars.js` autogenerates one sidebar from the folder tree; ordering comes from
`sidebar_position` front matter and `_category_.json` files.

More detail: [Contributing → Documentation](./docs/contributing/documentation.md).

### Generated function Q&A

Generated Haxe type pages and the Lua/Python API references include visible
function Q&As and prerendered FAQPage JSON-LD. Both use the same entries, built
by `scripts/function-faq.mjs`; the generator takes descriptions and signatures
from the source, and labels invocation patterns as placeholders rather than
pretending they are runnable examples. When a source description is missing, the
answer says so and points readers to the linked implementation. Improve those
answers by documenting the function at its source. A few verified scripting
examples are maintained in `function-faq.mjs`. The post-build check verifies
representative Haxe, Lua and Python pages against their visible Q&As. FAQ schema
is not a guarantee of search-engine rich results.
