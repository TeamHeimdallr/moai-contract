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

    struct Status {
        uint bptTotalSupply;
        uint amountRootInVault;
        uint amountXrpInVault;
        uint amountFarmed;
        uint amountPairedBPTLocked;
        uint unclaimedReward;
        uint lastRewardTime;
        uint depositedTime;
    }

    function _getVaultBalance() internal view returns (uint, uint) {
        uint[] memory poolTokenBalances;
        (, poolTokenBalances, ) = IVault(address(vault)).getPoolTokens(poolId);

        return (poolTokenBalances[rootIndex], poolTokenBalances[xrpIndex]);
    }

    function _getStatus()
        internal
        view
        returns (
            uint bptTotalSupply,
            uint amountRootInVault,
            uint amountXrpInVault
        )
    {
        bptTotalSupply = bpt.totalSupply();
        (amountRootInVault, amountXrpInVault) = _getVaultBalance();
    }

    function _getStatusWithFarm(
        address account
    ) internal view returns (Status memory status) {
        (
            status.bptTotalSupply,
            status.amountRootInVault,
            status.amountXrpInVault
        ) = _getStatus();
        (
            status.amountFarmed,
            status.amountPairedBPTLocked,
            status.unclaimedReward,
            status.lastRewardTime,
            status.depositedTime
        ) = campaign.farms(account);
    }

    function _participate(
        address account,
        uint amountXrpIn,
        uint amountRootIn
    ) internal {
        address originalAddress = msg.sender;
        vm.startPrank(account);
        vm.warp(campaign.rewardStartTime() + 1);
        if (amountXrpIn > 0) {
            xrp.faucet(account, amountXrpIn);
            xrp.approve(address(campaign), amountXrpIn);
        }
        if (amountRootIn > 0) {
            root.faucet(account, amountRootIn);
            root.approve(address(campaign), amountRootIn);
        }
        campaign.participate(amountXrpIn, amountRootIn);
        vm.startPrank(originalAddress);
    }

    function test_ParticipateOnlyXRP() public {
        uint amountXrpIn = 100 * 1e18;
        uint amountRootIn = 0;
        uint campaignStartTime = campaign.rewardStartTime();
        vm.warp(campaignStartTime + 1);

        (
            uint bptTotalSupplyBefore,
            uint amountRootInVaultBefore,
            uint amountXrpInVaultBefore
        ) = _getStatus();

        _participate(alice, amountXrpIn, amountRootIn);

        Status memory status = _getStatusWithFarm(alice);

        // check status
        uint mintedBpt = status.bptTotalSupply - bptTotalSupplyBefore;
        uint rootVaultAmountDiff = status.amountRootInVault -
            amountRootInVaultBefore;
        uint xrpVaultAmountDiff = status.amountXrpInVault -
            amountXrpInVaultBefore;
        uint liquiditySupportAfter = campaign.liquiditySupport();

        assertEq(campaignStartTime + 1, status.depositedTime);
        assertEq(status.depositedTime, status.lastRewardTime);
        assertEq(0, status.amountPairedBPTLocked);
        assertEq(0, status.unclaimedReward);
        assertEq(mintedBpt / 2, status.amountFarmed);
        assertEq(
            rootVaultAmountDiff,
            initialRootLiquiditySupport - liquiditySupportAfter
        );
        assertEq(xrpVaultAmountDiff, amountXrpIn);
    }

    function test_ParticipateOnlyROOT() public {
        uint amountXrpIn = 0;
        uint amountRootIn = 100 * 1e18;
        uint campaignStartTime = campaign.rewardStartTime();
        vm.warp(campaignStartTime + 1);

        (
            uint bptTotalSupplyBefore,
            uint amountRootInVaultBefore,
            uint amountXrpInVaultBefore
        ) = _getStatus();

        _participate(alice, amountXrpIn, amountRootIn);

        Status memory status = _getStatusWithFarm(alice);

        // check status
        uint mintedBpt = status.bptTotalSupply - bptTotalSupplyBefore;
        uint rootVaultAmountDiff = status.amountRootInVault -
            amountRootInVaultBefore;
        uint xrpVaultAmountDiff = status.amountXrpInVault -
            amountXrpInVaultBefore;
        uint liquiditySupportAfter = campaign.liquiditySupport();

        assertEq(campaignStartTime + 1, status.depositedTime);
        assertEq(status.depositedTime, status.lastRewardTime);
        assertEq(0, status.amountPairedBPTLocked);
        assertEq(0, status.unclaimedReward);
        assertEq(mintedBpt / 2, status.amountFarmed);
        assertEq(
            rootVaultAmountDiff,
            (initialRootLiquiditySupport - liquiditySupportAfter) + amountRootIn
        );
        assertEq(xrpVaultAmountDiff, 0);
    }

    function test_ParticipateBoth() public {
        uint amountXrpIn = 71 * 1e18;
        uint amountRootIn = 100 * 1e18;
        uint campaignStartTime = campaign.rewardStartTime();
        vm.warp(campaignStartTime + 1);

        (
            uint bptTotalSupplyBefore,
            uint amountRootInVaultBefore,
            uint amountXrpInVaultBefore
        ) = _getStatus();

        _participate(alice, amountXrpIn, amountRootIn);

        Status memory status = _getStatusWithFarm(alice);

        // check status
        uint mintedBpt = status.bptTotalSupply - bptTotalSupplyBefore;
        uint rootVaultAmountDiff = status.amountRootInVault -
            amountRootInVaultBefore;
        uint xrpVaultAmountDiff = status.amountXrpInVault -
            amountXrpInVaultBefore;
        uint liquiditySupportAfter = campaign.liquiditySupport();

        assertEq(campaignStartTime + 1, status.depositedTime);
        assertEq(status.depositedTime, status.lastRewardTime);
        assertEq(0, status.amountPairedBPTLocked);
        assertEq(0, status.unclaimedReward);
        assertEq(mintedBpt / 2, status.amountFarmed);
        assertEq(
            rootVaultAmountDiff,
            (initialRootLiquiditySupport - liquiditySupportAfter) + amountRootIn
        );
        assertEq(xrpVaultAmountDiff, amountXrpIn);
    }

    function testFail_ParticipateZeroAmount() public {
        uint amountXrpIn = 0;
        uint amountRootIn = 0;
        uint campaignStartTime = campaign.rewardStartTime();
        vm.warp(campaignStartTime + 1);

        _participate(alice, amountXrpIn, amountRootIn);
    }

    function testFail_ParticipateBeforeRewardStart() public {
        uint amountXrpIn = 1e4 * 1e18;
        uint amountRootIn = 1e4 * 1e18;
        uint campaignStartTime = campaign.rewardStartTime();
        vm.warp(campaignStartTime - 1);

        _participate(alice, amountXrpIn, amountRootIn);
    }

    function testFail_ParticipateAfterRewardEnd() public {
        uint amountXrpIn = 1e4 * 1e18;
        uint amountRootIn = 1e4 * 1e18;
        uint campaignEndTime = campaign.rewardEndTime();
        vm.warp(campaignEndTime + 1);

        _participate(alice, amountXrpIn, amountRootIn);
    }

    function testFail_ParticipateNotEnoughLiquiditySupport() public {
        uint amountXrpIn = initialRootLiquiditySupport + 1e4 * 1e18;
        uint amountRootIn = 0;
        uint campaignStartTime = campaign.rewardStartTime();
        vm.warp(campaignStartTime + 1);

        _participate(alice, amountXrpIn, amountRootIn);
    }

    function testFail_ParticipateNotEnoughReward() public {
        uint amountRootIn = 0;
        uint campaignStartTime = campaign.rewardStartTime();
        vm.warp(campaignStartTime + 1);

        uint currentRewardToBePaid = campaign.rewardToBePaid();
        uint remainedRewardToBePaid = campaign.rewardPool() -
            currentRewardToBePaid;
        uint maximumFarmingAmountBpt = (1e6 *
            ((remainedRewardToBePaid * 365 days) /
                (campaign.rewardEndTime() - (campaignStartTime + 1)))) /
            campaign.apr();

        (
            uint bptTotalSupplyBefore,
            ,
            uint amountXrpInVaultBefore
        ) = _getStatus();

        uint eps = 1e18;
        uint amountXrpIn = ((2 *
            maximumFarmingAmountBpt *
            amountXrpInVaultBefore) / bptTotalSupplyBefore) + (eps);

        // add more liquidity support
        root.approve(address(campaign), amountXrpIn);
        campaign.supportLiquidity(amountXrpIn);

        _participate(alice, amountXrpIn, amountRootIn);
    }
}
