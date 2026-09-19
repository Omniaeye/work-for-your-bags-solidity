import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { resolve, dirname } from 'node:path';
import { prepareRound } from './settlement.mjs';

const [inputPath, outputPath] = process.argv.slice(2);
if (!inputPath || !outputPath) throw new Error('Usage: npm run prepare -- input.json reports/round.json');
const bundle = prepareRound(JSON.parse(await readFile(resolve(inputPath), 'utf8')));
await mkdir(dirname(resolve(outputPath)), { recursive: true });
await writeFile(resolve(outputPath), JSON.stringify(bundle, null, 2) + '\n', { flag: 'wx', mode: 0o600 });
console.log(JSON.stringify({ status: bundle.manifest ? 'awaiting_human_review' : 'carryover', roundId: bundle.manifest?.roundId, manifestHash: bundle.manifestHash, carryover: bundle.carryover, transactionsSent: 0, containsPrivateEvidence: true }));
