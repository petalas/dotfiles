import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { chmodSync, lstatSync, mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

const root = fileURLToPath(new URL('../', import.meta.url));
const oldHash = '1'.repeat(40);
const newHash = '2'.repeat(40);
const entry = (name, source = 'owner/repo', extra = {}) => ({
  sourceType: 'github', source, skillPath: `skills/${name}/SKILL.md`,
  skillFolderHash: oldHash, ...extra,
});
const tree = (names) => ({
  sha: '3'.repeat(40), truncated: false,
  tree: Object.entries(names).flatMap(([name, sha]) => [
    { path: `skills/${name}`, type: 'tree', sha },
    { path: `skills/${name}/SKILL.md`, type: 'blob', sha: oldHash },
  ]),
});
const request = (source = 'owner/repo', ref = 'HEAD') =>
  `repos/${source}/git/trees/${encodeURIComponent(ref)}?recursive=1`;
const add = (source, ...names) => ['--yes', 'skills', 'add', source, '--skill', ...names,
  '--full-depth', '--global', '--agent', 'claude-code', 'codex', 'pi', 'universal', '--yes'];

function fixture(t, skills, trees = {}, failSources = []) {
  const home = mkdtempSync(join(tmpdir(), 'test-ai-skill-updates-'));
  t.after(() => rmSync(home, { recursive: true, force: true }));
  const bin = join(home, 'bin');
  mkdirSync(bin);
  mkdirSync(join(home, '.agents'));
  const lock = join(home, '.agents/.skill-lock.json');
  writeFileSync(lock, JSON.stringify({ version: 3, skills }));
  const config = join(home, 'fixtures.json');
  writeFileSync(config, JSON.stringify({ trees, failSources }));
  const log = join(home, 'commands.jsonl');
  writeFileSync(log, '');
  const stub = `#!${process.execPath}
import { readFileSync, appendFileSync } from 'node:fs';
import { basename } from 'node:path';
const command = basename(process.argv[1]);
const args = process.argv.slice(2);
const config = JSON.parse(readFileSync(process.env.FIXTURE_CONFIG, 'utf8'));
appendFileSync(process.env.FIXTURE_LOG, JSON.stringify({ command, args }) + '\\n');
if (command === 'gh') {
  const value = config.trees[args.at(-1)];
  if (!value) process.exit(1);
  process.stdout.write(JSON.stringify(value));
} else if (command === 'git') {
  process.stderr.write('fixture git lookup unavailable\\n');
  process.exit(1);
} else if (command === 'npx') {
  if (config.failSources.includes(args[3])) process.exit(1);
} else process.exit(99);
`;
  for (const command of ['gh', 'git', 'npx']) {
    const path = join(bin, command);
    writeFileSync(path, stub);
    chmodSync(path, 0o755);
  }
  symlinkSync(process.execPath, join(bin, 'node'));
  const env = { HOME: home, PATH: `${bin}:/usr/bin:/bin`, TMPDIR: home,
    FIXTURE_CONFIG: config, FIXTURE_LOG: log };
  return {
    home, lock,
    run(check = false) {
      const result = spawnSync('/bin/bash', [join(root, 'tools/update-ai-skills'), ...(check ? ['--check'] : [])],
        { env, encoding: 'utf8', timeout: 20_000, maxBuffer: 1024 * 1024 });
      assert.ifError(result.error);
      return result;
    },
    plan() {
      const result = spawnSync(process.execPath, [join(root, 'lib/ai-skill-updates.mjs'), lock],
        { env, encoding: 'utf8', timeout: 20_000, maxBuffer: 1024 * 1024 });
      assert.ifError(result.error);
      return result;
    },
    commands(command) {
      return readFileSync(log, 'utf8').split('\n').filter(Boolean).map(JSON.parse)
        .filter((item) => item.command === command).map((item) => item.args);
    },
  };
}

test('unchanged folders require no installs and one source lookup', (t) => {
  const f = fixture(t, { alpha: entry('alpha'), beta: entry('beta') },
    { [request()]: tree({ alpha: oldHash, beta: oldHash }) });
  const result = f.run();
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stderr, /no changed skill folders in owner\/repo/);
  assert.deepEqual(f.commands('npx'), []);
  assert.deepEqual(f.commands('gh'), [['api', '--hostname', 'github.com', request()]]);
});

test('changed installed skills form one batch including names outside the catalog', (t) => {
  const f = fixture(t, { alpha: entry('alpha'), 'private-extra': entry('private-extra'), beta: entry('beta') },
    { [request()]: tree({ alpha: newHash, 'private-extra': newHash, beta: oldHash }) });
  const result = f.run();
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(f.commands('npx'), [add('owner/repo', 'alpha', 'private-extra')]);
});

