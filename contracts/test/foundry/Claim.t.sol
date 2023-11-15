pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "./CampaignTestSetup.t.sol";

contract ClaimTest is CampaignTestSetup {
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

    function test_Claim() public {
        _participate(
            alice,
            1e2 * 1e18,
            (campaign.rewardEndTime() + campaign.rewardStartTime()) / 2
        );

        (
            uint amountFarmed,
            ,
            uint unclaimedRewards,
            uint lastRewardTime,
            uint depositedTime
        ) = campaign.farms(alice);
        assertEq(unclaimedRewards, 0);
        assertEq(lastRewardTime, block.timestamp);

        vm.warp(campaign.rewardEndTime());
        (Campaign.Farm memory farmSimulated, , , ) = campaign.simulateAccrue(
            alice
        );

        assertEq(amountFarmed, farmSimulated.amountFarmed);
        assertEq(farmSimulated.lastRewardTime, block.timestamp);
        assertEq(depositedTime, farmSimulated.depositedTime);

        uint expectedReward = (((amountFarmed * campaign.apr()) / 1e6) *
            (campaign.rewardEndTime() - campaign.rewardStartTime())) /
            2 /
            365 days;

        assertEq(farmSimulated.unclaimedRewards, expectedReward);

        vm.startPrank(alice);
        uint originalCampaignBpt = bpt.balanceOf(address(campaign));
        campaign.claim();
        assertEq(
            originalCampaignBpt - bpt.balanceOf(address(campaign)),
            expectedReward
        );

        (
            uint amountFarmedAfterClaim,
            ,
            uint unclaimedRewardsAfterClaim,
            uint lastRewardTimeAfterClaim,
            uint depositedTimeAfterClaim
        ) = campaign.farms(alice);
        assertEq(amountFarmed, amountFarmedAfterClaim);
        assertEq(unclaimedRewardsAfterClaim, 0);
        assertEq(lastRewardTimeAfterClaim, block.timestamp);
        assertEq(depositedTime, depositedTimeAfterClaim);
    }

    function test_ClaimRewardNotAccumulatedAfterEndTime() public {
        uint amountXrpIn = 1e2 * 1e18;
        _participate(
            alice,
            amountXrpIn,
            (campaign.rewardEndTime() + campaign.rewardStartTime()) / 2
        );
        (uint amountFarmed, , , , ) = campaign.farms(alice);

        vm.warp(campaign.rewardEndTime() + 1e9);
        vm.startPrank(alice);
        uint originalCampaignBptAlice = bpt.balanceOf(address(campaign));
        campaign.claim();
        uint aliceRewards = originalCampaignBptAlice -
            bpt.balanceOf(address(campaign));
        vm.stopPrank();

        // rewards should be given only for (max(claimedTime, rewardEndTime) - depositedTime)
        uint expectedRewards = (((amountFarmed * campaign.apr()) / 1e6) *
            (campaign.rewardEndTime() - campaign.rewardStartTime())) /
            2 /
            365 days;

        assertEq(expectedRewards, aliceRewards);
    }

    function testFail_ClaimWithoutParticipation() public {
        vm.warp((campaign.rewardEndTime() + campaign.rewardStartTime()) / 2);
        _participate(
            alice,
            1e2 * 1e18,
            (campaign.rewardEndTime() + campaign.rewardStartTime()) / 2
        );
        vm.startPrank(bob);
        campaign.claim();
    }

    function testFail_ClaimWithZeroReward() public {
        _participate(
            alice,
            1e2 * 1e18,
            (campaign.rewardEndTime() + campaign.rewardStartTime()) / 2
        );

        vm.warp(
            (2 * campaign.rewardEndTime() + campaign.rewardStartTime()) / 3
        );
        vm.startPrank(alice);
        campaign.claim();
        // 2nd claim at the same time
        campaign.claim();
    }
}
