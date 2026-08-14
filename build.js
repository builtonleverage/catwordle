#!/usr/bin/env node
// Injects secrets from environment variables into the static HTML template
// at build time. Locally, loads .env (gitignored) if present; in CI/hosting
// platforms, real env vars set in the dashboard take precedence and .env
// won't exist at all.
const fs = require('fs');
const path = require('path');

function loadDotEnv(file) {
  if (!fs.existsSync(file)) return;
  for (const line of fs.readFileSync(file, 'utf8').split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq === -1) continue;
    const key = trimmed.slice(0, eq).trim();
    const val = trimmed.slice(eq + 1).trim().replace(/^["']|["']$/g, '');
    if (!(key in process.env)) process.env[key] = val;
  }
}

loadDotEnv(path.join(__dirname, '.env'));

const REQUIRED = ['CATWORDLE_API_URL', 'CATWORDLE_API_TOKEN'];
const missing = REQUIRED.filter(k => !process.env[k]);
if (missing.length) {
  console.error('Missing required env vars: ' + missing.join(', '));
  console.error('Set them in .env locally, or in your hosting platform\'s environment variable settings.');
  process.exit(1);
}

const templatePath = path.join(__dirname, 'src', 'index.template.html');
const outDir = path.join(__dirname, 'dist');
const outPath = path.join(outDir, 'index.html');

let html = fs.readFileSync(templatePath, 'utf8');
html = html.split('__CATWORDLE_API_URL__').join(process.env.CATWORDLE_API_URL);
html = html.split('__CATWORDLE_API_TOKEN__').join(process.env.CATWORDLE_API_TOKEN);

if (html.includes('__CATWORDLE_')) {
  console.error('Unreplaced placeholder remains in output — check src/index.template.html');
  process.exit(1);
}

fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(outPath, html);
console.log('Built ' + outPath);
