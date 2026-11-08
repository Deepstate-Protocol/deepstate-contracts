import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

const input = process.argv[2];
const output = process.argv[3] || 'docs';
if (!input) throw Error('Usage: node script/build_gas_workup.mjs INPUT_DIRECTORY [OUTPUT_DIRECTORY]');
const read = file => fs.readFileSync(path.join(input, file), 'utf8');
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const manifest = JSON.parse(read('manifest.json'));
const accessManifest = JSON.parse(read('access-manifest.json'));
const expectedCommits = {
  master: 'bf18c54b13123de5ecc3e05dcff6822436e0cd27',
  before: 'fb144e9e7dc7c9e452efc2b22ced86b811124e13',
  after: '096eab28d87debdd472b4e22e65820e2b1b8d523',
};
assert.equal(manifest.executor, 'd3167db683c001c196126c912027437a9cb0bfb9');
assert.equal(manifest.settings.evm, 'cancun');
assert.equal(manifest.settings.isolated, true);
const sourceVerification = JSON.parse(read('source-verification.json'));
assert.equal(sourceVerification.length, 6);
for (const item of sourceVerification) assert.equal(item.ref, expectedCommits[item.name]);
assert.equal(manifest.runs.length, 12, 'six versions, each with release and insertion snapshots');
assert.equal(accessManifest.runs.length, 6, 'six access-list studies');
const compilers = ['solc', 'solar'];
const versions = ['master', 'before', 'after'];
const samples = {};
for (const compiler of compilers) {
  samples[compiler] = {};
  for (const version of versions) {
    const cases = new Map();
    for (const group of ['release', 'insertion']) {
      const run = manifest.runs.find(item => item.label === `${compiler}-${version}-${group}`);
      assert.ok(run, 'missing run');
      assert.equal(run.commit, expectedCommits[version]);
      const log = read(run.log);
      assert.equal(sha(log), run.logSha256, 'benchmark log fingerprint');
      assert.ok(log.includes(`${group === 'release' ? 188 : 12} tests passed, 0 failed, 0 skipped`), 'passing benchmark run');
      const snapshot = read(run.snapshot);
      assert.equal(sha(snapshot), run.snapshotSha256, 'raw snapshot fingerprint');
      const lines = snapshot.trim().split('\n');
      assert.equal(lines.length, group === 'release' ? 188 : 12);
      for (const line of lines) {
        const parsed = /^(\w+):(\w+)\(\) \(gas: (\d+)\)$/.exec(line);
        assert.ok(parsed, `invalid snapshot line: ${line}`);
        const id = `${parsed[1]}:${parsed[2]}()`;
        const gas = Number(parsed[3]);
        assert.ok(Number.isSafeInteger(gas) && gas > 0);
        assert.ok(!cases.has(id), 'duplicate case identity');
        cases.set(id, gas);
      }
    }
    assert.equal(cases.size, 200);
    samples[compiler][version] = cases;
  }
}
const ids = [...samples.solc.after.keys()].sort();
for (const compiler of compilers) {
  for (const version of versions) assert.deepEqual([...samples[compiler][version].keys()].sort(), ids);
}

