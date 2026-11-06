import {engine} from './engine.mjs';

/**
 * Shared Q&A copy and FAQPage JSON-LD builder for the documentation site.
 *
 * Answers may use inline `[label](url)` links and `` `code` `` spans:
 * - Visible pages render them with Docusaurus `<Link>` and `<code>` elements.
 * - `stripInlineMarkup()` turns the same source string into plain text for
 *   JSON-LD `acceptedAnswer.text`, keeping visible text and structured data
 *   identical without duplicating copy.
 */

export const faqPageMeta = {
  title: 'FAQ: Phoenix Engine, Multi-Platform Builds & Modding',
  name: 'FAQ: Phoenix Engine, multi-platform builds and Lua, Python and HScript modding',
  heading: 'Frequently asked questions about Phoenix Engine',
  description:
    'Sixteen questions with direct answers about FNF Phoenix Engine: supported platforms, '
    + 'Psych and JS Engine mod compatibility, Lua, Python and HScript scripting, and building from source.',
  dateModified: '2026-11-06',
};

/**
 * Core questions shown on both the homepage (`#faq`) and the dedicated `/faq` page.
 */
export const homepageFaqEntries = [
  {
    id: 'what-is-phoenix-engine',
    question: 'What is Phoenix Engine and how does it relate to Psych Engine and JS Engine?',
    answer:
      "Phoenix Engine is a free, open-source Friday Night Funkin' engine written in Haxe on OpenFL, "
      + 'Lime and HaxeFlixel. It forks [JS Engine](https://github.com/JordanSantiagoYT/FNF-JS-Engine), '
      + 'itself a performance-focused fork of Psych Engine, adding [Python scripting](/docs/modding/python-scripting), '
      + 'native Android and desktop bridges, modularized gameplay helpers and compile-time feature flags for low-end devices.',
  },
  {
    id: 'supported-platforms',
    question: 'Which platforms and compilation targets does Phoenix Engine support?',
    answer:
      'Phoenix Engine targets five operating systems — Windows, Linux, macOS, Android and iOS — alongside '
      + 'an HTML5 browser build and Neko, Flash and AIR runtimes. Feature availability varies by target: '
      + 'C++ desktop and mobile builds include the full modding stack, while HTML5 supports HScript without '
      + 'Lua, Python or video playback. See the [platform layer](/docs/architecture/platform-layer).',
  },
  {
    id: 'mod-compatibility',
    question: 'Are Psych Engine and JS Engine mods compatible with Phoenix Engine?',
    answer:
      'Yes. Phoenix Engine preserves the Psych Engine and JS Engine mod folder contract — `mods/MyMod/` '
      + 'with `data/`, `songs/`, `characters/`, `stages/`, `weeks/`, `scripts/`, `custom_events/` and '
      + '`custom_notetypes/` — plus Psych 1.0 charts and standard Lua callbacks, so most existing folder '
      + 'mods load unchanged. See the [modding overview](/docs/modding/overview).',
  },
  {
    id: 'scripting-languages',
    question: "Which scripting languages can I use to make a Friday Night Funkin' mod?",
    answer:
      'Three scripting runtimes are built in: [Lua](/docs/modding/lua-scripting) via `hxluajit`, '
      + '[Python](/docs/modding/python-scripting) via the pure-Haxe Hython interpreter, and standalone '
      + '[HScript](/docs/modding/hscript) (`.hx` or `.hscript`) via `hscript-improved` with direct access '
      + 'to engine classes. All three share song and state lifecycle hooks such as `onCreate`, `onBeatHit` '
      + 'and `onNoteHit`.',
  },
  {
    id: 'installing-folder-mods',
    question: 'How do I install and enable a folder mod without recompiling the engine?',
    answer:
      'Place your mod folder inside `mods/MyMod/`, include optional metadata in `pack.json`, and '
      + 'enable it either from the in-game Mods menu or by adding `MyMod|1` to `modsList.txt`. Drop '
      + '`.lua`, `.py` or `.hx` files into `scripts/` for global logic or `data/my-song/` for song-specific '
      + 'behaviour. See [mod folder structure](/docs/modding/mod-folder-structure).',
  },
  {
    id: 'compiling-from-source',
    question: 'How do I compile Phoenix Engine from source?',
    answer:
      'Install Haxe 4.2.5 or newer (4.3.7 recommended) and Git, run `haxelib setup`, then run '
      + '`setup\\windows.bat` on Windows or `sh setup/unix.sh` on Linux and macOS to install the pinned '
      + 'libraries from `hmm.json`. Compile a release build with `haxelib run lime build windows -Dofficial` '
      + 'or launch directly with `lime test windows` (or `linux`, `mac`, `android`, `html5`). Follow the '
      + '[build guide](/docs/getting-started/building).',
  },
  {
    id: 'lean-and-content-stripped-builds',
    question: "How can I build a smaller binary or strip built-in Friday Night Funkin' assets?",
    answer:
      'Pass `-DMODDING_LEVEL=1` to drop the Python VM while keeping Lua, or `-DMODDING_LEVEL=0` to '
      + 'exclude both Lua and Python from compilation. Pass `-DNO_BUILTIN_CONTENT` to omit base-game songs, '
      + 'charts, weeks, characters and cutscene videos while keeping the UI shell, editors and `mods/` '
      + 'loader. Details are in [project configuration](/docs/getting-started/project-configuration).',
  },
  {
    id: 'license-and-reuse',
    question: 'Is Phoenix Engine free to use for my own mods and forks?',
    answer:
      'Yes. Phoenix Engine is free and open source under the '
      + `[Apache License 2.0](${engine.licenseUrl}). You can build, modify and redistribute mods or engine `
      + 'forks at no cost, provided you preserve the license and attribution notices and respect the '
      + 'separate licenses of bundled fonts, libraries and base-game assets.',
  },
];

