// Fills ${VAR} placeholders in a credentials template from process.env.
// Usage: node render-credentials.js <template.json> <output.json>
// Values are substituted into the parsed JSON, so quotes/backslashes in secrets can't break it.
const fs = require('fs');

const [templatePath, outputPath] = process.argv.slice(2);
if (!templatePath || !outputPath) {
  console.error('usage: render-credentials.js <template> <output>');
  process.exit(2);
}

const missing = new Set();
const fill = (value) => {
  if (typeof value === 'string') {
    return value.replace(/\$\{([A-Z0-9_]+)\}/g, (_, name) => {
      if (process.env[name] === undefined) missing.add(name);
      return process.env[name] ?? '';
    });
  }
  if (Array.isArray(value)) return value.map(fill);
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, fill(v)]));
  }
  return value;
};

const rendered = fill(JSON.parse(fs.readFileSync(templatePath, 'utf8')));
if (missing.size) {
  console.error(`render-credentials: unset variables: ${[...missing].join(', ')}`);
  process.exit(1);
}
fs.writeFileSync(outputPath, JSON.stringify(rendered), { mode: 0o600 });