function attributes(id) {
  const [contract, fn] = id.split(':');
  const repeated = contract === 'RadixMatchingEngineGasTestWideSweep' && !fn.startsWith('testGas_MixedSweep');
  const budget = fn === 'testGas_MixedSweep1024FitsOneMillionGas()';
  const profiles = {
    RadixMatchingEngineGasTest: 'ERC20 / no hooks',
    RadixMatchingEngineHookGasTest: 'ERC20 / top-order hooks',
    RadixMatchingEngineFeeGasTest: 'ERC20 / 100 bps protocol fee',
    RadixMatchingEngineGasTestNativeDirtySpine: 'Native ETH / prior-fill histories',
    DeepstateV1IntegratorFeeGasTest: 'Integrator fees / routing',
    RadixMatchingEngineGasTestWideSweep: 'Mixed-price sweep stress',
    OpportunityGasProbe: 'Insertion diagnostics',
  };
  let category = 'Other';
  if (fn.includes('LargeRandomBook')) category = '5,000 orders per side';
  else if (contract === 'OpportunityGasProbe') category = fn.includes('NonceComb') ? 'Comb insertion' : '16/64-order insertion';
  else if (budget) category = 'Capped-gas functional check';
  else if (fn.includes('MixedSweep')) category = 'Wide mixed-price sweep';
  else if (fn.includes('Pathological') || fn.includes('FullDepth') || fn.includes('MaxValidDepth')) category = 'Pathological/deep tree';
  else if (fn.includes('NonceComb')) category = 'Nonce-comb matching';
  else if (fn.includes('Dirty')) category = 'Previously partially filled book';
  else if (fn.includes('Cancel')) category = 'Cancel / claim';
  else if (fn.includes('FillRest')) category = 'Empty-book rest';
  else if (fn.includes('RestsRemainder')) category = 'Match and rest';
  else if (fn.includes('MatchesSingle')) category = 'Single-maker match';
  else if (fn.includes('Subtree')) category = 'Aggregate matching';
  return { id, contract, fn, profile: profiles[contract], category, repeated, budget,
    duplicateOf: repeated ? `RadixMatchingEngineGasTest:${fn}` : '', summary: !repeated && !budget };
}
const cases = ids.map(attributes);
assert.equal(cases.filter(item => item.repeated).length, 42);
assert.equal(cases.filter(item => item.budget).length, 1);
assert.equal(cases.filter(item => item.summary).length, 157);
for (const item of cases.filter(item => item.repeated)) assert.ok(ids.includes(item.duplicateOf));
const records = compilers.flatMap(compiler => cases.map(item => {
  const master = samples[compiler].master.get(item.id);
  const before = samples[compiler].before.get(item.id);
  const after = samples[compiler].after.get(item.id);
  const delta = (a, b) => item.budget ? { gas: null, percent: null } : { gas: a - b, percent: 100 * (a - b) / b };
  return { ...item, compiler, master, before, after,
    fix: delta(after, before), overall: delta(after, master), preceding: delta(before, master) };
}));
const parseControl = file => new Map(read(file).trim().split('\n').map(line => {
  const match = /^(.*) \(gas: (\d+)\)$/.exec(line);
  assert.ok(match);
  return [match[1], Number(match[2])];
}));
const batchedControl = parseControl('batched-after-large-control.snapshot');
const unbatchedControl = parseControl('unbatched-after-large-control.snapshot');
assert.equal(batchedControl.size, 6);
assert.equal(unbatchedControl.size, 6);
for (const [id, gas] of batchedControl) {
  assert.equal(gas, samples.solc.after.get(id), 'batched control agrees with full run');
  assert.equal(gas - unbatchedControl.get(id), -2463, 'documented harness offset');
}
const primary = records.filter(item => item.compiler === 'solc' && item.summary);
const groups = [...new Set(primary.map(item => item.profile))];
const median = values => {
  const sorted = [...values].sort((a, b) => a - b);
  const i = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[i] : (sorted[i - 1] + sorted[i]) / 2;
};
const number = value => value.toLocaleString('en-US');
const signed = value => `${value > 0 ? '+' : ''}${number(value)}`;
const percent = value => `${value > 0 ? '+' : ''}${value.toFixed(2)}%`;
const change = value => value.gas === null ? 'N/A (outcome changed)' : `${signed(value.gas)} (${percent(value.percent)})`;
const csvCell = value => value === null || value === undefined ? '' : typeof value === 'string'
  ? `"${value.replaceAll('"', '""')}"` : String(value);
const csv = rows => rows.map(row => row.map(csvCell).join(',')).join('\n') + '\n';

const accessRows = [];
const requiredAccess = ['engine keys', 'base keys', 'quote keys', 'total keys', 'cold execution',
  'warm execution', 'execution-only saving', 'access-list intrinsic', 'warm plus intrinsic', 'transaction-net saving'];
