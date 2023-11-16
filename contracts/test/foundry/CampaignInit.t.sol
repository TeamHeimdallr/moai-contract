pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../../contracts/campaign/Campaign.sol";
import "@balancer-labs/v2-interfaces/contracts/pool-utils/IRateProvider.sol";
import "@balancer-labs/v2-interfaces/contracts/vault/IBasePool.sol";
import "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import "@balancer-labs/v2-interfaces/contracts/pool-weighted/WeightedPoolUserData.sol";

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

contract CampaignInitTest is Test {
    address originalAdmin = makeAddr("originalAdmin");
    TokenForTest xrp = TokenForTest(0xEC6F4E813E7354BB0dFF603a7FA346a9efd5d509);
    TokenForTest root =
        TokenForTest(0xc2fe5fAd30d8289176f4371b2599b6412D2e1CC4);
    TokenForTest test =
        TokenForTest(0x29860444BC48393ad54e0049e9640BD8A5F7eED2);
    uint xrpIndex;
    uint rootIndex;
    uint testIndex;
    IVault vault = IVault(0x6548DEA2fB59143215E54595D0157B79aac1335e);
    IWeightedPoolFactory poolFactory =
        IWeightedPoolFactory(0x1CFE9102cA4291e358B81221757a0988a39c0A44);
    address poolAddress;
    bytes32 poolId;
    uint initialJoinAmount = 1e6 * 1e18;

    function setUp() public {}

    function test_CampaignWrongPoolTokenLength() public {
        vm.startPrank(originalAdmin);

        // Mock $XRP and $ROOT
        xrpIndex = address(xrp) < address(root)
            ? (address(xrp) < address(test) ? 0 : 1)
            : 2;
        rootIndex = address(root) < address(xrp)
            ? (address(root) < address(test) ? 0 : 1)
            : 2;
        testIndex = address(test) < address(xrp)
            ? (address(test) < address(root) ? 0 : 1)
            : 2;

        // Create $XRP-$POOL Pool(50-50)
        IERC20[] memory tokens = new IERC20[](3);
        tokens[xrpIndex] = IERC20(address(xrp));
        tokens[rootIndex] = IERC20(address(root));
        tokens[testIndex] = IERC20(address(test));

        uint256[] memory weights = new uint256[](3);
        weights[0] = 400000000000000000;
        weights[1] = 400000000000000000;
        weights[2] = 200000000000000000;

        IRateProvider[] memory rateProviders = new IRateProvider[](3);
        rateProviders[0] = IRateProvider(address(0));
        rateProviders[1] = IRateProvider(address(0));
        rateProviders[2] = IRateProvider(address(0));

        poolAddress = poolFactory.create(
            "40-40-20-TEST",
            "40-40-20-TEST",
            tokens,
            weights,
            rateProviders,
            3000000000000000,
            originalAdmin,
            0x26504c2e4f5b39452f306c7a2b25763b7137415e2835535d58495865366a4724
        );
        poolId = IBasePool(poolAddress).getPoolId();

        vm.expectRevert("Campaign: The pool should be two tokens");
        new Campaign(
            address(root),
            address(xrp),
            address(vault),
            poolAddress,
            poolId
        );
    }

    function test_CampaignWrongPoolTokens() public {
        vm.startPrank(originalAdmin);

        // Mock $XRP and $TST
        xrpIndex = address(xrp) < address(test) ? 0 : 1;
        testIndex = 1 - xrpIndex;

        // Create $XRP-$POOL Pool(50-50)
        IERC20[] memory tokens = new IERC20[](2);
        tokens[xrpIndex] = IERC20(address(xrp));
        tokens[testIndex] = IERC20(address(test));

        uint256[] memory weights = new uint256[](2);
        weights[0] = 500000000000000000;
        weights[1] = 500000000000000000;

        IRateProvider[] memory rateProviders = new IRateProvider[](2);
        rateProviders[0] = IRateProvider(address(0));
        rateProviders[1] = IRateProvider(address(0));

        poolAddress = poolFactory.create(
            "50TST-50XRP-TEST",
            "50TST-50XRP-TEST",
            tokens,
            weights,
            rateProviders,
            3000000000000000,
            originalAdmin,
            0x26504c2e4f5b39452f306c7a2b25763b7137415e2835535d58495865366a4724
        );
        poolId = IBasePool(poolAddress).getPoolId();

        // faucet
        xrp.faucet(originalAdmin, 1e8 * 1e18);
        test.faucet(originalAdmin, 1e8 * 1e18);

        // approve
        xrp.approve(address(vault), initialJoinAmount);
        test.approve(address(vault), initialJoinAmount);

        // Provide initial liquidity
        IAsset[] memory joinAsset = new IAsset[](2);
        joinAsset[testIndex] = IAsset(address(test));
        joinAsset[xrpIndex] = IAsset(address(xrp));

        uint[] memory joinAmountsIn = new uint[](2);
        joinAmountsIn[testIndex] = initialJoinAmount;
        joinAmountsIn[xrpIndex] = initialJoinAmount;

        bytes memory userData = abi.encode(
            WeightedPoolUserData.JoinKind.INIT,
            joinAmountsIn
        );

        IVault.JoinPoolRequest memory request = IVault.JoinPoolRequest({
            assets: joinAsset,
            maxAmountsIn: joinAmountsIn,
            userData: userData,
            fromInternalBalance: false
        });

        // initial join
        IVault(address(vault)).joinPool(
            poolId,
            originalAdmin,
            originalAdmin,
            request
        );

        vm.expectRevert("Campaign: The pool should be XRP-ROOT pool");
        new Campaign(
            address(root),
            address(xrp),
            address(vault),
            poolAddress,
            poolId
        );
    }

    function test_CampaignNoLiquidity() public {
        vm.startPrank(originalAdmin);

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
            originalAdmin,
            0x26504c2e4f5b39452f306c7a2b25763b7137415e2835535d58495865366a4724
        );
        poolId = IBasePool(poolAddress).getPoolId();

        vm.expectRevert("Campaign: The pool should have liquidity");
        new Campaign(
            address(root),
            address(xrp),
            address(vault),
            poolAddress,
            poolId
        );
    }
}
