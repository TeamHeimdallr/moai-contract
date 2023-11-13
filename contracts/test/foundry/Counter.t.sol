pragma solidity ^0.7.1;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "./Token.sol";

import "../../contracts/weighted-pool-v4/v2-interfaces/contracts/vault/IVault.sol";
import "../../contracts/weighted-pool-v4/v2-interfaces/contracts/pool-utils/IRateProvider.sol";
import "../../contracts/weighted-pool-v4/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import "../../contracts/weighted-pool-v4/WeightedPoolFactory.sol";

contract ContractBTest is Test {
    Token xrp;
    Token root;
    IVault vault = IVault(0x6548DEA2fB59143215E54595D0157B79aac1335e);
    WeightedPoolFactory poolFactory =
        WeightedPoolFactory(0x1CFE9102cA4291e358B81221757a0988a39c0A44);
    address poolAddress;

    function setUp() public {
        xrp = new Token("XRP token in TRN", "XRP");
        root = new Token("Root token in TRN", "ROOT");
        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = address(xrp) < address(root) ? IERC20(xrp) : IERC20(root);
        tokens[1] = address(xrp) < address(root) ? IERC20(root) : IERC20(xrp);

        uint256[] memory weights = new uint256[](2);
        weights[0] = 500000000000000000;
        weights[1] = 500000000000000000;

        IRateProvider[] memory rateProviders = new IRateProvider[](2);
        rateProviders[0] = IRateProvider(address(0));
        rateProviders[1] = IRateProvider(address(0));

        poolAddress = poolFactory.create(
            "50ROOT-50XRP-TEST",
            "50ROOT-50XRP-TEST",
            tokens,
            weights,
            rateProviders,
            3000000000000000,
            address(this),
            0x26504c2e4f5b39452f306c7a2b25763b7137415e2835535d58495865366a4724
        );
    }

    function test_Balance() public {
        console.logString("abc");
        uint balance = xrp.balanceOf(address(this));
        console.logUint(balance);
        console.logAddress(poolAddress);
        // assertEq(testNumber, balance);
    }
}
