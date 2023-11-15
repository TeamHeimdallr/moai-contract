pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "./CampaignTestSetup.t.sol";
import "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";

contract ParticipateTest is CampaignTestSetup {
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public override {
        super.setUp();
    }

    function _getVaultBalance() internal view returns (uint, uint) {
        IERC20[] memory _poolTokens;
        uint[] memory poolTokenBalances;
        uint _lastChangeBlock;
        (_poolTokens, poolTokenBalances, _lastChangeBlock) = IVault(
            address(vault)
        ).getPoolTokens(poolId);

        return (poolTokenBalances[rootIndex], poolTokenBalances[xrpIndex]);
    }

    function test_ParticipateOnlyXRP() public {
        vm.startPrank(alice);
        uint campaignStartTime = campaign.rewardStartTime();
        vm.warp(campaignStartTime + 1);

        uint bptSupplyBeforeParticipate = bpt.totalSupply();
        (
            uint rootVaultAmountBefore,
            uint xrpVaultAmountBefore
        ) = _getVaultBalance();

        uint amountXrpIn = 100 * 1e18;
        xrp.faucet(alice, amountXrpIn * 2);
        xrp.approve(address(campaign), amountXrpIn);
        campaign.participate(amountXrpIn, 0);

        (
            uint amountFarmed,
            uint amountPairedBPTLocked,
            ,
            uint lastRewardTime,
            uint depositedTime
        ) = campaign.farms(alice);

        assertEq(campaignStartTime + 1, depositedTime);
        assertEq(depositedTime, lastRewardTime);
        assertEq(0, amountPairedBPTLocked);

        uint bptSupplyAfterParticipate = bpt.totalSupply();
        uint mintedBpt = bptSupplyAfterParticipate - bptSupplyBeforeParticipate;

        assertEq(mintedBpt / 2, amountFarmed);

        (
            uint rootVaultAmountAfter,
            uint xrpVaultAmountAfter
        ) = _getVaultBalance();

        uint rootVaultAmountDiff = rootVaultAmountAfter - rootVaultAmountBefore;
        uint xrpVaultAmountDiff = xrpVaultAmountAfter - xrpVaultAmountBefore;

        uint liquiditySupportAfter = campaign.liquiditySupport();

        assertEq(
            rootVaultAmountDiff,
            initialRootLiquiditySupport - liquiditySupportAfter
        );
        assertEq(xrpVaultAmountDiff, amountXrpIn);

        vm.stopPrank();
    }

    function test_ParticipateOnlyROOT() public {
        vm.startPrank(alice);
        uint campaignStartTime = campaign.rewardStartTime();
        vm.warp(campaignStartTime + 1);

        uint bptSupplyBeforeParticipate = bpt.totalSupply();

        uint amountRootIn = 100 * 1e18;
        root.faucet(alice, amountRootIn * 2);
        root.approve(address(campaign), amountRootIn);
        campaign.participate(0, amountRootIn);

        (
            uint amountFarmed,
            uint amountPairedBPTLocked,
            ,
            uint lastRewardTime,
            uint depositedTime
        ) = campaign.farms(alice);

        assertEq(campaignStartTime + 1, depositedTime);
        assertEq(depositedTime, lastRewardTime);
        assertEq(0, amountPairedBPTLocked);

        uint bptSupplyAfterParticipate = bpt.totalSupply();
        uint mintedBpt = bptSupplyAfterParticipate - bptSupplyBeforeParticipate;

        assertEq(mintedBpt / 2, amountFarmed);

        vm.stopPrank();
    }
}
