// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {DistributorTestBase} from "../helpers/DistributorTestBase.sol";

contract ConservationFuzzTest is DistributorTestBase {
    function testFuzzExactConservation(uint96 rawA, uint96 rawB, bool reverse) public {
        uint256 a = uint256(rawA) + 1;
        uint256 b = uint256(rawB) + 1;
        token.mint(TREASURY, a + b);
        fund(a + b, REPORT);
        (bytes32 root, bytes32[] memory pa, bytes32[] memory pb) = pair(1, a, b);
        propose(1, root, a + b);
        approve(1);
        if (reverse) {
            distributor.claim(1, BOB, b, pb);
            distributor.claim(1, ALICE, a, pa);
        } else {
            distributor.claim(1, ALICE, a, pa);
            distributor.claim(1, BOB, b, pb);
        }
        require(token.balanceOf(ALICE) == a && token.balanceOf(BOB) == b);
        require(
            distributor.totalPaid() == a + b && distributor.totalReserved() == 0 && distributor.availableFunding() == 0
        );
    }
}
