import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';

const root=process.argv[2]??'/tmp/deepstate-common-paths-20261108';
const output=process.argv[3]??'docs/common-path-gas-workup';
const variants=['00-baseline','01-noncrossing','02-cancel-successor'];
const sha=x=>crypto.createHash('sha256').update(x).digest('hex');
const read=p=>fs.readFileSync(p,'utf8');
const parse=p=>new Map(read(p).trim().split('\n').map(line=>{
 const m=/^(.*) \(gas: (\d+)\)$/.exec(line);assert.ok(m,line);return[m[1],Number(m[2])];
}));
fs.mkdirSync(path.join(output,'raw'),{recursive:true});
const fingerprints={};
function capture(name,bytes){fs.writeFileSync(path.join(output,name),bytes);fingerprints[name]=sha(bytes);}
const datasets=variants.map(variant=>{
 const source=fs.readFileSync(path.join(root,'variants',`${variant}.sol`));
 const manifest=JSON.parse(read(path.join(root,'results',`${variant}-manifest.json`)));
 assert.equal(manifest.sourceSha256,sha(source));
 assert.equal(manifest.compiler,'0.8.38+commit.e7a91fc7.solar.0.3.0');
 assert.equal(manifest.executor,'d3167db683c001c196126c912027437a9cb0bfb9');
 assert.equal(manifest.runs.length,3);
 const cases=new Map();
 for(const run of manifest.runs){
  for(const type of ['log','snapshot']){
   const bytes=fs.readFileSync(path.join(root,'results',run[type]));
   assert.equal(sha(bytes),run[`${type}Sha256`]);capture(`raw/${run[type]}`,bytes);
  }
  assert.match(read(path.join(root,'results',run.log)),new RegExp(`${run.count} tests passed, 0 failed, 0 skipped`));
  for(const[key,gas]of parse(path.join(root,'results',run.snapshot))){assert.ok(!cases.has(key));cases.set(key,gas);}
 }
 assert.equal(cases.size,223);
 capture(`raw/${variant}.sol.txt`,source);
 capture(`raw/${variant}-manifest.json`,JSON.stringify(manifest,null,2)+'\n');
 return{variant,manifest,cases};
});
assert.equal(datasets[0].manifest.sourceSha256,'ce755182dd007c3c578b860782ef3c9e45de2aae3287a3a4ef03fede6138b0c7');
assert.equal(datasets.at(-1).manifest.sourceSha256,sha(fs.readFileSync('src/DeepstateV1.sol')));
const controlFile=path.join(output,'raw/baseline-control.json');
const control=fs.existsSync(controlFile)?JSON.parse(read(controlFile)):{
 sourceSha256:datasets[0].manifest.sourceSha256,
 rows:JSON.parse(read('docs/robinhood-gas-comparison/summary.json')).rows.map(row=>({test:row.test,gas:row.optimizedGas})),
};
assert.equal(control.sourceSha256,datasets[0].manifest.sourceSha256);
assert.equal(control.rows.length,223);
assert.equal(new Set(control.rows.map(row=>row.test)).size,223);
for(const row of control.rows)assert.equal(datasets[0].cases.get(row.test),row.gas,`Baseline control ${row.test}`);
capture('raw/baseline-control.json',JSON.stringify(control,null,2)+'\n');
const keys=[...datasets[0].cases.keys()].sort();
for(const d of datasets)assert.deepEqual([...d.cases.keys()].sort(),keys);
function states(variant){
 const results={};let current;
 for(const line of read(path.join(root,'results',`${variant}-production.log`)).split('\n')){
  const test=/^\[PASS\] (testProduction_\S+)/.exec(line);if(test)current=test[1];
  const state=/economic state: (0x[0-9a-f]+)/.exec(line);if(state)results[current]=state[1];
 }
 assert.equal(Object.keys(results).length,23);return results;
}
for(const variant of variants.slice(1))assert.deepEqual(states(variants[0]),states(variant));
const validationFile=path.join(root,'results','validation-manifest.json');
let validation;
if(fs.existsSync(validationFile)){
 const v=JSON.parse(read(validationFile));
 if(v.runs.length===6&&v.compatibility){
  assert.equal(v.sourceSha256,datasets.at(-1).manifest.sourceSha256);
  assert.equal(v.compatibility.publicAbiEqual,true);assert.equal(v.compatibility.storageLayoutEqual,true);
  for(const run of v.runs){
   const bytes=fs.readFileSync(path.join(root,'results',run.log));
   assert.equal(sha(bytes),run.sha256);assert.equal(run.status,0);capture(`raw/${run.log}`,bytes);
  }
  capture('raw/validation-manifest.json',JSON.stringify(v,null,2)+'\n');
  validation={sourceSha256:v.sourceSha256,publicAbiEqual:true,persistentStorageLayoutEqual:true};
 }
}
if(process.env.REQUIRE_VALIDATION==='1')assert.ok(validation,'Complete validation is required');
const integer=x=>x.toLocaleString('en-US');
const signed=x=>`${x>0?'+':''}${integer(x)}`;
const percent=(delta,before)=>`${delta>0?'+':''}${(100*delta/before).toFixed(2)}%`;
const rows=[];
for(const key of keys){
 const baseline=datasets[0].cases.get(key);
 for(let stage=1;stage<datasets.length;stage++){
  const previous=datasets[stage-1].cases.get(key),candidate=datasets[stage].cases.get(key);
  rows.push({stage,variant:variants[stage],test:key,baseline,previous,candidate,
   deltaBaseline:candidate-baseline,percentBaseline:100*(candidate-baseline)/baseline,
   deltaPrevious:candidate-previous,percentPrevious:100*(candidate-previous)/previous,
   notes:key.includes('FitsOneMillionGas')?'functional budget check; both capped calls succeed':
    key.startsWith('RadixMatchingEngineGasTestWideSweep:')&&!key.includes('MixedSweep')?'inherited repetition':''});
 }
}
const orderedProduction=[
 'ReplacePair','ReplaceBid','ReplaceAsk','PartialCancelReplaceBid','PartialCancelReplaceAsk',
 'MatchFullBid','MatchFullAsk','MatchPartialBid','MatchPartialAsk','MatchCancelReplacePair',
 'CancelUnfilledBid','CancelUnfilledAsk','CancelPartialBid','CancelPartialAsk',
 'RestBidAtBest','RestAskAtBest','RestBidImproved','RestAskImproved',
 'ClaimFilledBid','ClaimFilledAsk','MatchAndRestBid','MatchAndRestAsk','ClaimAndCancelPair',
].map(x=>`ProductionCategoriesTest:testProduction_${x}()`);
assert.deepEqual(orderedProduction.toSorted(),keys.filter(x=>x.startsWith('ProductionCategoriesTest:')));
const groups=[['Production Categories',['ProductionCategoriesTest']],['Core',['RadixMatchingEngineGasTest']],
 ['Hooks',['RadixMatchingEngineHookGasTest']],['Protocol Fee',['RadixMatchingEngineFeeGasTest']],
 ['Wide Sweep',['RadixMatchingEngineGasTestWideSweep']],
 ['Additional Cases',['DeepstateV1IntegratorFeeGasTest','OpportunityGasProbe','RadixMatchingEngineGasTestNativeDirtySpine']]];
