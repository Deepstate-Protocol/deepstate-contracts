import fs from 'node:fs';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';

const root = '/tmp/deepstate-bounded-opportunities-20261107';
const forge = '/tmp/deepstate-rebase-pr34-20261107/toolchain/forge';
const baseline = '/tmp/deepstate-full-gas-workup-20261107/fixture';
const candidate = `${root}/project`;
const layout = cwd => JSON.parse(execFileSync(forge, ['inspect', 'src/DeepstateV1.sol:DeepstateV1', 'storageLayout', '--json'], {
  cwd, env: { ...process.env, FOUNDRY_DISABLE_NIGHTLY_WARNING: '1' }, encoding: 'utf8', maxBuffer: 5_000_000,
}));
const normalize = l => {
  const type = id => {
    const t = l.types[id];
    return {
      encoding: t.encoding, label: t.label, bytes: t.numberOfBytes,
      ...(t.key ? { key: type(t.key) } : {}), ...(t.value ? { value: type(t.value) } : {}),
      ...(t.base ? { base: type(t.base) } : {}),
      ...(t.members ? { members: t.members.map(m => ({ label: m.label, slot: m.slot, offset: m.offset, type: type(m.type) })) } : {}),
    };
  };
  return l.storage.map(m => ({ label: m.label, slot: m.slot, offset: m.offset, type: type(m.type) }));
};
const before = layout(baseline), after = layout(candidate);
assert.deepEqual(normalize(before), normalize(after));
const a = JSON.parse(fs.readFileSync('/tmp/deepstate-further-optimizations-20261107/artifacts/bounded/solc/DeepstateV1.sol/DeepstateV1.json'));
const b = JSON.parse(fs.readFileSync(`${candidate}/out-uniform-difference/DeepstateV1.sol/DeepstateV1.json`));
assert.deepEqual(a.abi, b.abi);
fs.writeFileSync(`${root}/results/compatibility.json`, JSON.stringify({ publicAbiEqual: true, storageLayoutEqual: true, before, after }, null, 2) + '\n');
console.log('Public ABI and canonical storage layout match the bounded baseline.');
