// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";

import "./MoaiUtils.sol";

// after campaign ends, users can claim their rewards
contract CampaignReward is MoaiUtils {
    mapping(address => uint) public unclaimedRewards;

    address public rewardAdmin;
    address public rewardTokenAddr;

    uint public rewardToBeDistributed;

    modifier onlyRewardAdmin() {
        require(msg.sender == rewardAdmin, "Campaign: Only rewardAdmin can do");
        _;
    }

    constructor(
        address rootTokenAddr_,
        address xrpTokenAddr_,
        address vaultAddress_,
        address bptAddr_,
        bytes32 poolId_
    ) {
        rewardAdmin = msg.sender;

        rootTokenAddr = rootTokenAddr_;
        xrpTokenAddr = xrpTokenAddr_;
        moaiVaultAddr = vaultAddress_;
        xrpRootBptAddr = bptAddr_;
        rewardTokenAddr = bptAddr_;
        moaiPoolId = poolId_;

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

    event Claim(address indexed claimer, uint amountRoot);
    event ProvideRewards(address indexed sender, uint amountBPTIn);
    event WithdrawRewards(address indexed sender, uint amountBPTOut);

    function updateRewards(
        address[] memory addresses,
        uint[] memory rewards
    ) external onlyRewardAdmin {
        require(
            addresses.length == rewards.length,
            "Campaign: Invalid input length"
        );

        uint len = addresses.length;
        for (uint i = 0; i < len; ++i) {
            rewardToBeDistributed -= unclaimedRewards[addresses[i]];
            unclaimedRewards[addresses[i]] = rewards[i];
            rewardToBeDistributed += rewards[i];
        }
    }

    // Provide farm reward with $XRP-$ROOT BPT
    function provideRewards(uint amount) external {
        IERC20(rewardTokenAddr).transferFrom(msg.sender, address(this), amount);

        emit ProvideRewards(msg.sender, amount);
    }

    function withdrawRewards(uint amount) external onlyRewardAdmin {
        IERC20(rewardTokenAddr).transfer(msg.sender, amount);

        emit WithdrawRewards(msg.sender, amount);
    }

    function claim() external {
        uint rewardAmount = unclaimedRewards[msg.sender];
        require(rewardAmount > 0, "Campaign: No rewards to claim");

        uint beforeRootAmount = IERC20(rootTokenAddr).balanceOf(address(this));
        _exitPoolSingle(rewardAmount, rootIndex, address(this));
        uint afterRootAmount = IERC20(rootTokenAddr).balanceOf(address(this));

        unclaimedRewards[msg.sender] = 0;

        IERC20(rootTokenAddr).transfer(
            msg.sender,
            afterRootAmount - beforeRootAmount
        );

        emit Claim(msg.sender, afterRootAmount - beforeRootAmount);
    }

    function changeRewardAdmin(address newAdmin) external onlyRewardAdmin {
        rewardAdmin = newAdmin;
    }
}
