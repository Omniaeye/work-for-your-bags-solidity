import { readFile } from 'node:fs/promises';
import { verifyPrepared } from './settlement.mjs';
const [inputPath, bundlePath] = process.argv.slice(2);
if (!inputPath || !bundlePath) throw new Error('Usage: npm run verify -- input.json reports/round.json');
verifyPrepared(JSON.parse(await readFile(inputPath, 'utf8')), JSON.parse(await readFile(bundlePath, 'utf8')));
console.log('Verified against supplied frozen evidence. Human review still required. No transactions sent.');
