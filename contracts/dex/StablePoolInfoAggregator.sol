// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";

interface IDecimals {
    function decimals() external view returns (uint8);
}

interface IComposableStablePool {
    function getSwapFeePercentage() external view returns (uint);
    function getAmplificationParameter()
        external
        view
        returns (uint256 value, bool isUpdating, uint256 precision);
    function getActualSupply() external view returns (uint256);
}

contract StablePoolInfoAggregator {
    address public vaultAddress;
    address private owner;

    constructor(address vaultAddress_) {
        vaultAddress = vaultAddress_;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Authentication Error");
        _;
    }

    function setOwner(address owner_) external onlyOwner {
        owner = owner_;
    }

    function aggregate(
        bytes32[] memory poolIds
    )
        external
        view
        returns (
            uint[] memory actualShares,
            uint[] memory swapFees,
            uint[] memory ampValue,
            uint[] memory ampPrecision,
            address[][] memory tokens,
            uint[][] memory balances,
            uint[][] memory decimals
        )
    {
        actualShares = new uint[](poolIds.length);
        swapFees = new uint[](poolIds.length);
        ampValue = new uint[](poolIds.length);
        ampPrecision = new uint[](poolIds.length);
        tokens = new address[][](poolIds.length);
        balances = new uint[][](poolIds.length);
        decimals = new uint[][](poolIds.length);
        for (uint i = 0; i < poolIds.length; ++i) {
            (IERC20[] memory erc20s_, uint[] memory balances_, ) = IVault(
                vaultAddress
            ).getPoolTokens(poolIds[i]);

            balances[i] = balances_;

            address[] memory tokens_ = new address[](erc20s_.length);
            uint[] memory decimals_ = new uint[](erc20s_.length);
            for (uint j = 0; j < erc20s_.length; ++j) {
                address tokenAddr = address(erc20s_[j]);
                tokens_[j] = tokenAddr;
                decimals_[j] = uint(IDecimals(tokenAddr).decimals());
            }

            tokens[i] = tokens_;
            decimals[i] = decimals_;

            (address poolAddress, ) = IVault(vaultAddress).getPool(poolIds[i]);
            IComposableStablePool pool = IComposableStablePool(poolAddress);
            swapFees[i] = pool.getSwapFeePercentage();
            actualShares[i] = pool.getActualSupply();
            (uint256 value, , uint256 precision) = pool
                .getAmplificationParameter();
            ampValue[i] = value;
            ampPrecision[i] = precision;
        }
    }
}
