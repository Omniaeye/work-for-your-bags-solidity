// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {WorkForYourBagsDistributor as Distributor} from "../../src/WorkForYourBagsDistributor.sol";
import {RewardMock} from "../helpers/RewardMock.sol";

contract ProposalActor {
    function propose(Distributor d, uint256 id, bytes32 root, uint256 amount) external {
        d.proposeRound(id, root, keccak256("invariant fixture"), amount);
    }
}

contract DistributionHandler {
    RewardMock public token;
    Distributor public distributor;
    ProposalActor private proposer;
    uint256[] public amounts;
    address constant BENEFICIARY = address(0xCAFE);
    uint256 private deposits;

    constructor() {
        token = new RewardMock();
        proposer = new ProposalActor();
        distributor = new Distributor(address(token), address(this), address(this), address(proposer));
        token.approve(address(distributor), type(uint256).max);
    }

    function fund(uint96 amount) public {
        if (amount == 0 || distributor.paused()) return;
        token.mint(address(this), amount);
        distributor.fund(amount, bytes32(++deposits));
    }

    function activate(uint96 raw) public {
        uint256 available = distributor.availableFunding();
        if (available == 0 || distributor.paused()) return;
        uint256 amount = uint256(raw) % available + 1;
        amounts.push(amount);
        uint256 id = amounts.length;
        proposer.propose(distributor, id, distributor.leafHash(id, BENEFICIARY, amount), amount);
        distributor.approveRound(id, distributor.roundCommitment(id));
    }

    function pay(uint256 raw) public {
        if (amounts.length == 0 || distributor.paused()) return;
        uint256 id = raw % amounts.length + 1;
        if (!distributor.claimed(id, BENEFICIARY)) {
            distributor.claim(id, BENEFICIARY, amounts[id - 1], new bytes32[](0));
        }
    }

    function togglePause() public {
        if (distributor.paused()) distributor.unpause();
        else distributor.pause();
    }

    function verifyAccounting() public view {
        uint256 paid;
        uint256 reserved;
        for (uint256 i; i < amounts.length; ++i) {
            if (distributor.claimed(i + 1, BENEFICIARY)) paid += amounts[i];
            else reserved += amounts[i];
        }
        require(distributor.totalPaid() == paid && distributor.totalReserved() == reserved);
        require(token.balanceOf(BENEFICIARY) == paid);
        require(token.balanceOf(address(distributor)) == distributor.totalFunded() - paid);
        require(paid + reserved + distributor.availableFunding() == distributor.totalFunded());
    }
}
