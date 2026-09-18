// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {DistributorTestBase} from "../helpers/DistributorTestBase.sol";
import {WorkForYourBagsDistributor as Distributor} from "../../src/WorkForYourBagsDistributor.sol";
import {RewardMock} from "../helpers/RewardMock.sol";

contract ClaimsTest is DistributorTestBase {
    function testRelayerCannotRedirectPayment() public {
        fund(100, REPORT);
        single(1, 100);
        vm.prank(BOB);
        vm.expectRevert(Distributor.InvalidProof.selector);
        distributor.claim(1, BOB, 100, empty());
        vm.prank(BOB);
        distributor.claim(1, ALICE, 100, empty());
        require(token.balanceOf(ALICE) == 100 && token.balanceOf(BOB) == 0);
    }

    function testDuplicateClaimRejected() public {
        fund(100, REPORT);
        single(1, 100);
        distributor.claim(1, ALICE, 100, empty());
        vm.expectRevert(Distributor.AlreadyClaimed.selector);
        distributor.claim(1, ALICE, 100, empty());
    }

    function testMaliciousRootCannotExceedBudget() public {
        fund(200, REPORT);
        (bytes32 root, bytes32[] memory pa, bytes32[] memory pb) = pair(1, 80, 80);
        propose(1, root, 100);
        approve(1);
        distributor.claim(1, ALICE, 80, pa);
        vm.expectRevert(Distributor.InsufficientFunding.selector);
        distributor.claim(1, BOB, 80, pb);
        require(distributor.totalReserved() == 20 && distributor.availableFunding() == 100);
    }

    function testBadAmountAndProofRejected() public {
        fund(100, REPORT);
        single(1, 100);
        vm.expectRevert(Distributor.InvalidProof.selector);
        distributor.claim(1, ALICE, 101, empty());
        vm.expectRevert(Distributor.InvalidPayment.selector);
        distributor.claim(1, ALICE, 0, empty());
        vm.expectRevert(Distributor.InvalidPayment.selector);
        distributor.claim(1, address(0), 100, empty());
    }

    function testProofCannotReplayAcrossRoundsOrChainsOrContracts() public {
        fund(200, REPORT);
        bytes32 root = distributor.leafHash(1, ALICE, 100);
        propose(1, root, 100);
        approve(1);
        propose(2, root, 100);
        approve(2);
        vm.expectRevert(Distributor.InvalidProof.selector);
        distributor.claim(2, ALICE, 100, empty());
        uint256 oldChain = block.chainid;
        vm.chainId(oldChain + 1);
        vm.expectRevert(Distributor.InvalidProof.selector);
        distributor.claim(1, ALICE, 100, empty());
        vm.chainId(oldChain);
        Distributor other = new Distributor(address(token), TREASURY, address(this), PROPOSER);
        require(root != other.leafHash(1, ALICE, 100));
        RewardMock otherToken = new RewardMock();
        Distributor third = new Distributor(address(otherToken), TREASURY, address(this), PROPOSER);
        require(root != third.leafHash(1, ALICE, 100));
    }

    function testTransferFailureRollsBackClaimAndRetryWorks() public {
        fund(100, REPORT);
        single(1, 100);
        token.setFail(true);
        vm.expectRevert();
        distributor.claim(1, ALICE, 100, empty());
        require(!distributor.claimed(1, ALICE) && distributor.totalReserved() == 100 && distributor.totalPaid() == 0);
        token.setFail(false);
        distributor.claim(1, ALICE, 100, empty());
    }

    function testBlockedRecipientDoesNotBlockOtherRecipient() public {
        fund(100, REPORT);
        (bytes32 root, bytes32[] memory pa, bytes32[] memory pb) = pair(1, 60, 40);
        propose(1, root, 100);
        approve(1);
        token.setBlocked(ALICE);
        vm.expectRevert();
        distributor.claim(1, ALICE, 60, pa);
        distributor.claim(1, BOB, 40, pb);
        require(token.balanceOf(BOB) == 40 && distributor.totalReserved() == 60);
    }

    function testTaxedPaymentRejectedAtomically() public {
        fund(100, REPORT);
        single(1, 100);
        token.setTax(true);
        vm.expectRevert(Distributor.UnsupportedTokenBehavior.selector);
        distributor.claim(1, ALICE, 100, empty());
        require(token.balanceOf(ALICE) == 0 && !distributor.claimed(1, ALICE));
    }

    function testTokenReentrancyCannotDoublePay() public {
        fund(100, REPORT);
        single(1, 100);
        token.setCallback(address(distributor), abi.encodeCall(distributor.claim, (1, ALICE, 100, empty())));
        distributor.claim(1, ALICE, 100, empty());
        require(!token.reentrySucceeded() && token.balanceOf(ALICE) == 100 && distributor.totalPaid() == 100);
    }

    function testLossOfBackingFailsClosed() public {
        fund(100, REPORT);
        single(1, 100);
        token.burn(address(distributor), 1);
        vm.expectRevert(Distributor.InsufficientFunding.selector);
        distributor.claim(1, ALICE, 100, empty());
        require(!distributor.claimed(1, ALICE));
    }

    function testPauseAndResumeAndNoExpiry() public {
        fund(100, REPORT);
        single(1, 100);
        distributor.pause();
        vm.expectRevert();
        distributor.claim(1, ALICE, 100, empty());
        vm.prank(BOB);
        vm.expectRevert();
        distributor.unpause();
        distributor.unpause();
        vm.warp(block.timestamp + 100 * 365 days);
        distributor.claim(1, ALICE, 100, empty());
        require(token.balanceOf(ALICE) == 100);
    }
}
