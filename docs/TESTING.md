# Testing and continuous integration

## Toolchain

| Tool | Pin |
| --- | --- |
| Node | 24.15.0 (`.nvmrc`) |
| Foundry | v1.7.1 |
| Solidity | 0.8.37, Paris EVM, optimizer 200, legacy pipeline |
| OpenZeppelin Contracts | 5.6.1 |
| OpenZeppelin Merkle Tree | 1.0.8 |
| viem | 2.56.8 |
| Slither | 0.11.6, Python 3.12 |

Dependencies are committed in `package-lock.json`; install with `npm ci --ignore-scripts`. The UUID override to 11.1.1 fixes advisory GHSA-w5hq-g745-h8pq in a transitive dependency. The proof generator/encoding is covered by tests after the override.

```sh
npm run check
npm run coverage
forge build --sizes
npm audit --audit-level=moderate
uv tool run --python 3.12 --from slither-analyzer==0.11.6 slither . --filter-paths 'node_modules|test' --fail-pedantic
```

`npm run check` validates repository paths/links, formatting, JavaScript settlement and Solidity behavior. Its credential-pattern scan is limited and is not a substitute for a dedicated secret scanner.

## Suites

| Location | Responsibility |
| --- | --- |
| `test/unit/Funding.t.sol` | Treasury-only funding, receipt references, direct donations, exact transfers and insufficient treasury balance |
| `test/unit/RoundLifecycle.t.sol` | Human approval, stale revisions, active immutability, reserved budgets, role separation and invalid configurations |
| `test/unit/Claims.t.sol` | Fixed beneficiaries, duplicates, replay isolation, failed/blocked recipients, malicious roots, reentrancy, pause and no expiry |
| `test/integration/MerkleCompatibility.t.sol` | JavaScript-generated standard tree and Solidity hashing compatibility |
| `test/fuzz/ConservationFuzz.t.sol` | 1,024 generated cases for exact distribution across different amounts and payment orders |
| `test/invariant/Conservation.t.sol` | 256 runs of 64 stateful calls across deposits, activations, payouts and pauses |
| `test/settlement/settlement.test.mjs` | Identity/receipt/post validation, time boundaries, scoring, integer rounding, proofs, tamper detection and approval evidence |

The stateful handler's accounting assertions compare paid rewards, pending reserves, available credit and real mock balances. `fail_on_revert = true` prevents silently discarding unexpected failing transitions.

The standalone score-vector test replaces a dependency on a local application path. Its expected values preserve the approved formula, including exclusion of replies. It is a golden-vector check, not a live application integration test.

## CI boundary

GitHub Actions runs validation and static analysis on pushes to main and pull requests. Actions are pinned to verified upstream commit SHAs, use read-only contents permissions, do not persist checkout credentials and have bounded run times. No signing keys, deployment environments or public RPC credentials are required. The workflow does not deploy or publish rewards.

Slither filters dependency and test paths; it does not suppress production detectors. Coverage percentages describe instrumented paths, not security guarantees. Unit/fuzz/invariant tests use synthetic data and mock tokens. Real USDG behavior, fork/testnet validation and independent audit remain separate release gates.

## Reproduce the offline example

```sh
npm run prepare -- test/fixtures/input.json reports/local-fixture.json
npm run verify -- test/fixtures/input.json reports/local-fixture.json
```

Use a new output filename on subsequent preparations. The example writes private-style fixture data locally and sends zero transactions. Never substitute production private data into committed fixtures.
