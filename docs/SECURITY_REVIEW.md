# Local security review

Reviewed on **19 September 2026**. This was a local implementation review by the same executor, not an independent audit. No real funds, live token behavior or deployed contract were tested.

## Findings addressed before publication

| Finding | Reproduction and correction |
| --- | --- |
| Self-referential administration | A predicted distributor address could be set as its initial owner, making administration unreachable. Reject self owner/proposer assignments and self pending owner; share proposer validation between constructor and setter. |
| Incomplete approval preparation | Manifest hashing alone did not require rechecking the source evidence; callers could omit the separate verification step. Approval preparation now requires the frozen input and recomputes the complete bundle internally. |
| Sender-side token surcharge | A token could debit 101 from treasury while crediting the requested 100. Funding now checks exact origin and destination deltas and reverts accounting/ref changes atomically on mismatch. |
| Repeated balance reads | Claims performed redundant distributor balance queries. The starting balance now also supplies the solvency check; exact transfer deltas preserve backing after payment. No exact gas improvement is claimed across changed compiler/mocks. |
| Older compiler pin | The local package originally used 0.8.30. It now pins 0.8.37 and explicitly selects the legacy pipeline, incorporating published security fixes. No compiler-bug exploit was demonstrated against the original contract. |

Four new Solidity regression cases and the approval-evidence test failed against the pre-correction code, then passed after correction. An additional insufficient-treasury-balance test covers the new explicit check. The exported contract retains those fixes.

## Code clarity

NatSpec is limited to the purpose, trust boundary, unrecoverable direct transfers, fixed claim destination and standard leaf hashing. Operational explanations live in the runbook. `round` replaces abbreviated state references. Redundant ownership-acceptance code is removed while OpenZeppelin's two-step behavior remains intact.

## Residual risks

The owner can approve incorrect or unfair allocations. A malformed Merkle root can strand reserved rewards even though the budget cap prevents overspending. The contract cannot authenticate X evidence, reconstruct the leaf sum or enforce social uniqueness. Account/holding/receipt assertions in a JSON input are not cryptographic attestations.

The administrator can maintain an indefinite pause. Active roots, token and treasury cannot be changed. Wrong configuration, lost authority, unavailable proof files or unsupported direct transfers have no general recovery path. Token issuer restrictions, network/RPC behavior and key custody remain external dependencies.

No proxy, administrative reward sweep, expiry or hidden recovery mechanism was added to address these risks. Changing these assumptions requires an explicit product/security decision, not an undocumented patch.

## References

- [Solidity security considerations](https://docs.soliditylang.org/en/latest/security-considerations.html)
- [Solidity style guide](https://docs.soliditylang.org/en/latest/style-guide.html) and [NatSpec](https://docs.soliditylang.org/en/latest/natspec-format.html)
- [OpenZeppelin access control](https://docs.openzeppelin.com/contracts/5.x/access-control) and [SafeERC20](https://docs.openzeppelin.com/contracts/5.x/api/token/erc20)
- [Solidity 0.8.37 release](https://github.com/argotorg/solidity/releases/tag/v0.8.37) and [known compiler bugs](https://raw.githubusercontent.com/ethereum/solidity/develop/docs/bugs.json)
- [Slither](https://github.com/crytic/slither)

The reproducible commands are in [TESTING.md](TESTING.md); the dated publication baseline is in [VALIDATION.md](VALIDATION.md).
