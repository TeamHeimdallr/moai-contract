// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;
pragma experimental ABIEncoderV2;

import "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
import "@balancer-labs/v2-interfaces/contracts/vault/IAsset.sol";
import "@balancer-labs/v2-interfaces/contracts/pool-weighted/WeightedPoolUserData.sol";

contract Campaign {
    address public rootTokenAddr;
    address public xrpTokenAddr;
    address public moaiVaultAddr;
    address public xrpRootBptAddr;
    bytes32 public moaiPoolId;
    uint public xrpIndex;
    uint public rootIndex;

    // Configurations
    uint public apr = 70000; // 100% = 1000000, 1e6
    // User can't withdraw its deposit before 'userLockupPeriod' has passed since its last deposit
    uint public userLockupPeriod = 12 hours;
    // If a deposit is locked up more than 'periodToLockupLPSupport',
    //  the supported liquidity by Futureverse becomes locked up for 2 years
    //  The locked up BPT isn't freed when the user withdraw from this campaign
    uint public periodToLockupLPSupport = 1 weeks;
    uint public rewardStartTime = type(uint256).max - 1;
    uint public rewardEndTime = type(uint256).max;
    uint public liquiditySupportLockupPeriod = 2 * 365 days; // 2 years

    address public rewardAdmin; // Moai Finance
    address public rootLiquidityAdmin; // Futureverse

    uint public liquiditySupport;
    uint public lockedLiquidity;

    uint public rewardPool;
    uint public rewardToBePaid;

    constructor(
        address rootTokenAddr_,
        address xrpTokenAddr_,
        address vaultAddress_,
        address bptAddr_,
        bytes32 poolId_
    ) {
        rewardAdmin = msg.sender;
        rootLiquidityAdmin = msg.sender;

        rootTokenAddr = rootTokenAddr_;
        xrpTokenAddr = xrpTokenAddr_;
        moaiVaultAddr = vaultAddress_;
        xrpRootBptAddr = bptAddr_;
        moaiPoolId = poolId_;

        IERC20[] memory poolTokens;
        uint[] memory poolTokenBalances;
        uint _lastChangeBlock;
        (poolTokens, poolTokenBalances, _lastChangeBlock) = IVault(
            moaiVaultAddr
        ).getPoolTokens(moaiPoolId);

        require(
            poolTokens.length == 2,
            "Campaign: The pool should be two tokens"
        );

        require(
            poolTokenBalances[0] > 0 && poolTokenBalances[1] > 0,
            "Campaign: The pool should have liquidity"
        );

        xrpIndex = (poolTokens[0] == IERC20(xrpTokenAddr)) ? 0 : 1;
        rootIndex = (xrpIndex == 0) ? 1 : 0;

        require(
            poolTokens[xrpIndex] == IERC20(xrpTokenAddr) &&
                poolTokens[rootIndex] == IERC20(rootTokenAddr),
            "Campaign: The pool should be XRP-ROOT pool"
        );

        IERC20(rootTokenAddr).approve(moaiVaultAddr, type(uint256).max);
        IERC20(xrpTokenAddr).approve(moaiVaultAddr, type(uint256).max);
    }

    struct Farm {
        uint amountFarmed;
        uint amountPairedBPTLocked;
        uint unclaimedRewards;
        uint lastRewardTime;
        uint depositedTime;
    }

    mapping(address => Farm) public farms;

    modifier onlyRewardAdmin() {
        require(msg.sender == rewardAdmin, "Campaign: Only rewardAdmin can do");
        _;
    }

    modifier onlyRootLiquidityAdmin() {
        require(
            msg.sender == rootLiquidityAdmin,
            "Campaign: Only rootLiquidityAdmin can do"
        );
        _;
    }

    event SwapRootToXrp(
        address indexed sender,
        uint amountRootIn,
        uint amountXrpOut
    );
    event Participate(
        address indexed participant,
        uint amountXrpIn,
        uint amountRootIn,
        uint amountXrpForJoin,
        uint amountPairedRootForJoin,
        uint remainedRootLiquidtySupport
    );
    event JoinPool(
        address indexed sender,
        uint amountXrp,
        uint amountRoot,
        uint amountBPT
    );
    event ExitPool(
        address indexed recipient,
        uint amountBPT,
        uint exitAssetIndex
    );
    event Claim(address indexed claimer, uint amountRoot);
    event Farmed(
        address indexed sender,
        uint amountFarmedBPTIn,
        uint amountFarmedBPT,
        uint depositedTime,
        uint totalRewardToBePaid
    );
    event UnFarmed(
        address indexed sender,
        uint amountFarmedBPTOut,
        uint amountFarmedBPT,
        uint amountPairedBPTLocked,
        uint totalRewardToBePaid
    );
    event SupportLiquidity(
        address indexed sender,
        uint amountRoot,
        uint liquiditySupport
    );
    event TakebackLiquidity(
        address indexed sender,
        uint amountRoot,
        uint liquiditySupport
    );
    event WithdrawLiquidityAsBPTAfterLockup(
        address indexed sender,
        uint amountBPT,
        uint lockedLiquidity
    );
    event ProvideRewards(
        address indexed sender,
        uint amountBPTIn,
        uint rewardPool
    );
    event WithdrawRewards(
        address indexed sender,
        uint amountBPTOut,
        uint rewardPool
    );

    /*
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

    function participate(uint amountXrpIn, uint amountRootIn) external {
        uint amountXrp = amountXrpIn;

        require(
            amountXrpIn > 0 || amountRootIn > 0,
            "Campaign: No amount to participate"
        );

        require(
            block.timestamp >= rewardStartTime &&
                block.timestamp < rewardEndTime,
            "Campaign: Not started or already ended"
        );

        if (amountXrpIn > 0) {
            IERC20(xrpTokenAddr).transferFrom(
                msg.sender,
                address(this),
                amountXrpIn
            );
        }

        if (amountRootIn > 0) {
            IERC20(rootTokenAddr).transferFrom(
                msg.sender,
                address(this),
                amountRootIn
            );

            uint xrpOut = _swapRootToXrp(amountRootIn);
            amountXrp += xrpOut;
        }

        IERC20[] memory poolTokens;
        uint[] memory poolTokenBalances;
        uint _lastChangeBlock;
        (poolTokens, poolTokenBalances, _lastChangeBlock) = IVault(
            moaiVaultAddr
        ).getPoolTokens(moaiPoolId);

        require(
            poolTokens.length == 2 && poolTokenBalances.length == 2,
            "Campaign: The pool should be XRP-ROOT pool"
        );

        require(
            poolTokenBalances[0] > 0 && poolTokenBalances[1] > 0,
            "Campaign: The pool should have liquidity"
        );

        uint pairedAmountRoot = (amountXrp * poolTokenBalances[rootIndex]) /
            (poolTokenBalances[xrpIndex]);

        require(
            liquiditySupport >= pairedAmountRoot,
            "Campaign: Not enough supported ROOT liquidity"
        );

        uint amountBPT = _joinPool(pairedAmountRoot, amountXrp);
        liquiditySupport -= pairedAmountRoot;

        _farm(amountBPT / 2);

        emit Participate(
            msg.sender,
            amountXrpIn,
            amountRootIn,
            amountXrp,
            pairedAmountRoot,
            liquiditySupport
        );
    }

    function withdraw(uint amount) external {
        uint amountToBeFreed = _unfarm(amount);

        // user
        _exitPool(amount, xrpIndex, msg.sender);

        // freed supported root
        if (amountToBeFreed > 0) {
            uint beforeRootAmount = IERC20(rootTokenAddr).balanceOf(
                address(this)
            );
            _exitPool(amountToBeFreed, rootIndex, address(this));
            uint afterRootAmount = IERC20(rootTokenAddr).balanceOf(
                address(this)
            );
            liquiditySupport += (afterRootAmount - beforeRootAmount);
        }
    }

    function claim() external {
        uint rewardAmount = _returnAndClearRewardAmount();
        require(rewardAmount > 0, "Campaign: No rewards to claim");

        uint beforeRootAmount = IERC20(rootTokenAddr).balanceOf(msg.sender);
        _exitPool(rewardAmount, rootIndex, msg.sender);
        uint afterRootAmount = IERC20(rootTokenAddr).balanceOf(msg.sender);

        emit Claim(msg.sender, afterRootAmount - beforeRootAmount);
    }

    // Support $ROOT liquidity
    function supportLiquidity(uint amount) external {
        IERC20(rootTokenAddr).transferFrom(msg.sender, address(this), amount);
        liquiditySupport += amount;

        emit SupportLiquidity(msg.sender, amount, liquiditySupport);
    }

    function _swapRootToXrp(uint amountRootIn) internal returns (uint xrpOut) {
        IVault.SingleSwap memory singleSwap = IVault.SingleSwap({
            poolId: moaiPoolId,
            kind: IVault.SwapKind.GIVEN_IN,
            assetIn: IAsset(rootTokenAddr),
            assetOut: IAsset(xrpTokenAddr),
            amount: amountRootIn,
            userData: new bytes(0)
        });

        IVault.FundManagement memory funds = IVault.FundManagement({
            sender: address(this),
            fromInternalBalance: false,
            recipient: payable(address(this)),
            toInternalBalance: false
        });

        xrpOut = IVault(moaiVaultAddr).swap(
            singleSwap,
            funds,
            0,
            block.timestamp + 1 days
        );

        emit SwapRootToXrp(msg.sender, amountRootIn, xrpOut);

        return xrpOut;
    }

    function _joinPool(
        uint amountRoot,
        uint amountXrp
    ) internal returns (uint joinedBPT) {
        IAsset[] memory joinAsset = new IAsset[](2);
        joinAsset[rootIndex] = IAsset(rootTokenAddr);
        joinAsset[xrpIndex] = IAsset(xrpTokenAddr);

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

        uint amountBPTBeforeJoin = IERC20(xrpRootBptAddr).balanceOf(
            address(this)
        );
        IVault(moaiVaultAddr).joinPool(
            moaiPoolId,
            address(this),
            address(this),
            request
        );
        uint amountBPTAfterJoin = IERC20(xrpRootBptAddr).balanceOf(
            address(this)
        );

        joinedBPT = amountBPTAfterJoin - amountBPTBeforeJoin;

        emit JoinPool(msg.sender, amountXrp, amountRoot, joinedBPT);
    }

    function _exitPool(
        uint exitBPTAmount,
        uint exitAssetIndex,
        address recipient
    ) internal {
        IAsset[] memory exitAsset = new IAsset[](2);
        exitAsset[rootIndex] = IAsset(rootTokenAddr);
        exitAsset[xrpIndex] = IAsset(xrpTokenAddr);

        uint[] memory exitAmountsOut = new uint[](2);
        exitAmountsOut[rootIndex] = 0;
        exitAmountsOut[xrpIndex] = 0;

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

        IVault(moaiVaultAddr).exitPool(
            moaiPoolId,
            address(this),
            payable(recipient),
            request
        );

        emit ExitPool(recipient, exitBPTAmount, exitAssetIndex);
    }

    /*
        Farm Part
            - manage farmed BPT and rewards
            - not directly interacting with users
            - not directly interacting with Moai Finance contracts
    */

    // Farm LP tokens for rewards
    function _farm(uint amount) internal {
        require(amount != 0, "Campaign: Farmed amount should not be zero");
        Farm storage farm = farms[msg.sender];
        _accrue(farm);
        if (farm.amountFarmed == farm.amountPairedBPTLocked) {
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
        require(rewardPool >= rewardToBePaid, "Campaign: Farming cap is full");

        emit Farmed(
            msg.sender,
            amount,
            farm.amountFarmed,
            farm.depositedTime,
            rewardToBePaid
        );
    }

    // Campaign part should repay 'amountToBeFreed' of BPT and give back $ROOT to Futureverse's LP support pool
    function _unfarm(uint amount) internal returns (uint amountToBeFreed) {
        require(amount != 0, "Campaign: Unfarmed amount should not be zero");
        Farm storage farm = farms[msg.sender];
        _accrue(farm);
        require(
            farm.amountFarmed >= amount,
            "Campaign: Not able to withdraw more than deposited"
        );
        require(
            farm.depositedTime + userLockupPeriod < block.timestamp,
            "Campaign: Lockup period"
        );
        farm.amountFarmed -= amount;
        if (farm.amountPairedBPTLocked < amount) {
            amountToBeFreed = amount - farm.amountPairedBPTLocked;
            farm.amountPairedBPTLocked = 0;
        } else {
            amountToBeFreed = 0;
            farm.amountPairedBPTLocked -= amount;
        }
        rewardToBePaid -=
            (((amount * apr) / 1e6) * (rewardEndTime - block.timestamp)) /
            365 days;

        emit UnFarmed(
            msg.sender,
            amount,
            farm.amountFarmed,
            farm.amountPairedBPTLocked,
            rewardToBePaid
        );
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
            lockedLiquidity += (farm.amountFarmed - farm.amountPairedBPTLocked);
            farm.amountPairedBPTLocked = farm.amountFarmed;
        }
    }

    // Provide farm reward with $XRP-$ROOT BPT
    function provideRewards(uint amount) external {
        IERC20(xrpRootBptAddr).transferFrom(msg.sender, address(this), amount);
        rewardPool += amount;

        emit ProvideRewards(msg.sender, amount, rewardPool);
    }

    function withdrawRewards(uint amount) external onlyRewardAdmin {
        require(
            rewardPool >= amount,
            "Campaign: Not enough reward pool to withdraw"
        );
        rewardPool -= amount;
        IERC20(xrpRootBptAddr).transfer(msg.sender, amount);

        emit WithdrawRewards(msg.sender, amount, rewardPool);
    }

    function changeRewardAdmin(address newAdmin) external onlyRewardAdmin {
        rewardAdmin = newAdmin;
    }

    function changeRootLiquidityAdmin(
        address newAdmin
    ) external onlyRootLiquidityAdmin {
        rootLiquidityAdmin = newAdmin;
    }

    function changeApr(uint newApr) external onlyRewardAdmin {
        rewardPool = (rewardPool * newApr) / apr;
        rewardToBePaid = (rewardToBePaid * newApr) / apr;
        apr = newApr;
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
            "Campaign: new start time should be ealier than new end time"
        );
        rewardStartTime = newStartTime;
        rewardEndTime = newEndTime;
    }

    function changePeriodToLockupLPSupport(
        uint newPeriodToLockupLPSupport
    ) external onlyRewardAdmin {
        periodToLockupLPSupport = newPeriodToLockupLPSupport;
    }

    function takebackSupport(uint amount) external onlyRootLiquidityAdmin {
        require(
            liquiditySupport >= amount,
            "Campaign: Not enough supported liquidity to take back"
        );
        IERC20(rootTokenAddr).transfer(msg.sender, amount);
        liquiditySupport -= amount;

        emit TakebackLiquidity(msg.sender, amount, liquiditySupport);
    }

    function withdrawSupportAfterCampaign(
        uint amount
    ) external onlyRootLiquidityAdmin {
        require(
            block.timestamp > rewardEndTime + liquiditySupportLockupPeriod,
            "Campaign: Not able to withdraw liquidity yet"
        );
        require(
            lockedLiquidity >= amount,
            "Campaign: Not enough locked liquidity to withdraw"
        );
        lockedLiquidity -= amount;
        IERC20(xrpRootBptAddr).transfer(msg.sender, amount);

        emit WithdrawLiquidityAsBPTAfterLockup(
            msg.sender,
            amount,
            lockedLiquidity
        );
    }
}
