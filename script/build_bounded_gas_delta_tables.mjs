import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';

const repo = path.resolve(process.argv[2] ?? path.join(path.dirname(fileURLToPath(import.meta.url)), '..'));
const docs = path.join(repo, 'docs');
const evidence = path.join(docs, 'bounded-gas-opportunities');
const raw = path.join(evidence, 'raw');
const baselineRaw = path.join(docs, 'gas-workup/raw');
const json = file => JSON.parse(fs.readFileSync(file, 'utf8'));
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const selection = json(path.join(evidence, 'selection.json'));
const historicalManifest = json(path.join(baselineRaw, 'manifest.json'));
const executor = 'd3167db683c001c196126c912027437a9cb0bfb9';
assert.equal(selection.baseline, '096eab28d87debdd472b4e22e65820e2b1b8d523');
assert.equal(selection.selected.variant, 'uniform-difference');
assert.equal(historicalManifest.executor, executor);
assert.equal(historicalManifest.settings.optimizerRuns, 200);
assert.equal(historicalManifest.settings.viaIR, true);
assert.equal(historicalManifest.settings.evm, 'cancun');
assert.equal(historicalManifest.settings.isolated, true);

for (const [file, hash] of Object.entries(json(path.join(evidence, 'evidence-sha256.json')))) {
  assert.equal(sha(fs.readFileSync(path.resolve(raw, file))), hash, `raw evidence: ${file}`);
}
const selectedPatch = fs.readFileSync(path.join(evidence, selection.selected.patch), 'utf8');
assert.ok(!/\+\s*if\s*\((?:removedQuote|quoteState\.addedQuote)\s*!=\s*0\)/.test(selectedPatch),
  'selected patch must not contain the rejected zero-delta guard');
for (const item of selection.rejected) {
  assert.ok(item.patch.startsWith('rejected/'));
  assert.ok(!fs.existsSync(path.join(raw, path.basename(item.patch))), 'rejected patch is not apply-ready');
}

function parseSnapshot(file) {
  const rows = new Map();
  for (const line of fs.readFileSync(file, 'utf8').trim().split('\n')) {
    const match = /^(\w+:\w+\(\)) \(gas: (\d+)\)$/.exec(line);
    assert.ok(match, `snapshot syntax: ${line}`);
    assert.ok(!rows.has(match[1]), 'duplicate snapshot identity');
    const gas = Number(match[2]);
    assert.ok(Number.isSafeInteger(gas) && gas > 0);
    rows.set(match[1], gas);
  }
  return rows;
}

const datasets = new Map();
function dataset(compiler, variant) {
  const key = `${compiler}/${variant}`;
  if (datasets.has(key)) return datasets.get(key);
  const historic = variant === 'after' || variant === 'master';
  const prefix = compiler === 'solar' ? `${variant}-solar` : variant;
  const manifest = historic ? historicalManifest : json(path.join(raw, `${prefix}-manifest.json`));
  assert.equal(manifest.executor, executor);
  const expectedCompiler = compiler === 'solc' ? '0.8.28+commit.7893614a' : '0.8.38+commit.e7a91fc7.solar.0.3.0';
  assert.equal(historicalManifest.compilerVersions[compiler], expectedCompiler);
  if (!historic) {
    assert.equal(manifest.compiler, expectedCompiler);
    assert.equal(manifest.baseline, selection.baseline);
    assert.equal(manifest.settings.optimizer.runs, 200);
    assert.equal(manifest.settings.evmVersion, 'cancun');
    if (compiler === 'solc') assert.equal(manifest.settings.viaIR, true);
    if (variant === selection.selected.variant) assert.equal(manifest.sourceSha256, selection.selected.sourceSha256);
  }
  const rows = new Map();
  for (const [group, count] of [['release', 188], ['insertion', 12]]) {
    const run = historic
      ? manifest.runs.find(item => item.label === `${compiler}-${variant}-${group}`)
      : manifest.runs.find(item => item.group === group);
    assert.ok(run, 'missing measurement group');
    if (historic) {
      const expectedRef = variant === 'after' ? selection.baseline : 'bf18c54b13123de5ecc3e05dcff6822436e0cd27';
      assert.equal(run.commit, expectedRef);
    }
    const dir = historic ? baselineRaw : raw;
    const snapshot = fs.readFileSync(path.join(dir, run.snapshot));
    const log = fs.readFileSync(path.join(dir, run.log));
    assert.equal(sha(snapshot), run.snapshotSha256);
    assert.equal(sha(log), run.logSha256);
    assert.ok(log.toString().includes(`${count} tests passed, 0 failed, 0 skipped`));
    const parsed = parseSnapshot(path.join(dir, run.snapshot));
    assert.equal(parsed.size, count);
    for (const [id, gas] of parsed) {
      assert.ok(!rows.has(id));
      rows.set(id, gas);
    }
  }
  assert.equal(rows.size, 200);
  const result = { rows, manifest };
  datasets.set(key, result);
  return result;
}

