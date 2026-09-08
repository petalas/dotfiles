// Plan updates from the CLI lock, without writing it or installing anything.
// Output is TSV consumed by install_ai_skills.sh; diagnostics go to stderr.
import { spawnSync } from 'node:child_process';
import { readFileSync, statSync, mkdtempSync, rmSync, readdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { tmpdir } from 'node:os';
import { join, posix } from 'node:path';

const maxBytes = 32 * 1024 * 1024;
const shaPattern = /^[a-f0-9]{40}$/i;
const safeField = (value) => typeof value === 'string' && value.length > 0 && !/[\x00-\x1f\x7f]/.test(value);

function command(program, args) {
  const result = spawnSync(program, args, {
    encoding: 'utf8', timeout: 60_000, maxBuffer: maxBytes,
    env: { ...process.env, GIT_TERMINAL_PROMPT: '0' },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  if (result.error || result.status !== 0) throw new Error(`${program} lookup failed`);
  return result.stdout;
}

function readLock(path) {
  try {
    if (statSync(path).size > maxBytes) throw new Error('Skill lock exceeds 32 MiB');
    const lock = JSON.parse(readFileSync(path, 'utf8'));
    if (!lock || typeof lock.skills !== 'object' || !lock.skills || Array.isArray(lock.skills)) {
      throw new Error('Invalid skill lock: expected skills object');
    }
    const entries = Object.entries(lock.skills);
    if (entries.length > 10_000) throw new Error('Skill lock exceeds 10000 skills');
    for (const [name, entry] of entries) {
      if (!safeField(name) || name.startsWith('-') || !entry || typeof entry !== 'object') {
        throw new Error('Invalid skill lock entry');
      }
    }
    return entries;
  } catch (error) {
    if (error.code === 'ENOENT') return [];
    throw error;
  }
}

function githubEntry(entry) {
  return entry.sourceType === 'github' &&
    typeof entry.source === 'string' && /^[A-Za-z0-9][\w.-]*\/[A-Za-z0-9][\w.-]*$/.test(entry.source) &&
    (entry.ref === undefined || safeField(entry.ref) && /^[A-Za-z0-9][\w./-]*$/.test(entry.ref)) &&
    safeField(entry.skillPath) && !entry.skillPath.split('/').includes('..') &&
    /^[a-f0-9]{40}([a-f0-9]{24})?$/i.test(entry.skillFolderHash);
}

// The CLI records SHA-256 content hashes when installation falls back to Git.
// Match its path ordering and exclusions instead of comparing these with SHA-1.
function contentHash(directory) {
  const pending = [''];
  const files = [];
  let count = 0;
  let bytes = 0;
  for (let index = 0; index < pending.length; index++) {
    for (const entry of readdirSync(join(directory, pending[index]), { withFileTypes: true })) {
      if (++count > 200_000) throw new Error('Skill folder exceeds 200000 entries');
      const path = posix.join(pending[index], entry.name);
      if (entry.isDirectory() && !['.git', 'node_modules'].includes(entry.name)) pending.push(path);
      else if (entry.isFile()) files.push(path);
    }
  }
  files.sort((a, b) => a.localeCompare(b));
  const hash = createHash('sha256');
  for (const path of files) {
    bytes += statSync(join(directory, path)).size;
    if (bytes > maxBytes) throw new Error('Skill folder exceeds 32 MiB');
    hash.update(path);
    hash.update(readFileSync(join(directory, path)));
  }
  return hash.digest('hex');
}

function gitTree(source, ref, contentPaths = []) {
  const directory = mkdtempSync(join(tmpdir(), 'dotfiles-skill-tree-'));
  try {
    command('git', ['init', '--quiet', directory]);
    command('git', ['-C', directory, 'fetch', '--quiet', '--depth=1',
      `https://github.com/${source}.git`, ref ?? 'HEAD']);
    const sha = command('git', ['-C', directory, 'rev-parse', 'FETCH_HEAD^{tree}']).trim();
    const output = command('git', ['-C', directory, 'ls-tree', '-r', '-t', '-z', 'FETCH_HEAD']);
    const tree = output.split('\0').filter(Boolean).map((line) => {
      const [metadata, path] = [line.slice(0, line.indexOf('\t')), line.slice(line.indexOf('\t') + 1)];
      const [, type, objectSha] = metadata.split(' ');
      return { type, sha: objectSha, path };
    });
    const hashes = new Map();
    if (contentPaths.length) {
      command('git', ['-C', directory, 'checkout', '--quiet', 'FETCH_HEAD', '--', '.']);
      for (const path of contentPaths) {
        if (tree.some((item) => item.path === path && item.type === 'blob')) {
          hashes.set(path, contentHash(join(directory, posix.dirname(path))));
        }
      }
    }
    return { sha, tree, truncated: false, hashes };
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
}

function sourceTree(source, ref, contentPaths) {
  if (contentPaths.length) return gitTree(source, ref, contentPaths);
  let tree;
  try {
    tree = JSON.parse(command('gh', ['api', '--hostname', 'github.com',
      `repos/${source}/git/trees/${encodeURIComponent(ref ?? 'HEAD')}?recursive=1`]));
    if (tree.truncated) throw new Error('Truncated GitHub tree');
  } catch {
    console.error(`:: checking ${source} via Git`);
    tree = gitTree(source, ref);
  }
  if (!shaPattern.test(tree.sha) || !Array.isArray(tree.tree) || tree.tree.length > 200_000 ||
      !tree.tree.every((item) => safeField(item.path) && shaPattern.test(item.sha) &&
        ['tree', 'blob', 'commit'].includes(item.type))) {
    throw new Error('Invalid repository tree');
  }
  return tree;
}

function checkSource(source, ref, items) {
  console.error(`:: checking global skills from ${source}${ref ? `#${ref}` : ''}`);
  const contentPaths = items.filter(([, entry]) => entry.skillFolderHash.length === 64)
    .map(([, entry]) => entry.skillPath);
  const tree = sourceTree(source, ref, contentPaths);
  const paths = new Map(tree.tree.map((item) => [item.path, item]));
  const changed = [];
  const fallback = [];
  for (const [name, entry] of items) {
    const folder = posix.dirname(entry.skillPath);
    const hash = entry.skillFolderHash.length === 64 ? tree.hashes?.get(entry.skillPath) :
      folder === '.' ? tree.sha : paths.get(folder)?.sha;
    // Let the CLI handle moved/deleted paths and names. Never guess a new path.
    if (paths.get(entry.skillPath)?.type !== 'blob' || !hash) fallback.push(name);
    else if (hash !== entry.skillFolderHash) changed.push(name);
  }
  if (changed.length) {
    console.error(`:: ${changed.length} changed skill(s): ${changed.join(', ')}`);
    console.log(['batch', `${source}${ref ? `#${ref}` : ''}`, ...changed].join('\t'));
  } else console.error(`:: no changed skill folders in ${source}`);
  return fallback;
}

function main(path) {
  if (!path) throw new Error('Usage: ai-skill-updates.mjs LOCK');
  const groups = new Map();
  const fallback = [];
  for (const item of readLock(path)) {
    const [name, entry] = item;
    if (!githubEntry(entry)) { fallback.push(name); continue; }
    const key = JSON.stringify([entry.source, entry.ref]);
    if (!groups.has(key)) groups.set(key, { source: entry.source, ref: entry.ref, items: [] });
    groups.get(key).items.push(item);
  }
  for (const { source, ref, items } of groups.values()) {
    try { fallback.push(...checkSource(source, ref, items)); }
    catch (error) {
      console.error(`Failed to check ${source}: ${error.message}`);
      process.exitCode = 1;
    }
  }
  if (fallback.length) {
    console.error(`:: CLI fallback required for: ${fallback.join(', ')}`);
    console.log(['fallback', ...fallback].join('\t'));
  }
}

try { main(process.argv[2]); }
catch (error) { console.error(error.message); process.exitCode = 1; }
