import fs from 'node:fs';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {spawnSync} from 'node:child_process';

const root='/tmp/deepstate-common-paths-20261108';
const repo='/tmp/deepstate-solar-gas-20261107/contracts';
const fixture='/tmp/deepstate-full-gas-workup-20261107/fixture';
const buildForge='/tmp/deepstate-solar-gas-20261107/toolchain/forge';
const gasForge='/tmp/deepstate-rebase-pr34-20261107/toolchain/forge';
const require=createRequire('/Users/dangerousfood/.codex/worktrees/shared-indexer-rpc/nigiri-webapp/package.json');
const {encodeAbiParameters,parseAbiParameters,keccak256}=require('viem');
const sha=x=>crypto.createHash('sha256').update(x).digest('hex');
const [mode,variant]=process.argv.slice(2);
fs.mkdirSync(`${root}/variants`,{recursive:true});
fs.mkdirSync(`${root}/results`,{recursive:true});
if(mode==='capture') {
 fs.copyFileSync(`${repo}/src/DeepstateV1.sol`,`${root}/variants/${variant}.sol`);
 const result=spawnSync(buildForge,['build','src/DeepstateV1.sol','--no-dynamic-test-linking',
  '--out',`out-common-${variant}`,'--cache-path',`cache-common-${variant}`,'--no-lint'],
  {cwd:repo,env:{...process.env,PATH:`/tmp/deepstate-solar-gas-20261107/toolchain:${process.env.PATH}`,FOUNDRY_PROFILE:'solar'},encoding:'utf8',maxBuffer:5*1024*1024});
 fs.writeFileSync(`${root}/results/${variant}-build.log`,result.stdout+result.stderr);
 assert.equal(result.status,0,result.stdout+result.stderr);
 fs.copyFileSync(`${repo}/out-common-${variant}/DeepstateV1.sol/DeepstateV1.json`,`${root}/${variant}-artifact.json`);
 console.log(`Captured ${variant}: ${sha(fs.readFileSync(`${root}/variants/${variant}.sol`))}`);
} else if(mode==='measure') {
 const artifact=JSON.parse(fs.readFileSync(`${root}/${variant}-artifact.json`,'utf8'));
 const meta=typeof artifact.metadata==='string'?JSON.parse(artifact.metadata):artifact.metadata;
 assert.equal(meta.compiler.version,'0.8.38+commit.e7a91fc7.solar.0.3.0');
 assert.equal(meta.sources['src/DeepstateV1.sol'].keccak256,
  keccak256('0x'+fs.readFileSync(`${root}/variants/${variant}.sol`).toString('hex')));
 const snapshot=JSON.parse(fs.readFileSync('/tmp/deepstate-robinhood-comparison-20261108/open-snapshot.json','utf8'));
 const encoded=encodeAbiParameters(parseAbiParameters('int32[], uint160[], uint32[], bool[]'),
  [snapshot.ticks,snapshot.quantities.map(BigInt),snapshot.nonces.map(Number),snapshot.bids]);
 const fixtureManifest=JSON.parse(fs.readFileSync(`${repo}/docs/gas-workup/raw/manifest.json`));
 for(const[file,hash]of Object.entries(fixtureManifest.fixtures))assert.equal(sha(fs.readFileSync(`${fixture}/${file}`)),hash,file);
 const groups=process.env.CATEGORY_ONLY==='1'?['production']:['release','insertion','production'];
 const manifestFile=`${root}/results/${variant}-manifest.json`;
 const previous=fs.existsSync(manifestFile)?JSON.parse(fs.readFileSync(manifestFile)):null;
 const manifest={variant,sourceSha256:sha(fs.readFileSync(`${root}/variants/${variant}.sol`)),
  runtimeSha256:sha(Buffer.from(artifact.deployedBytecode.object.replace(/^0x/,''),'hex')),
  fixtureSha256:sha(fs.readFileSync(`${fixture}/test/ProductionCategories.t.sol`)),
  compiler:meta.compiler.version,executor:'d3167db683c001c196126c912027437a9cb0bfb9',
  runs:(previous?.runs??[]).filter(x=>!groups.includes(x.group))};
 for(const group of groups) {
  const filters=group==='release'?['--match-contract','(RadixMatchingEngine(Gas|HookGas|FeeGas)Test|DeepstateV1IntegratorFeeGasTest)']:
   group==='insertion'?['--match-contract','^OpportunityGasProbe$','--match-test','^testOpportunity_']:
   ['--match-contract','^ProductionCategoriesTest$','--match-test','^testProduction_','-vv'];
  const log=`${variant}-${group}.log`,snap=`${variant}-${group}.snapshot`,fd=fs.openSync(`${root}/results/${log}`,'w');
  console.log(`START ${variant} ${group}`);
  const args=['snapshot',...filters,'--threads','4','--isolate','--snap',`${root}/results/${snap}`];
  const result=spawnSync(gasForge,args,{cwd:fixture,env:{...process.env,VARIANT_BYTECODE:artifact.deployedBytecode.object,
   EXACT_SUMMARIES:'true',PRODUCTION_SNAPSHOT:encoded,FOUNDRY_DISABLE_NIGHTLY_WARNING:'1'},stdio:['ignore',fd,fd]});
  fs.closeSync(fd);
  const logText=fs.readFileSync(`${root}/results/${log}`,'utf8');
  console.log(logText.split('\n').findLast(x=>/^Ran .*test suite/.test(x))??logText.slice(-1000));
  if(result.status!==0){console.error(logText.slice(-8000));process.exit(result.status??1);}
  const count=fs.readFileSync(`${root}/results/${snap}`,'utf8').trim().split('\n').length;
  assert.equal(count,group==='release'?188:group==='insertion'?12:23);
  manifest.runs.push({group,count,log,snapshot:snap,logSha256:sha(fs.readFileSync(`${root}/results/${log}`)),
   snapshotSha256:sha(fs.readFileSync(`${root}/results/${snap}`))});
  fs.writeFileSync(manifestFile,JSON.stringify(manifest,null,2)+'\n');
 }
} else throw new Error('Use capture or measure with a variant name');
