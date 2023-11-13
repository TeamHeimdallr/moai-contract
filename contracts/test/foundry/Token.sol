pragma solidity ^0.7.1;

import "../../contracts/weighted-pool-v4/v2-solidity-utils/contracts/openzeppelin/ERC20.sol";

contract Token is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1e23);
    }
}