/**
 * Additional questions answered on the dedicated `/faq` page (16 questions total).
 */
export const extraFaqEntries = [
  {
    id: 'why-project-hxp',
    question: 'Why does Phoenix Engine use project.hxp instead of project.xml?',
    answer:
      'Lime natively executes `.hxp` build scripts as Haxe classes extending `HXProject`. Using '
      + '`project.hxp` replaces deeply nested XML conditionals with readable Haxe methods for feature flags '
      + '(`LUA_ALLOWED`, `PYTHON_ALLOWED`, `VIDEOS_ALLOWED`), asset exclusions, class-path precedence and '
      + 'Android pre-build callbacks. See [project configuration](/docs/getting-started/project-configuration).',
  },
  {
    id: 'bundled-editors',
    question: 'What in-game editors come bundled with Phoenix Engine?',
    answer:
      'Phoenix Engine ships Chart, Character, Stage, Week, Dialogue, Dialogue Character and Menu Character '
      + 'editors, plus a Note Splash debugger and in-editor playtesting (`EditorPlayState`). The chart '
      + 'editor caches grid layers and audio waveforms for high-note-count charts and rotates through '
      + 'multiple automatic backup files on save. See [editors](/docs/subsystems/editors).',
  },
  {
    id: 'mobile-support',
    question: 'How does Android and iOS mobile support work?',
    answer:
      'On first launch, `mobile.CopyState` extracts packaged assets into writable app storage so `mods/`, '
      + 'saves and editors work on device. Menus and gameplay add virtual pad and four-lane hitbox touch '
      + 'controls, while Android integrates JNI bridges for Media3 lock-screen sessions, display cutouts, '
      + 'haptics and a system Files provider. See [mobile](/docs/subsystems/mobile).',
  },
  {
    id: 'audio-formats',
    question: 'Which audio format should songs and sound effects use?',
    answer:
      'Use Ogg Vorbis (`.ogg`). Every non-SWF target — desktop, mobile and HTML5 — uses `.ogg` because '
      + 'Vorbis decodes faster and seeks more accurately than MP3 when keeping charts locked to the '
      + 'instrumental; only Flash and AIR fall back to `.mp3`. Mods may ship either format via '
      + '`Paths.SOUND_EXTENSIONS`. See [audio and music](/docs/subsystems/audio).',
  },
  {
    id: 'pinned-haxelib-forks',
    question: 'Why did my Android or Windows C++ build fail after installing Haxe libraries?',
    answer:
      'Several libraries in `hmm.json` — including `lime`, `openfl`, `flixel`, `hxcpp` and `hxvlc` — '
      + 'point to pinned Git forks rather than public haxelib releases, so running `haxelib install` '
      + 'manually can switch the active library away from the fork. Re-run `setup/windows.bat` (plus '
      + '`setup/windows-msvc-fix.ps1` on MSVC) or `setup/unix.sh`, and check [troubleshooting](/docs/getting-started/troubleshooting).',
  },
  {
    id: 'transparent-windows-and-effects',
    question: 'Can mods create transparent windows or fourth-wall desktop effects?',
    answer:
      'Yes, on supported desktop targets. Windows builds expose color-key window transparency, '
      + 'whole-window opacity and click-through overlays via `backend.TransparentWindow` for Lua, Python '
      + 'and HScript mods. Optional fourth-wall desktop utilities (`META_HORROR`) are isolated behind '
      + 'explicit opt-in and script security guards. Read [transparent window](/docs/modding/transparent-window) '
      + 'and [script security](/docs/modding/script-security).',
  },
  {
    id: 'generated-api-reference',
    question: 'How is the API and scripting documentation kept in sync with the Haxe source code?',
    answer:
      'Running `npm run gen` inside `website/` parses every Haxe module under `source/` into the '
      + '[code reference](/docs/reference) and extracts `registerFunction` declarations from '
      + '`source/psychlua/` into the [Lua API reference](/docs/modding/lua-api-reference) and '
      + '[Python API reference](/docs/modding/python-api-reference). Both `npm start` and the GitHub Pages '
      + 'workflow regenerate those pages automatically on every build.',
  },
  {
    id: 'releases-bugs-and-contributing',
    question: 'Where do I download releases, report bugs or contribute patches?',
    answer:
      `Pre-built binaries are published on [GitHub Releases](${engine.releasesUrl}), bug reports and `
      + `feature requests belong on [GitHub Issues](${engine.repositoryUrl}/issues), and pull requests `
      + 'target the `main` branch. Before opening a PR, format Haxe code with `hxformat.json` (two-space '
      + 'indentation) and read the [contributing workflow](/docs/contributing/workflow).',
  },
];

