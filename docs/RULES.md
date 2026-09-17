# Reward rules — v1

These rules were approved by the project owner on 19 September 2026. They define the intended program; they do not announce a launch or a deployed token. Changes apply to future rounds and require a new version and human review.

| Topic | Rule |
| --- | --- |
| Round | Monday 00:00:00 UTC to the next Monday 00:00:00 UTC, end exclusive. Round ID equals opening Unix seconds. |
| Pool | 100% of project fees actually received from Pons, finalized and not previously allocated before the cutoff. Pending revenue is excluded. |
| Payment | USDG, in its verified smallest units. Other assets require conversion and source reconciliation before allocation; this repository performs no swaps. |
| Costs | Gas, APIs and infrastructure are funded separately from the reward pool. |
| Eligibility | At least 100,000 OMNIA at the same finalized closing block, with verified token address and decimals. Higher balances do not multiply scores. |
| Snapshot | Last canonical block whose timestamp is at or before closing; record its hash and the next block to establish the boundary. This does not prove continuous holding. |
| Later sales | Selling after the snapshot does not revoke that round's earned reward. |
| Identity | One stable X identity per wallet and one wallet per identity in a round. Verify account ownership and wallet control. These constraints do not prove one unique human. |
| Posts | Relevant original posts and quotes with an original contribution, published and submitted within the round. Replies, plain reposts, plagiarism and spam do not count. Relevant criticism is not excluded merely for being negative. |
| Selection | Up to three highest-scoring valid posts per participant. Ties: earlier publication, then smaller numeric post ID. A post is used in only one round. |
| Score | `views + 2 × likes + 3 × reposts + 4 × quotes`. Replies do not count. Missing metrics remain unresolved, never fabricated as zero. |
| Measurement | Final observations occur after submissions close, and each observation has its own timestamp. Freeze the evidence before review. This is not an equal-exposure window or a simultaneous X snapshot. |
| Moderation | Human exclusions require recorded reasons and evidence. Corrections require recomputation and a new approval. No participant-specific weight changes. |
| Allocation | `pool × participant score / eligible total score`, calculated with integers. Assign residual smallest units by largest remainder, then ascending normalized wallet address. Sum must equal the full pool. |
| Empty outcome | If no eligible score exists, carry the pool forward; do not publish an empty distribution. |
| Execution | Human approval activates payments. A relayer may pay gas, and participants may claim manually. Both use the same replay protection and fixed destination. |
| Unclaimed rewards | Remain reserved without expiry or administrative withdrawal. |

The generator enforces these rules against supplied input; it cannot prove the input is true. The contract enforces the reviewed allocation and funded budget, not X scores, ownership evidence, holding snapshots or the completeness of fees.

## Human approval

The preparer and reviewer are distinct addresses. The reviewer must be controlled by a person or a properly governed multisig, with signing authority kept outside collection/payment automation.

Review covers the receipt ledger, previous allocations, source evidence, identities, holding snapshot, posts, exclusions, arithmetic, recipients and exact amounts. Any change requires a fresh review. The EVM cannot prove that a person actually read a report.

## Unconfigured production inputs

Treasury, reviewer, proposer, OMNIA, canonical USDG, token decimals, RPC/finality policy and gas budget remain unconfigured. No access-control wallet from another product is assumed to be a deployment address. Pons fee denomination and collection depend on the actual launch configuration and must be verified.
