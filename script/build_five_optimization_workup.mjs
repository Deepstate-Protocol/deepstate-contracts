import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';

const root = process.argv[2] ?? '/tmp/deepstate-five-optimizations-20261107';
const output = process.argv[3] ?? 'docs/five-optimization-workup';
const stages = [
  ['00-baseline', 'Candidate E'],
  ['01-shared-rest-quote', 'Shared resting quotes'],
  ['02-known-hook-tops', 'Known hook tops'],
  ['03-cached-classification', 'Cached branch classification'],
  ['04-reused-branch-metadata', 'Reused branch metadata'],
  ['05-memory-match-buffer', 'Memory match buffer'],
];
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const read = file => fs.readFileSync(file, 'utf8');
const baselineSource = read(path.join(root, 'variants', '00-baseline.sol'));
const baselineHash = sha(baselineSource);
assert.equal(baselineHash, '45d978cb4e482bb2ad0d0a76e5e82eac26da8739b86e65f09fae1d6ba10d1f70');
const controls = `candidate-E:${baselineHash}`;
fs.mkdirSync(path.join(output, 'raw'), { recursive: true });
const fingerprints = {};
function capture(relative, bytes) {
  fs.writeFileSync(path.join(output, relative), bytes);
  fingerprints[relative] = sha(bytes);
}
const datasets = stages.map(([name, label]) => {
  const source = read(path.join(root, 'variants', `${name}.sol`));
  const manifestFile = `${name}-solar-manifest.json`;
  const manifest = JSON.parse(read(path.join(root, 'results', manifestFile)));
  assert.equal(manifest.compiler, '0.8.38+commit.e7a91fc7.solar.0.3.0');
  assert.equal(manifest.executor, 'd3167db683c001c196126c912027437a9cb0bfb9');
  assert.equal(manifest.settings.evmVersion, 'cancun');
  assert.equal(manifest.settings.optimizer.runs, 200);
  assert.equal(manifest.sourceSha256, sha(source));
  assert.equal(manifest.baseline, controls);
  capture(`raw/${manifestFile}`, JSON.stringify(manifest, null, 2) + '\n');
  capture(`raw/${name}.sol.txt`, source);
  const cases = new Map();
  for (const run of manifest.runs) {
    for (const type of ['log', 'snapshot']) {
      const bytes = fs.readFileSync(path.join(root, 'results', run[type]));
      assert.equal(sha(bytes), run[`${type}Sha256`]);
      capture(`raw/${run[type]}`, bytes);
    }
    assert.match(read(path.join(root, 'results', run.log)), new RegExp(`${run.count} tests passed, 0 failed, 0 skipped`));
    for (const line of read(path.join(root, 'results', run.snapshot)).trim().split('\n')) {
      const match = /^(.*) \(gas: (\d+)\)$/.exec(line);
      assert.ok(match, line);
      assert.ok(!cases.has(match[1]), match[1]);
      cases.set(match[1], Number(match[2]));
    }
  }
  assert.equal(cases.size, 200);
  return { name, label, cases, manifest };
});
const keys = [...datasets[0].cases.keys()].sort();
for (const dataset of datasets) assert.deepEqual([...dataset.cases.keys()].sort(), keys);
assert.equal(sha(read('src/DeepstateV1.sol')), datasets.at(-1).manifest.sourceSha256);
const validationFile = path.join(root, 'results', 'validation-manifest.json');
let validation;
if (fs.existsSync(validationFile)) {
  const checked = JSON.parse(read(validationFile));
  if (checked.runs.length === 6 && checked.compatibility) {
    assert.equal(checked.sourceSha256, datasets.at(-1).manifest.sourceSha256);
    assert.equal(checked.compatibility.publicAbiEqual, true);
    assert.equal(checked.compatibility.storageLayoutEqual, true);
    for (const run of checked.runs) {
      const bytes = fs.readFileSync(path.join(root, 'results', run.log));
      assert.equal(sha(bytes), run.sha256);
      assert.equal(run.status, 0);
      capture(`raw/${run.log}`, bytes);
    }
    validation = { sourceSha256: checked.sourceSha256, publicAbiEqual: true, storageLayoutEqual: true };
    capture('raw/validation-manifest.json', JSON.stringify(checked, null, 2) + '\n');
    capture('raw/release-solar.snapshot', fs.readFileSync('.gas-snapshot.solar'));
  }
}
if (process.env.REQUIRE_VALIDATION === '1') assert.ok(validation, 'Validation has not completed');
for (const filename of ['prepush-slither-pinned.log', 'prepush-coverage.log']) {
  const file = path.join(root, 'results', filename);
  if (fs.existsSync(file)) capture(`raw/${filename}`, fs.readFileSync(file));
}
const historical = new Map();
for (const group of ['release', 'insertion']) {
  for (const line of read(`docs/bounded-gas-opportunities/raw/uniform-difference-solar-${group}.snapshot`).trim().split('\n')) {
    const [, key, gas] = /^(.*) \(gas: (\d+)\)$/.exec(line);
    historical.set(key, Number(gas));
  }
}
assert.deepEqual(datasets[0].cases, historical, 'Baseline must reproduce the approved E measurements');
const integer = value => value.toLocaleString('en-US');
const signed = value => `${value > 0 ? '+' : ''}${integer(value)}`;
const percent = (delta, before) => `${delta > 0 ? '+' : ''}${(100 * delta / before).toFixed(4)}%`;
const rows = [];
const report = [
  '# Five Bounded Optimization Stages', '',
  'Solar 0.3.0 / Solidity 0.8.38; Cancun; optimizer 200. Frozen fixture and Forge executor d3167db.',
  `Baseline: candidate E, source SHA-256 \`${baselineHash}\`. It reproduces all 200 previously reported observations exactly.`,
  'Stages are cumulative, not five isolated experiments. Each stage is compared against E and the immediately preceding stage.',
  'All 200 cases per stage remain visible, including 42 inherited repetitions and the functional gas-budget check.',
  'Negative deltas save gas; positive deltas are regressions. Benchmark frequencies are not production-volume weights.', '',
];
const summaries = [];
for (let i = 1; i < datasets.length; i++) {
  const dataset = datasets[i];
  const previous = datasets[i - 1];
  report.push(`## ${i}. ${dataset.label}`, '',
    '| Test | E Baseline | Previous | Candidate | Delta vs E | % vs E | Delta vs Previous | % vs Previous | Notes |',
    '|---|---:|---:|---:|---:|---:|---:|---:|---|');
  const deltas = [];
  const steps = [];
  for (const key of keys) {
    const before = datasets[0].cases.get(key);
    const prior = previous.cases.get(key);
    const after = dataset.cases.get(key);
    const delta = after - before;
    const step = after - prior;
    const repeated = key.startsWith('RadixMatchingEngineGasTestWideSweep:') && !key.includes('MixedSweep');
    const check = key.includes('FitsOneMillionGas');
    const note = check ? 'functional budget check' : repeated ? 'inherited repetition' : '';
    rows.push([i, dataset.name, key, before, prior, after, delta, 100 * delta / before, step, 100 * step / prior, note]);
    report.push(`| ${key} | ${integer(before)} | ${integer(prior)} | ${integer(after)} | ${signed(delta)} | ${percent(delta, before)} | ${signed(step)} | ${percent(step, prior)} | ${note || '-'} |`);
    deltas.push(delta);
    steps.push(step);
  }
  const count = values => ({ cheaper: values.filter(x => x < 0).length, unchanged: values.filter(x => x === 0).length,
    dearer: values.filter(x => x > 0).length, smallestDelta: Math.min(...values), largestDelta: Math.max(...values) });
  summaries.push({ stage: i, name: dataset.name, baseline: count(deltas), previous: count(steps) });
  report.push('');
}
const csv = [['stage', 'variant', 'case', 'baseline_gas', 'previous_gas', 'candidate_gas', 'delta_baseline_gas',
  'delta_baseline_percent', 'delta_previous_gas', 'delta_previous_percent', 'notes'], ...rows]
  .map(row => row.map(value => JSON.stringify(value)).join(',')).join('\n') + '\n';
