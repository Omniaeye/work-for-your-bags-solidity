import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { StandardMerkleTree } from '@openzeppelin/merkle-tree';
import { decodeFunctionData, encodeAbiParameters, keccak256 } from 'viem';
import { prepareRound, verifyPrepared, prepareApproval, LEAF_TYPES, ABI, hashObject } from '../../scripts/settlement.mjs';
import { inputFixture } from '../fixtures/input.mjs';

const checkFailure = (change, message) => { const input = inputFixture(); change(input); assert.throws(() => prepareRound(input), message); };
test('exact proportional split, all rounding units distributed and proofs verify', () => {
  const b = prepareRound(inputFixture());
  assert.deepEqual(b.manifest.allocations.map(p => p.amount), ['16666667', '33333333', '50000000']);
  assert.equal(b.manifest.allocations.reduce((n, p) => n + BigInt(p.amount), 0n), 100000000n);
  assert.equal(b.approval, null);
  assert.equal(b.report.liveVerifiedByTool, false);
  for (const p of b.proofs) assert.ok(StandardMerkleTree.verify(b.manifest.root, LEAF_TYPES, [b.manifest.chainId, b.manifest.distributor, b.manifest.rewardToken, b.manifest.roundId, p.account, p.amount], p.proof));
  assert.equal(verifyPrepared(inputFixture(), b), true);
  assert.equal(decodeFunctionData({ abi: ABI, data: b.proposal.data }).functionName, 'proposeRound');
});
test('public manifest contains no X identity mapping or private post evidence', () => {
  const b = prepareRound(inputFixture()); const text = JSON.stringify(b.manifest);
  for (const key of ['xId', 'postId', 'identityEvidenceHash', 'decisions']) assert.ok(!text.includes(key));
});
test('reproducible for identical frozen input', () => assert.deepEqual(prepareRound(inputFixture()), prepareRound(inputFixture())));
test('pool conservation with random sizes and integer-only math', () => {
  let state = 42n;
  for (let i = 0; i < 300; i++) {
    state = (state * 1103515245n + 12345n) % (1n << 128n);
    const input = inputFixture(); input.receipts[0].amount = (state + 1n).toString();
    input.participants.forEach((p, j) => { p.posts[0].metrics.views = ((state >> BigInt(j * 7)) % 10000000000n + 1n).toString(); });
    const b = prepareRound(input);
    assert.equal(b.manifest.allocations.reduce((n, p) => n + BigInt(p.amount), 0n), state + 1n);
    assert.equal(new Set(b.manifest.allocations.map(p => p.account)).size, b.manifest.allocations.length);
  }
});
test('equal remainders use wallet order; zero-unit claims omitted', () => {
  const input = inputFixture(); input.receipts[0].amount = '2';
  input.participants.forEach(p => { p.posts[0].metrics.views = '1'; });
  const b = prepareRound(input); assert.deepEqual(b.proofs.map(p => p.amount), ['1', '1']);
  assert.equal(b.proofs[0].account, input.participants[0].wallet);
});
test('only best three posts; older publication breaks score ties', () => {
  const input = inputFixture(), p = input.participants[0], original = p.posts[0];
  p.posts = [1, 2, 3, 4].map(n => ({ ...structuredClone(original), id: String(2000 + n), publishedAt: `2026-09-${15 + n}T00:00:00Z`, submittedAt: `2026-09-${15 + n}T00:01:00Z` }));
  const b = prepareRound(input); assert.equal(b.report.decisions[0].score, '300');
  assert.deepEqual(b.report.decisions[0].selected.map(p => p.postId), ['2001', '2002', '2003']);
});
test('holder threshold inclusive and excess balance has no multiplier', () => {
  const input = inputFixture(); input.participants[1].balance = '99999999999999999999999';
  input.participants[2].balance = '999999999999999999999999999';
  const b = prepareRound(input); assert.deepEqual(b.report.decisions.map(p => p.eligible), [true, false, true]);
  assert.deepEqual(b.manifest.allocations.map(p => p.amount), ['25000000', '75000000']);
});
test('no eligible participants carries the pool forward without transaction', () => {
  const input = inputFixture(); input.participants.forEach(p => { p.balance = '0'; });
  const b = prepareRound(input); assert.equal(b.carryover, '100000000'); assert.equal(b.manifest, null); assert.equal(b.proposal, undefined);
});
test('zero scores or zero new funds produce no distribution', () => {
  const input = inputFixture(); input.participants.forEach(p => { p.posts[0].metrics.views = '0'; });
  assert.equal(prepareRound(input).manifest, null);
  input.receipts = []; assert.equal(prepareRound(input).carryover, '0');
});
test('human exclusions need reasons and do not silently change weights', () => {
  const input = inputFixture(); input.participants[0].posts[0].review = { decision: 'exclude', reason: 'Documented copied content' };
  const b = prepareRound(input); assert.equal(b.report.decisions[0].excluded.length, 1);
  assert.equal(b.manifest.allocations.length, 2);
  input.participants[0].posts[0].review.reason = ''; assert.throws(() => prepareRound(input), /reason/);
});
const failures = [
  ['missing metrics', i => { i.participants[0].posts[0].metrics.views = null; }, /integer string/],
  ['numeric JSON money', i => { i.receipts[0].amount = 100; }, /integer string/],
  ['negative score', i => { i.participants[0].posts[0].metrics.views = '-1'; }, /integer string/],
  ['overflow', i => { i.receipts[0].amount = (1n << 256n).toString(); }, /range/],
  ['unverified identity', i => { i.participants[0].identityVerified = false; }, /evidence/],
  ['wrong author', i => { i.participants[0].posts[0].authorId = '999'; }, /author/],
  ['duplicate wallet', i => { i.participants[1].wallet = i.participants[0].wallet; }, /Wallet/],
  ['duplicate X ID', i => { i.participants[1].xId = i.participants[0].xId; }, /identity/],
  ['duplicate post', i => { i.participants[0].posts.push(i.participants[0].posts[0]); }, /Post/],
  ['previously allocated post', i => { i.history.usedPostIds = ['1001']; }, /Post/],
  ['previously approved round', i => { i.history.approvedRoundIds = [i.roundId]; }, /already approved/],
  ['missing allocation history', i => { i.history.complete = false; }, /history/],
  ['malformed history', i => { i.history.usedPostIds = [1001]; }, /integer string/],
  ['non-finalized snapshot', i => { i.snapshot.finalized = false; }, /snapshot/],
  ['wrong snapshot block', i => { i.participants[0].balanceBlockHash = '0x' + 'a'.repeat(64); }, /block mismatch/],
  ['snapshot not closing block', i => { i.snapshot.nextBlockTimestamp = i.end; }, /last block/],
  ['replies', i => { i.participants[0].posts[0].type = 'reply'; }, /post type/],
  ['post at exclusive end', i => { i.participants[0].posts[0].publishedAt = i.end; }, /window/],
  ['metrics before close', i => { i.participants[0].posts[0].observedAt = i.start; }, /observation/],
  ['late metrics', i => { i.participants[0].posts[0].observedAt = '2026-09-22T00:00:00Z'; }, /observation/],
  ['unresolved review', i => { i.participants[0].posts[0].review.decision = 'pending'; }, /unresolved/],
  ['unverified fees', i => { i.receipts[0].originVerified = false; }, /Unverified/],
  ['wrong receipt asset', i => { i.receipts[0].token = i.projectToken; }, /non-USDG/],
  ['wrong treasury', i => { i.receipts[0].recipient = i.projectToken; }, /treasury/],
  ['duplicate receipt', i => { i.receipts.push(i.receipts[0]); }, /Fee/],
  ['old allocated receipt', i => { i.history.allocatedFeeKeys = [`${i.chainId}:${i.receipts[0].transactionHash}:0`]; }, /Fee/],
  ['receipt at cutoff', i => { i.receipts[0].receivedAt = i.end; }, /later round/],
  ['receipt beyond closing block', i => { i.receipts[0].blockNumber = '101'; }, /closing block/],
  ['wrong weekday', i => { i.start = '2026-09-15T00:00:00Z'; }, /Monday/],
  ['wrong round identifier', i => { i.roundId = '42'; }, /opening/],
  ['wrong chain', i => { i.chainId = '1'; }, /chain/],
  ['zero destination', i => { i.participants[0].wallet = '0x' + '0'.repeat(40); }, /address/],
];
for (const [name, change, message] of failures) test(`rejects ${name}`, () => checkFailure(change, message));
test('approved score vectors match v2 and replies do not count', () => {
  const vectors = JSON.parse(readFileSync(new URL('../fixtures/score-vectors.json', import.meta.url), 'utf8'));
  for (const vector of vectors) {
    const input = inputFixture();
    input.participants[0].posts[0].metrics = vector.metrics;
    assert.equal(prepareRound(input).report.decisions[0].score, vector.expectedScore);
  }
});
test('changing evidence, beneficiaries or proofs invalidates verification', () => {
  const input = inputFixture(), b = prepareRound(input);
  b.manifest.allocations[0].amount = '1'; assert.throws(() => verifyPrepared(input, b), /does not match/);
  const b2 = prepareRound(input); b2.proofs[0].proof = []; assert.throws(() => verifyPrepared(input, b2), /does not match/);
});
test('unsigned approval requires human acknowledgement and matching current revision', () => {
  const b = prepareRound(inputFixture()), m = b.manifest;
  const observed = { status: 'Proposed', chainId: m.chainId, distributor: m.distributor, rewardToken: m.rewardToken, treasury: m.treasury, root: m.root, manifestHash: b.manifestHash, budget: m.total, revision: '2' };
  observed.commitment = keccak256(encodeAbiParameters(
    [{type:'uint256'}, {type:'address'}, {type:'address'}, {type:'uint256'}, {type:'bytes32'}, {type:'bytes32'}, {type:'uint256'}, {type:'uint256'}],
    [BigInt(m.chainId),m.distributor,m.rewardToken,BigInt(m.roundId),m.root,b.manifestHash,BigInt(m.total),2n]));
  assert.throws(() => prepareApproval(b, observed), /human review/);
  const tx = prepareApproval(b, observed, { humanReviewed: true, input: inputFixture() });
  assert.equal(decodeFunctionData({abi: ABI, data: tx.data}).functionName, 'approveRound');
  assert.throws(() => prepareApproval(b, {...observed, revision: '3'}, {humanReviewed:true, input: inputFixture()}), /commitment/);
  assert.throws(() => prepareApproval(b, {...observed, budget:'1'}, {humanReviewed:true, input: inputFixture()}), /differs/);
  assert.throws(() => prepareApproval(b, observed, {humanReviewed:true}), /Frozen source evidence required/);
  b.manifest.allocations[0].amount = '1';
  b.manifestHash = hashObject(b.manifest);
  observed.manifestHash = b.manifestHash;
  observed.commitment = keccak256(encodeAbiParameters(
    [{type:'uint256'}, {type:'address'}, {type:'address'}, {type:'uint256'}, {type:'bytes32'}, {type:'bytes32'}, {type:'uint256'}, {type:'uint256'}],
    [BigInt(m.chainId),m.distributor,m.rewardToken,BigInt(m.roundId),m.root,b.manifestHash,BigInt(m.total),2n]));
  assert.throws(() => prepareApproval(b, observed, {humanReviewed:true, input: inputFixture()}), /does not match/);
});
test('committed cross-language fixture matches current generator', () => {
  const b = prepareRound(inputFixture()); const p = b.proofs[1];
  const expected = { root:b.manifest.root, chainId:b.manifest.chainId, roundId:b.manifest.roundId, distributor:b.manifest.distributor, rewardToken:b.manifest.rewardToken, account:p.account, amount:p.amount, proof:p.proof };
  const saved = JSON.parse(readFileSync(new URL('../fixtures/merkle.json', import.meta.url), 'utf8'));
  assert.deepEqual(saved, expected); assert.equal(hashObject(b.manifest), b.manifestHash);
});
