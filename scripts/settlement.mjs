import { StandardMerkleTree } from '@openzeppelin/merkle-tree';
import { encodeAbiParameters, encodeFunctionData, isAddress, keccak256, parseAbi, toHex } from 'viem';

export const RULES = Object.freeze({
  version: 'wfyb-v1', week: 'Monday 00:00 UTC; end exclusive', minimumTokens: '100000',
  bestPosts: 3, formula: 'views + 2 * likes + 3 * reposts + 4 * quotes',
  holdings: 'single finalized closing block', metrics: 'final observation after close',
  postTypes: ['original', 'quote'], payout: 'largest remainder; wallet ascending on equal remainders',
  expiry: 'none', approval: 'human owner transaction required',
});
export const LEAF_TYPES = ['uint256', 'address', 'address', 'uint256', 'address', 'uint256'];
export const ABI = parseAbi([
  'function proposeRound(uint256 roundId, bytes32 root, bytes32 manifestHash, uint256 budget)',
  'function approveRound(uint256 roundId, bytes32 expectedCommitment)',
  'function claim(uint256 roundId, address beneficiary, uint256 amount, bytes32[] proof)',
]);
const MAX = (1n << 256n) - 1n;
const ZERO_ADDRESS = '0x' + '0'.repeat(40);
const ZERO_HASH = '0x' + '0'.repeat(64);
const requireThat = (condition, message) => { if (!condition) throw new Error(message); };
const compare = (a, b) => a < b ? -1 : a > b ? 1 : 0;
export const canonical = value => {
  if (Array.isArray(value)) return '[' + value.map(canonical).join(',') + ']';
  if (value && typeof value === 'object') return '{' + Object.keys(value).sort().map(k => JSON.stringify(k) + ':' + canonical(value[k])).join(',') + '}';
  return JSON.stringify(value);
};
export const hashObject = value => keccak256(toHex(canonical(value)));
export const RULES_HASH = hashObject(RULES);

function uint(value, name, nonzero = false) {
  requireThat(typeof value === 'string' && /^(0|[1-9][0-9]*)$/.test(value), `${name}: canonical integer string required`);
  const n = BigInt(value);
  requireThat(n <= MAX && (!nonzero || n > 0n), `${name}: out of range`);
  return n;
}
function address(value, name) {
  requireThat(typeof value === 'string' && isAddress(value) && value.toLowerCase() !== ZERO_ADDRESS, `${name}: invalid address`);
  return value.toLowerCase();
}
function hash(value, name) {
  requireThat(typeof value === 'string' && /^0x[0-9a-fA-F]{64}$/.test(value) && value.toLowerCase() !== ZERO_HASH, `${name}: invalid hash`);
  return value.toLowerCase();
}
function time(value, name) {
  requireThat(typeof value === 'string' && /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$/.test(value), `${name}: UTC timestamp required`);
  const t = Date.parse(value);
  requireThat(Number.isFinite(t) && new Date(t).toISOString() === value.replace('Z', '.000Z'), `${name}: invalid date`);
  return t;
}
function list(value, name) { requireThat(Array.isArray(value), `${name}: array required`); return value; }
function unique(set, key, name) { requireThat(!set.has(key), `${name}: duplicate or previously allocated`); set.add(key); }