for (const run of accessManifest.runs) {
  const expected = manifest.runs.find(item => item.label === `${run.compiler}-${run.version}-release`);
  assert.equal(run.runtimeSha256, expected.runtimeSha256, 'access study engine runtime');
  const raw = read(run.log);
  assert.equal(sha(raw), run.logSha256);
  const log = raw.replace(/\x1b\[[0-9;]*m/g, '');
  const chunks = log.split(/^\[PASS\] /m).slice(1);
  assert.equal(chunks.length, 6);
  for (const chunk of chunks) {
    const fn = /^(testBenchmark_\w+)\(\)/.exec(chunk)?.[1];
    assert.ok(fn);
    const metrics = {};
    for (const match of chunk.matchAll(/^\s+([\w -]+):\s+(-?\d+)\s*$/gm)) metrics[match[1]] = Number(match[2]);
    for (const key of requiredAccess) assert.ok(Number.isSafeInteger(metrics[key]), `missing ${key}`);
    assert.equal(metrics['cold execution'] - metrics['warm plus intrinsic'], metrics['transaction-net saving']);
    accessRows.push({ compiler: run.compiler, version: run.version, fn, ...metrics });
  }
}
assert.equal(accessRows.length, 36);

let report = `# Full Gas Workup\n\n`;
report += `This supersedes the earlier selected-case comparison. It covers every current release benchmark scenario using one fixed comparison harness for all contract versions. **Negative deltas mean cheaper; positive deltas mean more expensive.**\n\n`;
report += `## Scope And Controls\n\n`;
report += `- Master: \`bf18c54b13123de5ecc3e05dcff6822436e0cd27\`.\n`;
report += `- Before the bounded-traversal fix: \`fb144e9e7dc7c9e452efc2b22ced86b811124e13\`.\n`;
report += `- After the fix: \`096eab28d87debdd472b4e22e65820e2b1b8d523\`. No contract implementation is changed by this workup.\n`;
report += `- Six builds: all three versions under solc 0.8.28 and experimental Solar 0.3.0 / Solidity 0.8.38. All execute under Forge \`d3167db683c001c196126c912027437a9cb0bfb9\`, Cancun. Solc uses via-IR and optimizer 200.\n`;
report += `- Same compiled fixtures, mock tokens, calldata, funding, isolated-call settings, and order sequences across all builds. The engine runtime is replaced before any book is populated.\n`;
report += `- **200 test rows per build:** all 188 release benchmark rows plus 12 insertion diagnostics. The 14 dirty-matching probes from the earlier report are now covered by the release suite under base, hook, and fee profiles.\n`;
report += `- **157 completed-operation scenarios** enter summaries: 42 inherited repeats and one capped-gas check are retained in the full tables but excluded from summary statistics.\n`;
report += `- Six access-list studies per build are reported separately: their internally cooled/warmed execution measurements are not the same metric as a Forge snapshot.\n`;
report += `- Large random books contain **5,000 bids and 5,000 asks**, not 5,000 orders total. Setup is unmetered. Each row measures its target operation, not the entire order lifecycle.\n`;
report += `- Large-book population is grouped inside one unmetered outer harness call to avoid repeating expensive EVM isolation during setup. The target operation remains an isolated call. This changes harness overhead: the six solc after-fix controls differ from the existing release snapshot by a constant -2,463 gas. No normalization is applied; all versions below use the same batched harness, and its source patch and control snapshot are included with the raw data.\n`;
report += `- Names containing \`Dirty\` describe the prior-fill history; the new implementation maintains exact summaries. Full-depth combs are synthetic key-depth fixtures.\n\n`;
report += `Raw snapshots and access logs, source/runtime fingerprints, and build metadata are in [gas-workup/raw](gas-workup/raw). The [complete CSV](FULL_GAS_WORKUP.csv) contains absolute and percentage deltas for all three pairwise comparisons. [Compiler-only comparisons](GAS_COMPILER_COMPARISON.csv) hold both implementation and executor fixed. Regenerate this report with \`node script/build_gas_workup.mjs docs/gas-workup/raw docs\`.\n\n`;
report += `Earlier headline numbers can differ slightly because that comparison used an older test dispatcher/helper harness. All columns below are newly measured using one fixed current harness; do not mix columns between reports.\n\n`;
report += `## Profile Summary\n\nMedians are unweighted across benchmark scenarios, not production-volume-weighted costs. Counts classify changes of at least 1,000 gas; smaller changes remain visible in every individual row. There is no defensible single production savings percentage without an operation-frequency distribution.\n\n`;
report += `| Profile | Cases | Median vs Master | Median vs Before Fix | Saves >=1k vs Before | Changes <1k | Adds >=1k vs Before |\n|---|---:|---:|---:|---:|---:|---:|\n`;
for (const group of groups) {
  const rows = primary.filter(item => item.profile === group);
  report += `| ${group} | ${rows.length} | ${percent(median(rows.map(item => item.overall.percent)))} | ${percent(median(rows.map(item => item.fix.percent)))} | ${rows.filter(item => item.fix.gas <= -1000).length} | ${rows.filter(item => Math.abs(item.fix.gas) < 1000).length} | ${rows.filter(item => item.fix.gas >= 1000).length} |\n`;
}
report += `| All independent completed operations | ${primary.length} | ${percent(median(primary.map(item => item.overall.percent)))} | ${percent(median(primary.map(item => item.fix.percent)))} | ${primary.filter(item => item.fix.gas <= -1000).length} | ${primary.filter(item => Math.abs(item.fix.gas) < 1000).length} | ${primary.filter(item => item.fix.gas >= 1000).length} |\n`;

const largeRows = primary.filter(item => item.category === '5,000 orders per side');
assert.equal(largeRows.length, 18);
assert.ok(largeRows.every(item => item.fix.gas > 0));
report += `\n## Assessment\n\n`;
report += `**This is a work-bound/correctness fix with substantial steady-state gas regressions, not a blanket gas optimization.** All 18 large-book operations regress against the pre-fix branch: ${percent(Math.min(...largeRows.map(item => item.fix.percent)))} to ${percent(Math.max(...largeRows.map(item => item.fix.percent)))}. Those ordinary fills and rests matter more to an active book than the sweep headline alone suggests.\n\n`;
report += `The report does not justify a production-wide savings claim or treating the new version as universally cheaper. The 64-level expansion bound and width-independent sweeps are real improvements; normal-book cost deserves another optimization pass before presenting this as a general gas win.\n\n`;
report += `### Next Optimization Targets\n\n`;
report += `1. **Recover early price-prefix divergence in insertion.** [The witness insertion](../src/DeepstateV1.sol#L714) currently descends to a leaf before discovering a new split belongs above an existing branch. Price-only divergence can potentially be detected from the exact cached representative tick, without a descendant-key walk. The different/worse-tick insertion and populated-book rest regressions make this the clearest candidate to test. No savings are assumed here.\n`;
report += `2. **Update mixed quote totals by known deltas.** [Ancestor rebuilding](../src/DeepstateV1.sol#L772) currently recomputes child quote sums after every mutation. Matching already computes the removed quote. Carrying that delta could avoid sibling pricing and some repeated reads, while preserving exact cached quotes. Persistent summary writes would still have a cost.\n`;
report += `3. **Reduce redundant top-order lookups for partial fills.** The matched leaf is already encountered during traversal; carrying its identity could avoid some extra hook lookup work. Keep callback behavior and rounding unchanged.\n\n`;
report += `These are source-based optimization hypotheses, not implemented changes or measured savings. Reintroducing the old mixed-descendant scan would undo the bound fix.\n`;

function table(rows, includeProfile = false) {
  let value = `| ${includeProfile ? 'Profile / ' : ''}Test | Master | Before Fix | After Fix | Delta vs Master | Delta vs Before Fix |\n|---|---:|---:|---:|---:|---:|\n`;
  for (const item of rows) value += `| ${includeProfile ? item.profile + ' / ' : ''}\`${item.fn}\` | ${number(item.master)} | ${number(item.before)} | ${number(item.after)} | ${change(item.overall)} | ${change(item.fix)} |\n`;
  return value;
}
report += `\n## Largest Regressions From The Previous Branch\n\n`;
report += table(primary.filter(item => item.fix.gas > 0).sort((a, b) => b.fix.gas - a.fix.gas).slice(0, 12), true);
report += `\n## Largest Savings From The Previous Branch\n\n`;
report += table(primary.filter(item => item.fix.gas < 0).sort((a, b) => a.fix.gas - b.fix.gas).slice(0, 12), true);
report += `\n## Large Random Books\n\nAll 18 nonduplicate large-book rows are included here. These are target operations against 10,000 resting orders.\n\n`;
report += table(primary.filter(item => item.category === '5,000 orders per side'), true);
report += `\n## Cost Interpretation\n\n`;
report += `- Cached mixed quotes remove descendant scans from full sweeps. This is a structural width-independence improvement, not a reason to expect every operation to get cheaper.\n`;
report += `- Maintaining exact ancestor quantities and quotes adds writes to partial fills and cancellations. Small best-order fills in populated books can therefore regress even when a whole-book sweep becomes dramatically cheaper.\n`;
report += `- Witness insertion removes repeated key-representative walks, but creating/updating mixed quote-cache words has a cost. Same-price comb insertion and divergent-price insertion must be assessed separately.\n`;
report += `- The hook profile uses a no-op notification hook. Stress rows additionally exhaust the 200,000-gas callback allowance. Neither is a measurement of a particular live rewarder contract.\n`;
report += `- Protocol-fee tests configure 100 bps, but many inherited fixtures trade only 1-10 raw token units, so their fee rounds to zero. Those rows do not all pay for a fee-recipient transfer. Dedicated 10,000-unit integrator/protocol cases and larger sweep cases force nonzero fees. Cancellation remains fee-free.\n`;
report += `- Unmetered setup means these rows cannot establish total lifetime cost or a network-wide weighted average. They do not include a live-chain USD fee estimate, calldata compression fees, or RPC costs.\n\n`;
const max = [...primary].sort((a, b) => b.after - a.after)[0];
report += `The highest measured independent solc operation here is **${number(max.after)} gas**, \`${max.id}\`. This is not a proof of the maximum gas of every possible route, hook, token, or state.\n\n`;

report += `## Solar Compiler Delta\n\nSame implementation and same Forge executor; negative means Solar uses less gas. The following includes only the 157 independent completed-operation scenarios.\n\n`;
report += `| Implementation | Median compiler delta | Lowest delta | Highest delta | Cheaper under Solar | More expensive under Solar | Unchanged |\n|---|---:|---:|---:|---:|---:|---:|\n`;
for (const version of versions) {
  const deltas = cases.filter(item => item.summary).map(item => {
    const a = samples.solc[version].get(item.id), b = samples.solar[version].get(item.id);
    return { gas: b - a, percent: 100 * (b - a) / a };
  });
  report += `| ${version} | ${percent(median(deltas.map(item => item.percent)))} | ${percent(Math.min(...deltas.map(item => item.percent)))} | ${percent(Math.max(...deltas.map(item => item.percent)))} | ${deltas.filter(item => item.gas < 0).length} | ${deltas.filter(item => item.gas > 0).length} | ${deltas.filter(item => item.gas === 0).length} |\n`;
}
report += `\nSolar remains experimental; its integer-gas savings are separate from the algorithm change and do not by themselves establish production compiler safety.\n\n`;
report += `## Capped-Gas Functional Check\n\nThe 1,024-price sweep is also submitted with a one-million-gas call allowance. Master and the pre-fix branch exhaust that allowance and roll back; the fixed branch succeeds. Legacy numbers are therefore censored failure-path measurements, **not** completed-operation costs. No savings percentage is calculated for this row.\n\n`;
report += `| Compiler | Master (failure) | Before Fix (failure) | After Fix (success) |\n|---|---:|---:|---:|\n`;
for (const compiler of compilers) {
  const row = records.find(item => item.compiler === compiler && item.budget);
  report += `| ${compiler} | ${number(row.master)} | ${number(row.before)} | ${number(row.after)} |\n`;
}
report += `\n## Access Lists\n\nThese are the existing predictive access-list studies, run in a separate fixed harness with explicit cold/warm slot preparation. All touched engine/token keys are warmed; the harness charges 2,400 gas per address and 1,900 per storage key. This is a comparison of that complete predicted list, not an optimized minimal list. **Positive net saving means the list helps; negative means it costs more than it saves.**\n\n`;
for (const compiler of compilers) {
  report += `### ${compiler}\n\n| Test | Master Net Saving | Before Net Saving | After Net Saving | After Cold Execution | After Warm + Intrinsic | After Keys |\n|---|---:|---:|---:|---:|---:|---:|\n`;
  const afterRows = accessRows.filter(item => item.compiler === compiler && item.version === 'after').sort((a, b) => a.fn.localeCompare(b.fn));
  for (const row of afterRows) {
    const master = accessRows.find(item => item.compiler === compiler && item.version === 'master' && item.fn === row.fn);
    const before = accessRows.find(item => item.compiler === compiler && item.version === 'before' && item.fn === row.fn);
    assert.ok(master && before);
    report += `| \`${row.fn}()\` | ${signed(master['transaction-net saving'])} | ${signed(before['transaction-net saving'])} | ${signed(row['transaction-net saving'])} | ${number(row['cold execution'])} | ${number(row['warm plus intrinsic'])} | ${row['total keys']} |\n`;
  }
  report += '\n';
}
report += `All 36 cold/warm/key/intrinsic measurements are in [GAS_ACCESS_LIST_WORKUP.csv](GAS_ACCESS_LIST_WORKUP.csv). Do not compare the internal gas-left measurements directly with snapshot totals above.\n\n`;

report += `## Every Test Row\n\nThe following tables retain every one of the 200 rows under both compilers. All repeated rows are labeled and excluded from the summary. Raw function identity, profile, category, outcomes, and all deltas are in the CSV.\n\n`;
for (const compiler of compilers) {
  report += `### ${compiler} / Full Matrix\n\n`;
  for (const group of groups) {
    report += `#### ${group}\n\n`;
    report += table(records.filter(item => item.compiler === compiler && item.profile === group && !item.repeated));
    report += '\n';
  }
  report += `<details>\n<summary>${compiler}: 42 inherited repeat rows, excluded from summary</summary>\n\n`;
  report += table(records.filter(item => item.compiler === compiler && item.repeated));
  report += '\n</details>\n\n';
}

const matrixHeader = ['compiler', 'case', 'profile', 'category', 'duplicate_of', 'included_in_summary',
  'master_gas', 'before_gas', 'after_gas', 'master_outcome', 'before_outcome', 'after_outcome',
  'before_vs_master_gas', 'before_vs_master_percent', 'after_vs_master_gas', 'after_vs_master_percent',
  'after_vs_before_gas', 'after_vs_before_percent'];
const matrix = [matrixHeader, ...records.map(item => [item.compiler, item.id, item.profile, item.category,
  item.duplicateOf, item.summary, item.master, item.before, item.after,
  item.budget ? 'gas-limit failure' : 'success', item.budget ? 'gas-limit failure' : 'success', 'success',
  item.preceding.gas, item.preceding.percent, item.overall.gas, item.overall.percent, item.fix.gas, item.fix.percent])];
const compilerHeader = ['case', 'profile', 'duplicate_of', 'included_in_summary', ...versions.flatMap(version =>
  [`${version}_solc_gas`, `${version}_solar_gas`, `${version}_solar_delta`, `${version}_solar_percent`])];
const compilerRows = [compilerHeader, ...cases.map(item => [item.id, item.profile, item.duplicateOf, item.summary,
  ...versions.flatMap(version => {
    const solc = samples.solc[version].get(item.id), solar = samples.solar[version].get(item.id);
    return [solc, solar, item.budget ? null : solar - solc, item.budget ? null : 100 * (solar - solc) / solc];
  })])];
const accessHeader = ['compiler', 'version', 'case', ...requiredAccess];
const accessCsv = [accessHeader, ...accessRows.map(item => [item.compiler, item.version, item.fn + '()', ...requiredAccess.map(key => item[key])])];

fs.mkdirSync(output, { recursive: true });
fs.writeFileSync(path.join(output, 'FULL_GAS_WORKUP.md'), report.trimEnd() + '\n');
fs.writeFileSync(path.join(output, 'FULL_GAS_WORKUP.csv'), csv(matrix));
fs.writeFileSync(path.join(output, 'GAS_COMPILER_COMPARISON.csv'), csv(compilerRows));
fs.writeFileSync(path.join(output, 'GAS_ACCESS_LIST_WORKUP.csv'), csv(accessCsv));
console.log(JSON.stringify({ testRowsPerBuild: ids.length, summaryScenarios: primary.length,
  compilerVersionMatrices: records.length, accessStudies: accessRows.length,
  highestAfter: { case: max.id, gas: max.after } }, null, 2));
