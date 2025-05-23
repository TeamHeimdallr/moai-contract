// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";

contract RewardFarm {
    // Configurations
    uint public apr = 100000; // 100% = 1000000, 1e6
    // User can't withdraw its deposit before 'userLockupPeriod' has passed since its last deposit
    uint public userLockupPeriod = 24 hours;
    // If a deposit is locked up more than 'periodToLockupLPSupport',
    //  the supported liquidity by Futureverse becomes locked up for 2 years
    //  The locked up BPT isn't freed when the user withdraw from this campaign
    uint public periodToLockupLPSupport = 30 days;
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
        uint totalRewardToBePaid,
        uint toBeLockedRatio
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
    event AprChanged(uint prevApr, uint newApr);
    event UserLockupPeriodChanged(
        uint prevUserLockupPeriod,
        uint newUserLockupPeriod
    );
    event RewardTimeChanged(
        uint prevRewardStartTime,
        uint prevRewardEndTime,
        uint newRewardStartTime,
        uint newRewardEndTime
    );
    event PeriodToLockupLPSupportChanged(
        uint prevPeriodToLockupLPSupport,
        uint newPeriodToLockupLPSupport
    );
    event RewardAdminChanged(address prevRewardAdmin, address newRewardAdmin);

    // Farm LP tokens for rewards
    function _farm(uint amount) internal {
        require(
            block.timestamp >= rewardStartTime &&
                block.timestamp < rewardEndTime,
            "Campaign: Not started or already ended"
        );
        Farm storage farm = farms[msg.sender];
        _accrue(msg.sender);
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

    // Campaign part should lock 'toBeLockedRatio' of BPT as BPT and remain $ROOT is freed
    function _unfarm(uint amount) internal returns (uint toBeLockedRatio) {
        require(amount != 0, "Campaign: Unfarmed amount should not be zero");
        Farm storage farm = farms[msg.sender];
        _accrue(msg.sender);
        require(
            farm.amountFarmed >= amount,
            "Campaign: Not able to withdraw more than deposited"
        );
        require(
            farm.depositedTime + userLockupPeriod < block.timestamp,
            "Campaign: Lockup period"
        );

        toBeLockedRatio = farm.amountPairedBPTLocked >= farm.amountFarmed
            ? 1e6
            : (1e6 * farm.amountPairedBPTLocked) / farm.amountFarmed;

        farm.amountFarmed -= amount;

        farm.amountPairedBPTLocked =
            (farm.amountFarmed * toBeLockedRatio) /
            1e6;

        rewardToBePaid -=
            (((amount * apr) / 1e6) * (rewardEndTime - block.timestamp)) /
            365 days;

        emit UnFarmed(
            msg.sender,
            amount,
            farm.amountFarmed,
            farm.amountPairedBPTLocked,
            rewardToBePaid,
            toBeLockedRatio
        );
    }

    function _returnAndClearRewardAmount() internal returns (uint amount) {
        Farm storage farm = farms[msg.sender];
        _accrue(msg.sender);
        amount = farm.unclaimedRewards;
        farm.unclaimedRewards = 0;
    }

    function _accrue(address account) internal {
        Farm storage farm = farms[account];

        (
            Farm memory farmSimulated,
            uint rewardToBePaidSimulated,
            uint rewardPoolSimulated
        ) = simulateAccrue(account);

        farm.amountPairedBPTLocked = farmSimulated.amountPairedBPTLocked;
        farm.lastRewardTime = farmSimulated.lastRewardTime;
        farm.unclaimedRewards = farmSimulated.unclaimedRewards;

        rewardToBePaid = rewardToBePaidSimulated;
        rewardPool = rewardPoolSimulated;
    }

    function simulateAccrue(
        address account
    )
        public
        view
        returns (
            Farm memory farmSimulated,
            uint rewardToBePaidSimulated,
            uint rewardPoolSimulated
        )
    {
        farmSimulated = farms[account];
        rewardToBePaidSimulated = rewardToBePaid;
        rewardPoolSimulated = rewardPool;

        if (
            block.timestamp > rewardStartTime &&
            farmSimulated.lastRewardTime < rewardEndTime
        ) {
            uint reward = (((farmSimulated.amountFarmed * apr) / 1e6) *
                ((
                    block.timestamp < rewardEndTime
                        ? block.timestamp
                        : rewardEndTime
                ) -
                    (
                        farmSimulated.lastRewardTime > rewardStartTime
                            ? farmSimulated.lastRewardTime
                            : rewardStartTime
                    ))) / 365 days;
            farmSimulated.unclaimedRewards += reward;
            rewardToBePaidSimulated = rewardToBePaid - reward;
            rewardPoolSimulated = rewardPool - reward;
            farmSimulated.lastRewardTime = block.timestamp;
        }
        if (
            block.timestamp - farmSimulated.depositedTime >
            periodToLockupLPSupport
        ) {
            farmSimulated.amountPairedBPTLocked = farmSimulated.amountFarmed;
        }
    }

    // Provide farm reward with $XRP-$ROOT BPT
    function provideRewards(uint amount) external {
        rewardPool += amount;
        IERC20(rewardTokenAddr).transferFrom(msg.sender, address(this), amount);

        emit ProvideRewards(msg.sender, amount, rewardPool);
    }

    // Note) some farmers can't receive rewards after reward withdrawal.
    function withdrawRewards(uint amount) external onlyRewardAdmin {
        require(
            rewardPool >= amount,
            "Campaign: Not enough reward pool to withdraw"
        );
        rewardPool -= amount;
        IERC20(rewardTokenAddr).transfer(msg.sender, amount);

        emit WithdrawRewards(msg.sender, amount, rewardPool);
    }

    function changeApr(uint newApr) external onlyRewardAdmin {
        require(newApr > 0, "RewardFarm: apr should not be 0");
        rewardToBePaid = (rewardToBePaid * newApr) / apr;
        apr = newApr;

        emit AprChanged(apr, newApr);
    }

    function changeUserLockupPeriod(
        uint newLockupPeriod
    ) external onlyRewardAdmin {
        userLockupPeriod = newLockupPeriod;

        emit UserLockupPeriodChanged(userLockupPeriod, newLockupPeriod);
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

        emit RewardTimeChanged(
            rewardStartTime,
            rewardEndTime,
            newStartTime,
            newEndTime
        );
    }

    function changePeriodToLockupLPSupport(
        uint newPeriodToLockupLPSupport
    ) external onlyRewardAdmin {
        periodToLockupLPSupport = newPeriodToLockupLPSupport;

        emit PeriodToLockupLPSupportChanged(
            periodToLockupLPSupport,
            newPeriodToLockupLPSupport
        );
    }

    function changeRewardAdmin(address newAdmin) external onlyRewardAdmin {
        require(
            farms[newAdmin].amountFarmed == 0,
            "Campaign: New admin must not have a farm."
        );
        rewardAdmin = newAdmin;

        emit RewardAdminChanged(msg.sender, newAdmin);
    }
}