/** Offline validation of supplied evidence, NOT a live X/RPC attestation. No signer/network access. */
export function prepareRound(input) {
  requireThat(input?.schema === 'omnia-wfyb-input-v1', 'Unsupported input schema');
  const chainId = uint(input.chainId, 'chainId', true);
  requireThat([4663n, 46630n, 31337n].includes(chainId), 'Unsupported chain');
  const distributor = address(input.distributor, 'distributor');
  const rewardToken = address(input.rewardToken, 'rewardToken');
  const projectToken = address(input.projectToken, 'projectToken');
  const treasury = address(input.treasury, 'treasury');
  requireThat(rewardToken !== projectToken, 'Reward and project tokens must differ');
  for (const key of ['rewardDecimals', 'projectDecimals']) requireThat(Number.isInteger(input[key]) && input[key] >= 0 && input[key] <= 36, `${key}: unsupported decimals`);
  const start = time(input.start, 'start'), end = time(input.end, 'end');
  const d = new Date(start);
  requireThat(d.getUTCDay() === 1 && d.getUTCHours() === 0 && d.getUTCMinutes() === 0 && d.getUTCSeconds() === 0 && end - start === 7 * 86400000, 'Round must be one UTC Monday-to-Monday week');
  const roundId = uint(input.roundId, 'roundId', true);
  requireThat(roundId === BigInt(start / 1000), 'roundId must equal opening Unix seconds');
  const closedAt = time(input.evidenceClosedAt, 'evidenceClosedAt');
  requireThat(closedAt >= end, 'Evidence cannot close before the round');
  const snapshot = input.snapshot;
  requireThat(snapshot?.finalized === true, 'Finalized holdings snapshot required');
  uint(snapshot.number, 'snapshot.number', true); hash(snapshot.hash, 'snapshot.hash');
  requireThat(time(snapshot.timestamp, 'snapshot.timestamp') <= end && time(snapshot.nextBlockTimestamp, 'snapshot.nextBlockTimestamp') > end, 'Snapshot must be the last block at/before closing');
  hash(snapshot.nextBlockHash, 'snapshot.nextBlockHash');
  requireThat(input.history?.complete === true, 'Complete prior allocation history required');
  const usedPosts = new Set(list(input.history.usedPostIds, 'usedPostIds'));
  const usedFees = new Set(list(input.history.allocatedFeeKeys, 'allocatedFeeKeys'));
  const historicalRounds = list(input.history.approvedRoundIds, 'approvedRoundIds');
  for (const id of usedPosts) uint(id, 'history.postId', true);
  for (const id of historicalRounds) uint(id, 'history.roundId', true);
  for (const key of usedFees) requireThat(typeof key === 'string' && /^(4663|46630|31337):0x[0-9a-f]{64}:(0|[1-9][0-9]*)$/.test(key), 'Invalid historical fee key');
  requireThat(!historicalRounds.includes(input.roundId), 'Round already approved');

  let pool = 0n;
  const feeKeys = [];
  for (const receipt of list(input.receipts, 'receipts')) {
    const tx = hash(receipt.transactionHash, 'receipt.transactionHash');
    const index = uint(receipt.logIndex, 'receipt.logIndex');
    const key = `${chainId}:${tx}:${index}`;
    unique(usedFees, key, 'Fee');
    requireThat(receipt.finalized === true && receipt.originVerified === true, 'Unverified fee receipt');
    requireThat(address(receipt.recipient, 'receipt.recipient') === treasury, 'Receipt treasury mismatch');
    requireThat(address(receipt.token, 'receipt.token') === rewardToken, 'Convert and reconcile non-USDG fees before allocation');
    requireThat(time(receipt.receivedAt, 'receipt.receivedAt') < end, 'Fee belongs to a later round');
    uint(receipt.blockNumber, 'receipt.blockNumber', true); hash(receipt.blockHash, 'receipt.blockHash');
    requireThat(BigInt(receipt.blockNumber) <= BigInt(snapshot.number), 'Fee receipt beyond closing block');
    hash(receipt.provenanceHash, 'receipt.provenanceHash');
    pool += uint(receipt.amount, 'receipt.amount', true);
    requireThat(pool <= MAX, 'Pool overflow');
    feeKeys.push(key);
  }
  const accounts = new Set(), xIds = new Set(), decisions = [], eligible = [];
  const minimum = 100000n * 10n ** BigInt(input.projectDecimals);
  for (const participant of list(input.participants, 'participants')) {
    const account = address(participant.wallet, 'participant.wallet');
    requireThat(account !== distributor, 'Distributor cannot be a beneficiary');
    uint(participant.xId, 'participant.xId', true);
    unique(accounts, account, 'Wallet'); unique(xIds, participant.xId, 'X identity');
    requireThat(participant.identityVerified === true && participant.walletVerified === true, 'Identity and wallet evidence required');
    hash(participant.identityEvidenceHash, 'identityEvidenceHash');
    requireThat(participant.balanceBlockHash?.toLowerCase() === snapshot.hash.toLowerCase(), 'Holdings block mismatch');
    const balance = uint(participant.balance, 'participant.balance');
    const posts = [], excluded = [];
    for (const post of list(participant.posts, 'participant.posts')) {
      uint(post.id, 'post.id', true); unique(usedPosts, post.id, 'Post');
      requireThat(post.authorId === participant.xId, 'Post author mismatch');
      if (post.review?.decision === 'exclude') {
        requireThat(typeof post.review.reason === 'string' && post.review.reason.trim().length > 0, 'Exclusion requires a reason');
        excluded.push({ postId: post.id, reason: post.review.reason }); continue;
      }
      requireThat(post.review?.decision === 'include' && post.available === true && post.relevant === true, 'Post review unresolved');
      requireThat(RULES.postTypes.includes(post.type), 'Ineligible post type');
      const published = time(post.publishedAt, 'post.publishedAt'), submitted = time(post.submittedAt, 'post.submittedAt');
      requireThat(published >= start && published < end && submitted >= published && submitted < end, 'Post outside submission window');
      const observed = time(post.observedAt, 'post.observedAt');
      requireThat(observed >= end && observed <= closedAt, 'Metrics not from final observation window');
      hash(post.evidenceHash, 'post.evidenceHash');
      const m = post.metrics;
      requireThat(m && typeof m === 'object', 'Metrics unavailable');
      const score = uint(m.views, 'views') + 2n * uint(m.likes, 'likes') + 3n * uint(m.reposts, 'reposts') + 4n * uint(m.quotes, 'quotes');
      requireThat(score <= MAX / 3n, 'Score overflow');
      posts.push({ postId: post.id, score: score.toString(), publishedAt: post.publishedAt, observedAt: post.observedAt });
    }
    posts.sort((a, b) => compare(BigInt(b.score), BigInt(a.score)) || compare(a.publishedAt, b.publishedAt) || compare(BigInt(a.postId), BigInt(b.postId)));
    const selected = posts.slice(0, RULES.bestPosts), score = selected.reduce((n, p) => n + BigInt(p.score), 0n);
    const isEligible = balance >= minimum;
    decisions.push({ wallet: account, xId: participant.xId, eligible: isEligible, balance: balance.toString(), score: score.toString(), selected, excluded });
    if (isEligible && score > 0n) eligible.push({ account, score });
  }
  eligible.sort((a, b) => compare(a.account, b.account));
  const totalScore = eligible.reduce((n, p) => n + p.score, 0n);
  const evidenceHash = hashObject(input);
  const report = { schema: 'omnia-wfyb-private-report-v1', evidenceHash, feeKeys: feeKeys.sort(), pool: pool.toString(), totalScore: totalScore.toString(), decisions, liveVerifiedByTool: false, requiresHumanReview: true };
  if (pool === 0n || totalScore === 0n) return { report, carryover: pool.toString(), manifest: null, proofs: [], approval: null };
  const shares = eligible.map(p => ({ ...p, amount: pool * p.score / totalScore, remainder: pool * p.score % totalScore }));
  let left = pool - shares.reduce((n, p) => n + p.amount, 0n);
  const byRemainder = [...shares].sort((a, b) => compare(b.remainder, a.remainder) || compare(a.account, b.account));
  for (let i = 0; left > 0n; i++, left--) byRemainder[i].amount++;
  const allocations = shares.filter(p => p.amount > 0n).map(p => ({ account: p.account, amount: p.amount.toString() }));
  const values = allocations.map(p => [input.chainId, distributor, rewardToken, input.roundId, p.account, p.amount]);
  const tree = StandardMerkleTree.of(values, LEAF_TYPES);
  const manifest = { schema: 'omnia-wfyb-manifest-v1', rules: RULES, rulesHash: RULES_HASH, chainId: input.chainId, distributor, rewardToken, projectToken, treasury, rewardDecimals: input.rewardDecimals, projectDecimals: input.projectDecimals, roundId: input.roundId, start: input.start, end: input.end, snapshot, evidenceHash, total: pool.toString(), root: tree.root, allocations };
  const manifestHash = hashObject(manifest);
  const proofs = allocations.map((p, i) => ({ ...p, proof: tree.getProof(i) }));
  return { report, carryover: '0', manifest, manifestHash, proofs, approval: null,
    proposal: { to: distributor, value: '0', chainId: input.chainId, data: encodeFunctionData({ abi: ABI, functionName: 'proposeRound', args: [roundId, tree.root, manifestHash, pool] }) } };
}