export const allFaqEntries = [...homepageFaqEntries, ...extraFaqEntries];

const INLINE_MARKUP_RE = /\[([^\]]+)\]\(([^)]+)\)|`([^`]+)`/g;

/**
 * Split an answer string into plain-text, inline-code and link tokens.
 *
 * @param {string} text
 * @returns {Array<{type: 'text', text: string} | {type: 'code', text: string} | {type: 'link', text: string, href: string}>}
 */
export function tokenizeInlineMarkup(text) {
  const tokens = [];
  let lastIndex = 0;

  for (const match of text.matchAll(INLINE_MARKUP_RE)) {
    const matchIndex = match.index ?? 0;
    if (matchIndex > lastIndex) {
      tokens.push({type: 'text', text: text.slice(lastIndex, matchIndex)});
    }
    if (match[1] !== undefined && match[2] !== undefined) {
      tokens.push({type: 'link', text: match[1], href: match[2]});
    } else if (match[3] !== undefined) {
      tokens.push({type: 'code', text: match[3]});
    }
    lastIndex = matchIndex + match[0].length;
  }

  if (lastIndex < text.length) {
    tokens.push({type: 'text', text: text.slice(lastIndex)});
  }

  return tokens;
}

/**
 * Convert an answer string with inline `[label](url)` / `` `code` `` markup
 * into plain text suitable for schema.org `Answer.text`.
 *
 * @param {string} text
 * @returns {string}
 */
export function stripInlineMarkup(text) {
  return tokenizeInlineMarkup(text)
    .map((token) => token.text)
    .join('');
}

function normalizeBaseUrl(baseUrl) {
  return baseUrl.endsWith('/') ? baseUrl : `${baseUrl}/`;
}

/**
 * Build the `/faq` page's `@graph` structured data (`WebPage`, `BreadcrumbList`
 * and `FAQPage`) using Docusaurus's configured origin and base path.
 *
 * @param {string} url Site origin from `siteConfig.url`.
 * @param {string} baseUrl Site base path from `siteConfig.baseUrl`.
 * @returns {Record<string, unknown>} A JSON-serializable schema.org `@graph` object.
 */
export function createFaqStructuredData(url, baseUrl) {
  const homepageUrl = new URL(normalizeBaseUrl(baseUrl), url).href;
  const faqUrl = new URL('faq', homepageUrl).href;

  return {
    '@context': 'https://schema.org',
    '@graph': [
      {
        '@type': 'WebPage',
        '@id': `${faqUrl}#webpage`,
        url: faqUrl,
        name: faqPageMeta.name,
        description: faqPageMeta.description,
        inLanguage: 'en',
        isPartOf: {
          '@id': `${homepageUrl}#website`,
        },
        dateModified: faqPageMeta.dateModified,
      },
      {
        '@type': 'BreadcrumbList',
        '@id': `${faqUrl}#breadcrumb`,
        itemListElement: [
          {
            '@type': 'ListItem',
            position: 1,
            name: engine.name,
            item: homepageUrl,
          },
          {
            '@type': 'ListItem',
            position: 2,
            name: 'FAQ',
            item: faqUrl,
          },
        ],
      },
      {
        '@type': 'FAQPage',
        '@id': `${faqUrl}#faq`,
        mainEntity: allFaqEntries.map((entry) => ({
          '@type': 'Question',
          name: entry.question,
          acceptedAnswer: {
            '@type': 'Answer',
            text: stripInlineMarkup(entry.answer),
          },
        })),
      },
    ],
  };
}
