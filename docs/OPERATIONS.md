# Operator runbook

No deployment or real transaction has been performed for this repository. These are future operating procedures, not evidence of an active service.

## 1. Before deployment

- Verify Robinhood network, canonical USDG address/decimals, OMNIA address/decimals and Pons launch/fee configuration using authoritative sources and read-only chain checks.
- Select treasury, human reviewer/multisig and separate proposer. Keep reviewer authority outside collection and payment automation. Confirm the selected smart wallets are supported and operable on the target network.
- Review issuer pause, blacklist and upgrade powers of USDG. Exact sender/recipient transfers are required; taxed/rebasing assets are not supported.
- Configure an archive RPC and a finality policy. Missing historical data must not turn into eligibility approval.
- Build an authenticated evidence export and persistent fee/allocation ledger. The offline tool cannot prove `history.complete` or other supplied assertions.
- Complete independent audit, a real-token fork test and a full testnet round. Explicitly authorize any mainnet pilot separately. Fund gas from a separate budget.

Constructor: `(rewardToken, treasury, reviewer, proposer)`. Treasury/token cannot be changed after deployment. No deployment script or signing key is provided here.

## 2. Close and prepare a round

Stop submissions at the exclusive weekly cutoff. Establish one finalized closing block for all holders. Collect final post observations, retaining per-post timestamps. Freeze identities, wallets, posts, metrics, holdings, receipts, exclusions and prior allocation history.

```sh
npm run prepare -- trusted-input.json reports/round.json
npm run verify -- trusted-input.json reports/round.json
```

The output path must not already exist. Store the full report privately; publish only the reviewed manifest/proofs when appropriate. The POSIX file mode argument is not a private Windows ACL: secure the output directory using the host's access controls.

## 3. Human review and funding

Review source authenticity, identity/wallet binding, snapshot, receipts and conversion provenance, previous allocations, exclusion reasons, top-three selection, formula, rounding, full sum and every recipient. Freeze that exact version. If any item changes, regenerate and review again.

Treasury approves the **exact** USDG amount and calls `fund(amount, fundingReference)` itself. Use a unique funding reference tied to the reconciled deposit batch. Do not transfer directly to the contract: direct deposits are uncredited and unrecoverable. Funding does not activate claims.

## 4. Publish proposal and approve

The proposer submits the generated `proposeRound` calldata. Read the resulting proposal and commitment from the chain. Confirm deployment, chain, token, treasury, reviewer, pause state and available credit. Generate unsigned approval only from the frozen source evidence and current proposal.

The reviewer signs `approveRound(roundId, expectedCommitment)`. Approval reserves the full budget. An updated root, manifest, budget or revision invalidates old approval calldata. An active round cannot be corrected or cancelled; stop before signing if the evidence is uncertain.

Update the allocation ledger only after confirmed approval, with reorganization handling. Generating a report or submitting an unconfirmed transaction is not sufficient to consume fee/post history.

## 5. Execute and reconcile

Execute individual `claim(roundId, beneficiary, amount, proof)` calls. A gas-funded relayer can submit them, and a user can use the same interface manually. The proof fixes the recipient; users do not grant token allowances to receive rewards.

Track transaction hash, nonce, receipt, canonical block and the `Claimed` event. On timeout, reconcile the existing transaction and query `claimed` before retrying. A retry of a completed claim reverts rather than paying again. Distinguish planned, submitted, confirmed, failed and unknown states in any UI.

At each checkpoint verify total funding, paid value, reserves and available credit. Failed individual recipients retain their entitlement; do not reallocate it to another round. No expiry applies.

## Incidents

The owner may pause operations while investigating. Pause does not move money or change a root. Rotate the proposer if compromised. Owner rotation requires two-step acceptance; renunciation is disabled. Record the incident, evidence and restart decision.

There is no recovery path for a bad active root, lost signing authority, wrong immutable treasury/token or unsupported direct transfers. Maintaining redundant manifest/proof copies and reviewing configuration before funding are essential. Never describe a pause or root replacement as a recovery mechanism that the contract does not implement.
