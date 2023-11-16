pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "./CampaignTestSetup.t.sol";
import "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";

contract RootLiquidityAdminTest is CampaignTestSetup {
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public override {
        super.setUp();
    }

    function _participate(
        address user,
        uint amountXrpIn,
        uint timestamp
    ) internal {
        address originalAddress = msg.sender;
        vm.startPrank(user);
        vm.warp(timestamp);
        xrp.faucet(user, amountXrpIn);
        xrp.approve(address(campaign), amountXrpIn);
        campaign.participate(amountXrpIn, 0);
        vm.startPrank(originalAddress);
    }

    function _withdraw(
        address user,
        uint amountBptOut,
        uint timestamp
    ) internal {
        address originalAddress = msg.sender;
        vm.startPrank(user);
        vm.warp(timestamp);
        campaign.withdraw(amountBptOut);
        vm.startPrank(originalAddress);
    }

    function test_ChangeRootLiquidityAdmin() public {
        vm.startPrank(originalAdmin);
        campaign.changeRootLiquidityAdmin(alice);
        vm.stopPrank();

        assertEq(campaign.rootLiquidityAdmin(), alice);
    }

    function test_ChangeRootLiquidityAdminNotAdmin() public {
        vm.startPrank(alice);
        vm.expectRevert("Campaign: Only rootLiquidityAdmin can do");
        campaign.changeRootLiquidityAdmin(bob);
    }

    function test_ChangeRootLiquidityAdminWithFarmed() public {
        _participate(alice, 1e18, campaign.rewardStartTime() + 1);
        vm.stopPrank();
        vm.startPrank(originalAdmin);
        vm.expectRevert("Campaign: New admin must not have a farm.");
        campaign.changeRootLiquidityAdmin(alice);
    }

    function test_TakebackSupportAll() public {
        vm.startPrank(originalAdmin);
        uint amountRootBefore = root.balanceOf(originalAdmin);
        campaign.takebackSupport(initialRootLiquiditySupport);
        uint amountRootAfter = root.balanceOf(originalAdmin);
        vm.stopPrank();

        assertEq(
            amountRootAfter - amountRootBefore,
            initialRootLiquiditySupport
        );
        assertEq(campaign.liquiditySupport(), 0);
    }

    function test_TakebackSupportPartially() public {
        vm.startPrank(originalAdmin);
        uint amountRootBefore = root.balanceOf(originalAdmin);
        campaign.takebackSupport(initialRootLiquiditySupport / 2);
        uint amountRootAfter = root.balanceOf(originalAdmin);
        vm.stopPrank();

        assertEq(
            amountRootAfter - amountRootBefore,
            initialRootLiquiditySupport / 2
        );
        assertEq(campaign.liquiditySupport(), initialRootLiquiditySupport / 2);
    }

    function test_TakebackSupportNotEnough() public {
        vm.startPrank(originalAdmin);
        vm.expectRevert(
            "Campaign: Not enough supported liquidity to take back"
        );
        campaign.takebackSupport(initialRootLiquiditySupport + 1);
    }

    function test_TakebackSupportNotAdmin() public {
        vm.startPrank(alice);
        vm.expectRevert("Campaign: Only rootLiquidityAdmin can do");
        campaign.takebackSupport(1e18);
    }

    function test_WithdrawSupportAfterCampaignAll() public {
        _participate(alice, 1e18, campaign.rewardStartTime() + 1);
        (uint amountFarmed, , , , ) = campaign.farms(alice);
        uint bptAmount = amountFarmed;
        _withdraw(
            alice,
            bptAmount,
            campaign.rewardStartTime() + campaign.periodToLockupLPSupport() + 2
        );

        vm.stopPrank();
        vm.startPrank(originalAdmin);
        vm.warp(
            campaign.rewardEndTime() +
                campaign.liquiditySupportLockupPeriod() +
                1
        );
        uint lockedLiquidity = campaign.lockedLiquidity();
        uint amountBptBefore = bpt.balanceOf(originalAdmin);
        campaign.withdrawSupportAfterCampaign(lockedLiquidity);
        uint amountBptAfter = bpt.balanceOf(originalAdmin);
        vm.stopPrank();

        assertEq(amountBptAfter - amountBptBefore, lockedLiquidity);
        assertEq(0, campaign.lockedLiquidity());
    }

    function test_WithdrawSupportAfterCampaignPartially() public {
        _participate(alice, 1e18, campaign.rewardStartTime() + 1);
        (uint amountFarmed, , , , ) = campaign.farms(alice);
        uint bptAmount = amountFarmed;
        _withdraw(
            alice,
            bptAmount,
            campaign.rewardStartTime() + campaign.periodToLockupLPSupport() + 2
        );

        vm.stopPrank();
        vm.startPrank(originalAdmin);
        vm.warp(
            campaign.rewardEndTime() +
                campaign.liquiditySupportLockupPeriod() +
                1
        );
        uint lockedLiquidity = campaign.lockedLiquidity();
        uint amountBptBefore = bpt.balanceOf(originalAdmin);
        campaign.withdrawSupportAfterCampaign(lockedLiquidity - 1);
        uint amountBptAfter = bpt.balanceOf(originalAdmin);
        vm.stopPrank();

        assertEq(amountBptAfter - amountBptBefore, lockedLiquidity - 1);
        assertEq(1, campaign.lockedLiquidity());
    }

    function test_WithdrawSupportAfterCampaignNotEnough() public {
        _participate(alice, 1e18, campaign.rewardStartTime() + 1);
        (uint bptAmount, , , , ) = campaign.farms(alice);
        _withdraw(
            alice,
            bptAmount,
            campaign.rewardStartTime() + campaign.periodToLockupLPSupport() + 2
        );

        vm.stopPrank();
        vm.startPrank(originalAdmin);
        vm.warp(
            campaign.rewardEndTime() +
                campaign.liquiditySupportLockupPeriod() +
                1
        );
        uint lockedLiquidity = campaign.lockedLiquidity();
        vm.expectRevert("Campaign: Not enough locked liquidity to withdraw");
        campaign.withdrawSupportAfterCampaign(lockedLiquidity + 1);
    }

    function test_WithdrawSupportBeforeCampaign() public {
        _participate(alice, 1e18, campaign.rewardStartTime() + 1);

        vm.stopPrank();
        vm.startPrank(originalAdmin);
        vm.warp(
            campaign.rewardEndTime() +
                campaign.liquiditySupportLockupPeriod() -
                1
        );
        vm.expectRevert("Campaign: Not able to withdraw liquidity yet");
        campaign.withdrawSupportAfterCampaign(10);
    }

    function test_WithdrawSupportAfterCampaignNotAdmin() public {
        _participate(alice, 1e18, campaign.rewardStartTime() + 1);

        vm.stopPrank();
        vm.startPrank(alice);
        vm.warp(
            campaign.rewardEndTime() +
                campaign.liquiditySupportLockupPeriod() +
                1
        );
        vm.expectRevert("Campaign: Only rootLiquidityAdmin can do");
        campaign.withdrawSupportAfterCampaign(10);
    }
}
