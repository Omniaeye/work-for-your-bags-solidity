// SYNTHETIC LOCAL FIXTURE. No production addresses, holdings, fees or X data.
const addr = n => '0x' + n.toString(16).padStart(40, '0');
const hash = n => '0x' + n.toString(16).padStart(64, '0');
export function inputFixture() {
  return {
    schema: 'omnia-wfyb-input-v1', chainId: '31337', distributor: addr(1), rewardToken: addr(2), projectToken: addr(3), treasury: addr(4),
    rewardDecimals: 6, projectDecimals: 18, roundId: String(Date.parse('2026-09-14T00:00:00Z') / 1000),
    start: '2026-09-14T00:00:00Z', end: '2026-09-21T00:00:00Z', evidenceClosedAt: '2026-09-21T00:05:00Z',
    snapshot: { number: '100', hash: hash(100), timestamp: '2026-09-21T00:00:00Z', nextBlockTimestamp: '2026-09-21T00:00:01Z', nextBlockHash: hash(101), finalized: true },
    history: { complete: true, usedPostIds: [], allocatedFeeKeys: [], approvedRoundIds: [] },
    receipts: [{ transactionHash: hash(50), logIndex: '0', token: addr(2), recipient: addr(4), amount: '100000000', receivedAt: '2026-09-20T23:00:00Z', blockNumber: '90', blockHash: hash(90), finalized: true, originVerified: true, provenanceHash: hash(51) }],
    participants: [1, 2, 3].map(n => ({
      xId: String(n), wallet: addr(10 + n), identityVerified: true, walletVerified: true, identityEvidenceHash: hash(200 + n),
      balance: '100000000000000000000000', balanceBlockHash: hash(100),
      posts: [{ id: String(n + 1000), authorId: String(n), type: 'original', available: true, relevant: true,
        publishedAt: '2026-09-15T00:00:00Z', submittedAt: '2026-09-15T00:01:00Z', observedAt: '2026-09-21T00:01:00Z',
        evidenceHash: hash(300 + n), review: { decision: 'include' },
        metrics: { views: String(n * 100), likes: '0', reposts: '0', quotes: '0' },
      }],
    })),
  };
}
