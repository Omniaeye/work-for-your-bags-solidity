# Security policy

This is a pre-release implementation. No version is represented as independently audited or production-ready. The repository contains no official deployed address.

## Reporting

Use the repository's **Security → Report a vulnerability** channel if private reporting is available. Otherwise, open a minimal issue requesting a private disclosure channel without including exploit details, private evidence or credentials. Do not post seed phrases, private keys, production reports or sensitive account data in issues or pull requests.

Include the affected revision, minimal local reproduction, preconditions and impact. Reproduce with fixtures or a local fork; do not test against other users or move real funds. No bug-bounty payment or response SLA is promised by this document.

## Security model

- Human-controlled owner approves each immutable distribution; proposer permission cannot approve.
- Treasury funds budgets explicitly. Active entitlements cannot be swept or expired.
- The generator checks supplied evidence, not its authenticity. The owner remains trusted to approve correct allocations.
- Token issuer powers, chain finality, proof availability and key custody remain external dependencies.
- Bad roots can strand rewards. Direct transfers are unrecoverable. Pause authority can suspend access indefinitely.

Read the [architecture](docs/ARCHITECTURE.md), [review findings](docs/SECURITY_REVIEW.md) and [production checklist](docs/OPERATIONS.md) before considering deployment. A clean scanner result or full coverage is not a security guarantee.
