# Publication validation

Executed locally on **19 September 2026**, against the standalone repository. Historical author dates do not change the execution date of these checks. See [provenance](PROVENANCE.md).

## Reproduced results

| Check | Result |
| --- | --- |
| Clean dependency installation | `npm ci --ignore-scripts` completed from the committed lockfile |
| JavaScript settlement tests | 46 passed, 0 failed |
| Solidity tests | 32 passed, 0 failed, across 6 suites |
| Conservation fuzz test | 1,024 generated cases passed |
| Stateful invariant | 256 runs, 16,384 calls, 0 reverts |
| Production contract coverage | 95/95 lines, 142/142 statements, 20/20 branches, 16/16 functions |
| Slither 0.11.6 | 13 contracts, 102 detectors, 0 findings; dependency and test paths filtered |
| Dependency audit | `npm audit --audit-level=moderate`: 0 known vulnerabilities at execution time |
| Optimized build | Runtime 6,817 bytes; initcode 7,643 bytes |
| Offline prepare/verify | Synthetic fixture prepared and verified; human review required; 0 transactions sent |

The compiler is Solidity 0.8.37, Paris EVM, optimizer 200, legacy pipeline. Production contract and settlement script SHA-256 hashes match the source snapshot in [PROVENANCE.md](PROVENANCE.md).

Foundry's coverage run disables optimization and emitted anchor warnings for helper/test code. The production row above is the measured production-contract result; it is not total repository coverage or a guarantee of safety. The invariant handler itself has intentionally unvisited branches in this sample.

## Publication checks

Repository path/link checks passed for 43 source files; `forge fmt --check` and `git diff --check` passed. A redacted Gitleaks 8.30.1 scan of those publishable files found no leaks. Generated reports, dependencies, caches and the rest of the local workspace were excluded from publication.

GitHub Actions independently repeats the test, coverage, audit and static-analysis checks after push. Consult the [actual workflow runs](https://github.com/Omniaeye/work-for-your-bags-solidity/actions) for hosted results; a local pass does not assert a hosted pass.

## Not validated

No independent audit, formal verification, real USDG/fork test, public testnet round, deployment, live evidence integration, signing or transfer of real funds occurred. Mock tokens and synthetic fixtures exercise local behavior only. Dependencies and scans must be rechecked before a release; zero current findings cannot establish zero vulnerabilities.