capture('GAS_DELTAS.csv', csv);
capture('GAS_TABLES.md', report.join('\n').trimEnd() + '\n');
capture('summary.json', JSON.stringify(summaries, null, 2) + '\n');
const profiles = [
  ['Core', ['RadixMatchingEngineGasTest']],
  ['Hooks', ['RadixMatchingEngineHookGasTest']],
  ['Protocol Fee', ['RadixMatchingEngineFeeGasTest']],
  ['Wide Sweep', ['RadixMatchingEngineGasTestWideSweep']],
  ['Additional Cases', ['DeepstateV1IntegratorFeeGasTest', 'OpportunityGasProbe', 'RadixMatchingEngineGasTestNativeDirtySpine']],
];
const chat = [
  '# Complete Gas Comparison', '',
  'Solar; candidate E baseline. Changes 1-5 are cumulative, in the order listed below.',
  ...stages.slice(1).map(([, label], i) => `${i + 1}. ${label}.`), '',
  'Each change cell is gas (absolute delta; percentage delta versus baseline).',
  'Wide Sweep rows repeat the core fixtures except MixedSweep cases; the gas-budget check is functional.', '',
];
for (const [label, contracts] of profiles) {
  chat.push(`## ${label}`, '',
    '| Test | Baseline | Change 1 | Change 2 | Change 3 | Change 4 | Change 5 |',
    '|---|---:|---:|---:|---:|---:|---:|');
  for (const key of keys.filter(key => contracts.includes(key.split(':')[0]))) {
    const [contract, test] = key.split(':');
    const name = `${contracts.length > 1 ? `${contract}:` : ''}${test.replace(/^(testGas_|testOpportunity_)/, '').replace(/\(\)$/, '')}`;
    const baseline = datasets[0].cases.get(key);
    const cells = datasets.slice(1).map(dataset => {
      const gas = dataset.cases.get(key);
      return `${integer(gas)} (${signed(gas - baseline)}; ${percent(gas - baseline, baseline)})`;
    });
    chat.push(`| ${name} | ${integer(baseline)} | ${cells.join(' | ')} |`);
  }
  chat.push('');
}
capture('CHAT_TABLE.md', chat.join('\n').trimEnd() + '\n');
for (let i = 1; i < stages.length; i++) {
  const before = path.join(root, 'variants', `${stages[i - 1][0]}.sol`);
  const after = path.join(root, 'variants', `${stages[i][0]}.sol`);
  const diff = spawnSync('diff', ['-u', '--label', 'a/src/DeepstateV1.sol', '--label', 'b/src/DeepstateV1.sol', before, after], { encoding: 'utf8' });
  assert.equal(diff.status, 1);
  capture(`raw/${stages[i][0]}.patch`, diff.stdout);
}
capture('manifest.json', JSON.stringify({ baseline: controls, stages: datasets.map(({ name, manifest }) => ({
  name, sourceSha256: manifest.sourceSha256, runtimeSha256: manifest.runtimeSha256,
})), casesPerStage: 200, comparisons: rows.length, validation, fingerprints }, null, 2) + '\n');
console.log(JSON.stringify({ comparisons: rows.length, summaries }, null, 2));
