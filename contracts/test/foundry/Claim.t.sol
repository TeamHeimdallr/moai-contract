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

        // get current BPT being farmed
        (uint amountFarmed, , , , ) = campaign.farms(alice);

        vm.warp(campaign.rewardEndTime());
        vm.startPrank(alice);
        uint originalCampaignBpt = bpt.balanceOf(address(campaign));
        campaign.claim();
        assertEq(
            originalCampaignBpt - bpt.balanceOf(address(campaign)),
            (((amountFarmed * campaign.apr()) / 1e6) *
                (campaign.rewardEndTime() - campaign.rewardStartTime())) /
                2 /
                365 days
        );
    }

    // TODO : this should be passed!
    function testFail_ClaimRewardNotAccumulatedAfterEndTime() public {
        uint amountXrpIn = 1e2 * 1e18;
        _participate(
            alice,
            amountXrpIn,
            (campaign.rewardEndTime() + campaign.rewardStartTime()) / 2
        );

        _participate(
            bob,
            amountXrpIn,
            (campaign.rewardEndTime() + campaign.rewardStartTime()) / 2
        );

        // Alice claims at reward ended
        vm.warp(campaign.rewardEndTime());
        vm.startPrank(alice);
        uint originalCampaignBptAlice = bpt.balanceOf(address(campaign));
        campaign.claim();
        uint aliceRewards = originalCampaignBptAlice -
            bpt.balanceOf(address(campaign));
        vm.stopPrank();

        // Bob claims after reward ended
        vm.warp(campaign.rewardEndTime() + 1e9);
        vm.startPrank(bob);
        uint originalCampaignBptBob = bpt.balanceOf(address(campaign));
        campaign.claim();
        uint bobRewards = originalCampaignBptBob -
            bpt.balanceOf(address(campaign));
        vm.stopPrank();

        // TODO : slightly different ... 110984271920968 and 110984271920964 ...
        assertEq(aliceRewards, bobRewards);
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