/** Recompute the entire result from the frozen private evidence before human signing. */
export function verifyPrepared(input, bundle) {
  const expected = prepareRound(input);
  requireThat(canonical(expected) === canonical(bundle), 'Prepared round does not match frozen evidence');
  return true;
}

/** Build UNSIGNED approval only against the current on-chain proposal, after explicit review. */
export function prepareApproval(bundle, observed, { humanReviewed = false, input } = {}) {
  requireThat(humanReviewed === true, 'Explicit human review acknowledgement required');
  requireThat(input, 'Frozen source evidence required');
  verifyPrepared(input, bundle);
  requireThat(bundle.manifest && hashObject(bundle.manifest) === bundle.manifestHash, 'Invalid manifest hash');
  const m = bundle.manifest;
  requireThat(observed.status === 'Proposed' && observed.chainId === m.chainId && observed.distributor.toLowerCase() === m.distributor && observed.rewardToken.toLowerCase() === m.rewardToken, 'Wrong proposal domain/status');
  requireThat(observed.root === m.root && observed.manifestHash === bundle.manifestHash && observed.budget === m.total, 'On-chain proposal differs from reviewed manifest');
  requireThat(observed.treasury?.toLowerCase() === m.treasury, 'On-chain treasury mismatch');
  const revision = uint(observed.revision, 'revision', true);
  const commitment = keccak256(encodeAbiParameters(
    [{ type: 'uint256' }, { type: 'address' }, { type: 'address' }, { type: 'uint256' }, { type: 'bytes32' }, { type: 'bytes32' }, { type: 'uint256' }, { type: 'uint256' }],
    [BigInt(m.chainId), m.distributor, m.rewardToken, BigInt(m.roundId), m.root, bundle.manifestHash, BigInt(m.total), revision],
  ));
  requireThat(observed.commitment === commitment, 'On-chain commitment mismatch');
  return { to: m.distributor, chainId: m.chainId, value: '0', data: encodeFunctionData({ abi: ABI, functionName: 'approveRound', args: [BigInt(m.roundId), commitment] }) };
}
