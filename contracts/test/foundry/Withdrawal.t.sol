pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "./CampaignTestSetup.t.sol";

contract WithdrawalTest is CampaignTestSetup {
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

    function test_Withdrawal() public {
        _participate(
            alice,
            1e2 * 1e18,
            (campaign.rewardEndTime() + campaign.rewardStartTime()) / 2
        );
        (uint amountFarmed, , , , uint depositedTime) = campaign.farms(alice);

        vm.startPrank(alice);
        vm.warp(block.timestamp + campaign.userLockupPeriod() + 1);
        uint originalCampaignBpt = bpt.balanceOf(address(campaign));
        uint originalLockedLiquidity = campaign.lockedLiquidity();
        (Campaign.Farm memory farmSimulated, , , ) = campaign.simulateAccrue(
            alice
        );

        campaign.withdraw(amountFarmed);
        (Campaign.Farm memory farmSimulatedAfterWithdrawal, , , ) = campaign
            .simulateAccrue(alice);
        uint expectedRewards = (((amountFarmed * campaign.apr()) / 1e6) *
            ((
                campaign.rewardEndTime() < block.timestamp
                    ? campaign.rewardEndTime()
                    : block.timestamp
            ) - depositedTime)) / 365 days;

        assertEq(
            originalCampaignBpt - bpt.balanceOf(address(campaign)),
            amountFarmed * 2
        );
        assertEq(campaign.lockedLiquidity(), originalLockedLiquidity);
        assertEq(farmSimulatedAfterWithdrawal.amountFarmed, 0);
        assertEq(
            farmSimulatedAfterWithdrawal.unclaimedRewards,
            farmSimulated.unclaimedRewards
        );
        assertEq(
            farmSimulatedAfterWithdrawal.unclaimedRewards,
            expectedRewards
        );
    }

    function test_WithdrawalPartially() public {
        _participate(
            alice,
            1e2 * 1e18,
            (campaign.rewardEndTime() + campaign.rewardStartTime()) / 2
        );

        (uint amountFarmed, , , , uint depositedTime) = campaign.farms(alice);

        vm.startPrank(alice);
        vm.warp(block.timestamp + campaign.userLockupPeriod() + 1);
        uint originalCampaignBpt = bpt.balanceOf(address(campaign));
        uint originalLockedLiquidity = campaign.lockedLiquidity();
        (Campaign.Farm memory farmSimulated, , , ) = campaign.simulateAccrue(
            alice
        );

        campaign.withdraw(amountFarmed / 2);
        (Campaign.Farm memory farmSimulatedAfterWithdrawal, , , ) = campaign
            .simulateAccrue(alice);
        uint expectedRewards = (((amountFarmed * campaign.apr()) / 1e6) *
            ((
                campaign.rewardEndTime() < block.timestamp
                    ? campaign.rewardEndTime()
                    : block.timestamp
            ) - depositedTime)) / 365 days;

        // No locked liquidity
        assertEq(campaign.lockedLiquidity(), originalLockedLiquidity);
        assertEq(
            originalCampaignBpt - bpt.balanceOf(address(campaign)),
            2 * (amountFarmed / 2) // So (the amount of user withdrawal) * 2 is substracted
        );

        assertEq(
            farmSimulatedAfterWithdrawal.amountFarmed,
            amountFarmed - amountFarmed / 2
        );
        assertEq(
            farmSimulatedAfterWithdrawal.unclaimedRewards,
            farmSimulated.unclaimedRewards
        );
        assertEq(
            farmSimulatedAfterWithdrawal.unclaimedRewards,
            expectedRewards
        );
    }

    function test_WithdrawalWithPairLockedUp() public {
        _participate(
            alice,
            1e2 * 1e18,
            (campaign.rewardEndTime() + campaign.rewardStartTime()) / 2
        );
        (uint amountFarmed, , , , uint depositedTime) = campaign.farms(alice);

        vm.startPrank(alice);
        vm.warp(block.timestamp + campaign.periodToLockupLPSupport() + 1);
        uint originalCampaignBpt = bpt.balanceOf(address(campaign));
        (Campaign.Farm memory farmSimulated, , , ) = campaign.simulateAccrue(
            alice
        );

        assertEq(farmSimulated.amountPairedBPTLocked, amountFarmed);

        campaign.withdraw(amountFarmed);
        (Campaign.Farm memory farmSimulatedAfterWithdrawal, , , ) = campaign
            .simulateAccrue(alice);
        uint expectedRewards = (((amountFarmed * campaign.apr()) / 1e6) *
            ((
                campaign.rewardEndTime() < block.timestamp
                    ? campaign.rewardEndTime()
                    : block.timestamp
            ) - depositedTime)) / 365 days;

        assertEq(
            originalCampaignBpt - bpt.balanceOf(address(campaign)),
            amountFarmed // Liquidity Locked Up
        );
        assertEq(campaign.lockedLiquidity(), amountFarmed);
        assertEq(farmSimulatedAfterWithdrawal.amountPairedBPTLocked, 0);
        assertEq(
            farmSimulatedAfterWithdrawal.unclaimedRewards,
            farmSimulated.unclaimedRewards
        );
        assertEq(
            farmSimulatedAfterWithdrawal.unclaimedRewards,
            expectedRewards
        );
    }
}
