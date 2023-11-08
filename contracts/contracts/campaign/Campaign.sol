// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.7.1;

import "../lib/openzeppelin/IERC20.sol";
import "../vault/interfaces/IVault.sol";

contract Comapaign {
    address public constant ROOT_TOKEN_ADDR =
        0x0000000000000000000000000000000000000000;
    address public constant XRP_TOKEN_ADDR =
        0x0000000000000000000000000000000000000000;
    address public constant MOAI_VAULT_ADDR =
        0x0000000000000000000000000000000000000000;
    address public constant MOAI_POOL_ADDR =
        0x0000000000000000000000000000000000000000;
    address public constant XRP_ROOT_BPT_ADDR =
        0x0000000000000000000000000000000000000000;
    string public constant MOAI_POOL_ID =
        "0x000000000000000000000000000000000000000000000a01012020";

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

    function participate(uint amountXrp, uint amountRootIn) external {
        IERC20(XRP_TOKEN_ADDR).transferFrom(
            msg.sender,
            address(this),
            amountXrp
        );
        if (amountRootIn > 0) {
            IERC20(ROOT_TOKEN_ADDR).transferFrom(
                msg.sender,
                address(this),
                amountRootIn
            );
            // TODO : Swap all $ROOT to $XRP
            // amountXrp += IVault(MOAI_VAULT_ADDR).swap();
        }

        // TODO : Calculate $ROOT amount to be paired by querying the spot price
        // IVault(MOAI_VAULT_ADDR).getPoolTokens(MOAI_POOL_ID);
        uint price = 0;
        uint amountRoot = amountXrp * price;

        // TODO : JoinPool (add liquidity) and receive LP token
        // IVault(MOAI_VAULT_ADDR).joinPool(MOAI_POOL_ID, msg.sender, address(this), JoinPoolRequest);
        liquiditySupport -= amountRoot;
        uint amountBPT = 0;

        _farm(amountBPT / 2);
    }

    // TODO
    function claim() external {}

    // Support $ROOT liquidity
    function supportLiquidity(uint amount) external {
        IERC20(ROOT_TOKEN_ADDR).transferFrom(msg.sender, address(this), amount);
        liquiditySupport += amount;
    }

    // TODO
    // function takebackSupport(uint amount) external;

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
