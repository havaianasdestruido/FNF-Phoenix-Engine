import clsx from 'clsx';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import Heading from '@theme/Heading';

import styles from './index.module.css';

const sections = [
  {
    title: 'Getting started',
    to: '/docs/getting-started/requirements',
    body: 'Install the Haxe toolchain, run the setup scripts and compile for Windows, Linux, macOS, Android, iOS, HTML5, Neko or Flash.',
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
          Codebase documentation for the Friday Night Funkin&apos; Phoenix Engine —
          a Haxe/HaxeFlixel engine built for weak devices and easy modding.
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
            href="https://github.com/havaianasdestruido/FNF-Phoenix-Engine">
            GitHub
          </Link>
        </div>
      </div>
    </header>
  );
}

export default function Home() {
  return (
    <Layout
      title="Documentation"
      description="Full codebase documentation for the FNF Phoenix Engine: building, architecture, subsystems, modding and a generated Haxe code reference.">
      <HomepageHeader />
      <main>
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
