// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract TestUSDT is ERC20, ERC20Permit {
    constructor() ERC20("Test USDT", "TestUSDT") ERC20Permit("TestUSDT") {
        _mint(msg.sender, 1000000 * 10 ** 6);
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
}
