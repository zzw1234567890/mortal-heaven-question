const fs = require('fs');
const path = require('path');
function walk(d, o) {
  for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    if (d === '.' && ['node_modules', '.git', 'docs'].includes(e.name)) continue;
    const p = path.join(d, e.name);
    if (e.isDirectory()) walk(p, o);
    else if (e.name.endsWith('.md')) o.push(p.split(path.sep).join('/'));
  }
  return o;
}
const sub = walk('.', []).sort();
const root = fs.readdirSync('.').filter(f => f.endsWith('.md'));
const all = [...new Set([...root, ...sub])]
  .filter(f => !['README.md', 'CONTRIBUTING.md', 'SECURITY.md', 'UPGRADING.md'].includes(f));
console.log('COUNT:' + all.length);
all.forEach(f => console.log(f));
