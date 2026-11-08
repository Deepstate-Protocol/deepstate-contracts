import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';

const root = process.argv[2] ?? '/tmp/deepstate-five-optimizations-20261107';
const forge = process.env.SOLAR_FORGE ?? '/tmp/deepstate-solar-gas-20261107/toolchain/forge';
const toolchain = path.dirname(forge);
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const sourceHash = sha(fs.readFileSync('src/DeepstateV1.sol'));
const manifest = { sourceSha256: sourceHash, runs: [] };
const env = { ...process.env, PATH: `${toolchain}:${process.env.PATH}`, FOUNDRY_PROFILE: 'solar',
  FOUNDRY_DISABLE_NIGHTLY_WARNING: '1', FOUNDRY_INVARIANT_RUNS: '256', FOUNDRY_INVARIANT_DEPTH: '64' };
const build = ['--no-dynamic-test-linking', '--out', 'out-five-validation', '--cache-path', 'cache-five-validation', '--threads', '4'];
const groups = [
  ['behavior', forge, ['test', ...build, '--no-match-contract', '(Invariant|Gas|AccessList|BoundedTraversal)', '--fuzz-runs', '256']],
  ['bounds', forge, ['test', ...build, '--match-contract', '^BoundedTraversalTest$', '--match-test', '^(test_|testFuzz_)', '--fuzz-runs', '256']],
  ['invariants', forge, ['test', ...build, '--match-contract', '(RadixMatchingEngineInvariantTest|DeepstateV1MultiPoolInvariantTest|DeepstateV1NativeETHInvariantTest)', '--match-test', 'invariant_.*']],
  ['release-snapshot', forge, ['snapshot', ...build, '--isolate', '--match-contract', '(RadixMatchingEngine(Gas|HookGas|FeeGas)Test|DeepstateV1IntegratorFeeGasTest)', '--snap', '.gas-snapshot.solar']],
  ['smt', 'python3', ['script/prove_protocol.py']],
  ['format', forge, ['fmt', '--check', 'src/DeepstateV1.sol', 'test/DeepstateV1.t.sol', 'test/BoundedTraversal.t.sol', 'test/RadixMatchingEngineGas.t.sol']],
];
for (const [group, command, args] of groups) {
  const filename = `validation-${group}.log`;
  const file = path.join(root, 'results', filename);
  const fd = fs.openSync(file, 'w');
  console.log(`START ${group}`);
  const run = spawnSync(command, args, { env, stdio: ['ignore', fd, fd] });
  fs.closeSync(fd);
  const log = fs.readFileSync(file, 'utf8');
  console.log(`END ${group}: ${run.status}; ${log.split('\n').filter(line => /^Ran .*test suite|^protocol proof/.test(line)).join(' ')}`);
  if (run.status !== 0) { console.error(log.slice(-12000)); process.exit(run.status ?? 1); }
  manifest.runs.push({ group, command, args, log: filename, sha256: sha(log), status: run.status });
  fs.writeFileSync(path.join(root, 'results', 'validation-manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
}
const candidate = JSON.parse(fs.readFileSync('out-five-validation/DeepstateV1.sol/DeepstateV1.json'));
const baseline = JSON.parse(fs.readFileSync('/tmp/deepstate-bounded-opportunities-20261107/project/out-uniform-difference-solar/DeepstateV1.sol/DeepstateV1.json'));
assert.deepEqual(candidate.abi, baseline.abi, 'Public ABI changed');
const inspect = spawnSync(forge, ['inspect', 'src/DeepstateV1.sol:DeepstateV1', 'storageLayout', '--json', '--out', 'out-five-layout', '--cache-path', 'cache-five-layout'], { env, encoding: 'utf8' });
assert.equal(inspect.status, 0, inspect.stderr);
const current = JSON.parse(inspect.stdout);
const previous = JSON.parse(fs.readFileSync('docs/bounded-gas-opportunities/raw/compatibility.json')).after;
function canonical(layout) {
  const type = id => {
    const entry = layout.types[id];
    return { label: entry.label, encoding: entry.encoding, bytes: entry.numberOfBytes,
      ...(entry.key ? { key: type(entry.key), value: type(entry.value) } : {}),
      ...(entry.members ? { members: entry.members.map(member) } : {}) };
  };
  const member = entry => ({ label: entry.label, slot: entry.slot, offset: entry.offset, type: type(entry.type) });
  return layout.storage.map(member);
}
assert.deepEqual(canonical(current), canonical(previous), 'Persistent storage layout changed');
manifest.compatibility = { publicAbiEqual: true, storageLayoutEqual: true, layout: current };
assert.equal(sourceHash, sha(fs.readFileSync('src/DeepstateV1.sol')));
fs.writeFileSync(path.join(root, 'results', 'validation-manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
console.log('Public ABI and persistent storage layout unchanged');
