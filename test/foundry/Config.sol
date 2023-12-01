pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "./CampaignTestSetup.t.sol";

// TODO : to be seperated in detail
contract ConfigTest is CampaignTestSetup {
    function test_PoolBalance() public view {
        IERC20[] memory poolTokens;
        uint[] memory poolTokenBalances;
        (poolTokens, poolTokenBalances, ) = IVault(address(vault))
            .getPoolTokens(poolId);

        require(
            poolTokenBalances[0] == initialJoinAmount,
            "pool 0 balance is not correct"
        );
        require(
            poolTokenBalances[1] == initialJoinAmount,
            "pool 1 balance is not correct"
        );
    }

    function test_RewardTime() public view {
        uint startTime_ = campaign.rewardStartTime();
        uint endTime_ = campaign.rewardEndTime();

        require(startTime == startTime_, "reward start time is not correct");
        require(endTime == endTime_, "reward end time is not correct");
    }

    function test_LiquiditySupport() public view {
        uint liquiditySupport = campaign.liquiditySupport();

        require(
            liquiditySupport == initialRootLiquiditySupport,
            "liquidity support is not correct"
        );
    }

    function test_ProvideReward() public view {
        uint rewardPool = campaign.rewardPool();

        require(
            rewardPool == initialRewardAmount,
            "reward pool is not correct"
        );

        uint rewardBalance = bpt.balanceOf(address(campaign));
        require(
            rewardBalance == initialRewardAmount,
            "reward balance is not correct"
        );
    }
}
