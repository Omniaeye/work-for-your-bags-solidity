# Work for Your Bags

Human-approved, prefunded reward distribution for OMNIA on Robinhood Chain. The Solidity contract pays an immutable allocation; an offline tool prepares the evidence, scores and Merkle proofs for review.


## How it works

1. Collect authenticated post evidence, a finalized holding snapshot and reconciled project-fee receipts.
2. Compute the weekly distribution and freeze the report for human review.
3. Treasury explicitly deposits the reward tokens; a separate proposer publishes the allocation commitment.
4. The human reviewer approves that exact revision, reserving the full budget.
5. Participants or a gas-paying relayer execute individual claims. Every proof fixes its beneficiary.

Preparation never activates payment. Changing a proposal invalidates earlier approval calldata. Once active, the allocation cannot be replaced or cancelled.

## Quick start

Prerequisites: Node **24.15.0** and Foundry **v1.7.1**. Solidity **0.8.37** is pinned in `foundry.toml` and installed by Foundry as needed.

```sh
git clone https://github.com/Omniaeye/work-for-your-bags-solidity.git
cd work-for-your-bags-solidity
npm ci --ignore-scripts
npm run check
```

Prepare and verify the included synthetic example:

```sh
npm run prepare -- test/fixtures/input.json reports/local-fixture.json
npm run verify -- test/fixtures/input.json reports/local-fixture.json
```

These commands do not access a wallet, query a public RPC or send transactions. Generated reports can contain private identity-to-wallet evidence and must not be committed or served publicly. Existing output files are never overwritten.

## Program rules

- Weekly UTC rounds; 100% of project fees actually received and not previously allocated.
- USDG payments, with gas/infrastructure financed separately.
- At least 100,000 OMNIA at one finalized closing block; no balance multiplier.
- Up to three valid original/quote posts per participant.
- Score: `views + 2 × likes + 3 × reposts + 4 × quotes`.
- Integer proportional allocation with deterministic largest-remainder rounding.
- Mandatory human approval, fixed recipients and no reward expiry.

The complete [rules](docs/RULES.md) define eligibility, timing, moderation, carryover and review. The offline generator checks supplied evidence; it cannot establish whether that evidence is true.

## Contract guarantees and limits

| Enforced | Still depends on review or operations |
| --- | --- |
| Fully funded budget and backed pending reserves | Correct Pons receipts, conversions and allocation history |
| Separate proposer and approval authority | Human-controlled signing keys and meaningful review |
| Immutable active root and revision-bound approval | Correct recipients, scores and sum of Merkle leaves |
| One successful payment per wallet per round | Authenticated identity, eligibility and social-abuse review |
| Proof-bound beneficiary and replay-domain isolation | Availability of manifests/proofs and reliable chain access |
| Exact sender/recipient transfer amounts | Canonical token configuration and token issuer behavior |

No proxy, upgrade, arbitrary execution, administrative withdrawal, reward expiry or active-root replacement exists. Direct transfers are uncredited and unrecoverable. An incorrect approved root can strand funds; the administrator can maintain a pause indefinitely. These are deliberate limitations, not problems a high coverage percentage resolves.

## Repository layout

```text
src/                  Reward distributor
scripts/              Offline settlement and repository validation
test/unit/            Funding, lifecycle and claim behavior
test/integration/     JavaScript/Solidity Merkle compatibility
test/fuzz/            Generated-value conservation checks
test/invariant/       Stateful accounting and reserve checks
test/settlement/      Evidence, allocation and approval validation
test/helpers/         Local-only token mocks and shared harness
test/fixtures/        Synthetic inputs and score/proof vectors
docs/                 Rules, architecture, operations and review
.github/workflows/    Read-only CI; no deployment automation
```

## Documentation

| Document | Purpose |
| --- | --- |
| [Rules](docs/RULES.md) | Approved product and allocation rules |
| [Architecture](docs/ARCHITECTURE.md) | State machine, accounting, Merkle encoding and trust boundaries |
| [Settlement](docs/SETTLEMENT.md) | Input schema, artifact visibility and review APIs |
| [Operations](docs/OPERATIONS.md) | Funding, approval, payment, reconciliation and incident procedures |
| [Testing](docs/TESTING.md) | Toolchain, focused suites, static analysis and CI |
| [Security review](docs/SECURITY_REVIEW.md) | Reproduced findings, fixes and residual risks |
| [Validation](docs/VALIDATION.md) | Dated local evidence and publication boundary |
| [Provenance](docs/PROVENANCE.md) | Existing-code import and reconstructed author dates |

See [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md) and [CHANGELOG.md](CHANGELOG.md).

## Before production

Verify the actual chain, contracts, decimals and fee path; integrate authenticated evidence and a persistent ledger; build the review/claim interface and relayer; complete a real-token fork test, full testnet round and independent audit. Only then authorize a separately reviewed pilot. This repository does not claim those steps are complete.

Licensed under [MIT](LICENSE). OpenZeppelin dependencies retain their own notices and licenses.