const ids = [...dataset('solc', 'after').rows.keys()].sort();
const stages = [
  { variant: 'mixed-delta', label: 'A', previous: 'after' },
  { variant: 'shared-cancel', label: 'B', previous: 'mixed-delta' },
  { variant: 'early-split', label: 'C', previous: 'shared-cancel' },
  { variant: 'early-split-gated', label: 'C2', previous: 'early-split' },
  { variant: 'insert-delta', label: 'D', previous: 'early-split-gated' },
  { variant: 'uniform-difference', label: 'E', previous: 'insert-delta' },
];
const profiles = {
  DeepstateV1IntegratorFeeGasTest: 'Integrator Fees And Routing',
  OpportunityGasProbe: 'Insertion Diagnostics',
  RadixMatchingEngineFeeGasTest: 'ERC20 With Protocol Fee',
  RadixMatchingEngineGasTest: 'ERC20 Without Hooks',
  RadixMatchingEngineGasTestNativeDirtySpine: 'Native ETH Histories',
  RadixMatchingEngineGasTestWideSweep: 'Wide Sweeps And Inherited Repeats',
  RadixMatchingEngineHookGasTest: 'Top-Order Hooks',
};
const number = value => value.toLocaleString('en-US');
const signed = value => `${value > 0 ? '+' : ''}${number(value)}`;
const percent = value => `${value > 0 ? '+' : ''}${value.toFixed(4)}%`;
const records = [];
function rowsFor(compiler, stage, status) {
  const base = dataset(compiler, 'after').rows;
  const previous = dataset(compiler, stage.previous).rows;
  const current = dataset(compiler, stage.variant).rows;
  const master = dataset(compiler, 'master').rows;
  for (const rows of [previous, current, master]) assert.deepEqual([...rows.keys()].sort(), ids);
  return ids.map(id => {
    const [contract, test] = id.split(':');
    const repeated = contract === 'RadixMatchingEngineGasTestWideSweep' && !test.startsWith('testGas_MixedSweep');
    const budget = test === 'testGas_MixedSweep1024FitsOneMillionGas()';
    const delta = current.get(id) - base.get(id);
    const step = current.get(id) - previous.get(id);
    const masterDelta = budget ? null : current.get(id) - master.get(id);
    const row = {
      compiler, variant: stage.variant, case: id, contract, test, status,
      included: !repeated && !budget, duplicate: repeated ? `RadixMatchingEngineGasTest:${test}` : '',
      baseline: base.get(id), previous: previous.get(id), candidate: current.get(id), master: master.get(id),
      previousStage: stage.previous, delta, percent: 100 * delta / base.get(id),
      step, stepPercent: 100 * step / previous.get(id), masterDelta,
      masterPercent: budget ? null : 100 * masterDelta / master.get(id),
      note: repeated ? 'Inherited repeat' : budget ? 'Capped-gas check; baseline and candidate succeed' : '-',
      masterOutcome: budget ? 'gas-limit failure' : 'success',
    };
    records.push(row);
    return row;
  });
}

function tableSection(compiler, stage, status, anchor) {
  const rows = rowsFor(compiler, stage, status);
  assert.equal(rows.filter(row => row.included).length, 157);
  let text = `<a id="${anchor}"></a>\n\n## ${compiler} / ${stage.label} / ${stage.variant}\n\n`;
  const previousLabel = stage.previous === 'after' ? '096eab2 (bounded baseline)' : stage.previous;
  text += `Status: **${status}**. Previous stage: \`${previousLabel}\`. Baseline: \`096eab2\`.\n\n`;
  text += `All **200 rows** are shown. Positive deltas cost more gas; negative deltas cost less.\n\n`;
  const contracts = [...new Set(rows.map(row => row.contract))];
  for (const contract of contracts) {
    text += `### ${profiles[contract]}\n\nContract: \`${contract}\`.\n\n`;
    text += '| Test | Bounded Baseline | Previous Stage | Candidate | Gas Delta vs Previous | % vs Previous | Gas Delta vs Baseline | % vs Baseline | Notes |\n';
    text += '|---|---:|---:|---:|---:|---:|---:|---:|---|\n';
    for (const row of rows.filter(item => item.contract === contract)) {
      text += `| \`${row.test}\` | ${number(row.baseline)} | ${number(row.previous)} | ${number(row.candidate)} | ${signed(row.step)} | ${percent(row.stepPercent)} | ${signed(row.delta)} | ${percent(row.percent)} | ${row.note} |\n`;
    }
    text += '\n';
  }
  return text;
}

