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
  --constructor-args 0xF5bB92ea0f82E01F890ad82AbbECE7B721fC780b 0x41F776D8fA56472fEe751593b313BF4103e2f586 {"name":"WeightedPoolFactory","version":4,"deployment":"20230320-weighted-pool-v4"} {"name":"WeightedPool","version":4,"deployment":"20230320-weighted-pool-v4"}

