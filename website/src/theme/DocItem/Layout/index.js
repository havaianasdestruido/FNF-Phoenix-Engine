import React from 'react';
import Head from '@docusaurus/Head';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import {useDoc} from '@docusaurus/plugin-content-docs/client';
import DocItemLayout from '@theme-original/DocItem/Layout';

// The generated front matter and visible Q&A use the same entries.
export default function LayoutWithFunctionFaq(props) {
  const {frontMatter, metadata} = useDoc();
  const {siteConfig} = useDocusaurusContext();
  const entries = frontMatter.function_faq;
  const pageUrl = new URL(metadata.permalink, siteConfig.url).href;
  const data = Array.isArray(entries) && entries.length ? {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    '@id': `${pageUrl}#faq`,
    mainEntity: entries.map(({question, answer}) => ({
      '@type': 'Question', name: question,
      acceptedAnswer: {'@type': 'Answer', text: answer},
    })),
  } : null;
  return <>
    {data && <Head><script type="application/ld+json">{JSON.stringify(data).replace(/</g, '\\u003c')}</script></Head>}
    <DocItemLayout {...props} />
  </>;
}
