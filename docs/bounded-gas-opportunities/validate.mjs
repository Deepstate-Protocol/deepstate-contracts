import fs from 'node:fs';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';

const root = '/tmp/deepstate-bounded-opportunities-20261107';
const project = `${root}/project`;
const forge = '/tmp/deepstate-rebase-pr34-20261107/toolchain/forge';
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const sourceHash = sha(fs.readFileSync(`${project}/src/DeepstateV1.sol`));
if (sourceHash !== sha(fs.readFileSync(`${root}/variants/uniform-difference.sol`))) throw Error('Wrong prototype source');
const manifest = { sourceSha256: sourceHash, variant: 'uniform-difference', runs: [] };
const groups = {
  bounds: ['--match-contract', '^BoundedTraversalTest$', '--match-test', '^(test_|testFuzz_)', '--fuzz-runs', '256'],
  behavioral: ['--no-match-contract', '(Invariant|Gas|AccessList|BoundedTraversal)', '--fuzz-runs', '256'],
  invariants: ['--match-contract', '.*(RadixMatchingEngineInvariantTest|DeepstateV1MultiPoolInvariantTest|DeepstateV1NativeETHInvariantTest).*', '--match-test', 'invariant_.*'],
};
for (const [group, args] of Object.entries(groups)) {
  const file = `${root}/results/validation-${group}.log`;
  const fd = fs.openSync(file, 'w');
  const start = Date.now();
  console.log(`START validation ${group}`);
  const result = spawnSync(forge, ['test', ...args, '--threads', '4'], {
    cwd: project,
    env: { ...process.env, FOUNDRY_DISABLE_NIGHTLY_WARNING: '1', FOUNDRY_INVARIANT_RUNS: '256', FOUNDRY_INVARIANT_DEPTH: '64' },
    stdio: ['ignore', fd, fd],
  });
  fs.closeSync(fd);
  const text = fs.readFileSync(file, 'utf8');
  const summary = text.split('\n').findLast(line => /^Ran .*test suite/.test(line));
  console.log(`END validation ${group}: status=${result.status}; ${summary}; ${Math.round((Date.now() - start) / 1000)}s`);
  if (result.status !== 0 || !summary?.includes('0 failed')) {
    console.log(text.slice(-12000));
    process.exit(result.status || 1);
  }
  manifest.runs.push({ group, args: ['test', ...args, '--threads', '4'], summary, log: `validation-${group}.log`, logSha256: sha(fs.readFileSync(file)) });
  fs.writeFileSync(`${root}/results/validation-manifest.json`, JSON.stringify(manifest, null, 2) + '\n');
}
