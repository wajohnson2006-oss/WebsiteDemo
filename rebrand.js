/**
 * rebrand.js
 * Usage:
 *   node rebrand.js            — read template.html + config.json → write index.html
 *   node rebrand.js --init     — read index.html + config.json → write template.html
 */

import fs   from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = __dirname;

// ── helpers ────────────────────────────────────────────────────────────────

/** Recursively flatten { a: { b: "v" } } → { "a.b": "v" } */
function flatten(obj, prefix = '') {
  const out = {};
  for (const [k, v] of Object.entries(obj)) {
    const key = prefix ? `${prefix}.${k}` : k;
    if (v !== null && typeof v === 'object' && !Array.isArray(v)) {
      Object.assign(out, flatten(v, key));
    } else {
      out[key] = String(v);
    }
  }
  return out;
}

/** Escape a string for use in a RegExp */
function escapeRE(str) {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

// ── load config ────────────────────────────────────────────────────────────

const configPath = path.join(root, 'config.json');
if (!fs.existsSync(configPath)) {
  console.error('Error: config.json not found.');
  process.exit(1);
}
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const tokens = flatten(config);   // e.g. { "company.name": "Artisan", ... }

// ── --init : generate template.html from index.html ───────────────────────

if (process.argv.includes('--init')) {
  const srcPath = path.join(root, 'index.html');
  if (!fs.existsSync(srcPath)) {
    console.error('Error: index.html not found. Cannot generate template.');
    process.exit(1);
  }

  let tmpl = fs.readFileSync(srcPath, 'utf8');

  // Sort by value length DESCENDING so longer strings are replaced first
  // (prevents "Steel Roofing" from being tokenised before "Artisan Steel Roofing")
  const sortedTokens = Object.entries(tokens).sort(
    ([, a], [, b]) => b.length - a.length
  );

  for (const [key, value] of sortedTokens) {
    if (value.trim() === '') continue;          // skip blank values
    tmpl = tmpl.replaceAll(value, `{{${key}}}`);
  }

  // Warn about any config value that appears zero times (may already be wrong)
  for (const [key, value] of sortedTokens) {
    if (value.trim() === '') continue;
    if (!fs.readFileSync(srcPath, 'utf8').includes(value)) {
      console.warn(`  ⚠  config key "${key}" value "${value}" not found in index.html`);
    }
  }

  const outPath = path.join(root, 'template.html');
  fs.writeFileSync(outPath, tmpl, 'utf8');
  console.log(`✓  template.html written (${tmpl.length} bytes)`);
  console.log('   Edit config.json then run: node rebrand.js');
  process.exit(0);
}

// ── main : apply config to template.html → index.html ────────────────────

const tmplPath = path.join(root, 'template.html');
if (!fs.existsSync(tmplPath)) {
  console.error(
    'Error: template.html not found.\n' +
    'Run  node rebrand.js --init  first to generate it from the current index.html.'
  );
  process.exit(1);
}

let html = fs.readFileSync(tmplPath, 'utf8');

for (const [key, value] of Object.entries(tokens)) {
  const re = new RegExp(`\\{\\{${escapeRE(key)}\\}\\}`, 'g');
  html = html.replace(re, value);
}

// Report any tokens left unreplaced
const leftovers = [...new Set((html.match(/\{\{[^}]+\}\}/g) || []))];
if (leftovers.length) {
  console.warn('  ⚠  Unreplaced tokens:', leftovers.join(', '));
}

fs.writeFileSync(path.join(root, 'index.html'), html, 'utf8');
console.log(`✓  index.html written from template.html + config.json`);
