// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract TestToken is ERC20, ERC20Permit {
    constructor() ERC20("TestToken", "TestToken") ERC20Permit("TestToken") {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }
}
