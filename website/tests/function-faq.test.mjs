import {test} from 'node:test';
import assert from 'node:assert/strict';
import {functionFaq, renderFaq} from '../scripts/function-faq.mjs';

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
