import Head from '@docusaurus/Head';
import Link from '@docusaurus/Link';
import useBaseUrl from '@docusaurus/useBaseUrl';
import Layout from '@theme/Layout';
import Heading from '@theme/Heading';

import styles from './play.module.css';

export default function PlayPage() {
  const gameUrl = useBaseUrl('/browser-game/');

  return (
    <Layout
      title="Play in your browser"
      description="Try the Phoenix Engine HTML5 build directly in your browser.">
      <Head>
        <meta name="theme-color" content="#14111b" />
      </Head>
      <main className={styles.page}>
        <div className="container">
          <div className={styles.header}>
            <div>
              <p className={styles.eyebrow}>PHOENIX ENGINE · HTML5</p>
              <Heading as="h1">Play in your browser</Heading>
              <p className={styles.lead}>
                A compact browser build with the Tutorial and Week 1 content. Click inside
                the game to give it keyboard focus and allow audio playback.
              </p>
            </div>
            <a className="button button--primary" href={gameUrl} target="_blank" rel="noreferrer">
              Open game in a new tab
            </a>
          </div>

          <div className={styles.gameFrame}>
            <iframe
              src={gameUrl}
              title="Phoenix Engine HTML5 game"
              allow="autoplay; fullscreen; gamepad"
              allowFullScreen
              loading="eager"
            />
          </div>

          <div className={styles.info}>
            <section>
              <Heading as="h2">Controls</Heading>
              <p>Use the keyboard controls shown in-game. If input does not respond, click once inside the game frame.</p>
            </section>
            <section>
              <Heading as="h2">Browser build limits</Heading>
              <p>
                This is the HTML5 target: Lua, Python and video playback are not included.
                HScript remains available; desktop-only features and user-installed mods
                may differ from native builds.
              </p>
            </section>
          </div>
          <p className={styles.back}><Link to="/docs/getting-started/building">Build and platform details</Link></p>
        </div>
      </main>
    </Layout>
  );
}
