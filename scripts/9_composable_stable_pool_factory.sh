#!/usr/bin/env bash

if [ "$1" != "--rpc" ]; then
    echo "Invalid option. Use --rpc"
    exit 1
fi

forge create \
  --rpc-url "$2" \
  --private-key $CALLER_PRIVATE_KEY \
  --optimize \
  --optimizer-runs 800 \
  --legacy \
  --verify \
  --verifier sourcify contracts/dex/composable-stable-pool-v5/ComposableStablePoolFactory.sol/:ComposableStablePoolFactory \
  --constructor-args 0xc922770de79fc31Cce42DF3fa8234c864fA3FeaE 0xCf39Dd95da35064c0C62b2e5dcCC15e7ACBc4CEb {"name":"ComposableStablePoolFactory","version":5,"deployment":"20230711-composable-stable-pool-v5"} {"name":"ComposableStablePool","version":5,"deployment":"20230711-composable-stable-pool-v5"}

# {
# IVault vault,
# IProtocolFeePercentagesProvider protocolFeeProvider,
# string memory factoryVersion,
# string memory poolVersion
# }

# vault
# mainnet: 0x1D6B655289328a1083EcD70170692002dBED1aBD
# porcini: 0xc922770de79fc31Cce42DF3fa8234c864fA3FeaE

# protocol fee provider
# mainnet: 0x2Cfc4e04a825286e2B54b1281De1D2AD43EB254F
# porcini: 0xCf39Dd95da35064c0C62b2e5dcCC15e7ACBc4CEb