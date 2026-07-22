const fs = require('fs');
const lines = fs.readFileSync('tmp_remaining.txt', 'utf8').split('\n').filter(l => l.trim() && !l.startsWith('COUNT:'));
// design/CLAUDE.md already translated in batch 2 — skip
const files = lines.filter(f => f.trim() !== 'design/CLAUDE.md');
const N = 14; // number of batches
const batchDir = 'tmp_batches';
if (!fs.existsSync(batchDir)) fs.mkdirSync(batchDir);
const size = Math.ceil(files.length / N);
let idx = 0;
for (let b = 1; b <= N; b++) {
  const slice = files.slice((b - 1) * size, b * size);
  if (slice.length === 0) continue;
  fs.writeFileSync(`${batchDir}/batch_${String(b).padStart(2, '0')}.txt`, slice.join('\n') + '\n');
  console.log(`batch_${String(b).padStart(2, '0')}.txt: ${slice.length} files`);
}
console.log('TOTAL:', files.length);