const tables={};
const combinedTables={};
for(const[label,contracts]of groups){
 const selected=label==='Production Categories'?orderedProduction:keys.filter(k=>contracts.includes(k.split(':')[0]));
 const lines=[`**${label}**`,'| Test | Baseline b4164fe | Change 1 | Change 2 | Final Delta Gas | Final Delta % |',
  '|---|---:|---:|---:|---:|---:|'];
 const combinedLines=[`**${label}**`,'| Test | Baseline b4164fe | Both Changes | Delta Gas | Delta % |',
  '|---|---:|---:|---:|---:|'];
 for(const key of selected){
  const[contract,test]=key.split(':');
  const name=(contracts.length>1?`${contract}:`:'')+test.replace(/^(testGas_|testProduction_|testOpportunity_)/,'').replace(/\(\)$/,'');
  const values=datasets.map(x=>x.cases.get(key));const delta=values[2]-values[0];
  lines.push(`| ${name} | ${values.map(integer).join(' | ')} | ${signed(delta)} | ${percent(delta,values[0])} |`);
  combinedLines.push(`| ${name} | ${integer(values[0])} | ${integer(values[2])} | ${signed(delta)} | ${percent(delta,values[0])} |`);
 }
 tables[label]=lines.join('\n');
 combinedTables[label]=combinedLines.join('\n');
}
const intro=['# Common-Path Gas Workup','',
 'Solar 0.3.0 / Solidity 0.8.38; Cancun; optimizer 200; frozen fixture; executor d3167db.',
 'Baseline is b4164fe, not the deployed Robinhood source. All 223 baseline values reproduce the preceding comparison exactly.',
 'Change 1 reuses the hook-required best leaf to reject non-crossing matching and avoids match-buffer allocation on empty/non-crossing hooked sides.',
 'Change 2 captures a top cancellation successor at its first collapsed parent, only when hooks require that successor.',
 'Changes are cumulative. Every measured row and regression remains visible; no thresholds filter the results.',
 'The production group is ordered by the previously observed post-DGP3 category frequency, not the frequency of individual bid/ask variants.',
 'Its fixture uses the same 222 indexed orders plus two test quotes, mock ERC20s and a counter hook, not full V3 rewarder execution.',
 'All 23 economic-state fingerprints agree across baseline and both candidates.',
 'Forty-two Wide Sweep rows are inherited repetitions. The budget check is functional, not an independent workload; both calls succeed.',
 'No production-weighted overall savings percentage is claimed.',
 validation?'Final functional validation, invariant campaign, bounds tests, SMT checks, ABI and persistent layout checks completed.':
  'Final validation has not completed. Do not treat these measurements as passing release gates.',
 'The existing default-build stack-depth blocker is recorded in raw/prepush-formal-build.log. Fresh coverage, Slither and Halmos have not passed.',''];
