// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {DistributionHandler} from "./DistributionHandler.sol";

contract WorkForYourBagsInvariantTest {
    struct FuzzSelector {
        address addr;
        bytes4[] selectors;
    }

    struct FuzzArtifactSelector {
        string artifact;
        bytes4[] selectors;
    }

    struct FuzzInterface {
        address addr;
        string[] artifacts;
    }
    DistributionHandler public handler;

    function setUp() public {
        handler = new DistributionHandler();
    }

    function targetContracts() public view returns (address[] memory targets) {
        targets = new address[](1);
        targets[0] = address(handler);
    }

    function targetArtifactSelectors() public pure returns (FuzzArtifactSelector[] memory) {
        return new FuzzArtifactSelector[](0);
    }

    function targetArtifacts() public pure returns (string[] memory) {
        return new string[](0);
    }

    function excludeArtifacts() public pure returns (string[] memory) {
        return new string[](0);
    }

    function targetSenders() public pure returns (address[] memory) {
        return new address[](0);
    }

    function excludeSenders() public pure returns (address[] memory) {
        return new address[](0);
    }

    function excludeContracts() public pure returns (address[] memory) {
        return new address[](0);
    }

    function targetInterfaces() public pure returns (FuzzInterface[] memory) {
        return new FuzzInterface[](0);
    }

    function targetSelectors() public pure returns (FuzzSelector[] memory) {
        return new FuzzSelector[](0);
    }

    function excludeSelectors() public pure returns (FuzzSelector[] memory) {
        return new FuzzSelector[](0);
    }

    function invariantConservationAndReservedBacking() public view {
        handler.verifyAccounting();
    }
}
