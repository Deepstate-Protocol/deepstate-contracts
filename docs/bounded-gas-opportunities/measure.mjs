import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { spawnSync, execFileSync } from 'node:child_process';

const root = process.env.GAS_OPPORTUNITY_ROOT ?? '/tmp/deepstate-bounded-opportunities-20261107';
const fixture = process.env.GAS_FIXTURE_ROOT ?? '/tmp/deepstate-full-gas-workup-20261107/fixture';
const prior = process.env.GAS_BASELINE_RAW ?? '/tmp/deepstate-solar-gas-20261107/contracts/docs/gas-workup/raw';
const forge = process.env.GAS_FORGE ?? '/tmp/deepstate-rebase-pr34-20261107/toolchain/forge';
const cast = process.env.GAS_CAST ?? '/tmp/deepstate-rebase-pr34-20261107/toolchain/cast';
if (!execFileSync(forge, ['--version'], { encoding: 'utf8' }).includes('d3167db')) throw Error('Wrong gas executor');
const [variant, artifactFile, compiler = 'solc'] = process.argv.slice(2);
if (!variant || !artifactFile) throw Error('Usage: node measure.mjs variant artifact');
const artifact = JSON.parse(fs.readFileSync(artifactFile));
const metadata = typeof artifact.metadata === 'string' ? JSON.parse(artifact.metadata) : artifact.metadata;
const expectedCompiler = compiler === 'solar' ? '0.8.38+commit.e7a91fc7.solar.0.3.0' : '0.8.28+commit.7893614a';
if (metadata.compiler.version !== expectedCompiler) throw Error('Compiler mismatch');
if (metadata.settings.evmVersion !== 'cancun' || metadata.settings.optimizer.runs !== 200 || (compiler === 'solc' && !metadata.settings.viaIR)) {
  throw Error('Compiler settings mismatch');
}
const sourceFile = path.join(root, 'variants', `${variant}.sol`);
const source = fs.readFileSync(sourceFile);
const keccak = execFileSync(cast, ['keccak'], { input: '0x' + source.toString('hex'), encoding: 'utf8' }).trim();
if (metadata.sources['src/DeepstateV1.sol'].keccak256 !== keccak) throw Error('Source fingerprint mismatch');
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const fixtureManifest = JSON.parse(fs.readFileSync(path.join(prior, 'manifest.json')));
for (const [file, hash] of Object.entries(fixtureManifest.fixtures)) {
  if (sha(fs.readFileSync(path.join(fixture, file))) !== hash) throw Error(`Fixture changed: ${file}`);
}
const runtime = artifact.deployedBytecode.object;
const resultName = compiler === 'solar' ? `${variant}-solar` : variant;
const manifest = {
  variant, compiler: metadata.compiler.version, settings: metadata.settings,
  sourceSha256: sha(source), sourceKeccak256: keccak,
  runtimeSha256: sha(Buffer.from(runtime.replace(/^0x/, ''), 'hex')),
  executor: 'd3167db683c001c196126c912027437a9cb0bfb9',
  baseline: process.env.GAS_COMPARISON_BASELINE ?? '096eab28d87debdd472b4e22e65820e2b1b8d523', runs: [],
};
for (const [group, filter, count] of [
  ['release', ['--match-contract', '(RadixMatchingEngine(Gas|HookGas|FeeGas)Test|DeepstateV1IntegratorFeeGasTest)'], 188],
  ['insertion', ['--match-contract', '^OpportunityGasProbe$', '--match-test', '^testOpportunity_'], 12],
]) {
  const label = `${resultName}-${group}`;
  const log = path.join(root, 'results', `${label}.log`);
  const snapshot = path.join(root, 'results', `${label}.snapshot`);
  const fd = fs.openSync(log, 'w');
  const args = ['snapshot', ...filter, '--threads', '4', '--isolate', '--snap', snapshot];
  console.log(`START ${label}`);
  const start = Date.now();
  const result = spawnSync(forge, args, {
    cwd: fixture, env: { ...process.env, FOUNDRY_DISABLE_NIGHTLY_WARNING: '1', VARIANT_BYTECODE: runtime, EXACT_SUMMARIES: 'true' },
    stdio: ['ignore', fd, fd],
  });
  fs.closeSync(fd);
  const text = fs.readFileSync(log, 'utf8');
  const summary = text.split('\n').findLast(line => /^Ran .*test suite/.test(line));
  console.log(`END ${label}: status=${result.status}, ${Math.round((Date.now() - start) / 1000)}s; ${summary}`);
  if (result.status !== 0) {
    console.log(text.slice(-12000));
    process.exit(result.status || 1);
  }
  if (!text.includes(`${count} tests passed, 0 failed, 0 skipped`)) throw Error('Unexpected test results');
  if (fs.readFileSync(snapshot, 'utf8').trim().split('\n').length !== count) throw Error('Unexpected case count');
  manifest.runs.push({ group, count, log: path.basename(log), snapshot: path.basename(snapshot),
    logSha256: sha(fs.readFileSync(log)), snapshotSha256: sha(fs.readFileSync(snapshot)) });
  fs.writeFileSync(path.join(root, 'results', `${resultName}-manifest.json`), JSON.stringify(manifest, null, 2) + '\n');
}
