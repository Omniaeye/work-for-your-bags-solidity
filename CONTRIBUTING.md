# Contributing

Keep changes scoped and independently reviewable. Explain the behavior, validation and any changed trust assumption. Use conventional commit subjects (`feat`, `fix`, `test`, `docs`, `ci`, `chore`); do not fabricate historical validation results.

## Local checks

Use Node 24.15.0, Foundry v1.7.1 and the pinned Solidity compiler. Run `npm ci --ignore-scripts`, then `npm run check`. For contract behavior changes also run coverage and Slither as described in [testing](docs/TESTING.md).

Use `forge fmt` for Solidity. Keep explanatory comments for trust boundaries and non-obvious behavior; put operating procedures in documentation. Use exact integer arithmetic for all monetary values. Preserve checks-effects-interactions, fixed beneficiaries, funded reserves and immutable active rounds.

Do not accept external metrics or verification flags as independently authenticated merely because their schema validates. A rule change needs an explicit version and a migration plan; it must not silently reinterpret an approved round.

## Test organization

Place funding and lifecycle tests under `test/unit`, encoding compatibility tests under `test/integration`, generated-value checks under `test/fuzz`, stateful handlers under `test/invariant`, and offline settlement tests under `test/settlement`. Shared mocks belong under `test/helpers`. Production code must not import test helpers.

Never add wallet keys, RPC credentials, live reports or personal account evidence. Report vulnerabilities using [SECURITY.md](SECURITY.md). CI has read-only repository permissions and no deployment credentials. Passing CI is not authorization to deploy or move funds.