test('planner emits separate batches for distinct refs of the same source', (t) => {
  const f = fixture(t, { alpha: entry('alpha'), beta: entry('beta', 'owner/repo', { ref: 'release/v2' }) },
    { [request()]: tree({ alpha: newHash }), [request('owner/repo', 'release/v2')]: tree({ beta: newHash }) });
  const result = f.plan();
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, 'batch\towner/repo\talpha\nbatch\towner/repo#release/v2\tbeta\n');
  assert.deepEqual(f.commands('npx'), []);
  const update = f.run();
  assert.equal(update.status, 0, update.stderr);
  assert.deepEqual(f.commands('npx'), [add('owner/repo', 'alpha'), add('owner/repo#release/v2', 'beta')]);
});

test('--check prints the update plan without invoking installs or changing the lock', (t) => {
  const f = fixture(t, { alpha: entry('alpha') }, { [request()]: tree({ alpha: newHash }) });
  const before = readFileSync(f.lock, 'utf8');
  const result = f.run(true);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, 'batch owner/repo alpha\n');
  assert.deepEqual(f.commands('npx'), []);
  assert.equal(readFileSync(f.lock, 'utf8'), before);
});

test('source lookup failures fail the command while other sources still update', (t) => {
  const f = fixture(t, { broken: entry('broken', 'owner/broken'), alpha: entry('alpha') },
    { [request()]: tree({ alpha: newHash }) });
  const result = f.run();
  assert.equal(result.status, 1);
  assert.match(result.stderr, /Failed to check owner\/broken: git lookup failed/);
  assert.deepEqual(f.commands('npx'), [add('owner/repo', 'alpha')]);
  assert.equal(f.commands('git').length, 1);
});

test('unsupported sources and moved paths use CLI fallback scoped to their names', (t) => {
  const f = fixture(t, { remote: { sourceType: 'git', source: 'https://example.invalid/repo' },
    moved: entry('moved'), alpha: entry('alpha') }, { [request()]: tree({ alpha: newHash }) });
  const result = f.run();
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(f.commands('npx'), [add('owner/repo', 'alpha'),
    ['--yes', 'skills', 'update', '--global', 'remote', 'moved']]);
});

test('malformed lock data fails before any lookup or installation', (t) => {
  const f = fixture(t, {});
  writeFileSync(f.lock, '{"skills":[]}');
  const result = f.run();
  assert.equal(result.status, 1);
  assert.match(result.stderr, /Invalid skill lock: expected skills object/);
  assert.deepEqual(f.commands('gh'), []);
  assert.deepEqual(f.commands('npx'), []);
});

test('a failed CLI batch does not skip a subsequent source', (t) => {
  const f = fixture(t, { alpha: entry('alpha'), beta: entry('beta', 'owner/second') },
    { [request()]: tree({ alpha: newHash }), [request('owner/second')]: tree({ beta: newHash }) }, ['owner/repo']);
  const result = f.run();
  assert.equal(result.status, 1);
  assert.deepEqual(f.commands('npx'), [add('owner/repo', 'alpha'), add('owner/second', 'beta')]);
});

test('check preserves stale links; update prunes them even after an install failure', (t) => {
  const f = fixture(t, { alpha: entry('alpha') }, { [request()]: tree({ alpha: newHash }) }, ['owner/repo']);
  const agentRoot = join(f.home, '.claude/skills');
  mkdirSync(agentRoot, { recursive: true });
  const stale = join(agentRoot, 'stale');
  const unrelated = join(agentRoot, 'unrelated');
  symlinkSync(join(f.home, '.agents/skills/stale'), stale);
  symlinkSync(join(f.home, 'other-missing'), unrelated);
  assert.equal(f.run(true).status, 0);
  assert.equal(lstatSync(stale).isSymbolicLink(), true);
  const result = f.run();
  assert.equal(result.status, 1);
  assert.match(result.stdout, /removing stale claude-code skill link: stale/);
  assert.throws(() => lstatSync(stale), { code: 'ENOENT' });
  assert.equal(lstatSync(unrelated).isSymbolicLink(), true);
});

