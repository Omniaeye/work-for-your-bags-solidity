// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/// @notice Funded reward rounds activated by a separate reviewer.
/// @dev Merkle proofs authenticate allocations, not their off-chain evidence.
contract WorkForYourBagsDistributor is Ownable2Step, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    enum Status {
        None,
        Proposed,
        Cancelled,
        Active
    }

    struct Round {
        bytes32 root;
        bytes32 manifestHash;
        uint256 budget;
        uint256 paid;
        uint256 revision;
        Status status;
    }

    IERC20 public immutable rewardToken;
    address public immutable treasury;
    address public proposer;
    uint256 public totalFunded;
    uint256 public totalPaid;
    uint256 public totalReserved;
    mapping(uint256 => Round) public rounds;
    mapping(uint256 => mapping(address => bool)) public claimed;
    mapping(bytes32 => bool) public fundingReferences;

    error InvalidConfiguration();
    error Unauthorized();
    error InvalidRound();
    error StaleApproval();
    error AlreadyClaimed();
    error InvalidProof();
    error InvalidPayment();
    error InsufficientFunding();
    error UnsupportedTokenBehavior();
    error RenunciationDisabled();

    event Funded(bytes32 indexed fundingReference, uint256 amount);
    event ProposerChanged(address indexed proposer);
    event RoundProposed(
        uint256 indexed roundId,
        bytes32 indexed commitment,
        bytes32 root,
        bytes32 manifestHash,
        uint256 budget,
        uint256 revision
    );
    event RoundCancelled(uint256 indexed roundId, uint256 revision);
    event RoundApproved(uint256 indexed roundId, bytes32 indexed commitment, address indexed approver);
    event Claimed(uint256 indexed roundId, address indexed beneficiary, uint256 amount, address indexed executor);

    constructor(address token_, address treasury_, address reviewer_, address proposer_) Ownable(reviewer_) {
        if (
            token_.code.length == 0 || treasury_ == address(0) || treasury_ == address(this)
                || reviewer_ == address(this)
        ) revert InvalidConfiguration();
        rewardToken = IERC20(token_);
        treasury = treasury_;
        _setProposer(proposer_);
    }

    /// @dev Direct transfers are uncredited and cannot be recovered.
    function fund(uint256 amount, bytes32 fundingReference) external nonReentrant whenNotPaused {
        if (msg.sender != treasury) revert Unauthorized();
        if (amount == 0 || fundingReference == bytes32(0) || fundingReferences[fundingReference]) {
            revert InvalidPayment();
        }
        uint256 beforeBalance = rewardToken.balanceOf(address(this));
        uint256 beforeTreasury = rewardToken.balanceOf(treasury);
        if (beforeTreasury < amount) revert InsufficientFunding();
        fundingReferences[fundingReference] = true;
        totalFunded += amount;
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
        uint256 afterBalance = rewardToken.balanceOf(address(this));
        if (afterBalance != beforeBalance + amount || rewardToken.balanceOf(treasury) != beforeTreasury - amount) {
            revert UnsupportedTokenBehavior();
        }
        _checkSolvent(afterBalance);
        emit Funded(fundingReference, amount);
    }

    function availableFunding() public view returns (uint256) {
        return totalFunded - totalPaid - totalReserved;
    }

    function proposeRound(uint256 roundId, bytes32 root, bytes32 manifestHash, uint256 budget) external whenNotPaused {
        if (msg.sender != proposer) revert Unauthorized();
        Round storage round = rounds[roundId];
        if (
            roundId == 0 || root == bytes32(0) || manifestHash == bytes32(0) || budget == 0
                || round.status == Status.Active
        ) revert InvalidRound();
        round.root = root;
        round.manifestHash = manifestHash;
        round.budget = budget;
        round.revision++;
        round.status = Status.Proposed;
        emit RoundProposed(roundId, roundCommitment(roundId), root, manifestHash, budget, round.revision);
    }

    function roundCommitment(uint256 roundId) public view returns (bytes32) {
        Round storage round = rounds[roundId];
        return keccak256(
            abi.encode(
                block.chainid,
                address(this),
                address(rewardToken),
                roundId,
                round.root,
                round.manifestHash,
                round.budget,
                round.revision
            )
        );
    }

    function approveRound(uint256 roundId, bytes32 expectedCommitment) external onlyOwner whenNotPaused {
        Round storage round = rounds[roundId];
        if (round.status != Status.Proposed) revert InvalidRound();
        if (roundCommitment(roundId) != expectedCommitment) revert StaleApproval();
        if (round.budget > availableFunding()) revert InsufficientFunding();
        _checkSolvent(rewardToken.balanceOf(address(this)));
        round.status = Status.Active;
        totalReserved += round.budget;
        emit RoundApproved(roundId, expectedCommitment, msg.sender);
    }

    function cancelProposal(uint256 roundId) external onlyOwner {
        Round storage round = rounds[roundId];
        if (round.status != Status.Proposed) revert InvalidRound();
        round.status = Status.Cancelled;
        round.revision++;
        emit RoundCancelled(roundId, round.revision);
    }

    /// @notice Any caller may execute a claim; payment goes only to the proven beneficiary.
    function claim(uint256 roundId, address beneficiary, uint256 amount, bytes32[] calldata proof)
        external
        nonReentrant
        whenNotPaused
    {
        Round storage round = rounds[roundId];
        if (round.status != Status.Active) revert InvalidRound();
        if (beneficiary == address(0) || beneficiary == address(this) || amount == 0) revert InvalidPayment();
        if (claimed[roundId][beneficiary]) revert AlreadyClaimed();
        if (!MerkleProof.verifyCalldata(proof, round.root, leafHash(roundId, beneficiary, amount))) {
            revert InvalidProof();
        }
        if (amount > round.budget - round.paid) revert InsufficientFunding();
        uint256 beforeContract = rewardToken.balanceOf(address(this));
        _checkSolvent(beforeContract);
        uint256 beforeBeneficiary = rewardToken.balanceOf(beneficiary);
        claimed[roundId][beneficiary] = true;
        round.paid += amount;
        totalPaid += amount;
        totalReserved -= amount;
        rewardToken.safeTransfer(beneficiary, amount);
        if (
            rewardToken.balanceOf(address(this)) != beforeContract - amount
                || rewardToken.balanceOf(beneficiary) != beforeBeneficiary + amount
        ) revert UnsupportedTokenBehavior();
        emit Claimed(roundId, beneficiary, amount, msg.sender);
    }

    /// @dev Double hashing matches OpenZeppelin StandardMerkleTree.
    function leafHash(uint256 roundId, address beneficiary, uint256 amount) public view returns (bytes32) {
        return keccak256(
            bytes.concat(
                keccak256(abi.encode(block.chainid, address(this), address(rewardToken), roundId, beneficiary, amount))
            )
        );
    }

    function setProposer(address proposer_) external onlyOwner {
        _setProposer(proposer_);
    }

    function transferOwnership(address newOwner) public override onlyOwner {
        if (newOwner == proposer || newOwner == address(this)) revert InvalidConfiguration();
        super.transferOwnership(newOwner);
    }

    function renounceOwnership() public view override onlyOwner {
        revert RenunciationDisabled();
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _setProposer(address proposer_) private {
        if (
            proposer_ == address(0) || proposer_ == address(this) || proposer_ == owner() || proposer_ == pendingOwner()
        ) {
            revert InvalidConfiguration();
        }
        proposer = proposer_;
        emit ProposerChanged(proposer_);
    }

    function _checkSolvent(uint256 balance) private view {
        if (balance < totalFunded - totalPaid) revert InsufficientFunding();
    }
}
