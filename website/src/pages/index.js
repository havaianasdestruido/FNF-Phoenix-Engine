import clsx from 'clsx';
import Head from '@docusaurus/Head';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import Heading from '@theme/Heading';

import {engine, platformGroups, createEngineStructuredData} from '../data/engine.mjs';
import styles from './index.module.css';

const sections = [
  {
    title: 'Getting started',
    to: '/docs/getting-started/requirements',
    body: 'Install the Haxe toolchain, run the setup scripts and compile for Windows, Linux, macOS, Android, iOS, HTML5, Neko, Flash or AIR.',
  },
  {
    title: 'Architecture',
    to: '/docs/architecture/overview',
    body: 'The layers of the engine: boot sequence, state flow, asset resolution, the Conductor, preferences and the platform layer.',
  },
  {
    title: 'Subsystems',
    to: '/docs/subsystems/playstate',
    body: 'Gameplay, charts, characters and stages, shaders, options, editors, audio, mobile, debugging and deep links.',
  },
  {
    title: 'Modding',
    to: '/docs/modding/overview',
    body: 'Mod folder layout, Lua and Python scripting, HScript, every script hook, custom events and notetypes.',
  },
  {
    title: 'Code reference',
    to: '/docs/reference',
    body: 'Every Haxe type under source/, generated from the sources — fields, signatures, compile-time flags and links to GitHub.',
  },
  {
    title: 'Contributing',
    to: '/docs/contributing/workflow',
    body: 'Workflow, code style, the CI build matrix and how to keep this documentation in sync with the code.',
  },
];

const stats = [
  {value: '284', label: 'Haxe modules'},
  {value: '391', label: 'documented types'},
  {value: '233', label: 'Lua functions'},
  {value: '128', label: 'Python functions'},
];

function HomepageHeader() {
  const {siteConfig} = useDocusaurusContext();
  return (
    <header className={clsx('hero', styles.heroBanner)}>
      <div className="container">
        <Heading as="h1" className="hero__title">
          {siteConfig.title}
        </Heading>
        <p className="hero__subtitle">
          A free, open-source Friday Night Funkin&apos; engine built on Haxe/HaxeFlixel
          for low-end devices and easy modding with Lua, Python and HScript.
          Explore the codebase, build guides and generated API reference.
        </p>
        <div className={styles.buttons}>
          <Link className="button button--primary button--lg" to="/docs/intro">
            Read the docs
          </Link>
          <Link className="button button--secondary button--lg" to="/docs/reference">
            Code reference
          </Link>
          <Link
            className="button button--secondary button--lg"
            href={engine.repositoryUrl}>
            GitHub
          </Link>
        </div>
      </div>
    </header>
  );
}

function EnginePlatforms() {
  return (
    <section className={styles.platforms} aria-labelledby="engine-platforms">
      <div className="container">
        <Heading as="h2" id="engine-platforms">
          One engine, multiple platforms
        </Heading>
        <p>
          Phoenix targets desktop, mobile and the web, alongside additional runtimes.
          These are compilation targets; build requirements and available features vary.
        </p>
        <div className={styles.platformGrid}>
          {platformGroups.map((group) => (
            <div key={group.label} className={styles.platformGroup}>
              <Heading as="h3">{group.label}</Heading>
              <ul className={styles.platformList}>
                {group.targets.map((target) => (
                  <li key={target}>{target}</li>
                ))}
              </ul>
            </div>
          ))}
        </div>
        <p className={styles.platformNote}>
          Scripting support varies by target: HTML5 supports HScript, but not Lua,
          Python or video. Feature flags can further change what a build includes.{' '}
          <Link to="/docs/architecture/platform-layer">Explore the platform layer</Link> or{' '}
          <Link to="/docs/getting-started/building">read the build instructions</Link>.
        </p>
      </div>
    </section>
  );
}

export default function Home() {
  const {siteConfig} = useDocusaurusContext();
  const structuredData = createEngineStructuredData(siteConfig.url, siteConfig.baseUrl);

  return (
    <Layout
      title="Engine and platforms"
      description="Phoenix Engine is a free, open-source Friday Night Funkin' engine for Windows, Linux, macOS, Android, iOS and HTML5, with documentation, build guides and modding APIs.">
      <Head>
        <script type="application/ld+json">{JSON.stringify(structuredData)}</script>
      </Head>
      <HomepageHeader />
      <main>
        <EnginePlatforms />
        <section className={styles.stats}>
          <div className="container">
            <div className="row">
              {stats.map((stat) => (
                <div key={stat.label} className="col col--3">
                  <div className={styles.stat}>
                    <div className={styles.statValue}>{stat.value}</div>
                    <div className={styles.statLabel}>{stat.label}</div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </section>

        <section className={styles.sections}>
          <div className="container">
            <div className="row">
              {sections.map((section) => (
                <div key={section.title} className="col col--4 margin-bottom--lg">
                  <Link className={styles.card} to={section.to}>
                    <Heading as="h3">{section.title}</Heading>
                    <p>{section.body}</p>
                  </Link>
                </div>
              ))}
            </div>
          </div>
        </section>
      </main>
    </Layout>
  );
}
