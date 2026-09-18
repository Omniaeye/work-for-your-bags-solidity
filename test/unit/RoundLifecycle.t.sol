// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {DistributorTestBase} from "../helpers/DistributorTestBase.sol";
import {WorkForYourBagsDistributor as Distributor} from "../../src/WorkForYourBagsDistributor.sol";
import {RewardMock} from "../helpers/RewardMock.sol";

contract RoundLifecycleTest is DistributorTestBase {
    function testHumanApprovalRequired() public {
        fund(100, REPORT);
        propose(1, distributor.leafHash(1, ALICE, 100), 100);
        vm.expectRevert(Distributor.InvalidRound.selector);
        distributor.claim(1, ALICE, 100, empty());
        bytes32 commitment = distributor.roundCommitment(1);
        vm.prank(PROPOSER);
        vm.expectRevert();
        distributor.approveRound(1, commitment);
        approve(1);
        distributor.claim(1, ALICE, 100, empty());
        require(token.balanceOf(ALICE) == 100 && distributor.totalReserved() == 0);
    }

    function testChangedProposalInvalidatesApproval() public {
        fund(100, REPORT);
        propose(1, distributor.leafHash(1, ALICE, 100), 100);
        bytes32 old = distributor.roundCommitment(1);
        propose(1, distributor.leafHash(1, ALICE, 99), 99);
        vm.expectRevert(Distributor.StaleApproval.selector);
        distributor.approveRound(1, old);
        approve(1);
    }

    function testSameValuesNewRevisionInvalidatesApproval() public {
        fund(100, REPORT);
        bytes32 root = distributor.leafHash(1, ALICE, 100);
        propose(1, root, 100);
        bytes32 old = distributor.roundCommitment(1);
        propose(1, root, 100);
        vm.expectRevert(Distributor.StaleApproval.selector);
        distributor.approveRound(1, old);
    }

    function testActiveRoundImmutableAndCannotCancel() public {
        fund(100, REPORT);
        single(1, 100);
        vm.prank(PROPOSER);
        vm.expectRevert(Distributor.InvalidRound.selector);
        distributor.proposeRound(1, REPORT, REPORT, 99);
        vm.expectRevert(Distributor.InvalidRound.selector);
        distributor.cancelProposal(1);
        vm.expectRevert(Distributor.InvalidRound.selector);
        distributor.approveRound(1, REPORT);
    }

    function testCancelAndReproposeNeedsFreshReview() public {
        fund(100, REPORT);
        propose(1, distributor.leafHash(1, ALICE, 100), 100);
        bytes32 old = distributor.roundCommitment(1);
        distributor.cancelProposal(1);
        require(distributor.availableFunding() == 100);
        vm.expectRevert(Distributor.InvalidRound.selector);
        distributor.approveRound(1, old);
        propose(1, distributor.leafHash(1, ALICE, 100), 100);
        vm.expectRevert(Distributor.StaleApproval.selector);
        distributor.approveRound(1, old);
        approve(1);
    }

    function testUnfundedApprovalRejected() public {
        propose(1, REPORT, 100);
        bytes32 commitment = distributor.roundCommitment(1);
        vm.expectRevert(Distributor.InsufficientFunding.selector);
        distributor.approveRound(1, commitment);
    }

    function testOtherRoundsCannotSpendReservedFunds() public {
        fund(150, REPORT);
        single(1, 100);
        propose(2, distributor.leafHash(2, ALICE, 100), 100);
        bytes32 commitment = distributor.roundCommitment(2);
        vm.expectRevert(Distributor.InsufficientFunding.selector);
        distributor.approveRound(2, commitment);
        distributor.claim(1, ALICE, 100, empty());
        require(distributor.availableFunding() == 50);
        vm.expectRevert(Distributor.InsufficientFunding.selector);
        distributor.approveRound(2, commitment);
    }

    function testRoleSeparationAndTwoStepOwnerChange() public {
        vm.expectRevert(Distributor.InvalidConfiguration.selector);
        distributor.setProposer(address(this));
        vm.expectRevert(Distributor.InvalidConfiguration.selector);
        distributor.transferOwnership(PROPOSER);
        distributor.transferOwnership(BOB);
        vm.expectRevert(Distributor.InvalidConfiguration.selector);
        distributor.setProposer(BOB);
        require(distributor.owner() == address(this));
        vm.prank(ALICE);
        vm.expectRevert();
        distributor.acceptOwnership();
        vm.prank(BOB);
        distributor.acceptOwnership();
        require(distributor.owner() == BOB);
        vm.expectRevert();
        distributor.pause();
    }

    function testNoRenounceOrWithdrawalOrUpgrade() public {
        vm.expectRevert(Distributor.RenunciationDisabled.selector);
        distributor.renounceOwnership();
        fund(100, REPORT);
        (bool withdrawOk,) = address(distributor).call(abi.encodeWithSignature("withdraw(address,uint256)", ALICE, 100));
        (bool upgradeOk,) = address(distributor).call(abi.encodeWithSignature("upgradeTo(address)", ALICE));
        require(!withdrawOk && !upgradeOk && token.balanceOf(address(distributor)) == 100);
    }

    function testInvalidConfigurationAndUnauthorizedProposal() public {
        vm.expectRevert(Distributor.InvalidConfiguration.selector);
        new Distributor(address(0x123), TREASURY, address(this), PROPOSER);
        vm.expectRevert(Distributor.InvalidConfiguration.selector);
        new Distributor(address(token), TREASURY, PROPOSER, PROPOSER);
        vm.expectRevert(Distributor.Unauthorized.selector);
        distributor.proposeRound(1, REPORT, REPORT, 1);
        vm.prank(PROPOSER);
        vm.expectRevert(Distributor.InvalidRound.selector);
        distributor.proposeRound(0, REPORT, REPORT, 1);
    }

    function testSelfProposerRejected() public {
        vm.expectRevert(Distributor.InvalidConfiguration.selector);
        distributor.setProposer(address(distributor));
    }

    function testSelfPendingOwnerRejected() public {
        vm.expectRevert(Distributor.InvalidConfiguration.selector);
        distributor.transferOwnership(address(distributor));
    }

    function testSelfInitialOwnerRejected() public {
        address predicted = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
        vm.expectRevert(Distributor.InvalidConfiguration.selector);
        new Distributor(address(token), TREASURY, predicted, PROPOSER);
    }
}
