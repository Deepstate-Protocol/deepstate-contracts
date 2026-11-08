import fs from 'node:fs';
import { spawnSync } from 'node:child_process';
const root = '/tmp/deepstate-bounded-opportunities-20261107';
const forge = '/tmp/deepstate-rebase-pr34-20261107/toolchain/forge';
const artifacts = {
  baseline: '/tmp/deepstate-further-optimizations-20261107/artifacts/bounded/solc/DeepstateV1.sol/DeepstateV1.json',
  combined: `${root}/project/out-uniform-difference/DeepstateV1.sol/DeepstateV1.json`,
  'zero-delta': `${root}/storage-probe/out-zero-delta/DeepstateV1.sol/DeepstateV1.json`,
};
for (const [label, file] of Object.entries(artifacts)) {
  const artifact = JSON.parse(fs.readFileSync(file));
  const fd = fs.openSync(`${root}/results/storage-${label}.log`, 'w');
  const result = spawnSync(forge, ['test', '--match-contract', '^StorageAccessProbe$', '--match-test', '^testStorage_', '--threads', '4', '-vv'], {
    cwd: `${root}/storage-access`,
    env: { ...process.env, FOUNDRY_DISABLE_NIGHTLY_WARNING: '1', VARIANT_BYTECODE: artifact.deployedBytecode.object, EXACT_SUMMARIES: 'true' },
    stdio: ['ignore', fd, fd],
  });
  fs.closeSync(fd);
  const text = fs.readFileSync(`${root}/results/storage-${label}.log`, 'utf8');
  if (result.status !== 0 || !text.includes('5 tests passed, 0 failed')) {
    console.log(text.slice(-8000));
    process.exit(result.status || 1);
  }
  console.log(label + '\n' + text.split('\n').filter(x => /testStorage_|recorded|unchanged engine/.test(x)).join('\n'));
}
