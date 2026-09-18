// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {DistributorTestBase} from "../helpers/DistributorTestBase.sol";
import {WorkForYourBagsDistributor as Distributor} from "../../src/WorkForYourBagsDistributor.sol";

contract FundingTest is DistributorTestBase {
    function testOnlyTreasuryFundsAndReferenceCannotRepeat() public {
        vm.expectRevert(Distributor.Unauthorized.selector);
        distributor.fund(100, REPORT);
        fund(100, REPORT);
        vm.expectRevert(Distributor.InvalidPayment.selector);
        fund(100, REPORT);
        require(distributor.totalFunded() == 100);
    }

    function testDonationsDoNotCreateFeeCredit() public {
        token.mint(address(distributor), 1000);
        require(distributor.availableFunding() == 0);
        propose(1, REPORT, 100);
        bytes32 commitment = distributor.roundCommitment(1);
        vm.expectRevert(Distributor.InsufficientFunding.selector);
        distributor.approveRound(1, commitment);
    }

    function testTaxedDepositRejectedAtomically() public {
        token.setTax(true);
        vm.expectRevert(Distributor.UnsupportedTokenBehavior.selector);
        fund(100, REPORT);
        require(
            distributor.totalFunded() == 0 && token.balanceOf(address(distributor)) == 0
                && !distributor.fundingReferences(REPORT)
        );
    }

    function testSenderSurchargeDepositRejectedAtomically() public {
        token.setSurcharge(true);
        uint256 beforeBalance = token.balanceOf(TREASURY);
        vm.expectRevert(Distributor.UnsupportedTokenBehavior.selector);
        fund(100, REPORT);
        require(token.balanceOf(TREASURY) == beforeBalance);
        require(distributor.totalFunded() == 0 && !distributor.fundingReferences(REPORT));
    }

    function testFundingAboveTreasuryBalanceRejected() public {
        vm.expectRevert(Distributor.InsufficientFunding.selector);
        fund(1_000_001, REPORT);
        require(distributor.totalFunded() == 0 && !distributor.fundingReferences(REPORT));
    }
}
