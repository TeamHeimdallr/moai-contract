// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";

contract RewardFarm {
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

    address public rewardAdmin; // Moai Finance
    address public rewardTokenAddr;

    uint public rewardPool;
    uint public rewardToBePaid;

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

    // Farm LP tokens for rewards
    function _farm(
        uint amount
    ) internal returns (uint additionalLockedLiquidity) {
        require(
            block.timestamp >= rewardStartTime &&
                block.timestamp < rewardEndTime,
            "Campaign: Not started or already ended"
        );
        require(amount != 0, "Campaign: Farmed amount should not be zero");
        Farm storage farm = farms[msg.sender];
        additionalLockedLiquidity = _accrue(farm);
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
    function _unfarm(
        uint amount
    ) internal returns (uint amountToBeFreed, uint additionalLockedLiquidity) {
        require(amount != 0, "Campaign: Unfarmed amount should not be zero");
        Farm storage farm = farms[msg.sender];
        additionalLockedLiquidity = _accrue(farm);
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

    function _returnAndClearRewardAmount()
        internal
        returns (uint amount, uint additionalLockedLiquidity)
    {
        Farm storage farm = farms[msg.sender];
        additionalLockedLiquidity = _accrue(farm);
        amount = farm.unclaimedRewards;
        farm.unclaimedRewards = 0;
    }

    function _accrue(
        Farm storage farm
    ) internal returns (uint additionalLockedLiquidity) {
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
            additionalLockedLiquidity = (farm.amountFarmed -
                farm.amountPairedBPTLocked);
            farm.amountPairedBPTLocked = farm.amountFarmed;
        }
    }

    // Provide farm reward with $XRP-$ROOT BPT
    function provideRewards(uint amount) external {
        rewardPool += amount;
        IERC20(rewardTokenAddr).transferFrom(msg.sender, address(this), amount);

        emit ProvideRewards(msg.sender, amount, rewardPool);
    }

    function withdrawRewards(uint amount) external onlyRewardAdmin {
        require(
            rewardPool >= amount,
            "Campaign: Not enough reward pool to withdraw"
        );
        rewardPool -= amount;
        IERC20(rewardTokenAddr).transfer(msg.sender, amount);

        emit WithdrawRewards(msg.sender, amount, rewardPool);
    }

    function changeRewardAdmin(address newAdmin) external onlyRewardAdmin {
        rewardAdmin = newAdmin;
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
}
