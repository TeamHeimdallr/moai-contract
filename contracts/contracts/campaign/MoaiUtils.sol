// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
import "@balancer-labs/v2-interfaces/contracts/vault/IAsset.sol";
import "@balancer-labs/v2-interfaces/contracts/pool-weighted/WeightedPoolUserData.sol";

contract MoaiUtils {
    function _swapRootToXrp(
        bytes32 poolId,
        address vaultAddr,
        address rootTokenAddr,
        address xrpTokenAddr,
        uint amountRootIn
    ) internal returns (uint xrpOut) {
        IVault.SingleSwap memory singleSwap = IVault.SingleSwap({
            poolId: poolId,
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

        xrpOut = IVault(vaultAddr).swap(
            singleSwap,
            funds,
            0,
            block.timestamp + 1 days
        );

        return xrpOut;
    }

    function _joinPool(
        bytes32 poolId,
        address vaultAddr,
        uint rootIndex,
        uint xrpIndex,
        address bptAddr,
        address rootTokenAddr,
        address xrpTokenAddr,
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

        uint amountBPTBeforeJoin = IERC20(bptAddr).balanceOf(address(this));
        IVault(vaultAddr).joinPool(
            poolId,
            address(this),
            address(this),
            request
        );
        uint amountBPTAfterJoin = IERC20(bptAddr).balanceOf(address(this));

        joinedBPT = amountBPTAfterJoin - amountBPTBeforeJoin;
    }

    function _exitPool(
        bytes32 poolId,
        address vaultAddr,
        uint rootIndex,
        uint xrpIndex,
        address bptAddr,
        address rootTokenAddr,
        address xrpTokenAddr,
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

        IVault(vaultAddr).exitPool(
            poolId,
            address(this),
            payable(recipient),
            request
        );
    }
}