capture('GAS_TABLES.md',intro.join('\n')+Object.values(tables).join('\n\n')+'\n');
capture('FINAL_GAS_TABLES.md',intro.join('\n')+
 'The final combined implementation includes both changes; deltas below are against b4164fe.\n\n'+
 Object.values(combinedTables).join('\n\n')+'\n');
const staged=['# Per-Stage Deltas',''];
for(let stage=1;stage<datasets.length;stage++){
 staged.push(`## Change ${stage}`,'','| Test | Baseline | Previous | Candidate | Delta vs Baseline | % vs Baseline | Delta vs Previous | % vs Previous | Notes |',
  '|---|---:|---:|---:|---:|---:|---:|---:|---|');
 for(const r of rows.filter(r=>r.stage===stage))staged.push(`| ${r.test} | ${integer(r.baseline)} | ${integer(r.previous)} | ${integer(r.candidate)} | ${signed(r.deltaBaseline)} | ${percent(r.deltaBaseline,r.baseline)} | ${signed(r.deltaPrevious)} | ${percent(r.deltaPrevious,r.previous)} | ${r.notes||'-'} |`);
 staged.push('');
}
capture('STAGE_DELTAS.md',staged.join('\n').trimEnd()+'\n');
capture('GAS_DELTAS.csv',[['stage','variant','test','baseline_gas','previous_gas','candidate_gas','delta_baseline_gas','delta_baseline_percent','delta_previous_gas','delta_previous_percent','notes'],
 ...rows.map(r=>[r.stage,r.variant,r.test,r.baseline,r.previous,r.candidate,r.deltaBaseline,r.percentBaseline,r.deltaPrevious,r.percentPrevious,r.notes])]
 .map(row=>row.map(x=>JSON.stringify(x)).join(',')).join('\n')+'\n');
capture('FINAL_GAS_DELTAS.csv',[['test','baseline_gas','combined_gas','delta_gas','delta_percent','notes'],
 ...rows.filter(r=>r.stage===2).map(r=>[r.test,r.baseline,r.candidate,r.deltaBaseline,r.percentBaseline,r.notes])]
 .map(row=>row.map(x=>JSON.stringify(x)).join(',')).join('\n')+'\n');
for(let i=1;i<variants.length;i++){
 const result=spawnSync('diff',['-u','--label','a/src/DeepstateV1.sol','--label','b/src/DeepstateV1.sol',
  path.join(root,'variants',`${variants[i-1]}.sol`),path.join(root,'variants',`${variants[i]}.sol`)],{encoding:'utf8'});
 assert.equal(result.status,1);capture(`raw/${variants[i]}.patch`,result.stdout);
}
capture('raw/ProductionCategories.t.sol.txt',fs.readFileSync('/tmp/deepstate-full-gas-workup-20261107/fixture/test/ProductionCategories.t.sol'));
capture('raw/open-snapshot.json',fs.readFileSync('/tmp/deepstate-robinhood-comparison-20261108/open-snapshot.json'));
capture('raw/study.mjs',fs.readFileSync(path.join(root,'study.mjs')));
const failedBuild=path.join(root,'results','prepush-formal-build.log');
if(fs.existsSync(failedBuild))capture('raw/prepush-formal-build.log',fs.readFileSync(failedBuild));
const counts=values=>({cheaper:values.filter(v=>v<0).length,unchanged:values.filter(v=>v===0).length,
 dearer:values.filter(v=>v>0).length,largestSaving:Math.min(...values),largestRegression:Math.max(...values)});
const summary=variants.slice(1).map((variant,i)=>({variant,baseline:counts(rows.filter(r=>r.stage===i+1).map(r=>r.deltaBaseline)),
 previous:counts(rows.filter(r=>r.stage===i+1).map(r=>r.deltaPrevious))}));
capture('summary.json',JSON.stringify({casesPerStage:223,summary,rows,economicStateFingerprintsEqual:true,validation},null,2)+'\n');
capture('manifest.json',JSON.stringify({baseline:'b4164fef1984e431ec4fe1c1741b3a958f64ecf8',
 stages:datasets.map(d=>d.manifest),validation,fingerprints},null,2)+'\n');
fs.writeFileSync(path.join(root,'tables.json'),JSON.stringify(tables));
fs.writeFileSync(path.join(root,'combined-tables.json'),JSON.stringify(combinedTables));
console.log(JSON.stringify({casesPerStage:223,summary,validation:validation??'incomplete'},null,2));
