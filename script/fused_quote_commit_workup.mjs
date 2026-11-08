import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {spawnSync} from 'node:child_process';

const root=process.env.WORKUP_ROOT??'/tmp/deepstate-fused-accepted-20261108';
const fixture=process.env.GAS_FIXTURE??'/tmp/deepstate-full-gas-workup-20261107/fixture';
const forge=process.env.SOLAR_FORGE??'/tmp/deepstate-solar-gas-20261107/toolchain/forge';
const executor=process.env.GAS_FORGE??'/tmp/deepstate-rebase-pr34-20261107/toolchain/forge';
const baselineArtifact=process.env.BASELINE_ARTIFACT??'/tmp/deepstate-common-paths-20261108/02-cancel-successor-artifact.json';
const output='docs/fused-quote-accepted';
const common='docs/common-path-gas-workup/raw';
const read=p=>fs.readFileSync(p,'utf8');
const sha=x=>crypto.createHash('sha256').update(x).digest('hex');
const env={...process.env,PATH:`${path.dirname(forge)}:${process.env.PATH}`,FOUNDRY_PROFILE:'solar',
 FOUNDRY_DISABLE_NIGHTLY_WARNING:'1',FOUNDRY_INVARIANT_RUNS:'256',FOUNDRY_INVARIANT_DEPTH:'64'};
