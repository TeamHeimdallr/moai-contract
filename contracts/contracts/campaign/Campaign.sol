// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.7.1;
pragma experimental ABIEncoderV2;

import "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
import "@balancer-labs/v2-interfaces/contracts/vault/IAsset.sol";
import "@balancer-labs/v2-interfaces/contracts/pool-weighted/WeightedPoolUserData.sol";
import "@balancer-labs/v2-solidity-utils/contracts/math/FixedPoint.sol";

contract Campaign {
    using FixedPoint for uint256;

    address public constant ROOT_TOKEN_ADDR =
        0xcCcCCccC00000001000000000000000000000000;
    address public constant XRP_TOKEN_ADDR =
        0xCCCCcCCc00000002000000000000000000000000;
    address public constant MOAI_VAULT_ADDR =
        0x6548DEA2fB59143215E54595D0157B79aac1335e;
    address public constant XRP_ROOT_BPT_ADDR =
        0x291AF6E1b841cAD6e3DCD66f2AA0790a007578AD;
    bytes32 public constant MOAI_POOL_ID =
        bytes32(
            0x291af6e1b841cad6e3dcd66f2aa0790a007578ad000200000000000000000000
        );

    // Configurations
    uint public apr = 70000; // 100% = 1000000, 1e6
    // User can't withdraw its deposit before 'userLockupPeriod' has passed since its last deposit
    uint public userLockupPeriod = 12 hours;
    // If a deposit is locked up more than 'periodToLockupLPSupport',
    //  the supported liquidity by Futureverse becomes locked up for 2 years
    //  The locked up BPT isn't freed when the user withdraw from this campaign
    uint public periodToLockupLPSupport = 1 weeks; // TODO : changeable or not?
    uint public rewardStartTime = type(uint256).max - 1;
    uint public rewardEndTime = type(uint256).max;
    address rewardAdmin = 0x0000000000000000000000000000000000000000; // Moai Finance
    address rootLiquidityAdmin = 0x0000000000000000000000000000000000000000; // Futureverse

    uint liquiditySupport;
    uint lockedLiquidity;

    uint rewardPool;
    uint rewardToBePaid;

    struct Farm {
        uint amountFarmed;
        uint amountLocked; // TODO : rename this. The amount of BPT whose paired BPT of Futureverse was locked
        uint unclaimedRewards;
        uint lastRewardTime;
        uint depositedTime;
    }

    mapping(address => Farm) public farms;

    modifier onlyRewardAdmin() {
        require(msg.sender == rewardAdmin, "Only rewardAdmin can do");
        _;
    }

    modifier onlyRootLiquidityAdmin() {
        require(
            msg.sender == rootLiquidityAdmin,
            "Only rootLiquidityAdmin can do"
        );
        _;
    }

    event SwapRootToXrp(uint amountRootIn, uint amountXrpOut);

ß    /*
        Campaign Part
            - interact with users and Moai Finance contracts
            - Not directly interact with farm variables
        Campaign Participation Scenario
            1. Users add liquidity through this part
            2-A. If there are $ROOT, swap all into $XRP via Moai Finance
            2-B. Provide $XRP-$ROOT liquidity and all the $ROOTs are from Futureverse
                Note) The half of LP tokens should belong to Futureverse
            3. Farm users' LP tokens
    */

    function participate(uint amountXrp, uint amountRootIn) external {
        require(
            amountXrp > 0 || amountRootIn > 0,
            "Campaign: No amount to participate"
        );

        if (amountXrp > 0) {
            IERC20(XRP_TOKEN_ADDR).transferFrom(
                msg.sender,
                address(this),
                amountXrp
            );
        }

        if (amountRootIn > 0) {
            IERC20(ROOT_TOKEN_ADDR).transferFrom(
                msg.sender,
                address(this),
                amountRootIn
            );

            IERC20(ROOT_TOKEN_ADDR).approve(MOAI_VAULT_ADDR, amountRootIn);

            IVault.SingleSwap memory singleSwap = IVault.SingleSwap({
                poolId: MOAI_POOL_ID,
                kind: IVault.SwapKind.GIVEN_IN,
                assetIn: IAsset(ROOT_TOKEN_ADDR),
                assetOut: IAsset(XRP_TOKEN_ADDR),
                amount: amountRootIn,
                userData: new bytes(0)
            });

            IVault.FundManagement memory funds = IVault.FundManagement({
                sender: address(this),
                fromInternalBalance: false,
                recipient: payable(address(this)),
                toInternalBalance: false
            });

            uint xrpOut = IVault(MOAI_VAULT_ADDR).swap(
                singleSwap,
                funds,
                0,
                2000000000
            ); // TODO: deadline
            amountXrp += xrpOut;

            emit SwapRootToXrp(amountRootIn, xrpOut);
        }

        IERC20[] memory poolTokens;
        uint[] memory poolTokenBalances;
        uint _lastChangeBlock;
        (poolTokens, poolTokenBalances, _lastChangeBlock) = IVault(
            MOAI_VAULT_ADDR
        ).getPoolTokens(MOAI_POOL_ID);

        require(
            poolTokens.length == 2 && poolTokenBalances.length == 2,
            "Campaign: The pool should be XRP-ROOT pool"
        );

        require(
            poolTokenBalances[0] > 0 && poolTokenBalances[1] > 0,
            "Campaign: The pool should have liquidity"
        );

        uint spotPrice = (poolTokens[0] == IERC20(XRP_TOKEN_ADDR))
            ? poolTokenBalances[1].divDown(poolTokenBalances[0])
            : poolTokenBalances[0].divDown(poolTokenBalances[1]);

        uint pairedAmountRoot = amountXrp.mulDown(spotPrice);

        require(
            liquiditySupport >= pairedAmountRoot,
            "Campaign: Not enough supported ROOT liquidity"
        );

        IAsset[] memory joinAsset = new IAsset[](2);
        joinAsset[0] = IAsset(ROOT_TOKEN_ADDR);
        joinAsset[1] = IAsset(XRP_TOKEN_ADDR);

        uint[] memory joinAmountsIn = new uint[](2);
        joinAmountsIn[0] = pairedAmountRoot;
        joinAmountsIn[1] = amountXrp;

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

        IERC20(ROOT_TOKEN_ADDR).approve(MOAI_VAULT_ADDR, pairedAmountRoot);
        IERC20(XRP_TOKEN_ADDR).approve(MOAI_VAULT_ADDR, amountXrp);

        uint amountBPTBeforeJoin = IERC20(XRP_ROOT_BPT_ADDR).balanceOf(
            address(this)
        );
        IVault(MOAI_VAULT_ADDR).joinPool(
            MOAI_POOL_ID,
            address(this),
            address(this),
            request
        );
        uint amountBPTAfterJoin = IERC20(XRP_ROOT_BPT_ADDR).balanceOf(
            address(this)
        );
        liquiditySupport -= pairedAmountRoot;

        uint amountBPT = amountBPTAfterJoin - amountBPTBeforeJoin;

        _farm(amountBPT / 2);
    }

    function claim() external {
        Farm storage farm = farms[msg.sender];
        _accrue(farm);
        require(farm.unclaimedRewards > 0, "Campaign: No rewards to claim");

        _exitPool(farm.unclaimedRewards, 0, msg.sender); // 0 = ROOT Token Index

        farm.unclaimedRewards = 0;
    }

    function withdraw(uint amount) external {
        uint amountToBeFreed = _unfarm(amount);

        // user
        _exitPool(amount, 1, msg.sender); // 1 = XRP Token Index

        // freed supported root // TODO: manage not freed BPT amount (2years lock-up)
        if (amountToBeFreed > 0) {
            _exitPool(amountToBeFreed, 0, address(this)); // 0 = ROOT Token Index
        }
    }

    function _exitPool(
        uint exitBPTAmount,
        uint exitAssetIndex,
        address recipient
    ) internal {
        IAsset[] memory exitAsset = new IAsset[](2);
        exitAsset[0] = IAsset(ROOT_TOKEN_ADDR);
        exitAsset[1] = IAsset(XRP_TOKEN_ADDR);

        uint[] memory exitAmountsOut = new uint[](2);
        exitAmountsOut[0] = 0;
        exitAmountsOut[1] = 0;

        bytes memory userData = abi.encode(
            WeightedPoolUserData.ExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT,
            exitBPTAmount,
            exitAssetIndex
        );

        IVault.ExitPoolRequest memory request = IVault.ExitPoolRequest({
            assets: exitAsset,
            minAmountsOut: exitAmountsOut,
            userData: userData,
            toInternalBalance: false
        });

        IVault(MOAI_VAULT_ADDR).exitPool(
            MOAI_POOL_ID,
            address(this),
            payable(recipient),
            request
        );
    }

    // Support $ROOT liquidity
    function supportLiquidity(uint amount) external {
        IERC20(ROOT_TOKEN_ADDR).transferFrom(msg.sender, address(this), amount);
        liquiditySupport += amount;
    }

    function takebackSupport(uint amount) external onlyRootLiquidityAdmin {
        require(
            liquiditySupport >= amount,
            "Campaign: Not enough supported liquidity to take back"
        );
        IERC20(ROOT_TOKEN_ADDR).transfer(msg.sender, amount);
        liquiditySupport -= amount;
    }

    /*
        Farm Part
            - manage farmed BPT and rewards
            - not directly interacting with users
            - not directly interacting with Moai Finance contracts
    */

    // Farm LP tokens for rewards
    function _farm(uint amount) internal {
        require(amount != 0, "Farmed amount should not be zero");
        Farm storage farm = farms[msg.sender];
        _accrue(farm);
        if (farm.amountFarmed == farm.amountLocked) {
            farm.depositedTime = block.timestamp;
        } else {
            // If there is a farmed amount whose paired LP support is not locked up,
            //  its new depositTime is an internally dividing point in inversely proportional to deposited amounts
            farm.depositedTime +=
                ((block.timestamp - farm.depositedTime) * amount) /
                (farm.amountFarmed + amount);
        }
        farm.amountFarmed += amount;
        rewardToBePaid +=
            (((amount * apr) / 1e6) * (rewardEndTime - block.timestamp)) /
            365 days;
        require(rewardPool >= rewardToBePaid, "Farming cap is full");
    }

    // Campaign part should repay 'amountToBeFreed' of BPT and give back $ROOT to Futureverse's LP support pool
    function _unfarm(uint amount) internal returns (uint amountToBeFreed) {
        require(amount != 0, "Unfarmed amount should not be zero");
        Farm storage farm = farms[msg.sender];
        _accrue(farm);
        require(
            farm.amountFarmed >= amount,
            "Not able to withdraw more than deposited"
        );
        require(
            farm.depositedTime + userLockupPeriod < block.timestamp,
            "Lockup period"
        );
        farm.amountFarmed -= amount;
        if (farm.amountLocked < amount) {
            amountToBeFreed = amount - farm.amountLocked;
            farm.amountLocked = 0;
        } else {
            amountToBeFreed = 0;
            farm.amountLocked -= amount;
        }
        rewardToBePaid -=
            (((amount * apr) / 1e6) * (rewardEndTime - block.timestamp)) /
            365 days;
    }

    function _returnAndClearRewardAmount() internal returns (uint amount) {
        Farm storage farm = farms[msg.sender];
        _accrue(farm);
        amount = farm.unclaimedRewards;
        farm.unclaimedRewards = 0;
    }

    function _accrue(Farm storage farm) internal {
        if (
            block.timestamp > rewardStartTime &&
            farm.lastRewardTime < rewardEndTime
        ) {
            uint reward = (((farm.amountFarmed * apr) / 1e6) *
                ((
                    block.timestamp < rewardEndTime
                        ? block.timestamp
                        : rewardEndTime
                ) -
                    (
                        farm.lastRewardTime > rewardStartTime
                            ? farm.lastRewardTime
                            : rewardStartTime
                    ))) / 365 days;
            farm.unclaimedRewards += reward;
            rewardToBePaid -= reward;
            rewardPool -= reward;
            farm.lastRewardTime = block.timestamp;
        }
        if (block.timestamp - farm.depositedTime > periodToLockupLPSupport) {
            farm.amountLocked = farm.amountFarmed;
        }
    }

    // Provide farm reward with $XRP-$ROOT BPT
    function provideRewards(uint amount) external {
        IERC20(XRP_ROOT_BPT_ADDR).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        rewardPool += amount;
    }

    function withdrawRewards(uint amount) external onlyRewardAdmin {
        require(rewardPool >= amount, "Not enough reward pool to withdraw");
        rewardPool -= amount;
        IERC20(XRP_ROOT_BPT_ADDR).transfer(msg.sender, amount);
    }

    function changeRewardAdmin(address newAdmin) external onlyRewardAdmin {
        rewardAdmin = newAdmin;
    }

    function changeApr(uint newApr) external onlyRewardAdmin {
        apr = newApr;
        rewardPool = (rewardPool * newApr) / apr;
        rewardToBePaid = (rewardToBePaid * newApr) / apr;
    }

    function changeUserLockupPeriod(
        uint newLockupPeriod
    ) external onlyRewardAdmin {
        userLockupPeriod = newLockupPeriod;
    }

    function changeRewardTime(
        uint newStartTime,
        uint newEndTime
    ) external onlyRewardAdmin {
        require(
            newStartTime < newEndTime,
            "new start time should be ealier than new end time"
        );
        rewardStartTime = newStartTime;
        rewardEndTime = newEndTime;
    }
}
