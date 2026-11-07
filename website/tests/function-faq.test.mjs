import {test} from 'node:test';
import assert from 'node:assert/strict';
import {functionFaq, frontmatterFaq, renderFaq} from '../scripts/function-faq.mjs';

test('Q&A uses documented behavior and an explicit Haxe invocation pattern', () => {
  const entries = functionFaq({name: 'load', owner: 'Song', language: 'Haxe', doc: 'Loads a chart.\n@param name Chart name', params: [{name: 'name'}], isStatic: true, conditions: 'MODS_ALLOWED'});
  assert.match(entries[0].answer, /Loads a chart/);
  assert.match(entries[0].answer, /MODS_ALLOWED/);
  assert.match(entries[1].answer, /Song\.load\(name\)/);
  assert.doesNotMatch(entries[0].answer, /@param/);
  assert.ok(renderFaq(entries).join('\n').includes(entries[0].question));
});

test('undocumented script functions do not invent behavior and use placeholders', () => {
  const entries = functionFaq({name: 'doThing', language: 'Lua', params: [{name: 'tag'}]});
  assert.match(entries[0].answer, /does not provide a description/);
  assert.match(entries[1].answer, /doThing\(tag\)/);
  assert.match(entries[1].answer, /Replace the parameter names/);
});

test('constructors and instance methods use appropriate patterns', () => {
  assert.match(functionFaq({name: 'new', owner: 'Thing', language: 'Haxe', params: [], isConstructor: true})[1].answer, /new Thing\(\)/);
  assert.match(functionFaq({name: 'update', owner: 'Thing', language: 'Haxe', params: [{name: 'elapsed'}], isConstructor: false})[1].answer, /instance\.update\(elapsed\)/);
});

test('front matter Q&A survives Windows paths in a doc comment', () => {
  // The MDX loader writes front matter values into a JS object literal without
  // escaping backslashes, so `C:\x` used to break the docs build.
  const doc = 'Whether a path is absolute: C:' + '\\' + 'x, C:/x or a UNC share.';
  const entries = functionFaq({
    name: 'isAbsolute', owner: 'RenderPaths', language: 'Haxe',
    doc, params: [{name: 'path'}], isStatic: true,
  });
  assert.ok(doc.includes('C:' + '\\' + 'x'), 'the sample really has a backslash');

  const frontMatter = frontmatterFaq(entries);
  assert.equal(frontMatter.length, entries.length);
  for (const {question, answer} of frontMatter) {
    assert.ok(!question.includes('\\'), 'front matter questions must not carry backslashes');
    assert.ok(!answer.includes('\\'), 'front matter answers must not carry backslashes');
  }
  assert.match(frontMatter[0].answer, /C:\/x/);
  // The visible Q&A keeps the real separator (escaped for Markdown).
  assert.ok(renderFaq(entries).join('\n').includes('C:' + '\\\\' + 'x'));
});
