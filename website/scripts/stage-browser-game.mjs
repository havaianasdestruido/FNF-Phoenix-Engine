#!/usr/bin/env node

/**
 * Copy Lime's HTML5 output into Docusaurus' static directory so the game is
 * deployed on the same GitHub Pages origin as the documentation.
 */
import {cp, mkdir, readdir, rm} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(scriptDir, '../..');
// project.hxp sets app.path to build/release/ for the non-debug CI build;
// Lime appends html5/bin to that path.
const source = path.join(repoRoot, 'build', 'release', 'html5', 'bin');
const destination = path.join(scriptDir, '..', 'static', 'browser-game');

async function exists(file) {
  try {
    await readdir(file);
    return true;
  } catch {
    return false;
  }
}

if (!(await exists(source))) {
  throw new Error(`HTML5 build output not found at ${source}. Build with: haxelib run lime build html5`);
}

const outputFiles = await readdir(source);
if (!outputFiles.includes('index.html') || !outputFiles.some((file) => file.endsWith('.js'))) {
  throw new Error(`Unexpected Lime HTML5 output in ${source}: expected index.html and a JavaScript bundle.`);
}

await rm(destination, {recursive: true, force: true});
await mkdir(destination, {recursive: true});
await cp(source, destination, {recursive: true});

console.log(`Staged ${outputFiles.length} HTML5 output entries into ${path.relative(repoRoot, destination)}.`);
