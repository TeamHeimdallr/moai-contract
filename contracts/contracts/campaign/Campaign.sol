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

    //
    uint liquiditySupport = 0;
    mapping(address => uint256) public lpShares;

    // Farm variables
    uint256 rewardPerLiquidity;
    uint112 rewardRemaining;
    uint112 liquidityFarmed;
    uint32 endTime;
    uint32 lastRewardTime;

    mapping(address => uint256) public rewardPerLiquidityLast;
    mapping(address => uint112) public farms;

    /*
        Campaign Part
            1. Users add liquidity through this part
            2-A. (Only XRP deposit) Provide $XRP-$ROOT liquidity and all the $ROOTs are from Futureverse
                Note) The half of LP tokens should belong to Futureverse
            2-B. (XRP, ROOT together) Provide liquidity and then provide the same dollar value amount of $ROOT from Futureverse
                Note) The second liquidity provision is independent of the user
            3. Farm users' LP tokens
    */

    // Add liquidity with supported $ROOT and automatically farm
    function depositOnlyXRP(uint amount) external returns (bool) {
        IERC20(XRP_TOKEN_ADDR).transferFrom(msg.sender, address(this), amount);

        // TODO : Calculate $ROOT amount to be paired by querying the spot price
        // IVault(MOAI_VAULT_ADDR).getPoolTokens(MOAI_POOL_ID);
        uint price = 0;
        uint amountRoot = amount * price;

        // TODO : JoinPool (add liquidity) and receive LP token
        // IVault(MOAI_VAULT_ADDR).joinPool(MOAI_POOL_ID, msg.sender, address(this), JoinPoolRequest);
        liquiditySupport -= amountRoot;
        uint amountBPT = 0;

        _farm(amountBPT / 2);
    }

    // Add liquidity and then add liquidity independently with supported $ROOT
    function addLiquidity(
        uint amountXRP,
        uint amountRoot
    ) external returns (bool) {
        IERC20(XRP_TOKEN_ADDR).transferFrom(
            msg.sender,
            address(this),
            amountXRP
        );
        IERC20(ROOT_TOKEN_ADDR).transferFrom(
            msg.sender,
            address(this),
            amountRoot
        );

        // TODO : JoinPool (add liquidity) and receive LP token
        uint amountBPT = 0;

        _farm(amountBPT);

        // TODO : Calculate $ROOT amount to be paired by querying the spot price
        uint price = 0;
        uint amountRootCalculated = amountXRP * price;

        // TODO : JoinPool (add liquidity) only with $ROOT and do not farm
    }

    // Support $ROOT liquidity
    function supportLiquidity(uint amount) external returns (bool) {
        IERC20(ROOT_TOKEN_ADDR).transferFrom(msg.sender, address(this), amount);
        liquiditySupport += amount;
    }

    /*
        Farm Part
    */

    // Provide farm reward with $ROOT
    // TODO : what if others create farm maliciously?
    function createFarm() external {}

    // Farm LP tokens for rewards
    function _farm(uint amount) internal returns (bool) {}
}
