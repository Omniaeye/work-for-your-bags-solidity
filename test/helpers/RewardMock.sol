// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RewardMock is ERC20 {
    bool public fail;
    bool public tax;
    bool public surcharge;
    address public blocked;
    address public callback;
    bytes public payload;
    bool public reentrySucceeded;
    constructor() ERC20("Local reward fixture", "FIXTURE") {}

    function mint(address to, uint256 value) external {
        _mint(to, value);
    }

    function burn(address from, uint256 value) external {
        _burn(from, value);
    }

    function setFail(bool value) external {
        fail = value;
    }

    function setTax(bool value) external {
        tax = value;
    }

    function setSurcharge(bool value) external {
        surcharge = value;
    }

    function setBlocked(address value) external {
        blocked = value;
    }

    function setCallback(address target, bytes calldata data) external {
        callback = target;
        payload = data;
    }

    function transfer(address to, uint256 value) public override returns (bool) {
        if (callback != address(0)) (reentrySucceeded,) = callback.call(payload);
        return super.transfer(to, value);
    }

    function _update(address from, address to, uint256 value) internal override {
        require(!fail && (blocked == address(0) || to != blocked), "fixture token unavailable");
        if (tax && from != address(0) && to != address(0)) {
            super._update(from, to, value - 1);
            super._update(from, address(0), 1);
        } else {
            super._update(from, to, value);
        }
        if (surcharge && from != address(0) && to != address(0)) _burn(from, 1);
    }
}
