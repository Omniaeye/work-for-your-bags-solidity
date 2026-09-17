# Implementation and history provenance

This repository imports an existing OMNIA implementation. Its ten changesets were assembled and published on **19 September 2026**. At the owner's request, author dates are assigned to **17, 18 and 19 September 2026**, grouped **3 + 3 + 4**. Committer dates preserve the actual import time. These dates organize the prior work; they are not evidence that these commits or tests were executed on those earlier days.

The repository's existing initial commit is preserved. The import adds ten commits; it does not rewrite the initial history or attribute work to another person.

| Author date | Changesets |
| --- | --- |
| 17 September | Standalone package; approved rules and architecture; reward distributor |
| 18 September | Funding/authorization tests; claim/proof tests; fuzz/stateful invariants |
| 19 September | Settlement tooling; settlement validation; CI/contribution controls; operator documentation and validation record |

## Imported implementation

The production contract and settlement generator were copied from the reviewed local package. The publication work splits the original Solidity suite into focused files, removes a Node test's dependency on an unrelated local application, and supplies fixed score vectors matching the approved formula. No production-contract behavior was changed for the repository export.

Source snapshot SHA-256, before export:

| File | SHA-256 |
| --- | --- |
| `src/WorkForYourBagsDistributor.sol` | `5d639666353960abf069e51229aed97810685c8b96d0ec59f87ae742d665bcf9` |
| `scripts/settlement.mjs` | `e68361d0e2ab533de8294f6134e9f160cfaba1c8b5d658cdaeec16668f112b91` |

## Evidence dates and scope

Validation records use the actual execution date, 19 September 2026. No audit, mainnet/testnet deployment, live X verification, token balance or transaction is implied by the reconstructed history. Fixtures are synthetic. CI run timestamps remain the timestamps recorded by GitHub.

The publication includes only code, synthetic fixtures, documentation and reproducibility configuration. Private reports, X-to-wallet evidence, credentials, production databases, wallet keys and the rest of the OMNIA workspace are excluded.