let report = '# Complete Bounded Gas Delta Tables\n\n';
report += 'Every measured row is included, without a savings threshold or selected-case filter. Each table contains 188 release rows and 12 insertion diagnostics. Inherited repeats and the capped-gas functional check remain visible and are labeled.\n\n';
report += 'The selected prototype is **E / `uniform-difference`**, with no zero-delta quote-cache guard. It remains an investigative patch, not the deployed or working contract source. See [selection metadata](bounded-gas-opportunities/selection.json).\n\n';
report += 'Controls: bounded baseline `096eab28d87debdd472b4e22e65820e2b1b8d523`; solc 0.8.28, via-IR, optimizer 200, Cancun; separate experimental Solar 0.3.0 / Solidity 0.8.38 comparison; Forge executor `d3167db683c001c196126c912027437a9cb0bfb9`. The original frozen harness and runtime-only substitution are unchanged. These are verified existing measurements, not new benchmark runs.\n\n';
report += 'Percentages are displayed to four decimal places; the [complete CSV](BOUNDED_GAS_OPPORTUNITIES.csv) retains full precision and also includes the same-harness master `bf18c54` comparison. Failed master capped-gas outcomes have no successful-operation delta. No production-weighted savings percentage is inferred.\n\n';
report += '## Contents\n\n- [Selected E: solc, all 200 cases](#selected-solc)\n- [Selected E: Solar, all 200 cases](#selected-solar)\n';
for (const stage of stages.slice(0, -1)) report += `- [Stage ${stage.label}: all 200 cases](#stage-${stage.label.toLowerCase()})\n`;
report += '- [Rejected zero-delta experiment: all 200 cases](bounded-gas-opportunities/rejected/ZERO_DELTA_GAS.md)\n\n';
report += tableSection('solc', stages.at(-1), 'selected prototype; no zero-delta guard', 'selected-solc');
report += tableSection('solar', { ...stages.at(-1), previous: 'after' }, 'selected prototype; separate compiler comparison', 'selected-solar');
for (const stage of stages.slice(0, -1)) report += tableSection('solc', stage, 'intermediate experiment', `stage-${stage.label.toLowerCase()}`);
let rejected = '# Archived Zero-Delta Gas Table\n\n';
rejected += '**Rejected experiment, not a selected implementation candidate.** Its records are retained for a complete audit trail. The selected E patch does not contain this guard.\n\n';
rejected += tableSection('solc', { variant: 'zero-delta', label: 'F', previous: 'uniform-difference' }, 'rejected; historical measurements only', 'rejected-zero-delta');
assert.equal(records.length, 1600);
const csvCell = value => value === null ? '' : typeof value === 'string' ? `"${value.replaceAll('"', '""')}"` : String(value);
const csvRows = [[
  'compiler', 'variant', 'case', 'included_in_summary', 'duplicate_of', 'bounded_096_gas', 'candidate_gas', 'delta_gas', 'delta_percent',
  'status', 'previous_stage', 'previous_stage_gas', 'delta_previous_gas', 'delta_previous_percent',
  'master_gas', 'master_outcome', 'delta_master_gas', 'delta_master_percent',
], ...records.map(row => [
  row.compiler, row.variant, row.case, row.included, row.duplicate, row.baseline, row.candidate, row.delta, row.percent,
  row.status, row.previousStage, row.previous, row.step, row.stepPercent,
  row.master, row.masterOutcome, row.masterDelta, row.masterPercent,
])];
const outputs = {
  'BOUNDED_GAS_DELTA_TABLES.md': report.trimEnd() + '\n',
  'bounded-gas-opportunities/rejected/ZERO_DELTA_GAS.md': rejected.trimEnd() + '\n',
  'BOUNDED_GAS_OPPORTUNITIES.csv': csvRows.map(row => row.map(csvCell).join(',')).join('\n') + '\n',
};
for (const [file, content] of Object.entries(outputs)) fs.writeFileSync(path.join(docs, file), content);
const generated = {
  baseline: selection.baseline, master: 'bf18c54b13123de5ecc3e05dcff6822436e0cd27', executor,
  selectedVariant: selection.selected.variant, selectedSourceSha256: selection.selected.sourceSha256,
  selectedRows: 400, intermediateRows: 1000, archivedRejectedRows: 200, totalCsvRows: records.length,
  outputs: Object.fromEntries(Object.entries(outputs).map(([file, content]) => [file, sha(content)])),
};
fs.writeFileSync(path.join(evidence, 'delta-table-manifest.json'), JSON.stringify(generated, null, 2) + '\n');
console.log(JSON.stringify(generated, null, 2));
