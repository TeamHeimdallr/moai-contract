pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "./CampaignTestSetup.t.sol";

contract RewardAdmin is CampaignTestSetup {
    address rewardAdmin = makeAddr("rewardAdmin");
    address alice = makeAddr("alice");

    function setUp() public override {
        super.setUp();
        vm.prank(originalAdmin);
        campaign.changeRewardAdmin(rewardAdmin);
    }

    function test_ChangeRewardAdmin() public {
        vm.prank(rewardAdmin);
        campaign.changeRewardAdmin(alice);
        assertEq(bpt.balanceOf(alice), 0);

        vm.expectRevert("Campaign: Only rewardAdmin can do");
        vm.prank(rewardAdmin);
        campaign.withdrawRewards(1);

        assertTrue(bpt.balanceOf(alice) == 0);
        vm.prank(alice);
        campaign.withdrawRewards(1);
        assertTrue(bpt.balanceOf(alice) == 1);
    }

    function test_ProvideMoreRewards() public {
        uint originalRewardPool = campaign.rewardPool();
        assertTrue(bpt.balanceOf(rewardAdmin) == 0);

        vm.startPrank(rewardAdmin);

        // Provide liquidity
        uint amountXrp = 1e8 * 1e18;
        uint amountRoot = amountXrp;

        xrp.faucet(rewardAdmin, amountXrp);
        root.faucet(rewardAdmin, amountRoot);

        xrp.approve(address(vault), amountXrp);
        root.approve(address(vault), amountRoot);

        IAsset[] memory joinAsset = new IAsset[](2);
        joinAsset[rootIndex] = IAsset(address(root));
        joinAsset[xrpIndex] = IAsset(address(xrp));

        uint[] memory joinAmountsIn = new uint[](2);
        joinAmountsIn[rootIndex] = amountRoot;
        joinAmountsIn[xrpIndex] = amountXrp;

        bytes memory userData = abi.encode(
            WeightedPoolUserData.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT,
            joinAmountsIn,
            0
        );

        IVault.JoinPoolRequest memory request = IVault.JoinPoolRequest({
            assets: joinAsset,
            maxAmountsIn: joinAmountsIn,
            userData: userData,
            fromInternalBalance: false
        });

        IVault(address(vault)).joinPool(
            poolId,
            rewardAdmin,
            rewardAdmin,
            request
        );

        // Provide rewards
        uint bptAmount = bpt.balanceOf(rewardAdmin);
        bpt.approve(address(campaign), bptAmount);
        campaign.provideRewards(bptAmount);
        vm.stopPrank();

        assertEq(bptAmount, campaign.rewardPool() - originalRewardPool);
    }

    function test_WithdrawRewards() public {
        assertTrue(bpt.balanceOf(rewardAdmin) == 0);
        uint originalRewardPool = campaign.rewardPool();
        vm.startPrank(rewardAdmin);
        campaign.withdrawRewards(originalRewardPool / 2);
        assertEq(campaign.rewardPool(), originalRewardPool / 2);
        assertEq(bpt.balanceOf(rewardAdmin), originalRewardPool / 2);
        vm.stopPrank();
    }

    function test_ChangeApr() public {
        uint originalApr = campaign.apr();
        uint originalRewardToBePaid = campaign.rewardToBePaid();
        vm.startPrank(rewardAdmin);
        uint newApr = 1e23; // 1e19%
        campaign.changeApr(newApr);
        assertEq(newApr, campaign.apr());
        assertEq(
            (originalRewardToBePaid * newApr) / originalApr,
            campaign.rewardToBePaid()
        );

        // Participation should fail due to farming cap
        vm.startPrank(alice);
        uint amountXrp = 1e20;
        xrp.faucet(alice, amountXrp);
        xrp.approve(address(campaign), amountXrp);
        vm.expectRevert("Campaign: Farming cap is full");
        campaign.participate(amountXrp, 0);
    }

    function test_ChangeUserLockupPeriod() public {
        vm.startPrank(alice);
        uint amountXrp = 1e20;
        xrp.faucet(alice, amountXrp);
        xrp.approve(address(campaign), amountXrp);
        campaign.participate(amountXrp, 0);

        vm.expectRevert("Campaign: Lockup period");
        campaign.withdraw(1);

        uint originalUserLockupPeriod = campaign.userLockupPeriod();
        vm.warp(block.timestamp + originalUserLockupPeriod / 2 + 1);
        vm.expectRevert("Campaign: Lockup period");
        campaign.withdraw(1);
        vm.stopPrank();

        vm.prank(rewardAdmin);
        campaign.changeUserLockupPeriod(originalUserLockupPeriod / 2);
        assertEq(campaign.userLockupPeriod(), originalUserLockupPeriod / 2);

        vm.prank(alice);
        campaign.withdraw(1);
    }

    // function test_ChangeRewardTime() public {}
}
