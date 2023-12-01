#!/usr/bin/env bash

if [ "$1" != "--rpc" ]; then
    echo "Invalid option. Use --rpc"
    exit 1
fi

forge create \
  --rpc-url "$2", \
  --private-key $CALLER_PRIVATE_KEY \
  --optimize \
  --optimizer-runs 800 \
  --gas-limit 9700000 \
  --legacy \
  --verify \
  --verifier sourcify contracts/weighted-pool-v4/WeightedPoolFactory.sol/:WeightedPoolFactory \
  --constructor-args 0x1D6B655289328a1083EcD70170692002dBED1aBD 0x2Cfc4e04a825286e2B54b1281De1D2AD43EB254F {"name":"WeightedPoolFactory","version":4,"deployment":"20230320-weighted-pool-v4"} {"name":"WeightedPool","version":4,"deployment":"20230320-weighted-pool-v4"}

