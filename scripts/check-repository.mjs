import { execFileSync } from 'node:child_process';
import { existsSync, lstatSync, readFileSync } from 'node:fs';
import { dirname, isAbsolute, relative, resolve } from 'node:path';

const root = process.cwd();
const files = [...new Set(execFileSync('git', ['ls-files', '--cached', '--others', '--exclude-standard', '-z'], { encoding: 'utf8' }).split('\0').filter(Boolean))];
const errors = [];
const forbidden = /(^|\/)(node_modules|out|cache|broadcast|reports|\.env[^/]*|\.secrets)(\/|$)|\.(pem|key|p12|pfx|sqlite|db)$/i;
const credentials = [/-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/, /gh[pousr]_[A-Za-z0-9]{30,}/, /github_pat_[A-Za-z0-9_]{60,}/];

for (const file of files) {
  if (forbidden.test(file)) errors.push(`${file}: generated/private file must not be tracked`);
  const absolute = resolve(root, file);
  if (!existsSync(absolute)) { errors.push(`${file}: missing working-tree file`); continue; }
  if (lstatSync(absolute).isSymbolicLink()) { errors.push(`${file}: symlink is not allowed in this source export`); continue; }
  const text = readFileSync(absolute, 'utf8');
  if (credentials.some(pattern => pattern.test(text))) errors.push(`${file}: possible credential; inspect privately`);
  if (/[A-Z]:[/\\]Users[/\\][^/\\\s]+/i.test(text)) errors.push(`${file}: local machine path must not be published`);
  if (!file.endsWith('.md')) continue;
  for (const [, raw] of text.matchAll(/\[[^\]]*\]\(([^\s)]+)(?:\s+"[^"]*")?\)/g)) {
    if (/^(https?:|mailto:|#)/.test(raw)) continue;
    const link = decodeURIComponent(raw.split('#')[0]);
    const destination = resolve(dirname(absolute), link);
    const local = relative(root, destination);
    if (isAbsolute(link) || local.startsWith('..') || isAbsolute(local) || !existsSync(destination)) errors.push(`${file}: broken or external local link: ${raw}`);
  }
}
if (errors.length) { console.error(errors.join('\n')); process.exitCode = 1; }
else console.log(`Repository checks passed for ${files.length} source files. Pattern scanning is not an exhaustive secret audit.`);
