// Reads an `n8n export:workflow --all` JSON array on stdin and writes one stable file per
// workflow into <outDir>/<id>.json. Drops fields that change on every save or differ per
// instance (timestamps, version ids, ownership, active flags), so a re-export of unchanged
// workflows is byte-identical and CI can diff it against the committed copy.
// Usage: node normalize-workflows.js <outDir> < export.json
const fs = require('fs');
const path = require('path');

const outDir = process.argv[2];
if (!outDir) {
  console.error('usage: node normalize-workflows.js <outDir> < export.json');
  process.exit(2);
}

const KEEP = ['id', 'name', 'nodes', 'connections', 'settings', 'pinData'];

const raw = fs.readFileSync(0, 'utf8');
const start = raw.indexOf('[');
if (start === -1) {
  console.error('normalize-workflows: no JSON array on stdin');
  process.exit(1);
}
const workflows = JSON.parse(raw.slice(start));
fs.mkdirSync(outDir, { recursive: true });

for (const wf of workflows) {
  const stable = {};
  for (const key of KEEP) stable[key] = wf[key] ?? (key === 'pinData' || key === 'settings' ? {} : undefined);
  // Credentials are referenced by id/name only; secrets are never part of an export.
  const file = path.join(outDir, `${wf.id}.json`);
  fs.writeFileSync(file, JSON.stringify(stable, null, 2) + '\n');
  console.log(`exported ${wf.name} -> ${file}`);
}
