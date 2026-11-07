/** Shared source for visible function Q&As and their FAQPage metadata. */
// Verified against the shared Lua/Python callback implementations.
const scriptExamples = {
  addScore: ['Adds to the song score and recalculates the rating.', 'addScore(100)'],
  setHealth: ['Sets the current health value.', 'setHealth(1)'],
  addHealth: ['Adds to the current health value.', 'addHealth(0.1)'],
  getHealth: ['Returns the current health value.', 'getHealth()'],
  debugPrint: ['Prints values to the script debug output.', 'debugPrint("Hello from a mod")'],
};
function plain(text) {
  return String(text || '').replace(/\s+/g, ' ').replace(/`/g, '').trim();
}

export function functionFaq({name, owner, language, doc, params, isStatic, isConstructor, conditions, group}) {
  const qualified = owner ? `${owner}.${name}` : name;
  const subject = `${qualified} in ${language}`;
  const example = !owner && scriptExamples[name];
  const description = plain(example?.[0] || doc).split(/\s+@(?:param|return|throws)\b/)[0].trim();
  const purpose = description
    ? `${description}${conditions ? ` Availability: ${conditions}.` : ''}`
    : `This is a ${group ? `${group.toLowerCase()} ` : ''}${language} function. The source does not provide a description for ${subject}; consult the linked implementation for its behavior${conditions ? ` and availability (${conditions})` : ''}.`;
  const args = params.map((p) => p.name).join(', ');
  let call = `${name}(${args})`;
  if (owner) call = isConstructor ? `new ${owner}(${args})` : `${isStatic ? owner : 'instance'}.${name}(${args})`;
  const usage = example ? `Example: ${example[1]}. See the signature and source for details.` : `Invocation pattern: ${call}. ${params.length ? 'Replace the parameter names with suitable values; see the signature and source for types and defaults.' : 'This call takes no declared parameters; see the signature and source for details.'}${owner && !isStatic && !isConstructor ? ` Here, instance is an existing ${owner} object.` : ''}`;
  return [
    {question: `What does ${subject} do?`, answer: purpose},
    {question: `How do I use ${subject}?`, answer: usage},
  ];
}

// Plain text in Markdown: prevent source comments from introducing markup or HTML.
function escapeMarkdown(text) {
  return text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/([\\`*_\[\]#])/g, '\\$1').replace(/\{/g, '&#123;').replace(/\}/g, '&#125;');
}

// Front matter ends up as a JavaScript object literal in the MDX module, and the
// loader that writes it does not escape backslashes: an answer containing
// `C:\x` is emitted as 'C:\x' and fails the build with "Bad character escape
// sequence". The copy used for metadata therefore only carries portable
// separators; the visible Q&A (renderFaq) keeps the original text.
export function frontmatterFaq(entries) {
  const portable = (text) => String(text || '').replace(/\\/g, '/');
  return entries.map(({question, answer}) => ({question: portable(question), answer: portable(answer)}));
}

export function renderFaq(entries) {
  if (!entries.length) return [];
  const lines = ['## Function questions and answers', ''];
  for (const {question, answer} of entries) {
    lines.push(`### ${escapeMarkdown(question)}`, '', escapeMarkdown(answer), '');
  }
  return lines;
}