for(const dir of ['results','variants'])fs.mkdirSync(path.join(root,dir),{recursive:true});
const control=JSON.parse(read(`${common}/02-cancel-successor-manifest.json`));
const manifestFile=path.join(root,'measurement.json'),validationFile=path.join(root,'validation.json');
const parse=p=>new Map(read(p).trim().split('\n').map(line=>{
 const m=/^(.*) \(gas: (\d+)\)$/.exec(line);assert.ok(m,line);return[m[1],Number(m[2])];
}));
function execute(name,command,args,options={}){
 const log=`${name}.log`,file=path.join(root,'results',log),fd=fs.openSync(file,'w');
 console.log(`START ${name}`);
 const run=spawnSync(command,args,{env,...options,stdio:['ignore',fd,fd]});fs.closeSync(fd);
 const text=read(file);
 if(run.status!==0){console.error(text.slice(-10000));throw new Error(`${name} failed: ${run.status}`);}
 console.log(`END ${name}: ${text.split('\n').filter(x=>/^Ran .*test suite|^protocol proof/.test(x)).join(' ')}`);
 return{command,args,log,sha256:sha(text),status:run.status};
}
function measure(){
 const before=fs.readFileSync(`${common}/02-cancel-successor.sol.txt`),after=fs.readFileSync('src/DeepstateV1.sol');
 assert.equal(sha(before),control.sourceSha256);
 assert.ok(!after.toString().includes('function cancelAndFill'),'Unapproved API entered the commit');
 fs.writeFileSync(path.join(root,'variants/baseline.sol'),before);
 fs.writeFileSync(path.join(root,'variants/candidate.sol'),after);
 execute('solar-build',forge,['build','src/DeepstateV1.sol','--no-dynamic-test-linking','--out','out-fused-accepted','--cache-path','cache-fused-accepted','--no-lint']);
 const artifacts={baseline:JSON.parse(read(baselineArtifact)),candidate:JSON.parse(read('out-fused-accepted/DeepstateV1.sol/DeepstateV1.json'))};
 const metadata={};
 const manifest={baselineCommit:'83ce527995e1e44932de281d5d732ed1afa80204',compiler:control.compiler,executor:control.executor,variants:{},runs:[]};
 for(const[variant,artifact]of Object.entries(artifacts)){
  const source=fs.readFileSync(path.join(root,`variants/${variant}.sol`));
  metadata[variant]=typeof artifact.metadata==='string'?JSON.parse(artifact.metadata):artifact.metadata;
  assert.equal(metadata[variant].compiler.version,'0.8.38+commit.e7a91fc7.solar.0.3.0');
  manifest.variants[variant]={sourceSha256:sha(source),runtimeSha256:sha(Buffer.from(artifact.deployedBytecode.object.replace(/^0x/,''),'hex'))};
  fs.writeFileSync(path.join(root,`${variant}-artifact.json`),JSON.stringify(artifact));
 }
 assert.deepEqual(artifacts.candidate.abi,artifacts.baseline.abi,'Public ABI changed');
 assert.deepEqual(metadata.candidate.settings,metadata.baseline.settings);
 const imported=m=>Object.fromEntries(Object.entries(m.sources).filter(([k])=>k!=='src/DeepstateV1.sol').map(([k,v])=>[k,v.keccak256]));
 assert.deepEqual(imported(metadata.candidate),imported(metadata.baseline));
 manifest.settings=metadata.candidate.settings;manifest.imports=imported(metadata.candidate);
 const require=createRequire(process.env.VIEM_PACKAGE_JSON??'/Users/dangerousfood/.codex/worktrees/shared-indexer-rpc/nigiri-webapp/package.json');
 const {encodeAbiParameters,parseAbiParameters,keccak256}=require('viem');
 for(const variant of ['baseline','candidate'])assert.equal(metadata[variant].sources['src/DeepstateV1.sol'].keccak256,
  keccak256('0x'+fs.readFileSync(path.join(root,`variants/${variant}.sol`)).toString('hex')));
 const pinned=JSON.parse(read('docs/gas-workup/raw/manifest.json'));
 manifest.fixtures={...pinned.fixtures,'test/ProductionCategories.t.sol':control.fixtureSha256};
 for(const[file,hash]of Object.entries(manifest.fixtures))assert.equal(sha(fs.readFileSync(path.join(fixture,file))),hash,file);
 const snapshot=JSON.parse(read(`${common}/open-snapshot.json`));
 const encoded=encodeAbiParameters(parseAbiParameters('int32[], uint160[], uint32[], bool[]'),
  [snapshot.ticks,snapshot.quantities.map(BigInt),snapshot.nonces.map(Number),snapshot.bids]);
 for(const run of control.runs){
  const name=`baseline-${run.group}`;
  for(const kind of ['log','snapshot']){
   const bytes=fs.readFileSync(`${common}/${run[kind]}`);assert.equal(sha(bytes),run[`${kind}Sha256`]);
   fs.writeFileSync(path.join(root,'results',`${name}.${kind}`),bytes);
  }
  manifest.runs.push({...run,name,variant:'baseline',reusedValidatedBaseline:true,log:`${name}.log`,snapshot:`${name}.snapshot`});
 }
 const save=()=>fs.writeFileSync(manifestFile,JSON.stringify(manifest,null,2)+'\n');save();
 for(const group of ['production','insertion','release']){
  const filters=group==='release'?['--match-contract','(RadixMatchingEngine(Gas|HookGas|FeeGas)Test|DeepstateV1IntegratorFeeGasTest)']:
   group==='insertion'?['--match-contract','^OpportunityGasProbe$','--match-test','^testOpportunity_']:
   ['--match-contract','^ProductionCategoriesTest$','--match-test','^testProduction_','-vv'];
  const name=`candidate-${group}`,snapshot=`${name}.snapshot`;
  const run=execute(name,executor,['snapshot',...filters,'--threads','4','--isolate','--snap',path.join(root,'results',snapshot)],
   {cwd:fixture,env:{...process.env,VARIANT_BYTECODE:artifacts.candidate.deployedBytecode.object,EXACT_SUMMARIES:'true',PRODUCTION_SNAPSHOT:encoded,FOUNDRY_DISABLE_NIGHTLY_WARNING:'1'}});
  const count=group==='release'?188:group==='insertion'?12:23;
  assert.match(read(path.join(root,'results',run.log)),new RegExp(`${count} tests passed, 0 failed, 0 skipped`));
  assert.equal(parse(path.join(root,'results',snapshot)).size,count);
  manifest.runs.push({...run,name,variant:'candidate',group,count,logSha256:run.sha256,snapshot,snapshotSha256:sha(read(path.join(root,'results',snapshot)))});save();
 }
 assert.equal(sha(fs.readFileSync('src/DeepstateV1.sol')),manifest.variants.candidate.sourceSha256);
}
function validate(){
 const files=['src/DeepstateV1.sol','src/libraries/TickMath32.sol','src/interfaces/IHook.sol','test/FusedQuote.t.sol','test/QuoteMath.sol','script/prove_protocol.py'];
 const hashes=Object.fromEntries(files.map(file=>[file,sha(fs.readFileSync(file))]));
 const args=['--no-dynamic-test-linking','--out','out-fused-check','--cache-path','cache-fused-check','--threads','4'];
 const groups=[
  ['focused',forge,['test',...args,'--match-contract','^FusedQuoteTest$','--fuzz-runs','4096']],
  ['behavior',forge,['test',...args,'--no-match-contract','(Invariant|Gas|AccessList|BoundedTraversal)','--fuzz-runs','256']],
  ['bounds',forge,['test',...args,'--match-contract','^BoundedTraversalTest$','--match-test','^(test_|testFuzz_)','--fuzz-runs','256']],
  ['invariants',forge,['test',...args,'--match-contract','(RadixMatchingEngineInvariantTest|DeepstateV1MultiPoolInvariantTest|DeepstateV1NativeETHInvariantTest)','--match-test','invariant_.*']],
  ['release-snapshot',forge,['snapshot',...args,'--isolate','--match-contract','(RadixMatchingEngine(Gas|HookGas|FeeGas)Test|DeepstateV1IntegratorFeeGasTest)','--snap','.gas-snapshot.solar']],
  ['smt','python3',['script/prove_protocol.py']],
  ['format',forge,['fmt','--check',...files.filter(x=>x.endsWith('.sol'))]],
 ];
 const manifest={hashes,runs:[]};
 for(const[group,command,commandArgs]of groups){
  manifest.runs.push({...execute(`validation-${group}`,command,commandArgs),group});
  fs.writeFileSync(validationFile,JSON.stringify(manifest,null,2)+'\n');
 }
 const baseline=JSON.parse(read(path.join(root,'baseline-artifact.json')));
 const candidate=JSON.parse(read('out-fused-check/DeepstateV1.sol/DeepstateV1.json'));
 assert.deepEqual(candidate.abi,baseline.abi,'Public ABI changed');
 const inspect=spawnSync(forge,['inspect','src/DeepstateV1.sol:DeepstateV1','storageLayout','--json',
  '--out','out-fused-layout','--cache-path','cache-fused-layout'],{env,encoding:'utf8'});
 assert.equal(inspect.status,0,inspect.stderr);
 const layout=JSON.parse(inspect.stdout),old=JSON.parse(read(`${common}/validation-manifest.json`)).compatibility.layout;
 function canonical(layout){
  const type=id=>{const x=layout.types[id];return{label:x.label,encoding:x.encoding,bytes:x.numberOfBytes,
   ...(x.key?{key:type(x.key),value:type(x.value)}:{}),...(x.members?{members:x.members.map(member)}:{})};};
  const member=x=>({label:x.label,slot:x.slot,offset:x.offset,type:type(x.type)});return layout.storage.map(member);
 }
 assert.deepEqual(canonical(layout),canonical(old),'Persistent layout changed');
 for(const[file,hash]of Object.entries(hashes))assert.equal(sha(fs.readFileSync(file)),hash,file);
 manifest.compatibility={publicAbiEqual:true,persistentStorageLayoutEqual:true,layout};
 fs.writeFileSync(validationFile,JSON.stringify(manifest,null,2)+'\n');
}
function report(){
 const measurement=JSON.parse(read(manifestFile)),validation=JSON.parse(read(validationFile));
 assert.equal(measurement.runs.length,6);assert.equal(validation.runs.length,7);assert.ok(validation.compatibility);
 assert.equal(validation.hashes['src/DeepstateV1.sol'],measurement.variants.candidate.sourceSha256);
 for(const[file,hash]of Object.entries(validation.hashes))assert.equal(sha(fs.readFileSync(file)),hash,file);
 fs.mkdirSync(path.join(output,'raw'),{recursive:true});const fingerprints={};
 const capture=(name,bytes)=>{fs.writeFileSync(path.join(output,name),bytes);fingerprints[name]=sha(bytes);};
 const datasets={};
 for(const run of measurement.runs){
  for(const kind of ['log','snapshot']){
   const bytes=fs.readFileSync(path.join(root,'results',run[kind]));assert.equal(sha(bytes),run[`${kind}Sha256`]);capture(`raw/${run[kind]}`,bytes);
  }
  assert.match(read(path.join(root,'results',run.log)),new RegExp(`${run.count} tests passed, 0 failed, 0 skipped`));
  datasets[run.name]=parse(path.join(root,'results',run.snapshot));assert.equal(datasets[run.name].size,run.count);
 }
 for(const run of validation.runs){const bytes=fs.readFileSync(path.join(root,'results',run.log));assert.equal(sha(bytes),run.sha256);assert.equal(run.status,0);capture(`raw/${run.log}`,bytes);}
 for(const[file,hash]of Object.entries(validation.hashes)){const bytes=fs.readFileSync(file);assert.equal(sha(bytes),hash);capture(`raw/${path.basename(file)}.txt`,bytes);}
 for(const variant of ['baseline','candidate']){const bytes=fs.readFileSync(path.join(root,`variants/${variant}.sol`));assert.equal(sha(bytes),measurement.variants[variant].sourceSha256);capture(`raw/${variant}.sol.txt`,bytes);}
 const rows=[];
 for(const group of ['production','insertion','release']){
  const before=datasets[`baseline-${group}`],after=datasets[`candidate-${group}`];assert.deepEqual([...before.keys()].sort(),[...after.keys()].sort());
  for(const[test,baseline]of before){const candidate=after.get(test),delta=candidate-baseline;rows.push({group,test,baseline,candidate,delta,percent:100*delta/baseline,
   notes:test.includes('FitsOneMillionGas')?'functional budget check; capped call succeeds':test.startsWith('RadixMatchingEngineGasTestWideSweep:')&&!test.includes('MixedSweep')?'inherited repetition':''});}
 }
 assert.equal(rows.length,223);
 function states(name){const values={};let current;for(const line of read(path.join(root,'results',`${name}.log`)).split('\n')){
  const test=/^\[PASS\] (testProduction_\S+)/.exec(line);if(test)current=test[1];const state=/economic state: (0x[0-9a-f]+)/.exec(line);if(state)values[current]=state[1];}return values;}
 const statesBefore=states('baseline-production');assert.equal(Object.keys(statesBefore).length,23);assert.deepEqual(states('candidate-production'),statesBefore);
 const integer=x=>x.toLocaleString('en-US'),signed=x=>`${x>0?'+':''}${integer(x)}`,percent=(d,b)=>`${d>0?'+':''}${(100*d/b).toFixed(2)}%`;
 const priority=['ReplacePair','ReplaceBid','ReplaceAsk','PartialCancelReplaceBid','PartialCancelReplaceAsk','MatchFullBid','MatchFullAsk','MatchPartialBid','MatchPartialAsk','MatchCancelReplacePair','CancelUnfilledBid','CancelUnfilledAsk','CancelPartialBid','CancelPartialAsk','RestBidAtBest','RestAskAtBest','RestBidImproved','RestAskImproved','ClaimFilledBid','ClaimFilledAsk','MatchAndRestBid','MatchAndRestAsk','ClaimAndCancelPair'];
 const groups=[['Production',r=>r.group==='production'],['Core',r=>r.test.startsWith('RadixMatchingEngineGasTest:')],['Hooks',r=>r.test.startsWith('RadixMatchingEngineHookGasTest:')],['Protocol Fee',r=>r.test.startsWith('RadixMatchingEngineFeeGasTest:')],['Wide Sweep',r=>r.test.startsWith('RadixMatchingEngineGasTestWideSweep:')],['Additional Cases',r=>r.test.startsWith('DeepstateV1IntegratorFeeGasTest:')||r.group==='insertion'||r.test.startsWith('RadixMatchingEngineGasTestNativeDirtySpine:')]];
 const tables={};let count=0;
 for(const[label,filter]of groups){let selected=rows.filter(filter);if(label==='Production')selected=selected.toSorted((a,b)=>priority.indexOf(a.test.split('testProduction_')[1].replace('()',''))-priority.indexOf(b.test.split('testProduction_')[1].replace('()','')));
  const lines=[`**${label}**`,'| Test | Baseline 83ce527 | Fused | Delta Gas | Delta % |','|---|---:|---:|---:|---:|'];
  for(const r of selected){const[contract,test]=r.test.split(':');lines.push(`| ${label==='Additional Cases'?contract+':':''}${test.replace(/^(testGas_|testProduction_|testOpportunity_)/,'').replace(/\(\)$/,'')} | ${integer(r.baseline)} | ${integer(r.candidate)} | ${signed(r.delta)} | ${percent(r.delta,r.baseline)} |`);}
  count+=selected.length;tables[label]=lines.join('\n');
 }
 assert.equal(count,223);
 const intro=['# Accepted Fused-Quote Gas Workup','','Baseline is parent commit 83ce527, without the separate cancelAndFill prototype.','Solar 0.3.0 / Solidity 0.8.38; Cancun; optimizer 200; executor d3167db; frozen fixtures.','All 223 baseline values reuse the parent\'s validated measurements; every candidate case was rerun.','Public ABI, imported sources and persistent storage layout are unchanged. All 23 economic fingerprints agree.','The 222-order snapshot plus two test quotes uses mock ERC20s, a counting hook and 10-bps fees, not full Rewarder V3 execution or historical replay.','Forty-two Wide Sweep rows are inherited repetitions. The capped budget row is functional, not independent savings.','No workload-weighted savings or deployed transaction-fee estimate is claimed. Existing default-build and static-analysis release concerns are not resolved here.',''];
 capture('GAS_TABLES.md',intro.join('\n')+Object.values(tables).join('\n\n')+'\n');
 capture('GAS_DELTAS.csv',[['group','test','baseline_gas','fused_gas','delta_gas','delta_percent','notes'],...rows.map(r=>[r.group,r.test,r.baseline,r.candidate,r.delta,r.percent,r.notes])].map(row=>row.map(x=>JSON.stringify(x)).join(',')).join('\n')+'\n');
 const summary={cases:223,cheaper:rows.filter(r=>r.delta<0).length,unchanged:rows.filter(r=>r.delta===0).length,costlier:rows.filter(r=>r.delta>0).length,largestSaving:Math.min(...rows.map(r=>r.delta)),largestRegression:Math.max(...rows.map(r=>r.delta)),rows};
 capture('summary.json',JSON.stringify(summary,null,2)+'\n');capture('raw/measurement.json',JSON.stringify(measurement,null,2)+'\n');capture('raw/validation.json',JSON.stringify(validation,null,2)+'\n');
 capture('raw/ProductionCategories.t.sol.txt',fs.readFileSync(path.join(fixture,'test/ProductionCategories.t.sol')));capture('raw/open-snapshot.json',fs.readFileSync(`${common}/open-snapshot.json`));
 const patch=spawnSync('diff',['-u','--label','a/src/DeepstateV1.sol','--label','b/src/DeepstateV1.sol',path.join(root,'variants/baseline.sol'),path.join(root,'variants/candidate.sol')],{encoding:'utf8'});assert.equal(patch.status,1);capture('raw/fused-only.patch',patch.stdout);
 capture('manifest.json',JSON.stringify({measurement,validation,fingerprints},null,2)+'\n');
 fs.writeFileSync(path.join(root,'tables.json'),JSON.stringify(tables));console.log(JSON.stringify({...summary,rows:undefined},null,2));
}
const mode=process.argv[2]??'all';assert.ok(['all','measure','validate','report'].includes(mode));
if(mode==='all'||mode==='measure')measure();
if(mode==='all'||mode==='validate')validate();
if(mode==='all'||mode==='report')report();
