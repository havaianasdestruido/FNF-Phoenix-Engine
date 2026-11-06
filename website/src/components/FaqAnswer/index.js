import Link from '@docusaurus/Link';

import {tokenizeInlineMarkup} from '../../data/faq.mjs';

export default function FaqAnswer({text}) {
  return tokenizeInlineMarkup(text).map((token, index) => {
    if (token.type === 'code') {
      return <code key={index}>{token.text}</code>;
    }
    if (token.type === 'link') {
      const isExternal = /^https?:\/\//i.test(token.href);
      return isExternal ? (
        <Link key={index} href={token.href}>
          {token.text}
        </Link>
      ) : (
        <Link key={index} to={token.href}>
          {token.text}
        </Link>
      );
    }
    return token.text;
  });
}
