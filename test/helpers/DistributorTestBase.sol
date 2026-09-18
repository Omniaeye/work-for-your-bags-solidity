// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {WorkForYourBagsDistributor as Distributor} from "../../src/WorkForYourBagsDistributor.sol";
import {RewardMock} from "./RewardMock.sol";
import {Vm} from "./Vm.sol";

abstract contract DistributorTestBase {
    Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    RewardMock token;
    Distributor distributor;
    address constant TREASURY = address(0xA11);
    address constant PROPOSER = address(0xB22);
    address constant ALICE = address(0xC33);
    address constant BOB = address(0xD44);
    bytes32 constant REPORT = keccak256("local fixture report");

    function setUp() public {
        token = new RewardMock();
        distributor = new Distributor(address(token), TREASURY, address(this), PROPOSER);
        token.mint(TREASURY, 1_000_000);
        vm.prank(TREASURY);
        token.approve(address(distributor), type(uint256).max);
    }

    function fund(uint256 value, bytes32 ref) internal {
        vm.prank(TREASURY);
        distributor.fund(value, ref);
    }

    function propose(uint256 id, bytes32 root, uint256 budget) internal {
        vm.prank(PROPOSER);
        distributor.proposeRound(id, root, REPORT, budget);
    }

    function approve(uint256 id) internal {
        distributor.approveRound(id, distributor.roundCommitment(id));
    }

    function single(uint256 id, uint256 amount) internal {
        propose(id, distributor.leafHash(id, ALICE, amount), amount);
        approve(id);
    }

    function empty() internal pure returns (bytes32[] memory) {
        return new bytes32[](0);
    }

    function pair(uint256 id, uint256 a, uint256 b)
        internal
        view
        returns (bytes32 root, bytes32[] memory pa, bytes32[] memory pb)
    {
        bytes32 la = distributor.leafHash(id, ALICE, a);
        bytes32 lb = distributor.leafHash(id, BOB, b);
        root = la < lb ? keccak256(abi.encodePacked(la, lb)) : keccak256(abi.encodePacked(lb, la));
        pa = new bytes32[](1);
        pa[0] = lb;
        pb = new bytes32[](1);
        pb[0] = la;
    }
}
