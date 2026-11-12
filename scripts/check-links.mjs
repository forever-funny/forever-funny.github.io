#!/usr/bin/env node
/**
 * Check internal links in a built Hugo site.
 *
 * Usage: node scripts/check-links.mjs [publicDir]
 *
 * Resolves absolute and relative href/src values against the public directory,
 * including "/foo/" -> "foo/index.html", and fails when a target is missing.
 * External URLs, anchors, mailto: and data: URIs are ignored.
 */

import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { join, dirname, extname, relative, resolve, sep } from 'node:path';

const root = resolve(process.argv[2] ?? 'public');
if (!existsSync(root)) {
  console.error(`public directory not found: ${root}`);
  process.exit(1);
}

const files = [];
function walk(dir) {
  for (const name of readdirSync(dir)) {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) walk(path);
    else if (extname(path) === '.html') files.push(path);
  }
}
walk(root);

const ATTR = /\b(?:href|src)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))/gi;
const skip = /^(?:[a-z][a-z0-9+.-]*:|\/\/|#)/i;

function resolveTarget(baseFile, url) {
  const clean = url.split('#')[0].split('?')[0];
  if (!clean) return null;
  let path;
  if (clean.startsWith('/')) path = join(root, decodeURIComponent(clean));
  else path = resolve(dirname(baseFile), decodeURIComponent(clean));

  if (clean.endsWith('/')) path = join(path, 'index.html');
  if (existsSync(path)) return null;
  if (!extname(path) && existsSync(join(path, 'index.html'))) return null;
  return path;
}

const missing = [];
let checked = 0;

for (const file of files) {
  const html = readFileSync(file, 'utf8');
  for (const match of html.matchAll(ATTR)) {
    const url = (match[1] ?? match[2] ?? match[3] ?? '').trim();
    if (!url || skip.test(url)) continue;
    checked += 1;
    const target = resolveTarget(file, url);
    if (target) {
      missing.push({
        page: '/' + relative(root, file).split(sep).join('/'),
        url,
        resolved: relative(root, target).split(sep).join('/'),
      });
    }
  }
}

const unique = new Map();
for (const item of missing) unique.set(`${item.page} -> ${item.url}`, item);

console.log(`checked ${checked} internal links across ${files.length} pages`);
if (unique.size) {
  console.error(`\n${unique.size} broken link(s):`);
  for (const item of [...unique.values()].slice(0, 50)) {
    console.error(`  ${item.page}: ${item.url}  (missing ${item.resolved})`);
  }
  process.exit(1);
}
console.log('no broken internal links');
