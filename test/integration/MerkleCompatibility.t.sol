// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {DistributorTestBase} from "../helpers/DistributorTestBase.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract MerkleCompatibilityTest is DistributorTestBase {
    function testJavaScriptStandardTreeCompatibility() public view {
        string memory fixture = vm.readFile("test/fixtures/merkle.json");
        bytes32 root = vm.parseJsonBytes32(fixture, ".root");
        uint256 chain = vm.parseJsonUint(fixture, ".chainId");
        uint256 id = vm.parseJsonUint(fixture, ".roundId");
        address dist = vm.parseJsonAddress(fixture, ".distributor");
        address reward = vm.parseJsonAddress(fixture, ".rewardToken");
        address account = vm.parseJsonAddress(fixture, ".account");
        uint256 amount = vm.parseJsonUint(fixture, ".amount");
        bytes32[] memory proof = abi.decode(vm.parseJson(fixture, ".proof"), (bytes32[]));
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(chain, dist, reward, id, account, amount))));
        require(MerkleProof.verify(proof, root, leaf), "JS tree / Solidity encoding mismatch");
    }
}
