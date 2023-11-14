pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../../contracts/campaign/Campaign.sol";
import "@balancer-labs/v2-interfaces/contracts/pool-utils/IRateProvider.sol";
import "@balancer-labs/v2-interfaces/contracts/vault/IBasePool.sol";
import "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";

interface IWeightedPoolFactory {
    function create(
        string memory name,
        string memory symbol,
        IERC20[] memory tokens,
        uint256[] memory normalizedWeights,
        IRateProvider[] memory rateProviders,
        uint256 swapFeePercentage,
        address owner,
        bytes32 salt
    ) external returns (address);
}

interface TokenForTest is IERC20 {
    function faucet(address, uint) external;
}

contract CampaignTest is Test {
    TokenForTest xrp = TokenForTest(0xEC6F4E813E7354BB0dFF603a7FA346a9efd5d509);
    TokenForTest root =
        TokenForTest(0xc2fe5fAd30d8289176f4371b2599b6412D2e1CC4);
    uint xrpIndex;
    uint rootIndex;
    IVault vault = IVault(0x6548DEA2fB59143215E54595D0157B79aac1335e);
    IWeightedPoolFactory poolFactory =
        IWeightedPoolFactory(0x1CFE9102cA4291e358B81221757a0988a39c0A44);
    address poolAddress;
    bytes32 poolId;

    Campaign campaign;

    function setUp() public {
        // Mock $XRP and $ROOT
        xrpIndex = address(xrp) < address(root) ? 0 : 1;
        rootIndex = 1 - xrpIndex;

        // Create $XRP-$POOL Pool(50-50)
        IERC20[] memory tokens = new IERC20[](2);
        tokens[xrpIndex] = IERC20(address(xrp));
        tokens[rootIndex] = IERC20(address(root));

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
        poolId = IBasePool(poolAddress).getPoolId();

        // Provide initial liquidity
        // IAsset[] memory joinAsset = new IAsset[](2);
        // joinAsset[xrpIndex] = IAsset(address(xrp));
        // joinAsset[rootIndex] = IAsset(address(root));

        // Create Campaign Contract
        campaign = new Campaign(
            address(root),
            address(xrp),
            address(vault),
            poolAddress,
            poolId
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