// Only fetches for the fixture source are redirected to this local repository.
// Any other remote fails before Git runs, so these tests cannot use the network.
function localRepository(f) {
  const repository = join(f.home, 'upstream');
  mkdirSync(repository);
  const git = (...args) => {
    const result = spawnSync('/usr/bin/git', ['-C', repository, ...args], {
      env: { HOME: f.home, PATH: '/usr/bin:/bin', GIT_CONFIG_NOSYSTEM: '1' },
      encoding: 'utf8', timeout: 10_000, maxBuffer: 1024 * 1024,
    });
    assert.ifError(result.error);
    assert.equal(result.status, 0, result.stderr);
    return result.stdout.trim();
  };
  git('init', '--quiet');
  const shim = `#!${process.execPath}
import { spawnSync } from 'node:child_process';
import { appendFileSync } from 'node:fs';
const args = process.argv.slice(2);
appendFileSync(process.env.FIXTURE_LOG, JSON.stringify({ command: 'git', args }) + '\\n');
if (args.includes('fetch')) {
  const index = args.indexOf('https://github.com/owner/repo.git');
  if (index < 0) process.exit(99);
  args[index] = ${JSON.stringify(repository)};
}
const result = spawnSync('/usr/bin/git', args, {
  env: { ...process.env, GIT_CONFIG_NOSYSTEM: '1' }, encoding: 'utf8', timeout: 10000,
  maxBuffer: 1024 * 1024,
});
if (result.error) throw result.error;
process.stdout.write(result.stdout);
process.stderr.write(result.stderr);
process.exit(result.status ?? 1);
`;
  writeFileSync(join(f.home, 'bin/git'), shim);
  return {
    path: repository, git,
    commit() {
      git('add', '--all');
      git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
        '-c', 'commit.gpgsign=false', 'commit', '--quiet', '-m', 'Fixture content');
    },
  };
}

test('mixed Git tree and content hashes skip unchanged skills and detect support-file changes', (t) => {
  const f = fixture(t, {});
  const repo = localRepository(f);
  mkdirSync(join(repo.path, 'skills/tree-skill'), { recursive: true });
  mkdirSync(join(repo.path, 'skills/content-skill/node_modules'), { recursive: true });
  writeFileSync(join(repo.path, 'skills/tree-skill/SKILL.md'), '# Tree skill\n');
  writeFileSync(join(repo.path, 'skills/content-skill/SKILL.md'), '# Content skill\n');
  writeFileSync(join(repo.path, 'skills/content-skill/helper.txt'), 'initial helper\n');
  writeFileSync(join(repo.path, 'skills/content-skill/node_modules/ignored.txt'), 'ignored dependency\n');
  symlinkSync('helper.txt', join(repo.path, 'skills/content-skill/ignored-link'));
  repo.commit();
  writeFileSync(f.lock, JSON.stringify({ skills: {
    'tree-skill': entry('tree-skill', 'owner/repo', { skillFolderHash: repo.git('rev-parse', 'HEAD:skills/tree-skill') }),
    'content-skill': entry('content-skill', 'owner/repo', {
      skillFolderHash: '40d6d0157546d24e3d331f9d7aa0fab7c905d183b9951e840f99c0febaaa9bb1',
    }),
  } }));
  const unchanged = f.run();
  assert.equal(unchanged.status, 0, unchanged.stderr);
  assert.match(unchanged.stderr, /no changed skill folders in owner\/repo/);
  assert.deepEqual(f.commands('npx'), []);
  writeFileSync(join(repo.path, 'skills/content-skill/helper.txt'), 'updated helper\n');
  repo.commit();
  const changed = f.run();
  assert.equal(changed.status, 0, changed.stderr);
  assert.deepEqual(f.commands('npx'), [add('owner/repo', 'content-skill')]);
});

test('root skill content hashes exclude checkout metadata and detect support-file changes', (t) => {
  const f = fixture(t, { root: entry('root', 'owner/repo', {
    skillPath: 'SKILL.md', skillFolderHash: '1e85850ff808bc74e92e0f3310b742550cf5218e9cfc25a374f5cd2eca7656dd',
  }) });
  const repo = localRepository(f);
  writeFileSync(join(repo.path, 'SKILL.md'), '# Root skill\n');
  writeFileSync(join(repo.path, 'helper.txt'), 'root helper\n');
  repo.commit();
  const unchanged = f.run();
  assert.equal(unchanged.status, 0, unchanged.stderr);
  assert.match(unchanged.stderr, /no changed skill folders in owner\/repo/);
  assert.deepEqual(f.commands('npx'), []);
  writeFileSync(join(repo.path, 'helper.txt'), 'changed root helper\n');
  repo.commit();
  const changed = f.run();
  assert.equal(changed.status, 0, changed.stderr);
  assert.deepEqual(f.commands('npx'), [add('owner/repo', 'root')]);
});

test('failed GitHub API lookup falls back to a successful Git tree lookup', (t) => {
  const f = fixture(t, { alpha: entry('alpha') });
  const repo = localRepository(f);
  mkdirSync(join(repo.path, 'skills/alpha'), { recursive: true });
  writeFileSync(join(repo.path, 'skills/alpha/SKILL.md'), '# Alpha\n');
  repo.commit();
  const result = f.run();
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stderr, /checking owner\/repo via Git/);
  assert.deepEqual(f.commands('gh'), [['api', '--hostname', 'github.com', request()]]);
  assert.deepEqual(f.commands('npx'), [add('owner/repo', 'alpha')]);
});
