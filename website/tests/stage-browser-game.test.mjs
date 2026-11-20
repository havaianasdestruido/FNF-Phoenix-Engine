import assert from 'node:assert/strict';
import {cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync} from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {test} from 'node:test';

const script = fileURLToPath(new URL('../scripts/stage-browser-game.mjs', import.meta.url));

function fixture(t) {
  const root = mkdtempSync(path.join(os.tmpdir(), 'phoenix-stage-game-'));
  t.after(() => rmSync(root, {recursive: true, force: true}));
  const scriptDir = path.join(root, 'website', 'scripts');
  const source = path.join(root, 'build', 'release', 'html5', 'bin');
  const destination = path.join(root, 'website', 'static', 'browser-game');
  mkdirSync(scriptDir, {recursive: true});
  mkdirSync(destination, {recursive: true});
  cpSync(script, path.join(scriptDir, 'stage-browser-game.mjs'));
  writeFileSync(path.join(destination, 'index.html'), 'existing placeholder');
  const run = () => spawnSync(process.execPath, [path.join(scriptDir, 'stage-browser-game.mjs')], {encoding: 'utf8'});
  return {source, destination, run};
}

test('stages the release HTML5 output and replaces the placeholder', (t) => {
  const {source, destination, run} = fixture(t);
  mkdirSync(path.join(source, 'assets'), {recursive: true});
  writeFileSync(path.join(source, 'index.html'), 'game');
  writeFileSync(path.join(source, 'Phoenix.js'), 'bundle');
  writeFileSync(path.join(source, 'assets', 'example.txt'), 'asset');
  writeFileSync(path.join(destination, 'old.txt'), 'stale');
  const result = run();
  assert.equal(result.status, 0, result.stderr);
  assert.equal(readFileSync(path.join(destination, 'index.html'), 'utf8'), 'game');
  assert.equal(readFileSync(path.join(destination, 'Phoenix.js'), 'utf8'), 'bundle');
  assert.equal(readFileSync(path.join(destination, 'assets', 'example.txt'), 'utf8'), 'asset');
  assert.equal(existsSync(path.join(destination, 'old.txt')), false);
});

test('a missing or incomplete build fails without replacing the placeholder', (t) => {
  const {source, destination, run} = fixture(t);
  let result = run();
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /HTML5 build output not found/);
  assert.equal(readFileSync(path.join(destination, 'index.html'), 'utf8'), 'existing placeholder');
  mkdirSync(source, {recursive: true});
  writeFileSync(path.join(source, 'index.html'), 'game');
  result = run();
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /expected index.html and a JavaScript bundle/);
  assert.equal(readFileSync(path.join(destination, 'index.html'), 'utf8'), 'existing placeholder');
});
