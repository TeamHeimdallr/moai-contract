// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
import "@balancer-labs/v2-interfaces/contracts/vault/IAsset.sol";
import "@balancer-labs/v2-interfaces/contracts/pool-weighted/WeightedPoolUserData.sol";

contract MoaiUtils {
    address public rootTokenAddr;
    address public xrpTokenAddr;
    address public moaiVaultAddr;
    address public xrpRootBptAddr;
    bytes32 public moaiPoolId;
    uint public xrpIndex;
    uint public rootIndex;

    event SwapRootToXrp(
        address indexed sender,
        uint amountRootIn,
        uint amountXrpOut
    );
    event JoinPool(
        address indexed sender,
        uint amountXrp,
        uint amountRoot,
        uint amountBPT
    );
    event ExitPool(address indexed recipient, uint amountBPT);
    event ExitPoolSingle(
        address indexed recipient,
        uint amountBPT,
        uint exitAssetIndex
    );

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

    function _exitPool(uint exitBPTAmount, address recipient) internal {
        IAsset[] memory exitAsset = new IAsset[](2);
        exitAsset[rootIndex] = IAsset(rootTokenAddr);
        exitAsset[xrpIndex] = IAsset(xrpTokenAddr);

        uint[] memory exitAmountsOut = new uint[](2);
        exitAmountsOut[rootIndex] = 0;
        exitAmountsOut[xrpIndex] = 0;

        bytes memory userData = abi.encode(
            WeightedPoolUserData.ExitKind.EXACT_BPT_IN_FOR_TOKENS_OUT,
            exitBPTAmount
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

        emit ExitPool(recipient, exitBPTAmount);
    }

    function _exitPoolSingle(
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

        emit ExitPoolSingle(recipient, exitBPTAmount, exitAssetIndex);
    }
}
