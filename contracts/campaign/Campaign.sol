// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";

import "./MoaiUtils.sol";
import "./RewardFarm.sol";

contract Campaign is MoaiUtils, RewardFarm {
    // Configurations
    uint public liquiditySupportLockupPeriod = 2 * 365 days; // 2 years

    address public rootLiquidityAdmin; // Futureverse

    uint public liquiditySupport;
    uint public lockedLiquidity;
    address public nativeXrpRootLpTokenAddress;
    uint public spotPriceLimit = 5000; // 0.5%

    constructor(
        address rootTokenAddr_,
        address xrpTokenAddr_,
        address vaultAddress_,
        address nativeXrpRootLpTokenAddress_,
        address bptAddr_,
        bytes32 poolId_
    ) {
        rewardAdmin = msg.sender;
        rootLiquidityAdmin = msg.sender;

        rootTokenAddr = rootTokenAddr_;
        xrpTokenAddr = xrpTokenAddr_;
        moaiVaultAddr = vaultAddress_;
        xrpRootBptAddr = bptAddr_;
        rewardTokenAddr = bptAddr_;
        moaiPoolId = poolId_;
        nativeXrpRootLpTokenAddress = nativeXrpRootLpTokenAddress_;

        IERC20[] memory poolTokens;
        uint[] memory poolTokenBalances;
        (poolTokens, poolTokenBalances, ) = IVault(moaiVaultAddr).getPoolTokens(
            moaiPoolId
        );

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

    modifier onlyRootLiquidityAdmin() {
        require(
            msg.sender == rootLiquidityAdmin,
            "Campaign: Only rootLiquidityAdmin can do"
        );
        _;
    }

    modifier onlyNormalUser() {
        require(
            msg.sender != rootLiquidityAdmin && msg.sender != rewardAdmin,
            "Campaign: Admins can't use functions for normal users."
        );
        _;
    }

    event Participate(
        address indexed participant,
        uint amountXrpIn,
        uint amountRootIn,
        uint amountXrpForJoin,
        uint amountPairedRootForJoin,
        uint remainedRootLiquidtySupport
    );
    event Withdraw(
        address indexed sender,
        uint amountBPT,
        uint amountToBeFreed,
        uint additionalLockedLiquidity,
        uint lockedLiquidity,
        uint liquiditySupport
    );
    event Claim(address indexed claimer, uint amountRoot);
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
    event RootLiquidityAdminChanged(
        address indexed prevAdmin,
        address indexed newAdmin
    );

    /*
        Campaign Participation Scenario
            1. Users add liquidity through this part
            2-A. If there are $ROOT, swap all into $XRP via Moai Finance
            2-B. Provide $XRP-$ROOT liquidity and all the $ROOTs are from Futureverse
                Note) The half of LP tokens should belong to Futureverse
            3. Farm users' LP tokens
        Campaign Part
            - interact with users and Moai Finance contracts
            - Not directly interact with farm variables
    */

    function participate(
        uint amountXrpIn,
        uint amountRootIn
    ) external onlyNormalUser {
        uint amountXrp = amountXrpIn;

        require(
            amountXrpIn > 0 || amountRootIn > 0,
            "Campaign: No amount to participate"
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
        (poolTokens, poolTokenBalances, ) = IVault(moaiVaultAddr).getPoolTokens(
            moaiPoolId
        );

        uint moaiPoolSpotPrice = (1e4 * poolTokenBalances[rootIndex]) /
            (poolTokenBalances[xrpIndex]);

        uint nativePoolSpotPrice = (1e4 *
            IERC20(rootTokenAddr).balanceOf(nativeXrpRootLpTokenAddress)) /
            (IERC20(xrpTokenAddr).balanceOf(nativeXrpRootLpTokenAddress));

        if (
            moaiPoolSpotPrice + ((moaiPoolSpotPrice * spotPriceLimit) / 1e5) <
            nativePoolSpotPrice ||
            moaiPoolSpotPrice - ((moaiPoolSpotPrice * spotPriceLimit) / 1e5) >
            nativePoolSpotPrice
        ) {
            revert("Campaign: Spot price is not in the range");
        }

        uint pairedAmountRoot = (amountXrp * poolTokenBalances[rootIndex]) /
            (poolTokenBalances[xrpIndex]);

        require(
            liquiditySupport >= pairedAmountRoot,
            "Campaign: Not enough supported ROOT liquidity"
        );

        uint amountBPT = _joinPool(pairedAmountRoot, amountXrp);
        liquiditySupport -= pairedAmountRoot;

        lockedLiquidity += _farm(amountBPT / 2);

        emit Participate(
            msg.sender,
            amountXrpIn,
            amountRootIn,
            amountXrp,
            pairedAmountRoot,
            liquiditySupport
        );
    }

    function withdraw(uint amount) external onlyNormalUser {
        (uint amountToBeFreed, uint additionalLockedLiquidity) = _unfarm(
            amount
        );
        lockedLiquidity += additionalLockedLiquidity;

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

        emit Withdraw(
            msg.sender,
            amount,
            amountToBeFreed,
            additionalLockedLiquidity,
            lockedLiquidity,
            liquiditySupport
        );
    }

    function claim() external onlyNormalUser {
        (
            uint rewardAmount,
            uint additionalLockedLiquidity
        ) = _returnAndClearRewardAmount();
        require(rewardAmount > 0, "Campaign: No rewards to claim");
        lockedLiquidity += additionalLockedLiquidity;

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

    function changeRootLiquidityAdmin(
        address newAdmin
    ) external onlyRootLiquidityAdmin {
        require(
            farms[newAdmin].amountFarmed == 0,
            "Campaign: New admin must not have a farm."
        );
        rootLiquidityAdmin = newAdmin;

        emit RootLiquidityAdminChanged(msg.sender, newAdmin);
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
