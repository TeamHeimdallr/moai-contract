// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "./v2-interfaces/contracts/vault/IVault.sol";

import "./v2-pool-utils/contracts/factories/BasePoolFactory.sol";
import "./v2-pool-utils/contracts/factories/FactoryWidePauseWindow.sol";

import "./WeightedPool.sol";

contract WeightedPoolFactory2 is BasePoolFactory, FactoryWidePauseWindow {
    constructor(
        IVault vault,
        IProtocolFeePercentagesProvider protocolFeeProvider
    )
        BasePoolFactory(
            vault,
            protocolFeeProvider,
            type(WeightedPool).creationCode
        )
    {}

    /**
     * @notice Returns a JSON representation of the contract version containing name, version number and task ID.
     */
    function version() external pure returns (string memory) {
        return
            '{"name":"WeightedPoolFactory","version":4,"deployment":"20230320-weighted-pool-v4"}';
    }

    /**
     * @notice Returns a JSON representation of the deployed pool version containing name, version number and task ID.
     *
     * @dev This is typically only useful in complex Pool deployment schemes, where multiple subsystems need to know
     * about each other. Note that this value will only be updated at factory creation time.
     */
    function getPoolVersion() public pure returns (string memory) {
        return
            '{"name":"WeightedPool","version":4,"deployment":"20230320-weighted-pool-v4"}';
    }

    /**
     * @dev Deploys a new `WeightedPool`.
     */
    function create(
        string memory name,
        string memory symbol,
        IERC20[] memory tokens,
        uint256[] memory normalizedWeights,
        IRateProvider[] memory rateProviders,
        uint256 swapFeePercentage,
        address owner,
        bytes32 salt
    ) external returns (address) {
        (
            uint256 pauseWindowDuration,
            uint256 bufferPeriodDuration
        ) = getPauseConfiguration();

        return
            _create(
                abi.encode(
                    WeightedPool.NewPoolParams({
                        name: name,
                        symbol: symbol,
                        tokens: tokens,
                        normalizedWeights: normalizedWeights,
                        rateProviders: rateProviders,
                        assetManagers: new address[](tokens.length), // Don't allow asset managers,
                        swapFeePercentage: swapFeePercentage
                    }),
                    IVault(0x398f18353094b3976FF0bDe42b2724c47dc66418),
                    getProtocolFeePercentagesProvider(),
                    pauseWindowDuration,
                    bufferPeriodDuration,
                    owner,
                    '{"name":"WeightedPool","version":4,"deployment":"20230320-weighted-pool-v4"}'
                ),
                salt
            );
    }
}
