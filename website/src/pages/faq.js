import clsx from 'clsx';
import Head from '@docusaurus/Head';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import Heading from '@theme/Heading';

import FaqAnswer from '../components/FaqAnswer';
import {engine} from '../data/engine.mjs';
import {allFaqEntries, createFaqStructuredData, faqPageMeta} from '../data/faq.mjs';
import styles from './faq.module.css';

export default function FaqPage() {
  const {siteConfig} = useDocusaurusContext();
  const structuredData = createFaqStructuredData(siteConfig.url, siteConfig.baseUrl);

  return (
    <Layout title={faqPageMeta.title} description={faqPageMeta.description}>
      <Head>
        <script type="application/ld+json">{JSON.stringify(structuredData)}</script>
      </Head>
      <main className={styles.page}>
        <div className={clsx('container', styles.content)}>
          <nav className={styles.breadcrumbs} aria-label="Breadcrumbs">
            <ul className="breadcrumbs">
              <li className="breadcrumbs__item">
                <Link className="breadcrumbs__link" to="/">
                  {engine.name}
                </Link>
              </li>
              <li className="breadcrumbs__item breadcrumbs__item--active">
                <span className="breadcrumbs__link" aria-current="page">
                  FAQ
                </span>
              </li>
            </ul>
          </nav>

          <section aria-labelledby="faq-heading">
            <Heading as="h1" id="faq-heading">
              {faqPageMeta.heading}
            </Heading>
            <p className={styles.lead}>
              Direct answers to common questions about {engine.name}, supported platforms,
              mod compatibility, Lua/Python/HScript scripting and building from source. The
              first eight questions also appear on the <Link to="/#faq">homepage</Link>.
            </p>

            <div className={styles.list}>
              {allFaqEntries.map((entry) => (
                <article key={entry.id} className={styles.item}>
                  <Heading as="h2" id={entry.id}>
                    {entry.question}
                  </Heading>
                  <p>
                    <FaqAnswer text={entry.answer} />
                  </p>
                </article>
              ))}
            </div>
          </section>

          <section className={styles.moreHelp} aria-labelledby="still-stuck">
            <Heading as="h2" id="still-stuck">
              Still stuck?
            </Heading>
            <p>
              Check the <Link to="/docs/getting-started/troubleshooting">troubleshooting guide</Link>,
              read the <Link to="/docs/getting-started/building">build instructions</Link> and{' '}
              <Link to="/docs/modding/overview">modding overview</Link>, or open an issue on the{' '}
              <Link href={`${engine.repositoryUrl}/issues`}>GitHub repository</Link>.
            </p>
          </section>
        </div>
      </main>
    </Layout>
  );
}
