# Settlement input and review artifacts

The generator is offline and deterministic. It does not fetch X data, query a chain, authenticate a wallet or send a transaction. Input must come from trusted, authenticated services and an authoritative ledger. Never accept participant-supplied verification flags as proof.

The complete synthetic schema example is [input.json](../test/fixtures/input.json), on local chain 31337. Robinhood mainnet 4663 and testnet 46630 are accepted domains; no production addresses are bundled.

## Input contract

| Field | Required content |
| --- | --- |
| `schema` | `omnia-wfyb-input-v1` |
| `chainId`, `distributor`, `rewardToken`, `projectToken`, `treasury` | Verified deployment domain and nonzero addresses. Reward/project token must differ. |
| `rewardDecimals`, `projectDecimals` | Integer decimals in the supported 0–36 range, checked against actual tokens before use. |
| `roundId`, `start`, `end`, `evidenceClosedAt` | Opening Unix seconds and UTC ISO timestamps; Monday-to-Monday week and final evidence closure after the round. |
| `snapshot` | Finalized block number/hash/timestamp and next block hash/timestamp establishing the closing boundary. |
| `history` | Explicit completeness assertion plus `usedPostIds`, `allocatedFeeKeys`, `approvedRoundIds`. Must be exported from the authoritative ledger. |
| `receipts` | Transaction hash/log index, token, treasury recipient, amount, received timestamp, block/hash and provenance hash. Finalized and origin-verified assertions are required. |
| `participants` | Stable X ID, wallet, identity/wallet verification assertions, evidence hash, holding balance/block hash and reviewed posts. |
| Each post | ID/author, type, availability/relevance, publication/submission/observation times, evidence hash, include/exclude decision and integer metrics. Exclusions require reasons. |

All monetary amounts, metric counters, chain/round/block IDs and X IDs are canonical decimal **strings**, not JSON floating-point numbers. Timestamps use `YYYY-MM-DDTHH:mm:ssZ`. Zero, unavailable and unresolved are different states. Fee keys are `chainId:transactionHash:logIndex`; transaction hashes are normalized lowercase.

Fees received in another asset must be converted and reconciled outside this tool, linking the result to the original receipt without counting both. Receipts already allocated cannot fund a new round. An empty/zero-score round does not consume the unallocated receipt history.

## Outputs

| Output | Visibility and purpose |
| --- | --- |
| `report` | **Private**. Identity-to-wallet mapping, scores, selected posts, exclusions and receipt keys. `liveVerifiedByTool` is false. |
| `manifest` | Public allocation commitment: domain, rules/hash, snapshot, evidence hash, exact budget, root and beneficiary amounts. No X identity mapping. |
| `manifestHash` | Keccak-256 of the canonical manifest serialization. |
| `proofs` | Public per-beneficiary proofs. Store redundantly; the contract does not reconstruct them for users. |
| `proposal` | Unsigned `proposeRound` transaction data. No funds are sent by preparation. |
| `approval` | Always null in generated bundles. Approval preparation is a separate human-reviewed operation. |
| `carryover` | Unallocated value when there is no distributable result. |

Object keys are sorted for canonical hashing; array order is preserved. Identical frozen input produces identical output. Reordering the source evidence can change its hash even if it preserves allocation amounts; this intentionally requires review of the new evidence package.

## APIs

```javascript
import { prepareRound, verifyPrepared, prepareApproval } from './scripts/settlement.mjs';

const bundle = prepareRound(frozenInput);
verifyPrepared(frozenInput, bundle);
const unsignedApproval = prepareApproval(bundle, observedProposal, {
  humanReviewed: true,
  input: frozenInput,
});
```

`observedProposal` must contain current on-chain `status` (`Proposed`), `chainId`, `distributor`, `rewardToken`, `treasury`, `root`, `manifestHash`, `budget`, `revision` and `commitment`. Read these independently from the intended chain. This function validates supplied observations; it does not authenticate the RPC or perform those reads itself.

The caller must also verify deployed bytecode, reviewer identity, token behavior, pause state and funding. The human signs only after those checks. Any change to the proposal revision invalidates stale approval calldata.
