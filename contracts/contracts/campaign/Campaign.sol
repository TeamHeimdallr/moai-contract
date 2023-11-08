// SPDX-License-Identifier: GPL-3.0-or-later

import "../lib/openzeppelin/IERC20.sol";
import "../vault/interfaces/IVault.sol";

contract Comapaign {
    address public ROOT_TOKEN_ADDR = 0x0000000000000000000000000000000000000000;
    address public XRP_TOKEN_ADDR = 0x0000000000000000000000000000000000000000;
    address public MOAI_VAULT_ADDR = 0x0000000000000000000000000000000000000000;
    address public MOAI_POOL_ADDR = 0x0000000000000000000000000000000000000000;
    address public XRP_ROOT_BPT_ADDR =
        0x0000000000000000000000000000000000000000;
    string public MOAI_POOL_ID =
        "0x000000000000000000000000000000000000000000000a01012020";

    uint public APR = 70000; // 100% = 1000000
    address rewardAdmin = 0x0000000000000000000000000000000000000000; // Moai Finance
    address rootLiquidityAdmin = 0x0000000000000000000000000000000000000000; // Futureverse

    uint liquiditySupport = 0;
    uint lockedLiquidity = 0;

    uint rewardStartTime = 0;
    uint rewardEndTime = 0;

    struct Farm {
        uint amountFarmed;
        uint amountLocked; // TODO : rename this. The amount of BPT whose paired BPT of Futureverse was locked
        uint unclaimedRewards;
        uint32 lastRewardTime;
        uint32 depositiedTime;
    }

    mapping(address => Farm) public farms;

    modifier onlyRewardAdmin() {
        require(msg.sender == rewardAdmin, "Only rewardAdmin can do");
        _;
    }

    /*
        Campaign Part
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

    /*
        Farm Part
    */

    // Farm LP tokens for rewards
    function _farm(uint amount) internal returns (bool) {
        Farm storage farm = farms[msg.sender];
    }

    function _accrue(Farm storage farm) internal returns (uint) {}

    // Provide farm reward with $XRP-$ROOT BPT
    function provideRewards(uint amount) external {
        IERC20(XRP_ROOT_BPT_ADDR).transferFrom(
            msg.sender,
            address(this),
            amount
        );
    }

    function withdrawRewards(uint amount) external onlyRewardAdmin {
        IERC20(XRP_ROOT_BPT_ADDR).transfer(msg.sender, amount);
    }

    function changeRewardAdmin(address newAdmin) external onlyRewardAdmin {
        rewardAdmin = newAdmin;
    }

    function changeAPR(uint newAPR) external onlyRewardAdmin {
        APR = newAPR;
    }
}
